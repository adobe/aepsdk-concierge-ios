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

/// Unit coverage for `VoiceSessionController`. The connect / mic-publish / interruption / route-change
/// behaviors are validated on real devices (see the audio-session design §8) — `AVAudioSession`
/// behavior is not meaningfully testable in the simulator — so these tests cover the deterministic,
/// no-`Room`-needed surface: initial/derived state.
final class VoiceSessionControllerTests: XCTestCase {

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
