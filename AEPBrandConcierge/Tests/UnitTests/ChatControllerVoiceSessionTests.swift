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

import XCTest
import AEPCore
@testable import AEPBrandConcierge

private final class SilentSpeaker: TextSpeaking { func utter(text: String) {} }

/// Brand Concierge's voice conversation, driven end to end through a `FakeVoiceTransport`:
/// availability, the bootstrap-to-connection handoff, transcript rendering, teardown, and gating
/// against other chat activity.
@MainActor
final class ChatControllerVoiceSessionTests: XCTestCase {

    private let configuration = ConciergeConfiguration()
    private var transport: FakeVoiceTransport!
    private var service: MockChatService!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        transport = FakeVoiceTransport()
        service = MockChatService(configuration: configuration)
        events = []
    }

    override func tearDown() {
        transport = nil
        service = nil
        Concierge.voiceTransport = nil
        super.tearDown()
    }

    // MARK: - Availability

    func test_voiceIsUnavailable_withoutATransport() {
        let controller = makeController(withVoice: false)

        XCTAssertFalse(controller.isVoiceAvailable)
        XCTAssertFalse(controller.voiceEnabled)

        controller.startVoiceSession()
        settle()
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_voiceIsAvailable_withATransport() {
        let controller = makeController()

        XCTAssertTrue(controller.isVoiceAvailable)
        XCTAssertTrue(controller.voiceEnabled)
        XCTAssertFalse(controller.isVoiceSessionActive)
    }

    func test_newChatSessions_useThePresentedTransport() {
        Concierge.voiceTransport = transport
        let session = Concierge.makeSession(configuration: configuration, sessionID: "session")
        XCTAssertTrue(session.controller.isVoiceAvailable)

        Concierge.voiceTransport = nil
        let withoutVoice = Concierge.makeSession(configuration: configuration, sessionID: "session")
        XCTAssertFalse(withoutVoice.controller.isVoiceAvailable)
    }

    // MARK: - Start

    func test_start_entersVoiceSession_andRequestsCredentials() {
        let controller = makeController()

        controller.startVoiceSession()

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.isVoiceConnecting)
        XCTAssertTrue(controller.voiceEnabled, "the button must stay tappable so the user can stop")
        XCTAssertFalse(controller.composerEditable)
        XCTAssertFalse(controller.micEnabled)
        XCTAssertFalse(controller.sendEnabled)
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1)
        settle()
        XCTAssertTrue(transport.connections.isEmpty, "no connection before the backend supplies credentials")
    }

    func test_bootstrap_connectsTheTransport_withTheBackendsUrlAndToken() {
        let controller = makeController()
        transport.autoConnect = false
        controller.startVoiceSession()

        service.emitBootstrap(url: "wss://voice.example", token: "secret")
        spinUntil(!transport.connections.isEmpty)

        XCTAssertEqual(transport.connections.map(\.url), ["wss://voice.example"])
        XCTAssertEqual(transport.connections.map(\.token), ["secret"])
        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertTrue(controller.isVoiceConnecting)
    }

    func test_connected_clearsTheConnectingIndicator() {
        let controller = makeController()

        startListening(controller)

        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_bootstrapClosingWithoutCredentials_failsBackToIdle_withAnErrorBubble() {
        let controller = makeController()
        controller.networkErrorMessage = "network down"
        controller.startVoiceSession()

        service.completeBootstrap(nil)
        spinUntil(controller.chatState == .idle)

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1, "the failure is tracked")
    }

    func test_bootstrapError_failsBackToIdle_withAnErrorBubble() {
        let controller = makeController()
        controller.startVoiceSession()

        service.completeBootstrap(.unreachable)
        spinUntil(controller.chatState == .idle)

        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "a finished bootstrap is not cancelled")
    }

    func test_bootstrapClosingAfterTheSessionStarted_keepsTheSessionRunning() {
        let controller = makeController()
        startListening(controller)

        service.completeBootstrap(nil)
        settle()

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertEqual(transport.disconnectCount, 0)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_microphonePermissionDenied_failsBackToIdle_withoutConnecting() {
        let controller = makeController(permission: false)
        controller.networkErrorMessage = "network down"
        controller.startVoiceSession()

        service.emitBootstrap()
        spinUntil(controller.chatState == .idle)

        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Transcript

    func test_transcript_updatesEachRolesBubbleInPlace_untilItIsFinal() {
        let controller = makeController()
        startListening(controller)

        userSays("Hel")
        userSays("Hello")
        userSays("Hello there", isFinal: true)
        transport.receive(json: ["event": "text_delta", "delta": "Hi"])
        transport.receive(json: ["event": "text_delta", "delta": ", how can I help?"])
        transport.receive(json: ["event": "turn_completed"])
        userSays("Shoes", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hello there", "Hi, how can I help?", "Shoes"])
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false, true])
    }

    func test_transcript_interleavedRoles_keepSeparateBubbles() {
        let controller = makeController()
        startListening(controller)

        userSays("I want")
        transport.receive(json: ["event": "text_delta", "delta": "Sure"])
        userSays("I want shoes", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["I want shoes", "Sure"])
    }

    func test_transcript_emptyText_addsNoBubble() {
        let controller = makeController()
        startListening(controller)

        userSays("  ", isFinal: true)

        XCTAssertTrue(controller.messages.isEmpty)
    }

    // MARK: - End

    func test_transportDisconnecting_returnsToIdle_withoutAnErrorBubble() {
        let controller = makeController()
        startListening(controller)
        transport.receive(json: ["event": "turn_completed", "fullText": "Bye"])

        transport.report(.disconnected)

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Bye"])
        XCTAssertTrue(events.isEmpty)
    }

    func test_agentEndingTheSession_returnsToIdle_andDisconnects() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["type": "session_notice", "data": ["kind": "session_ended", "reason": "user_inactivity_timeout"]])

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_transportFailure_returnsToIdle_withAnErrorBubble_andTracksIt() {
        let controller = makeController()
        controller.networkErrorMessage = "network down"
        startListening(controller)

        transport.report(.failed(URLError(.networkConnectionLost)))

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_stop_disconnectsTheTransport_andReturnsToIdle() {
        let controller = makeController()
        startListening(controller)
        service.completeBootstrap(nil)
        settle()

        controller.stopVoiceSession()

        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertNil(transport.delegate)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(controller.messages.isEmpty, "a user stop is not an error")
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "a finished bootstrap is not cancelled")
    }

    func test_stop_cancelsAStillOpenBootstrap() {
        let controller = makeController()
        startListening(controller)

        controller.stopVoiceSession()
        settle()

        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertTrue(controller.messages.isEmpty, "the cancelled bootstrap's completion is stale")
    }

    func test_stopBeforeCredentials_cancelsTheBootstrap_andNeverConnects() {
        let controller = makeController()
        controller.startVoiceSession()

        controller.stopVoiceSession()
        service.emitBootstrap()
        settle()

        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_toggle_startsThenStops() {
        let controller = makeController()

        controller.toggleVoiceSession()
        XCTAssertEqual(controller.chatState, .voiceSession)

        controller.toggleVoiceSession()
        XCTAssertEqual(controller.chatState, .idle)
    }

    // MARK: - Stale sessions

    func test_aSecondConversation_reusesTheTransport() {
        let controller = makeController()
        startListening(controller)
        userSays("first", isFinal: true)
        controller.stopVoiceSession()

        startListening(controller)
        userSays("second", isFinal: true)

        XCTAssertEqual(transport.connections.count, 2)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["first", "second"])
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_callbacksFromAnotherSession_areIgnored() {
        let controller = makeController()
        startListening(controller)
        let stranger = VoiceSessionController(transport: FakeVoiceTransport(), listener: controller)

        controller.voiceSession(stranger, didUpdateTranscript: "old", role: .assistant, isFinal: true)
        controller.voiceSession(stranger, didChangeState: .failed("late"))
        controller.voiceSession(stranger, didChangeState: .ended)

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Gating

    func test_start_isIgnoredWhileATurnIsInFlight() {
        service.shouldCallComplete = false
        let controller = makeController()
        controller.applyTextChange("hello")
        controller.sendMessage(isUser: true)
        XCTAssertEqual(controller.chatState, .processing)

        XCTAssertFalse(controller.voiceEnabled)
        controller.startVoiceSession()

        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(controller.chatState, .processing)
    }

    func test_start_isIgnoredWhileDictating() {
        let capturer = MockSpeechCapturer()
        let controller = makeController(capturer: capturer)
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.isRecording)

        XCTAssertFalse(controller.voiceEnabled)
        controller.startVoiceSession()

        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_typedTurnsAndDictation_areHeldOffDuringVoice() {
        let capturer = MockSpeechCapturer()
        let controller = makeController(capturer: capturer)
        controller.applyTextChange("hello")
        controller.startVoiceSession()

        controller.sendMessage(isUser: true)
        controller.startRecording(currentSelectionLocation: 0)
        settle()

        XCTAssertEqual(service.streamChatCallCount, 0)
        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 0)
    }

    func test_dataHandoff_isRejectedDuringVoice() {
        let controller = makeController()
        startListening(controller)

        var outcomes: [ConciergeError?] = []
        let accepted = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:]) { outcomes.append($0) }

        XCTAssertFalse(accepted)
        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertEqual(service.streamChatCallCount, 0)
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_chatReturnsToIdle_afterVoiceEnds_soTypedTurnsResume() {
        let controller = makeController()
        startListening(controller)
        controller.stopVoiceSession()

        controller.applyTextChange("hello")
        controller.sendMessage(isUser: true)
        spinUntil(service.streamChatCallCount == 1)

        XCTAssertEqual(controller.chatState, .processing)
        XCTAssertEqual(service.streamChatCallCount, 1)
    }

    // MARK: - Identity reset

    func test_identityReset_endsTheVoiceSession() {
        let controller = makeController()
        startListening(controller)

        controller.endConversationForIdentityReset()
        transport.receive(json: ["event": "turn_completed", "fullText": "late"])

        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertNil(transport.delegate)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertFalse(controller.voiceEnabled)

        controller.startVoiceSession()
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1, "an ended conversation cannot start voice")
    }

    func test_identityReset_freesTheTransportForTheNextChat() {
        let first = makeController()
        startListening(first)
        first.endConversationForIdentityReset()

        let nextService = MockChatService(configuration: configuration)
        service = nextService
        let second = makeController()
        startListening(second)
        userSays("hello", isFinal: true)

        XCTAssertEqual(second.messages.map(\.messageBody), ["hello"])
        XCTAssertTrue(first.messages.isEmpty)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    // MARK: - Helpers

    private func makeController(withVoice: Bool = true,
                                capturer: SpeechCapturing? = nil,
                                permission: Bool = true) -> ChatController {
        ChatController(configuration: configuration,
                       chatService: service,
                       speechCapturer: capturer,
                       speaker: SilentSpeaker(),
                       voiceTransport: withVoice ? transport : nil,
                       requestMicrophonePermission: { permission },
                       dispatch: { [weak self] in self?.events.append($0) })
    }

    /// Starts voice, delivers credentials and waits until the transport reports `.connected`.
    private func startListening(_ controller: ChatController,
                                file: StaticString = #filePath,
                                line: UInt = #line) {
        let count = transport.connections.count
        controller.startVoiceSession()
        service.emitBootstrap()
        spinUntil(transport.connections.count > count && !controller.isVoiceConnecting)
        XCTAssertGreaterThan(transport.connections.count, count, "credentials did not connect the transport", file: file, line: line)
        XCTAssertFalse(controller.isVoiceConnecting, "the transport did not report connected", file: file, line: line)
    }

    private func userSays(_ text: String, isFinal: Bool = false) {
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": text, "final": isFinal]])
    }

    private func isUserMessage(_ message: Message) -> Bool {
        if case .basic(let isUser) = message.template { return isUser }
        return false
    }

    private func spinUntil(timeout: TimeInterval = 1.0, _ predicate: @autoclosure () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    /// Lets already-scheduled work drain, so "nothing more happens" can be asserted.
    private func settle() {
        spinUntil(timeout: 0.2, false)
    }
}
