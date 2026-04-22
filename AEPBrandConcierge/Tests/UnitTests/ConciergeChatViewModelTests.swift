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

import XCTest
@testable import AEPBrandConcierge

// MARK: - Fakes
private final class NoopSpeaker: TextSpeaking { func utter(text: String) {} }

@MainActor
final class ChatControllerTests: XCTestCase {
    
    private var mockConciergeConfiguration = ConciergeConfiguration()
    
    func test_sendMessage_ignores_when_text_empty_or_not_idle() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // Empty text -> ignored
        controller.sendMessage(isUser: true)
        XCTAssertEqual(controller.messages.count, 0)

        // Non-idle -> ignored
        controller.applyTextChange("hi")
        controller.chatState = .processing
        controller.sendMessage(isUser: true)
        XCTAssertEqual(controller.messages.count, 0)
        XCTAssertEqual(controller.chatState, .processing)
    }

    func test_streaming_inProgress_accumulates_and_updates_placeholder() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep streaming; do not transition to idle
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hello "),
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "world")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("q")
        XCTAssertTrue(controller.sendEnabled)
        controller.sendMessage(isUser: true)
        // Wait for streaming chunks to apply and accumulate
        spinUntil(controller.messages.count == 2 && controller.messages[1].messageBody == "Hello world")

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello world")
        XCTAssertEqual(controller.chatState, .processing)

        // Now finish the stream explicitly and verify state transitions to idle
        fakeService.triggerCompletion()
        spinUntil(controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_streaming_completed_appends_only_delta() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hel"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Hello")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("go")
        controller.sendMessage(isUser: true)
        // Wait until final message is applied
        spinUntil(controller.messages.count == 2 && controller.messages[1].messageBody == "Hello")

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello")
    }

    func test_streaming_error_removes_placeholder_and_sets_error_state() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)

        // Allow onComplete to run
        spinUntil(controller.chatState == .error(.networkFailure))

        XCTAssertEqual(controller.messages.count, 1) // only user message remains
        XCTAssertEqual(controller.chatState, .error(.networkFailure))
    }

    func test_streaming_success_sets_idle_marks_shouldSpeak_and_attaches_sources() {
        let sources = [
            Source(url: "https://example.com/1", title: "One", startIndex: 0, endIndex: 1, citationNumber: 1),
            Source(url: "https://example.com/2", title: "Two", startIndex: 0, endIndex: 1, citationNumber: 2)
        ]
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hi"),
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: " there")
        ]
        fakeService.plannedError = nil
        // Also include a chunk that carries sources
        fakeService.plannedChunks.append(makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "!", sources: sources))

        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("x")
        controller.sendMessage(isUser: true)

        // Wait for chunks applied
        spinUntil(controller.messages.count == 2)

        // Completion happens immediately after chunks in fake
        spinUntil(controller.chatState == .idle)

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hi there!")
        XCTAssertTrue(agent.shouldSpeakMessage)
        let urls = agent.sources?.map { $0.url } ?? []
        XCTAssertEqual(urls.sorted(), ["https://example.com/1", "https://example.com/2"].sorted())
    }

    func test_toggleMic_flows_and_endCapture_transcript_updates_input() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = true
        capturer.transcriptToReturn = "return"
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)

        // Seed initial text and place cursor at end (4)
        controller.applyTextChange("set ")
        controller.toggleMic(currentSelectionLocation: 4)
        XCTAssertTrue(controller.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 1)

        // Toggle again to complete and deliver transcript
        controller.toggleMic(currentSelectionLocation: 4)

        // Wait for transcription completion to apply to controller input state machine
        spinUntil(controller.inputController.state == .editing && controller.inputController.data.text.contains("return"))

        XCTAssertEqual(capturer.endCaptures, 1)
        XCTAssertEqual(controller.inputController.data.text, "set return")
    }
    
    func test_startRecording_whenPermissionsNotGranted_showsPermissionDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false // Already asked before
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertFalse(controller.showPermissionDialog)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertTrue(controller.showPermissionDialog)
        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 0)
        XCTAssertEqual(capturer.permissionRequests, 0) // Should not request again
    }
    
    func test_dismissPermissionDialog_hidesDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.showPermissionDialog)
        
        controller.dismissPermissionDialog()
        
        XCTAssertFalse(controller.showPermissionDialog)
    }
    
    func test_requestOpenSettings_hidesDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.showPermissionDialog)
        
        controller.requestOpenSettings()
        
        XCTAssertFalse(controller.showPermissionDialog)
        // Note: The actual URL opening is handled by the view layer using SwiftUI's openURL
    }
    
    func test_startRecording_requestsPermissionsWhenNeverAsked() async {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = true // First time asking
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertEqual(capturer.permissionRequests, 0)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertEqual(capturer.permissionRequests, 1)
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertFalse(controller.isRecording) // Should not start recording because permissions still not available
        XCTAssertTrue(controller.showPermissionDialog) // Should show dialog after user denies
    }
    
    func test_startRecording_requestsPermissionsAndStartsRecordingWhenGranted() async {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.neverAsked = true // First time asking
        capturer.available = false // Not available initially
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertEqual(capturer.permissionRequests, 0)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertEqual(capturer.permissionRequests, 1)
        
        // Simulate user granting permissions
        capturer.available = true
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(controller.isRecording) // Should start recording after permissions granted
        XCTAssertFalse(controller.showPermissionDialog) // Should not show dialog
        XCTAssertEqual(capturer.beginCaptures, 1)
    }
    
    func test_startRecording_showsDialogWhenPreviouslyDenied() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false // Already asked before
        capturer.denied = false // Not explicitly denied (could be restricted or just not granted)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertTrue(controller.showPermissionDialog) // Should show dialog if already asked but not available
        XCTAssertEqual(capturer.permissionRequests, 0) // Should not request again
        XCTAssertFalse(controller.isRecording)
    }
    
    // MARK: - Product Card Rendering Tests

    func test_streaming_singleProduct_appendsProductCardMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element = MultimodalElement(
            id: "prod-1",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Widget Pro",
                productDescription: "A versatile tool",
                description: nil,
                productPageURL: "https://example.com/products/widget-pro",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/widget-pro.png",
                backgroundColor: nil,
                logo: nil,
                primary: ActionButton(text: "Buy", url: "https://example.com/buy"),
                secondary: nil,
                productPrice: "$9.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here's a product:"),
            makePayloadWithProducts(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [element],
                message: "Here's a product:"
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me a product")
        controller.sendMessage(isUser: true)

        // Then — wait for streaming to complete
        spinUntil(controller.chatState == .idle)

        // Messages: [user, agent text, product card]
        XCTAssertGreaterThanOrEqual(controller.messages.count, 3)

        let productMessage = controller.messages.last { message in
            if case .productCard = message.template { return true }
            return false
        }
        XCTAssertNotNil(productMessage, "Expected a .productCard message in the message list")
    }

    func test_streaming_multipleProducts_appendsCarouselGroupMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element1 = MultimodalElement(
            id: "prod-1",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Widget Pro",
                productDescription: nil,
                description: nil,
                productPageURL: "https://example.com/products/widget-pro",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/widget-pro.png",
                backgroundColor: nil,
                logo: nil,
                primary: nil,
                secondary: nil,
                productPrice: "$22.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )
        let element2 = MultimodalElement(
            id: "prod-2",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Gadget Basic",
                productDescription: nil,
                description: nil,
                productPageURL: "https://example.com/products/gadget-basic",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/gadget-basic.png",
                backgroundColor: nil,
                logo: nil,
                primary: nil,
                secondary: nil,
                productPrice: "$22.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here are some products:"),
            makePayloadWithProducts(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [element1, element2],
                message: "Here are some products:"
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me products")
        controller.sendMessage(isUser: true)

        // Then — wait for streaming to complete
        spinUntil(controller.chatState == .idle)

        // Expect a carouselGroup message containing the product carousel cards
        let carouselMessage = controller.messages.last { message in
            if case .carouselGroup = message.template { return true }
            return false
        }
        XCTAssertNotNil(carouselMessage, "Expected a .carouselGroup message in the message list")

        if case .carouselGroup(let items) = carouselMessage?.template {
            XCTAssertEqual(items.count, 2)
            if case .productCarouselCard(let cardData) = items[0].template {
                XCTAssertEqual(cardData.title, "Widget Pro")
            } else {
                XCTFail("Expected first carousel item to be .productCarouselCard")
            }
            if case .productCarouselCard(let cardData) = items[1].template {
                XCTAssertEqual(cardData.title, "Gadget Basic")
            } else {
                XCTFail("Expected second carousel item to be .productCarouselCard")
            }
        } else {
            XCTFail("Expected .carouselGroup template")
        }
    }

    // MARK: - CTA Button Rendering Tests

    func test_streaming_singleCtaButton_appendsCtaButtonMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let ctaElement = MultimodalElement(
            id: "cta-live-chat",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Chat now", url: "https://example.com/live-chat")
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Let me connect you."),
            makePayloadWithElements(state: ConciergeConstants.StreamState.COMPLETED, elements: [ctaElement], message: "Let me connect you.")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("help")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        let ctaMessage = controller.messages.first { message in
            if case .ctaButton = message.template { return true }
            return false
        }
        XCTAssertNotNil(ctaMessage, "Expected a .ctaButton message in the message list")

        if case .ctaButton(let action) = ctaMessage?.template {
            XCTAssertEqual(action.text, "Chat now")
            XCTAssertEqual(action.url, "https://example.com/live-chat")
        }
    }

    func test_streaming_ctaWithMissingPrimary_isSkipped() {
        // Given — CTA element with no primary action should be silently skipped
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let ctaWithNoPrimary = MultimodalElement(id: "cta-broken", type: "ctaButton", entityInfo: nil)

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here you go."),
            makePayloadWithElements(state: ConciergeConstants.StreamState.COMPLETED, elements: [ctaWithNoPrimary], message: "Here you go.")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("test")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        let ctaMessage = controller.messages.first { message in
            if case .ctaButton = message.template { return true }
            return false
        }
        XCTAssertNil(ctaMessage, "CTA with missing primary should not produce a message")
    }

    // MARK: - Interleaved Element Ordering Tests

    func test_streaming_interleavedCtaAndCards_respectsRelativeOrder() {
        // Given — [CTA, card, card, CTA, card] should produce [ctaButton, carousel(3), ctaButton]
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)

        let cta1 = MultimodalElement(
            id: "cta-1",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Chat with an agent", url: "https://example.com/chat")
        )
        let card1 = makeProductElement(id: "prod-1", name: "Product A", price: "$99.99")
        let card2 = makeProductElement(id: "prod-2", name: "Product B", price: "$129.99")
        let cta2 = MultimodalElement(
            id: "cta-2",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Find a store", url: "https://example.com/stores")
        )
        let card3 = makeProductElement(id: "prod-3", name: "Product C", price: "$149.99")

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here are some options."),
            makePayloadWithElements(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [cta1, card1, card2, cta2, card3],
                message: "Here are some options."
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me products")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        // Messages: [user, agent text, cta1, carousel, cta2]
        XCTAssertEqual(controller.messages.count, 5, "Expected 5 messages: user, agent text, CTA, carousel, CTA")

        // messages[0] = user message
        // messages[1] = agent text
        // messages[2] = first CTA
        if case .ctaButton(let action) = controller.messages[2].template {
            XCTAssertEqual(action.text, "Chat with an agent")
        } else {
            XCTFail("Expected messages[2] to be .ctaButton, got \(controller.messages[2].template)")
        }

        // messages[3] = carousel with 3 cards
        if case .carouselGroup(let items) = controller.messages[3].template {
            XCTAssertEqual(items.count, 3)
            if case .productCarouselCard(let cardData) = items[0].template {
                XCTAssertEqual(cardData.title, "Product A")
            } else {
                XCTFail("Expected first carousel item to be .productCarouselCard")
            }
            if case .productCarouselCard(let cardData) = items[2].template {
                XCTAssertEqual(cardData.title, "Product C")
            } else {
                XCTFail("Expected third carousel item to be .productCarouselCard")
            }
        } else {
            XCTFail("Expected messages[3] to be .carouselGroup, got \(controller.messages[3].template)")
        }

        // messages[4] = second CTA
        if case .ctaButton(let action) = controller.messages[4].template {
            XCTAssertEqual(action.text, "Find a store")
        } else {
            XCTFail("Expected messages[4] to be .ctaButton, got \(controller.messages[4].template)")
        }
    }

    // MARK: - Helpers
    private func makeController(configuration: ConciergeConfiguration, service: MockChatService, capturer: MockSpeechCapturer? = nil) -> ChatController {
        ChatController(configuration: configuration, chatService: service, speechCapturer: capturer, speaker: NoopSpeaker())
    }

    private func makePayload(state: String, message: String? = nil, sources: [Source]? = nil) -> ConversationPayload {
        let response: ConversationResponse? = message != nil || sources != nil
            ? ConversationResponse(message: message ?? "", promptSuggestions: nil, multimodalElements: nil, sources: sources, state: nil)
            : nil

        return ConversationPayload(
            conversationId: nil,
            interactionId: nil,
            request: nil,
            response: response,
            state: state,
            key: nil,
            value: nil,
            maxAge: nil
        )
    }

    private func makePayloadWithProducts(state: String, elements: [MultimodalElement], message: String? = nil) -> ConversationPayload {
        makePayloadWithElements(state: state, elements: elements, message: message)
    }

    private func makePayloadWithElements(state: String, elements: [MultimodalElement], message: String? = nil) -> ConversationPayload {
        let multimodal = MultimodalElements(elements: elements)
        let response = ConversationResponse(
            message: message ?? "",
            promptSuggestions: nil,
            multimodalElements: multimodal,
            sources: nil,
            state: nil
        )
        return ConversationPayload(
            conversationId: nil,
            interactionId: nil,
            request: nil,
            response: response,
            state: state,
            key: nil,
            value: nil,
            maxAge: nil
        )
    }

    private func makeCtaEntityInfo(text: String, url: String) -> EntityInfo {
        EntityInfo(
            productName: nil, productDescription: nil, description: nil, productPageURL: nil,
            details: nil, learningResource: nil, productImageURL: nil, backgroundColor: nil,
            logo: nil, primary: ActionButton(text: text, url: url),
            secondary: nil, productPrice: nil, productWasPrice: nil, productBadge: nil
        )
    }

    private func makeProductElement(id: String, name: String, price: String) -> MultimodalElement {
        MultimodalElement(
            id: id,
            entityInfo: EntityInfo(
                productName: name, productDescription: nil, description: nil,
                productPageURL: "https://example.com/p/\(id)", details: nil, learningResource: nil,
                productImageURL: "https://example.com/img/\(id).png",
                backgroundColor: nil, logo: nil, primary: nil,
                secondary: nil, productPrice: price, productWasPrice: nil, productBadge: nil
            )
        )
    }

    private func spinUntil(timeout: TimeInterval = 1.0, _ predicate: @autoclosure () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
