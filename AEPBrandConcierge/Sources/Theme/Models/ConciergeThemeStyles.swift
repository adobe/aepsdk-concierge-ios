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
import UIKit

/// Border style configuration
public struct ConciergeBorderStyle: Codable {
    public var width: CGFloat
    public var radius: CGFloat
    public var color: CodableColor

    public init(
        width: CGFloat = 1,
        radius: CGFloat = 0,
        color: CodableColor = CodableColor(Color.primary)
    ) {
        self.width = width
        self.radius = radius
        self.color = color
    }
}

/// Welcome screen component style
public struct ConciergeWelcomeStyle: Codable {
    public var headingColor: CodableColor
    public var subheadingColor: CodableColor
    public var inputOrder: Int
    public var cardsOrder: Int

    public init(
        headingColor: CodableColor = CodableColor(Color.primary),
        subheadingColor: CodableColor = CodableColor(Color.secondary),
        inputOrder: Int = 3,
        cardsOrder: Int = 2
    ) {
        self.headingColor = headingColor
        self.subheadingColor = subheadingColor
        self.inputOrder = inputOrder
        self.cardsOrder = cardsOrder
    }
}

/// Input bar component style
public struct ConciergeInputBarStyle: Codable {
    public var background: CodableColor
    public var textColor: CodableColor
    public var border: ConciergeBorderStyle
    public var placeholderColor: CodableColor
    public var icon: ConciergeIconConfig?
    public var voiceEnabled: Bool

    public init(
        background: CodableColor = CodableColor(Color.white),
        textColor: CodableColor = CodableColor(Color.primary),
        border: ConciergeBorderStyle = ConciergeBorderStyle(),
        placeholderColor: CodableColor = CodableColor(Color.secondary),
        icon: ConciergeIconConfig? = nil,
        voiceEnabled: Bool = false
    ) {
        self.background = background
        self.textColor = textColor
        self.border = border
        self.placeholderColor = placeholderColor
        self.icon = icon
        self.voiceEnabled = voiceEnabled
    }
}

/// Chat message component style
public struct ConciergeChatMessageStyle: Codable {
    public var userBackground: CodableColor
    public var userText: CodableColor
    public var conciergeBackground: CodableColor
    public var conciergeText: CodableColor
    public var linkColor: CodableColor
    public var borderRadius: CGFloat
    public var padding: ConciergePadding
    public var maxWidth: CGFloat? // nil = no max width, value = max width in points

    public init(
        userBackground: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground)),
        userText: CodableColor = CodableColor(Color.primary),
        conciergeBackground: CodableColor = CodableColor(Color(UIColor.systemBackground)),
        conciergeText: CodableColor = CodableColor(Color.primary),
        linkColor: CodableColor = CodableColor(Color.accentColor),
        borderRadius: CGFloat = 10,
        padding: ConciergePadding = ConciergePadding(vertical: 8, horizontal: 16),
        maxWidth: CGFloat? = nil
    ) {
        self.userBackground = userBackground
        self.userText = userText
        self.conciergeBackground = conciergeBackground
        self.conciergeText = conciergeText
        self.linkColor = linkColor
        self.borderRadius = borderRadius
        self.padding = padding
        self.maxWidth = maxWidth
    }
}

/// Feedback component style
public struct ConciergeFeedbackStyle: Codable {
    public var iconButtonBackground: CodableColor
    public var iconButtonSizeDesktop: CGFloat
    public var containerGap: CGFloat
    public var positiveNotesEnabled: Bool
    public var negativeNotesEnabled: Bool

    public init(
        iconButtonBackground: CodableColor = CodableColor(Color.white),
        iconButtonSizeDesktop: CGFloat = 44,
        containerGap: CGFloat = 4,
        positiveNotesEnabled: Bool = true,
        negativeNotesEnabled: Bool = true
    ) {
        self.iconButtonBackground = iconButtonBackground
        self.iconButtonSizeDesktop = iconButtonSizeDesktop
        self.containerGap = containerGap
        self.positiveNotesEnabled = positiveNotesEnabled
        self.negativeNotesEnabled = negativeNotesEnabled
    }
}

/// Carousel component style
public struct ConciergeCarouselStyle: Codable {
    public var cardBorderRadius: CGFloat
    public var cardBoxShadow: ConciergeShadow
    public var cardClickAction: String

    public init(
        cardBorderRadius: CGFloat = 16,
        cardBoxShadow: ConciergeShadow = .none,
        cardClickAction: String = "openLink"
    ) {
        self.cardBorderRadius = cardBorderRadius
        self.cardBoxShadow = cardBoxShadow
        self.cardClickAction = cardClickAction
    }
}

/// Disclaimer component style
public struct ConciergeDisclaimerStyle: Codable {
    public var textColor: CodableColor
    public var fontSize: CGFloat
    public var fontWeight: CodableFontWeight

    public init(
        textColor: CodableColor = CodableColor(Color(UIColor.systemGray)),
        fontSize: CGFloat = 12,
        fontWeight: CodableFontWeight = .regular
    ) {
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
    }
}

/// Consolidated component styles
public struct ConciergeComponentStyles: Codable {
    public var welcome: ConciergeWelcomeStyle
    public var inputBar: ConciergeInputBarStyle
    public var chatMessage: ConciergeChatMessageStyle
    public var feedback: ConciergeFeedbackStyle
    public var carousel: ConciergeCarouselStyle
    public var disclaimer: ConciergeDisclaimerStyle

    public init(
        welcome: ConciergeWelcomeStyle = ConciergeWelcomeStyle(),
        inputBar: ConciergeInputBarStyle = ConciergeInputBarStyle(),
        chatMessage: ConciergeChatMessageStyle = ConciergeChatMessageStyle(),
        feedback: ConciergeFeedbackStyle = ConciergeFeedbackStyle(),
        carousel: ConciergeCarouselStyle = ConciergeCarouselStyle(),
        disclaimer: ConciergeDisclaimerStyle = ConciergeDisclaimerStyle()
    ) {
        self.welcome = welcome
        self.inputBar = inputBar
        self.chatMessage = chatMessage
        self.feedback = feedback
        self.carousel = carousel
        self.disclaimer = disclaimer
    }
}
