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

    public let sources: [ConciergeSourceReference]
    private let initiallyExpanded: Bool

    @State private var isExpanded: Bool = false

    /// Creates a new Sources list view.
    /// - Parameters:
    ///   - sources: The list of sources to display. If empty, the view renders nothing.
    ///   - initiallyExpanded: Whether the list starts expanded.
    public init(sources: [ConciergeSourceReference], initiallyExpanded: Bool = false) {
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
                        Divider().background(Color.secondary.opacity(0.2))
                        VStack(spacing: 0) {
                            ForEach(Array(sources.enumerated()), id: \ .element.id) { index, source in
                                SourceRowView(source: source, theme: theme)
                                    .padding(.vertical, 10)
                                if index < sources.count - 1 {
                                    Divider().background(Color.secondary.opacity(0.1))
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(theme.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
                    .foregroundStyle(theme.textBody)
                Spacer()
                if !initiallyExpanded {
                    Text("\(sources.count)")
                        .font(.caption)
                        .foregroundStyle(theme.textBody.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
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
}

#if DEBUG
struct AgentSourcesListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SourcesListView(
                sources: [
                    ConciergeSourceReference(ordinal: "a.", link: URL(string: "https://example.com/articles/1")!),
                    ConciergeSourceReference(ordinal: "b.", link: URL(string: "https://example.com/articles/2")!)
                ],
                initiallyExpanded: true
            )
            .padding()
            .previewDisplayName("Expanded")

            SourcesListView(
                sources: [
                    ConciergeSourceReference(ordinal: "a.", link: URL(string: "https://example.com/articles/1")!)
                ],
                initiallyExpanded: false
            )
            .padding()
            .previewDisplayName("Collapsed")
        }
        .background(Color(UIColor.systemBackground))
    }
}
#endif


