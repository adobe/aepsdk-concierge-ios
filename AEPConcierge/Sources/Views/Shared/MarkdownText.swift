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

/// UIKit backed text view that displays an NSAttributedString and auto sizes
/// to its intrinsic height for use inside SwiftUI stacks.
struct MarkdownText: UIViewRepresentable {
    let attributed: NSAttributedString
    var maxWidth: CGFloat? = nil
    var onOpenLink: ((URL) -> Void)? = nil

    final class AutoSizingTextView: UITextView {
        var targetWidth: CGFloat = 0 { didSet { if oldValue != targetWidth { invalidateIntrinsicContentSize() } } }
        override var intrinsicContentSize: CGSize {
            let width = targetWidth > 0 ? targetWidth : bounds.width
            let size = sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            return CGSize(width: width, height: ceil(size.height))
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            if targetWidth <= 0 && bounds.width > 0 { targetWidth = bounds.width }
        }
    }

    func makeUIView(context: Context) -> AutoSizingTextView {
        let tv = AutoSizingTextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = false
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        uiView.attributedText = attributed
        if let w = maxWidth, w > 0 {
            uiView.targetWidth = w
            uiView.textContainer.size = CGSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownText

        init(parent: MarkdownText) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let handler = parent.onOpenLink {
                handler(URL)
                return false
            }
            return true
        }
    }
}
