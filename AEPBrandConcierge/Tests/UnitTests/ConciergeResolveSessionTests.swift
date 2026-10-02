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

/// Verifies `Concierge.resolveSession(configuration:)`'s reuse-vs-new-session decision, and its
/// interaction with `ConciergeXDMContextStore` - a genuinely new session must start with a clean
/// slate, while a reused session must leave whatever context an app already accumulated intact.
@MainActor
final class ConciergeResolveSessionTests: XCTestCase {

    private let configuration = ConciergeConfiguration(datastream: "ds-1", ecid: "ecid-1", server: "server.example", surfaces: ["surface-a"])

    override func setUp() {
        super.setUp()
        Concierge.currentSession = nil
        SessionManager.shared.clearSession()
        ConciergeXDMContextStore.shared.clear()
    }

    override func tearDown() {
        Concierge.currentSession = nil
        SessionManager.shared.clearSession()
        ConciergeXDMContextStore.shared.clear()
        super.tearDown()
    }

    func test_noPriorSession_createsANewSession_andPreservesContextSetBeforeTheFirstShow() throws {
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])

        let session = Concierge.resolveSession(configuration: configuration)

        XCTAssertTrue(session === Concierge.currentSession)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: ["loggedIn": true]))
    }

    func test_matchingConfigurationWithinTTL_reusesTheExistingSession_andPreservesHeldContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        SessionManager.shared.refreshSessionActivity()
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertTrue(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: ["loggedIn": true]))
    }

    func test_expiredTTL_createsANewSession_andClearsHeldContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])
        SessionManager.shared.clearSession() // no LAST_ACTIVITY recorded -> isSessionActive is false

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: [:]))
    }

    func test_updateAfterExpiryBeforeShow_preservesNewContextAndReplacesOldController() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["old": true])
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))
        XCTAssertFalse(SessionManager.shared.isSessionActive)

        try Concierge.updateXDMContext(["new": true])
        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertNotEqual(first.sessionID, second.sessionID)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["new": true]))
    }

    func test_turnAfterExpiry_rebindsActiveChatWithoutLosingTranscriptOrNewContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        let originalSessionID = first.sessionID
        try ConciergeXDMContextStore.shared.update(["old": true])
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))
        XCTAssertFalse(SessionManager.shared.isSessionActive)

        first.controller.applyTextChange("A turn after expiry")
        first.controller.sendMessage(isUser: true)
        let newSessionID = configuration.sessionId
        XCTAssertNotEqual(originalSessionID, newSessionID)
        XCTAssertEqual(first.controller.lastTurnSessionID, newSessionID)
        try Concierge.updateXDMContext(["new": true])
        SessionManager.shared.refreshSessionActivity()
        let messageIDs = first.controller.messages.map(\.id)

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertTrue(first === second)
        XCTAssertTrue(first.controller === second.controller)
        XCTAssertEqual(second.sessionID, newSessionID)
        XCTAssertEqual(second.controller.messages.map(\.id), messageIDs)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: newSessionID) as NSDictionary).isEqual(to: ["new": true]))
        second.controller.abandonActiveTurn()
    }

    func test_inactiveChatAfterRollover_startsFreshAndClearsExpiredContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))
        first.controller.applyTextChange("A turn after expiry")
        first.controller.sendMessage(isUser: true)
        let newSessionID = configuration.sessionId
        try Concierge.updateXDMContext(["new": true])
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))
        XCTAssertFalse(SessionManager.shared.isSessionActive)

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertFalse(first.controller === second.controller)
        XCTAssertNotEqual(second.sessionID, newSessionID)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: [:]))
        first.controller.abandonActiveTurn()
    }

    func test_handoffAfterExpiry_rebindsActiveChatAndKeepsLocalMessage() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        let originalSessionID = first.sessionID
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))

        XCTAssertTrue(first.controller.handleDataHandoff(
            routingHint: "checkout",
            xdmFields: ["purchase": true],
            localMessage: "Order placed"
        ))
        let newSessionID = configuration.sessionId
        SessionManager.shared.refreshSessionActivity()
        let messageIDs = first.controller.messages.map(\.id)

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertNotEqual(originalSessionID, newSessionID)
        XCTAssertTrue(first === second)
        XCTAssertEqual(second.sessionID, newSessionID)
        XCTAssertEqual(second.controller.messages.map(\.id), messageIDs)
        second.controller.abandonActiveTurn()
    }

    func test_identityChangeAfterTurnRollover_startsFreshAndClearsContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1))
        first.controller.applyTextChange("A turn after expiry")
        first.controller.sendMessage(isUser: true)
        SessionManager.shared.refreshSessionActivity()
        try Concierge.updateXDMContext(["new": true])

        let differentIdentity = ConciergeConfiguration(datastream: "ds-1", ecid: "ecid-2", server: "server.example", surfaces: ["surface-a"])
        let second = Concierge.resolveSession(configuration: differentIdentity)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: [:]))
        first.controller.abandonActiveTurn()
    }

    func test_changedChatServiceIdentity_createsANewSession_andClearsHeldContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        SessionManager.shared.refreshSessionActivity()
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])

        let differentServer = ConciergeConfiguration(datastream: "ds-1", ecid: "ecid-1", server: "different.example", surfaces: ["surface-a"])
        let second = Concierge.resolveSession(configuration: differentServer)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: [:]))
    }
}
