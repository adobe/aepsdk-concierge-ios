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

final class ProductDetailCardViewTests: XCTestCase {

    // MARK: - shouldShowProductCardCtaButton

    func test_shouldShowProductCardCtaButton_falseWhenPrimaryButtonNil() {
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: nil), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_falseWhenPrimaryButtonTextEmpty() {
        let action = ActionButton(text: "", url: "https://example.com/buy")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_trueWhenPrimaryButtonPresent_andNoSubtitle() {
        let action = ActionButton(text: "Buy now", url: "https://example.com/buy")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertTrue(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_trueWhenPrimaryButtonPresent_andSubtitlePresent() {
        // Visibility is driven entirely by payload presence, not subtitle absence.
        let action = ActionButton(text: "Buy now", url: "https://example.com/buy")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: "Subtitle text", primaryButton: action), cardWidth: 222)

        XCTAssertTrue(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_falseWhenUrlEmpty() {
        // A blank url would pass text validation but fail handleProductCardCtaButtonTap's URL(string:) guard,
        // leaving a dead button that does nothing on tap (no tracking either, since that guard
        // runs before onTap is invoked).
        let action = ActionButton(text: "Buy now", url: "")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_falseWhenTextIsWhitespaceOnly() {
        let action = ActionButton(text: "   ", url: "https://example.com/buy")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_falseWhenUrlIsWhitespaceOnly() {
        let action = ActionButton(text: "Buy now", url: "   ")
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    func test_shouldShowProductCardCtaButton_falseWhenUrlNil() {
        // A text-only action (no destination at all) is a valid payload shape, but the CTA
        // button specifically requires a destination to be worth showing.
        let action = ActionButton(text: "Buy now", url: nil)
        let card = ProductDetailCardView(data: makeProductCardData(subtitle: nil, primaryButton: action), cardWidth: 222)

        XCTAssertFalse(card.shouldShowProductCardCtaButton)
    }

    // MARK: - handleProductCardCtaButtonTap

    func test_handleProductCardCtaButtonTap_invokesOnTap_withActionLabelAndUrl() {
        var capturedLabel: String?
        var capturedUrl: String?
        let action = ActionButton(text: "Buy now", url: "https://example.com/buy")
        let card = ProductDetailCardView(
            data: makeProductCardData(subtitle: nil, primaryButton: action),
            cardWidth: 222,
            onTap: { label, url in
                capturedLabel = label
                capturedUrl = url
            }
        )

        card.handleProductCardCtaButtonTap(action)

        XCTAssertEqual(capturedLabel, "Buy now")
        XCTAssertEqual(capturedUrl, "https://example.com/buy")
    }

    func test_handleProductCardCtaButtonTap_doesNotInvokeOnTap_whenUrlNil() {
        var onTapCallCount = 0
        let action = ActionButton(text: "Buy now", url: nil)
        let card = ProductDetailCardView(
            data: makeProductCardData(subtitle: nil, primaryButton: action),
            cardWidth: 222,
            onTap: { _, _ in onTapCallCount += 1 }
        )

        card.handleProductCardCtaButtonTap(action)

        XCTAssertEqual(onTapCallCount, 0)
    }

    // MARK: - Helpers

    private func makeProductCardData(subtitle: String?, primaryButton: ActionButton?) -> ProductCardData {
        ProductCardData(
            imageSource: .remote(nil),
            title: "Product Name",
            subtitle: subtitle,
            price: "$63.97",
            badge: nil,
            destinationURL: nil,
            primaryButton: primaryButton,
            secondaryButton: nil,
            imageWidth: 150,
            imageHeight: 150
        )
    }
}
