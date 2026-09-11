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

/// Converts the platform-neutral `geo:` URI (RFC 5870) the Concierge backend emits for
/// "Get directions" links into an Apple Maps directions URL.
///
/// The backend sends coordinates when it has them (`geo:<lat>,<lng>?q=<label>`) or the
/// coordinate-less fallback `geo:0,0?q=<url-encoded address>`. iOS has no native `geo:` handler,
/// so the link is rewritten to `https://maps.apple.com/?daddr=<destination>` — which opens
/// turn-by-turn directions — before it is opened.
enum GeoURLConverter {

    /// Returns an Apple Maps directions URL for a `geo:` URL, or `nil` when `url` is not a `geo:`
    /// URI or carries no usable destination.
    ///
    /// Real coordinates are preferred as the destination (exact routing); when the coordinates are
    /// the `0,0` placeholder, the `q` address query is used instead.
    ///
    /// The `q` address is decoded and re-encoded via `URLComponents`. Per the backend contract its
    /// spaces are percent-encoded (`%20`), not `+`-encoded, so they round-trip to spaces in `daddr`;
    /// a `+`-encoded space would be forwarded literally.
    ///
    /// - Parameter url: A `geo:` URI as emitted by the backend.
    /// - Returns: An `https://maps.apple.com/?daddr=…` directions URL, or `nil`.
    static func appleMapsDirectionsURL(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == "geo",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let addressQuery = components.queryItems?
            .first { $0.name == "q" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer exact coordinates; fall back to the address query when they are the 0,0 placeholder.
        let destination = coordinates(from: components.path)
            ?? (addressQuery?.isEmpty == false ? addressQuery : nil)
        guard let destination else { return nil }

        var maps = URLComponents()
        maps.scheme = "https"
        maps.host = "maps.apple.com"
        maps.path = "/"
        maps.queryItems = [URLQueryItem(name: "daddr", value: destination)]
        return maps.url
    }

    /// Returns a `"lat,lng"` string when `path` holds real coordinates, or `nil` when it is empty,
    /// unparseable, or the `0,0` placeholder the backend uses when it has no coordinates.
    ///
    /// Only a bare `lat,lng` pair is recognized. RFC 5870 extras — a third altitude component
    /// (`lat,lng,alt`) or `;`-delimited parameters (e.g. `;u=35`) — are not parsed and fall back to
    /// the `q` address. This matches the backend contract, which emits `geo:0,0?q=<address>` or a
    /// bare `lat,lng` today; revisit if it ever adds those extras.
    private static func coordinates(from path: String) -> String? {
        let parts = path.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else {
            return nil
        }
        if latitude == 0, longitude == 0 { return nil }  // placeholder — no real coordinates
        return "\(parts[0]),\(parts[1])"
    }
}
