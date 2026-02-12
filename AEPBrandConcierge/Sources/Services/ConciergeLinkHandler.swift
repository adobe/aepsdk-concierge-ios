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

import Foundation
import UIKit

/// Handles URL routing decisions for the concierge chat interface.
/// Determines whether URLs should be opened in an in-app webview or handled by the system (for deep links).
public enum ConciergeLinkHandler {
    
    /// URL schemes that indicate web content suitable for in-app webview display.
    private static let webSchemes: Set<String> = ["http", "https"]
    
    /// Determines if the given URL is a deep link that should be handled by the system.
    /// Deep links include custom URL schemes (e.g., `myapp://`), mailto, tel, sms, and other
    /// system-handled schemes that should not be loaded in a webview.
    ///
    /// - Parameter url: The URL to evaluate.
    /// - Returns: `true` if the URL is a deep link that should be handled by the system, `false` otherwise.
    public static func isDeepLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        // If it's not a standard web scheme, treat it as a deep link
        return !webSchemes.contains(scheme)
    }
    
    /// Determines if the given URL should be opened in an in-app webview.
    /// Only standard HTTP and HTTPS URLs are suitable for webview display.
    ///
    /// - Parameter url: The URL to evaluate.
    /// - Returns: `true` if the URL should be opened in the in-app webview, `false` otherwise.
    public static func shouldOpenInWebView(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return webSchemes.contains(scheme)
    }
    
    /// Opens the URL using the appropriate handler.
    /// Deep links are passed to the system to handle, while web URLs trigger the provided webview handler.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - openInWebView: Closure called when the URL should be displayed in the in-app webview.
    ///   - openWithSystem: Closure called when the URL should be handled by the system (deep links).
    public static func handleURL(
        _ url: URL,
        openInWebView: (URL) -> Void,
        openWithSystem: (URL) -> Void
    ) {
        if shouldOpenInWebView(url) {
            openInWebView(url)
        } else {
            openWithSystem(url)
        }
    }
}
