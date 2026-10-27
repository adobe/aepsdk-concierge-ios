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

import UIKit
import XCTest
@testable import AEPBrandConcierge

final class CtaButtonViewTests: XCTestCase {

    private var openedURL: URL?

    override func setUp() {
        super.setUp()
        openedURL = nil
        ConciergeLinkHandler.urlOpener = { [weak self] url, _, completion in
            self?.openedURL = url
            completion?(true) // opened as a universal link, so nothing else runs
        }
    }

    override func tearDown() {
        ConciergeLinkHandler.urlOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
        super.tearDown()
    }

    /// Taps the button and returns the URL sent to tracking and the URL received by the host handler.
    private func tap(_ action: ActionButton, hostHandles: Bool = false) -> (tracked: String?, hostReceived: URL?) {
        var trackedURL: String?
        var hostURL: URL?
        let interceptor = ConciergeLinkInterceptor { url in
            hostURL = url
            return hostHandles
        }
        CtaButtonView(action: action, onTap: { _, url in trackedURL = url }).handleTap(linkInterceptor: interceptor)
        return (trackedURL, hostURL)
    }

    func test_handleTap_tracksOriginalURL_andOpensURLWithSummary() {
        let result = tap(ActionButton(text: "Chat now", url: "https://example.com/chat", summary: "refund for order 12345"))

        XCTAssertEqual(result.tracked, "https://example.com/chat")
        XCTAssertEqual(result.hostReceived?.absoluteString, "https://example.com/chat?summary=refund%20for%20order%2012345")
        XCTAssertEqual(openedURL?.absoluteString, "https://example.com/chat?summary=refund%20for%20order%2012345")
    }

    func test_handleTap_hostHandlesLink_receivesURLWithSummary_andSDKDoesNotOpen() {
        let result = tap(ActionButton(text: "Chat", url: "https://example.com/chat", summary: "hi"), hostHandles: true)

        XCTAssertEqual(result.tracked, "https://example.com/chat")
        XCTAssertEqual(result.hostReceived?.absoluteString, "https://example.com/chat?summary=hi")
        XCTAssertNil(openedURL)
    }

    func test_handleTap_withoutSummary_tracksAndOpensSameURL() {
        let result = tap(ActionButton(text: "Shop", url: "https://example.com/shop"))

        XCTAssertEqual(result.tracked, "https://example.com/shop")
        XCTAssertEqual(result.hostReceived?.absoluteString, "https://example.com/shop")
        XCTAssertEqual(openedURL?.absoluteString, "https://example.com/shop")
    }

    func test_handleTap_withoutInterceptor_usesDefaultAndOpensURLWithSummary() {
        var trackedURL: String?
        let action = ActionButton(text: "Chat", url: "https://example.com/chat", summary: "hi")

        CtaButtonView(action: action, onTap: { _, url in trackedURL = url }).handleTap()

        XCTAssertEqual(trackedURL, "https://example.com/chat")
        XCTAssertEqual(openedURL?.absoluteString, "https://example.com/chat?summary=hi")
    }

    func test_handleTap_doesNothing_whenURLNil() {
        let result = tap(ActionButton(text: "Chat", url: nil, summary: "hi"))

        XCTAssertNil(result.tracked)
        XCTAssertNil(result.hostReceived)
        XCTAssertNil(openedURL)
    }
}
