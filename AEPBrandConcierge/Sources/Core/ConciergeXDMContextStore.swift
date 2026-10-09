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

/// Backs `Concierge.updateXDMContext(_:)`. Holds app-provided XDM for the current backend session
/// and reads a fresh snapshot for every outbound turn.
final class ConciergeXDMContextStore {
    static let shared = ConciergeXDMContextStore()

    private let lock = NSLock()
    private let sessionIDProvider: () -> String?
    private var held: [String: Any] = [:]
    private var sessionID: String?

    var hasContext: Bool {
        lock.lock(); defer { lock.unlock() }
        return !held.isEmpty
    }

    init(sessionIDProvider: @escaping () -> String? = { SessionManager.shared.currentSessionIdIfActive }) {
        self.sessionIDProvider = sessionIDProvider
    }

    /// Applies an RFC 7396 JSON Merge Patch. Throws if `fields` is not JSON-serializable or
    /// contains a top-level `identityMap` key.
    func update(_ fields: [String: Any]) throws {
        try Self.validate(fields)
        lock.lock(); defer { lock.unlock() }
        let currentSessionID = sessionIDProvider()
        discardPreviousSession(ifNeededFor: currentSessionID)
        sessionID = currentSessionID
        held = Self.mergePatch(target: held, patch: Self.copyJSONObject(fields))
    }

    /// Returns context for `sessionID`, discarding context bound to a different backend session.
    func snapshot(for sessionID: String) -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        discardPreviousSession(ifNeededFor: sessionID)
        self.sessionID = sessionID
        return Self.copyJSONObject(held)
    }

    /// Clears stale bound context on presentation without adopting pending context into a session.
    func discardExpiredContext(for sessionID: String) {
        lock.lock(); defer { lock.unlock() }
        discardPreviousSession(ifNeededFor: sessionID)
    }

    private func discardPreviousSession(ifNeededFor currentSessionID: String?) {
        if let sessionID, sessionID != currentSessionID {
            held = [:]
            self.sessionID = nil
        }
    }

    /// Clears all held context when the chat-service identity changes.
    func clear() {
        lock.lock(); defer { lock.unlock() }
        held = [:]
        sessionID = nil
    }

    /// Deep-merges handoff fields, preserving JSON nulls as literal values (not deletions).
    static func merging(_ patch: [String: Any], over target: [String: Any]) -> [String: Any] {
        mergePatch(target: target, patch: copyJSONObject(patch), nullDeletes: false)
    }

    private static func validate(_ fields: [String: Any]) throws {
        guard fields[ConciergeConstants.Request.Keys.IDENTITY_MAP] == nil else {
            throw ConciergeXDMContextError.reservedKeyCollision
        }
        guard JSONSerialization.isValidJSONObject(fields) else {
            throw ConciergeXDMContextError.invalidValue
        }
    }

    /// RFC 7396 JSON Merge Patch for updates; handoff merges preserve literal JSON nulls.
    /// - `patch` values of `NSNull()` remove the corresponding key only when `nullDeletes` is true.
    /// - Nested `[String: Any]` values are merged recursively.
    /// - Any other value (including arrays) replaces `target`'s value wholesale (per spec - arrays
    ///   are not merged element-wise).
    private static func mergePatch(target: [String: Any], patch: [String: Any], nullDeletes: Bool = true) -> [String: Any] {
        var result = target
        for (key, value) in patch {
            if nullDeletes && value is NSNull {
                result.removeValue(forKey: key)
            } else if let nestedPatch = value as? [String: Any] {
                let nestedTarget = result[key] as? [String: Any] ?? [:]
                result[key] = mergePatch(target: nestedTarget, patch: nestedPatch, nullDeletes: nullDeletes)
            } else {
                result[key] = value
            }
        }
        return result
    }

    private static func copyJSONObject(_ object: [String: Any]) -> [String: Any] {
        object.mapValues(copyJSONValue)
    }

    private static func copyJSONValue(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return copyJSONObject(object)
        }
        if let array = value as? [Any] {
            return array.map(copyJSONValue)
        }
        if let string = value as? String {
            return string
        }
        return value
    }
}

/// Errors thrown by `Concierge.updateXDMContext(_:)`.
public enum ConciergeXDMContextError: Error, Equatable {
    /// `fields` contained a value that isn't JSON-serializable.
    case invalidValue
    /// `fields` used the reserved `identityMap` top-level key.
    case reservedKeyCollision
}
