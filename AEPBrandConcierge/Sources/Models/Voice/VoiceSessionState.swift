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
    /// Could not start, or the connection was lost. The reason is for logging, not for display.
    case failed(String)
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
