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

/// Surface color tokens
public struct ConciergeSurfaceColors: Codable {
    public var mainContainerBackground: CodableColor
    public var mainContainerBottomBackground: CodableColor
    public var messageBlockerBackground: CodableColor
    public var light: CodableColor
    public var dark: CodableColor

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
    public var userBackground: CodableColor
    public var userText: CodableColor
    /// Concierge message bubble background. When nil, falls back to `primary.container` then system default.
    public var conciergeBackground: CodableColor?
    public var conciergeText: CodableColor
    public var conciergeLink: CodableColor

    public init(
        userBackground: CodableColor = CodableColor(Color(UIColor.secondarySystemBackground)),
        userText: CodableColor = CodableColor(Color.primary),
        conciergeBackground: CodableColor? = nil,
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
    public var primaryBackground: CodableColor
    public var primaryText: CodableColor
    public var secondaryBorder: CodableColor
    public var secondaryText: CodableColor
    public var submitFill: CodableColor
    public var submitFillDisabled: CodableColor
    public var submitText: CodableColor
    public var disabledBackground: CodableColor

    public init(
        primaryBackground: CodableColor = CodableColor(Color.accentColor),
        primaryText: CodableColor = CodableColor(Color.white),
        secondaryBorder: CodableColor = CodableColor(Color.primary),
        secondaryText: CodableColor = CodableColor(Color.primary),
        // Default composer submit control renders as an icon without a background.
        submitFill: CodableColor = CodableColor(Color.clear),
        submitFillDisabled: CodableColor = CodableColor(Color.clear),
        submitText: CodableColor = CodableColor(Color.accentColor),
        disabledBackground: CodableColor = CodableColor(Color.clear)
    ) {
        self.primaryBackground = primaryBackground
        self.primaryText = primaryText
        self.secondaryBorder = secondaryBorder
        self.secondaryText = secondaryText
        self.submitFill = submitFill
        self.submitFillDisabled = submitFillDisabled
        self.submitText = submitText
        self.disabledBackground = disabledBackground
    }
}

/// Input color tokens
public struct ConciergeInputColors: Codable {
    public var background: CodableColor
    public var text: CodableColor
    public var outline: CodableColor? // TODO: are gradients required?
    public var outlineFocus: CodableColor
    public var sendIconColor: CodableColor?
    public var sendArrowIconColor: CodableColor?
    public var sendArrowBackgroundColor: CodableColor?
    public var micIconColor: CodableColor?
    public var micRecordingIconColor: CodableColor?

    public init(
        background: CodableColor = CodableColor(Color.white),
        text: CodableColor = CodableColor(Color.primary),
        outline: CodableColor? = nil,
        outlineFocus: CodableColor = CodableColor(Color.accentColor),
        sendIconColor: CodableColor? = nil,
        sendArrowIconColor: CodableColor? = nil,
        sendArrowBackgroundColor: CodableColor? = nil,
        micIconColor: CodableColor? = nil,
        micRecordingIconColor: CodableColor? = nil
    ) {
        self.background = background
        self.text = text
        self.outline = outline
        self.outlineFocus = outlineFocus
        self.sendIconColor = sendIconColor
        self.sendArrowIconColor = sendArrowIconColor
        self.sendArrowBackgroundColor = sendArrowBackgroundColor
        self.micIconColor = micIconColor
        self.micRecordingIconColor = micRecordingIconColor
    }
}

/// Welcome prompt color tokens
public struct ConciergeWelcomePromptColors: Codable {
    public var backgroundColor: CodableColor?
    public var textColor: CodableColor?

    public init(
        backgroundColor: CodableColor? = nil,
        textColor: CodableColor? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
}

/// Citation color tokens
public struct ConciergeCitationColors: Codable {
    public var background: CodableColor
    public var text: CodableColor

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
    public var iconButtonBackground: CodableColor

    public init(
        // Default feedback icons render without a background unless explicitly themed.
        iconButtonBackground: CodableColor = CodableColor(Color.clear)
    ) {
        self.iconButtonBackground = iconButtonBackground
    }
}

/// Primary color tokens
public struct ConciergePrimaryColors: Codable {
    public var primary: CodableColor
    public var secondary: CodableColor
    public var text: CodableColor
    /// Background for cards and container elements (prompt suggestion chips, product cards, message bubble fallback).
    /// Configurable via `--color-container`. When nil, falls back to hardcoded light/dark system values.
    public var container: CodableColor?

    public init(
        primary: CodableColor = CodableColor(Color.accentColor),
        secondary: CodableColor = CodableColor(Color.accentColor),
        text: CodableColor = CodableColor(Color.primary),
        container: CodableColor? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.text = text
        self.container = container
    }
}

/// Product card color tokens (used by the productDetail card style)
public struct ConciergeProductCardColors: Codable {
    /// Card background. When nil, falls back to `primary.container` then white.
    public var backgroundColor: CodableColor?
    public var titleColor: CodableColor
    public var subtitleColor: CodableColor
    public var priceColor: CodableColor
    public var wasPriceColor: CodableColor
    public var badgeTextColor: CodableColor
    public var badgeBackgroundColor: CodableColor
    public var outlineColor: CodableColor

    public init(
        backgroundColor: CodableColor? = nil,
        titleColor: CodableColor = CodableColor(Color.primary),
        subtitleColor: CodableColor = CodableColor(Color.primary),
        priceColor: CodableColor = CodableColor(Color.primary),
        wasPriceColor: CodableColor = CodableColor(Color.secondary),
        badgeTextColor: CodableColor = CodableColor(Color.white),
        badgeBackgroundColor: CodableColor = CodableColor(Color.primary),
        outlineColor: CodableColor = CodableColor(Color.clear)
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.priceColor = priceColor
        self.wasPriceColor = wasPriceColor
        self.badgeTextColor = badgeTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.outlineColor = outlineColor
    }
}

/// Thinking animation color tokens
public struct ConciergeThinkingColors: Codable {
    public var dotColor: CodableColor?

    public init(dotColor: CodableColor? = nil) {
        self.dotColor = dotColor
    }
}

/// CTA button color tokens
public struct ConciergeCtaButtonColors: Codable {
    public var background: CodableColor
    public var text: CodableColor
    public var iconColor: CodableColor

    public init(
        background: CodableColor = CodableColor(Color(UIColor.systemGray6)),
        text: CodableColor = CodableColor(Color.primary),
        iconColor: CodableColor = CodableColor(Color.primary)
    ) {
        self.background = background
        self.text = text
        self.iconColor = iconColor
    }
}

/// Consolidated color configuration with semantic groupings
public struct ConciergeThemeColors: Codable {
    public var primary: ConciergePrimaryColors
    public var surface: ConciergeSurfaceColors
    public var message: ConciergeMessageColors
    public var button: ConciergeButtonColors
    public var input: ConciergeInputColors
    public var citation: ConciergeCitationColors
    public var feedback: ConciergeFeedbackColors
    public var disclaimer: CodableColor
    public var productCard: ConciergeProductCardColors
    public var ctaButton: ConciergeCtaButtonColors
    public var welcomePrompt: ConciergeWelcomePromptColors
    public var thinking: ConciergeThinkingColors
    public var promptSuggestion: ConciergeWelcomePromptColors

    public init(
        primary: ConciergePrimaryColors = ConciergePrimaryColors(),
        surface: ConciergeSurfaceColors = ConciergeSurfaceColors(),
        message: ConciergeMessageColors = ConciergeMessageColors(),
        button: ConciergeButtonColors = ConciergeButtonColors(),
        input: ConciergeInputColors = ConciergeInputColors(),
        citation: ConciergeCitationColors = ConciergeCitationColors(),
        feedback: ConciergeFeedbackColors = ConciergeFeedbackColors(),
        disclaimer: CodableColor = CodableColor(Color(UIColor.systemGray)),
        productCard: ConciergeProductCardColors = ConciergeProductCardColors(),
        ctaButton: ConciergeCtaButtonColors = ConciergeCtaButtonColors(),
        welcomePrompt: ConciergeWelcomePromptColors = ConciergeWelcomePromptColors(),
        thinking: ConciergeThinkingColors = ConciergeThinkingColors(),
        promptSuggestion: ConciergeWelcomePromptColors = ConciergeWelcomePromptColors()
    ) {
        self.primary = primary
        self.surface = surface
        self.message = message
        self.button = button
        self.input = input
        self.citation = citation
        self.feedback = feedback
        self.disclaimer = disclaimer
        self.productCard = productCard
        self.ctaButton = ctaButton
        self.welcomePrompt = welcomePrompt
        self.thinking = thinking
        self.promptSuggestion = promptSuggestion
    }
}
