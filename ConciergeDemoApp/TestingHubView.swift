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
import AEPBrandConcierge

/// Consolidates the test-only scenarios (link handling, auth token provider, "Buy now" mock
/// response) behind one segmented picker instead of separate top-level tabs. Keeping the tab bar
/// at 4 items avoids iOS's "More" overflow tab entirely, which had its own bug: switching tabs
/// from a screen nested under "More" doesn't reliably work on iOS 18's `TabView` (confirmed via
/// live device testing — reproduced identically on the untouched "Auth" tab before this change).
struct TestingHubView: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case linkHandling = "Link Handling"
        case authToken = "Auth Token"
        case buyNowMock = "Buy Now Mock"

        var id: String { rawValue }
    }

    @State private var scenario: Scenario = .linkHandling

    @Binding var customLinkHandlingEnabled: Bool
    @Binding var closeChatOnIntercept: Bool
    @Binding var deepLinkURL: URL?
    var handleLink: (URL) -> Bool

    /// Switches to the tab hosting the always-mounted `Concierge.wrap` and shows chat. Used by
    /// Link Handling and Auth Token, neither of which has its own wrapper.
    var onOpenChatViaSwiftUITab: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scenario", selection: $scenario) {
                ForEach(Scenario.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            switch scenario {
            case .linkHandling:
                LinkHandlingTestView(
                    customLinkHandlingEnabled: $customLinkHandlingEnabled,
                    closeChatOnIntercept: $closeChatOnIntercept,
                    deepLinkURL: $deepLinkURL,
                    handleLink: handleLink,
                    onOpenChat: onOpenChatViaSwiftUITab
                )
            case .authToken:
                AuthTokenTestView(onOpenChat: onOpenChatViaSwiftUITab)
            case .buyNowMock:
                buyNowMockScenario
            }
        }
    }

    /// Wrapped in its own `Concierge.wrap` (rather than reusing the SwiftUI tab's) so it can force
    /// the `.productDetail` card style the "Buy now" CTA requires — none of the demo theme JSONs
    /// default to that style except "All Props", so sharing the SwiftUI tab's currently-selected
    /// theme would silently hide the CTA. `carouselStyle: .scroll` sidesteps a separate,
    /// pre-existing bug where the "paged" style's height-equalization doesn't accumulate a true
    /// max across pages (`TabView` only keeps the current +/- 1 page mounted).
    private var buyNowMockScenario: some View {
        Concierge.wrap(
            BuyNowMockView(onOpenChat: {
                Concierge.show(
                    surfaces: ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"],
                    title: "Concierge",
                    subtitle: "Powered by Adobe",
                    handleLink: handleLink
                )
            }),
            hideButton: true,
            handleLink: handleLink
        )
        .conciergeTheme(ConciergeTheme(
            behavior: ConciergeBehaviorConfig(
                multimodalCarousel: ConciergeMultimodalCarouselBehavior(carouselStyle: .scroll),
                productCard: ConciergeProductCardBehavior(cardStyle: .productDetail)
            )
        ))
    }
}
