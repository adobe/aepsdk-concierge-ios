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
@testable import AEPBrandConcierge

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
        XCTAssertEqual(theme.behavior.multimodalCarousel.carouselStyle, .paged)
    }
    
    func test_behavior_productCard_decodesCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }

        // Then
        XCTAssertEqual(theme.behavior.productCard?.cardStyle, .productDetail)
        XCTAssertEqual(theme.behavior.productCard?.cardsAlignment, .center)
    }

    func test_behavior_productCard_cardsAlignment_decodesAllValues() {
        let cases: [(String, CardsAlignment)] = [
            ("start", .start),
            ("center", .center),
            ("end", .end)
        ]
        for (raw, expected) in cases {
            let json = """
            {"behavior":{"productCard":{"cardStyle":"actionButton","cardsAlignment":"\(raw)"}}}
            """
            let data = json.data(using: .utf8)!
            let decoded = try? JSONDecoder().decode(ConciergeTheme.self, from: data)
            XCTAssertEqual(decoded?.behavior.productCard?.cardsAlignment, expected, "Failed for raw value '\(raw)'")
        }
    }

    func test_behavior_productCard_cardsAlignment_defaultsToCenter() {
        // When cardsAlignment is omitted, it should default to .center
        let json = """
        {"behavior":{"productCard":{"cardStyle":"actionButton"}}}
        """
        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(ConciergeTheme.self, from: data)
        XCTAssertEqual(decoded?.behavior.productCard?.cardsAlignment, .center)
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
        XCTAssertEqual(theme.behavior.input.silenceThreshold, 0.02, accuracy: 0.0001)
        XCTAssertEqual(theme.behavior.input.silenceDuration, 2.0, accuracy: 0.0001)
    }

    func test_behavior_input_decodesCustomSilenceVoiceFields() throws {
        let minimalJSON = """
        {
          "metadata": { "brandName": "Test" },
          "behavior": {
            "input": {
              "silenceThreshold": 0.035,
              "silenceDuration": 3.5
            }
          }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: minimalJSON)
        XCTAssertEqual(decoded.behavior.input.silenceThreshold, 0.035, accuracy: 0.0001)
        XCTAssertEqual(decoded.behavior.input.silenceDuration, 3.5, accuracy: 0.0001)
    }

    func test_behavior_input_missingSilenceVoiceFields_useDefaults() throws {
        let minimalJSON = """
        { "metadata": { "brandName": "Test" } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: minimalJSON)
        XCTAssertEqual(decoded.behavior.input.silenceThreshold, 0.02, accuracy: 0.0001)
        XCTAssertEqual(decoded.behavior.input.silenceDuration, 2.0, accuracy: 0.0001)
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
        XCTAssertEqual(theme.behavior.chat.userMessageBubbleStyle, .balloon) // "default" -> .balloon
    }

    func test_behavior_chat_userMessageBubbleStyle_balloon_decodes() throws {
        let json = """
        { "metadata": { "brandName": "Test" }, "behavior": { "chat": { "userMessageBubbleStyle": "balloon" } } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: json)
        XCTAssertEqual(decoded.behavior.chat.userMessageBubbleStyle, .balloon)
    }

    func test_behavior_chat_userMessageBubbleStyle_caseInsensitive_decodes() throws {
        let json = """
        { "metadata": { "brandName": "Test" }, "behavior": { "chat": { "userMessageBubbleStyle": "Balloon" } } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: json)
        XCTAssertEqual(decoded.behavior.chat.userMessageBubbleStyle, .balloon)
    }

    func test_behavior_chat_userMessageBubbleStyle_unknownValue_fallsBackToDefault() throws {
        let json = """
        { "metadata": { "brandName": "Test" }, "behavior": { "chat": { "userMessageBubbleStyle": "unknown" } } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: json)
        XCTAssertEqual(decoded.behavior.chat.userMessageBubbleStyle, .default)
    }

    // MARK: - behavior.chat.messageAlignment decoding (accepted value variants)

    private func decodeMessageAlignment(_ raw: String) throws -> ConciergeTextAlignment {
        let json = """
        { "metadata": { "brandName": "Test" }, "behavior": { "chat": { "messageAlignment": "\(raw)" } } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: json)
        return decoded.behavior.chat.messageAlignment
    }

    func test_behavior_chat_messageAlignment_webValues_decode() throws {
        XCTAssertEqual(try decodeMessageAlignment("left"), .leading)
        XCTAssertEqual(try decodeMessageAlignment("right"), .trailing)
        XCTAssertEqual(try decodeMessageAlignment("center"), .center)
        XCTAssertEqual(try decodeMessageAlignment("justify"), .center)
    }

    func test_behavior_chat_messageAlignment_composeValues_decode() throws {
        XCTAssertEqual(try decodeMessageAlignment("start"), .leading)
        XCTAssertEqual(try decodeMessageAlignment("end"), .trailing)
    }

    func test_behavior_chat_messageAlignment_swiftUIValues_decode() throws {
        XCTAssertEqual(try decodeMessageAlignment("leading"), .leading)
        XCTAssertEqual(try decodeMessageAlignment("trailing"), .trailing)
    }

    func test_behavior_chat_messageAlignment_caseInsensitive_decodes() throws {
        XCTAssertEqual(try decodeMessageAlignment("LEFT"), .leading)
        XCTAssertEqual(try decodeMessageAlignment("Trailing"), .trailing)
        XCTAssertEqual(try decodeMessageAlignment("CENTER"), .center)
    }

    func test_behavior_chat_messageAlignment_unknownValue_fallsBackToLeading() throws {
        XCTAssertEqual(try decodeMessageAlignment("sideways"), .leading)
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

    func test_behavior_feedback_displayMode_modalAndAction_decode() throws {
        let jsonModal = """
        { "metadata": { "brandName": "Test" }, "behavior": { "feedback": { "displayMode": "modal" } } }
        """.data(using: .utf8)!
        let modalTheme = try JSONDecoder().decode(ConciergeTheme.self, from: jsonModal)
        XCTAssertEqual(modalTheme.behavior.feedback?.displayMode, "modal")

        let jsonAction = """
        { "metadata": { "brandName": "Test" }, "behavior": { "feedback": { "displayMode": "action" } } }
        """.data(using: .utf8)!
        let actionTheme = try JSONDecoder().decode(ConciergeTheme.self, from: jsonAction)
        XCTAssertEqual(actionTheme.behavior.feedback?.displayMode, "action")
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
        XCTAssertEqual(theme.colors.primary.text.color.toHexString(), "#131313")
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
    
    // MARK: - Product Card CSS Variable Tests
    
    func test_productCardLayout_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.layout.productCardTitleFontSize, 14)
        XCTAssertEqual(theme.layout.productCardTitleFontWeight, .bold)
        XCTAssertEqual(theme.layout.productCardSubtitleFontSize, 12)
        XCTAssertEqual(theme.layout.productCardSubtitleFontWeight, .regular)
        XCTAssertEqual(theme.layout.productCardPriceFontSize, 16)
        XCTAssertEqual(theme.layout.productCardPriceFontWeight, .light)
        XCTAssertEqual(theme.layout.productCardBadgeFontSize, 12)
        XCTAssertEqual(theme.layout.productCardBadgeFontWeight, .semibold)
        XCTAssertEqual(theme.layout.productCardWasPriceTextPrefix, "was ")
        XCTAssertEqual(theme.layout.productCardWasPriceFontSize, 12)
        XCTAssertEqual(theme.layout.productCardWasPriceFontWeight, .regular)
        XCTAssertEqual(theme.layout.productCardWidth, 200)
        XCTAssertEqual(theme.layout.productCardHeight, 300)
        XCTAssertEqual(theme.layout.productCardTextSpacing, 10)
        XCTAssertEqual(theme.layout.productCardTextTopPadding, 24)
        XCTAssertEqual(theme.layout.productCardTextBottomPadding, 14)
        XCTAssertEqual(theme.layout.productCardTextHorizontalPadding, 16)
        XCTAssertEqual(theme.layout.productCardCarouselSpacing, 16)
        XCTAssertEqual(theme.layout.productCardCarouselHorizontalPadding, 8)
    }
    
    func test_productCardColors_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }
        
        // Then
        XCTAssertEqual(theme.colors.productCard.backgroundColor!.color.toHexString(), "#FFFFFF")
        XCTAssertEqual(theme.colors.productCard.titleColor.color.toHexString(), "#292929")
        XCTAssertEqual(theme.colors.productCard.subtitleColor.color.toHexString(), "#292929")
        XCTAssertEqual(theme.colors.productCard.priceColor.color.toHexString(), "#292929")
        XCTAssertEqual(theme.colors.productCard.wasPriceColor.color.toHexString(), "#6E6E6E")
        XCTAssertEqual(theme.colors.productCard.badgeTextColor.color.toHexString(), "#FFFFFF")
        XCTAssertEqual(theme.colors.productCard.badgeBackgroundColor.color.toHexString(), "#000000")
    }
    
    // MARK: - CTA Button CSS Variable Tests

    func test_ctaButtonLayout_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }

        // Then
        XCTAssertEqual(theme.layout.ctaButtonBorderRadius, 99)
        XCTAssertEqual(theme.layout.ctaButtonHorizontalPadding, 16)
        XCTAssertEqual(theme.layout.ctaButtonVerticalPadding, 12)
        XCTAssertEqual(theme.layout.ctaButtonFontSize, 14)
        XCTAssertEqual(theme.layout.ctaButtonFontWeight, .regular)
        XCTAssertEqual(theme.layout.ctaButtonIconSize, 16)
    }

    func test_ctaButtonColors_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }

        // Then
        XCTAssertEqual(theme.colors.ctaButton.background.color.toHexString(), "#EDEDED")
        XCTAssertEqual(theme.colors.ctaButton.text.color.toHexString(), "#191F1C")
        XCTAssertEqual(theme.colors.ctaButton.iconColor.color.toHexString(), "#161313")
    }

    // MARK: - Thinking Animation CSS Variable Tests

    func test_thinkingAnimationColors_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }

        // Then — "--thinking-dot-color": "#007BFF"
        XCTAssertEqual(theme.colors.thinking.dotColor?.color.toHexString(), "#007BFF")
    }

    func test_thinkingAnimationLayout_convertsCorrectly() {
        // Given
        guard let theme = theme else {
            XCTFail("Theme should be loaded")
            return
        }

        // Then
        XCTAssertEqual(theme.layout.thinkingDotSize, 8)
        XCTAssertEqual(theme.layout.thinkingDotSpacing, 8)
        XCTAssertEqual(theme.layout.thinkingBubbleBorderRadius, 8)
        XCTAssertEqual(theme.layout.thinkingBubblePaddingHorizontal, 16)
        XCTAssertEqual(theme.layout.thinkingBubblePaddingVertical, 8)
        XCTAssertEqual(theme.layout.thinkingDotVerticalAlignment, .center)
    }

    func test_thinkingDotVerticalAlignment_missingFromTheme_isNil() {
        // Given
        let minimalJSON = """
        { "metadata": { "brandName": "Test" } }
        """.data(using: .utf8)!

        // When
        let decoded = try? JSONDecoder().decode(ConciergeTheme.self, from: minimalJSON)

        // Then — all thinking properties should be nil when not set
        XCTAssertNil(decoded?.layout.thinkingDotVerticalAlignment)
        XCTAssertNil(decoded?.layout.thinkingDotSize)
        XCTAssertNil(decoded?.colors.thinking.dotColor)
    }

    func test_missingProductCardBehavior_usesDefaults() {
        // Given — minimal JSON with no productCard behavior
        let minimalJSON = """
        { "metadata": { "brandName": "Test" } }
        """.data(using: .utf8)!
        
        // When
        let decodedTheme = try? JSONDecoder().decode(ConciergeTheme.self, from: minimalJSON)
        
        // Then — defaults to actionButton card style and paged carousel
        XCTAssertNotNil(decodedTheme)
        XCTAssertEqual(decodedTheme?.behavior.productCard?.cardStyle, .actionButton)
        XCTAssertEqual(decodedTheme?.behavior.multimodalCarousel.carouselStyle, .paged)
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

    // MARK: - Prompt Suggestions Behavior Decoding Tests

    func test_behavior_promptSuggestions_decodesCorrectly() throws {
        let json = """
        {
          "behavior": {
            "promptSuggestions": {
              "itemMaxLines": 2,
              "showHeader": true,
              "alignToMessage": true
            }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: data)

        XCTAssertEqual(decoded.behavior.promptSuggestions?.itemMaxLines, 2)
        XCTAssertEqual(decoded.behavior.promptSuggestions?.showHeader, true)
        XCTAssertEqual(decoded.behavior.promptSuggestions?.alignToMessage, true)
    }

    func test_behavior_promptSuggestions_absentBlock_isNil() throws {
        let json = """
        { "behavior": {} }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: data)

        XCTAssertNil(decoded.behavior.promptSuggestions)
    }

    func test_behavior_promptSuggestions_defaults() {
        let behavior = ConciergePromptSuggestionsBehavior()
        XCTAssertEqual(behavior.itemMaxLines, 1)
        XCTAssertFalse(behavior.showHeader)
        XCTAssertFalse(behavior.alignToMessage)
    }

    func test_behavior_promptSuggestions_partialJson_usesDefaults() throws {
        let json = """
        {
          "behavior": {
            "promptSuggestions": {
              "showHeader": true
            }
          }
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: data)

        XCTAssertEqual(decoded.behavior.promptSuggestions?.itemMaxLines, 1)
        XCTAssertEqual(decoded.behavior.promptSuggestions?.showHeader, true)
        XCTAssertEqual(decoded.behavior.promptSuggestions?.alignToMessage, false)
    }

    // MARK: - suggestions.header Text String Tests

    func test_text_suggestionsHeader_decodesCorrectly() throws {
        let json = """
        { "text": { "suggestions.header": "Explore More" } }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: data)

        XCTAssertEqual(decoded.text.suggestionsHeader, "Explore More")
    }

    func test_text_suggestionsHeader_defaultsToSuggestions() throws {
        let json = """
        { "text": {} }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ConciergeTheme.self, from: data)

        XCTAssertEqual(decoded.text.suggestionsHeader, "Suggestions")
    }

    // MARK: - primary.container defaults

    func test_primaryColors_container_defaultsToNil() {
        let theme = ConciergeTheme()
        XCTAssertNil(theme.colors.primary.container)
    }

    func test_promptSuggestion_backgroundColor_defaultsToNil() {
        let theme = ConciergeTheme()
        XCTAssertNil(theme.colors.promptSuggestion.backgroundColor)
    }

    func test_message_conciergeBackground_defaultsToNil() {
        let theme = ConciergeTheme()
        XCTAssertNil(theme.colors.message.conciergeBackground)
    }

    func test_productCard_backgroundColor_defaultsToNil() {
        let theme = ConciergeTheme()
        XCTAssertNil(theme.colors.productCard.backgroundColor)
    }

}

