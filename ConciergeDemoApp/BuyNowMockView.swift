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

/// Toggles `BuyNowMockURLProtocol.isEnabled` and opens chat so a real turn (any message) gets
/// intercepted and answered with a canned response carrying product cards with a "Buy now"
/// action — exercising the actual production rendering/tracking pipeline instead of a
/// hand-constructed demo view.
struct BuyNowMockView: View {
    @State private var isMockEnabled = BuyNowMockURLProtocol.isEnabled

    /// Switches to the chat tab and presents the Concierge chat so the tester can send a turn.
    let onOpenChat: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Buy Now CTA — Mock Response")
                .font(.headline)
                .padding(.top, 12)

            Text("""
            When enabled, the chat network request is intercepted locally and answered with a \
            canned response containing product cards that carry a "primary" action \
            (entity_info.primary) — the same payload shape that drives the real "Buy now" CTA. \
            Open chat and send any message to see it render through the actual SDK pipeline.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            Toggle("Mock \"Buy now\" response", isOn: $isMockEnabled)
                .padding(.horizontal)
                .onChange(of: isMockEnabled) { newValue in
                    BuyNowMockURLProtocol.isEnabled = newValue
                }

            Button(action: onOpenChat) {
                Text("Open chat & send a message")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
    }
}
