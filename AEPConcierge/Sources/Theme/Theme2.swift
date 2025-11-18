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
import AEPServices

// MARK: - Theme Configuration Types

/// Metadata information about the theme configuration
public struct ConciergeThemeMetadata: Codable {
    public var brandName: String = ""
    public var version: String = "0.0.0"
    public var language: String = "en-US"
    public var namespace: String = "brand-concierge"
    
    private enum CodingKeys: String, CodingKey {
        case brandName
        case version
        case language
        case namespace
    }
    
    public init(
        brandName: String = "",
        version: String = "0.0.0",
        language: String = "en-US",
        namespace: String = "brand-concierge"
    ) {
        self.brandName = brandName
        self.version = version
        self.language = language
        self.namespace = namespace
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brandName = try container.decodeIfPresent(String.self, forKey: .brandName) ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "0.0.0"
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en-US"
        namespace = try container.decodeIfPresent(String.self, forKey: .namespace) ?? "brand-concierge"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brandName, forKey: .brandName)
        try container.encode(version, forKey: .version)
        try container.encode(language, forKey: .language)
        try container.encode(namespace, forKey: .namespace)
    }
}

/// Multimodal carousel behavior configuration
public struct ConciergeMultimodalCarouselBehavior: Codable {
    public var cardClickAction: String = "openLink"
    
    public init(cardClickAction: String = "openLink") {
        self.cardClickAction = cardClickAction
    }
}

/// Input behavior configuration
public struct ConciergeInputBehavior: Codable {
    public var enableVoiceInput: Bool = false
    public var disableMultiline: Bool = true
    public var showAiChatIcon: ConciergeIconConfig? = nil
    
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
    public var icon: String = ""
    
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
    public var title: String = "Privacy Notice"
    public var text: String = "Privact notice text."
    
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
    public var multimodalCarousel: ConciergeMultimodalCarouselBehavior = ConciergeMultimodalCarouselBehavior()
    public var input: ConciergeInputBehavior = ConciergeInputBehavior()
    public var chat: ConciergeChatBehavior = ConciergeChatBehavior()
    public var privacyNotice: ConciergePrivacyNoticeBehavior = ConciergePrivacyNoticeBehavior()
    
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

/// Disclaimer configuration with text and links
public struct ConciergeDisclaimer: Codable {
    public var text: String = "AI responses may be inaccurate. Check answers and sources. {Terms}"
    public var links: [ConciergeDisclaimerLink] = []
    
    public init(
        text: String = "AI responses may be inaccurate. Check answers and sources. {Terms}",
        links: [ConciergeDisclaimerLink] = []
    ) {
        self.text = text
        self.links = links
    }
}

/// Disclaimer link configuration
public struct ConciergeDisclaimerLink: Codable {
    public var text: String = ""
    public var url: String = ""
    
    public init(text: String = "", url: String = "") {
        self.text = text
        self.url = url
    }
}

/// Typography configuration (font families, sizes, line heights, weights)
public struct ConciergeTypography: Codable {
    /// Font family name (ex: "MarkerFelt-Thin")
    /// Expects a single font name. If empty or not provided, uses system font.
    public var fontFamily: String = ""
    public var fontSize: CGFloat = 16
    public var lineHeight: CGFloat = 1.75
    public var fontWeight: CodableFontWeight = .regular
    
    public init(
        fontFamily: String = "",
        fontSize: CGFloat = 16,
        lineHeight: CGFloat = 1.75,
        fontWeight: CodableFontWeight = .regular
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.fontWeight = fontWeight
    }
}

/// Surface color tokens
public struct ConciergeSurfaceColors: Codable {
    public var mainContainerBackground: CodableColor = CodableColor(Color(UIColor.systemBackground))
    public var mainContainerBottomBackground: CodableColor = CodableColor(Color(UIColor.systemBackground))
    public var messageBlockerBackground: CodableColor = CodableColor(Color(UIColor.systemBackground))
    public var light: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground))
    public var dark: CodableColor = CodableColor(Color(UIColor.systemBackground))
    
    public init(
        mainContainerBackground: CodableColor = CodableColor(Color(UIColor.systemBackground)),
        mainContainerBottomBackground: CodableColor = CodableColor(Color(UIColor.systemBackground)),
        messageBlockerBackground: CodableColor = CodableColor(Color(UIColor.systemBackground)),
        light: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground)),
        dark: CodableColor = CodableColor(Color(UIColor.systemBackground))
    ) {
        self.mainContainerBackground = mainContainerBackground
        self.mainContainerBottomBackground = mainContainerBottomBackground
        self.messageBlockerBackground = messageBlockerBackground
        self.light = light
        self.dark = dark
    }
}

/// Message color tokens
public struct ConciergeMessageColors: Codable {
    public var userBackground: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground))
    public var userText: CodableColor = CodableColor(Color.primary)
    public var conciergeBackground: CodableColor = CodableColor(Color(UIColor.systemBackground))
    public var conciergeText: CodableColor = CodableColor(Color.primary)
    public var conciergeLink: CodableColor = CodableColor(Color.accentColor)
    
    public init(
        userBackground: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground)),
        userText: CodableColor = CodableColor(Color.primary),
        conciergeBackground: CodableColor = CodableColor(Color(UIColor.systemBackground)),
        conciergeText: CodableColor = CodableColor(Color.primary),
        conciergeLink: CodableColor = CodableColor(Color.accentColor)
    ) {
        self.userBackground = userBackground
        self.userText = userText
        self.conciergeBackground = conciergeBackground
        self.conciergeText = conciergeText
        self.conciergeLink = conciergeLink
    }
}

/// Button color tokens
public struct ConciergeButtonColors: Codable {
    public var primaryBackground: CodableColor = CodableColor(Color.accentColor)
    public var primaryText: CodableColor = CodableColor(Color.white)
    public var primaryHover: CodableColor = CodableColor(Color.accentColor)
    public var secondaryBorder: CodableColor = CodableColor(Color.primary)
    public var secondaryText: CodableColor = CodableColor(Color.primary)
    public var secondaryHover: CodableColor = CodableColor(Color.primary)
    public var secondaryHoverText: CodableColor = CodableColor(Color.white)
    public var submitFill: CodableColor = CodableColor(Color.white)
    public var submitFillDisabled: CodableColor = CodableColor(Color(UIColor.systemGray3))
    public var submitText: CodableColor = CodableColor(Color.primary)
    public var submitTextHover: CodableColor = CodableColor(Color.primary)
    public var disabledBackground: CodableColor = CodableColor(Color.white)
    
    public init(
        primaryBackground: CodableColor = CodableColor(Color.accentColor),
        primaryText: CodableColor = CodableColor(Color.white),
        primaryHover: CodableColor = CodableColor(Color.accentColor),
        secondaryBorder: CodableColor = CodableColor(Color.primary),
        secondaryText: CodableColor = CodableColor(Color.primary),
        secondaryHover: CodableColor = CodableColor(Color.primary),
        secondaryHoverText: CodableColor = CodableColor(Color.white),
        submitFill: CodableColor = CodableColor(Color.white),
        submitFillDisabled: CodableColor = CodableColor(Color(UIColor.systemGray3)),
        submitText: CodableColor = CodableColor(Color.primary),
        submitTextHover: CodableColor = CodableColor(Color.primary),
        disabledBackground: CodableColor = CodableColor(Color.white)
    ) {
        self.primaryBackground = primaryBackground
        self.primaryText = primaryText
        self.primaryHover = primaryHover
        self.secondaryBorder = secondaryBorder
        self.secondaryText = secondaryText
        self.secondaryHover = secondaryHover
        self.secondaryHoverText = secondaryHoverText
        self.submitFill = submitFill
        self.submitFillDisabled = submitFillDisabled
        self.submitText = submitText
        self.submitTextHover = submitTextHover
        self.disabledBackground = disabledBackground
    }
}

/// Input color tokens
public struct ConciergeInputColors: Codable {
    public var background: CodableColor = CodableColor(Color.white)
    public var text: CodableColor = CodableColor(Color.primary)
    public var outline: CodableColor? = nil // TODO: are gradients required?
    public var outlineFocus: CodableColor = CodableColor(Color.accentColor)
    
    public init(
        background: CodableColor = CodableColor(Color.white),
        text: CodableColor = CodableColor(Color.primary),
        outline: CodableColor? = nil,
        outlineFocus: CodableColor = CodableColor(Color.accentColor)
    ) {
        self.background = background
        self.text = text
        self.outline = outline
        self.outlineFocus = outlineFocus
    }
}

/// Citation color tokens
public struct ConciergeCitationColors: Codable {
    public var background: CodableColor = CodableColor(Color(UIColor.systemGray3))
    public var text: CodableColor = CodableColor(Color.primary)
    
    public init(
        background: CodableColor = CodableColor(Color(UIColor.systemGray3)),
        text: CodableColor = CodableColor(Color.primary)
    ) {
        self.background = background
        self.text = text
    }
}

/// Feedback color tokens
public struct ConciergeFeedbackColors: Codable {
    public var iconButtonBackground: CodableColor = CodableColor(Color.white)
    public var iconButtonHoverBackground: CodableColor = CodableColor(Color.white)
    
    public init(
        iconButtonBackground: CodableColor = CodableColor(Color.white),
        iconButtonHoverBackground: CodableColor = CodableColor(Color.white)
    ) {
        self.iconButtonBackground = iconButtonBackground
        self.iconButtonHoverBackground = iconButtonHoverBackground
    }
}

/// Primary color tokens
public struct ConciergePrimaryColors: Codable {
    public var primary: CodableColor = CodableColor(Color.accentColor)
    public var secondary: CodableColor = CodableColor(Color.accentColor)
    public var text: CodableColor = CodableColor(Color.primary)
    
    public init(
        primary: CodableColor = CodableColor(Color.accentColor),
        secondary: CodableColor = CodableColor(Color.accentColor),
        text: CodableColor = CodableColor(Color.primary)
    ) {
        self.primary = primary
        self.secondary = secondary
        self.text = text
    }
}

/// Consolidated color configuration with semantic groupings
public struct ConciergeThemeColors: Codable {
    public var primary: ConciergePrimaryColors = ConciergePrimaryColors()
    public var surface: ConciergeSurfaceColors = ConciergeSurfaceColors()
    public var message: ConciergeMessageColors = ConciergeMessageColors()
    public var button: ConciergeButtonColors = ConciergeButtonColors()
    public var input: ConciergeInputColors = ConciergeInputColors()
    public var citation: ConciergeCitationColors = ConciergeCitationColors()
    public var feedback: ConciergeFeedbackColors = ConciergeFeedbackColors()
    public var disclaimer: CodableColor = CodableColor(Color(UIColor.systemGray))
    
    public init(
        primary: ConciergePrimaryColors = ConciergePrimaryColors(),
        surface: ConciergeSurfaceColors = ConciergeSurfaceColors(),
        message: ConciergeMessageColors = ConciergeMessageColors(),
        button: ConciergeButtonColors = ConciergeButtonColors(),
        input: ConciergeInputColors = ConciergeInputColors(),
        citation: ConciergeCitationColors = ConciergeCitationColors(),
        feedback: ConciergeFeedbackColors = ConciergeFeedbackColors(),
        disclaimer: CodableColor = CodableColor(Color(UIColor.systemGray))
    ) {
        self.primary = primary
        self.surface = surface
        self.message = message
        self.button = button
        self.input = input
        self.citation = citation
        self.feedback = feedback
        self.disclaimer = disclaimer
    }
}

/// Layout and spacing configuration
public struct ConciergeLayout: Codable {
    public var inputHeight: CGFloat = 52
    public var inputBorderRadius: CGFloat = 12
    public var inputOutlineWidth: CGFloat = 2
    public var inputFocusOutlineWidth: CGFloat = 2
    public var inputButtonHeight: CGFloat = 32
    public var inputButtonWidth: CGFloat = 32
    public var inputButtonBorderRadius: CGFloat = 8
    public var messageBorderRadius: CGFloat = 10
    public var messagePadding: ConciergePadding = ConciergePadding(vertical: 8, horizontal: 16)
    public var messageMaxWidth: CGFloat? = nil // nil = no max width, value = max width in points
    public var chatInterfaceMaxWidth: CGFloat = 768
    public var chatHistoryPadding: CGFloat = 16
    public var chatHistoryPaddingTopExpanded: CGFloat = 0
    public var chatHistoryBottomPadding: CGFloat = 0
    public var messageBlockerHeight: CGFloat = 105
    public var borderRadiusCard: CGFloat = 16
    public var buttonHeightSmall: CGFloat = 30
    public var feedbackContainerGap: CGFloat = 4
    public var citationsTextFontWeight: CodableFontWeight = .bold
    public var citationsDesktopButtonFontSize: CGFloat = 14
    public var disclaimerFontSize: CGFloat = 12
    public var disclaimerFontWeight: CodableFontWeight = .regular
    public var inputFontSize: CGFloat = 16
    public var inputBoxShadow: ConciergeShadow = ConciergeShadow(
        offsetX: 0,
        offsetY: 4,
        blurRadius: 16,
        spreadRadius: 0,
        color: CodableColor(Color.black.opacity(0.16))
    )
    public var multimodalCardBoxShadow: ConciergeShadow = .none
    public var welcomeInputOrder: Int = 3
    public var welcomeCardsOrder: Int = 2
    
    public init(
        inputHeight: CGFloat = 52,
        inputBorderRadius: CGFloat = 12,
        inputOutlineWidth: CGFloat = 2,
        inputFocusOutlineWidth: CGFloat = 2,
        inputButtonHeight: CGFloat = 32,
        inputButtonWidth: CGFloat = 32,
        inputButtonBorderRadius: CGFloat = 8,
        messageBorderRadius: CGFloat = 10,
        messagePadding: ConciergePadding = ConciergePadding(vertical: 8, horizontal: 16),
        messageMaxWidth: CGFloat? = nil,
        chatInterfaceMaxWidth: CGFloat = 768,
        chatHistoryPadding: CGFloat = 16,
        chatHistoryPaddingTopExpanded: CGFloat = 0,
        chatHistoryBottomPadding: CGFloat = 0,
        messageBlockerHeight: CGFloat = 105,
        borderRadiusCard: CGFloat = 16,
        buttonHeightSmall: CGFloat = 30,
        feedbackContainerGap: CGFloat = 4,
        citationsTextFontWeight: CodableFontWeight = .bold,
        citationsDesktopButtonFontSize: CGFloat = 14,
        disclaimerFontSize: CGFloat = 12,
        disclaimerFontWeight: CodableFontWeight = .regular,
        inputFontSize: CGFloat = 16,
        inputBoxShadow: ConciergeShadow = ConciergeShadow(
            offsetX: 0,
            offsetY: 4,
            blurRadius: 16,
            spreadRadius: 0,
            color: CodableColor(Color.black.opacity(0.16))
        ),
        multimodalCardBoxShadow: ConciergeShadow = .none,
        welcomeInputOrder: Int = 3,
        welcomeCardsOrder: Int = 2
    ) {
        self.inputHeight = inputHeight
        self.inputBorderRadius = inputBorderRadius
        self.inputOutlineWidth = inputOutlineWidth
        self.inputFocusOutlineWidth = inputFocusOutlineWidth
        self.inputButtonHeight = inputButtonHeight
        self.inputButtonWidth = inputButtonWidth
        self.inputButtonBorderRadius = inputButtonBorderRadius
        self.messageBorderRadius = messageBorderRadius
        self.messagePadding = messagePadding
        self.messageMaxWidth = messageMaxWidth
        self.chatInterfaceMaxWidth = chatInterfaceMaxWidth
        self.chatHistoryPadding = chatHistoryPadding
        self.chatHistoryPaddingTopExpanded = chatHistoryPaddingTopExpanded
        self.chatHistoryBottomPadding = chatHistoryBottomPadding
        self.messageBlockerHeight = messageBlockerHeight
        self.borderRadiusCard = borderRadiusCard
        self.buttonHeightSmall = buttonHeightSmall
        self.feedbackContainerGap = feedbackContainerGap
        self.citationsTextFontWeight = citationsTextFontWeight
        self.citationsDesktopButtonFontSize = citationsDesktopButtonFontSize
        self.disclaimerFontSize = disclaimerFontSize
        self.disclaimerFontWeight = disclaimerFontWeight
        self.inputFontSize = inputFontSize
        self.inputBoxShadow = inputBoxShadow
        self.multimodalCardBoxShadow = multimodalCardBoxShadow
        self.welcomeInputOrder = welcomeInputOrder
        self.welcomeCardsOrder = welcomeCardsOrder
    }
}

/// Border style configuration
public struct ConciergeBorderStyle: Codable {
    public var width: CGFloat = 1
    public var radius: CGFloat = 0
    public var color: CodableColor = CodableColor(Color.primary)
    
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
    public var headingColor: CodableColor = CodableColor(Color.primary)
    public var subheadingColor: CodableColor = CodableColor(Color.secondary)
    public var inputOrder: Int = 3
    public var cardsOrder: Int = 2
    
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
    public var background: CodableColor = CodableColor(Color.white)
    public var textColor: CodableColor = CodableColor(Color.primary)
    public var border: ConciergeBorderStyle = ConciergeBorderStyle()
    public var placeholderColor: CodableColor = CodableColor(Color.secondary)
    public var icon: ConciergeIconConfig? = nil
    public var voiceEnabled: Bool = false
    
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
    public var userBackground: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground))
    public var userText: CodableColor = CodableColor(Color.primary)
    public var conciergeBackground: CodableColor = CodableColor(Color(UIColor.systemBackground))
    public var conciergeText: CodableColor = CodableColor(Color.primary)
    public var linkColor: CodableColor = CodableColor(Color.accentColor)
    public var borderRadius: CGFloat = 10
    public var padding: ConciergePadding = ConciergePadding(vertical: 8, horizontal: 16)
    public var maxWidth: CGFloat? = nil // nil = no max width, value = max width in points
    
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
    public var iconButtonBackground: CodableColor = CodableColor(Color.white)
    public var iconButtonHoverBackground: CodableColor = CodableColor(Color.white)
    public var iconButtonSizeDesktop: CGFloat = 32
    public var containerGap: CGFloat = 4
    public var positiveNotesEnabled: Bool = true
    public var negativeNotesEnabled: Bool = true
    
    public init(
        iconButtonBackground: CodableColor = CodableColor(Color.white),
        iconButtonHoverBackground: CodableColor = CodableColor(Color.white),
        iconButtonSizeDesktop: CGFloat = 32,
        containerGap: CGFloat = 4,
        positiveNotesEnabled: Bool = true,
        negativeNotesEnabled: Bool = true
    ) {
        self.iconButtonBackground = iconButtonBackground
        self.iconButtonHoverBackground = iconButtonHoverBackground
        self.iconButtonSizeDesktop = iconButtonSizeDesktop
        self.containerGap = containerGap
        self.positiveNotesEnabled = positiveNotesEnabled
        self.negativeNotesEnabled = negativeNotesEnabled
    }
}

/// Carousel component style
public struct ConciergeCarouselStyle: Codable {
    public var cardBorderRadius: CGFloat = 16
    public var cardBoxShadow: ConciergeShadow = .none
    public var cardClickAction: String = "openLink"
    
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
    public var textColor: CodableColor = CodableColor(Color(UIColor.systemGray))
    public var fontSize: CGFloat = 12
    public var fontWeight: CodableFontWeight = .regular
    
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
    public var welcome: ConciergeWelcomeStyle = ConciergeWelcomeStyle()
    public var inputBar: ConciergeInputBarStyle = ConciergeInputBarStyle()
    public var chatMessage: ConciergeChatMessageStyle = ConciergeChatMessageStyle()
    public var feedback: ConciergeFeedbackStyle = ConciergeFeedbackStyle()
    public var carousel: ConciergeCarouselStyle = ConciergeCarouselStyle()
    public var disclaimer: ConciergeDisclaimerStyle = ConciergeDisclaimerStyle()
    
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

/// Assets configuration (icons, images, etc.)
public struct ConciergeAssets: Codable {
    public var icons: ConciergeIconAssets = ConciergeIconAssets()
    
    public init(icons: ConciergeIconAssets = ConciergeIconAssets()) {
        self.icons = icons
    }
}

/// Icon assets configuration
public struct ConciergeIconAssets: Codable {
    public var company: String = ""
    
    public init(company: String = "") {
        self.company = company
    }
}

/// Welcome example card configuration
public struct ConciergeWelcomeExample: Codable {
    public var text: String = ""
    public var image: String? = nil
    public var backgroundColor: CodableColor? = nil
    
    public init(text: String = "", image: String? = nil, backgroundColor: CodableColor? = nil) {
        self.text = text
        self.image = image
        self.backgroundColor = backgroundColor
    }
}

/// Text content and copy configuration (localizable strings)
/// Maps from web config "text" object with dot-notation keys (ex: "welcome.heading")
public struct ConciergeCopy: Codable {
    public var welcomeHeading: String = "Explore what you can do with Adobe apps."
    public var welcomeSubheading: String = "Choose an option or tell us what interests you and we'll point you in the right direction."
    public var inputPlaceholder: String = "Tell us what you'd like to do or create"
    public var inputMessageInputAria: String = "Message input"
    public var inputSendAria: String = "Send message"
    public var inputAiChatIconTooltip: String = "Ask AI"
    public var inputMicAria: String = "Voice input"
    public var cardAriaSelect: String = "Select example message"
    public var carouselPrevAria: String = "Previous cards"
    public var carouselNextAria: String = "Next cards"
    public var scrollBottomAria: String = "Scroll to bottom"
    public var errorNetwork: String = "I'm sorry, I'm having trouble connecting to our services right now."
    public var loadingMessage: String = "Generating response from our knowledge base"
    public var feedbackDialogTitlePositive: String = "Your feedback is appreciated"
    public var feedbackDialogTitleNegative: String = "Your feedback is appreciated"
    public var feedbackDialogQuestionPositive: String = "What went well? Select all that apply."
    public var feedbackDialogQuestionNegative: String = "What went wrong? Select all that apply."
    public var feedbackDialogNotes: String = "Notes"
    public var feedbackDialogSubmit: String = "Submit"
    public var feedbackDialogCancel: String = "Cancel"
    public var feedbackDialogNotesPlaceholder: String = "Additional notes (optional)"
    public var feedbackToastSuccess: String = "Thank you for the feedback."
    public var feedbackThumbsUpAria: String = "Thumbs up"
    public var feedbackThumbsDownAria: String = "Thumbs down"
    
    enum CodingKeys: String, CodingKey {
        case welcomeHeading = "welcome.heading"
        case welcomeSubheading = "welcome.subheading"
        case inputPlaceholder = "input.placeholder"
        case inputMessageInputAria = "input.messageInput.aria"
        case inputSendAria = "input.send.aria"
        case inputAiChatIconTooltip = "input.aiChatIcon.tooltip"
        case inputMicAria = "input.mic.aria"
        case cardAriaSelect = "card.aria.select"
        case carouselPrevAria = "carousel.prev.aria"
        case carouselNextAria = "carousel.next.aria"
        case scrollBottomAria = "scroll.bottom.aria"
        case errorNetwork = "error.network"
        case loadingMessage = "loading.message"
        case feedbackDialogTitlePositive = "feedback.dialog.title.positive"
        case feedbackDialogTitleNegative = "feedback.dialog.title.negative"
        case feedbackDialogQuestionPositive = "feedback.dialog.question.positive"
        case feedbackDialogQuestionNegative = "feedback.dialog.question.negative"
        case feedbackDialogNotes = "feedback.dialog.notes"
        case feedbackDialogSubmit = "feedback.dialog.submit"
        case feedbackDialogCancel = "feedback.dialog.cancel"
        case feedbackDialogNotesPlaceholder = "feedback.dialog.notes.placeholder"
        case feedbackToastSuccess = "feedback.toast.success"
        case feedbackThumbsUpAria = "feedback.thumbsUp.aria"
        case feedbackThumbsDownAria = "feedback.thumbsDown.aria"
    }
    
    public init(
        welcomeHeading: String = "Explore what you can do with Adobe apps.",
        welcomeSubheading: String = "Choose an option or tell us what interests you and we'll point you in the right direction.",
        inputPlaceholder: String = "Tell us what you'd like to do or create",
        inputMessageInputAria: String = "Message input",
        inputSendAria: String = "Send message",
        inputAiChatIconTooltip: String = "Ask AI",
        inputMicAria: String = "Voice input",
        cardAriaSelect: String = "Select example message",
        carouselPrevAria: String = "Previous cards",
        carouselNextAria: String = "Next cards",
        scrollBottomAria: String = "Scroll to bottom",
        errorNetwork: String = "I'm sorry, I'm having trouble connecting to our services right now.",
        loadingMessage: String = "Generating response from our knowledge base",
        feedbackDialogTitlePositive: String = "Your feedback is appreciated",
        feedbackDialogTitleNegative: String = "Your feedback is appreciated",
        feedbackDialogQuestionPositive: String = "What went well? Select all that apply.",
        feedbackDialogQuestionNegative: String = "What went wrong? Select all that apply.",
        feedbackDialogNotes: String = "Notes",
        feedbackDialogSubmit: String = "Submit",
        feedbackDialogCancel: String = "Cancel",
        feedbackDialogNotesPlaceholder: String = "Additional notes (optional)",
        feedbackToastSuccess: String = "Thank you for the feedback.",
        feedbackThumbsUpAria: String = "Thumbs up",
        feedbackThumbsDownAria: String = "Thumbs down"
    ) {
        self.welcomeHeading = welcomeHeading
        self.welcomeSubheading = welcomeSubheading
        self.inputPlaceholder = inputPlaceholder
        self.inputMessageInputAria = inputMessageInputAria
        self.inputSendAria = inputSendAria
        self.inputAiChatIconTooltip = inputAiChatIconTooltip
        self.inputMicAria = inputMicAria
        self.cardAriaSelect = cardAriaSelect
        self.carouselPrevAria = carouselPrevAria
        self.carouselNextAria = carouselNextAria
        self.scrollBottomAria = scrollBottomAria
        self.errorNetwork = errorNetwork
        self.loadingMessage = loadingMessage
        self.feedbackDialogTitlePositive = feedbackDialogTitlePositive
        self.feedbackDialogTitleNegative = feedbackDialogTitleNegative
        self.feedbackDialogQuestionPositive = feedbackDialogQuestionPositive
        self.feedbackDialogQuestionNegative = feedbackDialogQuestionNegative
        self.feedbackDialogNotes = feedbackDialogNotes
        self.feedbackDialogSubmit = feedbackDialogSubmit
        self.feedbackDialogCancel = feedbackDialogCancel
        self.feedbackDialogNotesPlaceholder = feedbackDialogNotesPlaceholder
        self.feedbackToastSuccess = feedbackToastSuccess
        self.feedbackThumbsUpAria = feedbackThumbsUpAria
        self.feedbackThumbsDownAria = feedbackThumbsDownAria
    }
}

/// Arrays configuration (welcome examples, feedback options)
public struct ConciergeArrays: Codable {
    public var welcomeExamples: [ConciergeWelcomeExample] = []
    public var feedbackPositiveOptions: [String] = ConciergeArrays.defaultPositive
    public var feedbackNegativeOptions: [String] = ConciergeArrays.defaultNegative
    
    private enum DotKeys: String, CodingKey {
        case welcomeExamples = "welcome.examples"
        case feedbackPositiveOptions = "feedback.positive.options"
        case feedbackNegativeOptions = "feedback.negative.options"
    }
    
    public static let defaultPositive: [String] = [
        "Helpful and relevant recommendations",
        "Clear and easy to understand",
        "Friendly and conversational tone",
        "Visually appealing presentation",
        "Other"
    ]
    
    public static let defaultNegative: [String] = [
        "Didn't understand my request",
        "Unhelpful or irrelevant information",
        "Too vague or lacking detail",
        "Errors or poor quality response",
        "Other"
    ]
    
    public init(
        welcomeExamples: [ConciergeWelcomeExample] = [],
        feedbackPositiveOptions: [String] = ConciergeArrays.defaultPositive,
        feedbackNegativeOptions: [String] = ConciergeArrays.defaultNegative
    ) {
        self.welcomeExamples = welcomeExamples
        self.feedbackPositiveOptions = feedbackPositiveOptions
        self.feedbackNegativeOptions = feedbackNegativeOptions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DotKeys.self)
        welcomeExamples = try container.decodeIfPresent([ConciergeWelcomeExample].self, forKey: .welcomeExamples) ?? []
        feedbackPositiveOptions = try container.decodeIfPresent([String].self, forKey: .feedbackPositiveOptions) ?? ConciergeArrays.defaultPositive
        feedbackNegativeOptions = try container.decodeIfPresent([String].self, forKey: .feedbackNegativeOptions) ?? ConciergeArrays.defaultNegative
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DotKeys.self)
        try container.encode(welcomeExamples, forKey: .welcomeExamples)
        try container.encode(feedbackPositiveOptions, forKey: .feedbackPositiveOptions)
        try container.encode(feedbackNegativeOptions, forKey: .feedbackNegativeOptions)
    }
}

/// Helper CodingKey for decoding dynamic CSS variable names
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Typed representation of processed theme values
public struct ConciergeThemeTokens: Codable {
    public var typography: ConciergeTypography = ConciergeTypography()
    public var colors: ConciergeThemeColors = ConciergeThemeColors()
    public var layout: ConciergeLayout = ConciergeLayout()
    public var components: ConciergeComponentStyles = ConciergeComponentStyles()
    
    public init(
        typography: ConciergeTypography = ConciergeTypography(),
        colors: ConciergeThemeColors = ConciergeThemeColors(),
        layout: ConciergeLayout = ConciergeLayout(),
        components: ConciergeComponentStyles = ConciergeComponentStyles()
    ) {
        self.typography = typography
        self.colors = colors
        self.layout = layout
        self.components = components
    }
}

/// Main ConciergeTheme2 structure that consolidates all theme configuration
/// Maps to the web styleConfiguration format for cross platform compatibility
/// 
/// JSON Structure Mapping:
/// - `metadata` -> metadata
/// - `behavior` -> behavior
/// - `disclaimer` -> disclaimer
/// - `text` -> text/copy (with nested structure matching web dot-notation keys)
/// - `arrays.welcome.examples` -> welcomeExamples
/// - `arrays.feedback.positive.options` -> feedbackPositiveOptions
/// - `arrays.feedback.negative.options` -> feedbackNegativeOptions
/// - `assets` -> assets
/// - `theme` -> colors, layout, typography, components (CSS variables mapped to semantic groups)
public struct ConciergeTheme2: Codable {
    public var metadata: ConciergeThemeMetadata
    public var behavior: ConciergeBehaviorConfig
    public var disclaimer: ConciergeDisclaimer
    public var assets: ConciergeAssets
    public var text: ConciergeCopy
    public var arrays: ConciergeArrays
    public var theme: ConciergeThemeTokens
    
    public var typography: ConciergeTypography {
        get { theme.typography }
        set { theme.typography = newValue }
    }
    
    public var colors: ConciergeThemeColors {
        get { theme.colors }
        set { theme.colors = newValue }
    }
    
    public var layout: ConciergeLayout {
        get { theme.layout }
        set { theme.layout = newValue }
    }
    
    public var components: ConciergeComponentStyles {
        get { theme.components }
        set { theme.components = newValue }
    }
    
    public var copy: ConciergeCopy {
        get { text }
        set { text = newValue }
    }
    
    public var welcomeExamples: [ConciergeWelcomeExample] {
        get { arrays.welcomeExamples }
        set { arrays.welcomeExamples = newValue }
    }
    
    public var feedbackPositiveOptions: [String] {
        get { arrays.feedbackPositiveOptions }
        set { arrays.feedbackPositiveOptions = newValue }
    }
    
    public var feedbackNegativeOptions: [String] {
        get { arrays.feedbackNegativeOptions }
        set { arrays.feedbackNegativeOptions = newValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case behavior
        case disclaimer
        case assets
        case text
        case arrays
        case theme
    }
    
    public init(
        metadata: ConciergeThemeMetadata = ConciergeThemeMetadata(),
        behavior: ConciergeBehaviorConfig = ConciergeBehaviorConfig(),
        disclaimer: ConciergeDisclaimer = ConciergeDisclaimer(),
        assets: ConciergeAssets = ConciergeAssets(),
        text: ConciergeCopy = ConciergeCopy(),
        arrays: ConciergeArrays = ConciergeArrays(),
        theme: ConciergeThemeTokens = ConciergeThemeTokens()
    ) {
        self.metadata = metadata
        self.behavior = behavior
        self.disclaimer = disclaimer
        self.assets = assets
        self.text = text
        self.arrays = arrays
        self.theme = theme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode top-level groups
        metadata = try container.decodeIfPresent(ConciergeThemeMetadata.self, forKey: .metadata) ?? ConciergeThemeMetadata()
        behavior = try container.decodeIfPresent(ConciergeBehaviorConfig.self, forKey: .behavior) ?? ConciergeBehaviorConfig()
        disclaimer = try container.decodeIfPresent(ConciergeDisclaimer.self, forKey: .disclaimer) ?? ConciergeDisclaimer()
        assets = try container.decodeIfPresent(ConciergeAssets.self, forKey: .assets) ?? ConciergeAssets()
        
        // Decode text/copy (maps from "text" key)
        do {
            text = try container.decodeIfPresent(ConciergeCopy.self, forKey: .text) ?? ConciergeCopy()
        } catch {
            Log.warning(label: Constants.LOG_TAG, "Failed to decode theme copy: \(error)")
            print("Failed to decode theme copy: \(error)")
            text = ConciergeCopy()
        }
        
        // Decode arrays (maps from "arrays" key)
        do {
            arrays = try container.decodeIfPresent(ConciergeArrays.self, forKey: .arrays) ?? ConciergeArrays()
        } catch {
            Log.warning(label: Constants.LOG_TAG, "Failed to decode theme arrays: \(error)")
            print("Failed to decode theme arrays: \(error)")
            arrays = ConciergeArrays()
        }
        
        // Decode theme tokens or process CSS variables
        if let typedTheme = try? container.decode(ConciergeThemeTokens.self, forKey: .theme) {
            theme = typedTheme
        } else {
            print("Theme key missing or not typed for theme configuration.")
            theme = ConciergeThemeTokens()
            if let themeContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .theme) {
                for cssKey in themeContainer.allKeys {
                    if let cssValue = try? themeContainer.decode(String.self, forKey: cssKey) {
                        CSSKeyMapper.apply(cssKey: cssKey.stringValue, cssValue: cssValue, to: &self)
                    }
                }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(metadata, forKey: .metadata)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(disclaimer, forKey: .disclaimer)
        try container.encode(assets, forKey: .assets)
        try container.encode(text, forKey: .text)
        try container.encode(arrays, forKey: .arrays)
        try container.encode(theme, forKey: .theme)
    }
}
