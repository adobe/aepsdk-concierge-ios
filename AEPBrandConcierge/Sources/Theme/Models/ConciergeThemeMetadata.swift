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

/// Metadata information about the theme configuration
public struct ConciergeThemeMetadata: Codable {
    public var brandName: String
    public var version: String
    public var language: String
    public var namespace: String

    private enum CodingKeys: String, CodingKey {
        case brandName
        case version
        case language
        case namespace
    }

    public init(
        brandName: String = "",
        version: String = "0.0.0",
        language: String = "en-US",
        namespace: String = "brand-concierge"
    ) {
        self.brandName = brandName
        self.version = version
        self.language = language
        self.namespace = namespace
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brandName = try container.decodeIfPresent(String.self, forKey: .brandName) ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "0.0.0"
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en-US"
        namespace = try container.decodeIfPresent(String.self, forKey: .namespace) ?? "brand-concierge"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(brandName, forKey: .brandName)
        try container.encode(version, forKey: .version)
        try container.encode(language, forKey: .language)
        try container.encode(namespace, forKey: .namespace)
    }
}
