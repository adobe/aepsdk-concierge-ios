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
import SwiftUI
@testable import AEPBrandConcierge

final class ColorExtensionTests: XCTestCase {

    // MARK: - toHexString Round trip tests

    func test_toHexString_opaqueColor_outputsSixCharHex() {
        let color = Color.fromHexString("#FF5733")
        XCTAssertEqual(color.toHexString(), "#FF5733")
    }

    func test_toHexString_black_roundTripsCorrectly() {
        let color = Color.fromHexString("#000000")
        XCTAssertEqual(color.toHexString(), "#000000")
    }

    func test_toHexString_white_roundTripsCorrectly() {
        let color = Color.fromHexString("#FFFFFF")
        XCTAssertEqual(color.toHexString(), "#FFFFFF")
    }

    func test_toHexString_lowValues_roundTripCorrectly() {
        let color = Color.fromHexString("#131313")
        XCTAssertEqual(color.toHexString(), "#131313")
    }

    func test_toHexString_mixedComponents_roundTripCorrectly() {
        let color = Color.fromHexString("#3B63FB")
        XCTAssertEqual(color.toHexString(), "#3B63FB")
    }

    func test_toHexString_preservesSRGBColorSpace() {
        let color = Color(.sRGB, red: 0.2, green: 0.4, blue: 0.6)
        let hex = color.toHexString()
        let roundTripped = Color.fromHexString(hex)
        XCTAssertEqual(roundTripped.toHexString(), hex)
    }

    // MARK: - Alpha output tests

    func test_toHexString_fullyOpaque_omitsAlpha() {
        let color = Color.fromHexString("#AA33CCFF")
        let hex = color.toHexString()
        XCTAssertEqual(hex, "#AA33CC")
        XCTAssertEqual(hex.count, 7)
    }

    func test_toHexString_halfTransparent_includesAlpha() {
        let color = Color.fromHexString("#FF000080")
        let hex = color.toHexString()
        XCTAssertEqual(hex, "#FF000080")
        XCTAssertEqual(hex.count, 9)
    }

    func test_toHexString_fullyTransparent_includesAlpha() {
        let color = Color.fromHexString("#12345600")
        let hex = color.toHexString()
        XCTAssertTrue(hex.hasSuffix("00"), "Fully transparent should end with 00, got \(hex)")
        XCTAssertEqual(hex.count, 9)
    }

    func test_toHexString_nearlyOpaque_includesAlpha() {
        let color = Color.fromHexString("#ABCDEFEE")
        let hex = color.toHexString()
        XCTAssertEqual(hex, "#ABCDEFEE")
        XCTAssertEqual(hex.count, 9)
    }

    func test_toHexString_alphaRoundTrips_throughFromHexString() {
        let original = "#4A74FF80"
        let color = Color.fromHexString(original)
        XCTAssertEqual(color.toHexString(), original)
    }

    // MARK: - fromHexString -> toHexString symmetry

    func test_fromHexString_sixChar_toHexString_roundTrips() {
        let inputs = ["#007BFF", "#191F1C", "#4B4B4B", "#EDEDED", "#161313", "#292929", "#6E6E6E"]
        for input in inputs {
            let result = Color.fromHexString(input).toHexString()
            XCTAssertEqual(result, input, "Round trip failed for \(input)")
        }
    }

    func test_fromHexString_eightChar_toHexString_roundTrips() {
        let inputs = ["#007BFF80", "#FF0000CC", "#00000029"]
        for input in inputs {
            let result = Color.fromHexString(input).toHexString()
            XCTAssertEqual(result, input, "Round trip failed for \(input)")
        }
    }

    // MARK: - Edge cases

    func test_toHexString_colorFromHexInit_roundTrips() {
        let color = Color(hex: 0xEB1000)
        XCTAssertEqual(color.toHexString(), "#EB1000")
    }

    func test_toHexString_colorFromHexInit_withAlpha_includesAlpha() {
        let color = Color(hex: 0xFF0000, alpha: 0.5)
        let hex = color.toHexString()
        XCTAssertTrue(hex.hasPrefix("#FF0000"), "RGB portion should be FF0000, got \(hex)")
        XCTAssertEqual(hex.count, 9, "Should include alpha bytes")
    }

    func test_toHexString_clearColor_outputsTransparent() {
        let hex = Color.clear.toHexString()
        XCTAssertTrue(hex.hasSuffix("00"), "Clear color should have 00 alpha, got \(hex)")
    }
}
