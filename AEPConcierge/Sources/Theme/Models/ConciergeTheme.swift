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

// MARK: - Theme Configuration Types

/// Helper CodingKey for decoding dynamic CSS variable names
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Main ConciergeTheme structure that consolidates all theme configuration
/// Maps to the web styleConfiguration format for cross platform compatibility
/// 
/// JSON Structure Mapping:
/// - `metadata` -> metadata
/// - `behavior` -> behavior
/// - `disclaimer` -> disclaimer
/// - `text` -> text/copy (with nested structure matching web dot-notation keys)
/// - `arrays.welcome.examples` -> welcomeExamples
/// - `arrays.feedback.positive.options` -> feedbackPositiveOptions
/// - `arrays.feedback.negative.options` -> feedbackNegativeOptions
/// - `assets` -> assets
/// - `theme` -> colors, layout, typography, components (CSS variables mapped to semantic groups)
public struct ConciergeTheme: Codable {
    public var metadata: ConciergeThemeMetadata
    public var behavior: ConciergeBehaviorConfig
    public var disclaimer: ConciergeDisclaimer
    public var assets: ConciergeAssets
    public var text: ConciergeCopy
    public var arrays: ConciergeArrays
    public var theme: ConciergeThemeTokens
    
    public var typography: ConciergeTypography {
        get { theme.typography }
        set { theme.typography = newValue }
    }
    
    public var colors: ConciergeThemeColors {
        get { theme.colors }
        set { theme.colors = newValue }
    }
    
    public var layout: ConciergeLayout {
        get { theme.layout }
        set { theme.layout = newValue }
    }
    
    public var components: ConciergeComponentStyles {
        get { theme.components }
        set { theme.components = newValue }
    }
    
    public var copy: ConciergeCopy {
        get { text }
        set { text = newValue }
    }
    
    public var welcomeExamples: [ConciergeWelcomeExample] {
        get { arrays.welcomeExamples }
        set { arrays.welcomeExamples = newValue }
    }
    
    public var feedbackPositiveOptions: [String] {
        get { arrays.feedbackPositiveOptions }
        set { arrays.feedbackPositiveOptions = newValue }
    }
    
    public var feedbackNegativeOptions: [String] {
        get { arrays.feedbackNegativeOptions }
        set { arrays.feedbackNegativeOptions = newValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case behavior
        case disclaimer
        case assets
        case text
        case arrays
        case theme
    }
    
    public init(
        metadata: ConciergeThemeMetadata = ConciergeThemeMetadata(),
        behavior: ConciergeBehaviorConfig = ConciergeBehaviorConfig(),
        disclaimer: ConciergeDisclaimer = ConciergeDisclaimer(),
        assets: ConciergeAssets = ConciergeAssets(),
        text: ConciergeCopy = ConciergeCopy(),
        arrays: ConciergeArrays = ConciergeArrays(),
        theme: ConciergeThemeTokens = ConciergeThemeTokens()
    ) {
        self.metadata = metadata
        self.behavior = behavior
        self.disclaimer = disclaimer
        self.assets = assets
        self.text = text
        self.arrays = arrays
        self.theme = theme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode top-level groups
        metadata = try container.decodeIfPresent(ConciergeThemeMetadata.self, forKey: .metadata) ?? ConciergeThemeMetadata()
        behavior = try container.decodeIfPresent(ConciergeBehaviorConfig.self, forKey: .behavior) ?? ConciergeBehaviorConfig()
        disclaimer = try container.decodeIfPresent(ConciergeDisclaimer.self, forKey: .disclaimer) ?? ConciergeDisclaimer()
        assets = try container.decodeIfPresent(ConciergeAssets.self, forKey: .assets) ?? ConciergeAssets()
        
        // Decode text/copy (maps from "text" key)
        do {
            text = try container.decodeIfPresent(ConciergeCopy.self, forKey: .text) ?? ConciergeCopy()
        } catch {
            Log.warning(label: Constants.LOG_TAG, "Failed to decode theme copy: \(error)")
            print("Failed to decode theme copy: \(error)")
            text = ConciergeCopy()
        }
        
        // Decode arrays (maps from "arrays" key)
        do {
            arrays = try container.decodeIfPresent(ConciergeArrays.self, forKey: .arrays) ?? ConciergeArrays()
        } catch {
            Log.warning(label: Constants.LOG_TAG, "Failed to decode theme arrays: \(error)")
            print("Failed to decode theme arrays: \(error)")
            arrays = ConciergeArrays()
        }
        
        // Decode theme tokens or process CSS variables
        if let typedTheme = try? container.decode(ConciergeThemeTokens.self, forKey: .theme) {
            theme = typedTheme
        } else {
            print("Theme key missing or not typed for theme configuration.")
            theme = ConciergeThemeTokens()
            if let themeContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .theme) {
                for cssKey in themeContainer.allKeys {
                    if let cssValue = try? themeContainer.decode(String.self, forKey: cssKey) {
                        CSSKeyMapper.apply(cssKey: cssKey.stringValue, cssValue: cssValue, to: &self)
                    }
                }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(metadata, forKey: .metadata)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(disclaimer, forKey: .disclaimer)
        try container.encode(assets, forKey: .assets)
        try container.encode(text, forKey: .text)
        try container.encode(arrays, forKey: .arrays)
        try container.encode(theme, forKey: .theme)
    }
}
