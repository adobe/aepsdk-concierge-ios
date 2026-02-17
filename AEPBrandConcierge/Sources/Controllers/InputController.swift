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

import Foundation
import Combine

// MARK: - Input Events

/// Events that can be applied to the input state machine.
@MainActor
enum InputEvent {
    case addContent
    case inputReceived(String)
    case deleteContent
    case startMic(currentSelectionLocation: Int)
    case streamingPartial(String)
    case recordingComplete
    case cancelRecording
    case transcriptionComplete(String)
    case transcriptionError(String)
    case permissionError(String)
    case sendMessage
    case reset
}

// MARK: - Input Data State

/// Current data state of the input field.
@MainActor
struct InputDataState {
    var text: String = ""
    var canSend: Bool = false
    var textAtRecordingStart: String = ""
    var recordingInsertStart: Int = 0
}

// MARK: - Input Controller

/// Controller managing the input field state machine.
/// Handles text input, voice recording states, and message submission.
@MainActor
final class InputController: ObservableObject {
    @Published private(set) var state: InputState = .empty
    @Published private(set) var data: InputDataState = .init()

    /// Applies an event to transition the input state machine.
    func apply(_ event: InputEvent) {
        switch event {
        case .addContent:
            if case .empty = state { state = .editing }

        case .inputReceived(let newText):
            data.text = newText
            data.canSend = !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if case .empty = state { state = .editing }
            if case .error = state { state = .editing }

        case .deleteContent:
            data.text = ""
            data.canSend = false
            if case .editing = state { state = .empty }

        case .startMic(let currentSelectionLocation):
            if state == .empty || state == .editing || {
                if case .error = state { return true } else { return false }
            }() {
                state = .recording
                data.textAtRecordingStart = data.text
                data.recordingInsertStart = max(0, min(currentSelectionLocation, (data.text as NSString).length))
            }

        case .streamingPartial(let partial):
            guard case .recording = state else { return }
            let base = data.textAtRecordingStart as NSString
            let start = max(0, min(data.recordingInsertStart, base.length))
            data.text = base.substring(to: start) + partial + base.substring(from: start)
            data.canSend = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        case .recordingComplete:
            if case .recording = state { state = .transcribing }

        case .cancelRecording:
            if case .recording = state {
                data.text = data.textAtRecordingStart
                data.canSend = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                state = data.text.isEmpty ? .empty : .editing
            }

        case .transcriptionComplete(let finalText):
            if case .transcribing = state {
                let base = data.textAtRecordingStart as NSString
                let start = max(0, min(data.recordingInsertStart, base.length))
                data.text = base.substring(to: start) + finalText + base.substring(from: start)
                data.canSend = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                state = .editing
            }

        case .transcriptionError:
            if case .transcribing = state {
                // Restore original text and return to editing/empty
                data.text = data.textAtRecordingStart
                data.canSend = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                state = data.text.isEmpty ? .empty : .editing
            }

        case .permissionError:
            if case .recording = state { state = .error(.permissionDenied) }

        case .sendMessage:
            if data.canSend {
                data.text = ""
                data.canSend = false
                state = .empty
            }

        case .reset:
            data = .init()
            state = .empty
        }
    }

    /// Applies a text change from the UI, routing to appropriate events.
    func applyTextChange(_ newText: String) {
        let wasEmpty = data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isEmptyNew = newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // User erased all text. Only apply .deleteContent so state becomes and stays .empty.
        if isEmptyNew && !wasEmpty {
            apply(.deleteContent)
        // User starts typing from empty.
        // First .addContent to move to .editing, then .inputReceived(newText) to set text.
        } else if !isEmptyNew && wasEmpty {
            apply(.addContent)
            apply(.inputReceived(newText))
        // User continues typing. Apply .inputReceived(newText) to set text.
        } else if !isEmptyNew {
            apply(.inputReceived(newText))
        }
        // Already empty and still empty: no-op to avoid toggling to editing
    }
}
