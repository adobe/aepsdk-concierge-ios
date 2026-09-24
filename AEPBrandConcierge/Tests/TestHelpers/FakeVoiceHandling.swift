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

import Foundation
@testable import AEPBrandConcierge

/// Dependency-free `VoiceHandling` double for `ChatController` tests, so the base module's test
/// target never needs the concrete LiveKit-backed implementation (which now lives in `AEPVoice`).
/// Records calls and lets tests drive state/transcript callbacks synchronously.
final class FakeVoiceHandling: VoiceHandling {
    private(set) var state: VoiceSessionState = .idle
    var onStateChange: ((VoiceSessionState) -> Void)?
    var onTranscriptUpdate: ((VoiceTranscriptRole, String, Bool) -> Void)?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastStartURL: String?
    private(set) var lastStartToken: String?

    func start(url: String, token: String) async {
        startCallCount += 1
        lastStartURL = url
        lastStartToken = token
        setState(.listening)
    }

    func stop() async {
        stopCallCount += 1
        setState(.idle)
    }

    // MARK: - Test drivers

    /// Sets `state` and fires `onStateChange`, mimicking the real handler's main-thread emission.
    func setState(_ newState: VoiceSessionState) {
        state = newState
        onStateChange?(newState)
    }

    /// Fires `onTranscriptUpdate` as the real handler would.
    func emitTranscript(_ role: VoiceTranscriptRole, _ text: String, isFinal: Bool) {
        onTranscriptUpdate?(role, text, isFinal)
    }
}
