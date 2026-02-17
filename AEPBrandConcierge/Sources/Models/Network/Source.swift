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

/// Citation source information for agent responses.
public struct Source: Codable, Hashable {
    public let url: String
    public let title: String
    public let startIndex: Int
    public let endIndex: Int
    public let citationNumber: Int

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case start_index
        case end_index
        case citation_number
    }

    public init(url: String, title: String, startIndex: Int, endIndex: Int, citationNumber: Int) {
        self.url = url
        self.title = title
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.citationNumber = citationNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        url = try container.decode(String.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        startIndex = try container.decode(Int.self, forKey: .start_index)
        endIndex = try container.decode(Int.self, forKey: .end_index)
        citationNumber = try container.decode(Int.self, forKey: .citation_number)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encode(startIndex, forKey: .start_index)
        try container.encode(endIndex, forKey: .end_index)
        try container.encode(citationNumber, forKey: .citation_number)
    }
}
