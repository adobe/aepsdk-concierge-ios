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

final class ComposerSnapshotTests: XCTestCase {
    func test_composerProbe_defaultTheme() {
        let view = ComposerProbeHost(
            theme: ConciergeThemeLoader.default(),
            isFocused: true
        )
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 140))
        )
    }
    
    func test_composerProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()
        
        // Exaggerate the composer styling so wiring issues are obvious.
        probeTheme.layout.inputBorderRadius = 28
        probeTheme.layout.inputFocusOutlineWidth = 6
        probeTheme.colors.input.outlineFocus = CodableColor(.green)
        probeTheme.components.inputBar.background = CodableColor(.black)
        probeTheme.components.inputBar.border = ConciergeBorderStyle(
            width: 3,
            radius: 0,
            color: CodableColor(.pink)
        )
        
        let view = ComposerProbeHost(
            theme: probeTheme,
            isFocused: true
        )
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 140))
        )
    }
}

private struct ComposerProbeHost: View {
    let theme: ConciergeTheme
    let isFocused: Bool
    
    @State private var inputText: String = "Test message"
    @State private var selectedRange: NSRange = NSRange(location: 12, length: 0)
    @State private var measuredHeight: CGFloat = 40
    @State private var focusedBinding: Bool
    
    init(theme: ConciergeTheme, isFocused: Bool) {
        self.theme = theme
        self.isFocused = isFocused
        _focusedBinding = State(initialValue: isFocused)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ChatComposer(
                inputText: $inputText,
                selectedRange: $selectedRange,
                measuredHeight: $measuredHeight,
                isFocused: $focusedBinding,
                inputState: .editing,
                chatState: .idle,
                composerEditable: true,
                micEnabled: true,
                sendEnabled: true,
                onEditingChanged: { _ in },
                onMicTap: {},
                onCancel: {},
                onComplete: {},
                onSend: {}
            )
        }
        .frame(width: 390, height: 140)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}


