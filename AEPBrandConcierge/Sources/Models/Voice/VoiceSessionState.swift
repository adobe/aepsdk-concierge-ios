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

/// The lifecycle of a `VoiceSessionController`: `connecting`, then `listening`, then `ended` or
/// `failed`. `ended` and `failed` are terminal; a session never leaves them.
enum VoiceSessionState: Equatable {
    /// Waiting for microphone permission or for the transport to connect.
    case connecting
    /// Connected; the conversation is live.
    case listening
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
