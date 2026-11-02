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

        var id: String {
            switch identity {
            case .element(let id): return "\(turnId.uuidString):id:\(id)"
            case .position(let position): return "\(turnId.uuidString):position:\(position)"
            }
        }
    }

    struct Activation {
        let occurrence: Occurrence
        let position: Int
        let element: [String: Any]
        let registration: NativeCardRegistry.Registration
    }

    private struct Entry {
        let card: NativeCard
        let occurrence: Occurrence
        let position: Int
    }

    private var entries: [String: Entry] = [:]
    private var cardIdsByOccurrence: [Occurrence: String] = [:]
    private var isBusy = false

    deinit {
        let cards = entries.values.map(\.card)
        Task { @MainActor in cards.forEach { $0.dispose() } }
    }

    func position(for occurrence: Occurrence) -> Int? {
        guard let cardId = cardIdsByOccurrence[occurrence] else { return nil }
        return entries[cardId]?.position
    }

    func activate(_ activation: Activation, payload: ConversationPayload, sessionId: String?) -> NativeCard? {
        guard cardIdsByOccurrence[activation.occurrence] == nil else { return nil }
        let card = NativeCard(element: activation.element, renderer: activation.registration.renderer,
                              occurrenceId: activation.occurrence.id, sessionId: sessionId,
                              conversationId: payload.conversationId, interactionId: payload.interactionId)
        card.setBusy(isBusy)
        entries[card.cardId] = Entry(card: card, occurrence: activation.occurrence, position: activation.position)
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
            if case .nativeCard(let card) = message.template { return card.cardId }
            return nil
        })
        let removed = entries.keys.filter { !visible.contains($0) }
        for cardId in removed {
            guard let entry = entries.removeValue(forKey: cardId) else { continue }
            cardIdsByOccurrence.removeValue(forKey: entry.occurrence)
            entry.card.dispose()
        }
    }

    func removeAll() {
        for entry in entries.values { entry.card.dispose() }
        entries.removeAll()
        cardIdsByOccurrence.removeAll()
    }
}
