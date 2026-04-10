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

import Foundation
import XCTest
@testable import AEPBrandConcierge

final class ThemeKeyCoverageTests: XCTestCase {

    // MARK: - Theme JSON key coverage

    func test_themeDefaultJSON_themeKeys_areAllMappedOrExplicitlyIgnoredOnIOS() throws {
        let themeDictionary = try loadThemeDefaultJSONThemeDictionary()

        let jsonThemeKeys = Set(themeDictionary.keys.map(Self.normalizeThemeCSSKey))
        let supportedKeys = CSSKeyMapper.supportedCSSKeys
        let ignoredOnIOSKeys = Self.ignoredOnIOSCSSKeys

        let unknownKeys = jsonThemeKeys.subtracting(supportedKeys).subtracting(ignoredOnIOSKeys)
        XCTAssertTrue(
            unknownKeys.isEmpty,
            """
            theme-default.json contains theme tokens not mapped by iOS and not allowlisted as ignored on iOS:
            \(unknownKeys.sorted().joined(separator: "\n"))
            """
        )
    }

    // MARK: - Theme model property coverage

    func test_cssKeyMapper_propertyCoverage_coversThemeTokenModelOrIsAllowlisted() {
        // The test suite keeps a parallel map from CSS keys -> theme property paths to ensure:
        // - We consciously update tests when mapper keys change
        // - We can verify every theme model property is either supported by CSS or explicitly allowlisted
        let supportedKeyToPropertyPath = Self.supportedCSSKeyToThemePropertyPath

        XCTAssertEqual(
            Set(supportedKeyToPropertyPath.keys),
            CSSKeyMapper.supportedCSSKeys,
            "Update ThemeKeyCoverageTests.supportedCSSKeyToThemePropertyPath to match CSSKeyMapper.supportedCSSKeys"
        )

        let coveredPropertyPaths = Set(supportedKeyToPropertyPath.values)
        let allThemeTokenLeafPropertyPaths = Self.collectLeafPropertyPaths(
            from: ConciergeThemeTokens(),
            rootPath: ""
        )

        let allowlistedPropertyPaths = allThemeTokenLeafPropertyPaths.filter { Self.isAllowlistedThemePropertyPath($0) }

        let uncoveredRequiredPropertyPaths = Set(allThemeTokenLeafPropertyPaths)
            .subtracting(allowlistedPropertyPaths)
            .subtracting(coveredPropertyPaths)

        XCTAssertTrue(
            uncoveredRequiredPropertyPaths.isEmpty,
            """
            The following theme token properties are not covered by CSSKeyMapper and are not allowlisted as intentionally not configurable via CSS on iOS:
            \(uncoveredRequiredPropertyPaths.sorted().joined(separator: "\n"))
            """
        )
    }
}

// MARK: - Helpers

private extension ThemeKeyCoverageTests {

    static let ignoredOnIOSCSSKeys: Set<String> = [
        // Desktop-only values are intentionally ignored on iOS; mobile values drive the experience.
        "input-height",
        "input-border-radius",

        // These tokens exist in the web theme, but iOS sources alignment and width from the typed `behavior.chat` section.
        "message-alignment",
        "message-width",

        // Hover tokens are web-focused interaction states and are intentionally ignored on iOS.
        "button-primary-hover",
        "button-secondary-hover",
        "color-button-secondary-hover-text",
        "color-button-submit-hover",
        "feedback-icon-btn-hover-background",
    ]

    /// CSSKeyMapper keys are normalized (no leading `--`), but JSON `theme` keys include the `--` prefix.
    static func normalizeThemeCSSKey(_ rawKey: String) -> String {
        rawKey.hasPrefix("--") ? String(rawKey.dropFirst(2)) : rawKey
    }

    func loadThemeDefaultJSONThemeDictionary() throws -> [String: Any] {
        guard let data = ThemeTestHelpers.loadThemeJSON(named: "theme-default") else {
            XCTFail("Failed to load theme-default.json from test bundle")
            return [:]
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = jsonObject as? [String: Any] else {
            XCTFail("theme-default.json root should be a JSON object")
            return [:]
        }

        guard let themeDictionary = root["theme"] as? [String: Any] else {
            XCTFail("theme-default.json should include a top-level 'theme' object")
            return [:]
        }

        return themeDictionary
    }

    // MARK: - CSS key -> theme property coverage map

    /// Parallel mapping of `CSSKeyMapper.supportedCSSKeys` -> theme token property path.
    /// Keep this in sync with `CSSKeyMapper.cssToAssignmentMap`.
    static let supportedCSSKeyToThemePropertyPath: [String: String] = [
        // Typography
        "font-family": "typography.fontFamily",
        "line-height-body": "typography.lineHeight",

        // Colors - Primary
        "color-primary": "colors.primary.primary",
        "color-text": "colors.primary.text",

        // Colors - Surface
        "main-container-background": "colors.surface.mainContainerBackground",
        "main-container-bottom-background": "colors.surface.mainContainerBottomBackground",
        "message-blocker-background": "colors.surface.messageBlockerBackground",

        // Colors - Message
        "message-user-background": "colors.message.userBackground",
        "message-user-text": "colors.message.userText",
        "message-concierge-background": "colors.message.conciergeBackground",
        "message-concierge-text": "colors.message.conciergeText",
        "message-concierge-link-color": "colors.message.conciergeLink",
        
        // Colors - Citations
        "citations-background-color": "colors.citation.background",
        "citations-text-color": "colors.citation.text",

        // Colors - Button
        "button-primary-background": "colors.button.primaryBackground",
        "button-primary-text": "colors.button.primaryText",
        "button-secondary-border": "colors.button.secondaryBorder",
        "button-secondary-text": "colors.button.secondaryText",
        "submit-button-fill-color": "colors.button.submitFill",
        "submit-button-fill-color-disabled": "colors.button.submitFillDisabled",
        "color-button-submit": "colors.button.submitText",
        "button-disabled-background": "colors.button.disabledBackground",

        // Colors - Input
        "input-background": "colors.input.background",
        "input-text-color": "colors.input.text",
        "input-outline-color": "colors.input.outline",
        "input-focus-outline-color": "colors.input.outlineFocus",

        // Colors - Feedback
        "feedback-icon-btn-background": "colors.feedback.iconButtonBackground",

        // Colors - Disclaimer
        "disclaimer-color": "colors.disclaimer",

        // Layout - Input
        "input-height-mobile": "layout.inputHeight",
        "input-border-radius-mobile": "layout.inputBorderRadius",
        "input-outline-width": "layout.inputOutlineWidth",
        "input-focus-outline-width": "layout.inputFocusOutlineWidth",
        "input-font-size": "layout.inputFontSize",
        "input-button-height": "layout.inputButtonHeight",
        "input-button-width": "layout.inputButtonWidth",
        "input-button-border-radius": "layout.inputButtonBorderRadius",
        "input-box-shadow": "layout.inputBoxShadow",

        // Layout - Message
        "message-border-radius": "layout.messageBorderRadius",
        "message-padding": "layout.messagePadding",
        "message-max-width": "layout.messageMaxWidth",

        // Layout - Chat
        "chat-interface-max-width": "layout.chatInterfaceMaxWidth",
        "chat-history-padding": "layout.chatHistoryPadding",
        "chat-history-padding-top-expanded": "layout.chatHistoryPaddingTopExpanded",
        "chat-history-bottom-padding": "layout.chatHistoryBottomPadding",
        "message-blocker-height": "layout.messageBlockerHeight",

        // Layout - Card
        "border-radius-card": "layout.borderRadiusCard",
        "multimodal-card-box-shadow": "layout.multimodalCardBoxShadow",

        // Layout - Button
        "button-height-s": "layout.buttonHeightSmall",

        // Layout - Feedback
        "feedback-container-gap": "layout.feedbackContainerGap",

        // Layout - Citations
        "citations-text-font-weight": "layout.citationsTextFontWeight",
        "citations-desktop-button-font-size": "layout.citationsDesktopButtonFontSize",

        // Layout - Disclaimer
        "disclaimer-font-size": "layout.disclaimerFontSize",
        "disclaimer-font-weight": "layout.disclaimerFontWeight",

        // Layout - Welcome Order
        "welcome-input-order": "layout.welcomeInputOrder",
        "welcome-cards-order": "layout.welcomeCardsOrder",

        // Layout - Feedback
        "feedback-icon-btn-size-desktop": "layout.feedbackIconButtonSize",

        // Colors - Product Card
        "product-card-background-color": "colors.productCard.backgroundColor",
        "product-card-title-color": "colors.productCard.titleColor",
        "product-card-subtitle-color": "colors.productCard.subtitleColor",
        "product-card-price-color": "colors.productCard.priceColor",
        "product-card-was-price-color": "colors.productCard.wasPriceColor",
        "product-card-badge-text-color": "colors.productCard.badgeTextColor",
        "product-card-badge-background-color": "colors.productCard.badgeBackgroundColor",
        "product-card-outline-color": "colors.productCard.outlineColor",

        // Layout - Product Card
        "product-card-title-font-size": "layout.productCardTitleFontSize",
        "product-card-title-font-weight": "layout.productCardTitleFontWeight",
        "product-card-subtitle-font-size": "layout.productCardSubtitleFontSize",
        "product-card-subtitle-font-weight": "layout.productCardSubtitleFontWeight",
        "product-card-price-font-size": "layout.productCardPriceFontSize",
        "product-card-price-font-weight": "layout.productCardPriceFontWeight",
        "product-card-badge-font-size": "layout.productCardBadgeFontSize",
        "product-card-badge-font-weight": "layout.productCardBadgeFontWeight",
        "product-card-was-price-text-prefix": "layout.productCardWasPriceTextPrefix",
        "product-card-was-price-font-size": "layout.productCardWasPriceFontSize",
        "product-card-was-price-font-weight": "layout.productCardWasPriceFontWeight",
        "product-card-width": "layout.productCardWidth",
        "product-card-height": "layout.productCardHeight",
        "product-card-text-spacing": "layout.productCardTextSpacing",
        "product-card-text-top-padding": "layout.productCardTextTopPadding",
        "product-card-text-bottom-padding": "layout.productCardTextBottomPadding",
        "product-card-text-horizontal-padding": "layout.productCardTextHorizontalPadding",
        "product-card-carousel-spacing": "layout.productCardCarouselSpacing",
        "product-card-carousel-horizontal-padding": "layout.productCardCarouselHorizontalPadding",

        // Colors - CTA Button
        "cta-button-background-color": "colors.ctaButton.background",
        "cta-button-text-color": "colors.ctaButton.text",
        "cta-button-icon-color": "colors.ctaButton.iconColor",

        // Layout - CTA Button
        "cta-button-border-radius": "layout.ctaButtonBorderRadius",
        "cta-button-horizontal-padding": "layout.ctaButtonHorizontalPadding",
        "cta-button-vertical-padding": "layout.ctaButtonVerticalPadding",
        "cta-button-font-size": "layout.ctaButtonFontSize",
        "cta-button-font-weight": "layout.ctaButtonFontWeight",
        "cta-button-icon-size": "layout.ctaButtonIconSize",

        // Layout - Agent Icon
        "agent-icon-size": "layout.agentIconSize",
        "agent-icon-spacing": "layout.agentIconSpacing",

        // Colors - Input Icons
        "input-send-icon-color": "colors.input.sendIconColor",
        "input-send-arrow-icon-color": "colors.input.sendArrowIconColor",
        "input-send-arrow-background-color": "colors.input.sendArrowBackgroundColor",
        "input-mic-icon-color": "colors.input.micIconColor",
        "input-mic-recording-icon-color": "colors.input.micRecordingIconColor",

        // Colors - Welcome Prompts
        "welcome-prompt-background-color": "colors.welcomePrompt.backgroundColor",
        "welcome-prompt-text-color": "colors.welcomePrompt.textColor",

        // Layout - Welcome Screen
        "header-title-font-size": "layout.headerTitleFontSize",
        "welcome-title-font-size": "layout.welcomeTitleFontSize",
        "welcome-text-align": "layout.welcomeTextAlign",
        "welcome-content-padding": "layout.welcomeContentPadding",
        "welcome-prompt-image-size": "layout.welcomePromptImageSize",
        "welcome-prompt-spacing": "layout.welcomePromptSpacing",
        "welcome-title-bottom-spacing": "layout.welcomeTitleBottomSpacing",
        "welcome-prompts-top-spacing": "layout.welcomePromptsTopSpacing",
        "welcome-prompt-padding": "layout.welcomePromptPadding",
        "welcome-prompt-corner-radius": "layout.welcomePromptCornerRadius",

        // Colors - Thinking Animation
        "thinking-dot-color": "colors.thinking.dotColor",

        // Layout - Thinking Animation
        "thinking-dot-size": "layout.thinkingDotSize",
        "thinking-dot-spacing": "layout.thinkingDotSpacing",
        "thinking-bubble-border-radius": "layout.thinkingBubbleBorderRadius",
        "thinking-bubble-padding-horizontal": "layout.thinkingBubblePaddingHorizontal",
        "thinking-bubble-padding-vertical": "layout.thinkingBubblePaddingVertical",
        "thinking-dot-vertical-alignment": "layout.thinkingDotVerticalAlignment",
    ]

    // MARK: - Theme token model reflection

    static func collectLeafPropertyPaths(from rootValue: Any, rootPath: String) -> [String] {
        let mirror = Mirror(reflecting: rootValue)

        // Treat optionals as leafs for coverage purposes (nil optionals will not have children).
        if mirror.displayStyle == .optional {
            return rootPath.isEmpty ? [] : [rootPath]
        }

        if isLeafValue(rootValue) {
            return rootPath.isEmpty ? [] : [rootPath]
        }

        guard let displayStyle = mirror.displayStyle, displayStyle == .struct else {
            return rootPath.isEmpty ? [] : [rootPath]
        }

        var results: [String] = []
        for child in mirror.children {
            guard let label = child.label else { continue }

            let nextPath = rootPath.isEmpty ? label : "\(rootPath).\(label)"
            results.append(contentsOf: collectLeafPropertyPaths(from: child.value, rootPath: nextPath))
        }
        return results
    }

    static func isLeafValue(_ value: Any) -> Bool {
        // Primitives and common theme leaf types
        if value is String || value is Int || value is Bool {
            return true
        }
        if value is CGFloat {
            return true
        }

        // Theme value objects we consider leafs (we do not require per-field coverage)
        if value is CodableColor || value is CodableFontWeight || value is ConciergePadding || value is ConciergeShadow {
            return true
        }

        // Component helpers (deep coverage for these does not add value, and they are not currently themed via CSS)
        if value is ConciergeBorderStyle {
            return true
        }

        return false
    }

    // MARK: - Theme token property allowlist

    static func isAllowlistedThemePropertyPath(_ path: String) -> Bool {
        // Typography: iOS currently only supports configuring font family and line height via CSS variables.
        if path == "typography.fontSize" || path == "typography.fontWeight" {
            return true
        }

        // Colors: these groups exist in the model but are not currently exposed as CSS variables.
        if path.hasPrefix("colors.citation.") {
            return true
        }
        if path == "colors.primary.secondary" {
            return true
        }
        if path == "colors.surface.light" || path == "colors.surface.dark" {
            return true
        }

        // Welcome prompt colors are optional and covered by CSS mappings (nil by default).
        // Input icon colors are optional (nil by default), covered by CSS mappings.
        // These are reported as leaf optionals that don't have values at init.

        // Welcome screen layout tokens are optional (nil by default).
        // They are covered by CSS key mappings but default to nil.

        // Components are derived from canonical tokens on iOS. We intentionally do not require CSS coverage
        // for component style fields because they are not the source of truth.
        if path.hasPrefix("components.") {
            return true
        }

        return false
    }
}


