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

/// Data the app hands to the Concierge SDK (via `Concierge.sendDataHandoff(...)`) to forward
/// toward the agent pipeline (Brand Concierge / Product Advisor), outside of normal user-typed
/// chat. Internal transport container between the public wrapper and the extension's listener -
/// not constructed by consumer apps directly.
///
/// `routingHint` is a keyword consumed only by Brand Concierge's current phrase-based router
/// (e.g. "successful-checkout") — the end user never sees it, and it is not conversational
/// content. It may be empty when routing is determined entirely from the XDM fields.
///
/// `xdmFields` is merged directly into the root of the XDM object the SDK forwards alongside
/// the routing hint — an ordinary nested dictionary, e.g.
/// `["commerce": ["order": ["purchaseID": "123"]]]`. The SDK never reads or validates the
/// business meaning of these values; the customer's own nesting defines the destination.
/// Must not use `identityMap` (or any other SDK-reserved top-level XDM key) as a top-level key.
///
/// `localMessage` is text rendered immediately in the chat transcript as a local, non-networked
/// message — distinct from `routingHint`/`xdmFields`, which are forwarded to Brand Concierge.
/// Present and non-empty -> shown immediately. `nil`/empty -> nothing shown locally; the
/// conversation only gets whatever Product Advisor eventually replies with, same as if this
/// field didn't exist.
struct ConciergeDataHandoffEvent {
    let routingHint: String
    let xdmFields: [String: Any]
    let localMessage: String?

    init(routingHint: String, xdmFields: [String: Any], localMessage: String? = nil) {
        self.routingHint = routingHint
        self.xdmFields = xdmFields
        self.localMessage = localMessage
    }
}

/// Any error encountered while forwarding a `Concierge.sendDataHandoff(...)` call.
public enum ConciergeDataHandoffError: Error, Equatable, LocalizedError {
    /// The SDK received no payload at all for this request.
    case missingEventData
    /// `xdmFields` was empty.
    case emptyXdmFields
    /// `xdmFields` contained a value that isn't JSON-serializable.
    case invalidXdmFieldValue
    /// `xdmFields` used a reserved top-level key (e.g. `identityMap`).
    case reservedKeyCollision
    /// No Concierge chat session was active when the handoff was submitted.
    case noActiveSession
    /// Another Concierge chat turn is currently being processed. The handoff was not started and
    /// nothing was rendered; the app may retry once the chat is no longer processing.
    case chatInProgress
    /// Brand Concierge returned an error, or the request could not be completed. The associated
    /// value carries the underlying service detail when one is available.
    case deliveryFailed(String?)
    /// Brand Concierge completed the stream without any renderable response content.
    case emptyResponse
    /// Brand Concierge did not complete the handoff within the delivery timeout. Distinguished from
    /// `deliveryFailed` so an app can retry a slow turn without retrying a rejected one.
    case deliveryTimeout
    /// The extension never responded (e.g. the call timed out).
    case noResponse

    /// A stable, machine-readable identifier for this error.
    ///
    /// Public so an app can report the failure to analytics or crash reporting without switching
    /// over every case.
    public var code: String {
        switch self {
        case .missingEventData: return "missing_event_data"
        case .emptyXdmFields: return "empty_xdm_fields"
        case .invalidXdmFieldValue: return "invalid_xdm_field_value"
        case .reservedKeyCollision: return "reserved_key_collision"
        case .noActiveSession: return "no_active_session"
        case .chatInProgress: return "chat_in_progress"
        case .deliveryFailed: return "delivery_failed"
        case .emptyResponse: return "empty_response"
        case .deliveryTimeout: return "delivery_timeout"
        case .noResponse: return "no_response"
        }
    }

    /// Maps an internal transport/stream error onto the public handoff taxonomy.
    init(serviceError: ConciergeError) {
        switch serviceError {
        case .timeout:
            self = .deliveryTimeout
        case .invalidResponseData:
            // The controller reports this only when a stream completes with no renderable content.
            self = .emptyResponse
        default:
            self = .deliveryFailed(serviceError.localizedDescription)
        }
    }

    init?(code: String, message: String? = nil) {
        switch code {
        case "missing_event_data": self = .missingEventData
        case "empty_xdm_fields": self = .emptyXdmFields
        case "invalid_xdm_field_value": self = .invalidXdmFieldValue
        case "reserved_key_collision": self = .reservedKeyCollision
        case "no_active_session": self = .noActiveSession
        case "chat_in_progress": self = .chatInProgress
        case "delivery_failed": self = .deliveryFailed(message)
        case "empty_response": self = .emptyResponse
        case "delivery_timeout": self = .deliveryTimeout
        case "no_response": self = .noResponse
        default: return nil
        }
    }

    /// The message that has to survive the event boundary for `init(code:message:)` to rebuild the
    /// exact same case. Only `.deliveryFailed` carries one; every other case is reconstructed from
    /// `code` alone and regenerates identical copy via `errorDescription`. Writing
    /// `localizedDescription` here instead would turn `.deliveryFailed(nil)` into
    /// `.deliveryFailed(<fallback copy>)` on the way back.
    var wireMessage: String? {
        if case .deliveryFailed(let message) = self { return message }
        return nil
    }

    public var errorDescription: String? {
        switch self {
        case .missingEventData:
            return "The data handoff payload was missing or invalid."
        case .emptyXdmFields:
            return "The data handoff requires at least one XDM field."
        case .invalidXdmFieldValue:
            return "The data handoff contains a value that cannot be serialized as JSON."
        case .reservedKeyCollision:
            return "The data handoff cannot override the SDK-managed identity map."
        case .noActiveSession:
            return "Data handoff requires an active Concierge chat session."
        case .chatInProgress:
            return "Data handoff cannot start while another Concierge chat turn is in progress."
        case .deliveryFailed(let message):
            return message ?? "The Concierge service failed to complete the data handoff."
        case .emptyResponse:
            return "The Concierge service completed the data handoff without any response content."
        case .deliveryTimeout:
            return "The Concierge service did not complete the data handoff in time."
        case .noResponse:
            return "No response was received for the data handoff."
        }
    }
}
