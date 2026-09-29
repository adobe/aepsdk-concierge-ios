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

import AEPCore
import AEPServices
import Foundation

/// Configuration for the Concierge service connection.
public struct ConciergeConfiguration: Codable {
    var consentCollectValue: String?
    var conversationId: String?
    var datastream: String?
    var ecid: String?
    /// The Edge Identity identityMap, forwarded verbatim in request payloads. Excluded from `Codable` - not persisted.
    var identityMap: [String: Any]?
    var server: String?
    var region: String?

    /// The session ID for this configuration.
    /// On first access, retrieves an existing valid session from persistence or creates a new one.
    /// Sessions have a TTL of 30 minutes from the last network activity.
    var sessionId: String? {
        get {
            // If we have a locally set session ID, use it
            if let localSessionId = _sessionId {
                return localSessionId
            }

            // Otherwise, get or create from SessionManager
            return SessionManager.shared.getOrCreateSessionId()
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
        case region
    }

    init(consentCollectValue: String? = nil,
         conversationId: String? = nil,
         datastream: String? = nil,
         ecid: String? = nil,
         identityMap: [String: Any]? = nil,
         server: String? = nil,
         sessionId: String? = nil,
         region: String? = nil,
         surfaces: [String] = []) {
        self.consentCollectValue = consentCollectValue
        self.conversationId = conversationId
        self.datastream = datastream
        self.ecid = ecid
        self.identityMap = identityMap
        self.server = server
        self.region = region
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
        region = try container.decodeIfPresent(String.self, forKey: .region)
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
        try container.encodeIfPresent(region, forKey: .region)
        try container.encodeIfPresent(_sessionId, forKey: .sessionId)
        try container.encode(surfaces, forKey: .surfaces)
    }
}

extension ConciergeConfiguration {
    /// The identityMap to forward in request payloads; falls back to an ECID-only map so a config that passes the readiness gate still sends ECID.
    var identityMapPayload: [String: Any] {
        if let identityMap = identityMap, !identityMap.isEmpty {
            if JSONSerialization.isValidJSONObject(identityMap) {
                return identityMap
            }
            // Log namespace keys only, never id values (PII)
            Log.warning(label: ConciergeConstants.LOG_TAG, "identityMap is not valid JSON and will be omitted; namespaces: \(identityMap.keys.sorted())")
        }
        if let ecid = ecid {
            return [ConciergeConstants.Request.Keys.ECID: [[ConciergeConstants.Request.Keys.ID: ecid]]]
        }
        return [:]
    }

    /// Whether ECID, server, datastream, and surfaces match so the same in-memory `ChatView` can keep serving this Concierge connection after dismiss.
    func hasSameChatServiceIdentity(as other: ConciergeConfiguration) -> Bool {
        guard ecid == other.ecid,
              server == other.server,
              datastream == other.datastream,
              region == other.region else {
            return false
        }
        return Set(surfaces) == Set(other.surfaces)
    }
}
