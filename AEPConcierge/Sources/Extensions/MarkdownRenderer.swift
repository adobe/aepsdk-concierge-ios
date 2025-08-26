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

/// Renders markdown into an AttributedString, leveraging the system markdown parser
/// and applying text style changes where applicable.
enum MarkdownRenderer {
    /// Parse and style a markdown string into an AttributedString.
    /// - Parameter markdown: The markdown source text.
    /// - Returns: A styled AttributedString for use with SwiftUI `Text(_:)` or UIKit.
    static func render(_ markdown: String) -> AttributedString {
        // Parse using system markdown support
        let options = AttributedString.MarkdownParsingOptions(
            // Preserve literal newlines and whitespace, but parse inline markdown like **bold**, _italic_, `code`, and links
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
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
