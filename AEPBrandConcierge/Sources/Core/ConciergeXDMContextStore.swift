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

/// Backs `Concierge.updateXDMContext(_:)`. Holds a single merged XDM object across the lifetime
/// of the current conversation session, read fresh on every outbound turn.
final class ConciergeXDMContextStore {
    static let shared = ConciergeXDMContextStore()

    private let lock = NSLock()
    private var held: [String: Any] = [:]

    /// Applies an RFC 7396 JSON Merge Patch. Throws if `fields` is not JSON-serializable or
    /// contains a top-level `identityMap` key.
    func update(_ fields: [String: Any]) throws {
        try Self.validate(fields)
        lock.lock()
        held = Self.mergePatch(target: held, patch: fields)
        lock.unlock()
    }

    /// Snapshot of the currently held context, read synchronously at turn-send time.
    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return held
    }

    /// Clears all held context. Internal only - invoked by `Concierge.resolveSession(...)` when a
    /// genuinely new session is created. Not exposed as a public API.
    func clear() {
        lock.lock(); defer { lock.unlock() }
        held = [:]
    }

    private static func validate(_ fields: [String: Any]) throws {
        guard fields[ConciergeConstants.Request.Keys.IDENTITY_MAP] == nil else {
            throw ConciergeXDMContextError.reservedKeyCollision
        }
        guard JSONSerialization.isValidJSONObject(fields) else {
            throw ConciergeXDMContextError.invalidValue
        }
    }

    /// RFC 7396 JSON Merge Patch: https://www.rfc-editor.org/rfc/rfc7396
    /// - `patch` values of `NSNull()` remove the corresponding key from `target`.
    /// - Nested `[String: Any]` values are merged recursively.
    /// - Any other value (including arrays) replaces `target`'s value wholesale (per spec - arrays
    ///   are not merged element-wise).
    private static func mergePatch(target: [String: Any], patch: [String: Any]) -> [String: Any] {
        var result = target
        for (key, value) in patch {
            if value is NSNull {
                result.removeValue(forKey: key)
            } else if let nestedPatch = value as? [String: Any] {
                let nestedTarget = result[key] as? [String: Any] ?? [:]
                result[key] = mergePatch(target: nestedTarget, patch: nestedPatch)
            } else {
                result[key] = value
            }
        }
        return result
    }
}

/// Errors thrown by `Concierge.updateXDMContext(_:)`.
public enum ConciergeXDMContextError: Error, Equatable {
    /// `fields` contained a value that isn't JSON-serializable.
    case invalidValue
    /// `fields` used the reserved `identityMap` top-level key.
    case reservedKeyCollision
}
