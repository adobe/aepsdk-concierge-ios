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

import SwiftUI
import XCTest
@testable import AEPBrandConcierge

final class AttachedPromptSuggestionsViewTests: XCTestCase {
    @MainActor
    func testHeaderFollowsTheSuggestionsSetting() {
        func height(showHeader: Bool) -> CGFloat {
            var theme = ConciergeTheme()
            theme.behavior.promptSuggestions = ConciergePromptSuggestionsBehavior(showHeader: showHeader)
            let view = AttachedPromptSuggestionsView(suggestions: ["Continue"])
                .environment(\.conciergeTheme, theme)
            return UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 320, height: 1000)).height
        }
        XCTAssertGreaterThan(height(showHeader: true), height(showHeader: false) + 10)
    }
}
