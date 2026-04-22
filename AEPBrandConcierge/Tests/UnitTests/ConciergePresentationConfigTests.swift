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

final class ConciergePresentationConfigTests: XCTestCase {

    private let customTitle = "Custom Title"
    private let customSubtitle = "Custom Subtitle"
    private let testURL = URL(string: "https://example.com")!

    override func tearDown() {
        Concierge.chatTitle = ConciergeConstants.Defaults.TITLE
        Concierge.chatSubtitle = ConciergeConstants.Defaults.SUBTITLE
        Concierge.speechCapturer = nil
        Concierge.textSpeaker = nil
        Concierge.linkInterceptor = ConciergeLinkInterceptor()
        super.tearDown()
    }

    // MARK: - applyPresentationConfiguration

    func test_applyPresentationConfiguration_setsAllProperties() {
        let capturer = MockSpeechCapturer()
        let speaker = MockSpeaker()

        Concierge.applyPresentationConfiguration(
            title: customTitle,
            subtitle: customSubtitle,
            speechCapturer: capturer,
            textSpeaker: speaker,
            handleLink: { _ in true }
        )

        XCTAssertEqual(Concierge.chatTitle, customTitle)
        XCTAssertEqual(Concierge.chatSubtitle, customSubtitle)
        XCTAssertTrue(Concierge.speechCapturer as AnyObject === capturer)
        XCTAssertTrue(Concierge.textSpeaker as AnyObject === speaker)
        XCTAssertTrue(Concierge.linkInterceptor.handleLink(testURL))
    }

    func test_applyPresentationConfiguration_withNilDefaults_resetsToDefaults() {
        Concierge.chatTitle = customTitle
        Concierge.chatSubtitle = customSubtitle
        Concierge.speechCapturer = MockSpeechCapturer()
        Concierge.textSpeaker = MockSpeaker()
        Concierge.linkInterceptor = ConciergeLinkInterceptor { _ in true }

        Concierge.applyPresentationConfiguration(
            title: nil,
            subtitle: nil,
            speechCapturer: nil,
            textSpeaker: nil,
            handleLink: nil
        )

        XCTAssertEqual(Concierge.chatTitle, ConciergeConstants.Defaults.TITLE)
        XCTAssertNil(Concierge.chatSubtitle)
        XCTAssertNil(Concierge.speechCapturer)
        XCTAssertNil(Concierge.textSpeaker)
        XCTAssertFalse(Concierge.linkInterceptor.handleLink(testURL))
    }

    func test_applyPresentationConfiguration_overwritesPreviousCustomValues() {
        let originalCapturer = MockSpeechCapturer()
        Concierge.applyPresentationConfiguration(
            title: customTitle,
            subtitle: customSubtitle,
            speechCapturer: originalCapturer,
            textSpeaker: MockSpeaker(),
            handleLink: { _ in true }
        )

        let replacementCapturer = MockSpeechCapturer()
        Concierge.applyPresentationConfiguration(
            title: "Replaced",
            subtitle: "Also Replaced",
            speechCapturer: replacementCapturer,
            textSpeaker: nil,
            handleLink: nil
        )

        XCTAssertEqual(Concierge.chatTitle, "Replaced")
        XCTAssertEqual(Concierge.chatSubtitle, "Also Replaced")
        XCTAssertTrue(Concierge.speechCapturer as AnyObject === replacementCapturer)
        XCTAssertNil(Concierge.textSpeaker)
        XCTAssertFalse(Concierge.linkInterceptor.handleLink(testURL))
    }

    // MARK: - reshow preserves stored values

    func test_reshow_preservesChatTitle() {
        Concierge.chatTitle = customTitle
        Concierge.reshow()
        XCTAssertEqual(Concierge.chatTitle, customTitle)
    }

    func test_reshow_preservesChatSubtitle() {
        Concierge.chatSubtitle = customSubtitle
        Concierge.reshow()
        XCTAssertEqual(Concierge.chatSubtitle, customSubtitle)
    }

    func test_reshow_preservesSpeechCapturer() {
        let capturer = MockSpeechCapturer()
        Concierge.speechCapturer = capturer
        Concierge.reshow()
        XCTAssertTrue(Concierge.speechCapturer as AnyObject === capturer)
    }

    func test_reshow_preservesTextSpeaker() {
        let speaker = MockSpeaker()
        Concierge.textSpeaker = speaker
        Concierge.reshow()
        XCTAssertTrue(Concierge.textSpeaker as AnyObject === speaker)
    }

    func test_reshow_preservesLinkInterceptor() {
        Concierge.linkInterceptor = ConciergeLinkInterceptor { _ in true }
        Concierge.reshow()
        XCTAssertTrue(Concierge.linkInterceptor.handleLink(testURL))
    }

    func test_reshow_preservesAllCustomValuesFromPriorConfiguration() {
        let capturer = MockSpeechCapturer()
        let speaker = MockSpeaker()

        Concierge.applyPresentationConfiguration(
            title: customTitle,
            subtitle: customSubtitle,
            speechCapturer: capturer,
            textSpeaker: speaker,
            handleLink: { _ in true }
        )

        Concierge.reshow()

        XCTAssertEqual(Concierge.chatTitle, customTitle)
        XCTAssertEqual(Concierge.chatSubtitle, customSubtitle)
        XCTAssertTrue(Concierge.speechCapturer as AnyObject === capturer)
        XCTAssertTrue(Concierge.textSpeaker as AnyObject === speaker)
        XCTAssertTrue(Concierge.linkInterceptor.handleLink(testURL))
    }
}
