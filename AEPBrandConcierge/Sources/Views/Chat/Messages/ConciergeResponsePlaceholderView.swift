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
/// Renders as a compact, self-contained bubble that wraps its content.
/// Dot color, size, spacing, bubble shape, padding, and dot alignment are all
/// customizable via CSS theme.
struct ConciergeResponsePlaceholderView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.conciergePlaceholderConfig) private var placeholderConfig

    /// Default horizontal padding applied to each side of the bubble content.
    static let defaultHorizontalPadding: CGFloat = 16

    /// Pass `0` when an agent icon is already providing the leading inset.
    var leadingPadding: CGFloat = defaultHorizontalPadding

    private var dotColor: Color {
        theme.colors.thinking.dotColor?.color ?? placeholderConfig.primaryDotColor
    }

    private var dotSize: CGFloat {
        theme.layout.thinkingDotSize ?? 8
    }

    private var dotSpacing: CGFloat {
        theme.layout.thinkingDotSpacing ?? 8
    }

    private var bubbleBorderRadius: CGFloat {
        theme.layout.thinkingBubbleBorderRadius ?? 8
    }

    private var bubblePaddingHorizontal: CGFloat {
        theme.layout.thinkingBubblePaddingHorizontal ?? 16
    }

    private var bubblePaddingVertical: CGFloat {
        theme.layout.thinkingBubblePaddingVertical ?? 8
    }

    private var dotVerticalAlignment: VerticalAlignment {
        switch theme.layout.thinkingDotVerticalAlignment {
        case .top: return .top
        case .bottom: return .bottom
        default: return .center
        }
    }

    var body: some View {
        HStack(alignment: dotVerticalAlignment, spacing: 8) {
            if !placeholderConfig.loadingText.isEmpty {
                Text(placeholderConfig.loadingText)
                    .foregroundColor(theme.colors.message.conciergeText.color)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LoadingDotsView(dotColor: dotColor, dotSize: dotSize, dotSpacing: dotSpacing)
                .fixedSize()
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, bubblePaddingHorizontal)
        .padding(.vertical, bubblePaddingVertical)
        .background(
            RoundedRectangle(cornerRadius: bubbleBorderRadius, style: .continuous)
                .fill(theme.colors.message.conciergeBackground.color)
        )
    }
}

/// Three dot loading indicator that animates the opacity of each dot in a wave.
private struct LoadingDotsView: View {
    let dotColor: Color
    let dotSize: CGFloat
    let dotSpacing: CGFloat
    @State private var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
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
        ConciergeResponsePlaceholderView()
            .conciergePlaceholderConfig(ConciergeResponsePlaceholderConfig(loadingText: "", primaryDotColor: .accentColor))
    }
    .padding()
    .conciergeTheme(ConciergeTheme())
}
