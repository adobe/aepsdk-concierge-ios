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

    // MARK: - CTA resolution (primary + secondary)

    func test_ctas_primaryOnly_whenNoSecondary() {
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy")
        )

        XCTAssertEqual(data.ctas.map { $0.role }, [.primary])
        XCTAssertEqual(data.ctas.map { $0.text }, ["Buy now"])
    }

    func test_ctas_bothRendered_primaryBeforeSecondary_whenBothValid() {
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "myapp://checkout?productId=prod-123"),
            secondaryButton: ActionButton(text: "Learn more", url: "https://shop.com/products/prod-123")
        )

        XCTAssertEqual(data.ctas.map { $0.role }, [.primary, .secondary])
        XCTAssertEqual(data.ctas.map { $0.text }, ["Buy now", "Learn more"])
        XCTAssertEqual(data.ctas.map { $0.url }, ["myapp://checkout?productId=prod-123", "https://shop.com/products/prod-123"])
    }

    func test_ctas_secondaryOnly_whenPrimaryInvalid() {
        // A valid secondary still renders even if the primary is missing/invalid.
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: nil,
            secondaryButton: ActionButton(text: "Learn more", url: "https://shop.com/learn")
        )

        XCTAssertEqual(data.ctas.map { $0.role }, [.secondary])
    }

    func test_ctas_dropsSecondary_whenUrlNil() {
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy"),
            secondaryButton: ActionButton(text: "Learn more", url: nil)
        )

        XCTAssertEqual(data.ctas.map { $0.role }, [.primary])
    }

    func test_ctas_dropsSecondary_whenTextOrUrlBlank() {
        let blankText = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy"),
            secondaryButton: ActionButton(text: "   ", url: "https://shop.com/learn")
        )
        XCTAssertEqual(blankText.ctas.map { $0.role }, [.primary])

        let blankUrl = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy"),
            secondaryButton: ActionButton(text: "Learn more", url: "   ")
        )
        XCTAssertEqual(blankUrl.ctas.map { $0.role }, [.primary])
    }

    func test_ctas_trimsWhitespaceFromTextAndUrl() {
        // Padded url must be stored trimmed so URL(string:) succeeds on tap.
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "  Buy now  ", url: "  https://example.com/buy  ")
        )

        XCTAssertEqual(data.ctas.first?.text, "Buy now")
        XCTAssertEqual(data.ctas.first?.url, "https://example.com/buy")
        XCTAssertNotNil(URL(string: data.ctas.first?.url ?? ""))
    }

    func test_ctas_idIsStableAcrossAccesses() {
        // ForEach identity must be stable across renders; id is derived from role, not a fresh UUID.
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy"),
            secondaryButton: ActionButton(text: "Learn more", url: "https://example.com/learn")
        )

        XCTAssertEqual(data.ctas.map { $0.id }, data.ctas.map { $0.id })
        XCTAssertEqual(data.ctas.map { $0.id }, [.primary, .secondary])
    }

    func test_ctas_empty_whenNeitherValid() {
        let data = makeProductCardData(
            subtitle: nil,
            primaryButton: ActionButton(text: "Buy now", url: nil),
            secondaryButton: ActionButton(text: "", url: "https://shop.com/learn")
        )

        XCTAssertTrue(data.ctas.isEmpty)
    }

    func test_handleProductCardCtaButtonTap_routesSecondaryAction() {
        var capturedLabel: String?
        var capturedUrl: String?
        let secondary = ActionButton(text: "Learn more", url: "https://shop.com/learn")
        let card = ProductDetailCardView(
            data: makeProductCardData(
                subtitle: nil,
                primaryButton: ActionButton(text: "Buy now", url: "https://example.com/buy"),
                secondaryButton: secondary
            ),
            cardWidth: 222,
            onTap: { label, url in
                capturedLabel = label
                capturedUrl = url
            }
        )

        card.handleProductCardCtaButtonTap(secondary)

        XCTAssertEqual(capturedLabel, "Learn more")
        XCTAssertEqual(capturedUrl, "https://shop.com/learn")
    }

    // MARK: - Helpers

    private func makeProductCardData(
        subtitle: String?,
        primaryButton: ActionButton?,
        secondaryButton: ActionButton? = nil
    ) -> ProductCardData {
        ProductCardData(
            imageSource: .remote(nil),
            title: "Product Name",
            subtitle: subtitle,
            price: "$63.97",
            badge: nil,
            destinationURL: nil,
            primaryButton: primaryButton,
            secondaryButton: secondaryButton,
            imageWidth: 150,
            imageHeight: 150
        )
    }
}
