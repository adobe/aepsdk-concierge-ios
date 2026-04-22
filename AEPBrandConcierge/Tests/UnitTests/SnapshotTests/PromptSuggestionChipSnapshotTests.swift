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

import SnapshotTesting
import SwiftUI
import XCTest

@testable import AEPBrandConcierge

final class PromptSuggestionChipSnapshotTests: XCTestCase {
    func test_promptSuggestionChip_defaultTheme() {
        let view = PromptSuggestionChipProbeHost(theme: ConciergeThemeLoader.default())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }

    func test_promptSuggestionChip_customColors() {
        var probeTheme = ConciergeThemeLoader.default()

        // Apply custom suggestion colors to confirm theming wires through.
        probeTheme.colors.promptSuggestion.backgroundColor = CodableColor(.indigo)
        probeTheme.colors.promptSuggestion.textColor = CodableColor(.white)
        probeTheme.layout.suggestionItemBorderRadius = 20

        let view = PromptSuggestionChipProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }

    func test_promptSuggestionChip_containerColorFallback() {
        var probeTheme = ConciergeThemeLoader.default()

        // Leave promptSuggestion.backgroundColor nil; container color should be the fallback.
        probeTheme.colors.primary.container = CodableColor(.mint)

        let view = PromptSuggestionChipProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }

    func test_promptSuggestionChip_multiLine() {
        var probeTheme = ConciergeThemeLoader.default()
        probeTheme.behavior.promptSuggestions = ConciergePromptSuggestionsBehavior(itemMaxLines: 3)

        let view = PromptSuggestionChipProbeHost(
            theme: probeTheme,
            text: "This is a long suggestion that should wrap across multiple lines when itemMaxLines allows it"
        )
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }
}

private struct PromptSuggestionChipProbeHost: View {
    let theme: ConciergeTheme
    var text: String = "Show me some examples"

    var body: some View {
        VStack(spacing: 12) {
            ChatMessageView(
                template: .promptSuggestion(text)
            )

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 390, height: 180, alignment: .top)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}
