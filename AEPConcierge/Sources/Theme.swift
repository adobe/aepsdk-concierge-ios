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


