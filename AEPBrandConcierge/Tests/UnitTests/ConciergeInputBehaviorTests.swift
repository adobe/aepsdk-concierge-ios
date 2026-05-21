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

import Foundation
import XCTest

@testable import AEPBrandConcierge

/// Tests defaults, overrides, and Codable round-trips for `ConciergeInputBehavior`.
final class ConciergeInputBehaviorTests: XCTestCase {

    // MARK: - Default values

    func test_defaults_enableRecordingAnimationIsFalse() {
        let behavior = ConciergeInputBehavior()
        XCTAssertFalse(behavior.enableRecordingAnimation)
    }

    func test_defaults_stopRecordingIconIsNil() {
        let behavior = ConciergeInputBehavior()
        XCTAssertNil(behavior.stopRecordingIcon)
    }

    func test_defaults_allFieldsHaveExpectedValues() {
        let behavior = ConciergeInputBehavior()

        XCTAssertFalse(behavior.enableVoiceInput)
        XCTAssertTrue(behavior.disableMultiline)
        XCTAssertNil(behavior.showAiChatIcon)
        XCTAssertEqual(behavior.sendButtonStyle, "default")
        XCTAssertEqual(behavior.silenceThreshold, 0.02)
        XCTAssertEqual(behavior.silenceDuration, 2.0)
        XCTAssertFalse(behavior.enableRecordingAnimation)
        XCTAssertNil(behavior.stopRecordingIcon)
    }

    // MARK: - Explicit overrides via init

    func test_init_enableRecordingAnimationTrue() {
        let behavior = ConciergeInputBehavior(enableRecordingAnimation: true)
        XCTAssertTrue(behavior.enableRecordingAnimation)
    }

    func test_init_stopRecordingIconCustomValue() {
        let behavior = ConciergeInputBehavior(stopRecordingIcon: "custom_stop_icon")
        XCTAssertEqual(behavior.stopRecordingIcon, "custom_stop_icon")
    }

    // MARK: - JSON decoding with missing keys

    func test_decode_missingKeys_usesDefaults() throws {
        let json = #"{}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)

        XCTAssertFalse(decoded.enableRecordingAnimation)
        XCTAssertNil(decoded.stopRecordingIcon)
        XCTAssertFalse(decoded.enableVoiceInput)
        XCTAssertTrue(decoded.disableMultiline)
        XCTAssertEqual(decoded.sendButtonStyle, "default")
        XCTAssertEqual(decoded.silenceThreshold, 0.02)
        XCTAssertEqual(decoded.silenceDuration, 2.0)
    }

    func test_decode_missingRecordingFields_usesDefaults() throws {
        let json = #"{"enableVoiceInput": true}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)

        XCTAssertTrue(decoded.enableVoiceInput)
        XCTAssertFalse(decoded.enableRecordingAnimation)
        XCTAssertNil(decoded.stopRecordingIcon)
    }

    // MARK: - JSON decoding with explicit values

    func test_decode_enableRecordingAnimationTrue() throws {
        let json = #"{"enableRecordingAnimation": true}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)
        XCTAssertTrue(decoded.enableRecordingAnimation)
    }

    func test_decode_enableRecordingAnimationFalse() throws {
        let json = #"{"enableRecordingAnimation": false}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)
        XCTAssertFalse(decoded.enableRecordingAnimation)
    }

    func test_decode_stopRecordingIconPresent() throws {
        let json = #"{"stopRecordingIcon": "my_stop_icon"}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)
        XCTAssertEqual(decoded.stopRecordingIcon, "my_stop_icon")
    }

    func test_decode_allRecordingFieldsPresent() throws {
        let json = #"""
        {
            "enableVoiceInput": true,
            "enableRecordingAnimation": true,
            "stopRecordingIcon": "record_stop"
        }
        """#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: data)

        XCTAssertTrue(decoded.enableVoiceInput)
        XCTAssertTrue(decoded.enableRecordingAnimation)
        XCTAssertEqual(decoded.stopRecordingIcon, "record_stop")
    }

    // MARK: - Codable round-trip

    func test_codable_roundTrip_preservesAllFields() throws {
        let original = ConciergeInputBehavior(
            enableVoiceInput: true,
            disableMultiline: false,
            sendButtonStyle: "arrow",
            silenceThreshold: 0.05,
            silenceDuration: 3.0,
            enableRecordingAnimation: true,
            stopRecordingIcon: "custom_icon"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: encoded)

        XCTAssertEqual(decoded.enableVoiceInput, true)
        XCTAssertEqual(decoded.disableMultiline, false)
        XCTAssertEqual(decoded.sendButtonStyle, "arrow")
        XCTAssertEqual(decoded.silenceThreshold, 0.05)
        XCTAssertEqual(decoded.silenceDuration, 3.0)
        XCTAssertEqual(decoded.enableRecordingAnimation, true)
        XCTAssertEqual(decoded.stopRecordingIcon, "custom_icon")
    }

    func test_codable_roundTrip_nilStopRecordingIconPreserved() throws {
        let original = ConciergeInputBehavior(stopRecordingIcon: nil)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: encoded)

        XCTAssertNil(decoded.stopRecordingIcon)
        XCTAssertFalse(decoded.enableRecordingAnimation)
    }

    func test_codable_roundTrip_defaultValues() throws {
        let original = ConciergeInputBehavior()

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeInputBehavior.self, from: encoded)

        XCTAssertEqual(decoded.enableVoiceInput, original.enableVoiceInput)
        XCTAssertEqual(decoded.disableMultiline, original.disableMultiline)
        XCTAssertEqual(decoded.sendButtonStyle, original.sendButtonStyle)
        XCTAssertEqual(decoded.silenceThreshold, original.silenceThreshold)
        XCTAssertEqual(decoded.silenceDuration, original.silenceDuration)
        XCTAssertEqual(decoded.enableRecordingAnimation, original.enableRecordingAnimation)
        XCTAssertEqual(decoded.stopRecordingIcon, original.stopRecordingIcon)
    }
}
