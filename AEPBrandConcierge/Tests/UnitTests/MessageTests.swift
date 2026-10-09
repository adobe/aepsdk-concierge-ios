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

import UIKit
import XCTest
@testable import AEPBrandConcierge

final class MessageTests: XCTestCase {

    // MARK: - chatMessageView(onCtaButtonTap:)

    func test_chatMessageView_threadsOnCtaButtonTapThrough() {
        var capturedLabel: String?
        var capturedUrl: String?
        let message = Message(template: .divider)

        let view = message.chatMessageView(onCtaButtonTap: { label, url in
            capturedLabel = label
            capturedUrl = url
        })
        view.onCtaButtonTap?("Buy now", "https://example.com/buy")

        XCTAssertEqual(capturedLabel, "Buy now")
        XCTAssertEqual(capturedUrl, "https://example.com/buy")
    }

    func test_chatMessageView_defaultsOnCtaButtonTapToNil() {
        let message = Message(template: .divider)

        let view = message.chatMessageView()

        XCTAssertNil(view.onCtaButtonTap)
    }

    // MARK: - BasicMessageView.markdownBlockSpacing

    func test_markdownBlockSpacing_defaultLineHeight_usesFontLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        let spacing = BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 1.0)

        XCTAssertEqual(spacing, font.lineHeight, accuracy: 0.001)
    }

    func test_markdownBlockSpacing_themedLineHeight_usesThemedLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        let spacing = BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 1.75)

        XCTAssertEqual(spacing, 28, accuracy: 0.001)
    }

    func test_markdownBlockSpacing_invalidMultiplier_fallsBackToFontLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        XCTAssertEqual(BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 0), font.lineHeight, accuracy: 0.001)
        XCTAssertEqual(BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: .nan), font.lineHeight, accuracy: 0.001)
    }
}
