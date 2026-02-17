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

import AVFoundation

class TextSpeaker: TextSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Tom")

    func utter(text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.prefersAssistiveTechnologySettings = true
            utterance.voice = self.voice
            utterance.rate = 0.4
            utterance.volume = 100
            self.synthesizer.speak(utterance)
        }
    }
}
