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

// Shared instance to manage state between Concierge and wrapper
class ConciergeStateManager: ObservableObject {
    static let shared = ConciergeStateManager()
    
    @Published var showingConcierge = false
    @Published var chatView: ChatView?
    
    private init() {}
    
    func showChat(_ chatView: ChatView) {
        DispatchQueue.main.async {
            self.chatView = chatView
            self.showingConcierge = true
        }
    }
    
    func hideChat() {
        DispatchQueue.main.async {
            self.showingConcierge = false
            self.chatView = nil
        }
    }
}

public extension Concierge {
    
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
        
        if let title = title { self.chatTitle = title }
        if let subtitle = subtitle { self.chatSubtitle = subtitle }
        
        let showEvent = Event(name: "Show UI",
                              type: Constants.EventType.concierge,
                              source: EventSource.requestContent,
                              data: nil)
        MobileCore.dispatch(event: showEvent)
    }
    
    // Convenience: allow programmatic open without a containing view
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
    
    static func wrap<Content: View>(
        _ content: Content,
        title: String? = nil,
        subtitle: String? = nil
    ) -> some View {
        if let title = title { self.chatTitle = title }
        if let subtitle = subtitle { self.chatSubtitle = subtitle }
        return ConciergeWrapper(content: content)
    }
    
    static func hide() {
        ConciergeStateManager.shared.hideChat()
    }
}

struct ConciergeWrapper<Content: View>: View {
    let content: Content
    @StateObject private var stateManager = ConciergeStateManager.shared
    @Environment(\.conciergeTheme) private var theme
    
    init(content: Content) {
        self.content = content
    }
    
    var body: some View {
        ZStack {
            content

            // In-app overlay for chat (safe-area aware by default)
            if stateManager.showingConcierge, let chatView = stateManager.chatView {
                chatView
                    .conciergeTheme(theme)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}
