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

/// Main chat view presenting the Concierge conversation interface.
public struct ChatView: View {
    private let LOG_TAG = "ChatView"

    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackEnvPresenter
    @Environment(\.openURL) private var openURL
    
    // MARK: - State
    
    @StateObject private var controller: ChatController
    @ObservedObject private var inputController: InputController
    @State private var showAgentSend: Bool = false
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var composerHeight: CGFloat = 0
    @State private var showFeedbackOverlay: Bool = false
    @State private var feedbackSentiment: FeedbackSentiment = .positive
    @State private var feedbackMessageId: UUID? = nil
    @State private var isInputFocused: Bool = false

    // MARK: - Dependencies and Configuration
    
    private let textSpeaker: TextSpeaking?
    private let onClose: (() -> Void)?
    private let titleText: String
    private let subtitleText: String?
    private var conciergeConfiguration: ConciergeConfiguration
    
    // MARK: - UI
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private var composerBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
    }
    private var composerBorderColor: Color {
        Color(UIColor.separator)
    }

    // MARK: - Initializers
    
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
        
        let chatController = ChatController(
            configuration: conciergeConfiguration,
            speechCapturer: speechCapturer ?? SpeechCapturer(),
            speaker: textSpeaker
        )
        _controller = StateObject(wrappedValue: chatController)
        _inputController = ObservedObject(wrappedValue: chatController.inputController)
    }

    // Internal use only for previews
    init(messages: [Message]) {
        self.textSpeaker = nil
        self.titleText = "Concierge"
        self.subtitleText = "Powered by Adobe"
        self.onClose = nil
        self.conciergeConfiguration = ConciergeConfiguration()
        
        let chatController = ChatController(configuration: ConciergeConfiguration(), speechCapturer: nil, speaker: nil)
        chatController.messages = messages
        _controller = StateObject(wrappedValue: chatController)
        _inputController = ObservedObject(wrappedValue: chatController.inputController)
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Full background color ignoring safe area (dynamic for light/dark)
            Color(.systemBackground)
                .ignoresSafeArea()

            // Filter welcome content (header + examples) based on input state and whether the user has interacted
            let shouldShowWelcome = (inputController.state == .empty) && !controller.hasUserSentMessage
            let displayMessages: [Message] = shouldShowWelcome ? controller.messages : controller.messages.filter { message in
                switch message.template {
                case .welcomePromptSuggestion, .welcomeHeader:
                    return false
                default:
                    return true
                }
            }

            MessageListView(
                messages: displayMessages,
                userScrollTick: controller.userScrollTick,
                userMessageToScrollId: controller.userMessageToScrollId,
                isInputFocused: $isInputFocused
            ) { text in
                textSpeaker?.utter(text: text)
            } onSuggestionTap: { suggestion in
                isInputFocused = true
                controller.applyTextChange(suggestion)
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
                        controller.chatState = .idle
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
                    get: { inputController.data.text },
                    set: { controller.applyTextChange($0) }
                ),
                selectedRange: $selectedTextRange,
                measuredHeight: $composerHeight,
                isFocused: $isInputFocused,
                inputState: inputController.state,
                chatState: controller.chatState,
                composerEditable: controller.chatState != .processing,
                micEnabled: controller.micEnabled,
                sendEnabled: inputController.data.canSend,
                onEditingChanged: { _ in },
                onMicTap: handleMicTap,
                onCancel: {
                    controller.cancelMic()
                    hapticFeedback.impactOccurred()
                },
                onComplete: {
                    controller.completeMic()
                    hapticFeedback.impactOccurred()
                },
                onSend: sendTapped
            )
        }
        .onAppear {
            hapticFeedback.prepare()
            Task { await controller.loadWelcomeIfNeeded() }
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
                        controller.sendFeedbackFor(messageId: feedbackMessageId, with: payload)                        
                        showFeedbackOverlay = false
                    }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .overlay(alignment: .center) {
            if controller.showPermissionDialog {
                ZStack {
                    // Backdrop with separate fade animation
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                controller.dismissPermissionDialog()
                            }
                        }
                    
                    // Dialog card with scale animation
                    PermissionDialogView(
                        theme: theme,
                        onCancel: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                controller.dismissPermissionDialog()
                            }
                        },
                        onOpenSettings: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                controller.requestOpenSettings()
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
        controller.sendMessage(isUser: !showAgentSend)
        hapticFeedback.impactOccurred(intensity: 0.5)
        hapticFeedback.impactOccurred(intensity: 0.7)
    }

    private func handleMicTap() {
        if controller.isRecording {
            controller.toggleMic(currentSelectionLocation: selectedTextRange.location)
        } else {
            hapticFeedback.impactOccurred()
            controller.toggleMic(currentSelectionLocation: selectedTextRange.location)
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
