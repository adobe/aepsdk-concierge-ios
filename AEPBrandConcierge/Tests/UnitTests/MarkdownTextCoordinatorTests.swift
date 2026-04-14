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

final class MarkdownTextCoordinatorTests: XCTestCase {

    private var textView: UITextView!

    override func setUp() {
        super.setUp()
        textView = UITextView()
    }

    override func tearDown() {
        super.tearDown()
        textView = nil
        ConciergeLinkHandler.urlOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
    }

    // MARK: - Helpers

    private func makeCoordinator(onOpenLink: ((URL) -> Void)? = nil) -> MarkdownTextCoordinator {
        let markdownText = MarkdownText(
            attributed: NSAttributedString(string: "test"),
            onOpenLink: onOpenLink
        )
        return MarkdownTextCoordinator(parent: markdownText)
    }

    private func interact(coordinator: MarkdownTextCoordinator, url: URL) -> Bool {
        coordinator.textView(
            textView,
            shouldInteractWith: url,
            in: NSRange(location: 0, length: 1),
            interaction: .invokeDefaultAction
        )
    }

    // MARK: - Web link routing

    func testShouldInteractWith_httpLink_callsOnOpenLink() {
        let url = URL(string: "http://www.example.com")!
        var receivedURL: URL?

        let coordinator = makeCoordinator(onOpenLink: { receivedURL = $0 })
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertEqual(receivedURL, url)
    }

    func testShouldInteractWith_httpsLink_callsOnOpenLink() {
        let url = URL(string: "https://www.example.com")!
        var receivedURL: URL?

        let coordinator = makeCoordinator(onOpenLink: { receivedURL = $0 })
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertEqual(receivedURL, url)
    }

    func testShouldInteractWith_httpLink_returnsFalse() {
        let url = URL(string: "https://www.example.com")!
        let coordinator = makeCoordinator(onOpenLink: { _ in })

        let result = interact(coordinator: coordinator, url: url)

        XCTAssertFalse(result)
    }

    func testShouldInteractWith_httpLink_withNoOnOpenLink_returnsFalse() {
        let url = URL(string: "https://www.example.com")!
        let coordinator = makeCoordinator(onOpenLink: nil)

        let result = interact(coordinator: coordinator, url: url)

        XCTAssertFalse(result)
    }

    func testShouldInteractWith_httpLink_doesNotCallUrlOpener() {
        let url = URL(string: "https://www.example.com")!
        var urlOpenerCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, _ in urlOpenerCalled = true }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertFalse(urlOpenerCalled)
    }

    // MARK: - Non-web link routing

    func testShouldInteractWith_telLink_callsUrlOpener() {
        let url = URL(string: "tel:+1234567890")!
        var urlOpenerCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            urlOpenerCalled = true
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertTrue(urlOpenerCalled)
    }

    func testShouldInteractWith_mailtoLink_callsUrlOpener() {
        let url = URL(string: "mailto:user@example.com")!
        var urlOpenerCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            urlOpenerCalled = true
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertTrue(urlOpenerCalled)
    }

    func testShouldInteractWith_nonWebLink_whenUrlOpenerSucceeds_returnsFalse() {
        let url = URL(string: "tel:+1234567890")!
        ConciergeLinkHandler.urlOpener = { _, _, completion in completion?(true) }

        let coordinator = makeCoordinator()
        let result = interact(coordinator: coordinator, url: url)

        XCTAssertFalse(result)
    }

    func testShouldInteractWith_nonWebLink_whenUrlOpenerFails_returnsTrue() {
        let url = URL(string: "tel:+1234567890")!
        ConciergeLinkHandler.urlOpener = { _, _, completion in completion?(false) }

        let coordinator = makeCoordinator()
        let result = interact(coordinator: coordinator, url: url)

        XCTAssertTrue(result)
    }

    func testShouldInteractWith_telLink_passesCorrectURLToUrlOpener() {
        let url = URL(string: "tel:+1234567890")!
        var receivedURL: URL?
        ConciergeLinkHandler.urlOpener = { opened, _, completion in
            receivedURL = opened
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertEqual(receivedURL, url)
    }

    func testShouldInteractWith_nonWebLink_doesNotPassUniversalLinksOption() {
        let url = URL(string: "tel:+1234567890")!
        var receivedOptions: [UIApplication.OpenExternalURLOptionsKey: Any]?
        ConciergeLinkHandler.urlOpener = { _, options, completion in
            receivedOptions = options
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertNil(receivedOptions?[.universalLinksOnly])
    }

    func testShouldInteractWith_nonWebLink_doesNotCallOnOpenLink() {
        let url = URL(string: "tel:+1234567890")!
        var onOpenLinkCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, completion in completion?(true) }

        let coordinator = makeCoordinator(onOpenLink: { _ in onOpenLinkCalled = true })
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertFalse(onOpenLinkCalled)
    }

    func testShouldInteractWith_smsLink_callsUrlOpener() {
        let url = URL(string: "sms:+1234567890")!
        var urlOpenerCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            urlOpenerCalled = true
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertTrue(urlOpenerCalled)
    }

    func testShouldInteractWith_customSchemeLink_callsUrlOpener() {
        let url = URL(string: "myapp://example.com/path")!
        var urlOpenerCalled = false
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            urlOpenerCalled = true
            completion?(true)
        }

        let coordinator = makeCoordinator()
        _ = interact(coordinator: coordinator, url: url)

        XCTAssertTrue(urlOpenerCalled)
    }
}
