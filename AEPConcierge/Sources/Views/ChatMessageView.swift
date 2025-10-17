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
import UIKit

struct ChatMessageView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergePlaceholderConfig) private var placeholderConfig
    @Environment(\.openURL) private var openURL

    let template: MessageTemplate
    var messageBody: String?
    var sources: [TempSource]? = nil
    var promptSuggestions: [String]? = nil
    var onSuggestionTap: ((String) -> Void)? = nil

    init(template: MessageTemplate, messageBody: String? = nil, sources: [TempSource]? = nil, promptSuggestions: [String]? = nil, onSuggestionTap: ((String) -> Void)? = nil) {
        self.template = template
        self.messageBody = messageBody
        self.sources = sources
        self.promptSuggestions = promptSuggestions
        self.onSuggestionTap = onSuggestionTap
    }
    
    var body: some View {
        switch template {
        case .divider:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
                .padding(.horizontal)
            
        case .basic(let isUserMessage):
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    if isUserMessage { Spacer() }
                    Group {
                        // User text
                        if isUserMessage {
                            Text(messageBody ?? "")
                        // Agent - Placeholder before message content is available, Markdown renderer otherwise.
                        } else {
                            if let messageBody, !messageBody.isEmpty {
                                MarkdownBlockView(
                                    markdown: messageBody,
                                    textColor: UIColor(theme.onAgent)
                                )
                            } else {
                                ConciergeResponsePlaceholderView()
                            }
                        }
                    }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, (!isUserMessage && (sources?.isEmpty == false)) ? 6 : 12)
                        .textSelection(.enabled)
                        .foregroundColor(isUserMessage ? theme.onPrimary : theme.onAgent)
                        .background(
                            Group {
                                if isUserMessage {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(theme.primary)
                                } else {
                                    if let sources, !sources.isEmpty {
                                        RoundedCornerShape(radius: 14, corners: [.topLeft, .topRight])
                                            .fill(theme.agentBubble)
                                    } else {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(theme.agentBubble)
                                    }
                                }
                            }
                        )
                        .compositingGroup()
                        .contextMenu {
                            Button(action: {
                                let source = messageBody ?? ""
                                // Copy raw markdown (preserve markers)
                                UIPasteboard.general.string = source
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }

                    if !isUserMessage { Spacer() }
                }

                // Attach sources dropdown for agent messages only
                if !isUserMessage, let sources, !sources.isEmpty {
                    HStack(alignment: .top) {
                        SourcesListView(sources: sources)
                        Spacer()
                    }
                }
            }
            
        case .thumbnail(let imageSource, let title, let text):
            HStack {
                HStack(spacing: 0) {
                    switch imageSource {
                    case .local(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100)
                            .clipped()
                    case .remote(let url):
                        RemoteImageView(url: url, width: 100, height: 100)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = title {
                            Text(title)
                                .font(.system(.headline, design: .rounded))
                                .bold()
                                .foregroundColor(Color.TextTitle)
                                .textSelection(.enabled)
                        }
                        Text(text)
                            .foregroundColor(Color.TextBody)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color.PrimaryLight)
                .cornerRadius(10)
                
                Spacer()
            }
            
        case .numbered(let number, let title, let body):
            HStack {
                HStack(alignment: .center, spacing: 12) {
                    if let number = number {
                        ZStack {
                            Circle()
                                .fill(Color.PrimaryDark)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 3)
                                .frame(width: 32, height: 32)
                            
                            Text("\(number)")
                                .font(.system(.body, design: .rounded))
                                .bold()
                                .foregroundColor(Color.TextTitle)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = title {
                            Text(title)
                                .font(.system(.headline, design: .rounded))
                                .bold()
                                .foregroundColor(Color.TextTitle)
                                .textSelection(.enabled)
                        }
                        if let body = body {
                            Text(body)
                                .foregroundColor(Color.TextBody)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.PrimaryLight)
                .cornerRadius(10)
                
                Spacer()
            }
            
        case .productCarouselCard(let imageSource, let title, let destination):
            Button(action: {
                if let destination = destination {
                    openURL(destination)
                }
            }) {
                ZStack(alignment: .bottomLeading) {
                    // Full card image
                    switch imageSource {
                    case .local(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 200)
                            .clipped()
                    case .remote(let url):
                        RemoteImageView(url: url, width: 280, height: 200)
                    }
                    
                    // Overlay title bubble at bottom left
                    Text(title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.black.opacity(0.7))
                        )
                        .padding(12)
                }
            }
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .frame(width: 280, height: 200)
            .buttonStyle(PlainButtonStyle())
            
            
        case .productCard(let imageSource, let title, let body, let primaryButton, let secondaryButton):
            VStack(alignment: .leading, spacing: 0) {
                switch imageSource {
                case .local(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 350, height: 200)
                        .clipped()
                case .remote(let url):
                    RemoteImageView(url: url, width: 350, height: 200)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .bold()
                        .foregroundColor(Color.TextTitle)
                        .textSelection(.enabled)
                    
                    Text(body)
                        .font(.system(.subheadline))
                        .foregroundColor(Color.TextBody)
                        .textSelection(.enabled)
                    
                    // Buttons section
                    if primaryButton != nil || secondaryButton != nil {
                        HStack(spacing: 12) {
                            if let primaryButton = primaryButton {
                                ButtonView(
                                    text: primaryButton.text,
                                    style: .primary,
                                    action: {
                                        if let url = URL(string: primaryButton.url) {
                                            openURL(url)
                                        }
                                    }
                                )
                            }
                            
                            if let secondaryButton = secondaryButton {
                                ButtonView(
                                    text: secondaryButton.text,
                                    style: .secondary,
                                    action: {
                                        if let url = URL(string: secondaryButton.url) {
                                            openURL(url)
                                        }
                                    }
                                )
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(14)
                .frame(width: 350, alignment: .leading)
            }
            .background(Color.PrimaryLight)
            .cornerRadius(10)
            .frame(width: 350)
            
        case .carouselGroup(let items):
            CarouselGroupView(items: items)

        case .promptSuggestion(let text):
            HStack(alignment: .bottom) {
                Group {
                    Button(action: { onSuggestionTap?(text) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrowshape.turn.up.right")
                                .imageScale(.small)
                                .foregroundColor(theme.onAgent)
                            Text(text)
                                .font(.system(.subheadline))
                                .foregroundColor(theme.onAgent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.agentBubble)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
    }
}
