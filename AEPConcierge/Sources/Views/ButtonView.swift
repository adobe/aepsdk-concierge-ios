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

/// Reusable button component with primary and secondary styling options
struct ButtonView: View {
    @Environment(\.conciergeTheme) private var theme
    
    let text: String
    let style: ButtonStyle
    let action: () -> Void
    
    init(text: String, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.text = text
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return theme.colors.button.primaryText.color
        case .secondary:
            return theme.colors.button.secondaryText.color
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return theme.colors.button.primaryBackground.color
        case .secondary:
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return theme.colors.button.secondaryBorder.color
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary:
            return 0
        case .secondary:
            return 1
        }
    }
}

public enum ButtonStyle {
    case primary
    case secondary
}



#Preview {
    VStack(spacing: 16) {
        ButtonView(text: "Primary Button", style: .primary) {
            print("Primary button tapped")
        }
        
        ButtonView(text: "Secondary Button", style: .secondary) {
            print("Secondary button tapped")
        }
    }
    .padding()
    .conciergeTheme(ConciergeTheme())
}
