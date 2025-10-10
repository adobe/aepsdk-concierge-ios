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

import AEPServices

public struct ChatView: View {
    private let LOG_TAG = "ChatView"

    // MARK: Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackEnvPresenter
    @StateObject private var viewModel: ConciergeChatViewModel
    @ObservedObject private var reducer: InputReducer
    @State private var showAgentSend: Bool = false
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var composerHeight: CGFloat = 0

    // MARK: Dependencies and configuration
    private let textSpeaker: TextSpeaking?
    // Close handler for UIKit hosting
    private let onClose: (() -> Void)?
    // Header content
    private let titleText: String
    private let subtitleText: String?

    // MARK: Derived values
    private var currentMessageIndex: Int { viewModel.messages.count - 1 }
    
    // MARK: UI values
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
    @State private var showFeedbackOverlay: Bool = false
    @State private var feedbackSentiment: FeedbackSentiment = .positive
    @State private var isInputFocused: Bool = false
    private var composerBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
    }
    private var composerBorderColor: Color {
        Color(UIColor.separator)
    }

    // MARK: - Initializers
    // Public initializer – callers do not need to (and cannot) pass the chat service.
    public init(
        speechCapturer: SpeechCapturing? = nil,
        textSpeaker: TextSpeaking? = nil,
        title: String = "Concierge",
        subtitle: String? = "Powered by Adobe",
        onClose: (() -> Void)? = nil
    ) {
        self.textSpeaker = textSpeaker
        self.titleText = title
        self.subtitleText = subtitle
        self.onClose = onClose
        let vm = ConciergeChatViewModel(
            chatService: ConciergeChatService(),
            speechCapturer: speechCapturer ?? SpeechCapturer(),
            speaker: textSpeaker
        )
        _viewModel = StateObject(wrappedValue: vm)
        _reducer = ObservedObject(wrappedValue: vm.inputReducer)
    }

    // internal use only for previews
    init(messages: [Message]) {
        self.textSpeaker = nil
        self.titleText = "Concierge"
        self.subtitleText = "Powered by Adobe"
        self.onClose = nil
        let vm = ConciergeChatViewModel(chatService: ConciergeChatService(), speechCapturer: nil, speaker: nil)
        vm.messages = messages
        _viewModel = StateObject(wrappedValue: vm)
        _reducer = ObservedObject(wrappedValue: vm.inputReducer)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Full background color ignoring safe area (dynamic for light/dark)
            Color(.systemBackground)
                .ignoresSafeArea()

            MessageListView(
                messages: viewModel.messages,
                agentScrollTick: viewModel.agentScrollTick,
                userScrollTick: viewModel.userScrollTick,
                isInputFocused: $isInputFocused
            ) { text in
                textSpeaker?.utter(text: text)
            }
        }
        // Safe area respecting top bar
        .safeAreaInset(edge: .top) {
            ChatTopBar(
                showAgentSend: $showAgentSend,
                title: titleText,
                subtitle: subtitleText,
                onToggleMode: { isAgent in
                    if isAgent {
                        viewModel.chatState = .idle
                    }
                },
                onClose: {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        Concierge.hide()
                    }
                },
                onToggleSources: { isOn in
                    viewModel.stubAgentSources = isOn
                }
            )
        }
        // Safe area respecting bottom composer
        .safeAreaInset(edge: .bottom) {
            ChatComposer(
                inputText: Binding(
                    get: { reducer.data.text },
                    set: { viewModel.applyTextChange($0) }
                ),
                selectedRange: $selectedTextRange,
                measuredHeight: $composerHeight,
                isFocused: $isInputFocused,
                inputState: reducer.state,
                chatState: viewModel.chatState,
                composerEditable: viewModel.chatState != .processing,
                micEnabled: viewModel.micEnabled,
                sendEnabled: reducer.data.canSend,
                onEditingChanged: { _ in },
                onMicTap: handleMicTap,
                onCancel: {
                    viewModel.cancelMic()
                    hapticFeedback.impactOccurred()
                },
                onComplete: {
                    viewModel.completeMic()
                    hapticFeedback.impactOccurred()
                },
                onSend: sendTapped
            )
        }
        .onAppear {
            hapticFeedback.prepare()
        }
        .onChange(of: isInputFocused) { newValue in
            // Trigger view update when focus changes
            // The SelectableTextView's updateUIView will handle the actual keyboard dismissal
        }
        // Provide a presenter to child views via environment
        .conciergeFeedbackPresenter(ConciergeFeedbackPresenter { sentiment in
            withAnimation {
                feedbackSentiment = sentiment
                showFeedbackOverlay = true
            }
        })
        // Overlay after layout to avoid affecting layout metrics
        .overlay(alignment: .center) {
            if showFeedbackOverlay {
                FeedbackOverlayView(
                    theme: theme,
                    sentiment: feedbackSentiment,
                    onCancel: { showFeedbackOverlay = false },
                    onSubmit: { _ in showFeedbackOverlay = false }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
    }
    
    // MARK: - Actions
    private func sendTapped() {
        viewModel.sendMessage(isUser: !showAgentSend)
        hapticFeedback.impactOccurred(intensity: 0.5)
        hapticFeedback.impactOccurred(intensity: 0.7)
    }

    private func handleMicTap() {
        if viewModel.isRecording {
            viewModel.toggleMic(currentSelectionLocation: selectedTextRange.location)
        } else {
            hapticFeedback.impactOccurred()
            viewModel.toggleMic(currentSelectionLocation: selectedTextRange.location)
        }
    }
}

#Preview {
    struct ChatViewPreview: View {
        var messages = [
            Message(template: .basic(isUserMessage: true), messageBody: "basic user message"),
            Message(template: .basic(isUserMessage: false), messageBody: "basic system message"),
            Message(template: .divider),
            Message(template: .numbered(number: 1, title: "Numbered template title", body: "numbered template body")),
            Message(template: .numbered(number: 2, title: "Numbered template title with much longer text", body: "numbered template body with much longer text")),
            Message(template: .divider),
            Message(template: .thumbnail(imageSource: .local(Image(systemName: "sparkles.square.filled.on.square")), title: "The title for this message", text: "Here's the thumbnail template with a system image named 'sparkles.square.filled.on.square'")),
            Message(template: .thumbnail(imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!), title: nil, text: "I'm Concierge - your virtual product expert. I'm here to answer any questions you may have about this product. What can I do for you today?")),
            Message(template: .divider),
            Message(template: .productCard(imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                                           title: "Title",
                                           body: "**1-2 product description lines** - dolor sit amet, consecteatur adipiscing elit, sed do eiusmod tempor incididunt.",
                                           primaryButton: TempButton(text: "Label", url: "label-url"),
                                           secondaryButton: TempButton(text: "label", url: "label-url"))),
            Message(template: .divider),
            Message(template: .carouselGroup([
                Message(template: .productCarouselCard(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 1",
                    destination: URL(string:"https://adobe.com")!
                )),
                Message(template: .productCarouselCard(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 2",
                    destination: URL(string:"https://adobe.com")!
                ))
            ])),
            Message(template: .divider)
        ]
        
        var body: some View {
            ChatView(messages: messages)
        }
    }
    
    return ChatViewPreview()
}
