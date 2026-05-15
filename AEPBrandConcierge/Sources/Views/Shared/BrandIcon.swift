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

/// Presents an icon from the asset catalog with an SF Symbol fallback.
struct BrandIcon: View {
    let assetName: String
    let systemName: String

    var body: some View {
        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage).renderingMode(.template)
        } else {
            Image(systemName: systemName).renderingMode(.template)
        }
    }

    /// Returns a `UIImage` using the same asset-catalog → SF Symbol priority as the SwiftUI view.
    /// Pass a non-nil `pointSize` to apply a `UIImage.SymbolConfiguration` to the SF Symbol fallback.
    ///
    /// - Parameters:
    ///   - assetName: Named asset to try first. An empty string skips straight to the SF Symbol.
    ///   - systemName: SF Symbol name used when the named asset is absent.
    ///   - pointSize: Point size applied to the SF Symbol configuration. Ignored for named assets.
    /// - Returns: The resolved `UIImage`, or `nil` if neither source produces an image.
    static func resolvedUIImage(assetName: String, systemName: String, pointSize: CGFloat? = nil) -> UIImage? {
        if !assetName.isEmpty, let asset = UIImage(named: assetName) {
            return asset
        }
        if let pointSize {
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            return UIImage(systemName: systemName, withConfiguration: config)
        }
        return UIImage(systemName: systemName)
    }
}
