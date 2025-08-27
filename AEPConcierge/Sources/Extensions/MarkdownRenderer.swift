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

/// Markdown renderer utilities: parse markdown and produce structured blocks
/// that can be rendered by SwiftUI components.
enum MarkdownRenderer {
    // MARK: - Block model for interleaving SwiftUI views
    enum Block: Equatable {
        case text(NSAttributedString)
        case divider
        case blockQuote([NSAttributedString])
    }

    /// Build blocks (text, divider, blockQuote) directly from PresentationIntent
    /// without relying on sentinel characters.
    static func buildBlocks(markdown: String, textColor: UIColor? = nil, baseFont: UIFont = .preferredFont(forTextStyle: .body)) -> [Block] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let attributed = try? AttributedString(markdown: markdown, options: options) else { return [] }

        var blocks: [Block] = []

        func nsFromSlice(_ slice: AttributedString, fallbackFont: UIFont? = nil) -> NSAttributedString {
            var s = slice
            if let font = fallbackFont {
                var c = AttributeContainer()
                c[AttributeScopes.UIKitAttributes.FontAttribute.self] = font
                s.mergeAttributes(c)
            }
            return NSAttributedString(s)
        }

        // Helpers to append a paragraph as a text block
        func pushParagraph(_ ns: NSAttributedString) {
            let styled = applyBaseStyling(ns, textColor: textColor, baseFont: baseFont)
            blocks.append(.text(styled))
        }

        // List accumulation (same approach as attributed builder)
        enum ListType { case ordered, unordered }
        var pendingListDepth: Int? = nil
        var pendingListType: ListType? = nil
        var pendingListOrdinal: Int? = nil
        struct ListSignature: Equatable { struct Component: Equatable { let type: ListType; let ordinal: Int }; let components: [Component] }
        var pendingListSignature: ListSignature? = nil
        var pendingListContent = NSMutableAttributedString()

        func flushPendingList() {
            guard let depth = pendingListDepth, let type = pendingListType else { return }
            let indentPerLevel: CGFloat = 20
            let indentSpaces = String(repeating: " ", count: Int(CGFloat(depth - 1) * indentPerLevel / 4))
            let bullet: String = (type == .ordered && pendingListOrdinal != nil) ? "\(pendingListOrdinal!)." : "•"
            let prefix = "\(indentSpaces)\(bullet) "
            let line = NSMutableAttributedString(string: prefix, attributes: [
                .font: baseFont,
                .foregroundColor: textColor ?? UIColor.label
            ])
            line.append(pendingListContent)
            let ps = NSMutableParagraphStyle()
            let tabLoc = (prefix as NSString).size(withAttributes: [.font: baseFont]).width
            ps.tabStops = [NSTextTab(textAlignment: .left, location: tabLoc, options: [:])]
            ps.firstLineHeadIndent = 0
            ps.headIndent = tabLoc
            ps.lineBreakMode = .byWordWrapping
            line.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: line.length))
            pushParagraph(line)
            pendingListDepth = nil
            pendingListType = nil
            pendingListOrdinal = nil
            pendingListSignature = nil
            pendingListContent = NSMutableAttributedString()
        }

        // Paragraph accumulation
        var pendingParagraph = NSMutableAttributedString()
        func flushPendingParagraph() {
            if pendingParagraph.length > 0 {
                pushParagraph(pendingParagraph)
                pendingParagraph = NSMutableAttributedString()
            }
        }

        // Header accumulation
        var headerBuffer = NSMutableAttributedString()
        var headerLevelActive: Int? = nil
        func flushHeaderBuffer() {
            guard let level = headerLevelActive, headerBuffer.length > 0 else { return }
            let font: UIFont = (
                level == 1 ? .systemFont(ofSize: 22, weight: .bold) :
                level == 2 ? .systemFont(ofSize: 20, weight: .semibold) :
                level == 3 ? .systemFont(ofSize: 18, weight: .semibold) :
                .systemFont(ofSize: 16, weight: .semibold)
            )
            let r = NSRange(location: 0, length: headerBuffer.length)
            headerBuffer.addAttribute(.font, value: font, range: r)
            headerBuffer.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: r)
            pushParagraph(headerBuffer)
            headerBuffer = NSMutableAttributedString()
            headerLevelActive = nil
        }

        // Block quote accumulation (structured)
        var quoteParas: [NSAttributedString] = []
        func flushQuote() {
            if !quoteParas.isEmpty {
                blocks.append(.blockQuote(quoteParas))
                quoteParas = []
            }
        }

        for run in attributed.runs {
            let sliceAS = AttributedString(attributed[run.range])
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
                    case .listItem(let ord): depth += 1; ordinal = ord; pendingOrdinalTemp = ord
                    case .orderedList: listType = .ordered; if let o = pendingOrdinalTemp { pairs.append((.ordered, o)); pendingOrdinalTemp = nil }
                    case .unorderedList: listType = .unordered; if let o = pendingOrdinalTemp { pairs.append((.unordered, o)); pendingOrdinalTemp = nil }
                    default: break
                    }
                }
            }
            let signature: ListSignature? = pairs.isEmpty ? nil : ListSignature(components: pairs.map { ListSignature.Component(type: $0.0, ordinal: $0.1) })

            if let level = headerLevel {
                flushPendingList()
                flushPendingParagraph()
                flushQuote()
                if headerLevelActive == nil {
                    headerLevelActive = level
                }
                if let active = headerLevelActive, active != level {
                    flushHeaderBuffer()
                    headerLevelActive = level
                }
                headerBuffer.append(nsFromSlice(sliceAS))
                continue
            } else if headerLevelActive != nil {
                flushHeaderBuffer()
            }

            if isThematic {
                flushPendingList()
                flushPendingParagraph()
                flushQuote()
                blocks.append(.divider)
                continue
            }
            if isCodeBlock {
                flushPendingList()
                flushPendingParagraph()
                flushQuote()
                let ns = nsFromSlice(sliceAS)
                let m = NSMutableAttributedString(attributedString: ns)
                m.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: NSRange(location: 0, length: m.length))
                m.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: NSRange(location: 0, length: m.length))
                pushParagraph(m)
                continue
            }
            if isBlockQuote {
                flushPendingList()
                flushPendingParagraph()
                quoteParas.append(applyBaseStyling(nsFromSlice(sliceAS), textColor: textColor, baseFont: baseFont))
                continue
            } else {
                flushQuote()
            }
            if depth > 0, let type = listType {
                flushPendingParagraph()
                let ns = nsFromSlice(sliceAS)
                if pendingListDepth == nil || pendingListDepth != depth || pendingListType == nil || (pendingListType! != type) || pendingListOrdinal != ordinal || pendingListSignature != signature {
                    flushPendingList()
                    pendingListDepth = depth
                    pendingListType = type
                    pendingListOrdinal = ordinal
                    pendingListSignature = signature
                }
                pendingListContent.append(ns)
                continue
            }
            let ns = nsFromSlice(sliceAS)
            pendingParagraph.append(ns)
        }

        flushPendingList()
        flushPendingParagraph()
        flushQuote()
        return blocks
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

