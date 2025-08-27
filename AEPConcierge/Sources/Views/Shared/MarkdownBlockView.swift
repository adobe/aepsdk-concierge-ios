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

/// SwiftUI component that renders markdown using the markdown block renderer.
/// It composes `MarkdownText` and native SwiftUI elements to support full markdown rendering.
struct MarkdownBlockView: View {
    let markdown: String
    var textColor: UIColor
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)
    var spacing: CGFloat = 8

    var body: some View {
        let blocks = MarkdownRenderer.buildBlocks(
            markdown: markdown,
            textColor: textColor,
            baseFont: baseFont
        )

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(blocks.enumerated()), id: \.0) { _, block in
                switch block {
                case .text(let ns):
                    MarkdownText(attributed: ns)
                        .fixedSize(horizontal: false, vertical: true)
                case .divider:
                    Divider()
                case .blockQuote(let paras):
                    QuoteBlockView(blocks: paras)
                case .list(let type, let items):
                    ListBlockView(type: type, items: items)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}

/// Quote block with left rule, supports nested content by stacking paragraphs.
private struct QuoteBlockView: View {
    let blocks: [MarkdownRenderer.Block]
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.secondary)
                .frame(width: 3)
                .cornerRadius(2)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.0) { _, child in
                    switch child {
                    case .text(let ns):
                        MarkdownText(attributed: ns)
                            .fixedSize(horizontal: false, vertical: true)
                    case .divider:
                        Divider()
                    case .blockQuote(let nested):
                        QuoteBlockView(blocks: nested)
                    case .list(let t, let children):
                        ListBlockView(type: t, items: children)
                    }
                }
            }
        }
    }
}

private struct ListBlockView: View {
    let type: MarkdownRenderer.ListType
    let items: [[MarkdownRenderer.Block]]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.0) { idx, blocks in
                HStack(alignment: .top, spacing: 8) {
                    Text(bullet(for: idx))
                        .font(.body)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(blocks.enumerated()), id: \.0) { _, child in
                            switch child {
                            case .text(let ns):
                                MarkdownText(attributed: ns)
                                    .fixedSize(horizontal: false, vertical: true)
                            case .divider:
                                Divider()
                            case .blockQuote(let nested):
                                QuoteBlockView(blocks: nested)
                            case .list(let t, let inner):
                                ListBlockView(type: t, items: inner)
                            }
                        }
                    }
                }
                .padding(.leading,  (type == .unordered ? 0 : 0))
            }
        }
    }

    private func bullet(for index: Int) -> String {
        switch type {
        case .ordered:
            return "\(index + 1)."
        case .unordered:
            return "•"
        }
    }
}


