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
    private let audioEngine = AVAudioEngine()
    private var currentTranscription = ""
    private var hasInputTapInstalled = false

    /// Silence detection
    private var silenceThreshold: Float = 0.02
    private var silenceDuration: TimeInterval = 2.0
    private var silenceStart: Date?
    private var hasSpokeOnce = false

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
        silenceStart = nil
        hasSpokeOnce = false
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
        // Remove tap before `reset()` — `reset()` can clear taps; `removeTap` after that is unsafe.
        removeInputTapIfNeeded()
        audioEngine.reset()
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
        // Normalize to 0...1 range (clamp raw RMS, typical speech peaks ~0.1-0.3)
        let normalized = min(rms / 0.2, 1.0)

        DispatchQueue.main.async { [weak self] in self?.audioLevelHandler?(normalized) }

        // Silence detection — auto-stop after `silenceDuration` of silence once speech has been detected
        if rms > silenceThreshold {
            hasSpokeOnce = true
            silenceStart = nil
        } else if hasSpokeOnce {
            if silenceStart == nil {
                silenceStart = Date()
            } else if let start = silenceStart, Date().timeIntervalSince(start) >= silenceDuration {
                silenceStart = nil
                hasSpokeOnce = false
                DispatchQueue.main.async { [weak self] in self?.silenceHandler?() }
            }
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
