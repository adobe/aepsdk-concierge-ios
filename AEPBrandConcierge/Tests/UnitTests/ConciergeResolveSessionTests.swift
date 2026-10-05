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
/// interaction with `ConciergeXDMContextStore` - context is scoped to the backend session and
/// survives presentation-only changes, but expires with the session or service identity.
@MainActor
final class ConciergeResolveSessionTests: XCTestCase {

    private let configuration = ConciergeConfiguration(datastream: "ds-1", ecid: "ecid-1", server: "server.example", surfaces: ["surface-a"])

    override func setUp() {
        super.setUp()
        Concierge.currentSession = nil
        Concierge.chatTitle = ConciergeConstants.Defaults.TITLE
        Concierge.chatSubtitle = ConciergeConstants.Defaults.SUBTITLE
        SessionManager.shared.clearSession()
        ConciergeXDMContextStore.shared.clear()
    }

    override func tearDown() {
        Concierge.currentSession = nil
        Concierge.chatTitle = ConciergeConstants.Defaults.TITLE
        Concierge.chatSubtitle = ConciergeConstants.Defaults.SUBTITLE
        SessionManager.shared.clearSession()
        ConciergeXDMContextStore.shared.clear()
        super.tearDown()
    }

    func test_noPriorSession_createsANewSession_andPreservesContextSetBeforeTheFirstShow() throws {
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        let initialSessionID: String? = dataStore.getString(key: ConciergeConstants.Session.Keys.SESSION_ID)
        let initialActivity: Date? = dataStore.getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        XCTAssertNil(initialSessionID)
        XCTAssertNil(initialActivity)

        try ConciergeXDMContextStore.shared.update(["loggedIn": true])
        XCTAssertFalse(SessionManager.shared.isSessionActive, "Updating context must not create a backend session")
        let sessionIDAfterUpdate: String? = dataStore.getString(key: ConciergeConstants.Session.Keys.SESSION_ID)
        let activityAfterUpdate: Date? = dataStore.getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        XCTAssertNil(sessionIDAfterUpdate)
        XCTAssertNil(activityAfterUpdate)

        let session = Concierge.resolveSession(configuration: configuration)

        XCTAssertTrue(session === Concierge.currentSession)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: session.sessionID) as NSDictionary).isEqual(to: ["loggedIn": true]))
    }

    func test_matchingConfigurationWithinTTL_reusesTheExistingSession_andPreservesHeldContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        SessionManager.shared.refreshSessionActivity()
        let activityBeforeUpdate: Date? = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
            .getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])
        let activityAfterUpdate: Date? = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
            .getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        XCTAssertEqual(activityAfterUpdate, activityBeforeUpdate, "Updating context must not refresh the session TTL")

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertTrue(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["loggedIn": true]))
    }

    func test_expiredTTL_createsANewSession_andClearsPreviousContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])
        SessionManager.shared.clearSession() // no LAST_ACTIVITY recorded -> isSessionActive is false

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: [:]))
    }

    func test_updateAfterExpiryBeforeShow_replacesStaleContextAndOldController() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["old": true])
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        let expiredAt = Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: expiredAt)
        XCTAssertFalse(SessionManager.shared.isSessionActive)

        try Concierge.updateXDMContext(["new": true])
        XCTAssertFalse(SessionManager.shared.isSessionActive, "Updating context after expiry must not create a backend session")
        let persistedSessionID: String? = dataStore.getString(key: ConciergeConstants.Session.Keys.SESSION_ID)
        let persistedActivity: Date? = dataStore.getObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY)
        XCTAssertEqual(persistedSessionID, first.sessionID, "Updating context must not replace the expired backend session")
        XCTAssertEqual(persistedActivity, expiredAt, "Updating context must not refresh an expired session")
        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertNotEqual(first.sessionID, second.sessionID)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["new": true]))
    }

    func test_pendingContextAfterExpiry_survivesReopeningAndAnotherExpiryBeforeFirstTurn() async throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try Concierge.updateXDMContext(["old": true])
        let dataStore = NamedCollectionDataStore(name: ConciergeConstants.Session.DATA_STORE_NAME)
        let expiredAt = Date().addingTimeInterval(-ConciergeConstants.Session.TTL_SECONDS - 1)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: expiredAt)
        try Concierge.updateXDMContext(["fresh": true])

        let second = Concierge.resolveSession(configuration: configuration)
        XCTAssertNotEqual(first.sessionID, second.sessionID)
        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: expiredAt)

        let third = Concierge.resolveSession(configuration: configuration)
        XCTAssertNotEqual(second.sessionID, third.sessionID)
        let requestSent = expectation(description: "First turn reaches the service")
        let service = MockChatService(configuration: third.configuration)
        service.onStreamChat = { requestSent.fulfill() }
        let controller = ChatController(
            configuration: third.configuration,
            chatService: service,
            speechCapturer: nil,
            speaker: nil
        )
        defer { controller.abandonActiveTurn() }
        controller.applyTextChange("First turn after reopening")
        controller.sendMessage(isUser: true)
        await fulfillment(of: [requestSent], timeout: 2)

        XCTAssertEqual(service.streamChatCallCount, 1)
        XCTAssertEqual(service.lastSessionID, third.sessionID)
        let fields = try XCTUnwrap(service.lastExtraXDMFields)
        XCTAssertTrue((fields as NSDictionary).isEqual(to: ["fresh": true]))
        let data = try service.createChatPayload(query: try XCTUnwrap(service.lastQuery), extraXDMFields: fields)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let events = try XCTUnwrap(payload["events"] as? [[String: Any]])
        let xdm = try XCTUnwrap(events.first?["xdm"] as? [String: Any])
        XCTAssertEqual(xdm["fresh"] as? Bool, true)
        XCTAssertNil(xdm["old"], "The outbound request must not carry expired context")

        dataStore.setObject(key: ConciergeConstants.Session.Keys.LAST_ACTIVITY, value: expiredAt)
        let fourth = Concierge.resolveSession(configuration: configuration)
        XCTAssertTrue(ConciergeXDMContextStore.shared.snapshot(for: fourth.sessionID).isEmpty,
                      "Once adopted by a turn snapshot, context must expire with its session")
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
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["new": true]))
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
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: [:]))
        first.controller.abandonActiveTurn()
    }

    func test_changedChatServiceIdentity_createsANewSession_andClearsHeldContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        SessionManager.shared.refreshSessionActivity()
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])

        let differentServer = ConciergeConfiguration(datastream: "ds-1", ecid: "ecid-1", server: "different.example", surfaces: ["surface-a"])
        let second = Concierge.resolveSession(configuration: differentServer)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: [:]))

        try ConciergeXDMContextStore.shared.update(["account": "new-user"])
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["account": "new-user"]))
    }

    func test_changedTitleRecreatesPresentationButPreservesContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["page": "pdp-123"])
        Concierge.chatTitle = "Product X"

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertTrue(first.controller !== second.controller)
        XCTAssertEqual(first.sessionID, second.sessionID)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["page": "pdp-123"]))
    }

    func test_changedSubtitleRecreatesPresentationButPreservesContext() throws {
        let first = Concierge.resolveSession(configuration: configuration)
        try ConciergeXDMContextStore.shared.update(["page": "pdp-123"])
        Concierge.chatSubtitle = "Special offers"

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertTrue(first.controller !== second.controller)
        XCTAssertEqual(first.sessionID, second.sessionID)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot(for: second.sessionID) as NSDictionary).isEqual(to: ["page": "pdp-123"]))
    }
}
