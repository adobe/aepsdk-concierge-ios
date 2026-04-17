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
import XCTest

@testable import AEPBrandConcierge

/// Tests visibility defaults and overrides for the feedback close (X) and Cancel buttons.
final class ConciergeFeedbackBehaviorTests: XCTestCase {

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
        let json = #"{"displayMode":"action","thumbsPlacement":"inline"}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConciergeFeedbackBehavior.self, from: data)

        XCTAssertNil(decoded.showCloseButton)
        XCTAssertNil(decoded.showCancelButton)
        XCTAssertNil(decoded.showNotes)
        XCTAssertTrue(decoded.resolvedShowCloseButton)
        XCTAssertFalse(decoded.resolvedShowCancelButton)
    }

    // MARK: - showNotes resolver

    /// When `showNotes` is nil, fall back to per-sentiment `ConciergeFeedbackStyle` values.
    func test_resolvedShowNotes_nil_fallsBackToPerSentimentFallback() {
        let behavior = ConciergeFeedbackBehavior(showNotes: nil)
        let fallbackBothOn = ConciergeFeedbackStyle(positiveNotesEnabled: true, negativeNotesEnabled: true)
        let fallbackPositiveOnly = ConciergeFeedbackStyle(positiveNotesEnabled: true, negativeNotesEnabled: false)
        let fallbackNegativeOnly = ConciergeFeedbackStyle(positiveNotesEnabled: false, negativeNotesEnabled: true)

        XCTAssertTrue(behavior.resolvedShowNotes(for: .positive, fallback: fallbackBothOn))
        XCTAssertTrue(behavior.resolvedShowNotes(for: .negative, fallback: fallbackBothOn))

        XCTAssertTrue(behavior.resolvedShowNotes(for: .positive, fallback: fallbackPositiveOnly))
        XCTAssertFalse(behavior.resolvedShowNotes(for: .negative, fallback: fallbackPositiveOnly))

        XCTAssertFalse(behavior.resolvedShowNotes(for: .positive, fallback: fallbackNegativeOnly))
        XCTAssertTrue(behavior.resolvedShowNotes(for: .negative, fallback: fallbackNegativeOnly))
    }

    /// When `showNotes` is set, it overrides the per-sentiment fallback for both sentiments.
    func test_resolvedShowNotes_explicitTrue_overridesFallbackForBothSentiments() {
        let behavior = ConciergeFeedbackBehavior(showNotes: true)
        let fallbackBothOff = ConciergeFeedbackStyle(positiveNotesEnabled: false, negativeNotesEnabled: false)

        XCTAssertTrue(behavior.resolvedShowNotes(for: .positive, fallback: fallbackBothOff))
        XCTAssertTrue(behavior.resolvedShowNotes(for: .negative, fallback: fallbackBothOff))
    }

    func test_resolvedShowNotes_explicitFalse_overridesFallbackForBothSentiments() {
        let behavior = ConciergeFeedbackBehavior(showNotes: false)
        let fallbackBothOn = ConciergeFeedbackStyle(positiveNotesEnabled: true, negativeNotesEnabled: true)

        XCTAssertFalse(behavior.resolvedShowNotes(for: .positive, fallback: fallbackBothOn))
        XCTAssertFalse(behavior.resolvedShowNotes(for: .negative, fallback: fallbackBothOn))
    }

    func test_codable_roundTrip_preservesShowNotesOverride() throws {
        let original = ConciergeFeedbackBehavior(displayMode: "modal", showNotes: false)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeFeedbackBehavior.self, from: encoded)

        XCTAssertEqual(decoded.showNotes, false)
        let fallback = ConciergeFeedbackStyle(positiveNotesEnabled: true, negativeNotesEnabled: true)
        XCTAssertFalse(decoded.resolvedShowNotes(for: .positive, fallback: fallback))
        XCTAssertFalse(decoded.resolvedShowNotes(for: .negative, fallback: fallback))
    }
}
