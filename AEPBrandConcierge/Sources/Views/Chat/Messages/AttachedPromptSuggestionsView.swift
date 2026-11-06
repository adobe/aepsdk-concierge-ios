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

import SwiftUI

/// Prompt suggestions attached below a card row. Each chip is drawn exactly like a standalone
/// suggestion row, and `MessageListView` gives the group the same insets as those rows.
struct AttachedPromptSuggestionsView: View {
    @Environment(\.conciergeTheme) private var theme

    let suggestions: [String]
    var onSuggestionTap: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if theme.behavior.promptSuggestions?.showHeader == true {
                Text(theme.text.suggestionsHeader)
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(theme.colors.message.conciergeText.color)
            }
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                ChatMessageView(template: .promptSuggestion(text: suggestion), onSuggestionTap: onSuggestionTap)
            }
        }
    }
}
