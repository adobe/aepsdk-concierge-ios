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

import AVFoundation
import XCTest
@testable import AEPBrandConcierge

/// Unit coverage for `VoiceSessionController`. The connect / mic-publish / interruption / route-change
/// behaviors are validated on real devices (see the audio-session design §8) — `AVAudioSession`
/// behavior is not meaningfully testable in the simulator — so these tests cover the deterministic,
/// no-`Room`-needed surface: the audio policy values and the initial state.
final class VoiceSessionControllerTests: XCTestCase {

    // MARK: - Audio session policy (audio-session design §6.1 / §6.5)

    func test_audioSessionPolicy_matchesLiveKitPlayAndRecordSpeaker() {
        // Category / mode: full-duplex, echo-cancelled; `.videoChat`, deliberately not `.voiceChat`.
        XCTAssertEqual(VoiceSessionController.audioSessionCategory, .playAndRecord)
        XCTAssertEqual(VoiceSessionController.audioSessionMode, .videoChat)

        // Options mirror LiveKit's `.playAndRecordSpeaker` preset.
        let options = VoiceSessionController.audioSessionCategoryOptions
        XCTAssertTrue(options.contains(.allowBluetooth))
        XCTAssertTrue(options.contains(.allowBluetoothA2DP))
        XCTAssertTrue(options.contains(.allowAirPlay))
        XCTAssertTrue(options.contains(.defaultToSpeaker))
    }

    func test_audioSessionPolicy_omitsMixWithOthers() {
        // `.mixWithOthers` triggers a WebRTC engine-init race on the record path — must stay absent.
        XCTAssertFalse(VoiceSessionController.audioSessionCategoryOptions.contains(.mixWithOthers))
    }

    // MARK: - Initial state

    func test_initialState_isIdle() {
        let controller = VoiceSessionController()
        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: - State equality

    func test_state_failedEquality_comparesReason() {
        XCTAssertEqual(VoiceSessionController.State.failed("x"), .failed("x"))
        XCTAssertNotEqual(VoiceSessionController.State.failed("x"), .failed("y"))
        XCTAssertNotEqual(VoiceSessionController.State.connecting, .listening)
    }
}
