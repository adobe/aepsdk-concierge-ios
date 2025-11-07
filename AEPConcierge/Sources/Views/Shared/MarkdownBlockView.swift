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

/// SwiftUI component that renders markdown using the markdown block renderer.
/// It composes `MarkdownText` and native SwiftUI elements to support full markdown rendering.
struct MarkdownBlockView: View {
    let markdown: String
    var textColor: UIColor
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)
    var spacing: CGFloat = 8
    var citationMarkers: [CitationRenderer.Marker] = []
    var citationStyle: CitationStyle = .default
    var onOpenLink: ((URL) -> Void)? = nil

    var body: some View {
        let blocks = MarkdownRenderer.buildBlocks(
            markdown: markdown,
            textColor: textColor,
            baseFont: baseFont
        )
        let transformedBlocks = blocks.map(transformBlock)

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(transformedBlocks.enumerated()), id: \.0) { _, block in
                switch block {
                case .text(let ns):
                    MarkdownText(
                        attributed: ns,
                        onOpenLink: onOpenLink
                    )
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let ns):
                    MarkdownText(
                        attributed: ns,
                        onOpenLink: onOpenLink
                    )
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                case .divider:
                    Divider()
                case .blockQuote(let paras):
                    QuoteBlockView(
                        blocks: paras,
                        onOpenLink: onOpenLink
                    )
                case .list(let type, let items):
                    ListBlockView(
                        type: type,
                        items: items,
                        onOpenLink: onOpenLink
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private func transformBlock(_ block: MarkdownRenderer.MarkdownBlock) -> MarkdownRenderer.MarkdownBlock {
        switch block {
        case .text(let ns):
            let replaced = CitationAttachmentBuilder.replaceTokens(
                in: ns,
                markers: citationMarkers,
                baseFont: baseFont,
                style: citationStyle
            )
            return .text(replaced)
        case .code(let ns):
            let replaced = CitationAttachmentBuilder.replaceTokens(
                in: ns,
                markers: citationMarkers,
                baseFont: baseFont,
                style: citationStyle
            )
            return .code(replaced)
        case .divider:
            return block
        case .blockQuote(let children):
            return .blockQuote(children.map(transformBlock))
        case .list(let type, let items):
            let transformedItems = items.map { $0.map(transformBlock) }
            return .list(type: type, items: transformedItems)
        }
    }
}

/// Quote block with left rule, supports nested content by stacking paragraphs.
private struct QuoteBlockView: View {
    let blocks: [MarkdownRenderer.MarkdownBlock]
    let onOpenLink: ((URL) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.0) { _, child in
                    switch child {
                    case .text(let ns):
                        MarkdownText(
                            attributed: ns,
                            onOpenLink: onOpenLink
                        )
                            .fixedSize(horizontal: false, vertical: true)
                    case .code(let ns):
                        MarkdownText(
                            attributed: ns,
                            onOpenLink: onOpenLink
                        )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                    case .divider:
                        Divider()
                    case .blockQuote(let nested):
                        QuoteBlockView(
                            blocks: nested,
                            onOpenLink: onOpenLink
                        )
                    case .list(let t, let children):
                        ListBlockView(
                            type: t,
                            items: children,
                            onOpenLink: onOpenLink
                        )
                    }
                }
            }
            .padding(.leading, 6)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 3, height: proxy.size.height)
                        .cornerRadius(2)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct ListBlockView: View {
    let type: MarkdownRenderer.ListType
    let items: [[MarkdownRenderer.MarkdownBlock]]
    let onOpenLink: ((URL) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                let idx = pair.offset
                let blocks = pair.element
                Group {
                    // Special case: list item is a single blockQuote
                    // Draw the quote rule alongside the bullet so the rule spans the full line of the list row.
                    if blocks.count == 1, case let .blockQuote(quotedChildren) = blocks[0] {
                        HStack(alignment: .top, spacing: 8) {
                            Text(bullet(for: idx))
                                .font(.body)
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(quotedChildren.enumerated()), id: \.0) { _, child in
                                    switch child {
                                    case .text(let ns):
                                        MarkdownText(
                                            attributed: ns,
                                            onOpenLink: onOpenLink
                                        )
                                            .fixedSize(horizontal: false, vertical: true)
                                    case .code(let ns):
                                        MarkdownText(
                                            attributed: ns,
                                            onOpenLink: onOpenLink
                                        )
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .cornerRadius(8)
                                    case .divider:
                                        Divider()
                                    case .blockQuote(let nested):
                                        QuoteBlockView(
                                            blocks: nested,
                                            onOpenLink: onOpenLink
                                        )
                                    case .list(let t, let inner):
                                        ListBlockView(
                                            type: t,
                                            items: inner,
                                            onOpenLink: onOpenLink
                                        )
                                    }
                                }
                            }
                            .padding(.leading, 6)
                            .background(alignment: .leading) {
                                GeometryReader { proxy in
                                    Rectangle()
                                        .fill(Color.secondary)
                                        .frame(width: 3, height: proxy.size.height)
                                        .cornerRadius(2)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    } else {
                        // If a list item contains only nested lists (no text/quotes),
                        // suppress the parent's bullet to avoid a visually empty bullet
                        // followed by an indented bullet list.
                        let hasOwnRenderableText = blocks.contains { b in
                            switch b {
                            case .text: return true
                            case .blockQuote: return true
                            case .divider: return false
                            case .list: return false
                            case .code: return true
                            }
                        }

                        if hasOwnRenderableText {
                            HStack(alignment: .top, spacing: 8) {
                                Text(bullet(for: idx))
                                    .font(.body)
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(blocks.enumerated()), id: \.0) { _, child in
                                        switch child {
                                        case .text(let ns):
                                            MarkdownText(
                                                attributed: ns,
                                                onOpenLink: onOpenLink
                                            )
                                                .fixedSize(horizontal: false, vertical: true)
                                        case .code(let ns):
                                            MarkdownText(
                                                attributed: ns,
                                                onOpenLink: onOpenLink
                                            )
                                                .fixedSize(horizontal: false, vertical: true)
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(uiColor: .secondarySystemBackground))
                                                .cornerRadius(8)
                                        case .divider:
                                            Divider()
                                        case .blockQuote(let nested):
                                            QuoteBlockView(
                                                blocks: nested,
                                                onOpenLink: onOpenLink
                                            )
                                        case .list(let t, let inner):
                                            ListBlockView(
                                                type: t,
                                                items: inner,
                                                onOpenLink: onOpenLink
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            // Render only the nested lists without an extra bullet at this level
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(blocks.enumerated()), id: \.0) { _, child in
                                    if case .list(let t, let inner) = child {
                                        ListBlockView(
                                            type: t,
                                            items: inner,
                                            onOpenLink: onOpenLink
                                        )
                                    } else if case .divider = child {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
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


