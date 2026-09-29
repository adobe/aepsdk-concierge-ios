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

/// Why a turn was started, which is the one thing that decides how it behaves.
///
/// The two kinds differ on exactly two points, and they differ for the same underlying reason: who
/// is waiting. Modelling that as one axis keeps them from drifting apart - as two independent
/// booleans they could be combined into states (a bounded turn that renders its failures, say)
/// that nothing should ever produce.
enum TurnKind {

    /// A turn the user typed.
    ///
    /// Failures render in the transcript, because the user is waiting on a visible answer. The turn
    /// is unbounded: the user is watching it and decides for themselves when to give up.
    case typed

    /// An app-originated data handoff, such as a checkout outcome.
    ///
    /// Failures stay out of the transcript - the user never asked for this turn and may not know
    /// one was sent, so an error bubble would appear unprompted. The turn is bounded, because an
    /// app is waiting on a completion that has to arrive either way.
    ///
    /// - Parameters:
    ///   - noResponse: How long the service may stay silent before the turn is abandoned. Catches a
    ///     backend that never answers at all, which is the common hang and worth failing fast on.
    ///   - ceiling: The hard wall-clock bound on the whole turn. Generous by design: cancelling a
    ///     turn that is actively streaming throws away a reply the user was about to see.
    case handoff(noResponse: TimeInterval, ceiling: TimeInterval)

    /// Whether a failed turn leaves a notice in the transcript.
    var rendersFailures: Bool {
        switch self {
        case .typed: return true
        case .handoff: return false
        }
    }
}

/// One agent turn in flight: the transcript placeholder it owns, the caller it owes an outcome to,
/// and the deadlines that bound it.
///
/// Before this type, a turn had no representation at all - its identity, completion, placeholder
/// and two deadlines were five separate mutable properties on `ChatController`, and every rule
/// about them ("report once", "disarm on finish", "ignore a superseded callback") was a convention
/// enforced by hand at each of the half-dozen places a turn can end. Each new failure mode added
/// another flag and another ordering hazard between them.
///
/// Gathering them into one object makes those rules structural:
///
/// - **It resolves exactly once.** `resolve(_:)` is idempotent, so every exit path out of the
///   streaming callbacks can report freely without coordinating with the others.
/// - **Resolving disarms it.** Deadlines are cancelled as part of resolving, so there is no
///   separate teardown step to forget on a path someone adds later.
/// - **It has identity.** The controller holds at most one turn; a callback compares the turn it
///   captured against the live one, so a turn that was abandoned cannot revive itself.
///
/// `@MainActor` because the transcript and chat state it coordinates with are main-actor state.
@MainActor
final class ChatTurn {

    /// Identity of the transcript message this turn streams into.
    ///
    /// Held as an id rather than an index because the transcript is mutated while the turn runs -
    /// product cards, prompt suggestions and an abandoned turn's cleanup all shift indices, and a
    /// stale index edits or deletes the wrong message instead of failing loudly.
    let placeholderId: UUID

    let kind: TurnKind

    /// Whether a failed turn leaves a notice in the transcript. See `TurnKind`.
    var rendersFailures: Bool { kind.rendersFailures }

    private(set) var isResolved = false

    private var outcome: ((ConciergeError?) -> Void)?
    private var noResponseDeadline: DispatchWorkItem?
    private var ceilingDeadline: DispatchWorkItem?

    init(placeholderId: UUID, kind: TurnKind, outcome: ((ConciergeError?) -> Void)? = nil) {
        self.placeholderId = placeholderId
        self.kind = kind
        self.outcome = outcome
    }

    /// Reports this turn's outcome to its caller and disarms its deadlines.
    ///
    /// Idempotent by design: a deadline firing, a service failure and a late completion can all
    /// race to end the same turn, and each is entitled to try. Returns whether this call is the one
    /// that ended the turn, so one-time work can be done without a second flag.
    ///
    /// A turn started with no completion still resolves, and is still disarmed. Keying that off the
    /// completion would silently leave a `nil`-completion handoff unbounded - the bug that
    /// originally forced a separate "in flight" flag to exist alongside the completion.
    @discardableResult
    func resolve(_ error: ConciergeError?) -> Bool {
        let wasPending = !isResolved
        isResolved = true
        cancelDeadlines()

        guard let outcome = outcome else { return wasPending }
        self.outcome = nil
        outcome(error)
        return wasPending
    }

    /// Records that the service has started answering, and disarms the fast no-response cap.
    ///
    /// The ceiling stays armed: a turn that is streaming is healthy, but it is still bounded.
    func noteResponseStarted() {
        noResponseDeadline?.cancel()
        noResponseDeadline = nil
    }

    /// Arms the hard ceiling, from the moment the turn is submitted.
    ///
    /// Covers everything the turn does, *including* the wait for an auth token, which is what makes
    /// the caller's completion a promise rather than a hope. No-op for a `.typed` turn.
    ///
    /// `handler` receives the interval that elapsed, so the reported timeout names the real bound.
    func armCeiling(_ handler: @escaping (TimeInterval) -> Void) {
        guard case .handoff(_, let ceiling) = kind, !isResolved else { return }
        ceilingDeadline = Self.schedule(after: ceiling, handler: handler)
    }

    /// Arms the fast "the service never answered" cap, at the moment the request actually goes out.
    ///
    /// It measures the service's silence, so it can only start once there is a request to be silent
    /// about. Arming it at submission instead charged the auth-token wait against the service, and
    /// an app whose token provider was slower than the cap had every handoff reported as a delivery
    /// timeout for a request that had never left the device. No-op for a `.typed` turn.
    func armNoResponseCap(_ handler: @escaping (TimeInterval) -> Void) {
        guard case .handoff(let noResponse, _) = kind, !isResolved else { return }
        noResponseDeadline = Self.schedule(after: noResponse, handler: handler)
    }

    private func cancelDeadlines() {
        noResponseDeadline?.cancel()
        noResponseDeadline = nil
        ceilingDeadline?.cancel()
        ceilingDeadline = nil
    }

    /// The hop to the main actor mirrors how the rest of the controller schedules work, and keeps
    /// this usable on the iOS 15 deployment target (`MainActor.assumeIsolated` is iOS 17+).
    private static func schedule(after interval: TimeInterval,
                                 handler: @escaping (TimeInterval) -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem {
            Task { @MainActor in handler(interval) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        return workItem
    }
}
