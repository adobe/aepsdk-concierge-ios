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

/// Shared button style used by `ButtonView` to support pressed and pointer hover states.
struct ConciergePressableButtonStyle: SwiftUI.ButtonStyle {
    let theme: ConciergeTheme
    let variant: ConciergeButtonVariant
    let isEnabled: Bool
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isActive = (configuration.isPressed || isHovered) && isEnabled

        return configuration.label
            .foregroundColor(foregroundColor(isActive: isActive))
            .background(backgroundColor(isActive: isActive))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor(isActive: isActive), lineWidth: borderWidth)
            )
            .cornerRadius(20)
            // Keep tap feedback for touch, but ensure pointer hover feels responsive.
            .opacity(isEnabled ? 1 : 0.7)
    }

    private func foregroundColor(isActive: Bool) -> Color {
        switch variant {
        case .primary:
            return theme.colors.button.primaryText.color
        case .secondary:
            return isActive ? theme.colors.button.secondaryHoverText.color : theme.colors.button.secondaryText.color
        }
    }

    private func backgroundColor(isActive: Bool) -> Color {
        switch variant {
        case .primary:
            if !isEnabled {
                return theme.colors.button.disabledBackground.color
            }
            return isActive ? theme.colors.button.primaryHover.color : theme.colors.button.primaryBackground.color
        case .secondary:
            return isActive ? theme.colors.button.secondaryHover.color : Color.clear
        }
    }

    private func borderColor(isActive: Bool) -> Color {
        switch variant {
        case .primary:
            return Color.clear
        case .secondary:
            // When active, match the filled state color to avoid a mismatched outline.
            return isActive ? theme.colors.button.secondaryHover.color : theme.colors.button.secondaryBorder.color
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .primary:
            return 0
        case .secondary:
            return 1
        }
    }
}


