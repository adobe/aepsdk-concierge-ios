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

import Foundation

import AEPServices

@MainActor
final class ConciergeChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var inputState: InputState = .empty
    @Published var chatState: ChatState = .idle

    private let LOG_TAG = "ConciergeChatViewModel"

    // MARK: Dependencies
    private let chatService: ConciergeChatService
    private let speechCapturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    // MARK: Recording helpers
    private var inputTextAtRecordingStart: String = ""
    private var recordingInsertStart: Int = 0

    init(chatService: ConciergeChatService, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.chatService = chatService
        self.speechCapturer = speechCapturer
        self.speaker = speaker
        configureSpeech()
    }

    // MARK: - Convenience properties
    var isRecording: Bool {
        inputState == .recording
    }
    var isProcessing: Bool {
        chatState == .processing
    }
    var composerEditable: Bool {
        chatState != .processing
        && inputState != .recording
        && inputState != .transcribing
    }
    var micEnabled: Bool {
        chatState == .idle
    }
    var sendEnabled: Bool {
        chatState == .idle
        && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Mic control
    func toggleMic(currentSelectionLocation: Int) {
        if isRecording {
            stopRecording(acceptTranscription: true)
        } else {
            startRecording(currentSelectionLocation: currentSelectionLocation)
        }
    }

    func cancelMic() {
        guard isRecording else {
            Log.warning(label: self.LOG_TAG, "cancelMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        stopRecording(acceptTranscription: false)
    }

    func completeMic() {
        guard isRecording else {
            Log.warning(label: self.LOG_TAG, "completeMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        stopRecording(acceptTranscription: true)
    }

    func startRecording(currentSelectionLocation: Int) {
        guard chatState == .idle else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }
        guard inputState == .empty || inputState == .editing else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected inputState to be 'empty' or 'editing', but was '\(inputState)'.")
            return
        }
        guard let capturer = speechCapturer, capturer.isAvailable() else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected speech capturer instance is nil.")
            // Optional: surface an error state instead
            // inputState = .error(.permissionDenied)
            return
        }
        inputTextAtRecordingStart = inputText
        recordingInsertStart = max(0, min(currentSelectionLocation, (inputText as NSString).length))
        // Flip to recording before kicking off capture so UI sticks even if focus callbacks fire
        inputState = .recording
        capturer.beginCapture()
    }

    func stopRecording(acceptTranscription: Bool) {
        guard isRecording else {
            Log.warning(label: self.LOG_TAG, "stopRecording ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        guard let capturer = speechCapturer else {
            Log.warning(label: self.LOG_TAG, "stopRecording ignored. Expected speech capturer instance to be present, but it was nil.")
            // We can't end capture—reset to a sane state
            inputState = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
            chatState = .idle
            return
        }
        // Update UI state depending on whether the transcription is going to be used or not
        if acceptTranscription {
            // Set the transcribing state while processing
            inputState = .transcribing
        } else {
            // Otherwise change back to editable without a transcribing phase
            inputState = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
        }
        capturer.endCapture { [weak self] transcript, _ in
            Task { @MainActor in
                self?.finishTranscription(transcript, acceptTranscription: acceptTranscription)
            }
        }
    }

    private func finishTranscription(_ transcript: String?, acceptTranscription: Bool) {
        if acceptTranscription, let transcript = transcript, !transcript.isEmpty {
            let base = inputTextAtRecordingStart as NSString
            let start = max(0, min(recordingInsertStart, base.length))
            inputText = base.substring(to: start) + transcript + base.substring(from: start)
        }
        inputTextAtRecordingStart = inputText
        recordingInsertStart = (inputText as NSString).length
        inputState = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
        chatState = .idle
    }

    // MARK: - Sending
    func sendMessage(isUser: Bool) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            Log.warning(label: self.LOG_TAG, "sendMessage ignored. Expected non-empty text, but was empty.")
            return
        }
        guard chatState == .idle else {
            Log.warning(label: self.LOG_TAG, "sendMessage ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }

        if isRecording {
            stopRecording(acceptTranscription: true)
        }

        messages.append(Message(template: .basic(isUserMessage: isUser), messageBody: text))
        inputText = ""

        if isUser {
            chatState = .processing
            chatService.processChat(text) { [weak self] response, error in
                Task { @MainActor in
                    if let _ = error {
                        self?.chatState = .error(.networkFailure)
                        return
                    }
                    guard let response = response else {
                        self?.chatState = .error(.modelError)
                        return
                    }
                    self?.handle(response: response)
                }
            }
        } else {
            inputState = .editing
            chatState = .idle
        }
    }

    private func handle(response: ConciergeResponse) {
        guard let message = response.interaction.response.first?.message else {
            chatState = .error(.modelError)
            return
        }

        messages.append(Message(template: .divider))
        messages.append(Message(template: .basic(isUserMessage: false), shouldSpeakMessage: true, messageBody: message.opening))

        if let items = message.items {
            messages.append(Message(template: .divider))
            var i = 1
            for item in items {
                messages.append(Message(template: .numbered(number: i, title: item.title, body: item.introduction)))
                i += 1
            }
        }

        if let closing = message.ending {
            messages.append(Message(template: .divider))
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: closing))
        }

        messages.append(Message(template: .divider))
        inputState = .editing
        chatState = .idle
    }

    // MARK: - Speech streaming
    private func configureSpeech() {
        speechCapturer?.initialize(responseProcessor: { [weak self] text in
            Task { @MainActor in
                self?.processStreaming(text: text)
            }
        })
    }

    private func processStreaming(text: String) {
        guard inputState == .recording else {
            Log.warning(label: self.LOG_TAG, "processStreaming ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        let base = inputTextAtRecordingStart as NSString
        let start = max(0, min(recordingInsertStart, base.length))
        inputText = base.substring(to: start) + text + base.substring(from: start)
    }
}


