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

    /// Minimum height of the single-line input row, shared by the text field and every icon in
    /// this row so they stay aligned. Not theme-configurable — it's a UX/tap-target floor, not a
    /// brand value, matching the other tap targets sized via `theme.layout.inputButtonHeight`.
    static let minimumRowHeight: CGFloat = 40

    /// Bottom padding that centers an `iconHeight`-tall icon within `rowHeight` at the
    /// single-line resting state, while still anchoring it to the bottom (last-line) edge as the
    /// row grows for multi-line text — the same recipe used by every icon in this HStack. Pulled
    /// out as a pure function so the centering math is unit-testable without rendering the view.
    static func iconBottomPadding(rowHeight: CGFloat = minimumRowHeight, iconHeight: CGFloat) -> CGFloat {
        max(0, (rowHeight - iconHeight) / 2)
    }

    private var iconBottomPadding: CGFloat {
        Self.iconBottomPadding(iconHeight: theme.layout.inputButtonHeight)
    }

    private var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Leading icon path (e.g. a brand icon) shown before the text field, from
    /// `theme.behavior.input.showAiChatIcon`. Empty when no asset is configured.
    private var leadingIconPath: String {
        theme.components.inputBar.icon?.icon ?? ""
    }

    /// Fade + horizontal slide transition animation.
    private var buttonTransition: AnyTransition {
        .opacity.combined(with: .move(edge: .trailing))
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if !leadingIconPath.isEmpty {
                // Local asset name or a remote http(s) URL; unresolvable paths render nothing.
                LocalAssetImageView(
                    iconPath: leadingIconPath,
                    width: theme.layout.inputButtonWidth,
                    height: theme.layout.inputButtonHeight,
                    contentMode: .fit,
                    clipToCircle: false
                )
                .accessibilityLabel(theme.text.inputAiChatIconTooltip)
                .padding(.bottom, iconBottomPadding)
            }

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
                maxLines: theme.behavior.input.disableMultiline ? 1 : 10,
                onEditingChanged: onEditingChanged
            )
            .frame(height: max(Self.minimumRowHeight, measuredHeight))
            .animation(.easeInOut(duration: 0.15), value: measuredHeight)

            if hasText, inputState != .recording {
                Button(action: {
                    inputText = ""
                }) {
                    BrandIcon(assetName: "S2_Icon_Close_20_N", systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(Color.black)
                        .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Clear text")
                .transition(buttonTransition)
                .padding(.bottom, iconBottomPadding)
            }

            if case .recording = inputState {
                // Waveform visual indicator
                AudioWaveformView(
                    audioLevel: audioLevel,
                    barColor: theme.colors.primary.primary.color,
                    gradient: theme.colors.input.micWaveformGradient
                )
                .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight)
                .padding(.bottom, iconBottomPadding)

                // Dedicated stop button (icon configurable via theme)
                Button(action: onStopRecording) {
                    Group {
                        if let iconName = theme.behavior.input.stopRecordingIcon,
                           let uiImage = UIImage(named: iconName) {
                            Image(uiImage: uiImage)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "stop.circle.fill")
                        }
                    }
                    .font(.system(size: theme.layout.inputButtonHeight, weight: .semibold))
                    .foregroundStyle(micIconStyle)
                    .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Stop recording")
                .padding(.bottom, iconBottomPadding)
            } else if hasText {
                // Send button appears in the same slot once text is present
                if theme.behavior.input.sendButtonStyle == "arrow" {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: theme.layout.inputButtonHeight, weight: .semibold))
                            .foregroundStyle(sendEnabled
                                             ? sendArrowStyle
                                             : AnyShapeStyle(theme.colors.button.submitFillDisabled.color))
                            .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(theme.text.inputSendAria)
                    .disabled(!sendEnabled)
                    .transition(buttonTransition)
                    .padding(.bottom, iconBottomPadding)
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
                    .transition(buttonTransition)
                    .padding(.bottom, iconBottomPadding)
                }
            } else if showMic {
                // Mic button when idle with no text
                Button(action: onMicTap) {
                    BrandIcon(assetName: "S2_Icon_Microphone_20_N", systemName: "mic.fill")
                        .foregroundStyle(micEnabled
                                         ? micIconStyle
                                         : AnyShapeStyle(Color.secondary.opacity(0.5)))
                        .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(theme.text.inputMicAria)
                .disabled(!micEnabled)
                .transition(buttonTransition)
                .padding(.bottom, iconBottomPadding)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: inputState)
        .animation(.easeInOut(duration: 0.2), value: hasText)
    }
}

private extension ComposerEditingView {
    /// Shared by the idle mic button and the recording/stop button so the two copies can't drift.
    var micIconStyle: AnyShapeStyle {
        conciergeShapeStyle(
            color: theme.colors.input.micIconColor,
            gradient: theme.colors.input.micIconGradient,
            fallback: theme.colors.primary.primary.color
        )
    }

    var sendArrowStyle: AnyShapeStyle {
        conciergeShapeStyle(
            color: theme.colors.input.sendArrowBackgroundColor,
            gradient: theme.colors.input.sendArrowBackgroundGradient,
            fallback: theme.colors.primary.primary.color
        )
    }

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
