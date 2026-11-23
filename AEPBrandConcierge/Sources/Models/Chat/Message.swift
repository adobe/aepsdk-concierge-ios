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

/// Represents a single message in the chat conversation.
public struct Message: Identifiable {
    /// What a transcript row draws. Callers switch on it exhaustively, so every row kind - including
    /// one added later - has to be handled where it's read, rather than assumed to be built-in.
    enum Content {
        /// A built-in row the SDK draws with `ChatMessageView`.
        case template(MessageTemplate)
        /// An app-rendered native card, resolved from the chat's `NativeCardStore` by its ID.
        case nativeCard(cardId: String)
    }

    public let id = UUID()
    /// Transcript navigation identity, independent of the transport attempt or card occurrence.
    var turnId: UUID?

    func inTurn(_ turnId: UUID) -> Message {
        var message = self
        message.turnId = turnId
        return message
    }

    let content: Content
    var nativeCardId: String? {
        guard case .nativeCard(let cardId) = content else { return nil }
        return cardId
    }

    /// Welcome content is shown only until the conversation starts. Native cards never are.
    var isWelcomeContent: Bool {
        switch content {
        case .template(.welcomeHeader), .template(.welcomePromptSuggestion):
            return true
        case .template, .nativeCard:
            return false
        }
    }
    var payload: ConversationPayload?
    var shouldSpeakMessage = false
    var messageBody: String?
    var sources: [Source]?
    var linkHints: [LinkHint]?
    var promptSuggestions: [String]?
    var feedbackSentiment: FeedbackSentiment?
    var feedbackEligible: Bool = false
    var isStreamComplete: Bool = false

    public static let divider = Message(template: .divider)

    init(nativeCardId: String, promptSuggestions: [String]? = nil) {
        content = .nativeCard(cardId: nativeCardId)
        payload = nil
        sources = nil
        linkHints = nil
        self.promptSuggestions = promptSuggestions
        feedbackSentiment = nil
    }

    /// - Parameter onCtaButtonTap: forwarded into the constructed `ChatMessageView` so CTA taps on
    ///   cards/buttons rendered inside a carousel (see `CarouselGroupView`) still track, matching
    ///   messages rendered directly by `MessageListView`.
    /// - Returns: The built-in view for this message, or `nil` for a native card row, which only
    ///   `NativeCardView` can draw.
    func chatMessageView(onCtaButtonTap: ((_ label: String, _ url: String) -> Void)? = nil) -> ChatMessageView? {
        switch content {
        case .template(let template):
            return ChatMessageView(messageId: id, template: template, messageBody: messageBody, sources: sources, linkHints: linkHints, promptSuggestions: promptSuggestions, feedbackSentiment: feedbackSentiment, feedbackEligible: feedbackEligible, isStreamComplete: isStreamComplete, onSuggestionTap: nil, onCtaButtonTap: onCtaButtonTap)
        case .nativeCard:
            return nil
        }
    }

    public init(template: MessageTemplate, shouldSpeakMessage: Bool = false, messageBody: String? = nil, sources: [Source]? = nil, linkHints: [LinkHint]? = nil, promptSuggestions: [String]? = nil, feedbackSentiment: FeedbackSentiment? = nil, feedbackEligible: Bool = false, payload: ConversationPayload? = nil) {
        content = .template(template)
        self.payload = payload
        self.shouldSpeakMessage = shouldSpeakMessage
        self.messageBody = messageBody
        self.sources = sources
        self.linkHints = linkHints
        self.promptSuggestions = promptSuggestions
        self.feedbackSentiment = feedbackSentiment
        self.feedbackEligible = feedbackEligible
    }
}
