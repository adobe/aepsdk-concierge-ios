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

import XCTest
@testable import AEPConcierge

final class ThemeDecodingTests: XCTestCase {
    
    var theme: ConciergeTheme?
    
    override func setUp() {
        super.setUp()
        let bundle = ThemeTestHelpers.makeTestBundle()
        theme = ConciergeThemeLoader.load(from: "theme-default", in: bundle)
    }
    
    // MARK: - Full JSON Decoding Tests
    
    func test_loadTheme_defaultJSON_decodesSuccessfully() {
        // Given/When (in setUp)
        // Then
        XCTAssertNotNil(theme, "Theme should decode successfully from theme-default.json")
    }
    
    // MARK: - Metadata Decoding Tests
    
    func test_metadata_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.metadata.brandName, "Concierge Demo")
        XCTAssertEqual(theme.metadata.version, "1.0.0")
        XCTAssertEqual(theme.metadata.language, "en-US")
        XCTAssertEqual(theme.metadata.namespace, "brand-concierge")
    }
    
    // MARK: - Behavior Decoding Tests
    
    func test_behavior_multimodalCarousel_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.behavior.multimodalCarousel.cardClickAction, "openLink")
    }
    
    func test_behavior_input_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertFalse(theme.behavior.input.enableVoiceInput)
        XCTAssertTrue(theme.behavior.input.disableMultiline)
        XCTAssertNil(theme.behavior.input.showAiChatIcon)
    }
    
    func test_behavior_chat_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.behavior.chat.messageAlignment, .leading) // "left" -> .leading
        XCTAssertNil(theme.behavior.chat.messageWidth) // "100%" -> nil
    }
    
    func test_behavior_privacyNotice_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.behavior.privacyNotice.title, "Privacy Notice")
        XCTAssertEqual(theme.behavior.privacyNotice.text, "Privacy notice text.")
    }
    
    // MARK: - Disclaimer Decoding Tests
    
    func test_disclaimer_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.disclaimer.text, "AI responses may be inaccurate. Check answers and sources. {Terms}")
        XCTAssertEqual(theme.disclaimer.links.count, 1)
        XCTAssertEqual(theme.disclaimer.links[0].text, "Terms")
        XCTAssertEqual(theme.disclaimer.links[0].url, "https://www.example.com")
    }
    
    // MARK: - Copy/Text Decoding Tests
    
    func test_copy_welcomeHeading_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.copy.welcomeHeading, "Welcome to [Name] concierge!")
    }
    
    func test_copy_welcomeSubheading_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        let expected = "I'm your personal guide to help you explore and find exactly what you need. Let's get started!\n\nNot sure where to start? Explore the suggested ideas below."
        XCTAssertEqual(theme.copy.welcomeSubheading, expected)
    }
    
    func test_copy_inputPlaceholder_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.copy.inputPlaceholder, "How can I help?")
    }
    
    func test_copy_allTextKeys_decoded() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - verify the expected localized strings are decoded
        XCTAssertEqual(theme.copy.inputMessageInputAria, "Message input")
        XCTAssertEqual(theme.copy.inputSendAria, "Send message")
        XCTAssertEqual(theme.copy.errorNetwork, "I'm sorry, I'm having trouble connecting to our services right now.")
        XCTAssertEqual(theme.copy.loadingMessage, "Generating response from our knowledge base")
        XCTAssertEqual(theme.copy.feedbackDialogTitlePositive, "Your feedback is appreciated")
        XCTAssertEqual(theme.copy.feedbackThumbsUpAria, "Thumbs up")
    }
    
    // MARK: - Arrays Decoding Tests
    
    func test_welcomeExamples_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.welcomeExamples.count, 2)
        XCTAssertEqual(theme.welcomeExamples[0].text, "I'd like to explore templates to see what I can create.")
        XCTAssertEqual(theme.welcomeExamples[0].image, "https://example.com/template.png")
        XCTAssertNotNil(theme.welcomeExamples[0].backgroundColor)
        XCTAssertEqual(theme.welcomeExamples[1].text, "I want to touch up and enhance my photos.")
    }
    
    func test_feedbackPositiveOptions_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.feedbackPositiveOptions.count, 5)
        XCTAssertEqual(theme.feedbackPositiveOptions[0], "Helpful and relevant recommendations")
        XCTAssertEqual(theme.feedbackPositiveOptions[4], "Other")
    }
    
    func test_feedbackNegativeOptions_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.feedbackNegativeOptions.count, 5)
        XCTAssertEqual(theme.feedbackNegativeOptions[0], "Didn't understand my request")
        XCTAssertEqual(theme.feedbackNegativeOptions[4], "Other")
    }
    
    // MARK: - Assets Decoding Tests
    
    func test_assets_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.assets.icons.company, "")
    }
    
    // MARK: - CSS Variable Processing Tests
    
    func test_theme_cssVariables_areProcessed() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - verify CSS variables were converted and applied
        // Typography
        XCTAssertEqual(theme.typography.fontFamily, "")
        XCTAssertEqual(theme.typography.lineHeight, 1.75, accuracy: 0.0001)
        
        // Colors
        XCTAssertEqual(theme.colors.primary.primary.color.toHexString(), "#007BFF")
        XCTAssertEqual(theme.colors.primary.text.color.toHexString(), "#121212")
        XCTAssertEqual(theme.colors.surface.mainContainerBackground.color.toHexString(), "#FFFFFF")
        
        // Layout
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
        XCTAssertEqual(theme.layout.inputBorderRadius, CGFloat(12))
    }
    
    // MARK: - Specific CSS Conversion Tests
    
    func test_messagePadding_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--message-padding": "8px 16px" -> ConciergePadding(vertical: 8, horizontal: 16)
        XCTAssertEqual(theme.layout.messagePadding.top, CGFloat(8))
        XCTAssertEqual(theme.layout.messagePadding.bottom, CGFloat(8))
        XCTAssertEqual(theme.layout.messagePadding.leading, CGFloat(16))
        XCTAssertEqual(theme.layout.messagePadding.trailing, CGFloat(16))
    }
    
    func test_inputBoxShadow_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--input-box-shadow": "0 4px 16px 0 #00000029"
        XCTAssertEqual(theme.layout.inputBoxShadow.offsetX, CGFloat(0))
        XCTAssertEqual(theme.layout.inputBoxShadow.offsetY, CGFloat(4))
        XCTAssertEqual(theme.layout.inputBoxShadow.blurRadius, CGFloat(16))
        XCTAssertEqual(theme.layout.inputBoxShadow.spreadRadius, CGFloat(0))
        XCTAssertTrue(theme.layout.inputBoxShadow.isEnabled)
    }
    
    func test_disclaimerFontWeight_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--disclaimer-font-weight": "400" -> CodableFontWeight.regular
        XCTAssertEqual(theme.layout.disclaimerFontWeight, .regular)
    }
    
    func test_multimodalCardBoxShadow_none_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--multimodal-card-box-shadow": "none" -> disabled shadow
        XCTAssertFalse(theme.layout.multimodalCardBoxShadow.isEnabled)
    }
    
    func test_welcomeInputOrder_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--welcome-input-order": "3"
        XCTAssertEqual(theme.layout.welcomeInputOrder, 3)
    }
    
    func test_welcomeCardsOrder_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--welcome-cards-order": "2"
        XCTAssertEqual(theme.layout.welcomeCardsOrder, 2)
    }
    
    func test_citationsTextFontWeight_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--citations-text-font-weight": "700" -> CodableFontWeight.bold
        XCTAssertEqual(theme.layout.citationsTextFontWeight, .bold)
    }
    
    func test_inputOutlineColor_null_handledCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then - "--input-outline-color": null -> nil
        XCTAssertNil(theme.colors.input.outline)
    }
    
    // MARK: - Missing Sections Tests
    
    func test_missingOptionalSections_usesDefaults() {
        // Given
        let minimalJSON = """
        {
          "metadata": {
            "brandName": "Test"
          }
        }
        """.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let theme: ConciergeTheme?
        do {
            theme = try decoder.decode(ConciergeTheme.self, from: minimalJSON)
        } catch {
            print("Decoding ConciergeTheme failed with error: \(error)")
            theme = nil
        }
        
        // Then
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.behavior.chat.messageAlignment, .leading)
        XCTAssertEqual(theme?.layout.inputHeight ?? 0, 52, accuracy: 0.0001)
    }
    
    func test_emptyThemeObject_usesDefaults() {
        // Given
        let jsonWithEmptyTheme = """
        {
          "metadata": {
            "brandName": "Test"
          }
        }
        """.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let theme = try? decoder.decode(ConciergeTheme.self, from: jsonWithEmptyTheme)
        
        // Then
        XCTAssertNotNil(theme)
        // Empty theme block should apply defaults
        XCTAssertEqual(theme?.layout.inputHeight ?? 0, 52, accuracy: 0.0001)
    }
    
    // MARK: - Encoding Roundtrip Tests
    
    func test_encode_decode_roundtrip() throws {
        // Given
        guard let originalTheme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encodedData = try encoder.encode(originalTheme)
        
        let decoder = JSONDecoder()
        let decodedTheme = try decoder.decode(ConciergeTheme.self, from: encodedData)
        
        // Then
        XCTAssertEqual(decodedTheme.metadata.brandName, originalTheme.metadata.brandName)
        XCTAssertEqual(decodedTheme.layout.inputHeight, originalTheme.layout.inputHeight, accuracy: 0.0001)
        XCTAssertEqual(decodedTheme.colors.primary.primary.color.toHexString(), originalTheme.colors.primary.primary.color.toHexString())
    }
    
    func test_encode_producesValidJSON() throws {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let encodedData = try encoder.encode(theme)
        
        // Then
        XCTAssertNotNil(encodedData)
        let jsonObject = try JSONSerialization.jsonObject(with: encodedData, options: [])
        XCTAssertTrue(jsonObject is [String: Any])
    }
    
}

