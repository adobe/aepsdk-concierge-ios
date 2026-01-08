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

/// Icon button that supports pressed and pointer hover styling, used for feedback actions.
struct FeedbackIconButton<Label: View>: View {
    let iconButtonSize: CGFloat
    let foregroundColor: Color
    let normalBackgroundColor: Color
    let activeBackgroundColor: Color
    let isDisabled: Bool
    let accessibilityLabel: String?
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPointerHovering: Bool = false

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: iconButtonSize, height: iconButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            FeedbackIconButtonStyle(
                foregroundColor: foregroundColor,
                normalBackgroundColor: normalBackgroundColor,
                activeBackgroundColor: activeBackgroundColor,
                isHovered: isPointerHovering
            )
        )
        .onHover { isHovering in
            isPointerHovering = isHovering
        }
        .accessibilityLabel(accessibilityLabel ?? "Feedback")
        .disabled(isDisabled)
    }
}

private struct FeedbackIconButtonStyle: SwiftUI.ButtonStyle {
    let foregroundColor: Color
    let normalBackgroundColor: Color
    let activeBackgroundColor: Color
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isActive = configuration.isPressed || isHovered
        return configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                Circle()
                    .fill(isActive ? activeBackgroundColor : normalBackgroundColor)
            )
    }
}


