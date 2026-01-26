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

final class ConsentStateTests: XCTestCase {
    
    // MARK: - Raw Value Tests
    
    func test_rawValue_optedIn_isY() {
        XCTAssertEqual(ConsentState.optedIn.rawValue, "y")
    }
    
    func test_rawValue_optedOut_isN() {
        XCTAssertEqual(ConsentState.optedOut.rawValue, "n")
    }
    
    func test_rawValue_unknown_isU() {
        XCTAssertEqual(ConsentState.unknown.rawValue, "u")
    }
    
    // MARK: - Payload Value Tests
    
    func test_payloadValue_optedIn_returnsIn() {
        XCTAssertEqual(ConsentState.optedIn.payloadValue, "in")
    }
    
    func test_payloadValue_optedOut_returnsOut() {
        XCTAssertEqual(ConsentState.optedOut.payloadValue, "out")
    }
    
    func test_payloadValue_unknown_returnsUnknown() {
        XCTAssertEqual(ConsentState.unknown.payloadValue, "unknown")
    }
    
    // MARK: - Init from Config Value Tests
    
    func test_initConfigValue_y_returnsOptedIn() {
        let state = ConsentState(configValue: "y")
        XCTAssertEqual(state, .optedIn)
        XCTAssertEqual(state.payloadValue, "in")
    }
    
    func test_initConfigValue_n_returnsOptedOut() {
        let state = ConsentState(configValue: "n")
        XCTAssertEqual(state, .optedOut)
        XCTAssertEqual(state.payloadValue, "out")
    }
    
    func test_initConfigValue_u_returnsUnknown() {
        let state = ConsentState(configValue: "u")
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
    
    func test_initConfigValue_nil_defaultsToUnknown() {
        let state = ConsentState(configValue: nil)
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
    
    func test_initConfigValue_invalidValue_defaultsToUnknown() {
        let state = ConsentState(configValue: "invalid")
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
    
    func test_initConfigValue_emptyString_defaultsToUnknown() {
        let state = ConsentState(configValue: "")
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
    
    func test_initConfigValue_uppercaseY_defaultsToUnknown() {
        // Ensures case sensitivity - "Y" should not match "y"
        let state = ConsentState(configValue: "Y")
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
    
    func test_initConfigValue_uppercaseN_defaultsToUnknown() {
        // Ensures case sensitivity - "N" should not match "n"
        let state = ConsentState(configValue: "N")
        XCTAssertEqual(state, .unknown)
        XCTAssertEqual(state.payloadValue, "unknown")
    }
}
