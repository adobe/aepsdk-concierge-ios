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
import AEPCore
import AEPServices

public struct ChatView: View {
    private let LOG_TAG = "ChatView"

    // MARK: Environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackEnvPresenter
    @Environment(\.openURL) private var openURL
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
    
    // TODO: need a better way to manage state across all these views
    private var conciergeConfiguration: ConciergeConfiguration

    // MARK: Derived values
    private var currentMessageIndex: Int { viewModel.messages.count - 1 }
    
    // MARK: UI values
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
    @State private var showFeedbackOverlay: Bool = false
    @State private var feedbackSentiment: FeedbackSentiment = .positive
    @State private var feedbackMessageId: UUID? = nil
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
        conciergeConfiguration: ConciergeConfiguration,
        onClose: (() -> Void)? = nil
    ) {
        self.textSpeaker = textSpeaker
        self.titleText = title
        self.subtitleText = subtitle
        self.onClose = onClose
        self.conciergeConfiguration = conciergeConfiguration
        let vm = ConciergeChatViewModel(
            configuration: conciergeConfiguration,
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
        self.conciergeConfiguration = ConciergeConfiguration()
        let vm = ConciergeChatViewModel(configuration: ConciergeConfiguration(), speechCapturer: nil, speaker: nil)
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

            // Filter welcome content (header + examples) based on input state and whether the user has interacted
            let shouldShowWelcome = (reducer.state == .empty) && !viewModel.hasUserSentMessage
            let displayMessages: [Message] = shouldShowWelcome ? viewModel.messages : viewModel.messages.filter { message in
                switch message.template {
                case .welcomePromptSuggestion, .welcomeHeader:
                    return false
                default:
                    return true
                }
            }

            MessageListView(
                messages: displayMessages,
                userScrollTick: viewModel.userScrollTick,
                userMessageToScrollId: viewModel.userMessageToScrollId,
                isInputFocused: $isInputFocused
            ) { text in
                textSpeaker?.utter(text: text)
            } onSuggestionTap: { suggestion in
                isInputFocused = true
                viewModel.applyTextChange(suggestion)
                selectedTextRange = NSRange(location: suggestion.utf16.count, length: 0)
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
            Task { await viewModel.loadWelcomeIfNeeded() }
        }
        // Provide a presenter to child views via environment
        .conciergeFeedbackPresenter(ConciergeFeedbackPresenter { sentiment, messageId in
            withAnimation {
                feedbackSentiment = sentiment
                feedbackMessageId = messageId
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
                    onSubmit: { payload in
                        viewModel.sendFeedbackFor(messageId: feedbackMessageId, with: payload)                        
                        showFeedbackOverlay = false
                    }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .overlay(alignment: .center) {
            if viewModel.showPermissionDialog {
                ZStack {
                    // Backdrop with separate fade animation
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.dismissPermissionDialog()
                            }
                        }
                    
                    // Dialog card with scale animation
                    PermissionDialogView(
                        theme: theme,
                        onCancel: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.dismissPermissionDialog()
                            }
                        },
                        onOpenSettings: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.requestOpenSettings()
                            }
                            
                            // Open app-specific settings
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Log.debug(label: LOG_TAG, "Opening settings URL: \(url.absoluteString)")
                                openURL(url)
                            } else {
                                Log.error(label: LOG_TAG, "Failed to create settings URL from: \(UIApplication.openSettingsURLString)")
                            }
                        }
                    )
                }
                .zIndex(1001)
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
        static let examples: [WelcomePromptSuggestion] = [
            WelcomePromptSuggestion(
                text: "I'd like to explore templates to see what I can create.",
                imageURL: URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_142fd6e4e46332d8f41f5aef982448361c0c8c65e.png"),
                backgroundHex: "#FFFFFF"
            ),
            WelcomePromptSuggestion(
                text: "I want to touch up and enhance my photos.",
                imageURL: URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_1e188097a1bc580b26c8be07d894205c5c6ca5560.png"),
                backgroundHex: "#FFFFFF"
            ),
            WelcomePromptSuggestion(
                text: "I'd like to edit PDFs and make them interactive.",
                imageURL: URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_1f6fed23045bbbd57fc17dadc3aa06bcc362f84cb.png"),
                backgroundHex: "#FFFFFF"
            ),
            WelcomePromptSuggestion(
                text: "I want to turn my clips into polished videos.",
                imageURL: URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_16c2ca834ea8f2977296082ae6f55f305a96674ac.png"),
                backgroundHex: "#FFFFFF"
            )
        ]
        var messages = [
//            Message(template: .welcomeHeader(title: "Welcome to Adobe Concierge!", body: "I’m your personal guide to help you explore and find exactly what you need. Let’s get started!\n\nNot sure where to start? Explore the suggested ideas below.")),
//            Message(template: .welcomePromptSuggestion(imageSource: .remote(examples[0].imageURL), text: examples[0].text, background: examples[0].background)),
//            Message(template: .welcomePromptSuggestion(imageSource: .remote(examples[1].imageURL), text: examples[1].text, background: examples[1].background)),
//            Message(template: .welcomePromptSuggestion(imageSource: .remote(examples[2].imageURL), text: examples[2].text, background: examples[2].background)),
//            Message(template: .welcomePromptSuggestion(imageSource: .remote(examples[3].imageURL), text: examples[3].text, background: examples[3].background)),
//            Message(template: .basic(isUserMessage: true), messageBody: "basic user message"),
//            Message(template: .basic(isUserMessage: false), messageBody: "basic system message"),
//            Message(template: .divider),
//            Message(template: .numbered(number: 1, title: "Numbered template title", body: "numbered template body")),
//            Message(template: .numbered(number: 2, title: "Numbered template title with much longer text", body: "numbered template body with much longer text")),
//            Message(template: .divider),
//            Message(template: .thumbnail(imageSource: .local(Image(systemName: "sparkles.square.filled.on.square")), title: "The title for this message", text: "Here's the thumbnail template with a system image named 'sparkles.square.filled.on.square'")),
//            Message(template: .thumbnail(imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!), title: nil, text: "I'm Concierge - your virtual product expert. I'm here to answer any questions you may have about this product. What can I do for you today?")),
//            Message(template: .divider),
//            Message(template: .productCard(imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
//                                           title: "Title",
//                                           body: "**1-2 product description lines** - dolor sit amet, consecteatur adipiscing elit, sed do eiusmod tempor incididunt.",
//                                           primaryButton: TempButton(text: "Label", url: "label-url"),
//                                           secondaryButton: TempButton(text: "label", url: "label-url"))),
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
