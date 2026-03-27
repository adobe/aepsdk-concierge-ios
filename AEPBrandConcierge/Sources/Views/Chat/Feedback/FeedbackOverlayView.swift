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
    /// Vertical offset while dragging the action sheet down (action layout only).
    @State private var actionSheetDragOffset: CGFloat = 0

    /// `behavior.feedback.displayMode`: `"action"` uses action sheet layout; `"modal"` uses centered modal layout.
    private var isActionSheet: Bool {
        theme.behavior.feedback?.displayMode == "action"
    }

    var body: some View {
        if isActionSheet {
            actionSheetLayout
        } else {
            modalLayout
        }
    }

    // MARK: - Modal Layout (centered overlay)

    private var modalLayout: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                feedbackContent
                    .padding(20)
                feedbackActionButtons
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

    // MARK: - Action Sheet Layout

    private var actionSheetLayout: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .gesture(actionSheetDismissDragGesture())

                ScrollView {
                    feedbackContent
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                feedbackActionButtons
                    .padding(20)
            }
            .frame(maxWidth: 560)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
            .background(
                RoundedCornerShape(radius: 20, corners: [.topLeft, .topRight])
                    .fill(theme.colors.surface.light.color)
            )
            .overlay(
                RoundedCornerShape(radius: 20, corners: [.topLeft, .topRight])
                    .stroke(borderColor)
            )
            .offset(y: actionSheetDragOffset)
        }
        .accessibilityElement(children: .contain)
    }

    private func actionSheetDismissDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { dragValue in
                let downwardTranslation = dragValue.translation.height
                actionSheetDragOffset = max(0, downwardTranslation)
            }
            .onEnded { dragValue in
                let distance = dragValue.translation.height
                let dismissDistanceThreshold: CGFloat = 100
                let flingVelocityHint = dragValue.predictedEndTranslation.height - dragValue.translation.height
                let dismissByFling = flingVelocityHint > 120
                if distance > dismissDistanceThreshold || dismissByFling {
                    onCancel()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        actionSheetDragOffset = 0
                    }
                }
            }
    }

    // MARK: - Shared Content

    private var feedbackContent: some View {
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
    }

    private var feedbackActionButtons: some View {
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
