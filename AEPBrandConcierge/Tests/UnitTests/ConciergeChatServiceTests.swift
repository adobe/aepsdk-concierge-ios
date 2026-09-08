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

final class ConciergeChatServiceTests: XCTestCase {

    override func tearDown() {
        // The resolver is a shared singleton; clear it so a provider set in one test never leaks.
        ConciergeAuthTokenResolver.shared.setProvider(nil)
        super.tearDown()
    }

    // MARK: - Test Helpers
    
    private func makeConfiguration(
        consentCollectValue: String? = nil,
        ecid: String = "test-ecid-12345",
        surfaces: [String] = ["web://test.adobe.com/surface"]
    ) -> ConciergeConfiguration {
        return ConciergeConfiguration(
            consentCollectValue: consentCollectValue,
            ecid: ecid,
            surfaces: surfaces
        )
    }
    
    private func extractPayloadDictionary(from service: ConciergeChatService, query: String) throws -> [String: Any] {
        let payloadData = try service.createChatPayload(query: query)
        guard let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw NSError(domain: "TestError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse payload as dictionary"])
        }
        return payload
    }
    
    private func extractFirstEvent(from payload: [String: Any]) -> [String: Any]? {
        guard let events = payload["events"] as? [[String: Any]],
              let firstEvent = events.first else {
            return nil
        }
        return firstEvent
    }
    
    private func extractConsentState(from event: [String: Any]) -> String? {
        guard let meta = event["meta"] as? [String: Any],
              let consent = meta["consent"] as? [String: Any],
              let state = consent["state"] as? String else {
            return nil
        }
        return state
    }
    
    // MARK: - Consent Metadata Tests
    
    func test_createChatPayload_withConsentY_includesMetaConsentStateIn() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Hello")
        let event = extractFirstEvent(from: payload)
        let consentState = extractConsentState(from: event!)
        
        // Then
        XCTAssertEqual(consentState, "in")
    }
    
    func test_createChatPayload_withConsentN_includesMetaConsentStateOut() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "n")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Hello")
        let event = extractFirstEvent(from: payload)
        let consentState = extractConsentState(from: event!)
        
        // Then
        XCTAssertEqual(consentState, "out")
    }
    
    func test_createChatPayload_withConsentU_includesMetaConsentStateUnknown() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "u")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Hello")
        let event = extractFirstEvent(from: payload)
        let consentState = extractConsentState(from: event!)
        
        // Then
        XCTAssertEqual(consentState, "unknown")
    }
    
    func test_createChatPayload_withNilConsent_includesMetaConsentStateUnknown() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: nil)
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Hello")
        let event = extractFirstEvent(from: payload)
        let consentState = extractConsentState(from: event!)
        
        // Then
        XCTAssertEqual(consentState, "unknown")
    }
    
    func test_createChatPayload_withInvalidConsent_includesMetaConsentStateUnknown() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "invalid")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Hello")
        let event = extractFirstEvent(from: payload)
        let consentState = extractConsentState(from: event!)
        
        // Then
        XCTAssertEqual(consentState, "unknown")
    }
    
    // MARK: - Payload Structure Tests
    
    func test_createChatPayload_containsMetaObjectAtEventLevel() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Test query")
        let event = extractFirstEvent(from: payload)
        
        // Then
        XCTAssertNotNil(event?["meta"], "Payload should contain 'meta' object at event level")
    }
    
    func test_createChatPayload_metaContainsConsentObject() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Test query")
        let event = extractFirstEvent(from: payload)
        let meta = event?["meta"] as? [String: Any]
        
        // Then
        XCTAssertNotNil(meta?["consent"], "Meta should contain 'consent' object")
    }
    
    func test_createChatPayload_consentContainsStateKey() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Test query")
        let event = extractFirstEvent(from: payload)
        let meta = event?["meta"] as? [String: Any]
        let consent = meta?["consent"] as? [String: Any]
        
        // Then
        XCTAssertNotNil(consent?["state"], "Consent should contain 'state' key")
    }
    
    func test_createChatPayload_containsQueryAndXdmAlongsideMeta() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        
        // When
        let payload = try extractPayloadDictionary(from: service, query: "Test query")
        let event = extractFirstEvent(from: payload)
        
        // Then
        XCTAssertNotNil(event?["query"], "Event should contain 'query' object")
        XCTAssertNotNil(event?["xdm"], "Event should contain 'xdm' object")
        XCTAssertNotNil(event?["meta"], "Event should contain 'meta' object")
    }
    
    // MARK: - Error Cases
    
    func test_createChatPayload_withNilEcid_throwsInvalidEcidError() {
        // Given
        let configuration = ConciergeConfiguration(
            consentCollectValue: "y",
            ecid: nil,
            surfaces: ["web://test.adobe.com/surface"]
        )
        let service = ConciergeChatService(configuration: configuration)
        
        // When / Then
        XCTAssertThrowsError(try service.createChatPayload(query: "Hello")) { error in
            guard let conciergeError = error as? ConciergeError else {
                XCTFail("Expected ConciergeError")
                return
            }
            if case .invalidEcid = conciergeError {
                // Success
            } else {
                XCTFail("Expected invalidEcid error, got \(conciergeError)")
            }
        }
    }
    
    func test_createChatPayload_withEmptySurfaces_throwsInvalidSurfacesError() {
        // Given
        let configuration = ConciergeConfiguration(
            consentCollectValue: "y",
            ecid: "test-ecid",
            surfaces: []
        )
        let service = ConciergeChatService(configuration: configuration)
        
        // When / Then
        XCTAssertThrowsError(try service.createChatPayload(query: "Hello")) { error in
            guard let conciergeError = error as? ConciergeError else {
                XCTFail("Expected ConciergeError")
                return
            }
            if case .invalidSurfaces = conciergeError {
                // Success
            } else {
                XCTFail("Expected invalidSurfaces error, got \(conciergeError)")
            }
        }
    }
    
    // MARK: - Feedback Payload Consent Tests
    
    private func extractFeedbackPayloadDictionary(from service: ConciergeChatService, data: [String: Any]) throws -> [String: Any] {
        let payloadData = try service.createFeedbackPayload(data: data)
        guard let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw NSError(domain: "TestError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse feedback payload as dictionary"])
        }
        return payload
    }
    
    private func extractFeedbackConsentState(from payload: [String: Any]) -> String? {
        guard let meta = payload["meta"] as? [String: Any],
              let consent = meta["consent"] as? [String: Any],
              let state = consent["state"] as? String else {
            return nil
        }
        return state
    }
    
    func test_createFeedbackPayload_withConsentY_includesMetaConsentStateIn() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = ["eventType": "conversation.feedback"]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        let consentState = extractFeedbackConsentState(from: payload)
        
        // Then
        XCTAssertEqual(consentState, "in")
    }
    
    func test_createFeedbackPayload_withConsentN_includesMetaConsentStateOut() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "n")
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = ["eventType": "conversation.feedback"]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        let consentState = extractFeedbackConsentState(from: payload)
        
        // Then
        XCTAssertEqual(consentState, "out")
    }
    
    func test_createFeedbackPayload_withConsentU_includesMetaConsentStateUnknown() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "u")
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = ["eventType": "conversation.feedback"]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        let consentState = extractFeedbackConsentState(from: payload)
        
        // Then
        XCTAssertEqual(consentState, "unknown")
    }
    
    func test_createFeedbackPayload_withNilConsent_includesMetaConsentStateUnknown() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: nil)
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = ["eventType": "conversation.feedback"]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        let consentState = extractFeedbackConsentState(from: payload)
        
        // Then
        XCTAssertEqual(consentState, "unknown")
    }
    
    func test_createFeedbackPayload_preservesOriginalData() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = [
            "eventType": "conversation.feedback",
            "feedback": ["rating": "positive"]
        ]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        
        // Then
        XCTAssertEqual(payload["eventType"] as? String, "conversation.feedback")
        XCTAssertNotNil(payload["feedback"])
        XCTAssertNotNil(payload["meta"], "Feedback payload should contain 'meta' object")
    }
    
    func test_createFeedbackPayload_containsMetaConsentStructure() throws {
        // Given
        let configuration = makeConfiguration(consentCollectValue: "y")
        let service = ConciergeChatService(configuration: configuration)
        let feedbackData: [String: Any] = ["eventType": "conversation.feedback"]
        
        // When
        let payload = try extractFeedbackPayloadDictionary(from: service, data: feedbackData)
        let meta = payload["meta"] as? [String: Any]
        let consent = meta?["consent"] as? [String: Any]
        
        // Then
        XCTAssertNotNil(meta, "Payload should contain 'meta' object")
        XCTAssertNotNil(consent, "Meta should contain 'consent' object")
        XCTAssertNotNil(consent?["state"], "Consent should contain 'state' key")
    }

    // MARK: - Auth Token: Chat Payload

    private func chatConversation(from payload: [String: Any]) -> [String: Any]? {
        guard let event = extractFirstEvent(from: payload),
              let query = event["query"] as? [String: Any],
              let conversation = query["conversation"] as? [String: Any] else {
            return nil
        }
        return conversation
    }

    func test_createChatPayload_withToken_attachesAuthDataPartAlongsideMessage() throws {
        // Given
        let service = ConciergeChatService(configuration: makeConfiguration())

        // When
        let data = try service.createChatPayload(query: "hello", token: "token-abc")
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let conversation = chatConversation(from: payload)

        // Then
        XCTAssertNotNil(conversation?["message"], "message should still be present")
        let auth = conversation?["data"] as? [String: Any]
        XCTAssertEqual(auth?["type"] as? String, "auth")
        XCTAssertEqual((auth?["payload"] as? [String: Any])?["token"] as? String, "token-abc")
    }

    func test_createChatPayload_withNilToken_omitsAuthDataPart() throws {
        // Given
        let service = ConciergeChatService(configuration: makeConfiguration())

        // When
        let data = try service.createChatPayload(query: "hello", token: nil)
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then
        XCTAssertNil(chatConversation(from: payload)?["data"], "No data part should be present without a token")
    }

    func test_createChatPayload_withEmptyToken_omitsAuthDataPart() throws {
        // Given
        let service = ConciergeChatService(configuration: makeConfiguration())

        // When
        let data = try service.createChatPayload(query: "hello", token: "")
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then
        XCTAssertNil(chatConversation(from: payload)?["data"])
    }

    // MARK: - Auth Token: Feedback Payload

    private func feedbackConversation(from payload: [String: Any]) -> [String: Any]? {
        guard let xdm = payload["xdm"] as? [String: Any],
              let conversation = xdm["conversation"] as? [String: Any] else {
            return nil
        }
        return conversation
    }

    func test_createFeedbackPayload_withToken_attachesAuthDataPartInXdmConversation() throws {
        // Given
        let service = ConciergeChatService(configuration: makeConfiguration())
        let feedbackData: [String: Any] = [
            "eventType": "conversation.feedback",
            "xdm": [
                "conversation": [
                    "feedback": ["source": "end-user"],
                    "turnID": "turn-1"
                ]
            ]
        ]

        // When
        let data = try service.createFeedbackPayload(data: feedbackData, token: "token-abc")
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let conversation = feedbackConversation(from: payload)

        // Then
        XCTAssertNotNil(conversation?["turnID"], "turnID should still be present")
        let auth = conversation?["data"] as? [String: Any]
        XCTAssertEqual(auth?["type"] as? String, "auth")
        XCTAssertEqual((auth?["payload"] as? [String: Any])?["token"] as? String, "token-abc")
    }

    func test_createFeedbackPayload_withNilToken_omitsAuthDataPart() throws {
        // Given
        let service = ConciergeChatService(configuration: makeConfiguration())
        let feedbackData: [String: Any] = [
            "xdm": ["conversation": ["turnID": "turn-1"]]
        ]

        // When
        let data = try service.createFeedbackPayload(data: feedbackData, token: nil)
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then
        XCTAssertNil(feedbackConversation(from: payload)?["data"])
    }

    // MARK: - Auth Token: Helpers

    func test_authDataPart_withToken_returnsAuthShape() {
        let part = ConciergeChatService.authDataPart(for: "token-abc")
        XCTAssertEqual(part?["type"] as? String, "auth")
        XCTAssertEqual((part?["payload"] as? [String: Any])?["token"] as? String, "token-abc")
    }

    func test_authDataPart_withNilEmptyOrBlank_returnsNil() {
        XCTAssertNil(ConciergeChatService.authDataPart(for: nil))
        XCTAssertNil(ConciergeChatService.authDataPart(for: ""))
        XCTAssertNil(ConciergeChatService.authDataPart(for: "   "))
        XCTAssertNil(ConciergeChatService.authDataPart(for: "\n\t "))
    }

    // MARK: - Auth Token: Resolver

    func test_resolver_withNoProvider_returnsNil() async {
        ConciergeAuthTokenResolver.shared.setProvider(nil)
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertNil(token)
    }

    func test_resolver_returnsSynchronousProviderValue() async {
        ConciergeAuthTokenResolver.shared.setProvider { "token-abc" }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "token-abc")
    }

    func test_resolver_awaitsAsynchronousProviderValue() async {
        ConciergeAuthTokenResolver.shared.setProvider {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms — provider suspends
            return "async-token"
        }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "async-token")
    }

    func test_resolver_providerSlowerThanTimeout_resolvesToNilAtTheBound() async {
        let resolver = ConciergeAuthTokenResolver()

        // Provider that takes far longer than the configured bound; resolveToken must not wait for it.
        resolver.setProvider({
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            return "too-late"
        }, timeout: 0.1) // 100ms

        let start = Date()
        let token = await resolver.resolveToken()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertNil(token, "A provider slower than the timeout must yield no token")
        XCTAssertLessThan(elapsed, 1.0, "resolveToken must return at the timeout, not wait for the provider")
    }

    func test_resolver_customTimeout_allowsSlowerProvider() async {
        // A raised timeout lets a provider that's slower than the default-ish still deliver a token.
        let resolver = ConciergeAuthTokenResolver()
        resolver.setProvider({
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            return "slow-but-ok"
        }, timeout: 1.0)

        let token = await resolver.resolveToken()
        XCTAssertEqual(token, "slow-but-ok", "a provider within the configured timeout must yield its token")
    }

    func test_resolver_nonFiniteOrHugeTimeout_isClampedAndDoesNotCrash() async {
        // The seconds->nanoseconds UInt64 conversion must never trap on out-of-range input.
        for timeout in [TimeInterval.infinity, .greatestFiniteMagnitude, 1e300, .nan] {
            let resolver = ConciergeAuthTokenResolver()
            resolver.setProvider({ "tok" }, timeout: timeout)
            let token = await resolver.resolveToken()
            XCTAssertEqual(token, "tok", "a fast provider must still resolve regardless of the clamped timeout")
        }
    }

    func test_setAuthTokenProvider_infiniteTimeout_doesNotCrash() async {
        // Guards the public API entry point against the same trap.
        Concierge.setAuthTokenProvider(timeout: .infinity) { "athlete-token" }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "athlete-token")
    }

    func test_resolver_withBlankToken_returnsNil() async {
        ConciergeAuthTokenResolver.shared.setProvider { "   " }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertNil(token)
    }

    func test_resolver_afterClear_returnsNil() async {
        ConciergeAuthTokenResolver.shared.setProvider { "token-abc" }
        ConciergeAuthTokenResolver.shared.setProvider(nil)
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertNil(token)
    }

    func test_resolver_usesMostRecentProvider() async {
        ConciergeAuthTokenResolver.shared.setProvider { "first" }
        ConciergeAuthTokenResolver.shared.setProvider { "second" }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "second")
    }

    func test_resolver_invokesProviderEveryCall_neverCaches() async {
        actor Counter { var n = 0; func next() -> Int { n += 1; return n } }
        let counter = Counter()
        ConciergeAuthTokenResolver.shared.setProvider { "token-\(await counter.next())" }

        let first = await ConciergeAuthTokenResolver.shared.resolveToken()
        let second = await ConciergeAuthTokenResolver.shared.resolveToken()

        XCTAssertEqual(first, "token-1")
        XCTAssertEqual(second, "token-2")
    }

    // MARK: - Auth Token: Public API

    func test_setAuthTokenProvider_registersWithResolver() async {
        Concierge.setAuthTokenProvider { "athlete-token" }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "athlete-token")
    }

    func test_setAuthTokenProvider_nil_clearsProvider() async {
        Concierge.setAuthTokenProvider { "athlete-token" }
        Concierge.setAuthTokenProvider(nil)
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertNil(token)
    }

    func test_setAuthTokenProvider_withCustomTimeout_registers() async {
        Concierge.setAuthTokenProvider(timeout: 8) { "athlete-token" }
        let token = await ConciergeAuthTokenResolver.shared.resolveToken()
        XCTAssertEqual(token, "athlete-token")
    }

    // MARK: - Auth Token: Request-path integration (stubbed network)

    func test_streamChat_withToken_omitsAuthorizationHeader() async {
        StubURLProtocol.reset()
        let service = makeStubbedService()

        service.streamChat("hello", token: "athlete-token-123", onChunk: { _ in }, onComplete: { _ in })
        await waitForCondition(timeout: 3.0) { StubURLProtocol.count >= 1 }

        guard let request = StubURLProtocol.last else {
            XCTFail("streamChat did not issue a request")
            return
        }
        // The token rides in the body (covered by the payload-builder tests) — never a header.
        let headers = request.allHTTPHeaderFields ?? [:]
        XCTAssertNil(headers.keys.first { $0.caseInsensitiveCompare("Authorization") == .orderedSame },
                     "The token must never be sent as an Authorization header")
        XCTAssertFalse(headers.values.contains { $0.contains("athlete-token-123") },
                       "The token must not appear in any header")
    }

    func test_sendFeedback_issuesRequestThroughService() async {
        StubURLProtocol.reset()
        let service = makeStubbedService()

        service.sendFeedback(data: ["xdm": ["conversation": ["feedback": ["source": "end-user"], "turnID": "t-1"]]], token: "athlete-token-123")
        await waitForCondition(timeout: 3.0) { StubURLProtocol.count >= 1 }
        try? await Task.sleep(nanoseconds: 300_000_000) // let the completion handler run

        guard let request = StubURLProtocol.last else {
            XCTFail("sendFeedback did not issue a request")
            return
        }
        let headers = request.allHTTPHeaderFields ?? [:]
        XCTAssertNil(headers.keys.first { $0.caseInsensitiveCompare("Authorization") == .orderedSame },
                     "Feedback must not send the token as an Authorization header")
    }

    func test_sendFeedback_networkError_isHandledWithoutCrashing() async {
        StubURLProtocol.reset()
        StubURLProtocol.shouldFail = true
        let service = makeStubbedService()

        service.sendFeedback(data: ["xdm": ["conversation": ["turnID": "t-1"]]], token: nil)
        await waitForCondition(timeout: 3.0) { StubURLProtocol.count >= 1 }
        try? await Task.sleep(nanoseconds: 300_000_000) // let the failing completion run

        XCTAssertGreaterThanOrEqual(StubURLProtocol.count, 1, "the request was issued; a network error is handled quietly")
    }

    func test_streamChat_withUnbuildableURL_completesWithError() async {
        // makeConfiguration() has no server, so createUrl() throws — exercising streamChat's catch.
        let service = ConciergeChatService(configuration: makeConfiguration())
        let received = LockedBox<ConciergeError?>(nil)

        service.streamChat("hi", token: nil, onChunk: { _ in }, onComplete: { received.value = $0 })
        await waitForCondition(timeout: 3.0) { received.value != nil }

        XCTAssertNotNil(received.value, "streamChat should surface a ConciergeError when the URL can't be built")
    }

    func test_sendFeedback_withUnbuildableURL_doesNotIssueRequest() async {
        StubURLProtocol.reset()
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        // No server -> createUrl() throws before any request is sent.
        let service = ConciergeChatService(configuration: makeConfiguration(), urlSessionConfiguration: sessionConfig)

        service.sendFeedback(data: ["xdm": ["conversation": ["turnID": "t-1"]]], token: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(StubURLProtocol.count, 0, "no request should be issued when the URL can't be built")
    }

    func test_createFeedbackPayload_withTokenButNoConversationNode_omitsToken() throws {
        let service = ConciergeChatService(configuration: makeConfiguration())
        // xdm present but no `conversation` node -> the token can't attach; the branch warns and omits.
        let data: [String: Any] = ["xdm": ["identityMap": ["ECID": [["id": "e"]]]]]

        let payloadData = try service.createFeedbackPayload(data: data, token: "athlete-token-123")
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        XCTAssertNil((payload["xdm"] as? [String: Any])?["conversation"], "no conversation node was present")
        let json = String(data: payloadData, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("athlete-token-123"), "token omitted when there is no conversation node to attach to")
    }

    // MARK: - Stubbed-network helpers

    private func makeStubbedService() -> ConciergeChatService {
        let model = ConciergeConfiguration(consentCollectValue: "y",
                                           datastream: "ds-123",
                                           ecid: "ecid-123",
                                           server: "test.example.com",
                                           surfaces: ["web://test.adobe.com/surface"])
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        return ConciergeChatService(configuration: model, urlSessionConfiguration: sessionConfig)
    }

    private func waitForCondition(timeout: TimeInterval, _ condition: @escaping () -> Bool) async {
        let start = Date()
        while !condition() && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}

/// Intercepts requests from an injected `URLSessionConfiguration` so tests can drive the service's
/// request path without real networking. Captures requests (thread-safe) and returns an empty 200.
private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests: [URLRequest] = []
    private static var _shouldFail = false

    static func reset() { lock.lock(); requests = []; _shouldFail = false; lock.unlock() }
    static var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
    static var last: URLRequest? { lock.lock(); defer { lock.unlock() }; return requests.last }
    static var shouldFail: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _shouldFail }
        set { lock.lock(); defer { lock.unlock() }; _shouldFail = newValue }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lock.lock()
        StubURLProtocol.requests.append(request)
        let shouldFail = StubURLProtocol._shouldFail
        StubURLProtocol.lock.unlock()

        if shouldFail {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "StubURLProtocol", code: -1))
            return
        }
        if let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Thread-safe box for capturing a callback value from a background task in a test.
private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}
