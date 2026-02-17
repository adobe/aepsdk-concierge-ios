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
        XCTAssertEqual(theme.colors.primary.text.color.toHexString(), "#121212")
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
        XCTAssertEqual(theme.colors.button.primaryBackground.color.toHexString(), "#3A62FB")
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
        XCTAssertEqual(theme.colors.disclaimer.color.toHexString(), "#4A4A4A")
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
        XCTAssertEqual(theme.colors.input.outline?.color.toHexString(), "#4A74FF")
    }
}

