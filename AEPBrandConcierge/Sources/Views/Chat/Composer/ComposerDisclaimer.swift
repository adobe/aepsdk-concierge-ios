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

    var onLinkTap: ((URL) -> Void)?

    var body: some View {
        Text(attributedDisclaimerText)
            .font(.system(size: theme.components.disclaimer.fontSize, weight: theme.components.disclaimer.fontWeight.toSwiftUIFontWeight()))
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                onLinkTap?(url)
                return .systemAction
            })
    }

    private var attributedDisclaimerText: AttributedString {
        LinkedTextFormatter.format(
            text: theme.disclaimer.text,
            links: theme.disclaimer.links,
            textColor: theme.components.disclaimer.textColor.color,
            linkColor: theme.colors.primary.text.color
        )
    }
}
