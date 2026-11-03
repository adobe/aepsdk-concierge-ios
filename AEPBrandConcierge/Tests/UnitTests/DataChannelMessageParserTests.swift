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

/// Mirrors web's `voiceStreamingUtils.test.ts` coverage for `parseDataChannelMessage` — the wire
/// contract is shared with the backend worker, so both clients must parse it identically.
final class DataChannelMessageParserTests: XCTestCase {

    // MARK: - Type-based: transcript_delta (user STT)

    func test_transcriptDelta_userTypeBased_parsesFields() {
        let raw: [String: Any] = [
            "type": "transcript_delta",
            "data": ["role": "user", "delta": "hello", "sequence": 2, "final": true, "turnId": "turn_1"]
        ]
        guard case let .transcriptDelta(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected transcriptDelta")
        }
        XCTAssertEqual(d.role, .user)
        XCTAssertEqual(d.delta, "hello")
        XCTAssertEqual(d.sequence, 2)
        XCTAssertTrue(d.final)
        XCTAssertEqual(d.turnId, "turn_1")
    }

    func test_transcriptDelta_assistantRole_typeBased() {
        let raw: [String: Any] = ["type": "transcript_delta", "data": ["role": "assistant", "delta": "hi"]]
        guard case let .transcriptDelta(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected transcriptDelta")
        }
        XCTAssertEqual(d.role, .assistant)
        XCTAssertEqual(d.sequence, 0, "missing sequence coerces to 0")
        XCTAssertFalse(d.final, "missing final coerces to false")
    }

    func test_transcriptDelta_missingData_returnsNil() {
        XCTAssertNil(DataChannelMessageParser.parse(["type": "transcript_delta"]))
    }

    func test_transcriptDelta_emptyTurnId_becomesNil() {
        let raw: [String: Any] = ["type": "transcript_delta", "data": ["delta": "x", "turnId": ""]]
        guard case let .transcriptDelta(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected transcriptDelta")
        }
        XCTAssertNil(d.turnId, "empty-string turnId must become nil, not \"\"")
    }

    // MARK: - Event-based: assistant turn

    func test_textDelta_eventBased_isAssistantNonFinal() {
        let raw: [String: Any] = ["event": "text_delta", "delta": "world", "sequence": 3, "turnId": "turn_9"]
        guard case let .transcriptDelta(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected transcriptDelta")
        }
        XCTAssertEqual(d.role, .assistant)
        XCTAssertEqual(d.delta, "world")
        XCTAssertEqual(d.sequence, 3)
        XCTAssertFalse(d.final)
        XCTAssertEqual(d.turnId, "turn_9")
    }

    func test_turnCompleted_eventBased_parsesTurnDone() {
        let raw: [String: Any] = ["event": "turn_completed", "fullText": "The answer.", "state": "completed", "turnId": "turn_9"]
        guard case let .turnDone(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected turnDone")
        }
        XCTAssertEqual(d.fullText, "The answer.")
        XCTAssertEqual(d.state, .completed)
        XCTAssertEqual(d.turnId, "turn_9")
    }

    func test_turnCompleted_missingState_defaultsToCompleted() {
        let raw: [String: Any] = ["event": "turn_completed", "fullText": "x"]
        guard case let .turnDone(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected turnDone")
        }
        XCTAssertEqual(d.state, .completed)
    }

    func test_turnCompleted_interruptedState() {
        let raw: [String: Any] = ["event": "turn_completed", "fullText": "x", "state": "interrupted"]
        guard case let .turnDone(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected turnDone")
        }
        XCTAssertEqual(d.state, .interrupted)
    }

    func test_uiPayload_eventBased_parsesPromptSuggestions() {
        let raw: [String: Any] = ["event": "ui_payload", "promptSuggestions": ["a", "b"], "sources": []]
        guard case let .uiPayload(d)? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected uiPayload")
        }
        XCTAssertEqual(d.promptSuggestions, ["a", "b"])
    }

    func test_stateEvents_mapToStateUpdate() {
        for (raw, expected): ([String: Any], String) in [
            (["event": "turn_started"], "turn_started"),
            (["event": "state_update", "state": "listening"], "listening"),
            (["event": "response_metadata"], "response_metadata"),
            (["event": "tts_hint"], "tts_hint")
        ] {
            guard case let .stateUpdate(state)? = DataChannelMessageParser.parse(raw) else {
                return XCTFail("expected stateUpdate for \(raw)")
            }
            XCTAssertEqual(state, expected)
        }
    }

    func test_unknownEvent_returnsNil() {
        XCTAssertNil(DataChannelMessageParser.parse(["event": "not_a_real_event"]))
    }

    // MARK: - Session notice

    func test_sessionNotice_sessionEnded_knownReason() {
        let raw: [String: Any] = ["type": "session_notice", "data": ["kind": "session_ended", "reason": "room_empty_timeout"]]
        guard case let .sessionNotice(.sessionEnded(reason))? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected sessionEnded")
        }
        XCTAssertEqual(reason, .roomEmptyTimeout)
    }

    func test_sessionNotice_sessionEnded_unknownReason_isNil() {
        let raw: [String: Any] = ["type": "session_notice", "data": ["kind": "session_ended", "reason": "brand_new_reason"]]
        guard case let .sessionNotice(.sessionEnded(reason))? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected sessionEnded")
        }
        XCTAssertNil(reason, "an unmodeled reason must not masquerade as a valid EndReason")
    }

    func test_sessionNotice_userSilenceWarning() {
        let raw: [String: Any] = ["type": "session_notice", "data": ["kind": "user_silence_warning", "silenceSeconds": 12]]
        guard case let .sessionNotice(.userSilenceWarning(seconds))? = DataChannelMessageParser.parse(raw) else {
            return XCTFail("expected userSilenceWarning")
        }
        XCTAssertEqual(seconds, 12)
    }

    func test_sessionNotice_unknownKind_returnsNil() {
        let raw: [String: Any] = ["type": "session_notice", "data": ["kind": "something_else"]]
        XCTAssertNil(DataChannelMessageParser.parse(raw))
    }

    // MARK: - Fallbacks

    func test_noTypeOrEvent_returnsNil() {
        XCTAssertNil(DataChannelMessageParser.parse(["foo": "bar"]))
    }

    func test_parseFromData_decodesJSONBytes() {
        let json = #"{"event":"turn_completed","fullText":"done","state":"completed"}"#.data(using: .utf8)!
        guard case let .turnDone(d)? = DataChannelMessageParser.parse(json) else {
            return XCTFail("expected turnDone from Data")
        }
        XCTAssertEqual(d.fullText, "done")
    }

    func test_parseFromData_nonJSON_returnsNil() {
        XCTAssertNil(DataChannelMessageParser.parse(Data([0x00, 0x01, 0x02])))
    }
}
