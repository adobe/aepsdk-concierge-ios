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

/// Result of decorating a markdown string with inline citation markers.
struct CitationDecoration {
    /// Annotated markdown with placeholder tokens inserted.
    let annotatedMarkdown: String
    /// Markers describing where each token was added.
    let markers: [CitationMarker]
    /// Deduplicated sources ordered by first appearance in the message.
    let deduplicatedSources: [Source]

    init(annotatedMarkdown: String, markers: [CitationMarker], deduplicatedSources: [Source]) {
        self.annotatedMarkdown = annotatedMarkdown
        self.markers = markers
        self.deduplicatedSources = deduplicatedSources
    }
}
