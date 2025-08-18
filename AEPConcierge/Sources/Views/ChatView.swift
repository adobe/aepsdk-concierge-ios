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
import AVFoundation
import Speech
import AEPServices
import UIKit

// MARK: - UIKit-backed multiline text view with selection support
private struct SelectableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var measuredHeight: CGFloat
    var isEditable: Bool
    var placeholder: String
    var minLines: Int = 1
    var maxLines: Int = 4
    var onEditingChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.isScrollEnabled = false
        tv.showsVerticalScrollIndicator = true
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.accessibilityTraits.insert(.allowsDirectInteraction)
        // Placeholder label
        let ph = UILabel()
        ph.text = placeholder
        ph.textColor = .secondaryLabel
        ph.numberOfLines = 1
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.tag = 999
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 12),
            ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 10)
        ])
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEditable = isEditable
        if let ph = uiView.viewWithTag(999) as? UILabel {
            ph.isHidden = !text.isEmpty
        }
        context.coordinator.recalculateHeight(uiView)
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
        if uiView.window != nil, uiView.isFirstResponder == false {
            // Keep cursor positioned where the binding says
            if let start = uiView.position(from: uiView.beginningOfDocument, offset: selectedRange.location),
               let end = uiView.position(from: start, offset: selectedRange.length),
               let range = uiView.textRange(from: start, to: end) {
                context.coordinator.isSettingSelectionProgrammatically = true
                uiView.selectedTextRange = range
                DispatchQueue.main.async {
                    context.coordinator.isSettingSelectionProgrammatically = false
                }
            }
            // Ensure caret/end visible
            context.coordinator.scrollToBottom(uiView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        var isSettingSelectionProgrammatically: Bool = false
        init(_ parent: SelectableTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            if parent.text != newText { parent.text = newText }
            recalculateHeight(textView)
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let length = textView.offset(from: range.start, to: range.end)
                let newRange = NSRange(location: location, length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
            scrollToBottom(textView)
        }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged?(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onEditingChanged?(false) }
        func textViewDidChangeSelection(_ textView: UITextView) {
            if isSettingSelectionProgrammatically { return }
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let length = textView.offset(from: range.start, to: range.end)
                let newRange = NSRange(location: location, length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
            scrollToBottom(textView)
        }
        func scrollToBottom(_ textView: UITextView) {
            let end = NSRange(location: (textView.text as NSString).length, length: 0)
            textView.scrollRangeToVisible(end)
        }
        func recalculateHeight(_ textView: UITextView) {
            // Use sizeThatFits to measure multiline height at current width
            textView.layoutIfNeeded()
            let lineHeight = textView.font?.lineHeight ?? 17
            let insets = textView.textContainerInset.top + textView.textContainerInset.bottom
            let minH = CGFloat(parent.minLines) * lineHeight + insets
            let maxH = CGFloat(parent.maxLines) * lineHeight + insets
            let fittingSize = CGSize(width: max(1, textView.bounds.width), height: .greatestFiniteMagnitude)
            let measured = textView.sizeThatFits(fittingSize).height
            let target = min(max(measured, minH), maxH)
            textView.isScrollEnabled = measured > maxH + 1
            if abs(parent.measuredHeight - target) > 0.5 {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.measuredHeight = target
                }
            }
        }
    }
}

public struct ChatView: View {
    private let LOG_TAG = "ChatView"
    
    @StateObject private var viewModel: ConciergeChatViewModel
    @State private var showAgentSend: Bool = false
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var composerHeight: CGFloat = 0
    
    private let parent: Concierge?
    
    private let textSpeaker: TextSpeaking?
    @Environment(\.conciergeTheme) private var theme
    
    // Header content
    private let titleText: String
    private let subtitleText: String?
    // Close handler for UIKit hosting
    private let onClose: (() -> Void)?
    private var currentMessageIndex: Int { viewModel.messages.count - 1 }
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
    @Environment(\.colorScheme) private var colorScheme
        
    public init(
        parent: Concierge? = nil,
        speechCapturer: SpeechCapturing? = nil,
        textSpeaker: TextSpeaking? = nil,
        title: String = "Concierge",
        subtitle: String? = "Powered by Adobe",
        onClose: (() -> Void)? = nil
    ) {
        self.parent = parent
        self.textSpeaker = textSpeaker
        self.titleText = title
        self.subtitleText = subtitle
        self.onClose = onClose
        let vm = ConciergeChatViewModel(
            chatService: parent?.conciergeChatService ?? ConciergeChatService(),
            speechCapturer: speechCapturer ?? SpeechCapturer(),
            speaker: textSpeaker
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
        
    // internal use only for previews
    init(parent: Concierge? = nil, messages: [Message]) {
        self.parent = nil
        self.textSpeaker = nil
        self.titleText = "Concierge"
        self.subtitleText = "Powered by Adobe"
        self.onClose = nil
        let vm = ConciergeChatViewModel(chatService: ConciergeChatService(), speechCapturer: nil, speaker: nil)
        vm.messages = messages
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    public var body: some View {
        // Fully opaque background
        mainView
    }
    
    private var mainView: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed background only (dynamic for light/dark)
            Color(.systemBackground)
                .ignoresSafeArea()

            // Messages list area respects safe areas (space between top/bottom insets)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            message.chatMessageView
                                .id(message.id)
                                .onAppear {
                                    if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                        textSpeaker?.utter(text: messageBody)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        // Safe-area aware top bar
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                // Brand title on the left
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundColor(Color.primary)
                    if let subtitleText = subtitleText {
                        Text(subtitleText)
                            .font(.system(.footnote))
                            .foregroundColor(Color.secondary)
                    }
                }

                Spacer()

                // Test-only sender toggle (kept near the close icon)
                Button(action: {
                    showAgentSend.toggle()
                    if showAgentSend {
                        viewModel.inputState = .editing
                        viewModel.chatState = .idle
                    }
                }) {
                    Text(showAgentSend ? "Agent" : "User")
                        .font(.system(.footnote))
                        .padding(8)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }

                // Close icon on the right
                Button(action: {
                    if let onClose = onClose { onClose() } else { parent?.hideChatUI() }
                }) {
                    brandIcon(named: "S2_Icon_Close_20_N", systemName: "xmark")
                        .foregroundColor(Color.Secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(theme.surfaceDark)
        }
        // Safe-area aware bottom composer
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    // Unified rounded container
                    HStack(spacing: 8) {
                    if viewModel.isRecording {
                        // Listening pill only; hide text and send (text preserved in VM)
                        HStack {
                            Button(action: { viewModel.cancelMic() }) {
                                brandIcon(named: "S2_Icon_Close_20_N", systemName: "xmark")
                                    .foregroundColor(Color.Secondary)
                            }
                            .buttonStyle(.plain)
                            brandIcon(named: "S2_Icon_AudioWave_20_N", systemName: "waveform")
                                .foregroundColor(Color.Secondary)
                            Text("Listening")
                                .font(.system(.subheadline))
                                .foregroundColor(.secondary)
                            Spacer(minLength: 0)
                            Button(action: { viewModel.completeMic() }) {
                                brandIcon(named: "S2_Icon_Checkmark_20_N", systemName: "checkmark")
                                    .foregroundColor(Color.Secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if viewModel.inputState == .transcribing {
                        // Transcribing pill only
                        HStack {
                            Button(action: { viewModel.cancelMic() }) {
                                brandIcon(named: "S2_Icon_Close_20_N", systemName: "xmark")
                                    .foregroundColor(Color.Secondary)
                            }
                            .buttonStyle(.plain)
                            Text("Transcribing")
                                .font(.system(.subheadline))
                                .foregroundColor(.secondary)
                            Spacer(minLength: 0)
                            brandIcon(named: "S2_Icon_Checkmark_20_N", systemName: "checkmark")
                                .foregroundColor(Color.secondary.opacity(0.4))
                        }
                    } else {
                        // Default: text view followed by mic, then send
                        SelectableTextView(
                            text: $viewModel.inputText,
                            selectedRange: $selectedTextRange,
                            measuredHeight: $composerHeight,
                            isEditable: viewModel.composerEditable,
                            placeholder: "How can I help",
                            onEditingChanged: { began in
                                DispatchQueue.main.async {
                                    if began { viewModel.inputState = .editing }
                                    else { viewModel.inputState = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing }
                                }
                            }
                        )
                        .frame(height: max(40, composerHeight))
                        .animation(.easeInOut(duration: 0.15), value: composerHeight)

                        Button(action: handleMicTap) {
                            brandIcon(named: "S2_Icon_Microphone_20_N", systemName: "mic.fill")
                                .foregroundColor(viewModel.micEnabled ? Color.Secondary : Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.micEnabled)

                        if viewModel.chatState == .processing {
                            brandIcon(named: "S2_Icon_ClockPending_20_N", systemName: "clock")
                                .foregroundColor(Color.secondary)
                        } else {
                            Button(action: sendTapped) {
                                brandIcon(named: "S2_Icon_Send_20_N", systemName: "arrow.up.circle.fill")
                                    .renderingMode(.template)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(viewModel.sendEnabled ? Color.Secondary : Color.secondary.opacity(0.5))
                            }
                            .disabled(!viewModel.sendEnabled)
                        }
                    }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(composerBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(composerBorderColor, lineWidth: (colorScheme == .light ? 1 : 0))
                    )
                    .cornerRadius(12)
                    
                }

                Text("AI responses may be inaccurate or misleading. Be sure to double check answers and sources.")
                    .font(.system(.footnote))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(theme.surfaceDark)
        }
        .onAppear {
            hapticFeedback.prepare()
            // initialize input machine for current text
            viewModel.inputState = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .editing
        }
    }
    
    private func sendTapped() {
        viewModel.sendMessage(isUser: !showAgentSend)
    }

    private var composerBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
    }

    private var composerBorderColor: Color {
        Color(UIColor.separator)
    }

    private func handleMicTap() {
        if viewModel.isRecording {
            viewModel.toggleMic(currentSelectionLocation: selectedTextRange.location)
        } else {
            hapticFeedback.impactOccurred()
            viewModel.toggleMic(currentSelectionLocation: selectedTextRange.location)
        }
    }
        

    // Prefer branded SVG/asset if present, fall back to SF Symbol
    private func brandIcon(named: String, systemName: String) -> Image {
        if let uiImage = UIImage(named: named) {
            return Image(uiImage: uiImage).renderingMode(.template)
        } else {
            return Image(systemName: systemName)
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
            Message(template: .carouselGroup([
                Message(template: .carousel(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 1",
                    body: "Product 1 description"
                )),
                Message(template: .carousel(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 2",
                    body: "Product 2 description"
                )),
                Message(template: .carousel(
                    imageSource: .remote(URL(string: "https://i.ibb.co/0X8R3TG/Messages-24.png")!),
                    title: "Product 3",
                    body: "Product 3 description"
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
