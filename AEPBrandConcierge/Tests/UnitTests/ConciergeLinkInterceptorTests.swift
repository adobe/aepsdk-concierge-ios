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

final class ConciergeLinkInterceptorTests: XCTestCase {

    // MARK: - Default behavior

    func testDefaultInterceptor_returnsFalseForAnyURL() {
        let interceptor = ConciergeLinkInterceptor()

        XCTAssertFalse(interceptor.handleLink(URL(string: "https://www.adobe.com")!))
        XCTAssertFalse(interceptor.handleLink(URL(string: "myapp://deep/path")!))
        XCTAssertFalse(interceptor.handleLink(URL(string: "tel:+1234567890")!))
    }

    // MARK: - Custom interceptor

    func testCustomInterceptor_returnsTrueWhenHandled() {
        let interceptor = ConciergeLinkInterceptor { url in
            url.scheme == "myapp"
        }

        XCTAssertTrue(interceptor.handleLink(URL(string: "myapp://products/123")!))
    }

    func testCustomInterceptor_returnsFalseWhenNotHandled() {
        let interceptor = ConciergeLinkInterceptor { url in
            url.scheme == "myapp"
        }

        XCTAssertFalse(interceptor.handleLink(URL(string: "https://www.adobe.com")!))
    }

    func testCustomInterceptor_receivesCorrectURL() {
        var receivedURL: URL?
        let interceptor = ConciergeLinkInterceptor { url in
            receivedURL = url
            return true
        }

        let expectedURL = URL(string: "myapp://checkout/order/456")!
        _ = interceptor.handleLink(expectedURL)

        XCTAssertEqual(receivedURL, expectedURL)
    }

    func testCustomInterceptor_canDifferentiateBetweenSchemes() {
        let interceptor = ConciergeLinkInterceptor { url in
            url.scheme == "myapp" || url.host == "special.adobe.com"
        }

        XCTAssertTrue(interceptor.handleLink(URL(string: "myapp://home")!))
        XCTAssertTrue(interceptor.handleLink(URL(string: "https://special.adobe.com/page")!))
        XCTAssertFalse(interceptor.handleLink(URL(string: "https://www.adobe.com/page")!))
        XCTAssertFalse(interceptor.handleLink(URL(string: "tel:+1234567890")!))
    }
}
