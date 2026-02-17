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

/// Controller coordinating speech capture and text-to-speech functionality.
final class SpeechController {
    private let capturer: SpeechCapturing?
    private let speaker: TextSpeaking?

    init(capturer: SpeechCapturing?, speaker: TextSpeaking?) {
        self.capturer = capturer
        self.speaker = speaker
    }

    // MARK: - Capture State

    var isCapturerAvailable: Bool {
        capturer != nil
    }

    var isAvailable: Bool {
        capturer?.isAvailable() ?? false
    }

    var hasNeverBeenAskedForPermission: Bool {
        capturer?.hasNeverBeenAskedForPermission() ?? true
    }

    // MARK: - Capture Operations

    func configureForStreaming(responseProcessor: @escaping (String) -> Void) {
        capturer?.initialize(responseProcessor: responseProcessor)
    }

    func requestPermissions(completion: @escaping () -> Void) {
        capturer?.requestSpeechAndMicrophonePermissions(completion: completion)
    }

    func beginCapture() {
        capturer?.beginCapture()
    }

    func endCapture(completion: @escaping (String?, Error?) -> Void) {
        capturer?.endCapture(completion: completion)
    }

    // MARK: - Speech Output

    func speak(_ text: String) {
        speaker?.utter(text: text)
    }
}
