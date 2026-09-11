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

/// Simple two-color linear gradient for theme tokens that support either a solid color or a gradient
/// (ex: input bar border, mic/send icon colors, mic waveform gradient) -- pick a start and end color,
/// with angle as an optional configuration knob on top rather than an arbitrary multi-stop system.
public struct ConciergeGradient: Codable, Equatable {
    public var startColor: CodableColor
    public var endColor: CodableColor
    /// Degrees, CSS `linear-gradient` convention: 0 = "to top", increases clockwise. Default 180 = "to bottom"
    /// (matches the waveform gradient's vertical top-to-bottom direction when left unconfigured).
    public var angle: CGFloat

    public init(startColor: CodableColor, endColor: CodableColor, angle: CGFloat = 180) {
        self.startColor = startColor
        self.endColor = endColor
        self.angle = angle
    }

    /// The gradient line's start/end points in unit space, derived from `angle`. Split out from
    /// `linearGradient` so the angle math is directly unit-testable (SwiftUI's `LinearGradient` itself
    /// exposes no way to read back its start/end points).
    /// Exact for the 4 axis-aligned angles (0/90/180/270 = to-top/right/bottom/left). Approximate at other
    /// angles: does not correct for non-square view aspect ratio or CSS's corner-reaching line-length scaling.
    var unitPoints: (start: UnitPoint, end: UnitPoint) {
        let radians = angle * .pi / 180
        let dx = sin(radians) * 0.5
        let dy = -cos(radians) * 0.5
        return (
            UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }

    /// Converts the CSS-style angle + two colors into a SwiftUI `LinearGradient`.
    public var linearGradient: LinearGradient {
        let points = unitPoints
        return LinearGradient(
            gradient: Gradient(colors: [startColor.color, endColor.color]),
            startPoint: points.start,
            endPoint: points.end
        )
    }

    /// Whether this gradient has real (non-`.clear`) colors on both ends. `CSSKeyMapper` builds a
    /// gradient incrementally as its 3 CSS keys (start/end/angle) arrive independently, defaulting
    /// whichever side hasn't been set yet to `.clear` as a placeholder -- so a gradient with only one
    /// side configured is not yet meant to render. `conciergeShapeStyle` checks this before treating
    /// the gradient as active, falling back to the solid color/fallback otherwise.
    var isRenderable: Bool {
        startColor != CodableColor(.clear) && endColor != CodableColor(.clear)
    }
}

/// Which underlying style `conciergeShapeStyle` picks for a given (color, gradient, fallback) input.
/// Split out from `conciergeShapeStyle` so the gradient > color > fallback priority is directly
/// assertable in tests -- SwiftUI's `AnyShapeStyle`/`LinearGradient` expose no way to read back what
/// they were constructed from, so testing `conciergeShapeStyle`'s return value directly can't catch
/// e.g. the priority order being accidentally inverted.
enum ConciergeResolvedStyle: Equatable {
    case gradient(ConciergeGradient)
    case color(CodableColor)
    case fallback
}

func resolveConciergeStyle(color: CodableColor?, gradient: ConciergeGradient?) -> ConciergeResolvedStyle {
    if let gradient, gradient.isRenderable {
        return .gradient(gradient)
    }
    if let color {
        return .color(color)
    }
    return .fallback
}

/// Resolves a themed color/gradient pair into a single `ShapeStyle`, preferring the gradient when
/// present and renderable (see `ConciergeGradient.isRenderable`). Used by views that render either a
/// solid color or a gradient through the same `.foregroundStyle`/`.stroke`/`.fill` call.
func conciergeShapeStyle(color: CodableColor?, gradient: ConciergeGradient?, fallback: Color) -> AnyShapeStyle {
    switch resolveConciergeStyle(color: color, gradient: gradient) {
    case .gradient(let gradient):
        return AnyShapeStyle(gradient.linearGradient)
    case .color(let color):
        return AnyShapeStyle(color.color)
    case .fallback:
        return AnyShapeStyle(fallback)
    }
}

/// Text alignment configuration
/// Matches SwiftUI's TextAlignment cases: .leading, .center, .trailing
public enum ConciergeTextAlignment: String, Codable {
    case leading
    case center
    case trailing

    /// Parses a text-align string into `ConciergeTextAlignment`. Case-insensitive. Accepts web, Compose,
    /// and SwiftUI idioms so the same string value can be used across platforms:
    ///  - `"left"` / `"leading"` / `"start"`  -> `.leading`
    ///  - `"center"` / `"justify"`            -> `.center`
    ///  - `"right"` / `"trailing"` / `"end"`  -> `.trailing`
    /// Unknown values fall back to `.leading` and log a warning.
    public static func parse(_ value: String) -> ConciergeTextAlignment {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "left", "leading", "start":
            return .leading
        case "right", "trailing", "end":
            return .trailing
        case "center", "justify":
            return .center
        default:
            Log.warning(label: ConciergeConstants.LOG_TAG, "Unknown text alignment '\(trimmed)', defaulting to leading.")
            return .leading
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ConciergeTextAlignment.parse(rawValue)
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

    /// Converts a theme font weight into the closest UIKit `UIFont.Weight`.
    func toUIFontWeight() -> UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    /// Converts a theme font weight into the closest SwiftUI `Font.Weight`.
    func toSwiftUIFontWeight() -> Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
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
