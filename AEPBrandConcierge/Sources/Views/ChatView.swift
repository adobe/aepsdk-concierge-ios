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
struct ChatView: View {
    private let LOG_TAG = "ChatView"

    // MARK: - Environment

    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackEnvPresenter
    @Environment(\.openURL) private var openURL

    // MARK: - State

    @ObservedObject private var controller: ChatController
    @ObservedObject private var inputController: InputController
    @State private var showAgentSend: Bool = false
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var composerHeight: CGFloat = 0
    @State private var showFeedbackOverlay: Bool = false
    @State private var feedbackSentiment: FeedbackSentiment = .positive
    @State private var feedbackMessageId: UUID?
    @State private var isInputFocused: Bool = false
    @State private var showWebViewPopover: Bool = false
    @State private var webViewURL: URL? = nil

    // MARK: - Dependencies and Configuration

    private let onClose: (() -> Void)?
    private let titleText: String
    private let subtitleText: String?

    // MARK: - UI

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Initializers

    init(
        controller: ChatController,
        title: String = ConciergeConstants.Defaults.TITLE,
        subtitle: String? = ConciergeConstants.Defaults.SUBTITLE,
        onClose: (() -> Void)? = nil
    ) {
        self.titleText = title
        self.subtitleText = subtitle
        self.onClose = onClose
        self._controller = ObservedObject(wrappedValue: controller)
        self._inputController = ObservedObject(wrappedValue: controller.inputController)
    }

    // Internal use only for previews
    init(messages: [Message]) {
        self.titleText = ConciergeConstants.Defaults.TITLE
        self.subtitleText = ConciergeConstants.Defaults.SUBTITLE
        self.onClose = nil

        let chatController = ChatController(configuration: ConciergeConfiguration(), speechCapturer: nil, speaker: nil)
        chatController.messages = messages
        self._controller = ObservedObject(wrappedValue: chatController)
        self._inputController = ObservedObject(wrappedValue: chatController.inputController)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full background color ignoring safe area (dynamic for light/dark)
            theme.colors.surface.mainContainerBackground.color
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

            VStack(spacing: 0) {
            MessageListView(
                messages: displayMessages,
                userScrollTick: controller.userScrollTick,
                userMessageToScrollId: controller.userMessageToScrollId,
                scrollToLastOnAppear: controller.hasUserSentMessage,
                isInputFocused: $isInputFocused
            ) { text in
                controller.speak(text)
            } onSuggestionTap: { suggestion in
                controller.applyTextChange(suggestion)
                controller.sendMessage(isUser: true)
            }
                .frame(maxWidth: theme.layout.chatInterfaceMaxWidth)
            }
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .conciergePlaceholderConfig(
            ConciergeResponsePlaceholderConfig(
                loadingText: theme.text.loadingMessage,
                primaryDotColor: theme.colors.primary.primary.color
            )
        )
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
                micEnabled: controller.micEnabled && theme.behavior.input.enableVoiceInput,
                sendEnabled: inputController.data.canSend,
                audioLevel: controller.audioLevel,
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
            Task { await controller.loadWelcomeIfNeeded(theme: theme) }
        }
        // Provide a presenter to child views via environment
        .conciergeFeedbackPresenter(ConciergeFeedbackPresenter { sentiment, messageId in
            withAnimation {
                feedbackSentiment = sentiment
                feedbackMessageId = messageId
                showFeedbackOverlay = true
            }
        })
        // Provide webview presenter to child views via environment
        .conciergeWebViewPresenter(ConciergeWebViewPresenter { url in
            webViewURL = url
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showWebViewPopover = true
            }
        })
        // Overlay after layout to avoid affecting layout metrics
        .overlay {
            if showFeedbackOverlay {
                FeedbackOverlayView(
                    sentiment: feedbackSentiment,
                    onCancel: { withAnimation { showFeedbackOverlay = false } },
                    onSubmit: { payload in
                        controller.sendFeedbackFor(messageId: feedbackMessageId, with: payload)
                        withAnimation { showFeedbackOverlay = false }
                    }
                )
                .transition(
                    theme.behavior.feedback?.displayMode == "action"
                        ? .move(edge: .bottom).combined(with: .opacity)
                        : .opacity
                )
                .zIndex(1000)
            }
        }
        .overlay(alignment: .top) {
            if controller.chatState == .error(.networkFailure) {
                Text(theme.text.errorNetwork)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.message.conciergeText.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                theme.components.chatMessage.conciergeBackground.color.opacity(0.96)
                            )
                    )
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
            }
        }
        .overlay(alignment: .center) {
            if controller.showPermissionDialog {
                ZStack {
                    // Backdrop with separate fade animation
                    theme.colors.surface.messageBlockerBackground.color
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                controller.dismissPermissionDialog()
                            }
                        }

                    // Dialog card with scale animation
                    PermissionDialogView(
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
        // WebView popover overlay - using overlay instead of fullScreenCover to show app behind
        .overlay {
            if showWebViewPopover, let url = webViewURL {
                WebViewPopover(
                    url: url,
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showWebViewPopover = false
                        }
                    }
                )
                .conciergeTheme(theme)
                .zIndex(1002)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .font(
            theme.typography.fontFamily.isEmpty
                ? .system(size: theme.typography.fontSize)
                : .custom(theme.typography.fontFamily, size: theme.typography.fontSize)
        )
    }

    // MARK: - Actions

    private func sendTapped() {
        controller.sendMessage(isUser: !showAgentSend)
        hapticFeedback.impactOccurred(intensity: 0.5)
        hapticFeedback.impactOccurred(intensity: 0.7)
    }

    private func handleMicTap() {
        controller.applyVoiceInputBehavior(theme.behavior.input)
        if controller.isRecording {
            controller.toggleMic(currentSelectionLocation: selectedTextRange.location)
        } else {
            // Dismiss keyboard before starting recording
            isInputFocused = false
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
                Message(template: .productCarouselCard(ProductCardData(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 1",
                    subtitle: nil,
                    price: nil,
                    badge: nil,
                    destinationURL: URL(string: "https://adobe.com")!,
                    primaryButton: nil,
                    secondaryButton: nil,
                    imageWidth: nil,
                    imageHeight: nil
                ))),
                Message(template: .productCarouselCard(ProductCardData(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 2",
                    subtitle: nil,
                    price: nil,
                    badge: nil,
                    destinationURL: URL(string: "https://adobe.com")!,
                    primaryButton: nil,
                    secondaryButton: nil,
                    imageWidth: nil,
                    imageHeight: nil
                )))
            ])),
            Message(template: .divider)
        ]

        var body: some View {
            ChatView(messages: messages)
                .conciergeTheme(ConciergeTheme())
        }
    }

    return ChatViewPreview()
}
