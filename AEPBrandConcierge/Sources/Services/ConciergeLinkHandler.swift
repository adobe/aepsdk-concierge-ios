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
import AEPServices

/// Handles URL routing decisions for the concierge chat interface.
/// Determines whether URLs should be opened in an in-app webview, handled as universal links
/// by the host app, or delegated to the system (for deep links and custom schemes).
public enum ConciergeLinkHandler {
    
    /// URL schemes intended to load within a WKWebView: standard web protocols and WebKit
    /// internal schemes (about:blank, about:srcdoc).
    private static let webSchemes: Set<String> = ["http", "https", "about"]

    private static let blockedSchemes: Set<String> = ["javascript", "file", "content", "intent", "data"]

    static func isBlockedURL(_ url: URL) -> Bool {
        blockedSchemes.contains(url.scheme?.lowercased() ?? "")
    }

    private static func rejectBlockedURL(_ url: URL) -> Bool {
        guard isBlockedURL(url) else { return false }
        Log.warning(label: "ConciergeLinkHandler", "Blocked URL scheme: \(url.scheme ?? "")")
        return true
    }
    
    /// Injectable URL opener for testing. Defaults to `UIApplication.shared.open`.
    /// Uses KVC to access the shared application to remain safe for App Extensions.
    static var urlOpener: (
        _ url: URL,
        _ options: [UIApplication.OpenExternalURLOptionsKey: Any],
        _ completion: ((Bool) -> Void)?
    ) -> Void = { url, options, completion in
        guard let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else {
            completion?(false)
            return
        }
        application.open(url, options: options, completionHandler: completion)
    }
    
    /// Determines if the given URL is a web link that should be loaded in a WebView.
    /// Uses the set of schemes defined in `webSchemes`.
    ///
    /// - Parameter url: The URL to evaluate.
    /// - Returns: `true` if the URL should be loaded in the WebView, `false` otherwise.
    public static func isWebLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return webSchemes.contains(scheme)
    }
    
    /// Opens the URL using the appropriate handler.
    ///
    /// For custom scheme URLs (deep links), the system handler is called immediately.
    /// For http/https URLs, the system is first asked to open the URL as a universal link.
    /// If an installed app has registered the URL's domain and path via Associated Domains,
    /// that app handles the navigation natively. Otherwise, the URL falls back to the in-app webview.
    /// Dangerous schemes, including `intent:`, are ignored.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - openInWebView: Closure called when the URL should be displayed in the in-app webview.
    ///   - openWithSystem: Closure called when the URL should be handled by the system (deep links).
    public static func handleURL(
        _ url: URL,
        openInWebView: @escaping (URL) -> Void,
        openWithSystem: @escaping (URL) -> Void
    ) {
        guard !rejectBlockedURL(url) else { return }

        // "Get directions" links arrive as platform-neutral geo: URIs (RFC 5870). iOS has no
        // native geo: handler, so rewrite them to an Apple Maps directions URL, which then routes
        // through the web-link path below (opens the Maps app via universal link, or the in-app
        // webview as a fallback).
        let resolvedURL = GeoURLConverter.appleMapsDirectionsURL(from: url) ?? url

        if isWebLink(resolvedURL) {
            urlOpener(resolvedURL, [.universalLinksOnly: true]) { success in
                DispatchQueue.main.async {
                    if !success {
                        openInWebView(resolvedURL)
                    }
                }
            }
        } else {
            openWithSystem(resolvedURL)
        }
    }

    /// Routes a link tapped in chat: the host's interceptor first, then `handleURL`
    /// (installed app via universal link, otherwise the in-app webview or system handler).
    static func handleTappedLink(
        _ url: URL,
        interceptor: ConciergeLinkInterceptor,
        openInWebView: @escaping (URL) -> Void,
        openWithSystem: @escaping (URL) -> Void
    ) {
        if interceptor.handleLink(url) { return }
        handleURL(url, openInWebView: openInWebView, openWithSystem: openWithSystem)
    }

    /// Routes WebView navigations without invoking the host's chat-link callback.
    /// Only tapped HTTPS links may launch an app; automatic web redirects remain in the WebView.
    static func handleWebViewURL(
        _ url: URL,
        isUserInitiated: Bool,
        openWithSystem: (URL) -> Void,
        completion: @escaping (_ shouldLoad: Bool) -> Void
    ) {
        guard !rejectBlockedURL(url) else {
            completion(false)
            return
        }

        if isUserInitiated && url.scheme?.lowercased() == "https" {
            urlOpener(url, [.universalLinksOnly: true]) { success in
                DispatchQueue.main.async {
                    completion(!success)
                }
            }
        } else if isWebLink(url) {
            completion(true)
        } else {
            openWithSystem(url)
            completion(false)
        }
    }
}
