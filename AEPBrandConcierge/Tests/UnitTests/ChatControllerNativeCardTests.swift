/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Combine
import XCTest
import SwiftUI
@testable import AEPBrandConcierge

final class ChatControllerNativeCardTests: NativeCardTestCase {
    @MainActor
    func testStreamingNativeCardsRequireCompletedElements() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
        let completions: [ConversationPayload?] = [
            streamPayload(state: "completed"),
            streamPayload(state: "completed", elements: []),
            nil
        ]
        for completion in completions {
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "in-progress", elements: elements)]
            if let completion { service.plannedChunks.append(completion) }
            let controller = ChatController(configuration: nil, chatService: service,
                                            speechCapturer: nil, speaker: nil)
            let finished = expectation(description: "Unfinalized native card rejected")
            var outcome: ConciergeError?
            controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
                outcome = error
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 2)
            guard case .invalidResponseData? = outcome else {
                return XCTFail("Expected invalidResponseData for an unfinalized native card")
            }
            XCTAssertTrue(controller.messages.isEmpty)
            XCTAssertEqual(controller.chatState, .idle)
        }
    }

    @MainActor
    func testCompletedNativeElementsReplaceStreamingCandidates() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"},{"type":"test.streaming","id":"final"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [
            streamPayload(state: "in-progress", elements: [elements[0]]),
            streamPayload(state: "completed", elements: [elements[1]], message: "Final response")
        ]
        service.shouldCallComplete = false
        let controller = ChatController(configuration: nil, chatService: service,
                                        speechCapturer: nil, speaker: nil)
        let receivedFinal = expectation(description: "Completed payload received")
        let observation = controller.$messages
            .first { $0.last?.messageBody == "Final response" }
            .sink { _ in receivedFinal.fulfill() }
        defer { observation.cancel() }
        let finished = expectation(description: "Final native card accepted")
        controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [receivedFinal], timeout: 2)
        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertFalse(controller.messages.contains {
            if case .nativeCard = $0.template { return true }
            return false
        })
        service.triggerCompletion()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 2)
        guard let card = nativeCard(at: controller.messages.count - 1, in: controller) else {
            return XCTFail("Expected the completed native card")
        }
        XCTAssertEqual(card.element["id"] as? String, "final")
        XCTAssertFalse(card.isBusy)
        XCTAssertEqual(controller.chatState, .idle)
    }

    @MainActor
    func testCompletedTextDoesNotActivateStreamingNativeCards() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [
            streamPayload(state: "in-progress", elements: elements),
            streamPayload(state: "completed", message: "No menu is available.")
        ]
        let controller = ChatController(configuration: nil, chatService: service,
                                        speechCapturer: nil, speaker: nil)
        let finished = expectation(description: "Final text accepted without a native card")
        controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(controller.messages.first?.messageBody, "No menu is available.")
        guard case .basic(isUserMessage: false) = controller.messages.first?.template else {
            return XCTFail("Expected only the completed text")
        }
    }

    @MainActor
    func testStreamingBuiltInElementsKeepLegacyBuffering() async throws {
        let product = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Buffered product"}}]"#.utf8))
        let completions: [[MultimodalElement]?] = [nil, []]
        for hasRenderer in [false, true] {
            var streamingElements = product
            if hasRenderer {
                NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
                streamingElements += try CardJSONValue.decode([MultimodalElement].self,
                    from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
            }
            for completedElements in completions {
                let service = MockChatService(configuration: ConciergeConfiguration())
                service.plannedChunks = [
                    streamPayload(state: "in-progress", elements: streamingElements),
                    streamPayload(state: "completed", elements: completedElements)
                ]
                let controller = ChatController(configuration: nil, chatService: service,
                                                speechCapturer: nil, speaker: nil)
                let finished = expectation(description: "Buffered built-in product accepted")
                controller.handleDataHandoff(routingHint: "products", xdmFields: [:]) { error in
                    XCTAssertNil(error)
                    finished.fulfill()
                }
                await fulfillment(of: [finished], timeout: 2)
                XCTAssertEqual(controller.messages.count, 1)
                guard case .productCard(let card) = controller.messages.first?.template else {
                    return XCTFail("Expected the buffered built-in product")
                }
                XCTAssertEqual(card.title, "Buffered product")
            }
        }
    }

    /// Matches Android: a card-only response whose cards all fail to render is an empty response,
    /// even with prompt suggestions; a built-in fallback still delivers it.
    @MainActor
    func testUnrenderableCardOnlyResponseIsReportedAsEmpty() async throws {
        NativeCardRegistry.register(type: "test.unrenderable") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let rejected = #"{"type":"test.unrenderable","nested":"# + nested + "}"
        let withFallback = #"{"type":"test.unrenderable","nested":"# + nested +
            #","entity_info":{"productName":"Fallback"}}"#
        for (json, delivered) in [(rejected, false), (withFallback, true)] {
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data("[\(json)]".utf8))
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "completed", elements: elements, suggestions: ["Next"])]
            let controller = ChatController(configuration: nil, chatService: service,
                                            speechCapturer: nil, speaker: nil)
            let finished = expectation(description: "Card-only handoff finished")
            var outcome: ConciergeError?
            controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
                outcome = error
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 2)
            XCTAssertEqual(controller.chatState, .idle)
            if delivered {
                XCTAssertNil(outcome)
                guard case .productCard? = controller.messages.first?.template else {
                    return XCTFail("A rejected native card with a built-in fallback must render the fallback")
                }
            } else {
                guard case .invalidResponseData? = outcome else {
                    return XCTFail("Expected invalidResponseData when no element can render")
                }
                XCTAssertTrue(controller.messages.isEmpty)
            }
        }
    }

    @MainActor
    func testRendererReplacementDuringTurnOnlyAffectsNewOccurrences() async throws {
        var renderedBy: [String] = []
        NativeCardRegistry.register(type: "test.replacement") { _, _, _ in
            renderedBy.append("first")
            return AnyView(EmptyView())
        }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.replacement","id":"same"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.shouldCallComplete = false
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let original = try XCTUnwrap(nativeCards(in: controller).first)
        var newCardWasBusy = false
        let observation = controller.$messages.sink { messages in
            let cards = self.nativeCards(in: messages, store: controller.nativeCards)
            if cards.count == 2 { newCardWasBusy = cards[1].isBusy }
        }
        defer { observation.cancel() }
        let started = expectation(description: "Turn sent")
        service.onStreamChat = { started.fulfill() }
        let finished = expectation(description: "Replacement renderer activated")
        controller.handleDataHandoff(routingHint: "new-card", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(original.isBusy)
        NativeCardRegistry.register(type: "test.replacement") { _, _, _ in
            renderedBy.append("replacement")
            return AnyView(EmptyView())
        }
        service.emitChunk(streamPayload(state: "completed", elements: elements))
        service.triggerCompletion()
        await fulfillment(of: [finished], timeout: 2)
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 2)
        for card in cards { _ = card.renderer(card.element, card.context, { _ in }) }
        XCTAssertEqual(renderedBy, ["first", "replacement"])
        XCTAssertTrue(newCardWasBusy)
        XCTAssertFalse(original.isStale)
        XCTAssertFalse(original.isBusy)
        XCTAssertNotEqual(cards[0].cardId, cards[1].cardId)
    }

    @MainActor
    func testFailedAndCancelledTurnsDoNotDisposeEarlierCards() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"same"}]"#.utf8))
        for cancel in [false, true] {
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.shouldCallComplete = false
            service.plannedError = .unreachable
            let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
            controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
            let card = try XCTUnwrap(nativeCards(in: controller).first)
            await saveStateAndWait(["kept": true], on: card)
            let started = expectation(description: "Failing turn sent")
            service.onStreamChat = { started.fulfill() }
            let finished = expectation(description: "Failing turn ended")
            controller.handleDataHandoff(routingHint: "failed", xdmFields: [:]) { error in
                XCTAssertNotNil(error)
                finished.fulfill()
            }
            await fulfillment(of: [started], timeout: 2)
            XCTAssertTrue(card.isBusy)
            if cancel {
                controller.abandonActiveTurn()
            } else {
                service.emitChunk(streamPayload(state: "in-progress", elements: elements, message: "Partial"))
                service.triggerCompletion()
            }
            await fulfillment(of: [finished], timeout: 2)
            XCTAssertEqual(controller.chatState, .idle)
            XCTAssertEqual(controller.messages.count, 1)
            XCTAssertEqual(nativeCards(in: controller).first?.cardId, card.cardId)
            XCTAssertEqual(card.state?["kept"] as? Bool, true)
            XCTAssertFalse(card.isStale)
            XCTAssertFalse(card.isBusy)
        }
    }

    @MainActor
    func testEveryTranscriptWriteKeepsCardLifetimeInSync() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"live"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [
            streamPayload(state: "in-progress", message: "Str"),
            streamPayload(state: "in-progress", message: "eamed"),
            streamPayload(state: "completed", message: "Streamed")
        ]
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let card = try XCTUnwrap(nativeCards(in: controller).first)

        let finished = expectation(description: "Streamed turn finished")
        controller.handleDataHandoff(routingHint: "text", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.last?.messageBody, "Streamed")
        XCTAssertFalse(card.isStale, "Streaming placeholder updates must not dispose existing cards")

        let index = try XCTUnwrap(controller.messages.firstIndex {
            if case .nativeCard = $0.template { return true }
            return false
        })
        controller.messages[index] = Message(template: .basic(isUserMessage: false), messageBody: "Replaced")
        XCTAssertTrue(card.isStale, "Replacing a card's row in place must dispose it like any removal")
        XCTAssertFalse(card.isLatest)
    }
}
