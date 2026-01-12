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
import Foundation

/// Manages Concierge session persistence and TTL validation.
///
/// Sessions are stored in persistent storage and remain valid for 30 minutes from
/// the last network activity. Any network request using the session resets the TTL timer.
class SessionManager {
    
    // MARK: - Singleton
    
    static let shared = SessionManager()
    
    // MARK: - Private Properties
    
    private let dataStore: NamedCollectionDataStore
    private let sessionTTL: TimeInterval
    
    // MARK: - Initialization
    
    init(dataStore: NamedCollectionDataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME),
         sessionTTL: TimeInterval = ConciergeConstants.Session.TTL_SECONDS) {
        self.dataStore = dataStore
        self.sessionTTL = sessionTTL
    }
    
    // MARK: - Public Methods
    
    /// Retrieves the current valid session ID, or creates a new one if the existing session has expired.
    ///
    /// - Returns: A valid session ID string.
    func getOrCreateSessionId() -> String {
        // Check for existing session
        if let existingSessionId = dataStore.getString(key: ConciergeConstants.Session.Keys.SESSION_ID),
           let lastActivity: Date = dataStore.getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY) {
            
            // Check if session is still valid (within TTL)
            let timeSinceLastActivity = Date().timeIntervalSince(lastActivity)
            if timeSinceLastActivity < sessionTTL {
                return existingSessionId
            }
        }
        
        // Session expired or doesn't exist - create new one
        return createNewSession()
    }
    
    /// Updates the last activity timestamp to the current time.git
    /// This should be called after each successful network request to reset the TTL timer.
    func refreshSessionActivity() {
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date())
    }
    
    /// Clears the current session from persistence.
    /// This forces a new session to be created on the next request.
    func clearSession() {
        dataStore.remove(key: ConciergeConstants.Session.Keys.SESSION_ID)
        dataStore.remove(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
    }
    
    // MARK: - Private Methods
    
    private func createNewSession() -> String {
        let newSessionId = UUID().uuidString
        
        // Store the new session ID and current timestamp
        dataStore.set(key: ConciergeConstants.Session.Keys.SESSION_ID, value: newSessionId)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date())
        
        return newSessionId
    }
}

