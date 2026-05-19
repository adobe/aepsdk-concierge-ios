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

import Foundation

/// Owns a `ChatController` independently of the SwiftUI view graph so chat
/// state survives hide/show cycles for both SwiftUI overlay and UIKit hosts.
@MainActor
final class ConciergeChatSession {
    let controller: ChatController
    let configuration: ConciergeConfiguration
    let title: String
    let subtitle: String?

    init(
        configuration: ConciergeConfiguration,
        title: String,
        subtitle: String?,
        speechCapturer: SpeechCapturing?,
        textSpeaker: TextSpeaking?
    ) {
        self.configuration = configuration
        self.title = title
        self.subtitle = subtitle
        self.controller = ChatController(
            configuration: configuration,
            speechCapturer: speechCapturer ?? SpeechCapturer(),
            speaker: textSpeaker
        )
    }

    func matches(configuration: ConciergeConfiguration, title: String, subtitle: String?) -> Bool {
        self.title == title
            && self.subtitle == subtitle
            && self.configuration.hasSameChatServiceIdentity(as: configuration)
    }
}
