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

    /// Notes field visibility. Never rendered in the action sheet layout; in modal mode falls back
    /// to the pre-existing per-sentiment `components.feedback.*NotesEnabled` flags.
    private var notesEnabled: Bool {
        guard !isActionSheet else { return false }
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

    /// Shows the close (X) button. Explicit `behavior.feedback.showCloseButton` takes precedence;
    /// defaults to `true` for `"action"` mode, `false` for `"modal"`.
    private var resolvedShowCloseButton: Bool {
        theme.behavior.feedback?.resolvedShowCloseButton ?? false
    }

    /// Shows the Cancel button. Explicit `behavior.feedback.showCancelButton` takes precedence;
    /// defaults to `true` for `"modal"` mode, `false` for `"action"`.
    private var resolvedShowCancelButton: Bool {
        theme.behavior.feedback?.resolvedShowCancelButton ?? true
    }

    /// X close icon tint; resolved from `cancelButtonFill` with `button.secondaryText` fallback.
    private var closeIconTint: Color {
        theme.colors.feedback.cancelButtonFill?.color ?? theme.colors.button.secondaryText.color
    }

    /// Sheet/modal background color; also applied to the notes editor fill. Defaults to `surface.light`.
    private var sheetBackgroundColor: Color {
        theme.colors.feedback.sheetBackground?.color ?? theme.colors.surface.light.color
    }

    /// Feedback title text color; when nil, the view falls back to the system `.primary` style.
    private var titleTextColor: Color? {
        theme.colors.feedback.titleText?.color
    }

    /// Feedback question text color; when nil, the view falls back to the system `.secondary` style.
    private var questionTextColor: Color? {
        theme.colors.feedback.questionText?.color
    }

    /// Feedback checkbox option label color; when nil, the row falls back to the system `.primary` style.
    private var optionsTextColor: Color? {
        theme.colors.feedback.optionsText?.color
    }

    /// Feedback checkbox outline border color; when nil, the row uses its `colorScheme`-adaptive default.
    private var checkboxBorderColor: Color? {
        theme.colors.feedback.checkboxBorder?.color
    }

    /// Action sheet drag handle color; when nil, the view falls back to `Color.secondary.opacity(0.4)`.
    private var dragHandleColor: Color {
        theme.colors.feedback.dragHandle?.color ?? Color.secondary.opacity(0.4)
    }

    /// Title alignment from `feedbackTitleTextAlign`: `.center` when set to `"center"`, otherwise `.leading`.
    private var titleTextAlignment: TextAlignment {
        theme.layout.feedbackTitleTextAlign?.lowercased() == "center" ? .center : .leading
    }

    private var titleFrameAlignment: Alignment {
        titleTextAlignment == .center ? .center : .leading
    }

    /// Title font. Falls back to `.title2.weight(.semibold)` when `feedbackTitleFontSize` is nil.
    private var titleFont: Font {
        if let size = theme.layout.feedbackTitleFontSize {
            return .system(size: size, weight: .semibold)
        }
        return .title2.weight(.semibold)
    }

    var body: some View {
        Group {
            if isActionSheet {
                actionSheetLayout
            } else {
                modalLayout
            }
        }
        .onAppear(perform: logResolvedFeedbackColors)
    }

    /// Logs all resolved feedback colors at `.debug` level on appear. Useful for diagnosing legibility when `sheetBackground` is pinned.
    private func logResolvedFeedbackColors() {
        let sheetHex = sheetBackgroundColor.toHexString()
        let titleHex = titleTextColor?.toHexString() ?? "system(.primary)"
        let questionHex = questionTextColor?.toHexString() ?? "system(.secondary)"
        let optionsHex = optionsTextColor?.toHexString() ?? "system(.primary)"
        let checkboxBorderHex = checkboxBorderColor?.toHexString() ?? "system(adaptive)"
        let dragHandleHex = dragHandleColor.toHexString()
        let borderHex = borderColor.toHexString()
        let closeTintHex = closeIconTint.toHexString()
        Log.debug(
            label: ConciergeConstants.LOG_TAG,
            "Feedback colors resolved — colorScheme=\(colorScheme) displayMode=\(isActionSheet ? "action" : "modal") sheetBackground=\(sheetHex) titleText=\(titleHex) questionText=\(questionHex) optionsText=\(optionsHex) checkboxBorder=\(checkboxBorderHex) dragHandle=\(dragHandleHex) border=\(borderHex) closeIconTint=\(closeTintHex)"
        )
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
                    .fill(sheetBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor)
            )
            .overlay(alignment: .topTrailing) {
                if resolvedShowCloseButton {
                    closeButton
                }
            }
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
                        .fill(dragHandleColor)
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
                    .fill(sheetBackgroundColor)
            )
            .overlay(
                RoundedCornerShape(radius: 20, corners: [.topLeft, .topRight])
                    .stroke(borderColor)
            )
            .overlay(alignment: .topTrailing) {
                if resolvedShowCloseButton {
                    closeButton
                }
            }
            .offset(y: actionSheetDragOffset)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Close (X) Button

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(closeIconTint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.text.feedbackDialogCancel)
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
            Group {
                if let titleTextColor {
                    Text(sentiment == .positive ? theme.text.feedbackDialogTitlePositive : theme.text.feedbackDialogTitleNegative)
                        .foregroundStyle(titleTextColor)
                } else {
                    Text(sentiment == .positive ? theme.text.feedbackDialogTitlePositive : theme.text.feedbackDialogTitleNegative)
                        .foregroundStyle(.primary)
                }
            }
            .font(titleFont)
            .multilineTextAlignment(titleTextAlignment)
            .frame(maxWidth: .infinity, alignment: titleFrameAlignment)

            Group {
                if let questionTextColor {
                    Text(sentiment == .positive ? theme.text.feedbackDialogQuestionPositive : theme.text.feedbackDialogQuestionNegative)
                        .foregroundStyle(questionTextColor)
                } else {
                    Text(sentiment == .positive ? theme.text.feedbackDialogQuestionPositive : theme.text.feedbackDialogQuestionNegative)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body)

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
                        accent: theme.colors.primary.primary.color,
                        cornerRadius: theme.layout.feedbackCheckboxBorderRadius,
                        labelColor: optionsTextColor,
                        borderColor: checkboxBorderColor
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
                                    .fill(sheetBackgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(checkboxBorderColor ?? borderColor)
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
            if resolvedShowCancelButton {
                Button(action: onCancel) {
                    Text(theme.text.feedbackDialogCancel)
                        .font(.body.weight(theme.layout.feedbackCancelButtonFontWeight.toSwiftUIFontWeight()))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(cancelButtonStyle)
            }

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
                    .font(.body.weight(theme.layout.feedbackSubmitButtonFontWeight.toSwiftUIFontWeight()))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(submitButtonStyle)
        }
    }

    // MARK: - Resolved Button Styles

    /// Submit button style; `feedback.submitButton*` tokens with `button.primary*` fallbacks.
    private var submitButtonStyle: FeedbackButtonStyle {
        FeedbackButtonStyle(
            backgroundColor: theme.colors.feedback.submitButtonFill?.color ?? theme.colors.button.primaryBackground.color,
            foregroundColor: theme.colors.feedback.submitButtonText?.color ?? theme.colors.button.primaryText.color,
            borderColor: .clear,
            borderWidth: 0,
            cornerRadius: theme.layout.feedbackSubmitButtonBorderRadius
        )
    }

    /// Cancel button style, resolved from `feedback.cancelButton*` tokens with `button.secondary*` fallbacks.
    /// - Fill: transparent by default (outline style); set `cancelButtonFill` for a solid background.
    /// - Border: always applied; set `feedbackCancelButtonBorderWidth` to `0` to suppress it.
    private var cancelButtonStyle: FeedbackButtonStyle {
        let foreground = theme.colors.feedback.cancelButtonText?.color ?? theme.colors.button.secondaryText.color
        let background = theme.colors.feedback.cancelButtonFill?.color ?? .clear
        let border = theme.colors.feedback.cancelButtonBorderColor?.color ?? theme.colors.button.secondaryBorder.color
        return FeedbackButtonStyle(
            backgroundColor: background,
            foregroundColor: foreground,
            borderColor: border,
            borderWidth: theme.layout.feedbackCancelButtonBorderWidth,
            cornerRadius: theme.layout.feedbackCancelButtonBorderRadius
        )
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
