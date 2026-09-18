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

/// Header bar showing title/subtitle, a User/Agent toggle, and a close button.
struct ChatTopBar: View {
    @Environment(\.conciergeTheme) private var theme

    @Binding var showAgentSend: Bool

    let title: String
    let subtitle: String?
    /// Current conversation session ID, surfaced (DEBUG builds only) as a tap-to-copy chip for
    /// debugging — it matches the request `sessionId` and the LiveKit room name.
    var sessionId: String? = nil

    let onToggleMode: (Bool) -> Void
    let onClose: () -> Void

    @State private var showSourcesToggle: Bool = true
    @State private var didCopySessionId: Bool = false

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

    private var hasTitle: Bool { !resolvedTitle.isEmpty }

    private var hasSubtitle: Bool {
        guard let sub = resolvedSubtitle else { return false }
        return !sub.isEmpty
    }

    @ViewBuilder
    private var headerImageView: some View {
        if !theme.header.image.isEmpty {
            // Local asset name or a remote http(s) URL; unresolvable paths render nothing.
            LocalAssetImageView(
                iconPath: theme.header.image,
                height: theme.header.imageHeight,
                contentMode: .fit,
                clipToCircle: false
            )
        } else {
            Image(systemName: "ellipsis.message.fill")
                .resizable()
                .scaledToFit()
                .frame(height: theme.header.imageHeight)
                .foregroundColor(theme.colors.primary.text.color)
        }
    }

    private var showHeaderText: Bool {
        if hasTitle || hasSubtitle { return true }
        #if DEBUG
        if let sessionId, !sessionId.isEmpty { return true }
        #endif
        return false
    }

    @ViewBuilder
    private var headerTextView: some View {
        if showHeaderText {
            VStack(alignment: .leading, spacing: 2) {
                if hasTitle {
                    Text(resolvedTitle)
                        .font(titleFont)
                        .foregroundColor(theme.colors.primary.text.color)
                        .lineLimit(1)
                }
                if hasSubtitle, let sub = resolvedSubtitle {
                    Text(sub)
                        .font(.system(.footnote))
                        .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                        .lineLimit(2)
                }
                #if DEBUG
                sessionIdChip
                #endif
            }
        }
    }

    #if DEBUG
    /// Debug-only tap-to-copy chip showing the current session ID. Compiled out of release builds.
    @ViewBuilder
    private var sessionIdChip: some View {
        if let sessionId, !sessionId.isEmpty {
            Button {
                UIPasteboard.general.string = sessionId
                didCopySessionId = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopySessionId = false }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: didCopySessionId ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9))
                    Text(didCopySessionId ? "Copied session ID" : "sid: \(sessionId)")
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundColor(theme.colors.primary.text.color.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy session ID")
            .accessibilityIdentifier("debugSessionIdChip")
        }
    }
    #endif

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
