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

import AEPServices

/// Payload received from the conversation service stream.
public struct ConversationPayload: Codable {
    // brand-concierge:conversation
    public let conversationId: String?
    public let interactionId: String?
    public let request: [String: AnyCodable]?
    public let response: ConversationResponse?
    public let state: String?

    // state:store
    public let key: String?
    public let value: String?
    public let maxAge: Int?
}
