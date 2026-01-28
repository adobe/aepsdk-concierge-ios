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

/// Response content from the conversation service.
public struct ConversationResponse: Codable {
    public let message: String
    public let promptSuggestions: [String]?
    public let multimodalElements: MultimodalElements?
    public let sources: [Source]?
    public let state: String?
}

/// Container for multimodal content elements.
public struct MultimodalElements: Codable {
    public let type: String?
    public let elements: [MultimodalElement]

    enum CodingKeys: String, CodingKey {
        case type
        case elements
    }

    public init(type: String? = nil, elements: [MultimodalElement]) {
        self.type = type
        self.elements = elements
    }

    public init(from decoder: Decoder) throws {
        // Correct shape is an object with an `elements` array
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            type = try container.decodeIfPresent(String.self, forKey: .type)
            elements = try container.decodeIfPresent([MultimodalElement].self, forKey: .elements) ?? []
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

/// A single multimodal content element (e.g., product card).
public struct MultimodalElement: Codable {
    public let id: String?
    public let type: String?
    public let width: Int?
    public let height: Int?
    public let thumbnailWidth: Int?
    public let thumbnailHeight: Int?
    public let entityInfo: EntityInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case width
        case height
        case thumbnail_width
        case thumbnail_height
        case entity_info
    }
    
    public init(id: String? = nil, type: String? = nil, width: Int? = nil, height: Int? = nil, thumbnailWidth: Int? = nil, thumbnailHeight: Int? = nil, entityInfo: EntityInfo? = nil) {
        self.id = id
        self.type = type
        self.width = width
        self.height = height
        self.thumbnailWidth = thumbnailWidth
        self.thumbnailHeight = thumbnailHeight
        self.entityInfo = entityInfo
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        thumbnailWidth = try container.decodeIfPresent(Int.self, forKey: .thumbnail_width)
        thumbnailHeight = try container.decodeIfPresent(Int.self, forKey: .thumbnail_height)
        entityInfo = try container.decodeIfPresent(EntityInfo.self, forKey: .entity_info)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(thumbnailWidth, forKey: .thumbnail_width)
        try container.encodeIfPresent(thumbnailHeight, forKey: .thumbnail_height)
        try container.encodeIfPresent(entityInfo, forKey: .entity_info)
    }
}

/// Entity information for product cards.
public struct EntityInfo: Codable {
    public let productName: String?
    public let productDescription: String?
    public let description: String?
    public let productPageURL: String?
    public let details: String?
    public let learningResource: String?
    public let productImageURL: String?
    public let backgroundColor: String?
    public let logo: String?
    public let primary: ActionButton?
    public let secondary: ActionButton?
}

/// Button action configuration.
public struct ActionButton: Codable {
    public let text: String
    public let url: String
}
