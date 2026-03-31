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
import UIKit

/// UIKit-backed multiline text input that exposes selection and dynamic height to SwiftUI.
struct SelectableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var measuredHeight: CGFloat
    @Binding var isFocused: Bool
    var isEditable: Bool
    var placeholder: String
    var accessibilityLabel: String?
    var font: UIFont?
    var textColor: UIColor?
    var placeholderTextColor: UIColor?
    var minLines: Int = 1
    var maxLines: Int = 4
    var onEditingChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = font ?? UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = textColor ?? .label
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = true
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.accessibilityTraits.insert(.allowsDirectInteraction)
        textView.accessibilityLabel = accessibilityLabel ?? placeholder

        // Placeholder label — positioned to match where text renders
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = placeholderTextColor ?? .secondaryLabel
        placeholderLabel.numberOfLines = 1
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        // Store weak reference for later visibility control
        context.coordinator.placeholderLabel = placeholderLabel
        let placeholderTop = placeholderLabel.topAnchor.constraint(
            equalTo: textView.topAnchor,
            constant: textView.textContainerInset.top
        )
        context.coordinator.placeholderTopConstraint = placeholderTop
        // align hint text and text caret
        let horizontalTextOrigin = textView.textContainerInset.left
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: horizontalTextOrigin),
            placeholderTop
        ])
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        let resolvedAccessibilityLabel = accessibilityLabel ?? placeholder
        if uiView.accessibilityLabel != resolvedAccessibilityLabel {
            uiView.accessibilityLabel = resolvedAccessibilityLabel
        }

        let resolvedFont = font ?? UIFont.preferredFont(forTextStyle: .body)
        if uiView.font != resolvedFont {
            uiView.font = resolvedFont
        }

        let resolvedTextColor = textColor ?? UIColor.label
        if uiView.textColor != resolvedTextColor {
            uiView.textColor = resolvedTextColor
        }

        if let placeholderLabel = context.coordinator.placeholderLabel {
            if placeholderLabel.text != placeholder {
                placeholderLabel.text = placeholder
            }
            let resolvedPlaceholderTextColor = placeholderTextColor ?? UIColor.secondaryLabel
            if placeholderLabel.textColor != resolvedPlaceholderTextColor {
                placeholderLabel.textColor = resolvedPlaceholderTextColor
            }
        }
        // Defer editable state changes and only apply the value when it differs from the last value to avoid
        // first responder recalculation during the same layout pass (which can cause AttributeGraph cycles)
        if context.coordinator.lastIsEditable != isEditable {
            context.coordinator.lastIsEditable = isEditable
            DispatchQueue.main.async {
                if !isEditable {
                    if uiView.isFirstResponder {
                        uiView.resignFirstResponder()
                    }
                    if isFocused {
                        isFocused = false
                    }
                }
                uiView.isEditable = isEditable
            }
        }

        // Handle focus state changes.
        //
        // Note: During snapshot/unit testing we intentionally avoid changing first responder status to keep
        // screenshots deterministic (caret blink, selection highlighting, and keyboard-driven layout can vary).
        if !TestEnvironment.isRunningTests {
            DispatchQueue.main.async {
                if isFocused, !uiView.isFirstResponder, isEditable {
                    uiView.becomeFirstResponder()
                } else if !isFocused, uiView.isFirstResponder {
                    uiView.resignFirstResponder()
                }
            }
        }

        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        context.coordinator.recalculateHeight(uiView)
        // Avoid forcing immediate layout; allow the system to coalesce updates
        uiView.setNeedsLayout()

        if uiView.window != nil, uiView.isFirstResponder == false {
            // Keep cursor positioned where the binding says
            if let start = uiView.position(from: uiView.beginningOfDocument, offset: selectedRange.location),
               let end = uiView.position(from: start, offset: selectedRange.length),
               let range = uiView.textRange(from: start, to: end) {
                context.coordinator.isSettingSelectionProgrammatically = true
                uiView.selectedTextRange = range
                DispatchQueue.main.async {
                    context.coordinator.isSettingSelectionProgrammatically = false
                }
            }
            // Only auto scroll on text change, not on selection change
            // Defer scroll to the next runloop to avoid layout feedback
            DispatchQueue.main.async {
                context.coordinator.scrollToBottom(uiView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        var isSettingSelectionProgrammatically: Bool = false
        weak var placeholderLabel: UILabel?
        weak var placeholderTopConstraint: NSLayoutConstraint?
        var lastIsEditable: Bool?

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""

            if parent.text != newText {
                parent.text = newText
            }

            recalculateHeight(textView)

            if let range = textView.selectedTextRange {
                let startOffset = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let endOffset = textView.offset(from: textView.beginningOfDocument, to: range.end)
                let location = min(startOffset, endOffset)
                let length = max(0, abs(endOffset - startOffset))
                let newRange = NSRange(location: max(0, location), length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged?(true)
            if !parent.isFocused {
                DispatchQueue.main.async { [parent] in
                    parent.isFocused = true
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged?(false)
            if parent.isFocused {
                DispatchQueue.main.async { [parent] in
                    parent.isFocused = false
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if isSettingSelectionProgrammatically { return }
            if let range = textView.selectedTextRange {
                let startOffset = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let endOffset = textView.offset(from: textView.beginningOfDocument, to: range.end)
                let location = min(startOffset, endOffset)
                let length = max(0, abs(endOffset - startOffset))
                let newRange = NSRange(location: max(0, location), length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
        }

        func scrollToBottom(_ textView: UITextView) {
            let length = max(0, (textView.text as NSString).length)
            let end = NSRange(location: length, length: 0)
            textView.scrollRangeToVisible(end)
        }

        private let baseInset: CGFloat = 6

        func recalculateHeight(_ textView: UITextView) {
            // Temporarily reset to base insets for stable measurement
            let currentTopInset = textView.textContainerInset.top
            if currentTopInset != baseInset {
                textView.textContainerInset = UIEdgeInsets(top: baseInset, left: 6, bottom: baseInset, right: 6)
            }
            textView.layoutIfNeeded()

            // Fallback to 17pt, the typical line height of the default .body font
            let rawLineHeight = textView.font?.lineHeight ?? 17
            let lineHeight: CGFloat = (rawLineHeight.isFinite && rawLineHeight > 0) ? rawLineHeight : 17
            let baseVerticalInsets = baseInset * 2
            let minHeight = CGFloat(parent.minLines) * lineHeight + baseVerticalInsets
            let maxHeight = CGFloat(parent.maxLines) * lineHeight + baseVerticalInsets
            var width = textView.bounds.width
            if !width.isFinite || width <= 0 {
                width = textView.frame.size.width
            }
            if !width.isFinite || width <= 0 {
                width = UIScreen.main.bounds.width - 32
            }
            let fittingSize = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
            var measured = textView.sizeThatFits(fittingSize).height
            if !measured.isFinite || measured.isNaN {
                measured = minHeight
            }
            let target = min(max(measured, minHeight), maxHeight)
            textView.isScrollEnabled = measured.isFinite && measured > maxHeight + 1

            if target.isFinite && abs(parent.measuredHeight - target) > 0.5 {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.measuredHeight = target
                }
            }

            // Vertically center single-line text by adjusting textContainerInset.top.
            // The SwiftUI frame is max(40, measuredHeight). When measured content is
            // shorter than the frame, pad the top so text + cursor sit at center.
            let frameHeight = max(40, target)
            let contentHeight = measured
            let topPadding: CGFloat
            if contentHeight < frameHeight {
                topPadding = max(baseInset, (frameHeight - contentHeight) / 2 + baseInset)
            } else {
                topPadding = baseInset
            }
            if abs(textView.textContainerInset.top - topPadding) > 0.5 {
                textView.textContainerInset = UIEdgeInsets(top: topPadding, left: 6, bottom: baseInset, right: 6)
                placeholderTopConstraint?.constant = topPadding
            }
        }
    }
}
