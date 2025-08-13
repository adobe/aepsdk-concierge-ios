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
    var isEditable: Bool
    var placeholder: String
    var onEditingChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.isScrollEnabled = true
        tv.showsVerticalScrollIndicator = true
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
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
    }
}

public struct ChatView: View {
    private let LOG_TAG = "ChatView"
    
    @State private var messages: [Message] = []
    // Text input for bottom composer
    @State private var inputText: String = ""
    @State private var isRecording: Bool = false
    @State private var isProcessing: Bool = false
    @State private var showAgentSend: Bool = false
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var inputTextAtRecordingStart: String = ""
    @State private var recordingInsertStart: Int? = nil
    @State private var ignoreEndCaptureTranscription: Bool = false
    @State private var audioLevels: [Float] = Array(repeating: 0, count: 5)
    
    private let parent: Concierge?
    
    private var speechCapturer: SpeechCapturing?
    private let textSpeaker: TextSpeaking?
    @Environment(\.conciergeTheme) private var theme
    
    // Header content
    private let titleText: String
    private let subtitleText: String?
    // Close handler for UIKit hosting
    private let onClose: (() -> Void)?
    private var currentMessageIndex: Int {
        messages.count - 1
    }
    
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
        self.speechCapturer = speechCapturer ?? SpeechCapturer()
        self.titleText = title
        self.subtitleText = subtitle
        self.onClose = onClose
    }
        
    // internal use only for previews
    init(parent: Concierge? = nil, messages: [Message]) {
        self.messages = messages
        self.parent = nil
        self.speechCapturer = nil
        self.textSpeaker = nil
        self.titleText = "Concierge"
        self.subtitleText = "Powered by Adobe"
        self.onClose = nil
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
                        ForEach(messages) { message in
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
                .onChange(of: messages.count) { _ in
                    if let lastId = messages.last?.id {
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
                Button("Close") {
                    if let onClose = onClose {
                        onClose()
                    } else {
                        parent?.hideChatUI()
                    }
                }
                .foregroundColor(Color.Secondary)
                .buttonStyle(.plain)

                Spacer()

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

                // Test-only control to flip sender to agent for the next send
                Button(action: { showAgentSend.toggle() }) {
                    Text(showAgentSend ? "Agent" : "User")
                        .font(.system(.footnote))
                        .padding(8)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(theme.surfaceDark)
        }
        // Safe-area aware bottom composer
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                // Voice input is always visible
                Button(action: handleMicTap) {
                    HStack(spacing: 6) {
                        if isRecording {
                            // 5-band pills from live spectrum
                            HStack(spacing: 4) {
                                let heights = audioLevels.map { lvl -> CGFloat in
                                    CGFloat(6 + Double(lvl) * 16)
                                }
                                ForEach(0..<5, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.Secondary)
                                        .frame(width: 4, height: heights.count > i ? heights[i] : 6)
                                }
                            }
                            brandIcon(named: "icon_stop", systemName: "stop.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundColor(Color.white)
                                .padding(6)
                                .background(Circle().fill(Color.Secondary))
                        } else {
                            brandIcon(named: "icon_mic", systemName: "mic.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(Color.Secondary)
                        }
                    }
                    .padding(10)
                    .background(
                        Capsule().fill(Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.12))
                    )
                }
                .accessibilityLabel(isRecording ? "Stop recording" : "Voice input")
                .disabled(isProcessing)

                // Single path for iOS 15+ using UITextView wrapper to support cursor insertions
                SelectableTextView(
                    text: $inputText,
                    selectedRange: $selectedTextRange,
                    isEditable: !isRecording,
                    placeholder: isRecording ? "Recording… Tap stop to edit" : "Type a message…"
                )
                    .frame(minHeight: 40, maxHeight: 100)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(composerBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isRecording ? Color.Secondary : composerBorderColor,
                                lineWidth: isRecording ? 1.5 : (colorScheme == .light ? 1 : 0)
                            )
                    )
                    .cornerRadius(12)
                    .opacity(isRecording ? 0.9 : 1)
                    .allowsHitTesting(!isRecording)
                    .frame(maxWidth: .infinity)

                Button(action: sendTapped) {
                    brandIcon(named: "icon_send", systemName: "arrow.up.circle.fill")
                        .renderingMode(.template)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.Secondary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(theme.surfaceDark)
        }
        .onAppear {
            // Keep initialization for future voice features, but no UI exposure now
            // Set handlers on the class-based capturer; no reassignment to self needed
            if let capturer = self.speechCapturer {
                capturer.initialize(responseProcessor: processSpeechData)
                capturer.levelUpdateHandler = { levels in
                    var five = levels
                    if five.count != 5 { five = Array(repeating: 0, count: 5) }
                    self.audioLevels = five
                }
            }
            hapticFeedback.prepare()
        }
    }
    
    private func sendTapped() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // If recording, stop capture but do NOT alter input with final transcription
        if isRecording {
            ignoreEndCaptureTranscription = true
            isRecording = false
            isProcessing = true
            speechCapturer?.endCapture { _, _ in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.ignoreEndCaptureTranscription = false
                }
            }
        }

        if showAgentSend {
            messages.append(Message(template: .basic(isUserMessage: false), messageBody: text))
        } else {
            messages.append(Message(template: .basic(isUserMessage: true), messageBody: text))
        }
        inputText = ""
    }

    private var composerBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white
    }

    private var composerBorderColor: Color {
        Color(UIColor.separator)
    }

    private func handleMicTap() {
        isRecording.toggle()
        if isRecording {
            hapticFeedback.impactOccurred()
            // Snapshot current input and insertion point so partial results replace this segment
            inputTextAtRecordingStart = inputText
            recordingInsertStart = max(0, min(selectedTextRange.location, (inputText as NSString).length))
            speechCapturer?.beginCapture()
            // Do NOT append a placeholder message; we now stream into the input field
        } else {
            isProcessing = true
            speechCapturer?.endCapture() { transcription, error in
                isProcessing = false
                // Do not auto-send. If not ignored, apply final transcription into the input field
                if !self.ignoreEndCaptureTranscription,
                   let transcription = transcription, !transcription.isEmpty {
                    let base = self.inputTextAtRecordingStart as NSString
                    let start = max(0, min(self.recordingInsertStart ?? 0, base.length))
                    let prefix = base.substring(to: start)
                    let suffix = base.substring(from: start)
                    self.inputText = prefix + transcription + suffix
                    self.selectedTextRange.location = start + (transcription as NSString).length
                    self.selectedTextRange.length = 0
                }
                // Reset snapshot to current state
                self.inputTextAtRecordingStart = self.inputText
                self.recordingInsertStart = self.selectedTextRange.location
            }
        }
    }
        
    private func processTranscription(_ transcription: String?, error: Error?) {
        guard let transcription = transcription, !transcription.isEmpty else {
            Log.trace(label: LOG_TAG, "Unable to process a transcription that was nil or empty.")
            return
        }
        
        parent?.conciergeChatService.processChat(transcription) { conciergeResponse, conciergeError in
            if conciergeError != nil {
                // handle error
                return
            }
            
            guard let response = conciergeResponse else {
                return
            }
            
            processResponse(response)
        }
    }
        
    private func processResponse(_ response: ConciergeResponse) {
        guard let message = response.interaction.response.first?.message else {
            print("we didn't get a response from the Chat API")
            return
        }
        
        messages.append(Message(template: .divider))
        
        messages.append(Message(
            template: .basic(isUserMessage: false),
            shouldSpeakMessage: true,
            messageBody: message.opening
        ))
        
        if let items = message.items {
            messages.append(Message(template: .divider))
            
            var itemNumber = 1
            items.forEach { item in
                messages.append(Message(
                    template: .numbered(
                        number: itemNumber,
                        title: item.title,
                        body: item.introduction
                    )
                ))
                itemNumber += 1
            }
        }
        
        if let closing = message.ending {
            messages.append(Message(template: .divider))
            messages.append(Message(
                template: .basic(isUserMessage: false),
                messageBody: closing
            ))
        }
        
        messages.append(Message(template: .divider))
    }
    
    private func processSpeechData(_ text: String) {
        DispatchQueue.main.async {
            // Insert transcribed text by replacing the streaming segment captured at start
            if isRecording {
                let base = inputTextAtRecordingStart as NSString
                let start = max(0, min(recordingInsertStart ?? 0, base.length))
                let prefix = base.substring(to: start)
                let suffix = base.substring(from: start)
                inputText = prefix + text + suffix
                // Place caret after the streamed text
                selectedTextRange.location = start + (text as NSString).length
                selectedTextRange.length = 0
            } else {
                // When not recording, do not mutate chat messages from speech callback.
                // Users will explicitly tap Send to post whatever is in the input box.
            }
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
