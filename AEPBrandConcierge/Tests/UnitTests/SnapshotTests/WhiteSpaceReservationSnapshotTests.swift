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

import SnapshotTesting
import SwiftUI
import XCTest

@testable import AEPBrandConcierge

/// Regression coverage for `MessageListView.shouldFillRemainingHeight(at:)`.
///
/// The agent's response bubble fills the remaining screen height only while a turn is actively in
/// flight (`chatState == .processing`) AND it's the last thing on screen, immediately following the
/// latest user message. That's what lets it "fill in" below the user's message while streaming.
/// The moment anything is appended after it — suggestions, cards, a new user message — or the turn
/// settles back to idle, this must stop applying, or conversations are left with a permanent empty
/// gap below the last message.
final class WhiteSpaceReservationSnapshotTests: XCTestCase {
    /// Response already has trailing suggestion chips appended (turn settled): the response bubble
    /// is no longer the last message, so it must NOT fill remaining height, and no empty gap should
    /// appear between the suggestions and the composer.
    @MainActor
    func test_settledConversationWithSuggestions_doesNotFillRemainingHeight() {
        let view = ChatView(messages: [
            Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here are a few sizes to consider:"),
            Message(template: .promptSuggestion(text: "8.5")),
            Message(template: .promptSuggestion(text: "10.0")),
            Message(template: .promptSuggestion(text: "11.0"))
        ])
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// Response is the last message, immediately following the latest user message, with nothing
    /// appended after it yet, AND a turn is actively in flight (`chatState == .processing`): it must
    /// fill remaining height, preserving the live-streaming "fills the screen" effect. Uses a real
    /// `ChatController` (not the `ChatView(messages:)` convenience init) because that init's internal
    /// controller defaults to `chatState == .idle`, which would no longer fill given the fix below.
    @MainActor
    func test_activeResponse_fillsRemainingHeight() {
        let controller = ChatController(configuration: ConciergeConfiguration(), speechCapturer: nil, speaker: nil)
        controller.messages = [
            Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here are a few")
        ]
        controller.chatState = .processing

        let view = ChatView(controller: controller)
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// A completed response with no trailing suggestions (e.g. reopening a past conversation whose
    /// last turn had no suggestions) is, structurally, "the last message immediately following the
    /// last user message" — same shape as the active case above. Without the `chatState` gate this
    /// used to still fill remaining height even though nothing is in progress; now that `chatState`
    /// is required to be non-idle, it correctly does not.
    @MainActor
    func test_completedConversationWithoutSuggestions_doesNotFillRemainingHeight() {
        let view = ChatView(messages: [
            Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
            Message(template: .basic(isUserMessage: false), messageBody: "Go with a 10.")
        ])
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// Response ends in a product card (no suggestions): the response text is no longer the last
    /// message once the card is appended, so it must NOT fill remaining height — matching
    /// `ChatController.renderMultimodalElements`, which appends cards as their own message.
    @MainActor
    func test_responseWithProductCardOnly_doesNotFillRemainingHeight() {
        let view = ChatView(messages: [
            Message(template: .basic(isUserMessage: true), messageBody: "Show me running shoes"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here's a great option:"),
            Message(template: .productCard(Self.sampleCard))
        ])
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// Response ends in a product card followed by suggestion chips: neither the response text nor
    /// the card is last, so neither should fill remaining height.
    @MainActor
    func test_responseWithProductCardAndSuggestions_doesNotFillRemainingHeight() {
        let view = ChatView(messages: [
            Message(template: .basic(isUserMessage: true), messageBody: "Show me running shoes"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here's a great option:"),
            Message(template: .productCard(Self.sampleCard)),
            Message(template: .promptSuggestion(text: "Show more")),
            Message(template: .promptSuggestion(text: "Different color"))
        ])
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// A genuinely empty response (no text, no elements) drives ChatController through its real
    /// error-fallback path (`ChatController.swift`, the `accumulatedContent.isEmpty &&
    /// latestElements.isEmpty` branch), which appends a plain `.basic(isUserMessage: false)` apology
    /// message with nothing after it — structurally identical to an in-progress response (last
    /// message, directly follows the user's message). `clearState()` (which sets `chatState =
    /// .idle`) runs in the same synchronous block as appending the message, so both land in the
    /// same SwiftUI render — no flicker, correctly no-fill from the first frame.
    @MainActor
    func test_emptyResponseFallback_doesNotFillRemainingHeight() async {
        let mockService = MockChatService(configuration: ConciergeConfiguration())
        mockService.plannedChunks = []
        mockService.plannedError = nil

        let controller = ChatController(configuration: nil, chatService: mockService, speechCapturer: nil, speaker: nil)
        controller.applyTextChange("What size should I get?")
        controller.sendMessage(isUser: true)

        // ChatController's completion handler runs inside `Task { @MainActor in ... }`, which is
        // scheduled rather than run synchronously even though we're already on the main actor —
        // yield until it's had a chance to execute.
        for _ in 0..<50 where controller.chatState != .idle {
            await Task.yield()
        }

        XCTAssertEqual(controller.messages.count, 2, "Expected [user message, fallback apology message]")
        XCTAssertEqual(controller.chatState, .idle)

        let view = ChatView(controller: controller)
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// A conversation long enough to exceed one screen renders and scrolls without breaking. Ends in
    /// the same `[user, agentText]` shape as `test_completedConversationWithoutSuggestions_...`
    /// above, so this only stays gap-free because `chatState == .idle` here too — conversation
    /// length itself has no bearing on `shouldFillRemainingHeight`, only the tail shape and chatState.
    @MainActor
    func test_longSettledConversation_rendersWithoutBreaking() {
        var messages: [Message] = []
        for i in 1...8 {
            messages.append(Message(template: .basic(isUserMessage: true), messageBody: "Question number \(i)?"))
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: "Answer number \(i), with enough text to wrap across a couple of lines in the bubble."))
        }

        let view = ChatView(messages: messages)
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// Short settled conversation under an accessibility-large Dynamic Type size: confirms the fix
    /// doesn't clip or overlap content when the composer/header grow taller than the default theme
    /// assumes (`messageBlockerHeight` is a fixed constant, not Dynamic-Type-aware).
    @MainActor
    func test_settledConversationWithSuggestions_accessibilityDynamicType() {
        let view = ChatView(messages: [
            Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here are a few sizes to consider:"),
            Message(template: .promptSuggestion(text: "8.5")),
            Message(template: .promptSuggestion(text: "10.0")),
            Message(template: .promptSuggestion(text: "11.0"))
        ])
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    private static let sampleCard = ProductCardData(
        imageSource: .remote(nil),
        title: "Running Shoes",
        subtitle: nil,
        price: "$129.99",
        wasPrice: nil,
        badge: nil,
        destinationURL: nil,
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: nil,
        imageHeight: nil
    )
}
