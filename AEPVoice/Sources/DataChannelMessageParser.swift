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

/// Parses a raw data-channel JSON object into a typed `DataChannelMessage`, mirroring web's
/// `parseDataChannelMessage` (`voiceStreamingUtils.ts`). Handles both on-wire formats:
///
/// - **Type-based** (user STT / notices): `{ "type": "transcript_delta", "data": { … } }`
/// - **Event-based** (assistant turn messages): `{ "event": "turn_completed", "fullText": "…" }`
///
/// Returns `nil` for a message that matches no known format, so callers drop it rather than acting
/// on a malformed shape. `text_input_error` is intentionally not handled here — it is a
/// browser→worker text-input concern with no consumer in the voice-only PoC.
enum DataChannelMessageParser {

    /// Parses raw `Data` (a single data-channel frame) into a typed message, or `nil` if the bytes
    /// aren't a JSON object or don't match a known format.
    static func parse(_ data: Data) -> DataChannelMessage? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let raw = object as? [String: Any] else {
            return nil
        }
        return parse(raw)
    }

    /// Parses an already-deserialized JSON object. Mirrors `parseDataChannelMessage(msg)`.
    static func parse(_ raw: [String: Any]) -> DataChannelMessage? {
        // Type-based format (user STT transcript_delta, session_notice, …).
        if let type = raw["type"] as? String {
            return buildTypeMessage(type: type, raw: raw)
        }
        // Event-based format (assistant turn messages from the worker).
        if let event = raw["event"] as? String {
            return buildEventMessage(event: event, raw: raw)
        }
        return nil
    }

    // MARK: - Type-based (mirrors buildTypeMessage)

    private static func buildTypeMessage(type: String, raw: [String: Any]) -> DataChannelMessage? {
        switch type {
        case "transcript_delta":
            guard let payload = raw["data"] as? [String: Any] else { return nil }
            let delta = TranscriptDeltaData(
                role: (payload["role"] as? String) == "assistant" ? .assistant : .user,
                turnId: asTurnId(payload["turnId"]),
                delta: asString(payload["delta"]),
                sequence: asNumber(payload["sequence"]),
                final: (payload["final"] as? Bool) == true
            )
            return .transcriptDelta(delta)

        case "session_notice":
            guard let notice = parseSessionNoticeData(raw["data"]) else { return nil }
            return .sessionNotice(notice)

        default:
            // Other type-based messages (e.g. state carriers) surface as a coarse state update.
            return .stateUpdate(state: type)
        }
    }

    // MARK: - Event-based (mirrors buildEventMessage)

    private static func buildEventMessage(event: String, raw: [String: Any]) -> DataChannelMessage? {
        switch event {
        case "text_delta":
            // Assistant transcript chunk — always non-final; completion comes via `turn_completed`.
            return .transcriptDelta(TranscriptDeltaData(
                role: .assistant,
                turnId: asTurnId(raw["turnId"]),
                delta: asString(raw["delta"]),
                sequence: asNumber(raw["sequence"]),
                final: false
            ))

        case "turn_completed":
            return .turnDone(TurnDoneData(
                fullText: asString(raw["fullText"]),
                state: TurnDoneData.TurnState(rawValue: asString(raw["state"], "completed")) ?? .completed,
                turnId: asTurnId(raw["turnId"])
            ))

        case "ui_payload":
            return .uiPayload(UiPayloadData(
                promptSuggestions: (raw["promptSuggestions"] as? [String]) ?? []
            ))

        case "turn_started":
            return .stateUpdate(state: "turn_started")

        case "state_update":
            return .stateUpdate(state: asString(raw["state"], "state_update"))

        case "response_metadata", "tts_hint":
            return .stateUpdate(state: event)

        default:
            return nil
        }
    }

    // MARK: - Session notice (mirrors parseSessionNoticeData)

    private static func parseSessionNoticeData(_ raw: Any?) -> SessionNoticeData? {
        guard let data = raw as? [String: Any], let kind = data["kind"] as? String else {
            return nil
        }
        switch kind {
        case "user_silence_warning":
            return .userSilenceWarning(silenceSeconds: asDouble(data["silenceSeconds"]))
        case "session_ended":
            return .sessionEnded(reason: asEndReason(data["reason"]))
        default:
            return nil
        }
    }

    // MARK: - Coercion helpers (mirror asString/asTurnId/asNumber/asEndReason)

    private static func asString(_ value: Any?, _ fallback: String = "") -> String {
        value as? String ?? fallback
    }

    /// Preserves the worker's omit-when-unknown convention: anything that isn't a non-empty string
    /// becomes `nil`, never `""` (an empty id would compare equal across turns).
    private static func asTurnId(_ value: Any?) -> String? {
        if let string = value as? String, !string.isEmpty { return string }
        return nil
    }

    private static func asNumber(_ value: Any?, _ fallback: Int = 0) -> Int {
        (value as? NSNumber)?.intValue ?? fallback
    }

    private static func asDouble(_ value: Any?, _ fallback: Double = 0) -> Double {
        (value as? NSNumber)?.doubleValue ?? fallback
    }

    /// Validates a wire `reason` against the known `EndReason` set rather than trusting the raw
    /// string — a missing or not-yet-modeled value (a worker newer than this client) becomes `nil`.
    private static func asEndReason(_ value: Any?) -> EndReason? {
        guard let string = value as? String else { return nil }
        return EndReason(rawValue: string)
    }
}
