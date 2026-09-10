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

import XCTest
@testable import AEPBrandConcierge

/// Tests for `ComposerEditingView.iconBottomPadding`, the formula that centers every icon
/// (leading icon, mic, send, clear, stop-recording) within the input row's single-line resting
/// height while still anchoring them to the bottom as the row grows for multi-line text.
final class ComposerEditingViewTests: XCTestCase {

    func test_iconBottomPadding_defaultRowHeight_iconSmallerThanRow_centersIcon() {
        // 40pt row, 32pt icon: (40 - 32) / 2 = 4.
        let padding = ComposerEditingView.iconBottomPadding(iconHeight: 32)
        XCTAssertEqual(padding, 4)
    }

    func test_iconBottomPadding_defaultThemeButtonHeight() {
        // Matches ConciergeThemeLayout's default inputButtonHeight (30).
        let padding = ComposerEditingView.iconBottomPadding(iconHeight: 30)
        XCTAssertEqual(padding, 5)
    }

    func test_iconBottomPadding_iconEqualsRowHeight_returnsZero() {
        let padding = ComposerEditingView.iconBottomPadding(iconHeight: ComposerEditingView.minimumRowHeight)
        XCTAssertEqual(padding, 0)
    }

    func test_iconBottomPadding_iconTallerThanRow_clampsToZero() {
        // A theme-configured icon taller than the row shouldn't produce negative padding.
        let padding = ComposerEditingView.iconBottomPadding(iconHeight: ComposerEditingView.minimumRowHeight + 10)
        XCTAssertEqual(padding, 0)
    }

    func test_iconBottomPadding_customRowHeight() {
        // 60pt row, 32pt icon: (60 - 32) / 2 = 14.
        let padding = ComposerEditingView.iconBottomPadding(rowHeight: 60, iconHeight: 32)
        XCTAssertEqual(padding, 14)
    }
}
