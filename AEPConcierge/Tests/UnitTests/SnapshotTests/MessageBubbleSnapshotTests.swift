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

import SnapshotTesting
import SwiftUI
import XCTest

@testable import AEPConcierge

final class MessageBubbleSnapshotTests: XCTestCase {
    func test_messageBubbleProbe_defaultTheme() {
        let view = MessageBubbleProbeHost(theme: ConciergeThemeLoader.default())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 320)))
    }
    
    func test_messageBubbleProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()
        
        // Exaggerate bubble styling so wiring issues are obvious.
        probeTheme.colors.message.userBackground = CodableColor(.yellow)
        probeTheme.colors.message.userText = CodableColor(.black)
        
        probeTheme.colors.message.conciergeBackground = CodableColor(.purple)
        probeTheme.colors.message.conciergeText = CodableColor(.white)
        
        probeTheme.layout.messagePadding = ConciergePadding(vertical: 24, horizontal: 30)
        probeTheme.layout.messageBorderRadius = 28
        
        // Sibling control for bubbles: cap width so the change is visible and stable.
        probeTheme.layout.messageMaxWidth = 260
        
        let view = MessageBubbleProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 320)))
    }
}

private struct MessageBubbleProbeHost: View {
    let theme: ConciergeTheme
    
    var body: some View {
        VStack(spacing: 16) {
            ChatMessageView(
                template: .basic(isUserMessage: true),
                messageBody: "User message bubble with a bit of text."
            )
            
            ChatMessageView(
                template: .basic(isUserMessage: false),
                messageBody: "Agent message bubble with a bit of text."
            )
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 390, height: 320, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}


