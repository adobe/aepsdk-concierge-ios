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

import SwiftUI

public struct Message: Identifiable {
    public let id = UUID()
    let template: MessageTemplate
    var payload: TempPayload? = nil
    var shouldSpeakMessage = false
    var messageBody: String?
    var sources: [TempSource]? = nil
    var promptSuggestions: [String]? = nil
    var feedbackSentiment: FeedbackSentiment? = nil
    
    public static let divider = Message(template: .divider)
    
    var chatMessageView: ChatMessageView {
        ChatMessageView(messageId: id, template: template, messageBody: messageBody, sources: sources, promptSuggestions: promptSuggestions, feedbackSentiment: feedbackSentiment, onSuggestionTap: nil)
    }
    
    public init(template: MessageTemplate, shouldSpeakMessage: Bool = false, messageBody: String? = nil, sources: [TempSource]? = nil, promptSuggestions: [String]? = nil, feedbackSentiment: FeedbackSentiment? = nil, payload: TempPayload? = nil) {
        self.template = template
        self.payload = payload
        self.shouldSpeakMessage = shouldSpeakMessage
        self.messageBody = messageBody
        self.sources = sources
        self.promptSuggestions = promptSuggestions
        self.feedbackSentiment = feedbackSentiment
    }
}
