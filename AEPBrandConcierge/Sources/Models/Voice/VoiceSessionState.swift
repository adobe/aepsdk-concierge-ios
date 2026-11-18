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

/// The lifecycle of a `VoiceSessionController`: `connecting`, then `listening` (moving to
/// `reconnecting` and back while the transport restores a lost connection), then `ended` or
/// `failed`. `ended` and `failed` are terminal; a session never leaves them.
enum VoiceSessionState: Equatable {
    /// Waiting for microphone permission or for the transport to connect.
    case connecting
    /// Connected; the conversation is live.
    case listening
    /// The transport lost the connection and is restoring it; the conversation stays open.
    case reconnecting
    /// Ended normally, for example after `VoiceSessionController.stop()`.
    case ended
    /// Could not start, or the connection was lost. The reason is for logging and tracking, not for display.
    case failed(VoiceSessionFailure)
}

/// Why a voice session failed. Each case has a fixed `message`, which is logged and sent to Edge
/// with `errorOccurred`. Error text from the transport or the network is never part of it: a
/// transport's error can carry the server URL or a server response.
enum VoiceSessionFailure: Equatable {
    /// The credentials had no `wss`/`https` server URL or no token.
    case invalidCredentials
    case microphonePermissionDenied
    /// The transport reported neither `.connected` nor `.failed` in time.
    case connectTimeout(seconds: Int)
    /// The transport did not restore a lost connection in time.
    case reconnectTimeout(seconds: Int)
    /// An audio interruption ended without iOS allowing the audio to resume.
    case audioNotResumable
    /// The voice agent ended the session with an error, a shutdown, or a reason this SDK doesn't know (`nil`).
    case agentEnded(EndReason?)
    /// The transport reported `.failed`.
    case transportFailed
    /// The Concierge service returned no voice credentials.
    case bootstrapFailed

    var message: String {
        switch self {
        case .invalidCredentials:
            return "Voice connection requires a valid server URL and a non-empty token."
        case .microphonePermissionDenied:
            return "Microphone permission was not granted."
        case .connectTimeout(let seconds):
            return "The voice connection was not established within \(seconds) seconds."
        case .reconnectTimeout(let seconds):
            return "The voice connection was not restored within \(seconds) seconds."
        case .audioNotResumable:
            return "The audio interruption ended without the system allowing the conversation to resume."
        case .agentEnded(let reason):
            return "The voice agent ended the session (\(reason?.rawValue ?? "unknown reason"))."
        case .transportFailed:
            return "The voice transport reported a failure."
        case .bootstrapFailed:
            return "The Concierge service did not return voice session credentials."
        }
    }
}

/// Who is speaking in a transcript update.
enum VoiceTranscriptRole: Equatable {
    /// The person using the app.
    case user
    /// The voice agent.
    case assistant
}

/// How a voice turn ended, delivered once per turn with the turn's latest UI payload.
struct VoiceTurnResult {
    enum Outcome: Equatable {
        /// The agent answered. The text is the authoritative full reply.
        case completed(String)
        /// The turn produced no usable reply. The session stays open.
        case failed(VoiceTurnFailure)
    }

    let outcome: Outcome
    /// Sources, suggestions and product cards for the turn, rendered even when the turn failed.
    let uiPayload: UiPayloadData?
}

/// Why a voice turn failed, which picks the copy shown in place of the reply.
enum VoiceTurnFailure: Equatable {
    /// The agent returned an error or an empty reply (`voice.turn.failed`).
    case turnFailed
    /// A message sent during the conversation could not be delivered (`voice.turn.messageSendFailed`).
    case messageSendFailed
}
