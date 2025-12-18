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
import AEPServices

// MARK: - Reusable CSS-like Types

/// Padding configuration with individual edge values
/// Replaces CSS padding shorthand (ex: "8px 16px") with explicit SwiftUI compatible values
public struct ConciergePadding: Codable, Equatable {
    public var top: CGFloat
    public var bottom: CGFloat
    public var leading: CGFloat
    public var trailing: CGFloat
    
    public init(top: CGFloat, bottom: CGFloat, leading: CGFloat, trailing: CGFloat) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }
    
    /// Convenience initializer for vertical/horizontal padding (common CSS pattern: "8px 16px")
    public init(vertical: CGFloat, horizontal: CGFloat) {
        self.top = vertical
        self.bottom = vertical
        self.leading = horizontal
        self.trailing = horizontal
    }
    
    /// Convenience initializer for uniform padding (CSS pattern: "8px")
    public init(all: CGFloat) {
        self.top = all
        self.bottom = all
        self.leading = all
        self.trailing = all
    }
    
    /// SwiftUI EdgeInsets conversion
    public var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }

    public static func == (lhs: ConciergePadding, rhs: ConciergePadding) -> Bool {
        lhs.top == rhs.top &&
        lhs.bottom == rhs.bottom &&
        lhs.leading == rhs.leading &&
        lhs.trailing == rhs.trailing
    }
}

/// Shadow configuration with individual component values
/// Replaces CSS box shadow string (ex: "0 4px 16px 0 #00000029") with explicit SwiftUI compatible values
public struct ConciergeShadow: Codable, Equatable {
    public var offsetX: CGFloat
    public var offsetY: CGFloat
    public var blurRadius: CGFloat
    public var spreadRadius: CGFloat
    public var color: CodableColor
    public var isEnabled: Bool
    
    public init(
        offsetX: CGFloat,
        offsetY: CGFloat,
        blurRadius: CGFloat,
        spreadRadius: CGFloat,
        color: CodableColor,
        isEnabled: Bool = true
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.blurRadius = blurRadius
        self.spreadRadius = spreadRadius
        self.color = color
        self.isEnabled = isEnabled
    }
    
    /// Disabled shadow (equivalent to CSS "none")
    public static var none: ConciergeShadow {
        ConciergeShadow(
            offsetX: 0,
            offsetY: 0,
            blurRadius: 0,
            spreadRadius: 0,
            color: CodableColor(Color.clear),
            isEnabled: false
        )
    }

    public static func == (lhs: ConciergeShadow, rhs: ConciergeShadow) -> Bool {
        lhs.offsetX == rhs.offsetX &&
        lhs.offsetY == rhs.offsetY &&
        lhs.blurRadius == rhs.blurRadius &&
        lhs.spreadRadius == rhs.spreadRadius &&
        lhs.color == rhs.color &&
        lhs.isEnabled == rhs.isEnabled
    }
}

/// Text alignment configuration
/// Matches SwiftUI's TextAlignment cases: .leading, .center, .trailing
public enum ConciergeTextAlignment: String, Codable {
    case leading
    case center
    case trailing
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "left":
            self = .leading
        case "right":
            self = .trailing
        case "center", "justify":
            self = .center
        default:
            Log.warning(label: ConciergeConstants.LOG_TAG, "Unknown message alignment '\(rawValue)', defaulting to leading.")
            self = .leading
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

/// Font weight configuration
/// Matches SwiftUI's Font.Weight cases: .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black
public enum CodableFontWeight: String, Codable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

/// Codable wrapper for SwiftUI Color to enable JSON encoding/decoding
/// Colors are stored as hex strings (ex: "#RRGGBB")
public struct CodableColor: Codable, Equatable {
    public var color: Color
    
    public init(_ color: Color) {
        self.color = color
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        self.color = Color.fromHexString(hexString)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let hexString = color.toHexString()
        try container.encode(hexString)
    }

    public static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        lhs.color.toHexString() == rhs.color.toHexString()
    }
}

