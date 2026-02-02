/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
@testable import AEPServices
@testable import AEPBrandConcierge

final class SessionManagerTests: XCTestCase {
    
    private var testDataStore: NamedCollectionDataStore!
    
    override func setUp() {
        super.setUp()
        // Use a unique data store name for each test to avoid cross-test pollution
        let uniqueName = "TestSessionStore_\(UUID().uuidString)"
        testDataStore = NamedCollectionDataStore(name: uniqueName)
    }
    
    override func tearDown() {
        // Clean up the data store
        testDataStore.remove(key: ConciergeConstants.Session.Keys.SESSION_ID)
        testDataStore.remove(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        testDataStore = nil
        super.tearDown()
    }
    
    // MARK: - getOrCreateSessionId Tests
    
    func test_getOrCreateSessionId_withNoExistingSession_createsNewSession() {
        // Given
        let sessionManager = SessionManager(dataStore: testDataStore)
        
        // When
        let sessionId = sessionManager.getOrCreateSessionId()
        
        // Then
        XCTAssertFalse(sessionId.isEmpty)
        XCTAssertNotNil(UUID(uuidString: sessionId), "Session ID should be a valid UUID")
    }
    
    func test_getOrCreateSessionId_withValidSession_returnsSameSession() {
        // Given
        let sessionManager = SessionManager(dataStore: testDataStore)
        let firstSessionId = sessionManager.getOrCreateSessionId()
        
        // When - Call again within TTL
        let secondSessionId = sessionManager.getOrCreateSessionId()
        
        // Then
        XCTAssertEqual(firstSessionId, secondSessionId)
    }
    
    func test_getOrCreateSessionId_withExpiredSession_createsNewSession() {
        // Given - Use a very short TTL for testing
        let shortTTL: TimeInterval = 0.1 // 100ms
        let sessionManager = SessionManager(dataStore: testDataStore, sessionTTL: shortTTL)
        let firstSessionId = sessionManager.getOrCreateSessionId()
        
        // When - Wait for session to expire
        Thread.sleep(forTimeInterval: 2.0) // Wait longer than TTL
        let secondSessionId = sessionManager.getOrCreateSessionId()
        
        // Then
        XCTAssertNotEqual(firstSessionId, secondSessionId, "Expired session should create a new one")
    }
    
    // MARK: - refreshSessionActivity Tests
    
    func test_refreshSessionActivity_extendsSessionValidity() {
        // Given - Short TTL
        let shortTTL: TimeInterval = 5.0
        let sessionManager = SessionManager(dataStore: testDataStore, sessionTTL: shortTTL)
        let initialSessionId = sessionManager.getOrCreateSessionId()
        
        // When - Refresh before expiration
        Thread.sleep(forTimeInterval: 3.0)
        sessionManager.refreshSessionActivity()
        Thread.sleep(forTimeInterval: 3.0)
        
        let sessionIdAfterRefresh = sessionManager.getOrCreateSessionId()
        
        // Then - Session should still be valid due to refresh
        XCTAssertEqual(initialSessionId, sessionIdAfterRefresh)
    }
    
    // MARK: - clearSession Tests
    
    func test_clearSession_removesSession() {
        // Given
        let sessionManager = SessionManager(dataStore: testDataStore)
        let initialSessionId = sessionManager.getOrCreateSessionId()
        
        // When
        sessionManager.clearSession()
        let newSessionId = sessionManager.getOrCreateSessionId()
        
        // Then
        XCTAssertNotEqual(initialSessionId, newSessionId, "Cleared session should create a new one")
    }
    
    func test_clearSession_whenNoSession_doesNotCrash() {
        // Given
        let sessionManager = SessionManager(dataStore: testDataStore)
        
        // When / Then - Should not crash
        sessionManager.clearSession()
        
        // Verify we can still create sessions
        let sessionId = sessionManager.getOrCreateSessionId()
        XCTAssertFalse(sessionId.isEmpty)
    }
    
    // MARK: - Multiple SessionManager Instances Tests
    
    func test_multipleInstances_shareDataStore_returnSameSession() {
        // Given
        let sessionManager1 = SessionManager(dataStore: testDataStore)
        let sessionManager2 = SessionManager(dataStore: testDataStore)
        
        // When
        let sessionId1 = sessionManager1.getOrCreateSessionId()
        let sessionId2 = sessionManager2.getOrCreateSessionId()
        
        // Then
        XCTAssertEqual(sessionId1, sessionId2, "Same data store should return same session")
    }
    
    // MARK: - Session ID Format Tests
    
    func test_sessionId_isValidUUID() {
        // Given
        let sessionManager = SessionManager(dataStore: testDataStore)
        
        // When
        let sessionId = sessionManager.getOrCreateSessionId()
        
        // Then
        XCTAssertNotNil(UUID(uuidString: sessionId), "Session ID should be a valid UUID string")
    }
}
