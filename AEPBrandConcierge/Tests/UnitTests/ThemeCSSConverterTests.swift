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
import SwiftUI
@testable import AEPBrandConcierge

final class ThemeCSSConverterTests: XCTestCase {
    
    // MARK: - parseBoxShadow Tests
    
    func test_parseBoxShadow_validShadow_returnsCorrectValues() {
        // Given
        let cssValue = "0 4px 16px 0 #00000029"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertEqual(shadow.offsetX, CGFloat(0))
        XCTAssertEqual(shadow.offsetY, CGFloat(4))
        XCTAssertEqual(shadow.blurRadius, CGFloat(16))
        XCTAssertEqual(shadow.spreadRadius, CGFloat(0))
        XCTAssertTrue(shadow.isEnabled)
        XCTAssertEqual(shadow.color.color.toHexString(), "#00000029")
    }
    
    func test_parseBoxShadow_none_returnsDisabledShadow() {
        // Given
        let cssValue = "none"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertEqual(shadow, .none)
        XCTAssertFalse(shadow.isEnabled)
    }
    
    func test_parseBoxShadow_noneCaseInsensitive_returnsDisabledShadow() {
        // Given
        let cssValue = "NONE"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertFalse(shadow.isEnabled)
    }
    
    func test_parseBoxShadow_missingColor_usesDefaultColor() {
        // Given
        let cssValue = "0 4px 16px 0"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertEqual(shadow.offsetX, CGFloat(0))
        XCTAssertEqual(shadow.offsetY, CGFloat(4))
        XCTAssertEqual(shadow.blurRadius, CGFloat(16))
        XCTAssertEqual(shadow.spreadRadius, CGFloat(0))
        XCTAssertEqual(shadow.color.color.toHexString(), "#000000")
    }
    
    func test_parseBoxShadow_missingSpreadRadius_usesZero() {
        // Given
        let cssValue = "0 4px 16px #000000"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertEqual(shadow.spreadRadius, CGFloat(0))
    }
    
    func test_parseBoxShadow_tooFewComponents_returnsNone() {
        // Given
        let cssValue = "0 4px"
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertFalse(shadow.isEnabled)
    }
    
    func test_parseBoxShadow_emptyString_returnsNone() {
        // Given
        let cssValue = ""
        
        // When
        let shadow = CSSValueConverter.parseBoxShadow(cssValue)
        
        // Then
        XCTAssertFalse(shadow.isEnabled)
    }
    
    // MARK: - parsePadding Tests
    
    func test_parsePadding_singleValue_setsAllSidesEqual() {
        // Given
        let cssValue = "8px"
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(8))
        XCTAssertEqual(padding.bottom, CGFloat(8))
        XCTAssertEqual(padding.leading, CGFloat(8))
        XCTAssertEqual(padding.trailing, CGFloat(8))
    }
    
    func test_parsePadding_twoValues_setsVerticalAndHorizontal() {
        // Given
        let cssValue = "8px 16px"
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(8))
        XCTAssertEqual(padding.bottom, CGFloat(8))
        XCTAssertEqual(padding.leading, CGFloat(16))
        XCTAssertEqual(padding.trailing, CGFloat(16))
    }
    
    func test_parsePadding_threeValues_setsTopHorizontalBottom() {
        // Given
        let cssValue = "8px 16px 4px"
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(8))
        XCTAssertEqual(padding.bottom, CGFloat(4))
        XCTAssertEqual(padding.leading, CGFloat(16))
        XCTAssertEqual(padding.trailing, CGFloat(16))
    }
    
    func test_parsePadding_fourValues_setsTopRightBottomLeft() {
        // Given
        let cssValue = "8px 16px 4px 2px"
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(8))
        XCTAssertEqual(padding.bottom, CGFloat(4))
        XCTAssertEqual(padding.leading, CGFloat(2))
        XCTAssertEqual(padding.trailing, CGFloat(16))
    }
    
    func test_parsePadding_emptyString_returnsZeroPadding() {
        // Given
        let cssValue = ""
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(0))
        XCTAssertEqual(padding.bottom, CGFloat(0))
        XCTAssertEqual(padding.leading, CGFloat(0))
        XCTAssertEqual(padding.trailing, CGFloat(0))
    }
    
    func test_parsePadding_invalidValues_returnsZeroPadding() {
        // Given
        let cssValue = "invalid"
        
        // When
        let padding = CSSValueConverter.parsePadding(cssValue)
        
        // Then
        XCTAssertEqual(padding.top, CGFloat(0))
    }
    
    // MARK: - parsePxValue Tests
    
    func test_parsePxValue_validPxValue_returnsCGFloat() throws {
        // Given
        let cssValue = "52px"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePxValue(cssValue))
        
        // Then
        XCTAssertEqual(value, 52, accuracy: 0.0001)
    }
    
    func test_parsePxValue_caseInsensitive_works() throws {
        // Given
        let cssValue = "52PX"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePxValue(cssValue))
        
        // Then
        XCTAssertEqual(value, 52, accuracy: 0.0001)
    }
    
    func test_parsePxValue_decimalValue_works() throws {
        // Given
        let cssValue = "12.5px"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePxValue(cssValue))
        
        // Then
        XCTAssertEqual(value, 12.5, accuracy: 0.0001)
    }
    
    func test_parsePxValue_invalidFormat_returnsZero() throws {
        // Given
        let cssValue = "invalid"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePxValue(cssValue))
        
        // Then
        XCTAssertEqual(value, 0, accuracy: 0.0001)
    }
    
    func test_parsePxValue_emptyString_returnsZero() throws {
        // Given
        let cssValue = ""
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePxValue(cssValue))
        
        // Then
        XCTAssertEqual(value, 0, accuracy: 0.0001)
    }
    
    // MARK: - parsePercentage Tests
    
    func test_parsePercentage_100Percent_returnsNil() {
        // Given
        let cssValue = "100%"
        
        // When
        let value = CSSValueConverter.parsePercentage(cssValue)
        
        // Then
        XCTAssertNil(value)
    }
    
    func test_parsePercentage_50Percent_returnsHalf() throws {
        // Given
        let cssValue = "50%"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePercentage(cssValue))
        
        // Then
        XCTAssertEqual(value, 0.5, accuracy: 0.0001)
    }
    
    func test_parsePercentage_0Percent_returnsZero() throws {
        // Given
        let cssValue = "0%"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parsePercentage(cssValue))
        
        // Then
        XCTAssertEqual(value, 0, accuracy: 0.0001)
    }
    
    func test_parsePercentage_over100Percent_returnsNil() {
        // Given
        let cssValue = "150%"
        
        // When
        let value = CSSValueConverter.parsePercentage(cssValue)
        
        // Then
        XCTAssertNil(value)
    }
    
    func test_parsePercentage_invalidFormat_returnsNil() {
        // Given
        let cssValue = "invalid"
        
        // When
        let value = CSSValueConverter.parsePercentage(cssValue)
        
        // Then
        XCTAssertNil(value)
    }
    
    // MARK: - parseWidth Tests
    
    func test_parseWidth_100Percent_returnsNil() {
        // Given
        let cssValue = "100%"
        
        // When
        let value = CSSValueConverter.parseWidth(cssValue)
        
        // Then
        XCTAssertNil(value)
    }
    
    func test_parseWidth_pxValue_returnsCGFloat() throws {
        // Given
        let cssValue = "768px"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parseWidth(cssValue))
        
        // Then
        XCTAssertEqual(value, 768, accuracy: 0.0001)
    }
    
    func test_parseWidth_numericString_returnsCGFloat() throws {
        // Given
        let cssValue = "500"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parseWidth(cssValue))
        
        // Then
        XCTAssertEqual(value, 500, accuracy: 0.0001)
    }
    
    func test_parseWidth_50Percent_returnsDecimal() throws {
        // Given
        let cssValue = "50%"
        
        // When
        let value = try XCTUnwrap(CSSValueConverter.parseWidth(cssValue))
        
        // Then
        XCTAssertEqual(value, 0.5, accuracy: 0.0001)
    }
    
    // MARK: - parseColor Tests
    
    func test_parseColor_validHex_returnsCodableColor() {
        // Given
        let cssValue = "#007BFF"
        
        // When
        let color = CSSValueConverter.parseColor(cssValue)
        
        // Then
        XCTAssertEqual(color.color.toHexString(), "#007BFF")
    }
    
    func test_parseColor_whiteHex_returnsWhite() {
        // Given
        let cssValue = "#FFFFFF"
        
        // When
        let color = CSSValueConverter.parseColor(cssValue)
        
        // Then
        XCTAssertEqual(color.color.toHexString(), "#FFFFFF")
    }
    
    func test_parseColor_invalidHex_usesDefault() {
        // Given
        let cssValue = "#INVALID"
        
        // When
        let color = CSSValueConverter.parseColor(cssValue)
        
        // Then
        // Should fallback to system background color
        let expectedHex = Color(UIColor.systemBackground).toHexString()
        XCTAssertEqual(color.color.toHexString(), expectedHex)
    }

    // MARK: - parseGradientAngle Tests

    func test_parseGradientAngle_degreesValue_returnsDegrees() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("90deg"), 90)
    }

    func test_parseGradientAngle_toRightKeyword_returns90() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("to right"), 90)
    }

    func test_parseGradientAngle_toTopKeyword_returns0() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("to top"), 0)
    }

    func test_parseGradientAngle_toTopRightKeyword_returns45() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("to top right"), 45)
    }

    func test_parseGradientAngle_unrecognized_defaultsTo180() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("sideways"), 180)
    }

    func test_parseGradientAngle_nanDeg_defaultsTo180() {
        // Regression test: Double(_:) follows strtod conventions, so "nandeg" parses "successfully"
        // to Double.nan -- must not propagate a non-finite value into ConciergeGradient's sin/cos math.
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("nandeg"), 180)
    }

    func test_parseGradientAngle_infinityDeg_defaultsTo180() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("infinitydeg"), 180)
    }

    func test_parseGradientAngle_hugeExponentDeg_defaultsTo180() {
        XCTAssertEqual(CSSValueConverter.parseGradientAngle("1e400deg"), 180)
    }

    // MARK: - parseFontWeight Tests
    
    func test_parseFontWeight_400_returnsRegular() {
        // Given
        let cssValue = "400"
        
        // When
        let weight = CSSValueConverter.parseFontWeight(cssValue)
        
        // Then
        XCTAssertEqual(weight, .regular)
    }
    
    func test_parseFontWeight_700_returnsBold() {
        // Given
        let cssValue = "700"
        
        // When
        let weight = CSSValueConverter.parseFontWeight(cssValue)
        
        // Then
        XCTAssertEqual(weight, .bold)
    }
    
    func test_parseFontWeight_normal_returnsRegular() {
        // Given
        let cssValue = "normal"
        
        // When
        let weight = CSSValueConverter.parseFontWeight(cssValue)
        
        // Then
        XCTAssertEqual(weight, .regular)
    }
    
    func test_parseFontWeight_bold_returnsBold() {
        // Given
        let cssValue = "bold"
        
        // When
        let weight = CSSValueConverter.parseFontWeight(cssValue)
        
        // Then
        XCTAssertEqual(weight, .bold)
    }
    
    func test_parseFontWeight_allWeightCases() {
        XCTAssertEqual(CSSValueConverter.parseFontWeight("100"), .ultraLight)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("200"), .thin)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("300"), .light)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("400"), .regular)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("500"), .medium)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("600"), .semibold)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("700"), .bold)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("800"), .heavy)
        XCTAssertEqual(CSSValueConverter.parseFontWeight("900"), .black)
    }
    
    func test_parseFontWeight_invalid_returnsRegular() {
        // Given
        let cssValue = "invalid"
        
        // When
        let weight = CSSValueConverter.parseFontWeight(cssValue)
        
        // Then
        XCTAssertEqual(weight, .regular)
    }
    
    // MARK: - parseTextAlignment Tests
    
    func test_parseTextAlignment_left_returnsLeading() {
        // Given
        let cssValue = "left"
        
        // When
        let alignment = CSSValueConverter.parseTextAlignment(cssValue)
        
        // Then
        XCTAssertEqual(alignment, .leading)
    }
    
    func test_parseTextAlignment_right_returnsTrailing() {
        // Given
        let cssValue = "right"
        
        // When
        let alignment = CSSValueConverter.parseTextAlignment(cssValue)
        
        // Then
        XCTAssertEqual(alignment, .trailing)
    }
    
    func test_parseTextAlignment_center_returnsCenter() {
        // Given
        let cssValue = "center"
        
        // When
        let alignment = CSSValueConverter.parseTextAlignment(cssValue)
        
        // Then
        XCTAssertEqual(alignment, .center)
    }
    
    func test_parseTextAlignment_justify_returnsCenter() {
        // Given
        let cssValue = "justify"

        // When
        let alignment = CSSValueConverter.parseTextAlignment(cssValue)

        // Then
        XCTAssertEqual(alignment, .center)
    }

    func test_parseTextAlignment_leading_returnsLeading() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("leading"), .leading)
    }

    func test_parseTextAlignment_trailing_returnsTrailing() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("trailing"), .trailing)
    }

    func test_parseTextAlignment_start_returnsLeading() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("start"), .leading)
    }

    func test_parseTextAlignment_end_returnsTrailing() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("end"), .trailing)
    }

    func test_parseTextAlignment_invalid_returnsLeading() {
        // Given
        let cssValue = "invalid"

        // When
        let alignment = CSSValueConverter.parseTextAlignment(cssValue)

        // Then
        XCTAssertEqual(alignment, .leading)
    }

    func test_parseTextAlignment_caseInsensitive_works() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("LEFT"), .leading)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("RIGHT"), .trailing)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("CENTER"), .center)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("Leading"), .leading)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("TRAILING"), .trailing)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("Start"), .leading)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("END"), .trailing)
    }

    func test_parseTextAlignment_whitespace_isTrimmed() {
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("  center  "), .center)
        XCTAssertEqual(CSSValueConverter.parseTextAlignment("\tleft\n"), .leading)
    }
    
    // MARK: - parseOrder Tests
    
    func test_parseOrder_validNumber_returnsInt() {
        // Given
        let cssValue = "3"
        
        // When
        let order = CSSValueConverter.parseOrder(cssValue)
        
        // Then
        XCTAssertEqual(order, 3)
    }
    
    func test_parseOrder_invalid_returnsZero() {
        // Given
        let cssValue = "invalid"
        
        // When
        let order = CSSValueConverter.parseOrder(cssValue)
        
        // Then
        XCTAssertEqual(order, 0)
    }
    
    func test_parseOrder_emptyString_returnsZero() {
        // Given
        let cssValue = ""
        
        // When
        let order = CSSValueConverter.parseOrder(cssValue)
        
        // Then
        XCTAssertEqual(order, 0)
    }
    
    // MARK: - parseFontFamily Tests
    
    func test_parseFontFamily_fontStack_returnsFirstFont() {
        // Given
        let cssValue = "'Adobe Clean', adobe-clean, 'Trebuchet MS', sans-serif"
        
        // When
        let fontFamily = CSSValueConverter.parseFontFamily(cssValue)
        
        // Then
        XCTAssertEqual(fontFamily, "Adobe Clean")
    }
    
    func test_parseFontFamily_singleFont_returnsFont() {
        // Given
        let cssValue = "Arial"
        
        // When
        let fontFamily = CSSValueConverter.parseFontFamily(cssValue)
        
        // Then
        XCTAssertEqual(fontFamily, "Arial")
    }
    
    func test_parseFontFamily_emptyString_returnsEmpty() {
        // Given
        let cssValue = ""
        
        // When
        let fontFamily = CSSValueConverter.parseFontFamily(cssValue)
        
        // Then
        XCTAssertEqual(fontFamily, "")
    }
    
    func test_parseFontFamily_withoutQuotes_works() {
        // Given
        let cssValue = "Arial, sans-serif"
        
        // When
        let fontFamily = CSSValueConverter.parseFontFamily(cssValue)
        
        // Then
        XCTAssertEqual(fontFamily, "Arial")
    }
    
    // MARK: - parseLineHeight Tests
    
    func test_parseLineHeight_unitless_returnsRatio() {
        // Given
        let cssValue = "1.75"
        
        // When
        let lineHeight = CSSValueConverter.parseLineHeight(cssValue)
        
        // Then
        XCTAssertEqual(lineHeight, 1.75, accuracy: 0.0001)
    }
    
    func test_parseLineHeight_withPx_returnsPxValue() {
        // Given
        let cssValue = "24px"
        
        // When
        let lineHeight = CSSValueConverter.parseLineHeight(cssValue)
        
        // Then
        XCTAssertEqual(lineHeight, 24, accuracy: 0.0001)
    }
    
    func test_parseLineHeight_invalid_returnsDefault() {
        // Given
        let cssValue = "invalid"
        
        // When
        let lineHeight = CSSValueConverter.parseLineHeight(cssValue)
        
        // Then
        XCTAssertEqual(lineHeight, 1.75, accuracy: 0.0001)
    }
    
    func test_parseLineHeight_emptyString_returnsDefault() {
        // Given
        let cssValue = ""

        // When
        let lineHeight = CSSValueConverter.parseLineHeight(cssValue)

        // Then
        XCTAssertEqual(lineHeight, 1.75, accuracy: 0.0001)
    }

    // MARK: - ConciergeGradient Tests

    func test_conciergeGradient_unitPoints_angle0_pointsUp() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue), angle: 0)
        let points = gradient.unitPoints
        XCTAssertEqual(points.start.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.start.y, 1.0, accuracy: 0.0001)
        XCTAssertEqual(points.end.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.end.y, 0.0, accuracy: 0.0001)
    }

    func test_conciergeGradient_unitPoints_angle90_pointsRight() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue), angle: 90)
        let points = gradient.unitPoints
        XCTAssertEqual(points.start.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(points.start.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.end.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(points.end.y, 0.5, accuracy: 0.0001)
    }

    func test_conciergeGradient_unitPoints_angle180_pointsDown() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue), angle: 180)
        let points = gradient.unitPoints
        XCTAssertEqual(points.start.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.start.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(points.end.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.end.y, 1.0, accuracy: 0.0001)
    }

    func test_conciergeGradient_unitPoints_angle270_pointsLeft() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue), angle: 270)
        let points = gradient.unitPoints
        XCTAssertEqual(points.start.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(points.start.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(points.end.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(points.end.y, 0.5, accuracy: 0.0001)
    }

    func test_conciergeGradient_defaultAngle_isOneEighty() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue))
        XCTAssertEqual(gradient.angle, 180)
    }

    func test_conciergeGradient_linearGradient_doesNotCrashAndIsUsable() {
        // linearGradient wraps SwiftUI's opaque LinearGradient (no public accessors to assert on directly);
        // this exercises construction end-to-end. The angle math itself is covered above via unitPoints.
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue), angle: 45)
        _ = gradient.linearGradient
    }

    func test_conciergeGradient_isRenderable_bothColorsReal_isTrue() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue))
        XCTAssertTrue(gradient.isRenderable)
    }

    func test_conciergeGradient_isRenderable_startClear_isFalse() {
        let gradient = ConciergeGradient(startColor: CodableColor(.clear), endColor: CodableColor(.blue))
        XCTAssertFalse(gradient.isRenderable)
    }

    func test_conciergeGradient_isRenderable_endClear_isFalse() {
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.clear))
        XCTAssertFalse(gradient.isRenderable)
    }

    // MARK: - resolveConciergeStyle / conciergeShapeStyle Tests

    func test_resolveConciergeStyle_renderableGradientSet_prefersGradientOverColor() {
        // Regression test: conciergeShapeStyle/resolveConciergeStyle must prefer a *renderable*
        // gradient over a solid color, but never a partially-built (single-side-clear) one.
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue))
        let resolved = resolveConciergeStyle(color: CodableColor(.green), gradient: gradient)
        XCTAssertEqual(resolved, .gradient(gradient))
    }

    func test_resolveConciergeStyle_gradientNotRenderable_fallsBackToColor() {
        // Regression test for the "one CSS key set, other defaults to clear" bug: a gradient with
        // only one real color must NOT render as a (partially invisible) gradient -- it should fall
        // back to the solid color exactly as if no gradient had been set at all.
        let partialGradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.clear))
        let resolved = resolveConciergeStyle(color: CodableColor(.green), gradient: partialGradient)
        XCTAssertEqual(resolved, .color(CodableColor(.green)))
    }

    func test_resolveConciergeStyle_gradientNotRenderableAndNoColor_fallsBackToFallback() {
        let partialGradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.clear))
        let resolved = resolveConciergeStyle(color: nil, gradient: partialGradient)
        XCTAssertEqual(resolved, .fallback)
    }

    func test_resolveConciergeStyle_colorSetNoGradient_choosesColor() {
        let resolved = resolveConciergeStyle(color: CodableColor(.green), gradient: nil)
        XCTAssertEqual(resolved, .color(CodableColor(.green)))
    }

    func test_resolveConciergeStyle_neitherSet_choosesFallback() {
        let resolved = resolveConciergeStyle(color: nil, gradient: nil)
        XCTAssertEqual(resolved, .fallback)
    }

    func test_conciergeShapeStyle_doesNotCrash_forEveryResolutionPath() {
        // conciergeShapeStyle itself wraps opaque SwiftUI types with no introspection API; the actual
        // priority logic is asserted above via resolveConciergeStyle. This just exercises the
        // AnyShapeStyle-wrapping switch end-to-end for each of the 3 paths.
        let gradient = ConciergeGradient(startColor: CodableColor(.red), endColor: CodableColor(.blue))
        _ = conciergeShapeStyle(color: nil, gradient: gradient, fallback: .black)
        _ = conciergeShapeStyle(color: CodableColor(.green), gradient: nil, fallback: .black)
        _ = conciergeShapeStyle(color: nil, gradient: nil, fallback: .black)
    }
}

