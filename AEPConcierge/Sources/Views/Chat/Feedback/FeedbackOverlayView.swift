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
    struct FeedbackPayload {
        let sentiment: FeedbackSentiment
        let selectedOptions: [String]
        let notes: String
    }

    let theme: ConciergeTheme
    let sentiment: FeedbackSentiment
    let onCancel: () -> Void
    let onSubmit: (_ payload: FeedbackPayload) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.conciergeFeedbackOptions) private var options
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
                    Text("Your feedback is appreciated")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("What went well? Select all that apply.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            CheckboxRow(
                                isOn: Binding(
                                    get: { selectedOptions.contains(option) },
                                    set: { isOn in
                                        if isOn { selectedOptions.insert(option) } else { selectedOptions.remove(option) }
                                    }
                                ),
                                label: option,
                                accent: theme.primary
                            )
                        }
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
                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                                    .padding(12)
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
                            selectedOptions: Array(selectedOptions),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        let joined = payload.selectedOptions.joined(separator: ", ")
                        Log.trace(label: Constants.LOG_TAG, "Feedback submitted. sentiment=\(sentiment) options=[\(joined)] notes=\(payload.notes)")
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
                    .conciergeFeedbackOptions([
                        "Helpful and relevant recommendations",
                        "Clear and easy to understand",
                        "Friendly and conversational tone",
                        "Visually appealing presentation",
                        "Other"
                    ])
                }
            }
        }
    }
    return FeedbackOverlayPreviewHost()
}
