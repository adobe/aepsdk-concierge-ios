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

/// Call to action (CTA) button rendered from a `ctaButton` multimodal element.
struct CtaButtonView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.conciergeWebViewPresenter) private var webViewPresenter
    @Environment(\.conciergeLinkInterceptor) private var linkInterceptor

    let action: ActionButton
    var onTap: ((_ label: String, _ url: String) -> Void)?

    var body: some View {
        HStack(alignment: .bottom) {
            Button(action: { handleTap() }) {
                HStack(spacing: 8) {
                    Text(action.text)
                        .font(.system(size: theme.layout.ctaButtonFontSize, weight: theme.layout.ctaButtonFontWeight.toSwiftUIFontWeight()))
                        .foregroundColor(theme.colors.ctaButton.text.color)

                    Image(systemName: "arrow.up.forward.app")
                        .resizable()
                        .frame(width: theme.layout.ctaButtonIconSize, height: theme.layout.ctaButtonIconSize)
                        .foregroundColor(theme.colors.ctaButton.iconColor.color)
                }
                .padding(.horizontal, theme.layout.ctaButtonHorizontalPadding)
                .padding(.vertical, theme.layout.ctaButtonVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.layout.ctaButtonBorderRadius, style: .continuous)
                        .fill(theme.colors.ctaButton.background.color)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(action.text)

            Spacer()
        }
    }

    /// Tracks the tap with the original URL, then opens the URL with the CTA's summary appended.
    /// `linkInterceptor` lets tests pass a host handler; the view uses the one from the environment.
    func handleTap(linkInterceptor interceptor: ConciergeLinkInterceptor? = nil) {
        guard let urlString = action.url else { return }
        onTap?(action.text, urlString)
        let clickURLString = CtaSummaryURLBuilder.clickURL(for: urlString, summary: action.summary)
        guard let url = URL(string: clickURLString) else { return }
        if (interceptor ?? linkInterceptor).handleLink(url) { return }
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
    }
}
