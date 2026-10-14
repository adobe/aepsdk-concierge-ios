# LiveKit Voice — Room Connection & Bootstrap — Requirements & Design

**Status:** Draft — pending team review
**Scope:** How the iOS SDK obtains LiveKit connection credentials (bootstrap), connects to the
LiveKit `Room`, publishes the mic, parses the worker's data-channel messages, and surfaces
voice-turn content to the user. Assumes the AVAudioSession design
(`voice-livekit-audio-session-design.md`) for audio-session/routing concerns — this document does
not repeat those. Does not cover detailed voice-mode UI states/visuals (separate doc) or Android.

**Revision note (2026-09-14):** §4 FR-05, §6.5, §8, and §9 Phase 3 were revised to reflect a
strategy pivot recorded in the vault ADR-011 — the first iteration deliberately ships a minimal,
ChatGPT-voice-mode-style UI (no live per-turn content during the call; a plain transcript once the
session ends) rather than reusing the existing chat transcript live, per FR-05. Richer live UI
(cards/CTAs, incremental streaming text) is treated as an on-demand follow-up, added only if
requested after the first demo, not built into this iteration. See ADR-011 for the full rationale.
**Audience:** iOS team (implementation + review) and `brand-concierge-web-agent` developers
(parity review). Every iOS decision below is cross-referenced against its web equivalent
(`voiceCommands.ts`, `VoiceTransport.ts`, `LiveKitVoiceManager.ts`, `LiveKitContracts.ts`).

---

## 1. Background & Problem Statement

### Current state

- `ChatController` (`AEPBrandConcierge/Sources/Controllers/ChatController.swift`) owns the only
  existing turn pipeline: `sendMessage` → `streamAgentResponse` → `ConciergeChatService.streamChat`
  (a `URLSession` SSE POST to the CCS `/brand-concierge/conversations` endpoint) → chunks decoded
  as `ConversationPayload`/`ConversationResponse` → appended into `@Published var messages`, with
  `chatState` gating the composer/mic (`micEnabled`, `sendEnabled`, `composerEditable`).
- `ConversationResponse` (`Models/Network/ConversationResponse.swift`) has fields for `message`,
  `promptSuggestions`, `multimodalElements`, `sources`, `linkHints`, `state`, `feedback` — **no
  `voice` field exists today.** Web's equivalent wire shape already carries a `response.voice`
  object (`VoicePayload` in `AudioStreaming.ts`) that iOS's model does not yet decode.
- `SpeechController`/`SpeechCapturer` (dictation) is a sibling of the chat pipeline: it turns
  speech into text that lands in the composer (`InputController`), and never touches the network
  or `messages` directly. It has no data-channel or WebRTC concept at all.
- No LiveKit dependency exists anywhere in this repo today (`Package.swift`, `Podfile`,
  `AEPBrandConcierge.podspec` — verified, none reference it).
- `ChatController`, `ChatView`, and every message-rendering view (`MessageListView`,
  `BasicMessageView`, etc.) are **internal** to the `AEPBrandConcierge` module (no `public`
  modifier) — a host app (including `ConciergeDemoApp`) cannot reach into `messages` or push a new
  bubble into the transcript from outside the framework. Only `Concierge.show(...)`/`.present(...)`
  and the `SpeechCapturing`/`TextSpeaking` protocols are public seams.

### Gap

Porting web's full_cycle voice flow (bootstrap over the same conversation-event channel → connect
`Room` → publish mic → receive transcript/turn state over the data channel → render as chat
turns) requires, and today has none of:

1. A wire-compatible way to request LiveKit connection credentials without a new endpoint (mirror
   web's reuse of `sendConversationDataEvent`/`bootstrapVoice`).
2. A `Room` connection + mic publish + remote-audio subscribe (LiveKit SDK not yet a dependency).
3. A Swift-side parser for the worker's data-channel JSON contract
   (`transcript_delta`/`turn_done`/`session_notice`/`ui_payload`/`text_input_error`) — this
   contract is defined by the shared backend worker, not by either client, so the JSON shape must
   match web's byte-for-byte, not be reinvented.
4. A way to get voice-turn content into the existing chat transcript UI, given `ChatController`/
   `messages` are internal to the module (see Rejected Alternatives).

### Comparison table

| Scenario | Current Behavior (text turn) | Desired Behavior (voice turn) |
|---|---|---|
| Getting a server response | `ConciergeChatService.streamChat` posts a `message`-shaped conversation event, decodes SSE chunks into `ConversationPayload` | A `livekit-bootstrap`-shaped conversation event is posted on the **same** endpoint/session; the SSE response carries a `response.voice` object with `type: "livekit_session"`, `livekitUrl`, `token` instead of `message` |
| Real-time transport | None — one request, one streamed text response | A LiveKit `Room` (WebRTC) carries the mic track out and a remote (TTS) audio track + JSON data-channel messages in |
| Turn content reaching the UI | `streamAgentResponse`'s `onChunk`/`onComplete` mutate `messages`/`chatState` directly, rendering incrementally as the response streams | **v1 (this doc):** no live per-turn UI during the call — a new voice-session controller buffers turn content and appends it to `messages` as a plain transcript once the session ends, ChatGPT-voice-mode-style. Live incremental rendering and rich content (cards/CTAs) mirroring the text-turn path are deferred to a later iteration (see FR-05, ADR-011) |
| Mic control | `SpeechController`/`InputController` gate on `chatState == .idle` | New voice session must additionally gate against dictation being active and vice versa (per `voice-livekit-audio-session-design.md` FR-08, already confirmed: dictation available only when voice session is off) |

---

## 2. Rejected Alternatives

**Option A — Build voice entirely inside `ConciergeDemoApp` (or the host app), outside the SDK,
with its own UI.** Rejected: `ChatController`, `ChatView`, and the message-rendering views are all
internal to the `AEPBrandConcierge` module. A host app has no public way to append a bubble to the
existing transcript or to reuse `MessageListView`/`BasicMessageView`. Building a second, parallel
chat UI outside the SDK just to keep LiveKit out of the SDK would be substantially *more* work
than adding voice inside the SDK, and would visually diverge from the existing chat — the opposite
of what a fast, demoable PoC needs.

**Option B — Add the LiveKit Swift SDK as a dependency of the existing single `AEPBrandConcierge`
target/podspec, the same tier as `AEPCore`/`AEPEdgeIdentity` today (selected for this task — see
Proposal).** Simple: one dependency line in `Package.swift`, the Podfile's `lib_main`/`lib_dev`
groups, and the podspec. Trade-off: every consumer of `AEPBrandConcierge` — even one that never
enables voice — now links LiveKit + WebRTC's compiled binary, which is a non-trivial size increase
compared to today's footprint. Accepted as the pragmatic choice for a 2-4 week demo, with an
explicit follow-up requirement (Open Question OQ-1) to revisit before any release beyond the Kings
PoC.

**Option C — Split voice into a second SPM library product / CocoaPods subspec (e.g.
`AEPBrandConciergeVoice`) that depends on core `AEPBrandConcierge` and is the only place LiveKit is
linked, so non-voice consumers pay nothing.** This is the architecturally correct long-term shape —
it mirrors how large SDKs ship optional heavy capabilities — but rejected for *this* task: it
requires restructuring `Package.swift`'s single-target layout and the CocoaPods podspec into
subspecs/multiple products, which is nontrivial scaffolding with no existing precedent in this repo
(the existing optional-capability pattern, `SpeechCapturing`/`TextSpeaking`, is a protocol
injected by the host app, not a separately-compiled module — it doesn't solve the "avoid linking a
heavy binary" problem the way a subspec would). Given the timeline, this is deferred, not solved,
by this design (see Open Question OQ-1).

---

## 3. Proposal

- Add the LiveKit Swift SDK as a direct dependency of the `AEPBrandConcierge` target (Option B),
  flagged for reassessment (OQ-1) before any release beyond this PoC.
- Add a small `voice: VoicePayload?` field to `ConversationResponse`, and a new `VoicePayload`
  model mirroring web's `AudioStreaming.ts` shape (only the fields actually consumed: `type`,
  `livekitUrl`, `token` — matching web's own "narrower than the wire payload" precedent). This is
  additive and backward compatible: `ConversationResponse` has no explicit `CodingKeys`/custom
  decoder, so Swift's synthesized `Codable` conformance already tolerates the new optional key
  being absent on ordinary text-turn responses.
- Add a bootstrap method to `ConciergeChatService` that posts a `livekit-bootstrap`-typed
  conversation event on the *same* endpoint/session/auth-token/consent plumbing `streamChat`
  already uses, and resolves once `response.voice.type == "livekit_session"` arrives — mirrors
  web's reuse of `sendConversationDataEvent`/`bootstrapVoice` riding the same SSE channel as text.
- Add `VoiceSessionController` (new file, sibling to `SpeechController`), owned by
  `ChatController`, that owns the LiveKit `Room`: connect using the bootstrapped credentials,
  publish the mic track (per the AVAudioSession doc's FR-01/FR-02), subscribe to the remote audio
  track, and parse data-channel JSON into a small Swift mirror of `DataChannelMessage`. Unlike
  web's split between `VoiceTransport.ts` (raw WebRTC plumbing) and `LiveKitVoiceManager.ts` (turn
  state machine) — a split driven by browser-specific concerns (autoplay policy, ReadableStream
  feature detection) that don't exist on iOS — this PoC combines both concerns into one controller.
  Revisit the split if the combined controller becomes unwieldy (Open Question OQ-2 candidate, not
  raised as blocking now).
- `ChatController` gains `startVoiceSession()`/`stopVoiceSession()`. **v1 does not stream turn
  content live**: `VoiceSessionController` buffers transcript/turn content as it arrives, and
  `ChatController` appends it to `messages` as a plain text transcript only once the voice session
  ends — mirroring a ChatGPT-voice-mode-style UI rather than the text turn's incremental
  rendering. This is a deliberate scope choice (see ADR-011): it's the fastest working voice UI to
  ship for the first demo, not a technical conclusion that live rendering is wrong. `ChatView`/
  `MessageListView` are still reused unmodified for displaying that post-call transcript — only
  the *timing* of when content reaches `messages` changes, not the rendering path.
- The data-channel message *type names and field names* are copied verbatim from
  `LiveKitContracts.ts` (`transcript_delta`, `turn_done`, `session_notice`, `ui_payload`,
  `text_input_error`, `fullText`, `turnId`, etc.) — the worker on the other end is the same backend
  process regardless of client language, so the wire contract is not iOS's to redesign.

---

## 4. Requirements

### Functional Requirements

| ID | Requirement |
|---|---|
| FR-01 | The app shall request LiveKit connection credentials by sending a `livekit-bootstrap`-typed event over the existing CCS conversation-event channel (same endpoint, session, auth token, and consent handling as a normal chat turn), and shall not depend on any statically configured LiveKit URL/token. |
| FR-02 | The app shall decode a `response.voice` object with `type == "livekit_session"` carrying `livekitUrl` and `token` from the bootstrap response, mirroring web's `LiveKitSessionBootstrap`. |
| FR-03 | Once bootstrapped, the app shall connect a LiveKit `Room` using the returned URL/token, publish the local mic track (per the AVAudioSession doc), and subscribe to the worker's published remote audio track. |
| FR-04 | The app shall parse inbound data-channel messages into the same message-type set as web (`transcript_delta`, `turn_done`, `session_notice`, `ui_payload`, `text_input_error`), using the same field names/types, so the shared backend worker's wire contract is honored without client-specific translation. |
| FR-05 | **(Revised 2026-09-14, see ADR-011)** For the first iteration, the app shall not render voice-turn content live during the call. `VoiceSessionController` shall buffer transcript/turn content (user transcript, assistant response) as it arrives over the data channel, and the app shall append it to the existing `messages` array as a plain-text transcript only once the voice session ends — a ChatGPT-voice-mode-style UI, not a live-updating one. Live incremental rendering, and rich content (product cards/CTAs via `ui_payload`) rendered during the call, are deferred to a later iteration and added only on request (e.g. if Mehul asks for web parity after seeing the first demo) — not built into this iteration. |
| FR-06 | The app shall gate the dictation mic button and the voice-session control as mutually exclusive, consistent with `voice-livekit-audio-session-design.md` FR-08. |
| FR-07 | A failed bootstrap (network error, malformed response, no `livekit_session` payload) shall surface a user-visible error and return the app to its pre-voice-session state, using error handling of the same quality as the existing text-turn failure path (`onComplete(error)` in `streamChat`) — no special-case hardening beyond that, per the resolved understanding that prior "backend flakiness" was a stage-config issue, not a systemic bootstrap reliability problem. |

### Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | The LiveKit Swift SDK dependency shall be added at the `AEPBrandConcierge` target/podspec level (not scoped to `ConciergeDemoApp` only), consistent with Option B — see OQ-1 for the follow-up on whether this should later move to an optional module. |
| NFR-02 | The new `voice` field on `ConversationResponse` and any new voice-specific model types shall not change the decoding behavior of existing text-turn responses (additive, optional fields only). |
| NFR-03 | Data-channel message type/field names shall match `LiveKitContracts.ts` exactly (case-sensitive), since the backend worker's contract is shared across clients. |

### Out of Scope

- Android (explicitly sequenced after iOS per the pilot's plan).
- XDM/analytics payload parity between web and mobile (explicitly deferred to a separate
  documentation-only follow-up, per CR's instruction).
- Full resilience hardening (processing/reconnect watchdogs, generation-token guarding against
  stale async callbacks, optimistic-mute rollback) that `LiveKitVoiceManager.ts` implements for
  browser-specific failure modes — get the happy path working first; add hardening only for
  failure modes actually observed on-device, not speculatively.
- Deciding the long-term SDK-modularization question (Option C) — tracked as OQ-1.
- Voice-mode UI visual states/animations — separate design doc.
- Live per-turn UI during the call (incremental transcript rendering, cards/CTAs via `ui_payload`
  shown mid-call) — deliberately deferred per FR-05/ADR-011's strategy of shipping the fastest
  working UI first and adding richness only on request.

---

## 5. System Architecture

### Component mapping (web → iOS)

| Web | iOS (proposed) |
|---|---|
| `chatApi.sendConversationDataEvent` (Alloy `sendConversationEvent`) | `ConciergeChatService` bootstrap method (new), reusing `streamChat`'s URL/session/payload plumbing |
| `voiceCommands.ts` (`bootstrapVoice`, mic pre-acquire, transport singleton) | `VoiceSessionController` (new) |
| `VoiceTransport.ts` (Room, track publish, data-channel send/receive, remote audio) | `VoiceSessionController` (combined, see Proposal) |
| `LiveKitVoiceManager.ts` (turn state machine, barge-in, watchdogs) | `VoiceSessionController` (combined for PoC; state machine subset only — no watchdogs yet, see Out of Scope) |
| `LiveKitContracts.ts` (wire types) | New Swift types in `Models/Voice/` (new group), field-for-field mirror |
| React/DOM chat UI consuming `StreamingCallbackData` | Existing `ChatController.messages` / `ChatView` (reused, not duplicated) |

### Data flow for one voice turn

```
User taps voice-mode control (dictation control is hidden/disabled per FR-06)
   │
   ▼
ChatController.startVoiceSession()
   │
   ▼
VoiceSessionController.bootstrap()
   │  → ConciergeChatService posts { type: "livekit-bootstrap", publishMic: true } as a
   │    conversation event, same endpoint/session/auth as streamChat
   │
   ▼
SSE response decodes into ConversationPayload.response.voice
   (type == "livekit_session", livekitUrl, token)
   │
   ▼
VoiceSessionController.connectRoom(livekitUrl, token)
   │  → LiveKit Room.connect(); publish mic track (AVAudioSession config from the
   │    companion design doc); subscribe to worker's remote audio track
   │
   ▼
Data channel messages arrive (transcript_delta / turn_done / session_notice / ui_payload)
   │  → parsed into Swift DataChannelMessage mirror
   │
   ▼
ChatController appends/updates a Message in `messages`, updates `chatState`
   (same shape as streamAgentResponse's onChunk/onComplete handling)
   │
   ▼
ChatView/MessageListView render the turn — no new rendering code needed
```

---

## 6. Detailed Design

### 6.1 Dependency addition (implemented 2026-09-15 — see PR #159)

Resolved, not via the pattern originally sketched above. Concretely:

- **`Package.swift`**: `.package(url: "https://github.com/livekit/client-sdk-swift.git", .upToNextMajor(from: "2.17.0"))`
  added to `dependencies`, and `.product(name: "LiveKit", package: "client-sdk-swift")` added to
  the `AEPBrandConcierge` target's `dependencies`. Also required adding `.macOS(.v10_15)` to
  `platforms:` (LiveKit's own manifest declares that minimum; SPM requires a consistent minimum
  across the whole graph even though this SDK doesn't ship a macOS product).
- **LiveKit is NOT added via CocoaPods**, unlike the original plan. CocoaPods trunk stopped
  publishing `LiveKitClient` at 2.0.18 (last published 2025-02-12); every version after that,
  including our required 2.17.0, depends on `LiveKitUniFFI`, which was **never published to
  CocoaPods trunk at all**. This isn't a staleness issue to work around — it's a hard resolution
  failure, confirmed via `pod install`. `Podfile` and `AEPBrandConcierge.podspec` are left without
  a LiveKit entry, each with a comment explaining why.
- Instead, LiveKit is added as a **native Xcode Swift Package dependency** directly on the
  `AEPBrandConcierge` and `ConciergeDemoApp` targets inside `AEPBrandConcierge.xcodeproj` (added
  programmatically via the `xcodeproj` Ruby gem — CocoaPods' own dependency — rather than by hand
  editing `project.pbxproj`, which is fragile to edit as text). This is a supported way to mix SPM
  packages into a CocoaPods-managed Xcode project, and lets `AEPBrandConcierge`'s own source
  (compiled within this repo's workspace) target LiveKit 2.17.0 regardless of the CocoaPods gap.
- **Consequence — CocoaPods distribution of this SDK's voice feature is currently broken for
  external consumers.** Since `AEPBrandConcierge`'s compiled source needs LiveKit 2.17.0 symbols,
  and CocoaPods can only ever supply 2.0.18 (see above), an external app that installs
  `AEPBrandConcierge` via CocoaPods (rather than SPM) cannot get a working voice feature at all.
  This was a deliberate, confirmed trade-off (not an oversight) — accepted for this PoC per the
  same "ship the fastest thing, don't solve distribution-channel parity yet" reasoning as OQ-1
  below and the ADR-011 strategy pivot. Revisit before any release beyond this demo.
- **Also required removing `APPLICATION_EXTENSION_API_ONLY` from the `AEPBrandConcierge` target.**
  CocoaPods propagates that setting to dependency pod targets reachable from an extension-safe
  target; LiveKit's camera-capture code (`LKRTCCameraVideoCapturer`) is annotated
  `unavailable` in app extensions and fails to compile under it. We don't use LiveKit's
  camera/video features at all (audio-only), but the code is still part of the compiled module.
  Removing the flag means this SDK can no longer declare itself safe for use inside an app
  extension (widget, share extension, etc.) — confirmed as an acceptable trade-off, not
  independently re-litigated here.
- Version chosen: **2.17.0**, not the CocoaPods-resolvable 2.0.18, after comparing the two —
  audio-session-relevant fixes landed between them that matter for this feature specifically
  (see `voice-livekit-audio-session-design.md` OQ-1 for details and links).

### 6.2 Wire model additions

New file `Models/Network/VoicePayload.swift`:

```swift
/// Mirrors web's `VoicePayload` (AudioStreaming.ts) — narrower than the full wire
/// shape; only the fields the client actually consumes.
public struct VoicePayload: Codable {
    public let type: String // "livekit_session" | "done" | ... (other values ignored)
    public let livekitUrl: String?
    public let token: String?
}
```

`ConversationResponse.swift` — add one field:

```swift
public struct ConversationResponse: Codable {
    public let message: String
    public let promptSuggestions: [String]?
    public let multimodalElements: MultimodalElements?
    public let sources: [Source]?
    public let linkHints: [LinkHint]?
    public let state: String?
    public let feedback: ConversationFeedbackInfo?
    public let voice: VoicePayload?   // new
}
```

**Behavioral analysis for unchanged code:** `ConversationResponse` has no custom `init(from:)`/
`CodingKeys`, so Swift's synthesized `Decodable` conformance already decodes "extra key present,
new field absent" and "new field present, old payload shape otherwise unchanged" correctly with no
further changes — every existing call site that decodes a text-turn `ConversationResponse` keeps
working unmodified.

New `Models/Voice/` group, mirroring `LiveKitContracts.ts` type-for-type (names kept identical to
the TypeScript source for cross-repo readability): `DataChannelMessage`, `TranscriptDeltaData`,
`TurnDoneData`, `UiPayloadData`, `SessionNoticeData`, `EndReason`, `TextInputErrorMessage`. Parsing
logic (`parseDataChannelMessage` equivalent) lives alongside, in `VoiceSessionController` or a
small dedicated parser file if it grows — decide when writing the code, not preemptively split
here.

### 6.3 Bootstrap request

New method on `ConciergeChatService`, sibling to `streamChat`:

```swift
func bootstrapVoiceSession(token: String?,
                            onBootstrap: @escaping (LiveKitSessionBootstrap) -> Void,
                            onComplete: @escaping (ConciergeError?) -> Void)
```

Reuses `createUrl()` (same endpoint/session/conversation query items) and the same
auth-token/consent attachment as `createChatPayload`, but with a new payload-building method
(e.g. `createVoiceBootstrapPayload(token:)`) whose `conversation` object carries
`{ type: "livekit-bootstrap", publishMic: true }` in place of `message` — mirroring
`voiceCommands.ts`'s `eventData: { type: "livekit-bootstrap", publishMic }`. Streaming/decoding
reuses the existing `URLSessionDataDelegate` chunk-handling path; the only new logic is checking
`payload.response?.voice?.type == "livekit_session"` instead of `payload.response?.message`.

**Debug-only `USE_TEMPS` note:** `ConciergeChatService` has a `USE_TEMPS`/`TEMP_*` debug shortcut
that hardcodes an endpoint/ecid/surface for local testing (see `createUrl()`/`createChatPayload`).
The bootstrap method must be tested against both paths — confirm whether `USE_TEMPS` should also
short-circuit bootstrap, or whether voice testing requires it to be `false` (real Kings stage
config) as already established for text-turn testing (Open Question OQ-3).

### 6.4 `VoiceSessionController`

New file `AEPBrandConcierge/Sources/Controllers/VoiceSessionController.swift`, sibling to
`SpeechController`. Owns:

- The LiveKit `Room` instance, connect/disconnect lifecycle (mirrors `VoiceTransport.connectRoom`/
  `disconnectRoom`).
- Mic track publish/mute (delegates AVAudioSession specifics to the configuration established in
  the companion design doc — this controller does not itself call `AVAudioSession` APIs beyond
  what that doc specifies).
- Data-channel receive → parse → callback, mirroring `LiveKitVoiceManager`'s
  `handleRawDataChannelMessage`/`handleDataChannelMessage`, but only the subset needed for a
  working demo (see Out of Scope — no barge-in/watchdog logic yet unless trivial to include).
- A small state enum mirroring `VoiceConversationState` (`idle`/`connecting`/`listening`/
  `processing`/`responding`) sufficient to drive UI state — full parity with web's state machine
  (barge-in detection, mute-reconciliation) is explicitly deferred.

### 6.5 `ChatController` wiring

- New `private let voiceSessionController: VoiceSessionController` property, constructed alongside
  `speechController` in `init`.
- New `startVoiceSession()`/`stopVoiceSession()` methods, analogous to `startRecording()`/
  `completeMic()`. **Per the FR-05 revision, these do not stream content into `messages` turn by
  turn.** `VoiceSessionController` accumulates transcript/turn text internally as data-channel
  messages arrive (user transcript deltas, assistant `turn_done` text) for the whole voice
  session. Only on `stopVoiceSession()` does `ChatController` append the accumulated exchange to
  `messages` as one or more plain `Message` entries — a lightweight, structurally simpler version
  of `streamAgentResponse`'s accumulation pattern, without the `accumulatedContent`/
  `streamingMessageIndex` mid-stream mutation it needs for live rendering.
- `micEnabled`/`composerEditable`/`sendEnabled` computed properties gain a voice-session-active
  check (mirrors `chatState == .processing` gating today), enforcing FR-06.
- `chatState` still reflects that a voice session is in progress (so text input stays gated per
  FR-06), even though no message content appears until the session ends — the state machine and
  the content-rendering timing are independent concerns.

### 6.6 Test plan

- Unit: `createVoiceBootstrapPayload` JSON shape (mirrors existing `createChatPayloadTests`-style
  coverage for `createChatPayload`); `ConversationResponse` decode with and without a `voice` key
  present (regression-proves NFR-02); data-channel message parsing for each of the five message
  types plus malformed/unknown-type inputs (mirrors `voiceStreamingUtils.test.ts` coverage).
- Manual/integration on the Kings stage environment (now that config is resolved): full bootstrap
  → connect → speak → hear a response → turn renders in the transcript → end session → dictation
  becomes available again (ties to the AVAudioSession doc's §8 handoff scenario).

---

## 7. What Does NOT Change

| Component | Reason unchanged |
|---|---|
| `ConciergeChatService.streamChat` (text-turn path) | Bootstrap is a new sibling method reusing the same primitives (URL, session, payload helpers) — the text-turn method itself is untouched |
| `SpeechCapturer`/`TextSpeaker`/dictation flow | Separate, coexisting capability per the confirmed FR-08 decision — not modified, only gated against concurrently with voice |
| `ChatView`/`MessageListView`/message rendering views | Reused as-is — voice turns produce ordinary `Message` values, no new rendering path |
| `AEPCore`/`AEPEdgeIdentity` config/identity plumbing | Unrelated to this module |
| Theming (`Theme/`) | Out of scope |

---

## 8. Verification Criteria

| Scenario | Expected Result |
|---|---|
| Start voice session against Kings stage | Bootstrap succeeds, `Room` connects, mic publishes, remote audio subscribes |
| Speak a question | No transcript appears in `messages` yet (v1 defers live rendering per FR-05); TTS audio plays as the worker responds over the connected `Room` |
| Worker responds | Assistant reply is heard as TTS over the `Room`; its text is buffered internally, not yet shown |
| Bootstrap fails (e.g. bad config, network down) | User-visible error, same quality as an existing text-turn failure; app returns to idle, no stuck "connecting" state |
| End voice session | `Room` disconnects, `AVAudioSession` deactivates per the companion doc, the buffered exchange appears in `messages` as a plain transcript, dictation mic button becomes available again |
| Existing text-turn flow, no voice session ever started | Behaves identically to today — `ConversationResponse` decode unaffected by the new optional `voice` field |

---

## 9. Implementation Plan

### Phase 1 — Wire model + bootstrap (no LiveKit yet)

| # | Task | Notes |
|---|---|---|
| 1.1 | Add `VoicePayload` + `ConversationResponse.voice` | Unit-testable without any LiveKit dependency |
| 1.2 | Add `createVoiceBootstrapPayload`/`bootstrapVoiceSession` to `ConciergeChatService` | Verify against real Kings stage response shape once backend confirms `livekit-bootstrap` support for iOS's surface |

### Phase 2 — LiveKit dependency + Room connection

| # | Task | Notes |
|---|---|---|
| 2.1 | ✅ Done (PR #159) — Add LiveKit 2.17.0 as a native Xcode SPM package dependency on `AEPBrandConcierge`/`ConciergeDemoApp`; removed `APPLICATION_EXTENSION_API_ONLY` | See §6.1 for the full rationale (CocoaPods can't resolve 2.17.0 at all) |
| 2.2 | `VoiceSessionController`: connect, mic publish (using the companion doc's audio-session policy), remote audio subscribe | |

### Phase 3 — Data channel + UI wiring

| # | Task | Notes |
|---|---|---|
| 3.1 | Data-channel message types + parser | Field/type names must match `LiveKitContracts.ts` exactly |
| 3.2 | `ChatController.startVoiceSession/stopVoiceSession`; `VoiceSessionController` buffers transcript/turn text; append as a plain transcript to `messages` on session end | Per FR-05 — no live/incremental wiring in this phase |
| 3.3 | Mic/dictation mutual-exclusion gating | Enforces FR-06 |

### Deferred

- Barge-in detection, processing/reconnect watchdogs, optimistic mute-rollback (full
  `LiveKitVoiceManager.ts` parity) — add only if the happy-path demo surfaces a real need.
- SDK modularization (OQ-1).
- Live per-turn UI during the call (incremental transcript, cards/CTAs) — per FR-05/ADR-011, add
  only if requested after the first demo.

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Adding LiveKit to the core `AEPBrandConcierge` target increases binary size for all consumers, including ones that never use voice | High (certain) | Medium | Accepted trade-off for the PoC timeline (Option B); tracked as OQ-1 for resolution before a real release |
| **(Materialized 2026-09-15)** CocoaPods cannot resolve LiveKit 2.17.0 at all (trunk stops at 2.0.18; 2.0.18+'s `LiveKitUniFFI` dependency was never published to trunk) — this is worse than the binary-size risk above: it's not a size trade-off but a hard resolution failure. LiveKit is added via a native Xcode SPM package dependency instead (§6.1), which fixes this repo's own build but means CocoaPods-based external consumers of `AEPBrandConcierge` cannot get a working voice feature at all right now | Certain | High for CocoaPods-based external adopters (none exist yet for this unreleased feature) | Confirmed acceptable for this PoC (ADR-011); must be resolved (e.g. wait for LiveKit to resume CocoaPods publishing, or drop CocoaPods distribution for this SDK, or vendor a private podspec) before any release beyond the Kings demo — folded into OQ-1 |
| Data-channel field/type names drift from `LiveKitContracts.ts` over time (two independently maintained clients) | Medium | High (breaks interop with the shared backend worker) | Field/type names copied verbatim in this design (§6.2); flag any web-side contract change to the iOS team and vice versa |
| `ConversationResponse`'s new `voice` field interacts badly with an existing decode edge case (e.g. a custom decoder elsewhere assuming a fixed key set) | Low | Medium | NFR-02 test case (§6.6) exercises decode with and without the key |
| Bootstrap and Room-connection error paths diverge in quality/coverage from each other (bootstrap well-handled, Room-connect failures not) | Medium | Medium | FR-07 sets bootstrap error handling to existing-text-turn quality; Room-connect failure handling should get the same bar in Phase 2, not skipped |

---

## 11. Open Questions

| # | Question | Owner |
|---|---|---|
| OQ-1 | Should LiveKit remain a direct dependency of `AEPBrandConcierge` past this PoC, or move to an optional SPM product/CocoaPods subspec (Rejected Alternative C) before any broader release? **Updated (2026-09-15):** this is no longer just a binary-size question — CocoaPods cannot resolve LiveKit 2.17.0 at all (see §6.1, Risks), so CocoaPods-based external adopters currently get no working voice feature regardless of the optional-module question. Needs a real decision (resume-CocoaPods-publishing dependency on LiveKit upstream, drop CocoaPods distribution for this SDK, or vendor a podspec) before any release beyond this PoC. | Anshika/Jose, iOS team |
| OQ-2 | Should `VoiceSessionController` be split into a transport layer and a turn-state-machine layer (mirroring web's `VoiceTransport`/`LiveKitVoiceManager` split) once real device testing is underway, or does the combined PoC version stay maintainable? | iOS team, revisit after Phase 2/3 |
| OQ-3 | Does the `USE_TEMPS` debug shortcut in `ConciergeChatService` need an equivalent for voice bootstrap testing, or should voice testing always require real Kings stage config (as already established for text)? | iOS team |
| OQ-4 | ~~Does the demo require sources/multimodal-element/feedback-eligibility parity for voice turns, or is a plain streaming text bubble sufficient for the initial demo to Mehul?~~ **Resolved (2026-09-14, see ADR-011):** no — v1 ships a plain post-call transcript with no live rendering or rich content at all (FR-05); parity is added later only if Mehul asks for it after seeing the first demo. | — resolved |
| OQ-5 | If/when a later iteration adds live rendering (per Mehul's feedback), does it reuse `streamAgentResponse`'s incremental accumulation pattern as originally planned, or does the buffered v1 design make a different approach easier? | iOS team, revisit if/when triggered |

---

## 12. Implementation Outcome (as-built, 2026-09-16)

Phases 1–3 are implemented and a **full voice loop runs on a real device** against Kings stage (bootstrap → Room connect → speak → live transcript → TTS → barge-in → end). Draft PRs #160 (Phase 1), #161 (Phase 2, stacked on #159), #162 (Phase 3 — integration branch merging #160 into the #161 stack). Device bring-up surfaced several corrections to this design that were **not knowable from the design phase**; they are recorded here rather than silently rewriting the sections above, and cross-checked against the working stage voice client `bc-voice-test/sdk-load`.

### 12.1 Bootstrap endpoint (corrects §3, §5, §6.3)

The voice bootstrap does **not** reuse the text-turn endpoint. It POSTs to **`/brand-concierge-voice/conversations`**, not `/brand-concierge/conversations`. `ConciergeChatService.createUrl(path:)` was parameterized so the bootstrap uses the voice path while `streamChat`/`sendFeedback` keep the text path. Sending the bootstrap to the text endpoint returns a stream that closes with no `livekit_session` payload (the first on-device failure mode observed).

### 12.2 Bootstrap payload shape (corrects §6.3)

The `livekit-bootstrap` discriminator rides in **`conversation.data.type`**, i.e. `conversation.data = { "type": "livekit-bootstrap" }` — the same `data` slot the text turn uses for its `{ type: "auth" }` part — **not** a top-level `conversation.type`, and **no `publishMic`** field. Voice bootstrap authenticates via the Edge identity/ECID, so the app auth token is **not** attached to the bootstrap payload. (The design's originally-sketched `{ type, publishMic }` at the conversation top level was wrong.)

### 12.3 FR-05 revised again: live rendering was implemented (resolves OQ-5)

After the buffered v1 loop worked on device, live per-turn rendering was added on request. It was cheap because the buffered v1 had already solved parsing, turn detection, and threading — so OQ-5 resolves in favor of "the buffered design made the live version easy." `VoiceSessionController` emits `onTranscriptUpdate(role, runningText, isFinal)`; `ChatController.applyVoiceTranscriptUpdate` updates the in-progress user/assistant bubble in place. Key parsing nuance confirmed on the wire: **user STT arrives as cumulative snapshots** (replace the bubble text), while **assistant `text_delta` is incremental** (append), finalized by `turn_done.fullText`. Rich `ui_payload` (cards/CTAs) is still deferred.

### 12.4 Mic control / barge-in (interacts with the AVAudioSession doc §6.3)

Half-duplex mic management matches web: mute the mic only during the brief *processing* gap (user-final → assistant starts responding) and keep it **live during the assistant's response**, relying on acoustic echo cancellation to keep the TTS out of the captured signal — which is what makes **barge-in** work. An initial implementation that muted for the whole assistant turn suppressed barge-in and was corrected. On-device (2026-09-16): echo (TTS-into-input) does not recur and barge-in works. Barge-in *polish* (pausing/ducking the remote TTS on interrupt, as web's `pauseRemoteAudio()` does) is still deferred.

### 12.5 Config & network prerequisites (device)

- **Datastream + IMS org must both be correct.** The app must be provisioned with the Kings voice datastream *and* the matching IMS org (the ECID must be minted under the datastream's org). A stale/incorrect datastream returns `Invalid datastream ID` from Edge. (Resolves OQ-3 in practice: real Kings stage config is required; there is no `USE_TEMPS` shortcut for voice.)
- **The LiveKit host is internal (corp).** Bootstrap returns a `.corp.ethos…` LiveKit host (e.g. `bc-livekit-stage.corp.ethos270-stage-va7.ethos.adobe.net`). The public Edge bootstrap succeeds off-corp, but the WebRTC `Room` connection (`wss://…/rtc`) **requires the device to be on the corp network / VPN**, or it times out. This was the second on-device blocker.
