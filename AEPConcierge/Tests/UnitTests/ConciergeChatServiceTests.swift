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
@testable import AEPConcierge

final class ConciergeChatServiceTests: XCTestCase {
    
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
}
