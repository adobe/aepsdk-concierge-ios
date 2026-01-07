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

final class FeedbackOverlaySnapshotTests: XCTestCase {
    func test_feedbackDialogProbe_defaultTheme() {
        let view = FeedbackOverlayProbeHost(theme: ConciergeThemeLoader.default())
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }
    
    func test_feedbackDialogProbe_exaggeratedTheme_buttonColorsAndSurfaceBackground() {
        var probeTheme = ConciergeThemeLoader.default()
        
        // Exaggerate the feedback dialog button colors and surface background
        // so wiring issues are obvious.
        probeTheme.colors.surface.light = CodableColor(.yellow)
        
        probeTheme.colors.button.primaryBackground = CodableColor(.red)
        probeTheme.colors.button.primaryText = CodableColor(.black)
        
        probeTheme.colors.button.secondaryBorder = CodableColor(.green)
        probeTheme.colors.button.secondaryText = CodableColor(.blue)
        
        // Make the placeholder copy visible and stable in the snapshot.
        probeTheme.text.feedbackDialogNotesPlaceholder = "Additional notes placeholder"
        
        let view = FeedbackOverlayProbeHost(theme: probeTheme)
        
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }
}

private struct FeedbackOverlayProbeHost: View {
    let theme: ConciergeTheme
    
    var body: some View {
        FeedbackOverlayView(
            sentiment: .positive,
            onCancel: {},
            onSubmit: { _ in }
        )
        .frame(width: 390, height: 700)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}


