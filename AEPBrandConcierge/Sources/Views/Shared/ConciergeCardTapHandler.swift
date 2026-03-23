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

/// Environment based handler for card tap tracking.
///
/// Injected by `ChatView` so that card views anywhere in the hierarchy
/// can report taps without nested callback wiring.
struct ConciergeCardTapHandler {
    private let handler: (ProductCardData) -> Void

    init(handler: @escaping (ProductCardData) -> Void = { _ in }) {
        self.handler = handler
    }

    func cardTapped(_ cardData: ProductCardData) {
        handler(cardData)
    }
}

// MARK: - Environment Key

private struct ConciergeCardTapHandlerKey: EnvironmentKey {
    static let defaultValue = ConciergeCardTapHandler()
}

extension EnvironmentValues {
    var conciergeCardTapHandler: ConciergeCardTapHandler {
        get { self[ConciergeCardTapHandlerKey.self] }
        set { self[ConciergeCardTapHandlerKey.self] = newValue }
    }
}

extension View {
    func conciergeCardTapHandler(_ handler: ConciergeCardTapHandler) -> some View {
        environment(\.conciergeCardTapHandler, handler)
    }
}
