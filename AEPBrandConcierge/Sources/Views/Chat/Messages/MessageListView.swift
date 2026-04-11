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

/// Scrollable chat transcript that renders messages and triggers text-to-speech via `onSpeak` when appropriate.
struct MessageListView: View {
    @Environment(\.conciergeTheme) private var theme

    /// Base scroll content padding. Combined with `chatHistoryPadding` to preserve the 
    // original total inset for non carousel messages.
    private static let scrollContentBasePadding: CGFloat = 16

    let messages: [Message]
    var userScrollTick: Int = 0
    var userMessageToScrollId: UUID?
    var scrollToLastOnAppear: Bool = false
    @Binding var isInputFocused: Bool
    let onSpeak: (String) -> Void
    var onSuggestionTap: ((String) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            // showHeader: insert a "Suggestions" label above the first chip in a group
                            if isFirstInSuggestionGroup(at: index),
                               theme.behavior.promptSuggestions?.showHeader == true {
                                HStack {
                                    Text(theme.text.suggestionsHeader)
                                        .font(.system(.subheadline).weight(.semibold))
                                        .foregroundColor(theme.colors.message.conciergeText.color)
                                    Spacer()
                                }
                                .padding(.horizontal, horizontalPadding(for: message.template))
                                .padding(.bottom, -4)
                            }

                            ChatMessageView(
                                messageId: message.id,
                                template: message.template,
                                messageBody: message.messageBody,
                                sources: message.sources,
                                promptSuggestions: message.promptSuggestions,
                                feedbackSentiment: message.feedbackSentiment,
                                onSuggestionTap: onSuggestionTap
                            )
                                .id(message.id)
                                .padding(horizontalPadding(for: message.template))
                                .onAppear {
                                    if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                        onSpeak(messageBody)
                                    }
                                }
                        }

                        // Add spacer to ensure scroll view has enough height to position user message at top
                        Spacer()
                            .frame(height: max(0, geometry.size.height - theme.layout.messageBlockerHeight))
                    }
                    .padding(.top, theme.layout.chatHistoryPaddingTopExpanded)
                    .padding(.bottom, theme.layout.chatHistoryBottomPadding)
                }
                // Scroll user message to top when sent, allowing agent response to fill screen below
                .onChange(of: userScrollTick) { _ in
                    guard let messageId = userMessageToScrollId else { return }
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(messageId, anchor: .top)
                        }
                    }
                }
                // When reopening a chat with prior messages, jump to the bottom so the user sees the latest exchange.
                .onAppear {
                    if scrollToLastOnAppear, let lastId = messages.last?.id {
                        DispatchQueue.main.async {
                            proxy.scrollTo(lastId, anchor: .top)
                        }
                    }
                }
                .onTapGesture {
                    if isInputFocused {
                        isInputFocused = false
                    }
                }
            }
        }
    }

    /// Returns the padding insets for a given message template.
    ///
    /// - Carousel messages use `productCardCarouselHorizontalPadding` when set,
    ///   falling back to `chatHistoryPadding + scrollContentBasePadding` (same as all other agent
    ///   elements) so the first card's left edge aligns with agent text. When an agent icon is
    ///   configured the leading inset is shifted by `agentTextIndent` instead.
    /// - Agent basic messages with a configured icon use `chatHistoryPadding` as the
    ///   leading inset only, so the icon sits flush at the history padding boundary.
    ///   The trailing inset keeps the full `chatHistoryPadding + scrollContentBasePadding`.
    /// - Secondary agent-response elements (product cards, CTA buttons, thumbnails, prompt
    ///   suggestions) with a configured icon are indented by `agentIconSize + agentIconSpacing`
    ///   so they align with the agent response text.
    /// - All other messages use `chatHistoryPadding + scrollContentBasePadding` on both sides.
    private func horizontalPadding(for template: MessageTemplate) -> EdgeInsets {
        if case .carouselGroup = template {
            if theme.hasAgentIcon {
                let trailing = theme.layout.productCardCarouselHorizontalPadding
                    ?? theme.layout.chatHistoryPadding
                return EdgeInsets(
                    top: 0,
                    leading: theme.layout.chatHistoryPadding + theme.layout.agentTextIndent,
                    bottom: 0,
                    trailing: trailing
                )
            }
            // Without an agent icon the carousel leading must match other agent elements
            // (chatHistoryPadding + scrollContentBasePadding) so the scroll container boundary
            // is flush with text bubbles and suggestion chips.
            // productCardCarouselHorizontalPadding still controls the trailing inset, letting
            // cards scroll closer to the right edge when a smaller value is configured.
            let leading = theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
            let trailing = theme.layout.productCardCarouselHorizontalPadding
                ?? theme.layout.chatHistoryPadding
            return EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing)
        }
        if case .basic(let isUserMessage) = template,
           !isUserMessage,
           theme.hasAgentIcon {
            return EdgeInsets(
                top: 0,
                leading: theme.layout.chatHistoryPadding,
                bottom: 0,
                trailing: theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
            )
        }
        if theme.hasAgentIcon {
            switch template {
            case .promptSuggestion, .productCard, .ctaButton, .thumbnail:
                return EdgeInsets(
                    top: 0,
                    leading: theme.layout.chatHistoryPadding + theme.layout.agentTextIndent,
                    bottom: 0,
                    trailing: theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
                )
            default:
                break
            }
        }
        let h = theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
        return EdgeInsets(top: 0, leading: h, bottom: 0, trailing: h)
    }

    /// Returns true when the message at `index` is a `promptSuggestion` and the preceding message is not.
    private func isFirstInSuggestionGroup(at index: Int) -> Bool {
        guard case .promptSuggestion = messages[index].template else { return false }
        if index == 0 { return true }
        if case .promptSuggestion = messages[index - 1].template { return false }
        return true
    }
}
