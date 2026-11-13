/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
*/

import Foundation
import XCTest

@testable import AEPBrandConcierge

/// Tests decoding defaults and overrides for `behavior.citations` in the theme JSON.
final class ConciergeCitationsBehaviorTests: XCTestCase {

    // MARK: - Defaults

    func test_defaults_showCitationNumbersIsTrue() {
        let behavior = ConciergeCitationsBehavior()

        XCTAssertTrue(behavior.showCitationNumbers)
        XCTAssertFalse(behavior.showLinkIcon)
    }

    // MARK: - Decoding

    func test_decoding_missingShowCitationNumbers_defaultsToTrue() throws {
        // Existing themes predate the key and must keep showing citation badges.
        let json = #"{"showLinkIcon": true}"#

        let decoded = try JSONDecoder().decode(ConciergeCitationsBehavior.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.showCitationNumbers)
        XCTAssertTrue(decoded.showLinkIcon)
    }

    func test_decoding_emptyObject_appliesDefaults() throws {
        let json = #"{}"#

        let decoded = try JSONDecoder().decode(ConciergeCitationsBehavior.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.showCitationNumbers)
        XCTAssertFalse(decoded.showLinkIcon)
    }

    func test_decoding_showCitationNumbersFalse_honored() throws {
        let json = #"{"showLinkIcon": true, "showCitationNumbers": false}"#

        let decoded = try JSONDecoder().decode(ConciergeCitationsBehavior.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.showCitationNumbers)
    }

    func test_decoding_theme_behaviorCitations_showCitationNumbersFalse_honored() throws {
        let json = #"{"behavior": {"citations": {"showCitationNumbers": false}}}"#

        let theme = try JSONDecoder().decode(ConciergeTheme.self, from: Data(json.utf8))

        XCTAssertEqual(theme.behavior.citations?.showCitationNumbers, false)
    }

    func test_decoding_theme_withoutCitations_leavesCitationsNil() throws {
        let json = #"{"behavior": {}}"#

        let theme = try JSONDecoder().decode(ConciergeTheme.self, from: Data(json.utf8))

        XCTAssertNil(theme.behavior.citations)
    }

    // MARK: - Codable round-trip

    func test_codable_roundTrip_preservesShowCitationNumbers() throws {
        let original = ConciergeCitationsBehavior(showLinkIcon: true, showCitationNumbers: false)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConciergeCitationsBehavior.self, from: encoded)

        XCTAssertTrue(decoded.showLinkIcon)
        XCTAssertFalse(decoded.showCitationNumbers)
    }

    func test_decoratingWithoutCitationNumbers_preservesSourceReadingOrder() {
        let markdown = "First source, then second source."
        let sources = [
            Source(
                url: "https://example.com/second",
                title: "Second",
                startIndex: 18,
                endIndex: 32,
                citationNumber: 2
            ),
            Source(
                url: "https://example.com/first",
                title: "First",
                startIndex: 0,
                endIndex: 12,
                citationNumber: 1
            ),
            Source(
                url: "https://example.com/first-duplicate",
                title: "First duplicate",
                startIndex: 0,
                endIndex: 12,
                citationNumber: 1
            )
        ]

        let withCitationNumbers = CitationRenderer.decorate(
            markdown: markdown,
            sources: sources,
            showCitationNumbers: true
        )
        let withoutCitationNumbers = CitationRenderer.decorate(
            markdown: markdown,
            sources: sources,
            showCitationNumbers: false
        )

        XCTAssertEqual(withoutCitationNumbers?.annotatedMarkdown, markdown)
        XCTAssertEqual(withoutCitationNumbers?.markers, [])
        XCTAssertEqual(
            withoutCitationNumbers?.deduplicatedSources.map(\.citationNumber),
            [1, 2]
        )
        XCTAssertEqual(
            withoutCitationNumbers?.deduplicatedSources,
            withCitationNumbers?.deduplicatedSources
        )
        XCTAssertNotEqual(withCitationNumbers?.annotatedMarkdown, markdown)
        XCTAssertFalse(withCitationNumbers?.markers.isEmpty ?? true)
    }
}
