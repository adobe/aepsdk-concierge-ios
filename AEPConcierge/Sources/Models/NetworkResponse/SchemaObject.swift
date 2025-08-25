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

import AEPServices

class SchemaObject: Codable {
    let itemId: String
    let schema: SchemaType
    let itemData: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id
        case schema
        case data
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        itemId = try container.decode(String.self, forKey: .id)
        schema = try SchemaType(from: container.decode(String.self, forKey: .schema))
        let codableItemData = try container.decode([String: AnyCodable].self, forKey: .data)
        itemData = AnyCodable.toAnyDictionary(dictionary: codableItemData) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(itemId, forKey: .id)
        try container.encode(schema.toString(), forKey: .schema)
        try container.encode(AnyCodable.from(dictionary: itemData), forKey: .data)
    }
}

extension SchemaObject {
    var conciergeJsonContent: ConciergeJsonContentObject? {
        guard schema == .jsonContent else {
            return nil
        }
        
        return getTypedData(ConciergeJsonContentObject.self)
    }
    
    // TODO: making a generic function to get data in case we decide to support multiple schemas instead of a monolithic schema
    private func getTypedData<T>(_ type: T.Type) -> T? where T: Decodable {
        guard let itemDataAsData = try? JSONSerialization.data(withJSONObject: itemData)
        else {
            Log.debug(label: Constants.LOG_TAG, "Unable to get typed data for schema object - could not convert 'data' field to type 'Data'.")
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: itemDataAsData)
        } catch {
            Log.warning(label: Constants.LOG_TAG, "An error occurred while decoding a schema object: \(error)")
            return nil
        }
    }
}
