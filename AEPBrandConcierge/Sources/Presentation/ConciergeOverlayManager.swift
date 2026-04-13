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
    @Published private(set) var showingConcierge = false
    /// The currently configured chat view to render as an overlay.
    @Published private(set) var chatView: ChatView?

    private init() {}

    /// Presents the given chat view as the overlay.
    /// - Parameter chatView: A fully configured `ChatView` to overlay.
    func showChat(_ chatView: ChatView) {
        self.chatView = chatView
        self.showingConcierge = true
    }

    /// Hides the overlay without discarding the chat view, so the transcript survives until `show(...)` replaces it or the app exits.
    func hideChat() {
        self.showingConcierge = false
    }
}
