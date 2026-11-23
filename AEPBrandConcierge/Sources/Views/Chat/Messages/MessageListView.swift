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
    @Environment(\.scenePhase) private var scenePhase
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var laidOutAnchor: UUID?
    @State private var navigation = TurnNavigation()

    /// Base scroll content padding. Combined with `chatHistoryPadding` to produce the standard
    /// horizontal inset used by text bubbles, suggestion chips, and non-carousel agent elements.
    /// Also referenced by `CarouselGroupView` when computing `scrollContentLeadingInset`.
    static let scrollContentBasePadding: CGFloat = 16
    private static let rowSpacing: CGFloat = 12

    let messages: [Message]
    var privacyNotice: ConciergePrivacyNoticeBehavior = ConciergePrivacyNoticeBehavior()
    @Binding var isInputFocused: Bool
    let onSpeak: (String) -> Void
    var onSuggestionTap: ((String) -> Void)?
    var onWelcomePromptSuggestionTap: ((String) -> Void)?
    var onCtaButtonTap: ((_ label: String, _ url: String) -> Void)?

    var body: some View {
        let rows = transcriptRows
        let turn = Self.newestTurn(in: messages)
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                let turnRows = turn.map { rows.dropFirst($0.startIndex) } ?? rows.suffix(0)
                let heights = turnRows.compactMap { rowHeights[$0.id] }
                let turnHeight = heights.isEmpty ? nil
                    : heights.reduce(0, +) + Self.rowSpacing * CGFloat(heights.count - 1)
                let measuredAnchor = heights.count == turnRows.count && geometry.size.height > 0 ? turn?.anchorId : nil
                let pending = scenePhase == .active && laidOutAnchor == measuredAnchor ? measuredAnchor : nil
                let bottom = theme.layout.chatHistoryBottomPadding
                ScrollView {
                    VStack(spacing: Self.rowSpacing) {
                        messageRows(rows, turnStart: turn?.startIndex)
                    }
                    .padding(.top, theme.layout.chatHistoryPaddingTopExpanded)
                    .padding(.bottom, bottom + Self.trailingSpace(
                        viewport: geometry.size.height,
                        turnHeight: turnHeight,
                        bottomPadding: bottom
                    ))
                    .background(GeometryReader { _ in
                        Color.clear.preference(key: LaidOutAnchorKey.self, value: measuredAnchor)
                    })
                }
                .onPreferenceChange(RowHeightsKey.self) { rowHeights = $0 }
                .onPreferenceChange(LaidOutAnchorKey.self) { laidOutAnchor = $0 }
                .onChange(of: messages.isEmpty) { if $0 { navigation = TurnNavigation() } }
                .task(id: pending) {
                    guard let pending, let turn else { return }
                    // This runs only after a layout containing both the anchor and its padding.
                    guard !Task.isCancelled,
                          navigation.consume(turn, older: messages.prefix(turn.startIndex)) else { return }
                    proxy.scrollTo(pending, anchor: .top)
                }
                .simultaneousGesture(DragGesture().onChanged { drag in
                    if let turn, abs(drag.translation.height) >= abs(drag.translation.width) {
                        _ = navigation.consume(turn, older: messages.prefix(turn.startIndex))
                    }
                })
                .onTapGesture {
                    if isInputFocused {
                        isInputFocused = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageRows(_ rows: [TranscriptRow], turnStart: Int?) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            VStack(spacing: Self.rowSpacing) {
                let message = row.message
                // showHeader: insert a "Suggestions" label above the first chip in a group
                if isFirstInSuggestionGroup(at: index),
                   theme.behavior.promptSuggestions?.showHeader == true {
                    HStack {
                        Text(theme.text.suggestionsHeader)
                            .font(.system(.subheadline).weight(.semibold))
                            .foregroundColor(theme.colors.message.conciergeText.color)
                        Spacer()
                    }
                    .padding(.leading, horizontalPadding(for: message).leading)
                    .padding(.trailing, horizontalPadding(for: message).trailing)
                    .padding(.bottom, -4)
                }

                if row.showsPrivacyNotice {
                    VStack(spacing: 12) {
                        PrivacyNoticeView(notice: privacyNotice)
                            .padding(horizontalPadding(for: .basic(isUserMessage: true)))
                        messageView(message)
                    }
                } else {
                    messageView(message)
                }
            }
            .background {
                if let turnStart, index >= turnStart {
                    GeometryReader { geometry in
                        Color.clear.preference(key: RowHeightsKey.self, value: [row.id: geometry.size.height])
                    }
                }
            }
            .id(row.id)
        }
    }

    struct TurnAnchor: Equatable {
        let id: UUID
        let anchorId: UUID
        let startIndex: Int
    }

    struct TurnNavigation {
        private var handled: Set<UUID> = []

        mutating func consume(_ turn: TurnAnchor, older: ArraySlice<Message>) -> Bool {
            guard handled.insert(turn.id).inserted else { return false }
            // Removing a failed turn must not re-anchor older transcript rows.
            handled.formUnion(older.map { $0.turnId ?? $0.id })
            return true
        }
    }

    static func newestTurn(in messages: [Message]) -> TurnAnchor? {
        if let id = messages.last?.turnId,
           let index = messages.firstIndex(where: { $0.turnId == id }) {
            return TurnAnchor(id: id, anchorId: messages[index].id, startIndex: index)
        }
        guard let index = messages.lastIndex(where: {
            if case .template(.basic(isUserMessage: true)) = $0.content { return true }
            return false
        }) else { return nil }
        let id = messages[index].id
        return TurnAnchor(id: id, anchorId: id, startIndex: index)
    }

    static func trailingSpace(viewport: CGFloat, turnHeight: CGFloat?, bottomPadding: CGFloat) -> CGFloat {
        guard let turnHeight else { return 0 }
        return max(0, viewport - turnHeight - bottomPadding)
    }

    private enum RowHeightsKey: PreferenceKey {
        static let defaultValue: [UUID: CGFloat] = [:]
        static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
        }
    }

    private enum LaidOutAnchorKey: PreferenceKey {
        static let defaultValue: UUID? = nil
        static func reduce(value: inout UUID?, nextValue: () -> UUID?) {
            if let anchor = nextValue() { value = anchor }
        }
    }

    @ViewBuilder
    private func messageView(_ message: Message) -> some View {
        if let suggestions = attachedSuggestions(for: message) {
            VStack(alignment: .leading, spacing: 8) {
                rowView(message)
                // Laid out like standalone suggestion rows, whatever insets the card row uses.
                AttachedPromptSuggestionsView(suggestions: suggestions, onSuggestionTap: onSuggestionTap)
                    .padding(horizontalPadding(for: .promptSuggestion(text: "")))
            }
        } else {
            rowView(message)
        }
    }

    private func rowView(_ message: Message) -> some View {
        Group {
            switch message.content {
            case .nativeCard(let cardId):
                NativeCardView(cardId: cardId)
            case .template(let template):
                ChatMessageView(
                    messageId: message.id,
                    template: template,
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
            }
        }
        .padding(horizontalPadding(for: message))
        .onAppear {
            guard case .template = message.content, message.shouldSpeakMessage,
                  let messageBody = message.messageBody else { return }
            onSpeak(messageBody)
        }
    }

    /// One scroll anchor per message. The privacy notice renders inside its first user query's
    /// row, so scrolling to that query brings the notice into view with it.
    struct TranscriptRow: Identifiable {
        let message: Message
        let showsPrivacyNotice: Bool
        var id: UUID { message.id }
    }

    var transcriptRows: [TranscriptRow] {
        let noticeIndex = privacyNoticeIndex
        return messages.enumerated().map { index, message in
            TranscriptRow(message: message, showsPrivacyNotice: index == noticeIndex)
        }
    }

    var privacyNoticeIndex: Int? {
        guard privacyNotice.hasContent else { return nil }
        return messages.firstIndex {
            if case .template(.basic(isUserMessage: true)) = $0.content { return true }
            return false
        }
    }

    /// Prompt suggestions the SDK attached to a card row of a response that rendered a native card.
    func attachedSuggestions(for message: Message) -> [String]? {
        guard let suggestions = message.promptSuggestions, !suggestions.isEmpty else { return nil }
        switch message.content {
        case .nativeCard, .template(.productCard), .template(.carouselGroup):
            return suggestions
        case .template:
            return nil
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
    ///   so they align with the leading edge of the agent message bubble.
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

    private func horizontalPadding(for message: Message) -> EdgeInsets {
        switch message.content {
        case .template(let template):
            return horizontalPadding(for: template)
        case .nativeCard:
            guard theme.hasAgentIcon else {
                let horizontal = theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
                return EdgeInsets(top: 0, leading: horizontal, bottom: 0, trailing: horizontal)
            }
            return EdgeInsets(
                top: 0,
                leading: theme.layout.chatHistoryPadding + theme.layout.agentTextIndent,
                bottom: 0,
                trailing: theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
            )
        }
    }

    /// Returns true when the message at `index` is a `promptSuggestion` and the preceding message is not.
    private func isFirstInSuggestionGroup(at index: Int) -> Bool {
        guard case .template(.promptSuggestion) = messages[index].content else { return false }
        if index == 0 { return true }
        if case .template(.promptSuggestion) = messages[index - 1].content { return false }
        return true
    }

}
