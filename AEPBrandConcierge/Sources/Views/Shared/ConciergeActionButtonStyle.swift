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

/// Shared primary and secondary button styling for dialog style surfaces (ex: permission, feedback overlay).
struct ConciergeActionButtonStyle: SwiftUI.ButtonStyle {
    let theme: ConciergeTheme
    let variant: ConciergeButtonVariant
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        let foregroundColor: Color
        let backgroundColor: Color
        let borderColor: Color
        let borderWidth: CGFloat

        switch variant {
        case .primary:
            foregroundColor = theme.colors.button.primaryText.color
            backgroundColor = theme.colors.button.primaryBackground.color
            borderColor = .clear
            borderWidth = 0
        case .secondary:
            foregroundColor = theme.colors.button.secondaryText.color
            backgroundColor = .clear
            borderColor = theme.colors.button.secondaryBorder.color
            borderWidth = 1
        }

        return configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(isPressed ? 0.96 : 1.0)
    }
}
