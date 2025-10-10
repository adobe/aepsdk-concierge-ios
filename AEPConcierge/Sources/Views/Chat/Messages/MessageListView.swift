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
    // A monotonic tick that increases whenever the latest agent message updates
    var agentScrollTick: Int = 0
    var userScrollTick: Int = 0
    @Binding var isInputFocused: Bool
    let onSpeak: (String) -> Void

    // A sentinel we can scroll to that represents the absolute bottom
    private let bottomAnchorId: String = "__bottom_anchor__"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { message in
                        message.chatMessageView
                            .id(message.id)
                            .onAppear {
                                if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                    onSpeak(messageBody)
                                }
                            }
                    }
                    // Bottom sentinel to ensure we can scroll to absolute end
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            // Scroll when the last message id changes (new append). We only handle
            // user messages here; agent messages are handled by `agentScrollTick`
            // to avoid a position jump at completion.
            .onChange(of: messages.last?.id) { _ in
                guard let lastMessage = messages.last else { return }
                let isAgentMessage: Bool = {
                    switch lastMessage.template {
                    case .divider:
                        return false
                    case .basic(let isUserMessage):
                        return !isUserMessage
                    default:
                        // All other templates are agent-authored
                        return true
                    }
                }()

                guard !isAgentMessage else { return }
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                    }
                }
            }
            // Scroll during agent streaming updates (tick increments)
            .onChange(of: agentScrollTick) { _ in
                guard let lastMessage = messages.last else { return }
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .top)
                    }
                }
            }
            // Scroll precisely to bottom when a user message is sent
            .onChange(of: userScrollTick) { _ in
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(bottomAnchorId, anchor: .bottom)
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


