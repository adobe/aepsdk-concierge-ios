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
@testable import AEPBrandConcierge

final class GeoURLConverterTests: XCTestCase {

    // MARK: - Address-query fallback (geo:0,0?q=…)

    func testConvert_withPlaceholderCoordinates_usesAddressQueryAsDestination() {
        let url = URL(string: "geo:0,0?q=The%20Mall%20At%20Robinson%2C%20Pittsburgh%2C%20PA%2015205-4834")!
        let result = GeoURLConverter.appleMapsDirectionsURL(from: url)
        XCTAssertEqual(
            result?.absoluteString,
            "https://maps.apple.com/?daddr=The%20Mall%20At%20Robinson,%20Pittsburgh,%20PA%2015205-4834"
        )
    }

    func testConvert_withUppercaseGeoScheme_isRecognized() {
        // URI schemes are case-insensitive; the converter lowercases before comparing.
        let url = URL(string: "GEO:0,0?q=Foo%20Bar")!
        XCTAssertEqual(
            GeoURLConverter.appleMapsDirectionsURL(from: url)?.absoluteString,
            "https://maps.apple.com/?daddr=Foo%20Bar"
        )
    }

    func testConvert_addressQuery_isPercentEncodedInDestination() {
        let url = URL(string: "geo:0,0?q=Great%20Southern%20Shopping%20Center%2C%20Bridgeville%2C%20PA%2015017")!
        let result = GeoURLConverter.appleMapsDirectionsURL(from: url)
        // Spaces are re-encoded as %20; the value round-trips to the original address.
        let daddr = URLComponents(url: result!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "daddr" }?.value
        XCTAssertEqual(daddr, "Great Southern Shopping Center, Bridgeville, PA 15017")
    }

    // MARK: - Coordinates (preferred when present)

    func testConvert_withRealCoordinates_prefersCoordinatesOverQuery() {
        let url = URL(string: "geo:37.6788,-122.4567?q=Foo%20Bar")!
        let result = GeoURLConverter.appleMapsDirectionsURL(from: url)
        XCTAssertEqual(result?.absoluteString, "https://maps.apple.com/?daddr=37.6788,-122.4567")
    }

    func testConvert_withCoordinatesOnly_usesCoordinates() {
        let url = URL(string: "geo:40.0,-75.0")!
        let result = GeoURLConverter.appleMapsDirectionsURL(from: url)
        XCTAssertEqual(result?.absoluteString, "https://maps.apple.com/?daddr=40.0,-75.0")
    }

    // MARK: - Non-convertible inputs return nil

    func testConvert_withPlaceholderCoordinatesAndNoQuery_returnsNil() {
        let url = URL(string: "geo:0,0")!
        XCTAssertNil(GeoURLConverter.appleMapsDirectionsURL(from: url))
    }

    func testConvert_withHttpsUrl_returnsNil() {
        let url = URL(string: "https://www.example.com")!
        XCTAssertNil(GeoURLConverter.appleMapsDirectionsURL(from: url))
    }

    func testConvert_withTelUrl_returnsNil() {
        let url = URL(string: "tel:+14127871330")!
        XCTAssertNil(GeoURLConverter.appleMapsDirectionsURL(from: url))
    }

    func testConvert_withAppleMapsUrl_returnsNil_soHandlerDoesNotDoubleConvert() {
        let url = URL(string: "https://maps.apple.com/?daddr=Foo")!
        XCTAssertNil(GeoURLConverter.appleMapsDirectionsURL(from: url))
    }
}
