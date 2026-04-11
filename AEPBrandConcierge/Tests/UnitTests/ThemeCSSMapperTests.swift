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

final class ThemeCSSMapperTests: XCTestCase {
    
    // MARK: - Key Normalization Tests
    
    func test_apply_withDoubleDashPrefix_normalizesKey() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "--input-height-mobile"
        let cssValue = "52px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
    }
    
    func test_apply_withoutPrefix_works() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-height-mobile"
        let cssValue = "52px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
    }
    
    // MARK: - Typography Mapping Tests
    
    func test_fontFamily_mapsToTypography() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "font-family"
        let cssValue = "Arial"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.typography.fontFamily, "Arial")
    }
    
    func test_lineHeightBody_mapsToTypography() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "line-height-body"
        let cssValue = "1.75"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.typography.lineHeight, 1.75, accuracy: 0.0001)
    }
    
    // MARK: - Color Mapping Tests
    
    func test_colorPrimary_mapsToPrimaryColor() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "color-primary"
        let cssValue = "#007BFF"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.primary.primary.color.toHexString(), "#007BFF")
    }
    
    func test_colorText_mapsToPrimaryText() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "color-text"
        let cssValue = "#131313"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.primary.text.color.toHexString(), "#131313")
    }
    
    func test_mainContainerBackground_mapsToSurface() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "main-container-background"
        let cssValue = "#FFFFFF"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.surface.mainContainerBackground.color.toHexString(), "#FFFFFF")
    }
    
    func test_messageUserBackground_mapsToMessageColors() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "message-user-background"
        let cssValue = "#EBEEFF"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.message.userBackground.color.toHexString(), "#EBEEFF")
    }
    
    func test_buttonPrimaryBackground_mapsToButtonColors() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "button-primary-background"
        let cssValue = "#3B63FB"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.button.primaryBackground.color.toHexString(), "#3B63FB")
    }
    
    func test_inputBackground_mapsToInputColors() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-background"
        let cssValue = "#FFFFFF"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.input.background.color.toHexString(), "#FFFFFF")
    }
    
    func test_disclaimerColor_mapsToDisclaimer() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "disclaimer-color"
        let cssValue = "#4B4B4B"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.colors.disclaimer.color.toHexString(), "#4B4B4B")
    }
    
    // MARK: - Layout Mapping Tests
    
    func test_inputBorderRadiusMobile_setsLayoutValues() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-border-radius-mobile"
        let cssValue = "18px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputBorderRadius, CGFloat(18))
    }
    
    func test_inputBorderRadiusDesktop_isIgnored() {
        // Given
        var theme = ConciergeTheme()
        let originalRadius = theme.layout.inputBorderRadius
        let cssKey = "input-border-radius"
        let cssValue = "25px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputBorderRadius, originalRadius)
    }
    
    func test_inputHeightMobile_setsLayoutValues() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-height-mobile"
        let cssValue = "64px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(Int(theme.layout.inputHeight), 64)
    }
    
    func test_inputHeightDesktop_isIgnored() {
        // Given
        var theme = ConciergeTheme()
        let originalHeight = theme.layout.inputHeight
        let cssKey = "input-height"
        let cssValue = "80px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, originalHeight)
    }
    
    func test_messagePadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "message-padding"
        let cssValue = "8px 16px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.messagePadding.top, CGFloat(8))
        XCTAssertEqual(theme.layout.messagePadding.bottom, CGFloat(8))
        XCTAssertEqual(theme.layout.messagePadding.leading, CGFloat(16))
        XCTAssertEqual(theme.layout.messagePadding.trailing, CGFloat(16))
    }
    
    func test_inputBoxShadow_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-box-shadow"
        let cssValue = "0 4px 16px 0 #00000029"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputBoxShadow.offsetX, CGFloat(0))
        XCTAssertEqual(theme.layout.inputBoxShadow.offsetY, CGFloat(4))
        XCTAssertEqual(theme.layout.inputBoxShadow.blurRadius, CGFloat(16))
        XCTAssertTrue(theme.layout.inputBoxShadow.isEnabled)
    }
    
    func test_messageMaxWidth_100Percent_mapsToNil() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "message-max-width"
        let cssValue = "100%"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertNil(theme.layout.messageMaxWidth)
    }
    
    func test_messageMaxWidth_pxValue_mapsToCGFloat() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "message-max-width"
        let cssValue = "768px"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertNotNil(theme.layout.messageMaxWidth)
        XCTAssertEqual(theme.layout.messageMaxWidth!, 768, accuracy: 0.0001)
    }
    
    func test_citationsTextFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "citations-text-font-weight"
        let cssValue = "700"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.citationsTextFontWeight, CodableFontWeight.bold)
    }
    
    // MARK: - Multiple Property Mapping Tests
    
    func test_welcomeInputOrder_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "welcome-input-order"
        let cssValue = "3"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.welcomeInputOrder, 3)
    }
    
    func test_welcomeCardsOrder_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "welcome-cards-order"
        let cssValue = "2"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.welcomeCardsOrder, 2)
    }
    
    // MARK: - Edge Cases
    
    func test_unknownKey_isSilentlyIgnored() {
        // Given
        var theme = ConciergeTheme()
        let originalInputHeight = theme.layout.inputHeight
        let cssKey = "unknown-css-key"
        let cssValue = "some value"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, originalInputHeight)
    }
    
    func test_inputOutlineColor_gradient_setsToNil() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-outline-color"
        let cssValue = "linear-gradient(to right, #000, #fff)"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertNil(theme.colors.input.outline)
    }
    
    func test_inputOutlineColor_solidColor_setsValue() {
        // Given
        var theme = ConciergeTheme()
        let cssKey = "input-outline-color"
        let cssValue = "#4B75FF"
        
        // When
        CSSKeyMapper.apply(cssKey: cssKey, cssValue: cssValue, to: &theme)
        
        // Then
        XCTAssertNotNil(theme.colors.input.outline)
        XCTAssertEqual(theme.colors.input.outline?.color.toHexString(), "#4B75FF")
    }

    // MARK: - Product Card Color Mapping Tests

    func test_productCardBackgroundColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-background-color", cssValue: "#F5F5F5", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.backgroundColor.color.toHexString(), "#F5F5F5")
    }

    func test_productCardTitleColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-title-color", cssValue: "#292929", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.titleColor.color.toHexString(), "#292929")
    }

    func test_productCardSubtitleColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-subtitle-color", cssValue: "#6E6E6E", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.subtitleColor.color.toHexString(), "#6E6E6E")
    }

    func test_productCardPriceColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-price-color", cssValue: "#000000", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.priceColor.color.toHexString(), "#000000")
    }

    func test_productCardWasPriceColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-was-price-color", cssValue: "#6E6E6E", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.wasPriceColor.color.toHexString(), "#6E6E6E")
    }

    func test_productCardBadgeTextColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-badge-text-color", cssValue: "#FFFFFF", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.badgeTextColor.color.toHexString(), "#FFFFFF")
    }

    func test_productCardBadgeBackgroundColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-badge-background-color", cssValue: "#000000", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.badgeBackgroundColor.color.toHexString(), "#000000")
    }

    func test_productCardOutlineColor_mapsToProductCardColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-outline-color", cssValue: "#00000000", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.productCard.outlineColor.color.toHexString(), "#00000000")
    }

    // MARK: - Product Card Layout Mapping Tests

    func test_productCardTitleFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-title-font-size", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTitleFontSize, 16)
    }

    func test_productCardTitleFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-title-font-weight", cssValue: "700", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTitleFontWeight, .bold)
    }

    func test_productCardSubtitleFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-subtitle-font-size", cssValue: "14px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardSubtitleFontSize, 14)
    }

    func test_productCardSubtitleFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-subtitle-font-weight", cssValue: "400", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardSubtitleFontWeight, .regular)
    }

    func test_productCardPriceFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-price-font-size", cssValue: "18px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardPriceFontSize, 18)
    }

    func test_productCardPriceFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-price-font-weight", cssValue: "300", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardPriceFontWeight, .light)
    }

    func test_productCardBadgeFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-badge-font-size", cssValue: "10px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardBadgeFontSize, 10)
    }

    func test_productCardBadgeFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-badge-font-weight", cssValue: "600", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardBadgeFontWeight, .semibold)
    }

    func test_productCardWasPriceTextPrefix_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-was-price-text-prefix", cssValue: "Previously ", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardWasPriceTextPrefix, "Previously ")
    }

    func test_productCardWasPriceFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-was-price-font-size", cssValue: "11px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardWasPriceFontSize, 11)
    }

    func test_productCardWasPriceFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-was-price-font-weight", cssValue: "400", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardWasPriceFontWeight, .regular)
    }

    func test_productCardWidth_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-width", cssValue: "220px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardWidth, 220)
    }

    func test_productCardHeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-height", cssValue: "350px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardHeight, 350)
    }

    func test_productCardTextSpacing_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-text-spacing", cssValue: "10px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTextSpacing, 10)
    }

    func test_productCardTextTopPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-text-top-padding", cssValue: "24px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTextTopPadding, 24)
    }

    func test_productCardTextBottomPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-text-bottom-padding", cssValue: "14px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTextBottomPadding, 14)
    }

    func test_productCardTextHorizontalPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-text-horizontal-padding", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardTextHorizontalPadding, 16)
    }

    func test_productCardCarouselSpacing_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-carousel-spacing", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardCarouselSpacing, 16)
    }

    func test_productCardCarouselHorizontalPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "product-card-carousel-horizontal-padding", cssValue: "8px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.productCardCarouselHorizontalPadding, 8)
    }

    // MARK: - CTA Button Color Mapping Tests

    func test_ctaButtonBackgroundColor_mapsToCtaButtonColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-background-color", cssValue: "#EDEDED", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.ctaButton.background.color.toHexString(), "#EDEDED")
    }

    func test_ctaButtonTextColor_mapsToCtaButtonColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-text-color", cssValue: "#191F1C", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.ctaButton.text.color.toHexString(), "#191F1C")
    }

    func test_ctaButtonIconColor_mapsToCtaButtonColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-icon-color", cssValue: "#161313", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.ctaButton.iconColor.color.toHexString(), "#161313")
    }

    // MARK: - CTA Button Layout Mapping Tests

    func test_ctaButtonBorderRadius_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-border-radius", cssValue: "99px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonBorderRadius, 99)
    }

    func test_ctaButtonHorizontalPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-horizontal-padding", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonHorizontalPadding, 16)
    }

    func test_ctaButtonVerticalPadding_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-vertical-padding", cssValue: "12px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonVerticalPadding, 12)
    }

    func test_ctaButtonFontSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-font-size", cssValue: "14px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonFontSize, 14)
    }

    func test_ctaButtonFontWeight_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-font-weight", cssValue: "400", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonFontWeight, .regular)
    }

    func test_ctaButtonIconSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "cta-button-icon-size", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.ctaButtonIconSize, 16)
    }

    // MARK: - Agent Icon Layout Mapping Tests

    func test_agentIconSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--agent-icon-size", cssValue: "44px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.agentIconSize, CGFloat(44))
    }

    func test_agentIconSpacing_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--agent-icon-spacing", cssValue: "8px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.agentIconSpacing, CGFloat(8))
    }

    // MARK: - Thinking Animation Color Mapping Tests

    func test_thinkingDotColor_mapsToThinkingColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-color", cssValue: "#006554", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.thinking.dotColor?.color.toHexString(), "#006554")
    }

    func test_thinkingDotColor_doesNotAffectOtherColors() {
        // Given
        var theme = ConciergeTheme()
        CSSKeyMapper.apply(cssKey: "color-primary", cssValue: "#007BFF", to: &theme)

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-color", cssValue: "#006554", to: &theme)

        // Then
        XCTAssertEqual(theme.colors.primary.primary.color.toHexString(), "#007BFF")
        XCTAssertEqual(theme.colors.thinking.dotColor?.color.toHexString(), "#006554")
    }

    // MARK: - Thinking Animation Layout Mapping Tests

    func test_thinkingDotSize_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-size", cssValue: "10px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotSize, 10)
    }

    func test_thinkingDotSpacing_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-spacing", cssValue: "6px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotSpacing, 6)
    }

    func test_thinkingBubbleBorderRadius_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-bubble-border-radius", cssValue: "16px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingBubbleBorderRadius, 16)
    }

    func test_thinkingBubblePaddingHorizontal_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-bubble-padding-horizontal", cssValue: "14px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingBubblePaddingHorizontal, 14)
    }

    func test_thinkingBubblePaddingVertical_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-bubble-padding-vertical", cssValue: "12px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingBubblePaddingVertical, 12)
    }

    func test_thinkingDotVerticalAlignment_center_mapsToEnum() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-vertical-alignment", cssValue: "center", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotVerticalAlignment, .center)
    }

    func test_thinkingDotVerticalAlignment_top_mapsToEnum() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-vertical-alignment", cssValue: "top", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotVerticalAlignment, .top)
    }

    func test_thinkingDotVerticalAlignment_bottom_mapsToEnum() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-vertical-alignment", cssValue: "bottom", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotVerticalAlignment, .bottom)
    }

    func test_thinkingDotVerticalAlignment_uppercased_isCaseInsensitive() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-vertical-alignment", cssValue: "TOP", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.thinkingDotVerticalAlignment, .top)
    }

    func test_thinkingDotVerticalAlignment_invalid_mapsToNil() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "thinking-dot-vertical-alignment", cssValue: "left", to: &theme)

        // Then
        XCTAssertNil(theme.layout.thinkingDotVerticalAlignment)
    }

    // MARK: - Prompt Suggestions CSS Key Tests

    func test_colorContainer_mapsToColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--color-container", cssValue: "#F0F0F0", to: &theme)

        // Then
        XCTAssertNotNil(theme.colors.primary.container)
    }

    func test_suggestionBackgroundColor_mapsToColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--suggestion-background-color", cssValue: "#F0F0F0", to: &theme)

        // Then
        XCTAssertNotNil(theme.colors.promptSuggestion.backgroundColor)
    }

    func test_suggestionTextColor_mapsToColors() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--suggestion-text-color", cssValue: "#131313", to: &theme)

        // Then
        XCTAssertNotNil(theme.colors.promptSuggestion.textColor)
    }

    func test_suggestionItemBorderRadius_mapsToLayout() {
        // Given
        var theme = ConciergeTheme()

        // When
        CSSKeyMapper.apply(cssKey: "--suggestion-item-border-radius", cssValue: "10px", to: &theme)

        // Then
        XCTAssertEqual(theme.layout.suggestionItemBorderRadius, 10)
    }
}

