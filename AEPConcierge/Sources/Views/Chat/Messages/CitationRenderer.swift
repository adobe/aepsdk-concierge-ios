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

/// Produces inline citation markers and deduplicated source lists for agent responses.
enum CitationRenderer {

    /// Unique placeholder token prefix used to mark citation positions.
    private static let tokenPrefix = "§§CIT"
    private static let tokenSuffix = "§"

    /// Describes a citation marker injected into the markdown stream.
    struct Marker: Hashable {
        /// Placeholder token inserted into the markdown.
        let token: String
        /// Citation number displayed to the user.
        let citationNumber: Int
        /// Normalized source associated with this marker.
        let source: TempSource
        /// Ending offset (in characters) within the original markdown.
        let endOffset: Int
    }

    /// Result of decorating a markdown string with inline citation markers.
    struct Decoration {
        /// Annotated markdown with placeholder tokens inserted.
        let annotatedMarkdown: String
        /// Markers describing where each token was added.
        let markers: [Marker]
        /// Deduplicated sources ordered by first appearance in the message.
        let deduplicatedSources: [TempSource]
    }

    /// Inserts placeholder tokens at each citation boundary and returns marker metadata.
    /// - Parameters:
    ///   - markdown: Original agent response text.
    ///   - sources: Sources supplied by the concierge service.
    /// - Returns: Decoration data containing annotated markdown, markers, and deduplicated sources.
    static func decorate(markdown: String, sources: [TempSource]) -> Decoration {
        // Return early when either the markdown or source list is empty.
        guard !markdown.isEmpty, !sources.isEmpty else {
            return Decoration(annotatedMarkdown: markdown, markers: [], deduplicatedSources: [])
        }

        let characterCount = markdown.count

        struct ProcessedSource {
            let normalized: TempSource
            let end: Int
        }

        var processed: [ProcessedSource] = []

        for source in sources {
        // Clamp the end index to the bounds of the message to avoid invalid ranges.
            let clampedEnd = max(0, min(source.endIndex, characterCount))
            let normalized = TempSource(
                url: source.url,
                title: source.title,
                startIndex: source.startIndex,
                endIndex: clampedEnd,
                citationNumber: source.citationNumber
            )
            processed.append(ProcessedSource(normalized: normalized, end: clampedEnd))
        }

        // If every source collapsed to an invalid range, fall back to the original text.
        guard !processed.isEmpty else {
            return Decoration(annotatedMarkdown: markdown, markers: [], deduplicatedSources: [])
        }

        // Sort so markers are inserted in reading order (ties broken by citation number for determinism).
        processed.sort { lhs, rhs in
            if lhs.end == rhs.end {
                return lhs.normalized.citationNumber < rhs.normalized.citationNumber
            }
            return lhs.end < rhs.end
        }

        var annotated = markdown
        var markers: [Marker] = []
        var uniqueTokenId = 0

        // Insert tokens starting from the highest offset so earlier inserts do not shift later indexes.
        for item in processed.sorted(by: { $0.end > $1.end }) {
            let token = makeToken(id: uniqueTokenId)
            uniqueTokenId += 1

            guard let insertIndex = annotated.index(annotated.startIndex, offsetBy: item.end, limitedBy: annotated.endIndex) else {
                continue
            }

            annotated.insert(contentsOf: token, at: insertIndex)

            // Capture metadata so downstream code can swap the token for a badge.
            let marker = Marker(
                token: token,
                citationNumber: item.normalized.citationNumber,
                source: item.normalized,
                endOffset: item.end
            )
            markers.append(marker)
        }

        // Present markers in natural reading order for consumers.
        markers.sort { $0.endOffset < $1.endOffset }

        let deduplicated = deduplicatedSources(from: markers)

        return Decoration(
            annotatedMarkdown: annotated,
            markers: markers,
            deduplicatedSources: deduplicated
        )
    }

    /// Deduplicates sources by citation number while preserving first appearance order.
    /// - Parameter markers: Markers ordered by their appearance in the text.
    /// - Returns: Array containing a single representative per citation number.
    private static func deduplicatedSources(from markers: [Marker]) -> [TempSource] {
        var seenNumbers: Set<Int> = []
        var result: [TempSource] = []

        for marker in markers {
            if seenNumbers.insert(marker.citationNumber).inserted {
                result.append(marker.source)
            }
        }

        return result
    }

    /// Deduplicates the provided array by citation number while preserving order.
    static func deduplicate(_ sources: [TempSource]) -> [TempSource] {
        var seenNumbers: Set<Int> = []
        var result: [TempSource] = []

        for source in sources {
            if seenNumbers.insert(source.citationNumber).inserted {
                result.append(source)
            }
        }

        return result
    }

    /// Generates a unique placeholder token for a given identifier.
    private static func makeToken(id: Int) -> String {
        return "\(tokenPrefix)\(id)\(tokenSuffix)"
    }
}


