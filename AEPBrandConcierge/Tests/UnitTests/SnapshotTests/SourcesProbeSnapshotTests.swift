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

final class SourcesProbeSnapshotTests: XCTestCase {
    func test_sourcesProbe_defaultTheme() {
        let view = SourcesProbeHost(theme: ConciergeThemeLoader.default())

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 220))
        )
    }

    func test_sourcesProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()

        // Exaggerate sources styling so wiring issues are obvious.
        probeTheme.colors.message.conciergeBackground = CodableColor(.purple)
        probeTheme.colors.message.conciergeLink = CodableColor(.green)

        // Sibling control for sources container: match the message bubble radius to ensure it is theme driven.
        probeTheme.layout.messageBorderRadius = 28

        let view = SourcesProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 220))
        )
    }
}

private struct SourcesProbeHost: View {
    let theme: ConciergeTheme

    private let sources: [Source] = [
        Source(
            url: "https://example.com/articles/1",
            title: "A source with a long title that truncates in the middle for stability",
            startIndex: 1,
            endIndex: 2,
            citationNumber: 1
        ),
        Source(
            url: "https://example.com/articles/2",
            title: "Another source link",
            startIndex: 1,
            endIndex: 2,
            citationNumber: 2
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SourcesListView(sources: sources, initiallyExpanded: true)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(width: 390, height: 220)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}


