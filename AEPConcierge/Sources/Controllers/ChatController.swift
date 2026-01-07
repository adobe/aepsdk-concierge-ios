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
import AEPCore
import AEPServices

/// Main controller orchestrating chat functionality.
/// Manages messages, chat state, and coordinates between services.
@MainActor
final class ChatController: ObservableObject {
    // MARK: - Published State
    
    @Published var messages: [Message] = []
    @Published var chatState: ChatState = .idle
    @Published var userScrollTick: Int = 0
    @Published var userMessageToScrollId: UUID? = nil
    @Published var showPermissionDialog: Bool = false
    
    // MARK: - Input Controller
    
    let inputController = InputController()
    
    var inputText: String { inputController.data.text }
    var inputState: InputState { inputController.state }
    
    // MARK: - Private Properties
    
    private let LOG_TAG = "ChatController"
    private let chatService: ConciergeChatService
    private let configuration: ConciergeConfiguration?
    private let speechController: SpeechController
    
    private var welcomeMessagesLoaded: Bool = false
    private var latestSources: [Source] = []
    private var productCardIndex: Int? = nil
    private var latestPromptSuggestions: [String] = []
    
    // MARK: - Computed Properties
    
    var isRecording: Bool { inputState == .recording }
    var isProcessing: Bool { chatState == .processing }
    var composerEditable: Bool { chatState != .processing }
    var micEnabled: Bool { chatState == .idle }
    var sendEnabled: Bool { chatState == .idle && inputController.data.canSend }
    
    /// Whether at least one user message exists in the transcript.
    var hasUserSentMessage: Bool {
        messages.contains { message in
            if case .basic(let isUserMessage) = message.template {
                return isUserMessage
            }
            return false
        }
    }
    
    // MARK: - Initialization
    
    init(configuration: ConciergeConfiguration, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.configuration = configuration
        self.chatService = ConciergeChatService(configuration: configuration)
        self.speechController = SpeechController(capturer: speechCapturer, speaker: speaker)
        
        configureSpeech()
    }
    
    #if DEBUG
    // Internal for testing only
    init(configuration: ConciergeConfiguration?, chatService: ConciergeChatService, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.configuration = configuration
        self.chatService = chatService
        self.speechController = SpeechController(capturer: speechCapturer, speaker: speaker)
        
        configureSpeech()
    }
    #endif
    
    // MARK: - Input Handling
    
    func applyTextChange(_ newText: String) {
        inputController.applyTextChange(newText)
    }
    
    // MARK: - Mic Control
    
    func toggleMic(currentSelectionLocation: Int) {
        if isRecording { completeMic() }
        else { startRecording(currentSelectionLocation: currentSelectionLocation) }
    }
    
    func cancelMic() {
        guard isRecording else {
            Log.warning(label: LOG_TAG, "cancelMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputController.apply(.cancelRecording)
        speechController.endCapture { _, _ in }
    }
    
    func completeMic() {
        guard isRecording else {
            Log.warning(label: LOG_TAG, "completeMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputController.apply(.recordingComplete)
        speechController.endCapture { [weak self] transcript, _ in
            Task { @MainActor in
                if let transcript = transcript, !transcript.isEmpty {
                    self?.inputController.apply(.transcriptionComplete(transcript))
                } else {
                    self?.inputController.apply(.transcriptionError("empty transcript"))
                }
            }
        }
    }
    
    func startRecording(currentSelectionLocation: Int) {
        guard chatState == .idle else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }
        guard inputState == .empty || inputState == .editing || {
            if case .error = inputState { return true } else { return false }
        }() else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Expected inputState to be 'empty' or 'editing', but was '\(inputState)'.")
            return
        }
        guard speechController.isCapturerAvailable else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Speech capturer instance is nil.")
            return
        }
        
        // Only request permissions if the user has never been asked before
        if speechController.hasNeverBeenAskedForPermission {
            Log.debug(label: LOG_TAG, "Requesting speech and microphone permissions for the first time.")
            speechController.requestPermissions { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    // After user responds to system prompts, check if permissions were granted
                    if self.speechController.isAvailable {
                        Log.debug(label: self.LOG_TAG, "Permissions granted. Starting recording.")
                        self.inputController.apply(.startMic(currentSelectionLocation: currentSelectionLocation))
                        self.speechController.beginCapture()
                    } else {
                        Log.debug(label: self.LOG_TAG, "Permissions not granted after request. Showing permission dialog.")
                        self.showPermissionDialog = true
                    }
                }
            }
            return
        }
        
        // Always check if permissions are available before proceeding
        if !speechController.isAvailable {
            // Permissions were asked but not granted - show custom dialog
            Log.debug(label: LOG_TAG, "Speech or microphone permissions not granted. Showing permission dialog.")
            showPermissionDialog = true
            return
        }
        
        // Permissions granted - proceed with recording
        inputController.apply(.startMic(currentSelectionLocation: currentSelectionLocation))
        speechController.beginCapture()
    }
    
    // MARK: - Permission Dialog
    
    func dismissPermissionDialog() {
        showPermissionDialog = false
    }
    
    func requestOpenSettings() {
        showPermissionDialog = false
    }
    
    // MARK: - Message Sending
    
    func sendMessage(isUser: Bool) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            Log.warning(label: LOG_TAG, "sendMessage ignored. Expected non-empty text, but was empty.")
            return
        }
        guard chatState == .idle else {
            Log.warning(label: LOG_TAG, "sendMessage ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }

        if isRecording { completeMic() }

        // Clear input via controller to keep state machine consistent
        inputController.apply(.sendMessage)

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
            streamAgentResponse(for: text)
        } else {
            clearState()
        }
    }
    
    // MARK: - Welcome Content
    
    /// Loads initial welcome header and examples if not already loaded.
    func loadWelcomeIfNeeded() async {
        // Prevent loading if already loaded OR if messages is not empty
        guard !welcomeMessagesLoaded && messages.isEmpty else { return }
        welcomeMessagesLoaded = true
        
        let welcome = await chatService.fetchWelcome()
        // Header
        messages.append(Message(template: .welcomeHeader(title: welcome.title, body: welcome.body)))
        // Welcome prompt suggestions
        for example in welcome.examples {
            let message = Message(
                template: .welcomePromptSuggestion(
                    imageSource: .remote(example.imageURL),
                    text: example.text,
                    background: example.background
                )
            )
            messages.append(message)
        }
    }
    
    // MARK: - Feedback
    
    func sendFeedbackFor(messageId: UUID?, with feedbackPayload: FeedbackPayload) {
        guard let messageId = messageId, let index = messages.firstIndex(where: { $0.id == messageId }) else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, the message was not retrievable from the chat.")
            return
        }
        
        guard let configuration = configuration else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, configuration is not available.")
            return
        }
        
        // Get the message information for which feedback was provided
        var currentMessage = messages[index]
        
        guard let messagePayload = currentMessage.payload else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, message payload is not available.")
            return
        }
        
        // Attach sentiment
        currentMessage.feedbackSentiment = feedbackPayload.sentiment
        
        // Write the updated message back to the array so UI updates
        messages[index] = currentMessage
                
        // Generate an edge event to track the feedback
        let feedbackEventData: [String: Any] = [
            ConciergeConstants.Request.Keys.XDM: [
                ConciergeConstants.Request.Keys.EVENT_TYPE: ConciergeConstants.Request.EventType.CONVERSATION_FEEDBACK,
                ConciergeConstants.Request.Keys.IDENTITY_MAP: [
                    ConciergeConstants.Request.Keys.ECID: [
                        [
                            ConciergeConstants.Request.Keys.ID: configuration.ecid
                        ]
                    ]
                ],
                ConciergeConstants.Request.Keys.CONVERSATION: [
                    ConciergeConstants.Request.Keys.Feedback.FEEDBACK: [
                        ConciergeConstants.Request.Keys.Feedback.SOURCE: ConciergeConstants.Request.Values.Feedback.END_USER,
                        ConciergeConstants.Request.Keys.Feedback.RAW: [
                            [
                                ConciergeConstants.Request.Keys.Feedback.TEXT: feedbackPayload.notes,
                                ConciergeConstants.Request.Keys.Feedback.PURPOSE: ConciergeConstants.Request.Values.Feedback.USER_INPUT
                            ]
                        ],
                        ConciergeConstants.Request.Keys.Feedback.RATING: [
                            ConciergeConstants.Request.Keys.Feedback.SCORE: feedbackPayload.sentiment == .positive ? 1 : 0,
                            ConciergeConstants.Request.Keys.Feedback.CLASSIFICATION: feedbackPayload.sentiment.thumbsValue(),
                            ConciergeConstants.Request.Keys.Feedback.REASONS: feedbackPayload.selectedOptions
                        ]
                    ],
                    ConciergeConstants.Request.Keys.Feedback.CONVERSATION_ID: messagePayload.conversationId ?? "unknown",
                    ConciergeConstants.Request.Keys.Feedback.TURN_ID: messagePayload.interactionId ?? "unknown"
                ]
            ]
        ]
        
        chatService.sendFeedback(data: feedbackEventData)
    }
    
    // MARK: - Private Methods
    
    private func configureSpeech() {
        speechController.configureForStreaming { [weak self] text in
            Task { @MainActor in
                self?.inputController.apply(.streamingPartial(text))
            }
        }
    }
    
    private func streamAgentResponse(for query: String) {
        let streamingMessageIndex = messages.count
        messages.append(Message(template: .basic(isUserMessage: false), messageBody: ""))
        
        var accumulatedContent = ""
        var accumulatedProducts: [MultimodalElement] = []
        
        chatService.streamChat(query,
            onChunk: { [weak self] payload in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    let state = payload.state
                    
                    if let response = payload.response {
                        Log.debug(label: self.LOG_TAG, "SSE chunk: state=\(state ?? "n/a"), textLen=\(response.message.count), sources=\(response.sources?.count ?? 0), suggestions=\(response.promptSuggestions?.count ?? 0)")
                        
                        if state == ConciergeConstants.StreamState.COMPLETED,
                            let data = try? JSONEncoder().encode(response),
                            let json = String(data: data, encoding: .utf8) {
                            Log.debug(label: self.LOG_TAG, "SSE final response JSON: \(json)")
                        }
                    } else {
                        Log.debug(label: self.LOG_TAG, "SSE chunk: state=\(state ?? "n/a") (no response)")
                    }
                    
                    // Handle messages
                    if let message = payload.response?.message {
                        if state == ConciergeConstants.StreamState.IN_PROGRESS {
                            accumulatedContent += message
                            Log.trace(label: self.LOG_TAG, "SSE chunk (len=\(message.count)): \"\(message)\"")
                            Log.trace(label: self.LOG_TAG, "Accumulated (len=\(accumulatedContent.count))")
                            
                            // Update the streaming message with accumulated content (preserve id)
                            if streamingMessageIndex < self.messages.count {
                                var current = self.messages[streamingMessageIndex]
                                current.messageBody = accumulatedContent
                                current.payload = payload
                                self.messages[streamingMessageIndex] = current
                            }
                        } else if state == ConciergeConstants.StreamState.COMPLETED {
                            let fullText = message
                            Log.trace(label: self.LOG_TAG, "Completion received. Full text length=\(fullText.count)")
                            
                            if streamingMessageIndex < self.messages.count {
                                var current = self.messages[streamingMessageIndex]
                                current.messageBody = fullText
                                current.payload = payload
                                self.messages[streamingMessageIndex] = current
                            }
                            
                            accumulatedContent = fullText
                        }
                    }
                    
                    // Handle cards in multimodalElements
                    if let elements = payload.response?.multimodalElements?.elements, !elements.isEmpty {
                        let newElementIds = Set(elements.map { $0.id })
                        accumulatedProducts.removeAll { existingElement in
                            newElementIds.contains(existingElement.id)
                        }
                        
                        accumulatedProducts.append(contentsOf: elements)
                        
                        if self.productCardIndex == nil {
                            self.productCardIndex = streamingMessageIndex + 1
                        }
                        
                        self.renderProductCards(accumulatedProducts)
                    }

                    // Capture prompt suggestions if present
                    if let suggestions = payload.response?.promptSuggestions, !suggestions.isEmpty {
                        self.latestPromptSuggestions = suggestions
                    }

                    // Capture sources from payload as they arrive (used on completion)
                    if let sources = payload.response?.sources {
                        self.latestSources = sources
                    }
                }
            },
            onComplete: { [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        Log.error(label: self.LOG_TAG, "Streaming error: \(error)")
                        self.chatState = .error(.networkFailure)
                        
                        if streamingMessageIndex < self.messages.count {
                            self.messages.remove(at: streamingMessageIndex)
                        }
                    } else if accumulatedContent.isEmpty {
                        if streamingMessageIndex < self.messages.count {
                            self.messages.remove(at: streamingMessageIndex)
                        }
                        
                        self.messages.append(Message(template: .basic(isUserMessage: false), messageBody: "Sorry, I wasn't able to get a response from the Concierge Service. \n\nPlease try again later."))
                        
                        self.clearState()
                    }
                    else {
                        if streamingMessageIndex < self.messages.count {
                            var current = self.messages[streamingMessageIndex]
                            current.messageBody = accumulatedContent
                            current.shouldSpeakMessage = true
                            if !self.latestSources.isEmpty {
                                Log.trace(label: self.LOG_TAG, "Using sources: count=\(self.latestSources.count)")
                                current.sources = self.latestSources
                            }
                            self.messages[streamingMessageIndex] = current
                        }
                        
                        // Append prompt suggestions as their own message bubbles at the end
                        if !self.latestPromptSuggestions.isEmpty {
                            for suggestion in self.latestPromptSuggestions {
                                self.messages.append(Message(template: .promptSuggestion(text: suggestion)))
                            }
                        }
                        
                        self.clearState()
                    }
                }
            }
        )
    }
    
    private func clearState() {
        chatState = .idle
        productCardIndex = nil
        latestSources = []
        latestPromptSuggestions = []
    }
    
    private func renderProductCards(_ products: [MultimodalElement]) {
        if products.count == 1, let entityInfo = products.first?.entityInfo {
            // Show a single product card
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
            
            removeProductCard(atIndex: productCardIndex)
            messages.append(card)
        } else {
            // Show a carousel of cards
            var carouselElements: [Message] = []
            for product in products {
                guard let entityInfo = product.entityInfo else { continue }
                let cardTitle = entityInfo.productName ?? "No title"
                let cardImageUrl = entityInfo.productImageURL.flatMap { URL(string: $0) }
                let cardClickThroughURL = entityInfo.productPageURL.flatMap { URL(string: $0) }
                                                
                let card = Message(template: .productCarouselCard(imageSource: .remote(cardImageUrl),
                                                                  title: cardTitle,
                                                                  destination: cardClickThroughURL))
                
                carouselElements.append(card)
            }
            
            removeProductCard(atIndex: productCardIndex)
            messages.append(Message(template: .carouselGroup(carouselElements)))
        }
    }
    
    private func removeProductCard(atIndex index: Int?) {
        if let index = index, index < messages.count {
            messages.remove(at: index)
        }
    }
}

// MARK: - Array Safe Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

