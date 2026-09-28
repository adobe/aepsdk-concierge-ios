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
        SessionManager.shared.clearSession() // no LAST_ACTIVITY recorded -> isSessionActive is false
        try ConciergeXDMContextStore.shared.update(["loggedIn": true])

        let second = Concierge.resolveSession(configuration: configuration)

        XCTAssertFalse(first === second)
        XCTAssertTrue((ConciergeXDMContextStore.shared.snapshot() as NSDictionary).isEqual(to: [:]))
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
