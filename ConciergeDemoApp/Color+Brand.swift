/*
 Copyright 2025 Adobe. All rights reserved.
*/

import SwiftUI

// App-specific brand colors for the demo app. The library itself uses system defaults.
extension Color {
    enum Brand {
        static let red = Color(hex: 0xEB1000)
        static let white = Color.white
        static let black = Color.black
    }

    // Map SDK semantics to app brand
    static var Primary: Color { Brand.red }
    static var Secondary: Color { Brand.red }
    static var TextTitle: Color { Brand.white }
    static var TextBody: Color { Color(white: 1.0, opacity: 0.85) }
    static var PrimaryLight: Color { Color(hex: 0x111111) }
    static var PrimaryDark: Color { Brand.black }
}

// Hex convenience for the app target (duplicated by intent to avoid reaching into the library)
private extension Color {
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


