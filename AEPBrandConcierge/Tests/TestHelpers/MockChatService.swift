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

    // Captures for the feedback path
    private(set) var sendFeedbackCallCount = 0
    private(set) var lastFeedbackData: [String: Any]? = nil
    private(set) var lastFeedbackToken: String? = nil

    override func sendFeedback(data: [String: Any], token: String?) {
        sendFeedbackCallCount += 1
        lastFeedbackData = data
        lastFeedbackToken = token
    }

    override func streamChat(_ query: String, token: String?, onChunk: @escaping (ConversationPayload) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        // Immediately emit planned chunks then complete
        for chunk in plannedChunks {
            onChunk(chunk)
        }
        if shouldCallComplete {
            onComplete(plannedError)
        } else {
            pendingOnComplete = onComplete
        }
    }

    func triggerCompletion() {
        guard let complete = pendingOnComplete else { return }
        pendingOnComplete = nil
        complete(plannedError)
    }
}
