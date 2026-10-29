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

import AEPBrandConcierge
import Foundation
import LiveKit
import os

/// Brand Concierge's `VoiceTransport` built on the LiveKit Swift SDK.
///
/// Copy this file into your app and add the LiveKit package
/// (`https://github.com/livekit/client-sdk-swift`) to your app target. Create one instance and pass
/// it to every `Concierge.show(...)` or `Concierge.present(...)` call.
///
/// Brand Concierge calls this class on the main thread, and the class keeps its own state on the
/// main thread too: LiveKit callbacks hop to main and are dropped unless they come from the current
/// room. That is how a connection reports nothing after `disconnect()`.
final class LiveKitTransport: NSObject, VoiceTransport, @unchecked Sendable {
    weak var delegate: VoiceTransportDelegate?

    private static let logger = Logger(subsystem: "com.adobe.aep.ConciergeDemoApp", category: "LiveKitTransport")

    /// Moves on with every `connect(url:token:)` and `disconnect()`, so a room created for an
    /// earlier connection can tell it has been superseded.
    private var connectionID = 0
    /// The current connection's room, set once it is created.
    private var room: Room?
    private var connectTask: Task<Void, Never>?
    /// Microphone changes run one after another, so a quick mute and unmute land in order.
    private var microphoneTask: Task<Void, Never>?
    /// Tears down the previous connection. A new connection waits for it, because the teardown stops
    /// the shared audio stack's microphone input, which would otherwise cut off the new connection's.
    private var teardownTask: Task<Void, Never>?

    func connect(url: String, token: String) {
        disconnect()
        let id = connectionID
        let teardown = teardownTask
        connectTask = Task.detached { [weak self] in
            await teardown?.value
            // Creating a room can initialize WebRTC's audio stack, so keep it off the main thread.
            let room = Room()
            guard await self?.adopt(room, connectionID: id) == true else { return }
            do {
                try await Self.join(room, url: url, token: token)
                await self?.connectFinished(room, error: nil)
            } catch {
                await self?.connectFinished(room, error: error)
            }
        }
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        guard let room else { return }
        let previous = microphoneTask
        microphoneTask = Task.detached {
            await previous?.value
            do {
                try await room.localParticipant.setMicrophone(enabled: enabled)
            } catch {
                Self.logger.warning("Could not set the microphone enabled=\(enabled): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func disconnect() {
        connectionID += 1
        microphoneTask = nil
        let task = connectTask
        let room = self.room
        connectTask = nil
        self.room = nil
        guard task != nil || room != nil else { return }
        // A join still in progress can outlast its cancellation; `connectFinished` cleans up after it.
        task?.cancel()
        tearDown {
            // LiveKit leaves the microphone input that preconnect capture opened running.
            await Self.stopMicrophoneInput()
            await room?.disconnect()
        }
    }

    /// Runs `teardown` after the previous teardown, and makes the next connection wait for it.
    private func tearDown(_ teardown: @escaping @Sendable () async -> Void) {
        let previous = teardownTask
        teardownTask = Task.detached {
            await previous?.value
            await teardown()
        }
    }

    /// Connects and publishes the microphone. Returns once the microphone is live. A failed join leaves
    /// releasing the microphone to `disconnect()`.
    private static func join(_ room: Room, url: String, token: String) async throws {
        try Task.checkCancellation()
        AudioManager.shared.isSpeakerOutputPreferred = true
        let preconnect = PreconnectCapture()
        do {
            // Records the microphone while the room connects and sends that audio to the agent once
            // it joins, so the user can start speaking right away. Publishes the microphone on success.
            try await room.withPreConnectAudio {
                preconnect.markStarted()
                // LiveKit can keep connecting long after cancellation, so give up here.
                try Task.checkCancellation()
                try await room.connect(url: url, token: token)
            } onError: { error in
                logger.warning("Preconnect audio could not be sent: \(error.localizedDescription, privacy: .public)")
            }
        } catch where !preconnect.hasStarted {
            // Only a capture that could not start falls back; a failed connection would just fail again.
            try Task.checkCancellation()
            logger.warning("Preconnect audio unavailable; connecting without it: \(error.localizedDescription, privacy: .public)")
            try await room.connect(url: url, token: token)
            try Task.checkCancellation()
            try await room.localParticipant.setMicrophone(enabled: true)
        }
    }

    /// Stops the audio stack's microphone input. The call blocks until WebRTC applies it, so it runs
    /// on a dispatch queue instead of holding a Swift Concurrency thread.
    private static func stopMicrophoneInput() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try AudioManager.shared.stopLocalRecording()
                } catch {
                    logger.warning("Could not stop the microphone input: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }
    }

    @MainActor
    private func adopt(_ room: Room, connectionID id: Int) -> Bool {
        guard id == connectionID else { return false }
        room.add(delegate: self)
        self.room = room
        return true
    }

    @MainActor
    private func connectFinished(_ room: Room, error: Error?) {
        guard room === self.room else {
            // Superseded while connecting. Make sure the room does not stay up, and release the
            // microphone this join may have opened after `disconnect()`, unless a newer connection uses it.
            tearDown { [weak self] in
                await room.disconnect()
                let idle = await self?.isIdle ?? true
                if idle { await Self.stopMicrophoneInput() }
            }
            return
        }
        if let error {
            disconnect()
            report(.failed(error))
        } else {
            report(.connected)
        }
    }

    @MainActor
    private var isIdle: Bool {
        connectTask == nil && room == nil
    }

    private func report(_ state: VoiceTransportState) {
        delegate?.voiceTransport(self, didChange: state)
    }

    /// Runs `action` on main if `room` is still the current connection's room.
    private func onMain(ifCurrent room: Room, _ action: @escaping (LiveKitTransport) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, room === self.room else { return }
            action(self)
        }
    }
}

// MARK: - RoomDelegate

extension LiveKitTransport: RoomDelegate {
    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        onMain(ifCurrent: room) { transport in
            transport.disconnect()
            // The room closing or removing the user ends the conversation normally.
            if let error, ![.cancelled, .roomDeleted, .participantRemoved].contains(error.type) {
                transport.report(.failed(error))
            } else {
                transport.report(.disconnected)
            }
        }
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard publication.kind == .audio else { return }
        Self.logger.info("Subscribed to remote audio track from \(participant.identity?.stringValue ?? "unknown", privacy: .public).")
    }

    func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        onMain(ifCurrent: room) { transport in
            transport.delegate?.voiceTransport(transport, didReceive: data, topic: topic.isEmpty ? nil : topic)
        }
    }
}

/// Records whether preconnect capture started. `withPreConnectAudio` runs its operation only once it has.
private final class PreconnectCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false

    var hasStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    func markStarted() {
        lock.lock()
        started = true
        lock.unlock()
    }
}
