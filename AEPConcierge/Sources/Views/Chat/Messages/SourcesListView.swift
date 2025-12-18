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

/// A collapsible list of sources.
public struct SourcesListView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergeFeedbackPresenter) private var feedbackPresenter

    public let sources: [Source]
    private let initiallyExpanded: Bool
    public let feedbackSentiment: FeedbackSentiment?
    public let messageId: UUID?

    @State private var isExpanded: Bool = false

    /// Creates a new Sources list view.
    /// - Parameters:
    ///   - sources: The list of sources to display. If empty, the view renders nothing.
    ///   - initiallyExpanded: Whether the list starts expanded.
    ///   - feedbackSentiment: The feedback sentiment that was submitted for this message, if any.
    ///   - messageId: The ID of the message this sources list belongs to.
    public init(sources: [Source], initiallyExpanded: Bool = false, feedbackSentiment: FeedbackSentiment? = nil, messageId: UUID? = nil) {
        self.sources = sources
        self.initiallyExpanded = initiallyExpanded
        self.feedbackSentiment = feedbackSentiment
        self.messageId = messageId
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        Group {
            if !uniqueSources.isEmpty {
                sourceContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sources")
    }
    
    private var sourceContent: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                expandedContent
            }
        }
        .background(backgroundShape)
    }
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            Divider().background(Color.black.opacity(0.08))
            sourceRows
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var sourceRows: some View {
        let entries = uniqueSources
        return VStack(spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                let source = entries[index]
                sourceRow(for: source)
                if index < entries.count - 1 {
                    bottomDivider
                }
            }
        }
    }
    
    private func sourceRow(for source: Source) -> some View {
        SourceRowView(ordinal: "\(source.citationNumber).",
                      title: source.title,
                      link: URL(string: source.url),
                      theme: theme)
            .padding(.vertical, 10)
    }
    
    private var bottomDivider: some View {
        Divider().background(Color.black.opacity(0.06))
    }

    private var uniqueSources: [Source] {
        CitationRenderer.deduplicate(sources)
    }
    
    private var backgroundShape: some View {
        RoundedCornerShape(radius: 14, corners: [.bottomLeft, .bottomRight])
            .fill(theme.colors.message.conciergeBackground.color)
    }

    private var header: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 8) {
                chevronImage
                    .foregroundStyle(theme.colors.message.conciergeText.color)
                Text("Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.message.conciergeText.color)
                Spacer()
                // Feedback buttons
                HStack(spacing: 4) {
                    Button(action: {
                        feedbackPresenter.present(.positive, messageId)
                    }) {
                        thumbUpImage
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(thumbUpColor)
                    .disabled(feedbackSentiment != nil)

                    Button(action: {
                        feedbackPresenter.present(.negative, messageId)
                    }) {
                        thumbDownImage
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(thumbDownColor)
                    .disabled(feedbackSentiment != nil)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AgentSourcesListView.Header")
    }

    @ViewBuilder
    var chevronImage: some View {
        let assetName = isExpanded ? "S2_Icon_ChevronDown_20_N" : "S2_Icon_ChevronRight_20_N"
        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .renderingMode(.template)
        } else {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
        }
    }

    @ViewBuilder
    var thumbUpImage: some View {
        if let uiImage = UIImage(named: "S2_Icon_ThumbUp_20_N") {
            Image(uiImage: uiImage).renderingMode(.template)
        } else {
            Image(systemName: "hand.thumbsup")
        }
    }

    @ViewBuilder
    var thumbDownImage: some View {
        if let uiImage = UIImage(named: "S2_Icon_ThumbDown_20_N") {
            Image(uiImage: uiImage).renderingMode(.template)
        } else {
            Image(systemName: "hand.thumbsdown")
        }
    }
    
    private var thumbUpColor: Color {
        guard let sentiment = feedbackSentiment else {
            return theme.colors.message.conciergeText.color
        }
        return sentiment == .positive ? theme.colors.primary.primary.color : Color.gray.opacity(0.4)
    }
    
    private var thumbDownColor: Color {
        guard let sentiment = feedbackSentiment else {
            return theme.colors.message.conciergeText.color
        }
        return sentiment == .negative ? theme.colors.primary.primary.color : Color.gray.opacity(0.4)
    }
}

// MARK: - Previews
#Preview("Expanded") {
    SourcesListView(
        sources: [
            Source(url: "https://example.com/articles/1", title: "Article of first source", startIndex: 1, endIndex: 2, citationNumber: 1),
            Source(url: "https://example.com/articles/2", title: "Second source found here", startIndex: 1, endIndex: 2, citationNumber: 2)
        ],
        initiallyExpanded: true
    )
    .padding()
    .background(Color(UIColor.systemBackground))
}

#Preview("Collapsed") {
    SourcesListView(
        sources: [
            Source(url: "https://example.com/articles/1", title: "Article of first source", startIndex: 1, endIndex: 2, citationNumber: 1),
            Source(url: "https://example.com/articles/2", title: "Second source found here", startIndex: 1, endIndex: 2, citationNumber: 2)
        ],
        initiallyExpanded: false
    )
    .padding()
    .background(Color(UIColor.systemBackground))
}
