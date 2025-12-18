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

final class PermissionDialogSnapshotTests: XCTestCase {
    func test_permissionDialogProbe_defaultTheme() {
        let view = PermissionDialogProbeHost(
            theme: ConciergeThemeLoader.default(),
            colorScheme: .light
        )

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 320))
        )
    }

    func test_permissionDialogProbe_exaggeratedTheme() {
        var probeTheme = ConciergeThemeLoader.default()

        // Exaggerate button and surface styling so wiring issues are obvious.
        probeTheme.colors.button.primaryBackground = CodableColor(.red)
        probeTheme.colors.button.primaryText = CodableColor(.black)

        probeTheme.colors.button.secondaryBorder = CodableColor(.green)
        probeTheme.colors.button.secondaryText = CodableColor(.blue)

        probeTheme.colors.surface.light = CodableColor(.yellow)
        probeTheme.colors.surface.dark = CodableColor(.purple)

        // Render in dark mode so the dialog uses the `surface.dark` token.
        let view = PermissionDialogProbeHost(
            theme: probeTheme,
            colorScheme: .dark
        )

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 320))
        )
    }
}

private struct PermissionDialogProbeHost: View {
    let theme: ConciergeTheme
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            PermissionDialogView(
                onCancel: {},
                onOpenSettings: {}
            )
        }
        .frame(width: 390, height: 320)
        .conciergeTheme(theme)
        .environment(\.colorScheme, colorScheme)
    }
}


