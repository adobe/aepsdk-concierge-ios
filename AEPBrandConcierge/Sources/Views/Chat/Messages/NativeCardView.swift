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

/// A native card row. The row carries only its card's ID; the live card comes from the chat's store,
/// so rows never hold a card past its disposal.
struct NativeCardView: View {
    let cardId: String
    @Environment(\.conciergeNativeCardStore) private var nativeCardStore

    var body: some View {
        if let card = nativeCardStore?.card(withId: cardId) {
            RenderedNativeCard(card: card)
        }
    }
}

/// Observes the card so the app's view re-renders whenever its context changes.
private struct RenderedNativeCard: View {
    @ObservedObject var card: NativeCard

    var body: some View {
        card.renderer(card.element, card.context, { [weak card] state in card?.saveState(state) })
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NativeCardStoreKey: EnvironmentKey {
    static let defaultValue: NativeCardStore? = nil
}

extension EnvironmentValues {
    /// The store that native card rows resolve their cards from, provided by the chat that owns them.
    var conciergeNativeCardStore: NativeCardStore? {
        get { self[NativeCardStoreKey.self] }
        set { self[NativeCardStoreKey.self] = newValue }
    }
}
