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

import SwiftUI

/// Header bar showing title/subtitle, a User/Agent toggle, and a close button.
struct ChatTopBar: View {
    @Environment(\.conciergeTheme) private var theme

    @Binding var showAgentSend: Bool

    let title: String
    let subtitle: String?

    let onToggleMode: (Bool) -> Void
    let onClose: () -> Void
    
    @State private var showSourcesToggle: Bool = true

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(Color.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(.footnote))
                        .foregroundColor(Color.secondary)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                // User/Agent control with caption
                VStack(alignment: .center, spacing: 4) {
                    Button(action: {
                        showAgentSend.toggle()
                        onToggleMode(showAgentSend)
                    }) {
                        Text(showAgentSend ? "Agent" : "User")
                            .font(.system(.footnote))
                            .padding(8)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(8)
                    }
                    Text("Message will be sent from this perspective")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: onClose) {
                BrandIcon(assetName: "S2_Icon_Close_20_N", systemName: "xmark")
                    .foregroundColor(Color.Secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(theme.surfaceDark)
    }
}


