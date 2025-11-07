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
    let theme: ConciergeTheme
    let onCancel: () -> Void
    let onOpenSettings: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12)
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
                            .foregroundStyle(theme.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.secondary, lineWidth: 1)
                    )
                    
                    Button(action: onOpenSettings) {
                        Text("Open Settings")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(theme.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.primary)
                    )
                }
                .padding(20)
            }
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.surfaceLight)
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
                            theme: ConciergeTheme(),
                            onCancel: { showDialog = false },
                            onOpenSettings: { showDialog = false }
                        )
                    }
                }
            }
        }
    }
    return PermissionDialogPreviewHost()
}
