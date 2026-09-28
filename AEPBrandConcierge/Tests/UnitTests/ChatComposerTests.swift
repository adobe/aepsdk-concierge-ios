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

import SwiftUI
import XCTest
@testable import AEPBrandConcierge

final class ChatComposerTests: XCTestCase {

    // MARK: - focusOutlineStyle

    func test_focusOutlineStyle_gradientBorder_keepsGradientWhileFocused() {
        // Regression test for the focus ring flattening a gradient border: the focused outline is
        // stroked over the base border, so resolving it to the solid --input-focus-outline-color
        // would erase the gradient the theme asked for.
        // Given
        let gradient = ConciergeGradient(
            startColor: CodableColor(Color(hex: 0x4DAF90)),
            endColor: CodableColor(Color(hex: 0x006554)),
            angle: 180
        )
        let border = ConciergeBorderStyle(width: 2, color: CodableColor(Color(hex: 0x4DAF90)), gradient: gradient)

        // When
        let resolved = ChatComposer.focusOutlineStyle(border: border, focusColor: CodableColor(Color(hex: 0x000000)))

        // Then
        XCTAssertEqual(resolved, .gradient(gradient))
    }

    func test_focusOutlineStyle_solidBorder_stillUsesFocusOutlineColor() {
        // Themes without a border gradient must keep the previous focus behavior.
        // Given
        let focusColor = CodableColor(Color(hex: 0x006554))
        let border = ConciergeBorderStyle(width: 2, color: CodableColor(Color(hex: 0x4DAF90)), gradient: nil)

        // When
        let resolved = ChatComposer.focusOutlineStyle(border: border, focusColor: focusColor)

        // Then
        XCTAssertEqual(resolved, .color(focusColor))
    }

    func test_focusOutlineStyle_halfConfiguredBorderGradient_fallsBackToFocusColor() {
        // A gradient missing one side isn't renderable, so it must not win over the focus color
        // and paint a half-clear ring.
        // Given
        let focusColor = CodableColor(Color(hex: 0x006554))
        let halfGradient = ConciergeGradient(
            startColor: CodableColor(Color(hex: 0x4DAF90)),
            endColor: CodableColor(.clear),
            angle: 180
        )
        let border = ConciergeBorderStyle(width: 2, color: CodableColor(Color(hex: 0x4DAF90)), gradient: halfGradient)

        // When
        let resolved = ChatComposer.focusOutlineStyle(border: border, focusColor: focusColor)

        // Then
        XCTAssertEqual(resolved, .color(focusColor))
    }

}
