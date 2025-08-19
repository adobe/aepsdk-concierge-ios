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

/// UIKit backed multiline text view with selection support
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
        uiView.isEditable = isEditable
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        context.coordinator.recalculateHeight(uiView)
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()

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
            // Scroll to where the cursor/end of text is
            context.coordinator.scrollToBottom(uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        var isSettingSelectionProgrammatically: Bool = false
        weak var placeholderLabel: UILabel?

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
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let length = textView.offset(from: range.start, to: range.end)
                let newRange = NSRange(location: location, length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
            scrollToBottom(textView)
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
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let length = textView.offset(from: range.start, to: range.end)
                let newRange = NSRange(location: location, length: length)
                if parent.selectedRange != newRange {
                    DispatchQueue.main.async { [parent] in
                        parent.selectedRange = newRange
                    }
                }
            }
            scrollToBottom(textView)
        }

        func scrollToBottom(_ textView: UITextView) {
            let end = NSRange(location: (textView.text as NSString).length, length: 0)
            textView.scrollRangeToVisible(end)
        }

        func recalculateHeight(_ textView: UITextView) {
            // Use sizeThatFits to measure multiline height at current width
            textView.layoutIfNeeded()
            // Fallback to 17pt, the typical line height of the default .body font
            let lineHeight = textView.font?.lineHeight ?? 17
            let insets = textView.textContainerInset.top + textView.textContainerInset.bottom
            let minHeight = CGFloat(parent.minLines) * lineHeight + insets
            let maxHeight = CGFloat(parent.maxLines) * lineHeight + insets
            let fittingSize = CGSize(width: max(1, textView.bounds.width), height: .greatestFiniteMagnitude)
            let measured = textView.sizeThatFits(fittingSize).height
            let target = min(max(measured, minHeight), maxHeight)
            textView.isScrollEnabled = measured > maxHeight + 1
            if abs(parent.measuredHeight - target) > 0.5 {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.measuredHeight = target
                }
            }
        }
    }
}
