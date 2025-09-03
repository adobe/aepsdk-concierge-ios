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

struct SourceRowView: View {
    let source: ConciergeSourceReference
    let theme: ConciergeTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(source.ordinal)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textBody.opacity(0.8))
                .frame(minWidth: 18, alignment: .leading)

            Link(destination: source.link) {
                Text(source.link.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("Opens in browser")
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    SourceRowView(
        source: ConciergeSourceReference(ordinal: "a.", link: URL(string: "https://example.com/articles/1")!),
        theme: ConciergeTheme()
    )
    .padding()
}
