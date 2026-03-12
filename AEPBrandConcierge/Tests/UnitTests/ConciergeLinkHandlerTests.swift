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

final class ConciergeLinkHandlerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        ConciergeLinkHandler.urlOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
    }
    
    // MARK: - isDeepLink Tests
    
    func testIsDeepLink_withHttpScheme_returnsFalse() {
        let url = URL(string: "http://www.adobe.com")!
        XCTAssertFalse(ConciergeLinkHandler.isDeepLink(url))
    }
    
    func testIsDeepLink_withHttpsScheme_returnsFalse() {
        let url = URL(string: "https://www.adobe.com")!
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
    
    // MARK: - handleURL Tests
    
    func testHandleURL_withHttpsUrl_whenNotUniversalLink_callsOpenInWebView() {
        let url = URL(string: "https://www.adobe.com")!
        let expectation = expectation(description: "openInWebView called")
        var openInWebViewCalled = false
        var openWithSystemCalled = false
        
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            completion?(false)
        }
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in
                openInWebViewCalled = true
                expectation.fulfill()
            },
            openWithSystem: { _ in openWithSystemCalled = true }
        )
        
        waitForExpectations(timeout: 1)
        XCTAssertTrue(openInWebViewCalled)
        XCTAssertFalse(openWithSystemCalled)
    }
    
    func testHandleURL_withHttpUrl_whenNotUniversalLink_callsOpenInWebView() {
        let url = URL(string: "http://www.adobe.com")!
        let expectation = expectation(description: "openInWebView called")
        var openInWebViewCalled = false
        var openWithSystemCalled = false
        
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            completion?(false)
        }
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in
                openInWebViewCalled = true
                expectation.fulfill()
            },
            openWithSystem: { _ in openWithSystemCalled = true }
        )
        
        waitForExpectations(timeout: 1)
        XCTAssertTrue(openInWebViewCalled)
        XCTAssertFalse(openWithSystemCalled)
    }
    
    func testHandleURL_withHttpsUrl_whenUniversalLinkSucceeds_doesNotCallWebView() {
        let url = URL(string: "https://www.dickssportinggoods.com/p/some-product")!
        var openInWebViewCalled = false
        var openWithSystemCalled = false
        
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            completion?(true)
        }
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in openInWebViewCalled = true },
            openWithSystem: { _ in openWithSystemCalled = true }
        )
        
        let expectation = expectation(description: "main queue drain")
        DispatchQueue.main.async { expectation.fulfill() }
        waitForExpectations(timeout: 1)
        
        XCTAssertFalse(openInWebViewCalled)
        XCTAssertFalse(openWithSystemCalled)
    }
    
    func testHandleURL_withHttpsUrl_universalLinkProbeUsesCorrectOptions() {
        let url = URL(string: "https://www.adobe.com/products")!
        var receivedOptions: [UIApplication.OpenExternalURLOptionsKey: Any]?
        
        ConciergeLinkHandler.urlOpener = { _, options, completion in
            receivedOptions = options
            completion?(false)
        }
        
        let expectation = expectation(description: "webview fallback")
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in expectation.fulfill() },
            openWithSystem: { _ in }
        )
        
        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedOptions?[.universalLinksOnly] as? Bool, true)
    }

    func testHandleURL_withCustomScheme_callsOpenWithSystem() {
        let url = URL(string: "myapp://some/path")!
        var openInWebViewCalled = false
        var openWithSystemCalled = false
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in openInWebViewCalled = true },
            openWithSystem: { _ in openWithSystemCalled = true }
        )
        
        XCTAssertFalse(openInWebViewCalled)
        XCTAssertTrue(openWithSystemCalled)
    }

    func testHandleURL_withMailto_callsOpenWithSystem() {
        let url = URL(string: "mailto:test@example.com")!
        var openInWebViewCalled = false
        var openWithSystemCalled = false
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in openInWebViewCalled = true },
            openWithSystem: { _ in openWithSystemCalled = true }
        )
        
        XCTAssertFalse(openInWebViewCalled)
        XCTAssertTrue(openWithSystemCalled)
    }

    func testHandleURL_whenNotUniversalLink_passesCorrectURLToWebViewClosure() {
        let url = URL(string: "https://www.adobe.com/products")!
        let expectation = expectation(description: "webview called with URL")
        var receivedURL: URL?
        
        ConciergeLinkHandler.urlOpener = { _, _, completion in
            completion?(false)
        }
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { receivedURL = $0; expectation.fulfill() },
            openWithSystem: { _ in }
        )
        
        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedURL, url)
    }

    func testHandleURL_passesCorrectURLToSystemClosure() {
        let url = URL(string: "tel:+1234567890")!
        var receivedURL: URL?
        
        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in },
            openWithSystem: { receivedURL = $0 }
        )
        
        XCTAssertEqual(receivedURL, url)
    }
}
