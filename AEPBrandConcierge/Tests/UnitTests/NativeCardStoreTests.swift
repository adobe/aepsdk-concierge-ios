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

final class NativeCardStoreTests: NativeCardTestCase {
    @MainActor
    func testDistinctOccurrencesRemainDeduplicated() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        NativeCardRegistry.register(type: "test.occurrence") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.occurrence","id":"1"},{"type":"test.occurrence"}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 2)
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(Set(cards.map(\.cardId)).count, 2)
        XCTAssertEqual(cards.map(\.sequence), [0, 1], "sequence follows transcript order within one response")
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 2, "Reprocessing the response must not append cards")
    }

    @MainActor
    func testControllerTeardownDisposesRetainedCard() async throws {
        var controller: ChatController? = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        NativeCardRegistry.register(type: "test.teardown") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
                                                from: Data(#"[{"type":"test.teardown"}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        controller?.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        guard let card = controller.flatMap({ nativeCard(at: 0, in: $0) }) else {
            return XCTFail("Missing native card")
        }
        let disposed = expectation(description: "Releasing the chat disposes its card")
        let observation = card.$isStale.first { $0 }.sink { _ in disposed.fulfill() }
        defer { observation.cancel() }
        let isReleased = { [weak controller] in controller == nil }
        controller = nil
        await fulfillment(of: [disposed], timeout: 2)
        XCTAssertTrue(isReleased())
        XCTAssertTrue(card.disposed)
        card.applySavedState(["late": true])
        XCTAssertNil(card.state)
    }

    @MainActor
    func testNativeEmptyNullAndMissingIdsUsePosition() throws {
        NativeCardRegistry.register(type: "test.identity") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"test.identity","id":""},{"type":"test.identity","id":""},
         {"type":"test.identity","id":null},{"type":"test.identity","id":null},
         {"type":"test.identity"},{"type":"test.identity"},
         {"type":"test.identity","id":" "}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let turn = UUID()
        let payload = streamPayload(state: "completed")
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 7)
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 7)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.count, 14, "Occurrence IDs must be scoped to a turn")
    }

    @MainActor
    func testTenThousandNativeCardsAppendOnceAndDisposeRemovedOccurrences() throws {
        NativeCardRegistry.register(type: "test.large") { _, _, _ in AnyView(EmptyView()) }
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let json = "[" + (0..<10_000).map { #"{"type":"test.large","id":\#($0)}"# }.joined(separator: ",") + "]"
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = streamPayload(state: "completed")
        let turn = UUID()
        var publications = 0
        let subscription = controller.$messages.dropFirst().sink { _ in publications += 1 }
        defer { subscription.cancel() }
        let startedAt = ProcessInfo.processInfo.systemUptime
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        let duration = ProcessInfo.processInfo.systemUptime - startedAt
        XCTAssertEqual(publications, 1, "A completed response must publish its rows in one batch")
        XCTAssertLessThan(duration, 10, "A valid 10,000-element response must not trigger quadratic transcript scans")
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 10_000)
        XCTAssertEqual(cards.first?.element["id"] as? Int, 0)
        XCTAssertEqual(cards.last?.element["id"] as? Int, 9_999)
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(publications, 1, "Replayed occurrences must not publish duplicate rows")
        controller.messages.removeFirst(5_000)
        XCTAssertTrue(cards.prefix(5_000).allSatisfy(\.disposed))
        XCTAssertTrue(cards.suffix(5_000).allSatisfy { !$0.disposed })
        controller.messages.removeAll()
        XCTAssertTrue(cards.allSatisfy(\.disposed))
        controller.renderElementsForTesting([elements[0]], turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 1, "Disposal must release occurrence identities")
    }

    @MainActor
    func testRollbackDisposesOnlyRemovedCardsAndRejectsQueuedSaves() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"older"},{"type":"test.lifecycle","id":"removed"}]"#.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.count, 2)
        await saveStateAndWait(["kept": true], on: cards[0])
        controller.messages.removeLast()
        // A save queued before the rollback arrives after it; the disposed card must ignore it.
        cards[1].applySavedState(["queued": true])
        XCTAssertTrue(cards[1].isStale)
        XCTAssertTrue(cards[1].disposed)
        XCTAssertNil(cards[1].state)
        XCTAssertFalse(cards[0].isStale)
        XCTAssertEqual(cards[0].state?["kept"] as? Bool, true)
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let restored = nativeCards(in: controller)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].cardId, cards[0].cardId)
        XCTAssertNotEqual(restored[1].cardId, cards[1].cardId)
        XCTAssertNil(restored[1].state)
    }

    @MainActor
    func testIdentityResetDisposesLiveCardsAndIgnoresQueuedSaves() throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle"}]"#.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let card = try XCTUnwrap(nativeCards(in: controller).first)
        var observedStaleness = false
        let observation = card.$isStale.dropFirst().sink { observedStaleness = $0 }
        defer { observation.cancel() }
        controller.endConversationForIdentityReset()
        // A save queued before the reset arrives after it; the disposed card must ignore it.
        card.applySavedState(["queued": true])
        XCTAssertTrue(observedStaleness)
        XCTAssertTrue(card.disposed)
        XCTAssertNil(card.state)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    @MainActor
    func testCardsAndSavedStateRemainPrivateToEachChat() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"same"}]"#.utf8))
        let controllers = (0..<2).map { _ in
            ChatController(configuration: nil, chatService: MockChatService(configuration: ConciergeConfiguration()),
                           speechCapturer: nil, speaker: nil)
        }
        let turn = UUID()
        for controller in controllers {
            controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        }
        let first = try XCTUnwrap(nativeCards(in: controllers[0]).first)
        let second = try XCTUnwrap(nativeCards(in: controllers[1]).first)
        await saveStateAndWait(["private": true], on: first)
        XCTAssertEqual(first.state?["private"] as? Bool, true)
        XCTAssertNil(second.state)
        XCTAssertNotEqual(first.cardId, second.cardId)
        controllers[0].messages.removeAll()
        XCTAssertTrue(first.isStale)
        XCTAssertFalse(second.isStale)
    }

    @MainActor
    private func makeOrderingController() -> ChatController {
        NativeCardRegistry.register(type: "test.menu") { _, _, _ in AnyView(EmptyView()) }
        NativeCardRegistry.register(type: "test.cart") { _, _, _ in AnyView(EmptyView()) }
        return ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
    }

    private func orderingElements(_ json: String) throws -> [MultimodalElement] {
        try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
    }

    @MainActor
    func testLastCardOfATypeInOneResponseIsLatestAndTypesAreIndependent() throws {
        let controller = makeOrderingController()
        let elements = try orderingElements(
            #"[{"type":"test.menu","id":"m1"},{"type":"test.cart","id":"c1"},{"type":"test.menu","id":"m2"}]"#)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(cards.map(\.isLatest), [false, true, true])
        XCTAssertEqual(cards[2].context["sequence"] as? Int, 2)
        XCTAssertEqual(cards[2].context["isLatest"] as? Bool, true)
        XCTAssertEqual(cards[0].context["isLatest"] as? Bool, false)
    }

    @MainActor
    func testNewerTurnTakesOverLatestForItsTypeOnly() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(cards.map(\.isLatest), [false, true, true])
    }

    @MainActor
    func testRollbackPromotesTheNewestRemainingCardOfTheType() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.map(\.isLatest), [false, false, true, true])

        controller.messages.removeLast(2)
        XCTAssertTrue(cards[1].isLatest, "the highest remaining sequence of the type is promoted")
        XCTAssertFalse(cards[0].isLatest)
        XCTAssertFalse(cards[2].isLatest)
        XCTAssertFalse(cards[3].isLatest, "a disposed card is never latest")
        XCTAssertTrue(cards[3].disposed)

        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let newCart = try XCTUnwrap(nativeCards(in: controller).last)
        XCTAssertTrue(newCart.isLatest, "rolling back the only card of a type leaves no latest to demote")
        XCTAssertEqual(newCart.sequence, 4, "sequences are never reused after rollback")
    }

    @MainActor
    func testRejectedAndDuplicateElementsDoNotConsumeASequence() throws {
        let controller = makeOrderingController()
        let elements = try orderingElements(
            #"[{"type":"test.menu","id":"same"},{"type":"test.menu","id":"same"},{"type":"test.menu","id":"next"}]"#)
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller)
        XCTAssertEqual(cards.map(\.sequence), [0, 1])
        XCTAssertEqual(cards.map(\.isLatest), [false, true])
    }

    @MainActor
    func testRemovingAllCardsKeepsTheSequenceCounter() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let first = try XCTUnwrap(nativeCards(in: controller).first)
        controller.messages.removeAll()
        XCTAssertFalse(first.isLatest)
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let second = try XCTUnwrap(nativeCards(in: controller).first)
        XCTAssertEqual(second.sequence, 1)
        XCTAssertTrue(second.isLatest)
    }
}
