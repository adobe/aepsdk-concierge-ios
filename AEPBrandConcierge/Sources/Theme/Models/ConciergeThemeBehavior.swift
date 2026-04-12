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
import AEPServices

// MARK: - Behavior Configuration Types

/// Multimodal carousel behavior configuration
public struct ConciergeMultimodalCarouselBehavior: Codable {
    public var cardClickAction: String
    public var carouselStyle: CarouselStyle?

    public init(
        cardClickAction: String = "openLink",
        carouselStyle: CarouselStyle = .paged
    ) {
        self.cardClickAction = cardClickAction
        self.carouselStyle = carouselStyle
    }
}

/// Input behavior configuration
public struct ConciergeInputBehavior: Codable {
    public var enableVoiceInput: Bool
    public var disableMultiline: Bool
    public var showAiChatIcon: ConciergeIconConfig?
    public var sendButtonStyle: String
    /// RMS level above which audio is treated as speech (not silence). Typical range roughly `0.01`–`0.05`.
    public var silenceThreshold: Float
    /// Seconds of continuous silence after speech before auto-stopping capture.
    public var silenceDuration: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case enableVoiceInput
        case disableMultiline
        case showAiChatIcon
        case sendButtonStyle
        case silenceThreshold
        case silenceDuration
    }

    public init(
        enableVoiceInput: Bool = false,
        disableMultiline: Bool = true,
        showAiChatIcon: ConciergeIconConfig? = nil,
        sendButtonStyle: String = "default",
        silenceThreshold: Float = 0.02,
        silenceDuration: TimeInterval = 2.0
    ) {
        self.enableVoiceInput = enableVoiceInput
        self.disableMultiline = disableMultiline
        self.showAiChatIcon = showAiChatIcon
        self.sendButtonStyle = sendButtonStyle
        self.silenceThreshold = silenceThreshold
        self.silenceDuration = silenceDuration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableVoiceInput = try container.decodeIfPresent(Bool.self, forKey: .enableVoiceInput) ?? false
        disableMultiline = try container.decodeIfPresent(Bool.self, forKey: .disableMultiline) ?? true
        showAiChatIcon = try container.decodeIfPresent(ConciergeIconConfig.self, forKey: .showAiChatIcon)
        sendButtonStyle = try container.decodeIfPresent(String.self, forKey: .sendButtonStyle) ?? "default"
        silenceThreshold = try container.decodeIfPresent(Float.self, forKey: .silenceThreshold) ?? 0.02
        if let duration = try container.decodeIfPresent(TimeInterval.self, forKey: .silenceDuration) {
            silenceDuration = duration
        } else {
            silenceDuration = 2.0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enableVoiceInput, forKey: .enableVoiceInput)
        try container.encode(disableMultiline, forKey: .disableMultiline)
        try container.encodeIfPresent(showAiChatIcon, forKey: .showAiChatIcon)
        try container.encode(sendButtonStyle, forKey: .sendButtonStyle)
        try container.encode(silenceThreshold, forKey: .silenceThreshold)
        try container.encode(silenceDuration, forKey: .silenceDuration)
    }
}

/// Welcome card behavior configuration
public struct ConciergeWelcomeCardBehavior: Codable {
    public var closeButtonAlignment: String
    public var promptFullWidth: Bool
    public var promptMaxLines: Int
    public var contentAlignment: String

    public init(
        closeButtonAlignment: String = "end",
        promptFullWidth: Bool = true,
        promptMaxLines: Int = 3,
        contentAlignment: String = "top"
    ) {
        self.closeButtonAlignment = closeButtonAlignment
        self.promptFullWidth = promptFullWidth
        self.promptMaxLines = promptMaxLines
        self.contentAlignment = contentAlignment
    }
}

/// Feedback behavior configuration
/// To-do: update vars to enums or bools where applicable
public struct ConciergeFeedbackBehavior: Codable {
    /// Presentation for the feedback flow. Matches concierge extension theme JSON:
    /// - `"modal"` — centered dialog with blurred backdrop (`FeedbackOverlayView` modal layout).
    /// - `"action"` — action sheet-style layout with drag affordance.
    public var displayMode: String
    public var thumbsPlacement: String

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case thumbsPlacement
    }

    public init(
        displayMode: String = "modal",
        thumbsPlacement: String = "inline"
    ) {
        self.displayMode = displayMode
        self.thumbsPlacement = thumbsPlacement
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayMode = try container.decodeIfPresent(String.self, forKey: .displayMode) ?? "modal"
        thumbsPlacement = try container.decodeIfPresent(String.self, forKey: .thumbsPlacement) ?? "inline"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(thumbsPlacement, forKey: .thumbsPlacement)
    }
}

/// Citations behavior configuration
public struct ConciergeCitationsBehavior: Codable {
    public var showLinkIcon: Bool

    public init(showLinkIcon: Bool = false) {
        self.showLinkIcon = showLinkIcon
    }
}

/// Icon configuration (SVG string or URL)
public struct ConciergeIconConfig: Codable {
    public var icon: String

    public init(icon: String = "") {
        self.icon = icon
    }
}

/// Shape style for the user message bubble.
public enum UserMessageBubbleStyle: String, Codable {
    /// Fully rounded corners on all sides (default).
    case `default` = "default"
    /// Speech-bubble style with a squared-off bottom-right corner.
    case balloon = "balloon"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UserMessageBubbleStyle(rawValue: raw.lowercased()) ?? .default
    }
}

/// Chat behavior configuration
public struct ConciergeChatBehavior: Codable {
    public var messageAlignment: ConciergeTextAlignment
    public var messageWidth: CGFloat? // nil = no max width, value = max width in points
    public var userMessageBubbleStyle: UserMessageBubbleStyle

    private enum CodingKeys: String, CodingKey {
        case messageAlignment
        case messageWidth
        case userMessageBubbleStyle
    }

    public init(
        messageAlignment: ConciergeTextAlignment = .leading,
        messageWidth: CGFloat? = nil,
        userMessageBubbleStyle: UserMessageBubbleStyle = .default
    ) {
        self.messageAlignment = messageAlignment
        self.messageWidth = messageWidth
        self.userMessageBubbleStyle = userMessageBubbleStyle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageAlignment = try container.decodeIfPresent(ConciergeTextAlignment.self, forKey: .messageAlignment) ?? .leading

        if let widthString = try? container.decode(String.self, forKey: .messageWidth) {
            messageWidth = CSSValueConverter.parseWidth(widthString)
        } else if let widthNumber = try? container.decodeIfPresent(CGFloat.self, forKey: .messageWidth) {
            messageWidth = widthNumber
        } else {
            messageWidth = nil
        }

        userMessageBubbleStyle = try container.decodeIfPresent(UserMessageBubbleStyle.self, forKey: .userMessageBubbleStyle) ?? .default
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageAlignment, forKey: .messageAlignment)
        if let width = messageWidth {
            try container.encode(width, forKey: .messageWidth)
        }
        if userMessageBubbleStyle != .default {
            try container.encode(userMessageBubbleStyle, forKey: .userMessageBubbleStyle)
        }
    }
}

/// Rendering style for product cards
public enum ProductCardStyle: String, Codable {
    /// Image, description text, and primary/secondary action buttons
    case actionButton
    /// Image, optional badge, title, subtitle, price; entire card is tappable
    case productDetail
}

/// Scroll behavior for product card carousels
public enum CarouselStyle: String, Codable {
    /// Paged items with prev/next buttons and page indicator dots
    case paged
    /// Continuous horizontal scroll with freely scrollable cards
    case scroll
}

/// Horizontal alignment of product cards within their container.
public enum CardsAlignment: String, Codable {
    case start
    case center
    case end
}

/// Product card behavior configuration
public struct ConciergeProductCardBehavior: Codable {
    public var cardStyle: ProductCardStyle
    /// Horizontal alignment of product cards within their container. Default is `.center`.
    public var cardsAlignment: CardsAlignment

    public init(
        cardStyle: ProductCardStyle = .actionButton,
        cardsAlignment: CardsAlignment = .center
    ) {
        self.cardStyle = cardStyle
        self.cardsAlignment = cardsAlignment
    }
}

/// Prompt suggestions behavior configuration
public struct ConciergePromptSuggestionsBehavior: Codable {
    /// Max lines of text per chip before ellipsis. Default: `1`.
    public var itemMaxLines: Int
    /// Show a customizable "Suggestions" header label above the chips. Default: `false`.
    public var showHeader: Bool
    /// Align chips to the inner content edge of the bot message bubble. Default: `false`.
    public var alignToMessage: Bool

    private enum CodingKeys: String, CodingKey {
        case itemMaxLines
        case showHeader
        case alignToMessage
    }

    public init(
        itemMaxLines: Int = 1,
        showHeader: Bool = false,
        alignToMessage: Bool = false
    ) {
        self.itemMaxLines = itemMaxLines
        self.showHeader = showHeader
        self.alignToMessage = alignToMessage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemMaxLines = try container.decodeIfPresent(Int.self, forKey: .itemMaxLines) ?? 1
        showHeader = try container.decodeIfPresent(Bool.self, forKey: .showHeader) ?? false
        alignToMessage = try container.decodeIfPresent(Bool.self, forKey: .alignToMessage) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemMaxLines, forKey: .itemMaxLines)
        try container.encode(showHeader, forKey: .showHeader)
        try container.encode(alignToMessage, forKey: .alignToMessage)
    }
}

/// Privacy notice configuration
public struct ConciergePrivacyNoticeBehavior: Codable {
    public var title: String
    public var text: String

    public init(
        title: String = "Privacy Notice",
        text: String = "Privact notice text."
    ) {
        self.title = title
        self.text = text
    }
}

/// Consolidated behavior configuration
public struct ConciergeBehaviorConfig: Codable {
    public var multimodalCarousel: ConciergeMultimodalCarouselBehavior
    public var input: ConciergeInputBehavior
    public var chat: ConciergeChatBehavior
    public var privacyNotice: ConciergePrivacyNoticeBehavior
    public var productCard: ConciergeProductCardBehavior?
    public var welcomeCard: ConciergeWelcomeCardBehavior?
    public var feedback: ConciergeFeedbackBehavior?
    public var citations: ConciergeCitationsBehavior?
    public var promptSuggestions: ConciergePromptSuggestionsBehavior?

    private enum CodingKeys: String, CodingKey {
        case multimodalCarousel
        case input
        case chat
        case privacyNotice
        case productCard
        case welcomeCard
        case feedback
        case citations
        case promptSuggestions
    }

    public init(
        multimodalCarousel: ConciergeMultimodalCarouselBehavior = ConciergeMultimodalCarouselBehavior(),
        input: ConciergeInputBehavior = ConciergeInputBehavior(),
        chat: ConciergeChatBehavior = ConciergeChatBehavior(),
        privacyNotice: ConciergePrivacyNoticeBehavior = ConciergePrivacyNoticeBehavior(),
        productCard: ConciergeProductCardBehavior = ConciergeProductCardBehavior(),
        welcomeCard: ConciergeWelcomeCardBehavior? = nil,
        feedback: ConciergeFeedbackBehavior? = nil,
        citations: ConciergeCitationsBehavior? = nil,
        promptSuggestions: ConciergePromptSuggestionsBehavior? = nil
    ) {
        self.multimodalCarousel = multimodalCarousel
        self.input = input
        self.chat = chat
        self.privacyNotice = privacyNotice
        self.productCard = productCard
        self.welcomeCard = welcomeCard
        self.feedback = feedback
        self.citations = citations
        self.promptSuggestions = promptSuggestions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        multimodalCarousel = try container.decodeIfPresent(ConciergeMultimodalCarouselBehavior.self, forKey: .multimodalCarousel)
            ?? ConciergeMultimodalCarouselBehavior()
        input = try container.decodeIfPresent(ConciergeInputBehavior.self, forKey: .input) ?? ConciergeInputBehavior()
        chat = try container.decodeIfPresent(ConciergeChatBehavior.self, forKey: .chat) ?? ConciergeChatBehavior()
        privacyNotice = try container.decodeIfPresent(ConciergePrivacyNoticeBehavior.self, forKey: .privacyNotice)
            ?? ConciergePrivacyNoticeBehavior()
        if container.contains(.productCard) {
            productCard = try container.decodeIfPresent(ConciergeProductCardBehavior.self, forKey: .productCard)
        } else {
            productCard = ConciergeProductCardBehavior()
        }
        welcomeCard = try container.decodeIfPresent(ConciergeWelcomeCardBehavior.self, forKey: .welcomeCard)
        feedback = try container.decodeIfPresent(ConciergeFeedbackBehavior.self, forKey: .feedback)
        citations = try container.decodeIfPresent(ConciergeCitationsBehavior.self, forKey: .citations)
        promptSuggestions = try container.decodeIfPresent(ConciergePromptSuggestionsBehavior.self, forKey: .promptSuggestions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(multimodalCarousel, forKey: .multimodalCarousel)
        try container.encode(input, forKey: .input)
        try container.encode(chat, forKey: .chat)
        try container.encode(privacyNotice, forKey: .privacyNotice)
        try container.encodeIfPresent(productCard, forKey: .productCard)
        try container.encodeIfPresent(welcomeCard, forKey: .welcomeCard)
        try container.encodeIfPresent(feedback, forKey: .feedback)
        try container.encodeIfPresent(citations, forKey: .citations)
        try container.encodeIfPresent(promptSuggestions, forKey: .promptSuggestions)
    }
}
