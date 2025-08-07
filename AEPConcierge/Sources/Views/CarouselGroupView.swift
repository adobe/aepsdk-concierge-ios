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

struct CarouselGroupView: View {
    let items: [Message]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, message in
                    message.chatMessageView
                        .padding(.horizontal)
                        .tag(index)
                }
            }
            .frame(minHeight: 400)
            .frame(minWidth: 350)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            PageIndicator(numberOfPages: items.count, currentIndex: $currentIndex)
                .padding(.bottom, 8)
        }
    }
} 
