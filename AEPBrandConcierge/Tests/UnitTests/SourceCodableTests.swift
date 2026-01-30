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

import XCTest
@testable import AEPBrandConcierge

final class SourceCodableTests: XCTestCase {
    
    // MARK: - Decoding Tests
    
    func test_decode_withSnakeCaseKeys_decodesCorrectly() throws {
        // Given
        let json = """
        {
            "url": "https://example.com",
            "title": "Example Source",
            "start_index": 10,
            "end_index": 50,
            "citation_number": 1
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let source = try JSONDecoder().decode(Source.self, from: data)
        
        // Then
        XCTAssertEqual(source.url, "https://example.com")
        XCTAssertEqual(source.title, "Example Source")
        XCTAssertEqual(source.startIndex, 10)
        XCTAssertEqual(source.endIndex, 50)
        XCTAssertEqual(source.citationNumber, 1)
    }
    
    func test_decode_withZeroIndices_decodesCorrectly() throws {
        // Given
        let json = """
        {
            "url": "https://test.com",
            "title": "Test",
            "start_index": 0,
            "end_index": 0,
            "citation_number": 0
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let source = try JSONDecoder().decode(Source.self, from: data)
        
        // Then
        XCTAssertEqual(source.startIndex, 0)
        XCTAssertEqual(source.endIndex, 0)
        XCTAssertEqual(source.citationNumber, 0)
    }
    
    func test_decode_withLargeIndices_decodesCorrectly() throws {
        // Given
        let json = """
        {
            "url": "https://test.com",
            "title": "Large Indices",
            "start_index": 999999,
            "end_index": 1000000,
            "citation_number": 100
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let source = try JSONDecoder().decode(Source.self, from: data)
        
        // Then
        XCTAssertEqual(source.startIndex, 999999)
        XCTAssertEqual(source.endIndex, 1000000)
        XCTAssertEqual(source.citationNumber, 100)
    }
    
    func test_decode_withUnicodeTitle_decodesCorrectly() throws {
        // Given
        let json = """
        {
            "url": "https://example.com",
            "title": "Títle with émojis 🎉 and ñ",
            "start_index": 5,
            "end_index": 10,
            "citation_number": 2
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let source = try JSONDecoder().decode(Source.self, from: data)
        
        // Then
        XCTAssertEqual(source.title, "Títle with émojis 🎉 and ñ")
    }
    
    // MARK: - Encoding Tests
    
    func test_encode_producesSnakeCaseKeys() throws {
        // Given
        let source = Source(
            url: "https://adobe.com",
            title: "Adobe Source",
            startIndex: 15,
            endIndex: 30,
            citationNumber: 3
        )
        
        // When
        let data = try JSONEncoder().encode(source)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Then
        XCTAssertNotNil(json?["start_index"])
        XCTAssertNotNil(json?["end_index"])
        XCTAssertNotNil(json?["citation_number"])
        XCTAssertEqual(json?["start_index"] as? Int, 15)
        XCTAssertEqual(json?["end_index"] as? Int, 30)
        XCTAssertEqual(json?["citation_number"] as? Int, 3)
    }
    
    func test_encode_thenDecode_roundTrip() throws {
        // Given
        let original = Source(
            url: "https://round.trip/test",
            title: "Round Trip Test",
            startIndex: 100,
            endIndex: 200,
            citationNumber: 5
        )
        
        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Source.self, from: encoded)
        
        // Then
        XCTAssertEqual(original.url, decoded.url)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.startIndex, decoded.startIndex)
        XCTAssertEqual(original.endIndex, decoded.endIndex)
        XCTAssertEqual(original.citationNumber, decoded.citationNumber)
    }
    
    // MARK: - Hashable Tests
    
    func test_hashable_sameValues_areEqual() {
        // Given
        let source1 = Source(url: "https://test.com", title: "Test", startIndex: 0, endIndex: 10, citationNumber: 1)
        let source2 = Source(url: "https://test.com", title: "Test", startIndex: 0, endIndex: 10, citationNumber: 1)
        
        // Then
        XCTAssertEqual(source1, source2)
        XCTAssertEqual(source1.hashValue, source2.hashValue)
    }
    
    func test_hashable_differentValues_areNotEqual() {
        // Given
        let source1 = Source(url: "https://test1.com", title: "Test 1", startIndex: 0, endIndex: 10, citationNumber: 1)
        let source2 = Source(url: "https://test2.com", title: "Test 2", startIndex: 0, endIndex: 10, citationNumber: 2)
        
        // Then
        XCTAssertNotEqual(source1, source2)
    }
    
    func test_hashable_canBeUsedInSet() {
        // Given
        let source1 = Source(url: "https://test.com", title: "Test", startIndex: 0, endIndex: 10, citationNumber: 1)
        let source2 = Source(url: "https://test.com", title: "Test", startIndex: 0, endIndex: 10, citationNumber: 1)
        let source3 = Source(url: "https://other.com", title: "Other", startIndex: 5, endIndex: 15, citationNumber: 2)
        
        // When
        let set: Set<Source> = [source1, source2, source3]
        
        // Then
        XCTAssertEqual(set.count, 2, "Set should contain 2 unique sources")
    }
    
    // MARK: - Array Decoding Tests
    
    func test_decodeArray_multipleSources_decodesCorrectly() throws {
        // Given
        let json = """
        [
            {"url": "https://one.com", "title": "One", "start_index": 0, "end_index": 5, "citation_number": 1},
            {"url": "https://two.com", "title": "Two", "start_index": 10, "end_index": 20, "citation_number": 2}
        ]
        """
        let data = json.data(using: .utf8)!
        
        // When
        let sources = try JSONDecoder().decode([Source].self, from: data)
        
        // Then
        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources[0].url, "https://one.com")
        XCTAssertEqual(sources[1].citationNumber, 2)
    }
}
