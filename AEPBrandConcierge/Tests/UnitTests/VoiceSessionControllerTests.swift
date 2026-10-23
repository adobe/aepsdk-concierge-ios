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

import AVFoundation
import UIKit
import XCTest
@testable import AEPBrandConcierge

@MainActor
final class VoiceSessionControllerTests: XCTestCase {
    private let url = "wss://voice.example.com"
    private let token = "test-token"

    func test_initialState_isConnecting() {
        let listener = RecordingVoiceListener()
        let session = start(FakeVoiceTransport(), listener: listener)
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(listener.states.isEmpty, "start must return before callbacks")
        session.stop()
    }

    func test_state_failedEquality_comparesReason() {
        XCTAssertEqual(VoiceSessionState.failed("x"), .failed("x"))
        XCTAssertNotEqual(VoiceSessionState.failed("x"), .failed("y"))
        XCTAssertNotEqual(VoiceSessionState.connecting, .listening)
    }

    func test_connect_claimsTransport_passesCredentials_andReportsListening() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        XCTAssertEqual(transport.connections.count, 1)
        XCTAssertEqual(transport.connections.first?.url, url)
        XCTAssertEqual(transport.connections.first?.token, token)
        XCTAssertTrue(transport.delegate === session)
        XCTAssertEqual(listener.states, [.connecting, .listening])
        XCTAssertEqual(session.state, .listening)
        session.stop()
    }

    func test_invalidCredentials_reportFailureWithoutPermissionOrConnect() async {
        for (invalidURL, invalidToken) in [
            ("", token),
            ("not-a-url", token),
            ("file:///tmp/voice", token),
            ("wss:///room", token),
            (url, ""),
            (url, "  \n")
        ] {
            let transport = FakeVoiceTransport()
            let listener = RecordingVoiceListener()
            let failure = expectation(description: "invalid credentials")
            listener.onState = { if case .failed = $0 { failure.fulfill() } }
            let session = VoiceSessionController(transport: transport, listener: listener, requestMicrophonePermission: {
                XCTFail("invalid credentials must not request microphone permission")
                return true
            })
            session.start(url: invalidURL, token: invalidToken)
            XCTAssertEqual(session.state, .connecting)
            await fulfillment(of: [failure], timeout: 2)
            XCTAssertTrue(transport.connections.isEmpty)
            XCTAssertEqual(transport.disconnectCount, 0, "a transport that was never connected is left alone")
            session.stop()
            XCTAssertEqual(listener.states.count, 2, "stop after failure is a no-op")
        }
    }

    func test_permissionDenied_isTerminal_andNeverClaimsTransport() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let failure = expectation(description: "permission denied")
        listener.onState = { if case .failed = $0 { failure.fulfill() } }
        let session = start(transport, listener: listener, permission: false)
        await fulfillment(of: [failure], timeout: 2)
        XCTAssertEqual(session.state, .failed("Microphone permission was not granted."))
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertNil(transport.delegate)
        session.stop()
        XCTAssertEqual(listener.states.count, 2)
    }

    func test_connectFailure_isTerminal_releasesAndDisconnects() async {
        let transport = FakeVoiceTransport()
        transport.autoConnect = false
        transport.onConnect = { DispatchQueue.main.async { transport.report(.failed(TestVoiceError())) } }
        let listener = RecordingVoiceListener()
        let failure = expectation(description: "connection failure")
        listener.onState = { if case .failed = $0 { failure.fulfill() } }
        let session = start(transport, listener: listener)
        await fulfillment(of: [failure], timeout: 2)
        XCTAssertEqual(session.state, .failed("Test connection error"))
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertNil(transport.delegate)
        session.stop()
        XCTAssertEqual(listener.states, [.connecting, .failed("Test connection error")])
    }

    func test_stop_releasesTransportBeforeReporting_isIdempotent_andIgnoresLateEvents() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        listener.onState = { _ in
            XCTAssertNil(transport.delegate, "the transport is free by the time the listener hears the end")
            XCTAssertEqual(transport.disconnectCount, 1)
        }
        session.stop()
        listener.onState = nil
        XCTAssertEqual(session.state, .ended)
        session.stop()
        session.voiceTransport(transport, didChange: .failed(TestVoiceError()))
        session.voiceTransport(transport, didReceive: json(["event": "text_delta", "delta": "late"]), topic: nil)
        XCTAssertEqual(listener.states, [.connecting, .listening, .ended])
        XCTAssertTrue(listener.transcripts.isEmpty)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_stopBeforeStart_doesNotConnect() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        session.stop()
        await drainMainQueue()
        XCTAssertEqual(listener.states, [.ended])
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertEqual(transport.disconnectCount, 0)
    }

    func test_stopDuringPermission_doesNotConnectAfterPermissionArrives() async {
        let gate = AsyncGate<Bool>()
        let requested = expectation(description: "permission requested")
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = VoiceSessionController(transport: transport, listener: listener, requestMicrophonePermission: {
            requested.fulfill()
            return await gate.wait()
        })
        session.start(url: url, token: token)
        await fulfillment(of: [requested], timeout: 2)
        session.stop()
        gate.resume(true)
        await drainMainQueue()
        await drainMainQueue()
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertNil(transport.delegate)
        XCTAssertEqual(session.state, .ended)
        XCTAssertEqual(listener.states, [.connecting, .ended])
    }

    func test_stopWhileConnecting_disconnects_andDropsTheLateConnected() async {
        let transport = FakeVoiceTransport()
        transport.autoConnect = false
        let connecting = expectation(description: "connecting")
        transport.onConnect = { connecting.fulfill() }
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await fulfillment(of: [connecting], timeout: 2)
        session.stop()
        transport.report(.connected)
        session.voiceTransport(transport, didChange: .connected)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertEqual(listener.states, [.connecting, .ended])
        XCTAssertEqual(session.state, .ended)
    }

    func test_releaseWhileConnected_disconnectsAndDoesNotRetainSession() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        var session: VoiceSessionController? = start(transport, listener: listener)
        weak let weakSession = session
        await listening(listener)
        session = nil
        XCTAssertNil(weakSession)
        XCTAssertNil(transport.delegate)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertEqual(listener.states, [.connecting, .listening])
    }

    func test_listenerIsWeak() async {
        var listener: RecordingVoiceListener? = RecordingVoiceListener()
        weak let weakListener = listener
        let session = start(FakeVoiceTransport(), listener: listener!)
        listener = nil
        XCTAssertNil(weakListener)
        await drainMainQueue()
        session.stop()
    }

    func test_transportDisconnectOrFailure_reportsTerminalStatesOnMain() async {
        for failed in [false, true] {
            let transport = FakeVoiceTransport()
            let listener = RecordingVoiceListener()
            let session = start(transport, listener: listener)
            await listening(listener)
            let terminal = expectation(description: "terminal callback on main")
            listener.onState = { state in
                if state == .ended || state == .failed("Test connection error") { terminal.fulfill() }
            }
            DispatchQueue.global().async {
                transport.report(failed ? .failed(TestVoiceError()) : .disconnected)
            }
            await fulfillment(of: [terminal], timeout: 2)
            XCTAssertEqual(session.state, failed ? .failed("Test connection error") : .ended)
            XCTAssertEqual(transport.disconnectCount, 1)
            XCTAssertNil(transport.delegate)
            session.voiceTransport(transport, didChange: .failed(TestVoiceError()))
            XCTAssertEqual(listener.states.count, 3)
        }
    }

    func test_repeatedConnected_whileListening_isIgnored() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.report(.connected)
        XCTAssertEqual(listener.states, [.connecting, .listening])
        session.stop()
    }

    func test_backgroundStop_reportsEndedOnMain() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        let ended = expectation(description: "ended on main")
        listener.onState = { if $0 == .ended { ended.fulfill() } }
        DispatchQueue.global().async { session.stop() }
        await fulfillment(of: [ended], timeout: 2)
        XCTAssertEqual(session.state, .ended)
    }

    func test_userTranscript_usesCumulativeSnapshots() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": " hello ", "final": false]])
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": " hello world ", "final": true]])
        XCTAssertEqual(listener.transcripts, [
            .init(text: "hello", role: .user, isFinal: false),
            .init(text: "hello world", role: .user, isFinal: true)
        ])
        session.stop()
    }

    func test_assistantTranscript_accumulatesAndUsesAuthoritativeFinalText() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.receive(json: ["event": "text_delta", "delta": " Hello"])
        transport.receive(json: ["event": "text_delta", "delta": " world "])
        transport.receive(json: ["event": "turn_completed", "fullText": " Corrected reply "])
        transport.receive(json: ["event": "text_delta", "delta": " Next turn"])
        transport.receive(json: ["event": "turn_completed"])
        XCTAssertEqual(listener.transcripts, [
            .init(text: "Hello", role: .assistant, isFinal: false),
            .init(text: "Hello world", role: .assistant, isFinal: false),
            .init(text: "Corrected reply", role: .assistant, isFinal: true),
            .init(text: "Next turn", role: .assistant, isFinal: false),
            .init(text: "Next turn", role: .assistant, isFinal: true)
        ])
        session.stop()
    }

    func test_assistantTypeBasedFinal_closesTurn() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.receive(json: ["type": "transcript_delta", "data": ["role": "assistant", "delta": "first", "final": true]])
        transport.receive(json: ["event": "text_delta", "delta": "second"])
        XCTAssertEqual(listener.transcripts, [
            .init(text: "first", role: .assistant, isFinal: true),
            .init(text: "second", role: .assistant, isFinal: false)
        ])
        session.stop()
    }

    func test_emptyInterim_isSuppressedButEmptyFinalClosesTurn() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "  "]])
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "  ", "final": true]])
        XCTAssertEqual(listener.transcripts, [.init(text: "", role: .user, isFinal: true)])
        session.stop()
    }

    func test_dataFromBackground_isDeliveredOnMain() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        let transcript = expectation(description: "transcript on main")
        listener.onTranscript = { transcript.fulfill() }
        DispatchQueue.global().async {
            transport.receive(Data(#"{"event":"text_delta","delta":"hello"}"#.utf8), topic: "lk.chat")
        }
        await fulfillment(of: [transcript], timeout: 2)
        XCTAssertEqual(listener.transcripts.first?.text, "hello")
        session.stop()
    }

    func test_dataBeforeConnected_isDelivered() async {
        let transport = FakeVoiceTransport()
        transport.autoConnect = false
        let connecting = expectation(description: "connecting")
        transport.onConnect = { connecting.fulfill() }
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await fulfillment(of: [connecting], timeout: 2)
        transport.receive(json: ["event": "text_delta", "delta": "early"])
        XCTAssertEqual(listener.transcripts.map(\.text), ["early"])
        session.stop()
    }

    func test_sessionEndedNotice_stopsSession() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        transport.receive(json: ["type": "session_notice", "data": ["kind": "session_ended", "reason": "user_inactivity_timeout"]])
        XCTAssertEqual(session.state, .ended)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_ignoredMessages_doNotEmitTranscriptOrChangeState() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        for raw: [String: Any] in [
            ["event": "ui_payload", "promptSuggestions": ["one"]],
            ["event": "turn_started"],
            ["type": "session_notice", "data": ["kind": "user_silence_warning"]],
            ["event": "unknown"]
        ] {
            transport.receive(json: raw)
        }
        transport.receive(Data([0, 1, 2]))
        XCTAssertTrue(listener.transcripts.isEmpty)
        XCTAssertEqual(session.state, .listening)
        session.stop()
    }

    func test_appBackground_endsSession() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(session.state, .ended)
    }

    func test_interruption_mutesAndResumesTheMicrophone() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        interruption(.began)
        interruption(.ended, options: .shouldResume)
        XCTAssertEqual(transport.microphoneChanges, [false, true])
        XCTAssertEqual(session.state, .listening)
        session.stop()
    }

    func test_interruption_doesNotResumeWithoutSystemPermission() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        interruption(.began)
        interruption(.ended)
        XCTAssertEqual(transport.microphoneChanges, [false])
        session.stop()
    }

    func test_interruption_doesNotResumeAMicrophoneThatWasAlreadyMuted() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        interruption(.began)
        interruption(.began)
        interruption(.ended, options: .shouldResume)
        XCTAssertEqual(transport.microphoneChanges, [false, false])
        session.stop()
    }

    func test_interruption_isIgnoredBeforeConnected() async {
        let transport = FakeVoiceTransport()
        transport.autoConnect = false
        let connecting = expectation(description: "connecting")
        transport.onConnect = { connecting.fulfill() }
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await fulfillment(of: [connecting], timeout: 2)
        interruption(.began)
        interruption(.ended, options: .shouldResume)
        XCTAssertTrue(transport.microphoneChanges.isEmpty)
        session.stop()
    }

    func test_sharedTransport_servesOneSessionAfterAnother() async {
        let transport = FakeVoiceTransport()
        let firstListener = RecordingVoiceListener()
        let first = start(transport, listener: firstListener)
        await listening(firstListener)
        transport.receive(json: ["event": "text_delta", "delta": "first"])
        first.stop()

        let secondListener = RecordingVoiceListener()
        let second = start(transport, listener: secondListener)
        await listening(secondListener)
        XCTAssertTrue(transport.delegate === second)
        transport.receive(json: ["event": "text_delta", "delta": "second"])
        // A misbehaving transport that still reaches the first session's delegate methods.
        first.voiceTransport(transport, didChange: .disconnected)
        first.voiceTransport(transport, didReceive: json(["event": "text_delta", "delta": "stale"]), topic: nil)

        XCTAssertEqual(transport.connections.count, 2)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertEqual(firstListener.transcripts.map(\.text), ["first"])
        XCTAssertEqual(secondListener.transcripts.map(\.text), ["second"])
        XCTAssertEqual(second.state, .listening)
        second.stop()
    }

    func test_callbacksFromAnotherTransport_areIgnored() async {
        let transport = FakeVoiceTransport()
        let listener = RecordingVoiceListener()
        let session = start(transport, listener: listener)
        await listening(listener)
        let other = FakeVoiceTransport()
        session.voiceTransport(other, didChange: .disconnected)
        session.voiceTransport(other, didReceive: json(["event": "text_delta", "delta": "other"]), topic: nil)
        XCTAssertEqual(session.state, .listening)
        XCTAssertTrue(listener.transcripts.isEmpty)
        session.stop()
    }

    // MARK: - Helpers

    private func start(_ transport: FakeVoiceTransport,
                       listener: RecordingVoiceListener,
                       permission: Bool = true) -> VoiceSessionController {
        let session = VoiceSessionController(transport: transport,
                                             listener: listener,
                                             requestMicrophonePermission: { permission })
        session.start(url: url, token: token)
        return session
    }

    private func listening(_ listener: RecordingVoiceListener) async {
        let connected = expectation(description: "listening")
        listener.onState = { if $0 == .listening { connected.fulfill() } }
        await fulfillment(of: [connected], timeout: 2)
        listener.onState = nil
    }

    private func json(_ raw: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }

    private func interruption(_ type: AVAudioSession.InterruptionType,
                              options: AVAudioSession.InterruptionOptions = []) {
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: type.rawValue,
            AVAudioSessionInterruptionOptionKey: options.rawValue
        ])
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

private final class RecordingVoiceListener: VoiceSessionListener {
    struct Transcript: Equatable {
        let text: String
        let role: VoiceTranscriptRole
        let isFinal: Bool
    }

    var states: [VoiceSessionState] = []
    var transcripts: [Transcript] = []
    var onState: ((VoiceSessionState) -> Void)?
    var onTranscript: (() -> Void)?

    func voiceSession(_ session: VoiceSessionController, didChangeState state: VoiceSessionState) {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual(session.state, state)
        states.append(state)
        onState?(state)
    }

    func voiceSession(_ session: VoiceSessionController, didUpdateTranscript text: String, role: VoiceTranscriptRole, isFinal: Bool) {
        XCTAssertTrue(Thread.isMainThread)
        transcripts.append(.init(text: text, role: role, isFinal: isFinal))
        onTranscript?()
    }
}

private final class AsyncGate<Value> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?
    private var pendingValue: Value?

    func wait() async -> Value {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let value = pendingValue {
                pendingValue = nil
                lock.unlock()
                continuation.resume(returning: value)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func resume(_ value: Value) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        if continuation == nil { pendingValue = value }
        lock.unlock()
        continuation?.resume(returning: value)
    }
}

private struct TestVoiceError: LocalizedError {
    var errorDescription: String? { "Test connection error" }
}
