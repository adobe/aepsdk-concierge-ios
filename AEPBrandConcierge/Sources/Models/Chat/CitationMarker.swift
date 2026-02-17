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

/// Describes a citation marker injected into the markdown stream.
struct CitationMarker: Hashable {
    /// Placeholder token inserted into the markdown.
    let token: String
    /// Citation number displayed to the user.
    let citationNumber: Int
    /// Normalized source associated with this marker.
    let source: Source
    /// Ending offset (in characters) within the original markdown.
    let endOffset: Int

    init(token: String, citationNumber: Int, source: Source, endOffset: Int) {
        self.token = token
        self.citationNumber = citationNumber
        self.source = source
        self.endOffset = endOffset
    }
}
