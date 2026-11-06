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

final class ResponseElementResolverTests: NativeCardTestCase {
    @MainActor
    func testLegacyProductFallbackWithoutAnyRegistry() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Legacy"}}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.count, 1)
        guard case .productCard = controller.messages.first?.template else {
            return XCTFail("No registrations must retain legacy product parsing")
        }
    }

    @MainActor
    func testNativeDuplicateIdsUseBuiltInFallback() async throws {
        NativeCardRegistry.register(type: "test.identity") { _, _, _ in AnyView(EmptyView()) }
        let duplicateIds = [
            ("42", "42"), (#""same""#, #""same""#), ("42", #""42""#),
            ("42.5", "42.5"), ("true", #""true""#),
            ("18446744073709551615", #""18446744073709551615""#)
        ]
        for ids in duplicateIds {
            let controller = ChatController(configuration: nil,
                chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
            let json = """
            [{"type":"test.identity","id":\(ids.0)},
             {"type":"test.identity","id":\(ids.1)},
             {"type":"test.identity","id":\(ids.1),"entity_info":{"productName":"Fallback"}},
             {"type":"ctaButton","id":"cta","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
            """
            NativeCardRegistry.register(type: "ctaButton") { _, _, _ in AnyView(EmptyView()) }
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
            let payload = streamPayload(state: "completed")
            let turn = UUID()
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            XCTAssertEqual(controller.messages.count, 3)
            guard let first = nativeCard(at: 0, in: controller),
                  case .productCard(let fallback) = controller.messages[1].template,
                  case .nativeCard = controller.messages[2].template else {
                return XCTFail("Duplicate IDs must use a fallback or be omitted, not activate twice")
            }
            XCTAssertEqual(fallback.title, "Fallback")
            await saveStateAndWait(["selected": true], on: first)
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            let cards = nativeCards(in: controller)
            XCTAssertEqual(cards.count, 2, "Reprocessing must not reactivate an occurrence")
            XCTAssertEqual(cards.first?.cardId, first.cardId)
            XCTAssertEqual(first.state?["selected"] as? Bool, true)
            controller.messages.removeAll()
            XCTAssertTrue(first.disposed)
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            guard let replacement = nativeCard(at: 0, in: controller) else {
                return XCTFail("Rollback must release occurrence IDs")
            }
            XCTAssertNotEqual(replacement.cardId, first.cardId)
        }
    }

    @MainActor
    func testNativeDuplicateIdUsesCtaFallback() throws {
        NativeCardRegistry.register(type: "ctaButton") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"ctaButton","id":"same"},
         {"type":"ctaButton","id":"same","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        XCTAssertEqual(controller.messages.count, 2)
        guard case .nativeCard = controller.messages[0].template,
              case .ctaButton = controller.messages[1].template else {
            return XCTFail("Duplicate native IDs must fall back to the built-in CTA")
        }
    }

    @MainActor
    func testNativeRoutingFallbackAndOccurrenceState() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.native.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"same","custom":{"null":null}},
         {"type":"\(type)","id":"same"},
         {"type":"unknown","entity_info":{"productName":"unknown fallback"}},
         {"type":"product","entity_info":{"productName":"legacy product"}},
         {"type":"unregistered.custom","entity_info":{"productName":"custom fallback"}},
         {"type":"unregistered.custom","custom":{"name":"no product data"}},
         {"entity_info":{"productName":"untyped fallback"}},
         {"type":"productCard","entity_info":{"productName":"visible"}},
         {"type":"horizontalCard","entity_info":{"productName":"horizontal fallback"}},
         {"type":"ctaButton","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))
        let turnId = UUID()
        controller.renderElementsForTesting(elements, turnId: turnId, payload: payload, sessionId: "session")
        XCTAssertEqual(controller.messages.count, 3)
        guard case .carouselGroup(let products) = controller.messages[1].template else {
            return XCTFail("Expected the allowed productCard fallback")
        }
        XCTAssertEqual(products.count, 6)
        let titles = products.compactMap { message -> String? in
            if case .productCarouselCard(let product) = message.template { return product.title }
            return nil
        }
        XCTAssertEqual(titles, [
            "unknown fallback", "legacy product", "custom fallback",
            "untyped fallback", "visible", "horizontal fallback"
        ])
        XCTAssertTrue(controller.messages.contains {
            if case .ctaButton = $0.template { return true }
            return false
        })
        guard let card = nativeCard(at: 0, in: controller) else {
            return XCTFail("Expected native card")
        }
        XCTAssertEqual(card.context["conversationId"] as? String, "conv")
        XCTAssertEqual(card.context["sessionId"] as? String, "session")
        XCTAssertTrue((card.element["custom"] as? [String: Any])?["null"] is NSNull)
        controller.renderElementsForTesting(elements, turnId: turnId, payload: payload, sessionId: "session")
        XCTAssertEqual(controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }.count, 1)
        controller.messages.removeAll()
        XCTAssertTrue(card.isStale)
        card.applySavedState(["late": true])
        XCTAssertNil(card.state)
    }

    @MainActor
    func testPromptSuggestionsPreferBuiltInRowOverNativeRow() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"native"},
         {"type":"productCard","entity_info":{"productName":"Product"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Try another"])

        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        let builtInMessage = try XCTUnwrap(controller.messages.first {
            if case .productCard = $0.template { return true }
            return false
        })
        XCTAssertNil(nativeMessage.promptSuggestions)
        XCTAssertEqual(builtInMessage.promptSuggestions, ["Try another"])
        XCTAssertFalse(controller.messages.contains {
            if case .promptSuggestion = $0.template { return true }
            return false
        })
    }

    @MainActor
    func testPromptSuggestionsAttachToLastNativeRowWithoutBuiltInCard() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"first"},
         {"type":"\(type)","id":"last"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let nativeMessages = controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }
        XCTAssertEqual(nativeMessages.count, 2)
        XCTAssertNil(nativeMessages.first?.promptSuggestions)
        XCTAssertEqual(nativeMessages.last?.promptSuggestions, ["Continue"])
    }

    @MainActor
    func testPromptSuggestionsPreferNonEmptyBuiltInCarousel() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"native"},
         {"type":"productCard","entity_info":{"productName":"One"}},
         {"type":"productCard","entity_info":{"productName":"Two"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let carousel = try XCTUnwrap(controller.messages.first {
            if case .carouselGroup = $0.template { return true }
            return false
        })
        guard case .carouselGroup(let products) = carousel.template else { return XCTFail("Expected carousel") }
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(carousel.promptSuggestions, ["Continue"])
        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        XCTAssertNil(nativeMessage.promptSuggestions)
    }

    @MainActor
    func testPromptSuggestionsIgnoreAnEmptyBuiltInCarousel() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"unknown-one"},{"type":"unknown-two"},{"type":"\(type)","id":"native"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let carousel = try XCTUnwrap(controller.messages.first {
            if case .carouselGroup = $0.template { return true }
            return false
        })
        guard case .carouselGroup(let products) = carousel.template else { return XCTFail("Expected carousel") }
        XCTAssertTrue(products.isEmpty)
        XCTAssertNil(carousel.promptSuggestions)
        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        XCTAssertEqual(nativeMessage.promptSuggestions, ["Continue"])
    }

    @MainActor
    func testResolverDoesNotActivateOrReserveOccurrences() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.plan","id":"same"},{"type":"test.plan","id":"same"}]"#.utf8))
        let store = NativeCardStore()
        let turn = UUID()
        let occurrence = NativeCardStore.Occurrence(element: elements[0], position: 0, turnId: turn)
        let plan = ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store)
        XCTAssertTrue(plan.hasRenderableElements)
        XCTAssertEqual(plan.targets.count, 1)
        XCTAssertNil(store.position(for: occurrence))
        let repeatedPlan = ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store)
        XCTAssertEqual(repeatedPlan.targets.count, 1)
        let messages = repeatedPlan.makeMessages(nativeCards: store, payload: streamPayload(state: "completed"),
                                                sessionId: "session", promptSuggestions: [])
        store.reconcile(with: messages)
        XCTAssertEqual(store.position(for: occurrence), 0)
        XCTAssertFalse(ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store).hasRenderableElements)
        store.removeAll()
        XCTAssertNil(store.position(for: occurrence))
        XCTAssertTrue(ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store).hasRenderableElements)
    }

    @MainActor
    func testResolverSeparatesExplicitMarkerIdsFromPositionIdentities() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(##"[{"type":"test.plan","id":"#1"},{"type":"test.plan"}]"##.utf8))
        let store = NativeCardStore()
        let turn = UUID()
        let plan = ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store)
        let messages = plan.makeMessages(nativeCards: store, payload: streamPayload(state: "completed"),
                                        sessionId: nil, promptSuggestions: [])
        XCTAssertEqual(nativeCards(in: messages, store: store).count, 2)
        XCTAssertEqual(store.position(for: NativeCardStore.Occurrence(element: elements[0], position: 0, turnId: turn)), 0)
        XCTAssertEqual(store.position(for: NativeCardStore.Occurrence(element: elements[1], position: 1, turnId: turn)), 1)
    }

    @MainActor
    func testRejectedCandidateDoesNotReserveAnIdForItsValidSibling() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let json = """
        [{"type":"test.plan","id":"same","nested":\(nested),"entity_info":{"productName":"Fallback"}},
         {"type":"test.plan","id":"same"},
         {"type":"test.plan","id":"same","entity_info":{"productName":"Duplicate fallback"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"),
                                            promptSuggestions: ["Continue"])
        XCTAssertEqual(controller.messages.count, 2)
        guard case .carouselGroup(let products) = controller.messages[0].template,
              case .nativeCard = controller.messages[1].template else {
            return XCTFail("Rejected candidates must preserve fallback order without reserving the ID")
        }
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(controller.messages[0].promptSuggestions, ["Continue"])
        XCTAssertEqual(nativeCards(in: controller).count, 1)
    }

    @MainActor
    func testMixedResponseKeepsTextBatchingCtasSuggestionsAndTracking() async throws {
        NativeCardRegistry.register(type: "test.mixed") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"ctaButton","entity_info":{"primary":{"text":"First CTA","url":"https://example.com/first"}}},
         {"type":"product","entity_info":{"productName":"One"}},
         {"type":"test.mixed","id":"first"},
         {"type":"product","entity_info":{"productName":"Two"}},
         {"type":"ctaButton","entity_info":{"primary":{"text":"Last CTA","url":"https://example.com/last"}}},
         {"type":"test.mixed","id":"last"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [streamPayload(state: "completed", elements: elements,
                                               message: "Final text", suggestions: ["Continue"])]
        var tracking: [[String: Any]] = []
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil,
                                        dispatch: { tracking.append($0.data ?? [:]) })
        let finished = expectation(description: "Mixed response rendered")
        controller.handleDataHandoff(routingHint: "mixed", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 6)
        XCTAssertEqual(controller.messages[0].messageBody, "Final text")
        XCTAssertTrue(controller.messages[0].isStreamComplete)
        guard case .ctaButton(let firstCTA) = controller.messages[1].template,
              case .carouselGroup(let products) = controller.messages[2].template,
              let first = nativeCard(at: 3, in: controller),
              case .ctaButton(let lastCTA) = controller.messages[4].template,
              let last = nativeCard(at: 5, in: controller) else {
            return XCTFail("Text, batched products and independent element rows must retain their order")
        }
        XCTAssertEqual(firstCTA.text, "First CTA")
        XCTAssertEqual(lastCTA.text, "Last CTA")
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(controller.messages[2].promptSuggestions, ["Continue"])
        XCTAssertNil(controller.messages[3].promptSuggestions)
        XCTAssertNil(controller.messages[5].promptSuggestions)
        XCTAssertFalse(controller.messages[3].feedbackEligible)
        XCTAssertNil(controller.messages[3].messageBody)
        XCTAssertEqual(first.conversationId, "conversation")
        XCTAssertEqual(last.interactionId, "interaction")
        typealias Key = ConciergeConstants.TrackingEvent.EventData.Key
        typealias EventType = ConciergeConstants.TrackingEvent.XDMType
        let events = tracking.compactMap { $0[Key.EVENT_TYPE] as? String }
        XCTAssertEqual(events.filter { $0 == EventType.RESPONSE_STARTED }.count, 1)
        XCTAssertEqual(events.filter { $0 == EventType.RESPONSE_COMPLETED }.count, 1)
        let cardEvents = tracking.filter { ($0[Key.EVENT_TYPE] as? String) == EventType.CARDS_RENDERED }
        XCTAssertEqual(cardEvents.count, 1)
        XCTAssertEqual(cardEvents.first?["displayMode"] as? String, "carousel")
        let rendered = cardEvents.first?["elements"] as? [[String: Any]]
        XCTAssertEqual(rendered?.compactMap { $0["productName"] as? String }, ["One", "Two"])
    }

    @MainActor
    func testBuiltInOnlyResponseKeepsSeparateSuggestionRows() async throws {
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Product"}}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [streamPayload(state: "completed", elements: elements, suggestions: ["One", "Two"])]
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
        let finished = expectation(description: "Built-in suggestions rendered")
        controller.handleDataHandoff(routingHint: "products", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 3)
        guard case .productCard = controller.messages[0].template,
              case .promptSuggestion(text: "One") = controller.messages[1].template,
              case .promptSuggestion(text: "Two") = controller.messages[2].template else {
            return XCTFail("Without a native row, suggestions must remain independent rows")
        }
        XCTAssertNil(controller.messages[0].promptSuggestions)
    }

    @MainActor
    func testNativeSuggestionsArePublishedWithTheirRowBeforeATrailingCta() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data("""
        [{"type":"test.plan","id":"first"},{"type":"test.plan","id":"last"},
         {"type":"ctaButton","entity_info":{"primary":{"text":"CTA","url":"https://example.com"}}}]
        """.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        var published: [[Message]] = []
        let observation = controller.$messages.dropFirst().sink { published.append($0) }
        defer { observation.cancel() }
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"),
                                            promptSuggestions: ["Continue"])
        XCTAssertEqual(published.count, 1)
        XCTAssertEqual(published.first?.count, 3)
        XCTAssertEqual(published.first?[1].promptSuggestions, ["Continue"])
        XCTAssertNil(published.first?[0].promptSuggestions)
        XCTAssertNil(published.first?[2].promptSuggestions)
    }
}
