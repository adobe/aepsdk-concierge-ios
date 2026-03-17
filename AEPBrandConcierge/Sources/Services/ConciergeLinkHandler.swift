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

/// Handles URL routing decisions for the concierge chat interface.
/// Determines whether URLs should be opened in an in-app webview, handled as universal links
/// by the host app, or delegated to the system (for deep links and custom schemes).
public enum ConciergeLinkHandler {
    
    /// URL schemes intended to load within a WKWebView: standard web protocols and WebKit
    /// internal schemes (about:blank, about:srcdoc).
    private static let webSchemes: Set<String> = ["http", "https", "about"]
    
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
    /// If the host app has registered the URL's domain and path via Associated Domains,
    /// the app handles the navigation natively. Otherwise, the URL falls back to the in-app webview.
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
        if isWebLink(url) {
            urlOpener(url, [.universalLinksOnly: true]) { success in
                DispatchQueue.main.async {
                    if !success {
                        openInWebView(url)
                    }
                }
            }
        } else {
            openWithSystem(url)
        }
    }
}
