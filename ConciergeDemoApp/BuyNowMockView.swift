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

/// Opens chat with `BuyNowMockURLProtocol` active so a turn gets intercepted and answered with a
/// canned response carrying product cards with a "Buy now" action, exercising the production
/// rendering/tracking pipeline instead of a hand-constructed demo view.
///
/// `ContentView.syncBuyNowMock()` only arms the mock while this scenario is showing.
struct BuyNowMockView: View {
    /// Owned by `ContentView`, which combines it with the selected tab/scenario to decide whether
    /// `BuyNowMockURLProtocol` actually intercepts.
    @Binding var isMockEnabled: Bool

    /// Simulates a sluggish backend. Owned by `ContentView` alongside `isMockEnabled` so the delay
    /// is cleared whenever the mock is disarmed.
    @Binding var isSlowResponseEnabled: Bool
    @Binding var slowResponseDelay: Double

    /// Switches to the chat tab and presents the Concierge chat so the tester can send a turn.
    let onOpenChat: () -> Void

    /// 20s deliberately overshoots the SDK's 15s read timeout so the failure path is reachable
    /// from the UI, not just the "slow but it eventually arrives" path.
    private let delayOptions: [Double] = [5, 10, 20]

    var body: some View {
        VStack(spacing: 12) {
            Text("Buy Now CTA — Mock Response")
                .font(.headline)
                .padding(.top, 12)

            Text("""
            When enabled, chat opened *from this scenario* is intercepted locally and answered \
            from a canned response. Ask "\(BuyNowMockURLProtocol.productCardsPrompt)" to get \
            product cards carrying a "primary" action (entity_info.primary) — the same payload \
            shape that drives the real "Buy now" CTA — rendered through the actual SDK pipeline. \
            Checking out hands the order back to the SDK and returns accessory recommendations; \
            any other message gets a plain text reply. Chat opened from the other tabs always \
            talks to the real Concierge service.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            Toggle("Mock \"Buy now\" response", isOn: $isMockEnabled)
                .padding(.horizontal)

            slowResponseControls

            Button(action: onOpenChat) {
                Text("Open chat & ask for headphones")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
    }

    private var slowResponseControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Slow response", isOn: $isSlowResponseEnabled)
                .disabled(!isMockEnabled)

            if isSlowResponseEnabled {
                Picker("Delay", selection: $slowResponseDelay) {
                    ForEach(delayOptions, id: \.self) { delay in
                        Text("\(Int(delay))s").tag(delay)
                    }
                }
                .pickerStyle(.segmented)

                Text(slowResponseFootnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
    }

    private var slowResponseFootnote: String {
        if slowResponseDelay > 15 {
            return "Past the SDK's 15s read timeout — the turn should fail rather than arrive. "
                + "Applies to typed messages and to the post-checkout data handoff."
        }
        return "Delays the first byte of every intercepted turn, including the post-checkout data "
            + "handoff, so you can see how long the chat stays in its processing state."
    }
}
