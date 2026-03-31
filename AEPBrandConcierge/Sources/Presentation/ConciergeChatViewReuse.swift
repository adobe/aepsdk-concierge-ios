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

/// Shared rules for reusing one `ChatView` instance across dismiss/reopen within a single app process.
@MainActor
enum ConciergeChatViewReuse {

    /// Returns the stored view when header text and chat-service identity match; otherwise runs `create`, updates the backing storage, and returns the new view.
    static func existingOrNew(
        configuration: ConciergeConfiguration,
        title: String,
        subtitle: String?,
        storedView: inout ChatView?,
        storedTitle: inout String?,
        storedSubtitle: inout String?,
        create: () -> ChatView
    ) -> ChatView {
        if let existing = storedView,
           storedTitle == title,
           storedSubtitle == subtitle,
           existing.hasSameChatServiceIdentity(as: configuration) {
            return existing
        }
        let newView = create()
        storedView = newView
        storedTitle = title
        storedSubtitle = subtitle
        return newView
    }
}
