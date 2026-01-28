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

// CSS to mobile value converters
public enum CSSValueConverter {
    /// Parses CSS box shadow string (ex: "0 4px 16px 0 #00000029" or "none")
    public static func parseBoxShadow(_ cssValue: String) -> ConciergeShadow {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.lowercased() == "none" {
            return .none
        }
        
        // Parse: "offsetX offsetY blurRadius spreadRadius color"
        // Example: "0 4px 16px 0 #00000029"
        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 3 else {
            return .none
        }
        
        let offsetX = parsePxValue(components[0]) ?? 0
        let offsetY = parsePxValue(components[1]) ?? 0
        let blurRadius = parsePxValue(components[2]) ?? 0
        let spreadRadius = components.count >= 4 ? (parsePxValue(components[3]) ?? 0) : 0
        let colorString = components.count >= 5 ? components[4] : "#000000"
        let normalizedColorString = colorString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let color: CodableColor
        if isValidHexColor(normalizedColorString) {
            color = CodableColor(Color.fromHexString(normalizedColorString))
        } else {
            Log.warning(label: ConciergeConstants.LOG_TAG, "Unsupported box shadow color value '\(colorString)'. Expected hex format (#RRGGBB). Defaulting to #000000.")
            color = CodableColor(Color.fromHexString("#000000"))
        }
        
        return ConciergeShadow(
            offsetX: offsetX,
            offsetY: offsetY,
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
            color: color,
            isEnabled: true
        )
    }
    
    /// Parses CSS padding string to ConciergePadding
    /// Supports: "8px", "8px 16px", "8px 16px 4px", "8px 16px 4px 2px"
    public static func parsePadding(_ cssValue: String) -> ConciergePadding {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard !components.isEmpty else {
            return ConciergePadding(all: 0)
        }
        
        let values = components.compactMap { parsePxValue($0) }
        
        switch values.count {
        case 1:
            // "8px" -> all sides
            return ConciergePadding(all: values[0])
        case 2:
            // "8px 16px" -> vertical horizontal
            return ConciergePadding(vertical: values[0], horizontal: values[1])
        case 3:
            // "8px 16px 4px" -> top horizontal bottom
            return ConciergePadding(
                top: values[0],
                bottom: values[2],
                leading: values[1],
                trailing: values[1]
            )
        case 4:
            // "8px 16px 4px 2px" -> top right bottom left
            return ConciergePadding(
                top: values[0],
                bottom: values[2],
                leading: values[3],
                trailing: values[1]
            )
        default:
            return ConciergePadding(all: 0)
        }
    }
    
    /// Parses CSS px value (ex: "52px", "12px") to CGFloat
    public static func parsePxValue(_ cssValue: String) -> CGFloat? {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "px", with: "", options: .caseInsensitive)
        return CGFloat(Double(cleaned) ?? 0)
    }
    
    /// Parses CSS percentage value (ex: "100%") to CGFloat?
    /// Returns nil for "100%" (no constraint), or percentage as decimal (0.0-1.0)
    public static func parsePercentage(_ cssValue: String) -> CGFloat? {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("%") else { return nil }
        
        let cleaned = trimmed.replacingOccurrences(of: "%", with: "")
        guard let value = Double(cleaned) else { return nil }
        
        // 100% means no constraint (nil), otherwise return as decimal
        if value >= 100 {
            return nil
        }
        return CGFloat(value / 100.0)
    }
    
    /// Parses CSS width value (px or percentage) to CGFloat?
    /// "100%" -> nil (no max width), "768px" -> 768.0
    public static func parseWidth(_ cssValue: String) -> CGFloat? {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasSuffix("%") {
            return parsePercentage(trimmed)
        } else if trimmed.hasSuffix("px") {
            return parsePxValue(trimmed)
        } else {
            // Try parsing as number directly
            return CGFloat(Double(trimmed) ?? 0)
        }
    }
    
    /// Parses CSS color string to CodableColor
    /// Supports hex colors: "#007bff", "#FFFFFF"
    public static func parseColor(_ cssValue: String) -> CodableColor {
        return CodableColor(Color.fromHexString(cssValue))
    }
    
    /// Parses CSS font-weight string to CodableFontWeight enum
    /// Supports: "400", "700", "normal", "bold"
    public static func parseFontWeight(_ cssValue: String) -> CodableFontWeight {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch trimmed.lowercased() {
        case "100":
            return .ultraLight
        case "200":
            return .thin
        case "300":
            return .light
        case "400", "normal":
            return .regular
        case "500":
            return .medium
        case "600":
            return .semibold
        case "700", "bold":
            return .bold
        case "800":
            return .heavy
        case "900":
            return .black
        default:
            return .regular
        }
    }
    
    /// Parses CSS text alignment string to ConciergeTextAlignment
    /// Maps "left" -> .leading, "right" -> .trailing for RTL support
    public static func parseTextAlignment(_ cssValue: String) -> ConciergeTextAlignment {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch trimmed {
        case "left":
            return .leading
        case "right":
            return .trailing
        case "center":
            return .center
        case "justify":
            return .leading // SwiftUI doesn't support justify, fallback to leading
        default:
            return .leading
        }
    }
    
    /// Parses CSS order value (string number) to Int
    public static func parseOrder(_ cssValue: String) -> Int {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed) ?? 0
    }
    
    /// Parses CSS font-family string (takes first font name, ignores font stack)
    public static func parseFontFamily(_ cssValue: String) -> String {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract first font name from font stack (ex: "'Adobe Clean', adobe-clean, ..." -> "Adobe Clean")
        // Remove quotes and take first entry
        let cleaned = trimmed.replacingOccurrences(of: "'", with: "")
        let fonts = cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return fonts.first ?? ""
    }
    
    /// Parses CSS line-height value (can be unitless ratio like "1.75" or px value)
    public static func parseLineHeight(_ cssValue: String) -> CGFloat {
        let trimmed = cssValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it has "px", parse as px value
        if trimmed.hasSuffix("px") {
            return parsePxValue(trimmed) ?? 1.75
        }
        
        // Otherwise parse as unitless ratio
        return CGFloat(Double(trimmed) ?? 1.75)
    }
}

extension CSSValueConverter {
    private static func isValidHexColor(_ cssValue: String) -> Bool {
        let trimmed = cssValue.hasPrefix("#") ? String(cssValue.dropFirst()) : cssValue
        guard trimmed.count == 6 || trimmed.count == 8 else {
            return false
        }
        
        let validCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        return trimmed.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }
}

