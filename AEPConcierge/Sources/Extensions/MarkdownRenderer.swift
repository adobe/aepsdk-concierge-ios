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

import UIKit

struct MarkdownRenderer {
    enum ListType {
        case ordered
        case unordered
    }

    enum Block: Equatable {
        case text(NSAttributedString)
        case divider
        case list(type: ListType, items: [[Block]])
        case blockQuote([Block])
    }

    // Outer-to-inner container order (helps reason about stack diffs)
    enum Container: Equatable {
        case blockQuote
        case orderedList
        case unorderedList
        case listItem(ordinal: Int)
        case paragraph
        case header(level: Int)
    }

    enum Event {
        case open(Container)
        case close(Container)
        case text(NSAttributedString)
        case divider
        case code(NSAttributedString)
    }

    // Internal parser leaf classification
    private enum LeafKind {
        case none
        case codeBlock
        case thematicBreak
    }

    // Runtime list frame (engine state)
    struct ListFrame {
        var type: ListType
        var items: [[Block]]
        var currentItem: [Block]
    }

    // MARK: Inputs (immutable)
    private let attributed: AttributedString
    private let textColor: UIColor?
    private let baseFont: UIFont

    // MARK: Output
    private var blocks: [Block] = []

    // MARK: Container state (structure of the tree)
    private var listStack: [ListFrame] = []
    private var quoteChildrenStack: [[Block]] = []

    // MARK: Accumulation buffers (inline content)
    private var paragraphBuffer = NSMutableAttributedString()
    private var headerBuffer = NSMutableAttributedString()

    // MARK: Mode/flags
    private var headerLevelActive: Int? = nil

    // MARK: - Public API
    static func buildBlocks(
        markdown: String,
        textColor: UIColor? = nil,
        baseFont: UIFont = .preferredFont(forTextStyle: .body)
    ) -> [MarkdownRenderer.Block] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else { return [] }
        var builder = MarkdownRenderer(attributed: attributed, textColor: textColor, baseFont: baseFont)
        return builder.build()
    }

    private mutating func build() -> [Block] {
        // Phase 1: build events by diffing container stacks per run
        var events: [Event] = []
        var prevStack: [Container] = []

        for run in attributed.runs {
            let runSlice = AttributedString(attributed[run.range])
            let (nextStack, leafKind) = containersFor(presentation: run.presentationIntent)

            // diff stacks -> close then open
            let longestCommonPrefixLength = longestCommonPrefix(prevStack, nextStack)
            if prevStack.count > longestCommonPrefixLength {
                for idx in stride(from: prevStack.count - 1, through: longestCommonPrefixLength, by: -1) {
                    events.append(.close(prevStack[idx]))
                }
            }
            if nextStack.count > longestCommonPrefixLength {
                for idx in longestCommonPrefixLength..<nextStack.count {
                    events.append(.open(nextStack[idx]))
                }
            }

            // leaf payloads
            switch leafKind {
            case .codeBlock:
                let ns = nsFromSlice(runSlice)
                let m = NSMutableAttributedString(attributedString: ns)
                m.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: 0, length: m.length))
                m.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: m.length))
                events.append(.code(m))
            case .thematicBreak:
                events.append(.divider)
            case .none:
                let ns = nsFromSlice(runSlice)
                if ns.length > 0 { events.append(.text(ns)) }
            }

            prevStack = nextStack
        }

        // close any remaining containers at EOF
        for idx in stride(from: prevStack.count - 1, through: 0, by: -1) {
            events.append(.close(prevStack[idx]))
        }

        // Phase 2: consume events centrally
        consume(events: events)

        // Safety: finalize any residual state (should be no-ops if events were complete)
        while !listStack.isEmpty { closeListFrame() }
        flushParagraphBuffer()
        if headerLevelActive != nil { flushHeaderBuffer() }
        while !quoteChildrenStack.isEmpty { flushQuote() }
        return blocks
    }

    // MARK: - Block assembly helpers
    private mutating func appendBlock(_ block: Block) {
        if !listStack.isEmpty {
            listStack[listStack.count - 1].currentItem.append(block)
        } else if !quoteChildrenStack.isEmpty {
            quoteChildrenStack[quoteChildrenStack.count - 1].append(block)
        } else {
            blocks.append(block)
        }
    }

    private mutating func pushParagraph(_ ns: NSAttributedString) {
        let styled = applyBaseStyling(ns, textColor: textColor, baseFont: baseFont)
        appendBlock(.text(styled))
    }

    // MARK: - Paragraph/Header/Quote finalizers
    private mutating func flushParagraphBuffer() {
        if paragraphBuffer.length > 0 {
            pushParagraph(paragraphBuffer)
            paragraphBuffer = NSMutableAttributedString()
        }
    }

    private mutating func flushHeaderBuffer() {
        guard let level = headerLevelActive, headerBuffer.length > 0 else { return }
        let r = NSRange(location: 0, length: headerBuffer.length)
        headerBuffer.addAttribute(.font, value: headerFont(for: level), range: r)
        headerBuffer.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: r)
        pushParagraph(headerBuffer)
        headerBuffer = NSMutableAttributedString()
        headerLevelActive = nil
    }

    private mutating func flushQuote() {
        guard !quoteChildrenStack.isEmpty else { return }
        let children = quoteChildrenStack.removeLast()
        appendBlock(.blockQuote(children))
    }

    // MARK: - Event production helpers

    /// PresentationIntent.components appear inner most first -> outer most.
    /// Iterate reversed to go outer -> inner, which keeps the container
    /// type stack aligned with listItem depths.
    ///
    /// For example, for the run:
    ///   [run] "Nested ordered 9"
    ///   block kinds: [paragraph, listItem 1, unorderedList, listItem 1, unorderedList, blockQuote]
    /// The components arrive inner-most first (paragraph) and end with the outer blockQuote.
    ///
    /// Reversing yields:
    ///   [blockQuote, unorderedList, listItem 1, orderedList, listItem 1, paragraph]
    /// As we scan this reversed list:
    ///   - blockQuote            -> quoteDepth += 1
    ///   - unorderedList         -> containerTypeStack = [.unordered]
    ///   - listItem 1            -> pairs += (.unordered, 1)
    ///   - orderedList           -> containerTypeStack = [.unordered, .ordered]
    ///   - listItem 1            -> pairs += (.ordered, 1)  // nested item at depth 2 (ordered)
    ///   - paragraph             -> hasParagraph = true
    ///
    /// From these we build the container stack outer->inner:
    ///   [.blockQuote, .unorderedList, .listItem(1), .orderedList, .listItem(1), .paragraph]
    /// This creates a stable longest-common-prefix and aligns list containers, preserving
    /// correct sibling boundaries.
    ///
    /// Using outer -> inner
    /// A = [.blockQuote, .unorderedList, .listItem(1), .orderedList, .listItem(1), .paragraph]
    /// B = [.blockQuote, .unorderedList, .listItem(2), .paragraph]
    /// Shared prefix = [.blockQuote, .unorderedList]. The event diff (performed elsewhere)
    /// will close A’s trailing containers and open B’s trailing containers, producing a new
    /// sibling list item at the same parent unordered list.
    ///
    /// Using inner -> outer (default parser order, you get the wrong groupings)
    /// C = [.paragraph, .listItem(1), .orderedList, .listItem(1), .unorderedList, .blockQuote]
    /// D = [.paragraph, .listItem(2), .unorderedList, .blockQuote]
    /// Shared prefix is only [.paragraph] in inner -> outer order. Using this order causes
    /// incorrect groupings and sibling boundaries.
    private func containersFor(presentation: PresentationIntent?) -> ([Container], LeafKind) {
        guard let presentation = presentation else {
            // If there is no presentation intent, default to a standard paragraph container
            return ([.paragraph], .none)
        }

        // Outer structural context/flags
        var headerLevel: Int? = nil
        var hasParagraph = false
        var leaf: LeafKind = .none
        var appendedParagraph = false

        var containers: [Container] = []

        // Build container stack directly by walking reversed components.
        for comp in presentation.components.reversed() {
            switch comp.kind {
            case .header(let level):
                headerLevel = level
            case .codeBlock:
                leaf = .codeBlock
            case .thematicBreak:
                leaf = .thematicBreak
            case .blockQuote:
                containers.append(.blockQuote)
            case .orderedList:
                containers.append(.orderedList)
            case .unorderedList:
                containers.append(.unorderedList)
            case .listItem(let ord):
                containers.append(.listItem(ordinal: ord))
            case .paragraph:
                hasParagraph = true
                if !appendedParagraph {
                    containers.append(.paragraph)
                    appendedParagraph = true
                }
            default:
                break
            }
        }

        // Header takes precedence over paragraph
        if let level = headerLevel, leaf == .none {
            containers.append(.header(level: level))
            return (containers, .none)
        }

        // Paragraph: add only when not a leaf block and not already appended
        if leaf == .none && hasParagraph && !appendedParagraph {
            containers.append(.paragraph)
        }

        return (containers, leaf)
    }

    private func longestCommonPrefix(_ a: [Container], _ b: [Container]) -> Int {
        let n = min(a.count, b.count)
        var i = 0
        while i < n && a[i] == b[i] { i += 1 }
        return i
    }

    // MARK: - Event consumer
    private mutating func consume(events: [Event]) {
        for event in events {
            switch event {
            case .open(let c):
                handleOpen(c)
            case .close(let c):
                handleClose(c)
            case .text(let ns):
                handleText(ns)
            case .divider:
                // HR is a block element: end paragraphs and lists first
                while !listStack.isEmpty { closeListFrame() }
                flushParagraphBuffer()
                appendBlock(.divider)
            case .code(let ns):
                // Code blocks are standalone blocks, not inside lists/paragraphs
                while !listStack.isEmpty { closeListFrame() }
                flushParagraphBuffer()
                pushParagraph(ns)
            }
        }
    }

    private mutating func handleOpen(_ c: Container) {
        switch c {
        case .blockQuote:
            // Enter a new quote context
            quoteChildrenStack.append([])
        case .orderedList:
            listStack.append(ListFrame(type: .ordered, items: [], currentItem: []))
        case .unorderedList:
            listStack.append(ListFrame(type: .unordered, items: [], currentItem: []))
        case .listItem:
            if !listStack.isEmpty {
                // ensure we are ready to capture children into currentItem
                if !listStack[listStack.count - 1].currentItem.isEmpty {
                    // if somehow item has residuals, finalize it before starting
                    listStack[listStack.count - 1].items.append(listStack[listStack.count - 1].currentItem)
                    listStack[listStack.count - 1].currentItem = []
                }
            }
        case .paragraph:
            // Start a fresh paragraph buffer
            if paragraphBuffer.length > 0 { flushParagraphBuffer() }
        case .header(let level):
            if headerLevelActive != nil { flushHeaderBuffer() }
            headerLevelActive = level
        }
    }

    private mutating func handleClose(_ c: Container) {
        switch c {
        case .blockQuote:
            flushParagraphBuffer()
            flushQuote()
        case .orderedList, .unorderedList:
            closeListFrame()
        case .listItem:
            closeListItemIfNeeded()
        case .paragraph:
            flushParagraphBuffer()
        case .header:
            flushHeaderBuffer()
        }
    }

    private mutating func handleText(_ ns: NSAttributedString) {
        if let _ = headerLevelActive {
            headerBuffer.append(ns)
        } else {
            paragraphBuffer.append(ns)
        }
    }

    // MARK: - List helpers for event consumer
    private mutating func closeListItemIfNeeded() {
        flushParagraphBuffer()
        guard !listStack.isEmpty else { return }
        if !listStack[listStack.count - 1].currentItem.isEmpty {
            listStack[listStack.count - 1].items.append(listStack[listStack.count - 1].currentItem)
            listStack[listStack.count - 1].currentItem = []
        }
    }

    private mutating func closeListFrame() {
        flushParagraphBuffer()
        guard var frame = listStack.popLast() else { return }
        if !frame.currentItem.isEmpty { frame.items.append(frame.currentItem) }
        let listBlock = Block.list(type: frame.type, items: frame.items)
        if !listStack.isEmpty {
            listStack[listStack.count - 1].currentItem.append(listBlock)
        } else if !quoteChildrenStack.isEmpty {
            quoteChildrenStack[quoteChildrenStack.count - 1].append(listBlock)
        } else {
            blocks.append(listBlock)
        }
    }

    private func nsFromSlice(_ slice: AttributedString, fallbackFont: UIFont? = nil) -> NSAttributedString {
        var s = slice
        if let font = fallbackFont {
            var c = AttributeContainer()
            c[AttributeScopes.UIKitAttributes.FontAttribute.self] = font
            s.mergeAttributes(c)
        }
        return NSAttributedString(s)
    }

    private func applyBaseStyling(_ source: NSAttributedString, textColor: UIColor?, baseFont: UIFont) -> NSAttributedString {
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

    private func headerFont(for level: Int) -> UIFont {
        switch level {
        case 1: return .systemFont(ofSize: 22, weight: .bold)
        case 2: return .systemFont(ofSize: 20, weight: .semibold)
        case 3: return .systemFont(ofSize: 18, weight: .semibold)
        default: return .systemFont(ofSize: 16, weight: .semibold)
        }
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

