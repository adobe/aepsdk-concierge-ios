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

import AEPServices
import AVFoundation
import Foundation
import LiveKit

/// Owns the LiveKit `Room` for a voice session: connect using bootstrapped credentials, publish the
/// local mic track, and let LiveKit auto-subscribe/render the worker's remote (TTS) audio track.
///
/// Sibling to `SpeechController` (not built on it) — the two voice paths are mutually exclusive and
/// share no code (see the LiveKit voice design docs). This PoC combines web's `VoiceTransport` and
/// `LiveKitVoiceManager` responsibilities into one controller; the data-channel turn state machine
/// and `ChatController` wiring are added in a later phase and are intentionally absent here.
///
/// Audio-session policy is handed to LiveKit's `AudioManager` rather than set directly — LiveKit
/// remains the sole caller of `AVAudioSession.setActive`/`setCategory` while a voice `Room` exists
/// (audio-session design NFR-01).
final class VoiceSessionController: NSObject {

    /// Lifecycle state of the voice session. Later phases extend this with the data-channel-driven
    /// turn states (`processing`/`responding`); this phase only covers connection + mic publish.
    enum State: Equatable {
        /// No session — nothing connected.
        case idle
        /// Bootstrapped; connecting the `Room` and publishing the mic.
        case connecting
        /// Connected with the mic live, awaiting/among turns.
        case listening
        /// The session failed to start or dropped; carries a human-readable reason.
        case failed(String)
    }

    /// One buffered line of the post-call transcript. Per FR-05 the PoC does not render turns live;
    /// entries accumulate here and `ChatController` appends them to the chat once the session ends.
    struct TranscriptEntry: Equatable {
        enum Role { case user, assistant }
        let role: Role
        let text: String
    }

    // MARK: - Public surface

    /// Current session state. Mutated only via `setState(_:)` (which lands on the main thread), so
    /// observers are always called on main.
    private(set) var state: State = .idle

    /// Invoked on the main thread whenever `state` changes.
    var onStateChange: ((State) -> Void)?

    /// Invoked on the main thread as transcript content arrives, so the chat can render it live:
    /// `(role, running text so far, isFinal)`. A `role` turn is "closed" once `isFinal` is true;
    /// the next update for that role begins a new turn/bubble.
    var onTranscriptUpdate: ((TranscriptEntry.Role, String, Bool) -> Void)?

    // MARK: - Private

    private let LOG_TAG = "VoiceSessionController"
    private let room: Room

    /// Whether the mic was enabled when an audio-session interruption began, so the correct state
    /// can be restored on `.ended` with `.shouldResume`.
    private var micWasEnabledBeforeInterruption = false

    /// Accumulated running text for the in-progress assistant turn (its deltas are incremental), so
    /// each live update carries the full text so far. Touched only on the main thread. (User STT
    /// arrives as full snapshots, so it needs no accumulator.)
    private var pendingAssistantText = ""

    /// Whether the mic is currently muted for the assistant's turn (so the device's TTS output isn't
    /// captured as input). Guards against redundant toggles. Touched only on the main thread.
    private var micMutedForAssistantTurn = false

    // MARK: - Init

    override init() {
        room = Room()
        super.init()
        room.add(delegate: self)
        Self.configureAudioSessionPolicy()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    /// Connects the `Room` with the bootstrapped credentials and publishes the mic. Drives `state`
    /// through `connecting` → `listening`, or `failed` on any error. Call from the main thread.
    /// - Parameters:
    ///   - url: LiveKit server URL from the bootstrap response.
    ///   - token: LiveKit access token from the bootstrap response.
    func start(url: String, token: String) async {
        guard state == .idle || isFailed else {
            Log.debug(label: LOG_TAG, "start() ignored — a voice session is already active (state=\(state)).")
            return
        }
        pendingAssistantText = ""
        micMutedForAssistantTurn = false
        setState(.connecting)

        guard await Self.requestMicrophonePermission() else {
            setState(.failed("Microphone permission was not granted."))
            return
        }

        do {
            try await room.connect(url: url, token: token)
            try await room.localParticipant.setMicrophone(enabled: true)
            setState(.listening)
        } catch {
            Log.warning(label: LOG_TAG, "Failed to start voice session: \(error.localizedDescription)")
            setState(.failed(error.localizedDescription))
            // Best-effort teardown so a failed start leaves no half-open Room / active audio session.
            await room.disconnect()
        }
    }

    /// Ends the session: disconnects the `Room` (which lets LiveKit's `AudioManager` deactivate the
    /// shared audio session per FR-07) and returns to `idle`.
    func stop() async {
        await room.disconnect()
        setState(.idle)
    }

    // MARK: - Audio session policy

    /// The audio-session policy handed to LiveKit (audio-session design §6.1) — LiveKit's own
    /// `.playAndRecordSpeaker` preset values, kept here as plain AVFoundation types because that
    /// preset is `internal` to LiveKit. `.playAndRecord` / `.videoChat` (not `.voiceChat`) with the
    /// speaker-routed Bluetooth/AirPlay option set; `.mixWithOthers` is deliberately omitted (it
    /// triggers a WebRTC engine-init race on the record path). Exposed for testing.
    static let audioSessionCategory: AVAudioSession.Category = .playAndRecord
    static let audioSessionMode: AVAudioSession.Mode = .videoChat
    static let audioSessionCategoryOptions: AVAudioSession.CategoryOptions =
        [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]

    /// Hands the policy above to LiveKit's `AudioManager`, which becomes the sole owner of
    /// `AVAudioSession.setActive`/`setCategory` while a voice `Room` exists (NFR-01).
    private static func configureAudioSessionPolicy() {
        AudioManager.shared.sessionConfiguration = AudioSessionConfiguration(
            category: audioSessionCategory,
            categoryOptions: audioSessionCategoryOptions,
            mode: audioSessionMode
        )
    }

    /// Requests record permission, using the non-deprecated `AVAudioApplication` API on iOS 17+.
    private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Interruptions (audio-session design §6.3)

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            // Mute the local mic; the OS suspends the audio session, so remote (TTS) playback pauses
            // with it. The Room connection is left intact (FR-04).
            micWasEnabledBeforeInterruption = room.localParticipant.isMicrophoneEnabled()
            setMicrophone(enabled: false)
        case .ended:
            // Resume only when the system says we should, and only if the mic had been live (FR-05).
            let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            if options.contains(.shouldResume), micWasEnabledBeforeInterruption {
                setMicrophone(enabled: true)
            }
        @unknown default:
            break
        }
    }

    // MARK: - Helpers

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    /// Enables/disables the local mic track without blocking the caller; errors are logged, not
    /// surfaced (a mute/unmute failure should not tear down the session).
    private func setMicrophone(enabled: Bool) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.room.localParticipant.setMicrophone(enabled: enabled)
            } catch {
                Log.warning(label: self.LOG_TAG, "Failed to set microphone enabled=\(enabled): \(error.localizedDescription)")
            }
        }
    }

    private func setState(_ newState: State) {
        let apply = { [weak self] in
            guard let self, self.state != newState else { return }
            self.state = newState
            self.onStateChange?(newState)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}

// MARK: - RoomDelegate

extension VoiceSessionController: RoomDelegate {

    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        if let error {
            Log.warning(label: LOG_TAG, "Voice Room disconnected with error: \(error.localizedDescription)")
            setState(.failed(error.localizedDescription))
        } else {
            Log.trace(label: LOG_TAG, "Voice Room disconnected.")
            setState(.idle)
        }
    }

    func room(_ room: Room, didFailToConnectWithError error: LiveKitError?) {
        Log.warning(label: LOG_TAG, "Voice Room failed to connect: \(error?.localizedDescription ?? "unknown error")")
        setState(.failed(error?.localizedDescription ?? "Failed to connect to the voice session."))
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        // LiveKit auto-subscribes and its AudioManager renders the remote audio track; this is just
        // observability for the remote (TTS) track arriving.
        if publication.kind == .audio {
            Log.trace(label: LOG_TAG, "Subscribed to remote audio track from \(participant.identity?.stringValue ?? "unknown").")
        }
    }

    func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        guard let message = DataChannelMessageParser.parse(data) else {
            Log.trace(label: LOG_TAG, "Dropped an unrecognized data-channel message on topic '\(topic)'.")
            return
        }
        // Buffer on the main thread so `bufferedTranscript` has a single-threaded owner shared with
        // the reader in `ChatController`.
        DispatchQueue.main.async { [weak self] in
            self?.handle(message)
        }
    }
}

// MARK: - Data-channel handling (live transcript)

private extension VoiceSessionController {

    /// Turns each parsed data-channel message into a live `onTranscriptUpdate` emission carrying the
    /// running text so far. Must run on the main thread.
    func handle(_ message: DataChannelMessage) {
        switch message {
        case .transcriptDelta(let delta) where delta.role == .user:
            // User STT sends a cumulative snapshot (the full running transcript) on each delta, not
            // an incremental piece — use it directly rather than appending (which would concatenate
            // every snapshot). Mirrors web's `onTranscriptUpdate(data.delta)`.
            emit(.user, delta.delta, isFinal: delta.final)
            // The user's turn ends → the worker responds. Mute the mic for the assistant's turn so
            // the device's own TTS output isn't captured and transcribed back as input (half-duplex;
            // mirrors web's mute-on-enter-processing). Barge-in remains deferred.
            if delta.final { muteForAssistantTurn() }

        case .transcriptDelta(let delta): // assistant streaming chunks
            pendingAssistantText += delta.delta
            emit(.assistant, pendingAssistantText, isFinal: false)
            // Also mute here in case the assistant speaks without a preceding user-final (e.g. an
            // opening greeting) — the guard makes this a no-op once already muted.
            muteForAssistantTurn()

        case .turnDone(let turn):
            // `fullText` is the authoritative assistant reply; fall back to what streamed if absent.
            let full = turn.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = full.isEmpty ? pendingAssistantText : full
            pendingAssistantText = ""
            emit(.assistant, text, isFinal: true)
            // Assistant turn finished — reopen the mic for the next user turn. (A brief TTS tail may
            // still be draining; the built-in echo cancellation covers that short window.)
            unmuteForNextUserTurn()

        case .sessionNotice(.sessionEnded):
            // The worker ended the session; tear down so the state transitions to idle.
            Task { [weak self] in await self?.stop() }

        case .uiPayload, .sessionNotice, .stateUpdate:
            // Rich UI payloads (deferred, FR-05), silence warnings, and coarse state updates are not
            // rendered in this minimal live transcript.
            break
        }
    }

    /// Emits a trimmed running-text update, suppressing empty non-final noise.
    func emit(_ role: TranscriptEntry.Role, _ text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || isFinal else { return }
        onTranscriptUpdate?(role, trimmed, isFinal)
    }

    func muteForAssistantTurn() {
        guard !micMutedForAssistantTurn else { return }
        micMutedForAssistantTurn = true
        setMicrophone(enabled: false)
    }

    func unmuteForNextUserTurn() {
        guard micMutedForAssistantTurn else { return }
        micMutedForAssistantTurn = false
        setMicrophone(enabled: true)
    }
}
