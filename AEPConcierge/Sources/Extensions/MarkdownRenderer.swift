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

/// Renders markdown into an AttributedString, leveraging the system markdown parser
/// and applying text style changes where applicable.
enum MarkdownRenderer {
    /// Parse and style a markdown string into an AttributedString.
    /// - Parameter markdown: The markdown source text.
    /// - Returns: A styled AttributedString for use with SwiftUI `Text(_:)` or UIKit.
    static func render(_ markdown: String) -> AttributedString {
        // Parse using system markdown support
        let options = AttributedString.MarkdownParsingOptions(
            // Use full parsing for block and inline detection
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        guard var attributed = try? AttributedString(markdown: markdown, options: options) else {
            return AttributedString(markdown)
        }

        applyInlineStyles(&attributed)
        applyBlockStyles(&attributed)
        return attributed
    }

    // MARK: - Styling
    private static func applyInlineStyles(_ attributed: inout AttributedString) {
        var container = AttributeContainer()
        let swiftUIFontScope = AttributeScopes.SwiftUIAttributes.self

        for run in attributed.runs {
            // For inline code styling, apply monospaced font
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                container[swiftUIFontScope.FontAttribute.self] = .system(.body, design: .monospaced)
                attributed[run.range].mergeAttributes(container)
                container = AttributeContainer()
            }
        }
    }

    private static func applyBlockStyles(_ attributed: inout AttributedString) {
        let swiftUIFontScope = AttributeScopes.SwiftUIAttributes.self
        let uiKitScope = AttributeScopes.UIKitAttributes.self

        for run in attributed.runs {
            if let presentation = run.presentationIntent {
                for component in presentation.components {
                    switch component.kind {
                    case .header(let level):
                        var container = AttributeContainer()
                        // Map heading levels to font sizes/weights
                        let font: Font
                        switch level {
                        case 1: font = .system(size: 22, weight: .bold)
                        case 2: font = .system(size: 20, weight: .semibold)
                        case 3: font = .system(size: 18, weight: .semibold)
                        default: font = .system(size: 16, weight: .semibold)
                        }
                        container[swiftUIFontScope.FontAttribute.self] = font
                        attributed[run.range].mergeAttributes(container)

                    case .blockQuote:
                        var container = AttributeContainer()
                        // Slightly dim quotes to differentiate
                        container[uiKitScope.ForegroundColorAttribute.self] = UIColor.secondaryLabel
                        attributed[run.range].mergeAttributes(container)
                    default:
                        break
                    }
                }
            }
        }
    }
}

extension Text {
    /// Convenience helper to create a Text view from markdown using MarkdownRenderer.
    static func markdown(_ markdown: String) -> Text {
        return Text(MarkdownRenderer.render(markdown))
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

