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
    public var conciergeBackground: CodableColor
    public var conciergeText: CodableColor
    public var conciergeLink: CodableColor
    
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
    public var primaryBackground: CodableColor
    public var primaryText: CodableColor
    public var primaryHover: CodableColor
    public var secondaryBorder: CodableColor
    public var secondaryText: CodableColor
    public var secondaryHover: CodableColor
    public var secondaryHoverText: CodableColor
    public var submitFill: CodableColor
    public var submitFillDisabled: CodableColor
    public var submitText: CodableColor
    public var submitTextHover: CodableColor
    public var disabledBackground: CodableColor
    
    public init(
        primaryBackground: CodableColor = CodableColor(Color.accentColor),
        primaryText: CodableColor = CodableColor(Color.white),
        primaryHover: CodableColor = CodableColor(Color.accentColor),
        secondaryBorder: CodableColor = CodableColor(Color.primary),
        secondaryText: CodableColor = CodableColor(Color.primary),
        secondaryHover: CodableColor = CodableColor(Color.primary),
        secondaryHoverText: CodableColor = CodableColor(Color.white),
        // Default composer submit control renders as an icon without a background.
        submitFill: CodableColor = CodableColor(Color.clear),
        submitFillDisabled: CodableColor = CodableColor(Color.clear),
        submitText: CodableColor = CodableColor(Color.accentColor),
        submitTextHover: CodableColor = CodableColor(Color.accentColor),
        disabledBackground: CodableColor = CodableColor(Color.clear)
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
    public var background: CodableColor
    public var text: CodableColor
    public var outline: CodableColor? // TODO: are gradients required?
    public var outlineFocus: CodableColor
    
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
    public var iconButtonHoverBackground: CodableColor
    
    public init(
        // Default feedback icons render without a background unless explicitly themed.
        iconButtonBackground: CodableColor = CodableColor(Color.clear),
        iconButtonHoverBackground: CodableColor = CodableColor(Color.clear)
    ) {
        self.iconButtonBackground = iconButtonBackground
        self.iconButtonHoverBackground = iconButtonHoverBackground
    }
}

/// Primary color tokens
public struct ConciergePrimaryColors: Codable {
    public var primary: CodableColor
    public var secondary: CodableColor
    public var text: CodableColor
    
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
    public var primary: ConciergePrimaryColors
    public var surface: ConciergeSurfaceColors
    public var message: ConciergeMessageColors
    public var button: ConciergeButtonColors
    public var input: ConciergeInputColors
    public var citation: ConciergeCitationColors
    public var feedback: ConciergeFeedbackColors
    public var disclaimer: CodableColor
    
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

