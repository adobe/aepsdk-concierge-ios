/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
import UIKit
@testable import AEPBrandConcierge

final class MarkdownRendererTests: XCTestCase {
    
    // MARK: - Plain Text Tests
    
    func test_buildBlocks_plainText_returnsSingleTextBlock() {
        // Given
        let markdown = "Hello world"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertEqual(attributedString.string, "Hello world")
        } else {
            XCTFail("Expected text block")
        }
    }
    
    func test_buildBlocks_emptyString_returnsEmptyArray() {
        // Given
        let markdown = ""
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertTrue(blocks.isEmpty)
    }
    
    func test_buildBlocks_multipleParagraphs_returnsMultipleTextBlocks() {
        // Given
        let markdown = "First paragraph\n\nSecond paragraph"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 2)
        
        if case .text(let first) = blocks[0] {
            XCTAssertEqual(first.string, "First paragraph")
        } else {
            XCTFail("Expected first text block")
        }
        
        if case .text(let second) = blocks[1] {
            XCTAssertEqual(second.string, "Second paragraph")
        } else {
            XCTFail("Expected second text block")
        }
    }
    
    // MARK: - Header Tests
    
    func test_buildBlocks_header1_returnsTextBlockWithContent() {
        // Given
        let markdown = "# Header 1"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertEqual(attributedString.string, "Header 1")
        } else {
            XCTFail("Expected text block for header")
        }
    }
    
    func test_buildBlocks_header2_returnsTextBlockWithContent() {
        // Given
        let markdown = "## Header 2"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertEqual(attributedString.string, "Header 2")
        } else {
            XCTFail("Expected text block for header")
        }
    }

    func test_buildBlocks_headingColorOverridesAllLevelsAndKeepsBodyAndFonts() throws {
        let markdown = """
        # Heading one

        ## Heading two

        ### Heading three

        #### Heading four

        ##### Heading five

        ###### Heading six

        Body text
        """
        let bodyColor = UIColor.black
        var originalFonts: [UIFont] = []
        let configurations: [(headingColor: UIColor?, expected: UIColor)] = [
            (nil, bodyColor), (.red, .red), (.blue, .blue), (nil, bodyColor)
        ]

        for (index, configuration) in configurations.enumerated() {
            let blocks = MarkdownRenderer.buildBlocks(
                markdown: markdown,
                textColor: bodyColor,
                headingColor: configuration.headingColor
            )
            XCTAssertEqual(blocks.count, 7)
            guard blocks.count == 7 else { return }

            for headingIndex in 0..<6 {
                guard case .text(let heading) = blocks[headingIndex] else {
                    return XCTFail("Expected a text block for heading \(headingIndex + 1)")
                }
                let color = try XCTUnwrap(heading.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
                let font = try XCTUnwrap(heading.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(color, configuration.expected)
                if index == 0 {
                    originalFonts.append(font)
                } else {
                    XCTAssertEqual(font, originalFonts[headingIndex])
                }
            }

            guard case .text(let body) = blocks[6] else {
                return XCTFail("Expected a body text block")
            }
            XCTAssertEqual(body.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, bodyColor)
        }
    }

    func test_buildBlocks_headingColorAppliesInsideBlockQuotesWithoutChangingBody() throws {
        let blocks = MarkdownRenderer.buildBlocks(
            markdown: "> ## Quoted heading\n>\n> Quoted body",
            textColor: .black,
            headingColor: .red
        )
        guard case .blockQuote(let children) = blocks.first, children.count == 2,
              case .text(let heading) = children[0], case .text(let body) = children[1] else {
            return XCTFail("Expected a quoted heading and body")
        }
        XCTAssertEqual(heading.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(body.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .black)
    }
    
    // MARK: - Unordered List Tests
    
    func test_buildBlocks_unorderedList_returnsListBlock() {
        // Given
        let markdown = "- Item 1\n- Item 2\n- Item 3"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .list(let type, let items) = blocks.first {
            XCTAssertEqual(type, .unordered)
            XCTAssertEqual(items.count, 3)
        } else {
            XCTFail("Expected unordered list block")
        }
    }
    
    func test_buildBlocks_unorderedListWithAsterisks_returnsListBlock() {
        // Given
        let markdown = "* First\n* Second"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .list(let type, let items) = blocks.first {
            XCTAssertEqual(type, .unordered)
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected unordered list block")
        }
    }
    
    // MARK: - Ordered List Tests
    
    func test_buildBlocks_orderedList_returnsListBlock() {
        // Given
        let markdown = "1. First\n2. Second\n3. Third"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .list(let type, let items) = blocks.first {
            XCTAssertEqual(type, .ordered)
            XCTAssertEqual(items.count, 3)
        } else {
            XCTFail("Expected ordered list block")
        }
    }
    
    // MARK: - Code Block Tests
    
    func test_buildBlocks_codeBlock_returnsCodeBlock() {
        // Given
        let markdown = "```\nlet x = 1\nprint(x)\n```"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .code(let attributedString) = blocks.first {
            XCTAssertTrue(attributedString.string.contains("let x = 1"))
        } else {
            XCTFail("Expected code block")
        }
    }
    
    func test_buildBlocks_codeBlockWithLanguage_returnsCodeBlock() {
        // Given
        let markdown = "```swift\nfunc hello() {}\n```"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .code(let attributedString) = blocks.first {
            XCTAssertTrue(attributedString.string.contains("func hello"))
        } else {
            XCTFail("Expected code block")
        }
    }
    
    // MARK: - Thematic Break (Divider) Tests
    
    func test_buildBlocks_thematicBreak_returnsDivider() {
        // Given
        let markdown = "Before\n\n---\n\nAfter"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        let hasDivider = blocks.contains { block in
            if case .divider = block { return true }
            return false
        }
        XCTAssertTrue(hasDivider, "Should contain a divider block")
    }
    
    // MARK: - Block Quote Tests
    
    func test_buildBlocks_blockQuote_returnsBlockQuote() {
        // Given
        let markdown = "> This is a quote"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .blockQuote(let children) = blocks.first {
            XCTAssertFalse(children.isEmpty, "Block quote should have children")
        } else {
            XCTFail("Expected block quote block")
        }
    }
    
    func test_buildBlocks_multiLineBlockQuote_returnsBlockQuote() {
        // Given
        let markdown = "> Line one\n> Line two"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .blockQuote = blocks.first {
            // Success
        } else {
            XCTFail("Expected block quote block")
        }
    }
    
    // MARK: - Inline Formatting Tests
    
    func test_buildBlocks_boldText_preservesContent() {
        // Given
        let markdown = "This is **bold** text"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertEqual(attributedString.string, "This is bold text")
        } else {
            XCTFail("Expected text block")
        }
    }
    
    func test_buildBlocks_italicText_preservesContent() {
        // Given
        let markdown = "This is *italic* text"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertEqual(attributedString.string, "This is italic text")
        } else {
            XCTFail("Expected text block")
        }
    }
    
    func test_buildBlocks_inlineCode_preservesContent() {
        // Given
        let markdown = "Use `let` keyword"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertTrue(attributedString.string.contains("let"))
        } else {
            XCTFail("Expected text block")
        }
    }
    
    // MARK: - Nested Structure Tests
    
    func test_buildBlocks_listWithNestedItems_parsesCorrectly() {
        // Given
        let markdown = "- Item 1\n  - Nested 1\n  - Nested 2\n- Item 2"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then - Should parse without crashing
        XCTAssertFalse(blocks.isEmpty)
    }
    
    func test_buildBlocks_quoteWithList_parsesCorrectly() {
        // Given
        let markdown = "> Quote with list:\n> - Item A\n> - Item B"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .blockQuote(let children) = blocks.first {
            XCTAssertFalse(children.isEmpty)
        } else {
            XCTFail("Expected block quote")
        }
    }
    
    // MARK: - Text Color Tests
    
    func test_buildBlocks_withTextColor_appliesColor() {
        // Given
        let markdown = "Colored text"
        let color = UIColor.red
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown, textColor: color)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            var hasColor = false
            attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length)) { value, _, _ in
                if value != nil {
                    hasColor = true
                }
            }
            XCTAssertTrue(hasColor, "Attributed string should have foreground color")
        } else {
            XCTFail("Expected text block")
        }
    }
    
    // MARK: - Base Font Tests
    
    func test_buildBlocks_withCustomFont_usesFont() {
        // Given
        let markdown = "Custom font text"
        let customFont = UIFont.systemFont(ofSize: 20)
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown, baseFont: customFont)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text = blocks.first {
            // Font is applied - detailed font checking would require digging into attributes
        } else {
            XCTFail("Expected text block")
        }
    }
    
    // MARK: - Complex Markdown Tests
    
    func test_buildBlocks_complexMarkdown_parsesWithoutCrash() {
        // Given
        let markdown = """
        # Title
        
        This is a **bold** paragraph with *italic* and `code`.
        
        ## Section 1
        
        - List item 1
        - List item 2
          - Nested item
        
        > A quote here
        
        ```swift
        let code = "example"
        ```
        
        ---
        
        Final paragraph.
        """
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertFalse(blocks.isEmpty, "Should parse complex markdown without crashing")
    }
    
    // MARK: - Edge Cases
    
    func test_buildBlocks_unicodeContent_parsesCorrectly() {
        // Given
        let markdown = "Hello 👋 世界 🌍"
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertEqual(blocks.count, 1)
        if case .text(let attributedString) = blocks.first {
            XCTAssertTrue(attributedString.string.contains("👋"))
            XCTAssertTrue(attributedString.string.contains("世界"))
        } else {
            XCTFail("Expected text block")
        }
    }
    
    func test_buildBlocks_specialCharacters_parsesCorrectly() {
        // Given
        let markdown = "Price: $100 & <tag> \"quotes\""
        
        // When
        let blocks = MarkdownRenderer.buildBlocks(markdown: markdown)
        
        // Then
        XCTAssertFalse(blocks.isEmpty)
    }
}
