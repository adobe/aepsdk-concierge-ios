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

/// SwiftUI component that renders markdown using the markdown block renderer.
/// It composes `MarkdownText` and native SwiftUI elements to support full markdown rendering.
struct MarkdownBlockView: View {
    let markdown: String
    var textColor: UIColor
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)
    var spacing: CGFloat = 8

    var body: some View {
        let blocks = MarkdownRenderer.buildBlocks(
            markdown: markdown,
            textColor: textColor,
            baseFont: baseFont
        )

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(blocks.enumerated()), id: \.0) { _, block in
                switch block {
                case .text(let ns):
                    MarkdownText(attributed: ns)
                        .fixedSize(horizontal: false, vertical: true)
                case .divider:
                    Divider()
                case .blockQuote(let paras):
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 3)
                            .cornerRadius(2)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(paras.enumerated()), id: \.0) { _, p in
                                MarkdownText(attributed: p)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }
}


