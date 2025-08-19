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

/// Container that overlays the Concierge chat UI on top of arbitrary app content when enabled.
struct ConciergeWrapper<Content: View>: View {
    let content: Content
    @StateObject private var stateManager = ConciergeOverlayManager.shared
    @Environment(\.conciergeTheme) private var theme

    init(content: Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content
            // View overlay for chat UI (safe area respecting by default)
            if stateManager.showingConcierge, let chatView = stateManager.chatView {
                chatView
                    .conciergeTheme(theme)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}
