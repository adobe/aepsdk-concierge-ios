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

final class CitationsSnapshotTests: XCTestCase {
    func test_citationsProbe_defaultTheme() {
        let view = CitationsProbeHost(theme: ConciergeThemeLoader.default())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 220)))
    }
    
    func test_citationsProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()
        
        // Exaggerate citation styling so wiring issues are obvious.
        probeTheme.colors.citation.background = CodableColor(.orange)
        probeTheme.colors.citation.text = CodableColor(.black)
        probeTheme.layout.citationsTextFontWeight = .black
        probeTheme.layout.citationsDesktopButtonFontSize = 20
        
        let view = CitationsProbeHost(theme: probeTheme)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 220)))
    }
}

private struct CitationsProbeHost: View {
    let theme: ConciergeTheme
    
    private let citationToken0 = "§§CIT0§"
    private let citationToken1 = "§§CIT1§"
    
    var body: some View {
        let markdown = "This sentence has a citation\(citationToken0) and another citation\(citationToken1)."
        let markers: [CitationMarker] = [
            CitationMarker(
                token: citationToken0,
                citationNumber: 1,
                source: Source(
                    url: "https://example.com/one",
                    title: "One",
                    startIndex: 0,
                    endIndex: 1,
                    citationNumber: 1
                ),
                endOffset: 0
            ),
            CitationMarker(
                token: citationToken1,
                citationNumber: 2,
                source: Source(
                    url: "https://example.com/two",
                    title: "Two",
                    startIndex: 0,
                    endIndex: 1,
                    citationNumber: 2
                ),
                endOffset: 0
            )
        ]
        
        let citationStyle = CitationStyle(
            backgroundColor: UIColor(theme.colors.citation.background.color),
            textColor: UIColor(theme.colors.citation.text.color),
            font: UIFont.systemFont(
                ofSize: theme.layout.citationsDesktopButtonFontSize,
                weight: theme.layout.citationsTextFontWeight.toUIFontWeight()
            )
        )
        
        return VStack(alignment: .leading, spacing: 12) {
            MarkdownBlockView(
                markdown: markdown,
                textColor: UIColor.black,
                baseFont: UIFont.systemFont(ofSize: 16),
                citationMarkers: markers,
                citationStyle: citationStyle,
                onOpenLink: nil
            )
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 390, height: 220, alignment: .topLeading)
        .background(Color.white)
        .conciergeTheme(theme)
    }
}


