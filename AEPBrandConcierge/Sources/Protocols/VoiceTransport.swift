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

/// The real-time audio and data connection that a voice conversation runs over, provided by the app.
///
/// Brand Concierge runs the conversation itself: it fetches the connection credentials, asks for
/// microphone permission, reads the voice agent's messages and renders the transcript. The transport
/// only carries audio and data, so Brand Concierge does not depend on any real-time media SDK. The
/// sample app contains a complete LiveKit implementation to copy.
///
/// Pass a transport to `Concierge.show(...)` or `Concierge.present(...)`. Without one, the voice
/// button is hidden.
///
/// Implementations must follow these rules:
/// - Brand Concierge calls every method on the main thread. Each method returns immediately and
///   reports its outcome to `delegate`.
/// - One instance serves every conversation: `connect(url:token:)` can be called again after
///   `disconnect()`.
/// - Brand Concierge sets `delegate` before each `connect(url:token:)` and clears it before
///   `disconnect()`. Hold it weakly.
/// - After `disconnect()`, report nothing more about that connection, even if a new connection has
///   started since.
/// - Delegate methods can be called on any thread.
public protocol VoiceTransport: AnyObject {
    /// Receives the connection's state changes and data messages.
    var delegate: VoiceTransportDelegate? { get set }

    /// Joins the voice agent's room, publishes the microphone and plays the agent's audio.
    ///
    /// Report `.connected` once the microphone is live, or `.failed(_:)` if the connection cannot be made.
    ///
    /// - Parameters:
    ///   - url: the real-time media server URL from the Concierge service.
    ///   - token: the access token for the room, from the Concierge service.
    func connect(url: String, token: String)

    /// Mutes or unmutes the microphone without leaving the room. Brand Concierge mutes it while
    /// another app interrupts the audio session (for example, a phone call), and unmutes it afterwards.
    func setMicrophoneEnabled(_ enabled: Bool)

    /// Leaves the room and releases the microphone. Safe to call at any time, including while
    /// connecting or when not connected.
    func disconnect()
}

/// Receives updates from a `VoiceTransport`. Methods can be called on any thread.
public protocol VoiceTransportDelegate: AnyObject {
    /// Called when the connection's state changes.
    func voiceTransport(_ transport: VoiceTransport, didChange state: VoiceTransportState)

    /// Called for every data message the voice agent sends.
    ///
    /// - Parameters:
    ///   - data: the message payload, unchanged.
    ///   - topic: the message topic, or `nil` if the transport has none.
    func voiceTransport(_ transport: VoiceTransport, didReceive data: Data, topic: String?)
}

/// The state of a `VoiceTransport` connection.
public enum VoiceTransportState {
    /// Connected, with the microphone live.
    case connected
    /// The connection ended without an error, for example because the room closed.
    case disconnected
    /// The connection could not be made, or was lost because of `error`.
    case failed(Error)
}
