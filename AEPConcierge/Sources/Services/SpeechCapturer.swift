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
    var levelUpdateHandler: (([Float]) -> Void)?
    
    // MARK: - private members
    private let LOG_TAG = "SpeechCapturer"
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var currentTranscription = ""
    private var bandEMA: [Float] = Array(repeating: 0, count: 5) // smoothed 5 bands
    private var bandNoise: [Float] = Array(repeating: 0.001, count: 5) // adaptive noise floor per band
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    }
    
    func initialize(responseProcessor: ((String) -> Void)?) {
        self.responseProcessor = responseProcessor
        requestSpeechAndMicrophonePermissions()
    }
    
    // MARK: - internal methods
    
    func isAvailable() -> Bool {
        permissionGrantedForAudio && permissionGrantedForSpeech
    }
    
    func beginCapture() {
        // Cancel any existing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try audioSession.setMode(.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        bandEMA = Array(repeating: 0, count: 5)
        bandNoise = Array(repeating: 0.001, count: 5)
        if #available(iOS 16, *) {
            recognitionRequest?.addsPunctuation = true
        }
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.responseProcessor?(result.bestTranscription.formattedString)
            }
            
            if error != nil {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // Smaller buffer for snappier level updates
        inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
            // Compute a simple 5-band spectrum (very lightweight DFT buckets)
            if let channelData = buffer.floatChannelData?[0] {
                let count = Int(buffer.frameLength)
                if count > 0 {
                    // Precompute equally spaced frequency bins by sampling every Nth sample
                    // This is a rough/cheap spectrum visualization, not an FFT.
                    var bands = [Float](repeating: 0, count: 5)
                    let step = max(1, count / 64)
                    var idx = 0
                    while idx < count {
                        let v = channelData[idx]
                        let a = fabsf(v)
                        // Map sample index to pseudo-frequency bucket
                        let bucket = min(4, (idx * 5) / max(1, count))
                        if a > bands[bucket] { bands[bucket] = a }
                        idx += step
                    }
                    // Normalize, floor and gain
                    for i in 0..<5 {
                        // Slowly adapt noise floor upward; prevents baseline activation
                        self.bandNoise[i] = max(0.0005, self.bandNoise[i] * 0.995 + bands[i] * 0.005)
                        let adjusted = max(0, bands[i] - self.bandNoise[i] * 1.7)
                        // Lower gain to prevent easy saturation at conversational volume
                        let amplified: Float = adjusted * 10.0
                        // Log compression for wide dynamic range without pegging
                        let logNumerator = log(1 + Double(6.0 * amplified))
                        let logDenominator = log(1 + 6.0)
                        var comp = Float(logNumerator / logDenominator) // 0...1
                        // Per-band adaptive EMA (fast attack, fast release)
                        if comp > self.bandEMA[i] { self.bandEMA[i] = self.bandEMA[i] * 0.3 + comp * 0.7 }
                        else { self.bandEMA[i] = self.bandEMA[i] * 0.6 + comp * 0.4 }
                        // Gate very low residuals to zero; soft-cap peaks lower
                        if self.bandEMA[i] < 0.03 { self.bandEMA[i] = 0 }
                        if self.bandEMA[i] > 0.85 { self.bandEMA[i] = 0.85 }
                    }
                    let levels = self.bandEMA
                    DispatchQueue.main.async { [weak self] in self?.levelUpdateHandler?(levels) }
                }
            }
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func endCapture(completion: @escaping (String?, (any Error)?) -> Void) {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        bandEMA = Array(repeating: 0, count: 5)
        bandNoise = Array(repeating: 0.001, count: 5)
        
        completion(currentTranscription, nil)
    }
    
    // MARK: - private methods
    private func requestSpeechAndMicrophonePermissions() {        
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !allowed {
                    Log.debug(label: self.LOG_TAG, "User has denied use of the Microphone.")
                }
            }
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if authStatus != .authorized {
                    Log.debug(label: self.LOG_TAG, "User has declined the request for speech recognition.")
                }
            }
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
