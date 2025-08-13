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
import AVFoundation
import Speech
import Lottie
import AudioToolbox
import AEPConcierge

struct ContentView: View {
    var body: some View {
        Concierge.wrap(
            VStack(spacing: 0) {
                Button(action: {
                    Concierge.show(
                        title: "Concierge",
                        subtitle: "Powered by Adobe"
                    )
                }) {
                    Text("Open Chat")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 28)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red)
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .conciergeTheme(
                ConciergeTheme(
                    primary: .Brand.red,
                    secondary: .Brand.red,
                    onPrimary: .white,
                    textBody: .primary,
                    surfaceLight: Color(UIColor.secondarySystemBackground),
                    surfaceDark: Color(UIColor.systemBackground)
                )
            )
        )
    }
}

#Preview {
    ContentView()
}
