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

/// Header bar showing title/subtitle, a User/Agent toggle, and a close button.
struct ChatTopBar: View {
    @Environment(\.conciergeTheme) private var theme

    @Binding var showAgentSend: Bool

    let title: String
    let subtitle: String?

    let onToggleMode: (Bool) -> Void
    let onClose: () -> Void

    @State private var showSourcesToggle: Bool = true

    /// Resolved title, preferring theme text over the initializer value.
    private var resolvedTitle: String {
        let themeTitle = theme.text.headerTitle
        return themeTitle.isEmpty ? title : themeTitle
    }

    /// Resolved subtitle, preferring theme text over the initializer value.
    private var resolvedSubtitle: String? {
        let themeSub = theme.text.headerSubtitle
        if !themeSub.isEmpty { return themeSub }
        return subtitle
    }

    private var closeButtonAlignedStart: Bool {
        theme.behavior.welcomeCard?.closeButtonAlignment == "start"
    }

    private var titleFont: Font {
        if let size = theme.layout.headerTitleFontSize {
            return .system(size: size, design: .rounded).weight(.semibold)
        }
        return .system(.title3, design: .rounded).weight(.semibold)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                if closeButtonAlignedStart {
                    closeButton
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(resolvedTitle)
                        .font(titleFont)
                        .foregroundColor(theme.colors.primary.text.color)
                    if let sub = resolvedSubtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(.footnote))
                            .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                    }
                }

                Spacer()

                if !closeButtonAlignedStart {
                    closeButton
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

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
