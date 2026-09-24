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

/// Swift mirror of web's data-channel message contract (`LiveKitContracts.ts`). The worker on the
/// other end is the same backend process regardless of client language, so the type/field names
/// here are copied verbatim from the TypeScript source and must not drift (NFR-03).
///
/// The worker sends two on-wire formats — type-based (user STT `transcript_delta`, `session_notice`)
/// and event-based (assistant `text_delta`/`turn_completed`/…) — which `DataChannelMessageParser`
/// normalizes into these cases (mirroring web's `parseDataChannelMessage`). Only the subset the
/// buffered-transcript PoC consumes is modeled; richer `ui_payload` content is parsed but not yet
/// rendered (FR-05).
enum DataChannelMessage: Equatable {
    case transcriptDelta(TranscriptDeltaData)
    case turnDone(TurnDoneData)
    case uiPayload(UiPayloadData)
    case sessionNotice(SessionNoticeData)
    /// A coarse worker state signal (`turn_started`, `state_update`, `response_metadata`, `tts_hint`).
    case stateUpdate(state: String)
}

/// An incremental transcript chunk. User chunks arrive type-based; assistant chunks are normalized
/// from the worker's `text_delta` events. Mirrors web's `TranscriptDeltaData`.
struct TranscriptDeltaData: Equatable {
    enum Role: String { case user, assistant }

    let role: Role
    let turnId: String?
    let delta: String
    let sequence: Int
    /// Whether this is the last chunk of the turn's transcript (user STT sets it; assistant deltas
    /// are always non-final — the assistant's completion is signaled by `turn_done` instead).
    let final: Bool
}

/// The completed assistant turn. Mirrors web's `TurnDoneData` (normalized from `turn_completed`).
struct TurnDoneData: Equatable {
    enum TurnState: String { case completed, interrupted, error }

    let fullText: String
    let state: TurnState
    let turnId: String?
}

/// Rich turn content (product cards / CTAs / suggestions). Parsed for contract completeness but not
/// rendered in the buffered-transcript PoC (FR-05). Mirrors web's `UiPayloadData`; only
/// `promptSuggestions` is typed — `sources`/`widgets`/`multimodalElements` are `unknown[]` on the
/// wire and have no v1 consumer.
struct UiPayloadData: Equatable {
    let promptSuggestions: [String]
}

/// The worker's terminal EndReason for a session, validated against the known set rather than
/// trusting the raw wire string (a newer worker's unknown reason parses to `nil`, never a falsely
/// narrowed value). Mirrors web's `EndReason`.
enum EndReason: String {
    case roomEmptyTimeout = "room_empty_timeout"
    case userJoinTimeout = "user_join_timeout"
    case workerShutdown = "worker_shutdown"
    case userInactivityTimeout = "user_inactivity_timeout"
    case error
}

/// A worker session notice. Mirrors web's `SessionNoticeData` union; an unrecognized `kind` parses
/// to `nil` so the caller drops it rather than passing through a malformed shape.
enum SessionNoticeData: Equatable {
    case userSilenceWarning(silenceSeconds: Double)
    case sessionEnded(reason: EndReason?)
}
