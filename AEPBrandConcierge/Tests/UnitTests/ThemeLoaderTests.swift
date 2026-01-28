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

import XCTest
@testable import AEPBrandConcierge

final class ThemeLoaderTests: XCTestCase {
    
    // MARK: - load(from:in:) Tests
    
    func test_load_existingFile_returnsTheme() {
        // Given
        let bundle = ThemeTestHelpers.makeTestBundle()
        
        // When
        let theme = ConciergeThemeLoader.load(from: "theme-default", in: bundle)
        
        // Then
        XCTAssertNotNil(theme)
    }
    
    func test_load_nonExistentFile_returnsNil() {
        // Given
        let bundle = ThemeTestHelpers.makeTestBundle()
        
        // When
        let theme = ConciergeThemeLoader.load(from: "non-existent-file", in: bundle)
        
        // Then
        XCTAssertNil(theme)
    }
    
    // MARK: - default() Tests
    
    func test_default_returnsConciergeTheme() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
    }
    
    func test_default_allPropertiesInitialized() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        // Verify key properties have default values
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
        XCTAssertEqual(theme.layout.inputBorderRadius, CGFloat(12))
        XCTAssertEqual(theme.typography.fontSize, CGFloat(16))
        XCTAssertEqual(theme.typography.fontWeight, CodableFontWeight.regular)
        XCTAssertEqual(theme.behavior.chat.messageAlignment, ConciergeTextAlignment.leading)
    }
    
    func test_default_hasDefaultColors() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        // Colors should be initialized (not nil)
        XCTAssertNotNil(theme.colors.primary.primary)
        XCTAssertNotNil(theme.colors.surface.mainContainerBackground)
        XCTAssertNotNil(theme.colors.message.userBackground)
    }
    
    func test_default_hasDefaultLayout() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        XCTAssertEqual(theme.layout.inputHeight, CGFloat(52))
        XCTAssertEqual(theme.layout.inputBorderRadius, CGFloat(12))
        XCTAssertEqual(theme.layout.messageBorderRadius, CGFloat(10))
        XCTAssertEqual(theme.layout.chatInterfaceMaxWidth, CGFloat(768))
    }
    
    func test_default_hasDefaultComponents() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        XCTAssertEqual(theme.components.welcome.inputOrder, 3)
        XCTAssertEqual(theme.components.welcome.cardsOrder, 2)
        XCTAssertEqual(theme.layout.feedbackIconButtonSize, 44)
    }
    
    func test_default_hasDefaultBehavior() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        XCTAssertEqual(theme.behavior.multimodalCarousel.cardClickAction, "openLink")
        XCTAssertFalse(theme.behavior.input.enableVoiceInput)
        XCTAssertTrue(theme.behavior.input.disableMultiline)
        XCTAssertEqual(theme.behavior.chat.messageAlignment, ConciergeTextAlignment.leading)
    }
    
    func test_default_hasDefaultCopy() {
        // When
        let theme = ConciergeThemeLoader.default()
        
        // Then
        XCTAssertFalse(theme.copy.welcomeHeading.isEmpty)
        XCTAssertFalse(theme.copy.inputPlaceholder.isEmpty)
        XCTAssertFalse(theme.copy.errorNetwork.isEmpty)
    }
}

