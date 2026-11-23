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
    @State private var isExpanded = false
    @State private var isTruncated = false

    let notice: ConciergePrivacyNoticeBehavior

    private var hasSummary: Bool {
        let summary = notice.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return !summary.isEmpty && summary != notice.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCollapsible: Bool { notice.presentation == .collapsible }

    private var formattedText: AttributedString {
        linkedText(notice.text)
    }

    private func linkedText(_ text: String) -> AttributedString {
        LinkedTextFormatter.format(
            text: text,
            links: notice.links,
            textColor: theme.colors.message.conciergeText.color.opacity(0.75),
            linkColor: theme.colors.message.conciergeLink.color
        )
    }

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
                if isCollapsible {
                    noticeBody
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            if !hasSummary {
                                truncationProbe
                            }
                        }
                } else {
                    noticeBody
                }
                if isCollapsible && (hasSummary || isTruncated) {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: isExpanded ? notice.showLessLabel : notice.readMoreLabel)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .accessibilityHidden(true)
                        }
                        .font(bodyFont.weight(.semibold))
                        .foregroundColor(theme.colors.message.conciergeLink.color)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("privacyNotice.toggle")
                }
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
            .onPreferenceChange(PrivacyNoticeHeightKey.self) { heights in
                if let full = heights[true], let preview = heights[false] {
                    isTruncated = full > preview + 0.5
                }
            }
            .onChange(of: notice.text) { _ in isExpanded = false }
            .onChange(of: notice.summary) { _ in isExpanded = false }
        }
    }

    @ViewBuilder
    private var noticeBody: some View {
        if isCollapsible && !isExpanded {
            Text(verbatim: String((hasSummary ? linkedText(notice.summary) : formattedText).characters))
                .font(bodyFont)
                .foregroundColor(theme.colors.message.conciergeText.color.opacity(0.75))
                .lineLimit(hasSummary ? nil : max(1, notice.collapsedMaxLines))
        } else {
            Text(formattedText)
                .font(bodyFont)
                .environment(\.openURL, OpenURLAction { url in
                    handleLinkTap(url)
                    return .handled
                })
        }
    }

    // Measure both layouts at the same width, even while the full notice is expanded.
    private var truncationProbe: some View {
        Text(verbatim: String(formattedText.characters))
            .font(bodyFont)
            .lineLimit(max(1, notice.collapsedMaxLines))
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: PrivacyNoticeHeightKey.self, value: [false: geometry.size.height])
            })
            .overlay(alignment: .topLeading) {
                Text(verbatim: String(formattedText.characters))
                    .font(bodyFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: PrivacyNoticeHeightKey.self, value: [true: geometry.size.height])
                    })
            }
            .hidden()
            .accessibilityHidden(true)
    }

    private func handleLinkTap(_ url: URL) {
        linkClickTracker.track(url.absoluteString, ConciergeConstants.TrackingEvent.LinkClickOrigin.PRIVACY_NOTICE)
        ConciergeLinkHandler.handleTappedLink(
            url,
            interceptor: linkInterceptor,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
    }

    private struct PrivacyNoticeHeightKey: PreferenceKey {
        static var defaultValue: [Bool: CGFloat] = [:]

        static func reduce(value: inout [Bool: CGFloat], nextValue: () -> [Bool: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }
}
