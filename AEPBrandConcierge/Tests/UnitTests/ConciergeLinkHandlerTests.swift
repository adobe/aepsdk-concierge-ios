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

final class ConciergeLinkHandlerTests: XCTestCase {
    
    // MARK: - isDeepLink Tests
    
    func testIsDeepLink_withHttpScheme_returnsFalse() {
        let url = URL(string: "https://www.adobe.com")!
        XCTAssertFalse(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withHttpsScheme_returnsFalse() {
        let url = URL(string: "http://www.adobe.com")!
        XCTAssertFalse(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withCustomScheme_returnsTrue() {
        let url = URL(string: "myapp://some/path")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withUniversalLinkAppLinks_returnsFalse() {
        // Universal links use https but are handled by apps
        let url = URL(string: "https://applinks.adobe.com/open?param=value")!
        XCTAssertFalse(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withMailtoScheme_returnsTrue() {
        let url = URL(string: "mailto:test@example.com")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withTelScheme_returnsTrue() {
        let url = URL(string: "tel:+1234567890")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withSmsScheme_returnsTrue() {
        let url = URL(string: "sms:+1234567890")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withAppStoreScheme_returnsTrue() {
        let url = URL(string: "itms-apps://apps.apple.com/app/id123456")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withMapsScheme_returnsTrue() {
        let url = URL(string: "maps://?q=Adobe")!
        XCTAssertTrue(ConciergeLinkHandler.isDeepLink(url))
    }
    
    // MARK: - shouldOpenInWebView Tests
    
    func testShouldOpenInWebView_withHttpsUrl_returnsTrue() {
        let url = URL(string: "https://www.adobe.com")!
        XCTAssertTrue(ConciergeLinkHandler.shouldOpenInWebView(url))
    }
    
    func testShouldOpenInWebView_withHttpUrl_returnsTrue() {
        let url = URL(string: "http://www.adobe.com")!
        XCTAssertTrue(ConciergeLinkHandler.shouldOpenInWebView(url))
    }
    
    func testShouldOpenInWebView_withCustomScheme_returnsFalse() {
        let url = URL(string: "myapp://some/path")!
        XCTAssertFalse(ConciergeLinkHandler.shouldOpenInWebView(url))
    }
    
    func testShouldOpenInWebView_withMailto_returnsFalse() {
        let url = URL(string: "mailto:test@example.com")!
        XCTAssertFalse(ConciergeLinkHandler.shouldOpenInWebView(url))
    }
}
