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

@testable import AEPBrandConcierge

final class MockChatService: ConciergeChatService {
    var plannedChunks: [ConversationPayload] = []
    var plannedError: ConciergeError? = nil
    var shouldCallComplete: Bool = true
    private var pendingOnComplete: ((ConciergeError?) -> Void)? = nil
    private var pendingOnChunk: ((ConversationPayload) -> Void)? = nil

    // Captures for the feedback path
    private(set) var sendFeedbackCallCount = 0
    private(set) var lastFeedbackData: [String: Any]? = nil
    private(set) var lastFeedbackToken: String? = nil

    // Captures for the chat path
    private(set) var streamChatCallCount = 0
    private(set) var lastQuery: String? = nil
    private(set) var lastExtraXDMFields: [String: Any]? = nil

    override func sendFeedback(data: [String: Any], token: String?) {
        sendFeedbackCallCount += 1
        lastFeedbackData = data
        lastFeedbackToken = token
    }

    override func streamChat(_ query: String, token: String?, extraXDMFields: [String: Any]? = nil, onChunk: @escaping (ConversationPayload) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        streamChatCallCount += 1
        lastQuery = query
        lastExtraXDMFields = extraXDMFields

        // Immediately emit planned chunks then complete
        for chunk in plannedChunks {
            onChunk(chunk)
        }
        if shouldCallComplete {
            onComplete(plannedError)
        } else {
            pendingOnChunk = onChunk
            pendingOnComplete = onComplete
        }
    }

    /// Streams a chunk on a turn being held open, the way a slow-but-alive backend would.
    func emitChunk(_ payload: ConversationPayload) {
        pendingOnChunk?(payload)
    }

    private(set) var cancelActiveStreamCallCount = 0

    /// Whether cancelling reports a completion. True mirrors the real delegate when a `dataTask` is
    /// in flight: the cancellation surfaces as an ordinary connection failure. Set false to model
    /// the case the real service also has - `cancelActiveStream()` is `dataTask?.cancel()`, so with
    /// nothing in flight it reports nothing at all, and the caller gets no failure path to unwind
    /// through.
    var completesOnCancel = true

    override func cancelActiveStream() {
        cancelActiveStreamCallCount += 1
        pendingOnChunk = nil
        guard completesOnCancel, let complete = pendingOnComplete else { return }
        pendingOnComplete = nil
        complete(.unreachable)
    }

    func triggerCompletion() {
        pendingOnChunk = nil
        guard let complete = pendingOnComplete else { return }
        pendingOnComplete = nil
        complete(plannedError)
    }
}
