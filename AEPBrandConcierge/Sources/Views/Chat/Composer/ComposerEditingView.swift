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
import UIKit

/// Text entry row with editable field plus mic and send controls.
struct ComposerEditingView: View {
    @Environment(\.conciergeTheme) private var theme

    @Binding var inputText: String
    @Binding var selectedRange: NSRange
    @Binding var measuredHeight: CGFloat
    @Binding var isFocused: Bool
    let isEditable: Bool
    let showMic: Bool
    let inputState: InputState
    let onEditingChanged: (Bool) -> Void
    let onMicTap: () -> Void
    let onStopRecording: () -> Void
    let micEnabled: Bool
    let sendEnabled: Bool
    let audioLevel: Float
    let onSend: () -> Void

    private var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom) {
            SelectableTextView(
                text: $inputText,
                selectedRange: $selectedRange,
                measuredHeight: $measuredHeight,
                isFocused: $isFocused,
                isEditable: isEditable,
                placeholder: theme.text.inputPlaceholder,
                accessibilityLabel: theme.text.inputMessageInputAria,
                font: resolvedInputFont,
                textColor: UIColor(theme.components.inputBar.textColor.color),
                placeholderTextColor: UIColor(theme.components.inputBar.placeholderColor.color),
                maxLines: theme.behavior.input.disableMultiline ? 1 : 15,
                onEditingChanged: onEditingChanged
            )
            .frame(height: max(40, measuredHeight))
            .animation(.easeInOut(duration: 0.15), value: measuredHeight)

            if hasText {
                Button(action: {
                    inputText = ""
                }) {
                    BrandIcon(assetName: "S2_Icon_CrossCircle_20_N", systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.secondary.opacity(0.6))
                        .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Clear text")
            }

            if case .recording = inputState {
                // Waveform replaces the send/mic slot during recording
                AudioWaveformView(
                    audioLevel: audioLevel,
                    barColor: theme.colors.primary.primary.color
                )
                .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight)
                .accessibilityLabel("Recording audio")
            } else if hasText {
                // Send button appears in the same slot once text is present
                if theme.behavior.input.sendButtonStyle == "arrow" {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: theme.layout.inputButtonHeight, weight: .semibold))
                            .foregroundColor(sendEnabled
                                             ? (theme.colors.input.sendArrowBackgroundColor?.color ?? theme.colors.primary.primary.color)
                                             : theme.colors.button.submitFillDisabled.color)
                            .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(theme.text.inputSendAria)
                    .disabled(!sendEnabled)
                } else {
                    Button(action: onSend) {
                        BrandIcon(assetName: "S2_Icon_Send_20_N", systemName: "paperplane")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(
                        ComposerSendButtonStyle(
                            theme: theme,
                            isEnabled: sendEnabled
                        )
                    )
                    .contentShape(Rectangle())
                    .accessibilityLabel(theme.text.inputSendAria)
                    .disabled(!sendEnabled)
                }
            } else if showMic {
                // Mic button when idle with no text
                Button(action: onMicTap) {
                    BrandIcon(assetName: "S2_Icon_Microphone_20_N", systemName: "mic.fill")
                        .foregroundColor(micEnabled ? (theme.colors.input.micIconColor?.color ?? theme.colors.primary.primary.color) : Color.secondary.opacity(0.5))
                        .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(theme.text.inputMicAria)
                .disabled(!micEnabled)
            }
        }
    }
}

private extension ComposerEditingView {
    var resolvedInputFont: UIFont {
        let fontSize = theme.layout.inputFontSize
        if theme.typography.fontFamily.isEmpty {
            return UIFont.systemFont(ofSize: fontSize, weight: theme.typography.fontWeight.toUIFontWeight())
        }

        // If the font is not available at runtime, fall back to the system font.
        return UIFont(name: theme.typography.fontFamily, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: theme.typography.fontWeight.toUIFontWeight())
    }
}
