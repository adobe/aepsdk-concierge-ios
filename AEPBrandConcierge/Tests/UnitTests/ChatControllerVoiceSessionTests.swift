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
import AEPPluginSupport
@testable import AEPBrandConcierge

private final class SilentSpeaker: TextSpeaking { func utter(text: String) {} }

/// Brand Concierge's side of the voice plugin contract, driven through `FakeVoicePlugin`: discovery,
/// the bootstrap-to-session handoff, transcript rendering, teardown, and gating against other chat
/// activity.
@MainActor
final class ChatControllerVoiceSessionTests: XCTestCase {

    private let configuration = ConciergeConfiguration()
    private var plugin: FakeVoicePlugin!
    private var service: MockChatService!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        AEPPlugins.removeAll()
        plugin = FakeVoicePlugin()
        service = MockChatService(configuration: configuration)
        events = []
    }

    override func tearDown() {
        AEPPlugins.removeAll()
        plugin = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Discovery

    func test_voiceIsUnavailable_whenNoPluginIsRegistered() {
        let controller = makeController()

        XCTAssertFalse(controller.isVoiceAvailable)
        XCTAssertFalse(controller.voiceEnabled)

        controller.startVoiceSession()
        settle()
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_voiceIsAvailable_whenAPluginIsRegistered() {
        AEPPlugins.add(plugin)
        let controller = makeController()

        XCTAssertTrue(controller.isVoiceAvailable)
        XCTAssertTrue(controller.voiceEnabled)
        XCTAssertFalse(controller.isVoiceSessionActive)
    }

    // MARK: - Start

    func test_start_entersVoiceSession_andRequestsCredentials() {
        let controller = makeVoiceController()

        controller.startVoiceSession()

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.isVoiceConnecting)
        XCTAssertTrue(controller.voiceEnabled, "the button must stay tappable so the user can stop")
        XCTAssertFalse(controller.composerEditable)
        XCTAssertFalse(controller.micEnabled)
        XCTAssertFalse(controller.sendEnabled)
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1)
        XCTAssertTrue(plugin.sessions.isEmpty, "no session before the backend supplies credentials")
    }

    func test_bootstrap_startsAPluginSession_withTheBackendsUrlAndToken() {
        let controller = makeVoiceController()
        controller.startVoiceSession()

        service.emitBootstrap(livekitUrl: "wss://voice.example", token: "secret")
        spinUntil(!plugin.sessions.isEmpty)

        XCTAssertEqual(plugin.connections, [["url": "wss://voice.example", "token": "secret"]])
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_listening_clearsTheConnectingIndicator() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        session.report(.listening)

        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_bootstrapClosingWithoutCredentials_failsBackToIdle_withAnErrorBubble() {
        let controller = makeVoiceController()
        controller.networkErrorMessage = "network down"
        controller.startVoiceSession()

        service.completeBootstrap(nil)
        spinUntil(controller.chatState == .idle)

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(plugin.sessions.isEmpty)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1, "the failure is tracked")
    }

    func test_bootstrapError_failsBackToIdle_withAnErrorBubble() {
        let controller = makeVoiceController()
        controller.startVoiceSession()

        service.completeBootstrap(.unreachable)
        spinUntil(controller.chatState == .idle)

        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "a finished bootstrap is not cancelled")
    }

    func test_bootstrapClosingAfterTheSessionStarted_keepsTheSessionRunning() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        service.completeBootstrap(nil)
        settle()

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertEqual(session.stopCallCount, 0)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    // MARK: - Transcript

    func test_transcript_updatesEachRolesBubbleInPlace_untilItIsFinal() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)
        session.report(.listening)

        session.transcript("Hel", role: .user)
        session.transcript("Hello", role: .user)
        session.transcript("Hello there", role: .user, isFinal: true)
        session.transcript("Hi", role: .assistant)
        session.transcript("Hi, how can I help?", role: .assistant, isFinal: true)
        session.transcript("Shoes", role: .user, isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hello there", "Hi, how can I help?", "Shoes"])
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false, true])
    }

    func test_transcript_interleavedRoles_keepSeparateBubbles() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        session.transcript("I want", role: .user)
        session.transcript("Sure", role: .assistant)
        session.transcript("I want shoes", role: .user, isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["I want shoes", "Sure"])
    }

    func test_transcript_emptyText_addsNoBubble() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        session.transcript("", role: .assistant)

        XCTAssertTrue(controller.messages.isEmpty)
    }

    // MARK: - End

    func test_sessionEndingOnItsOwn_returnsToIdle_withoutAnErrorBubble() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)
        session.transcript("Bye", role: .assistant, isFinal: true)

        session.report(.ended)

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Bye"])
        XCTAssertTrue(events.isEmpty)
    }

    func test_sessionFailure_returnsToIdle_withAnErrorBubble_andTracksIt() {
        let controller = makeVoiceController()
        controller.networkErrorMessage = "network down"
        let session = startConnectedSession(controller)

        session.report(.failed("connection lost"))

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1)
    }

    func test_stop_stopsTheSession_andReturnsToIdle() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)
        service.completeBootstrap(nil)
        settle()

        controller.stopVoiceSession()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(controller.messages.isEmpty, "a user stop is not an error")
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "a finished bootstrap is not cancelled")
    }

    func test_stop_cancelsAStillOpenBootstrap() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        controller.stopVoiceSession()
        settle()

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertTrue(controller.messages.isEmpty, "the cancelled bootstrap's completion is stale")
    }

    func test_stopBeforeCredentials_cancelsTheBootstrap_andNeverStartsASession() {
        let controller = makeVoiceController()
        controller.startVoiceSession()

        controller.stopVoiceSession()
        service.emitBootstrap()
        settle()

        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertTrue(plugin.sessions.isEmpty)
        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_toggle_startsThenStops() {
        let controller = makeVoiceController()

        controller.toggleVoiceSession()
        XCTAssertEqual(controller.chatState, .voiceSession)

        controller.toggleVoiceSession()
        XCTAssertEqual(controller.chatState, .idle)
    }

    // MARK: - Stale sessions

    func test_callbacksFromAnEndedSession_areIgnored() {
        let controller = makeVoiceController()
        let first = startConnectedSession(controller)
        controller.stopVoiceSession()

        let second = startConnectedSession(controller)
        second.report(.listening)
        first.transcript("old", role: .assistant, isFinal: true)
        first.deliverUnchecked(.failed("late"))
        first.deliverUnchecked(.ended)

        XCTAssertEqual(controller.chatState, .voiceSession)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    func test_synchronousCallbacksDuringStartSession_areMatchedToTheNewSession() {
        let controller = makeVoiceController()
        plugin.onStartSession = { session in
            session.report(.listening)
            session.transcript("Hi", role: .assistant, isFinal: true)
        }

        _ = startConnectedSession(controller)

        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hi"])
    }

    func test_synchronousFailureDuringStartSession_returnsToIdle() {
        let controller = makeVoiceController()
        plugin.onStartSession = { $0.report(.failed("invalid url")) }

        controller.startVoiceSession()
        service.emitBootstrap()
        spinUntil(!plugin.sessions.isEmpty)

        XCTAssertEqual(controller.chatState, .idle)
        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(events.count, 1)
    }

    // MARK: - Gating

    func test_start_isIgnoredWhileATurnIsInFlight() {
        service.shouldCallComplete = false
        let controller = makeVoiceController()
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
        let controller = makeVoiceController(capturer: capturer)
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.isRecording)

        XCTAssertFalse(controller.voiceEnabled)
        controller.startVoiceSession()

        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_typedTurnsAndDictation_areHeldOffDuringVoice() {
        let capturer = MockSpeechCapturer()
        let controller = makeVoiceController(capturer: capturer)
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
        let controller = makeVoiceController()
        _ = startConnectedSession(controller)

        var outcomes: [ConciergeError?] = []
        let accepted = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:]) { outcomes.append($0) }

        XCTAssertFalse(accepted)
        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertEqual(service.streamChatCallCount, 0)
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_chatReturnsToIdle_afterVoiceEnds_soTypedTurnsResume() {
        let controller = makeVoiceController()
        _ = startConnectedSession(controller)
        controller.stopVoiceSession()

        controller.applyTextChange("hello")
        controller.sendMessage(isUser: true)
        spinUntil(service.streamChatCallCount == 1)

        XCTAssertEqual(controller.chatState, .processing)
        XCTAssertEqual(service.streamChatCallCount, 1)
    }

    // MARK: - Identity reset

    func test_identityReset_endsTheVoiceSession() {
        let controller = makeVoiceController()
        let session = startConnectedSession(controller)

        controller.endConversationForIdentityReset()
        session.transcript("late", role: .assistant, isFinal: true)

        XCTAssertEqual(session.stopCallCount, 1)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertFalse(controller.voiceEnabled)

        controller.startVoiceSession()
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1, "an ended conversation cannot start voice")
    }

    // MARK: - Helpers

    private func makeController(capturer: SpeechCapturing? = nil) -> ChatController {
        ChatController(configuration: configuration,
                       chatService: service,
                       speechCapturer: capturer,
                       speaker: SilentSpeaker(),
                       dispatch: { [weak self] in self?.events.append($0) })
    }

    private func makeVoiceController(capturer: SpeechCapturing? = nil) -> ChatController {
        AEPPlugins.add(plugin)
        return makeController(capturer: capturer)
    }

    /// Starts voice and delivers credentials, returning the plugin session they started.
    private func startConnectedSession(_ controller: ChatController,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) -> FakeVoiceSession {
        let count = plugin.sessions.count
        controller.startVoiceSession()
        service.emitBootstrap()
        spinUntil(plugin.sessions.count > count)
        guard plugin.sessions.count > count, let session = plugin.lastSession else {
            XCTFail("credentials did not start a plugin session", file: file, line: line)
            return FakeVoiceSession(listener: controller)
        }
        return session
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
