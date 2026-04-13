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

@MainActor
final class ConciergeChatSessionTests: XCTestCase {

    private let title = "title"
    private let subtitle = "subtitle"
    private let alternateTitle = "alternate-title"
    private let alternateSubtitle = "alternate-subtitle"

    private func makeConfiguration(
        ecid: String = "ecid-1",
        surfaces: [String] = ["a", "b"]
    ) -> ConciergeConfiguration {
        ConciergeConfiguration(
            datastream: "ds",
            ecid: ecid,
            server: "server.example",
            surfaces: surfaces
        )
    }

    private func makeSession(
        configuration: ConciergeConfiguration? = nil,
        title: String? = nil,
        subtitle: String? = nil
    ) -> ConciergeChatSession {
        ConciergeChatSession(
            configuration: configuration ?? makeConfiguration(),
            title: title ?? self.title,
            subtitle: subtitle ?? self.subtitle,
            speechCapturer: MockSpeechCapturer(),
            textSpeaker: nil
        )
    }

    // MARK: - matches

    func test_matches_sameIdentityAndHeaders_returnsTrue() {
        let session = makeSession()
        XCTAssertTrue(session.matches(configuration: makeConfiguration(), title: title, subtitle: subtitle))
    }

    func test_matches_surfaceOrderDiffers_returnsTrue() {
        let session = makeSession()
        XCTAssertTrue(session.matches(
            configuration: makeConfiguration(surfaces: ["b", "a"]),
            title: title,
            subtitle: subtitle
        ))
    }

    func test_matches_differentEcid_returnsFalse() {
        let session = makeSession()
        XCTAssertFalse(session.matches(
            configuration: makeConfiguration(ecid: "ecid-2"),
            title: title,
            subtitle: subtitle
        ))
    }

    func test_matches_differentTitle_returnsFalse() {
        let session = makeSession()
        XCTAssertFalse(session.matches(
            configuration: makeConfiguration(),
            title: alternateTitle,
            subtitle: subtitle
        ))
    }

    func test_matches_differentSubtitle_returnsFalse() {
        let session = makeSession()
        XCTAssertFalse(session.matches(
            configuration: makeConfiguration(),
            title: title,
            subtitle: alternateSubtitle
        ))
    }

    // MARK: - Controller ownership

    func test_session_ownsController() {
        let session = makeSession()
        XCTAssertNotNil(session.controller)
    }

    func test_session_controllerIdentityStableAcrossAccesses() {
        let session = makeSession()
        let firstAccess = session.controller
        let secondAccess = session.controller
        XCTAssertTrue(firstAccess === secondAccess)
    }
}
