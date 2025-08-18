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

import AEPCore
import SwiftUI

public extension Concierge {
    /// Shows the Concierge chat UI on top of the supplied SwiftUI view hierarchy.
    ///
    /// - Parameters:
    ///   - containingView: The SwiftUI view to wrap. The overlay is injected above this view.
    ///   - title: Optional title shown in the chat header.
    ///   - subtitle: Optional subtitle shown under the title.
    ///   - speechCapturer: Optional speech capture implementation to use.
    ///   - textSpeaker: Optional text-to-speech implementation to use.
    static func show(
        containingView: (some View),
        title: String? = nil,
        subtitle: String? = nil,
        speechCapturer: SpeechCapturing? = nil,
        textSpeaker: TextSpeaking? = nil
    ) {
        self.containingView = AnyView(containingView)

        if let speechCapturer = speechCapturer {
            self.speechCapturer = speechCapturer
        }

        if let textSpeaker = textSpeaker {
            self.textSpeaker = textSpeaker
        }

        if let title = title {
            self.chatTitle = title
        }

        if let subtitle = subtitle {
            self.chatSubtitle = subtitle
        }

        let showEvent = Event(name: "Show UI",
                              type: Constants.EventType.concierge,
                              source: EventSource.requestContent,
                              data: nil)
        MobileCore.dispatch(event: showEvent)
    }

    /// Shows the chat UI without requiring a specific containing view.
    ///
    /// - Parameters:
    ///   - title: Optional title shown in the chat header.
    ///   - subtitle: Optional subtitle shown under the title.
    ///   - speechCapturer: Optional speech capture implementation to use.
    ///   - textSpeaker: Optional text-to-speech implementation to use.
    static func show(
        title: String? = nil,
        subtitle: String? = nil,
        speechCapturer: SpeechCapturing? = nil,
        textSpeaker: TextSpeaking? = nil
    ) {
        self.show(containingView: EmptyView(),
                  title: title,
                  subtitle: subtitle,
                  speechCapturer: speechCapturer,
                  textSpeaker: textSpeaker)
    }

    /// Wraps the app’s content so the Concierge chat overlay can be presented.
    ///
    /// Place the returned view near the app root to enable overlay presentation
    /// triggered by the `show(...)` APIs.
    ///
    /// - Parameters:
    ///   - content: The app’s SwiftUI content.
    ///   - title: Optional title shown in the chat header for subsequent sessions.
    ///   - subtitle: Optional subtitle shown under the title for subsequent sessions.
    /// - Returns: A view that renders `content` and conditionally overlays the chat UI.
    static func wrap<Content: View>(
        _ content: Content,
        title: String? = nil,
        subtitle: String? = nil
    ) -> some View {
        if let title = title {
            self.chatTitle = title
        }
        if let subtitle = subtitle {
            self.chatSubtitle = subtitle
        }
        return ConciergeWrapper(content: content)
    }

    /// Hides the chat overlay if it is currently presented.
    @MainActor
    static func hide() {
        ConciergeOverlayManager.shared.hideChat()
    }
}
