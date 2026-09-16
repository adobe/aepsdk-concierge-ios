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

/// The `response.voice` object carried on a `ConversationResponse` for a voice-bootstrap turn.
///
/// Mirrors web's `VoicePayload` (`AudioStreaming.ts`) — deliberately narrower than the full wire
/// shape, decoding only the fields the client actually consumes. Other `type` values (e.g. `"done"`)
/// decode without error and are simply ignored by callers that only act on `livekit_session`.
public struct VoicePayload: Codable {
    /// The kind of voice payload. `SessionType.livekitSession` is the only value the client acts on.
    public let type: String
    /// LiveKit server URL to connect the `Room` to; present on a `livekit_session` payload.
    public let livekitUrl: String?
    /// Access token for the LiveKit `Room`; present on a `livekit_session` payload.
    public let token: String?

    /// Known `type` discriminator values, kept in sync with web's contract.
    public enum SessionType {
        /// A resolved LiveKit session carrying `livekitUrl`/`token`.
        public static let livekitSession = "livekit_session"
    }
}

/// Connection credentials resolved from a successful voice bootstrap, ready to hand to the LiveKit
/// `Room`. Mirrors web's `LiveKitSessionBootstrap` — the non-optional, validated form of the pieces
/// carried loosely on `VoicePayload`.
public struct LiveKitSessionBootstrap: Equatable {
    public let livekitUrl: String
    public let token: String

    public init(livekitUrl: String, token: String) {
        self.livekitUrl = livekitUrl
        self.token = token
    }
}
