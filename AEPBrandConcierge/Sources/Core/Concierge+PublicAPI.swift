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

import SwiftUI
import UIKit
import AEPCore
import AEPServices

/// Public API extensions for showing/hiding the Concierge chat UI.
public extension Concierge {
    // MARK: - SwiftUI Presentation APIs

    /// Shows the Concierge chat UI on top of the wrapped SwiftUI view hierarchy.
    ///
    /// - Parameters:
    ///   - surfaces: The surfaces to use for the chat experience.
    ///   - title: Optional title shown in the chat header.
    ///   - subtitle: Optional subtitle shown under the title.
    ///   - speechCapturer: Optional speech capture implementation to use.
    ///   - textSpeaker: Optional text-to-speech implementation to use.
    ///   - handleLink: Optional callback invoked when a link is tapped in the chat.
    ///     Return `true` to claim the link (the SDK takes no action). Return `false` to let the SDK handle it normally.
    static func show(surfaces: [String], title: String? = nil, subtitle: String? = nil, speechCapturer: SpeechCapturing? = nil, textSpeaker: TextSpeaking? = nil, handleLink: ((URL) -> Bool)? = nil) {
        fetchChatConfiguration(forSurfaces: surfaces) { config in
            self.speechCapturer = speechCapturer
            self.textSpeaker = textSpeaker
            self.chatTitle = title ?? ConciergeConstants.Defaults.TITLE
            self.chatSubtitle = subtitle
            self.linkInterceptor = handleLink.map { ConciergeLinkInterceptor(handleLink: $0) } ?? ConciergeLinkInterceptor()

            presentConciergeSwiftUIOverlay(configuration: config)
        }
    }

    /// Wraps the app's content so the Concierge chat overlay can be presented.
    ///
    /// Place the returned view near the app root to enable overlay presentation
    /// triggered by the `show(...)` APIs.
    ///
    /// - Parameters:
    ///   - content: The app's SwiftUI content.
    ///   - surfaces: The surfaces to use for the chat experience when using the floating button.
    ///   - title: Optional title shown in the chat header for subsequent sessions.
    ///   - subtitle: Optional subtitle shown under the title for subsequent sessions.
    ///   - hideButton: Whether to hide the floating button.
    ///   - handleLink: Optional callback invoked when a link is tapped in the chat.
    ///     Return `true` to claim the link (the SDK takes no action). Return `false` to let the SDK handle it normally.
    /// - Returns: A view that renders `content` and conditionally overlays the chat UI.
    static func wrap<Content: View>(
        _ content: Content,
        surfaces: [String] = [],
        title: String? = nil,
        subtitle: String? = nil,
        hideButton: Bool = false,
        handleLink: ((URL) -> Bool)? = nil
    ) -> some View {
        // wrap() is called inside a SwiftUI body and re-evaluates on every state change.
        // Only overwrite values that are explicitly provided to avoid resetting state
        // set by a prior show() call (e.g. the link interceptor for an active chat session).
        if let title = title { self.chatTitle = title }
        if let subtitle = subtitle { self.chatSubtitle = subtitle }
        if !surfaces.isEmpty { self.surfaces = surfaces }
        if let handleLink = handleLink {
            self.linkInterceptor = ConciergeLinkInterceptor(handleLink: handleLink)
        }
        return ConciergeWrapper(content: content, hideButton: hideButton)
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

    // MARK: - UIKit Presentation API

    /// Presents the chat UI from a UIKit context by embedding a SwiftUI `ChatView`
    /// inside a `UIHostingController` and adding it as a child of the provided
    /// view controller.
    /// - Parameters:
    ///   - presentingViewController: The view controller that will host the chat UI.
    ///   - surfaces: The surfaces to use for the chat experience.
    ///   - title: Optional title displayed in the chat header.
    ///   - subtitle: Optional subtitle displayed under the title.
    ///   - speechCapturer: Optional speech capture; when `nil`, any implementation set by a previous `show` / `present` call is kept.
    ///   - textSpeaker: Optional TTS; when `nil`, any implementation set by a previous call is kept.
    ///   - handleLink: Optional callback invoked when a link is tapped in the chat.
    ///     Return `true` to claim the link (the SDK takes no action). Return `false` to let the SDK handle it normally.
    static func present(on presentingViewController: UIViewController, surfaces: [String], title: String? = nil, subtitle: String? = nil, speechCapturer: SpeechCapturing? = nil, textSpeaker: TextSpeaking? = nil, handleLink: ((URL) -> Bool)? = nil) {
        fetchChatConfiguration(forSurfaces: surfaces) { config in
            if let speechCapturer = speechCapturer {
                self.speechCapturer = speechCapturer
            }
            if let textSpeaker = textSpeaker {
                self.textSpeaker = textSpeaker
            }
            self.chatTitle = title ?? ConciergeConstants.Defaults.TITLE
            self.chatSubtitle = subtitle
            self.linkInterceptor = handleLink.map { ConciergeLinkInterceptor(handleLink: $0) } ?? ConciergeLinkInterceptor()

            attachConciergeUIKitHost(configuration: config, presentingViewController: presentingViewController)
        }
    }
}

// MARK: - Shared presentation internals

extension Concierge {
    /// Fetches `ConciergeConfiguration` via the shared `SHOW_UI` event for SwiftUI and UIKit entry points.
    fileprivate static func fetchChatConfiguration(
        forSurfaces surfaces: [String],
        completion: @escaping @MainActor (ConciergeConfiguration) -> Void
    ) {
        let showEvent = Event(name: ConciergeConstants.EventName.SHOW_UI,
                              type: ConciergeConstants.EventType.concierge,
                              source: EventSource.requestContent,
                              data: [ConciergeConstants.EventData.Key.SURFACES: surfaces])

        MobileCore.dispatch(event: showEvent, timeout: ConciergeConstants.DEFAULT_TIMEOUT) { responseEvent in
            guard let responseEvent = responseEvent,
                  let eventData = responseEvent.data,
                  let config = eventData[ConciergeConstants.EventData.Key.CONFIG] as? ConciergeConfiguration else {
                Log.warning(label: ConciergeConstants.LOG_TAG, "Unable to show chat UI - configuration is not available.")
                return
            }
            Task { @MainActor in
                completion(config)
            }
        }
    }

    @MainActor
    fileprivate static func makeChatView(
        configuration: ConciergeConfiguration,
        title: String,
        subtitle: String?
    ) -> ChatView {
        ChatView(
            speechCapturer: speechCapturer,
            textSpeaker: textSpeaker,
            title: title,
            subtitle: subtitle,
            conciergeConfiguration: configuration,
            onClose: { Concierge.hide() }
        )
    }

    @MainActor
    fileprivate static func presentConciergeSwiftUIOverlay(configuration: ConciergeConfiguration) {
        let overlay = ConciergeOverlayManager.shared
        let resolvedTitle = chatTitle
        let resolvedSubtitle = chatSubtitle
        _ = overlay.makeOverlayChatView(
            configuration: configuration,
            title: resolvedTitle,
            subtitle: resolvedSubtitle
        ) {
            makeChatView(configuration: configuration, title: resolvedTitle, subtitle: resolvedSubtitle)
        }
        overlay.showingConcierge = true
    }

    @MainActor
    fileprivate static func attachConciergeUIKitHost(
        configuration: ConciergeConfiguration,
        presentingViewController: UIViewController
    ) {
        if let previousHosting = presentedUIKitController {
            previousHosting.willMove(toParent: nil)
            previousHosting.view.removeFromSuperview()
            previousHosting.removeFromParent()
            presentedUIKitController = nil
        }

        let resolvedTitle = chatTitle
        let resolvedSubtitle = chatSubtitle
        let view = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: resolvedTitle,
            subtitle: resolvedSubtitle,
            storedView: &detachedUIKitChatView,
            storedTitle: &detachedUIKitChatTitle,
            storedSubtitle: &detachedUIKitChatSubtitle
        ) {
            makeChatView(configuration: configuration, title: resolvedTitle, subtitle: resolvedSubtitle)
        }

        let hosting = ConciergeHostingController(chatView: view)
        presentedUIKitController = hosting

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
