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

struct ChatMessageView: View {
    @Environment(\.conciergeTheme) private var theme

    let template: MessageTemplate
    var messageBody: String?

    init(template: MessageTemplate, messageBody: String? = nil) {
        self.template = template
        self.messageBody = messageBody
    }
    
    var body: some View {
        switch template {
        case .divider:
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
                .padding(.horizontal)
            
        case .basic(let isUserMessage):
            HStack(alignment: .bottom) {
                if isUserMessage { Spacer() }

                // Render agent messages with inline markdown
                (isUserMessage ? Text(messageBody ?? "") : Text.markdown(messageBody ?? ""))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .textSelection(.enabled)
                    .foregroundColor(isUserMessage ? theme.onPrimary : theme.onAgent)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isUserMessage ? theme.primary : theme.agentBubble)
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
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 100)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100)
                                    .clipped()
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: 100)
                            @unknown default:
                                EmptyView()
                            }
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
            
        case .carousel(let imageSource, let title, let body):
            VStack(alignment: .leading, spacing: 0) {
                switch imageSource {
                case .local(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 350, height: 200)
                        .clipped()
                case .remote(let url):
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 350, height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 350, height: 200)
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 350, height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
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
                        .padding(.bottom, 14)
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(width: 350, alignment: .leading)
            }
            .background(Color.PrimaryLight)
            .cornerRadius(10)
            .frame(width: 350)
            
        case .carouselGroup(let items):
            CarouselGroupView(items: items)
        }
    }
}
