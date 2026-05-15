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

final class ConciergeServiceIdentityTests: XCTestCase {

    private func makeConfiguration(
        ecid: String? = "ecid-1",
        server: String? = "server.example",
        datastream: String? = "datastream-1",
        surfaces: [String] = ["surface-a", "surface-b"],
        conversationId: String? = "conv-1",
        sessionId: String? = "session-1"
    ) -> ConciergeConfiguration {
        ConciergeConfiguration(
            conversationId: conversationId,
            datastream: datastream,
            ecid: ecid,
            server: server,
            sessionId: sessionId,
            surfaces: surfaces
        )
    }

    func test_hasSameChatServiceIdentity_allFieldsMatch_returnsTrue() {
        let left = makeConfiguration()
        let right = makeConfiguration()
        XCTAssertTrue(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_surfacesOrderDiffers_returnsTrue() {
        let left = makeConfiguration(surfaces: ["b", "a"])
        let right = makeConfiguration(surfaces: ["a", "b"])
        XCTAssertTrue(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_ecidDiffers_returnsFalse() {
        let left = makeConfiguration(ecid: "a")
        let right = makeConfiguration(ecid: "b")
        XCTAssertFalse(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_serverDiffers_returnsFalse() {
        let left = makeConfiguration(server: "one.example")
        let right = makeConfiguration(server: "two.example")
        XCTAssertFalse(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_datastreamDiffers_returnsFalse() {
        let left = makeConfiguration(datastream: "ds-1")
        let right = makeConfiguration(datastream: "ds-2")
        XCTAssertFalse(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_surfaceSetDiffers_returnsFalse() {
        let left = makeConfiguration(surfaces: ["x"])
        let right = makeConfiguration(surfaces: ["y"])
        XCTAssertFalse(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_conversationIdDiffers_stillReturnsTrue() {
        let left = makeConfiguration(conversationId: "conv-a")
        let right = makeConfiguration(conversationId: "conv-b")
        XCTAssertTrue(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_sessionIdDiffers_stillReturnsTrue() {
        let left = makeConfiguration(sessionId: "sess-a")
        let right = makeConfiguration(sessionId: "sess-b")
        XCTAssertTrue(left.hasSameChatServiceIdentity(as: right))
    }

    func test_hasSameChatServiceIdentity_optionalPrimitivesBothNil_returnsTrue() {
        let left = ConciergeConfiguration(datastream: nil, ecid: nil, server: nil, surfaces: [])
        let right = ConciergeConfiguration(datastream: nil, ecid: nil, server: nil, surfaces: [])
        XCTAssertTrue(left.hasSameChatServiceIdentity(as: right))
    }
}
