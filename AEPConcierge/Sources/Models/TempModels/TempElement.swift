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

public struct TempElement: Codable {
    public let id: String?
    public let type: String?
    public let width: Int?
    public let height: Int?
    public let thumbnailWidth: Int?
    public let thumbnailHeight: Int?
    public let entityInfo: TempEntityInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case width
        case height
        case thumbnail_width
        case thumbnail_height
        case entity_info
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        thumbnailWidth = try container.decode(Int.self, forKey: .thumbnail_width)
        thumbnailHeight = try container.decode(Int.self, forKey: .thumbnail_height)
        entityInfo = try container.decode(TempEntityInfo.self, forKey: .entity_info)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(thumbnailWidth, forKey: .thumbnail_width)
        try container.encode(thumbnailHeight, forKey: .thumbnail_height)
        try container.encode(entityInfo, forKey: .entity_info)
    }
}
