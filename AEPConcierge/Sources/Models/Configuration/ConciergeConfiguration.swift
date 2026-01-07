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
    var server: String?
    var datastream: String?
    var ecid: String?
    
    var sessionId: String? {
        mutating get {
            if self._sessionId == nil {
                self._sessionId = UUID().uuidString
            }
            
            return self._sessionId
        }
    }
    private var _sessionId: String?
    
    var conversationId: String?
    var surfaces: [String] = []
    
    init(server: String? = nil, datastream: String? = nil, ecid: String? = nil, _sessionId: String? = nil, conversationId: String? = nil, surfaces: [String] = []) {
        self.server = server
        self.datastream = datastream
        self.ecid = ecid
        self._sessionId = _sessionId
        self.conversationId = conversationId
        self.surfaces = surfaces
    }
}

