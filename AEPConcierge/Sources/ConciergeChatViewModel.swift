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
    // ID of the user message to scroll to when userScrollTick changes
    @Published var userMessageToScrollId: UUID? = nil

    private let LOG_TAG = "ConciergeChatViewModel"

    // MARK: Dependencies
    private let chatService: ConciergeChatService
    private let configuration: ConciergeConfiguration?
    private let speechCapturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    // MARK: Input reducer
    let inputReducer = InputReducer()
    
    // MARK: Chunk handling
    private var latestSources: [TempSource] = []
    private var productCardIndex: Int? = nil
    private var latestPromptSuggestions: [String] = []

    // MARK: Feature flags
    // Toggle to attach stubbed sources to agent responses for testing until backend supports it
    var stubAgentSources: Bool = true

    init(configuration: ConciergeConfiguration, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.configuration = configuration
        self.chatService = ConciergeChatService(configuration: configuration)
        self.speechCapturer = speechCapturer
        self.speaker = speaker
        
        configureSpeech()
    }
    
    #if DEBUG
    // INTERAL FOR TESTING ONLY
    init(configuration: ConciergeConfiguration?, chatService: ConciergeChatService, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.configuration = configuration
        self.chatService = chatService
        self.speechCapturer = speechCapturer
        self.speaker = speaker
        
        configureSpeech()
    }
    #endif

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

        let newMessage = Message(template: .basic(isUserMessage: isUser), messageBody: text)
        messages.append(newMessage)
        if isUser {
            // Store the user message ID first
            userMessageToScrollId = newMessage.id
            // Defer tick increment to ensure ID is published first
            DispatchQueue.main.async {
                self.userScrollTick &+= 1
            }
        }

        if isUser {
            chatState = .processing
            
            // Add a placeholder message that will be updated with streaming content
            let streamingMessageIndex = messages.count
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: ""))
            
            var accumulatedContent = ""
            // TODO: TempElement will be replaced with permanent model
            var accumulatedProducts: [TempElement] = []
            
            chatService.streamChat(text,
                onChunk: { [weak self] payload in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        let state = payload.state
                        
                        // start with handling messages only
                        if let message = payload.response?.message {
                            if state == Constants.StreamState.IN_PROGRESS {
                                // Build up content with each chunk
                                accumulatedContent += message
                                print("chunk: \(message)")
                                print("accumulatedContent: \(accumulatedContent)")
                                
                                // Update the streaming message with accumulated content (preserve id)
                                if streamingMessageIndex < self.messages.count {
                                    var current = self.messages[streamingMessageIndex]
                                    current.messageBody = accumulatedContent
                                    self.messages[streamingMessageIndex] = current
                                }
                                
                                // Notify views to adjust scroll for agent updates
                                self.agentScrollTick &+= 1
                            } else if state == Constants.StreamState.COMPLETED {
                                // On completion, do a full replace with the entire text response
                                let fullText = message
                                print("completion - full text: \(fullText)")
                                
                                // Replace with complete text response
                                if streamingMessageIndex < self.messages.count {
                                    var current = self.messages[streamingMessageIndex]
                                    current.messageBody = fullText
                                    self.messages[streamingMessageIndex] = current
                                }
                                
                                // Update accumulated content to match final text
                                accumulatedContent = fullText
                                // Final agent update tick
                                self.agentScrollTick &+= 1
                            }
                        }
                        
                        // handle cards in multimodalElements
                        if let elements = payload.response?.multimodalElements?.elements, !elements.isEmpty {
                            // consolidate elements - priority given to elements over accumulatedProducts when IDs conflict
                            // Remove any existing elements that have matching IDs in the new elements
                            let newElementIds = Set(elements.map { $0.id })
                            accumulatedProducts.removeAll { existingElement in
                                newElementIds.contains(existingElement.id)
                            }
                            
                            // Add all new elements (they now have priority over any previous versions)
                            accumulatedProducts.append(contentsOf: elements)
                            
                            // set the index of the product card to the last in the list
                            // so we can update it in the future when necessary
                            if self.productCardIndex == nil {
                                self.productCardIndex = streamingMessageIndex + 1
                            }
                            
                            self.renderProductCards(accumulatedProducts)
                        }

                        // capture prompt suggestions if present
                        if let suggestions = payload.response?.promptSuggestions, !suggestions.isEmpty {
                            self.latestPromptSuggestions = suggestions
                        }

                        // Capture sources from payload as they arrive (used on completion)
                        if let tempSources = payload.response?.sources {
                            self.latestSources = tempSources
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
                        } else if accumulatedContent.isEmpty {
                            // Remove the placeholder message
                            if streamingMessageIndex < self.messages.count {
                                self.messages.remove(at: streamingMessageIndex)
                            }
                            
                            self.messages.append(Message(template: .basic(isUserMessage: false), messageBody: "Sorry, I wasn't able to get a response from the Concierge Service. \n\nPlease try again later."))
                            
                            self.clearState()
                        }
                        else {
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
                                        TempSource(url: "https://example.com/guide/introduction", title: "Introduction source", startIndex: 1, endIndex: 2, citationNumber: 1),
                                        TempSource(url: "https://example.com/docs/reference#section", title: "Reference section in docs", startIndex: 1, endIndex: 2, citationNumber: 2)
                                    ]
                                }
                                self.messages[streamingMessageIndex] = current
                                // Final tick to keep scroll pinned after completion
                                self.agentScrollTick &+= 1
                            }
                            // Append prompt suggestions as their own message bubbles at the end
                            if !self.latestPromptSuggestions.isEmpty {
                                for suggestion in self.latestPromptSuggestions {
                                    self.messages.append(Message(template: .promptSuggestion(text: suggestion)))
                                }
                                // Keep scroll pinned to bottom when suggestions are appended
                                self.agentScrollTick &+= 1
                            }
                            
                            // Stream completed successfully
                            self.clearState()
                        }
                    }
                }
            )
        } else {
            // Agent messages don't change input state here; reducer already cleared input
            self.clearState()
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
                    TempSource(url: "https://example.com/guide/introduction", title: "Introduction source", startIndex: 1, endIndex: 2, citationNumber: 1),
                    TempSource(url: "https://example.com/docs/reference#section", title: "Reference section in docs", startIndex: 1, endIndex: 2, citationNumber: 2)
                ]
            }
            messages.append(agent)
            self.clearState()
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
    
    private func clearState() {
        chatState = .idle
        productCardIndex = nil
        latestSources = []
        latestPromptSuggestions = []
    }
    
    /// this must be called from the main thread
    private func renderProductCards(_ products: [TempElement]) {
        if products.count == 1, let entityInfo = products.first?.entityInfo {
            // show a single product card
            let cardTitle = entityInfo.productName ?? "No title"
            let cardText = entityInfo.productDescription ?? "No description"
            let cardImageUrl = entityInfo.productImageURL.flatMap { URL(string: $0) }
            let primaryButton = entityInfo.primary
            let secondaryButton = entityInfo.secondary
                                            
            let card = Message(template: .productCard(imageSource: .remote(cardImageUrl),
                                                   title: cardTitle,
                                                   body: cardText,
                                                   primaryButton: primaryButton,
                                                   secondaryButton: secondaryButton))
            
            // don't duplicate the product card
            removeProductCard(atIndex: self.productCardIndex)
            self.messages.append(card)
        } else {
            // show a carousel of cards
            var carouselElements: [Message] = []
            for product in products {
                guard let entityInfo = product.entityInfo else {
                    continue
                }
            let cardTitle = entityInfo.productName ?? "No title"
            let cardImageUrl = entityInfo.productImageURL.flatMap { URL(string: $0) }
            let cardClickThroughURL = entityInfo.productPageURL.flatMap { URL(string: $0) }
                                                
                let card = Message(template: .productCarouselCard(imageSource: .remote(cardImageUrl),
                                                                  title: cardTitle,
                                                                  destination: cardClickThroughURL))
                
                carouselElements.append(card)
            }
            
            // don't duplicate the product card
            removeProductCard(atIndex: self.productCardIndex)
            self.messages.append(Message(template: .carouselGroup(carouselElements)))
        }
    }
    
    /// removes the product card if the following conditions are met:
    /// 1. a valid index was provided
    /// 2. the index is less than the number of existing messages (prevents out of range errors)
    private func removeProductCard(atIndex index: Int?) {
        if let index = index, index < self.messages.count {
            self.messages.remove(at: index)
        }
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


