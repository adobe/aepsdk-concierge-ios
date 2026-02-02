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

final class FeedbackSentimentTests: XCTestCase {
    
    // MARK: - thumbsValue Tests
    
    func test_thumbsValue_positive_returnsThumbsUp() {
        // Given
        let sentiment = FeedbackSentiment.positive
        
        // When
        let value = sentiment.thumbsValue()
        
        // Then
        XCTAssertEqual(value, ConciergeConstants.FeedbackSentimentValue.THUMBS_UP)
    }
    
    func test_thumbsValue_negative_returnsThumbsDown() {
        // Given
        let sentiment = FeedbackSentiment.negative
        
        // When
        let value = sentiment.thumbsValue()
        
        // Then
        XCTAssertEqual(value, ConciergeConstants.FeedbackSentimentValue.THUMBS_DOWN)
    }
    
    func test_thumbsValue_positive_matchesConstant() {
        // Given
        let sentiment = FeedbackSentiment.positive
        
        // When
        let value = sentiment.thumbsValue()
        
        // Then
        XCTAssertEqual(value, "Thumbs Up")
    }
    
    func test_thumbsValue_negative_matchesConstant() {
        // Given
        let sentiment = FeedbackSentiment.negative
        
        // When
        let value = sentiment.thumbsValue()
        
        // Then
        XCTAssertEqual(value, "Thumbs Down")
    }
    
    // MARK: - Equality Tests
    
    func test_equality_sameValues_areEqual() {
        // Given
        let sentiment1 = FeedbackSentiment.positive
        let sentiment2 = FeedbackSentiment.positive
        
        // Then
        XCTAssertTrue(sentiment1 == sentiment2)
    }
    
    func test_equality_differentValues_areNotEqual() {
        // Given
        let positive = FeedbackSentiment.positive
        let negative = FeedbackSentiment.negative
        
        // Then
        XCTAssertFalse(positive == negative)
    }
    
    // MARK: - Case Completeness Tests
    
    func test_allCases_positiveAndNegative() {
        // This test ensures both cases are handled
        // Given
        let sentiments: [FeedbackSentiment] = [.positive, .negative]
        
        // When
        let values = sentiments.map { $0.thumbsValue() }
        
        // Then
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.contains("Thumbs Up"))
        XCTAssertTrue(values.contains("Thumbs Down"))
    }
}
