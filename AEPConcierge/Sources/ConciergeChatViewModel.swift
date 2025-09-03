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
    // Incremented whenever the latest agent message is updated, to drive scroll behavior
    @Published var agentScrollTick: Int = 0
    // Incremented when a user message is appended, to drive bottom scroll
    @Published var userScrollTick: Int = 0

    private let LOG_TAG = "ConciergeChatViewModel"

    // MARK: Dependencies
    private let chatService: ConciergeChatService
    private let speechCapturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    // MARK: Input reducer
    let inputReducer = InputReducer()
    
    // MARK: Chunk handling
    var lastEmittedResponseText: String = ""
    private var latestSources: [URL] = []

    // MARK: Feature flags
    // Toggle to attach stubbed sources to agent responses for testing until backend supports it
    var stubAgentSources: Bool = true

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
        // Streaming path handles updates and completion via closures
        
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
            // Trigger scroll-to-bottom for the newly sent user message
            userScrollTick &+= 1
        }

        if isUser {
            chatState = .processing
            
            // Add a placeholder message that will be updated with streaming content
            let streamingMessageIndex = messages.count
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: ""))
            
            var accumulatedContent = ""
            
            chatService.streamChat(text,
                onChunk: { [weak self] payload in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        let state = payload.state
                        
                        // start with handling messages only
                        if let message = payload.response?.message {
                            if state == Constants.StreamState.IN_PROGRESS {
                                // Emit raw fragment and accumulate locally
                                accumulatedContent += message
                                print("chunk: \(message)")
                                print("accumulatedContent: \(accumulatedContent)")
                                // Update the streaming message with accumulated content (preserve id)
                                if streamingMessageIndex < self.messages.count {
                                    var current = self.messages[streamingMessageIndex]
                                    current.messageBody = accumulatedContent
                                    self.messages[streamingMessageIndex] = current
                                }
                                self.lastEmittedResponseText += message
                                // Notify views to adjust scroll for agent updates
                                self.agentScrollTick &+= 1
                            } else if state == Constants.StreamState.COMPLETED {
                                // Emit only the remainder beyond what we already streamed
                                let fullText = message
                                if self.lastEmittedResponseText.count < fullText.count {
                                    let startIndex = fullText.index(fullText.startIndex, offsetBy: self.lastEmittedResponseText.count)
                                    let delta = String(fullText[startIndex...])
                                    if !delta.isEmpty {
                                        accumulatedContent += delta
                                        print("chunk: \(delta)")
                                        print("accumulatedContent: \(delta)")
                                        // Update the streaming message with accumulated content (preserve id)
                                        if streamingMessageIndex < self.messages.count {
                                            var current = self.messages[streamingMessageIndex]
                                            current.messageBody = accumulatedContent
                                            self.messages[streamingMessageIndex] = current
                                        }
                                    }
                                }
                                self.lastEmittedResponseText = fullText
                                // Final agent update tick
                                self.agentScrollTick &+= 1
                            }
                        }
                        
                        // handle cards in multimodalElements
                        if let elements = payload.response?.multimodalElements?.elements, !elements.isEmpty {
                            var carouselElements: [Message] = []
                            for element in elements {
                                // make a card
                                let cardTitle = element.entityInfo?.productName ?? "No title"
                                let cardText = element.entityInfo?.productDescription ?? "No description"
                                let cardImage = element.entityInfo?.productImageURL ?? "No image"
                                let cardImageUrl = URL(string: cardImage)!
                                let primaryButton = element.entityInfo?.primary
                                let secondaryButton = element.entityInfo?.secondary
                                                                
                                let card = Message(template: .productCard(imageSource: .remote(cardImageUrl),
                                                                       title: cardTitle,
                                                                       body: cardText,
                                                                       primaryButton: primaryButton,
                                                                       secondaryButton: secondaryButton))
                                
                                carouselElements.append(card)
                            }
                            
                            self.messages.append(Message(template: .carouselGroup(carouselElements)))
                        }

                        // Capture sources from payload as they arrive (used on completion)
                        if let tempSources = payload.response?.sources {
                            let urls = tempSources.compactMap { source -> URL? in
                                guard let url = URL(string: source.url) else {
                                    Log.trace(label: self.LOG_TAG, "Ignoring invalid source URL: \(source.url)")
                                    return nil
                                }
                                return url
                            }
                            if !urls.isEmpty {
                                self.latestSources = urls
                            }
                        }
                    }
                },
                onComplete: { [weak self] error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        if let error = error {
                            Log.error(label: self.LOG_TAG, "Streaming error: \(error)")
                            self.chatState = .error(.networkFailure)
                            
                            // Remove the placeholder message on error
                            if streamingMessageIndex < self.messages.count {
                                self.messages.remove(at: streamingMessageIndex)
                            }
                        } else {
                            // Stream completed successfully
                            self.chatState = .idle
                            
                            // Mark the existing streaming message for speaking while preserving its id
                            if streamingMessageIndex < self.messages.count {
                                var current = self.messages[streamingMessageIndex]
                                current.messageBody = accumulatedContent
                                current.shouldSpeakMessage = true
                                // Attach real sources captured during streaming if present
                                if !self.latestSources.isEmpty {
                                    Log.trace(label: self.LOG_TAG, "Using real sources: \(self.latestSources)")
                                    current.sources = self.latestSources
                                } else if self.stubAgentSources {
                                    Log.trace(label: self.LOG_TAG, "Using stubbed sources")
                                    current.sources = [
                                        URL(string: "https://example.com/guide/introduction")!,
                                        URL(string: "https://example.com/docs/reference#section")!
                                    ]
                                }
                                self.messages[streamingMessageIndex] = current
                                // Final tick to keep scroll pinned after completion
                                self.agentScrollTick &+= 1
                            }
                        }
                        
                        self.lastEmittedResponseText = ""
                        self.latestSources = []
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
            var agent = Message(template: .basic(isUserMessage: false), shouldSpeakMessage: true, messageBody: response?.message)
            // TODO: Update this logic to reflect real backend response when available
            if stubAgentSources {
                agent.sources = [
                    URL(string: "https://example.com/guide/introduction")!,
                    URL(string: "https://example.com/docs/reference#section")!
                ]
            }
            messages.append(agent)
            chatState = .idle
            agentScrollTick &+= 1
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
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


