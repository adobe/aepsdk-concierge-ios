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

import SwiftUI
import XCTest

@testable import AEPBrandConcierge

/// Direct logic coverage for `MessageListView.shouldFillRemainingHeight(at:)`.
///
/// A snapshot alone can't detect an inverted or broken condition here: `.frame(minHeight:)` only
/// affects the ScrollView's total (scrollable) content height, which is invisible in a single
/// fixed-frame capture taken at the default scroll offset. These tests exercise the boolean
/// directly instead, and — unlike the snapshot tests in `WhiteSpaceReservationSnapshotTests` —
/// actually run in CI, since they involve no rendering.
@MainActor
final class MessageListViewShouldFillRemainingHeightTests: XCTestCase {
    private func makeView(messages: [Message], chatState: ChatState) -> MessageListView {
        MessageListView(messages: messages, chatState: chatState, isInputFocused: .constant(false), onSpeak: { _ in })
    }

    private func makeView(messages: [Message], chatState: ChatState, anchorId: UUID?) -> MessageListView {
        MessageListView(messages: messages,
                        userMessageToScrollId: anchorId,
                        chatState: chatState,
                        isInputFocused: .constant(false),
                        onSpeak: { _ in })
    }

    /// A `sendDataHandoff(...)` local message is an *agent* message - the user never typed it - so
    /// the "last user message sits directly above" test can't see it. Without the filler the
    /// anchor has nothing to scroll against and the response lands below the fold.
    func test_handoffLocalMessageAnchor_returnsTrue() {
        let localMessage = Message(template: .basic(isUserMessage: false), messageBody: "Your order is confirmed!")
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "Show me headphones"),
                Message(template: .basic(isUserMessage: false), messageBody: "Here are a couple of products:"),
                Message(template: .carouselGroup([]), messageBody: nil),
                localMessage,
                Message(template: .basic(isUserMessage: false), messageBody: "")
            ],
            chatState: .processing,
            anchorId: localMessage.id
        )
        XCTAssertTrue(view.shouldFillRemainingHeight(at: 4))
    }

    /// A handoff with no local message anchors on the streaming placeholder itself.
    func test_handoffWithNoLocalMessage_placeholderIsItsOwnAnchor_returnsTrue() {
        let placeholder = Message(template: .basic(isUserMessage: false), messageBody: "")
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "Show me headphones"),
                Message(template: .carouselGroup([]), messageBody: nil),
                placeholder
            ],
            chatState: .processing,
            anchorId: placeholder.id
        )
        XCTAssertTrue(view.shouldFillRemainingHeight(at: 2))
    }

    /// The anchor only counts for the turn that's actually in flight.
    func test_handoffLocalMessageAnchor_idle_returnsFalse() {
        let localMessage = Message(template: .basic(isUserMessage: false), messageBody: "Your order is confirmed!")
        let view = makeView(
            messages: [
                localMessage,
                Message(template: .basic(isUserMessage: false), messageBody: "Great pick!")
            ],
            chatState: .idle,
            anchorId: localMessage.id
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 1))
    }

    /// A stale anchor from a previous turn must not resurrect the filler for a settled message.
    func test_staleAnchorFromEarlierTurn_returnsFalse() {
        let oldAnchor = Message(template: .basic(isUserMessage: false), messageBody: "Your order is confirmed!")
        let view = makeView(
            messages: [
                oldAnchor,
                Message(template: .basic(isUserMessage: false), messageBody: "Great pick!"),
                Message(template: .carouselGroup([]), messageBody: nil),
                Message(template: .basic(isUserMessage: false), messageBody: "Anything else?")
            ],
            chatState: .processing,
            anchorId: oldAnchor.id
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 3))
    }

    func test_activeResponse_returnsTrue() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Here are a few")
            ],
            chatState: .processing
        )
        XCTAssertTrue(view.shouldFillRemainingHeight(at: 1))
    }

    func test_sameShape_idle_returnsFalse() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Go with a 10.")
            ],
            chatState: .idle
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 1))
    }

    /// `.error` is non-idle too — must not be treated as "in flight" even though it isn't `.idle`.
    func test_sameShape_error_returnsFalse() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Go with a 10.")
            ],
            chatState: .error(.networkFailure)
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 1))
    }

    func test_processingWithTrailingSuggestions_responseIsNoLongerLast_returnsFalse() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Here are a few sizes:"),
                Message(template: .promptSuggestion(text: "8.5"))
            ],
            chatState: .processing
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 1), "the response is no longer the last message")
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 2), "suggestion chips are never eligible")
    }

    func test_processing_lastMessageIsUsersOwn_returnsFalse() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?")
            ],
            chatState: .processing
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 0))
    }

    /// Response is last, but a prior assistant message sits between it and the user's message —
    /// `lastUserIndex == index - 1` must fail.
    func test_processing_responseNotImmediatelyAfterUserMessage_returnsFalse() {
        let view = makeView(
            messages: [
                Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Let me check..."),
                Message(template: .basic(isUserMessage: false), messageBody: "Here are a few")
            ],
            chatState: .processing
        )
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 2))
    }

    func test_emptyMessages_returnsFalse() {
        let view = makeView(messages: [], chatState: .processing)
        XCTAssertFalse(view.shouldFillRemainingHeight(at: 0))
    }
}
