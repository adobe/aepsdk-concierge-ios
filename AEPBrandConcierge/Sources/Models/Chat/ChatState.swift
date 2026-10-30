/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

// MARK: - Input State Machine

/// Errors that can occur during input processing.
public enum InputError: Error, Equatable {
    case permissionDenied
    case transcriptionFailed
    case unknown
}

/// Current state of the input field.
public enum InputState: Equatable {
    case empty
    case editing
    case recording
    case transcribing
    case error(InputError)
}

// MARK: - Chat State Machine

/// Errors that can occur during chat processing.
public enum ChatError: Error, Equatable {
    case networkFailure
    case modelError
    case cancelled
    case emptyResponse
}

/// Current state of the chat session.
public enum ChatState: Equatable {
    case idle
    case processing

    /// - Important: No production code path produces this case. A failed turn is a *finished* turn:
    ///   it surfaces the failure and returns to `.idle`. Parking here would deadlock the chat, since
    ///   `sendMessage`, `sendEnabled` and `micEnabled` all require `.idle` and the only route back
    ///   runs inside a turn those guards prevent from starting.
    ///
    ///   The case is kept because removing it is a breaking API change, and the views still reason
    ///   about it - `MessageListView.shouldFillRemainingHeight` deliberately refuses to fill an
    ///   `.error` bubble so the guard stays correct if a producer is ever reintroduced. Today the
    ///   only writer is the `DEBUG`-only `ChatController.setChatStateForTesting`.
    case error(ChatError)
}
