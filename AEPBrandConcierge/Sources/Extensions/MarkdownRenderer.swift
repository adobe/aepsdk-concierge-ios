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
    /// Describes the list marker style used when rendering lists.
    enum ListType {
        /// A numbered list (ex: 1., 2., 3.).
        case ordered
        /// A bulleted list (ex: •).
        case unordered
    }

    /// The final render model produced by `MarkdownRenderer` and consumed by the view layer.
    /// Each case corresponds to a block level unit that can be laid out vertically.
    enum MarkdownBlock: Equatable {
        /// A paragraph or header represented as attributed text ready for display.
        case text(NSAttributedString)
        /// A thematic break (divider).
        case divider
        /// A list block with its marker `type` and per-item child blocks.
        case list(type: ListType, items: [[MarkdownBlock]])
        /// A block quote containing nested blocks.
        case blockQuote([MarkdownBlock])
        /// A code block rendered as monospaced attributed text.
        case code(NSAttributedString)
    }

    /// Structural containers derived from `AttributedString.PresentationIntent` for a run.
    /// The array of components is ordered from **outermost to innermost** (root to leaf).
    private enum PresentationComponent: Equatable {
        /// Quote container (>) around content.
        case blockQuote
        /// Numbered list container.
        case orderedList
        /// Bulleted list container.
        case unorderedList
        /// A single list item within the nearest list, carrying its 1-based ordinal.
        case listItem(ordinal: Int)
        /// A paragraph container.
        case paragraph
        /// A header container with the given level (1-6).
        case header(level: Int)
        /// A fenced code block container.
        case codeBlock
        /// A thematic break (divider).
        case thematicBreak
    }

    /// A linear stream of events produced while scanning runs, later consumed to
    /// construct the `MarkdownBlock` hierarchy.
    ///
    /// An anaology is to think of these as open and close parentheses for the nested markdown content.
    private enum BuildEvent {
        /// Opens the given structural container.
        case open(PresentationComponent)
        /// Closes the given structural container.
        case close(PresentationComponent)
        /// Emits inline text discovered in the current run.
        case text(NSAttributedString)
        /// Emits a thematic break.
        case divider
        /// Emits raw text that belongs to a code block (coalesced at close).
        case code(NSAttributedString)
    }

    /// Internal stack node used while assembling `MarkdownBlock`s.
    private enum BuildNode {
        /// Quote node accumulating nested blocks.
        case blockQuote(children: [MarkdownBlock])
        /// List node accumulating per-item child blocks.
        case list(type: ListType, items: [[MarkdownBlock]])
        /// A single list item accumulating its blocks.
        case listItem(children: [MarkdownBlock])
        /// Paragraph node buffering attributed text.
        case paragraph(buffer: NSMutableAttributedString)
        /// Header node buffering attributed text at a specific level.
        case header(level: Int, buffer: NSMutableAttributedString)
        /// Code block node buffering raw attributed text for later styling.
        case codeBlock(buffer: NSMutableAttributedString)
    }

    // MARK: Logging
    private let LOG_TAG = "MarkdownRenderer"

    // MARK: Inputs
    /// The parsed markdown as `AttributedString` runs. This is the single source of truth
    /// for both structural containers (`presentationIntent`) and inline attributes.
    private let attributed: AttributedString
    /// Optional foreground color applied as a base to emitted text unless an inline color overrides it.
    private let textColor: UIColor?
    /// Base font used for paragraphs; headers and code derive from this for sizing/mono.
    private let baseFont: UIFont

    // MARK: Build state
    /// LIFO stack of transient build nodes representing the currently open containers
    /// (ex: quote, list, listItem, paragraph, header, codeBlock).
    private var nodeStack: [BuildNode] = []

    // MARK: Output
    /// Final render tree built from the input runs. Consumed by SwiftUI views for display.
    private var blocks: [MarkdownBlock] = []

    // MARK: - Public API
    static func buildBlocks(
        markdown: String,
        textColor: UIColor? = nil,
        baseFont: UIFont = .preferredFont(forTextStyle: .body)
    ) -> [MarkdownRenderer.MarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else { return [] }
        var builder = MarkdownRenderer(attributed: attributed, textColor: textColor, baseFont: baseFont)
        return builder.build()
    }

    private mutating func build() -> [MarkdownBlock] {
        // Phase 1: build parent block open/close events by diffing container stacks between a run and
        // its predecessor
        var events: [BuildEvent] = []
        var prevStack: [PresentationComponent] = []
        var prevHadInlineStyling = false

        for run in attributed.runs {
            let runSlice = AttributedString(attributed[run.range])
            // Extract the concrete containers for the text based on the run's parse result
            let currentStack = containersFor(presentation: run.presentationIntent)
            let longestCommonIndex = commonPrefixLength(prevStack, currentStack)
            // Determine whether this run carries inline styling (bold/italic/code/link/etc.)
            let hasInlineStyling = runHasInlineStyling(run)

            // Only when container hierarchies are identical, create block breaks for certain types
            if longestCommonIndex == currentStack.count && prevStack.count == currentStack.count {
                // Create a new paragraph boundary when the split isn't caused by inline styling.
                if (prevStack.last == .paragraph
                    && currentStack.last == .paragraph
                    && !hasInlineStyling
                    && !prevHadInlineStyling) {
                    events.append(.close(.paragraph))
                    events.append(.open(.paragraph))
                }

                // Create a new code block boundary
                if (prevStack.last == .codeBlock && currentStack.last == .codeBlock) {
                    events.append(.close(.codeBlock))
                    events.append(.open(.codeBlock))
                }
            }
            // This closes the previous stacks components which are different from the curent one
            // from innermost to outermost (leaf to root)
            if prevStack.count > longestCommonIndex {
                for idx in stride(from: prevStack.count - 1, through: longestCommonIndex, by: -1) {
                    events.append(.close(prevStack[idx]))
                }
            }
            // This opens the current stack from outermost to innermost (root to leaf)
            if currentStack.count > longestCommonIndex {
                for idx in longestCommonIndex..<currentStack.count {
                    events.append(.open(currentStack[idx]))
                }
            }

            // Handle special leaf components based on innermost container
            #if DEBUG
            Log.trace(label: LOG_TAG, "consume leaf for innermost=\(String(describing: currentStack.last.map { describe($0) }))")
            #endif
            if case .some(.thematicBreak) = currentStack.last {
                events.append(.divider)
            } else {
                // For code blocks and all other content, accumulate raw text here
                // Styling and block assembly happen in the consumer
                let ns = NSAttributedString(runSlice)
                if ns.length > 0 { events.append(.text(ns)) }
            }

            // Once run processing is complete, set up properties for the next run
            prevStack = currentStack
            prevHadInlineStyling = hasInlineStyling
        }

        // This closes the final run's common components
        // (last current run is assigned to prevStack at the end of the for loop logic)
        for index in stride(from: prevStack.count - 1, through: 0, by: -1) {
            events.append(.close(prevStack[index]))
        }

        // Phase 2: Evaluate the events which have been constructed using the markdown hierarchy
        consume(events: events)

        // Safety: finalize any residual state
        finalizeAllOpenNodes()
        return blocks
    }

    // MARK: - Event production helpers

    /// Returns the structural container stack for a single markdown run, ordered
    /// from outermost to innermost (root to leaf).
    ///
    /// Note that `AttributedString.PresentationIntent.components` are delivered
    /// innermost first by the parser. They are reversed so the event producer can diff
    /// previous vs current stacks and emit open/close events that align with the
    /// node based build stack (open from root to leaf, close from leaf to root).
    ///
    /// Examples (outermost to innermost):
    /// - [.blockQuote, .unorderedList, .listItem(1), .paragraph]
    /// - [.blockQuote, .unorderedList, .listItem(2), .paragraph]
    ///
    /// - Parameter presentation: The run's `PresentationIntent` (if any).
    /// - Returns: An array of `PresentationComponent` ordered outermost to innermost.
    private func containersFor(presentation: PresentationIntent?) -> [PresentationComponent] {
        guard let presentation = presentation else {
            // If there is no presentation intent, default to a standard paragraph container
            return [.paragraph]
        }

        var containers: [PresentationComponent] = []

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
    ///   - lhs: The first container stack, ordered outermost to innermost.
    ///   - rhs: The second container stack, ordered outermost to innermost.
    /// - Returns: The number of leading containers that are identical in both stacks.
    private func commonPrefixLength(_ lhs: [PresentationComponent], _ rhs: [PresentationComponent]) -> Int {
        let maxSharedCount = min(lhs.count, rhs.count)
        var currentIndex = 0
        while currentIndex < maxSharedCount && lhs[currentIndex] == rhs[currentIndex] {
            currentIndex += 1
        }
        return currentIndex
    }

    // MARK: - Event processing
    /// Consumes a linear collection of `BuildEvent`s and incrementally assembles the
    /// `MarkdownBlock` tree using a node based stack.
    ///
    /// Inline nodes (`paragraph`, `header`, `codeBlock`) are finalized before emitting
    /// block level elements that must stand alone (ex: `divider`).
    ///
    /// Structural containers (`list`, `listItem`, `quote`) route emitted blocks to their
    /// own child collections, Otherwise blocks are appended at the top level.
    ///
    /// - Parameter events: Ordered stream of build events produced from markdown runs.
    private mutating func consume(events: [BuildEvent]) {
        for event in events {
            switch event {
            case .open(let container):
                handleOpen(container)
            case .close(let container):
                handleClose(container)
            case .text(let ns):
                handleText(ns)
            // Finalizes any open inline nodes, then appends a `.divider` block.
            case .divider:
                finalizeInlineNodes()
                closeListContainersIfAny()
                appendBlock(.divider)
            // If a `codeBlock` node is active, appends to its buffer.
            // Otherwise, falls back to emitting styled paragraph text.
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

    /// Opens a structural container by pushing the corresponding `BuildNode` onto
    /// the node stack. For inline containers, a new mutable buffer is created.
    ///
    /// - Parameter container: The structural component to open.
    private mutating func handleOpen(_ container: PresentationComponent) {
        #if DEBUG
        Log.trace(label: LOG_TAG, "OPEN   \(describe(container)) stackDepth(before)=\(nodeStack.count)")
        #endif
        switch container {
        // Pushes an empty quote node.
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
        // No node is opened; handled elsewhere as a divider event.
        case .thematicBreak:
            break
        }
    }

    /// Closes a structural container by popping the corresponding `BuildNode` from
    /// the node stack and emitting a finalized `MarkdownBlock` into the appropriate
    /// parent (or the root).
    ///
    /// - Parameter container: The structural component to close.
    private mutating func handleClose(_ container: PresentationComponent) {
        #if DEBUG
        Log.trace(label: LOG_TAG, "CLOSE  \(describe(container)) stackDepth(before)=\(nodeStack.count)")
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
        // No node is closed; handled elsewhere as a divider event.
        case .thematicBreak:
            break
        }
    }

    /// Appends attributed text from the current run to the active inline node on the
    /// top of the stack. Only `paragraph`, `header`, and `codeBlock` nodes accept
    /// inline text. Other node types ignore text events.
    ///
    /// - Parameter ns: The attributed string produced for the run.
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
    /// Appends a finalized `MarkdownBlock` to the correct destination based on the
    /// current open structural containers.
    ///
    /// Routing rules:
    /// - If a `listItem` or `blockQuote` is currently open, the block is appended to
    ///   that node’s children (preferring the most recently opened node).
    /// - Otherwise, the block is appended at the root level of the render tree.
    ///
    /// - Parameter block: Finalized block to append.
    private mutating func appendBlock(_ block: MarkdownBlock) {
        // Find the most recent structural container (listItem or blockQuote)
        if let index = nodeStack.lastIndex(where: { node in
            switch node {
            case .listItem, .blockQuote:
                return true
            default:
                return false
            }
        }) {
            switch nodeStack[index] {
            case .listItem(let children):
                var newChildren = children
                newChildren.append(block)
                nodeStack[index] = .listItem(children: newChildren)
            case .blockQuote(let children):
                var newChildren = children
                newChildren.append(block)
                nodeStack[index] = .blockQuote(children: newChildren)
            default:
                blocks.append(block)
            }
        } else {
            blocks.append(block)
        }
    }

    /// Applies base text styling to the given attributed substring and appends it as a `.text`
    /// block, routing through `appendBlock(_:)` to attach to the correct parent component.
    ///
    /// - Parameter ns: The attributed text to style and emit as a paragraph block.
    private mutating func pushParagraph(_ ns: NSAttributedString) {
        let styled = applyBaseStyling(ns, textColor: textColor, baseFont: baseFont)
        appendBlock(.text(styled))
    }

    // MARK: - Node finalizers
    /// Pops the top `paragraph` node from the stack and emits it as a `.text` block
    /// if the buffered content is not empty.
    ///
    /// Uses `pushParagraph(_:)` to apply base styling and route to the correct structural parent.
    /// Does nothing if the top node is not a `paragraph`.
    private mutating func popParagraphToBlock() {
        guard let top = nodeStack.last else { return }
        if case .paragraph(let buffer) = top {
            nodeStack.removeLast()
            if buffer.length > 0 {
                pushParagraph(buffer)
            }
        }
    }

    /// Pops the top `header` node from the stack and emits it as a styled `.text` block
    /// if the buffered content is not empty.
    ///
    /// Applies the appropriate header font for `level` and the base foreground color
    /// before routing through `pushParagraph(_:)` to the correct structural parent.
    /// Does nothing if the top node is not a `header`.
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

    /// Pops the top `codeBlock` node and emits it as a `.code` block if the buffer
    /// has content.
    ///
    /// Trailing newlines inserted by the parser are removed to avoid
    /// rendering an extra blank line. Applies a monospaced font to the entire
    /// buffer. The background styling is provided by the SwiftUI layer.
    ///
    /// Does nothing if the top node is not a `codeBlock`.
    private mutating func popCodeBlockToBlock() {
        guard let top = nodeStack.last else { return }
        if case .codeBlock(let buffer) = top {
            nodeStack.removeLast()
            if buffer.length > 0 {
                var length = buffer.length
                while length > 0 {
                    let lastRange = NSRange(location: length - 1, length: 1)
                    let last = buffer.attributedSubstring(from: lastRange).string
                    if last == "\n" || last == "\r" {
                        buffer.deleteCharacters(in: lastRange); length -= 1
                    } else {
                        break
                    }
                }
                
                let r = NSRange(location: 0, length: buffer.length)
                buffer.addAttribute(.font,
                                     value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                                     range: r)
                appendBlock(.code(buffer))
            }
        }
    }

    /// Pops the top `blockQuote` node and emits a `.blockQuote` block containing
    /// the accumulated child blocks.
    ///
    /// Does nothing if the top node is not a quote.
    private mutating func popBlockQuote() {
        guard let top = nodeStack.last else { return }
        if case .blockQuote(let children) = top {
            nodeStack.removeLast()
            appendBlock(.blockQuote(children))
        }
    }

    /// Pops the top `listItem` node and attaches its accumulated child blocks to
    /// the nearest open `list` node as a new item.
    ///
    /// If no parent list is found, its children are appended directly to the output as a fallback.
    private mutating func popListItem() {
        guard let top = nodeStack.last else { return }
        if case .listItem(let children) = top {
            nodeStack.removeLast()
            if let listIndex = nodeStack.lastIndex(where: { node in
                if case .list = node {
                    return true
                } else {
                    return false
                }
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

    /// Pops the top `list` node and emits a `.list(type:items:)` block built from
    /// the accumulated list items. The block is routed via `appendBlock(_:)` to the
    /// nearest structural parent (ex: quote block or outer list) or the root.
    private mutating func popList() {
        guard let top = nodeStack.last else { return }
        if case .list(let type, let items) = top {
            nodeStack.removeLast()
            let listBlock = MarkdownBlock.list(type: type, items: items)
            appendBlock(listBlock)
        }
    }

    /// Finalizes any inline nodes sitting at the top of the stack by repeatedly
    /// popping `paragraph`, `header`, and `codeBlock` nodes and emitting their
    /// corresponding blocks. Stops once the top is a structural container
    /// (`list`, `listItem`, `blockQuote`) or the stack is empty.
    ///
    /// This is used before emitting standalone block level elements (ex: divider) or when
    /// transitioning between containers.
    private mutating func finalizeInlineNodes() {
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

    /// Iteratively closes any open list related containers (in priority of `listItem` then `list`)
    /// sitting on top of the stack. Used to make sure list structures are finalized
    /// before emitting standalone block level elements or when leaving a list context.
    private mutating func closeListContainersIfAny() {
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

    /// Drains the node stack by finalizing and emitting all remaining nodes in
    /// last-in-first-out (LIFO) order (leaf to root).
    private mutating func finalizeAllOpenNodes() {
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

    /// Applies default foreground color and normalizes fonts to the provided base font
    /// size for non-monospace, non-bold runs. Monospaced and bold fonts are preserved
    /// (ex: inline code and strong emphasis).
    ///
    /// - Parameters:
    ///   - source: The input attributed string to style.
    ///   - textColor: Optional base foreground color to apply across the string.
    ///   - baseFont: The default font to use for body text and to normalize sizes.
    /// - Returns: A styled `NSAttributedString` with normalized fonts and color.
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

    /// Returns the system font to use for a header at the specified level.
    ///
    /// Levels map to sizes/weights:
    /// - 1: 22pt, bold
    /// - 2: 20pt, semibold
    /// - 3: 18pt, semibold
    /// - default (4-6): 16pt, semibold
    ///
    /// - Parameter level: The markdown header level (1-6).
    /// - Returns: A `UIFont` appropriate for the given header level.
    private func headerFont(for level: Int) -> UIFont {
        switch level {
        case 1: return .systemFont(ofSize: 22, weight: .bold)
        case 2: return .systemFont(ofSize: 20, weight: .semibold)
        case 3: return .systemFont(ofSize: 18, weight: .semibold)
        default: return .systemFont(ofSize: 16, weight: .semibold)
        }
    }

    /// Returns true if the run has any inline styling indicators:
    /// - Bold
    /// - Italic
    /// - Inline code
    /// - Link
    /// - Underline or
    /// - Font override
    ///
    /// Used to avoid splitting paragraphs due to inline styling changes.
    private func runHasInlineStyling(_ run: AttributedString.Runs.Run) -> Bool {
        if run.inlinePresentationIntent != nil { return true }
        if run.attributes[AttributeScopes.FoundationAttributes.LinkAttribute.self] != nil { return true }
        if run.attributes[AttributeScopes.UIKitAttributes.FontAttribute.self] != nil { return true }
        if run.attributes[AttributeScopes.UIKitAttributes.UnderlineStyleAttribute.self] != nil { return true }
        return false
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

    /// Returns a debug string describing the given `PresentationComponent` and its values.
    private func describe(_ container: PresentationComponent) -> String {
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
}
#endif
