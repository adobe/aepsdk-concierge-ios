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

            let session = resolveSession(configuration: config)
            ConciergeOverlayManager.shared.showChat(makeChatView(session: session))
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

private extension Concierge {

    /// Dispatches a `SHOW_UI` event to retrieve the `ConciergeConfiguration` needed to present the chat.
    ///
    /// The event triggers the extension's `handleShowChatUIRequestEvent`.
    /// If the response is missing, malformed, or times out (ex: configuration or Edge Identity not yet available),
    /// the completion is not called and a warning is logged.
    ///
    /// - Parameters:
    ///   - surfaces: The surface identifiers for this chat experience.
    ///   - completion: Called on the main actor with the resolved configuration. Not called on failure.
    static func fetchChatConfiguration(
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

    /// Returns the current `ConciergeChatSession` if its service identity (ECID, server, datastream, surfaces),
    /// title, and subtitle all match the incoming values, and the server session has not expired;
    /// otherwise creates and stores a new session.
    ///
    /// This is the single decision point for chat reuse across both SwiftUI and UIKit presentation paths.
    /// The `ChatController` inside the returned session retains all messages and the chat
    /// service from prior interactions when a match is found.
    ///
    /// - Parameter configuration: The freshly fetched configuration from the `SHOW_UI` response event.
    /// - Returns: An existing or newly created session.
    @MainActor
    static func resolveSession(configuration: ConciergeConfiguration) -> ConciergeChatSession {
        let resolvedTitle = chatTitle
        let resolvedSubtitle = chatSubtitle

        if let existing = currentSession,
           SessionManager.shared.isSessionActive,
           existing.matches(configuration: configuration, title: resolvedTitle, subtitle: resolvedSubtitle) {
            return existing
        }

        let session = ConciergeChatSession(
            configuration: configuration,
            title: resolvedTitle,
            subtitle: resolvedSubtitle,
            speechCapturer: speechCapturer,
            textSpeaker: textSpeaker
        )
        currentSession = session
        return session
    }

    /// Creates a new `ChatView` bound to the given session's `ChatController`.
    ///
    /// The view is lightweight and stateless; all conversation state lives on the controller.
    ///
    /// - Parameter session: The session whose controller the view will observe.
    /// - Returns: A configured `ChatView` ready for embedding in a SwiftUI overlay or UIKit host.
    @MainActor
    static func makeChatView(session: ConciergeChatSession) -> ChatView {
        ChatView(
            controller: session.controller,
            title: session.title,
            subtitle: session.subtitle,
            onClose: { Concierge.hide() }
        )
    }

    /// Embeds the Concierge chat UI as a child view controller of the given `UIViewController`.
    ///
    /// If a previous UIKit-hosted chat is still attached, it is removed from the hierarchy first.
    /// The method resolves or reuses a session, creates a `ChatView`, wraps it in a
    /// `ConciergeHostingController`, and pins it edge-to-edge within the presenting view controller.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for this chat session.
    ///   - presentingViewController: The UIKit view controller that will host the chat UI as a child.
    @MainActor
    static func attachConciergeUIKitHost(
        configuration: ConciergeConfiguration,
        presentingViewController: UIViewController
    ) {
        if let previousHosting = presentedUIKitController {
            previousHosting.willMove(toParent: nil)
            previousHosting.view.removeFromSuperview()
            previousHosting.removeFromParent()
            presentedUIKitController = nil
        }

        let session = resolveSession(configuration: configuration)
        let view = makeChatView(session: session)

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
