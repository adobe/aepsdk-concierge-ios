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

    // MARK: - Transcript → bubble mapping (FR-05)

    func test_messagesFromVoiceTranscript_mapsRolesAndTextInOrder() {
        let transcript: [VoiceSessionController.TranscriptEntry] = [
            .init(role: .user, text: "what's the price?"),
            .init(role: .assistant, text: "It's $9.99 per month.")
        ]

        let messages = ChatController.messages(fromVoiceTranscript: transcript)

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].messageBody, "what's the price?")
        XCTAssertEqual(messages[1].messageBody, "It's $9.99 per month.")
        guard case .basic(let firstIsUser) = messages[0].template,
              case .basic(let secondIsUser) = messages[1].template else {
            return XCTFail("expected .basic templates")
        }
        XCTAssertTrue(firstIsUser, "user entry maps to a user bubble")
        XCTAssertFalse(secondIsUser, "assistant entry maps to an agent bubble")
    }

    func test_messagesFromVoiceTranscript_emptyTranscript_producesNoMessages() {
        XCTAssertTrue(ChatController.messages(fromVoiceTranscript: []).isEmpty)
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
