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

// MARK: - Environment Key for ConciergeTheme

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

// MARK: - WebView presentation environment

/// Presenter for opening URLs in an in-app webview popover.
/// Child views can use this to trigger the webview popover without needing direct access to the parent view's state.
public struct ConciergeWebViewPresenter {
    /// Opens the provided URL in the webview popover.
    public var openURL: (_ url: URL) -> Void
    
    public init(openURL: @escaping (_ url: URL) -> Void = { _ in }) {
        self.openURL = openURL
    }
}

private struct ConciergeWebViewPresenterKey: EnvironmentKey {
    static let defaultValue = ConciergeWebViewPresenter()
}

public extension EnvironmentValues {
    var conciergeWebViewPresenter: ConciergeWebViewPresenter {
        get { self[ConciergeWebViewPresenterKey.self] }
        set { self[ConciergeWebViewPresenterKey.self] = newValue }
    }
}
