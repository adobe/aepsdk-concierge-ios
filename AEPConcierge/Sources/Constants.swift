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

enum Constants {
    static let LOG_TAG = "Concierge"
    static let EXTENSION_NAME = "com.adobe.aep.concierge"
    
    static let EXTENSION_VERSION = "5.0.0"
    static let FRIENDLY_NAME = "Concierge"
    
    enum ContentTypes {
        static let APPLICATION_JSON = "application/json"
    }
    
    enum AcceptTypes {
        static let TEXT_EVENT_STREAM = "text/event-stream"
    }
    
    enum HTTPMethods {
        static let POST = "POST"
    }
    
    enum HeaderFields {
        static let CONTENT_TYPE = "Content-Type"
        static let ACCEPT = "Accept"
    }
    
    enum EventType {
        static let concierge = "com.adobe.eventType.concierge"
    }
    
    enum ConciergeSchemas {
        static let JSON_CONTENT = "https://ns.adobe.com/concierge/json-content"
    }
    
    enum SSE {
        // intentionally including the space here - this value is used to identify data in SSE responses
        static let DATA_PREFIX = "data: "
    }
    
    enum Request {
        static let READ_TIMEOUT = 15.0
        
        enum Keys {
            static let EVENTS = "events"
            static let QUERY = "query"
            static let CONVERSATION = "conversation"
            static let FETCH_CONVERSATIONAL_EXPERIENCE = "fetchConversationalExperience"
            static let SURFACES = "surfaces"
            static let MESSAGE = "message"
        }
    }
        
    enum SharedState {
        enum Concierge {
            static let COLOR_TEXT_TITLE = "000000"
            static let DELETE_ENDPOINT = ""
            static let CHAT_ENDPOINT = ""
        }

        enum Configuration {
            static let NAME = "com.adobe.module.configuration"

            // TODO: define configuration properties for concierge
        }

        enum EdgeIdentity {
            static let NAME = "com.adobe.edge.identity"
            static let IDENTITY_MAP = "identityMap"
            static let ECID = "ECID"
            static let ID = "id"
        }
    }
    
    enum TempConfig {
        static let DEFAULT_MESSAGE = "I'm Concierge - your virtual product expert. I'm here to answer any questions you may have about this product. What can I do for you today?"
        static let DEFAULT_MESSAGE_IMAGE = "https://i.ibb.co/0X8R3TG/Messages-24.png"
    }
}
