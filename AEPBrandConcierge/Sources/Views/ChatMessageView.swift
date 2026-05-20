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

/// View that renders a single chat message based on its template.
struct ChatMessageView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergePlaceholderConfig) private var placeholderConfig
    @Environment(\.openURL) private var openURL
    @Environment(\.conciergeWebViewPresenter) private var webViewPresenter
    @Environment(\.conciergeLinkInterceptor) private var linkInterceptor
    @Environment(\.conciergeCardTapHandler) private var cardTapHandler

    let messageId: UUID?
    let template: MessageTemplate
    var messageBody: String?
    var sources: [Source]?
    var linkHints: [LinkHint]?
    var promptSuggestions: [String]?
    var feedbackSentiment: FeedbackSentiment?
    /// Whether the message is eligible to display the feedback affordance. Drives the
    /// inclusion of `MessageFeedbackView` below the bubble; defaults to `false`.
    var feedbackEligible: Bool = false
    /// Whether the SSE stream for this message has fully completed. Required to gate
    /// `alwaysDisplay` so feedback is not shown while streaming is still in progress.
    var isStreamComplete: Bool = false
    var onSuggestionTap: ((String) -> Void)?
    var onWelcomePromptSuggestionTap: ((String) -> Void)?

    init(messageId: UUID? = nil, template: MessageTemplate, messageBody: String? = nil, sources: [Source]? = nil, linkHints: [LinkHint]? = nil, promptSuggestions: [String]? = nil, feedbackSentiment: FeedbackSentiment? = nil, feedbackEligible: Bool = false, isStreamComplete: Bool = false, onSuggestionTap: ((String) -> Void)? = nil, onWelcomePromptSuggestionTap: ((String) -> Void)? = nil) {
        self.messageId = messageId
        self.template = template
        self.messageBody = messageBody
        self.sources = sources
        self.linkHints = linkHints
        self.promptSuggestions = promptSuggestions
        self.feedbackSentiment = feedbackSentiment
        self.feedbackEligible = feedbackEligible
        self.isStreamComplete = isStreamComplete
        self.onSuggestionTap = onSuggestionTap
        self.onWelcomePromptSuggestionTap = onWelcomePromptSuggestionTap
    }

    var body: some View {
        switch template {
        case .welcomeHeader(let title, let body):
            let welcomeAlign: TextAlignment = theme.layout.welcomeTextAlign == "center" ? .center : .leading
            let titleFontSize = theme.layout.welcomeTitleFontSize ?? 22
            let titleBottomSpacing = theme.layout.welcomeTitleBottomSpacing ?? 10
            let contentPadding = theme.layout.welcomeContentPadding ?? 0

            VStack(alignment: welcomeAlign == .center ? .center : .leading, spacing: titleBottomSpacing) {
                Text(title)
                    .font(.system(size: titleFontSize).weight(.semibold))
                    .foregroundColor(theme.colors.primary.text.color)
                    .multilineTextAlignment(welcomeAlign)
                    .textSelection(.enabled)
                Text(body)
                    .font(.system(.body))
                    .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                    .multilineTextAlignment(welcomeAlign)
                    .textSelection(.enabled)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .padding(.horizontal, contentPadding)

        case .welcomePromptSuggestion(let imageSource, let text, let background):
            let promptFullWidth = theme.behavior.welcomeCard?.promptFullWidth ?? true
            let promptMaxLines = theme.behavior.welcomeCard?.promptMaxLines ?? 3
            let promptImageSize = theme.layout.welcomePromptImageSize ?? 90
            let promptPadding = theme.layout.welcomePromptPadding ?? 0
            let promptCornerRadius = theme.layout.welcomePromptCornerRadius ?? theme.layout.borderRadiusCard
            let promptBgColor = theme.colors.welcomePrompt.backgroundColor?.color ?? background
            let promptTextColor = theme.colors.welcomePrompt.textColor?.color ?? theme.colors.primary.text.color

            Button(action: { onWelcomePromptSuggestionTap?(text) }) {
                if promptFullWidth {
                    HStack(spacing: 0) {
                        // Only render image block when a valid source is available
                        switch imageSource {
                        case .local(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: promptImageSize, height: promptImageSize)
                                .clipped()
                        case .remote(let url):
                            if url != nil {
                                RemoteImageView(url: url, width: promptImageSize, height: promptImageSize)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(text)
                                .font(.system(.body))
                                .foregroundColor(promptTextColor)
                                .multilineTextAlignment(.leading)
                                .lineLimit(promptMaxLines)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(promptBgColor)
                    .cornerRadius(promptCornerRadius)
                } else {
                    // Compact chip layout
                    HStack(spacing: 6) {
                        BrandIcon(assetName: "S2_Icon_Sparkle_20_N", systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(promptTextColor)
                        Text(text)
                            .font(.system(.subheadline))
                            .foregroundColor(promptTextColor)
                            .lineLimit(promptMaxLines)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: promptCornerRadius, style: .continuous)
                            .fill(promptBgColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: promptCornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(promptPadding)
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(theme.text.cardAriaSelect)
            .accessibilityHint(text)

        case .divider:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
                .padding(.horizontal)

        case .basic(let isUserMessage):
            BasicMessageView(
                isUserMessage: isUserMessage,
                messageBody: messageBody,
                sources: sources,
                linkHints: linkHints,
                feedbackSentiment: feedbackSentiment,
                feedbackEligible: effectiveFeedbackEligible,
                messageId: messageId,
                onLinkTap: { handleLinkTap($0) }
            )

        case .thumbnail(let imageSource, let title, let text):
            HStack {
                HStack(spacing: 0) {
                    switch imageSource {
                    case .local(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100)
                            .clipped()
                    case .remote(let url):
                        RemoteImageView(url: url, width: 100, height: 100)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let title = title {
                            Text(title)
                                .font(.system(.headline))
                                .bold()
                                .foregroundColor(theme.colors.primary.text.color)
                                .textSelection(.enabled)
                        }
                        Text(text)
                            .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color.PrimaryLight)
                .cornerRadius(theme.layout.borderRadiusCard)

                Spacer()
            }

        case .numbered(let number, let title, let body):
            HStack {
                HStack(alignment: .center, spacing: 12) {
                    if let number = number {
                        ZStack {
                            Circle()
                                .fill(Color.PrimaryDark)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 3)
                                .frame(width: 32, height: 32)

                            Text("\(number)")
                                .font(.system(.body))
                                .bold()
                                .foregroundColor(theme.colors.primary.text.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let title = title {
                            Text(title)
                                .font(.system(.headline))
                                .bold()
                                .foregroundColor(theme.colors.primary.text.color)
                                .textSelection(.enabled)
                        }
                        if let body = body {
                            Text(body)
                                .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.PrimaryLight)
                .cornerRadius(theme.layout.borderRadiusCard)

                Spacer()
            }

        case .productCarouselCard(let cardData):
            switch theme.behavior.productCard?.cardStyle ?? .actionButton {
            case .productDetail:
                ProductDetailCardView(
                    data: cardData,
                    cardWidth: theme.layout.productCardWidth,
                    cardHeight: theme.layout.productCardHeight
                )
            case .actionButton:
                actionButtonCarouselCard(data: cardData)
            }

        case .productCard(let cardData):
            let cardAlignment = (theme.behavior.productCard?.cardsAlignment ?? .center).swiftUIAlignment
            Group {
                switch theme.behavior.productCard?.cardStyle ?? .actionButton {
                case .productDetail:
                    ProductDetailCardView(
                        data: cardData,
                        cardWidth: theme.layout.productCardWidth,
                        cardHeight: theme.layout.productCardHeight
                    )
                case .actionButton:
                    actionButtonProductCard(data: cardData)
                }
            }
            .frame(maxWidth: .infinity, alignment: cardAlignment)

        case .ctaButton(let action):
            CtaButtonView(action: action)

        case .carouselGroup(let items):
            CarouselGroupView(items: items)

        case .promptSuggestion(let text):
            let suggestionTextColor = theme.colors.promptSuggestion.textColor?.color
                ?? theme.colors.message.conciergeText.color
            let suggestionBgColor = theme.colors.promptSuggestion.backgroundColor?.color
                ?? theme.colors.primary.container?.color
                ?? Color(UIColor.secondarySystemBackground)
            let suggestionCornerRadius = theme.layout.suggestionItemBorderRadius ?? 10
            let suggestionMaxLines = theme.behavior.promptSuggestions?.itemMaxLines ?? 1

            HStack(alignment: .bottom) {
                Button(action: { onSuggestionTap?(text) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .imageScale(.small)
                            .foregroundColor(suggestionTextColor)
                        Text(text)
                            .font(.system(.subheadline))
                            .foregroundColor(suggestionTextColor)
                            .lineLimit(suggestionMaxLines)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: suggestionCornerRadius, style: .continuous)
                            .fill(suggestionBgColor)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
        }
    }
}

// MARK: - Action Button Card Style (existing)

private extension ChatMessageView {
    func actionButtonCarouselCard(data: ProductCardData) -> some View {
        Button(action: {
            cardTapHandler.cardTapped(data)
            if let destination = data.destinationURL {
                handleLinkTap(destination)
            }
        }) {
            ZStack(alignment: .bottomLeading) {
                switch data.imageSource {
                case .local(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 200)
                        .clipped()
                case .remote(let url):
                    RemoteImageView(url: url, width: 280, height: 200)
                }

                Text(data.title)
                    .font(.system(.subheadline))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.7))
                    )
                    .padding(12)
            }
        }
        .cornerRadius(theme.layout.borderRadiusCard)
        .shadow(
            color: theme.layout.multimodalCardBoxShadow.isEnabled ? theme.layout.multimodalCardBoxShadow.color.color : .clear,
            radius: theme.layout.multimodalCardBoxShadow.blurRadius,
            x: theme.layout.multimodalCardBoxShadow.offsetX,
            y: theme.layout.multimodalCardBoxShadow.offsetY
        )
        .frame(width: 280, height: 200)
        .buttonStyle(PlainButtonStyle())
    }

    func actionButtonProductCard(data: ProductCardData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            switch data.imageSource {
            case .local(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 350, height: 200)
                    .clipped()
            case .remote(let url):
                RemoteImageView(url: url, width: 350, height: 200)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.system(.headline))
                    .bold()
                    .foregroundColor(theme.colors.primary.text.color)
                    .textSelection(.enabled)

                if let subtitle = data.subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline))
                        .foregroundColor(theme.colors.primary.text.color.opacity(0.75))
                        .textSelection(.enabled)
                }

                if data.primaryButton != nil || data.secondaryButton != nil {
                    HStack(spacing: 12) {
                        if let primaryButton = data.primaryButton {
                            ButtonView(
                                text: primaryButton.text,
                                variant: .primary,
                                action: {
                                    if let url = URL(string: primaryButton.url) {
                                        handleLinkTap(url)
                                    }
                                }
                            )
                        }

                        if let secondaryButton = data.secondaryButton {
                            ButtonView(
                                text: secondaryButton.text,
                                variant: .secondary,
                                action: {
                                    if let url = URL(string: secondaryButton.url) {
                                        handleLinkTap(url)
                                    }
                                }
                            )
                        }

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding(14)
            .frame(width: 350, alignment: .leading)
        }
        .background(theme.components.chatMessage.conciergeBackground.color)
        .cornerRadius(theme.layout.borderRadiusCard)
        .shadow(
            color: theme.layout.multimodalCardBoxShadow.isEnabled ? theme.layout.multimodalCardBoxShadow.color.color : .clear,
            radius: theme.layout.multimodalCardBoxShadow.blurRadius,
            x: theme.layout.multimodalCardBoxShadow.offsetX,
            y: theme.layout.multimodalCardBoxShadow.offsetY
        )
        .frame(width: 350)
    }
}

// MARK: - Helpers

private extension ChatMessageView {
    /// `true` when the server marks this message eligible, or when the theme sets `alwaysDisplay: true`
    /// and the SSE stream has fully completed.
    var effectiveFeedbackEligible: Bool {
        feedbackEligible || (isStreamComplete && theme.behavior.feedback?.alwaysDisplay == true)
    }

    func handleLinkTap(_ url: URL) {
        if linkInterceptor.handleLink(url) { return }
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
    }
}

private extension CardsAlignment {
    var swiftUIAlignment: Alignment {
        switch self {
        case .start:  return .leading
        case .end:    return .trailing
        case .center: return .center
        }
    }
}
