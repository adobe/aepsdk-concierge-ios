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
    var isEditable: Bool
    var placeholder: String
    var minLines: Int = 1
    var maxLines: Int = 4
    var onEditingChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = true
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.accessibilityTraits.insert(.allowsDirectInteraction)

        // Placeholder label
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.numberOfLines = 1
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        // Store weak reference for later visibility control
        context.coordinator.placeholderLabel = placeholderLabel
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 12),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10)
        ])
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Defer editable state changes and only apply the value when it differs from the last value to avoid
        // first responder recalculation during the same layout pass (which can cause AttributeGraph cycles)
        if context.coordinator.lastIsEditable != isEditable {
            context.coordinator.lastIsEditable = isEditable
            DispatchQueue.main.async {
                if !isEditable, uiView.isFirstResponder {
                    uiView.resignFirstResponder()
                }
                uiView.isEditable = isEditable
            }
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        context.coordinator.recalculateHeight(uiView)
        // Avoid forcing immediate layout; allow the system to coalesce updates
        uiView.setNeedsLayout()

        // Make the text view first responder asynchronously once it's in a window to avoid AttributeGraph cycles
        if uiView.window != nil,
           uiView.isFirstResponder == false,
           context.coordinator.didBecomeFirstResponder == false,
           isEditable {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                context.coordinator.didBecomeFirstResponder = true
            }
        }

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
        var didBecomeFirstResponder: Bool = false
        var lastIsEditable: Bool? = nil

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
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged?(false)
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

        func recalculateHeight(_ textView: UITextView) {
            textView.layoutIfNeeded()
            // Fallback to 17pt, the typical line height of the default .body font
            let rawLineHeight = textView.font?.lineHeight ?? 17
            let lineHeight: CGFloat = (rawLineHeight.isFinite && rawLineHeight > 0) ? rawLineHeight : 17
            let insets = textView.textContainerInset.top + textView.textContainerInset.bottom
            let minHeight = CGFloat(parent.minLines) * lineHeight + insets
            let maxHeight = CGFloat(parent.maxLines) * lineHeight + insets
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
        }
    }
}
