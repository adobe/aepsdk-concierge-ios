/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

/// A model describing a single source reference shown beneath an agent response.
public struct ConciergeSourceReference: Identifiable, Codable, Hashable {
    public let ordinal: String
    public let link: URL

    public var id: String { ordinal + "|" + link.absoluteString }

    public init(ordinal: String, link: URL) {
        self.ordinal = ordinal
        self.link = link
    }

    private enum CodingKeys: String, CodingKey {
        case ordinal
        case link
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ordinal = try container.decode(String.self, forKey: .ordinal)
        let linkString = try container.decode(String.self, forKey: .link)
        guard let url = URL(string: linkString) else {
            throw DecodingError.dataCorruptedError(forKey: .link,
                                                   in: container,
                                                   debugDescription: "Invalid URL string: \(linkString)")
        }
        self.link = url
    }

    /// Decodes an array of `ConciergeSourceReference` from raw JSON data.
    public static func decodeArray(from data: Data) throws -> [ConciergeSourceReference] {
        let decoder = JSONDecoder()
        return try decoder.decode([ConciergeSourceReference].self, from: data)
    }
}
