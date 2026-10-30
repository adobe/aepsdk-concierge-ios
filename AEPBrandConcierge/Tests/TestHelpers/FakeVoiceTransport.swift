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

/// In-memory `VoiceTransport` for tests: records what Brand Concierge asks for and lets a test
/// report connection states and data messages, without a media SDK or audio.
///
/// By default `connect` reports `.connected` on the next main-queue turn, like a real transport
/// that connects asynchronously. Set `autoConnect` to `false` to report states manually.
final class FakeVoiceTransport: VoiceTransport, @unchecked Sendable {
    private let lock = NSLock()
    private weak var storedDelegate: VoiceTransportDelegate?
    private var recordedConnections: [(url: String, token: String)] = []
    private var recordedDisconnectCount = 0
    private var recordedMicrophoneChanges: [Bool] = []
    private var connectHandler: (() -> Void)?
    private var disconnectHandler: (() -> Void)?
    private var microphoneHandler: ((Bool) -> Void)?

    var autoConnect = true

    var delegate: VoiceTransportDelegate? {
        get { locked { storedDelegate } }
        set { locked { storedDelegate = newValue } }
    }

    var connections: [(url: String, token: String)] { locked { recordedConnections } }
    var disconnectCount: Int { locked { recordedDisconnectCount } }
    var microphoneChanges: [Bool] { locked { recordedMicrophoneChanges } }

    /// Runs inside `connect`, after it is recorded.
    var onConnect: (() -> Void)? {
        get { locked { connectHandler } }
        set { locked { connectHandler = newValue } }
    }

    /// Runs inside `disconnect`, after it is recorded.
    var onDisconnect: (() -> Void)? {
        get { locked { disconnectHandler } }
        set { locked { disconnectHandler = newValue } }
    }

    /// Runs inside `setMicrophoneEnabled`, after it is recorded.
    var onMicrophoneChange: ((Bool) -> Void)? {
        get { locked { microphoneHandler } }
        set { locked { microphoneHandler = newValue } }
    }

    func connect(url: String, token: String) {
        locked { recordedConnections.append((url, token)) }
        onConnect?()
        guard autoConnect else { return }
        DispatchQueue.main.async { [weak self] in
            self?.report(.connected)
        }
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        locked { recordedMicrophoneChanges.append(enabled) }
        onMicrophoneChange?(enabled)
    }

    func disconnect() {
        locked { recordedDisconnectCount += 1 }
        onDisconnect?()
    }

    /// Reports `state` to the current delegate, as the transport would from any thread.
    func report(_ state: VoiceTransportState) {
        delegate?.voiceTransport(self, didChange: state)
    }

    /// Delivers raw bytes to the current delegate.
    func receive(_ data: Data, topic: String? = nil) {
        delegate?.voiceTransport(self, didReceive: data, topic: topic)
    }

    /// Delivers a JSON object to the current delegate.
    func receive(json: [String: Any], topic: String? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            preconditionFailure("Invalid test JSON: \(json)")
        }
        receive(data, topic: topic)
    }

    private func locked<T>(_ action: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }
}
