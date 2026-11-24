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
import Combine
import Foundation

/// Receives updates for one `VoiceSessionController`. Every method is called on the main thread.
protocol VoiceSessionListener: AnyObject {
    /// Called whenever the session's state changes. `state` is also `session.state`.
    func voiceSession(_ session: VoiceSessionController, didChangeState state: VoiceSessionState)

    /// Called whenever a transcript turn is updated. `text` is the turn's full text so far, not a
    /// delta. `isFinal` closes the turn; the next update for the same role starts a new one.
    func voiceSession(_ session: VoiceSessionController, didUpdateTranscript text: String, role: VoiceTranscriptRole, isFinal: Bool)

    /// Called once when a turn ends, after its last transcript update. Replaces the open assistant
    /// reply with the result and renders the turn's UI payload.
    func voiceSession(_ session: VoiceSessionController, didFinishTurn result: VoiceTurnResult)

    /// Called when the current turn starts or stops waiting for its reply. It waits from the user's
    /// final transcript, spoken or sent as text, until the reply's first transcript update, the
    /// turn's end, a newer turn or the session's end. Turned off after that transcript update or
    /// turn end has been reported.
    func voiceSession(_ session: VoiceSessionController, didChangeAwaitingReply awaitingReply: Bool)
}

/// One voice conversation over the app's `VoiceTransport`: microphone permission, the connection
/// lifecycle, audio interruptions, and turning the voice agent's data messages into transcript updates.
///
/// The transport is shared by every conversation in the app. Only one conversation runs at a time
/// (see `VoiceSessionOwnership`), and a session claims the transport (becomes its delegate) only for
/// the time it is connected, and releases it before disconnecting. Mutable
/// lifecycle and transcript work runs on main; `state` is lock-protected, so any thread may read it
/// or call `stop()`.
final class VoiceSessionController: NSObject, @unchecked Sendable {
    /// How long the transport may take to report `.connected` after `connect` before the session fails.
    static let defaultConnectTimeout: TimeInterval = 20
    /// How long a lost connection may take to come back before the session fails.
    static let defaultReconnectTimeout: TimeInterval = 30
    /// How long a conversation may last from its first `.connected` before it ends normally, so a
    /// forgotten conversation, in the background for example, can't hold a room indefinitely.
    static let defaultMaxConversationLength: TimeInterval = 60 * 60

    private let LOG_TAG = "VoiceSessionController"
    private let transport: VoiceTransport
    private weak var listener: VoiceSessionListener?
    private let requestMicrophonePermission: () async -> Bool
    private let connectTimeout: TimeInterval
    private let reconnectTimeout: TimeInterval
    private let maxConversationLength: TimeInterval
    private var startTask: Task<Void, Never>?
    /// Runs while waiting for `.connected`, first after `connect` and again while reconnecting.
    private var connectionTimer: DispatchWorkItem?
    /// Runs from the first `.connected` until the session ends; reconnects don't restart it.
    private var conversationLengthTimer: DispatchWorkItem?
    private let stateLock = NSLock()
    private var currentState: VoiceSessionState = .connecting
    /// The turn in flight, from the user's first words (or the agent's, when it speaks first) until
    /// its `turn_completed` or the next user turn.
    private var turn: Turn?
    /// Turns that ended. Their late messages, such as the worker's second `turn_completed` after a
    /// playback error, are dropped.
    private var closedTurnIds: Set<String> = []
    /// The in-flight turn's assistant text so far.
    private var pendingAssistantText = ""
    /// The in-flight turn's latest UI payload. Each one is a snapshot of the whole turn.
    private var latestUiPayload: UiPayloadData?
    /// The last value reported through `didChangeAwaitingReply`.
    private var awaitingReply = false
    /// True from `connect` until this session disconnects the transport.
    private var holdsTransport = false
    /// The topic the voice agent reads text prompts from.
    static let textInputTopic = "bc-text-input"

    /// The transport's `continuesInBackground`, read once at `connect`.
    private var transportContinuesInBackground = false
    /// True from an audio interruption (a phone call, Siri) until it ends, in any active state.
    /// Tracked apart from the session state, so a `.connected` that arrives during the interruption
    /// doesn't leave the microphone live. The transport has no microphone getter: the microphone is
    /// live once `.connected`, and only interruptions change it after that.
    private var isAudioInterrupted = false

    var state: VoiceSessionState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentState
    }

    private var isActive: Bool {
        let currentState = state
        return currentState == .connecting || currentState == .listening || currentState == .reconnecting
    }

    /// Whether the conversation may keep running while the app is in the background: the transport
    /// opted in, and `connect` was called, which starts the microphone. False before `connect`
    /// (permission or credentials still pending) and once the session ended. Read on main.
    var continuesInBackground: Bool {
        holdsTransport && transportContinuesInBackground && isActive
    }

    init(transport: VoiceTransport,
         listener: VoiceSessionListener,
         requestMicrophonePermission: @escaping () async -> Bool = VoiceSessionController.requestMicrophonePermission,
         connectTimeout: TimeInterval = VoiceSessionController.defaultConnectTimeout,
         reconnectTimeout: TimeInterval = VoiceSessionController.defaultReconnectTimeout,
         maxConversationLength: TimeInterval = VoiceSessionController.defaultMaxConversationLength) {
        self.transport = transport
        self.listener = listener
        self.requestMicrophonePermission = requestMicrophonePermission
        self.connectTimeout = connectTimeout
        self.reconnectTimeout = reconnectTimeout
        self.maxConversationLength = maxConversationLength
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        startTask?.cancel()
        connectionTimer?.cancel()
        conversationLengthTimer?.cancel()
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
            fail(.invalidCredentials)
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
                    session.fail(.microphonePermissionDenied)
                    return
                }
                session.holdsTransport = true
                session.transportContinuesInBackground = session.transport.continuesInBackground
                session.transport.delegate = session
                // The transport is app code; don't wait forever for it to report back.
                let timeout = session.connectTimeout
                session.startConnectionTimer(timeout: timeout, while: .connecting,
                                             failure: .connectTimeout(seconds: Int(timeout)))
                session.transport.connect(connection)
            }
        }
    }

    /// Ends the session. Returns immediately; the end is reported to the listener as `.ended`.
    /// Calling it again, or after the session has already ended or failed, has no effect.
    func stop() {
        onMain { $0.finish(.ended) }
    }

    /// Whether `sendText(_:)` can start a turn now: the conversation is connected, and no user
    /// turn is waiting for the agent to start replying. Mirrors web, which holds text back from the
    /// start of the user's speech until the reply starts, and while reconnecting. Read on main.
    var canSendText: Bool {
        guard holdsTransport, state == .listening else { return false }
        guard let turn else { return true }
        return turn.replyStarted
    }

    /// Sends `text` to the voice agent as the user's next turn, as if they had said it, and reports
    /// it as the user's final transcript right away. Returns `false`, sending nothing, when
    /// `canSendText` is `false` or the text is blank. Call on main.
    @discardableResult
    func sendText(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSendText, !text.isEmpty else { return false }
        let turnId = "txt-" + UUID().uuidString.lowercased()
        let message: [String: Any] = ["type": "text_prompt", "turn_id": turnId, "text": text]
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return false }

        beginTurn(id: nil)
        turn?.textTurnId = turnId
        turn?.echoText = text
        turn?.userFinal = true
        emit(.user, text, isFinal: true)
        updateAwaitingReply()

        let transport = transport
        Task { @MainActor [weak self] in
            do {
                try await transport.send(data, topic: Self.textInputTopic)
            } catch {
                guard let self else { return }
                Log.warning(label: self.LOG_TAG, "Could not send a text prompt to the voice agent.")
                // The transport's error can carry the server URL or a server response.
                Log.debug(label: self.LOG_TAG, "Voice transport send error: \(error.localizedDescription)")
                guard self.isActive, self.turn?.textTurnId == turnId else { return }
                self.finishTurn(.failed(.messageSendFailed))
            }
        }
        return true
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
            guard session.isActive else { return }
            switch type {
            case .began:
                guard !session.isAudioInterrupted else { return }
                session.isAudioInterrupted = true
                session.setMicrophone(enabled: false)
            case .ended:
                guard session.isAudioInterrupted else { return }
                session.isAudioInterrupted = false
                guard options.contains(.shouldResume) else {
                    // iOS often omits it, and the chat has no unmute control, so a muted call would
                    // look live while the agent hears nothing. End it so the user knows.
                    session.fail(.audioNotResumable)
                    return
                }
                session.setMicrophone(enabled: true)
            @unknown default:
                break
            }
        }
    }

    /// Changes the microphone once connected. Before that it is left alone: the transport turns it
    /// on when it connects, and `.connected` applies any interruption.
    private func setMicrophone(enabled: Bool) {
        guard holdsTransport, state == .listening || state == .reconnecting else { return }
        transport.setMicrophoneEnabled(enabled)
    }

    private func fail(_ failure: VoiceSessionFailure) {
        guard isActive else { return }
        Log.warning(label: LOG_TAG, "Voice session failed: \(failure.message)")
        finish(.failed(failure))
    }

    /// Moves to a terminal state. The transport is released first, so it is free again by the
    /// time the listener hears about the end.
    private func finish(_ terminalState: VoiceSessionState) {
        guard isActive else { return }
        startTask?.cancel()
        cancelConnectionTimer()
        conversationLengthTimer?.cancel()
        conversationLengthTimer = nil
        if holdsTransport {
            holdsTransport = false
            if transport.delegate === self {
                transport.delegate = nil
            }
            transport.disconnect()
        }
        closeTurn()
        updateAwaitingReply()
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
                cancelConnectionTimer()
                startConversationLengthTimer()
                setState(.listening)
                if isAudioInterrupted {
                    setMicrophone(enabled: false)
                }
            case .reconnecting:
                // The transport keeps the microphone as it was; an interruption mute stays.
                cancelConnectionTimer()
                setState(.listening)
            default:
                break
            }
        case .reconnecting:
            guard state == .listening else { return }
            setState(.reconnecting)
            startConnectionTimer(timeout: reconnectTimeout, while: .reconnecting,
                                 failure: .reconnectTimeout(seconds: Int(reconnectTimeout)))
        case .disconnected:
            finish(.ended)
        case .failed(let error):
            // The error is app code's and can carry the server URL or a server response, so it is
            // logged at debug level only and never tracked.
            Log.debug(label: LOG_TAG, "Voice transport error: \(error.localizedDescription)")
            fail(.transportFailed)
        }
    }

    /// Fails the session with `failure`, which also disconnects the transport, if it is still in
    /// `waitingState` after `timeout`.
    private func startConnectionTimer(timeout: TimeInterval, while waitingState: VoiceSessionState, failure: VoiceSessionFailure) {
        cancelConnectionTimer()
        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.state == waitingState else { return }
            self.fail(failure)
        }
        connectionTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
    }

    private func cancelConnectionTimer() {
        connectionTimer?.cancel()
        connectionTimer = nil
    }

    /// Ends the session normally, which also disconnects the transport, once it has run for
    /// `maxConversationLength`, in the foreground or the background.
    private func startConversationLengthTimer() {
        conversationLengthTimer?.cancel()
        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else { return }
            Log.debug(label: self.LOG_TAG, "Ending the voice session: it reached the maximum length of \(Int(self.maxConversationLength)) seconds.")
            self.finish(.ended)
        }
        conversationLengthTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + maxConversationLength, execute: timer)
    }

    private func handle(_ message: DataChannelMessage) {
        switch message {
        case .transcriptDelta(let delta) where delta.role == .user:
            handleUserTranscript(delta)
        case .transcriptDelta(let delta):
            handleAssistantTranscript(delta)
        case .uiPayload(let payload):
            guard acceptsTurnMessage(turnId: payload.turnId, startsTurn: false) else { return }
            latestUiPayload = payload
        case .turnDone(let done):
            handleTurnDone(done)
        case .sessionNotice(.sessionEnded(let reason)):
            handleSessionEnded(reason)
        case .textInputError(let error):
            handleTextInputError(error)
        case .sessionNotice, .stateUpdate:
            break
        }
    }

    // MARK: - Turns

    /// Mirrors web's turn handling (`LiveKitVoiceManager`): the user's transcript decides the
    /// current turn, and messages for any other turn are dropped.
    private struct Turn {
        /// The worker's turn id, `nil` until a message for the turn carries one.
        var id: String?
        /// The `turn_id` sent with the text prompt that started the turn, if text started it.
        var textTurnId: String?
        /// The prompt's text, until the worker echoes it back as the user's transcript.
        var echoText: String?
        var userFinal = false
        var replyStarted = false
    }

    private func handleUserTranscript(_ delta: TranscriptDeltaData) {
        let text = delta.delta.trimmingCharacters(in: .whitespacesAndNewlines)
        if delta.final, let echo = turn?.echoText, text == echo {
            // The worker's echo of the text prompt carries the worker's id for the turn. The user's
            // bubble is already shown.
            turn?.echoText = nil
            if turn?.id == nil { turn?.id = delta.turnId }
            return
        }
        if !text.isEmpty {
            if let id = delta.turnId, closedTurnIds.contains(id) {
                Log.trace(label: LOG_TAG, "Dropped a user transcript for a turn that already ended.")
                return
            }
            if startsNewTurn(userTurnId: delta.turnId) {
                if let current = turn, current.textTurnId != nil, current.echoText != nil, !current.replyStarted {
                    // The user spoke before the worker took the text prompt. The worker rejects a prompt
                    // once the user is speaking, and its text_input_error would arrive after this turn
                    // was replaced, so fail the prompt now.
                    finishTurn(.failed(.turnFailed))
                }
                beginTurn(id: delta.turnId)
            } else if turn?.id == nil {
                turn?.id = delta.turnId
            }
            if delta.final { turn?.userFinal = true }
        }
        emit(.user, delta.delta, isFinal: delta.final)
        updateAwaitingReply()
    }

    private func startsNewTurn(userTurnId id: String?) -> Bool {
        guard let turn else { return true }
        if let id, let currentId = turn.id { return id != currentId }
        return turn.userFinal || turn.replyStarted
    }

    private func handleAssistantTranscript(_ delta: TranscriptDeltaData) {
        guard acceptsTurnMessage(turnId: delta.turnId, startsTurn: true) else { return }
        turn?.replyStarted = true
        pendingAssistantText += delta.delta
        let text = pendingAssistantText
        if delta.final { pendingAssistantText = "" }
        emit(.assistant, text, isFinal: delta.final)
        updateAwaitingReply()
    }

    /// The worker rejected a text prompt, for example because the user started speaking. Fails the
    /// prompt's turn unless the reply already started or a newer turn replaced it.
    private func handleTextInputError(_ error: TextInputErrorData) {
        guard let current = turn, let textTurnId = current.textTurnId, !current.replyStarted,
              error.turnId == nil || error.turnId == textTurnId else {
            Log.trace(label: LOG_TAG, "Dropped a text_input_error for a turn that is not in flight.")
            return
        }
        Log.debug(label: LOG_TAG, "The voice agent rejected a text prompt (\(error.reason)).")
        finishTurn(.failed(.turnFailed))
    }

    /// Mirrors web's `handleTurnDone`. An error or an empty reply fails the turn; `interrupted`
    /// counts as completed.
    private func handleTurnDone(_ done: TurnDoneData) {
        guard turn != nil, acceptsTurnMessage(turnId: done.turnId, startsTurn: false) else {
            Log.trace(label: LOG_TAG, "Dropped a turn_completed for a turn that is not in flight.")
            return
        }
        let fullText = done.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if done.state == .error || fullText.isEmpty {
            finishTurn(.failed(.turnFailed))
        } else {
            finishTurn(.completed(fullText))
        }
    }

    /// Whether an assistant message belongs to the turn in flight. A turn without an id adopts the
    /// message's id. With no turn in flight, only a message that `startsTurn` is kept, as the start
    /// of a turn the agent opens.
    private func acceptsTurnMessage(turnId id: String?, startsTurn: Bool) -> Bool {
        if let id, closedTurnIds.contains(id) { return false }
        guard let current = turn else {
            guard startsTurn else { return false }
            beginTurn(id: id)
            return true
        }
        guard let id else { return true }
        guard let currentId = current.id else {
            turn?.id = id
            return true
        }
        return id == currentId
    }

    /// Closes the turn in flight, if any, and opens a new one.
    private func beginTurn(id: String?) {
        if turn != nil {
            // The previous turn got no turn_completed, for example because the user interrupted it.
            // Close its reply bubble and drop its UI payload.
            let text = pendingAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { emit(.assistant, text, isFinal: true) }
            closeTurn()
            updateAwaitingReply()
        }
        turn = Turn(id: id)
    }

    private func finishTurn(_ outcome: VoiceTurnResult.Outcome) {
        let result = VoiceTurnResult(outcome: outcome, uiPayload: latestUiPayload)
        closeTurn()
        listener?.voiceSession(self, didFinishTurn: result)
        updateAwaitingReply()
    }

    private func closeTurn() {
        if let id = turn?.id { closedTurnIds.insert(id) }
        turn = nil
        pendingAssistantText = ""
        latestUiPayload = nil
    }

    /// Reports a change in whether the turn in flight waits for its reply: the user's final
    /// transcript was shown and the reply has not started.
    private func updateAwaitingReply() {
        let awaiting = isActive && turn.map { $0.userFinal && !$0.replyStarted } == true
        guard awaiting != awaitingReply else { return }
        awaitingReply = awaiting
        listener?.voiceSession(self, didChangeAwaitingReply: awaiting)
    }

    /// The voice agent ended the session. Only its timeouts are a normal end. An error, a shutdown or
    /// a reason this SDK doesn't know is a failure, so the user sees a message and it is tracked.
    private func handleSessionEnded(_ reason: EndReason?) {
        switch reason {
        case .roomEmptyTimeout, .userJoinTimeout, .userInactivityTimeout:
            finish(.ended)
        case .error, .workerShutdown, nil:
            fail(.agentEnded(reason))
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

// MARK: - VoiceSessionOwnership

/// Allows one voice conversation at a time across the app.
///
/// The overlay chat (`show`) and the UIKit chat (`present`) can be open together and usually get the
/// same transport. A second conversation on it would take the transport's delegate, so the first
/// conversation's transcript would appear in the second chat, and ending either one would hang up the
/// other's call. So a chat claims ownership at the voice tap, before its conversation touches the
/// transport, and keeps it until the conversation ends. Other chats can't start voice meanwhile.
final class VoiceSessionOwnership: @unchecked Sendable {
    static let shared = VoiceSessionOwnership()

    /// Held by the chat whose conversation owns voice. Releasing it, or deallocating it along with
    /// that chat, frees voice for the other chats.
    final class Claim {
        private let ownership: VoiceSessionOwnership

        fileprivate init(ownership: VoiceSessionOwnership) {
            self.ownership = ownership
        }

        deinit {
            ownership.release(ObjectIdentifier(self))
        }

        /// Frees voice for the other chats. Calling it again has no effect.
        func release() {
            ownership.release(ObjectIdentifier(self))
        }
    }

    private let lock = NSLock()
    private var ownerID: ObjectIdentifier?
    private let changeSubject = PassthroughSubject<Void, Never>()

    /// Whether a conversation owns voice right now.
    var isClaimed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ownerID != nil
    }

    /// Fires after every claim and release, on the thread that made it. Read `isClaimed` for the
    /// current value.
    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    /// Returns a claim, or `nil` when another conversation already owns voice.
    func claim() -> Claim? {
        let claim = Claim(ownership: self)
        lock.lock()
        let granted = ownerID == nil
        if granted {
            ownerID = ObjectIdentifier(claim)
        }
        lock.unlock()
        guard granted else { return nil }
        changeSubject.send()
        return claim
    }

    private func release(_ id: ObjectIdentifier) {
        lock.lock()
        let released = ownerID == id
        if released {
            ownerID = nil
        }
        lock.unlock()
        if released {
            changeSubject.send()
        }
    }
}

// MARK: - ConciergeVoiceTransportHolder

/// Holds the transport the app registered with `Concierge.setVoiceTransport(_:)`.
///
/// Every chat reads it, so a new value reaches the chats already open as well as later ones. A
/// running conversation keeps the transport it started with.
final class ConciergeVoiceTransportHolder: @unchecked Sendable {
    static let shared = ConciergeVoiceTransportHolder()

    private let LOG_TAG = "ConciergeVoiceTransportHolder"
    private let lock = NSLock()
    private var _transport: VoiceTransport?
    private let changeSubject = PassthroughSubject<Void, Never>()

    /// The registered transport, or `nil` when the app offers no voice.
    var transport: VoiceTransport? {
        lock.lock()
        defer { lock.unlock() }
        return _transport
    }

    /// Fires after every change, on the thread that made it. Read `transport` for the current value.
    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    /// Replaces the registered transport. Pass `nil` to clear it.
    func set(_ transport: VoiceTransport?) {
        lock.lock()
        _transport = transport
        lock.unlock()
        Log.debug(label: LOG_TAG, transport == nil ? "Voice transport cleared." : "Voice transport registered.")
        changeSubject.send()
    }
}
