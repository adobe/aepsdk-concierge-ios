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

import UIKit
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
        ConciergeXDMContextStore.shared.clear()
    }

    override func tearDown() {
        ConciergeXDMContextStore.shared.clear()
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
        controller.applyTextChange("hello")

        controller.startVoiceSession()

        XCTAssertEqual(controller.chatState, .idle, "voice adds no case to the public ChatState")
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.isVoiceConnecting)
        XCTAssertTrue(controller.voiceEnabled, "the button must stay tappable so the user can stop")
        XCTAssertFalse(controller.composerEditable)
        XCTAssertFalse(controller.micEnabled)
        XCTAssertFalse(controller.sendEnabled)
        spinUntil(service.bootstrapVoiceSessionCallCount == 1)
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1)
        settle()
        XCTAssertTrue(transport.connections.isEmpty, "no connection before the backend supplies credentials")
    }

    func test_bootstrap_sendsTheHeldXDMContext_forTheResolvedSession() throws {
        try ConciergeXDMContextStore.shared.update(["loyalty": ["tier": "gold"]])
        let controller = makeController()

        startVoice(controller)

        let expected: [String: Any] = ["loyalty": ["tier": "gold"]]
        XCTAssertTrue((service.lastBootstrapXDMFields as NSDictionary?)?.isEqual(to: expected) ?? false)
        XCTAssertEqual(service.lastBootstrapSessionID, configuration.sessionId)
    }

    func test_bootstrap_withNoHeldXDMContext_sendsNoExtraXDMFields() {
        let controller = makeController()

        startVoice(controller)

        XCTAssertNil(service.lastBootstrapXDMFields)
    }

    func test_bootstrap_connectsTheTransport_withTheBackendsUrlAndToken() {
        let controller = makeController()
        transport.autoConnect = false
        startVoice(controller)

        service.emitBootstrap(url: "wss://voice.example", token: "secret")
        spinUntil(!transport.connections.isEmpty)

        XCTAssertEqual(transport.connections.map(\.url.absoluteString), ["wss://voice.example"])
        XCTAssertEqual(transport.connections.map(\.token), ["secret"])
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.isVoiceConnecting)
    }

    func test_connected_clearsTheConnectingIndicator() {
        let controller = makeController()

        startListening(controller)

        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(controller.isVoiceSessionActive)
    }

    func test_reconnecting_keepsTheConversation_andShowsTheConnectingIndicatorUntilConnected() {
        let controller = makeController()
        startListening(controller)

        transport.report(.reconnecting)
        XCTAssertTrue(controller.isVoiceConnecting)
        XCTAssertTrue(controller.isVoiceSessionActive)

        transport.report(.connected)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertEqual(transport.disconnectCount, 0)
        XCTAssertTrue(controller.messages.isEmpty, "no error bubble")
    }

    func test_bootstrapClosingWithoutCredentials_failsBackToIdle_withAnErrorBubble() {
        let controller = makeController()
        controller.networkErrorMessage = "network down"
        startVoice(controller)

        service.completeBootstrap(nil)
        spinUntil(!controller.isVoiceSessionActive)

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1, "the failure is tracked")
    }

    func test_bootstrapError_failsBackToIdle_withAnErrorBubble() {
        let controller = makeController()
        startVoice(controller)

        service.completeBootstrap(.unreachable)
        spinUntil(!controller.isVoiceSessionActive)

        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(trackedErrorMessage(), VoiceSessionFailure.bootstrapFailed.message)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "a finished bootstrap is not cancelled")
    }

    func test_bootstrapClosingAfterTheSessionStarted_keepsTheSessionRunning() {
        let controller = makeController()
        startListening(controller)

        service.completeBootstrap(nil)
        settle()

        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertEqual(transport.disconnectCount, 0)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_microphonePermissionDenied_startsNothing_andShowsThePermissionDialog() {
        let controller = makeController(permission: false)
        controller.startVoiceSession()

        spinUntil(!controller.isVoiceSessionActive)
        settle()

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.isVoiceConnecting)
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0, "no conversation is requested without the microphone")
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertTrue(controller.showPermissionDialog)
        XCTAssertEqual(controller.permissionDialogPurpose, .voiceConversation)
        XCTAssertTrue(controller.messages.isEmpty, "a denied permission is not an error")
        XCTAssertTrue(events.isEmpty)
    }

    func test_stopWhilePermissionIsPending_neverRequestsCredentials() {
        let controller = makeController()
        controller.startVoiceSession()

        controller.stopVoiceSession()
        settle()

        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "there was no request to cancel")
        XCTAssertFalse(controller.showPermissionDialog)
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
        transport.receive(json: ["event": "turn_completed", "fullText": "Hi, how can I help?"])
        userSays("Shoes", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hello there", "Hi, how can I help?", "Shoes", ""])
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false, true, false])
    }

    func test_transcript_interleavedRoles_keepSeparateBubbles() {
        let controller = makeController()
        startListening(controller)

        userSays("I want")
        transport.receive(json: ["event": "text_delta", "delta": "Sure"])
        userSays("I want shoes", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["I want shoes", "Sure", ""])
    }

    func test_transcript_scrollsTheUsersWordsToTheTop_andKeepsThemThereForTheReply() {
        let controller = makeController()
        startListening(controller)

        userSays("Show me shoes", isFinal: true)
        let firstUserBubble = controller.messages[0].id
        XCTAssertEqual(controller.voiceScrollAnchorId, firstUserBubble)
        XCTAssertEqual(controller.userMessageToScrollId, firstUserBubble)

        transport.receive(json: ["event": "text_delta", "delta": "Sure"])
        transport.receive(json: ["event": "turn_completed", "fullText": "Sure"])
        XCTAssertEqual(controller.voiceScrollAnchorId, firstUserBubble, "the reply shows below the user's words")
        XCTAssertEqual(controller.userMessageToScrollId, firstUserBubble)

        userSays("Red ones", isFinal: true)
        XCTAssertEqual(controller.voiceScrollAnchorId, controller.messages[2].id)
        XCTAssertEqual(controller.userMessageToScrollId, controller.messages[2].id)
    }

    func test_transcript_agentSpeakingFirst_scrollsItsBubbleToTheTop() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["event": "text_delta", "delta": "Hi! How can I help?"])

        XCTAssertEqual(controller.voiceScrollAnchorId, controller.messages[0].id)
        XCTAssertEqual(controller.userMessageToScrollId, controller.messages[0].id)
    }

    func test_voiceSessionEnding_clearsTheScrollAnchor() {
        let controller = makeController()
        startListening(controller)
        userSays("Show me shoes", isFinal: true)

        controller.stopVoiceSession()

        XCTAssertNil(controller.voiceScrollAnchorId)
    }

    func test_transcript_emptyText_addsNoBubble() {
        let controller = makeController()
        startListening(controller)

        userSays("  ", isFinal: true)

        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_transcript_emptyFinal_removesTheOpenBubble_andTheNextBubbleBecomesTheAnchor() {
        let controller = makeController()
        startListening(controller)
        userSays("Show me")
        XCTAssertEqual(controller.messages.count, 1)

        userSays("", isFinal: true)

        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertNil(controller.voiceScrollAnchorId)

        transport.receive(json: ["event": "text_delta", "delta": "Hi"])
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hi"])
        XCTAssertEqual(controller.voiceScrollAnchorId, controller.messages[0].id)
    }

    // MARK: - Turn end

    func test_turnEnd_rendersTheReplyWithSources_thenCardsCtasAndSuggestions_likeATypedTurn() {
        let controller = makeController()
        startListening(controller)

        userSays("Shoes", isFinal: true)
        transport.receive(json: ["event": "text_delta", "delta": "Here are"])
        transport.receive(json: [
            "event": "ui_payload",
            "sources": [["url": "https://example.com", "title": "Example", "start_index": 0, "end_index": 4, "citation_number": 1]],
            "multimodalElements": ["elements": [
                ["id": "p1", "entity_info": ["productName": "Runner"]],
                ["id": "cta", "type": "ctaButton", "entity_info": ["primary": ["text": "Shop", "url": "https://example.com/shop"]]]
            ]],
            "promptSuggestions": ["Red ones", "Blue ones"]
        ])
        transport.receive(json: ["event": "turn_completed", "fullText": "Here are some shoes"])

        XCTAssertEqual(controller.messages.count, 6)
        XCTAssertEqual(controller.messages[1].messageBody, "Here are some shoes")
        XCTAssertEqual(controller.messages[1].sources?.map(\.url), ["https://example.com"])
        XCTAssertFalse(controller.messages[1].feedbackEligible, "a voice reply has no payload to send feedback on")
        XCTAssertFalse(controller.messages[1].isStreamComplete)
        guard case .productCard(let card) = controller.messages[2].template else { return XCTFail("expected a product card") }
        XCTAssertEqual(card.title, "Runner")
        guard case .ctaButton(let action) = controller.messages[3].template else { return XCTFail("expected a CTA") }
        XCTAssertEqual(action.text, "Shop")
        XCTAssertEqual(controller.messages.suffix(2).map(suggestionText), ["Red ones", "Blue ones"])
        XCTAssertEqual(events.map(\.name), [ConciergeConstants.TrackingEvent.Name.CARDS_RENDERED])
    }

    func test_failedTurn_replacesTheReplyWithTheCopy_andStillRendersThePayload() {
        let controller = makeController()
        controller.voiceTurnFailedMessage = "Try again"
        startListening(controller)

        userSays("Shoes", isFinal: true)
        transport.receive(json: ["event": "text_delta", "delta": "Here are"])
        transport.receive(json: ["event": "ui_payload", "promptSuggestions": ["Red ones"]])
        transport.receive(json: ["event": "turn_completed", "fullText": "Here are", "state": "error"])

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Try again", nil])
        XCTAssertEqual(controller.messages.last.flatMap(suggestionText), "Red ones")
        XCTAssertTrue(controller.isVoiceSessionActive, "a failed turn keeps the conversation open")
        XCTAssertTrue(events.isEmpty)
    }

    func test_failedTurnWithoutAReply_showsTheCopyInPlaceOfTheThinkingIndicator() {
        let controller = makeController()
        startListening(controller)

        userSays("Shoes", isFinal: true)
        let thinking = controller.messages.last?.id
        transport.receive(json: ["event": "turn_completed", "fullText": "", "state": "error"])
        userSays("Hello", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", ConciergeCopy.defaultVoiceTurnFailed, "Hello", ""])
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false, true, false])
        XCTAssertEqual(controller.messages[1].id, thinking)
    }

    func test_turnEnd_afterTheNextUserTurnStarted_isDropped() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "Shoes", "final": true, "turnId": "t1"]])
        transport.receive(json: ["event": "text_delta", "delta": "Here", "turnId": "t1"])
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "Stop", "final": true, "turnId": "t2"]])
        transport.receive(json: ["event": "ui_payload", "turnId": "t1", "promptSuggestions": ["Red ones"]])
        transport.receive(json: ["event": "turn_completed", "turnId": "t1", "fullText": "Here are shoes"])

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Here", "Stop", ""])
    }

    // MARK: - Thinking indicator

    func test_thinkingIndicator_showsAfterTheUsersFinal_andTheReplyFillsIt() {
        let controller = makeController()
        startListening(controller)

        userSays("Shoes")
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes"], "the user is still speaking")
        userSays("Shoes", isFinal: true)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", ""])
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false])
        XCTAssertEqual(controller.voiceScrollAnchorId, controller.messages[0].id, "the user's words stay at the top")
        let thinking = controller.messages[1].id

        transport.receive(json: ["event": "text_delta", "delta": "Here"])
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Here"])
        transport.receive(json: ["event": "text_delta", "delta": " are shoes"])
        transport.receive(json: ["event": "turn_completed", "fullText": "Here are shoes"])

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Here are shoes"])
        XCTAssertEqual(controller.messages[1].id, thinking, "the reply takes the indicator's place, as in a typed turn")
        XCTAssertEqual(controller.voiceScrollAnchorId, controller.messages[0].id)
    }

    func test_thinkingIndicator_isRemoved_whenANewerTurnReplacesIt() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "Shoes", "final": true, "turnId": "t1"]])
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "Stop", "final": false, "turnId": "t2"]])
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Stop"])

        transport.receive(json: ["type": "transcript_delta", "data": ["delta": "Stop", "final": true, "turnId": "t2"]])
        transport.receive(json: ["event": "text_delta", "delta": "OK", "turnId": "t2"])
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Shoes", "Stop", "OK"])
    }

    func test_thinkingIndicator_isNotShown_forAWithdrawnUtterance_orATurnTheAgentOpens() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["event": "text_delta", "delta": "Hi!"])
        transport.receive(json: ["event": "turn_completed", "fullText": "Hi!"])
        userSays("Um")
        userSays("", isFinal: true)

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Hi!"])
    }

    func test_thinkingIndicator_isRemoved_whenVoiceStopsOrFails() {
        for fails in [false, true] {
            let controller = makeController()
            controller.networkErrorMessage = "network down"
            startListening(controller)
            userSays("Shoes", isFinal: true)

            if fails {
                transport.report(.failed(URLError(.networkConnectionLost)))
            } else {
                controller.stopVoiceSession()
            }

            XCTAssertEqual(controller.messages.map(\.messageBody), fails ? ["Shoes", "network down"] : ["Shoes"])
        }
    }

    // MARK: - Prompt suggestions

    func test_suggestionTapDuringVoice_goesToTheVoiceAgent_notToTheService() {
        let controller = makeController()
        startListening(controller)

        controller.sendPromptSuggestion("Red ones")
        spinUntil(!transport.sends.isEmpty)

        XCTAssertEqual(transport.sends.map(\.topic), ["bc-text-input"])
        XCTAssertEqual(transport.sentJSON.first?["text"] as? String, "Red ones")
        XCTAssertEqual(service.streamChatCallCount, 0)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Red ones", ""], "the thinking indicator follows the user's words")
        XCTAssertEqual(controller.messages.map(isUserMessage), [true, false])
        XCTAssertEqual(controller.userMessageToScrollId, controller.messages[0].id)
        XCTAssertEqual(controller.inputText, "", "the composer is left alone")
        XCTAssertEqual(events.map(\.name), [ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED])
    }

    func test_suggestionTapDuringVoice_tracksTheContextSentWithTheBootstrap() throws {
        try ConciergeXDMContextStore.shared.update(["loyalty": ["tier": "gold"]])
        let controller = makeController()
        startListening(controller)
        try ConciergeXDMContextStore.shared.update(["loyalty": ["tier": "platinum"]])

        controller.sendPromptSuggestion("Red ones")
        spinUntil(!events.isEmpty)

        let tracked = events.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.XDM_FIELDS] as? [String: Any]
        XCTAssertEqual((tracked?["loyalty"] as? [String: Any])?["tier"] as? String, "gold",
                       "a running voice conversation keeps the context it started with")
    }

    func test_suggestionTapDuringVoice_isDroppedWhileConnectingOrWhileATurnWaitsForItsReply() {
        transport.autoConnect = false
        let controller = makeController()
        startVoice(controller)
        service.emitBootstrap()
        spinUntil(!transport.connections.isEmpty)
        controller.sendPromptSuggestion("Red ones")

        transport.report(.connected)
        userSays("I want shoes", isFinal: true)
        controller.sendPromptSuggestion("Red ones")
        settle()

        XCTAssertTrue(transport.sends.isEmpty)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["I want shoes", ""])
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(service.streamChatCallCount, 0)
    }

    func test_suggestionSendFailureDuringVoice_showsTheMessageSendFailedCopy() {
        transport.sendError = URLError(.notConnectedToInternet)
        let controller = makeController()
        controller.voiceMessageSendFailedMessage = "Not sent"
        startListening(controller)

        controller.sendPromptSuggestion("Red ones")
        spinUntil(controller.messages.last?.messageBody == "Not sent")

        XCTAssertEqual(controller.messages.map(\.messageBody), ["Red ones", "Not sent"])
        XCTAssertTrue(controller.isVoiceSessionActive)
    }

    func test_suggestionTapAfterVoiceEnds_streamsLikeATypedMessage() {
        let controller = makeController()
        startListening(controller)
        controller.stopVoiceSession()

        controller.sendPromptSuggestion("Red ones")
        spinUntil(service.streamChatCallCount == 1)

        XCTAssertEqual(service.streamChatCallCount, 1)
        XCTAssertTrue(transport.sends.isEmpty)
        XCTAssertEqual(controller.messages.first?.messageBody, "Red ones")
        XCTAssertEqual(events.first?.name, ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED)
    }

    // MARK: - End

    func test_transportDisconnecting_returnsToIdle_withoutAnErrorBubble() {
        let controller = makeController()
        startListening(controller)
        transport.receive(json: ["event": "text_delta", "delta": "Bye"])
        transport.receive(json: ["event": "turn_completed", "fullText": "Bye"])

        transport.report(.disconnected)

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["Bye"])
        XCTAssertTrue(events.isEmpty)
    }

    func test_agentEndingTheSession_returnsToIdle_andDisconnects() {
        let controller = makeController()
        startListening(controller)

        transport.receive(json: ["type": "session_notice", "data": ["kind": "session_ended", "reason": "user_inactivity_timeout"]])

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_agentEndingTheSessionWithAnError_returnsToIdle_withAnErrorBubble_andTracksIt() {
        let controller = makeController()
        controller.networkErrorMessage = "network down"
        startListening(controller)

        transport.receive(json: ["type": "session_notice", "data": ["kind": "session_ended", "reason": "error"]])

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_transportFailure_returnsToIdle_withAnErrorBubble_andTracksIt() {
        let controller = makeController()
        controller.networkErrorMessage = "network down"
        startListening(controller)

        transport.report(.failed(URLError(.networkConnectionLost)))

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["network down"])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_transportFailure_tracksAFixedMessage_withoutTheTransportsErrorText() {
        struct ErrorWithCredentials: LocalizedError {
            var errorDescription: String? { "Invalid URL: wss://voice.example.com/rtc?access_token=secret-token" }
        }
        let controller = makeController()
        startListening(controller)

        transport.report(.failed(ErrorWithCredentials()))

        XCTAssertEqual(trackedErrorMessage(), VoiceSessionFailure.transportFailed.message)
    }

    func test_stop_disconnectsTheTransport_andReturnsToIdle() {
        let controller = makeController()
        startListening(controller)
        service.completeBootstrap(nil)
        settle()

        controller.stopVoiceSession()

        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertNil(transport.delegate)
        XCTAssertFalse(controller.isVoiceSessionActive)
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
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty, "the cancelled bootstrap's completion is stale")
    }

    func test_stopBeforeCredentials_cancelsTheBootstrap_andNeverConnects() {
        let controller = makeController()
        startVoice(controller)

        controller.stopVoiceSession()
        service.emitBootstrap()
        settle()

        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_toggle_startsThenStops() {
        let controller = makeController()

        controller.toggleVoiceSession()
        XCTAssertTrue(controller.isVoiceSessionActive)

        controller.toggleVoiceSession()
        XCTAssertFalse(controller.isVoiceSessionActive)
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
        XCTAssertEqual(controller.messages.map(\.messageBody), ["first", "second", ""])
        XCTAssertTrue(controller.isVoiceSessionActive)
    }

    func test_callbacksFromAnotherSession_areIgnored() {
        let controller = makeController()
        startListening(controller)
        let stranger = VoiceSessionController(transport: FakeVoiceTransport(), listener: controller)

        controller.voiceSession(stranger, didUpdateTranscript: "old", role: .assistant, isFinal: true)
        controller.voiceSession(stranger, didChangeState: .failed(.transportFailed))
        controller.voiceSession(stranger, didChangeState: .ended)

        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - One conversation app-wide

    func test_anotherChat_cannotStartVoice_whileAConversationRuns() {
        let ownership = VoiceSessionOwnership()
        let owner = makeController(voiceOwnership: ownership)
        let other = makeController(voiceOwnership: ownership)
        XCTAssertTrue(other.voiceEnabled)

        owner.startVoiceSession()
        XCTAssertFalse(other.voiceEnabled, "voice is claimed at the tap, before permission and credentials")
        spinUntil(service.bootstrapVoiceSessionCallCount == 1)
        service.emitBootstrap()
        spinUntil(!owner.isVoiceConnecting)

        other.startVoiceSession()
        settle()
        other.stopVoiceSession()
        userSays("hello", isFinal: true)

        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 1)
        XCTAssertEqual(transport.connections.count, 1)
        XCTAssertEqual(transport.disconnectCount, 0)
        XCTAssertFalse(other.isVoiceSessionActive)
        XCTAssertTrue(other.messages.isEmpty)
        XCTAssertEqual(owner.messages.map(\.messageBody), ["hello", ""])
        XCTAssertTrue(owner.voiceEnabled, "the owner can still stop its conversation")
    }

    func test_endingTheConversation_freesVoiceForTheOtherChat() {
        let ownership = VoiceSessionOwnership()
        let owner = makeController(voiceOwnership: ownership)
        let other = makeController(voiceOwnership: ownership)
        startListening(owner)
        owner.stopVoiceSession()

        XCTAssertTrue(other.voiceEnabled)
        startListening(other)
        userSays("hi", isFinal: true)

        XCTAssertEqual(other.messages.map(\.messageBody), ["hi", ""])
        XCTAssertTrue(owner.messages.isEmpty)
        XCTAssertFalse(owner.voiceEnabled)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    func test_theOwningChatGoingAway_hangsUpItsCall_andFreesVoice() {
        let ownership = VoiceSessionOwnership()
        let other = makeController(voiceOwnership: ownership)
        weak var released: ChatController?
        autoreleasepool {
            let owner = makeController(voiceOwnership: ownership)
            released = owner
            startListening(owner)
            XCTAssertFalse(other.voiceEnabled)
        }

        XCTAssertNil(released)
        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertNil(transport.delegate)
        XCTAssertTrue(other.voiceEnabled)
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
        XCTAssertTrue(controller.isVoiceSessionActive)
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

    // MARK: - App background

    func test_appBackground_withoutTheTransportsOptIn_endsTheVoiceSession() {
        let controller = makeController()
        startListening(controller)

        enterBackground()
        spinUntil(!controller.isVoiceSessionActive)

        XCTAssertEqual(transport.disconnectCount, 1)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty, "going to the background is not an error")
    }

    func test_appBackground_withTheTransportsOptIn_keepsTheConversation_andItsTranscript() {
        transport.continuesInBackground = true
        let controller = makeController()
        startListening(controller)

        enterBackground()
        settle()
        userSays("still here", isFinal: true)

        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertEqual(transport.disconnectCount, 0)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["still here", ""])

        transport.report(.disconnected)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(controller.messages.map(\.messageBody), ["still here"], "a transport end in the background is not an error")
        XCTAssertTrue(events.isEmpty)
    }

    func test_appBackgroundWhileConnecting_withTheTransportsOptIn_keepsTheConversation() {
        transport.continuesInBackground = true
        transport.autoConnect = false
        let controller = makeController()
        startVoice(controller)
        service.emitBootstrap()
        spinUntil(!transport.connections.isEmpty)

        enterBackground()
        settle()
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertEqual(transport.disconnectCount, 0)

        transport.report(.connected)
        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.isVoiceConnecting)
    }

    func test_appBackgroundWhilePermissionIsPending_endsTheConversation_evenWithTheTransportsOptIn() {
        transport.continuesInBackground = true
        let controller = makeController(requestPermission: {
            try? await Task.sleep(nanoseconds: 300_000_000)
            return true
        })
        controller.startVoiceSession()

        enterBackground()
        spinUntil(!controller.isVoiceSessionActive)
        spinUntil(timeout: 0.5, false)

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertEqual(service.bootstrapVoiceSessionCallCount, 0, "a granted permission after the end requests nothing")
        XCTAssertTrue(transport.connections.isEmpty)
    }

    func test_appBackgroundDuringBootstrap_cancelsIt_andNeverConnects_evenWithTheTransportsOptIn() {
        transport.continuesInBackground = true
        let controller = makeController()
        startVoice(controller)

        enterBackground()
        spinUntil(!controller.isVoiceSessionActive)
        service.emitBootstrap()
        settle()

        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertTrue(transport.connections.isEmpty)
        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.messages.isEmpty)
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

        XCTAssertEqual(second.messages.map(\.messageBody), ["hello", ""])
        XCTAssertTrue(first.messages.isEmpty)
        XCTAssertEqual(transport.disconnectCount, 1)
    }

    // MARK: - Helpers

    private func makeController(withVoice: Bool = true,
                                capturer: SpeechCapturing? = nil,
                                permission: Bool = true,
                                requestPermission: (() async -> Bool)? = nil,
                                appState: ConciergeAppState = ConciergeAppState(),
                                voiceOwnership: VoiceSessionOwnership = VoiceSessionOwnership()) -> ChatController {
        ChatController(configuration: configuration,
                       chatService: service,
                       speechCapturer: capturer,
                       speaker: SilentSpeaker(),
                       voiceTransport: withVoice ? transport : nil,
                       requestMicrophonePermission: requestPermission ?? { permission },
                       dispatch: { [weak self] in self?.events.append($0) },
                       appState: appState,
                       voiceOwnership: voiceOwnership)
    }

    /// Starts voice, delivers credentials and waits until the transport reports `.connected`.
    private func startListening(_ controller: ChatController,
                                file: StaticString = #filePath,
                                line: UInt = #line) {
        let count = transport.connections.count
        startVoice(controller)
        service.emitBootstrap()
        spinUntil(transport.connections.count > count && !controller.isVoiceConnecting)
        XCTAssertGreaterThan(transport.connections.count, count, "credentials did not connect the transport", file: file, line: line)
        XCTAssertFalse(controller.isVoiceConnecting, "the transport did not report connected", file: file, line: line)
    }

    /// Starts voice and waits until the microphone permission check lets the bootstrap request out.
    private func startVoice(_ controller: ChatController) {
        let count = service.bootstrapVoiceSessionCallCount
        controller.startVoiceSession()
        spinUntil(service.bootstrapVoiceSessionCallCount > count)
    }

    /// Posts the app's background notification, and brings every app state back to the foreground
    /// when the test ends so later tests don't start in the background.
    private func enterBackground() {
        addTeardownBlock {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func userSays(_ text: String, isFinal: Bool = false) {
        transport.receive(json: ["type": "transcript_delta", "data": ["delta": text, "final": isFinal]])
    }

    private func trackedErrorMessage() -> String? {
        events.last?.data?[ConciergeConstants.TrackingEvent.EventData.Key.ERROR_MESSAGE] as? String
    }

    private func suggestionText(_ message: Message) -> String? {
        if case .promptSuggestion(let text) = message.template { return text }
        return nil
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
