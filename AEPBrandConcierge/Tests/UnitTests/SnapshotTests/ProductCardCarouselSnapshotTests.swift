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

import SnapshotTesting
import SwiftUI
import XCTest

@testable import AEPBrandConcierge

/// Layout coverage for a product-card carousel whose cards carry different amounts of content.
///
/// These live as snapshots rather than unit tests because everything they assert — where the
/// pricing block lands, whether a card reserves the CTA slot, how tall the cards end up — is
/// decided inside `ProductDetailCardView`'s `private extension`, which is unreachable from a test
/// without loosening access purely for testing.
final class ProductCardCarouselSnapshotTests: XCTestCase {
    /// Descriptions sized to wrap to roughly six, three and two lines at the card width below, so
    /// the cards have genuinely different natural heights.
    private enum Description {
        static let long = "Experience unparalleled comfort and support with the Trailwind 9 running shoe. Designed with an engineered mesh upper made from 55% recycled polyester and a rearfoot-focused cushioning system built for long training runs."
        static let medium = "Experience unparalleled comfort and support with the Trailwind 9 running shoe. Designed with engineered mesh."
        static let short = "Experience unparalleled comfort and support with the Trailwind 9 shoe."
    }

    /// `.remote(nil)` renders the grey placeholder, keeping the snapshot free of any network load.
    private func card(title: String, description: String, withCta: Bool) -> ProductCardData {
        ProductCardData(
            imageSource: .remote(nil),
            title: title,
            subtitle: description,
            price: "$99.99",
            wasPrice: "$149.99",
            badge: "Badge Text",
            destinationURL: nil,
            primaryButton: withCta ? ActionButton(text: "Buy now", url: "https://example.com/buy") : nil,
            secondaryButton: nil,
            imageWidth: nil,
            imageHeight: nil
        )
    }

    private func carousel(_ cards: [ProductCardData]) -> Message {
        Message(template: .carouselGroup(cards.map { Message(template: .productCarouselCard($0)) }))
    }

    /// Six-line descriptions and a 463pt cap, matching the layout these tests are about.
    private func theme() -> ConciergeTheme {
        var theme = ConciergeThemeLoader.default()
        theme.behavior.multimodalCarousel.carouselStyle = .scroll
        theme.behavior.productCard = ConciergeProductCardBehavior(cardStyle: .productDetail)
        theme.layout.productCardDescriptionMaxLines = 6
        theme.layout.productCardMaxHeight = 463
        theme.layout.productCardWidth = 224
        return theme
    }

    private func assertCarousel(_ cards: [ProductCardData],
                                file: StaticString = #file,
                                testName: String = #function,
                                line: UInt = #line) {
        let view = ChatView(messages: [carousel(cards)])
            .frame(width: 390, height: 844)
            .conciergeTheme(theme())

        assertSnapshot(of: view,
                       as: .image(layout: .fixed(width: 390, height: 844)),
                       file: file,
                       testName: testName,
                       line: line)
    }

    /// Every card has a CTA. The shorter cards stretch to the tallest card's height and their
    /// pricing blocks sit on a common baseline just above the button.
    @MainActor
    func test_allCardsWithCta_shareHeightAndBaseline() {
        assertCarousel([
            card(title: "Trailwind 10 Running Shoes", description: Description.long, withCta: true),
            card(title: "Trailwind Versa 10 Running Shoes", description: Description.medium, withCta: true),
            card(title: "Trailwind Lite 10 Running Shoes", description: Description.short, withCta: true)
        ])
    }

    /// The first card has no CTA while its siblings do. It must still reserve the button's slot so
    /// its price row stays level with theirs and the blank space falls at the bottom of the card —
    /// without the reservation the bottom-anchoring spacer drops its pricing block to the card's
    /// bottom edge, leaving the gap between the description and the price instead.
    @MainActor
    func test_mixedCta_cardWithoutCtaKeepsPriceBaselineAndTrailsBlankSpace() {
        assertCarousel([
            card(title: "Trailwind 10 Running Shoes", description: Description.long, withCta: false),
            card(title: "Trailwind Versa 10 Running Shoes", description: Description.medium, withCta: true),
            card(title: "Trailwind Lite 10 Running Shoes", description: Description.short, withCta: true)
        ])
    }

    /// No card has a CTA, so nothing reserves a slot: the pricing blocks stay hard against the
    /// bottom inset. Guards the reservation from leaking into carousels that never show a button.
    @MainActor
    func test_noCardHasCta_reservesNoButtonSlot() {
        assertCarousel([
            card(title: "Trailwind 10 Running Shoes", description: Description.long, withCta: false),
            card(title: "Trailwind Versa 10 Running Shoes", description: Description.medium, withCta: false),
            card(title: "Trailwind Lite 10 Running Shoes", description: Description.short, withCta: false)
        ])
    }
}
