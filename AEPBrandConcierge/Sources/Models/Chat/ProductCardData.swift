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

/// Unified data model for product card display across both card styles.
public struct ProductCardData {
    public let imageSource: ImageSource
    public let title: String
    public let subtitle: String?
    public let price: String?
    public let wasPrice: String?
    public let badge: String?
    public let destinationURL: URL?
    public let primaryButton: ActionButton?
    public let secondaryButton: ActionButton?
    public let imageWidth: CGFloat?
    public let imageHeight: CGFloat?

    /// Constructs product card data from API response types.
    public init(entityInfo: EntityInfo, element: MultimodalElement) {
        let imageUrl = entityInfo.productImageURL.flatMap { URL(string: $0) }
        let pageUrl = entityInfo.productPageURL.flatMap { URL(string: $0) }

        self.imageSource = .remote(imageUrl)
        self.title = entityInfo.productName ?? "No title"
        self.subtitle = entityInfo.productDescription
        self.price = entityInfo.productPrice
        self.wasPrice = entityInfo.productWasPrice
        self.badge = entityInfo.productBadge
        self.destinationURL = pageUrl
        self.primaryButton = entityInfo.primary
        self.secondaryButton = entityInfo.secondary
        self.imageWidth = element.thumbnailWidth.map { CGFloat($0) }
        self.imageHeight = element.thumbnailHeight.map { CGFloat($0) }
    }

    public init(
        imageSource: ImageSource,
        title: String,
        subtitle: String?,
        price: String?,
        wasPrice: String? = nil,
        badge: String?,
        destinationURL: URL?,
        primaryButton: ActionButton?,
        secondaryButton: ActionButton?,
        imageWidth: CGFloat?,
        imageHeight: CGFloat?
    ) {
        self.imageSource = imageSource
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.wasPrice = wasPrice
        self.badge = badge
        self.destinationURL = destinationURL
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

// Call to action (CTA) resolution

/// Drives a CTA's visual style. Add a case (and update `ProductCardData.ctas`) to support more actions.
public enum ProductCardCTARole: Hashable {
    case primary
    case secondary
}

/// A validated, display-ready product card CTA (see `ProductCardData.makeCTA(from:role:)`).
public struct ProductCardCTA: Identifiable {
    /// Role as identity: one CTA per role, so it's a stable `ForEach` id across renders.
    public var id: ProductCardCTARole { role }
    public let text: String
    public let url: String
    public let role: ProductCardCTARole

    public init(text: String, url: String, role: ProductCardCTARole) {
        self.text = text
        self.url = url
        self.role = role
    }
}

public extension ProductCardData {
    /// Ordered, validated CTAs (primary then secondary) — the single source of truth for CTA visibility.
    var ctas: [ProductCardCTA] {
        [(primaryButton, ProductCardCTARole.primary), (secondaryButton, ProductCardCTARole.secondary)]
            .compactMap { action, role in ProductCardData.makeCTA(from: action, role: role) }
    }

    /// Returns a CTA only when both text and url are non-blank; stores trimmed values so a padded
    /// url can't render a button that then fails `URL(string:)` on tap.
    static func makeCTA(from action: ActionButton?, role: ProductCardCTARole) -> ProductCardCTA? {
        guard let action, let url = action.url else { return nil }
        let trimmedText = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !trimmedURL.isEmpty else { return nil }
        return ProductCardCTA(text: trimmedText, url: trimmedURL, role: role)
    }
}
