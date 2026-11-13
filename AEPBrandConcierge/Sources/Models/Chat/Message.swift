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
    public let id = UUID()
    private enum Content {
        case template(MessageTemplate)
        case nativeCard(cardId: String)
    }

    private let content: Content
    var template: MessageTemplate {
        guard case .template(let template) = content else {
            preconditionFailure("Native-card messages do not have a built-in template.")
        }
        return template
    }
    var nativeCardId: String? {
        guard case .nativeCard(let cardId) = content else { return nil }
        return cardId
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
    func chatMessageView(onCtaButtonTap: ((_ label: String, _ url: String) -> Void)? = nil) -> ChatMessageView {
        ChatMessageView(messageId: id, template: template, messageBody: messageBody, sources: sources, linkHints: linkHints, promptSuggestions: promptSuggestions, feedbackSentiment: feedbackSentiment, feedbackEligible: feedbackEligible, isStreamComplete: isStreamComplete, onSuggestionTap: nil, onCtaButtonTap: onCtaButtonTap)
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
