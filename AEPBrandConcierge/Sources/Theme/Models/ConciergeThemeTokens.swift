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

/// Typed representation of processed theme values
public struct ConciergeThemeTokens: Codable {
    public var typography: ConciergeTypography
    public var colors: ConciergeThemeColors
    public var layout: ConciergeLayout

    public init(
        typography: ConciergeTypography = ConciergeTypography(),
        colors: ConciergeThemeColors = ConciergeThemeColors(),
        layout: ConciergeLayout = ConciergeLayout()
    ) {
        self.typography = typography
        self.colors = colors
        self.layout = layout
    }

    private enum CodingKeys: String, CodingKey {
        case typography, colors, layout
    }

    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(_ stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(stringValue: String) {
            self.init(stringValue)
        }

        init?(intValue: Int) {
            return nil
        }
    }

    /// Decodes the typed theme, restoring defaults for optional layout properties whose absence
    /// would otherwise be indistinguishable from an explicit `null`.
    ///
    /// `ConciergeLayout` relies on synthesized decoding, which maps an absent optional to `nil`
    /// rather than to the property's `init` default. That is the right behaviour for properties
    /// whose default *is* `nil`, but not for `productCardDescriptionMaxLines`, where `nil` means
    /// "unbounded" and the default is `2`. A typed theme written before that property existed has
    /// no such key, and would silently switch from a two-line description to an unbounded one.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typography = try container.decode(ConciergeTypography.self, forKey: .typography)
        colors = try container.decode(ConciergeThemeColors.self, forKey: .colors)

        var decodedLayout = try container.decode(ConciergeLayout.self, forKey: .layout)
        if decodedLayout.productCardDescriptionMaxLines == nil,
           !Self.layoutDeclaresDescriptionMaxLines(in: container) {
            // Read the default off a default-constructed layout so the two cannot drift apart.
            decodedLayout.productCardDescriptionMaxLines = ConciergeLayout().productCardDescriptionMaxLines
        }
        layout = decodedLayout
    }

    /// Whether the encoded layout carries a `productCardDescriptionMaxLines` key at all, which is
    /// what distinguishes "written before the property existed" from an explicit `null` opting in
    /// to an unbounded description.
    private static func layoutDeclaresDescriptionMaxLines(
        in container: KeyedDecodingContainer<CodingKeys>
    ) -> Bool {
        guard let layoutContainer = try? container.nestedContainer(
            keyedBy: DynamicCodingKey.self,
            forKey: .layout
        ) else {
            return false
        }
        return layoutContainer.contains(DynamicCodingKey("productCardDescriptionMaxLines"))
    }
}
