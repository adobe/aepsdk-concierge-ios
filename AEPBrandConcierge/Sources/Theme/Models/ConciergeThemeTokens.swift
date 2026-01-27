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
}

