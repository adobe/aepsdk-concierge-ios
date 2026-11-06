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

import Combine
import XCTest
import SwiftUI
@testable import AEPBrandConcierge

final class CardJSONValueTests: NativeCardTestCase {
    @MainActor
    func testRawActivationEnforcesExactDepthAndNodeBudgets() throws {
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        NativeCardRegistry.register(type: "test.budget") { _, _, _ in
            AnyView(EmptyView())
        }
        func element(depth: Int) throws -> MultimodalElement {
            let json = #"{"type":"test.budget","nested":"# +
                String(repeating: "[", count: depth - 1) + "0" +
                String(repeating: "]", count: depth - 1) + "}"
            return try CardJSONValue.decode(MultimodalElement.self, from: Data(json.utf8))
        }
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        let fallbackJSON = #"{"type":"test.budget","nested":"# +
            String(repeating: "[", count: 64) + "0" +
            String(repeating: "]", count: 64) +
            #","entity_info":{"productName":"Fallback after rejection"}}"#
        let fallbackElement = try CardJSONValue.decode(MultimodalElement.self, from: Data(fallbackJSON.utf8))
        controller.renderElementsForTesting([try element(depth: 64), try element(depth: 65), fallbackElement],
                                            turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }.count, 1)
        XCTAssertTrue(controller.messages.contains {
            switch $0.template {
            case .productCard(let product):
                return product.title == "Fallback after rejection"
            case .carouselGroup(let items):
                return items.contains {
                    if case .productCarouselCard(let product) = $0.template {
                        return product.title == "Fallback after rejection"
                    }
                    return false
                }
            default:
                return false
            }
        }, "A rejected native activation must retain its parsed built-in fallback")
        XCTAssertNotNil(NativeCard.copyJSON(["nodes": Array(repeating: 0, count: 99_998)]))
        XCTAssertNil(NativeCard.copyJSON(["nodes": Array(repeating: 0, count: 99_999)]))
        let huge = #"{"type":"test.budget","nodes":["# + Array(repeating: "0", count: 100_000).joined(separator: ",") + "]}"
        let hugeElement = try CardJSONValue.decode(MultimodalElement.self, from: Data(huge.utf8))
        XCTAssertFalse(hugeElement.hasCompleteRawElement)
        controller.renderElementsForTesting([hugeElement], turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }.count, 1)
    }

    func testRawNumbersBridgeLikeJSONSerializationAndRoundTrip() throws {
        NativeCardRegistry.register(type: "test.numbers") { _, _, _ in AnyView(EmptyView()) }
        let json = #"{"type":"test.numbers","qty":3,"price":4.5,"flag":true,"nested":{"id":42},"array":[7]}"#
        let data = Data(json.utf8)
        let element = try CardJSONValue.decode(MultimodalElement.self, from: data)
        let reference = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(element.rawElement["qty"] as? Int, 3)
        XCTAssertEqual(element.rawElement["qty"] as? Double, 3)
        XCTAssertEqual(element.rawElement["price"] as? Double, 4.5)
        XCTAssertEqual(element.rawElement["flag"] as? Bool, true)
        XCTAssertEqual((element.rawElement["nested"] as? [String: Any])?["id"] as? Int, 42)
        XCTAssertEqual((element.rawElement["array"] as? [Any])?.first as? Int, 7)
        XCTAssertEqual(element.rawElement as NSDictionary, reference as NSDictionary)
        let encoded = try JSONEncoder().encode(element)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? NSDictionary,
                       reference as NSDictionary)
    }

    @MainActor
    func testExactDecimalNumbersSurviveActivationStateAndEncoding() async throws {
        NativeCardRegistry.register(type: "test.precision") { _, _, _ in AnyView(EmptyView()) }
        let tokens = [
            "18446744073709551616", "-9223372036854775809",
            "1.23456789012345678901234567890123456789", "1.234567890123456789e30", "1e-120"
        ]
        for token in tokens {
            let json = #"{"type":"test.precision","nested":{"number":\#(token)},"values":[\#(token)]}"#
            let element = try CardJSONValue.decode(MultimodalElement.self, from: Data(json.utf8))
            XCTAssertTrue(element.hasCompleteRawElement, token)
            let expected = NSDecimalNumber(string: token)
            let info = try XCTUnwrap(element.rawElement["nested"] as? [String: Any])
            XCTAssertEqual(info["number"] as? NSDecimalNumber, expected)
            let copy = try XCTUnwrap(NativeCard.copyJSON(element.rawElement))
            XCTAssertEqual((copy["nested"] as? [String: Any])?["number"] as? NSDecimalNumber, expected)
            let controller = ChatController(configuration: nil,
                chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
            controller.renderElementsForTesting([element], turnId: UUID(), payload: streamPayload(state: "completed"))
            guard let card = nativeCard(at: 0, in: controller) else {
                return XCTFail("An exactly representable decimal must activate")
            }
            await saveStateAndWait(copy, on: card)
            XCTAssertEqual((card.state?["nested"] as? [String: Any])?["number"] as? NSDecimalNumber, expected)
            let encoded = try JSONEncoder().encode(element)
            let decoded = try CardJSONValue.decode(MultimodalElement.self, from: encoded)
            XCTAssertEqual((decoded.rawElement["nested"] as? [String: Any])?["number"] as? NSDecimalNumber, expected)
        }
    }

    @MainActor
    func testUnrepresentableNumbersRejectOnlyNativeActivationAndKeepFallback() throws {
        NativeCardRegistry.register(type: "test.precision") { _, _, _ in AnyView(EmptyView()) }
        let tokens = [
            "123456789012345678901234567890123456789123456789",
            "1.0000000000000000000000000000000000000001", "1e-400", "1e400"
        ]
        for token in tokens {
            let json = """
            [{"type":"test.precision","nested":{"value":\(token)},"entity_info":{"productName":"Fallback"}},
             {"type":"test.precision","id":"accepted","value":2}]
            """
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
            XCTAssertFalse(elements[0].hasCompleteRawElement, token)
            XCTAssertTrue(elements[1].hasCompleteRawElement)
            let controller = ChatController(configuration: nil,
                chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
            controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
            XCTAssertEqual(controller.messages.count, 2)
            guard case .productCard(let fallback) = controller.messages[0].template,
                  case .nativeCard = controller.messages[1].template else {
                return XCTFail("Numeric rejection must preserve the built-in fallback and adjacent cards")
            }
            XCTAssertEqual(fallback.title, "Fallback")
        }
    }

    func testNumberSourcePathsHandleEscapedKeysAndNumberLikeStrings() throws {
        NativeCardRegistry.register(type: "test.precision") { _, _, _ in AnyView(EmptyView()) }
        let json = #"""
        {"type":"test.precision","text":"\"1e400\"","123":{"a\u0022b":[
        {"number":1.234567890123456789,"text":"\\1e-400"}]},"[0]":42}
        """#
        let element = try CardJSONValue.decode(MultimodalElement.self, from: Data(json.utf8))
        XCTAssertTrue(element.hasCompleteRawElement)
        XCTAssertEqual(element.rawElement["text"] as? String, "\"1e400\"")
        let nested = try XCTUnwrap(element.rawElement["123"] as? [String: Any])
        let array = try XCTUnwrap(nested["a\"b"] as? [[String: Any]])
        XCTAssertEqual(array[0]["number"] as? NSDecimalNumber, NSDecimalNumber(string: "1.234567890123456789"))
        XCTAssertEqual(element.rawElement["[0]"] as? Int, 42)
    }

    func testNativeNumbersWithoutSourceBytesFailClosed() {
        let json = Data(#"{"value":1.5}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(CardJSONValue.self, from: json),
                             "A generic Decoder cannot prove the original numeric precision")
        XCTAssertNoThrow(try CardJSONValue.decode(CardJSONValue.self, from: json))
    }

    func testNativeDecodingUsesItsTypeSnapshotRatherThanTheLiveRegistry() throws {
        let json = Data(#"[{"type":"test.first","id":42},{"type":"test.second","id":"two"}]"#.utf8)
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: json, nativeCardTypes: ["test.first"])
        XCTAssertTrue(elements[0].hasCompleteRawElement, "A snapshot type decodes natively without a registration")
        XCTAssertEqual(elements[0].nativeElementId, "42")
        XCTAssertFalse(elements[1].hasCompleteRawElement)

        NativeCardRegistry.register(type: "test.first") { _, _, _ in AnyView(EmptyView()) }
        XCTAssertThrowsError(try CardJSONValue.decode([MultimodalElement].self, from: json, nativeCardTypes: []),
                             "An empty snapshot keeps strict decoding even after a registration")
    }

    @MainActor
    func testUnsignedIdentifiersRemainExactThroughRendererStateAndEncoding() throws {
        NativeCardRegistry.register(type: "test.unsigned") { _, _, _ in AnyView(EmptyView()) }
        for identifier in [UInt64(Int64.max) + 2, UInt64.max] {
            let json = #"{"type":"test.unsigned","entity_info":{"id":\#(identifier)}}"#
            let element = try CardJSONValue.decode(MultimodalElement.self, from: Data(json.utf8))
            let info = try XCTUnwrap(element.rawElement["entity_info"] as? [String: Any])
            XCTAssertEqual((info["id"] as? NSNumber)?.stringValue, String(identifier))

            var receivedIdentifier: String?
            let card = NativeCard(element: element.rawElement, renderer: { raw, _, _ in
                let info = raw["entity_info"] as? [String: Any]
                receivedIdentifier = (info?["id"] as? NSNumber)?.stringValue
                return AnyView(EmptyView())
            }, sessionId: nil, conversationId: nil, interactionId: nil)
            _ = card.renderer(card.element, card.context, { _ in })
            XCTAssertEqual(receivedIdentifier, String(identifier))

            let copied = try XCTUnwrap(NativeCard.copyJSON(element.rawElement))
            let copiedInfo = try XCTUnwrap(copied["entity_info"] as? [String: Any])
            XCTAssertEqual((copiedInfo["id"] as? NSNumber)?.stringValue, String(identifier))
            let encoded = try JSONEncoder().encode(element)
            let decoded = try CardJSONValue.decode(MultimodalElement.self, from: encoded)
            let decodedInfo = try XCTUnwrap(decoded.rawElement["entity_info"] as? [String: Any])
            XCTAssertEqual((decodedInfo["id"] as? NSNumber)?.stringValue, String(identifier))
        }
    }
}
