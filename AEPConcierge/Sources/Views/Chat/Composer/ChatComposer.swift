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
    @State private var glowRotation: Double = 0

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
                        ZStack {
                            Circle()
                                .fill(theme.primary)
                                .frame(width: 28, height: 28)
                            // Punch the icon out to create negative space
                            BrandIcon(assetName: "S2_Icon_Stop_20_N", systemName: "stop.fill")
                                .foregroundColor(.black) // color irrelevant for destinationOut
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
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
                .cornerRadius(12)
                .overlay(
                    ZStack {
                        // Base border
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: (colorScheme == .light ? 1 : 0))
                        // Recording glow border
                        if case .recording = inputState {
                            RotatingGlowBorder(color: Color.Secondary, cornerRadius: 12)
                        }
                    }
                )
                
            }

            ComposerDisclaimer()
                .padding(.horizontal, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(theme.surfaceDark)
        .onAppear { startOrStopGlow() }
        .onChange(of: inputState) { _ in startOrStopGlow() }
    }
}

private extension ChatComposer {
    func startOrStopGlow() {
        if case .recording = inputState {
            // Restart animation from zero every time recording starts
            glowRotation = 0
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        } else {
            // Snap to zero and cancel animation by setting a non animating state change
            withAnimation(.none) { glowRotation = 0 }
        }
    }
}

private struct RotatingGlowBorder: View {
    var color: Color
    var cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            /// Controls the speed at which the glowing border moves around the composer edges
            let period: Double = 3.5
            let phase = (t.remainder(dividingBy: period)) / period
            let angle = phase * 360.0
            // Length of the moving highlight arc (degrees around the border)
            // increase to make the spot longer
            let segmentDegrees: Double = 100

            ZStack {
                // Inner ring
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: color.opacity(0.95), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .center,
                            startAngle: .degrees(angle),
                            endAngle: .degrees(angle + segmentDegrees)
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 2)
                    .opacity(0.9)
                // Outer soft halo
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: color, location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .center,
                            startAngle: .degrees(angle),
                            endAngle: .degrees(angle + segmentDegrees)
                        ),
                        lineWidth: 8
                    )
                    .blur(radius: 9)
                    .opacity(0.35)
            }
        }
    }
}


