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

public struct ChatView: View {
    private let LOG_TAG = "ChatView"
    
    @State private var messages: [Message] = []
    // Text input for bottom composer
    @State private var inputText: String = ""
    
    private let parent: Concierge?
    
    private let speechCapturer: SpeechCapturing?
    private let textSpeaker: TextSpeaking?
    
    // Header content
    private let titleText: String
    private let subtitleText: String?
    // Close handler for UIKit hosting
    private let onClose: (() -> Void)?
    private var currentMessageIndex: Int {
        messages.count - 1
    }
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
        
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
            // Solid background
            Color.PrimaryDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with title/subtitle and Close
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundColor(Color.TextTitle)
                        if let subtitleText = subtitleText {
                            Text(subtitleText)
                                .font(.system(.footnote))
                                .foregroundColor(Color.TextBody)
                        }
                    }
                    Spacer()
                    Button("Close") {
                        if let onClose = onClose {
                            onClose()
                        } else {
                            parent?.hideChatUI()
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.Secondary.opacity(0.9))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.PrimaryDark)

                // Messages list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            message.chatMessageView.onAppear {
                                if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                    textSpeaker?.utter(text: messageBody)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }

            // Bottom input bar (iOS 15-compatible)
            HStack(spacing: 8) {
                if #available(iOS 16.0, *) {
                    TextField("Type a message…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(12)
                        .foregroundColor(.black)
                        .lineLimit(1...4)
                } else {
                    // Fallback: TextEditor for iOS 15
                    ZStack(alignment: .leading) {
                        if inputText.isEmpty {
                            Text("Type a message…")
                                .foregroundColor(Color.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $inputText)
                            .frame(minHeight: 40, maxHeight: 100)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            .foregroundColor(.black)
                    }
                }

                Button(action: sendTapped) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.Secondary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.PrimaryDark.opacity(0.98).ignoresSafeArea(edges: .bottom))
        }
        .onAppear {
            // Keep initialization for future voice features, but no UI exposure now
            speechCapturer?.initialize(responseProcessor: processSpeechData)
            hapticFeedback.prepare()
        }
    }
    
    private func sendTapped() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(Message(template: .basic(isUserMessage: true), messageBody: text))
        inputText = ""
    }
        
    private func processTranscription(_ transcription: String?, error: Error?) {
        guard let transcription = transcription, !transcription.isEmpty else {
            Log.trace(label: LOG_TAG, "Unable to process a transcription that was nil or empty.")
            if !messages.isEmpty { messages.removeLast() }
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
            if messages.isEmpty {
                messages.append(Message(template: .basic(isUserMessage: true), messageBody: text))
            } else {
                messages[currentMessageIndex].messageBody = text
            }
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
