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

/// A collapsible list of sources
public struct SourcesListView: View {
    @Environment(\.conciergeTheme) private var theme

    public let sources: [URL]
    private let initiallyExpanded: Bool

    @State private var isExpanded: Bool = false

    /// Creates a new Sources list view.
    /// - Parameters:
    ///   - sources: The list of sources to display. If empty, the view renders nothing.
    ///   - initiallyExpanded: Whether the list starts expanded.
    public init(sources: [URL], initiallyExpanded: Bool = false) {
        self.sources = sources
        self.initiallyExpanded = initiallyExpanded
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        Group {
            if !sources.isEmpty {
                VStack(spacing: 0) {
                    header
                    if isExpanded {
                        Divider().background(Color.black.opacity(0.08))
                        VStack(spacing: 0) {
                            ForEach(Array(sources.enumerated()), id: \.offset) { index, link in
                                SourceRowView(ordinal: "\(index + 1).", link: link, theme: theme)
                                    .padding(.vertical, 10)
                                if index < sources.count - 1 {
                                    Divider().background(Color.black.opacity(0.06))
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(
                    RoundedCornerShape(radius: 14, corners: [.bottomLeft, .bottomRight])
                        .fill(theme.agentBubble)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sources")
    }

    private var header: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 8) {
                chevronImage
                    .foregroundStyle(theme.textBody)
                Text("Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onAgent)
                Spacer()
                // Feedback buttons
                HStack(spacing: 4) {
                    Button(action: {}) {
                        thumbUpImage
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.onAgent)

                    Button(action: {}) {
                        thumbDownImage
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.onAgent)
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
}

// MARK: - Previews
#Preview("Expanded") {
    SourcesListView(
        sources: [URL(string: "https://example.com/articles/1")!, URL(string: "https://example.com/articles/2")!],
        initiallyExpanded: true
    )
    .padding()
    .background(Color(UIColor.systemBackground))
}

#Preview("Collapsed") {
    SourcesListView(
        sources: [URL(string: "https://example.com/articles/1")!],
        initiallyExpanded: false
    )
    .padding()
    .background(Color(UIColor.systemBackground))
}
