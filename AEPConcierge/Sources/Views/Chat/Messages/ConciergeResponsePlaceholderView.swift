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

/// A placeholder response bubble shown while the agent is loading a response.
/// Customizable elements:
/// - Placeholder bubble's text (ex: "Thinking...")
/// - Loading dot color (primary). The two lighter shades are derived automatically.
struct ConciergeResponsePlaceholderView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergePlaceholderConfig) private var placeholderConfig

    private var lighterDotColor1: Color {
        placeholderConfig.primaryDotColor.opacity(0.7)
    }

    private var lighterDotColor2: Color {
        placeholderConfig.primaryDotColor.opacity(0.45)
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(placeholderConfig.loadingText)
                .foregroundColor(theme.onAgent)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            LoadingDotsView(dotColors: [placeholderConfig.primaryDotColor, lighterDotColor1, lighterDotColor2])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.agentBubble)
        )
    }
}

/// Three dot loading indicator that animates the opacity of dots in a wave.
private struct LoadingDotsView: View {
    let dotColors: [Color]
    @State private var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotColors[min(index, dotColors.count - 1)])
                    .frame(width: 10, height: 10)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.9)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    VStack(spacing: 20) {
        ConciergeResponsePlaceholderView()
        ConciergeResponsePlaceholderView()
            .conciergePlaceholderConfig(ConciergeResponsePlaceholderConfig(loadingText: "Loading personalized ideas...", primaryDotColor: .purple))
    }
    .padding()
    .conciergeTheme(ConciergeTheme())
}


