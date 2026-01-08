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
    @Environment(\.isEnabled) private var isEnabled
    
    let text: String
    let variant: ConciergeButtonVariant
    let action: () -> Void
    
    @State private var isPointerHovering: Bool = false
    
    init(text: String, variant: ConciergeButtonVariant = .primary, action: @escaping () -> Void) {
        self.text = text
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: theme.layout.buttonHeightSmall)
        }
        .buttonStyle(
            ConciergePressableButtonStyle(
                theme: theme,
                variant: variant,
                isEnabled: isEnabled,
                isHovered: isPointerHovering
            )
        )
        .onHover { isHovering in
            isPointerHovering = isHovering
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ButtonView(text: "Primary Button", variant: .primary) {
            print("Primary button tapped")
        }
        
        ButtonView(text: "Secondary Button", variant: .secondary) {
            print("Secondary button tapped")
        }
    }
    .padding()
    .conciergeTheme(ConciergeTheme())
}
