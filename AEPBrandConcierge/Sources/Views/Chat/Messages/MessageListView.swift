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
                    .onAppear {
                        if message.shouldSpeakMessage, let messageBody = message.chatMessageView().messageBody {
                            onSpeak(messageBody)
                        }
                    }
            }

            // Scroll room for the turn that's in flight. The anchor can only come to rest at the
            // top of the viewport if there's at least a screenful of content beneath it, so the
            // shortfall is reserved here.
            //
            // This is deliberately *additive* — a sibling below the whole turn rather than a
            // minimum height on the response bubble — because the distance between the anchor and
            // the bubble isn't fixed: a typed turn anchors on the user's message above the bubble,
            // while a `sendDataHandoff(...)` turn with no local message anchors on the bubble
            // itself. A minimum height on the bubble only reserves correctly for the first case
            // and leaves the second a full `messageBlockerHeight` short. As a sibling it holds for
            // both, without anyone having to measure the anchor.
            //
            // The turn's own messages already contribute roughly `messageBlockerHeight` toward
            // that screenful, so only the remainder is reserved and the list doesn't over-scroll.
            // The gate collapses this the moment the turn settles, so a completed turn never
            // leaves a permanent gap below the last message.
            if shouldFillRemainingHeight(at: messages.count - 1) {
                Spacer(minLength: 0)
                    .frame(height: max(0, geometry.size.height - theme.layout.messageBlockerHeight))
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
    /// snapshot alone can't detect an inverted or broken condition here, since the reserved space
    /// only affects scrollable content height, which is invisible in a single fixed-frame capture.
    func shouldFillRemainingHeight(at index: Int) -> Bool {
        guard chatState == .processing,
              messages.indices.contains(index),
              index == messages.count - 1,
              case .basic(let isUserMessage) = messages[index].template,
              !isUserMessage
        else { return false }

        // Either the placeholder sits directly below this turn's anchor, or - for a handoff with no
        // local message - the placeholder *is* the anchor. Without the filler there's nothing below
        // the anchor to scroll against, so the scroll clamps part-way.
        if isTurnAnchor(at: index - 1) || isTurnAnchor(at: index) { return true }

        guard let lastUserIndex = messages.lastIndex(where: { if case .basic(true) = $0.template { return true }; return false })
        else { return false }
        return lastUserIndex == index - 1
    }

    /// Returns true when the message at `index` is the anchor the controller scrolled to the top.
    ///
    /// A typed turn anchors on the user's own message; a `sendDataHandoff(...)` turn anchors on its
    /// local message, which is rendered as an agent message. Asking the controller covers both.
    private func isTurnAnchor(at index: Int) -> Bool {
        guard let anchorId = userMessageToScrollId, messages.indices.contains(index) else { return false }
        return messages[index].id == anchorId
    }
}
