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

import Combine
import Foundation
import AEPServices
import UIKit

/// The last application lifecycle state observed through UIKit notifications.
enum ConciergeApplicationState: Equatable {
    case unknown
    case foreground
    case background
}

/// Tracks whole-app foreground/background transitions without requiring host Lifecycle API calls.
final class ConciergeAppState {
    static let shared = ConciergeAppState()

    private let lock = NSLock()
    private var storedState: ConciergeApplicationState = .unknown
    private let stateSubject = CurrentValueSubject<ConciergeApplicationState, Never>(.unknown)
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        notificationObservers = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateState(.background)
            },
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateState(.foreground)
            }
        ]
    }

    var state: ConciergeApplicationState {
        lock.lock()
        defer { lock.unlock() }
        return storedState
    }

    var statePublisher: AnyPublisher<ConciergeApplicationState, Never> {
        stateSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    private func updateState(_ nextState: ConciergeApplicationState) {
        lock.lock()
        let didChange = storedState != nextState
        storedState = nextState
        lock.unlock()

        guard didChange else { return }
        let description = nextState == .background ? "background" : "foreground"
        Log.debug(label: ConciergeConstants.LOG_TAG, "UIKit reports app entered \(description).")
        stateSubject.send(nextState)
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }
}
