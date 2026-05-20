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

/// Supported image file extensions for header image asset lookup.
private enum SupportedImageExtension: String, CaseIterable {
    case png
    case jpg
    case jpeg
    case webp
    case heic
    case gif
}

/// Header bar showing title/subtitle, a User/Agent toggle, and a close button.
struct ChatTopBar: View {
    @Environment(\.conciergeTheme) private var theme

    @Binding var showAgentSend: Bool

    let title: String
    let subtitle: String?

    let onToggleMode: (Bool) -> Void
    let onClose: () -> Void

    @State private var showSourcesToggle: Bool = true

    /// Resolved title, preferring theme header over the initializer value.
    private var resolvedTitle: String {
        let themeTitle = theme.header.title
        return themeTitle.isEmpty ? title : themeTitle
    }

    /// Resolved subtitle, preferring theme header over the initializer value.
    private var resolvedSubtitle: String? {
        let themeSub = theme.header.subtitle
        if !themeSub.isEmpty { return themeSub }
        return subtitle
    }

    /// Resolved header image from the theme's `header.image` local asset path.
    /// Returns nil when the key is absent or the asset cannot be found.
    private var resolvedHeaderImage: UIImage? {
        let path = theme.header.image
        guard !path.isEmpty else { return nil }
        if let image = UIImage(named: path) { return image }
        for ext in SupportedImageExtension.allCases {
            if let filePath = Bundle.main.path(forResource: path, ofType: ext.rawValue),
               let image = UIImage(contentsOfFile: filePath) { return image }
        }
        return nil
    }

    private var hasTitle: Bool { !resolvedTitle.isEmpty }

    private var hasSubtitle: Bool {
        guard let sub = resolvedSubtitle else { return false }
        return !sub.isEmpty
    }

    @ViewBuilder
    private var headerImageView: some View {
        if let image = resolvedHeaderImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 48)
        }
    }

    @ViewBuilder
    private var headerTextView: some View {
        if hasTitle || hasSubtitle {
            VStack(alignment: .leading, spacing: 2) {
                if hasTitle {
                    Text(resolvedTitle)
                        .font(titleFont)
                        .foregroundColor(theme.colors.primary.text.color)
                }
                if hasSubtitle, let sub = resolvedSubtitle {
                    Text(sub)
                        .font(.system(.footnote))
                        .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                }
            }
        }
    }

    private var closeButtonAlignedStart: Bool {
        theme.behavior.welcomeCard?.closeButtonAlignment == "start"
    }

    private var titleFont: Font {
        if let size = theme.layout.headerTitleFontSize {
            return .system(size: size).weight(.semibold)
        }
        return .system(.title3).weight(.semibold)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                if closeButtonAlignedStart {
                    closeButton
                }

                HStack(spacing: 10) {
                    if theme.header.layoutType != .textOnly {
                        headerImageView
                    }

                    if theme.header.layoutType != .imageOnly {
                        headerTextView
                    }
                }

                Spacer()

                if !closeButtonAlignedStart {
                    closeButton
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
        }
        .background(theme.colors.surface.mainContainerBackground.color)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            BrandIcon(assetName: "S2_Icon_Close_20_N", systemName: "xmark")
                .foregroundColor(theme.colors.primary.text.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
