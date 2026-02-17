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

// Library defaults should rely on system colors; apps can brand via .tint and their own extensions.
extension Color {
    // MARK: - Semantic colors (system-based defaults)
    static var TextTitle: Color { Color.primary }
    static var TextBody: Color { Color.secondary }

    // Use environment accent color for accents, and system backgrounds for surfaces
    static var Primary: Color { Color.accentColor }
    static var Secondary: Color { Color.accentColor }
    static var PrimaryLight: Color { Color(UIColor.secondarySystemBackground) }
    static var PrimaryDark: Color { Color(UIColor.systemBackground) }

    // Convenience initializer for hex RGB (e.g., 0xEB1000)
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }

    /// Parses a hex string in the form "#RRGGBB", "RRGGBB", "#RRGGBBAA", or "RRGGBBAA" into a SwiftUI Color.
    /// If parsing fails, returns the provided default color (system background by default).
    static func fromHexString(_ hexString: String, default defaultColor: Color = Color(UIColor.systemBackground)) -> Color {
        let cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        if cleaned.count == 6, let value = UInt(cleaned, radix: 16) {
            return Color(hex: value)
        }

        // Support #RRGGBBAA (CSS-style hex with trailing alpha).
        if cleaned.count == 8, let value = UInt(cleaned, radix: 16) {
            let rgb = value >> 8
            let alphaByte = value & 0xff
            let alpha = Double(alphaByte) / 255.0
            return Color(hex: rgb, alpha: alpha)
        }

        return defaultColor
    }

    /// Converts a SwiftUI Color to a hex string in the form "#RRGGBB".
    /// If conversion fails (e.g., non-RGB color space), returns "#000000".
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        // Handle different color spaces by converting to RGB
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(format: "#%02X%02X%02X",
                         Int(red * 255),
                         Int(green * 255),
                         Int(blue * 255))
        } else {
            // Fallback for colors that can't be converted to RGB
            return "#000000"
        }
    }
}
