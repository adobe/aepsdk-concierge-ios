/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AVFoundation
import Speech

import AEPServices

class SpeechCapturer: SpeechCapturing {
    var responseProcessor: ((String) -> Void)?
    var audioLevelHandler: ((Float) -> Void)?
    var silenceHandler: (() -> Void)?

    private let LOG_TAG = "SpeechCapturer"
    private var isCapturing: Bool = false

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Recreated on every `prepareAudioEngineForNewInputTap()` rather than reused for the SpeechCapturer's whole
    /// lifetime — AVAudioEngine can retain stale input-node hardware-format state across a route change (e.g.
    /// built-in mic at 48kHz -> AirPods' Bluetooth mic profile at 24kHz), which `reset()` alone doesn't clear
    /// and which otherwise surfaces as "formats don't match" (-10868) when starting/restarting capture.
    private var audioEngine = AVAudioEngine()
    private var currentTranscription = ""
    private var hasInputTapInstalled = false

    /// Guards all "Silence detection" and "Ambient noise floor" state below: it's written from the main thread
    /// (`configureSilenceDetection`, `resetSilenceDetectionState` via `beginCapture`/route-change restart) and
    /// read/written from Core Audio's realtime tap-callback thread (`processAudioLevel` and everything it calls).
    /// `AVAudioEngine.stop()`/`removeTap` don't document a guarantee that an in-flight tap callback has returned
    /// before they do, so this can't safely rely on call ordering alone — particularly `noiseFloorCalibrationSamples`,
    /// where a concurrent append/reassign on an `Array` from two threads is undefined behavior, not just a stale read.
    private let silenceDetectionLock = NSLock()

    /// Silence detection
    private var silenceThreshold: Float = 0.02
    private var silenceDuration: TimeInterval = 2.0
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests` by setting a past `Date` to
    /// deterministically simulate elapsed silence duration without a real sleep.
    var silenceStart: Date?
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    var hasSpokeOnce = false

    /// Ambient noise floor (raw RMS, uncompensated), calibrated at the start of each capture and slowly adapted
    /// during quiet periods before speech is first detected. Used only to compute `gainCompensatedRMS`.
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    var noiseFloor: Float?
    private var noiseFloorCalibrationSamples: [Float] = []
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests` by setting a past `Date` to
    /// deterministically simulate an elapsed calibration window without a real sleep.
    var captureStartTime: Date?

    /// How long at the start of a capture to sample ambient noise before making speech/silence decisions.
    static let noiseFloorCalibrationDuration: TimeInterval = 0.3
    /// How quickly the noise floor drifts toward newly observed quiet samples (0...1, higher = faster).
    static let noiseFloorAdaptationRate: Float = 0.05
    /// Hard floor under the noise floor. Not just a divide-by-zero guard — it caps how large the compensation
    /// gain below can get. Some mics (e.g. AirPods, calibrated as low as ~0.00005 RMS in testing) are so much
    /// quieter than a phone's built-in mic (~0.0002-0.0006 RMS) that an uncapped gain amplifies ordinary
    /// breathing/mouth noise after speech ends (~0.0003-0.0005 RMS observed) past `silenceThreshold`, so the
    /// user is never detected as having gone quiet. This value is set above that observed non-speech ceiling.
    static let minimumNoiseFloorRMS: Float = 0.0005
    /// What a properly auto-gain-controlled ambient floor is assumed to look like — fixed to the *default*
    /// `silenceThreshold` (0.02) rather than derived from the live, configurable `silenceThreshold`. Deriving it
    /// from the live value would cancel out in `gainCompensatedRMS`'s comparison against that same value, making
    /// `silenceThreshold` have no effect on sensitivity; keeping this fixed is what makes the live threshold scale
    /// the required floor-multiple correctly (higher threshold -> proportionally more floor required -> less
    /// sensitive, per its documented meaning). 3x is what we validated on real device RMS at the default value
    /// during the "voice to text is endless" investigation — thresholds far from 0.02 are not on-device validated.
    static let targetFloorReferenceRMS: Float = 0.02 / 3.0

    /// Avoid overlapping pipeline restarts when route notifications fire in quick succession.
    private var isRestartingCaptureForRouteChange = false

    private var routeChangeObserver: NSObjectProtocol?

    /// Prevents stale `SFSpeechRecognitionTask` callbacks (from a prior session or `cancel()`) from mutating state or calling `abortStreamingCapture` after a new capture has started.
    private var recognitionSessionToken = UUID()

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioRouteChange(notification: notification)
        }
    }

    deinit {
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func configureSilenceDetection(threshold: Float, duration: TimeInterval) {
        let resolvedThreshold = threshold > 0 ? threshold : 0.02
        let resolvedDuration = duration > 0 ? duration : 2.0
        silenceDetectionLock.lock()
        defer { silenceDetectionLock.unlock() }
        silenceThreshold = resolvedThreshold
        silenceDuration = resolvedDuration
    }

    func initialize(responseProcessor: ((String) -> Void)?) {
        self.responseProcessor = responseProcessor
    }

    // MARK: - internal methods

    func isAvailable() -> Bool {
        permissionGrantedForAudio && permissionGrantedForSpeech
    }

    func hasPermissionBeenDenied() -> Bool {
        let audioStatus = AVAudioSession.sharedInstance().recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        return audioStatus == .denied || speechStatus == .denied || speechStatus == .restricted
    }

    func hasNeverBeenAskedForPermission() -> Bool {
        let audioStatus = AVAudioSession.sharedInstance().recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        return audioStatus == .undetermined && speechStatus == .notDetermined
    }

    func beginCapture() {
        // Prevent double-starts which can cause a crash due to multiple recognition tasks trying to access the same audio engine/tap
        if isCapturing {
            Log.warning(label: self.LOG_TAG, "beginCapture ignored. Capturing is already in progress.")
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            Log.error(label: self.LOG_TAG, "Speech recognition is not available for the current locale or configuration.")
            return
        }

        isCapturing = true
        resetTranscriptionAndSilenceTracking()
        cancelRecognitionTaskAndClearRequest()

        prepareAudioEngineForNewInputTap()

        do {
            try configureAudioSessionForCapture()
            try startRecognitionPipeline(recognizer: recognizer)
        } catch {
            Log.error(label: self.LOG_TAG, "Failed to start speech capture: \(error)")
            isCapturing = false
            cancelRecognitionTaskAndClearRequest()
            prepareAudioEngineForNewInputTap()
        }
    }

    func endCapture(completion: @escaping (String?, (any Error)?) -> Void) {
        recognitionSessionToken = UUID()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        removeInputTapIfNeeded()
        isCapturing = false
        DispatchQueue.main.async { [weak self] in self?.audioLevelHandler?(0) }
        completion(currentTranscription, nil)
    }

    // MARK: - private methods

    private func resetTranscriptionAndSilenceTracking() {
        currentTranscription = ""
        resetSilenceDetectionState()
    }

    /// Resets noise-floor calibration and speech/silence tracking without touching `currentTranscription`,
    /// so a mid-capture restart (e.g. `restartLiveCaptureAfterRouteChange`) recalibrates against the new
    /// input device instead of reusing a floor calibrated for the previous one.
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    func resetSilenceDetectionState() {
        silenceDetectionLock.lock()
        defer { silenceDetectionLock.unlock() }
        silenceStart = nil
        hasSpokeOnce = false
        noiseFloor = nil
        noiseFloorCalibrationSamples = []
        captureStartTime = Date()
    }

    private func cancelRecognitionTaskAndClearRequest() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func configureAudioSessionForCapture() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setMode(.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
    }

    private func prepareAudioEngineForNewInputTap() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // Remove tap on the old instance before discarding it — must happen before we drop our only reference.
        removeInputTapIfNeeded()
        // Fresh instance so the input node re-negotiates hardware format against whatever route is active now,
        // instead of potentially reusing a format cached from before a route change (e.g. Bluetooth mic).
        audioEngine = AVAudioEngine()
    }

    private func removeInputTapIfNeeded() {
        guard hasInputTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInputTapInstalled = false
    }

    private func makeStreamingRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        request.shouldReportPartialResults = true
        return request
    }

    private func recognitionTaskResultHandler(sessionToken: UUID) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak self] result, error in
            guard let self = self else { return }
            guard self.recognitionSessionToken == sessionToken else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.currentTranscription = text
                self.responseProcessor?(text)
            }

            guard let error = error else { return }
            let nsError = error as NSError
            let isCanceled = (nsError.domain == "kLSRErrorDomain" && nsError.code == 301)
                || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
            if isCanceled { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.recognitionSessionToken == sessionToken else { return }
                self.abortStreamingCapture(shouldStopEngineFirst: true)
            }
        }
    }

    /// Installs the tap with `format: nil` so it tracks the live input bus (required when the route/sample rate changes, e.g. Bluetooth).
    private func startRecognitionPipeline(recognizer: SFSpeechRecognizer) throws {
        recognitionSessionToken = UUID()
        let sessionToken = recognitionSessionToken

        let inputNode = audioEngine.inputNode
        let request = makeStreamingRecognitionRequest()
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request, resultHandler: recognitionTaskResultHandler(sessionToken: sessionToken))

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            request.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        hasInputTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleAudioRouteChange(notification: Notification) {
        guard isCapturing, !isRestartingCaptureForRouteChange else { return }
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // Only react when the set of audio devices actually changes. `categoryChange`, `override`, and
        // `routeConfigurationChange` often fire when *we* activate the session or start the engine;
        // restarting there cancels the recognition task before any audio is processed (broken dictation).
        let shouldRestartForHardwareRouteChange: Bool
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            shouldRestartForHardwareRouteChange = true
        default:
            shouldRestartForHardwareRouteChange = false
        }

        guard shouldRestartForHardwareRouteChange else { return }

        Log.debug(label: LOG_TAG, "Audio route hardware change (\(reason.rawValue)); restarting speech capture for new input format.")
        restartLiveCaptureAfterRouteChange()
    }

    private func restartLiveCaptureAfterRouteChange() {
        guard isCapturing, !isRestartingCaptureForRouteChange else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            abortStreamingCapture(shouldStopEngineFirst: true)
            return
        }

        isRestartingCaptureForRouteChange = true
        defer { isRestartingCaptureForRouteChange = false }

        cancelRecognitionTaskAndClearRequest()
        prepareAudioEngineForNewInputTap()
        resetSilenceDetectionState()

        do {
            try configureAudioSessionForCapture()
            try startRecognitionPipeline(recognizer: recognizer)
        } catch {
            Log.error(label: LOG_TAG, "Failed to restart speech capture after route change: \(error)")
            cancelRecognitionTaskAndClearRequest()
            abortStreamingCapture(shouldStopEngineFirst: false)
        }
    }

    /// If `start()` failed, use `shouldStopEngineFirst: false` (do not call `stop()` before `removeTap`).
    private func abortStreamingCapture(shouldStopEngineFirst: Bool) {
        let performTeardown = { [weak self] in
            guard let self = self, self.isCapturing else { return }
            self.recognitionSessionToken = UUID()
            if shouldStopEngineFirst {
                self.audioEngine.stop()
            }
            self.removeInputTapIfNeeded()
            self.audioEngine.reset()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.isCapturing = false
        }
        if Thread.isMainThread {
            performTeardown()
        } else {
            DispatchQueue.main.async(execute: performTeardown)
        }
    }

    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let rootMeanSquare: Float?
        if let floatSamples = buffer.floatChannelData?[0] {
            rootMeanSquare = Self.rootMeanSquare(floatSamples: floatSamples, frameLength: frameLength)
        } else if let int16Samples = buffer.int16ChannelData?[0] {
            rootMeanSquare = Self.rootMeanSquare(int16Samples: int16Samples, frameLength: frameLength)
        } else if let int32Samples = buffer.int32ChannelData?[0] {
            rootMeanSquare = Self.rootMeanSquare(int32Samples: int32Samples, frameLength: frameLength)
        } else {
            rootMeanSquare = nil
        }

        guard let rms = rootMeanSquare else { return }

        // Locked for the whole section below: `calibratedNoiseFloor`/`detectSilence` read and write the same
        // noise-floor/silence-tracking state that `configureSilenceDetection`/`resetSilenceDetectionState` write
        // from the main thread — see `silenceDetectionLock`'s declaration.
        silenceDetectionLock.lock()
        defer { silenceDetectionLock.unlock() }

        guard let floor = calibratedNoiseFloor(for: rms) else {
            // Still calibrating the noise floor — no speech/silence decision or meaningful level yet.
            DispatchQueue.main.async { [weak self] in self?.audioLevelHandler?(0) }
            return
        }

        let correctedRms = gainCompensatedRMS(rms: rms, floor: floor)
        // Normalize to 0...1 range (clamp raw RMS, typical speech peaks ~0.1-0.3)
        let normalized = min(correctedRms / 0.2, 1.0)
        DispatchQueue.main.async { [weak self] in self?.audioLevelHandler?(normalized) }

        detectSilence(correctedRms: correctedRms, rawRms: rms, floor: floor)
    }

    /// Establishes an ambient noise floor over the first `noiseFloorCalibrationDuration` of each capture by
    /// averaging RMS samples, then returns that floor (and keeps it slowly adapting — see `detectSilence`).
    /// Returns `nil` while still calibrating.
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    func calibratedNoiseFloor(for rms: Float) -> Float? {
        if let floor = noiseFloor {
            return floor
        }
        guard let start = captureStartTime, Date().timeIntervalSince(start) >= Self.noiseFloorCalibrationDuration else {
            noiseFloorCalibrationSamples.append(rms)
            return nil
        }
        let samples = noiseFloorCalibrationSamples
        let floor = samples.isEmpty ? rms : samples.reduce(0, +) / Float(samples.count)
        noiseFloor = floor
        noiseFloorCalibrationSamples = []
        return floor
    }

    /// Software auto-gain-control: `.measurement` audio-session mode (see `configureAudioSessionForCapture`)
    /// disables the session's own AGC, so raw mic RMS on real devices can be far quieter than the AGC'd levels
    /// `silenceThreshold` and the waveform's `/0.2` normalization assume — see the "voice to text is endless"
    /// investigation. Rescaling by the calibrated floor's ratio to `targetFloorReferenceRMS` restores those
    /// original absolute-RMS assumptions without changing `silenceThreshold`'s public meaning or default.
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    func gainCompensatedRMS(rms: Float, floor: Float) -> Float {
        let gain = Self.targetFloorReferenceRMS / max(floor, Self.minimumNoiseFloorRMS)
        return rms * gain
    }

    /// Silence detection against the gain-compensated RMS. A sample counts as speech once it exceeds
    /// `silenceThreshold`; the underlying noise floor keeps drifting slowly before speech is first detected so
    /// it tracks a slowly-changing environment (e.g. HVAC turning on) before the user starts talking.
    /// Internal rather than private: unit-tested directly in `SpeechCapturerTests`.
    func detectSilence(correctedRms: Float, rawRms: Float, floor: Float) {
        let now = Date()

        if correctedRms > silenceThreshold {
            hasSpokeOnce = true
            silenceStart = nil
            return
        }

        // Only let the floor drift before speech has ever been detected this session — it tracks slow ambient
        // change (e.g. background noise before the user starts talking), not moment-to-moment dips between
        // words/breaths in ongoing speech. Adapting during active speech would otherwise walk the threshold up
        // until it swallows the user's own voice, cutting them off mid-sentence.
        if !hasSpokeOnce {
            noiseFloor = floor * (1 - Self.noiseFloorAdaptationRate) + rawRms * Self.noiseFloorAdaptationRate
        }

        guard hasSpokeOnce else { return }
        if silenceStart == nil {
            silenceStart = now
        } else if let start = silenceStart, now.timeIntervalSince(start) >= silenceDuration {
            silenceStart = nil
            hasSpokeOnce = false
            Log.debug(label: LOG_TAG, "Silence threshold reached (correctedRms=\(correctedRms), threshold=\(silenceThreshold), duration=\(silenceDuration)). Firing silenceHandler.")
            DispatchQueue.main.async { [weak self] in self?.silenceHandler?() }
        }
    }

    private static func rootMeanSquare(floatSamples: UnsafePointer<Float>, frameLength: Int) -> Float {
        var sum: Float = 0
        for sampleIndex in 0..<frameLength {
            let sample = floatSamples[sampleIndex]
            sum += sample * sample
        }
        return sqrtf(sum / Float(frameLength))
    }

    private static func rootMeanSquare(int16Samples: UnsafePointer<Int16>, frameLength: Int) -> Float {
        let int16Scale = 1.0 / Float(Int16.max)
        var sum: Float = 0
        for sampleIndex in 0..<frameLength {
            let sample = Float(int16Samples[sampleIndex]) * int16Scale
            sum += sample * sample
        }
        return sqrtf(sum / Float(frameLength))
    }

    private static func rootMeanSquare(int32Samples: UnsafePointer<Int32>, frameLength: Int) -> Float {
        let int32Scale = 1.0 / Float(Int32.max)
        var sum: Float = 0
        for sampleIndex in 0..<frameLength {
            let sample = Float(int32Samples[sampleIndex]) * int32Scale
            sum += sample * sample
        }
        return sqrtf(sum / Float(frameLength))
    }

    func requestSpeechAndMicrophonePermissions(completion: @escaping () -> Void) {
        // Use a dispatch group to wait for both permission requests to complete
        let permissionGroup = DispatchGroup()

        permissionGroup.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !allowed {
                    Log.debug(label: self.LOG_TAG, "User has denied use of the Microphone.")
                }
                permissionGroup.leave()
            }
        }

        permissionGroup.enter()
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if authStatus != .authorized {
                    Log.debug(label: self.LOG_TAG, "User has declined the request for speech recognition.")
                }
                permissionGroup.leave()
            }
        }

        // Notify when both permissions have been responded to
        permissionGroup.notify(queue: .main) {
            completion()
        }
    }

    private var permissionGrantedForAudio: Bool {
        if #unavailable(iOS 17.0) {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        } else {
            return AVAudioApplication.shared.recordPermission == .granted
        }
    }

    private var permissionGrantedForSpeech: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
}
