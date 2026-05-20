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

/// View that renders a single user or agent chat message bubble,
/// including the text content, citation sources, and feedback controls.
struct BasicMessageView: View {
    @Environment(\.conciergeTheme) private var theme

    let isUserMessage: Bool
    var messageBody: String?
    var sources: [Source]?
    var linkHints: [LinkHint]?
    var feedbackSentiment: FeedbackSentiment?
    var feedbackEligible: Bool = false
    var messageId: UUID?
    var onLinkTap: ((URL) -> Void)?

    // MARK: - Lightweight derived state (no heavy computation)

    private var isThinking: Bool {
        !isUserMessage && (messageBody?.isEmpty ?? true)
    }

    private var showAgentIcon: Bool {
        !isUserMessage && theme.hasAgentIcon
    }

    private var resolvedAgentFont: UIFont {
        let fontSize = theme.typography.fontSize
        if theme.typography.fontFamily.isEmpty {
            return UIFont.systemFont(ofSize: fontSize)
        }
        return UIFont(name: theme.typography.fontFamily, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
    }

    private var resolvedMessageMaxWidth: CGFloat? {
        if let behaviorWidth = theme.behavior.chat.messageWidth, behaviorWidth > 1 {
            return behaviorWidth
        }
        return theme.layout.messageMaxWidth
    }

    private var resolvedFeedbackPlacement: ThumbsPlacement {
        theme.behavior.feedback?.thumbsPlacement ?? .inline
    }

    private var messageLineSpacing: CGFloat {
        let multiplier = theme.typography.lineHeight
        guard multiplier.isFinite, multiplier > 0 else { return 0 }

        let fontSize = theme.typography.fontSize
        let baseFont: UIFont = {
            if theme.typography.fontFamily.isEmpty {
                return UIFont.systemFont(ofSize: fontSize)
            }
            return UIFont(name: theme.typography.fontFamily, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        }()

        let targetLineHeight = fontSize * multiplier
        return max(0, targetLineHeight - baseFont.lineHeight)
    }

    /// Builds a link icon resolver closure from the message's `linkHints` and the theme's
    /// `citations` icon config.
    private var resolvedLinkIconResolver: ((URL) -> (assetName: String, sfSymbol: String, image: UIImage?))? {
        guard theme.behavior.citations?.showLinkIcon == true else { return nil }
        let citations = theme.behavior.citations
        let hints = linkHints ?? []
        return { url in
            let hint = hints.first { $0.href == url.absoluteString }
            switch hint?.kind {
            case "phone":
                return (citations?.phoneIcon ?? "", "phone", nil)
            case "store":
                return (citations?.storeIcon ?? "", "storefront", nil)
            default:
                return (citations?.defaultLinkIcon ?? "", "arrow.up.forward.app", nil)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        let alignment: HorizontalAlignment = theme.behavior.chat.messageAlignment == .center ? .center : .leading

        // Compute citation decoration exactly once per render pass.
        // The original code used local `let` bindings; as separate computed properties
        // the expensive `CitationRenderer.decorate` call would run 3× per render.
        let rawSources = sources ?? []
        let decoration: CitationDecoration? = {
            guard !isUserMessage, let body = messageBody, !body.isEmpty else { return nil }
            return CitationRenderer.decorate(markdown: body, sources: rawSources)
        }()
        let annotatedBody = decoration?.annotatedMarkdown ?? (messageBody ?? "")
        let markers = decoration?.markers ?? []
        let displayedSources = decoration?.deduplicatedSources ?? CitationRenderer.deduplicate(rawSources)

        VStack(alignment: alignment, spacing: 0) {
            HStack(alignment: isThinking ? .center : .top) {
                if isUserMessage { Spacer() } else if theme.behavior.chat.messageAlignment == .center { Spacer() }

                if showAgentIcon {
                    LocalAssetImageView(iconPath: theme.assets.icons.company, size: theme.layout.agentIconSize)
                        .padding(.trailing, theme.layout.agentIconSpacing)
                }

                if isThinking {
                    ConciergeResponsePlaceholderView()
                } else {
                    bubbleContent(
                        annotatedBody: annotatedBody,
                        markers: markers,
                        displayedSources: displayedSources
                    )
                }

                if !isUserMessage { Spacer() } else if theme.behavior.chat.messageAlignment == .center { Spacer() }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func bubbleContent(
        annotatedBody: String,
        markers: [CitationMarker],
        displayedSources: [Source]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            messageContent(annotatedBody: annotatedBody, markers: markers)
                .lineSpacing(messageLineSpacing)
                .padding(showAgentIcon
                    ? EdgeInsets(top: theme.layout.messagePadding.top, leading: 0, bottom: theme.layout.messagePadding.bottom, trailing: 0)
                    : theme.layout.messagePadding.edgeInsets)
                .frame(maxWidth: resolvedMessageMaxWidth, alignment: .leading)
                .textSelection(.enabled)
                .foregroundColor(isUserMessage ? theme.colors.message.userText.color : theme.colors.message.conciergeText.color)
                .background(bubbleBackground(hasDisplayedSources: !displayedSources.isEmpty))
                .compositingGroup()
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = messageBody ?? ""
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }

            if !isUserMessage, !displayedSources.isEmpty {
                SourcesListView(
                    sources: displayedSources,
                    feedbackEligible: feedbackEligible,
                    feedbackSentiment: feedbackSentiment,
                    messageId: messageId
                )
            }

            if !isUserMessage, feedbackEligible,
               resolvedFeedbackPlacement == .standalone {
                MessageFeedbackView(
                    feedbackSentiment: feedbackSentiment,
                    messageId: messageId
                )
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func messageContent(annotatedBody: String, markers: [CitationMarker]) -> some View {
        if isUserMessage {
            Text(messageBody ?? "")
        } else {
            MarkdownBlockView(
                markdown: annotatedBody,
                textColor: UIColor(theme.colors.message.conciergeText.color),
                baseFont: resolvedAgentFont,
                citationMarkers: markers,
                citationStyle: .init(
                    backgroundColor: UIColor(theme.colors.citation.background.color),
                    textColor: UIColor(theme.colors.citation.text.color),
                    font: UIFont.systemFont(
                        ofSize: theme.layout.citationsDesktopButtonFontSize,
                        weight: theme.layout.citationsTextFontWeight.toUIFontWeight()
                    )
                ),
                linkIconResolver: resolvedLinkIconResolver,
                linkIconColor: UIColor(theme.behavior.citations?.linkIconStyle?.color?.color ?? theme.colors.message.conciergeLink.color),
                linkIconSize: theme.behavior.citations?.linkIconStyle?.size ?? 10,
                linkIconSpacing: theme.behavior.citations?.linkIconStyle?.spacing,
                linkIconBaselineAdjust: theme.behavior.citations?.linkIconStyle?.baselineAdjust ?? 0,
                onOpenLink: { url in
                    onLinkTap?(url)
                }
            )
        }
    }

    @ViewBuilder
    private func bubbleBackground(hasDisplayedSources: Bool) -> some View {
        let conciergeBackgroundColor = theme.components.chatMessage.conciergeBackground.color
        if isUserMessage {
            if theme.behavior.chat.userMessageBubbleStyle == .balloon {
                RoundedCornerShape(radius: theme.layout.messageBorderRadius, corners: [.topLeft, .topRight, .bottomLeft])
                    .fill(theme.colors.message.userBackground.color)
            } else {
                RoundedRectangle(cornerRadius: theme.layout.messageBorderRadius, style: .continuous)
                    .fill(theme.colors.message.userBackground.color)
            }
        } else {
            if hasDisplayedSources {
                RoundedCornerShape(radius: theme.layout.messageBorderRadius, corners: [.topLeft, .topRight])
                    .fill(conciergeBackgroundColor)
            } else {
                RoundedRectangle(cornerRadius: theme.layout.messageBorderRadius, style: .continuous)
                    .fill(conciergeBackgroundColor)
            }
        }
    }
}
