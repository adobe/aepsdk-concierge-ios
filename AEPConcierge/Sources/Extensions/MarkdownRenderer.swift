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

/// Markdown renderer utilities: parse markdown and produce structured blocks
/// that can be rendered by SwiftUI components.
enum MarkdownRenderer {
    // MARK: - Block model for interleaving SwiftUI views
    enum Block: Equatable {
        case text(NSAttributedString)
        case divider
        case blockQuote([Block])
        case list(type: ListType, items: [[Block]])
    }

    // MARK: - Shared helper types (extracted)
    enum ListType { case ordered, unordered }
    struct ListSignature: Equatable {
        struct Component: Equatable { let type: ListType; let ordinal: Int }
        let components: [Component]
    }

    // MARK: - Shared helpers (extracted)
    private static func nsFromSlice(_ slice: AttributedString, fallbackFont: UIFont? = nil) -> NSAttributedString {
        var s = slice
        if let font = fallbackFont {
            var c = AttributeContainer()
            c[AttributeScopes.UIKitAttributes.FontAttribute.self] = font
            s.mergeAttributes(c)
        }
        return NSAttributedString(s)
    }

    /// Build blocks (text, divider, blockQuote) directly from PresentationIntent
    /// using a small stateful builder.
    static func buildBlocks(markdown: String, textColor: UIColor? = nil, baseFont: UIFont = .preferredFont(forTextStyle: .body)) -> [Block] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else { return [] }
        var builder = BlockBuilder(attributed: attributed, textColor: textColor, baseFont: baseFont)
        return builder.build()
    }

    // MARK: - Builder
    private struct BlockBuilder {
        let attributed: AttributedString
        let textColor: UIColor?
        let baseFont: UIFont

        private(set) var blocks: [Block] = []

        // List state (stack of list items, each level collects blocks for a single item)
        struct ListFrame { var type: ListType; var items: [[Block]]; var currentItem: [Block]; var ordinal: Int?; var signature: ListSignature? }
        var listStack: [ListFrame] = []

        // Paragraph state
        var pendingParagraph = NSMutableAttributedString()

        // Header state
        var headerBuffer = NSMutableAttributedString()
        var headerLevelActive: Int? = nil

        // Quote state (stack of child blocks for nested quotes)
        var quoteChildrenStack: [[Block]] = []

        private mutating func appendBlock(_ block: Block) {
            if !listStack.isEmpty {
                listStack[listStack.count - 1].currentItem.append(block)
            } else if !quoteChildrenStack.isEmpty {
                quoteChildrenStack[quoteChildrenStack.count - 1].append(block)
            } else {
                blocks.append(block)
            }
        }

        mutating func pushParagraph(_ ns: NSAttributedString) {
            let styled = applyBaseStyling(ns, textColor: textColor, baseFont: baseFont)
            appendBlock(.text(styled))
        }

        mutating func flushCurrentListItem() {
            guard var frame = listStack.popLast() else { return }
            // finalize current item
            if !pendingParagraph.string.isEmpty { flushPendingParagraph() }
            if !frame.currentItem.isEmpty { frame.items.append(frame.currentItem) }
            // emit or push back up
            if listStack.isEmpty {
                // produce top level list block
                let block = Block.list(type: frame.type, items: frame.items)
                if !quoteChildrenStack.isEmpty {
                    quoteChildrenStack[quoteChildrenStack.count - 1].append(block)
                } else {
                    blocks.append(block)
                }
            } else {
                listStack[listStack.count - 1].currentItem.append(.list(type: frame.type, items: frame.items))
            }
        }

        mutating func flushPendingParagraph() {
            if pendingParagraph.length > 0 {
                pushParagraph(pendingParagraph)
                pendingParagraph = NSMutableAttributedString()
            }
        }

        func headerFont(for level: Int) -> UIFont {
            switch level {
            case 1: return .systemFont(ofSize: 22, weight: .bold)
            case 2: return .systemFont(ofSize: 20, weight: .semibold)
            case 3: return .systemFont(ofSize: 18, weight: .semibold)
            default: return .systemFont(ofSize: 16, weight: .semibold)
            }
        }

        mutating func flushHeaderBuffer() {
            guard let level = headerLevelActive, headerBuffer.length > 0 else { return }
            let r = NSRange(location: 0, length: headerBuffer.length)
            headerBuffer.addAttribute(.font, value: headerFont(for: level), range: r)
            headerBuffer.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: r)
            pushParagraph(headerBuffer)
            headerBuffer = NSMutableAttributedString()
            headerLevelActive = nil
        }

        mutating func flushQuote() {
            guard !quoteChildrenStack.isEmpty else { return }
            let children = quoteChildrenStack.removeLast()
            appendBlock(.blockQuote(children))
        }

        mutating func build() -> [Block] {
            for run in attributed.runs {
                let sliceAS = AttributedString(attributed[run.range])
                let kind = classify(presentation: run.presentationIntent)
                let quoteDepth = blockQuoteDepth(presentation: run.presentationIntent)
                // Synchronize quote stack depth with current run
                while quoteChildrenStack.count > quoteDepth {
                    while !listStack.isEmpty { flushCurrentListItem() }
                    flushPendingParagraph()
                    flushQuote()
                }
                while quoteChildrenStack.count < quoteDepth {
                    while !listStack.isEmpty { flushCurrentListItem() }
                    // Entering a deeper quote. Flush any outside paragraph before opening quote
                    flushPendingParagraph()
                    quoteChildrenStack.append([])
                }

                switch kind {
                case .header(let level):
                    while !listStack.isEmpty { flushCurrentListItem() }
                    flushPendingParagraph()
                    // end quote group between blocks
                    while !quoteChildrenStack.isEmpty { flushQuote() }
                    if headerLevelActive == nil {
                        headerLevelActive = level
                    }
                    if let active = headerLevelActive, active != level {
                        flushHeaderBuffer()
                        headerLevelActive = level
                    }
                    headerBuffer.append(nsFromSlice(sliceAS))

                case .thematicBreak:
                    while !listStack.isEmpty { flushCurrentListItem() }
                    flushPendingParagraph()
                    appendBlock(.divider)

                case .codeBlock:
                    while !listStack.isEmpty { flushCurrentListItem() }
                    flushPendingParagraph()
                    let ns = nsFromSlice(sliceAS)
                    let m = NSMutableAttributedString(attributedString: ns)
                    m.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: 0, length: m.length))
                    m.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: m.length))
                    pushParagraph(m)

                case .blockQuote:
                    // Treat quoted text as paragraph content at current quote depth
                    let ns = nsFromSlice(sliceAS)
                    pendingParagraph.append(ns)

                case .list(let type, let depth, let ordinal, let signature):
                    // If we are about to enter a deeper list level from paragraph text,
                    // flush the paragraph so it renders before the list at this position.
                    if listStack.count < depth {
                        flushPendingParagraph()
                    }

                    // Synchronize list stack depth
                    while listStack.count > depth { flushCurrentListItem() }
                    while listStack.count < depth { listStack.append(ListFrame(type: type, items: [], currentItem: [], ordinal: nil, signature: nil)) }

                    // If the list container type changed at this depth, end the current list frame
                    // and start a new sibling frame at the same depth with the new type
                    if let top = listStack.last, top.type != type {
                        flushCurrentListItem()
                        // after flush, depth decreased by 1; restore frame at same depth with new type
                        while listStack.count < depth { listStack.append(ListFrame(type: type, items: [], currentItem: [], ordinal: nil, signature: nil)) }
                    }

                    // Start a new item when ordinal/signature changes
                    if let top = listStack.last, top.ordinal != ordinal || top.signature != signature {
                        if !listStack[listStack.count - 1].currentItem.isEmpty {
                            listStack[listStack.count - 1].items.append(listStack[listStack.count - 1].currentItem)
                            listStack[listStack.count - 1].currentItem = []
                        }
                        listStack[listStack.count - 1].ordinal = ordinal
                        listStack[listStack.count - 1].signature = signature
                    }

                    // Append this run as a paragraph block inside the current list item
                    let ns = nsFromSlice(sliceAS)
                    pushParagraph(ns)

                case .paragraph:
                    if headerLevelActive != nil { flushHeaderBuffer() }
                    // If we were inside a list and now see a plain paragraph, the list has ended.
                    // Finalize all open list frames before starting this paragraph
                    while !listStack.isEmpty { flushCurrentListItem() }
                    let ns = nsFromSlice(sliceAS)
                    pendingParagraph.append(ns)
                }
            }

            while !listStack.isEmpty { flushCurrentListItem() }
            flushPendingParagraph()
            // Close any remaining quotes
            while !quoteChildrenStack.isEmpty { flushQuote() }
            return blocks
        }

        // MARK: - Run classification
        private enum RunKind {
            case header(Int)
            case thematicBreak
            case codeBlock
            case blockQuote
            case list(ListType, Int, Int?, ListSignature?)
            case paragraph
        }

        private func classify(presentation: PresentationIntent?) -> RunKind {
            struct Context {
                var headerLevel: Int? = nil
                var isCodeBlock: Bool = false
                var isThematic: Bool = false
                var isBlockQuote: Bool = false
                var ordinal: Int? = nil
                var pairs: [(ListType, Int)] = []
                var quoteDepth: Int = 0

                init(presentation: PresentationIntent?) {
                    guard let pres = presentation else { return }
                    var containerStack: [ListType] = []
                    for comp in pres.components {
                        switch comp.kind {
                        case .header(let level):
                            headerLevel = level
                        case .codeBlock:
                            isCodeBlock = true
                        case .thematicBreak:
                            isThematic = true
                        case .blockQuote:
                            isBlockQuote = true
                            quoteDepth += 1
                        case .orderedList:
                            containerStack.append(.ordered)
                        case .unorderedList:
                            containerStack.append(.unordered)
                        case .listItem(let ord):
                            ordinal = ord
                            let currentType = containerStack.last ?? .unordered
                            pairs.append((currentType, ord))
                        default:
                            break
                        }
                    }
                }

                func toRunKind() -> RunKind {
                    if let level = headerLevel { return .header(level) }
                    if isThematic { return .thematicBreak }
                    if isCodeBlock { return .codeBlock }
                    if !pairs.isEmpty {
                        let type = pairs.last!.0
                        let depth = pairs.count
                        let signature: ListSignature? = ListSignature(components: pairs.map { ListSignature.Component(type: $0.0, ordinal: $0.1) })
                        return .list(type, depth, ordinal, signature)
                    }
                    return .paragraph
                }
            }

            let ctx = Context(presentation: presentation)
            // Keep quote depth info by storing it temporarily in a thread-local? We instead
            // synchronize quote stack in build() using presentation again, so just return kind here.
            return ctx.toRunKind()
        }

        private func hasBlockQuote(presentation: PresentationIntent?) -> Bool {
            guard let pres = presentation else { return false }
            for comp in pres.components {
                if case .blockQuote = comp.kind { return true }
            }
            return false
        }

        private func blockQuoteDepth(presentation: PresentationIntent?) -> Int {
            guard let pres = presentation else { return 0 }
            var depth = 0
            for comp in pres.components {
                if case .blockQuote = comp.kind { depth += 1 }
            }
            return depth
        }
    }

    static func applyBaseStyling(_ source: NSAttributedString, textColor: UIColor?, baseFont: UIFont) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let range = NSRange(location: 0, length: mutable.length)
        if let color = textColor { mutable.addAttribute(.foregroundColor, value: color, range: range) }
        mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? UIFont else {
                mutable.addAttribute(.font, value: baseFont, range: subrange)
                return
            }
            let traits = font.fontDescriptor.symbolicTraits
            let isMono = traits.contains(.traitMonoSpace)
            let isBoldish = traits.contains(.traitBold)
            if !isMono && !isBoldish {
                let new = UIFont(descriptor: font.fontDescriptor.withSize(baseFont.pointSize), size: baseFont.pointSize)
                mutable.addAttribute(.font, value: new, range: subrange)
            }
        }
        return mutable
    }
}

#if DEBUG
extension MarkdownRenderer {
    /// Debug utility to print the runs and presentation intents produced by Markdown parsing.
    static func debugDump(_ markdown: String, syntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax) {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: syntax,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            print("MarkdownRenderer.debugDump: failed to parse markdown")
            return
        }

        let swiftUIFontScope = AttributeScopes.SwiftUIAttributes.self
        let uiKitScope = AttributeScopes.UIKitAttributes.self
        let foundationScope = AttributeScopes.FoundationAttributes.self

        print("\n—— MarkdownRenderer Debug Dump (syntax: \(syntax)) ——")
        print("Raw text:\n\(String(attributed.characters))")

        for run in attributed.runs {
            let slice = AttributedString(attributed[run.range])
            let text = String(slice.characters)
            print("\n[run] \"\(text)\"")

            if let inline = run.inlinePresentationIntent { print(" inline: \(inline)") }

            if let pres = run.presentationIntent {
                let kinds = pres.components.map { $0.kind }
                print(" block kinds: \(kinds)")
            }

            if let font = run.attributes[swiftUIFontScope.FontAttribute.self] {
                print(" font: \(font)")
            }
            if let color = run.attributes[uiKitScope.ForegroundColorAttribute.self] {
                print(" color: \(color)")
            }
            if let link = run.attributes[foundationScope.LinkAttribute.self] {
                print(" link: \(String(describing: link))")
            }
        }
        print("—— End Debug Dump ——\n")
    }
}
#endif

