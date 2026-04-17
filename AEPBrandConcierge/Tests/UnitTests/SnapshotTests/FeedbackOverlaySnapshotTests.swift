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

@testable import AEPBrandConcierge

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

    // MARK: - Display mode defaults

    func test_feedbackDialogProbe_modalDefault_showsCancelNotClose() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(displayMode: "modal")

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    func test_feedbackDialogProbe_actionDefault_showsCloseNotCancel() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(displayMode: "action")

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    // MARK: - Explicit override flags

    func test_feedbackDialogProbe_modal_withCloseOverride_showsBoth() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(
            displayMode: "modal",
            showCloseButton: true,
            showCancelButton: true
        )

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    func test_feedbackDialogProbe_action_withCancelOverride_showsBoth() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(
            displayMode: "action",
            showCloseButton: true,
            showCancelButton: true
        )

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    func test_feedbackDialogProbe_modal_bothFalse_rendersNeitherAffordance() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(
            displayMode: "modal",
            showCloseButton: false,
            showCancelButton: false
        )

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    // MARK: - Per-button token coverage

    func test_feedbackDialogProbe_exaggeratedFeedbackButtonTokens() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(
            displayMode: "modal",
            showCloseButton: true,
            showCancelButton: true
        )
        probeTheme.colors.surface.light = CodableColor(.yellow)

        probeTheme.colors.feedback.submitButtonFill = CodableColor(.red)
        probeTheme.colors.feedback.submitButtonText = CodableColor(.black)
        probeTheme.colors.feedback.cancelButtonFill = CodableColor(.purple)
        probeTheme.colors.feedback.cancelButtonText = CodableColor(.white)
        probeTheme.colors.feedback.cancelButtonBorderColor = CodableColor(.green)

        probeTheme.layout.feedbackSubmitButtonBorderRadius = 2
        probeTheme.layout.feedbackCancelButtonBorderRadius = 20
        probeTheme.layout.feedbackCancelButtonBorderWidth = 3
        probeTheme.layout.feedbackSubmitButtonFontWeight = .black
        probeTheme.layout.feedbackCancelButtonFontWeight = .thin

        // Additional styling controls mixed in so one probe covers the whole surface.
        probeTheme.colors.feedback.sheetBackground = CodableColor(.orange)
        probeTheme.layout.feedbackCheckboxBorderRadius = 12
        probeTheme.layout.feedbackTitleTextAlign = "center"

        probeTheme.text.feedbackDialogNotesPlaceholder = "Additional notes placeholder"

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    // MARK: - Additional styling controls (each isolated)

    /// Feedback sheet background override. Should paint both the modal card and the notes editor.
    func test_feedbackDialogProbe_customSheetBackground() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.colors.feedback.sheetBackground = CodableColor(.orange)

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    /// Exaggerated checkbox corner radius — verifies wiring through `CheckboxRow`.
    func test_feedbackDialogProbe_exaggeratedCheckboxCornerRadius() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.layout.feedbackCheckboxBorderRadius = 12

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    /// `behavior.feedback.showNotes = false` hides the notes free-text field for both sentiments.
    func test_feedbackDialogProbe_showNotesFalse_hidesNotesField() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.feedback = ConciergeFeedbackBehavior(
            displayMode: "modal",
            showNotes: false
        )

        let view = FeedbackOverlayProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 700))
        )
    }

    /// Centered title alignment via `layout.feedbackTitleTextAlign = "center"`.
    func test_feedbackDialogProbe_centeredTitleAlignment() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.layout.feedbackTitleTextAlign = "center"

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


