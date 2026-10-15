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
import AEPPluginSupport

/// In-memory `VoicePlugin` for tests: records what Brand Concierge asks for and lets a test drive
/// each session's callbacks, without LiveKit or audio.
final class FakeVoicePlugin: NSObject, VoicePlugin {
    private(set) var connections: [[String: String]] = []
    private(set) var sessions: [FakeVoiceSession] = []

    /// Runs inside `startSession` before it returns, to model a plugin that calls back synchronously.
    var onStartSession: ((FakeVoiceSession) -> Void)?

    var lastSession: FakeVoiceSession? { sessions.last }

    func startSession(connection: [String: String], listener: VoiceSessionListener) -> VoiceSession {
        connections.append(connection)
        let session = FakeVoiceSession(listener: listener)
        sessions.append(session)
        onStartSession?(session)
        return session
    }
}

/// A session that follows the contract: starts `.connecting`, holds its listener weakly, reports on
/// the calling (main) thread, and `stop()` is idempotent and reports `.ended` synchronously.
final class FakeVoiceSession: VoiceSession {
    private weak var listener: VoiceSessionListener?
    private(set) var state: VoiceSessionState = .connecting
    private(set) var stopCallCount = 0

    init(listener: VoiceSessionListener) {
        self.listener = listener
    }

    func stop() {
        stopCallCount += 1
        report(.ended)
    }

    /// Moves to `state` and reports it, unless the session already ended or failed.
    func report(_ newState: VoiceSessionState) {
        switch state {
        case .ended, .failed:
            return
        default:
            state = newState
            listener?.voiceSession(self, didChangeState: newState)
        }
    }

    /// Calls the listener with `state` regardless of the session's own state, to model a late or
    /// misbehaving callback that the host must drop on its own.
    func deliverUnchecked(_ state: VoiceSessionState) {
        listener?.voiceSession(self, didChangeState: state)
    }

    func transcript(_ text: String, role: VoiceTranscriptRole, isFinal: Bool = false) {
        listener?.voiceSession(self, didUpdateTranscript: text, role: role, isFinal: isFinal)
    }
}
