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
@testable import AEPBrandConcierge

/// Deterministic coverage for `ChatController`'s voice-session wiring: the buffered-transcript →
/// bubble mapping and the FR-06 mutual-exclusion gating. The end-to-end bootstrap → connect → turn
/// flow is exercised on device (it needs a live `Room` and network) per the design docs.
@MainActor
final class ChatControllerVoiceSessionTests: XCTestCase {

    private func makeController() -> ChatController {
        let configuration = ConciergeConfiguration(consentCollectValue: "y", ecid: "ecid", surfaces: ["web://test"])
        let service = MockChatService(configuration: configuration)
        return ChatController(configuration: configuration, chatService: service, speechCapturer: nil, speaker: nil)
    }

    // MARK: - Live transcript rendering

    private func isUserBubble(_ message: Message) -> Bool? {
        if case .basic(let isUser) = message.template { return isUser }
        return nil
    }

    func test_liveUpdate_userPartialsUpdateOneBubbleInPlaceThenClose() {
        let controller = makeController()
        controller.chatState = .voiceSession

        controller.applyVoiceTranscriptUpdate(role: .user, text: "what's", isFinal: false)
        controller.applyVoiceTranscriptUpdate(role: .user, text: "what's the price", isFinal: false)
        controller.applyVoiceTranscriptUpdate(role: .user, text: "what's the price?", isFinal: true)

        XCTAssertEqual(controller.messages.count, 1, "user partials update one bubble in place")
        XCTAssertEqual(controller.messages[0].messageBody, "what's the price?")
        XCTAssertEqual(isUserBubble(controller.messages[0]), true)

        // After final, the next user update starts a new bubble.
        controller.applyVoiceTranscriptUpdate(role: .user, text: "and shipping?", isFinal: true)
        XCTAssertEqual(controller.messages.count, 2)
        XCTAssertEqual(controller.messages[1].messageBody, "and shipping?")
    }

    func test_liveUpdate_assistantStreamsIntoOneBubble() {
        let controller = makeController()
        controller.chatState = .voiceSession

        controller.applyVoiceTranscriptUpdate(role: .assistant, text: "It's", isFinal: false)
        controller.applyVoiceTranscriptUpdate(role: .assistant, text: "It's $9.99", isFinal: false)
        controller.applyVoiceTranscriptUpdate(role: .assistant, text: "It's $9.99 per month.", isFinal: true)

        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(controller.messages[0].messageBody, "It's $9.99 per month.")
        XCTAssertEqual(isUserBubble(controller.messages[0]), false)
    }

    func test_liveUpdate_userThenAssistant_rendersTwoBubblesInOrder() {
        let controller = makeController()
        controller.chatState = .voiceSession

        controller.applyVoiceTranscriptUpdate(role: .user, text: "hi", isFinal: true)
        controller.applyVoiceTranscriptUpdate(role: .assistant, text: "hello there", isFinal: true)

        XCTAssertEqual(controller.messages.count, 2)
        XCTAssertEqual(isUserBubble(controller.messages[0]), true)
        XCTAssertEqual(controller.messages[0].messageBody, "hi")
        XCTAssertEqual(isUserBubble(controller.messages[1]), false)
        XCTAssertEqual(controller.messages[1].messageBody, "hello there")
    }

    func test_liveUpdate_ignoredWhenNotInVoiceSession() {
        let controller = makeController()
        controller.chatState = .idle

        controller.applyVoiceTranscriptUpdate(role: .user, text: "hi", isFinal: true)

        XCTAssertTrue(controller.messages.isEmpty, "updates outside a voice session are ignored")
    }

    // MARK: - Gating (FR-06)

    func test_gating_duringVoiceSession_blocksComposerMicAndSend() {
        let controller = makeController()

        controller.chatState = .voiceSession

        XCTAssertTrue(controller.isVoiceSessionActive)
        XCTAssertFalse(controller.micEnabled, "dictation mic must be gated off during a voice session")
        XCTAssertFalse(controller.composerEditable, "text composer must be gated off during a voice session")
        XCTAssertFalse(controller.sendEnabled, "send must be gated off during a voice session")
    }

    func test_gating_idle_allowsComposerAndMic() {
        let controller = makeController()

        controller.chatState = .idle

        XCTAssertFalse(controller.isVoiceSessionActive)
        XCTAssertTrue(controller.micEnabled)
        XCTAssertTrue(controller.composerEditable)
    }

    // MARK: - Start/stop guards

    func test_startVoiceSession_fromIdle_entersVoiceSessionState() {
        let controller = makeController()

        controller.startVoiceSession()

        // Set synchronously before the async bootstrap runs.
        XCTAssertEqual(controller.chatState, .voiceSession)
    }

    func test_startVoiceSession_whileProcessing_isIgnored() {
        let controller = makeController()
        controller.chatState = .processing

        controller.startVoiceSession()

        XCTAssertEqual(controller.chatState, .processing, "a voice session must not start over a processing turn")
    }

    func test_stopVoiceSession_whenNotActive_isIgnored() {
        let controller = makeController()
        controller.chatState = .idle

        controller.stopVoiceSession()

        XCTAssertEqual(controller.chatState, .idle)
    }
}
