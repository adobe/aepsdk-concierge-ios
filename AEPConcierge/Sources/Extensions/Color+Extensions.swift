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
}
