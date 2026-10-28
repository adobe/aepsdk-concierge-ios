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

struct PrivacyNoticeView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.conciergeWebViewPresenter) private var webViewPresenter
    @Environment(\.conciergeLinkInterceptor) private var linkInterceptor
    @Environment(\.conciergeLinkClickTracker) private var linkClickTracker
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    let notice: ConciergePrivacyNoticeBehavior

    private var bodyFont: Font {
        let size = theme.typography.fontSize * textScale
        return theme.typography.fontFamily.isEmpty
            ? .system(size: size)
            : .custom(theme.typography.fontFamily, fixedSize: size)
    }

    var body: some View {
        if notice.hasContent {
            VStack(alignment: .leading, spacing: 8) {
                if !notice.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: notice.title)
                        .font(bodyFont.weight(.semibold))
                        .foregroundColor(theme.colors.primary.text.color)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(LinkedTextFormatter.format(
                    text: notice.text,
                    links: notice.links,
                    textColor: theme.colors.message.conciergeText.color.opacity(0.75),
                    linkColor: theme.colors.message.conciergeLink.color
                ))
                    .font(bodyFont)
                    .environment(\.openURL, OpenURLAction { url in
                        handleLinkTap(url)
                        return .handled
                    })
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.layout.borderRadiusCard, style: .continuous)
                    .fill(theme.components.chatMessage.conciergeBackground.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.layout.borderRadiusCard, style: .continuous)
                    .strokeBorder(theme.colors.message.conciergeText.color.opacity(0.12), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
        }
    }

    private func handleLinkTap(_ url: URL) {
        linkClickTracker.track(url.absoluteString, ConciergeConstants.TrackingEvent.LinkClickOrigin.PRIVACY_NOTICE)
        if linkInterceptor.handleLink(url) { return }
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
    }
}
