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

/// Button style for the chat composer send button.
struct ComposerSendButtonStyle: SwiftUI.ButtonStyle {
    let theme: ConciergeTheme
    let isEnabled: Bool
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isActive = configuration.isPressed || isHovered
        let foregroundColor: Color = {
            if !isEnabled {
                return theme.colors.button.submitText.color.opacity(0.5)
            }
            return isActive ? theme.colors.button.submitTextHover.color : theme.colors.button.submitText.color
        }()

        return configuration.label
            .foregroundColor(foregroundColor)
            .frame(width: theme.layout.inputButtonWidth, height: theme.layout.inputButtonHeight, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: theme.layout.inputButtonBorderRadius, style: .continuous)
                    .fill(isEnabled ? theme.colors.button.submitFill.color : theme.colors.button.submitFillDisabled.color)
            )
            .opacity(isActive ? 0.92 : 1.0)
    }
}


