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

final class CtaSummaryURLBuilderTests: XCTestCase {

    private let maxLength = CtaSummaryURLBuilder.maxClickURLLength

    private func clickURL(_ url: String, _ summary: String?) -> String {
        CtaSummaryURLBuilder.clickURL(for: url, summary: summary)
    }

    // MARK: - No summary

    func test_clickURL_returnsURL_whenSummaryNil() {
        XCTAssertEqual(clickURL("https://example.com/chat", nil), "https://example.com/chat")
    }

    func test_clickURL_returnsURL_whenSummaryEmptyOrBlank() {
        for summary in ["", "   ", "\n\t "] {
            XCTAssertEqual(clickURL("https://example.com/chat", summary), "https://example.com/chat", "summary=\(summary.debugDescription)")
        }
    }

    // MARK: - Appending

    func test_clickURL_appendsSummary_whenNoQuery() {
        XCTAssertEqual(clickURL("https://example.com/chat", "hi"), "https://example.com/chat?summary=hi")
    }

    func test_clickURL_trimsSummary() {
        XCTAssertEqual(clickURL("https://example.com/chat", "  hi  "), "https://example.com/chat?summary=hi")
    }

    func test_clickURL_encodesSpacesAsPercent20() {
        XCTAssertEqual(
            clickURL("https://www.example.com/support", "The customer asked about a refund for order 12345."),
            "https://www.example.com/support?summary=The%20customer%20asked%20about%20a%20refund%20for%20order%2012345."
        )
    }

    func test_clickURL_percentEncodesSpecialAndMultiByteCharacters() {
        let summary = "Asked: \"refund for order #12345?\" & more caf\u{E9}"

        XCTAssertEqual(
            clickURL("https://example.com/chat", summary),
            "https://example.com/chat?summary=Asked%3A%20%22refund%20for%20order%20%2312345%3F%22%20%26%20more%20caf%C3%A9"
        )
    }

    func test_clickURL_percentEncodesReservedCharactersAndLineBreak() {
        XCTAssertEqual(
            clickURL("https://example.com/chat", "a+b/c=d&e%f\ng"),
            "https://example.com/chat?summary=a%2Bb%2Fc%3Dd%26e%25f%0Ag"
        )
    }

    func test_clickURL_leavesUnreservedCharactersUnencoded() {
        XCTAssertEqual(clickURL("https://example.com/chat", "aZ0-._~"), "https://example.com/chat?summary=aZ0-._~")
    }

    func test_clickURL_addsSummaryToExistingQuery() {
        XCTAssertEqual(clickURL("https://example.com/chat?lang=en", "hi"), "https://example.com/chat?lang=en&summary=hi")
    }

    func test_clickURL_preservesExistingQueryEncoding() {
        XCTAssertEqual(
            clickURL("https://example.com/chat?q=a%20b&x=1", "hi"),
            "https://example.com/chat?q=a%20b&x=1&summary=hi"
        )
    }

    func test_clickURL_addsSummaryBeforeFragment() {
        XCTAssertEqual(clickURL("https://example.com/chat#faq?x=1", "hi"), "https://example.com/chat?summary=hi#faq?x=1")
        XCTAssertEqual(clickURL("https://example.com/chat?lang=en#faq", "hi"), "https://example.com/chat?lang=en&summary=hi#faq")
    }

    func test_clickURL_handlesURLEndingWithQuestionMark() {
        XCTAssertEqual(clickURL("https://example.com/chat?", "hi"), "https://example.com/chat?summary=hi")
    }

    func test_clickURL_handlesURLEndingWithAmpersand() {
        XCTAssertEqual(clickURL("https://example.com/chat?lang=en&", "hi"), "https://example.com/chat?lang=en&summary=hi")
    }

    func test_clickURL_handlesEmptyFragment() {
        XCTAssertEqual(clickURL("https://example.com/chat#", "hi"), "https://example.com/chat?summary=hi#")
        XCTAssertEqual(clickURL("https://example.com/chat?#", "hi"), "https://example.com/chat?summary=hi#")
    }

    func test_clickURL_resultIsAValidURLWithDecodableSummary() throws {
        let summary = "Refund for order #12345 & more?\nThanks = 100%"
        let result = clickURL("https://example.com/chat?lang=en#faq", summary)

        let components = try XCTUnwrap(URLComponents(string: result))
        XCTAssertNotNil(URL(string: result))
        XCTAssertEqual(components.queryItems?.first { $0.name == "summary" }?.value, summary)
        XCTAssertEqual(components.queryItems?.first { $0.name == "lang" }?.value, "en")
        XCTAssertEqual(components.fragment, "faq")
    }

    // MARK: - Existing summary parameter

    func test_clickURL_keepsURL_whenSummaryParameterAlreadyPresent() {
        let urls = [
            "https://example.com/chat?summary=existing",
            "https://example.com/chat?lang=en&summary=existing#faq",
            "https://example.com/chat?summary",
            "https://example.com/chat?summary=",
            "https://example.com/chat?Summary=existing",
            "https://example.com/chat?SUMMARY=existing",
            "https://example.com/chat?%73ummary=x",
            "https://example.com/chat?%53UMMARY=x"
        ]
        for url in urls {
            XCTAssertEqual(clickURL(url, "hi"), url, url)
        }
    }

    func test_clickURL_appendsSummary_whenOnlySimilarlyNamedParameterOrFragmentExists() {
        XCTAssertEqual(
            clickURL("https://example.com/chat?summary_id=1&mysummary=2", "hi"),
            "https://example.com/chat?summary_id=1&mysummary=2&summary=hi"
        )
        XCTAssertEqual(
            clickURL("https://example.com/chat#summary=existing", "hi"),
            "https://example.com/chat?summary=hi#summary=existing"
        )
        XCTAssertEqual(
            clickURL("https://example.com/summary?x=summary", "hi"),
            "https://example.com/summary?x=summary&summary=hi"
        )
    }

    // MARK: - Length limit

    func test_clickURL_appendsSummary_thatReachesLengthLimitExactly() {
        let url = "https://example.com/chat?lang=en#faq"
        let summary = String(repeating: "x", count: maxLength - url.count - "&summary=".count)

        let result = clickURL(url, summary)

        XCTAssertEqual(result, "https://example.com/chat?lang=en&summary=\(summary)#faq")
        XCTAssertEqual(result.count, maxLength)
    }

    func test_clickURL_keepsURL_whenSummaryWouldExceedLengthLimit() {
        let url = "https://example.com/chat?lang=en#faq"
        let summary = String(repeating: "x", count: maxLength - url.count - "&summary=".count + 1)

        XCTAssertEqual(clickURL(url, summary), url)
    }

    func test_clickURL_measuresLengthAfterPercentEncoding() {
        let url = "https://example.com/chat"
        // Each "é" encodes to 6 characters, so 400 fit unencoded but not encoded.
        XCTAssertEqual(clickURL(url, String(repeating: "\u{E9}", count: 400)), url)
        XCTAssertEqual(
            clickURL(url, String(repeating: "\u{E9}", count: 300)),
            "\(url)?summary=" + String(repeating: "%C3%A9", count: 300)
        )
    }

    func test_clickURL_keepsURL_whenAlreadyOverLengthLimit() {
        let url = "https://example.com/" + String(repeating: "p", count: maxLength)

        XCTAssertEqual(clickURL(url, "hi"), url)
    }

    // MARK: - Schemes

    func test_clickURL_modifiesHttpAndHttpsCaseInsensitively() {
        XCTAssertEqual(clickURL("http://example.com/chat", "hi"), "http://example.com/chat?summary=hi")
        XCTAssertEqual(clickURL("HTTPS://example.com/chat", "hi"), "HTTPS://example.com/chat?summary=hi")
        XCTAssertEqual(clickURL("Http://example.com/chat", "hi"), "Http://example.com/chat?summary=hi")
    }

    func test_clickURL_keepsNonHttpURLsUnchanged() {
        let urls = [
            "tel:+15555550100",
            "mailto:help@example.com",
            "myapp://support/chat",
            "javascript://x%0Aalert(1)",
            "geo:37.7,-122.4",
            "about:blank",
            "/support/chat",
            "example.com/chat"
        ]
        for url in urls {
            XCTAssertEqual(clickURL(url, "hi"), url, url)
        }
    }

    func test_clickURL_keepsUnparsableURLUnchanged() {
        let url = "https://exa mple.com/chat"

        XCTAssertEqual(clickURL(url, "hi"), url)
    }
}

// MARK: - ActionButton.clickURL

final class ActionButtonClickURLTests: XCTestCase {

    func test_clickURL_appendsSummary_andKeepsURLUnchanged() {
        let action = ActionButton(text: "Chat", url: "https://example.com/chat", summary: "hi")

        XCTAssertEqual(action.url, "https://example.com/chat")
        XCTAssertEqual(action.clickURL, "https://example.com/chat?summary=hi")
    }

    func test_clickURL_equalsURL_whenNoSummary() {
        XCTAssertEqual(ActionButton(text: "Chat", url: "https://example.com/chat").clickURL, "https://example.com/chat")
    }

    func test_clickURL_isNil_whenURLNil() {
        XCTAssertNil(ActionButton(text: "Chat", url: nil, summary: "hi").clickURL)
    }
}

// MARK: - CtaButtonView tap

final class CtaButtonViewTests: XCTestCase {

    override func tearDown() {
        ConciergeLinkHandler.urlOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
        super.tearDown()
    }

    /// Taps the button and returns the URL sent to tracking and the URL the SDK tried to open.
    private func tap(_ action: ActionButton) -> (tracked: String?, opened: URL?) {
        var trackedURL: String?
        var openedURL: URL?
        ConciergeLinkHandler.urlOpener = { url, _, completion in
            openedURL = url
            completion?(true) // handled as a universal link, so no further routing
        }
        CtaButtonView(action: action, onTap: { _, url in trackedURL = url }).handleTap()
        return (trackedURL, openedURL)
    }

    func test_handleTap_tracksOriginalURL_andOpensURLWithSummary() {
        let result = tap(ActionButton(text: "Chat now", url: "https://example.com/chat", summary: "refund for order 12345"))

        XCTAssertEqual(result.tracked, "https://example.com/chat")
        XCTAssertEqual(result.opened?.absoluteString, "https://example.com/chat?summary=refund%20for%20order%2012345")
    }

    func test_handleTap_withoutSummary_tracksAndOpensSameURL() {
        let result = tap(ActionButton(text: "Shop", url: "https://example.com/shop"))

        XCTAssertEqual(result.tracked, "https://example.com/shop")
        XCTAssertEqual(result.opened?.absoluteString, "https://example.com/shop")
    }

    func test_handleTap_doesNothing_whenURLNil() {
        let result = tap(ActionButton(text: "Chat", url: nil, summary: "hi"))

        XCTAssertNil(result.tracked)
        XCTAssertNil(result.opened)
    }
}
