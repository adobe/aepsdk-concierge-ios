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

/// Text entry row with editable field plus mic and send controls.
struct ComposerEditingView: View {
    @Binding var inputText: String
    @Binding var selectedRange: NSRange
    @Binding var measuredHeight: CGFloat
    let isEditable: Bool
    let onEditingChanged: (Bool) -> Void
    let onMicTap: () -> Void
    let micEnabled: Bool
    let sendEnabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SelectableTextView(
                text: $inputText,
                selectedRange: $selectedRange,
                measuredHeight: $measuredHeight,
                isEditable: isEditable,
                placeholder: "How can I help",
                onEditingChanged: onEditingChanged
            )
            .frame(height: max(40, measuredHeight))
            .animation(.easeInOut(duration: 0.15), value: measuredHeight)

            Button(action: onMicTap) {
                BrandIcon(assetName: "S2_Icon_Microphone_20_N", systemName: "mic.fill")
                    .foregroundColor(micEnabled ? Color.Secondary : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!micEnabled)

            Button(action: onSend) {
                BrandIcon(assetName: "S2_Icon_Send_20_N", systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(sendEnabled ? Color.Secondary : Color.secondary.opacity(0.5))
            }
            .disabled(!sendEnabled)
        }
    }
}


