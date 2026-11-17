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
        NativeCardRegistry.register(rendererId: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.streaming","id":"draft"}]"#.utf8))
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
        NativeCardRegistry.register(rendererId: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.streaming","id":"draft"},{"type":"custom","rendererId":"test.streaming","id":"final"}]"#.utf8))
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
            $0.nativeCardId != nil
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
        NativeCardRegistry.register(rendererId: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.streaming","id":"draft"}]"#.utf8))
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
        guard case .template(.basic(isUserMessage: false)) = controller.messages.first?.content else {
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
                NativeCardRegistry.register(rendererId: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
                streamingElements += try CardJSONValue.decode([MultimodalElement].self,
                    from: Data(#"[{"type":"custom","rendererId":"test.streaming","id":"draft"}]"#.utf8))
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
                guard case .template(.productCard(let card)) = controller.messages.first?.content else {
                    return XCTFail("Expected the buffered built-in product")
                }
                XCTAssertEqual(card.title, "Buffered product")
            }
        }
    }

    /// A card-only response whose custom cards cannot render is empty, even with suggestions.
    @MainActor
    func testUnrenderableCardOnlyResponseIsReportedAsEmpty() async throws {
        NativeCardRegistry.register(rendererId: "test.unrenderable") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let rejected = #"{"type":"custom","rendererId":"test.unrenderable","nested":"# + nested + "}"
        let withFallback = #"{"type":"custom","rendererId":"test.unrenderable","nested":"# + nested +
            #","entity_info":{"productName":"Fallback"}}"#
        let unregistered = #"{"type":"custom","rendererId":"not.registered","id":42,"entity_info":{"productName":"Not a product"}}"#
        let missingId = #"{"type":"custom","entity_info":{"productName":"Not a product"}}"#
        for (json, withoutRegistry) in [(rejected, false), (withFallback, false), (unregistered, false),
                                        (missingId, false), (unregistered, true), (missingId, true)] {
            if withoutRegistry { NativeCardRegistry.resetForTesting() }
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
            guard case .invalidResponseData? = outcome else {
                return XCTFail("Expected invalidResponseData when no element can render")
            }
            XCTAssertTrue(controller.messages.isEmpty)
        }
    }

    @MainActor
    func testRendererReplacementDuringTurnOnlyAffectsNewOccurrences() async throws {
        var renderedBy: [String] = []
        NativeCardRegistry.register(rendererId: "test.replacement") { _, _, _ in
            renderedBy.append("first")
            return AnyView(EmptyView())
        }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.replacement","id":"same"}]"#.utf8))
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
        NativeCardRegistry.register(rendererId: "test.replacement") { _, _, _ in
            renderedBy.append("replacement")
            return AnyView(EmptyView())
        }
        service.emitChunk(streamPayload(state: "completed", elements: elements))
        service.triggerCompletion()
        await fulfillment(of: [finished], timeout: 2)
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 2)
        for card in cards { _ = card.renderer(card.element, card.cardContext, { _ in }) }
        XCTAssertEqual(renderedBy, ["first", "replacement"])
        XCTAssertTrue(newCardWasBusy)
        XCTAssertFalse(original.isStale)
        XCTAssertFalse(original.isBusy)
        XCTAssertNotEqual(cards[0].cardId, cards[1].cardId)
    }

    @MainActor
    func testFailedAndCancelledTurnsDoNotDisposeEarlierCards() async throws {
        NativeCardRegistry.register(rendererId: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.lifecycle","id":"same"}]"#.utf8))
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
        NativeCardRegistry.register(rendererId: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.lifecycle","id":"live"}]"#.utf8))
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
            $0.nativeCardId != nil
        })
        controller.messages[index] = Message(template: .basic(isUserMessage: false), messageBody: "Replaced")
        XCTAssertTrue(card.isStale, "Replacing a card's row in place must dispose it like any removal")
        XCTAssertFalse(card.isLatest)
    }

    /// A typed turn with nothing to show still offers the response's suggestions, as ordinary
    /// suggestion rows below the standard error. Handoffs stay silent; see
    /// `testUnrenderableCardOnlyResponseIsReportedAsEmpty`.
    @MainActor
    func testTypedTurnWithNothingRenderableKeepsSuggestionsBelowTheError() async throws {
        let unregistered = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"not.registered","id":"menu"}]"#.utf8))
        for suggestions in [["Show the menu", "Talk to someone"], nil] {
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "completed", elements: unregistered, suggestions: suggestions)]
            var errorEvents = 0
            let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil) { event in
                if event.name == ConciergeConstants.TrackingEvent.Name.ERROR_OCCURRED { errorEvents += 1 }
            }

            await sendTypedTurn("Order food", on: controller)

            XCTAssertEqual(errorEvents, 1, "A typed turn with nothing to show reports errorOccurred")
            let rows = Array(controller.messages.dropFirst())
            guard case .template(.basic(isUserMessage: false)) = rows.first?.content else {
                return XCTFail("Expected the standard error row after the query")
            }
            XCTAssertEqual(rows.first?.messageBody, emptyResponseMessage)
            XCTAssertEqual(suggestionTexts(in: Array(rows.dropFirst())), suggestions ?? [])
            XCTAssertEqual(rows.count, 1 + (suggestions?.count ?? 0))

            guard let suggestion = suggestions?.first else { continue }
            // Tapping a suggestion sends it as the next query, exactly as ChatView's handler does, and
            // the error turn's suggestions don't carry over into that turn.
            service.plannedChunks = [streamPayload(state: "completed", message: "Here is the menu")]
            let rowCountBeforeTap = controller.messages.count
            await sendTypedTurn(suggestion, on: controller)
            XCTAssertEqual(service.lastQuery, suggestion)
            let tapRows = Array(controller.messages.dropFirst(rowCountBeforeTap))
            XCTAssertEqual(tapRows.map(\.messageBody), [suggestion, "Here is the menu"])
            XCTAssertEqual(suggestionTexts(in: tapRows), [])
        }
    }

    /// The server can close the stream with a transport error after it already sent `COMPLETED`.
    /// The completed response stays authoritative: the late error is neither shown nor retried, and the
    /// empty placeholder gives way to the standard error and the response's suggestions.
    @MainActor
    func testLateTransportErrorAfterAnEmptyCompletedResponseKeepsTheErrorAndSuggestions() async throws {
        let unsupported = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"not.registered","id":"menu"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [streamPayload(state: "completed", elements: unsupported,
                                               suggestions: ["Show the menu", "Talk to someone"])]
        service.plannedError = .unreachable
        var errorEvents = 0
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil) { event in
            if event.name == ConciergeConstants.TrackingEvent.Name.ERROR_OCCURRED { errorEvents += 1 }
        }
        var placeholderIds = Set<UUID>()
        let observation = controller.$messages.sink { messages in
            for message in messages where message.messageBody?.isEmpty == true {
                if case .template(.basic(isUserMessage: false)) = message.content { placeholderIds.insert(message.id) }
            }
        }
        defer { observation.cancel() }

        await sendTypedTurn("Order food", on: controller)

        XCTAssertEqual(placeholderIds.count, 1, "The turn streamed into one placeholder")
        XCTAssertFalse(controller.messages.contains { placeholderIds.contains($0.id) }, "The placeholder is replaced")
        XCTAssertEqual(controller.messages.map(\.messageBody),
                       ["Order food", emptyResponseMessage, nil, nil], "The late error is not shown")
        XCTAssertEqual(suggestionTexts(in: controller.messages), ["Show the menu", "Talk to someone"])
        XCTAssertEqual(service.streamChatCallCount, 1, "The late error is not retried")
        XCTAssertEqual(errorEvents, 1, "Only the empty response is reported")
        XCTAssertEqual(controller.chatState, .idle)
    }

    /// Without a native card, a response's suggestions are always standalone rows after its content,
    /// whatever else it rendered or omitted.
    @MainActor
    func testResponsesWithoutNativeCardsKeepSuggestionsAsStandaloneRows() async throws {
        NativeCardRegistry.register(rendererId: "test.registered") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let cases: [(name: String, message: String, json: String, rowsBeforeSuggestions: Int)] = [
            ("text only", "Hello", "[]", 1),
            ("text with an unregistered custom element", "Hello",
             #"[{"type":"custom","rendererId":"not.registered"}]"#, 1),
            ("text with a rejected native element", "Hello",
             #"[{"type":"custom","rendererId":"test.registered","nested":"# + nested + "}]", 1),
            ("CTA only", "", #"[{"type":"ctaButton","entity_info":{"primary":{"text":"Go","url":"https://example.com"}}}]"#, 1),
            ("product only", "", #"[{"type":"product","entity_info":{"productName":"Product"}}]"#, 1)
        ]
        for testCase in cases {
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(testCase.json.utf8))
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "completed", elements: elements, message: testCase.message,
                                                   suggestions: ["One", "Two"])]
            let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)

            await sendTypedTurn("Hi", on: controller)

            let rows = Array(controller.messages.dropFirst())
            XCTAssertEqual(rows.count, testCase.rowsBeforeSuggestions + 2, testCase.name)
            XCTAssertEqual(suggestionTexts(in: Array(rows.dropFirst(testCase.rowsBeforeSuggestions))), ["One", "Two"],
                           testCase.name)
            XCTAssertTrue(rows.allSatisfy { $0.promptSuggestions == nil }, "\(testCase.name): nothing is attached")
        }
    }

    private let emptyResponseMessage =
        "Sorry, I wasn't able to get a response from the Concierge Service. \n\nPlease try again later."

    /// Sends `text` the way the composer does and waits until the turn has settled back to idle.
    @MainActor
    private func sendTypedTurn(_ text: String, on controller: ChatController) async {
        let settled = expectation(description: "Typed turn settled")
        let observation = controller.$chatState.dropFirst().first { $0 == .idle }.sink { _ in settled.fulfill() }
        controller.applyTextChange(text)
        controller.sendMessage(isUser: true)
        await fulfillment(of: [settled], timeout: 2)
        observation.cancel()
    }

    private func suggestionTexts(in messages: [Message]) -> [String] {
        messages.compactMap { message in
            guard case .template(.promptSuggestion(let text)) = message.content else { return nil }
            return text
        }
    }
}
