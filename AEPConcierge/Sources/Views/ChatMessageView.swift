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
    let template: MessageTemplate
    var messageBody: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    
    // Bubble with tail shape
    struct ChatBubbleShape: Shape {
        let isUser: Bool
        let cornerRadius: CGFloat = 12
        let tailSize = CGSize(width: 10, height: 12)
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let bubbleRect: CGRect
            if isUser {
                bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailSize.width, height: rect.height)
            } else {
                bubbleRect = CGRect(x: rect.minX + tailSize.width, y: rect.minY, width: rect.width - tailSize.width, height: rect.height)
            }

            let bubble = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            path.addPath(bubble.path(in: bubbleRect))

            // Curved tail from the bottom-corner, concave inward with extreme taper
            // Slight negative overlap tucks the tail under the bubble to avoid white seam
            let overlap: CGFloat = 1.5
            if isUser {
                // Bottom-right corner attachment
                let baseRight = CGPoint(x: bubbleRect.maxX - overlap, y: bubbleRect.maxY - cornerRadius * 0.9)
                let baseBottom = CGPoint(x: bubbleRect.maxX - cornerRadius * 0.7, y: bubbleRect.maxY - overlap)
                let tip = CGPoint(x: bubbleRect.maxX + tailSize.width, y: bubbleRect.maxY - tailSize.height * 0.25)
                // Controls chosen to bow inward and make a thin tip
                let c1 = CGPoint(x: baseRight.x + tailSize.width * 0.40, y: baseRight.y + tailSize.height * 0.8)
                let c2 = CGPoint(x: tip.x - tailSize.width * 0.22, y: tip.y - tailSize.height * 0.22)
                let c3 = CGPoint(x: tip.x - tailSize.width * 0.22, y: tip.y + tailSize.height * 0.24)
                let c4 = CGPoint(x: baseBottom.x + tailSize.width * 0.24, y: baseBottom.y - tailSize.height * 0.1)

                path.move(to: baseRight)
                path.addCurve(to: tip, control1: c1, control2: c2)
                path.addCurve(to: baseBottom, control1: c3, control2: c4)
                path.addLine(to: baseRight)
                path.closeSubpath()
            } else {
                // Bottom-left corner attachment (mirror)
                let baseLeft = CGPoint(x: bubbleRect.minX + overlap, y: bubbleRect.maxY - cornerRadius * 0.9)
                let baseBottom = CGPoint(x: bubbleRect.minX + cornerRadius * 0.7, y: bubbleRect.maxY - overlap)
                let tip = CGPoint(x: bubbleRect.minX - tailSize.width, y: bubbleRect.maxY - tailSize.height * 0.25)
                let c1 = CGPoint(x: baseLeft.x - tailSize.width * 0.40, y: baseLeft.y + tailSize.height * 0.8)
                let c2 = CGPoint(x: tip.x + tailSize.width * 0.22, y: tip.y - tailSize.height * 0.22)
                let c3 = CGPoint(x: tip.x + tailSize.width * 0.22, y: tip.y + tailSize.height * 0.24)
                let c4 = CGPoint(x: baseBottom.x - tailSize.width * 0.24, y: baseBottom.y - tailSize.height * 0.1)

                path.move(to: baseLeft)
                path.addCurve(to: tip, control1: c1, control2: c2)
                path.addCurve(to: baseBottom, control1: c3, control2: c4)
                path.addLine(to: baseLeft)
                path.closeSubpath()
            }

            return path
        }
    }
    
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
                
                let tailPadding: CGFloat = 14
                Text(messageBody ?? "")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(isUserMessage ? theme.onPrimary : theme.textBody)
                    .background(
                        ChatBubbleShape(isUser: isUserMessage)
                            .fill(isUserMessage ? theme.primary : Color(UIColor.systemGray5))
                    )
                    .compositingGroup()
                    .drawingGroup()
                    // Ensure visual margins are even by accounting for tail width
                    .padding(.leading, isUserMessage ? 0 : tailPadding)
                    .padding(.trailing, isUserMessage ? tailPadding : 0)
                    .padding(.horizontal, 2) // small global adjustment to balance both sides
                
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
                        }
                        Text(text)
                            .foregroundColor(Color.TextBody)
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
                        }
                        if let body = body {
                            Text(body)
                                .foregroundColor(Color.TextBody)
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
                    
                    Text(body)
                        .font(.system(.subheadline))
                        .foregroundColor(Color.TextBody)
                        .padding(.bottom, 14)
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
