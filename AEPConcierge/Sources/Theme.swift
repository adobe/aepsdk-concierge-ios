/*
 Copyright 2025 Adobe. All rights reserved.
*/

import SwiftUI

public struct ConciergeTheme {
    public var primary: Color
    public var secondary: Color
    public var onPrimary: Color
    public var textBody: Color
    public var surfaceLight: Color
    public var surfaceDark: Color

    public init(
        primary: Color = .accentColor,
        secondary: Color = .accentColor,
        onPrimary: Color = .primary,
        textBody: Color = .secondary,
        surfaceLight: Color = Color(UIColor.secondarySystemBackground),
        surfaceDark: Color = Color(UIColor.systemBackground)
    ) {
        self.primary = primary
        self.secondary = secondary
        self.onPrimary = onPrimary
        self.textBody = textBody
        self.surfaceLight = surfaceLight
        self.surfaceDark = surfaceDark
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


