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
/// Decodes only the fields the client consumes. Other `type` values (e.g. `"done"`) decode without
/// error and are ignored by callers that only act on `livekit_session`.
public struct VoicePayload: Codable {
    /// The kind of voice payload. `SessionType.livekitSession` is the only value the client acts on.
    public let type: String
    /// Real-time media server URL; present on a `livekit_session` payload.
    public let livekitUrl: String?
    /// Access token for the real-time media session; present on a `livekit_session` payload.
    public let token: String?

    /// Known `type` discriminator values.
    public enum SessionType {
        /// A resolved session carrying `livekitUrl` and `token`.
        public static let livekitSession = "livekit_session"
    }
}

/// Connection credentials resolved from a successful voice bootstrap: the validated, non-optional
/// form of the fields carried on `VoicePayload`.
struct LiveKitSessionBootstrap: Equatable {
    let livekitUrl: String
    let token: String
}
