/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
*/

import Foundation
import SwiftUI
import XCTest

@testable import AEPBrandConcierge

/// Tests visibility defaults and overrides for the feedback close (X) and Cancel buttons.
final class ConciergeFeedbackBehaviorTests: XCTestCase {

    @MainActor
    func test_modalCompactHeight_scrollsToNotes() throws {
        let controller = UIHostingController(
            rootView: FeedbackOverlayView(
                sentiment: .positive,
                onCancel: {},
                onSubmit: { _ in }
            )
            .conciergeTheme(ConciergeThemeLoader.default())
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.layoutIfNeeded()

        let editor = try XCTUnwrap(descendant(of: UITextView.self, in: controller.view))
        let scrollView = try XCTUnwrap(enclosingScrollView(of: editor))
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        XCTAssertGreaterThan(scrollView.bounds.height, 0)
        let viewport = scrollView.convert(scrollView.bounds, to: controller.view)
        XCTAssertGreaterThanOrEqual(viewport.minY, 0)
        XCTAssertLessThanOrEqual(viewport.maxY + 84, controller.view.bounds.maxY)

        scrollView.scrollRectToVisible(editor.convert(editor.bounds, to: scrollView), animated: false)
        XCTAssertGreaterThan(scrollView.contentOffset.y, 0)
        XCTAssertTrue(scrollView.bounds.intersects(editor.convert(editor.bounds, to: scrollView)))
    }

    private func descendant<T: UIView>(of type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { self.descendant(of: type, in: $0) }.first
    }

    private func enclosingScrollView(of view: UIView) -> UIScrollView? {
        guard let parent = view.superview else { return nil }
        return (parent as? UIScrollView) ?? enclosingScrollView(of: parent)
    }

    // MARK: - Default resolution by displayMode

    func test_defaults_modal_closeHiddenCancelShown() {
        let behavior = ConciergeFeedbackBehavior(displayMode: "modal")

        XCTAssertFalse(behavior.resolvedShowCloseButton)
        XCTAssertTrue(behavior.resolvedShowCancelButton)
    }

    func test_defaults_action_closeShownCancelHidden() {
        let behavior = ConciergeFeedbackBehavior(displayMode: "action")

        XCTAssertTrue(behavior.resolvedShowCloseButton)
        XCTAssertFalse(behavior.resolvedShowCancelButton)
    }

    // MARK: - Explicit overrides

    func test_explicitOverrides_modal_closeTrueCancelFalse_honored() {
        let behavior = ConciergeFeedbackBehavior(
            displayMode: "modal",
            showCloseButton: true,
            showCancelButton: false
        )

        XCTAssertTrue(behavior.resolvedShowCloseButton)
        XCTAssertFalse(behavior.resolvedShowCancelButton)
    }

    func test_explicitOverrides_action_closeFalseCancelTrue_honored() {
        let behavior = ConciergeFeedbackBehavior(
            displayMode: "action",
            showCloseButton: false,
            showCancelButton: true
        )

        XCTAssertFalse(behavior.resolvedShowCloseButton)
        XCTAssertTrue(behavior.resolvedShowCancelButton)
    }

    /// Both `false` is respected — neither button is shown. Submit always exits; action mode also allows drag-down.
    func test_explicitOverrides_bothFalse_neitherAffordanceRendersAutomatically() {
        for displayMode in ["modal", "action"] {
            let behavior = ConciergeFeedbackBehavior(
                displayMode: displayMode,
                showCloseButton: false,
                showCancelButton: false
            )

            XCTAssertFalse(behavior.resolvedShowCloseButton,
                           "displayMode=\(displayMode) should honor showCloseButton=false without auto-flipping")
            XCTAssertFalse(behavior.resolvedShowCancelButton,
                           "displayMode=\(displayMode) should honor showCancelButton=false without auto-flipping")
        }
    }

    // MARK: - Codable round-trip

    func test_codable_roundTrip_preservesExplicitOverridesAndNilDefaults() throws {
        let original = ConciergeFeedbackBehavior(
            displayMode: "action",
            showCloseButton: false,
            showCancelButton: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeFeedbackBehavior.self, from: encoded)

        XCTAssertEqual(decoded.displayMode, "action")
        XCTAssertEqual(decoded.showCloseButton, false)
        XCTAssertEqual(decoded.showCancelButton, false)
        XCTAssertFalse(decoded.resolvedShowCloseButton)
        XCTAssertFalse(decoded.resolvedShowCancelButton)
    }

    func test_codable_missingKeys_leaveOverridesNilAndApplyDefaults() throws {
        let json = #"{"displayMode":"action"}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeFeedbackBehavior.self, from: data)

        XCTAssertNil(decoded.showCloseButton)
        XCTAssertNil(decoded.showCancelButton)
        XCTAssertTrue(decoded.resolvedShowCloseButton)
        XCTAssertFalse(decoded.resolvedShowCancelButton)
    }
}
