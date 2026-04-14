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

final class ConciergeWebViewTests: XCTestCase {

    // MARK: - mobileSafariUserAgent

    func testMobileSafariUserAgent_containsSafariToken() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4")
        XCTAssertTrue(ua.contains("Safari/604.1"), "UA must contain Safari/604.1 token")
    }

    func testMobileSafariUserAgent_containsVersionToken() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4")
        XCTAssertTrue(ua.contains("Version/18.4"), "UA must contain Version/x.x token")
    }

    func testMobileSafariUserAgent_versionTokenAppearsBeforeMobileToken() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4")
        let versionRange = ua.range(of: "Version/")
        let mobileRange = ua.range(of: "Mobile/")
        XCTAssertNotNil(versionRange)
        XCTAssertNotNil(mobileRange)
        XCTAssertLessThan(versionRange!.lowerBound, mobileRange!.lowerBound,
                          "Version/ token must appear before Mobile/ token")
    }

    func testMobileSafariUserAgent_osVersionDotsReplacedWithUnderscores() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4.1")
        XCTAssertTrue(ua.contains("18_4_1"), "OS version dots must be replaced with underscores in UA")
    }

    func testMobileSafariUserAgent_shortVersionUsedForVersionToken() {
        // Only major.minor should appear in Version/, not the patch component
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4.1")
        XCTAssertTrue(ua.contains("Version/18.4"), "Version token should use major.minor only")
        XCTAssertFalse(ua.contains("Version/18.4.1"), "Version token must not include patch component")
    }

    func testMobileSafariUserAgent_containsMozillaPrefix() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4")
        XCTAssertTrue(ua.hasPrefix("Mozilla/5.0"))
    }

    func testMobileSafariUserAgent_containsAppleWebKit() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18.4")
        XCTAssertTrue(ua.contains("AppleWebKit/605.1.15"))
    }

    func testMobileSafariUserAgent_majorVersionOnly_stillBuildsValidUA() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "18")
        XCTAssertTrue(ua.contains("Version/18"))
        XCTAssertTrue(ua.contains("Safari/604.1"))
    }

    func testMobileSafariUserAgent_patchVersion_underscoredCorrectly() {
        let ua = ConciergeWebView.mobileSafariUserAgent(for: "17.5.1")
        XCTAssertTrue(ua.contains("iPhone OS 17_5_1"))
    }
}
