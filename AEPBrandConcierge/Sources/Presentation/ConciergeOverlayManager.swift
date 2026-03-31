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

/// View overlay manager used by the SwiftUI implementation.
///
/// This type owns the minimal, observable state required to show/hide the
/// chat UI overlay within SwiftUI. SDK consumers do not interact with it
/// directly; they should call the static `Concierge` public APIs.
@MainActor
final class ConciergeOverlayManager: ObservableObject {
    /// Global instance used by `ConciergeWrapper` and the `Concierge` API.
    static let shared = ConciergeOverlayManager()

    /// Whether the overlay chat UI should be presented.
    @Published var showingConcierge = false
    /// The currently configured chat view to render as an overlay.
    @Published var chatView: ChatView?

    private var lastOverlayTitle: String?
    private var lastOverlaySubtitle: String?

    private init() {}

    /// Returns the cached overlay `ChatView` when the session still matches; otherwise runs `create` and stores the result (same rules as UIKit).
    func makeOverlayChatView(
        configuration: ConciergeConfiguration,
        title: String,
        subtitle: String?,
        create: () -> ChatView
    ) -> ChatView {
        ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: subtitle,
            storedView: &chatView,
            storedTitle: &lastOverlayTitle,
            storedSubtitle: &lastOverlaySubtitle,
            create: create
        )
    }

    /// Hides the overlay without discarding the chat view, so the transcript survives until `show(...)` replaces it or the app exits.
    func hideChat() {
        self.showingConcierge = false
    }
}
