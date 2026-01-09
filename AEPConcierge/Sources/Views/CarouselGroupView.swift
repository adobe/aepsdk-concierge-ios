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

/// Horizontally paged carousel of message cards with a page indicator.
struct CarouselGroupView: View {
    @Environment(\.conciergeTheme) private var theme
    let items: [Message]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, message in
                    message.chatMessageView
                        .tag(index)
                }
            }
            .frame(idealWidth: 150, idealHeight: 200)
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
}
