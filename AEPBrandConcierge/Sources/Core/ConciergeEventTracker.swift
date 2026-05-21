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

import AEPCore
import AEPServices
import Foundation

/// Forwards Concierge notification events to the Adobe Experience Platform Edge Network as
/// Experience Events, without taking a compile-time dependency on the AEPEdge extension.
///
/// Each notification xdmType has an explicit case that pulls the fields it expects and builds
/// the outbound `data` map. This keeps the mapping deterministic and grep-friendly: to see what
/// a given Concierge event sends to Edge, jump to the case with that xdmType.
///
/// Dispatch goes through `MobileCore.dispatch(event:)` with type `com.adobe.eventType.edge` and
/// source `com.adobe.eventSource.requestContent`. The AEPEdge extension — if present in the app
/// at runtime — picks the event up and forwards it. If AEPEdge is missing, the event is silently
/// ignored. No compile-time coupling.
///
/// Sanitization rules (per agreement with team):
/// - `query` (QuerySubmitted) and `notes` (FeedbackSubmitted) are dropped: free-form user text,
///   PII risk.
/// - `element` (CardClicked) and entries in `elements` (CardsRendered) are filtered down to
///   product-identifier fields (`productName`, `productPageURL`); display-only fields like
///   `productDescription`, `productPrice`, `productBadge` are stripped.
///
/// Mirrors the Android `ConciergeEventTracker` implementation field-for-field.
internal enum ConciergeEventTracker {

    private static let SELF_TAG = "ConciergeEventTracker"

    private static let EVENT_NAME = "Concierge Tracking Edge Request"
    private static let EDGE_EVENT_DATA_KEY_XDM = "xdm"
    private static let EDGE_EVENT_DATA_KEY_DATA = "data"
    private static let XDM_EVENT_TYPE = "eventType"

    // Fields kept when filtering card payloads.
    private static let CARD_KEY_PRODUCT_NAME = "productName"
    private static let CARD_KEY_PRODUCT_PAGE_URL = "productPageURL"

    /// Gate for Edge forwarding. Tracking is disabled by default; the consumer app must call
    /// `Concierge.enableTracking()` to opt in. Mirrors the Android `trackingEnabled` flag.
    internal static var trackingEnabled = false

    /// Flips the gate so subsequent notification events are forwarded to Edge.
    /// Internal — the public entry point is `Concierge.enableTracking()` in `Concierge+PublicAPI.swift`.
    internal static func enableTracking(enable: Bool) {
        trackingEnabled = enable
        Log.debug(
            label: ConciergeConstants.LOG_TAG,
            "Concierge tracking \(enable ? "enabled" : "disabled")."
        )
    }

    /// Builds and dispatches an Edge request event for the given Concierge notification.
    /// No-ops if tracking is disabled, event data is missing, the routing key is absent, or the
    /// xdmType is unrecognized.
    static func trackEvent(_ event: Event) {
        guard trackingEnabled else {
            Log.debug(label: ConciergeConstants.LOG_TAG,
                      "[\(SELF_TAG)] Ignoring track event. Call Concierge.enableTracking() to enable tracking.")
            return
        }
        guard let data = event.data else {
            Log.debug(label: ConciergeConstants.LOG_TAG,
                      "[\(SELF_TAG)] Skipping Edge forwarding: notification event '\(event.name)' has no event data.")
            return
        }
        typealias Key = ConciergeConstants.TrackingEvent.EventData.Key
        guard let xdmType = data[Key.EVENT_TYPE] as? String, !xdmType.isEmpty else {
            Log.warning(label: ConciergeConstants.LOG_TAG,
                        "[\(SELF_TAG)] Skipping Edge forwarding: notification event missing routing key '\(Key.EVENT_TYPE)'.")
            return
        }

        typealias Types = ConciergeConstants.TrackingEvent.XDMType
        switch xdmType {
        case Types.SESSION_INITIALIZED:
            dispatchEdge(xdmType: xdmType, data: [:])

        case Types.CHAT_OPENED:
            var payload: [String: Any] = [:]
            if let epoch = data[Key.EPOCH_TIME] as? Int64 {
                payload[Key.EPOCH_TIME] = epoch
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.CHAT_CLOSED:
            var payload: [String: Any] = [:]
            if let epoch = data[Key.EPOCH_TIME] as? Int64 {
                payload[Key.EPOCH_TIME] = epoch
            }
            if let duration = data[Key.DURATION_MILLIS] as? Int64 {
                payload[Key.DURATION_MILLIS] = duration
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.QUERY_SUBMITTED:
            // `query` is dropped (free-form user-typed text — PII risk).
            dispatchEdge(xdmType: xdmType, data: [:])

        case Types.PROMPT_SUGGESTION_CLICKED:
            var payload: [String: Any] = [:]
            if let suggestion = data[Key.SUGGESTION] as? String {
                payload[Key.SUGGESTION] = suggestion
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.WELCOME_PROMPT_SUGGESTION_CLICKED:
            var payload: [String: Any] = [:]
            if let suggestion = data[Key.SUGGESTION] as? String {
                payload[Key.SUGGESTION] = suggestion
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.CARD_CLICKED:
            var payload: [String: Any] = [:]
            if let element = data[Key.ELEMENT] as? [String: Any] {
                let filtered = filterCardElement(element)
                if !filtered.isEmpty {
                    payload[Key.ELEMENT] = filtered
                }
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.MIC_BUTTON_CLICKED:
            dispatchEdge(xdmType: xdmType, data: [:])

        case Types.RESPONSE_STARTED:
            var payload: [String: Any] = [:]
            if let conversationId = data[Key.CONVERSATION_ID] as? String {
                payload[Key.CONVERSATION_ID] = conversationId
            }
            if let interactionId = data[Key.INTERACTION_ID] as? String {
                payload[Key.INTERACTION_ID] = interactionId
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.RESPONSE_COMPLETED:
            var payload: [String: Any] = [:]
            if let conversationId = data[Key.CONVERSATION_ID] as? String {
                payload[Key.CONVERSATION_ID] = conversationId
            }
            if let interactionId = data[Key.INTERACTION_ID] as? String {
                payload[Key.INTERACTION_ID] = interactionId
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.CARDS_RENDERED:
            var payload: [String: Any] = [:]
            if let displayMode = data[Key.DISPLAY_MODE] as? String {
                payload[Key.DISPLAY_MODE] = displayMode
            }
            if let elements = data[Key.ELEMENTS] as? [[String: Any]] {
                let filtered = elements.map(filterCardElement).filter { !$0.isEmpty }
                if !filtered.isEmpty {
                    payload[Key.ELEMENTS] = filtered
                }
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.FEEDBACK_SUBMITTED:
            var payload: [String: Any] = [:]
            if let conversationId = data[Key.CONVERSATION_ID] as? String {
                payload[Key.CONVERSATION_ID] = conversationId
            }
            if let interactionId = data[Key.INTERACTION_ID] as? String {
                payload[Key.INTERACTION_ID] = interactionId
            }
            if let feedbackType = data[Key.FEEDBACK_TYPE] as? String {
                payload[Key.FEEDBACK_TYPE] = feedbackType
            }
            if let selectedOptions = data[Key.SELECTED_OPTIONS] as? [String] {
                payload[Key.SELECTED_OPTIONS] = selectedOptions
            }
            // `notes` is dropped (free-form user-typed text — PII risk).
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.DISCLAIMER_LINK_CLICKED:
            var payload: [String: Any] = [:]
            if let url = data[Key.URL] as? String {
                payload[Key.URL] = url
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.ERROR_OCCURRED:
            var payload: [String: Any] = [:]
            if let errorMessage = data[Key.ERROR_MESSAGE] as? String {
                payload[Key.ERROR_MESSAGE] = errorMessage
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        case Types.CTA_BUTTON_CLICKED:
            var payload: [String: Any] = [:]
            if let label = data[Key.LABEL] as? String {
                payload[Key.LABEL] = label
            }
            if let url = data[Key.URL] as? String {
                payload[Key.URL] = url
            }
            dispatchEdge(xdmType: xdmType, data: payload)

        default:
            Log.debug(label: ConciergeConstants.LOG_TAG,
                      "[\(SELF_TAG)] Skipping Edge forwarding: unrecognized xdmType '\(xdmType)'. " +
                      "Add a case to ConciergeEventTracker.trackEvent to forward this event.")
        }
    }

    /// Returns a copy of a card content map keeping only fields that identify the product.
    /// Strips display-only fields (`productDescription`, `productPrice`, `productBadge`).
    private static func filterCardElement(_ card: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        if let value = card[CARD_KEY_PRODUCT_NAME] {
            out[CARD_KEY_PRODUCT_NAME] = value
        }
        if let value = card[CARD_KEY_PRODUCT_PAGE_URL] {
            out[CARD_KEY_PRODUCT_PAGE_URL] = value
        }
        return out
    }

    /// Builds the `(EventType.edge, EventSource.requestContent)` event with the standard
    /// `{xdm, data}` shape and dispatches it via `MobileCore`.
    ///
    /// The xdmType is written into both:
    /// - `xdm.eventType` — for tag-property Rule conditions targeting XDM
    /// - `data.conciergeEventType` — for Rule conditions targeting the free-form data map
    ///   (also useful when reading the dispatched event in Assurance / log output without
    ///   inspecting xdm)
    private static func dispatchEdge(xdmType: String, data: [String: Any]) {
        let xdm: [String: Any] = [XDM_EVENT_TYPE: xdmType]
        var dataWithEventType = data
        dataWithEventType[ConciergeConstants.TrackingEvent.EventData.Key.EVENT_TYPE] = xdmType

        let edgeEvent = Event(
            name: EVENT_NAME,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: [
                EDGE_EVENT_DATA_KEY_XDM: xdm,
                EDGE_EVENT_DATA_KEY_DATA: dataWithEventType
            ]
        )

        Log.trace(label: ConciergeConstants.LOG_TAG,
                  "[\(SELF_TAG)] Dispatching Edge request: xdm.eventType='\(xdmType)', data=\(dataWithEventType).")
        MobileCore.dispatch(event: edgeEvent)
    }
}
