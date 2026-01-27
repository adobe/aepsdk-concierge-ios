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
@testable import AEPBrandConcierge

@MainActor
final class InputControllerTests: XCTestCase {
    // MARK: - Happy path tests
    func test_sendMessage_resets_text_and_state_to_empty() {
        // Given
        let controller = makeController(withInitialText: "hello world")
        XCTAssertEqual(controller.state, .editing)
        XCTAssertEqual(controller.data.text, "hello world")
        XCTAssertTrue(controller.data.canSend)

        // When
        controller.apply(.sendMessage)

        // Then
        XCTAssertEqual(controller.state, .empty)
        XCTAssertEqual(controller.data.text, "")
        XCTAssertFalse(controller.data.canSend)
    }

    // MARK: - Input text and canSend
    func test_whitespaceInput_disables_canSend_and_sendMessage_is_noop() {
        let controller = InputController()
        controller.apply(.addContent)
        controller.apply(.inputReceived("   \n\t"))
        XCTAssertFalse(controller.data.canSend)
        XCTAssertEqual(controller.state, .editing)

        // sendMessage should be a noop when canSend == false
        controller.apply(.sendMessage)
        XCTAssertEqual(controller.state, .editing)
        XCTAssertEqual(controller.data.text, "   \n\t")
        XCTAssertFalse(controller.data.canSend)
    }

    func test_inputReceived_while_error_transitions_to_editing() {
        let controller = InputController()
        // Put into error state by simulating recording then permission error
        controller.apply(.addContent)
        controller.apply(.inputReceived("hi"))
        controller.apply(.startMic(currentSelectionLocation: 0))
        controller.apply(.permissionError("denied"))
        XCTAssertEqual(controller.state, .error(.permissionDenied))

        // When input arrives, state should move to editing
        controller.apply(.inputReceived("hello"))
        XCTAssertEqual(controller.state, .editing)
        XCTAssertEqual(controller.data.text, "hello")
        XCTAssertTrue(controller.data.canSend)
    }

    // MARK: - Delete and reset behaviors
    func test_deleteContent_transitions_editing_to_empty_and_is_noop_when_already_empty() {
        let controller = makeController(withInitialText: "x")
        XCTAssertEqual(controller.state, .editing)
        controller.apply(.deleteContent)
        XCTAssertEqual(controller.state, .empty)
        XCTAssertEqual(controller.data.text, "")
        XCTAssertFalse(controller.data.canSend)

        // No-op when already empty
        controller.apply(.deleteContent)
        XCTAssertEqual(controller.state, .empty)
        XCTAssertEqual(controller.data.text, "")
    }

    func test_reset_restores_defaults_from_any_state() {
        let controller = makeController(withInitialText: "abc")
        controller.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(controller.state, .recording)

        controller.apply(.reset)
        XCTAssertEqual(controller.state, .empty)
        XCTAssertEqual(controller.data.text, "")
        XCTAssertFalse(controller.data.canSend)
        XCTAssertEqual(controller.data.recordingInsertStart, 0)
        XCTAssertEqual(controller.data.textAtRecordingStart, "")
    }

    // MARK: - Mic start guards and selection edges
    func test_startMic_allowed_from_error_and_ignored_in_recording_or_transcribing() {
        let controller = makeController(withInitialText: "hello")
        controller.apply(.startMic(currentSelectionLocation: 0))
        controller.apply(.permissionError("denied"))
        XCTAssertEqual(controller.state, .error(.permissionDenied))

        // Allowed from error -> should go to recording
        controller.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(controller.state, .recording)

        // Ignored if already recording
        controller.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(controller.state, .recording)

        // Move to transcribing, then startMic should be ignored
        controller.apply(.recordingComplete)
        XCTAssertEqual(controller.state, .transcribing)
        controller.apply(.startMic(currentSelectionLocation: 2))
        XCTAssertEqual(controller.state, .transcribing)
    }

    func test_startMic_selection_exact_bounds_start_and_end() {
        let controller = makeController(withInitialText: "😀ab")
        // start of string
        controller.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(controller.data.recordingInsertStart, 0)
        controller.apply(.cancelRecording)

        // end of string (NSString length semantics)
        controller.apply(.startMic(currentSelectionLocation: (controller.data.text as NSString).length))
        XCTAssertEqual(controller.data.recordingInsertStart, ("😀ab" as NSString).length)
    }

    // MARK: - Partial streaming constraints and Unicode handling
    func test_streamingPartial_ignored_unless_recording_and_handles_emoji_boundaries() {
        let controller = makeController(withInitialText: "👩🏽‍💻 code")

        // Not recording yet -> ignored
        controller.apply(.streamingPartial(" live"))
        XCTAssertEqual(controller.data.text, "👩🏽‍💻 code")

        // Start recording at prefix 0
        controller.apply(.startMic(currentSelectionLocation: 0))
        controller.apply(.streamingPartial("🔥"))
        XCTAssertTrue(controller.data.text.hasPrefix("🔥"))

        // Update partial at end
        controller.apply(.streamingPartial("🔥 Fire"))
        XCTAssertTrue(controller.data.text.hasPrefix("🔥 Fire"))
        XCTAssertTrue(controller.data.canSend)
    }

    // MARK: - Recording lifecycle correctness
    func test_recordingComplete_and_transcription_handlers_guards_and_empty_final_text() {
        let controller = makeController(withInitialText: "base")

        // recordingComplete ignored unless recording
        controller.apply(.recordingComplete)
        XCTAssertEqual(controller.state, .editing)

        controller.apply(.startMic(currentSelectionLocation: 2))
        controller.apply(.recordingComplete)
        XCTAssertEqual(controller.state, .transcribing)

        // transcriptionComplete with empty final text keeps original base merged correctly
        controller.apply(.transcriptionComplete(""))
        XCTAssertEqual(controller.state, .editing)
        XCTAssertEqual(controller.data.text, "base")

        // transcriptionError ignored unless transcribing
        controller.apply(.transcriptionError("err"))
        XCTAssertEqual(controller.state, .editing)

        // permissionError ignored unless recording
        controller.apply(.permissionError("denied"))
        XCTAssertEqual(controller.state, .editing)
    }

    // MARK: - Cancel behavior and state restoration
    func test_cancelRecording_restores_state_for_empty_or_nonempty_bases() {
        // Non-empty base
        let r1 = makeController(withInitialText: "abc")
        r1.apply(.startMic(currentSelectionLocation: 1))
        r1.apply(.streamingPartial("Z"))
        r1.apply(.cancelRecording)
        XCTAssertEqual(r1.state, .editing)
        XCTAssertEqual(r1.data.text, "abc")

        // Empty base
        let r2 = makeController(withInitialText: "")
        r2.apply(.startMic(currentSelectionLocation: 0))
        r2.apply(.streamingPartial("hi"))
        r2.apply(.cancelRecording)
        XCTAssertEqual(r2.state, .empty)
        XCTAssertEqual(r2.data.text, "")
    }
    func test_streamingPartial_inserts_at_selection_middle_accumulates() {
        // Given
        let controller = makeController(withInitialText: "hello world")
        // cursor after the space (index 6)
        controller.apply(.startMic(currentSelectionLocation: 6))
        XCTAssertEqual(controller.state, .recording)
        XCTAssertEqual(controller.data.textAtRecordingStart, "hello world")
        XCTAssertEqual(controller.data.recordingInsertStart, 6)

        // When: first partial
        controller.apply(.streamingPartial("foo"))

        // Then: inserted into original base text at index 6
        XCTAssertEqual(controller.data.text, "hello fooworld")

        // When: updated partial grows (accumulates replacement using base + new partial)
        controller.apply(.streamingPartial("foobar"))

        // Then: latest partial is reflected in the composed text
        XCTAssertEqual(controller.data.text, "hello foobarworld")
        XCTAssertTrue(controller.data.canSend)
    }

    func test_transcriptionComplete_merges_and_sets_editing() {
        // Given
        let controller = makeController(withInitialText: "abc xyz")
        controller.apply(.startMic(currentSelectionLocation: 4)) // after "abc "
        XCTAssertEqual(controller.state, .recording)

        // When: complete recording, then provide final transcript
        controller.apply(.recordingComplete)
        XCTAssertEqual(controller.state, .transcribing)
        controller.apply(.transcriptionComplete("DEF"))

        // Then: final text merged at insertion point and state returns to editing
        XCTAssertEqual(controller.data.text, "abc DEFxyz")
        XCTAssertEqual(controller.state, .editing)
        XCTAssertTrue(controller.data.canSend)
    }

    func test_transcriptionError_restores_original_text_and_state() {
        // Given
        let controller = makeController(withInitialText: "abc")
        controller.apply(.startMic(currentSelectionLocation: 1))
        XCTAssertEqual(controller.state, .recording)

        // When: simulate some partial, then error during transcription
        controller.apply(.streamingPartial("Z"))
        controller.apply(.recordingComplete)
        XCTAssertEqual(controller.state, .transcribing)
        controller.apply(.transcriptionError("network"))

        // Then: original text restored and state reflects non-empty editing
        XCTAssertEqual(controller.data.text, "abc")
        XCTAssertEqual(controller.state, .editing)
        XCTAssertTrue(controller.data.canSend)
    }

    func test_startMic_records_insert_index_bounds() {
        // Given
        let controller = makeController(withInitialText: "abc")

        // When: negative selection clamps to 0
        controller.apply(.startMic(currentSelectionLocation: -5))

        // Then
        XCTAssertEqual(controller.state, .recording)
        XCTAssertEqual(controller.data.recordingInsertStart, 0)
        XCTAssertEqual(controller.data.textAtRecordingStart, "abc")

        // Return to editable state
        controller.apply(.cancelRecording)
        XCTAssertEqual(controller.state, .editing)

        // When: overly large selection clamps to end
        controller.apply(.startMic(currentSelectionLocation: 10))

        // Then
        XCTAssertEqual(controller.state, .recording)
        XCTAssertEqual(controller.data.recordingInsertStart, 3) // length of "abc"
        XCTAssertEqual(controller.data.textAtRecordingStart, "abc")
    }

    func test_permissionError_transitions_to_error() {
        // Given
        let controller = makeController(withInitialText: "hello")
        controller.apply(.startMic(currentSelectionLocation: 0))
        XCTAssertEqual(controller.state, .recording)

        // When
        controller.apply(.permissionError("mic denied"))

        // Then
        XCTAssertEqual(controller.state, .error(.permissionDenied))
    }
    
    // MARK: - Helpers
    private func makeController(withInitialText text: String) -> InputController {
        let controller = InputController()
        if !text.isEmpty {
            controller.applyTextChange(text)
        }
        return controller
    }
}


