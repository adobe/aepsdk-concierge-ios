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
@testable import AEPCore
@testable import AEPBrandConcierge

final class SharedStateResultConciergeTests: XCTestCase {
    
    // MARK: - ECID Tests
    
    func test_ecid_withValidIdentityMap_returnsEcid() {
        // Given
        let value: [String: Any] = [
            "identityMap": [
                "ECID": [
                    ["id": "test-ecid-12345"]
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertEqual(ecid, "test-ecid-12345")
    }
    
    func test_ecid_withMultipleEcids_returnsFirstOne() {
        // Given
        let value: [String: Any] = [
            "identityMap": [
                "ECID": [
                    ["id": "first-ecid"],
                    ["id": "second-ecid"]
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertEqual(ecid, "first-ecid")
    }
    
    func test_ecid_withEmptyEcid_returnsNil() {
        // Given
        let value: [String: Any] = [
            "identityMap": [
                "ECID": [
                    ["id": ""]
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertNil(ecid)
    }
    
    func test_ecid_withNoIdentityMap_returnsNil() {
        // Given
        let value: [String: Any] = [:]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertNil(ecid)
    }
    
    func test_ecid_withEmptyEcidArray_returnsNil() {
        // Given
        let value: [String: Any] = [
            "identityMap": [
                "ECID": [] as [[String: Any]]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertNil(ecid)
    }
    
    func test_ecid_withMissingIdKey_returnsNil() {
        // Given
        let value: [String: Any] = [
            "identityMap": [
                "ECID": [
                    ["other": "value"]
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertNil(ecid)
    }
    
    func test_ecid_withNilValue_returnsNil() {
        // Given
        let result = SharedStateResult(status: .set, value: nil)
        
        // When
        let ecid = result.ecid
        
        // Then
        XCTAssertNil(ecid)
    }
    
    // MARK: - Concierge Server Tests
    
    func test_conciergeServer_withValidServer_returnsServer() {
        // Given
        let value: [String: Any] = [
            "concierge.server": "edge.adobedc.net"
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let server = result.conciergeServer
        
        // Then
        XCTAssertEqual(server, "edge.adobedc.net")
    }
    
    func test_conciergeServer_withMissingKey_returnsNil() {
        // Given
        let value: [String: Any] = [:]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let server = result.conciergeServer
        
        // Then
        XCTAssertNil(server)
    }
    
    func test_conciergeServer_withNonStringValue_returnsNil() {
        // Given
        let value: [String: Any] = [
            "concierge.server": 12345
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let server = result.conciergeServer
        
        // Then
        XCTAssertNil(server)
    }
    
    // MARK: - Concierge Datastream Tests
    
    func test_conciergeDatastream_withValidDatastream_returnsDatastream() {
        // Given
        let value: [String: Any] = [
            "concierge.configId": "datastream-123-456"
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let datastream = result.conciergeDatastream
        
        // Then
        XCTAssertEqual(datastream, "datastream-123-456")
    }
    
    func test_conciergeDatastream_withMissingKey_returnsNil() {
        // Given
        let value: [String: Any] = [:]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let datastream = result.conciergeDatastream
        
        // Then
        XCTAssertNil(datastream)
    }
    
    // MARK: - Collect Value Tests
    
    func test_collectValue_withValidConsent_returnsValue() {
        // Given
        let value: [String: Any] = [
            "consents": [
                "collect": [
                    "val": "y"
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, "y")
    }
    
    func test_collectValue_withConsentN_returnsN() {
        // Given
        let value: [String: Any] = [
            "consents": [
                "collect": [
                    "val": "n"
                ]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, "n")
    }
    
    func test_collectValue_withMissingConsents_returnsDefault() {
        // Given
        let value: [String: Any] = [:]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, ConciergeConstants.Defaults.CONSENT_VALUE)
    }
    
    func test_collectValue_withMissingCollect_returnsDefault() {
        // Given
        let value: [String: Any] = [
            "consents": [:] as [String: Any]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, ConciergeConstants.Defaults.CONSENT_VALUE)
    }
    
    func test_collectValue_withMissingVal_returnsDefault() {
        // Given
        let value: [String: Any] = [
            "consents": [
                "collect": [:] as [String: Any]
            ]
        ]
        let result = SharedStateResult(status: .set, value: value)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, ConciergeConstants.Defaults.CONSENT_VALUE)
    }
    
    func test_collectValue_withNilValue_returnsDefault() {
        // Given
        let result = SharedStateResult(status: .set, value: nil)
        
        // When
        let collectValue = result.collectValue
        
        // Then
        XCTAssertEqual(collectValue, ConciergeConstants.Defaults.CONSENT_VALUE)
    }
}
