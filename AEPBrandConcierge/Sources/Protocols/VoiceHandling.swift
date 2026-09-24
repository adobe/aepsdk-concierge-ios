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

/// Lifecycle state of a voice session, surfaced to `ChatController` without exposing the concrete
/// (LiveKit-backed) implementation. Mirrors the state machine the implementation drives internally.
public enum VoiceSessionState: Equatable {
    /// No session — nothing connected.
    case idle
    /// Bootstrapped; connecting the transport and publishing the mic.
    case connecting
    /// Connected with the mic live, awaiting/among turns.
    case listening
    /// The session failed to start or dropped; carries a human-readable reason.
    case failed(String)
}

/// Which side of the conversation a live transcript update belongs to.
public enum VoiceTranscriptRole: Equatable {
    case user
    case assistant
}

/// The seam through which `ChatController` drives a real-time voice session without depending on the
/// concrete implementation or its third-party stack (LiveKit/WebRTC). A host app that wants voice
/// links the separate `AEPVoice` library and injects its concrete `VoiceHandling` at
/// `Concierge.show(...)` — the same opt-in shape as the un-defaulted `TextSpeaking` injection. Unlike
/// `SpeechCapturing`, there is no dependency-free default implementation, so this is never defaulted:
/// with no handler injected, voice is simply off.
public protocol VoiceHandling: AnyObject {
    /// Current session state. Implementations must mutate this on the main thread so that observers,
    /// which are invoked on the main thread, always read a consistent value.
    var state: VoiceSessionState { get }

    /// Invoked on the main thread whenever `state` changes.
    var onStateChange: ((VoiceSessionState) -> Void)? { get set }

    /// Invoked on the main thread as transcript content arrives, so the chat can render it live:
    /// `(role, running text so far, isFinal)`. A `role` turn is "closed" once `isFinal` is true; the
    /// next update for that role begins a new turn/bubble.
    var onTranscriptUpdate: ((VoiceTranscriptRole, String, Bool) -> Void)? { get set }

    /// Connects the session with the bootstrapped credentials and publishes the mic, driving `state`
    /// through `connecting` → `listening`, or `failed` on any error. Call from the main thread.
    /// - Parameters:
    ///   - url: Transport server URL from the bootstrap response.
    ///   - token: Access token from the bootstrap response.
    func start(url: String, token: String) async

    /// Ends the session and returns to `idle`.
    func stop() async
}
