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

/// Central constants for the Concierge SDK.
enum ConciergeConstants {
    static let LOG_TAG = "Concierge"
    static let EXTENSION_NAME = "com.adobe.aep.concierge"
    static let EXTENSION_VERSION = "5.0.0"
    static let FRIENDLY_NAME = "Concierge"
    static let DEFAULT_TIMEOUT = 3.0
    
    // MARK: - HTTP
    
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
    
    // MARK: - SDK Events
    
    enum EventType {
        static let concierge = "com.adobe.eventType.concierge"
    }
    
    enum ConciergeSchemas {
        static let JSON_CONTENT = "https://ns.adobe.com/concierge/json-content"
    }
    
    enum EventName {
        static let SHOW_UI = "Show Brand Concierge UI - Request"
        static let SHOW_UI_RESPONSE = "Show Brand Concierge UI - Response"
        static let FEEDBACK = "Brand Concierge - Chat Feedback"
    }
    
    enum EventData {
        enum Key {
            static let CONFIG = "config"
        }
    }
    
    // MARK: - Server-Sent Events
    
    enum SSE {
        // Intentionally including the space - used to identify data in SSE responses
        static let DATA_PREFIX = "data: "
    }
    
    enum StreamState {
        static let IN_PROGRESS = "in-progress"
        static let COMPLETED = "completed"
    }
    
    // MARK: - Network Requests
    
    enum Request {
        static let READ_TIMEOUT = 15.0
        static let HTTPS = "https://"
        
        enum EventType {
            static let CONVERSATION_FEEDBACK = "conversation.feedback"
        }
        
        enum Keys {
            static let EVENTS = "events"
            static let QUERY = "query"
            static let CONVERSATION = "conversation"
            static let FETCH_CONVERSATIONAL_EXPERIENCE = "fetchConversationalExperience"
            static let SURFACES = "surfaces"
            static let MESSAGE = "message"
            static let XDM = "xdm"
            static let IDENTITY_MAP = "identityMap"
            static let ECID = "ECID"
            static let ID = "id"
            static let EVENT_TYPE = "eventType"
            static let CONFIG_ID = "configId"
            static let SESSION_ID = "sessionId"
            static let CONVERSATION_ID = "conversationId"
            
            enum Consent {
                static let META = "meta"
                static let STATE = "state"
                static let ENTRIES = "entries"
                static let VALUE = "value"
                static let MAX_AGE = "maxAge"
                static let KEY = "key"
            }
            
            enum Feedback {
                static let FEEDBACK = "feedback"
                static let SOURCE = "source"
                static let RAW = "raw"
                static let TEXT = "text"
                static let PURPOSE = "purpose"
                static let RATING = "rating"
                static let SCORE = "score"
                static let CLASSIFICATION = "classification"
                static let REASONS = "reasons"
                static let CONVERSATION_ID = "conversationID"
                static let TURN_ID = "turnID"
            }
        }
        
        enum Values {
            enum Consent {
                static let MAX_AGE = 15552000 // seconds in 180 days
            }
            
            enum Feedback {
                static let END_USER = "end-user"
                static let USER_INPUT = "user input"
            }
        }
    }
    
    // MARK: - Feedback
    
    enum FeedbackSentimentValue {
        static let THUMBS_DOWN = "Thumbs Down"
        static let THUMBS_UP = "Thumbs Up"
    }
    
    // MARK: - Shared State
    
    enum SharedState {
        enum Configuration {
            static let NAME = "com.adobe.module.configuration"

            enum Concierge {
                static let SERVER = "concierge.server"
                static let DATASTREAM = "concierge.configId"
                static let SURFACES = "concierge.surfaces"
            }
        }

        enum EdgeIdentity {
            static let NAME = "com.adobe.edge.identity"
            static let IDENTITY_MAP = "identityMap"
            static let ECID = "ECID"
            static let ID = "id"
        }
        
        enum Consent {
            static let NAME = "com.adobe.edge.consent"
            static let CONSENTS = "consents"
            static let COLLECT = "collect"
            static let VAL = "val"
        }
    }
    
    // MARK: - Defaults
    
    enum Defaults {
        static let CONSENT_VALUE = "y"
        static let MESSAGE = "I'm Concierge - your virtual product expert. I'm here to answer any questions you may have about this product. What can I do for you today?"
        static let MESSAGE_IMAGE = "https://i.ibb.co/0X8R3TG/Messages-24.png"
    }
}

