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
    private let lock = NSRecursiveLock()
    private var generation = 0
    private let schedule: (@escaping () -> Void) -> Void
    private let speakUtterance: (AVSpeechUtterance) -> Void
    private let stopOutput: () -> Void

    init(
        schedule: @escaping (@escaping () -> Void) -> Void = { work in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        },
        speak: ((AVSpeechUtterance) -> Void)? = nil,
        stop: (() -> Void)? = nil
    ) {
        self.schedule = schedule
        speakUtterance = speak ?? { [synthesizer] in synthesizer.speak($0) }
        stopOutput = stop ?? { [synthesizer] in synthesizer.stopSpeaking(at: .immediate) }
    }

    func utter(text: String) {
        let identityGeneration = ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }
        lock.lock()
        let outputGeneration = generation
        lock.unlock()
        schedule { [weak self] in
            guard let self else { return }
            ConciergeIdentityBoundary.shared.synchronized {
                self.lock.lock()
                defer { self.lock.unlock() }
                guard self.generation == outputGeneration,
                      ConciergeIdentityBoundary.shared.admits(identityGeneration) else { return }
                let utterance = AVSpeechUtterance(string: text)
                utterance.prefersAssistiveTechnologySettings = true
                utterance.voice = self.voice
                utterance.rate = 0.4
                utterance.volume = 100
                self.speakUtterance(utterance)
            }
        }
    }

    func stopSpeaking() {
        lock.lock()
        generation &+= 1
        lock.unlock()
        // Synthesizer access, including stopping, stays on main without a blocking join.
        if Thread.isMainThread {
            stopOutput()
        } else {
            DispatchQueue.main.async { self.stopOutput() }
        }
    }
}
