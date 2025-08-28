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
        case code(NSAttributedString)
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

    // Unified node for building nested structures (Option B)
    private enum Node {
        case blockQuote(children: [Block])
        case list(type: ListType, items: [[Block]])
        case listItem(children: [Block])
        case paragraph(buffer: NSMutableAttributedString)
        case header(level: Int, buffer: NSMutableAttributedString)
        case codeBlock(buffer: NSMutableAttributedString)
    }

    // MARK: Inputs (immutable)
    private let attributed: AttributedString
    private let textColor: UIColor?
    private let baseFont: UIFont

    // MARK: Output
    private var blocks: [Block] = []

    // MARK: Container state (unified)
    private var nodeStack: [Node] = []

    // MARK: Logging
    private let LOG_TAG = "MarkdownRenderer"

#if DEBUG
    // MARK: - Debug tracing helpers
    private func trace(_ message: String) {
        print("[MarkdownRenderer] " + message)
    }
    private func describe(_ container: Container) -> String {
        switch container {
        case .blockQuote: return "blockQuote"
        case .orderedList: return "orderedList"
        case .unorderedList: return "unorderedList"
        case .listItem(let ord): return "listItem(ordinal: \(ord))"
        case .paragraph: return "paragraph"
        case .header(let level): return "header(\(level))"
        case .codeBlock: return "codeBlock"
        case .thematicBreak: return "thematicBreak"
        }
    }
    // container stack description no longer used; keep container describe only
#endif

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

            // Force a boundary between distinct code blocks when two successive runs
            // are both innermost codeBlock components. This prevents separate fenced
            // blocks from merging into one when their container stacks are identical.
            if (prevStack.last == .codeBlock
                && currentStack.last == .codeBlock) {
                events.append(.close(.codeBlock))
                events.append(.open(.codeBlock))
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
#if DEBUG
            trace("consume leaf for innermost=\(String(describing: currentStack.last.map { describe($0) }))")
#endif
            switch currentStack.last {
            case .some(.codeBlock):
                // Accumulate raw text for code; styling will be applied on code block close
                let ns = NSAttributedString(runSlice)
                if ns.length > 0 { events.append(.text(ns)) }
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

        // Safety: finalize any residual state
        finalizeAllOpenNodes()
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
                // HR is a block element: finalize inline and close lists first
                finalizeInlineNodes()
                closeListContainersIfAny()
                appendBlock(.divider)
            case .code(let ns):
                // Append code text into an active code block node if present.
                if case .codeBlock(let buffer) = nodeStack.last {
                    buffer.append(ns)
                    nodeStack[nodeStack.count - 1] = .codeBlock(buffer: buffer)
                } else {
                    // Fallback: treat as paragraph text with monospace styling
                    pushParagraph(ns)
                }
            }
        }
    }

    private mutating func handleOpen(_ container: Container) {
#if DEBUG
        trace("OPEN   \(describe(container)) stackDepth(before)=\(nodeStack.count)")
#endif
        switch container {
        case .blockQuote:
            nodeStack.append(.blockQuote(children: []))
        case .orderedList:
            nodeStack.append(.list(type: .ordered, items: []))
        case .unorderedList:
            nodeStack.append(.list(type: .unordered, items: []))
        case .listItem:
            nodeStack.append(.listItem(children: []))
        case .paragraph:
            nodeStack.append(.paragraph(buffer: NSMutableAttributedString()))
        case .header(let level):
            nodeStack.append(.header(level: level, buffer: NSMutableAttributedString()))
        case .codeBlock:
            nodeStack.append(.codeBlock(buffer: NSMutableAttributedString()))
        case .thematicBreak:
            break
        }
    }

    private mutating func handleClose(_ container: Container) {
#if DEBUG
        trace("CLOSE  \(describe(container)) stackDepth(before)=\(nodeStack.count)")
#endif
        switch container {
        case .blockQuote:
            popBlockQuote()
        case .orderedList, .unorderedList:
            popList()
        case .listItem:
            popListItem()
        case .paragraph:
            popParagraphToBlock()
        case .header:
            popHeaderToBlock()
        case .codeBlock:
            popCodeBlockToBlock()
        case .thematicBreak:
            break
        }
    }

    private mutating func handleText(_ ns: NSAttributedString) {
        guard let top = nodeStack.last else { return }
        switch top {
        case .paragraph(let buffer):
            buffer.append(ns)
            nodeStack[nodeStack.count - 1] = .paragraph(buffer: buffer)
        case .header(let level, let buffer):
            buffer.append(ns)
            nodeStack[nodeStack.count - 1] = .header(level: level, buffer: buffer)
        case .codeBlock(let buffer):
            buffer.append(ns)
            nodeStack[nodeStack.count - 1] = .codeBlock(buffer: buffer)
        default:
            break
        }
    }

    // MARK: - Block assembly helpers
    private mutating func appendBlock(_ block: Block) {
        // Route to the most recent structural container (listItem or blockQuote)
        if let idx = nodeStack.lastIndex(where: { node in
            switch node {
            case .listItem, .blockQuote: return true
            default: return false
            }
        }) {
            switch nodeStack[idx] {
            case .listItem(let children):
                var newChildren = children
                newChildren.append(block)
                nodeStack[idx] = .listItem(children: newChildren)
            case .blockQuote(let children):
                var newChildren = children
                newChildren.append(block)
                nodeStack[idx] = .blockQuote(children: newChildren)
            default:
                blocks.append(block)
            }
        } else {
            blocks.append(block)
        }
    }

    private mutating func pushParagraph(_ ns: NSAttributedString) {
        let styled = applyBaseStyling(ns, textColor: textColor, baseFont: baseFont)
        appendBlock(.text(styled))
    }

    // MARK: - Node finalizers
    private mutating func popParagraphToBlock() {
        guard let top = nodeStack.last else { return }
        if case .paragraph(let buffer) = top {
            nodeStack.removeLast()
            if buffer.length > 0 {
                pushParagraph(buffer)
            }
        }
    }

    private mutating func popHeaderToBlock() {
        guard let top = nodeStack.last else { return }
        if case .header(let level, let buffer) = top {
            nodeStack.removeLast()
            if buffer.length > 0 {
                let r = NSRange(location: 0, length: buffer.length)
                buffer.addAttribute(.font, value: headerFont(for: level), range: r)
                buffer.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: r)
                pushParagraph(buffer)
            }
        }
    }

    private mutating func popCodeBlockToBlock() {
        guard let top = nodeStack.last else { return }
        if case .codeBlock(let buffer) = top {
            nodeStack.removeLast()
            if buffer.length > 0 {
                // Apply monospace font to the entire code buffer once. Background color
                // will be provided by the SwiftUI view for full-width styling.
                // Trim trailing newlines added by the parser so we don't render an
                // extra blank line at the bottom of the code block.
                var length = buffer.length
                while length > 0 {
                    let lastRange = NSRange(location: length - 1, length: 1)
                    let last = buffer.attributedSubstring(from: lastRange).string
                    if last == "\n" || last == "\r" { buffer.deleteCharacters(in: lastRange); length -= 1 } else { break }
                }
                
                let r = NSRange(location: 0, length: buffer.length)
                buffer.addAttribute(.font,
                                     value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                                     range: r)
                appendBlock(.code(buffer))
            }
        }
    }

    private mutating func popBlockQuote() {
        guard let top = nodeStack.last else { return }
        if case .blockQuote(let children) = top {
            nodeStack.removeLast()
            appendBlock(.blockQuote(children))
        }
    }

    private mutating func popListItem() {
        guard let top = nodeStack.last else { return }
        if case .listItem(let children) = top {
            nodeStack.removeLast()
            if let listIndex = nodeStack.lastIndex(where: { node in
                if case .list = node { return true } else { return false }
            }) {
                switch nodeStack[listIndex] {
                case .list(let type, let items):
                    var newItems = items
                    newItems.append(children)
                    nodeStack[listIndex] = .list(type: type, items: newItems)
                default:
                    break
                }
            } else {
                // No parent list found; degrade gracefully by appending children directly
                for child in children { appendBlock(child) }
                Log.warning(label: self.LOG_TAG, "listItem closed without a parent list; appended its children directly.")
            }
        }
    }

    private mutating func popList() {
        guard let top = nodeStack.last else { return }
        if case .list(let type, let items) = top {
            nodeStack.removeLast()
            let listBlock = Block.list(type: type, items: items)
            appendBlock(listBlock)
        }
    }

    private mutating func finalizeInlineNodes() {
        // Pop and emit paragraph/header nodes sitting on top
        var keepLooping = true
        while keepLooping, let top = nodeStack.last {
            switch top {
            case .paragraph:
                popParagraphToBlock()
            case .header:
                popHeaderToBlock()
            case .codeBlock:
                popCodeBlockToBlock()
            default:
                keepLooping = false
            }
        }
    }

    private mutating func closeListContainersIfAny() {
        // Close any open listItem/list pairs on the top of the stack
        var didClose = true
        while didClose, let top = nodeStack.last {
            didClose = false
            switch top {
            case .listItem:
                popListItem()
                didClose = true
            case .list:
                popList()
                didClose = true
            default:
                break
            }
        }
    }

    private mutating func finalizeAllOpenNodes() {
        // Close everything in LIFO order
        while let top = nodeStack.last {
            switch top {
            case .paragraph:
                popParagraphToBlock()
            case .header:
                popHeaderToBlock()
            case .listItem:
                popListItem()
            case .list:
                popList()
            case .blockQuote:
                popBlockQuote()
            case .codeBlock:
                popCodeBlockToBlock()
            }
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

