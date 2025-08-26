/*
 Copyright 2023 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

enum SchemaType: Int, Codable {
    case unknown = 0
    case jsonContent = 1
    
    /// Initializes SchemaType with the provided content schema string
    /// - Parameter schema: SchemaType content schema string
    init(from schema: String) {
        switch schema {
        case Constants.ConciergeSchemas.JSON_CONTENT:
            self = .jsonContent
            
        default:
            self = .unknown
        }
    }

    /// Returns the schema type string.
    /// - Returns: A string representing the schema type.
    public func toString() -> String {
        switch self {
        case .jsonContent:
            return Constants.ConciergeSchemas.JSON_CONTENT

        default:
            return ""
        }
    }
}
