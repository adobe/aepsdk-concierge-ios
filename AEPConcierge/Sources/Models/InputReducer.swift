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

@MainActor
struct InputDataState {
    var text: String = ""
    var canSend: Bool = false
    var textAtRecordingStart: String = ""
    var recordingInsertStart: Int = 0
}

@MainActor
final class InputReducer: ObservableObject {
    @Published private(set) var state: InputState = .empty
    @Published private(set) var data: InputDataState = .init()

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

        case .transcriptionError(_):
            if case .transcribing = state {
                // Restore original text and return to editing/empty
                data.text = data.textAtRecordingStart
                data.canSend = !data.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                state = data.text.isEmpty ? .empty : .editing
            }

        case .permissionError(_):
            if case .recording = state { state = .error(.permissionDenied) }

        case .sendMessage:
            if case .editing = state, data.canSend {
                data.text = ""
                data.canSend = false
                state = .empty
            }

        case .reset:
            data = .init()
            state = .empty
        }
    }
}


