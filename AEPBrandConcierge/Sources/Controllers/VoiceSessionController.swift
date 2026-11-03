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

/// Receives updates for one `VoiceSessionController`. Every method is called on the main thread.
protocol VoiceSessionListener: AnyObject {
    /// Called whenever the session's state changes. `state` is also `session.state`.
    func voiceSession(_ session: VoiceSessionController, didChangeState state: VoiceSessionState)

    /// Called whenever a transcript turn is updated. `text` is the turn's full text so far, not a
    /// delta. `isFinal` closes the turn; the next update for the same role starts a new one.
    func voiceSession(_ session: VoiceSessionController, didUpdateTranscript text: String, role: VoiceTranscriptRole, isFinal: Bool)
}

/// One voice conversation over the app's `VoiceTransport`: microphone permission, the connection
/// lifecycle, audio interruptions, and turning the voice agent's data messages into transcript updates.
///
/// The transport is shared by every conversation in the app, so a session claims it (becomes its
/// delegate) only for the time it is connected, and releases it before disconnecting. Mutable
/// lifecycle and transcript work runs on main; `state` is lock-protected, so any thread may read it
/// or call `stop()`.
final class VoiceSessionController: NSObject, @unchecked Sendable {
    /// How long a lost connection may take to come back before the session fails.
    static let defaultReconnectTimeout: TimeInterval = 30

    private let LOG_TAG = "VoiceSessionController"
    private let transport: VoiceTransport
    private weak var listener: VoiceSessionListener?
    private let requestMicrophonePermission: () async -> Bool
    private let reconnectTimeout: TimeInterval
    private var startTask: Task<Void, Never>?
    private var reconnectTimer: DispatchWorkItem?
    private let stateLock = NSLock()
    private var currentState: VoiceSessionState = .connecting
    private var pendingAssistantText = ""
    /// True from `connect` until this session disconnects the transport.
    private var holdsTransport = false
    /// The transport has no microphone getter: the microphone is live once `.connected`, and only
    /// this session changes it after that.
    private var isMicrophoneEnabled = false
    private var micWasEnabledBeforeInterruption = false

    var state: VoiceSessionState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentState
    }

    private var isActive: Bool {
        let currentState = state
        return currentState == .connecting || currentState == .listening || currentState == .reconnecting
    }

    init(transport: VoiceTransport,
         listener: VoiceSessionListener,
         requestMicrophonePermission: @escaping () async -> Bool = VoiceSessionController.requestMicrophonePermission,
         reconnectTimeout: TimeInterval = VoiceSessionController.defaultReconnectTimeout) {
        self.transport = transport
        self.listener = listener
        self.requestMicrophonePermission = requestMicrophonePermission
        self.reconnectTimeout = reconnectTimeout
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        startTask?.cancel()
        reconnectTimer?.cancel()
        guard holdsTransport else { return }
        // The transport's delegate is weak and already nil here.
        let transport = transport
        if Thread.isMainThread {
            transport.disconnect()
        } else {
            DispatchQueue.main.async { transport.disconnect() }
        }
    }

    /// Starts the conversation and returns immediately. Invalid credentials, a denied microphone
    /// permission and connection failures are reported to the listener as `.failed`.
    func start(url: String, token: String) {
        // Always defer, including validation failures, so the caller can retain the connecting session.
        DispatchQueue.main.async { [weak self] in
            self?.begin(url: url, token: token)
        }
    }

    private func begin(url: String, token: String) {
        guard isActive else { return }
        listener?.voiceSession(self, didChangeState: .connecting)
        guard isActive else { return }
        // The token travels on this connection, so only encrypted schemes are accepted.
        guard let parsedURL = URLComponents(string: url),
              ["wss", "https"].contains(parsedURL.scheme?.lowercased() ?? ""),
              let host = parsedURL.host, !host.isEmpty,
              let serverURL = parsedURL.url,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fail("Voice connection requires a valid server URL and a non-empty token.")
            return
        }
        let connection = VoiceConnection(url: serverURL, token: token)

        // ChatController already asks for the permission before requesting the session. This second
        // check is a safety net for any caller that starts a session without going through
        // ChatController; when the permission is already granted it returns at once.
        let requestPermission = requestMicrophonePermission
        startTask = Task { [weak self] in
            let granted = await requestPermission()
            guard !Task.isCancelled else { return }
            self?.onMain { session in
                guard session.isActive else { return }
                guard granted else {
                    session.fail("Microphone permission was not granted.")
                    return
                }
                session.holdsTransport = true
                session.transport.delegate = session
                session.transport.connect(connection)
            }
        }
    }

    /// Ends the session. Returns immediately; the end is reported to the listener as `.ended`.
    /// Calling it again, or after the session has already ended or failed, has no effect.
    func stop() {
        onMain { $0.finish(.ended) }
    }

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
            .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
        onMain { session in
            guard session.state == .listening || session.state == .reconnecting else { return }
            switch type {
            case .began:
                session.micWasEnabledBeforeInterruption = session.isMicrophoneEnabled
                session.setMicrophone(enabled: false)
            case .ended:
                if options.contains(.shouldResume), session.micWasEnabledBeforeInterruption {
                    session.setMicrophone(enabled: true)
                }
                session.micWasEnabledBeforeInterruption = false
            @unknown default:
                break
            }
        }
    }

    private func setMicrophone(enabled: Bool) {
        guard holdsTransport, isActive else { return }
        isMicrophoneEnabled = enabled
        transport.setMicrophoneEnabled(enabled)
    }

    private func fail(_ reason: String) {
        guard isActive else { return }
        Log.warning(label: LOG_TAG, "Voice session failed: \(reason)")
        finish(.failed(reason))
    }

    /// Moves to a terminal state. The transport is released first, so it is free again by the
    /// time the listener hears about the end.
    private func finish(_ terminalState: VoiceSessionState) {
        guard isActive else { return }
        startTask?.cancel()
        cancelReconnectTimer()
        if holdsTransport {
            holdsTransport = false
            if transport.delegate === self {
                transport.delegate = nil
            }
            transport.disconnect()
        }
        setState(terminalState)
    }

    private func setState(_ newState: VoiceSessionState) {
        guard isActive, state != newState else { return }
        stateLock.lock()
        currentState = newState
        stateLock.unlock()
        listener?.voiceSession(self, didChangeState: newState)
    }

    private func onMain(_ action: @escaping (VoiceSessionController) -> Void) {
        if Thread.isMainThread {
            action(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                action(self)
            }
        }
    }

    /// True when a transport callback belongs to this session's live connection.
    private func ownsCallback(from sender: VoiceTransport) -> Bool {
        sender === transport && holdsTransport && isActive
    }

    private func handleTransportState(_ transportState: VoiceTransportState) {
        switch transportState {
        case .connected:
            switch state {
            case .connecting:
                isMicrophoneEnabled = true
                setState(.listening)
            case .reconnecting:
                // The transport keeps the microphone as it was; an interruption mute stays.
                cancelReconnectTimer()
                setState(.listening)
            default:
                break
            }
        case .reconnecting:
            guard state == .listening else { return }
            setState(.reconnecting)
            startReconnectTimer()
        case .disconnected:
            finish(.ended)
        case .failed(let error):
            fail(error.localizedDescription)
        }
    }

    private func startReconnectTimer() {
        cancelReconnectTimer()
        let timeout = reconnectTimeout
        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.state == .reconnecting else { return }
            self.fail("The voice connection was not restored within \(Int(timeout)) seconds.")
        }
        reconnectTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
    }

    private func cancelReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func handle(_ message: DataChannelMessage) {
        switch message {
        case .transcriptDelta(let delta) where delta.role == .user:
            emit(.user, delta.delta, isFinal: delta.final)
        case .transcriptDelta(let delta):
            pendingAssistantText += delta.delta
            let text = pendingAssistantText
            if delta.final { pendingAssistantText = "" }
            emit(.assistant, text, isFinal: delta.final)
        case .turnDone(let turn):
            let fullText = turn.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = fullText.isEmpty ? pendingAssistantText : fullText
            pendingAssistantText = ""
            emit(.assistant, text, isFinal: true)
        case .sessionNotice(.sessionEnded):
            stop()
        case .uiPayload, .sessionNotice, .stateUpdate:
            break
        }
    }

    private func emit(_ role: VoiceTranscriptRole, _ text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || isFinal else { return }
        listener?.voiceSession(self, didUpdateTranscript: trimmed, role: role, isFinal: isFinal)
    }
}

// MARK: - VoiceTransportDelegate

extension VoiceSessionController: VoiceTransportDelegate {
    func voiceTransport(_ transport: VoiceTransport, didChange state: VoiceTransportState) {
        onMain { session in
            guard session.ownsCallback(from: transport) else { return }
            session.handleTransportState(state)
        }
    }

    func voiceTransport(_ transport: VoiceTransport, didReceive data: Data, topic: String?) {
        onMain { session in
            guard session.ownsCallback(from: transport) else { return }
            guard let message = DataChannelMessageParser.parse(data) else {
                Log.trace(label: session.LOG_TAG, "Dropped an unrecognized data-channel message.")
                return
            }
            session.handle(message)
        }
    }
}
