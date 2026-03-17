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

/// Product card with image, badge, title, subtitle, and price.
///
/// Layout: product image at top (sized via thumbnail dimensions), optional badge
/// overlapping the bottom of the image, title, optional subtitle, and optional price.
/// The entire card is tappable, navigating to the product page URL.
struct ProductDetailCardView: View {
    @Environment(\.conciergeTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.conciergeWebViewPresenter) private var webViewPresenter
    @Environment(\.conciergeLinkInterceptor) private var linkInterceptor

    let data: ProductCardData
    let cardWidth: CGFloat
    var cardHeight: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageSection
            textSection
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
        .background(theme.colors.productCard.backgroundColor.color)
        .cornerRadius(theme.layout.borderRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: theme.layout.borderRadiusCard)
                .stroke(theme.colors.productCard.outlineColor.color, lineWidth: 1)
        )
        .shadow(
            color: shadowColor,
            radius: theme.layout.multimodalCardBoxShadow.blurRadius,
            x: theme.layout.multimodalCardBoxShadow.offsetX,
            y: theme.layout.multimodalCardBoxShadow.offsetY
        )
        .contentShape(Rectangle())
        .onTapGesture { handleCardTap() }
    }
}

// MARK: - Subviews

private extension ProductDetailCardView {
    var imageSection: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                switch data.imageSource {
                case .local(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: thumbnailDisplayWidth, height: thumbnailDisplayHeight)
                        .overlay(debugImageBorder)
                case .remote(let url):
                    if let url = url {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: thumbnailDisplayWidth, height: thumbnailDisplayHeight)
                            case .success(let loaded):
                                loaded
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: thumbnailDisplayWidth, height: thumbnailDisplayHeight)
                                    .overlay(debugImageBorder)
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: thumbnailDisplayWidth, height: thumbnailDisplayHeight)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .frame(width: thumbnailDisplayWidth, height: thumbnailDisplayHeight)
                    }
                }
            }
            .frame(width: cardWidth, height: imageContainerHeight, alignment: .top)

            if let badge = data.badge, !badge.isEmpty {
                badgeView(text: badge)
                    .frame(maxWidth: cardWidth, alignment: .leading)
                    .offset(y: 12)
            }
        }
    }

    var textSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.productCardTextSpacing) {
            Text(data.title)
                .font(.system(size: theme.layout.productCardTitleFontSize))
                .fontWeight(theme.layout.productCardTitleFontWeight.toSwiftUIFontWeight())
                .foregroundColor(theme.colors.productCard.titleColor.color)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = data.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: theme.layout.productCardSubtitleFontSize))
                    .fontWeight(theme.layout.productCardSubtitleFontWeight.toSwiftUIFontWeight())
                    .foregroundColor(theme.colors.productCard.subtitleColor.color)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let price = data.price, !price.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(price)
                        .font(.system(size: theme.layout.productCardPriceFontSize))
                        .fontWeight(theme.layout.productCardPriceFontWeight.toSwiftUIFontWeight())
                        .foregroundColor(theme.colors.productCard.priceColor.color)

                    Text("\(theme.layout.productCardWasPriceTextPrefix)\(data.wasPrice ?? "")")
                        .font(.system(size: theme.layout.productCardWasPriceFontSize))
                        .fontWeight(theme.layout.productCardWasPriceFontWeight.toSwiftUIFontWeight())
                        .foregroundColor(theme.colors.productCard.wasPriceColor.color)
                        .opacity(data.wasPrice.map { !$0.isEmpty } ?? false ? 1 : 0)
                }
            }
        }
        .padding(.top, theme.layout.productCardTextTopPadding)
        .padding(.horizontal, theme.layout.productCardTextHorizontalPadding)
        .padding(.bottom, theme.layout.productCardTextBottomPadding)
        .frame(width: cardWidth, height: textSectionHeight, alignment: .topLeading)
    }

    func badgeView(text: String) -> some View {
        Text(text)
            .font(.system(size: theme.layout.productCardBadgeFontSize))
            .fontWeight(theme.layout.productCardBadgeFontWeight.toSwiftUIFontWeight())
            .foregroundColor(theme.colors.productCard.badgeTextColor.color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.colors.productCard.badgeBackgroundColor.color)
    }
}

// MARK: - Helpers

private extension ProductDetailCardView {
    var thumbnailDisplayWidth: CGFloat {
        data.imageWidth ?? 150
    }

    var thumbnailDisplayHeight: CGFloat {
        data.imageHeight ?? 150
    }

    var imageContainerHeight: CGFloat {
        thumbnailDisplayHeight
    }

    var textSectionHeight: CGFloat? {
        guard let cardHeight = cardHeight else { return nil }
        return cardHeight - imageContainerHeight
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

    var shadowColor: Color {
        theme.layout.multimodalCardBoxShadow.isEnabled
            ? theme.layout.multimodalCardBoxShadow.color.color
            : .clear
    }

    func handleCardTap() {
        guard let destination = data.destinationURL else { return }
        if linkInterceptor.handleLink(destination) { return }
        ConciergeLinkHandler.handleURL(
            destination,
            openInWebView: { webViewPresenter.openURL($0) },
            openWithSystem: { openURL($0) }
        )
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

#endif
