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

final class ProductCardDataTests: XCTestCase {

    // MARK: - init(entityInfo:element:) — full data

    func test_initFromEntityInfo_mapsAllFieldsCorrectly() throws {
        // Given
        let entityInfo = try decodeEntityInfo("""
        {
            "productName": "Widget Pro",
            "productDescription": "A versatile tool",
            "productPageURL": "https://example.com/products/widget-pro",
            "productImageURL": "https://example.com/images/widget-pro.png",
            "productPrice": "$9.99/mo",
            "productWasPrice": "$14.99/mo",
            "productBadge": "Popular",
            "primary": { "text": "Buy Now", "url": "https://example.com/buy" },
            "secondary": { "text": "Learn More", "url": "https://example.com/learn" }
        }
        """)
        let element = MultimodalElement(thumbnailWidth: 200, thumbnailHeight: 300)

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        if case .remote(let url) = card.imageSource {
            XCTAssertEqual(url?.absoluteString, "https://example.com/images/widget-pro.png")
        } else {
            XCTFail("Expected .remote image source")
        }
        XCTAssertEqual(card.title, "Widget Pro")
        XCTAssertEqual(card.subtitle, "A versatile tool")
        XCTAssertEqual(card.price, "$9.99/mo")
        XCTAssertEqual(card.wasPrice, "$14.99/mo")
        XCTAssertEqual(card.badge, "Popular")
        XCTAssertEqual(card.destinationURL?.absoluteString, "https://example.com/products/widget-pro")
        XCTAssertEqual(card.primaryButton?.text, "Buy Now")
        XCTAssertEqual(card.primaryButton?.url, "https://example.com/buy")
        XCTAssertEqual(card.secondaryButton?.text, "Learn More")
        XCTAssertEqual(card.secondaryButton?.url, "https://example.com/learn")
        XCTAssertEqual(card.imageWidth, 200)
        XCTAssertEqual(card.imageHeight, 300)
    }

    // MARK: - init(entityInfo:element:) — nil / missing fields

    func test_initFromEntityInfo_nilProductName_defaultsToNoTitle() throws {
        // Given
        let entityInfo = try decodeEntityInfo("""
        { "productDescription": "A product" }
        """)
        let element = MultimodalElement()

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        XCTAssertEqual(card.title, "No title")
    }

    func test_initFromEntityInfo_nilImageURL_producesRemoteNil() throws {
        // Given
        let entityInfo = try decodeEntityInfo("{}")
        let element = MultimodalElement()

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        if case .remote(let url) = card.imageSource {
            XCTAssertNil(url)
        } else {
            XCTFail("Expected .remote image source")
        }
    }

    func test_initFromEntityInfo_nilPageURL_destinationIsNil() throws {
        // Given
        let entityInfo = try decodeEntityInfo("{}")
        let element = MultimodalElement()

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        XCTAssertNil(card.destinationURL)
    }

    func test_initFromEntityInfo_allOptionalFieldsNil() throws {
        // Given
        let entityInfo = try decodeEntityInfo("{}")
        let element = MultimodalElement()

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        XCTAssertEqual(card.title, "No title")
        XCTAssertNil(card.subtitle)
        XCTAssertNil(card.price)
        XCTAssertNil(card.wasPrice)
        XCTAssertNil(card.badge)
        XCTAssertNil(card.destinationURL)
        XCTAssertNil(card.primaryButton)
        XCTAssertNil(card.secondaryButton)
        XCTAssertNil(card.imageWidth)
        XCTAssertNil(card.imageHeight)
    }

    func test_initFromEntityInfo_nilThumbnailDimensions_imageWidthAndHeightAreNil() throws {
        // Given
        let entityInfo = try decodeEntityInfo("{}")
        let element = MultimodalElement(thumbnailWidth: nil, thumbnailHeight: nil)

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        XCTAssertNil(card.imageWidth)
        XCTAssertNil(card.imageHeight)
    }

    func test_initFromEntityInfo_invalidURLString_producesNilURL() throws {
        // Given — URL(string:) returns nil for malformed bracket syntax
        let entityInfo = try decodeEntityInfo("""
        {
            "productImageURL": "http://[invalid",
            "productPageURL": ""
        }
        """)
        let element = MultimodalElement()

        // When
        let card = ProductCardData(entityInfo: entityInfo, element: element)

        // Then
        if case .remote(let url) = card.imageSource {
            XCTAssertNil(url)
        } else {
            XCTFail("Expected .remote image source")
        }
        XCTAssertNil(card.destinationURL)
    }

    // MARK: - Helpers

    private func decodeEntityInfo(_ json: String) throws -> EntityInfo {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(EntityInfo.self, from: data)
    }
}
