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
@testable import AEPBrandConcierge

/// Base for native card suites. Renderer registrations are process-wide, so every test starts and ends
/// with none; otherwise one suite's registrations would change how another suite's responses decode.
class NativeCardTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        NativeCardRegistry.resetForTesting()
    }

    override func tearDown() {
        NativeCardRegistry.resetForTesting()
        super.tearDown()
    }

    func streamPayload(state: String, elements: [MultimodalElement]? = nil,
                       message: String = "", suggestions: [String]? = nil) -> ConversationPayload {
        ConversationPayload(conversationId: "conversation", interactionId: "interaction", request: nil,
            response: ConversationResponse(message: message, promptSuggestions: suggestions,
                multimodalElements: elements.map { MultimodalElements(elements: $0) },
                sources: nil, linkHints: nil, state: nil, feedback: nil),
            state: state, key: nil, value: nil, maxAge: nil)
    }

    /// Saves through the card's any-thread `saveState` and waits until its main-actor hop applies the
    /// copy, so tests never depend on when that hop is scheduled.
    @MainActor
    func saveStateAndWait(_ state: [String: Any], on card: NativeCard) async {
        let applied = expectation(description: "Saved state applied")
        let observation = card.$state.dropFirst().sink { _ in applied.fulfill() }
        card.saveState(state)
        await fulfillment(of: [applied], timeout: 2)
        observation.cancel()
    }

    /// The live cards behind `messages`, resolved through `store` the way `NativeCardView` does.
    @MainActor
    func nativeCards(in messages: [Message], store: NativeCardStore) -> [NativeCard] {
        messages.compactMap { message in
            if case .nativeCard(let cardId) = message.template { return store.card(withId: cardId) }
            return nil
        }
    }

    @MainActor
    func nativeCards(in controller: ChatController) -> [NativeCard] {
        nativeCards(in: controller.messages, store: controller.nativeCards)
    }

    /// The live card in `controller`'s row at `index`, or `nil` when that row isn't a native card.
    @MainActor
    func nativeCard(at index: Int, in controller: ChatController) -> NativeCard? {
        guard controller.messages.indices.contains(index),
              case .nativeCard(let cardId) = controller.messages[index].template else { return nil }
        return controller.nativeCards.card(withId: cardId)
    }
}
