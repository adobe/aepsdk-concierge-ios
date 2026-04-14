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

import UIKit

final class MarkdownTextCoordinator: NSObject, UITextViewDelegate {
    var parent: MarkdownText

    init(parent: MarkdownText) {
        self.parent = parent
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if ConciergeLinkHandler.isWebLink(URL) {
            // Route http/https links through the custom handler (opens in in-app webview).
            parent.onOpenLink?(URL)
            return false
        }
        // Intercept non-web links and open via UIApplication directly.
        // UITextView converts tel: → telprompt:// internally, which requires LSApplicationQueriesSchemes
        // in the host app's Info.plist and can fail silently. Opening via UIApplication.open bypasses
        // that conversion and works reliably for tel:, mailto:, sms:, etc.
        // If UIApplication.open fails, fall back to letting UITextView handle it natively by
        // returning true — this preserves the system default behavior as a last resort.
        var handledBySystem = false
        ConciergeLinkHandler.urlOpener(URL, [:]) { success in handledBySystem = success }
        return !handledBySystem
    }
}
