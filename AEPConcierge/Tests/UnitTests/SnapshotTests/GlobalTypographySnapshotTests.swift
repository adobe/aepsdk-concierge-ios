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

final class GlobalTypographySnapshotTests: XCTestCase {
    func test_globalTypographyProbe_defaultTheme() {
        let view = GlobalTypographyProbeHost(theme: ConciergeThemeLoader.default())

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 520))
        )
    }

    func test_globalTypographyProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()

        // Exaggerate global typography so wiring issues are obvious.
        probeTheme.typography.fontFamily = "Courier"
        probeTheme.typography.fontSize = 22

        let view = GlobalTypographyProbeHost(theme: probeTheme)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 520))
        )
    }
}

private struct GlobalTypographyProbeHost: View {
    let theme: ConciergeTheme

    private let messages: [Message] = [
        Message(
            template: .basic(isUserMessage: false),
            messageBody: "This is a multiline message intended to show the global font size.\nA second line makes the size difference obvious."
        ),
        Message(
            template: .basic(isUserMessage: true),
            messageBody: "A user reply message."
        )
    ]

    var body: some View {
        ChatView(messages: messages)
            .frame(width: 390, height: 520)
            .conciergeTheme(theme)
    }
}


