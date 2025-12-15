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

public struct ConciergeTheme {
    public var primary: Color
    public var secondary: Color
    public var onPrimary: Color
    public var textBody: Color
    public var agentBubble: Color
    public var onAgent: Color
    public var surfaceLight: Color
    public var surfaceDark: Color
    public var citationBackground: Color
    public var citationText: Color

    public init(
        primary: Color = .accentColor,
        secondary: Color = .accentColor,
        onPrimary: Color = .primary,
        textBody: Color = .secondary,
        agentBubble: Color = Color(UIColor.secondarySystemBackground),
        onAgent: Color = .primary,
        surfaceLight: Color = Color(UIColor.secondarySystemBackground),
        surfaceDark: Color = Color(UIColor.systemBackground),
        citationBackground: Color = Color(UIColor.systemGray3),
        citationText: Color = Color(UIColor.label)
    ) {
        self.primary = primary
        self.secondary = secondary
        self.onPrimary = onPrimary
        self.textBody = textBody
        self.agentBubble = agentBubble
        self.onAgent = onAgent
        self.surfaceLight = surfaceLight
        self.surfaceDark = surfaceDark
        self.citationBackground = citationBackground
        self.citationText = citationText
    }
}

private struct ConciergeThemeKey: EnvironmentKey {
    static let defaultValue = ConciergeTheme()
}

public extension EnvironmentValues {
    var conciergeTheme: ConciergeTheme {
        get { self[ConciergeThemeKey.self] }
        set { self[ConciergeThemeKey.self] = newValue }
    }
}

public extension View {
    func conciergeTheme(_ theme: ConciergeTheme) -> some View {
        environment(\.conciergeTheme, theme)
    }
}

// MARK: - Feedback presentation environment

public struct ConciergeFeedbackPresenter {
    public var present: (_ sentiment: FeedbackSentiment, _ messageId: UUID?) -> Void
    public init(present: @escaping (_ sentiment: FeedbackSentiment, _ messageId: UUID?) -> Void = { _, _ in }) {
        self.present = present
    }
}

private struct ConciergeFeedbackPresenterKey: EnvironmentKey {
    static let defaultValue = ConciergeFeedbackPresenter()
}

public extension EnvironmentValues {
    var conciergeFeedbackPresenter: ConciergeFeedbackPresenter {
        get { self[ConciergeFeedbackPresenterKey.self] }
        set { self[ConciergeFeedbackPresenterKey.self] = newValue }
    }
}

public extension View {
    func conciergeFeedbackPresenter(_ presenter: ConciergeFeedbackPresenter) -> some View {
        environment(\.conciergeFeedbackPresenter, presenter)
    }
}

// MARK: - Feedback options environment (array of unique strings)
private struct ConciergePositiveFeedbackOptionsKey: EnvironmentKey {
    static let defaultValue: [String] = [
        "Helpful and relevant recommendations",
        "Clear and easy to understand",
        "Friendly and conversational tone",
        "Visually appealing presentation",
        "Other"
    ]
}

private struct ConciergeNegativeFeedbackOptionsKey: EnvironmentKey {
    static let defaultValue: [String] = [
        "Didn't understand my request",
        "Unhelpful or irrelevant information",
        "Too vague or lacking detail",
        "Errors or poor quality response",
        "Other"
    ]
}

public extension EnvironmentValues {
    var conciergePositiveFeedbackOptions: [String] {
        get { self[ConciergePositiveFeedbackOptionsKey.self] }
        set { self[ConciergePositiveFeedbackOptionsKey.self] = newValue }
    }
    var conciergeNegativeFeedbackOptions: [String] {
        get { self[ConciergeNegativeFeedbackOptionsKey.self] }
        set { self[ConciergeNegativeFeedbackOptionsKey.self] = newValue }
    }
}

// MARK: - Consolidated feedback configuration

public struct ConciergeFeedbackConfig {
    public var positiveOptions: [String]
    public var negativeOptions: [String]
    public var positiveNotesEnabled: Bool
    public var negativeNotesEnabled: Bool

    public init(
        positiveOptions: [String] = [
            "Helpful and relevant recommendations",
            "Clear and easy to understand",
            "Friendly and conversational tone",
            "Visually appealing presentation",
            "Other"
        ],
        negativeOptions: [String] = [
            "Didn't understand my request",
            "Unhelpful or irrelevant information",
            "Too vague or lacking detail",
            "Errors or poor quality response",
            "Other"
        ],
        positiveNotesEnabled: Bool = true,
        negativeNotesEnabled: Bool = true
    ) {
        self.positiveOptions = positiveOptions
        self.negativeOptions = negativeOptions
        self.positiveNotesEnabled = positiveNotesEnabled
        self.negativeNotesEnabled = negativeNotesEnabled
    }
}

private struct ConciergeFeedbackConfigKey: EnvironmentKey {
    static let defaultValue = ConciergeFeedbackConfig()
}

public extension EnvironmentValues {
    var conciergeFeedbackConfig: ConciergeFeedbackConfig {
        get { self[ConciergeFeedbackConfigKey.self] }
        set { self[ConciergeFeedbackConfigKey.self] = newValue }
    }
}

public extension View {
    func conciergeFeedbackConfig(_ config: ConciergeFeedbackConfig) -> some View {
        environment(\.conciergeFeedbackConfig, config)
    }
}

// MARK: - Concierge response placeholder configuration

public struct ConciergeResponsePlaceholderConfig {
    public var loadingText: String
    public var primaryDotColor: Color

    public init(loadingText: String = "Thinking...", primaryDotColor: Color = .accentColor) {
        self.loadingText = loadingText
        self.primaryDotColor = primaryDotColor
    }
}

private struct ConciergePlaceholderConfigKey: EnvironmentKey {
    static let defaultValue = ConciergeResponsePlaceholderConfig()
}

public extension EnvironmentValues {
    var conciergePlaceholderConfig: ConciergeResponsePlaceholderConfig {
        get { self[ConciergePlaceholderConfigKey.self] }
        set { self[ConciergePlaceholderConfigKey.self] = newValue }
    }
}

public extension View {
    func conciergePlaceholderConfig(_ config: ConciergeResponsePlaceholderConfig) -> some View {
        environment(\.conciergePlaceholderConfig, config)
    }
}


