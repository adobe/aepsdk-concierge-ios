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
            offsetY: 2,
            blurRadius: 8,
            spreadRadius: 0,
            color: CodableColor(Color.black.opacity(0.08))
        ),
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
