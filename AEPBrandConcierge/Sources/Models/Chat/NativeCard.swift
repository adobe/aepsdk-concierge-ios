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

import SwiftUI
import Foundation
import CoreFoundation
import Combine
import AEPServices

public typealias ConciergeCardRenderer =
    (_ element: [String: Any], _ context: [String: Any], _ saveState: @escaping ([String: Any]) -> Void) -> AnyView

enum NativeCardRegistry {
    struct Registration {
        let renderer: ConciergeCardRenderer
    }
    private static let lock = NSLock()
    private static var registrations: [String: Registration] = [:]

    static func register(type: String, renderer: @escaping ConciergeCardRenderer) {
        guard !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lock.lock()
        registrations[type] = Registration(renderer: renderer)
        lock.unlock()
    }

    static func renderer(for type: String?) -> ConciergeCardRenderer? {
        registration(for: type)?.renderer
    }

    static func registration(for type: String?) -> Registration? {
        guard let type else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return registrations[type]
    }

    static var hasAnyRenderer: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !registrations.isEmpty
    }

    #if DEBUG
    static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        registrations.removeAll()
    }
    #endif
}

/// A transcript occurrence owns its renderer and state even while its SwiftUI row is off screen.
@MainActor
public final class NativeCard: ObservableObject {
    private static var nextReceiptSequence = 0
    let cardId = UUID().uuidString
    let occurrenceId: String
    let element: [String: Any]
    let renderer: ConciergeCardRenderer
    let sessionId: String?
    let conversationId: String?
    let interactionId: String?
    @Published private(set) var state: [String: Any]?
    @Published private(set) var isBusy = false
    @Published private(set) var isStale = false
    private(set) var disposed = false
    private let receiptSequence: Int

    init(element: [String: Any], renderer: @escaping ConciergeCardRenderer,
         occurrenceId: String = UUID().uuidString,
         sessionId: String?, conversationId: String?, interactionId: String?) {
        self.occurrenceId = occurrenceId
        self.element = element
        self.renderer = renderer
        self.sessionId = sessionId
        self.conversationId = conversationId
        self.interactionId = interactionId
        NativeCard.nextReceiptSequence += 1
        receiptSequence = NativeCard.nextReceiptSequence
    }

    var context: [String: Any] {
        var result: [String: Any] = ["cardId": cardId, "isBusy": isBusy, "isStale": isStale,
                                     "receiptSequence": receiptSequence]
        if let sessionId { result["sessionId"] = sessionId }
        if let conversationId { result["conversationId"] = conversationId }
        if let interactionId { result["interactionId"] = interactionId }
        if let state { result["state"] = state }
        return result
    }

    nonisolated func saveState(_ value: [String: Any]) {
        guard let copy = NativeCard.copyJSON(value) else {
            Log.warning(label: "NativeCard", "Rejected invalid or over-budget saved state.")
            return
        }
        Task { @MainActor [weak self] in
            guard let self, !self.disposed else { return }
            self.state = copy
        }
    }

    func dispose() {
        guard !disposed else { return }
        isStale = true
        disposed = true
        state = nil
    }

    func setBusy(_ busy: Bool) {
        isBusy = busy
    }

    /// Copy containers without a serialization round trip that could round decimal numbers.
    nonisolated static func copyJSON(_ value: [String: Any]) -> [String: Any]? {
        var count = 0
        var ancestors = Set<ObjectIdentifier>()
        func copy(_ item: Any, depth: Int) -> Any? {
            count += 1
            guard depth <= 64, count <= 100_000 else { return nil }
            if let dictionary = item as? NSDictionary {
                let identity = ObjectIdentifier(dictionary)
                guard ancestors.insert(identity).inserted else { return nil }
                defer { ancestors.remove(identity) }
                var result: [String: Any] = [:]
                for (key, item) in dictionary {
                    guard let key = key as? String, let value = copy(item, depth: depth + 1) else { return nil }
                    result[key] = value
                }
                return result
            }
            if let array = item as? NSArray {
                let identity = ObjectIdentifier(array)
                guard ancestors.insert(identity).inserted else { return nil }
                defer { ancestors.remove(identity) }
                var result: [Any] = []
                result.reserveCapacity(array.count)
                for item in array {
                    guard let value = copy(item, depth: depth + 1) else { return nil }
                    result.append(value)
                }
                return result
            }
            if item is NSNull { return NSNull() }
            if let string = item as? String { return string }
            if let number = item as? NSNumber {
                guard CFGetTypeID(number) == CFBooleanGetTypeID() || number.doubleValue.isFinite else { return nil }
                return number
            }
            return nil
        }
        return copy(value, depth: 0) as? [String: Any]
    }
}
