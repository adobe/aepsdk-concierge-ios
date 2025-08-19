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
import Combine

final class ConciergeChatViewModel: ObservableObject {
    // MARK: - Published UI state
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var inputState: InputState = .empty
    @Published var chatState: ChatState = .idle

    // MARK: - Dependencies
    private let chatService: ConciergeChatService
    private let speechCapturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    // MARK: - Recording bookkeeping
    private var inputTextAtRecordingStart: String = ""
    private var recordingInsertStart: Int = 0
    private var ignoreEndCaptureTranscription: Bool = false

    init(chatService: ConciergeChatService, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.chatService = chatService
        self.speechCapturer = speechCapturer
        self.speaker = speaker
        configureSpeech()
    }

    // MARK: - Derived convenience
    var isRecording: Bool { inputState == .recording }
    var isProcessing: Bool { chatState == .processing }
    var composerEditable: Bool { chatState != .processing && inputState != .recording && inputState != .transcribing }
    var micEnabled: Bool { chatState == .idle }
    var sendEnabled: Bool { chatState == .idle && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Mic control
    func toggleMic(currentSelectionLocation: Int) {
        if isRecording { stopRecording() } else { startRecording(currentSelectionLocation: currentSelectionLocation) }
    }

    func cancelMic() { guard isRecording else { return }; ignoreEndCaptureTranscription = true; stopRecording() }
    func completeMic() { guard isRecording else { return }; stopRecording() }

    private func startRecording(currentSelectionLocation: Int) {
        inputTextAtRecordingStart = inputText
        recordingInsertStart = max(0, min(currentSelectionLocation, (inputText as NSString).length))
        speechCapturer?.beginCapture()
        inputState = .recording
    }

    private func stopRecording() {
        chatState = .processing
        speechCapturer?.endCapture { [weak self] transcription, _ in
            guard let self = self else { return }
            self.finishTranscription(transcription)
        }
    }

    private func finishTranscription(_ final: String?) {
        if !ignoreEndCaptureTranscription, let t = final, !t.isEmpty {
            let base = inputTextAtRecordingStart as NSString
            let start = max(0, min(recordingInsertStart, base.length))
            inputText = base.substring(to: start) + t + base.substring(from: start)
        }
        ignoreEndCaptureTranscription = false
        inputTextAtRecordingStart = inputText
        recordingInsertStart = (inputText as NSString).length
        inputState = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
        chatState = .idle
    }

    // MARK: - Sending
    func sendMessage(isUser: Bool) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isRecording { ignoreEndCaptureTranscription = true; stopRecording() }

        messages.append(Message(template: .basic(isUserMessage: isUser), messageBody: text))
        inputText = ""

        if isUser {
            chatState = .processing
            chatService.processChat(text) { [weak self] response, error in
                DispatchQueue.main.async {
                    if let _ = error { self?.chatState = .error(.networkFailure); return }
                    guard let response = response else { self?.chatState = .error(.modelError); return }
                    self?.handle(response: response)
                }
            }
        } else {
            inputState = .editing
            chatState = .idle
        }
    }

    private func handle(response: ConciergeResponse) {
        guard let message = response.interaction.response.first?.message else { chatState = .error(.modelError); return }
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
        speechCapturer?.initialize(responseProcessor: { [weak self] text in self?.processStreaming(text: text) })
    }

    private func processStreaming(text: String) {
        DispatchQueue.main.async {
            guard self.inputState == .recording else { return }
            let base = self.inputTextAtRecordingStart as NSString
            let start = max(0, min(self.recordingInsertStart, base.length))
            self.inputText = base.substring(to: start) + text + base.substring(from: start)
        }
    }
}


