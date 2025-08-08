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
    @State private var isRecording = false
    @State private var isProcessing = false
    
    private let parent: Concierge?
    
    private let speechCapturer: SpeechCapturing?
    private let textSpeaker: TextSpeaking?
    private var currentMessageIndex: Int {
        messages.count - 1
    }
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
        
    public init(parent: Concierge? = nil, speechCapturer: SpeechCapturing? = nil, textSpeaker: TextSpeaking? = nil) {
        self.parent = parent
        self.textSpeaker = textSpeaker
        self.speechCapturer = speechCapturer ?? SpeechCapturer()
    }
        
    // internal use only for previews
    init(parent: Concierge? = nil, messages: [Message]) {
        self.messages = messages
        self.parent = nil
        self.speechCapturer = nil
        self.textSpeaker = nil
    }
    
    public var body: some View {
        if #available(iOS 16.4, *) {
            mainView
                .background(.clear)
                .presentationBackground(.clear)
        } else {
            mainView
                .background(Color.clear)
        }
    }
    
    private var mainView: some View {
        ZStack {
            // Border glow effect with increased width and blur
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white, lineWidth: 4)
                .blur(radius: 8)
                .ignoresSafeArea()
            
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        parent?.hideChatUI()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.Secondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.top)
                .overlay(
                    VStack(spacing: 4) {
                        Text("Concierge")
                            .font(.system(.title, design: .rounded))
                            .bold()
                            .foregroundColor(Color.Secondary)
                        Text("Powered by Adobe")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white)
                    }
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity)
                )
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(messages) { message in
                            message.chatMessageView.onAppear {
                                if message.shouldSpeakMessage, let messageBody = message.chatMessageView.messageBody {
                                    textSpeaker?.utter(text: messageBody)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 90)
                }
                .padding(.top, 15)
                
                Spacer()
            }
            .overlay(
                ZStack {
                    // Mic button
                    Button(action: handleMicTap) {
                        if !isRecording && !isProcessing {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Color.PrimaryLight)
                                .background(Circle().fill(Color.white))
                                .clipShape(Circle())
                        } else {
                            LottieView(name: isProcessing ? "thinking" : "listening")
                                .scaleEffect(0.35)
                                .frame(width: 64, height: 64)
                                .padding(.bottom, 15)
                        }
                    }
                    .disabled(isProcessing)
                }
                    .padding(.bottom, 20),
                alignment: .bottom
            )
        }
        .onAppear {
            speechCapturer?.initialize(responseProcessor: processSpeechData)
            hapticFeedback.prepare()
        }
    }
    
    private func handleMicTap() {
        isRecording.toggle()
        
        if isRecording {
            speechCapturer?.beginCapture()
            // Create the user message immediately
            messages.append(Message(template: .basic(isUserMessage: true), messageBody: ""))
        } else {
            speechCapturer?.endCapture() { transcription, error in
                processTranscription(transcription, error: error)
            }
        }
    }
        
    private func processTranscription(_ transcription: String?, error: Error?) {
        guard let transcription = transcription, !transcription.isEmpty else {
            Log.trace(label: LOG_TAG, "Unable to process a transcription that was nil or empty.")
            messages.removeLast()
            return
        }
        
        isProcessing = true
        
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
            // Update the message body directly instead of through chatMessageView
            messages[currentMessageIndex].messageBody = text
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
