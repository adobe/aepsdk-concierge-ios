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

    private let LOG_TAG = "SpeechCapturer"
    private var isCapturing: Bool = false

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var currentTranscription = ""

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
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
        // Prevent double-starts
        if isCapturing {
            Log.warning(label: self.LOG_TAG, "beginCapture ignored. Capturing is already in progress.")
            return
        }
        isCapturing = true
        currentTranscription = ""
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
            Log.error(label: self.LOG_TAG, "Failed to set up audio session: \(error)")
            isCapturing = false
            return
        }

        // Ensure a clean slate on the input node
        let inputNode = audioEngine.inputNode
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        inputNode.removeTap(onBus: 0)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if #available(iOS 16, *) {
            recognitionRequest?.addsPunctuation = true
        }

        guard let recognitionRequest = recognitionRequest else {
            Log.error(label: self.LOG_TAG, "Unable to create recognition request")
            isCapturing = false
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                self.currentTranscription = text
                self.responseProcessor?(text)
            }

            if error != nil {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isCapturing = false
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            Log.error(label: self.LOG_TAG, "Failed to start audio engine: \(error)")
            isCapturing = false
        }
    }

    func endCapture(completion: @escaping (String?, (any Error)?) -> Void) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        isCapturing = false
        completion(currentTranscription, nil)
    }

    // MARK: - private methods
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
