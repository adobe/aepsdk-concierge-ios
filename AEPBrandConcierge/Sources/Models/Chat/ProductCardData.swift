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
        self.badge = badge
        self.destinationURL = destinationURL
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}
