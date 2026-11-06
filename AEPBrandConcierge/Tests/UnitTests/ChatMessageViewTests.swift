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

final class ChatMessageViewTests: XCTestCase {
    @MainActor
    func testAttachedSuggestionsRespectHeaderSettingAndEmptySuggestions() {
        func height(showHeader: Bool, suggestions: [String]) -> CGFloat {
            var theme = ConciergeTheme()
            theme.behavior.promptSuggestions = ConciergePromptSuggestionsBehavior(showHeader: showHeader)
            let view = ChatMessageView(template: .nativeCard(cardId: "card"), promptSuggestions: suggestions)
                .environment(\.conciergeTheme, theme)
            let controller = UIHostingController(rootView: view)
            return controller.sizeThatFits(in: CGSize(width: 320, height: 1000)).height
        }
        let withoutHeader = height(showHeader: false, suggestions: ["Continue"])
        let withHeader = height(showHeader: true, suggestions: ["Continue"])
        XCTAssertGreaterThan(withHeader, withoutHeader + 10)
        XCTAssertEqual(height(showHeader: true, suggestions: []),
                       height(showHeader: false, suggestions: []), accuracy: 0.5)
    }
}
