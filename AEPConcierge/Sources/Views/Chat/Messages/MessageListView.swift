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
    let messages: [Message]
    var userScrollTick: Int = 0
    var userMessageToScrollId: UUID?
    @Binding var isInputFocused: Bool
    let onSpeak: (String) -> Void
    var onSuggestionTap: ((String) -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
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
                                .onAppear {
                                    if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                        onSpeak(messageBody)
                                    }
                                }
                        }
                        
                        // Add spacer to ensure scroll view has enough height to position user message at top
                        Spacer()
                            .frame(height: max(0, geometry.size.height - 100))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
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
}
