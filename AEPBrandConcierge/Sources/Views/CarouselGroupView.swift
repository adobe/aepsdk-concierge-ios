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

/// Horizontally scrollable carousel of message cards.
///
/// Supports two modes controlled by `behavior.multimodalCarousel.carouselStyle`:
/// - paged: `TabView` that snaps to the current item with prev/next buttons and page indicator dots
/// - scroll: continuous horizontal `ScrollView` with freely scrollable cards
///
/// The `ScrollView` always spans the full available width so cards are never clipped during
/// horizontal scrolling. The leading inset is applied inside the scroll content so the first
/// card aligns with the agent icon (or the standard chat history padding when no icon is set).
///
/// `productCardCarouselHorizontalPadding` adds horizontal padding to the scroll content:
/// - Leading: added on top of the column-aligned base (first card cannot move left of the base).
/// - Trailing: used directly, falling back to `chatHistoryPadding` when unset.
struct CarouselGroupView: View {
    @Environment(\.conciergeTheme) private var theme
    let items: [Message]
    @State private var currentIndex = 0

    /// Leading offset applied inside the scroll content so the first card aligns correctly
    /// while the ScrollView itself spans the full width (preventing clipping on scroll).
    ///
    /// Computed as `columnAlignedBase + (productCardCarouselHorizontalPadding ?? 0)`, where the
    /// column-aligned base is:
    /// - With an agent icon: `chatHistoryPadding + agentTextIndent`, aligning with agent text
    ///   and suggestion chips (i.e. the start of the response text column).
    /// - Without an agent icon: `chatHistoryPadding + scrollContentBasePadding`, aligning with
    ///   text bubbles and suggestion chips.
    private var scrollContentLeadingInset: CGFloat {
        let columnAlignedBase: CGFloat
        if theme.hasAgentIcon {
            columnAlignedBase = theme.layout.chatHistoryPadding + theme.layout.agentTextIndent
        } else {
            columnAlignedBase = theme.layout.chatHistoryPadding + MessageListView.scrollContentBasePadding
        }
        return columnAlignedBase + (theme.layout.productCardCarouselHorizontalPadding ?? 0)
    }

    private var carouselIdealHeight: CGFloat {
        switch theme.behavior.productCard?.cardStyle ?? .actionButton {
        case .productDetail:
            return theme.layout.productCardHeight
        case .actionButton:
            return 200
        }
    }

    var body: some View {
        switch theme.behavior.multimodalCarousel.carouselStyle ?? .paged {
        case .paged:
            pagedCarousel
        case .scroll:
            scrollingCarousel
        }
    }

    private var pagedCarousel: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, message in
                    message.chatMessageView
                        .tag(index)
                }
            }
            .frame(idealHeight: carouselIdealHeight)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            HStack(spacing: 16) {
                Button(action: { currentIndex = max(0, currentIndex - 1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)
                .accessibilityLabel(theme.text.carouselPrevAria)

                PageIndicator(numberOfPages: items.count, currentIndex: $currentIndex)

                Button(action: { currentIndex = min(items.count - 1, currentIndex + 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= items.count - 1)
                .accessibilityLabel(theme.text.carouselNextAria)
            }
            .padding(.top, 16)
        }
        .padding(.vertical, 8)
    }

    private var scrollingCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: theme.layout.productCardCarouselSpacing) {
                ForEach(items, id: \.id) { message in
                    message.chatMessageView
                }
            }
            .padding(.leading, scrollContentLeadingInset)
            .padding(.trailing, theme.layout.productCardCarouselHorizontalPadding ?? theme.layout.chatHistoryPadding)
            .padding(.vertical, 12)
        }
    }
}
