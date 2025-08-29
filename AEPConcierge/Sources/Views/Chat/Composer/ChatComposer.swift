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

/// Input composer container that switches between editing, listening, and transcribing states and wires user actions.
struct ChatComposer: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme

    @Binding var inputText: String
    @Binding var selectedRange: NSRange
    @Binding var measuredHeight: CGFloat
    let inputState: InputState
    let chatState: ChatState
    let composerEditable: Bool
    let micEnabled: Bool
    let sendEnabled: Bool
    let onEditingChanged: (Bool) -> Void
    let onMicTap: () -> Void
    let onCancel: () -> Void
    let onComplete: () -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Stop button outside the input when recording
                if case .recording = inputState {
                    Button(action: onComplete) {
                        BrandIcon(assetName: "S2_Icon_Stop_20_N", systemName: "stop.circle.fill")
                            .foregroundColor(Color.Secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    ComposerEditingView(
                        inputText: $inputText,
                        selectedRange: $selectedRange,
                        measuredHeight: $measuredHeight,
                        isEditable: composerEditable,
                        showMic: !(inputState == .recording),
                        onEditingChanged: onEditingChanged,
                        onMicTap: onMicTap,
                        micEnabled: micEnabled,
                        sendEnabled: sendEnabled,
                        onSend: onSend
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator), lineWidth: (colorScheme == .light ? 1 : 0))
                )
                .cornerRadius(12)
            }

            ComposerDisclaimer()
                .padding(.horizontal, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(theme.surfaceDark)
    }
}


