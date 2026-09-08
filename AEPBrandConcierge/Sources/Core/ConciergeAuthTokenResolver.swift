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

/// Holds the app-registered auth token provider and resolves a token for each turn.
///
/// The provider is `async`, so one API serves both a synchronous caller (never suspends) and an
/// async caller (awaits a refresh); it's awaited on a background `Task`, so it never blocks the UI.
/// It's consulted fresh every turn (never cached); a missing provider, a `nil`/blank return, or a
/// provider that doesn't finish within the configured timeout sends the turn without a token.
/// The SDK never sees the underlying Auth0 token.
final class ConciergeAuthTokenResolver {
    static let shared = ConciergeAuthTokenResolver()

    /// Default time to wait for the provider before sending the turn without a token, when the app
    /// doesn't specify one. A safety net against a provider that never returns.
    static let defaultTimeout: TimeInterval = 3

    /// Upper bound on the provider timeout. Clamps non-finite (`.infinity`/`.nan`) or absurdly large
    /// values so the seconds→nanoseconds `UInt64` conversion can never trap.
    static let maxTimeout: TimeInterval = 600 // 10 minutes; far below the UInt64-nanosecond overflow

    private let LOG_TAG = "ConciergeAuthTokenResolver"

    private let lock = NSLock()
    private var _provider: (@Sendable () async -> String?)?
    private var _timeoutNanoseconds: UInt64 = 3_000_000_000 // defaultTimeout in ns; overwritten on setProvider

    /// Registers `provider` and the maximum time to await it before sending the turn without a
    /// token. Pass `nil` to clear. `timeout` is clamped to `[0, maxTimeout]`.
    func setProvider(_ provider: (@Sendable () async -> String?)?,
                     timeout: TimeInterval = ConciergeAuthTokenResolver.defaultTimeout) {
        lock.lock()
        _provider = provider
        _timeoutNanoseconds = Self.nanoseconds(fromTimeout: timeout)
        lock.unlock()
        Log.debug(label: LOG_TAG, provider == nil ? "Auth token provider cleared." : "Auth token provider registered.")
    }

    /// Converts a timeout in seconds to nanoseconds, clamped to `[0, maxTimeout]` so a non-finite or
    /// out-of-range value can't trap the `UInt64` conversion.
    private static func nanoseconds(fromTimeout seconds: TimeInterval) -> UInt64 {
        let clamped = seconds.isFinite ? min(max(0, seconds), maxTimeout) : maxTimeout
        return UInt64(clamped * 1_000_000_000)
    }

    /// Returns the current token, or `nil` if there's no provider, it returns `nil`/blank, or it
    /// doesn't finish within the configured timeout. Awaits without blocking the caller.
    func resolveToken() async -> String? {
        lock.lock()
        let provider = _provider
        let timeoutNanoseconds = _timeoutNanoseconds
        lock.unlock()
        guard let provider = provider else { return nil }
        let raw = await Self.firstResult(of: { await provider() }, orNilAfter: timeoutNanoseconds)
        guard let token = raw,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return token
    }

    /// Returns `operation`'s result, or `nil` if it doesn't finish within `nanoseconds`.
    ///
    /// Runs the operation and a timeout as two racing tasks; whichever resumes the continuation first
    /// wins and cancels the loser — so the timeout sleep doesn't linger after a fast provider, and a
    /// cooperative provider is cancelled once the timeout fires. A non-cooperative provider that
    /// ignores cancellation is abandoned to finish on its own, its result discarded, so even an
    /// operation that never returns cannot wedge the caller. (Structured alternatives await their
    /// child tasks at scope exit, which would re-introduce that hang.)
    private static func firstResult(of operation: @escaping @Sendable () async -> String?,
                                    orNilAfter nanoseconds: UInt64) async -> String? {
        let gate = ResumeGate()
        return await withCheckedContinuation { continuation in
            gate.attach(continuation)
            let operationTask = Task { gate.resume(returning: await operation()) }
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: nanoseconds)
                gate.resume(returning: nil)
            }
            gate.trackSiblings(operationTask, timeoutTask)
        }
    }
}

/// Resumes a `CheckedContinuation` exactly once — whichever racing task (the provider or the
/// timeout) finishes first wins, and the loser is cancelled; any later resume is a no-op.
/// `@unchecked Sendable`: all mutable state is serialized by `lock`.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?
    private var siblings: [Task<Void, Never>] = []

    func attach(_ continuation: CheckedContinuation<String?, Never>) {
        lock.lock(); defer { lock.unlock() }
        self.continuation = continuation
    }

    /// Registers the racing tasks so the winner can cancel the loser. If a winner already resumed
    /// before this runs, the tasks are cancelled immediately.
    func trackSiblings(_ tasks: Task<Void, Never>...) {
        lock.lock()
        let alreadyResumed = (continuation == nil)
        if !alreadyResumed { siblings = tasks }
        lock.unlock()
        if alreadyResumed { tasks.forEach { $0.cancel() } }
    }

    func resume(returning value: String?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let siblings = self.siblings
        self.siblings = []
        lock.unlock()
        continuation?.resume(returning: value)
        siblings.forEach { $0.cancel() }
    }
}
