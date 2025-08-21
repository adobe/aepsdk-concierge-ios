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
    var inputText: String { inputReducer.data.text }
    var inputState: InputState { inputReducer.state }
    @Published var chatState: ChatState = .idle

    private let LOG_TAG = "ConciergeChatViewModel"

    // MARK: Dependencies
    private let chatService: ConciergeChatService
    private let speechCapturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    // MARK: Input reducer
    let inputReducer = InputReducer()

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
        && inputReducer.state != .recording
        && inputReducer.state != .transcribing
    }
    var micEnabled: Bool {
        chatState == .idle
    }
    var sendEnabled: Bool {
        chatState == .idle && inputReducer.data.canSend
    }

    // MARK: - Mic control
    func toggleMic(currentSelectionLocation: Int) {
        if isRecording { completeMic() }
        else { startRecording(currentSelectionLocation: currentSelectionLocation) }
    }

    func cancelMic() {
        guard isRecording else {
            Log.warning(label: self.LOG_TAG, "cancelMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputReducer.apply(.cancelRecording)
        speechCapturer?.endCapture { _, _ in }
    }

    func completeMic() {
        guard isRecording else {
            Log.warning(label: self.LOG_TAG, "completeMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputReducer.apply(.recordingComplete)
        speechCapturer?.endCapture { [weak self] transcript, _ in
            Task { @MainActor in
                if let t = transcript, !t.isEmpty {
                    self?.inputReducer.apply(.transcriptionComplete(t))
                } else {
                    self?.inputReducer.apply(.transcriptionError("empty transcript"))
                }
            }
        }
    }

    func startRecording(currentSelectionLocation: Int) {
        guard chatState == .idle else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }
        guard inputState == .empty || inputState == .editing || {
            if case .error = inputState { return true } else { return false }
        }() else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected inputState to be 'empty' or 'editing', but was '\(inputState)'.")
            return
        }
        guard let capturer = speechCapturer, capturer.isAvailable() else {
            Log.warning(label: self.LOG_TAG, "startRecording ignored. Expected speech capturer instance is nil.")
            // Optional: surface an error state instead
            // inputState = .error(.permissionDenied)
            return
        }
        inputReducer.apply(.startMic(currentSelectionLocation: currentSelectionLocation))
        capturer.beginCapture()
    }

    // stopRecording behavior moved into cancel/complete + reducer

    // finishTranscription handled by reducer via transcriptionComplete/error

    // MARK: - Sending
    func sendMessage(isUser: Bool) {
        chatService.setServerEventHandler(handle(response:error:))
        
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            Log.warning(label: self.LOG_TAG, "sendMessage ignored. Expected non-empty text, but was empty.")
            return
        }
        guard chatState == .idle else {
            Log.warning(label: self.LOG_TAG, "sendMessage ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }

        if isRecording { completeMic() }

        // Clear input via reducer to keep state machine consistent
        inputReducer.apply(.sendMessage)

        messages.append(Message(template: .basic(isUserMessage: isUser), messageBody: text))

        if isUser {
            chatState = .processing
            
            // Add a placeholder message that will be updated with streaming content
            let streamingMessageIndex = messages.count
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: ""))
            
            var accumulatedContent = ""
            
            chatService.streamChat(text,
                onChunk: { [weak self] chunk in
                    Task { @MainActor in
                        accumulatedContent += chunk
                        // Update the streaming message with accumulated content
                        if streamingMessageIndex < self?.messages.count ?? 0 {
                            self?.messages[streamingMessageIndex] = Message(
                                template: .basic(isUserMessage: false),
                                messageBody: accumulatedContent
                            )
                        }
                    }
                },
                onComplete: { [weak self] error in
                    Task { @MainActor in
                        if let error = error {
                            Log.error(label: self?.LOG_TAG ?? "ConciergeChatViewModel", "Streaming error: \(error)")
                            self?.chatState = .error(.networkFailure)
                            
                            // Remove the placeholder message on error
                            if streamingMessageIndex < self?.messages.count ?? 0 {
                                self?.messages.remove(at: streamingMessageIndex)
                            }
                        } else {
                            // Stream completed successfully
                            self?.chatState = .idle
                            
                            // Optionally speak the completed message
                            if var finalMessage = self?.messages[safe: streamingMessageIndex] {
                                finalMessage.shouldSpeakMessage = true
                            }
                        }
                    }
                }
            )
        } else {
            // Non-user messages don't mutate input state here; reducer already cleared input
            chatState = .idle
        }
    }

    private func handle(response: ConciergeResponse?, error: ConciergeError?) {
        if let error = error {
            Log.warning(label: LOG_TAG, "An error occurred while retrieving data from the ConciergeChatService: \(error)")
            return
        }

        Task { @MainActor in
            messages.append(Message(template: .basic(isUserMessage: false), shouldSpeakMessage: true, messageBody: response?.message))
            chatState = .idle
        }        
    }

    // MARK: - Speech streaming
    private func configureSpeech() {
        speechCapturer?.initialize(responseProcessor: { [weak self] text in
            Task { @MainActor in
                self?.inputReducer.apply(.streamingPartial(text))
            }
        })
    }

    // MARK: - Text changes routing to reducer
    func applyTextChange(_ newText: String) {
        let wasEmpty = inputReducer.data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isEmptyNew = newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmptyNew && !wasEmpty {
            inputReducer.apply(.deleteContent)
        } else if !isEmptyNew && wasEmpty {
            inputReducer.apply(.addContent)
        }
        inputReducer.apply(.inputReceived(newText))
    }

    // MARK: - Combine
    // No additional subscriptions; views may observe reducer directly
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


