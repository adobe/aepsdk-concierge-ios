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

@MainActor
final class NativeCardStore {
    struct Occurrence: Hashable {
        enum Identity: Hashable {
            case element(String)
            case position(Int)
        }

        let turnId: UUID
        let identity: Identity

        init(element: MultimodalElement, position: Int, turnId: UUID) {
            self.turnId = turnId
            identity = element.nativeElementId.map(Identity.element) ?? .position(position)
        }
    }

    struct Activation {
        let occurrence: Occurrence
        let position: Int
        let type: String
        let element: [String: Any]
        let registration: NativeCardRegistry.Registration
    }

    private struct Entry {
        let card: NativeCard
        let occurrence: Occurrence
        let position: Int
        let type: String
    }

    private var entries: [String: Entry] = [:]
    private var cardIdsByOccurrence: [Occurrence: String] = [:]
    private var latestCardIdByType: [String: String] = [:]
    /// The next activation's `sequence`; never reset, so values aren't reused within this chat.
    private var nextSequence = 0
    private var isBusy = false

    deinit {
        let cards = entries.values.map(\.card)
        Task { @MainActor in cards.forEach { $0.dispose() } }
    }

    func position(for occurrence: Occurrence) -> Int? {
        guard let cardId = cardIdsByOccurrence[occurrence] else { return nil }
        return entries[cardId]?.position
    }

    /// The live card behind a transcript row, or `nil` once it's been disposed.
    func card(withId cardId: String) -> NativeCard? {
        entries[cardId]?.card
    }

    func activate(_ activation: Activation, payload: ConversationPayload, sessionId: String?) -> NativeCard? {
        guard cardIdsByOccurrence[activation.occurrence] == nil else { return nil }
        let card = NativeCard(element: activation.element, renderer: activation.registration.renderer,
                              sequence: nextSequence, sessionId: sessionId,
                              conversationId: payload.conversationId, interactionId: payload.interactionId)
        nextSequence += 1
        card.setBusy(isBusy)
        // Cards activate in transcript order, so the newest card of a type is always the latest.
        if let previousId = latestCardIdByType.updateValue(card.cardId, forKey: activation.type) {
            entries[previousId]?.card.setLatest(false)
        }
        card.setLatest(true)
        entries[card.cardId] = Entry(card: card, occurrence: activation.occurrence, position: activation.position,
                                     type: activation.type)
        cardIdsByOccurrence[activation.occurrence] = card.cardId
        return card
    }

    func setBusy(_ busy: Bool) {
        isBusy = busy
        for entry in entries.values {
            entry.card.setBusy(busy)
        }
    }

    func reconcile(with messages: [Message]) {
        guard !entries.isEmpty else { return }
        let visible = Set(messages.compactMap { message -> String? in
            message.nativeCardId
        })
        let removed = entries.keys.filter { !visible.contains($0) }
        var typesLosingLatest = Set<String>()
        for cardId in removed {
            guard let entry = entries.removeValue(forKey: cardId) else { continue }
            cardIdsByOccurrence.removeValue(forKey: entry.occurrence)
            entry.card.dispose()
            if latestCardIdByType[entry.type] == cardId {
                latestCardIdByType.removeValue(forKey: entry.type)
                typesLosingLatest.insert(entry.type)
            }
        }
        typesLosingLatest.forEach(promoteLatest)
    }

    func removeAll() {
        for entry in entries.values { entry.card.dispose() }
        entries.removeAll()
        cardIdsByOccurrence.removeAll()
        latestCardIdByType.removeAll()
    }

    /// Makes the remaining card of `type` with the highest sequence the latest, if any remains.
    private func promoteLatest(_ type: String) {
        guard let newest = entries.values.filter({ $0.type == type }).max(by: { $0.card.sequence < $1.card.sequence })
        else { return }
        latestCardIdByType[type] = newest.card.cardId
        newest.card.setLatest(true)
    }
}
