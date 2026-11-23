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

/// Visual coverage for transcript contents. The measurable turn padding and one-shot navigation
/// are checked separately; a fixed-frame snapshot does not measure the scrollable range.
final class WhiteSpaceReservationSnapshotTests: XCTestCase {
    /// Suggestion chips follow the response without a spacer between them.
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

    /// An in-flight reply still renders below its prompt.
    @MainActor
    func test_activeResponse_fillsRemainingHeight() {
        let controller = ChatController(configuration: ConciergeConfiguration(), speechCapturer: nil, speaker: nil)
        controller.messages = [
            Message(template: .basic(isUserMessage: true), messageBody: "What size should I get?"),
            Message(template: .basic(isUserMessage: false), messageBody: "Here are a few")
        ]
        controller.setChatStateForTesting(.processing)

        let view = ChatView(controller: controller)
            .frame(width: 390, height: 844)
            .conciergeTheme(ConciergeThemeLoader.default())

        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844)))
    }

    /// A completed response with no trailing suggestions still renders below its prompt.
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

    /// An empty response replaces its placeholder with the apology.
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

    /// A transcript longer than a screen still lays out its messages.
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

    /// A short transcript at an accessibility Dynamic Type size.
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
