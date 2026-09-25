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

public enum VoiceSessionState: Equatable {
    case idle
    case connecting
    case listening
    case failed(String)
}

public enum VoiceTranscriptRole: Equatable {
    case user
    case assistant
}

/// Dependency-free seam through which `ChatController` drives a voice session, kept free of
/// LiveKit/WebRTC so the core module never links them. A host app injects a concrete implementation
/// at `Concierge.show(...)`; with none injected, voice is off.
public protocol VoiceHandling: AnyObject {
    var state: VoiceSessionState { get }

    /// Invoked on the main thread whenever `state` changes.
    var onStateChange: ((VoiceSessionState) -> Void)? { get set }

    /// Invoked on the main thread with `(role, running text so far, isFinal)`: text is cumulative, and
    /// a turn is closed once `isFinal` is true, so the next update for that role starts a new turn.
    var onTranscriptUpdate: ((VoiceTranscriptRole, String, Bool) -> Void)? { get set }

    func start(url: String, token: String) async
    func stop() async
}
