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

/// Configuration for the Concierge service connection.
public struct ConciergeConfiguration: Codable {
    var consentCollectValue: String?
    var conversationId: String?
    var datastream: String?
    var ecid: String?
    var server: String?
    var sessionId: String? {
        mutating get {
            if self._sessionId == nil {
                self._sessionId = UUID().uuidString
            }
            
            return self._sessionId
        }
    }
    private var _sessionId: String?
    var surfaces: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case consentCollectValue
        case conversationId
        case datastream
        case ecid
        case server
        case sessionId
        case surfaces
    }
        
    init(consentCollectValue: String? = nil,
         conversationId: String? = nil,
         datastream: String? = nil,
         ecid: String? = nil,
         server: String? = nil,
         sessionId: String? = nil,
         surfaces: [String] = []) {
        self.consentCollectValue = consentCollectValue
        self.conversationId = conversationId
        self.datastream = datastream
        self.ecid = ecid
        self.server = server
        self._sessionId = sessionId
        self.surfaces = surfaces
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        consentCollectValue = try container.decodeIfPresent(String.self, forKey: .consentCollectValue)
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId)
        datastream = try container.decodeIfPresent(String.self, forKey: .datastream)
        ecid = try container.decodeIfPresent(String.self, forKey: .ecid)
        server = try container.decodeIfPresent(String.self, forKey: .server)
        _sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        surfaces = try container.decodeIfPresent([String].self, forKey: .surfaces) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(consentCollectValue, forKey: .consentCollectValue)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(datastream, forKey: .datastream)
        try container.encodeIfPresent(ecid, forKey: .ecid)
        try container.encodeIfPresent(server, forKey: .server)
        try container.encodeIfPresent(_sessionId, forKey: .sessionId)        
        try container.encode(surfaces, forKey: .surfaces)
    }
}
