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
import AEPServices

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

    // Outer to inner container order
    enum Container: Equatable {
        case blockQuote
        case orderedList
        case unorderedList
        case listItem(ordinal: Int)
        case paragraph
        case header(level: Int)
        case codeBlock
        case thematicBreak
    }

    enum Event {
        case open(Container)
        case close(Container)
        case text(NSAttributedString)
        case divider
        case code(NSAttributedString)
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

    // MARK: Logging
    private let LOG_TAG = "MarkdownRenderer"

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
        // Phase 1: build parent block open/close events by diffing container stacks between a run and
        // its predecessor
        var events: [Event] = []
        var prevStack: [Container] = []
        var prevHadInlineStyling = false

        for run in attributed.runs {
            let runSlice = AttributedString(attributed[run.range])
            // Extract the concrete containers for the text based on the run's parse result
            let currentStack = containersFor(presentation: run.presentationIntent)
            let longestCommonIndex = longestCommonIndex(prevStack, currentStack)
            // Determine whether this run carries inline styling (bold/italic/code/link/etc.)
            let foundationScope = AttributeScopes.FoundationAttributes.self
            let uiKitScope = AttributeScopes.UIKitAttributes.self
            let hasInlineStyling = (run.inlinePresentationIntent != nil)
                || (run.attributes[foundationScope.LinkAttribute.self] != nil)
                || (run.attributes[uiKitScope.FontAttribute.self] != nil)
                || (run.attributes[uiKitScope.UnderlineStyleAttribute.self] != nil)

            if (prevStack.last == .paragraph
                && currentStack.last == .paragraph
                && !hasInlineStyling
                && !prevHadInlineStyling) {
                events.append(.close(.paragraph))
                events.append(.open(.paragraph))
            }

            if prevStack.count > longestCommonIndex {
                for idx in stride(from: prevStack.count - 1, through: longestCommonIndex, by: -1) {
                    events.append(.close(prevStack[idx]))
                }
            }
            if currentStack.count > longestCommonIndex {
                for idx in longestCommonIndex..<currentStack.count {
                    events.append(.open(currentStack[idx]))
                }
            }

            // Handle special leaf components based on innermost container
            switch currentStack.last {
            case .some(.codeBlock):
                let ns = NSAttributedString(runSlice)
                let mutable = NSMutableAttributedString(attributedString: ns)
                mutable.addAttribute(.font,
                                     value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                                     range: NSRange(location: 0, length: mutable.length))
                mutable.addAttribute(.backgroundColor,
                                     value: UIColor.secondarySystemBackground,
                                     range: NSRange(location: 0, length: mutable.length))
                events.append(.code(mutable))
            case .some(.thematicBreak):
                events.append(.divider)
            default:
                let ns = NSAttributedString(runSlice)
                if ns.length > 0 { events.append(.text(ns)) }
            }
            prevStack = currentStack
            prevHadInlineStyling = hasInlineStyling
        }

        // This unwinds the final run's common components
        for index in stride(from: prevStack.count - 1, through: 0, by: -1) {
            events.append(.close(prevStack[index]))
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

    // MARK: - Event production helpers

    /// Builds the outermost to innermost container stack for a markdown run.
    ///
    /// - Parameter presentation: The run's `PresentationIntent` (if any).
    /// - Returns: `containers` ordered outermost to innermost.
    ///
    /// PresentationIntent.components come innermost first from the parser. The reverse outermost to
    /// innermost order is used so container hierarchy aligns correctly.
    ///
    /// Using outermost -> innermost
    ///
    /// A = [.blockQuote, .unorderedList, .listItem(1), .orderedList, .listItem(1), .paragraph]
    ///
    /// B = [.blockQuote, .unorderedList, .listItem(2), .paragraph]
    ///
    /// Using innermost to outermost (default parser order, you get the wrong groupings)
    ///
    /// A = [.paragraph, .listItem(1), .orderedList, .listItem(1), .unorderedList, .blockQuote]
    ///
    /// B = [.paragraph, .listItem(2), .unorderedList, .blockQuote]
    private func containersFor(presentation: PresentationIntent?) -> [Container] {
        guard let presentation = presentation else {
            // If there is no presentation intent, default to a standard paragraph container
            return [.paragraph]
        }

        var containers: [Container] = []

        // Build container stack from outermost container to innermost by walking reversed components.
        // Note: `.header`, `.paragraph`, `.codeBlock`, and `.thematicBreak` are
        // mutually exclusive within a run and should always be the innermost block component (no early break needed).
        for comp in presentation.components.reversed() {
            switch comp.kind {
            case .header(let level):
                containers.append(.header(level: level))
            case .codeBlock:
                containers.append(.codeBlock)
            case .thematicBreak:
                containers.append(.thematicBreak)
            case .blockQuote:
                containers.append(.blockQuote)
            case .orderedList:
                containers.append(.orderedList)
            case .unorderedList:
                containers.append(.unorderedList)
            case .listItem(let ordinal):
                containers.append(.listItem(ordinal: ordinal))
            case .paragraph:
                containers.append(.paragraph)
            default:
                break
            }
        }

        return containers
    }

    /// Returns the length of the shared leading sequence between two container stacks.
    ///
    /// - Parameters:
    ///   - first: The first container stack, ordered outermost to innermost.
    ///   - second: The second container stack, ordered outermost to innermost.
    /// - Returns: The number of leading containers that are identical in both stacks.
    private func longestCommonIndex(_ lhs: [Container], _ rhs: [Container]) -> Int {
        let maxSharedCount = min(lhs.count, rhs.count)
        var currentIndex = 0
        while currentIndex < maxSharedCount && lhs[currentIndex] == rhs[currentIndex] {
            currentIndex += 1
        }
        return currentIndex
    }

    // MARK: - Event consumer
    private mutating func consume(events: [Event]) {
        for event in events {
            switch event {
            case .open(let container):
                handleOpen(container)
            case .close(let container):
                handleClose(container)
            case .text(let nsAttributedString):
                handleText(nsAttributedString)
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

    private mutating func handleOpen(_ container: Container) {
        switch container {
        case .blockQuote:
            // Enter a new quote context and ensure current paragraph text is flushed
            // so the quote starts on its own line within the owning container.
            quoteChildrenStack.append([])
        case .orderedList:
            listStack.append(ListFrame(type: .ordered, items: [], currentItem: []))
        case .unorderedList:
            listStack.append(ListFrame(type: .unordered, items: [], currentItem: []))
        case .listItem:
            guard !listStack.isEmpty else {
                Log.warning(label: self.LOG_TAG, "Encountered listItem without an active list; ignoring listItem open.")
                return
            }
            closeListItemIfNeeded()
        case .paragraph:
            // Start a fresh paragraph buffer
            if paragraphBuffer.length > 0 {
                flushParagraphBuffer()
            }
        case .header(let level):
            if headerLevelActive != nil {
                flushHeaderBuffer()
            }
            headerLevelActive = level
        case .codeBlock, .thematicBreak:
            break
        }
    }

    private mutating func handleClose(_ container: Container) {
        switch container {
        case .blockQuote:
            flushParagraphBuffer()
            flushQuote()
        case .orderedList, .unorderedList:
            closeListFrame()
        case .listItem:
            flushParagraphBuffer()
            closeListItemIfNeeded()
        case .paragraph:
            flushParagraphBuffer()
        case .header:
            flushHeaderBuffer()
        case .codeBlock, .thematicBreak:
            break
        }
    }

    private mutating func handleText(_ ns: NSAttributedString) {
        if let _ = headerLevelActive {
            headerBuffer.append(ns)
        } else {
            paragraphBuffer.append(ns)
        }
    }

    // MARK: - Block assembly helpers
    private mutating func appendBlock(_ block: Block) {
        // Attach content to the deepest structural container that semantically owns it.
        // For text inside list items (even when wrapped by a quote), we want the text to
        // belong to the list item so bullets/numbers render correctly. The quote receives
        // the finalized list block when the list closes.
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
        if !listStack.isEmpty {
            // If we're inside an inner quote (depth >= 2), route paragraph to the inner quote so
            // the quote has visible children; otherwise keep with the list item so bullets render.
            if quoteChildrenStack.count >= 2 {
                quoteChildrenStack[quoteChildrenStack.count - 1].append(.text(styled))
            } else {
                listStack[listStack.count - 1].currentItem.append(.text(styled))
            }
        } else if !quoteChildrenStack.isEmpty {
            // Quoted paragraph outside of any list
            quoteChildrenStack[quoteChildrenStack.count - 1].append(.text(styled))
        } else {
            blocks.append(.text(styled))
        }
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

    // MARK: - List helpers for event consumer
    private mutating func closeListItemIfNeeded() {
        guard !listStack.isEmpty else {
            Log.warning(label: self.LOG_TAG, "No active lists; ignoring closeListItemIfNeeded.")
            return
        }
        let mostRecentListFrame = listStack.count - 1
        if !listStack[mostRecentListFrame].currentItem.isEmpty {
            listStack[mostRecentListFrame].items.append(listStack[mostRecentListFrame].currentItem)
            listStack[mostRecentListFrame].currentItem = []
        }
    }

    private mutating func closeListFrame() {
        flushParagraphBuffer()
        guard var frame = listStack.popLast() else {
            Log.warning(label: self.LOG_TAG, "closeListFrame called but no active lists. Unable to close list frame.")
            return
        }
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

