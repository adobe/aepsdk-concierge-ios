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

// MARK: - UIKit bridge for block-aware Markdown rendering
/// A UIViewRepresentable that renders Markdown with full block parsing via
/// NSAttributedString(markdown:), so lists/quotes/code blocks are laid out correctly.
/// Tables are parsed but not laid out as grids by TextKit (custom rendering needed).
struct UIKitMarkdownText: UIViewRepresentable {
    let markdown: String
    var textColor: UIColor? = nil
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)
    /// Pass container width from SwiftUI (e.g., GeometryReader) for correct wrapping.
    var maxWidth: CGFloat? = nil

    final class AutoSizingTextView: UITextView {
        var targetWidth: CGFloat = 0 { didSet { if oldValue != targetWidth { invalidateIntrinsicContentSize() } } }
        override var intrinsicContentSize: CGSize {
            let width = targetWidth > 0 ? targetWidth : bounds.width
            let size = sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: width, height: ceil(size.height))
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            if targetWidth <= 0 && bounds.width > 0 { targetWidth = bounds.width }
        }
    }

    func makeUIView(context: Context) -> AutoSizingTextView {
        let tv = AutoSizingTextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = false
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        let styled = buildBlockAwareAttributedString(markdown: markdown)
        uiView.attributedText = styled

        if let w = maxWidth, w > 0 {
            uiView.targetWidth = w
            uiView.textContainer.size = CGSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    private func applyBaseStyling(to source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let range = NSRange(location: 0, length: mutable.length)

        if let color = textColor {
            mutable.addAttribute(.foregroundColor, value: color, range: range)
        }

        // Ensure body text matches desired baseFont where no explicit font is provided.
        mutable.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? UIFont else {
                mutable.addAttribute(.font, value: baseFont, range: subrange)
                return
            }
            // Keep monospace/heading fonts; normalize plain body-ish runs to baseFont size.
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

    // MARK: - Block-aware builder
    private func buildBlockAwareAttributedString(markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown, attributes: [.font: baseFont, .foregroundColor: textColor ?? UIColor.label])
        }

        let out = NSMutableAttributedString()
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor ?? UIColor.label
        ]

        // Helpers to append with explicit paragraph separation (U+2029)
        func appendParagraph(_ ns: NSAttributedString) {
            let paragraphSeparator = "\u{2029}"
            if out.length > 0, !out.string.hasSuffix(paragraphSeparator) {
                out.append(NSAttributedString(string: paragraphSeparator))
            }
            out.append(ns)
            out.append(NSAttributedString(string: paragraphSeparator))
        }

        func nsFromSlice(_ slice: AttributedString, fallbackFont: UIFont? = nil) -> NSAttributedString {
            var s = slice
            if let font = fallbackFont {
                var c = AttributeContainer()
                c[AttributeScopes.UIKitAttributes.FontAttribute.self] = font
                s.mergeAttributes(c)
            }
            return NSAttributedString(s)
        }

        // List accumulation state
        enum ListType { case ordered, unordered }
        var pendingListDepth: Int? = nil
        var pendingListType: ListType? = nil
        var pendingListOrdinal: Int? = nil
        struct ListSignature: Equatable { struct Component: Equatable { let type: ListType; let ordinal: Int }; let components: [Component] }
        var pendingListSignature: ListSignature? = nil
        var pendingListContent = NSMutableAttributedString()

        func flushPendingList() {
            guard let depth = pendingListDepth, let type = pendingListType else { return }
            // Build a line for the item
            let indentPerLevel: CGFloat = 20
            let indentSpaces = String(repeating: " ", count: Int(CGFloat(depth - 1) * indentPerLevel / 4))
            let bullet: String
            if type == .ordered, let ord = pendingListOrdinal {
                bullet = "\(ord)."
            } else { bullet = "•" }

            let prefix = "\(indentSpaces)\(bullet) "
            let line = NSMutableAttributedString(string: prefix, attributes: bodyAttrs)
            line.append(pendingListContent)
            // Apply paragraph style for wrap indent
            let ps = NSMutableParagraphStyle()
            let tabLoc = (prefix as NSString).size(withAttributes: [.font: baseFont]).width
            ps.tabStops = [NSTextTab(textAlignment: .left, location: tabLoc, options: [:])]
            ps.firstLineHeadIndent = 0
            ps.headIndent = tabLoc
            ps.lineBreakMode = .byWordWrapping
            line.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: line.length))
            appendParagraph(line)

            // reset
            pendingListDepth = nil
            pendingListType = nil
            pendingListOrdinal = nil
            pendingListContent = NSMutableAttributedString()
        }

        // Accumulate normal paragraph text
        var pendingParagraph = NSMutableAttributedString()
        func flushPendingParagraph() {
            if pendingParagraph.length > 0 {
                appendParagraph(pendingParagraph)
                pendingParagraph = NSMutableAttributedString()
            }
        }

        // Header accumulation state to avoid splitting header content across runs
        var headerBuffer = NSMutableAttributedString()
        var headerLevelActive: Int? = nil

        func flushHeaderBuffer() {
            guard let level = headerLevelActive, headerBuffer.length > 0 else { return }
            let font: UIFont
            switch level {
            case 1: font = .systemFont(ofSize: 22, weight: .bold)
            case 2: font = .systemFont(ofSize: 20, weight: .semibold)
            case 3: font = .systemFont(ofSize: 18, weight: .semibold)
            default: font = .systemFont(ofSize: 16, weight: .semibold)
            }
            let range = NSRange(location: 0, length: headerBuffer.length)
            headerBuffer.addAttribute(.font, value: font, range: range)
            headerBuffer.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: range)
            appendParagraph(headerBuffer)
            headerBuffer = NSMutableAttributedString()
            headerLevelActive = nil
        }

        for run in attributed.runs {
            let sliceAS = AttributedString(attributed[run.range])
            // Classification
            var headerLevel: Int? = nil
            var isCodeBlock = false
            var isBlockQuote = false
            var isThematic = false
            var depth = 0
            var listType: ListType? = nil
            var ordinal: Int? = nil
            var pairs: [(ListType, Int)] = []
            var pendingOrdinalTemp: Int? = nil

            if let pres = run.presentationIntent {
                for comp in pres.components {
                    switch comp.kind {
                    case .header(let level): headerLevel = level
                    case .codeBlock: isCodeBlock = true
                    case .blockQuote: isBlockQuote = true
                    case .thematicBreak: isThematic = true
                    case .listItem(let ord):
                        depth += 1
                        ordinal = ord
                        pendingOrdinalTemp = ord
                    case .orderedList:
                        listType = .ordered
                        if let o = pendingOrdinalTemp { pairs.append((.ordered, o)); pendingOrdinalTemp = nil }
                    case .unorderedList:
                        listType = .unordered
                        if let o = pendingOrdinalTemp { pairs.append((.unordered, o)); pendingOrdinalTemp = nil }
                    default: break
                    }
                }
            }

            let signature: ListSignature? = pairs.isEmpty ? nil : ListSignature(components: pairs.map { ListSignature.Component(type: $0.0, ordinal: $0.1) })

            if let level = headerLevel {
                flushPendingList(); flushPendingParagraph()
                if headerLevelActive == nil { headerLevelActive = level }
                // If header level changed mid-stream, flush the previous header
                if let active = headerLevelActive, active != level {
                    flushHeaderBuffer()
                    headerLevelActive = level
                }
                headerBuffer.append(nsFromSlice(sliceAS))
                continue
            } else if headerLevelActive != nil {
                // Header block ended; flush it before proceeding
                flushHeaderBuffer()
            }

            if isThematic {
                flushPendingList(); flushPendingParagraph()
                let rule = NSAttributedString(string: "\n\u{2014}\u{2014}\u{2014}\u{2014}\u{2014}\n", attributes: bodyAttrs)
                appendParagraph(rule)
                continue
            }

            if isCodeBlock {
                flushPendingList(); flushPendingParagraph()
                let ns = nsFromSlice(sliceAS)
                let m = NSMutableAttributedString(attributedString: ns)
                m.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: 0, length: m.length))
                m.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: m.length))
                appendParagraph(m)
                continue
            }

            if isBlockQuote {
                flushPendingList(); flushPendingParagraph()
                let marker = NSAttributedString(string: "▎ ", attributes: [.foregroundColor: UIColor.tertiaryLabel, .font: baseFont])
                let ns = nsFromSlice(sliceAS)
                let m = NSMutableAttributedString(attributedString: marker)
                m.append(ns)
                // Indent quoted text
                let ps = NSMutableParagraphStyle()
                ps.headIndent = 16
                ps.firstLineHeadIndent = 0
                ps.lineBreakMode = .byWordWrapping
                m.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: m.length))
                appendParagraph(m)
                continue
            }

            if depth > 0, let type = listType {
                // If we were accumulating a paragraph before the list, flush it so ordering stays correct
                flushPendingParagraph()
                // list item content
                let ns = nsFromSlice(sliceAS)
                if pendingListDepth == nil || pendingListDepth != depth || pendingListType == nil || (pendingListType! != type) || pendingListOrdinal != ordinal || pendingListSignature != signature {
                    // flush previous item
                    flushPendingList()
                    pendingListDepth = depth
                    pendingListType = type
                    pendingListOrdinal = ordinal
                    pendingListSignature = signature
                }
                pendingListContent.append(ns)
                continue
            }

            // Paragraph text
            let ns = nsFromSlice(sliceAS)
            if pendingParagraph.length > 0 { pendingParagraph.append(NSAttributedString(string: " ")) }
            pendingParagraph.append(ns)
        }

        // Flush any remaining
        flushPendingList(); flushPendingParagraph()

        return applyBaseStyling(to: out)
    }
}
