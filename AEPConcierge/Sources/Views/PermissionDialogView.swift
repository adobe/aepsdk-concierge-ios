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

struct PermissionDialogView: View {
    // Uses the environment theme instead of requiring callers to pass one explicitly.
    let onCancel: () -> Void
    let onOpenSettings: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12)
    }
    
    private var dialogSurfaceBackgroundColor: Color {
        colorScheme == .dark ? theme.colors.surface.dark.color : theme.colors.surface.light.color
    }

    var body: some View {
        VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Microphone and Speech Recognition Required")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("To use speech to text, please enable microphone access and speech recognition in Settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.colors.button.secondaryText.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.colors.button.secondaryBorder.color, lineWidth: 1)
                    )
                    
                    Button(action: onOpenSettings) {
                        Text("Open Settings")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.colors.button.primaryText.color)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.colors.button.primaryBackground.color)
                    )
                }
                .padding(20)
            }
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(dialogSurfaceBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                )
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Permission Dialog")
    }
}

// Compatibility initializer for existing call sites that still pass a theme explicitly.
extension PermissionDialogView {
    init(theme: ConciergeTheme, onCancel: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onOpenSettings = onOpenSettings
    }
}

#Preview("PermissionDialogView") {
    struct PermissionDialogPreviewHost: View {
        @State private var showDialog: Bool = true
        var body: some View {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                if showDialog {
                    ZStack {
                        Color.clear
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture { showDialog = false }
                        
                        PermissionDialogView(
                            onCancel: { showDialog = false },
                            onOpenSettings: { showDialog = false }
                        )
                        .conciergeTheme(ConciergeTheme())
                    }
                }
            }
        }
    }
    return PermissionDialogPreviewHost()
}
