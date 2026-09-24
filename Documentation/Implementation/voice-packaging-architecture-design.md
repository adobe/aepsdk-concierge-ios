# LiveKit Voice — Client Packaging & Architecture Options

**Status:** Draft — pending team review
**Scope:** How the mobile Brand Concierge SDK should package and distribute the real-time-voice
capability so it does not force a third-party dependency (LiveKit/WebRTC), app-size growth, or a
CocoaPods incompatibility onto every Brand Concierge customer — including those who never use
voice — while, ideally, remaining reusable by extensions beyond Brand Concierge in the future.
This document covers only the outer packaging/architecture boundary. It does not cover the
LiveKit bootstrap wire contract (`voice-livekit-connection-bootstrap-design.md`) or audio-session
policy (`voice-livekit-audio-session-design.md`), both of which assume voice lives inside
`AEPBrandConcierge` as currently implemented — this doc is what may change around them, not a
replacement for them.
**Audience:** Ashu Malik's mobile-SDK-ownership team, Peter Fransen, the active Brand Concierge
SDK engineers (Christopher Hoffmann — iOS, Ryan Morales — Android), and Steve Benedick / Prashanth
Rudrabhat (advisory, former SDK owners).

---

## 1. Background & Problem Statement

### Current state

The working iOS voice proof-of-concept adds LiveKit 2.17.0 as a **direct dependency of the core
`AEPBrandConcierge` target** — same tier as `AEPCore` — with no separable module. This was a
deliberate choice: `ChatController`/`ChatView`/message-rendering views are all `internal` to the
module, so a host app has no public seam to inject voice content into the existing chat transcript
from outside the SDK; building voice as a second, parallel UI outside the SDK was assessed as more
work, not less.

### Why this needs to change

A review with Steve Benedick and Prashanth Rudrabhat (who used to own the AEP mobile SDK;
ownership of everything except the Brand Concierge extension has since moved to Ashu Malik's team)
raised concerns with embedding LiveKit directly in Core, in spirit:

- Adobe has intentionally not shipped third-party SDKs bundled into its always-on distributions
  (Core, or an extension every Brand Concierge customer gets by default).
- LiveKit specifically cannot currently be resolved via CocoaPods at all: CocoaPods trunk stopped
  publishing `LiveKitClient` at 2.0.18; every version since — including our required 2.17.0 —
  depends on `LiveKitUniFFI`, which was never published to CocoaPods trunk. This is a hard
  resolution failure, not staleness.
- Third-party transitive dependencies risk conflicting with a host app's own dependency graph.
- App-size growth affects every customer, including ones who will never use voice (e.g. Dick's
  Sporting Goods was raised as a likely example).

### Existing precedent this SDK already has

Dictation (speech-to-text into the composer) and speech synthesis already use an
interface-injection pattern, not a hard-coded implementation:

- `SpeechCapturing` (`AEPBrandConcierge/Sources/Protocols/SpeechCapturing.swift`) — a public
  protocol with no third-party (or even platform-specific) imports. `ConciergeChatSession` defaults
  to a real `SpeechCapturer()` (Apple `SFSpeechRecognizer`/`AVAudioEngine`) if the host app doesn't
  supply one — this works because the default implementation has no third-party dependency to
  avoid forcing on anyone.
- `TextSpeaking` — same shape, but **not** defaulted; the host app must explicitly opt in by
  supplying an implementation, or speech synthesis is simply off. This is the closer precedent for
  voice: an optional capability with real dependency weight that only activates if the host app
  wires it in.

---

## 2. Requirements

Derived from the concerns above and this SDK's existing conventions:

- **R1 — Zero impact on non-voice customers.** Adding voice must not increase app size, dependency
  count, or build-tool constraints for any Brand Concierge customer who doesn't use it.
- **R2 — CocoaPods gap must be scoped, not silently inherited by everyone.** Given LiveKit is not
  resolvable via CocoaPods today, whatever we build must make that limitation apply only to
  customers who want voice — not regress the CocoaPods experience for the rest of Brand Concierge.
- **R3 — Reusable beyond Brand Concierge.** Other extensions (Analytics, Messaging, etc.) are
  plausible future consumers of voice. The design should not hard-code the injection seam to
  Brand Concierge specifically if it can reasonably avoid it.
- **R4 — No regression in real-time audio quality or echo cancellation** versus the current PoC,
  which relies on LiveKit's client-side WebRTC stack (adaptive bitrate/jitter/loss handling, and
  local echo cancellation — directly relevant to a still-open TTS→STT self-barge-in issue,
  [livekit/agents#3758](https://github.com/livekit/agents/issues/3758), a known LiveKit mobile
  limitation with the built-in mic).
- **R5 — Bounded new operational ownership.** Brand Concierge currently has no dedicated SDK
  owner; a design that requires standing up and operating new backend infrastructure is a
  materially bigger ask than one that doesn't.
- **R6 — Respect the existing customer-overridable networking mechanism** where relevant — the
  SDK's own networking layer is first-party and already overridable by customers with their own
  stack.

---

## 3. Options considered

### Option A — Separate library + overridable interface

An interface (tentatively `VoiceHandling`, mirroring `SpeechCapturing`'s shape: state, callbacks,
`start`/`stop`) is declared with no third-party imports. Whether it lives on Core services or on
Brand Concierge itself is an open question (§5, OQ-B) — placing it on Core services satisfies R3
directly, since any current or future extension can share one Core-level injection rather than
each needing its own. The *concrete* implementation (today's `VoiceSessionController`, which
`import LiveKit`s) moves out of `AEPBrandConcierge` into a new, separate distributable artifact
(e.g. `AEPVoice`). A host app that wants voice adds that artifact as a
dependency and constructs/injects its concrete type at `ConciergeChatSession`/`ChatController`
init — the same shape as the existing, un-defaulted `TextSpeaking` injection.

- Satisfies R1 (opt-in cost only), R4 (unchanged — still LiveKit's client SDK, so no audio-quality
  or AEC regression versus the current PoC), R5 (no new backend — this is a client repackaging).
- R2: only partially — the CocoaPods gap doesn't regress the rest of Brand Concierge, but it is
  **inherited, not solved**: any host app that wants voice and integrates via CocoaPods still
  can't get it, until LiveKit's own CocoaPods publishing situation changes (outside Adobe's
  control). This is a known, pre-existing limitation of using LiveKit at all, not something this
  packaging choice creates.
- R3: satisfied only if the interface is placed at the Core-services layer, letting any current or
  future extension share one injection point instead of each needing its own — but a host app must
  still explicitly add the library and wire the concrete instance in — this cannot become an
  automatic, always-on Core capability, no matter where the interface itself is declared, because
  the concrete implementation is inherently heavy (LiveKit).
- Lowest engineering cost of the two options: repackages the already-working proof-of-concept
  rather than building anything new.

### Option B — Server-side Gateway

Adobe operates a Gateway service, in Adobe's own network, that is the actual LiveKit/WebRTC
client — joining the backend-issued Room the same way the existing voice worker already does on
the agent side, but standing in for the mobile app. The mobile app never links LiveKit at all; it
implements a thin `VoiceHandling`-shaped protocol backed by a plain WebSocket/SSE connection to the
Gateway for mic-audio-out / TTS-audio-and-transcript-in.

- Fully satisfies R1 and R2 for *every* customer, including CocoaPods-based ones — voice becomes
  available regardless of integration method, since the client-side piece has no meaningful
  third-party footprint.
- Best answer to R3: because the client-side implementation is thin enough to plausibly live
  directly in Core (no third-party SDK, negligible size — none of the objections that block
  LiveKit apply to a WebSocket client), voice could become a default, always-on Core capability
  available to every extension with zero host-app opt-in step — stronger than anything Option A
  can reach.
- R4 is currently unproven and likely regresses on the transport side, but echo cancellation
  itself is not inherently lost: WS/SSE are TCP-based, while WebRTC/LiveKit is UDP-based
  specifically to tolerate jitter/loss in real-time audio over cellular networks (the actual
  target environment, not corp Wi-Fi) — swapping the transport risks audible glitches or growing
  latency, independent of echo cancellation. Separately, iOS's on-device echo cancellation (Voice
  Processing I/O, via `AVAudioEngine`) is a platform capability, not something LiveKit uniquely
  provides — LiveKit's client SDK merely configures and uses it. So the thin client *can* still get
  the same on-device echo cancellation LiveKit gets today, but only if it plays the TTS audio
  received from the Gateway back through the *same* `AVAudioEngine` instance that captures the mic
  (with voice processing enabled on that engine) — VPIO only cancels echo from audio played out
  through its own engine graph; a naive implementation that plays TTS via a separate path (e.g.
  `AVAudioPlayer`) would not get cancellation. This means the "thin" client isn't just a WebSocket
  wrapper — it also needs a real local audio-capture/playback pipeline built directly on
  `AVAudioEngine`, which is real, unproven implementation work (though it adds no third-party
  dependency or app-size cost). Even done correctly, it would likely inherit the same underlying
  iOS VPIO onset-convergence limitation behind the still-open self-barge-in bug noted under R4
  above, since that is a platform limitation, not a LiveKit-specific one.
- Fails R5: requires building and operating a new, persistent, per-session media-relay backend
  service — effectively a second "client-side" LiveKit participant mirroring what the existing
  voice worker already is on the agent side — a materially larger lift than a client repackaging,
  with no obvious owner given Brand Concierge's current ownership gap.
- Also adds a network hop (phone ⇄ Gateway ⇄ LiveKit Server ⇄ Worker vs. today's phone ⇄ LiveKit
  Server ⇄ Worker) on top of an already latency-sensitive barge-in UX.
- R6 becomes easier under this option: a WS/SSE client fits the SDK's existing overridable
  first-party networking model far more naturally than raw WebRTC does.

### Comparison summary

| Requirement | A — Library + Interface | B — Gateway |
|---|---|---|
| R1 zero impact on non-voice customers | ✓ | ✓ |
| R2 CocoaPods gap scoped/solved | Partial (scoped, not solved) | ✓ (solved) |
| R3 reusable beyond Brand Concierge | ✓ if interface is Core-level | ✓✓ (could be Core-default) |
| R4 audio quality / AEC parity | ✓ (unchanged from today) | Partial — transport quality unproven; AEC achievable but requires reimplementing the local audio pipeline |
| R5 bounded new ops burden | ✓ (client-only change) | ✗ (new backend service) |
| R6 respects networking override | ✗ (unchanged from today) | ✓ |

---

## 4. Recommendation

Pursue **Option A (Library + Interface)** first. It is the smallest step from the already-working
proof-of-concept, matches the guidance given by the (former) SDK owners, and its one real cost —
voice unavailable to CocoaPods-integrated host apps — is a bounded, pre-existing limitation of
using LiveKit at all, rather than a new open risk. Placing the `VoiceHandling` interface at the
Core-services layer (rather than Brand-Concierge-specific) is recommended specifically to keep R3
open for the future without extra cost now.

**Option B (Gateway) should stay documented, not pursued further right now.** Its dependency-
isolation story is strictly better than Option A's, including for future multi-extension reuse,
but it carries real, unproven risk on transport-level audio quality (R4) — and, even though
on-device echo cancellation is achievable in principle by routing capture/playback through the
same `AVAudioEngine` instance, that pipeline would need to be built and correctly tuned from
scratch — plus a substantially larger operational ask (R5) that Option A does not. If CocoaPods
support for voice becomes a hard requirement for a real customer (see OQ-A below), Option B should
be revisited — starting with a narrow prototype of both WS/SSE transport quality and the
`AVAudioEngine`-based echo-cancellation pipeline against a local dev environment, since those
questions alone determine whether the rest of the design is viable.

---

## 5. Open questions

- **OQ-A:** Does any actual VC customer require CocoaPods integration for Brand Concierge, making
  Option A's "voice is SPM-only" gap a real blocker rather than an acceptable limitation? Needs
  input from Anshika/Jose/Peter Fransen, not just an internal engineering call.
- **OQ-B:** Should `VoiceHandling` be exposed from Core services or from Brand Concierge itself?
  Affects how directly R3 is satisfied under Option A.
- **OQ-C:** If Option B is ever revisited, who would own building and operating the Gateway
  service, given Brand Concierge currently has no dedicated SDK owner?

---

## 6. Next steps

1. Circulate this draft to Ashu Malik's team, Peter Fransen, Steve Benedick, and Prashanth
   Rudrabhat for review.
2. Resolve OQ-A and OQ-B before implementation work on repackaging begins.
3. If Option A is confirmed, update `voice-livekit-connection-bootstrap-design.md` and
   `voice-livekit-audio-session-design.md` to reflect the new module boundary (today they assume
   voice lives inside `AEPBrandConcierge`).
