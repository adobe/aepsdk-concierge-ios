# LiveKit Voice — AVAudioSession Management — Requirements & Design

**Status:** Draft — pending team review
**Scope:** Audio session / audio routing concerns only, for the new LiveKit/WebRTC-based voice
feature in `AEPBrandConcierge`. Does **not** cover the LiveKit `Room` connection lifecycle,
data-channel turn state machine, or UI — those are separate design docs.
**Audience:** iOS team (implementation + review) and `brand-concierge-web-agent` developers
(context/parity review). Web readers do not need to read Swift to follow this document; every
iOS-specific decision is cross-referenced against the equivalent concern in `VoiceTransport.ts`.

---

## 1. Background & Problem Statement

### Current state

`AEPBrandConcierge` has exactly one existing voice code path today, and it is not the one this
feature builds on:

- `SpeechCapturer.swift` does on-device STT via `SFSpeechRecognizer`, and `TextSpeaker.swift` does
  on-device TTS via `AVSpeechSynthesizer`. The recognized text and the text-to-speak text both
  travel as plain strings over the existing SSE chat turn (`ConciergeChatService.streamChat`) —
  there is no raw audio streaming, and mic capture and audio playback never happen at the same
  time.
- `SpeechCapturer.configureAudioSessionForCapture()` configures the shared `AVAudioSession` as:
  `setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])`,
  `setMode(.measurement)`, `setActive(true, options: .notifyOthersOnDeactivation)`,
  `setAllowHapticsAndSystemSoundsDuringRecording(true)`. `.measurement` mode is chosen there
  specifically to **turn off** the session's built-in AGC/echo-cancellation/noise-suppression,
  because `SpeechCapturer` does its own manual gain-compensated RMS silence detection on the raw
  mic signal — see `gainCompensatedRMS`/`calibratedNoiseFloor` and the comments explaining why an
  AGC'd signal would break that calibration.
- `SpeechCapturer` owns an `AVAudioSession.routeChangeNotification` observer and, on a hardware
  route change (`.newDeviceAvailable` / `.oldDeviceUnavailable`), tears down and rebuilds its
  `AVAudioEngine` + recognition tap, because `AVAudioEngine` caches stale hardware format
  (sample rate, channel count) across a route change.
- Nothing today configures `AVAudioSession` for **full-duplex** use (simultaneous mic capture +
  audio playback), and nothing today integrates with a WebRTC audio stack.

### Gap

The new voice feature (full_cycle: a server-side worker does STT → LLM → TTS; the client only
publishes a raw mic track and subscribes to a raw remote audio track over LiveKit/WebRTC, per
`VoiceTransport.ts`) requires:

1. Simultaneous mic capture and remote-audio playback in the same session, with echo cancellation
   on — the mic must not pick up the device's own speaker output.
2. Coordinating `AVAudioSession` configuration with the LiveKit iOS SDK, which is built on
   WebRTC's audio device module and has its own expectations about who configures the shared
   session and when.
3. Handling interruptions (phone calls, Siri, other apps) and route changes (headset
   plug/unplug, AirPods) — concerns that don't exist in the same form on web, where the browser
   and OS handle device selection and interruption transparently.
4. A clean handoff story with the existing `SpeechCapturer` session type, so that if a host app
   somehow exercises both voice paths across app lifetime, neither leaves `AVAudioSession` in a
   state that breaks the other.

None of this exists today; this document proposes how to build it.

### Comparison table

| Scenario | Current Behavior (SpeechCapturer, text-turn voice) | Desired Behavior (LiveKit full-duplex voice) |
|---|---|---|
| Mic + playback concurrency | Never concurrent — capture ends (`endCapture`), THEN `TextSpeaker` plays a reply | Concurrent by design — user can barge in while TTS is playing |
| Echo cancellation / AGC | Deliberately OFF (`.measurement` mode) so manual RMS silence detection isn't skewed | Must be ON — mirrors web's `AUDIO_CAPTURE_DEFAULTS = { echoCancellation: true, noiseSuppression: true, autoGainControl: true }` |
| Who owns `AVAudioSession` config | `SpeechCapturer` calls `setCategory`/`setMode`/`setActive` directly | LiveKit's audio session manager should own it; app code should configure policy, not fight it with direct calls (see §2, §6.3) |
| Route change (e.g. AirPods connect) | `SpeechCapturer` observes `routeChangeNotification` itself and rebuilds its own `AVAudioEngine` tap | LiveKit's WebRTC audio device module re-negotiates the audio unit's format on route change internally; app-level handling is limited to policy (preferred output) and UI feedback, not tap rebuilding |
| Session teardown | `endCapture()` stops the engine; audio session is left active for `TextSpeaker`'s playback-only use | Voice-session end must deactivate the session (mirrors `VoiceTransport.disconnectRoom()` releasing the mic track and remote `<audio>` element) so a subsequent chat-only or `SpeechCapturer` session starts from a clean state |
| Interruption (incoming call) | Not explicitly handled — `AVAudioEngine`/recognition task typically errors out and `abortStreamingCapture` fires | Must explicitly pause (mute local track, pause remote playback) on `.began` and offer resume on `.ended` with `.shouldResume`, since a live two-way call-like session is more disruptive to interrupt silently |

---

## 2. Rejected Alternatives

**Option A — Reuse `SpeechCapturer.configureAudioSessionForCapture()` as-is.** Rejected: it sets
`.measurement` mode, which disables the session's built-in echo cancellation and AGC. In a
full-duplex session where the remote (TTS) track is playing out of the device speaker/receiver
while the mic is live, this would let the remote audio bleed back into the mic and either
trigger constant false barge-in detection or produce an audible echo for the person on the other
end. `SpeechCapturer`'s silence-detection math also has no reason to exist in the LiveKit path
(the server-side worker does VAD/turn-taking, not the client), so there's no counter-motivation
to keep AGC off.

**Option B — Let the app (host app / SwiftUI layer) own all `AVAudioSession` configuration
directly, and treat LiveKit purely as a "dumb" media transport.** Rejected: LiveKit's iOS SDK is
built on Google's WebRTC, whose audio device module (`RTCAudioSession` under the hood, wrapped by
LiveKit's `AudioManager`) actively manages the shared `AVAudioSession` whenever a `Room` has a
published or subscribed audio track — it calls `setCategory`/`setMode`/`setActive`/
`overrideOutputAudioPort` itself in response to track publish/subscribe and route-change events.
Two independent, uncoordinated owners calling these APIs on the same shared session is a
well-documented source of iOS WebRTC bugs (silent mic after a category fight, crashes on
`setActive(false)` while WebRTC still holds the session active, lost audio after backgrounding).
Fighting the SDK for ownership was rejected as high-risk for a PoC.

**Option C — Adopt LiveKit's audio session manager as the sole owner of session activation, and
configure it through the hooks the SDK exposes (selected).** LiveKit's `AudioManager` (the
client-side wrapper around WebRTC's audio session handling) is designed to be configured, not
bypassed. This gives us the full-duplex, echo-cancelled configuration we need (§4, FR-02) without
contesting ownership of `setActive` timing with WebRTC's own engine. **Verified against LiveKit
2.17.0 (the version actually pinned — see `voice-livekit-connection-bootstrap-design.md` §6.1) on
2026-09-15, resolving Open Question OQ-1:** the mechanism this design originally assumed,
`AudioManager.shared.customConfigureAudioSessionFunc`, exists but is **deprecated** in 2.17.0 in
favor of `AudioManager.shared.set(engineObservers:)` (an `AudioSessionEngineObserver`-based
mechanism) for dynamic/reactive configuration. For our use case — a fixed policy applied once,
not reactive reconfiguration — the simpler, non-deprecated fit is the declarative
`AudioManager.shared.sessionConfiguration: AudioSessionConfiguration?` property (see §6.1 for the
concrete value). Both `sessionConfiguration` and `customConfigureAudioSessionFunc` are ignored if
the other is set — pick one, not both.

---

## 3. Proposal

- Treat `AVAudioSession` category/mode/options as **policy we hand to LiveKit's `AudioManager`**,
  not state we imperatively set ourselves — LiveKit remains the sole caller of
  `setActive`/`setCategory` while a voice `Room` exists.
- Default configuration: LiveKit's own `.playAndRecordSpeaker` preset — `.playAndRecord` category,
  `.videoChat` mode (not `.voiceChat`; see §6.1 for why LiveKit's own maintainers use `.videoChat`
  for the speaker-routed case), `[.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay,
  .defaultToSpeaker]` options — all still full-duplex/echo-cancelled per WebRTC's voice-processing
  I/O, matching web's `echoCancellation: true` (§6.1, revised 2026-09-15 after checking the actual
  pinned SDK version).
- The new voice controller (sibling to `SpeechController`, not built on it) owns telling LiveKit
  when to activate/deactivate the session — i.e., it starts/stops in step with `Room` connect/
  disconnect, the same lifecycle boundary `VoiceTransport.connectRoom()`/`disconnectRoom()` use
  on web.
- Interruptions and route changes are handled by observing the same system notifications
  `SpeechCapturer` already uses as a pattern (`AVAudioSession.interruptionNotification`,
  `.routeChangeNotification`), but the *response* differs: mute/pause the LiveKit track and
  surface UI state, rather than rebuilding an `AVAudioEngine` tap (LiveKit's WebRTC audio unit
  handles its own re-negotiation on route change).
- Background audio is explicitly out of scope for this PoC unless product requires it (Open
  Question OQ-2) — the design assumes foreground-only voice sessions for now, which simplifies
  session lifecycle significantly.

---

## 4. Requirements

### Functional Requirements

| ID | Requirement |
|---|---|
| FR-01 | The voice session shall configure the shared `AVAudioSession` for full-duplex audio (`.playAndRecord`) with the device's built-in echo cancellation enabled, so that local mic capture is not corrupted by concurrent remote (TTS) playback. |
| FR-02 | The voice session shall enable acoustic echo cancellation, noise suppression, and automatic gain control equivalent in effect to web's `AUDIO_CAPTURE_DEFAULTS` (`echoCancellation: true`, `noiseSuppression: true`, `autoGainControl: true`), via a full-duplex-capable session mode (`.videoChat`, per §6.1 — WebRTC's voice-processing I/O provides AEC/NS/AGC regardless of the `.videoChat`/`.voiceChat` mode choice) and/or LiveKit's audio processing configuration. |
| FR-03 | The voice session shall route audio to the speaker by default (`.defaultToSpeaker`) and support Bluetooth HFP/A2DP headsets and AirPlay via LiveKit's own `.playAndRecordSpeaker` option set (`[.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]`, §6.1 — updated 2026-09-15, resolving OQ-3), matching current in-app expectations from `SpeechCapturer` for the speaker/HFP case and extending beyond it per LiveKit's own tuning. |
| FR-04 | On an `AVAudioSession.interruptionNotification` with reason `.began` (e.g. incoming call, Siri), the voice session shall mute the local mic track and pause remote audio playback without tearing down the LiveKit `Room` connection. |
| FR-05 | On the corresponding interruption `.ended` with `.shouldResume` set, the voice session shall restore mic/playback to their pre-interruption state; without `.shouldResume`, it shall leave the session paused and require explicit user action to resume. |
| FR-06 | On a hardware route change (`.newDeviceAvailable`/`.oldDeviceUnavailable`, e.g. AirPods connect/disconnect, wired headset plug/unplug), the voice session shall allow LiveKit's WebRTC audio unit to renegotiate format/routing without the app rebuilding its own capture pipeline (contrast with `SpeechCapturer`'s manual `AVAudioEngine` rebuild, which does not apply here — see §6.2). |
| FR-07 | When the voice session ends (user stops voice mode, or the `Room` disconnects), the app shall deactivate the shared `AVAudioSession` (via LiveKit's normal teardown, not a direct competing `setActive(false)` call) so a subsequent `SpeechCapturer`-based session or plain audio-free chat session starts from a clean, inactive-session state. |
| FR-08 | Starting a new voice session while a `SpeechCapturer` session is active (or vice versa) shall not be supported concurrently; the app shall treat these as mutually exclusive foreground audio sessions. **Confirmed product decision (not a PoC-only simplification):** mirroring the web client, the existing dictation mic control stays available and functional whenever the LiveKit voice session is off, and is gated off while a voice session is on. The dictation button is not replaced by the voice control — the two coexist as separate, mutually exclusive entry points (see Out of Scope). |

### Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | Audio session configuration must not directly call `AVAudioSession.sharedInstance().setActive(...)` from Brand Concierge code while a LiveKit `Room` with an audio track is connected — LiveKit's `AudioManager` must be the sole caller during that window, to avoid session-ownership contention (see Rejected Alternative B). |
| NFR-02 | The chosen category/mode/options must be verified on at least: built-in mic + speaker, wired headset, and one Bluetooth HFP device, before this design is considered validated (see §8 Verification Criteria). |
| NFR-03 | ✅ Done (2026-09-15): the pinned LiveKit SDK version (2.17.0) was checked against the audio-session configuration mechanism this design assumes (Open Question OQ-1) — resolved to the `sessionConfiguration`/`AudioSessionConfiguration` API, not the originally-assumed (and now-deprecated) `customConfigureAudioSessionFunc`. See §2 Option C and §6.1. |

### Out of Scope

- The LiveKit `Room` connection state machine, data-channel message contract, and turn-taking
  logic (separate design doc, analogous to `LiveKitVoiceManager.ts`).
- Background audio / voice sessions continuing while the app is backgrounded (Open Question
  OQ-2) — if required, it needs its own `UIBackgroundModes` + session-category follow-up design.
- Concurrent operation of `SpeechCapturer`-based voice and LiveKit-based voice in the same
  session — they are treated as mutually exclusive (FR-08).
- CallKit integration (treating the voice session as a system-level call) — not assumed to be a
  requirement; would be a separate, larger design if product asks for it later.
- Any change to `TextSpeaker`/`SpeechCapturer` internals — they are untouched by this feature
  (see §7).

---

## 5. System Architecture

### Audio session ownership, before vs. after

```
Today (SpeechCapturer, text-turn voice):

  SpeechCapturer  ──owns──▶  AVAudioSession  ──owns──▶  AVAudioEngine (STT tap)
       │
       └── TextSpeaker ──uses (implicitly active session)──▶ AVSpeechSynthesizer


New (LiveKit full-duplex voice):

  New voice controller (sibling to SpeechController)
       │
       │  start()/stop() bracket the Room lifecycle
       ▼
  LiveKit Room  ──owns (via AudioManager)──▶  AVAudioSession  ──owns──▶  WebRTC audio unit
       │                                                                (mic capture + speaker/
       │                                                                 receiver playback,
       │                                                                 AEC/NS/AGC built in)
       └── app supplies: category/mode/options policy, interruption/route-change UI reactions
           (does NOT call setActive/setCategory directly while Room is connected)
```

### Data/control flow for one voice session (audio-session-relevant events only)

```
User starts voice mode
   │
   ▼
New voice controller: request mic permission (AVAudioApplication / AVAudioSession record permission)
   │
   ▼
New voice controller: configure LiveKit AudioManager policy (category/mode/options) — one-time,
   idempotent; does not itself activate the session
   │
   ▼
LiveKit Room.connect() + local track publish
   │
   ▼
LiveKit AudioManager activates AVAudioSession (.playAndRecord/.videoChat, see §6.1) ── mirrors web's
   `room.connect()` + `publishTrack()` in VoiceTransport.connectRoom()
   │
   ├─▶ AVAudioSession.interruptionNotification (.began) → mute local track, pause remote audio
   │        (.ended, shouldResume) → unmute/resume
   │
   ├─▶ AVAudioSession.routeChangeNotification → no app-level pipeline rebuild (contrast
   │        SpeechCapturer); update "current output route" UI state only if needed
   │
   ▼
User stops voice mode / Room disconnects
   │
   ▼
LiveKit AudioManager deactivates AVAudioSession as part of Room teardown ── mirrors web's
   `disconnectRoom()` releasing the mic track + removing the remote <audio> element
```

---

## 6. Detailed Design

### 6.1 Category, mode, and options

**Revised 2026-09-15** after checking LiveKit 2.17.0's actual `AudioSessionConfiguration` presets
(`Sources/LiveKit/Types/AudioSessionConfiguration.swift`) — LiveKit ships its own tuned presets for
exactly this kind of full-duplex voice use case, and their own code comments document a real,
observed WebRTC bug our original assumption would have walked into. Use their preset rather than
hand-rolling the tuple:

- **Category:** `.playAndRecord` — unchanged from the original plan and from `SpeechCapturer`;
  required for simultaneous input+output. Matches LiveKit's own `playAndRecordSpeaker`/
  `playAndRecordReceiver` presets.
- **Mode:** `.videoChat`, **not** `.voiceChat` as originally planned. LiveKit's own
  `playAndRecordSpeaker` preset (the one with `.defaultToSpeaker`, which is what we want per FR-03)
  uses `.videoChat` mode, not `.voiceChat` — their code comment explains why: "iOS may rewrite the
  mode when Voice Processing I/O is instantiated (observed switching to voiceChat, adding this
  option itself), and `.default` mode routes to the receiver without it." In other words, `.voiceChat`
  mode combined with speaker routing has an observed iOS quirk that LiveKit's own maintainers
  already hit and worked around; `.measurement` (used by `SpeechCapturer`) remains wrong here for
  the same AGC/echo-cancellation reason as before (FR-01, FR-02).
- **Options:** `[.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]`, matching
  LiveKit's own `playAndRecordSpeaker` preset (`playAndRecordOptions.union(.defaultToSpeaker)`).
  This **reverses** the original plan's decision to omit `.allowBluetoothA2DP` (OQ-3) — LiveKit's
  own maintainers include it in their recommended preset, which is a stronger signal than our
  original guess that HFP-only is sufficient; there's no longer a reason to diverge from their
  tuning. `.allowAirPlay` is newly added for the same reason (not previously considered).
  **`.mixWithOthers` must NOT be added** — LiveKit's own comment documents a real WebRTC engine-init
  race (`-66637`/`kAudioUnitErr_Initialized`) triggered by that option on the record path; it's
  deliberately absent from their `playAndRecord*` presets (kept only on their listen-only
  `playback` preset, where it's safe).
- **Where this is set:** `AudioManager.shared.sessionConfiguration = AudioSessionConfiguration(category: .playAndRecord, categoryOptions: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker], mode: .videoChat)`
  (or simply `AudioManager.shared.sessionConfiguration = .playAndRecordSpeaker`, LiveKit's own
  built-in preset, which is exactly this — use the preset unless a reason emerges to diverge from
  it), set once before the first `Room.connect()` of a voice session. Use the declarative
  `sessionConfiguration` property, **not** the deprecated `customConfigureAudioSessionFunc` (see
  §2 Option C) — not via a direct `AVAudioSession.setCategory` call from Brand Concierge code while
  a `Room` is live (NFR-01).

### 6.2 Route changes

`SpeechCapturer.handleAudioRouteChange` exists because `AVAudioEngine`'s tap caches a hardware
format that goes stale across a route change, and rebuilding the whole engine/tap is the fix for
*that specific engine*. The LiveKit path does not use `AVAudioEngine` directly — WebRTC's own
audio device module owns the audio unit and already re-negotiates format on route change as part
of its normal operation. The recommended design is therefore **not** to port
`SpeechCapturer`'s rebuild-the-pipeline pattern; the new controller should only:

- Observe `routeChangeNotification` for UI purposes (e.g., show "Now using AirPods" or similar,
  if the product wants that — not assumed as a requirement here), and
- Confirm during verification (§8) that LiveKit's own handling recovers audio without app
  intervention. If real-device testing shows LiveKit does *not* recover cleanly on some
  route-change reason, that is a signal to revisit this section, not to preemptively add a
  rebuild path now (PoC — no gold-plating, per project guidance already agreed upstream in this
  conversation).

### 6.3 Interruptions

Unlike `SpeechCapturer` (which has no explicit interruption handling and just lets the
recognition task error out via `abortStreamingCapture`), a full-duplex voice call is more
disruptive to silently drop, so this needs explicit handling:

- Observe `AVAudioSession.interruptionNotification`.
- On `.began`: mute the local LiveKit audio track and pause the remote (TTS) track — mirrors
  `VoiceTransport`'s `muteLocalAudio()`/`pauseRemoteAudio()` on web, called for a different
  trigger (barge-in/text-submit there vs. system interruption here) but the same primitive
  operations.
- On `.ended`: inspect `AVAudioSessionInterruptionOptions` — if `.shouldResume` is present,
  unmute/resume automatically (mirrors `resumeRemoteAudio()`/`unmuteVoice()`); if absent, leave
  the session paused and surface UI state for the user to manually resume, rather than guessing.
- This handling lives in the new voice controller, not in `SpeechController`/`SpeechCapturer` —
  no shared code between the two paths (§7).

### 6.4 Session teardown / handoff

- Voice session end must result in the `AVAudioSession` being deactivated once LiveKit's own
  teardown completes (mirrors `VoiceTransport.disconnectRoom()`'s track/element cleanup), so a
  subsequent `SpeechCapturer` session's `configureAudioSessionForCapture()` (which calls
  `setActive(true, ...)` itself) starts clean rather than layering on top of a session LiveKit
  still considers active.
- Because FR-08 declares the two voice paths mutually exclusive within a session, this is a
  simpler case than a true concurrent-owner problem — the requirement is sequential cleanliness,
  not simultaneous coordination. This is a **common path, not a rare edge case**: since dictation
  is not replaced and stays available whenever voice mode is off (FR-08), users are expected to
  switch between the two regularly within a single app session, so this handoff must be reliable
  every time, not just tolerated as an edge case. Explicit test coverage in §8 reflects this.

### 6.5 Test plan

- Unit-level (where mockable): configuration-policy object (category/mode/options tuple) is
  correct for `.playAndRecord`/`.videoChat`/`[.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]` (LiveKit's `.playAndRecordSpeaker` preset), and is applied
  exactly once per voice-session start (not re-applied redundantly on every track event).
- Manual/integration, on real devices (AVAudioSession behavior is not meaningfully testable in
  the simulator for mic/route/interruption scenarios):
  - Start voice session on built-in mic/speaker; confirm no audible echo of TTS output into the
    transcript/worker-perceived input.
  - Start voice session, connect AirPods mid-session; confirm audio continues without app crash
    or silent mic, without any app-triggered pipeline rebuild.
  - Start voice session, receive a phone call; confirm mic mutes and TTS pauses; decline/end the
    call; confirm resume behavior matches `.shouldResume`.
  - Start voice session, unplug wired headset mid-session; confirm route falls back to
    speaker/mic per `.defaultToSpeaker`.
  - End a voice session, then start a `SpeechCapturer`-based (existing) voice interaction in the
    same app run; confirm it captures correctly (session was left in a clean state).

---

## 7. What Does NOT Change

| Component | Reason unchanged |
|---|---|
| `SpeechCapturer.swift` / `TextSpeaker.swift` / `SpeechController.swift` | Different, older architecture (on-device STT/TTS over text turns); the new LiveKit voice controller is a sibling, not a modification of these. Their `.measurement`-mode session config is correct for their own use case and is not touched. |
| `ConciergeChatService.swift` (existing SSE chat transport) | This design covers audio session/routing only; the bootstrap event that hands off to LiveKit (`livekit-bootstrap`, mirroring web's `sendConversationDataEvent`) is covered in a separate design doc for the connection/bootstrap module. |
| `AEPCore` / `AEPEdgeIdentity` shared-state usage (`Concierge.swift`) | Identity/config/consent plumbing is unrelated to audio session management. |
| Any UI/theming code (`Views/`, `Theme/`) | Out of scope for this module. |

---

## 8. Verification Criteria

| Scenario | Expected Result |
|---|---|
| Start voice session on built-in mic + speaker | Session activates as `.playAndRecord`/`.videoChat` (LiveKit's `.playAndRecordSpeaker` preset); no audible echo of remote TTS into what the worker receives as user speech |
| Start voice session, then connect Bluetooth HFP headset | Mic and playback both switch to the Bluetooth device without app crash or silent mic |
| Start voice session, then connect/disconnect AirPods | LiveKit's WebRTC audio unit recovers without an app-level pipeline rebuild; no dropped audio beyond the expected brief route-switch gap |
| Incoming phone call during voice session | Local mic mutes, remote (TTS) playback pauses; `Room` connection is not torn down |
| Phone call ends, system reports `.shouldResume` | Mic/playback resume automatically, matching pre-interruption state |
| Phone call ends, system does not report `.shouldResume` | Session stays paused; UI reflects a "paused, tap to resume" state rather than silently resuming |
| End voice session normally | `AVAudioSession` is deactivated once LiveKit teardown completes |
| Start a `SpeechCapturer` (existing) voice interaction immediately after ending a LiveKit voice session | `SpeechCapturer` captures correctly — no leftover session state from the LiveKit path |
| Attempt to start LiveKit voice while `SpeechCapturer` capture is active (or vice versa) | Treated as mutually exclusive per FR-08 — exact UX (blocked vs. auto-stop-the-other) is an open question (OQ-4), but no audio-session corruption in either path |

---

## 9. Implementation Plan

### Phase 1 — Confirm LiveKit SDK audio-session API (blocking)

| # | Task | Notes |
|---|---|---|
| 1.1 | ✅ Done (PR #159) — Added LiveKit 2.17.0 as a native Xcode SPM dependency (not CocoaPods — see `voice-livekit-connection-bootstrap-design.md` §6.1) | |
| 1.2 | ✅ Done (2026-09-15) — Verified `AudioManager`'s actual configuration API against 2.17.0: resolved to `sessionConfiguration`/`AudioSessionConfiguration` (§6.1), and discovered the correct mode is `.videoChat` (matching LiveKit's own `.playAndRecordSpeaker` preset), not the originally-planned `.voiceChat` | Resolves OQ-1 |

### Phase 2 — Audio session policy module

| # | Task | Notes |
|---|---|---|
| 2.1 | Implement the category/mode/options policy object and wire it into LiveKit's configuration hook | One-time setup, applied before first `Room.connect()` of a voice session |
| 2.2 | Implement interruption handling (§6.3) in the new voice controller | Sibling to `SpeechController`, not inside it |
| 2.3 | Implement session teardown coordination (§6.4) | Verify against FR-07/FR-08 |

### Phase 3 — Device verification

| # | Task | Notes |
|---|---|---|
| 3.1 | Run the manual test matrix in §6.5/§8 on real devices (built-in, wired, Bluetooth HFP, AirPods) | Blocking sign-off for this module — simulator testing is not sufficient for audio-session/route behavior |

### Deferred

- Background audio (OQ-2) — deferred until product confirms it's required.
- CallKit integration — deferred; not currently in scope.

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Brand Concierge code and LiveKit's `AudioManager` both call `AVAudioSession` activation APIs, causing category/activation contention (silent mic, crash on deactivate) | Medium | High | NFR-01: no direct `setActive`/`setCategory` calls from Brand Concierge while a voice `Room` is connected; all policy goes through LiveKit's configuration hook (Phase 1.2 verifies the exact API) |
| ~~Assumed `AudioManager` configuration hook doesn't exist or behaves differently in the SDK version actually pinned~~ | ~~Medium~~ | ~~High~~ | **Resolved 2026-09-15** (Phase 1.2): it existed but was deprecated; corrected to `sessionConfiguration` and the `.videoChat` mode finding (§6.1) |
| `.videoChat` mode's built-in AEC/NS/AGC doesn't fully suppress echo on some devices (e.g. loud speaker + sensitive mic) | Low–Medium | Medium | Covered by the real-device echo test in §8; if insufficient, escalate to LiveKit's own audio-processing options (e.g. explicit AEC configuration) as a follow-up, not by reverting to `.voiceChat` (§6.1 explains why `.videoChat` was chosen instead) |
| Route-change behavior differs across iOS versions/devices in ways `SpeechCapturer`'s precedent didn't need to handle (since it rebuilt its own engine) | Low | Medium | §8's AirPods/wired-headset test scenarios are part of sign-off; if LiveKit doesn't recover cleanly on a given reason code, revisit §6.2 then (avoid pre-building a rebuild path speculatively, per PoC scope) |
| Sequential handoff between LiveKit voice and `SpeechCapturer` voice leaves stale session state (FR-08/§6.4) | Low | Medium | Explicit test case in §8; if a problem surfaces, the fix is scoped to session-deactivation ordering, not a redesign |

---

## 11. Open Questions

| # | Question | Owner |
|---|---|---|
| OQ-1 | ~~What is the exact `AudioManager` configuration API in the LiveKit Swift SDK version we pin, and does it match the `customConfigureAudioSessionFunc`-style hook assumed in §2/§6.1?~~ **Resolved (2026-09-15):** it's `sessionConfiguration`/`AudioSessionConfiguration` (the closure hook exists but is deprecated); mode corrected to `.videoChat`. See §2 Option C and §6.1. | — resolved |
| OQ-2 | Is background audio (voice session continuing while the app is backgrounded) a requirement for this PoC, or a later phase? | Product/PoC owner |
| OQ-3 | ~~Do we need `.allowBluetoothA2DP` for any target Bluetooth accessory, or is HFP-only (`.allowBluetooth`) sufficient?~~ **Resolved (2026-09-15):** yes — LiveKit's own `.playAndRecordSpeaker` preset includes `.allowBluetoothA2DP` (and `.allowAirPlay`); adopted rather than diverging from their tuning (§6.1). Device-matrix testing (§8) still applies to confirm behavior on real hardware. | — resolved |
| OQ-4 | ~~If a `SpeechCapturer` interaction and a LiveKit voice session are both reachable in the same app build, what's the desired UX when one is requested while the other is active?~~ **Resolved:** dictation is not replaced; it stays available whenever voice mode is off and is gated off while voice mode is on (mirrors web). See FR-08. | — resolved |
| OQ-5 | Does product want CallKit-style system integration (voice session appears as a call) for a future phase? | Product |

---

## 12. Implementation Outcome (as-built, 2026-09-16)

The audio policy from §6.1 was implemented as designed and verified on a real device against Kings stage: `AudioManager.shared.sessionConfiguration = AudioSessionConfiguration(category: .playAndRecord, categoryOptions: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker], mode: .videoChat)` (LiveKit's `.playAndRecordSpeaker` preset values, rebuilt explicitly because that preset is `internal`). Interruption handling (§6.3) is in `VoiceSessionController`.

**Echo cancellation confirmed sufficient (FR-01/FR-02).** On device, with the mic live during the assistant's response, the worker's TTS is **not** transcribed back as user input — WebRTC/Apple voice-processing AEC (on by default; `isPlatformVoiceProcessingAllowed` = true, `.videoChat` mode) handles it. No explicit `AudioProcessingOptions` tuning was needed.

**Per-turn mic muting is minimal, and is NOT the echo defense.** An early attempt muted the mic for the entire assistant turn to stop TTS-into-input; that suppressed barge-in and diverged from web. Corrected to match web's turn model: mute only during the brief *processing* gap (user-final → assistant starts responding) and keep the mic **live during the response** so the user can barge in — echo is handled by AEC, not by muting. This lives in `VoiceSessionController`'s data-channel handler (see `voice-livekit-connection-bootstrap-design.md` §12.4), not in `SpeechController`.

**Real-device matrix (§8) status:** built-in mic + speaker verified (no echo, barge-in works, mic/session teardown clean). Bluetooth HFP, AirPods connect/disconnect, incoming-call interruption resume, and wired-headset unplug remain to be run.
