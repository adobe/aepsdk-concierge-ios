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

final class NativeCardTests: XCTestCase {
    @MainActor
    func testAttachedSuggestionsRespectHeaderSettingAndEmptySuggestions() {
        let card = NativeCard(element: [:], renderer: { _, _, _ in AnyView(EmptyView()) },
                              sessionId: nil, conversationId: nil, interactionId: nil)
        func height(showHeader: Bool, suggestions: [String]) -> CGFloat {
            var theme = ConciergeTheme()
            theme.behavior.promptSuggestions = ConciergePromptSuggestionsBehavior(showHeader: showHeader)
            let view = ChatMessageView(template: .nativeCard(card), promptSuggestions: suggestions)
                .environment(\.conciergeTheme, theme)
            let controller = UIHostingController(rootView: view)
            return controller.sizeThatFits(in: CGSize(width: 320, height: 1000)).height
        }
        let withoutHeader = height(showHeader: false, suggestions: ["Continue"])
        let withHeader = height(showHeader: true, suggestions: ["Continue"])
        XCTAssertGreaterThan(withHeader, withoutHeader + 10)
        XCTAssertEqual(height(showHeader: true, suggestions: []),
                       height(showHeader: false, suggestions: []), accuracy: 0.5)
    }

    override func setUp() {
        super.setUp()
        NativeCardRegistry.resetForTesting()
    }

    override func tearDown() {
        NativeCardRegistry.resetForTesting()
        super.tearDown()
    }

    @MainActor
    func testStreamingNativeCardsRequireCompletedElements() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
        let completions: [ConversationPayload?] = [
            streamPayload(state: "completed"),
            streamPayload(state: "completed", elements: []),
            nil
        ]
        for completion in completions {
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "in-progress", elements: elements)]
            if let completion { service.plannedChunks.append(completion) }
            let controller = ChatController(configuration: nil, chatService: service,
                                            speechCapturer: nil, speaker: nil)
            let finished = expectation(description: "Unfinalized native card rejected")
            var outcome: ConciergeError?
            controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
                outcome = error
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 2)
            guard case .invalidResponseData? = outcome else {
                return XCTFail("Expected invalidResponseData for an unfinalized native card")
            }
            XCTAssertTrue(controller.messages.isEmpty)
            XCTAssertEqual(controller.chatState, .idle)
        }
    }

    @MainActor
    func testCompletedNativeElementsReplaceStreamingCandidates() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"},{"type":"test.streaming","id":"final"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [
            streamPayload(state: "in-progress", elements: [elements[0]]),
            streamPayload(state: "completed", elements: [elements[1]], message: "Final response")
        ]
        service.shouldCallComplete = false
        let controller = ChatController(configuration: nil, chatService: service,
                                        speechCapturer: nil, speaker: nil)
        let receivedFinal = expectation(description: "Completed payload received")
        let observation = controller.$messages
            .first { $0.last?.messageBody == "Final response" }
            .sink { _ in receivedFinal.fulfill() }
        defer { observation.cancel() }
        let finished = expectation(description: "Final native card accepted")
        controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [receivedFinal], timeout: 2)
        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertFalse(controller.messages.contains {
            if case .nativeCard = $0.template { return true }
            return false
        })
        service.triggerCompletion()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 2)
        guard case .nativeCard(let card) = controller.messages.last?.template else {
            return XCTFail("Expected the completed native card")
        }
        XCTAssertEqual(card.element["id"] as? String, "final")
        XCTAssertFalse(card.isBusy)
        XCTAssertEqual(controller.chatState, .idle)
    }

    @MainActor
    func testCompletedTextDoesNotActivateStreamingNativeCards() async throws {
        NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [
            streamPayload(state: "in-progress", elements: elements),
            streamPayload(state: "completed", message: "No menu is available.")
        ]
        let controller = ChatController(configuration: nil, chatService: service,
                                        speechCapturer: nil, speaker: nil)
        let finished = expectation(description: "Final text accepted without a native card")
        controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(controller.messages.first?.messageBody, "No menu is available.")
        guard case .basic(isUserMessage: false) = controller.messages.first?.template else {
            return XCTFail("Expected only the completed text")
        }
    }

    @MainActor
    func testStreamingBuiltInElementsKeepLegacyBuffering() async throws {
        let product = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Buffered product"}}]"#.utf8))
        let completions: [[MultimodalElement]?] = [nil, []]
        for hasRenderer in [false, true] {
            var streamingElements = product
            if hasRenderer {
                NativeCardRegistry.register(type: "test.streaming") { _, _, _ in AnyView(EmptyView()) }
                streamingElements += try CardJSONValue.decode([MultimodalElement].self,
                    from: Data(#"[{"type":"test.streaming","id":"draft"}]"#.utf8))
            }
            for completedElements in completions {
                let service = MockChatService(configuration: ConciergeConfiguration())
                service.plannedChunks = [
                    streamPayload(state: "in-progress", elements: streamingElements),
                    streamPayload(state: "completed", elements: completedElements)
                ]
                let controller = ChatController(configuration: nil, chatService: service,
                                                speechCapturer: nil, speaker: nil)
                let finished = expectation(description: "Buffered built-in product accepted")
                controller.handleDataHandoff(routingHint: "products", xdmFields: [:]) { error in
                    XCTAssertNil(error)
                    finished.fulfill()
                }
                await fulfillment(of: [finished], timeout: 2)
                XCTAssertEqual(controller.messages.count, 1)
                guard case .productCard(let card) = controller.messages.first?.template else {
                    return XCTFail("Expected the buffered built-in product")
                }
                XCTAssertEqual(card.title, "Buffered product")
            }
        }
    }

    /// Matches Android: a card-only response whose cards all fail to render is an empty response,
    /// even with prompt suggestions; a built-in fallback still delivers it.
    @MainActor
    func testUnrenderableCardOnlyResponseIsReportedAsEmpty() async throws {
        NativeCardRegistry.register(type: "test.unrenderable") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let rejected = #"{"type":"test.unrenderable","nested":"# + nested + "}"
        let withFallback = #"{"type":"test.unrenderable","nested":"# + nested +
            #","entity_info":{"productName":"Fallback"}}"#
        for (json, delivered) in [(rejected, false), (withFallback, true)] {
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data("[\(json)]".utf8))
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.plannedChunks = [streamPayload(state: "completed", elements: elements, suggestions: ["Next"])]
            let controller = ChatController(configuration: nil, chatService: service,
                                            speechCapturer: nil, speaker: nil)
            let finished = expectation(description: "Card-only handoff finished")
            var outcome: ConciergeError?
            controller.handleDataHandoff(routingHint: "menu", xdmFields: [:]) { error in
                outcome = error
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 2)
            XCTAssertEqual(controller.chatState, .idle)
            if delivered {
                XCTAssertNil(outcome)
                guard case .productCard? = controller.messages.first?.template else {
                    return XCTFail("A rejected native card with a built-in fallback must render the fallback")
                }
            } else {
                guard case .invalidResponseData? = outcome else {
                    return XCTFail("Expected invalidResponseData when no element can render")
                }
                XCTAssertTrue(controller.messages.isEmpty)
            }
        }
    }

    private func streamPayload(state: String, elements: [MultimodalElement]? = nil,
                               message: String = "", suggestions: [String]? = nil) -> ConversationPayload {
        ConversationPayload(conversationId: "conversation", interactionId: "interaction", request: nil,
            response: ConversationResponse(message: message, promptSuggestions: suggestions,
                multimodalElements: elements.map { MultimodalElements(elements: $0) },
                sources: nil, linkHints: nil, state: nil, feedback: nil),
            state: state, key: nil, value: nil, maxAge: nil)
    }

    @MainActor
    func testLegacyProductFallbackWithoutAnyRegistry() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Legacy"}}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.count, 1)
        guard case .productCard = controller.messages.first?.template else {
            return XCTFail("No registrations must retain legacy product parsing")
        }
    }

    @MainActor
    func testDistinctOccurrencesRemainDeduplicated() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        NativeCardRegistry.register(type: "test.occurrence") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.occurrence","id":"1"},{"type":"test.occurrence"}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 2)
        let cards = controller.messages.compactMap { message -> NativeCard? in
            if case .nativeCard(let card) = message.template { return card }
            return nil
        }
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(Set(cards.map(\.cardId)).count, 2)
        XCTAssertEqual(cards.map(\.sequence), [0, 1], "sequence follows transcript order within one response")
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 2, "Reprocessing the response must not append cards")
    }

    @MainActor
    func testControllerTeardownDisposesRetainedCard() async throws {
        var controller: ChatController? = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        NativeCardRegistry.register(type: "test.teardown") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
                                                from: Data(#"[{"type":"test.teardown"}]"#.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self, from: Data("{}".utf8))
        controller?.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        guard case .nativeCard(let card) = controller?.messages.first?.template else {
            return XCTFail("Missing native card")
        }
        weak var releasedController = controller
        controller = nil
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(releasedController)
        XCTAssertTrue(card.disposed)
        card.saveState(["late": true])
        await Task.yield()
        XCTAssertNil(card.state)
    }

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

    func testRawElementsKeepUnknownNestedValuesAndInvalidBuiltInProjection() throws {
        NativeCardRegistry.register(type: "kings.menu") { _, _, _ in AnyView(EmptyView()) }
        let response = """
        {"type":"kings.menu","entity_info":{"products":[{"id":3,"extra":null}],"primary":{"text":42}},
        "unknown":{"flags":[true,false,null]},"id":42}
        """
        let element = try CardJSONValue.decode(MultimodalElement.self, from: Data(response.utf8))
        XCTAssertNil(element.id)
        XCTAssertEqual(element.type, "kings.menu")
        XCTAssertTrue(element.hasCompleteRawElement)
        let info = try XCTUnwrap(element.rawElement["entity_info"] as? [String: Any])
        XCTAssertTrue((info["products"] as? [[String: Any]])?[0]["extra"] is NSNull)
        let nested = try XCTUnwrap(element.rawElement["unknown"] as? [String: Any])
        XCTAssertTrue((nested["flags"] as? [Any])?[2] is NSNull)
        let encoded = try JSONEncoder().encode(element)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    }

    func testDebugDescriptionOmitsNativePayloadAndPreservesLegacyOutput() throws {
        NativeCardRegistry.register(type: "test.private") { _, _, _ in AnyView(EmptyView()) }
        let nativeJSON = """
        {"message":"hello","multimodalElements":{"elements":[
        {"type":"test.private","entity_info":{"customer":"sensitive-value"}}]}}
        """
        let native = try CardJSONValue.decode(ConversationResponse.self, from: Data(nativeJSON.utf8))
        let description = try XCTUnwrap(native.debugLogDescription)
        XCTAssertEqual(description, "[native card payload omitted]")
        XCTAssertFalse(description.contains("sensitive-value"))

        let legacyJSON = """
        {"message":"hello","multimodalElements":{"elements":[
        {"type":"product","entity_info":{"productName":"Visible product"}}]}}
        """
        let legacy = try CardJSONValue.decode(ConversationResponse.self, from: Data(legacyJSON.utf8))
        let encoded = try JSONEncoder().encode(legacy)
        let originalDescription = try XCTUnwrap(String(data: encoded, encoding: .utf8)).prettyPrintedJSON()
        XCTAssertEqual(legacy.debugLogDescription, originalDescription)
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
            guard case .nativeCard(let card) = controller.messages.first?.template else {
                return XCTFail("An exactly representable decimal must activate")
            }
            card.saveState(copy)
            await Task.yield()
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

    func testNativeNumbersWithoutSourceBytesFailClosed() throws {
        NativeCardRegistry.register(type: "test.precision") { _, _, _ in AnyView(EmptyView()) }
        let json = #"{"type":"test.precision","value":1.0000000000000000000000000000000000000001}"#
        let element = try JSONDecoder().decode(MultimodalElement.self, from: Data(json.utf8))
        XCTAssertFalse(element.hasCompleteRawElement, "A generic Decoder cannot prove the original numeric precision")
    }

    func testUnregisteredElementsKeepStrictBuiltInDecodingWithoutRawCapture() throws {
        let element = try CardJSONValue.decode(MultimodalElement.self,
            from: Data(#"{"id":"1","type":"kings.menu","entity_info":{"productName":"Built-in"}}"#.utf8))
        XCTAssertTrue(element.rawElement.isEmpty)
        XCTAssertFalse(element.hasCompleteRawElement)
        XCTAssertEqual(element.entityInfo?.productName, "Built-in")
        XCTAssertThrowsError(try CardJSONValue.decode(MultimodalElement.self,
            from: Data(#"{"id":42,"type":"kings.menu"}"#.utf8)), "Unregistered types keep dev's strict decoding")
    }

    func testNativeCardResponseStillRequiresAStringMessage() throws {
        NativeCardRegistry.register(type: "test.required") { _, _, _ in AnyView(EmptyView()) }
        let elements = #""multimodalElements":{"elements":[{"type":"test.required"}]}"#
        for message in ["", #""message":null,"#, #""message":42,"#] {
            let json = "{\(message)\(elements)}"
            XCTAssertThrowsError(try CardJSONValue.decode(ConversationResponse.self, from: Data(json.utf8)))
        }
        let emptyMessage = "{ \"message\":\"\", \(elements) }"
        let response = try CardJSONValue.decode(ConversationResponse.self, from: Data(emptyMessage.utf8))
        XCTAssertEqual(response.message, "")
        XCTAssertTrue(response.multimodalElements?.elements.first?.hasCompleteRawElement == true)
    }

    func testRegistryExactMatchingAndReplacement() {
        let type = "test.card.\(UUID().uuidString)"
        let first: ConciergeCardRenderer = { _, _, _ in AnyView(Text("first")) }
        let second: ConciergeCardRenderer = { _, _, _ in AnyView(Text("second")) }
        NativeCardRegistry.register(type: "", renderer: first)
        XCTAssertNil(NativeCardRegistry.renderer(for: ""))
        NativeCardRegistry.register(type: type, renderer: first)
        XCTAssertNil(NativeCardRegistry.renderer(for: type.uppercased()))
        let captured = NativeCardRegistry.renderer(for: type)
        NativeCardRegistry.register(type: type, renderer: second)
        XCTAssertNotNil(captured)
        XCTAssertNotNil(NativeCardRegistry.renderer(for: type))
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

    @MainActor
    func testStateIsReplacedAndDisposedCardsIgnoreLateSaves() async {
        let card = NativeCard(element: [:], renderer: { _, _, _ in AnyView(EmptyView()) },
                              sessionId: "session", conversationId: "conversation", interactionId: "turn")
        XCTAssertNil(card.context["state"])
        XCTAssertEqual(card.context["interactionId"] as? String, "turn")
        let mutable = NSMutableDictionary(dictionary: ["value": "before", "null": NSNull()])
        card.saveState(["data": mutable])
        await Task.yield()
        mutable["value"] = "after"
        XCTAssertEqual((card.state?["data"] as? [String: Any])?["value"] as? String, "before")
        XCTAssertTrue((card.state?["data"] as? [String: Any])?["null"] is NSNull)
        card.saveState(["next": 3])
        await Task.yield()
        XCTAssertNil(card.state?["data"])
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        card.saveState(["invalid": Double.infinity])
        await Task.yield()
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        let cycle = NSMutableDictionary()
        cycle["self"] = cycle
        card.saveState(["cycle": cycle])
        await Task.yield()
        XCTAssertEqual(card.state?["next"] as? Int, 3)
        card.dispose()
        card.saveState(["late": 1])
        await Task.yield()
        XCTAssertTrue(card.isStale)
        XCTAssertNil(card.state)
    }

    func testCustomThemeVariablesBounded() {
        var theme = ConciergeTheme()
        CSSKeyMapper.apply(cssKey: "--fnb-accent", cssValue: "  #123456  ", to: &theme)
        XCTAssertEqual(theme.customVariables["--fnb-accent"], "#123456")
        CSSKeyMapper.apply(cssKey: "not-css", cssValue: "value", to: &theme)
        XCTAssertNil(theme.customVariables["not-css"])
        for index in 0..<260 {
            CSSKeyMapper.apply(cssKey: "--sample-\(index)", cssValue: "value", to: &theme)
        }
        XCTAssertEqual(theme.customVariables.count, 256)
        CSSKeyMapper.apply(cssKey: "--fnb-accent", cssValue: "new", to: &theme)
        XCTAssertEqual(theme.customVariables["--fnb-accent"], "new")
    }

    @MainActor
    func testNativeDuplicateIdsUseBuiltInFallback() async throws {
        NativeCardRegistry.register(type: "test.identity") { _, _, _ in AnyView(EmptyView()) }
        let duplicateIds = [
            ("42", "42"), (#""same""#, #""same""#), ("42", #""42""#),
            ("42.5", "42.5"), ("true", #""true""#),
            ("18446744073709551615", #""18446744073709551615""#)
        ]
        for ids in duplicateIds {
            let controller = ChatController(configuration: nil,
                chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
            let json = """
            [{"type":"test.identity","id":\(ids.0)},
             {"type":"test.identity","id":\(ids.1)},
             {"type":"test.identity","id":\(ids.1),"entity_info":{"productName":"Fallback"}},
             {"type":"ctaButton","id":"cta","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
            """
            NativeCardRegistry.register(type: "ctaButton") { _, _, _ in AnyView(EmptyView()) }
            let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
            let payload = streamPayload(state: "completed")
            let turn = UUID()
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            XCTAssertEqual(controller.messages.count, 3)
            guard case .nativeCard(let first) = controller.messages[0].template,
                  case .productCard(let fallback) = controller.messages[1].template,
                  case .nativeCard = controller.messages[2].template else {
                return XCTFail("Duplicate IDs must use a fallback or be omitted, not activate twice")
            }
            XCTAssertEqual(fallback.title, "Fallback")
            first.saveState(["selected": true])
            await Task.yield()
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            let cards = controller.messages.compactMap { message -> NativeCard? in
                if case .nativeCard(let card) = message.template { return card }
                return nil
            }
            XCTAssertEqual(cards.count, 2, "Reprocessing must not reactivate an occurrence")
            XCTAssertEqual(cards.first?.cardId, first.cardId)
            XCTAssertEqual(first.state?["selected"] as? Bool, true)
            controller.messages.removeAll()
            XCTAssertTrue(first.disposed)
            controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
            guard case .nativeCard(let replacement) = controller.messages.first?.template else {
                return XCTFail("Rollback must release occurrence IDs")
            }
            XCTAssertNotEqual(replacement.cardId, first.cardId)
        }
    }

    @MainActor
    func testNativeEmptyNullAndMissingIdsUsePosition() throws {
        NativeCardRegistry.register(type: "test.identity") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"test.identity","id":""},{"type":"test.identity","id":""},
         {"type":"test.identity","id":null},{"type":"test.identity","id":null},
         {"type":"test.identity"},{"type":"test.identity"},
         {"type":"test.identity","id":" "}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let turn = UUID()
        let payload = streamPayload(state: "completed")
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        let cards = controller.messages.compactMap { message -> NativeCard? in
            if case .nativeCard(let card) = message.template { return card }
            return nil
        }
        XCTAssertEqual(cards.count, 7)
        XCTAssertEqual(Set(cards.map(\.occurrenceId)).count, 7)
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 7)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload)
        XCTAssertEqual(controller.messages.count, 14, "Occurrence IDs must be scoped to a turn")
    }

    @MainActor
    func testTenThousandNativeCardsAppendOnceAndDisposeRemovedOccurrences() throws {
        NativeCardRegistry.register(type: "test.large") { _, _, _ in AnyView(EmptyView()) }
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let json = "[" + (0..<10_000).map { #"{"type":"test.large","id":\#($0)}"# }.joined(separator: ",") + "]"
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = streamPayload(state: "completed")
        let turn = UUID()
        var publications = 0
        let subscription = controller.$messages.dropFirst().sink { _ in publications += 1 }
        defer { subscription.cancel() }
        let startedAt = ProcessInfo.processInfo.systemUptime
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        let duration = ProcessInfo.processInfo.systemUptime - startedAt
        XCTAssertEqual(publications, 1, "A completed response must publish its rows in one batch")
        XCTAssertLessThan(duration, 10, "A valid 10,000-element response must not trigger quadratic transcript scans")
        let cards = controller.messages.compactMap { message -> NativeCard? in
            if case .nativeCard(let card) = message.template { return card }
            return nil
        }
        XCTAssertEqual(cards.count, 10_000)
        XCTAssertEqual(Set(cards.map(\.occurrenceId)).count, 10_000)
        XCTAssertEqual(cards.first?.element["id"] as? Int, 0)
        XCTAssertEqual(cards.last?.element["id"] as? Int, 9_999)
        controller.renderElementsForTesting(elements, turnId: turn, payload: payload)
        XCTAssertEqual(publications, 1, "Replayed occurrences must not publish duplicate rows")
        controller.messages.removeFirst(5_000)
        XCTAssertTrue(cards.prefix(5_000).allSatisfy(\.disposed))
        XCTAssertTrue(cards.suffix(5_000).allSatisfy { !$0.disposed })
        controller.messages.removeAll()
        XCTAssertTrue(cards.allSatisfy(\.disposed))
        controller.renderElementsForTesting([elements[0]], turnId: turn, payload: payload)
        XCTAssertEqual(controller.messages.count, 1, "Disposal must release occurrence identities")
    }

    @MainActor
    func testNativeDuplicateIdUsesCtaFallback() throws {
        NativeCardRegistry.register(type: "ctaButton") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"ctaButton","id":"same"},
         {"type":"ctaButton","id":"same","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        XCTAssertEqual(controller.messages.count, 2)
        guard case .nativeCard = controller.messages[0].template,
              case .ctaButton = controller.messages[1].template else {
            return XCTFail("Duplicate native IDs must fall back to the built-in CTA")
        }
    }

    @MainActor
    func testNativeRoutingFallbackAndOccurrenceState() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.native.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"same","custom":{"null":null}},
         {"type":"\(type)","id":"same"},
         {"type":"unknown","entity_info":{"productName":"unknown fallback"}},
         {"type":"product","entity_info":{"productName":"legacy product"}},
         {"type":"unregistered.custom","entity_info":{"productName":"custom fallback"}},
         {"type":"unregistered.custom","custom":{"name":"no product data"}},
         {"entity_info":{"productName":"untyped fallback"}},
         {"type":"productCard","entity_info":{"productName":"visible"}},
         {"type":"horizontalCard","entity_info":{"productName":"horizontal fallback"}},
         {"type":"ctaButton","entity_info":{"primary":{"text":"Tap","url":"https://example.com"}}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))
        let turnId = UUID()
        controller.renderElementsForTesting(elements, turnId: turnId, payload: payload, sessionId: "session")
        XCTAssertEqual(controller.messages.count, 3)
        guard case .carouselGroup(let products) = controller.messages[1].template else {
            return XCTFail("Expected the allowed productCard fallback")
        }
        XCTAssertEqual(products.count, 6)
        let titles = products.compactMap { message -> String? in
            if case .productCarouselCard(let product) = message.template { return product.title }
            return nil
        }
        XCTAssertEqual(titles, [
            "unknown fallback", "legacy product", "custom fallback",
            "untyped fallback", "visible", "horizontal fallback"
        ])
        XCTAssertTrue(controller.messages.contains {
            if case .ctaButton = $0.template { return true }
            return false
        })
        guard case .nativeCard(let card) = controller.messages[0].template else {
            return XCTFail("Expected native card")
        }
        XCTAssertEqual(card.context["conversationId"] as? String, "conv")
        XCTAssertEqual(card.context["sessionId"] as? String, "session")
        XCTAssertTrue((card.element["custom"] as? [String: Any])?["null"] is NSNull)
        controller.renderElementsForTesting(elements, turnId: turnId, payload: payload, sessionId: "session")
        XCTAssertEqual(controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }.count, 1)
        controller.messages.removeAll()
        XCTAssertTrue(card.isStale)
        card.saveState(["late": true])
        XCTAssertNil(card.state)
    }

    @MainActor
    func testPromptSuggestionsPreferBuiltInRowOverNativeRow() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"native"},
         {"type":"productCard","entity_info":{"productName":"Product"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Try another"])

        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        let builtInMessage = try XCTUnwrap(controller.messages.first {
            if case .productCard = $0.template { return true }
            return false
        })
        XCTAssertNil(nativeMessage.promptSuggestions)
        XCTAssertEqual(builtInMessage.promptSuggestions, ["Try another"])
        XCTAssertFalse(controller.messages.contains {
            if case .promptSuggestion = $0.template { return true }
            return false
        })
    }

    @MainActor
    func testPromptSuggestionsAttachToLastNativeRowWithoutBuiltInCard() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"first"},
         {"type":"\(type)","id":"last"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let nativeMessages = controller.messages.filter {
            if case .nativeCard = $0.template { return true }
            return false
        }
        XCTAssertEqual(nativeMessages.count, 2)
        XCTAssertNil(nativeMessages.first?.promptSuggestions)
        XCTAssertEqual(nativeMessages.last?.promptSuggestions, ["Continue"])
    }

    @MainActor
    func testPromptSuggestionsPreferNonEmptyBuiltInCarousel() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"\(type)","id":"native"},
         {"type":"productCard","entity_info":{"productName":"One"}},
         {"type":"productCard","entity_info":{"productName":"Two"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let carousel = try XCTUnwrap(controller.messages.first {
            if case .carouselGroup = $0.template { return true }
            return false
        })
        guard case .carouselGroup(let products) = carousel.template else { return XCTFail("Expected carousel") }
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(carousel.promptSuggestions, ["Continue"])
        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        XCTAssertNil(nativeMessage.promptSuggestions)
    }

    @MainActor
    func testPromptSuggestionsIgnoreAnEmptyBuiltInCarousel() throws {
        let controller = ChatController(configuration: nil,
                                        chatService: MockChatService(configuration: ConciergeConfiguration()),
                                        speechCapturer: nil, speaker: nil)
        let type = "test.suggestions.\(UUID().uuidString)"
        NativeCardRegistry.register(type: type) { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"unknown-one"},{"type":"unknown-two"},{"type":"\(type)","id":"native"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let payload = try CardJSONValue.decode(ConversationPayload.self,
                                                from: Data(#"{"conversationId":"conv","interactionId":"turn"}"#.utf8))

        controller.renderElementsForTesting(elements, turnId: UUID(), payload: payload,
                                            promptSuggestions: ["Continue"])

        let carousel = try XCTUnwrap(controller.messages.first {
            if case .carouselGroup = $0.template { return true }
            return false
        })
        guard case .carouselGroup(let products) = carousel.template else { return XCTFail("Expected carousel") }
        XCTAssertTrue(products.isEmpty)
        XCTAssertNil(carousel.promptSuggestions)
        let nativeMessage = try XCTUnwrap(controller.messages.first {
            if case .nativeCard = $0.template { return true }
            return false
        })
        XCTAssertEqual(nativeMessage.promptSuggestions, ["Continue"])
    }

    @MainActor
    func testResolverDoesNotActivateOrReserveOccurrences() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.plan","id":"same"},{"type":"test.plan","id":"same"}]"#.utf8))
        let store = NativeCardStore()
        let turn = UUID()
        let occurrence = NativeCardStore.Occurrence(element: elements[0], position: 0, turnId: turn)
        let plan = ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store)
        XCTAssertTrue(plan.hasRenderableElements)
        XCTAssertEqual(plan.targets.count, 1)
        XCTAssertNil(store.position(for: occurrence))
        let repeatedPlan = ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store)
        XCTAssertEqual(repeatedPlan.targets.count, 1)
        let messages = repeatedPlan.makeMessages(nativeCards: store, payload: streamPayload(state: "completed"),
                                                sessionId: "session", promptSuggestions: [])
        store.reconcile(with: messages)
        XCTAssertEqual(store.position(for: occurrence), 0)
        XCTAssertFalse(ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store).hasRenderableElements)
        store.removeAll()
        XCTAssertNil(store.position(for: occurrence))
        XCTAssertTrue(ResponseElementResolver.resolve(elements, turnId: turn, nativeCards: store).hasRenderableElements)
    }

    @MainActor
    func testResolverSeparatesExplicitMarkerIdsFromPositionIdentities() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(##"[{"type":"test.plan","id":"#1"},{"type":"test.plan"}]"##.utf8))
        let store = NativeCardStore()
        let plan = ResponseElementResolver.resolve(elements, turnId: UUID(), nativeCards: store)
        let messages = plan.makeMessages(nativeCards: store, payload: streamPayload(state: "completed"),
                                        sessionId: nil, promptSuggestions: [])
        let cards = nativeCards(in: messages)
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(Set(cards.map(\.occurrenceId)).count, 2)
    }

    @MainActor
    func testRejectedCandidateDoesNotReserveAnIdForItsValidSibling() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let nested = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
        let json = """
        [{"type":"test.plan","id":"same","nested":\(nested),"entity_info":{"productName":"Fallback"}},
         {"type":"test.plan","id":"same"},
         {"type":"test.plan","id":"same","entity_info":{"productName":"Duplicate fallback"}}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"),
                                            promptSuggestions: ["Continue"])
        XCTAssertEqual(controller.messages.count, 2)
        guard case .carouselGroup(let products) = controller.messages[0].template,
              case .nativeCard = controller.messages[1].template else {
            return XCTFail("Rejected candidates must preserve fallback order without reserving the ID")
        }
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(controller.messages[0].promptSuggestions, ["Continue"])
        XCTAssertEqual(nativeCards(in: controller.messages).count, 1)
    }

    @MainActor
    func testMixedResponseKeepsTextBatchingCtasSuggestionsAndTracking() async throws {
        NativeCardRegistry.register(type: "test.mixed") { _, _, _ in AnyView(EmptyView()) }
        let json = """
        [{"type":"ctaButton","entity_info":{"primary":{"text":"First CTA","url":"https://example.com/first"}}},
         {"type":"product","entity_info":{"productName":"One"}},
         {"type":"test.mixed","id":"first"},
         {"type":"product","entity_info":{"productName":"Two"}},
         {"type":"ctaButton","entity_info":{"primary":{"text":"Last CTA","url":"https://example.com/last"}}},
         {"type":"test.mixed","id":"last"}]
        """
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [streamPayload(state: "completed", elements: elements,
                                               message: "Final text", suggestions: ["Continue"])]
        var tracking: [[String: Any]] = []
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil,
                                        dispatch: { tracking.append($0.data ?? [:]) })
        let finished = expectation(description: "Mixed response rendered")
        controller.handleDataHandoff(routingHint: "mixed", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 6)
        XCTAssertEqual(controller.messages[0].messageBody, "Final text")
        XCTAssertTrue(controller.messages[0].isStreamComplete)
        guard case .ctaButton(let firstCTA) = controller.messages[1].template,
              case .carouselGroup(let products) = controller.messages[2].template,
              case .nativeCard(let first) = controller.messages[3].template,
              case .ctaButton(let lastCTA) = controller.messages[4].template,
              case .nativeCard(let last) = controller.messages[5].template else {
            return XCTFail("Text, batched products and independent element rows must retain their order")
        }
        XCTAssertEqual(firstCTA.text, "First CTA")
        XCTAssertEqual(lastCTA.text, "Last CTA")
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(controller.messages[2].promptSuggestions, ["Continue"])
        XCTAssertNil(controller.messages[3].promptSuggestions)
        XCTAssertNil(controller.messages[5].promptSuggestions)
        XCTAssertFalse(controller.messages[3].feedbackEligible)
        XCTAssertNil(controller.messages[3].messageBody)
        XCTAssertEqual(first.conversationId, "conversation")
        XCTAssertEqual(last.interactionId, "interaction")
        typealias Key = ConciergeConstants.TrackingEvent.EventData.Key
        typealias EventType = ConciergeConstants.TrackingEvent.XDMType
        let events = tracking.compactMap { $0[Key.EVENT_TYPE] as? String }
        XCTAssertEqual(events.filter { $0 == EventType.RESPONSE_STARTED }.count, 1)
        XCTAssertEqual(events.filter { $0 == EventType.RESPONSE_COMPLETED }.count, 1)
        let cardEvents = tracking.filter { ($0[Key.EVENT_TYPE] as? String) == EventType.CARDS_RENDERED }
        XCTAssertEqual(cardEvents.count, 1)
        XCTAssertEqual(cardEvents.first?["displayMode"] as? String, "carousel")
        let rendered = cardEvents.first?["elements"] as? [[String: Any]]
        XCTAssertEqual(rendered?.compactMap { $0["productName"] as? String }, ["One", "Two"])
    }

    @MainActor
    func testBuiltInOnlyResponseKeepsSeparateSuggestionRows() async throws {
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"product","entity_info":{"productName":"Product"}}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.plannedChunks = [streamPayload(state: "completed", elements: elements, suggestions: ["One", "Two"])]
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
        let finished = expectation(description: "Built-in suggestions rendered")
        controller.handleDataHandoff(routingHint: "products", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(controller.messages.count, 3)
        guard case .productCard = controller.messages[0].template,
              case .promptSuggestion(text: "One") = controller.messages[1].template,
              case .promptSuggestion(text: "Two") = controller.messages[2].template else {
            return XCTFail("Without a native row, suggestions must remain independent rows")
        }
        XCTAssertNil(controller.messages[0].promptSuggestions)
    }

    @MainActor
    func testNativeSuggestionsArePublishedWithTheirRowBeforeATrailingCta() throws {
        NativeCardRegistry.register(type: "test.plan") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data("""
        [{"type":"test.plan","id":"first"},{"type":"test.plan","id":"last"},
         {"type":"ctaButton","entity_info":{"primary":{"text":"CTA","url":"https://example.com"}}}]
        """.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        var published: [[Message]] = []
        let observation = controller.$messages.dropFirst().sink { published.append($0) }
        defer { observation.cancel() }
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"),
                                            promptSuggestions: ["Continue"])
        XCTAssertEqual(published.count, 1)
        XCTAssertEqual(published.first?.count, 3)
        XCTAssertEqual(published.first?[1].promptSuggestions, ["Continue"])
        XCTAssertNil(published.first?[0].promptSuggestions)
        XCTAssertNil(published.first?[2].promptSuggestions)
    }

    @MainActor
    func testRendererReplacementDuringTurnOnlyAffectsNewOccurrences() async throws {
        var renderedBy: [String] = []
        NativeCardRegistry.register(type: "test.replacement") { _, _, _ in
            renderedBy.append("first")
            return AnyView(EmptyView())
        }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.replacement","id":"same"}]"#.utf8))
        let service = MockChatService(configuration: ConciergeConfiguration())
        service.shouldCallComplete = false
        let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let original = try XCTUnwrap(nativeCards(in: controller.messages).first)
        var newCardWasBusy = false
        let observation = controller.$messages.sink { messages in
            let cards = self.nativeCards(in: messages)
            if cards.count == 2 { newCardWasBusy = cards[1].isBusy }
        }
        defer { observation.cancel() }
        let started = expectation(description: "Turn sent")
        service.onStreamChat = { started.fulfill() }
        let finished = expectation(description: "Replacement renderer activated")
        controller.handleDataHandoff(routingHint: "new-card", xdmFields: [:]) { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(original.isBusy)
        NativeCardRegistry.register(type: "test.replacement") { _, _, _ in
            renderedBy.append("replacement")
            return AnyView(EmptyView())
        }
        service.emitChunk(streamPayload(state: "completed", elements: elements))
        service.triggerCompletion()
        await fulfillment(of: [finished], timeout: 2)
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.count, 2)
        for card in cards { _ = card.renderer(card.element, card.context, { _ in }) }
        XCTAssertEqual(renderedBy, ["first", "replacement"])
        XCTAssertTrue(newCardWasBusy)
        XCTAssertFalse(original.isStale)
        XCTAssertFalse(original.isBusy)
        XCTAssertNotEqual(cards[0].cardId, cards[1].cardId)
    }

    @MainActor
    func testRollbackDisposesOnlyRemovedCardsAndRejectsQueuedSaves() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"older"},{"type":"test.lifecycle","id":"removed"}]"#.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.count, 2)
        cards[0].saveState(["kept": true])
        await Task.yield()
        cards[1].saveState(["queued": true])
        controller.messages.removeLast()
        await Task.yield()
        XCTAssertTrue(cards[1].isStale)
        XCTAssertTrue(cards[1].disposed)
        XCTAssertNil(cards[1].state)
        XCTAssertFalse(cards[0].isStale)
        XCTAssertEqual(cards[0].state?["kept"] as? Bool, true)
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let restored = nativeCards(in: controller.messages)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].cardId, cards[0].cardId)
        XCTAssertNotEqual(restored[1].cardId, cards[1].cardId)
        XCTAssertNil(restored[1].state)
    }

    @MainActor
    func testIdentityResetDisposesLiveCardsAndIgnoresQueuedSaves() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle"}]"#.utf8))
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let card = try XCTUnwrap(nativeCards(in: controller.messages).first)
        var observedStaleness = false
        let observation = card.$isStale.dropFirst().sink { observedStaleness = $0 }
        defer { observation.cancel() }
        card.saveState(["queued": true])
        controller.endConversationForIdentityReset()
        await Task.yield()
        XCTAssertTrue(observedStaleness)
        XCTAssertTrue(card.disposed)
        XCTAssertNil(card.state)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    @MainActor
    func testCardsAndSavedStateRemainPrivateToEachChat() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"same"}]"#.utf8))
        let controllers = (0..<2).map { _ in
            ChatController(configuration: nil, chatService: MockChatService(configuration: ConciergeConfiguration()),
                           speechCapturer: nil, speaker: nil)
        }
        let turn = UUID()
        for controller in controllers {
            controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        }
        let first = try XCTUnwrap(nativeCards(in: controllers[0].messages).first)
        let second = try XCTUnwrap(nativeCards(in: controllers[1].messages).first)
        first.saveState(["private": true])
        await Task.yield()
        XCTAssertEqual(first.state?["private"] as? Bool, true)
        XCTAssertNil(second.state)
        XCTAssertNotEqual(first.cardId, second.cardId)
        controllers[0].messages.removeAll()
        XCTAssertTrue(first.isStale)
        XCTAssertFalse(second.isStale)
    }

    @MainActor
    func testFailedAndCancelledTurnsDoNotDisposeEarlierCards() async throws {
        NativeCardRegistry.register(type: "test.lifecycle") { _, _, _ in AnyView(EmptyView()) }
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"test.lifecycle","id":"same"}]"#.utf8))
        for cancel in [false, true] {
            let service = MockChatService(configuration: ConciergeConfiguration())
            service.shouldCallComplete = false
            service.plannedError = .unreachable
            let controller = ChatController(configuration: nil, chatService: service, speechCapturer: nil, speaker: nil)
            controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
            let card = try XCTUnwrap(nativeCards(in: controller.messages).first)
            card.saveState(["kept": true])
            await Task.yield()
            let started = expectation(description: "Failing turn sent")
            service.onStreamChat = { started.fulfill() }
            let finished = expectation(description: "Failing turn ended")
            controller.handleDataHandoff(routingHint: "failed", xdmFields: [:]) { error in
                XCTAssertNotNil(error)
                finished.fulfill()
            }
            await fulfillment(of: [started], timeout: 2)
            XCTAssertTrue(card.isBusy)
            if cancel {
                controller.abandonActiveTurn()
            } else {
                service.emitChunk(streamPayload(state: "in-progress", elements: elements, message: "Partial"))
                service.triggerCompletion()
            }
            await fulfillment(of: [finished], timeout: 2)
            XCTAssertEqual(controller.chatState, .idle)
            XCTAssertEqual(controller.messages.count, 1)
            XCTAssertEqual(nativeCards(in: controller.messages).first?.cardId, card.cardId)
            XCTAssertEqual(card.state?["kept"] as? Bool, true)
            XCTAssertFalse(card.isStale)
            XCTAssertFalse(card.isBusy)
        }
    }

    @MainActor
    private func makeOrderingController() -> ChatController {
        NativeCardRegistry.register(type: "test.menu") { _, _, _ in AnyView(EmptyView()) }
        NativeCardRegistry.register(type: "test.cart") { _, _, _ in AnyView(EmptyView()) }
        return ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
    }

    private func orderingElements(_ json: String) throws -> [MultimodalElement] {
        try CardJSONValue.decode([MultimodalElement].self, from: Data(json.utf8))
    }

    @MainActor
    func testLastCardOfATypeInOneResponseIsLatestAndTypesAreIndependent() throws {
        let controller = makeOrderingController()
        let elements = try orderingElements(
            #"[{"type":"test.menu","id":"m1"},{"type":"test.cart","id":"c1"},{"type":"test.menu","id":"m2"}]"#)
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(cards.map(\.isLatest), [false, true, true])
        XCTAssertEqual(cards[2].context["sequence"] as? Int, 2)
        XCTAssertEqual(cards[2].context["isLatest"] as? Bool, true)
        XCTAssertEqual(cards[0].context["isLatest"] as? Bool, false)
    }

    @MainActor
    func testNewerTurnTakesOverLatestForItsTypeOnly() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(cards.map(\.isLatest), [false, true, true])
    }

    @MainActor
    func testRollbackPromotesTheNewestRemainingCardOfTheType() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"},{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.map(\.isLatest), [false, false, true, true])

        controller.messages.removeLast(2)
        XCTAssertTrue(cards[1].isLatest, "the highest remaining sequence of the type is promoted")
        XCTAssertFalse(cards[0].isLatest)
        XCTAssertFalse(cards[2].isLatest)
        XCTAssertFalse(cards[3].isLatest, "a disposed card is never latest")
        XCTAssertTrue(cards[3].disposed)

        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.cart"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let newCart = try XCTUnwrap(nativeCards(in: controller.messages).last)
        XCTAssertTrue(newCart.isLatest, "rolling back the only card of a type leaves no latest to demote")
        XCTAssertEqual(newCart.sequence, 4, "sequences are never reused after rollback")
    }

    @MainActor
    func testRejectedAndDuplicateElementsDoNotConsumeASequence() throws {
        let controller = makeOrderingController()
        let elements = try orderingElements(
            #"[{"type":"test.menu","id":"same"},{"type":"test.menu","id":"same"},{"type":"test.menu","id":"next"}]"#)
        let turn = UUID()
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        controller.renderElementsForTesting(elements, turnId: turn, payload: streamPayload(state: "completed"))
        let cards = nativeCards(in: controller.messages)
        XCTAssertEqual(cards.map(\.sequence), [0, 1])
        XCTAssertEqual(cards.map(\.isLatest), [false, true])
    }

    @MainActor
    func testRemovingAllCardsKeepsTheSequenceCounter() throws {
        let controller = makeOrderingController()
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let first = try XCTUnwrap(nativeCards(in: controller.messages).first)
        controller.messages.removeAll()
        XCTAssertFalse(first.isLatest)
        controller.renderElementsForTesting(try orderingElements(#"[{"type":"test.menu"}]"#),
                                            turnId: UUID(), payload: streamPayload(state: "completed"))
        let second = try XCTUnwrap(nativeCards(in: controller.messages).first)
        XCTAssertEqual(second.sequence, 1)
        XCTAssertTrue(second.isLatest)
    }

    @MainActor
    private func nativeCards(in messages: [Message]) -> [NativeCard] {
        messages.compactMap { message in
            if case .nativeCard(let card) = message.template { return card }
            return nil
        }
    }
}
