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

final class NativeCardTests: NativeCardTestCase {
    func testRegistryExactMatchingAndReplacement() {
        let type = "test.card.\(UUID().uuidString)"
        let first: ConciergeCardRenderer = { _, _, _ in AnyView(Text("first")) }
        let second: ConciergeCardRenderer = { _, _, _ in AnyView(Text("second")) }
        NativeCardRegistry.register(type: "", renderer: first)
        XCTAssertNil(NativeCardRegistry.registration(for: ""))
        NativeCardRegistry.register(type: type, renderer: first)
        XCTAssertNil(NativeCardRegistry.registration(for: type.uppercased()))
        let captured = NativeCardRegistry.registration(for: type)
        NativeCardRegistry.register(type: type, renderer: second)
        XCTAssertNotNil(captured)
        XCTAssertNotNil(NativeCardRegistry.registration(for: type))
    }

    @MainActor
    func testStateIsReplacedAndDisposedCardsIgnoreLateSaves() async {
        let card = NativeCard(element: [:], renderer: { _, _, _ in AnyView(EmptyView()) },
                              sessionId: "session", conversationId: "conversation", interactionId: "turn")
        XCTAssertNil(card.context["state"])
        XCTAssertEqual(card.context["interactionId"] as? String, "turn")
        let mutable = NSMutableDictionary(dictionary: ["value": "before", "null": NSNull()])
        await saveStateAndWait(["data": mutable], on: card)
        mutable["value"] = "after"
        XCTAssertEqual((card.state?["data"] as? [String: Any])?["value"] as? String, "before")
        XCTAssertTrue((card.state?["data"] as? [String: Any])?["null"] is NSNull)
        await saveStateAndWait(["next": 3], on: card)
        XCTAssertNil(card.state?["data"])
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        // Invalid saves are rejected before the main-actor hop, so nothing is queued to apply later.
        card.saveState(["invalid": Double.infinity])
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        let cycle = NSMutableDictionary()
        cycle["self"] = cycle
        card.saveState(["cycle": cycle])
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        card.dispose()
        card.applySavedState(["late": 1])
        XCTAssertTrue(card.isStale)
        XCTAssertNil(card.state)
    }

    @MainActor
    func testSaveStateFromAnyThreadIsAppliedOnTheMainActor() async {
        let card = NativeCard(element: [:], renderer: { _, _, _ in AnyView(EmptyView()) },
                              sessionId: nil, conversationId: nil, interactionId: nil)
        let applied = expectation(description: "Background save applied")
        var appliedOnMainThread = false
        let observation = card.$state.dropFirst().sink { _ in
            appliedOnMainThread = Thread.isMainThread
            applied.fulfill()
        }
        defer { observation.cancel() }
        DispatchQueue.global().async { card.saveState(["origin": "background"]) }
        await fulfillment(of: [applied], timeout: 2)
        XCTAssertTrue(appliedOnMainThread)
        XCTAssertEqual(card.state?["origin"] as? String, "background")
    }
}
