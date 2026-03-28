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

final class ConversationResponseDecodingTests: XCTestCase {

    // MARK: - EntityInfo decoding

    func test_entityInfo_decodesNewProductFields() throws {
        // Given
        let json = """
        {
            "productName": "Widget Pro",
            "productPrice": "$22.99/mo",
            "productWasPrice": "$31.99/mo",
            "productBadge": "Best Seller"
        }
        """.data(using: .utf8)!

        // When
        let entityInfo = try JSONDecoder().decode(EntityInfo.self, from: json)

        // Then
        XCTAssertEqual(entityInfo.productName, "Widget Pro")
        XCTAssertEqual(entityInfo.productPrice, "$22.99/mo")
        XCTAssertEqual(entityInfo.productWasPrice, "$31.99/mo")
        XCTAssertEqual(entityInfo.productBadge, "Best Seller")
    }

    func test_entityInfo_newFieldsAreOptional_missingFieldsDecodeAsNil() throws {
        // Given — no price/badge fields present
        let json = """
        {
            "productName": "Gadget Basic"
        }
        """.data(using: .utf8)!

        // When
        let entityInfo = try JSONDecoder().decode(EntityInfo.self, from: json)

        // Then
        XCTAssertEqual(entityInfo.productName, "Gadget Basic")
        XCTAssertNil(entityInfo.productPrice)
        XCTAssertNil(entityInfo.productWasPrice)
        XCTAssertNil(entityInfo.productBadge)
    }

    func test_entityInfo_decodesAllFields() throws {
        // Given
        let json = """
        {
            "productName": "Super Tool",
            "productDescription": "All-in-one toolkit",
            "description": "General description",
            "productPageURL": "https://example.com/products/super-tool",
            "details": "Some details",
            "learningResource": "https://example.com/learn/super-tool",
            "productImageURL": "https://example.com/images/super-tool.png",
            "backgroundColor": "#FF0000",
            "logo": "https://example.com/images/logo.png",
            "primary": { "text": "Buy", "url": "https://example.com/buy" },
            "secondary": { "text": "Try", "url": "https://example.com/try" },
            "productPrice": "$14.99",
            "productWasPrice": "$19.99",
            "productBadge": "New"
        }
        """.data(using: .utf8)!

        // When
        let entityInfo = try JSONDecoder().decode(EntityInfo.self, from: json)

        // Then
        XCTAssertEqual(entityInfo.productName, "Super Tool")
        XCTAssertEqual(entityInfo.productDescription, "All-in-one toolkit")
        XCTAssertEqual(entityInfo.description, "General description")
        XCTAssertEqual(entityInfo.productPageURL, "https://example.com/products/super-tool")
        XCTAssertEqual(entityInfo.details, "Some details")
        XCTAssertEqual(entityInfo.learningResource, "https://example.com/learn/super-tool")
        XCTAssertEqual(entityInfo.productImageURL, "https://example.com/images/super-tool.png")
        XCTAssertEqual(entityInfo.backgroundColor, "#FF0000")
        XCTAssertEqual(entityInfo.logo, "https://example.com/images/logo.png")
        XCTAssertEqual(entityInfo.primary?.text, "Buy")
        XCTAssertEqual(entityInfo.primary?.url, "https://example.com/buy")
        XCTAssertEqual(entityInfo.secondary?.text, "Try")
        XCTAssertEqual(entityInfo.secondary?.url, "https://example.com/try")
        XCTAssertEqual(entityInfo.productPrice, "$14.99")
        XCTAssertEqual(entityInfo.productWasPrice, "$19.99")
        XCTAssertEqual(entityInfo.productBadge, "New")
    }

    func test_entityInfo_emptyJSON_decodesWithAllNil() throws {
        // Given
        let json = "{}".data(using: .utf8)!

        // When
        let entityInfo = try JSONDecoder().decode(EntityInfo.self, from: json)

        // Then
        XCTAssertNil(entityInfo.productName)
        XCTAssertNil(entityInfo.productDescription)
        XCTAssertNil(entityInfo.productPageURL)
        XCTAssertNil(entityInfo.productImageURL)
        XCTAssertNil(entityInfo.productPrice)
        XCTAssertNil(entityInfo.productWasPrice)
        XCTAssertNil(entityInfo.productBadge)
        XCTAssertNil(entityInfo.primary)
        XCTAssertNil(entityInfo.secondary)
    }

    // MARK: - MultimodalElement decoding (snake_case keys)

    func test_multimodalElement_decodesSnakeCaseKeys() throws {
        // Given
        let json = """
        {
            "id": "prod-1",
            "type": "product",
            "width": 800,
            "height": 600,
            "thumbnail_width": 200,
            "thumbnail_height": 150,
            "entity_info": {
                "productName": "Video Editor",
                "productPrice": "$22.99"
            }
        }
        """.data(using: .utf8)!

        // When
        let element = try JSONDecoder().decode(MultimodalElement.self, from: json)

        // Then
        XCTAssertEqual(element.id, "prod-1")
        XCTAssertEqual(element.type, "product")
        XCTAssertEqual(element.width, 800)
        XCTAssertEqual(element.height, 600)
        XCTAssertEqual(element.thumbnailWidth, 200)
        XCTAssertEqual(element.thumbnailHeight, 150)
        XCTAssertEqual(element.entityInfo?.productName, "Video Editor")
        XCTAssertEqual(element.entityInfo?.productPrice, "$22.99")
    }

    func test_multimodalElement_minimalJSON_decodesWithNils() throws {
        // Given
        let json = "{}".data(using: .utf8)!

        // When
        let element = try JSONDecoder().decode(MultimodalElement.self, from: json)

        // Then
        XCTAssertNil(element.id)
        XCTAssertNil(element.type)
        XCTAssertNil(element.width)
        XCTAssertNil(element.height)
        XCTAssertNil(element.thumbnailWidth)
        XCTAssertNil(element.thumbnailHeight)
        XCTAssertNil(element.entityInfo)
    }

    func test_multimodalElement_encodesBackToSnakeCaseKeys() throws {
        // Given
        let element = MultimodalElement(
            id: "e1",
            type: "product",
            thumbnailWidth: 100,
            thumbnailHeight: 75,
            entityInfo: nil
        )

        // When
        let data = try JSONEncoder().encode(element)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then — verify encoded JSON uses snake_case keys
        XCTAssertNotNil(dict?["thumbnail_width"])
        XCTAssertNotNil(dict?["thumbnail_height"])
        XCTAssertNotNil(dict?["id"])
        XCTAssertNil(dict?["thumbnailWidth"])
        XCTAssertNil(dict?["thumbnailHeight"])
    }

    // MARK: - MultimodalElements decoding (object vs array shape)

    func test_multimodalElements_objectShape_decodesCorrectly() throws {
        // Given
        let json = """
        {
            "type": "products",
            "elements": [
                { "id": "p1", "entity_info": { "productName": "App A" } },
                { "id": "p2", "entity_info": { "productName": "App B" } }
            ]
        }
        """.data(using: .utf8)!

        // When
        let multimodal = try JSONDecoder().decode(MultimodalElements.self, from: json)

        // Then
        XCTAssertEqual(multimodal.type, "products")
        XCTAssertEqual(multimodal.elements.count, 2)
        XCTAssertEqual(multimodal.elements[0].id, "p1")
        XCTAssertEqual(multimodal.elements[0].entityInfo?.productName, "App A")
        XCTAssertEqual(multimodal.elements[1].id, "p2")
    }

    func test_multimodalElements_arrayShape_decodesAsEmpty() throws {
        // Given — server intermediate response sends an array instead of object
        let json = "[1, 2, 3]".data(using: .utf8)!

        // When
        let multimodal = try JSONDecoder().decode(MultimodalElements.self, from: json)

        // Then
        XCTAssertNil(multimodal.type)
        XCTAssertTrue(multimodal.elements.isEmpty)
    }

    func test_multimodalElements_objectWithNoElements_defaultsToEmptyArray() throws {
        // Given
        let json = """
        { "type": "products" }
        """.data(using: .utf8)!

        // When
        let multimodal = try JSONDecoder().decode(MultimodalElements.self, from: json)

        // Then
        XCTAssertEqual(multimodal.type, "products")
        XCTAssertTrue(multimodal.elements.isEmpty)
    }

    func test_multimodalElement_ctaButton_decodesTypeAndPrimary() throws {
        // Given
        let json = """
        {
            "type": "ctaButton",
            "id": "service-intent-live-chat",
            "entity_info": {
                "primary": {
                    "text": "Chat now",
                    "url": "https://www.example.com/live-chat"
                }
            }
        }
        """.data(using: .utf8)!

        // When
        let element = try JSONDecoder().decode(MultimodalElement.self, from: json)

        // Then
        XCTAssertEqual(element.type, "ctaButton")
        XCTAssertEqual(element.id, "service-intent-live-chat")
        XCTAssertEqual(element.entityInfo?.primary?.text, "Chat now")
        XCTAssertEqual(element.entityInfo?.primary?.url, "https://www.example.com/live-chat")
        XCTAssertNil(element.width)
        XCTAssertNil(element.height)
        XCTAssertNil(element.thumbnailWidth)
        XCTAssertNil(element.thumbnailHeight)
    }

    func test_multimodalElements_encodeDecodeRoundtrip() throws {
        // Given
        let original = MultimodalElements(type: "cards", elements: [
            MultimodalElement(id: "x1", type: "product", thumbnailWidth: 100, thumbnailHeight: 100)
        ])

        // When
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MultimodalElements.self, from: data)

        // Then
        XCTAssertEqual(decoded.type, "cards")
        XCTAssertEqual(decoded.elements.count, 1)
        XCTAssertEqual(decoded.elements[0].id, "x1")
        XCTAssertEqual(decoded.elements[0].thumbnailWidth, 100)
    }

    // MARK: - MultimodalElementType resolution

    func test_elementType_ctaButton_resolvesToCtaButton() {
        let element = MultimodalElement(id: "cta-1", type: "ctaButton")
        XCTAssertEqual(element.elementType, .ctaButton)
    }

    func test_elementType_nilType_resolvesToUnknownNil() {
        let element = MultimodalElement(id: "prod-1", type: nil)
        XCTAssertEqual(element.elementType, .unknown(nil))
    }

    func test_elementType_productString_resolvesToUnknownProduct() {
        let element = MultimodalElement(id: "prod-1", type: "product")
        XCTAssertEqual(element.elementType, .unknown("product"))
    }

    func test_elementType_unrecognizedString_resolvesToUnknownWithValue() {
        let element = MultimodalElement(id: "x-1", type: "someFutureType")
        XCTAssertEqual(element.elementType, .unknown("someFutureType"))
    }

    func test_elementType_init_rawType_ctaButton() {
        XCTAssertEqual(MultimodalElementType(rawType: "ctaButton"), .ctaButton)
    }

    func test_elementType_init_rawType_nil() {
        XCTAssertEqual(MultimodalElementType(rawType: nil), .unknown(nil))
    }

    func test_elementType_init_rawType_unrecognized() {
        XCTAssertEqual(MultimodalElementType(rawType: "video"), .unknown("video"))
    }
}
