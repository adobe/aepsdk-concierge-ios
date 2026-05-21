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

final class ConciergeHeaderConfigTests: XCTestCase {

    // MARK: - Default Init

    func test_defaultInit_hasExpectedDefaults() {
        let config = ConciergeHeaderConfig()

        XCTAssertEqual(config.title, "")
        XCTAssertEqual(config.subtitle, "")
        XCTAssertEqual(config.image, "")
        XCTAssertEqual(config.layoutType, .textOnly)
        XCTAssertEqual(config.imageHeight, 48)
    }

    // MARK: - Decoding with all fields

    func test_decode_allFields() throws {
        let json = """
        {
            "title": "My Brand",
            "subtitle": "Tagline",
            "image": "logo",
            "layoutType": "imageOnly",
            "imageHeight": 64
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.title, "My Brand")
        XCTAssertEqual(config.subtitle, "Tagline")
        XCTAssertEqual(config.image, "logo")
        XCTAssertEqual(config.layoutType, .imageOnly)
        XCTAssertEqual(config.imageHeight, 64)
    }

    // MARK: - Decoding with missing fields falls back to defaults

    func test_decode_emptyObject_usesDefaults() throws {
        let json = "{}"
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.title, "")
        XCTAssertEqual(config.subtitle, "")
        XCTAssertEqual(config.image, "")
        XCTAssertEqual(config.layoutType, .textOnly)
        XCTAssertEqual(config.imageHeight, 48)
    }

    func test_decode_missingImageHeight_defaultsTo48() throws {
        let json = """
        {
            "image": "logo",
            "layoutType": "imageOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.imageHeight, 48)
    }

    func test_decode_customImageHeight() throws {
        let json = """
        {
            "imageHeight": 100
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.imageHeight, 100)
    }

    func test_decode_missingLayoutType_defaultsToTextOnly() throws {
        let json = """
        {
            "title": "Test",
            "subtitle": "Sub"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.layoutType, .textOnly)
    }

    func test_decode_missingImage_defaultsToEmpty() throws {
        let json = """
        {
            "title": "Test",
            "layoutType": "textOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.image, "")
    }

    // MARK: - layoutType values

    func test_decode_layoutType_imageOnly() throws {
        let json = """
        {
            "image": "logo",
            "layoutType": "imageOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.layoutType, .imageOnly)
        XCTAssertEqual(config.image, "logo")
    }

    func test_decode_layoutType_textOnly() throws {
        let json = """
        {
            "title": "Brand",
            "subtitle": "Tagline",
            "layoutType": "textOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.layoutType, .textOnly)
        XCTAssertEqual(config.title, "Brand")
        XCTAssertEqual(config.subtitle, "Tagline")
    }

    // MARK: - Blank title/subtitle with textOnly

    func test_decode_blankTitleSubtitle_textOnly() throws {
        let json = """
        {
            "title": "",
            "subtitle": "",
            "layoutType": "textOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.title, "")
        XCTAssertEqual(config.subtitle, "")
        XCTAssertEqual(config.layoutType, .textOnly)
    }

    // MARK: - imageOnly ignores title/subtitle at config level

    func test_decode_imageOnly_withTitleSubtitle_stillDecodesAll() throws {
        let json = """
        {
            "title": "Should be ignored",
            "subtitle": "Also ignored",
            "image": "logo",
            "layoutType": "imageOnly"
        }
        """
        let config = try JSONDecoder().decode(ConciergeHeaderConfig.self, from: Data(json.utf8))

        // Config stores all values; the view layer decides what to show
        XCTAssertEqual(config.title, "Should be ignored")
        XCTAssertEqual(config.subtitle, "Also ignored")
        XCTAssertEqual(config.image, "logo")
        XCTAssertEqual(config.layoutType, .imageOnly)
    }

    // MARK: - Theme-level header decoding

    func test_theme_decode_withHeader() throws {
        let json = """
        {
            "metadata": {
                "brandName": "Test",
                "version": "1.0",
                "language": "en",
                "namespace": "test"
            },
            "header": {
                "title": "Chat",
                "subtitle": "Powered by AI",
                "image": "brand_logo",
                "layoutType": "imageOnly"
            }
        }
        """
        let theme = try JSONDecoder().decode(ConciergeTheme.self, from: Data(json.utf8))

        XCTAssertEqual(theme.header.title, "Chat")
        XCTAssertEqual(theme.header.subtitle, "Powered by AI")
        XCTAssertEqual(theme.header.image, "brand_logo")
        XCTAssertEqual(theme.header.layoutType, .imageOnly)
        XCTAssertEqual(theme.header.imageHeight, 48)
    }

    func test_theme_decode_withoutHeader_usesDefaults() throws {
        let json = """
        {
            "metadata": {
                "brandName": "Test",
                "version": "1.0",
                "language": "en",
                "namespace": "test"
            }
        }
        """
        let theme = try JSONDecoder().decode(ConciergeTheme.self, from: Data(json.utf8))

        XCTAssertEqual(theme.header.title, "")
        XCTAssertEqual(theme.header.subtitle, "")
        XCTAssertEqual(theme.header.image, "")
        XCTAssertEqual(theme.header.layoutType, .textOnly)
        XCTAssertEqual(theme.header.imageHeight, 48)
    }
}
