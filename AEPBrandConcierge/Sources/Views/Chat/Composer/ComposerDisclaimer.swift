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

import Foundation
import SwiftUI

struct ComposerDisclaimer: View {
    @Environment(\.conciergeTheme) private var theme

    var body: some View {
        Text(attributedDisclaimerText)
            .font(.system(size: theme.components.disclaimer.fontSize, weight: theme.components.disclaimer.fontWeight.toSwiftUIFontWeight()))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedDisclaimerText: AttributedString {
        let text = theme.disclaimer.text
        let links = theme.disclaimer.links
        let disclaimerColor = theme.components.disclaimer.textColor.color

        var result = AttributedString()

        var remainingText = text[...]
        while let openBraceIndex = remainingText.firstIndex(of: "{"),
              let closeBraceIndex = remainingText[openBraceIndex...].firstIndex(of: "}") {
            // Append prefix text.
            let prefix = String(remainingText[..<openBraceIndex])
            var prefixString = AttributedString(prefix)
            prefixString.foregroundColor = disclaimerColor
            result.append(prefixString)

            // Extract token inside braces.
            let tokenStart = remainingText.index(after: openBraceIndex)
            let token = String(remainingText[tokenStart..<closeBraceIndex])

            var tokenString = AttributedString(token)
            tokenString.foregroundColor = disclaimerColor

            if let link = links.first(where: { $0.text == token }),
               let url = URL(string: link.url) {
                tokenString.link = url
                tokenString.foregroundColor = theme.colors.primary.text.color
                tokenString.underlineStyle = .single
            }

            result.append(tokenString)

            // Continue after close brace.
            remainingText = remainingText[remainingText.index(after: closeBraceIndex)...]
        }

        // Append trailing text.
        var trailingString = AttributedString(String(remainingText))
        trailingString.foregroundColor = disclaimerColor
        result.append(trailingString)
        return result
    }
}
