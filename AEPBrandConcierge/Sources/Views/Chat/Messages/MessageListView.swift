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
                                .padding(.horizontal, horizontalPadding(for: message.template))
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
                .onTapGesture {
                    if isInputFocused {
                        isInputFocused = false
                    }
                }
            }
        }
    }

    /// Returns the horizontal padding for a given message template.
    ///
    /// Carousel messages use `productCardCarouselHorizontalPadding` when set,
    /// falling back to `chatHistoryPadding` when not configured.
    /// Prompt suggestion chips use the default inset unless `alignToMessage` is true,
    /// in which case they align to the message bubble content edge.
    /// All other messages use `chatHistoryPadding` plus the base scroll content padding
    /// to preserve the original combined inset.
    private func horizontalPadding(for template: MessageTemplate) -> CGFloat {
        if case .carouselGroup = template {
            return theme.layout.productCardCarouselHorizontalPadding
                ?? theme.layout.chatHistoryPadding
        }
        if case .promptSuggestion = template,
           theme.behavior.promptSuggestions?.alignToMessage == true {
            // Align to message bubble: match the bubble's horizontal inset (padding + message padding)
            return theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
                + theme.layout.messagePadding.leading
        }
        return theme.layout.chatHistoryPadding + Self.scrollContentBasePadding
    }

    /// Returns true when the message at `index` is a `promptSuggestion` and the preceding message is not.
    private func isFirstInSuggestionGroup(at index: Int) -> Bool {
        guard case .promptSuggestion = messages[index].template else { return false }
        if index == 0 { return true }
        if case .promptSuggestion = messages[index - 1].template { return false }
        return true
    }
}
