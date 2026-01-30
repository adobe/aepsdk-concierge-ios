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

final class StringFormattingTests: XCTestCase {
    
    // MARK: - prettyPrintedJSON Tests
    
    func test_prettyPrintedJSON_validSimpleJSON_formatsCorrectly() {
        // Given
        let json = "{\"name\":\"John\",\"age\":30}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("\n"), "Pretty printed JSON should contain newlines")
        XCTAssertTrue(result.contains("name"))
        XCTAssertTrue(result.contains("John"))
        XCTAssertTrue(result.contains("age"))
        XCTAssertTrue(result.contains("30"))
    }
    
    func test_prettyPrintedJSON_validNestedJSON_formatsCorrectly() {
        // Given
        let json = "{\"user\":{\"name\":\"Jane\",\"address\":{\"city\":\"NYC\"}}}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("\n"), "Pretty printed JSON should contain newlines")
        XCTAssertTrue(result.contains("user"))
        XCTAssertTrue(result.contains("address"))
        XCTAssertTrue(result.contains("city"))
    }
    
    func test_prettyPrintedJSON_validArrayJSON_formatsCorrectly() {
        // Given
        let json = "[{\"id\":1},{\"id\":2},{\"id\":3}]"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("\n"), "Pretty printed JSON should contain newlines")
        XCTAssertTrue(result.contains("1"))
        XCTAssertTrue(result.contains("2"))
        XCTAssertTrue(result.contains("3"))
    }
    
    func test_prettyPrintedJSON_invalidJSON_returnsOriginalString() {
        // Given
        let invalidJson = "not valid json"
        
        // When
        let result = invalidJson.prettyPrintedJSON()
        
        // Then
        XCTAssertEqual(result, invalidJson)
    }
    
    func test_prettyPrintedJSON_emptyString_returnsOriginalString() {
        // Given
        let empty = ""
        
        // When
        let result = empty.prettyPrintedJSON()
        
        // Then
        XCTAssertEqual(result, empty)
    }
    
    func test_prettyPrintedJSON_malformedJSON_returnsOriginalString() {
        // Given
        let malformed = "{\"key\": value}" // missing quotes around value
        
        // When
        let result = malformed.prettyPrintedJSON()
        
        // Then
        XCTAssertEqual(result, malformed)
    }
    
    func test_prettyPrintedJSON_emptyObject_formatsCorrectly() {
        // Given
        let json = "{}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertFalse(result.isEmpty)
    }
    
    func test_prettyPrintedJSON_emptyArray_formatsCorrectly() {
        // Given
        let json = "[]"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertFalse(result.isEmpty)
    }
    
    func test_prettyPrintedJSON_unicodeContent_preservesContent() {
        // Given
        let json = "{\"message\":\"Hello 世界 🌍\"}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("世界"))
        XCTAssertTrue(result.contains("🌍"))
    }
    
    func test_prettyPrintedJSON_specialCharacters_preservesContent() {
        // Given
        let json = "{\"html\":\"<div>test</div>\",\"path\":\"/path/to/file\"}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        // Note: JSON serialization escapes / as \/ and may escape < and > to unicode sequences
        XCTAssertTrue(result.contains("html"))
        XCTAssertTrue(result.contains("test"))
        XCTAssertTrue(result.contains("path"))
        XCTAssertTrue(result.contains("file"))
    }
    
    func test_prettyPrintedJSON_alreadyPrettyPrinted_remainsValid() {
        // Given
        let prettyJson = """
        {
          "name": "Test",
          "value": 123
        }
        """
        
        // When
        let result = prettyJson.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("name"))
        XCTAssertTrue(result.contains("Test"))
        XCTAssertTrue(result.contains("123"))
    }
    
    func test_prettyPrintedJSON_booleanValues_preservesTypes() {
        // Given
        let json = "{\"enabled\":true,\"disabled\":false}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("true"))
        XCTAssertTrue(result.contains("false"))
    }
    
    func test_prettyPrintedJSON_nullValue_preservesNull() {
        // Given
        let json = "{\"value\":null}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then
        XCTAssertTrue(result.contains("null"))
    }
    
    func test_prettyPrintedJSON_sortedKeys_keysAreSorted() {
        // Given
        let json = "{\"zebra\":1,\"apple\":2,\"mango\":3}"
        
        // When
        let result = json.prettyPrintedJSON()
        
        // Then - Keys should be sorted alphabetically
        let appleIndex = result.range(of: "apple")?.lowerBound
        let mangoIndex = result.range(of: "mango")?.lowerBound
        let zebraIndex = result.range(of: "zebra")?.lowerBound
        
        XCTAssertNotNil(appleIndex)
        XCTAssertNotNil(mangoIndex)
        XCTAssertNotNil(zebraIndex)
        
        if let apple = appleIndex, let mango = mangoIndex, let zebra = zebraIndex {
            XCTAssertTrue(apple < mango, "apple should come before mango")
            XCTAssertTrue(mango < zebra, "mango should come before zebra")
        }
    }
}
