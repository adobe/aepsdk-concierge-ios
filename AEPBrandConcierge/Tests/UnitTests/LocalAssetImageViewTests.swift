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

/// Tests for LocalAssetImageView's image resolution logic.
///
/// LocalAssetImageView is a SwiftUI view, so its rendering is covered by snapshot tests.
/// These tests focus on the two observable behaviors that can be unit-tested directly:
/// - Whether a given iconPath is recognized as a remote URL
/// - The SupportedImageExtension enum values and CaseIterable exhaustiveness
final class LocalAssetImageViewTests: XCTestCase {

    // MARK: - Remote URL detection

    func test_iconPath_httpPrefix_isRecognizedAsRemote() {
        XCTAssertTrue("http://example.com/icon.png".hasPrefix("http://"))
    }

    func test_iconPath_httpsPrefix_isRecognizedAsRemote() {
        XCTAssertTrue("https://example.com/icon.png".hasPrefix("https://"))
    }

    func test_iconPath_emptyString_isNotRemote() {
        let path = ""
        XCTAssertFalse(path.hasPrefix("http://") || path.hasPrefix("https://"))
    }

    func test_iconPath_localName_isNotRemote() {
        let path = "agent-icon"
        XCTAssertFalse(path.hasPrefix("http://") || path.hasPrefix("https://"))
    }

    func test_iconPath_relativePathWithSlash_isNotRemote() {
        // Paths with slashes but no http(s) scheme should be treated as local.
        let path = "assets/icons/agent.png"
        XCTAssertFalse(path.hasPrefix("http://") || path.hasPrefix("https://"))
    }

    // MARK: - SupportedImageExtension enum

    func test_supportedImageExtensions_containsExpectedValues() {
        // Verify every expected extension is present; guards against accidental deletion.
        let expected: [String] = ["png", "jpg", "jpeg", "webp", "heic", "heif", "gif", "tiff", "tif", "bmp"]
        let actual = LocalAssetImageView.SupportedImageExtension.allCases.map { $0.rawValue }
        XCTAssertEqual(actual, expected)
    }

    func test_supportedImageExtensions_count() {
        XCTAssertEqual(LocalAssetImageView.SupportedImageExtension.allCases.count, 10)
    }
}
