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

import SwiftUI

/// Fixed layout for product-detail cards (padding, corner radius, line heights, letter spacing, badge insets are encoded here).
private enum ProductDetailCardDimensions {
    static let contentPadding: CGFloat = 16
    static let titleLineHeight: CGFloat = 17
    static let subtitleLineHeight: CGFloat = 14
    static let priceLineHeight: CGFloat = 17
    static let wasPriceLineHeight: CGFloat = 14
    static let subtitleLetterSpacing: CGFloat = -0.5
    static let priceLetterSpacing: CGFloat = -0.5
    static let badgeHorizontalPadding: CGFloat = 12
    static let badgeVerticalPadding: CGFloat = 4
}

/// Product card with image, badge, title, subtitle, and price.
///
/// The image is always rendered at a fixed `productImageWidth` x `productImageHeight` (width clamped
/// to the inner content width); a missing or failed image shows a grey placeholder. Every other
/// element renders only when present. The card height grows with its content, clamped between
/// `productCardMinHeight` and `productCardMaxHeight`; content taller than the available height scrolls
/// internally.
///
/// In a carousel, the parent supplies `carouselEqualizedHeight` (the tallest card's clamped height)
/// via the environment so all cards share one height. Each card reports its own clamped natural
/// height back up through `CardHeightKey`. Card shadow uses `multimodalCardBoxShadow`.
struct ProductDetailCardView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.conciergeWebViewPresenter) private var webViewPresenter
    @Environment(\.conciergeLinkInterceptor) private var linkInterceptor
    @Environment(\.conciergeCardTapHandler) private var cardTapHandler
    @Environment(\.carouselEqualizedHeight) private var carouselEqualizedHeight

    let data: ProductCardData
    let cardWidth: CGFloat

    /// This card's own clamped natural height, measured from its content. Used to self-size when
    /// the card is not part of a carousel (no equalized height supplied).
    @State private var selfMeasuredHeight: CGFloat = 0

    /// This card's raw (unclamped) natural content height. Used to decide whether the content
    /// overflows the displayed height and therefore needs an internal scroll view.
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        Group {
            // Only wrap in a ScrollView when the content actually overflows the displayed height.
            // When it fits, render plain content so there is no bounce/scroll (matching Android).
            if needsScroll {
                ScrollView(.vertical, showsIndicators: false) { cardContent }
            } else {
                cardContent
            }
        }
        .frame(width: cardWidth, height: resolvedHeight, alignment: .top)
        .onPreferenceChange(CardHeightKey.self) { selfMeasuredHeight = $0 }
        .onPreferenceChange(CardNaturalHeightKey.self) { naturalHeight = $0 }
        .background(
            theme.colors.productCard.backgroundColor?.color
                ?? theme.colors.primary.container?.color
                ?? Color.white
        )
        .cornerRadius(theme.layout.borderRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: theme.layout.borderRadiusCard)
                .stroke(theme.colors.productCard.outlineColor.color, lineWidth: 1)
        )
        .shadow(
            color: multimodalCardShadowColor,
            radius: theme.layout.multimodalCardBoxShadow.blurRadius,
            x: theme.layout.multimodalCardBoxShadow.offsetX,
            y: theme.layout.multimodalCardBoxShadow.offsetY
        )
        .contentShape(Rectangle())
        .onTapGesture { handleCardTap() }
    }

    /// The card's content. Publishes both its clamped height (for carousel equalization) and its
    /// raw natural height (for the overflow/scroll decision).
    private var cardContent: some View {
        VStack(alignment: .center, spacing: 0) {
            imageSection
            textSection
        }
        .padding(ProductDetailCardDimensions.contentPadding)
        .frame(width: cardWidth)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CardHeightKey.self, value: clampedHeight(proxy.size.height))
                    .preference(key: CardNaturalHeightKey.self, value: proxy.size.height)
            }
        )
    }

    /// The height to display the card at: the carousel's equalized (tallest) height when in a
    /// carousel, otherwise this card's own clamped natural height. Content taller than this scrolls.
    private var resolvedHeight: CGFloat {
        if let equalized = carouselEqualizedHeight {
            return equalized
        }
        return selfMeasuredHeight > 0 ? selfMeasuredHeight : theme.layout.productCardMinHeight
    }

    /// True when the natural content is taller than the height the card is displayed at, so the
    /// content must scroll. A small tolerance avoids spurious scrolling from sub-pixel rounding.
    private var needsScroll: Bool {
        naturalHeight > resolvedHeight + 0.5
    }

    /// Clamps a natural content height into the configured per-card bounds.
    private func clampedHeight(_ natural: CGFloat) -> CGFloat {
        min(max(natural, theme.layout.productCardMinHeight), theme.layout.productCardMaxHeight)
    }
}

// MARK: - Subviews

private extension ProductDetailCardView {
    var imageSection: some View {
        let slotSize = imageSlotSize
        let contentMode = theme.layout.productImageScale.contentMode

        return ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    switch data.imageSource {
                    case .local(let image):
                        image
                            .productCardImageFill(width: slotSize.width, height: slotSize.height, contentMode: contentMode)
                            .overlay(debugImageBorder)
                    case .remote(let url):
                        if let url = url {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(width: slotSize.width, height: slotSize.height)
                                case .success(let loaded):
                                    loaded
                                        .productCardImageFill(width: slotSize.width, height: slotSize.height, contentMode: contentMode)
                                        .overlay(debugImageBorder)
                                case .failure:
                                    imagePlaceholder(slotSize)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            imagePlaceholder(slotSize)
                        }
                    }
                }
                .frame(width: slotSize.width, height: slotSize.height)
                .clipped()
                Spacer(minLength: 0)
            }
            .frame(width: innerContentWidth)

            if let badge = data.badge, !badge.isEmpty {
                badgeView(text: badge)
                    .frame(maxWidth: innerContentWidth, alignment: .leading)
                    // Flush to the card’s left edge (ignore content padding); sits slightly below the image.
                    .offset(
                        x: -ProductDetailCardDimensions.contentPadding,
                        y: 5
                    )
            }
        }
    }

    /// Grey placeholder shown when the product image is missing or fails to load.
    func imagePlaceholder(_ size: CGSize) -> some View {
        Rectangle()
            .fill(Color(white: 0.9))
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    var productCardTitleSubtitleBlock: some View {
        VStack(alignment: .leading, spacing: theme.layout.productCardTitleSubtitleSpacing ?? theme.layout.productCardTextSpacing) {
            Text(data.title)
                .font(.system(size: theme.layout.productCardTitleFontSize))
                .fontWeight(theme.layout.productCardTitleFontWeight.toSwiftUIFontWeight())
                .foregroundColor(theme.colors.productCard.titleColor.color)
                .lineSpacing(productCardExtraLineSpacing(
                    fontSize: theme.layout.productCardTitleFontSize,
                    lineHeight: ProductDetailCardDimensions.titleLineHeight
                ))
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = data.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: theme.layout.productCardSubtitleFontSize))
                    .fontWeight(theme.layout.productCardSubtitleFontWeight.toSwiftUIFontWeight())
                    .foregroundColor(theme.colors.productCard.subtitleColor.color)
                    .kerning(ProductDetailCardDimensions.subtitleLetterSpacing)
                    .lineSpacing(productCardExtraLineSpacing(
                        fontSize: theme.layout.productCardSubtitleFontSize,
                        lineHeight: ProductDetailCardDimensions.subtitleLineHeight
                    ))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    var productCardPriceBlock: some View {
        if let price = data.price, !price.isEmpty {
            VStack(alignment: .leading, spacing: theme.layout.productCardPriceSpacing ?? theme.layout.productCardTextSpacing) {
                Text(price)
                    .font(.system(size: theme.layout.productCardPriceFontSize))
                    .fontWeight(theme.layout.productCardPriceFontWeight.toSwiftUIFontWeight())
                    .foregroundColor(theme.colors.productCard.priceColor.color)
                    .kerning(ProductDetailCardDimensions.priceLetterSpacing)
                    .lineSpacing(productCardExtraLineSpacing(
                        fontSize: theme.layout.productCardPriceFontSize,
                        lineHeight: ProductDetailCardDimensions.priceLineHeight
                    ))

                if let wasPrice = data.wasPrice, !wasPrice.isEmpty {
                    Text("\(theme.layout.productCardWasPriceTextPrefix)\(wasPrice)")
                        .font(.system(size: theme.layout.productCardWasPriceFontSize))
                        .fontWeight(theme.layout.productCardWasPriceFontWeight.toSwiftUIFontWeight())
                        .foregroundColor(theme.colors.productCard.wasPriceColor.color)
                        .kerning(ProductDetailCardDimensions.priceLetterSpacing)
                        .lineSpacing(productCardExtraLineSpacing(
                            fontSize: theme.layout.productCardWasPriceFontSize,
                            lineHeight: ProductDetailCardDimensions.wasPriceLineHeight
                        ))
                }
            }
        }
    }

    var textSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.productCardSectionSpacing ?? theme.layout.productCardTextSpacing) {
            productCardTitleSubtitleBlock
            productCardPriceBlock
        }
        .padding(.top, theme.layout.productCardTextTopPadding)
        .padding(.horizontal, theme.layout.productCardTextHorizontalPadding)
        .padding(.bottom, theme.layout.productCardTextBottomPadding)
        .frame(width: innerContentWidth, alignment: .topLeading)
    }

    func badgeView(text: String) -> some View {
        Text(text)
            .font(.system(size: theme.layout.productCardBadgeFontSize))
            .fontWeight(theme.layout.productCardBadgeFontWeight.toSwiftUIFontWeight())
            .foregroundColor(theme.colors.productCard.badgeTextColor.color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, ProductDetailCardDimensions.badgeHorizontalPadding)
            .padding(.vertical, ProductDetailCardDimensions.badgeVerticalPadding)
            .background(theme.colors.productCard.badgeBackgroundColor.color)
    }
}

// MARK: - Helpers

private extension ProductDetailCardView {
    var innerContentWidth: CGFloat {
        cardWidth - 2 * ProductDetailCardDimensions.contentPadding
    }

    /// Fixed image slot size from the theme (`productImageWidth` x `productImageHeight`), with the
    /// width clamped to the inner content width. The image is never scaled to API dimensions.
    var imageSlotSize: CGSize {
        let width = min(theme.layout.productImageWidth, innerContentWidth)
        return CGSize(width: width, height: theme.layout.productImageHeight)
    }

    func productCardExtraLineSpacing(fontSize: CGFloat, lineHeight: CGFloat) -> CGFloat {
        max(0, lineHeight - fontSize)
    }

    @ViewBuilder
    var debugImageBorder: some View {
        #if DEBUG
        if ProductDetailCardView.showDebugOverlay {
            Rectangle()
                .stroke(Color.red.opacity(0.6), lineWidth: 1)
        }
        #endif
    }

    var multimodalCardShadowColor: Color {
        theme.layout.multimodalCardBoxShadow.isEnabled
            ? theme.layout.multimodalCardBoxShadow.color.color
            : .clear
    }

    func handleCardTap() {
        cardTapHandler.cardTapped(data)
        guard let destination = data.destinationURL else { return }
        if linkInterceptor.handleLink(destination) { return }
        ConciergeLinkHandler.handleURL(
            destination,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
    }
}

private extension Image {
    /// Renders the image in the fixed slot (width x height) using the given content mode:
    /// `.fill` scales to fill and crops overflow; `.fit` fits the whole image inside the slot.
    func productCardImageFill(width: CGFloat, height: CGFloat, contentMode: ContentMode) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: width, height: height)
            .clipped()
    }
}

#if DEBUG

extension ProductDetailCardView {
    /// When `true`, draws a red border around the product image and shows a
    /// width×height label in the top left corner of each card.
    static var showDebugOverlay = false
}

private struct MeasuredCardView: View {
    let data: ProductCardData
    let cardWidth: CGFloat

    var body: some View {
        ProductDetailCardView(
            data: data,
            cardWidth: cardWidth
        )
            .overlay(alignment: .topTrailing) {
                if ProductDetailCardView.showDebugOverlay {
                    GeometryReader { geometry in
                        Text("\(Int(geometry.size.width))×\(Int(geometry.size.height))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }
    }
}

// MARK: - Preview

private enum PreviewData {
    // swiftlint:disable line_length
    private static let templatesImageURL = URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_142fd6e4e46332d8f41f5aef982448361c0c8c65e.png")
    private static let photosImageURL = URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_1e188097a1bc580b26c8be07d894205c5c6ca5560.png")
    private static let pdfImageURL = URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_1f6fed23045bbbd57fc17dadc3aa06bcc362f84cb.png")
    private static let videoImageURL = URL(string: "https://main--milo--adobecom.aem.page/drafts/methomas/assets/media_16c2ca834ea8f2977296082ae6f55f305a96674ac.png")
    // swiftlint:enable line_length

    static let allFields = ProductCardData(
        imageSource: .remote(templatesImageURL),
        title: "The North Face Men's Evolution Short-Sleeve Tee",
        subtitle: "Lightweight everyday tee with UPF 30 sun protection",
        price: "$18.97–$35.00",
        wasPrice: "$45.00",
        badge: "New Color",
        destinationURL: URL(string: "https://example.com/all-fields"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let exploreTemplates = ProductCardData(
        imageSource: .remote(templatesImageURL),
        title: "Explore Templates",
        subtitle: "Browse hundreds of professionally designed templates to jumpstart your next creative project",
        price: "$9.99/mo",
        badge: "Popular",
        destinationURL: URL(string: "https://example.com/templates"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let photoEnhancement = ProductCardData(
        imageSource: .remote(photosImageURL),
        title: "Photo Enhancement Suite",
        subtitle: "Professional retouching tools",
        price: "$14.99",
        badge: "New",
        destinationURL: URL(string: "https://example.com/photo-enhancement"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let pdfEditor = ProductCardData(
        imageSource: .remote(pdfImageURL),
        title: "Interactive PDF Editor with Form Builder and Digital Signature Support for Teams",
        subtitle: nil,
        price: "$19.99/mo",
        badge: nil,
        destinationURL: URL(string: "https://example.com/pdf-editor"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let videoProduction = ProductCardData(
        imageSource: .remote(videoImageURL),
        title: "Video Production Toolkit",
        subtitle: nil,
        price: "$24.99-$49.99",
        badge: "Best Value",
        destinationURL: URL(string: "https://example.com/video-production"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let templateStarter = ProductCardData(
        imageSource: .remote(templatesImageURL),
        title: "Template Starter Pack",
        subtitle: "Get started with curated templates for social media, presentations, and print design",
        price: "Free",
        badge: "Featured",
        destinationURL: URL(string: "https://example.com/starter-pack"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let photoRetouching = ProductCardData(
        imageSource: .remote(photosImageURL),
        title: "AI Photo Retouching",
        subtitle: "One-click enhancements",
        price: "See Plan Options",
        badge: "Limited Offer",
        destinationURL: URL(string: "https://example.com/photo-retouching"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let pdfConverter = ProductCardData(
        imageSource: .remote(pdfImageURL),
        title: "PDF Converter Pro with Batch Processing, OCR Text Recognition, and Cloud Storage Integration",
        subtitle: "Convert, merge, and compress PDF files with advanced formatting preservation across platforms",
        price: "$12.99-$29.99",
        badge: "Top Rated",
        destinationURL: URL(string: "https://example.com/pdf-converter"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    static let videoClipper = ProductCardData(
        imageSource: .remote(videoImageURL),
        title: "Quick Video Clipper",
        subtitle: nil,
        price: "$7.99",
        badge: nil,
        destinationURL: URL(string: "https://example.com/video-clipper"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    /// Title only — no subtitle, price, was-price, or badge. The shortest card.
    static let titleOnly = ProductCardData(
        imageSource: .remote(photosImageURL),
        title: "Minimal Card",
        subtitle: nil,
        price: nil,
        wasPrice: nil,
        badge: nil,
        destinationURL: URL(string: "https://example.com/minimal"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    /// Missing image (nil URL) — exercises the grey placeholder. Has title + price.
    static let missingImage = ProductCardData(
        imageSource: .remote(nil),
        title: "Image Failed To Load",
        subtitle: "Shows the grey placeholder in the fixed image slot",
        price: "$5.00",
        wasPrice: nil,
        badge: "Sale",
        destinationURL: URL(string: "https://example.com/missing-image"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    /// Every field populated with long text — the tallest card, used to drive equalization and,
    /// under a constrained max height, the internal scroll behaviour.
    static let richTallest = ProductCardData(
        imageSource: .remote(pdfImageURL),
        title: "Premium All-In-One Creative Suite With Advanced Editing Tools",
        subtitle: "Includes photo, video, vector, and PDF tools with cloud sync and team collaboration",
        price: "$29.99–$59.99 / month",
        wasPrice: "$79.99",
        badge: "Best Value",
        destinationURL: URL(string: "https://example.com/premium-suite"),
        primaryButton: nil,
        secondaryButton: nil,
        imageWidth: 150,
        imageHeight: 150
    )

    /// A representative mix of card shapes for carousel previews: full, title-only, no-subtitle,
    /// minimal, missing-image, and the tall rich card.
    static let mixed: [ProductCardData] = [
        richTallest,
        titleOnly,
        pdfEditor,
        videoClipper,
        missingImage,
        allFields
    ]
}

#Preview("Carousel") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 12) {
            MeasuredCardView(data: PreviewData.exploreTemplates, cardWidth: 222)
            MeasuredCardView(data: PreviewData.photoEnhancement, cardWidth: 222)
            MeasuredCardView(data: PreviewData.pdfEditor, cardWidth: 222)
            MeasuredCardView(data: PreviewData.videoProduction, cardWidth: 222)
            MeasuredCardView(data: PreviewData.templateStarter, cardWidth: 222)
            MeasuredCardView(data: PreviewData.photoRetouching, cardWidth: 222)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding()
    }
    .conciergeTheme(ConciergeTheme())
}

#Preview("Carousel - Badge Variations") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 12) {
            MeasuredCardView(data: PreviewData.pdfConverter, cardWidth: 222)
            MeasuredCardView(data: PreviewData.videoClipper, cardWidth: 222)
            MeasuredCardView(data: PreviewData.templateStarter, cardWidth: 222)
            MeasuredCardView(data: PreviewData.photoRetouching, cardWidth: 222)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding()
    }
    .conciergeTheme(ConciergeTheme())
}

#Preview("Single Card") {
    ScrollView {
        VStack(spacing: 16) {
            MeasuredCardView(data: PreviewData.exploreTemplates, cardWidth: 222)
            MeasuredCardView(data: PreviewData.photoEnhancement, cardWidth: 222)
            MeasuredCardView(data: PreviewData.pdfEditor, cardWidth: 222)
            MeasuredCardView(data: PreviewData.videoClipper, cardWidth: 222)
        }
        .padding()
    }
    .conciergeTheme(ConciergeTheme())
}

#Preview("All Fields") {
    ScrollView {
        VStack(spacing: 16) {
            ProductDetailCardView(data: PreviewData.allFields, cardWidth: 222)
        }
        .padding()
    }
    .conciergeTheme(ConciergeTheme())
}

private extension PreviewData {
    /// The mixed cards wrapped as carousel-card messages for `CarouselGroupView`.
    static var mixedMessages: [Message] {
        mixed.map { Message(template: .productCarouselCard($0)) }
    }
}

/// Builds a theme that renders product-detail cards in a carousel of the given style. Pass
/// `maxHeight` to constrain the card max height (to demonstrate internal scroll on overflow).
private func productDetailCarouselTheme(carouselStyle: CarouselStyle, maxHeight: CGFloat? = nil) -> ConciergeTheme {
    var theme = ConciergeTheme(
        behavior: ConciergeBehaviorConfig(
            multimodalCarousel: ConciergeMultimodalCarouselBehavior(carouselStyle: carouselStyle),
            productCard: ConciergeProductCardBehavior(cardStyle: .productDetail)
        )
    )
    if let maxHeight = maxHeight {
        theme.layout.productCardMaxHeight = maxHeight
    }
    return theme
}

#Preview("CarouselGroupView - Scroll (mixed cards)") {
    CarouselGroupView(items: PreviewData.mixedMessages)
        .conciergeTheme(productDetailCarouselTheme(carouselStyle: .scroll))
}

#Preview("CarouselGroupView - Paged (mixed cards)") {
    CarouselGroupView(items: PreviewData.mixedMessages)
        .conciergeTheme(productDetailCarouselTheme(carouselStyle: .paged))
}

#Preview("CarouselGroupView - Constrained (internal scroll)") {
    // Tall card exceeds the 260pt max, so every card equalizes to 260 and the tall one scrolls.
    CarouselGroupView(items: PreviewData.mixedMessages)
        .conciergeTheme(productDetailCarouselTheme(carouselStyle: .scroll, maxHeight: 260))
}

#endif
