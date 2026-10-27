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

    func connect(url: String, token: String) {
        disconnect()
        let id = connectionID
        connectTask = Task.detached { [weak self] in
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
        connectTask?.cancel()
        connectTask = nil
        microphoneTask = nil
        guard let room else { return }
        self.room = nil
        Task.detached { await room.disconnect() }
    }

    /// Connects and publishes the microphone. Returns once the microphone is live.
    private static func join(_ room: Room, url: String, token: String) async throws {
        AudioManager.shared.isSpeakerOutputPreferred = true
        do {
            // Records the microphone while the room connects and sends that audio to the agent once
            // it joins, so the user can start speaking right away. Publishes the microphone on success.
            try await room.withPreConnectAudio {
                try await room.connect(url: url, token: token)
            } onError: { error in
                logger.warning("Preconnect audio could not be sent: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            try Task.checkCancellation()
            logger.warning("Preconnect path unavailable; falling back to plain connect: \(error.localizedDescription, privacy: .public)")
            try await room.connect(url: url, token: token)
            try await room.localParticipant.setMicrophone(enabled: true)
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
            // Superseded while connecting; make sure the room does not stay up.
            Task.detached { await room.disconnect() }
            return
        }
        if let error {
            disconnect()
            report(.failed(error))
        } else {
            report(.connected)
        }
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
