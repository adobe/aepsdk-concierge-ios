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
import SwiftUI
import WebKit
import XCTest
@testable import AEPBrandConcierge

final class ConciergeLinkHandlerTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        ConciergeLinkHandler.urlOpener = { url, options, completion in
            UIApplication.shared.open(url, options: options, completionHandler: completion)
        }
    }
    
    // MARK: - isWebLink Tests
    
    func testIsWebLink_withHttpScheme_returnsTrue() {
        let url = URL(string: "http://www.example.com")!
        XCTAssertTrue(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withHttpsScheme_returnsTrue() {
        let url = URL(string: "https://www.example.com")!
        XCTAssertTrue(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withAboutBlank_returnsTrue() {
        let url = URL(string: "about:blank")!
        XCTAssertTrue(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withAboutSrcdoc_returnsTrue() {
        let url = URL(string: "about:srcdoc")!
        XCTAssertTrue(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withCustomScheme_returnsFalse() {
        let url = URL(string: "myapp://example.com/path")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withMailtoScheme_returnsFalse() {
        let url = URL(string: "mailto:user@example.com")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withTelScheme_returnsFalse() {
        let url = URL(string: "tel:+1234567890")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withSmsScheme_returnsFalse() {
        let url = URL(string: "sms:+1234567890")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withAppStoreScheme_returnsFalse() {
        let url = URL(string: "itms-apps://apps.apple.com/app/id123456")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withMapsScheme_returnsFalse() {
        let url = URL(string: "maps://?q=example")!
        XCTAssertFalse(ConciergeLinkHandler.isWebLink(url))
    }
    
    func testIsWebLink_withUniversalLinkAppLinks_returnsTrue() {
        let url = URL(string: "https://applinks.example.com/open?param=value")!
        XCTAssertTrue(ConciergeLinkHandler.isWebLink(url))
    }
    
    // MARK: - handleURL Tests
    
    func testHandleURL_withHttpsUrl_whenNotUniversalLink_callsOpenInWebView() {
        let url = URL(string: "https://www.example.com")!
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
        let url = URL(string: "http://www.example.com")!
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
        let url = URL(string: "https://www.example.com/some-product")!
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
        let url = URL(string: "https://www.example.com/products")!
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
        let url = URL(string: "myapp://example.com/path")!
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
        let url = URL(string: "mailto:user@example.com")!
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
        let url = URL(string: "https://www.example.com/products")!
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

    // MARK: - handleURL geo: (Get directions) Tests

    func testHandleURL_withGeoUrl_probesAppleMapsUniversalLinkWithCorrectOptions() {
        let url = URL(string: "geo:0,0?q=The%20Mall%20At%20Robinson%2C%20Pittsburgh%2C%20PA%2015205-4834")!
        var probedURL: URL?
        var probedOptions: [UIApplication.OpenExternalURLOptionsKey: Any]?

        ConciergeLinkHandler.urlOpener = { openedURL, options, completion in
            probedURL = openedURL
            probedOptions = options
            completion?(true)
        }

        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in },
            openWithSystem: { _ in }
        )

        let drain = expectation(description: "main queue drain")
        DispatchQueue.main.async { drain.fulfill() }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(
            probedURL?.absoluteString,
            "https://maps.apple.com/?daddr=The%20Mall%20At%20Robinson,%20Pittsburgh,%20PA%2015205-4834"
        )
        XCTAssertEqual(probedOptions?[.universalLinksOnly] as? Bool, true)
    }

    func testHandleURL_withGeoUrl_whenMapsAppUnavailable_opensAppleMapsInWebView() {
        let url = URL(string: "geo:0,0?q=Ross%20Park%20Mall%2C%20Pittsburgh%2C%20PA%2015237-3803")!
        let expectation = expectation(description: "openInWebView called")
        var webViewURL: URL?
        var openWithSystemCalled = false

        ConciergeLinkHandler.urlOpener = { _, _, completion in
            completion?(false)
        }

        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { webViewURL = $0; expectation.fulfill() },
            openWithSystem: { _ in openWithSystemCalled = true }
        )

        waitForExpectations(timeout: 1)
        XCTAssertEqual(
            webViewURL?.absoluteString,
            "https://maps.apple.com/?daddr=Ross%20Park%20Mall,%20Pittsburgh,%20PA%2015237-3803"
        )
        XCTAssertFalse(openWithSystemCalled)
    }

    func testHandleURL_withGeoUrl_realCoordinates_probesAppleMapsWithCoordinateDaddr() {
        let url = URL(string: "geo:37.6788,-122.4567?q=DICK%27S")!
        var probedURL: URL?

        ConciergeLinkHandler.urlOpener = { openedURL, _, completion in
            probedURL = openedURL
            completion?(true)
        }

        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { _ in },
            openWithSystem: { _ in }
        )

        let drain = expectation(description: "main queue drain")
        DispatchQueue.main.async { drain.fulfill() }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(probedURL?.absoluteString, "https://maps.apple.com/?daddr=37.6788,-122.4567")
    }

    func testHandleURL_blockedSchemes_neverReachAnyOpener() {
        ConciergeLinkHandler.urlOpener = { _, _, _ in
            XCTFail("Blocked links must not probe installed apps")
        }

        for scheme in ["intent", "InTeNt", "javascript", "file", "content", "data"] {
            ConciergeLinkHandler.handleURL(
                URL(string: "\(scheme):example")!,
                openInWebView: { _ in XCTFail("Blocked links must not load in the WebView") },
                openWithSystem: { _ in XCTFail("Blocked links must not reach the system") }
            )
        }
    }

    // MARK: - Tapped chat link routing order

    func testHandleTappedLink_hostDeclines_triesNativeAppThenFallsBackToWebViewOnlyWhenUnclaimed() {
        let destination = URL(string: "https://maps.apple.com/?daddr=arena")!
        for appAccepted in [true, false] {
            var routingOrder: [String] = []
            ConciergeLinkHandler.urlOpener = { openedURL, options, completion in
                XCTAssertEqual(openedURL, destination)
                XCTAssertEqual(options[.universalLinksOnly] as? Bool, true)
                routingOrder.append("nativeApp")
                completion?(appAccepted)
            }
            let interceptor = ConciergeLinkInterceptor { url in
                XCTAssertEqual(url, destination)
                routingOrder.append("hostCallback")
                return false
            }

            ConciergeLinkHandler.handleTappedLink(
                destination,
                interceptor: interceptor,
                openInWebView: { url in
                    XCTAssertEqual(url, destination)
                    routingOrder.append("webView")
                },
                openWithSystem: { _ in XCTFail("HTTPS links must not use the system handler") }
            )
            let drain = expectation(description: "main queue drained (appAccepted: \(appAccepted))")
            DispatchQueue.main.async { drain.fulfill() }
            waitForExpectations(timeout: 1)

            XCTAssertEqual(
                routingOrder,
                appAccepted ? ["hostCallback", "nativeApp"] : ["hostCallback", "nativeApp", "webView"]
            )
        }
    }

    func testHandleTappedLink_hostClaims_skipsNativeAppAndWebView() {
        ConciergeLinkHandler.urlOpener = { _, _, _ in
            XCTFail("A host-claimed link must not probe installed apps")
        }
        var hostCalls = 0
        let interceptor = ConciergeLinkInterceptor { _ in
            hostCalls += 1
            return true
        }

        ConciergeLinkHandler.handleTappedLink(
            URL(string: "https://example.com/claimed")!,
            interceptor: interceptor,
            openInWebView: { _ in XCTFail("A host-claimed link must not open the WebView") },
            openWithSystem: { _ in XCTFail("A host-claimed link must not reach the system") }
        )
        let drain = expectation(description: "main queue drained")
        DispatchQueue.main.async { drain.fulfill() }
        waitForExpectations(timeout: 1)

        XCTAssertEqual(hostCalls, 1)
    }

    @MainActor
    func testWebView_tappedHttpsLink_triesNativeAppThenAllowsOnlyUnclaimedNavigation() {
        let destination = URL(string: "https://maps.google.com/maps?q=arena")!
        for appAccepted in [true, false] {
            var routingOrder: [String] = []
            ConciergeLinkHandler.urlOpener = { openedURL, options, completion in
                XCTAssertEqual(openedURL, destination)
                XCTAssertEqual(options[.universalLinksOnly] as? Bool, true)
                routingOrder.append("native app")
                completion?(appAccepted)
            }

            let wrapper = ConciergeWebView(
                url: URL(string: "about:blank")!,
                currentURLString: .constant("about:blank"),
                isLoading: .constant(false),
                onOpenDeepLink: { _ in XCTFail("An HTTPS link must not open a browser") }
            )
            let finished = expectation(description: "Navigation policy after native-app result")
            wrapper.makeCoordinator().webView(
                WKWebView(),
                decidePolicyFor: TestWebNavigationAction(
                    url: destination, type: .linkActivated, targetFrame: TestFrameInfo(isMainFrame: true)
                )
            ) { policy in
                routingOrder.append("navigation policy")
                XCTAssertEqual(policy, appAccepted ? .cancel : .allow)
                finished.fulfill()
            }
            waitForExpectations(timeout: 1)
            XCTAssertEqual(routingOrder, ["native app", "navigation policy"])
        }
    }

    @MainActor
    func testWebView_tappedHttpsLink_probesNativeAppOnlyForMainFrameNavigations() {
        let destination = URL(string: "https://maps.google.com/maps?q=arena")!
        let cases: [(name: String, frame: WKFrameInfo?, expectsProbe: Bool)] = [
            ("main frame", TestFrameInfo(isMainFrame: true), true),
            ("new window", nil, false),
            ("subframe", TestFrameInfo(isMainFrame: false), false)
        ]
        for testCase in cases {
            var probes = 0
            ConciergeLinkHandler.urlOpener = { _, _, completion in
                probes += 1
                completion?(false)
            }
            let wrapper = ConciergeWebView(
                url: URL(string: "about:blank")!,
                currentURLString: .constant("about:blank"),
                isLoading: .constant(false),
                onOpenDeepLink: { _ in XCTFail("HTTPS links must not reach the system handler") }
            )
            let finished = expectation(description: testCase.name)
            wrapper.makeCoordinator().webView(
                WKWebView(),
                decidePolicyFor: TestWebNavigationAction(
                    url: destination, type: .linkActivated, targetFrame: testCase.frame
                )
            ) { policy in
                XCTAssertEqual(policy, .allow, testCase.name)
                finished.fulfill()
            }
            waitForExpectations(timeout: 1)
            XCTAssertEqual(probes, testCase.expectsProbe ? 1 : 0, testCase.name)
        }
    }

    @MainActor
    func testWebView_automaticNavigationsAndTappedHttp_stayInWebViewWithoutNativeAppProbe() {
        ConciergeLinkHandler.urlOpener = { _, _, _ in
            XCTFail("Only tapped HTTPS links may probe installed apps")
        }
        let wrapper = ConciergeWebView(
            url: URL(string: "about:blank")!,
            currentURLString: .constant("about:blank"),
            isLoading: .constant(false),
            onOpenDeepLink: { _ in XCTFail("Web navigations must stay in the WebView") }
        )
        let coordinator = wrapper.makeCoordinator()
        let cases: [(String, WKNavigationType)] = [
            ("https://maps.google.com/redirect", .other),
            ("https://example.com/form", .formSubmitted),
            ("https://example.com/history", .backForward),
            ("https://example.com/reload", .reload),
            ("http://example.com/link", .linkActivated),
            ("about:blank", .other)
        ]
        for (urlString, type) in cases {
            var completed = false
            coordinator.webView(
                WKWebView(),
                decidePolicyFor: TestWebNavigationAction(url: URL(string: urlString)!, type: type)
            ) { policy in
                XCTAssertEqual(policy, .allow, urlString)
                completed = true
            }
            XCTAssertTrue(completed, "Web navigation should not wait for an app probe")
        }
    }

    @MainActor
    func testWebView_blockedSchemes_cancelTapsAndRedirectsWithoutOpeningApps() {
        ConciergeLinkHandler.urlOpener = { _, _, _ in
            XCTFail("Blocked links must not probe installed apps")
        }
        let wrapper = ConciergeWebView(
            url: URL(string: "about:blank")!,
            currentURLString: .constant("about:blank"),
            isLoading: .constant(false),
            onOpenDeepLink: { _ in XCTFail("Blocked links must not reach the system") }
        )
        let coordinator = wrapper.makeCoordinator()
        for scheme in ["intent", "InTeNt", "javascript", "file", "content", "data"] {
            for type: WKNavigationType in [.linkActivated, .other] {
                var completed = false
                coordinator.webView(
                    WKWebView(),
                    decidePolicyFor: TestWebNavigationAction(url: URL(string: "\(scheme):example")!, type: type)
                ) { policy in
                    XCTAssertEqual(policy, .cancel)
                    completed = true
                }
                XCTAssertTrue(completed)
            }
        }
    }

    @MainActor
    func testWebView_customScheme_isForwardedToSystemAndCancelled() {
        let destination = URL(string: "myapp://directions")!
        var systemURL: URL?
        ConciergeLinkHandler.urlOpener = { _, _, _ in
            XCTFail("Custom schemes should not probe universal links")
        }
        let wrapper = ConciergeWebView(
            url: URL(string: "about:blank")!,
            currentURLString: .constant("about:blank"),
            isLoading: .constant(false),
            onOpenDeepLink: { systemURL = $0 }
        )
        var completed = false
        wrapper.makeCoordinator().webView(
            WKWebView(),
            decidePolicyFor: TestWebNavigationAction(url: destination, type: .linkActivated)
        ) { policy in
            XCTAssertEqual(policy, .cancel)
            completed = true
        }
        XCTAssertTrue(completed)
        XCTAssertEqual(systemURL, destination)
    }

    @MainActor
    func testWebViewPopover_contentStaysInsideVisibleSafeAreaAcrossWindowSizes() throws {
        for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390),
                     CGSize(width: 768, height: 600)] {
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            let hosting = UIHostingController(rootView: WebViewPopover(
                url: URL(string: "about:blank")!, onDismiss: {}
            ))
            hosting.additionalSafeAreaInsets = UIEdgeInsets(top: 20, left: 0, bottom: 34, right: 0)
            window.rootViewController = hosting
            window.isHidden = false
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            hosting.view.layoutIfNeeded()

            let webView = try XCTUnwrap(findWebView(in: hosting.view))
            defer { webView.stopLoading() }
            let visibleBounds = hosting.view.safeAreaLayoutGuide.layoutFrame
            let contentBounds = webView.convert(webView.bounds, to: hosting.view)
            XCTAssertGreaterThan(contentBounds.height, 0)
            XCTAssertGreaterThanOrEqual(contentBounds.minY, visibleBounds.minY)
            XCTAssertLessThanOrEqual(contentBounds.maxY, visibleBounds.maxY + 1,
                                     "Web content must not run under the bottom inset at \(size)")
            XCTAssertEqual(contentBounds.maxY, visibleBounds.maxY, accuracy: 1,
                           "The WebView should use the available height, not a fixed screen height")
        }
    }

    @MainActor
    func testWebViewPopover_sheetBackgroundFillsBottomInsetBehindContent() throws {
        let size = CGSize(width: 390, height: 844)
        let bottomInset: CGFloat = 83
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let hosting = UIHostingController(rootView: WebViewPopover(
            url: URL(string: "about:blank")!, onDismiss: {}
        ))
        hosting.overrideUserInterfaceStyle = .light
        hosting.view.backgroundColor = .clear
        hosting.additionalSafeAreaInsets = UIEdgeInsets(top: 20, left: 0, bottom: bottomInset, right: 0)
        window.rootViewController = hosting
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        hosting.view.layoutIfNeeded()

        let webView = try XCTUnwrap(findWebView(in: hosting.view))
        defer { webView.stopLoading() }
        let visibleBounds = hosting.view.safeAreaLayoutGuide.layoutFrame
        XCTAssertEqual(webView.convert(webView.bounds, to: hosting.view).maxY, visibleBounds.maxY, accuracy: 1)

        let image = UIGraphicsImageRenderer(bounds: hosting.view.bounds).image { context in
            hosting.view.layer.render(in: context.cgContext)
        }
        let samplePoint = CGPoint(x: size.width / 2, y: size.height - bottomInset / 2)
        let alpha = try XCTUnwrap(alphaComponent(of: image, at: samplePoint))
        XCTAssertGreaterThan(alpha, 0.99, "The sheet surface should cover the bottom inset instead of exposing the chat behind it")
    }

    private func alphaComponent(of image: UIImage, at point: CGPoint) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let pixelX = Int(point.x * image.scale)
        let pixelY = Int(point.y * image.scale)
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: -CGFloat(pixelX), y: -CGFloat(cgImage.height - pixelY - 1),
                                         width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return CGFloat(pixel[3]) / 255
    }

    @MainActor
    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        for subview in view.subviews {
            if let webView = findWebView(in: subview) { return webView }
        }
        return nil
    }
}

private final class TestFrameInfo: WKFrameInfo {
    private let frameIsMain: Bool

    init(isMainFrame: Bool) {
        frameIsMain = isMainFrame
        super.init()
    }

    override var isMainFrame: Bool { frameIsMain }
}

private final class TestWebNavigationAction: WKNavigationAction {
    private let destination: URL
    private let type: WKNavigationType
    private let frame: WKFrameInfo?

    init(url: URL, type: WKNavigationType, targetFrame: WKFrameInfo? = nil) {
        destination = url
        self.type = type
        frame = targetFrame
        super.init()
    }

    override var request: URLRequest { URLRequest(url: destination) }
    override var navigationType: WKNavigationType { type }
    override var targetFrame: WKFrameInfo? { frame }
}
