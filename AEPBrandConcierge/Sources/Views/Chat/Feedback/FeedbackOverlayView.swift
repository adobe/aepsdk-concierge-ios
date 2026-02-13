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
import AEPServices

struct FeedbackOverlayView: View {

    let sentiment: FeedbackSentiment
    let onCancel: () -> Void
    let onSubmit: (_ payload: FeedbackPayload) -> Void

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12)
    }

    // Allows providing any number of sentiment options
    private var effectiveOptions: [String] {
        switch sentiment {
        case .positive: return theme.arrays.feedbackPositiveOptions
        case .negative: return theme.arrays.feedbackNegativeOptions
        }
    }

    private var notesEnabled: Bool {
        switch sentiment {
        case .positive: return theme.components.feedback.positiveNotesEnabled
        case .negative: return theme.components.feedback.negativeNotesEnabled
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeTheme) private var theme
    @State private var selectedOptions: Set<String> = []
    @State private var notes: String = ""

    var body: some View {
        ZStack {
            // Opaque material to blur content underneath
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(sentiment == .positive ? theme.text.feedbackDialogTitlePositive : theme.text.feedbackDialogTitleNegative)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(sentiment == .positive ? theme.text.feedbackDialogQuestionPositive : theme.text.feedbackDialogQuestionNegative)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(effectiveOptions, id: \.self) { option in
                            CheckboxRow(
                                isOn: Binding(
                                    get: { selectedOptions.contains(option) },
                                    set: { isOn in
                                        if isOn { selectedOptions.insert(option) } else { selectedOptions.remove(option) }
                                    }
                                ),
                                label: option,
                                accent: theme.colors.primary.primary.color
                            )
                        }
                    }

                    if notesEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(theme.text.feedbackDialogNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(theme.colors.surface.light.color)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(borderColor)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .clear, radius: 0)

                                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(theme.text.feedbackDialogNotesPlaceholder)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 20)
                                        .padding(.leading, 18)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .padding(20)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(theme.text.feedbackDialogCancel)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(
                        ConciergeActionButtonStyle(theme: theme, variant: .secondary)
                    )

                    Button(action: {
                        let payload = FeedbackPayload(
                            sentiment: sentiment,
                            selectedOptions: Array(selectedOptions),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        let joined = payload.selectedOptions.joined(separator: ", ")
                        Log.trace(label: ConciergeConstants.LOG_TAG, "Feedback submitted. sentiment=\(sentiment) options=[\(joined)] notes=\(payload.notes)")
                        onSubmit(payload)
                    }) {
                        Text(theme.text.feedbackDialogSubmit)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(
                        ConciergeActionButtonStyle(theme: theme, variant: .primary)
                    )
                }
                .padding(20)
            }
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.colors.surface.light.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor)
            )
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
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
                        sentiment: .positive,
                        onCancel: { show = false },
                        onSubmit: { _ in show = false }
                    )
                    .conciergeTheme(ConciergeTheme())
                }
            }
        }
    }
    return FeedbackOverlayPreviewHost()
}
