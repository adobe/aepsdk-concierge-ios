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
import UIKit

public extension Concierge {
    // MARK: - SwiftUI presentation APIs

    /// Shows the Concierge chat UI on top of the wrapped SwiftUI view hierarchy.
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

        // Construct and present the chat view immediately via the SwiftUI overlay.
        let view = ChatView(
            speechCapturer: self.speechCapturer,
            textSpeaker: self.textSpeaker,
            title: self.chatTitle,
            subtitle: self.chatSubtitle,
            onClose: { Concierge.hide() }
        )
        Task { @MainActor in
            ConciergeOverlayManager.shared.showChat(view)
        }
        // Dispatch event to notify extension that UI is presented
        let showEvent = Event(name: "Showing Chat UI",
                              type: Constants.EventType.concierge,
                              source: EventSource.requestContent,
                              data: nil)
        MobileCore.dispatch(event: showEvent)
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
    static func hide() {
        Task { @MainActor in
            // Hide SwiftUI overlay if present
            ConciergeOverlayManager.shared.hideChat()

            // Remove UIKit hosted controller if present
            if let controller = Concierge.presentedUIKitController {
                controller.willMove(toParent: nil)
                controller.view.removeFromSuperview()
                controller.removeFromParent()
                Concierge.presentedUIKitController = nil
            }
        }
    }

    // MARK: - UIKit presentation API

    /// Presents the chat UI from a UIKit context by embedding a SwiftUI `ChatView`
    /// inside a `UIHostingController` and adding it as a child of the provided
    /// view controller.
    /// - Parameters:
    ///   - presentingViewController: The view controller that will host the chat UI.
    ///   - title: Optional title displayed in the chat header.
    ///   - subtitle: Optional subtitle displayed under the title.
    static func present(on presentingViewController: UIViewController, title: String? = nil, subtitle: String? = nil) {
        if let title = title { self.chatTitle = title }
        if let subtitle = subtitle { self.chatSubtitle = subtitle }

        let hosting = ConciergeHostingController(title: title, subtitle: subtitle)
        presentedUIKitController = hosting

        Task { @MainActor in
            presentingViewController.addChild(hosting)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            presentingViewController.view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: presentingViewController.view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: presentingViewController.view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: presentingViewController.view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: presentingViewController.view.bottomAnchor)
            ])
            hosting.didMove(toParent: presentingViewController)
        }
    }
}
