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

import AEPServices
import Foundation

/// Builds the URL opened when a standalone CTA button carrying a `summary` is tapped.
///
/// For an `http`/`https` URL the summary is appended as a percent-encoded `summary` query
/// parameter, placed before any `#fragment`. The original URL is returned unchanged when:
/// - there is no summary,
/// - the URL is not `http`/`https` (e.g. `tel:`, `mailto:`, `myapp://`) or cannot be parsed,
/// - the URL already has a `summary` query parameter (case-insensitive, percent-decoded),
/// - appending the summary would exceed `maxClickURLLength` (the summary is never truncated).
///
/// The summary text is never logged.
enum CtaSummaryURLBuilder {
    private static let LOG_TAG = "CtaSummaryURLBuilder"

    /// Longest URL the summary may produce, to stay within common server and CDN limits.
    static let maxClickURLLength = 2048

    static let summaryParameterName = "summary"

    private static let supportedSchemes: Set<String> = ["http", "https"]

    /// RFC 3986 unreserved characters; everything else in the summary is percent-encoded
    /// (including `+`, `/`, `=`, `&`, `%`, `#`, `?`, spaces and line breaks).
    private static let allowedSummaryCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    /// Returns the URL to open for a CTA tap.
    /// - Parameters:
    ///   - urlString: The destination URL sent by the backend.
    ///   - summary: The optional CTA summary.
    /// - Returns: `urlString` with the summary appended, or `urlString` unchanged (see type docs).
    static func clickURL(for urlString: String, summary: String?) -> String {
        guard let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty else {
            return urlString
        }

        // Note: unlike `URL(string:)` on iOS 17+, `URLComponents(string:)` does not auto-encode invalid
        // characters (e.g. a raw space), so such a URL fails here and opens without the summary.
        // Acceptable: the backend is expected to send valid, already-encoded URLs.
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              supportedSchemes.contains(scheme) else {
            Log.debug(label: LOG_TAG, "CTA summary not appended: URL scheme is not http(s) or the URL could not be parsed.")
            return urlString
        }

        // `queryItems` names are percent-decoded, so `%73ummary` is detected as `summary`.
        let hasSummaryParameter = components.queryItems?.contains {
            $0.name.caseInsensitiveCompare(summaryParameterName) == .orderedSame
        } ?? false
        if hasSummaryParameter {
            Log.debug(label: LOG_TAG, "CTA summary not appended: URL already has a '\(summaryParameterName)' query parameter.")
            return urlString
        }

        guard let encodedSummary = summary.addingPercentEncoding(withAllowedCharacters: allowedSummaryCharacters) else {
            Log.debug(label: LOG_TAG, "CTA summary not appended: summary could not be percent-encoded.")
            return urlString
        }

        // Splice into the original string rather than rebuilding through `URLComponents`, so the
        // rest of the URL (encoding, ordering of existing parameters) is preserved byte for byte.
        let fragmentStart = urlString.firstIndex(of: "#") ?? urlString.endIndex
        let base = urlString[..<fragmentStart]
        let fragment = urlString[fragmentStart...]
        let separator: String
        if base.contains("?") {
            separator = (base.hasSuffix("?") || base.hasSuffix("&")) ? "" : "&"
        } else {
            separator = "?"
        }
        let clickURL = "\(base)\(separator)\(summaryParameterName)=\(encodedSummary)\(fragment)"

        guard clickURL.utf16.count <= maxClickURLLength else {
            Log.debug(label: LOG_TAG, "CTA summary not appended: resulting URL would exceed \(maxClickURLLength) characters.")
            return urlString
        }
        return clickURL
    }
}
