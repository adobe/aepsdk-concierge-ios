/*
 Copyright 2026 Adobe. All rights reserved.
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

/// Displays a circular icon from a remote URL or a local app bundle asset.
///
/// - Remote URLs (`http://` or `https://`): loaded asynchronously via `RemoteImageView`.
/// - Local asset names: searched in the app bundle using supported image extensions
///   (`.png`, `.jpg`, `.jpeg`, `.webp`, `.heic`, `.heif`, `.gif`, `.tiff`, `.tif`, `.bmp`).
///   Asset catalogs are also checked via `UIImage(named:)`. Note: `.gif` renders the first frame only.
/// - Empty path or unresolvable assets render nothing (silent failure).
struct LocalAssetImageView: View {
    let iconPath: String
    let size: CGFloat

    var body: some View {
        iconContent
    }

    @ViewBuilder
    private var iconContent: some View {
        if iconPath.hasPrefix("http://") || iconPath.hasPrefix("https://") {
            RemoteImageView(url: URL(string: iconPath), width: size, height: size)
                .clipShape(Circle())
        } else if let uiImage = resolvedLocalImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        // else: empty path or missing asset — renders nothing
    }

    private enum SupportedImageExtension: String, CaseIterable {
        case png, jpg, jpeg, webp, heic, heif, gif, tiff, tif, bmp
    }

    private var resolvedLocalImage: UIImage? {
        // Check asset catalog and named resources first
        if let image = UIImage(named: iconPath) {
            return image
        }
        // Fall back to searching the main bundle with supported extensions
        for ext in SupportedImageExtension.allCases {
            if let path = Bundle.main.path(forResource: iconPath, ofType: ext.rawValue),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }
}
