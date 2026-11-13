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
import AEPServices

@MainActor
struct ResponseElementPlan {
    enum Target {
        case native(NativeCardStore.Activation)
        case product(MultimodalElement)
        case cta(ActionButton)
    }

    let targets: [Target]

    var hasRenderableElements: Bool {
        targets.contains { target in
            switch target {
            case .native, .cta: return true
            case .product(let element): return element.entityInfo != nil
            }
        }
    }

    var cardsRenderedEvent: ConciergeTrackingEvent? {
        let elements: [[String: Any]] = productElements.compactMap { element in
            guard let entityInfo = element.entityInfo else { return nil }
            var result: [String: Any] = [:]
            if let name = entityInfo.productName { result["productName"] = name }
            if let url = entityInfo.productPageURL { result["productPageURL"] = url }
            if let price = entityInfo.productPrice { result["productPrice"] = price }
            return result
        }
        guard !elements.isEmpty else { return nil }
        return .cardsRendered(displayMode: elements.count == 1 ? "single" : "carousel", elements: elements)
    }

    private var productElements: [MultimodalElement] {
        targets.compactMap { target in
            if case .product(let element) = target { return element }
            return nil
        }
    }

    func makeMessages(nativeCards: NativeCardStore, payload: ConversationPayload, sessionId: String?,
                      promptSuggestions: [String]) -> [Message] {
        let elements = productElements
        let products = elements.compactMap { element -> ProductCardData? in
            guard let entityInfo = element.entityInfo else { return nil }
            return ProductCardData(entityInfo: entityInfo, element: element)
        }
        let productMessage: Message?
        if elements.count == 1, let product = products.first {
            productMessage = Message(template: .productCard(product))
        } else if elements.count > 1 {
            // Legacy batching counts element candidates, even when their product projection is empty.
            productMessage = Message(template: .carouselGroup(products.map {
                Message(template: .productCarouselCard($0))
            }))
        } else {
            productMessage = nil
        }

        var messages: [Message] = []
        messages.reserveCapacity(targets.count + promptSuggestions.count)
        var productEmitted = false
        var productIndex: Int?
        var lastNativeIndex: Int?
        for target in targets {
            switch target {
            case .native(let activation):
                guard let card = nativeCards.activate(activation, payload: payload, sessionId: sessionId) else { continue }
                lastNativeIndex = messages.count
                messages.append(Message(nativeCardId: card.cardId))
            case .product:
                guard !productEmitted else { continue }
                productEmitted = true
                if let productMessage {
                    if !products.isEmpty { productIndex = messages.count }
                    messages.append(productMessage)
                }
            case .cta(let action):
                messages.append(Message(template: .ctaButton(action)))
            }
        }
        if !promptSuggestions.isEmpty {
            if let lastNativeIndex {
                messages[productIndex ?? lastNativeIndex].promptSuggestions = promptSuggestions
            } else {
                messages.append(contentsOf: promptSuggestions.map {
                    Message(template: .promptSuggestion(text: $0))
                })
            }
        }
        return messages
    }
}

@MainActor
enum ResponseElementResolver {
    private static let LOG_TAG = "ResponseElementResolver"

    static func resolve(_ elements: [MultimodalElement], turnId: UUID, nativeCards: NativeCardStore,
                        allowsNativeCards: Bool = true) -> ResponseElementPlan {
        var targets: [ResponseElementPlan.Target] = []
        targets.reserveCapacity(elements.count)
        var occurrencePositions: [NativeCardStore.Occurrence: Int] = [:]
        for (position, element) in elements.enumerated() {
            let registration = NativeCardRegistry.registration(for: element.type)
            // Streaming-only native candidates never become either native rows or built-in fallbacks.
            if !allowsNativeCards, registration != nil { continue }
            if let registration {
                let occurrence = NativeCardStore.Occurrence(element: element, position: position, turnId: turnId)
                let existingPosition = nativeCards.position(for: occurrence)
                if let originalPosition = occurrencePositions[occurrence] ?? existingPosition,
                   originalPosition != position {
                    Log.warning(label: LOG_TAG, "Rejected native card element at position \(position): duplicate element id.")
                } else if !element.hasCompleteRawElement {
                    Log.warning(label: LOG_TAG, "Rejected native card element with invalid, over-budget, or inexact raw JSON.")
                } else {
                    occurrencePositions[occurrence] = position
                    // Decoding already enforced the JSON budget; build the renderer's copy only for new cards.
                    if existingPosition == nil {
                        targets.append(.native(NativeCardStore.Activation(occurrence: occurrence, position: position,
                                                                         type: element.type ?? "",
                                                                         element: element.rawElement,
                                                                         registration: registration)))
                    }
                    continue
                }
            }
            if element.elementType == .ctaButton {
                if let action = element.entityInfo?.primary {
                    targets.append(.cta(action))
                } else {
                    Log.warning(label: LOG_TAG, "Skipping ctaButton element '\(element.id ?? "unknown")': missing entity_info.primary.")
                }
            } else if element.entityInfo != nil || registration == nil {
                targets.append(.product(element))
            }
        }
        return ResponseElementPlan(targets: targets)
    }
}
