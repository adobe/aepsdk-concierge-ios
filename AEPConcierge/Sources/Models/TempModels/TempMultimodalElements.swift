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

public struct TempMultimodalElements: Codable {
    public let type: String?
    public let elements: [TempElement]

    enum CodingKeys: String, CodingKey {
        case type
        case elements
    }

    public init(type: String? = nil, elements: [TempElement]) {
        self.type = type
        self.elements = elements
    }

    public init(from decoder: Decoder) throws {
        // Correct shape is an object with an `elements` array
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            type = try container.decodeIfPresent(String.self, forKey: .type)
            elements = try container.decodeIfPresent([TempElement].self, forKey: .elements) ?? []
            return
        }

        // Currently server returns array format for intermediate responses; ignore
        if (try? decoder.unkeyedContainer()) != nil {
            type = nil
            elements = []
            return
        }

        // Default to empty
        type = nil
        elements = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(elements, forKey: .elements)
    }
}
