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

/// Layout and spacing configuration
public struct ConciergeLayout: Codable {
    public var inputHeight: CGFloat
    public var inputBorderRadius: CGFloat
    public var inputOutlineWidth: CGFloat
    public var inputFocusOutlineWidth: CGFloat
    public var inputButtonHeight: CGFloat
    public var inputButtonWidth: CGFloat
    public var inputButtonBorderRadius: CGFloat
    public var messageBorderRadius: CGFloat
    public var messagePadding: ConciergePadding
    public var messageMaxWidth: CGFloat? // nil = no max width, value = max width in points
    public var chatInterfaceMaxWidth: CGFloat
    public var chatHistoryPadding: CGFloat
    public var chatHistoryPaddingTopExpanded: CGFloat
    public var chatHistoryBottomPadding: CGFloat
    public var messageBlockerHeight: CGFloat
    public var borderRadiusCard: CGFloat
    public var buttonHeightSmall: CGFloat
    public var feedbackContainerGap: CGFloat
    public var feedbackIconButtonSize: CGFloat
    public var citationsTextFontWeight: CodableFontWeight
    public var citationsDesktopButtonFontSize: CGFloat
    public var disclaimerFontSize: CGFloat
    public var disclaimerFontWeight: CodableFontWeight
    public var inputFontSize: CGFloat
    public var inputBoxShadow: ConciergeShadow
    public var multimodalCardBoxShadow: ConciergeShadow
    public var welcomeInputOrder: Int
    public var welcomeCardsOrder: Int
    public var productCardTitleFontSize: CGFloat
    public var productCardTitleFontWeight: CodableFontWeight
    public var productCardSubtitleFontSize: CGFloat
    public var productCardSubtitleFontWeight: CodableFontWeight
    public var productCardPriceFontSize: CGFloat
    public var productCardPriceFontWeight: CodableFontWeight
    public var productCardBadgeFontSize: CGFloat
    public var productCardBadgeFontWeight: CodableFontWeight
    public var productCardWasPriceTextPrefix: String
    public var productCardWasPriceFontSize: CGFloat
    public var productCardWasPriceFontWeight: CodableFontWeight
    public var productCardWidth: CGFloat
    public var productCardHeight: CGFloat
    public var productCardTextSpacing: CGFloat
    public var productCardTextTopPadding: CGFloat
    public var productCardTextBottomPadding: CGFloat
    public var productCardTextHorizontalPadding: CGFloat
    public var productCardCarouselSpacing: CGFloat
    /// Horizontal padding applied to the carousel container within the chat history.
    /// When `nil`, falls back to `chatHistoryPadding`.
    public var productCardCarouselHorizontalPadding: CGFloat?
    public var ctaButtonBorderRadius: CGFloat
    public var ctaButtonHorizontalPadding: CGFloat
    public var ctaButtonVerticalPadding: CGFloat
    public var ctaButtonFontSize: CGFloat
    public var ctaButtonFontWeight: CodableFontWeight
    public var ctaButtonIconSize: CGFloat

    // Welcome screen layout
    public var headerTitleFontSize: CGFloat?
    public var welcomeTitleFontSize: CGFloat?
    public var welcomeTextAlign: String?
    public var welcomeContentPadding: CGFloat?
    public var welcomePromptImageSize: CGFloat?
    public var welcomePromptSpacing: CGFloat?
    public var welcomeTitleBottomSpacing: CGFloat?
    public var welcomePromptsTopSpacing: CGFloat?
    public var welcomePromptPadding: CGFloat?
    public var welcomePromptCornerRadius: CGFloat?

    public init(
        inputHeight: CGFloat = 52,
        inputBorderRadius: CGFloat = 12,
        inputOutlineWidth: CGFloat = 2,
        inputFocusOutlineWidth: CGFloat = 2,
        // Keep defaults aligned with the current composer button layout (30x30).
        inputButtonHeight: CGFloat = 30,
        inputButtonWidth: CGFloat = 30,
        inputButtonBorderRadius: CGFloat = 8,
        messageBorderRadius: CGFloat = 10,
        messagePadding: ConciergePadding = ConciergePadding(vertical: 8, horizontal: 16),
        messageMaxWidth: CGFloat? = nil,
        chatInterfaceMaxWidth: CGFloat = 768,
        chatHistoryPadding: CGFloat = 16,
        // Keep defaults aligned with the current message list layout.
        chatHistoryPaddingTopExpanded: CGFloat = 8,
        chatHistoryBottomPadding: CGFloat = 12,
        messageBlockerHeight: CGFloat = 105,
        borderRadiusCard: CGFloat = 16,
        buttonHeightSmall: CGFloat = 30,
        feedbackContainerGap: CGFloat = 4,
        feedbackIconButtonSize: CGFloat = 44,
        citationsTextFontWeight: CodableFontWeight = .bold,
        citationsDesktopButtonFontSize: CGFloat = 14,
        disclaimerFontSize: CGFloat = 12,
        disclaimerFontWeight: CodableFontWeight = .regular,
        inputFontSize: CGFloat = 16,
        // Default UI does not apply a composer shadow unless explicitly configured by a theme.
        inputBoxShadow: ConciergeShadow = .none,
        // Default matches the current product carousel card drop shadow.
        multimodalCardBoxShadow: ConciergeShadow = ConciergeShadow(
            offsetX: 0,
            offsetY: 1,
            blurRadius: 3,
            spreadRadius: 0,
            color: CodableColor(Color.black.opacity(0.2))
        ),
        welcomeInputOrder: Int = 3,
        welcomeCardsOrder: Int = 2,
        productCardTitleFontSize: CGFloat = 14,
        productCardTitleFontWeight: CodableFontWeight = .bold,
        productCardSubtitleFontSize: CGFloat = 12,
        productCardSubtitleFontWeight: CodableFontWeight = .regular,
        productCardPriceFontSize: CGFloat = 14,
        productCardPriceFontWeight: CodableFontWeight = .light,
        productCardBadgeFontSize: CGFloat = 12,
        productCardBadgeFontWeight: CodableFontWeight = .semibold,
        productCardWasPriceTextPrefix: String = "was ",
        productCardWasPriceFontSize: CGFloat = 12,
        productCardWasPriceFontWeight: CodableFontWeight = .regular,
        productCardWidth: CGFloat = 250,
        productCardHeight: CGFloat = 300,
        productCardTextSpacing: CGFloat = 8,
        productCardTextTopPadding: CGFloat = 20,
        productCardTextBottomPadding: CGFloat = 12,
        productCardTextHorizontalPadding: CGFloat = 12,
        productCardCarouselSpacing: CGFloat = 12,
        productCardCarouselHorizontalPadding: CGFloat? = nil,
        ctaButtonBorderRadius: CGFloat = 99,
        ctaButtonHorizontalPadding: CGFloat = 16,
        ctaButtonVerticalPadding: CGFloat = 12,
        ctaButtonFontSize: CGFloat = 14,
        ctaButtonFontWeight: CodableFontWeight = .regular,
        ctaButtonIconSize: CGFloat = 16,
        headerTitleFontSize: CGFloat? = nil,
        welcomeTitleFontSize: CGFloat? = nil,
        welcomeTextAlign: String? = nil,
        welcomeContentPadding: CGFloat? = nil,
        welcomePromptImageSize: CGFloat? = nil,
        welcomePromptSpacing: CGFloat? = nil,
        welcomeTitleBottomSpacing: CGFloat? = nil,
        welcomePromptsTopSpacing: CGFloat? = nil,
        welcomePromptPadding: CGFloat? = nil,
        welcomePromptCornerRadius: CGFloat? = nil
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
        self.feedbackIconButtonSize = feedbackIconButtonSize
        self.citationsTextFontWeight = citationsTextFontWeight
        self.citationsDesktopButtonFontSize = citationsDesktopButtonFontSize
        self.disclaimerFontSize = disclaimerFontSize
        self.disclaimerFontWeight = disclaimerFontWeight
        self.inputFontSize = inputFontSize
        self.inputBoxShadow = inputBoxShadow
        self.multimodalCardBoxShadow = multimodalCardBoxShadow
        self.welcomeInputOrder = welcomeInputOrder
        self.welcomeCardsOrder = welcomeCardsOrder
        self.productCardTitleFontSize = productCardTitleFontSize
        self.productCardTitleFontWeight = productCardTitleFontWeight
        self.productCardSubtitleFontSize = productCardSubtitleFontSize
        self.productCardSubtitleFontWeight = productCardSubtitleFontWeight
        self.productCardPriceFontSize = productCardPriceFontSize
        self.productCardPriceFontWeight = productCardPriceFontWeight
        self.productCardBadgeFontSize = productCardBadgeFontSize
        self.productCardBadgeFontWeight = productCardBadgeFontWeight
        self.productCardWasPriceTextPrefix = productCardWasPriceTextPrefix
        self.productCardWasPriceFontSize = productCardWasPriceFontSize
        self.productCardWasPriceFontWeight = productCardWasPriceFontWeight
        self.productCardWidth = productCardWidth
        self.productCardHeight = productCardHeight
        self.productCardTextSpacing = productCardTextSpacing
        self.productCardTextTopPadding = productCardTextTopPadding
        self.productCardTextBottomPadding = productCardTextBottomPadding
        self.productCardTextHorizontalPadding = productCardTextHorizontalPadding
        self.productCardCarouselSpacing = productCardCarouselSpacing
        self.productCardCarouselHorizontalPadding = productCardCarouselHorizontalPadding
        self.ctaButtonBorderRadius = ctaButtonBorderRadius
        self.ctaButtonHorizontalPadding = ctaButtonHorizontalPadding
        self.ctaButtonVerticalPadding = ctaButtonVerticalPadding
        self.ctaButtonFontSize = ctaButtonFontSize
        self.ctaButtonFontWeight = ctaButtonFontWeight
        self.ctaButtonIconSize = ctaButtonIconSize
        self.headerTitleFontSize = headerTitleFontSize
        self.welcomeTitleFontSize = welcomeTitleFontSize
        self.welcomeTextAlign = welcomeTextAlign
        self.welcomeContentPadding = welcomeContentPadding
        self.welcomePromptImageSize = welcomePromptImageSize
        self.welcomePromptSpacing = welcomePromptSpacing
        self.welcomeTitleBottomSpacing = welcomeTitleBottomSpacing
        self.welcomePromptsTopSpacing = welcomePromptsTopSpacing
        self.welcomePromptPadding = welcomePromptPadding
        self.welcomePromptCornerRadius = welcomePromptCornerRadius
    }
}

/// Typography configuration (font families, sizes, line heights, weights)
public struct ConciergeTypography: Codable {
    /// Font family name (ex: "MarkerFelt-Thin")
    /// Expects a single font name. If empty or not provided, uses system font.
    public var fontFamily: String
    public var fontSize: CGFloat
    public var lineHeight: CGFloat
    public var fontWeight: CodableFontWeight

    public init(
        fontFamily: String = "",
        fontSize: CGFloat = 16,
        // Interpreted as a multiplier (ex: 1.25 means 125% line height).
        // Default is 1.0 to match typical system typography unless a theme explicitly overrides it.
        lineHeight: CGFloat = 1.0,
        fontWeight: CodableFontWeight = .regular
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.fontWeight = fontWeight
    }
}
