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
import UIKit

/// A UIKit wrapper that presents the SwiftUI `ChatView` from a
/// UIKit context (ex: pushing or presenting modally).
final class ConciergeHostingController: UIHostingController<ChatView> {
    /// Creates a hosting controller for `ChatView`.
    /// - Parameters:
    ///   - title: Title shown in the chat header. If `nil`, uses the SDK default.
    ///   - subtitle: Subtitle shown under the title. If `nil`, uses the SDK default.
    init(title: String?, subtitle: String?) {
        let view = ChatView(
            speechCapturer: Concierge.speechCapturer,
            textSpeaker: Concierge.textSpeaker,
            title: title ?? Concierge.chatTitle,
            subtitle: subtitle ?? Concierge.chatSubtitle,
            onClose: {
                Task { @MainActor in
                    Concierge.dismiss()
                }
            }
        )
        super.init(rootView: view)
        modalPresentationStyle = .fullScreen
    }

    // Required for storyboard/XIB decoding, but unused in our implementation
    /// Unavailable. Use `init(title:subtitle:)` to construct programmatically.
    @MainActor @available(*, unavailable)
    required dynamic init?(coder decoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
