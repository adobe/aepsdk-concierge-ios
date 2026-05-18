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

import Foundation

/// Per-weight font file mapping matching the cross-platform theme JSON format.
///
/// Each slot holds a font file basename (without extension). For example:
/// ```json
/// "--font-family": {
///     "thin": "Raleway-Thin",
///     "light": "Raleway-Light",
///     "regular": "Raleway-Regular",
///     "italic": "Raleway-Italic",
///     "bold": "Raleway-Bold",
///     "black": "Raleway-Black"
/// }
/// ```
public struct ConciergeFontFamilySpec: Codable, Hashable {
    public var thin: String?
    public var light: String?
    public var regular: String?
    public var italic: String?
    public var bold: String?
    public var black: String?

    public init(
        thin: String? = nil,
        light: String? = nil,
        regular: String? = nil,
        italic: String? = nil,
        bold: String? = nil,
        black: String? = nil
    ) {
        self.thin = thin
        self.light = light
        self.regular = regular
        self.italic = italic
        self.bold = bold
        self.black = black
    }

    var isEmpty: Bool {
        [thin, light, regular, italic, bold, black]
            .allSatisfy { $0?.isEmpty ?? true }
    }
}
