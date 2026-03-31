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
final class ConciergeChatViewReuseTests: XCTestCase {

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

    private func makeChatView(configuration: ConciergeConfiguration) -> ChatView {
        ChatView(
            speechCapturer: MockSpeechCapturer(),
            textSpeaker: nil,
            title: title,
            subtitle: subtitle,
            conciergeConfiguration: configuration,
            onClose: nil
        )
    }

    func test_chatView_hasSameChatServiceIdentity_forwardsToConfiguration() {
        let configuration = makeConfiguration()
        let subject = makeChatView(configuration: configuration)
        XCTAssertTrue(subject.hasSameChatServiceIdentity(as: makeConfiguration()))
        XCTAssertFalse(subject.hasSameChatServiceIdentity(as: makeConfiguration(ecid: "other")))
    }

    func test_existingOrNew_firstCall_invokesCreate() {
        var storedView: ChatView?
        var storedTitle: String?
        var storedSubtitle: String?
        var createCount = 0
        let configuration = makeConfiguration()

        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle
        ) {
            createCount += 1
            return self.makeChatView(configuration: configuration)
        }

        XCTAssertEqual(createCount, 1)
        XCTAssertNotNil(storedView)
        XCTAssertEqual(storedTitle, title)
        XCTAssertEqual(storedSubtitle, subtitle)
    }

    func test_existingOrNew_matchingHeadersAndIdentity_doesNotInvokeCreateAgain() {
        var storedView: ChatView?
        var storedTitle: String?
        var storedSubtitle: String?
        var createCount = 0
        let configuration = makeConfiguration()

        let factory = {
            createCount += 1
            return self.makeChatView(configuration: configuration)
        }

        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )
        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: makeConfiguration(surfaces: ["b", "a"]),
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )

        XCTAssertEqual(createCount, 1)
        XCTAssertNotNil(storedView)
    }

    func test_existingOrNew_differentTitle_invokesCreateAgain() {
        var storedView: ChatView?
        var storedTitle: String?
        var storedSubtitle: String?
        var createCount = 0
        let configuration = makeConfiguration()

        let factory = {
            createCount += 1
            return self.makeChatView(configuration: configuration)
        }

        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )
        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: alternateTitle,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )

        XCTAssertEqual(createCount, 2)
    }

    func test_existingOrNew_differentSubtitle_invokesCreateAgain() {
        var storedView: ChatView?
        var storedTitle: String?
        var storedSubtitle: String?
        var createCount = 0
        let configuration = makeConfiguration()

        let factory = {
            createCount += 1
            return self.makeChatView(configuration: configuration)
        }

        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )
        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: configuration,
            title: title,
            subtitle: alternateSubtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )

        XCTAssertEqual(createCount, 2)
    }

    func test_existingOrNew_differentServiceIdentity_invokesCreateAgain() {
        var storedView: ChatView?
        var storedTitle: String?
        var storedSubtitle: String?
        var createCount = 0
        let firstConfiguration = makeConfiguration()
        let secondConfiguration = makeConfiguration(ecid: "ecid-2")

        let factory = {
            createCount += 1
            return self.makeChatView(configuration: firstConfiguration)
        }

        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: firstConfiguration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )
        _ = ConciergeChatViewReuse.existingOrNew(
            configuration: secondConfiguration,
            title: title,
            subtitle: subtitle,
            storedView: &storedView,
            storedTitle: &storedTitle,
            storedSubtitle: &storedSubtitle,
            create: factory
        )

        XCTAssertEqual(createCount, 2)
    }
}
