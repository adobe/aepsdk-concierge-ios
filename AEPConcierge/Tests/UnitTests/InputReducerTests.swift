/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
@testable import AEPConcierge

@MainActor
final class InputReducerTests: XCTestCase {
    // MARK: - Happy path tests
    func test_sendMessage_resets_text_and_state_to_empty() {
        // Given
        let reducer = makeReducer(withInitialText: "hello world")
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertEqual(reducer.data.text, "hello world")
        XCTAssertTrue(reducer.data.canSend)

        // When
        reducer.apply(.sendMessage)

        // Then
        XCTAssertEqual(reducer.state, .empty)
        XCTAssertEqual(reducer.data.text, "")
        XCTAssertFalse(reducer.data.canSend)
    }

    // MARK: - Input text and canSend
    func test_whitespaceInput_disables_canSend_and_sendMessage_is_noop() {
        let reducer = InputReducer()
        reducer.apply(.addContent)
        reducer.apply(.inputReceived("   \n\t"))
        XCTAssertFalse(reducer.data.canSend)
        XCTAssertEqual(reducer.state, .editing)

        // sendMessage should be a noop when canSend == false
        reducer.apply(.sendMessage)
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertEqual(reducer.data.text, "   \n\t")
        XCTAssertFalse(reducer.data.canSend)
    }

    func test_inputReceived_while_error_transitions_to_editing() {
        let reducer = InputReducer()
        // Put into error state by simulating recording then permission error
        reducer.apply(.addContent)
        reducer.apply(.inputReceived("hi"))
        reducer.apply(.startMic(currentSelectionLocation: 0))
        reducer.apply(.permissionError("denied"))
        XCTAssertEqual(reducer.state, .error(.permissionDenied))

        // When input arrives, state should move to editing
        reducer.apply(.inputReceived("hello"))
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertEqual(reducer.data.text, "hello")
        XCTAssertTrue(reducer.data.canSend)
    }

    // MARK: - Delete and reset behaviors
    func test_deleteContent_transitions_editing_to_empty_and_is_noop_when_already_empty() {
        let reducer = makeReducer(withInitialText: "x")
        XCTAssertEqual(reducer.state, .editing)
        reducer.apply(.deleteContent)
        XCTAssertEqual(reducer.state, .empty)
        XCTAssertEqual(reducer.data.text, "")
        XCTAssertFalse(reducer.data.canSend)

        // No-op when already empty
        reducer.apply(.deleteContent)
        XCTAssertEqual(reducer.state, .empty)
        XCTAssertEqual(reducer.data.text, "")
    }

    func test_reset_restores_defaults_from_any_state() {
        let reducer = makeReducer(withInitialText: "abc")
        reducer.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(reducer.state, .recording)

        reducer.apply(.reset)
        XCTAssertEqual(reducer.state, .empty)
        XCTAssertEqual(reducer.data.text, "")
        XCTAssertFalse(reducer.data.canSend)
        XCTAssertEqual(reducer.data.recordingInsertStart, 0)
        XCTAssertEqual(reducer.data.textAtRecordingStart, "")
    }

    // MARK: - Mic start guards and selection edges
    func test_startMic_allowed_from_error_and_ignored_in_recording_or_transcribing() {
        let reducer = makeReducer(withInitialText: "hello")
        reducer.apply(.startMic(currentSelectionLocation: 0))
        reducer.apply(.permissionError("denied"))
        XCTAssertEqual(reducer.state, .error(.permissionDenied))

        // Allowed from error -> should go to recording
        reducer.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(reducer.state, .recording)

        // Ignored if already recording
        reducer.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(reducer.state, .recording)

        // Move to transcribing, then startMic should be ignored
        reducer.apply(.recordingComplete)
        XCTAssertEqual(reducer.state, .transcribing)
        reducer.apply(.startMic(currentSelectionLocation: 2))
        XCTAssertEqual(reducer.state, .transcribing)
    }

    func test_startMic_selection_exact_bounds_start_and_end() {
        let reducer = makeReducer(withInitialText: "😀ab")
        // start of string
        reducer.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(reducer.data.recordingInsertStart, 0)
        reducer.apply(.cancelRecording)

        // end of string (NSString length semantics)
        reducer.apply(.startMic(currentSelectionLocation: (reducer.data.text as NSString).length))
        XCTAssertEqual(reducer.data.recordingInsertStart, ("😀ab" as NSString).length)
    }

    // MARK: - Partial streaming constraints and Unicode handling
    func test_streamingPartial_ignored_unless_recording_and_handles_emoji_boundaries() {
        let reducer = makeReducer(withInitialText: "👩🏽‍💻 code")

        // Not recording yet -> ignored
        reducer.apply(.streamingPartial(" live"))
        XCTAssertEqual(reducer.data.text, "👩🏽‍💻 code")

        // Start recording at prefix 0
        reducer.apply(.startMic(currentSelectionLocation: 0))
        reducer.apply(.streamingPartial("🔥"))
        XCTAssertTrue(reducer.data.text.hasPrefix("🔥"))

        // Update partial at end
        reducer.apply(.streamingPartial("🔥 Fire"))
        XCTAssertTrue(reducer.data.text.hasPrefix("🔥 Fire"))
        XCTAssertTrue(reducer.data.canSend)
    }

    // MARK: - Recording lifecycle correctness
    func test_recordingComplete_and_transcription_handlers_guards_and_empty_final_text() {
        let reducer = makeReducer(withInitialText: "base")

        // recordingComplete ignored unless recording
        reducer.apply(.recordingComplete)
        XCTAssertEqual(reducer.state, .editing)

        reducer.apply(.startMic(currentSelectionLocation: 2))
        reducer.apply(.recordingComplete)
        XCTAssertEqual(reducer.state, .transcribing)

        // transcriptionComplete with empty final text keeps original base merged correctly
        reducer.apply(.transcriptionComplete(""))
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertEqual(reducer.data.text, "base")

        // transcriptionError ignored unless transcribing
        reducer.apply(.transcriptionError("err"))
        XCTAssertEqual(reducer.state, .editing)

        // permissionError ignored unless recording
        reducer.apply(.permissionError("denied"))
        XCTAssertEqual(reducer.state, .editing)
    }

    // MARK: - Cancel behavior and state restoration
    func test_cancelRecording_restores_state_for_empty_or_nonempty_bases() {
        // Non-empty base
        let r1 = makeReducer(withInitialText: "abc")
        r1.apply(.startMic(currentSelectionLocation: 1))
        r1.apply(.streamingPartial("Z"))
        r1.apply(.cancelRecording)
        XCTAssertEqual(r1.state, .editing)
        XCTAssertEqual(r1.data.text, "abc")

        // Empty base
        let r2 = makeReducer(withInitialText: "")
        r2.apply(.startMic(currentSelectionLocation: 0))
        r2.apply(.streamingPartial("hi"))
        r2.apply(.cancelRecording)
        XCTAssertEqual(r2.state, .empty)
        XCTAssertEqual(r2.data.text, "")
    }
    func test_streamingPartial_inserts_at_selection_middle_accumulates() {
        // Given
        let reducer = makeReducer(withInitialText: "hello world")
        // cursor after the space (index 6)
        reducer.apply(.startMic(currentSelectionLocation: 6))
        XCTAssertEqual(reducer.state, .recording)
        XCTAssertEqual(reducer.data.textAtRecordingStart, "hello world")
        XCTAssertEqual(reducer.data.recordingInsertStart, 6)

        // When: first partial
        reducer.apply(.streamingPartial("foo"))

        // Then: inserted into original base text at index 6
        XCTAssertEqual(reducer.data.text, "hello fooworld")

        // When: updated partial grows (accumulates replacement using base + new partial)
        reducer.apply(.streamingPartial("foobar"))

        // Then: latest partial is reflected in the composed text
        XCTAssertEqual(reducer.data.text, "hello foobarworld")
        XCTAssertTrue(reducer.data.canSend)
    }

    func test_transcriptionComplete_merges_and_sets_editing() {
        // Given
        let reducer = makeReducer(withInitialText: "abc xyz")
        reducer.apply(.startMic(currentSelectionLocation: 4)) // after "abc "
        XCTAssertEqual(reducer.state, .recording)

        // When: complete recording, then provide final transcript
        reducer.apply(.recordingComplete)
        XCTAssertEqual(reducer.state, .transcribing)
        reducer.apply(.transcriptionComplete("DEF"))

        // Then: final text merged at insertion point and state returns to editing
        XCTAssertEqual(reducer.data.text, "abc DEFxyz")
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertTrue(reducer.data.canSend)
    }

    func test_transcriptionError_restores_original_text_and_state() {
        // Given
        let reducer = makeReducer(withInitialText: "abc")
        reducer.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(reducer.state, .recording)

        // When: simulate some partial, then error during transcription
        reducer.apply(.streamingPartial("Z"))
        reducer.apply(.recordingComplete)
        XCTAssertEqual(reducer.state, .transcribing)
        reducer.apply(.transcriptionError("network"))

        // Then: original text restored and state reflects non-empty editing
        XCTAssertEqual(reducer.data.text, "abc")
        XCTAssertEqual(reducer.state, .editing)
        XCTAssertTrue(reducer.data.canSend)
    }

    func test_startMic_records_insert_index_bounds() {
        // Given
        let reducer = makeReducer(withInitialText: "abc")

        // When: negative selection clamps to 0
        reducer.apply(.startMic(currentSelectionLocation: -5))

        // Then
        XCTAssertEqual(reducer.state, .recording)
        XCTAssertEqual(reducer.data.recordingInsertStart, 0)
        XCTAssertEqual(reducer.data.textAtRecordingStart, "abc")

        // Return to editable state
        reducer.apply(.cancelRecording)
        XCTAssertEqual(reducer.state, .editing)

        // When: overly large selection clamps to end
        reducer.apply(.startMic(currentSelectionLocation: 10))

        // Then
        XCTAssertEqual(reducer.state, .recording)
        XCTAssertEqual(reducer.data.recordingInsertStart, 3) // length of "abc"
        XCTAssertEqual(reducer.data.textAtRecordingStart, "abc")
    }

    func test_permissionError_transitions_to_error() {
        // Given
        let reducer = makeReducer(withInitialText: "hello")
        reducer.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(reducer.state, .recording)

        // When
        reducer.apply(.permissionError("mic denied"))

        // Then
        XCTAssertEqual(reducer.state, .error(.permissionDenied))
    }
    
    // MARK: - Helpers
    private func makeReducer(withInitialText text: String) -> InputReducer {
        let reducer = InputReducer()
        if !text.isEmpty {
            reducer.apply(.addContent)
            reducer.apply(.inputReceived(text))
        }
        return reducer
    }
}


