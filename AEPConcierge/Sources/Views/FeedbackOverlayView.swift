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

public enum FeedbackSentiment {
    case positive
    case negative
}

struct FeedbackOverlayView: View {
    struct FeedbackPayload {
        let sentiment: FeedbackSentiment
        let helpful: Bool
        let clear: Bool
        let friendly: Bool
        let visual: Bool
        let other: Bool
        let notes: String
    }

    let theme: ConciergeTheme
    let sentiment: FeedbackSentiment
    let onCancel: () -> Void
    let onSubmit: (_ payload: FeedbackPayload) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var helpful: Bool = false
    @State private var clear: Bool = false
    @State private var friendly: Bool = false
    @State private var visual: Bool = false
    @State private var other: Bool = false
    @State private var notes: String = ""

    var body: some View {
        ZStack {
            // Opaque-ish material to obscure underlying content
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your feedback is appreciated")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("What went well? Select all that apply.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        CheckboxRow(isOn: $helpful, label: "Helpful and relevant recommendations", accent: theme.primary)
                        CheckboxRow(isOn: $clear, label: "Clear and easy to understand", accent: theme.primary)
                        CheckboxRow(isOn: $friendly, label: "Friendly and conversational tone", accent: theme.primary)
                        CheckboxRow(isOn: $visual, label: "Visually appealing presentation", accent: theme.primary)
                        CheckboxRow(isOn: $other, label: "Other", accent: theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.surfaceLight)
                                )
                                .frame(minHeight: 120)
                            if #available(iOS 16.0, *) {
                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                            } else {
                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                                    .padding(12)
                            }
                        }
                    }
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

                    Button(action: {
                        let payload = FeedbackPayload(
                            sentiment: sentiment,
                            helpful: helpful,
                            clear: clear,
                            friendly: friendly,
                            visual: visual,
                            other: other,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSubmit(payload)
                    }) {
                        Text("Submit")
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
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.surfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor)
            )
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 8)
        }
        .accessibilityElement(children: .contain)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12)
    }
}

#Preview("FeedbackOverlayView") {
    struct FeedbackOverlayPreviewHost: View {
        @State private var show: Bool = true
        var body: some View {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                if show {
                    FeedbackOverlayView(
                        theme: ConciergeTheme(),
                        sentiment: .positive,
                        onCancel: { show = false },
                        onSubmit: { _ in show = false }
                    )
                }
            }
        }
    }
    return FeedbackOverlayPreviewHost()
}
