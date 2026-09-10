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

    /// Base scroll content padding. Combined with `chatHistoryPadding` to produce the standard
    /// horizontal inset used by text bubbles, suggestion chips, and non-carousel agent elements.
    /// Also referenced by `CarouselGroupView` when computing `scrollContentLeadingInset`.
    static let scrollContentBasePadding: CGFloat = 16

    let messages: [Message]
    var userScrollTick: Int = 0
    var userMessageToScrollId: UUID?
    var scrollToLastOnAppear: Bool = false
    /// Gates `shouldFillRemainingHeight` so only a turn that's actually in flight fills the screen —
    /// message-list shape alone can't distinguish "just arrived" from "settled a while ago with
    /// nothing following it" (e.g. a reopened past conversation, or an empty-response fallback
    /// message), since both look structurally identical.
    var chatState: ChatState = .idle
    @Binding var isInputFocused: Bool
    let onSpeak: (String) -> Void
    var onSuggestionTap: ((String) -> Void)?
    var onWelcomePromptSuggestionTap: ((String) -> Void)?
    var onCtaButtonTap: ((_ label: String, _ url: String) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    messageStack(geometry: geometry)
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

    @ViewBuilder
    private func messageStack(geometry: GeometryProxy) -> some View {
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
                    .padding(.leading, horizontalPadding(for: message.template).leading)
                    .padding(.trailing, horizontalPadding(for: message.template).trailing)
                    .padding(.bottom, -4)
                }

                let fillHeight: CGFloat? = shouldFillRemainingHeight(at: index) ? max(0, geometry.size.height - theme.layout.messageBlockerHeight) : nil

                ChatMessageView(
                    messageId: message.id,
                    template: message.template,
                    messageBody: message.messageBody,
                    sources: message.sources,
                    linkHints: message.linkHints,
                    promptSuggestions: message.promptSuggestions,
                    feedbackSentiment: message.feedbackSentiment,
                    feedbackEligible: message.feedbackEligible,
                    isStreamComplete: message.isStreamComplete,
                    onSuggestionTap: onSuggestionTap,
                    onWelcomePromptSuggestionTap: onWelcomePromptSuggestionTap,
                    onCtaButtonTap: onCtaButtonTap
                )
                    .id(message.id)
                    .padding(horizontalPadding(for: message.template))
                    // The in-progress response bubble fills the remaining screen height while
                    // it's the last thing on screen, so it appears to "fill in" below the user's
                    // message as it streams. The instant anything is appended after it (prompt
                    // suggestions, cards, a new user message), this no longer applies to it and
                    // it settles back to its natural size — so completed turns never leave a
                    // permanent empty gap below the last message.
                    .frame(minHeight: fillHeight, alignment: .top)
                    .onAppear {
                        if message.shouldSpeakMessage, let messageBody = message.chatMessageView().messageBody {
                            onSpeak(messageBody)
                        }
                    }
            }
        }
    }

    /// Returns the padding insets for a given message template.
    ///
    /// - Carousel messages receive zero container padding. The carousel's `ScrollView` spans
    ///   the full available width so cards are never clipped during horizontal scrolling.
    ///   `CarouselGroupView` applies the appropriate leading inset inside the scroll content.
    /// - Agent basic messages with a configured icon use `chatHistoryPadding` as the
    ///   leading inset only, so the icon sits flush at the history padding boundary.
    ///   The trailing inset keeps the full `chatHistoryPadding + scrollContentBasePadding`.
    /// - Secondary agent-response elements (product cards, CTA buttons, thumbnails, prompt
    ///   suggestions) with a configured icon are indented by `agentIconSize + agentIconSpacing`
    ///   so they align with the agent response text.
    /// - All other messages use `chatHistoryPadding + scrollContentBasePadding` on both sides.
    private func horizontalPadding(for template: MessageTemplate) -> EdgeInsets {
        if case .carouselGroup = template {
            // Carousel manages its own leading inset inside the ScrollView content
            // (see CarouselGroupView.scrollContentLeadingInset) so the ScrollView container
            // spans the full available width, preventing cards from being clipped on scroll.
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
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

    /// True when a turn is actively in flight (`chatState == .processing`) AND the message at `index`
    /// is the agent's response to the latest user message with nothing appended after it yet (no
    /// suggestions, cards, or new user message). The message-shape check alone matches the Android
    /// implementation this was ported from; the `chatState` check is additionally required so a
    /// settled conversation with the same shape (reopened past conversation, empty-response
    /// fallback) doesn't also fill. Deliberately `== .processing` rather than `!= .idle`: `.error`
    /// is also non-idle, and this must not fill an error-state bubble even if a future change to
    /// the error path leaves one as the last message (today it doesn't, but that's an accident of
    /// `ChatController`'s error handling, not something this guard should rely on).
    /// Internal (not private) so `shouldFillRemainingHeight` can be unit tested directly — a
    /// snapshot alone can't detect an inverted or broken condition here, since `.frame(minHeight:)`
    /// only affects scrollable content height, which is invisible in a single fixed-frame capture.
    func shouldFillRemainingHeight(at index: Int) -> Bool {
        guard chatState == .processing,
              index == messages.count - 1,
              case .basic(let isUserMessage) = messages[index].template,
              !isUserMessage,
              let lastUserIndex = messages.lastIndex(where: { if case .basic(true) = $0.template { return true }; return false })
        else { return false }
        return lastUserIndex == index - 1
    }
}
