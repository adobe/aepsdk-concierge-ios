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

import AEPServices

// MARK: - CSS Key to Property Mapper

/// Maps CSS variable names (ex: "--input-box-shadow") directly to property assignments
/// Used to convert web CSS theme format to ConciergeTheme structure
public enum CSSKeyMapper {
    /// Direct assignment function that converts CSS value and applies it to theme
    public typealias Assignment = (String, inout ConciergeTheme) -> Void
    
    /// Mapping from CSS variable name (without --) to direct assignment function
    private static let cssToAssignmentMap: [String: Assignment] = [
        // Typography
        "font-family": { cssValue, theme in theme.typography.fontFamily = CSSValueConverter.parseFontFamily(cssValue) },
        "line-height-body": { cssValue, theme in theme.typography.lineHeight = CSSValueConverter.parseLineHeight(cssValue) },
        
        // Colors - Primary
        "color-primary": { cssValue, theme in theme.colors.primary.primary = CSSValueConverter.parseColor(cssValue) },
        "color-text": { cssValue, theme in theme.colors.primary.text = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Surface
        "main-container-background": { cssValue, theme in theme.colors.surface.mainContainerBackground = CSSValueConverter.parseColor(cssValue) },
        "main-container-bottom-background": { cssValue, theme in theme.colors.surface.mainContainerBottomBackground = CSSValueConverter.parseColor(cssValue) },
        "message-blocker-background": { cssValue, theme in theme.colors.surface.messageBlockerBackground = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Message
        "message-user-background": { cssValue, theme in theme.colors.message.userBackground = CSSValueConverter.parseColor(cssValue) },
        "message-user-text": { cssValue, theme in theme.colors.message.userText = CSSValueConverter.parseColor(cssValue) },
        "message-concierge-background": { cssValue, theme in theme.colors.message.conciergeBackground = CSSValueConverter.parseColor(cssValue) },
        "message-concierge-text": { cssValue, theme in theme.colors.message.conciergeText = CSSValueConverter.parseColor(cssValue) },
        "message-concierge-link-color": { cssValue, theme in theme.colors.message.conciergeLink = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Button
        "button-primary-background": { cssValue, theme in theme.colors.button.primaryBackground = CSSValueConverter.parseColor(cssValue) },
        "button-primary-text": { cssValue, theme in theme.colors.button.primaryText = CSSValueConverter.parseColor(cssValue) },
        "button-secondary-border": { cssValue, theme in theme.colors.button.secondaryBorder = CSSValueConverter.parseColor(cssValue) },
        "button-secondary-text": { cssValue, theme in theme.colors.button.secondaryText = CSSValueConverter.parseColor(cssValue) },
        "submit-button-fill-color": { cssValue, theme in theme.colors.button.submitFill = CSSValueConverter.parseColor(cssValue) },
        "submit-button-fill-color-disabled": { cssValue, theme in theme.colors.button.submitFillDisabled = CSSValueConverter.parseColor(cssValue) },
        "color-button-submit": { cssValue, theme in theme.colors.button.submitText = CSSValueConverter.parseColor(cssValue) },
        "button-disabled-background": { cssValue, theme in theme.colors.button.disabledBackground = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Input
        "input-background": { cssValue, theme in
            theme.colors.input.background = CSSValueConverter.parseColor(cssValue)
        },
        "input-text-color": { cssValue, theme in
            theme.colors.input.text = CSSValueConverter.parseColor(cssValue)
        },
        "input-outline-color": { cssValue, theme in
            // Handle gradients - if starts with "linear-gradient", set to nil
            if cssValue.hasPrefix("linear-gradient") {
                theme.colors.input.outline = nil
            } else {
                theme.colors.input.outline = CSSValueConverter.parseColor(cssValue)
            }
        },
        "input-focus-outline-color": { cssValue, theme in theme.colors.input.outlineFocus = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Feedback
        "feedback-icon-btn-background": { cssValue, theme in theme.colors.feedback.iconButtonBackground = CSSValueConverter.parseColor(cssValue) },
        
        // Colors - Disclaimer
        "disclaimer-color": { cssValue, theme in
            theme.colors.disclaimer = CSSValueConverter.parseColor(cssValue)
        },
        
        // Layout - Input
        // Desktop height is intentionally ignored; mobile height drives the experience
        "input-height-mobile": { cssValue, theme in
            let parsedHeight = CSSValueConverter.parsePxValue(cssValue) ?? 52
            theme.layout.inputHeight = parsedHeight
        },
        // Desktop radius is intentionally ignored; mobile radius drives the experience
        "input-border-radius-mobile": { cssValue, theme in
            let parsedRadius = CSSValueConverter.parsePxValue(cssValue) ?? 12
            theme.layout.inputBorderRadius = parsedRadius
        },
        "input-outline-width": { cssValue, theme in theme.layout.inputOutlineWidth = CSSValueConverter.parsePxValue(cssValue) ?? 2 },
        "input-focus-outline-width": { cssValue, theme in theme.layout.inputFocusOutlineWidth = CSSValueConverter.parsePxValue(cssValue) ?? 2 },
        "input-font-size": { cssValue, theme in theme.layout.inputFontSize = CSSValueConverter.parsePxValue(cssValue) ?? 16 },
        "input-button-height": { cssValue, theme in theme.layout.inputButtonHeight = CSSValueConverter.parsePxValue(cssValue) ?? 32 },
        "input-button-width": { cssValue, theme in theme.layout.inputButtonWidth = CSSValueConverter.parsePxValue(cssValue) ?? 32 },
        "input-button-border-radius": { cssValue, theme in theme.layout.inputButtonBorderRadius = CSSValueConverter.parsePxValue(cssValue) ?? 8 },
        "input-box-shadow": { cssValue, theme in theme.layout.inputBoxShadow = CSSValueConverter.parseBoxShadow(cssValue) },
        
        // Layout - Message
        "message-border-radius": { cssValue, theme in theme.layout.messageBorderRadius = CSSValueConverter.parsePxValue(cssValue) ?? 10 },
        "message-padding": { cssValue, theme in
            theme.layout.messagePadding = CSSValueConverter.parsePadding(cssValue)
        },
        "message-max-width": { cssValue, theme in
            theme.layout.messageMaxWidth = CSSValueConverter.parseWidth(cssValue)
        },
        
        // Layout - Chat
        "chat-interface-max-width": { cssValue, theme in theme.layout.chatInterfaceMaxWidth = CSSValueConverter.parsePxValue(cssValue) ?? 768 },
        "chat-history-padding": { cssValue, theme in theme.layout.chatHistoryPadding = CSSValueConverter.parsePxValue(cssValue) ?? 16 },
        "chat-history-padding-top-expanded": { cssValue, theme in theme.layout.chatHistoryPaddingTopExpanded = CSSValueConverter.parsePxValue(cssValue) ?? 0 },
        "chat-history-bottom-padding": { cssValue, theme in theme.layout.chatHistoryBottomPadding = CSSValueConverter.parsePxValue(cssValue) ?? 0 },
        "message-blocker-height": { cssValue, theme in theme.layout.messageBlockerHeight = CSSValueConverter.parsePxValue(cssValue) ?? 105 },
        
        // Layout - Card
        "border-radius-card": { cssValue, theme in
            theme.layout.borderRadiusCard = CSSValueConverter.parsePxValue(cssValue) ?? 16
        },
        "multimodal-card-box-shadow": { cssValue, theme in
            theme.layout.multimodalCardBoxShadow = CSSValueConverter.parseBoxShadow(cssValue)
        },
        
        // Layout - Button
        "button-height-s": { cssValue, theme in theme.layout.buttonHeightSmall = CSSValueConverter.parsePxValue(cssValue) ?? 30 },
        
        // Layout - Feedback
        "feedback-container-gap": { cssValue, theme in theme.layout.feedbackContainerGap = CSSValueConverter.parsePxValue(cssValue) ?? 4 },
        
        // Layout - Citations
        "citations-text-font-weight": { cssValue, theme in theme.layout.citationsTextFontWeight = CSSValueConverter.parseFontWeight(cssValue) },
        "citations-desktop-button-font-size": { cssValue, theme in theme.layout.citationsDesktopButtonFontSize = CSSValueConverter.parsePxValue(cssValue) ?? 14 },
        
        // Layout - Disclaimer
        "disclaimer-font-size": { cssValue, theme in theme.layout.disclaimerFontSize = CSSValueConverter.parsePxValue(cssValue) ?? 12 },
        "disclaimer-font-weight": { cssValue, theme in theme.layout.disclaimerFontWeight = CSSValueConverter.parseFontWeight(cssValue) },
        
        // Layout - Welcome Order (also sets components)
        "welcome-input-order": { cssValue, theme in
            theme.layout.welcomeInputOrder = CSSValueConverter.parseOrder(cssValue)
        },
        "welcome-cards-order": { cssValue, theme in
            theme.layout.welcomeCardsOrder = CSSValueConverter.parseOrder(cssValue)
        },
        
        // Layout - Feedback (button hit target size)
        "feedback-icon-btn-size-desktop": { cssValue, theme in theme.layout.feedbackIconButtonSize = CSSValueConverter.parsePxValue(cssValue) ?? 44 },
    ]

    /// Returns the normalized CSS keys (without the leading `--`) that are supported by iOS.
    /// This is primarily intended for unit tests to ensure theme token coverage and to prevent silent drift.
    public static var supportedCSSKeys: Set<String> {
        Set(cssToAssignmentMap.keys)
    }
    
    /// Applies CSS value to ConciergeTheme using the mapped assignment function
    public static func apply(cssKey: String, cssValue: String, to theme: inout ConciergeTheme) {
        // Remove -- prefix if present
        let normalizedKey = cssKey.hasPrefix("--") ? String(cssKey.dropFirst(2)) : cssKey
        
        // Find and execute the assignment function
        if let assignment = cssToAssignmentMap[normalizedKey] {
            assignment(cssValue, &theme)
        } else {
            Log.debug(label: ConciergeConstants.LOG_TAG, "Unknown CSS key '\(normalizedKey)' ignored.")
        }
    }
}

