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

    public init(cardClickAction: String = "openLink") {
        self.cardClickAction = cardClickAction
    }
}

/// Input behavior configuration
public struct ConciergeInputBehavior: Codable {
    public var enableVoiceInput: Bool
    public var disableMultiline: Bool
    public var showAiChatIcon: ConciergeIconConfig?

    public init(
        enableVoiceInput: Bool = false,
        disableMultiline: Bool = true,
        showAiChatIcon: ConciergeIconConfig? = nil
    ) {
        self.enableVoiceInput = enableVoiceInput
        self.disableMultiline = disableMultiline
        self.showAiChatIcon = showAiChatIcon
    }
}

/// Icon configuration (SVG string or URL)
public struct ConciergeIconConfig: Codable {
    public var icon: String

    public init(icon: String = "") {
        self.icon = icon
    }
}

/// Chat behavior configuration
public struct ConciergeChatBehavior: Codable {
    public var messageAlignment: ConciergeTextAlignment
    public var messageWidth: CGFloat? // nil = no max width, value = max width in points

    private enum CodingKeys: String, CodingKey {
        case messageAlignment
        case messageWidth
    }

    public init(
        messageAlignment: ConciergeTextAlignment = .leading,
        messageWidth: CGFloat? = nil
    ) {
        self.messageAlignment = messageAlignment
        self.messageWidth = messageWidth
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
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageAlignment, forKey: .messageAlignment)
        if let width = messageWidth {
            try container.encode(width, forKey: .messageWidth)
        }
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

    public init(
        multimodalCarousel: ConciergeMultimodalCarouselBehavior = ConciergeMultimodalCarouselBehavior(),
        input: ConciergeInputBehavior = ConciergeInputBehavior(),
        chat: ConciergeChatBehavior = ConciergeChatBehavior(),
        privacyNotice: ConciergePrivacyNoticeBehavior = ConciergePrivacyNoticeBehavior()
    ) {
        self.multimodalCarousel = multimodalCarousel
        self.input = input
        self.chat = chat
        self.privacyNotice = privacyNotice
    }
}
