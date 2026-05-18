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

// MARK: - Font helpers

extension ConciergeTypography {
    /// Returns a SwiftUI `Font` at a fixed point size, resolving from the font family spec
    /// when available, falling back to the legacy `fontFamily` string, then system font.
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let uiFont = ConciergeFontResolver.shared.resolve(spec: fontFamilySpec, size: size, weight: weight.uiFontWeight) {
            return Font(uiFont)
        }
        guard !fontFamily.isEmpty else {
            return .system(size: size, weight: weight)
        }
        return Font(UIFont.fromFamily(fontFamily, size: size, weight: weight.uiFontWeight))
    }

    /// Returns a SwiftUI `Font` scaled to a semantic text style, resolving from the font
    /// family spec when available, falling back to the legacy `fontFamily` string, then system font.
    func font(textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let size = UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle).pointSize
        return font(size: size, weight: weight)
    }

    /// Returns a `UIFont` at a fixed point size, resolving from the font family spec when
    /// available, falling back to the legacy `fontFamily` string, then system font.
    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let uiFont = ConciergeFontResolver.shared.resolve(spec: fontFamilySpec, size: size, weight: weight) {
            return uiFont
        }
        guard !fontFamily.isEmpty else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        return UIFont.fromFamily(fontFamily, size: size, weight: weight)
    }
}
