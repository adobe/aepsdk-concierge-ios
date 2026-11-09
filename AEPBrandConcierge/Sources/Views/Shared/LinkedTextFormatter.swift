/*
 Copyright 2026 Adobe. All rights reserved.
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

/// Formats brace-delimited link placeholders shared by legal notices.
enum LinkedTextFormatter {
    static func format(
        text: String,
        links: [ConciergeDisclaimerLink],
        textColor: Color,
        linkColor: Color
    ) -> AttributedString {
        var result = AttributedString()

        var remainingText = text[...]
        while let openBraceIndex = remainingText.firstIndex(of: "{"),
              let closeBraceIndex = remainingText[openBraceIndex...].firstIndex(of: "}") {
            let prefix = String(remainingText[..<openBraceIndex])
            var prefixString = AttributedString(prefix)
            prefixString.foregroundColor = textColor
            result.append(prefixString)

            let tokenStart = remainingText.index(after: openBraceIndex)
            let token = String(remainingText[tokenStart..<closeBraceIndex])

            var tokenString = AttributedString(token)
            tokenString.foregroundColor = textColor

            if let link = links.first(where: { $0.text == token }),
               let url = URL(string: link.url) {
                tokenString.link = url
                tokenString.foregroundColor = linkColor
                tokenString.underlineStyle = .single
            }

            result.append(tokenString)
            remainingText = remainingText[remainingText.index(after: closeBraceIndex)...]
        }

        var trailingString = AttributedString(String(remainingText))
        trailingString.foregroundColor = textColor
        result.append(trailingString)
        return result
    }
}
