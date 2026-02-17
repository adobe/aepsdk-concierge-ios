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

import UIKit

/// Utility responsible for replacing inline citation tokens with tappable badge attachments.
enum CitationAttachmentBuilder {
    /// Replaces citation placeholder tokens with inline badge attachments.
    ///
    /// - Parameters:
    ///   - attributed: The attributed string produced by the markdown renderer.
    ///   - markers: Metadata describing each token that should be replaced.
    ///   - baseFont: The surrounding font, used to align the badge vertically.
    ///   - style: Colors describing how the badge should be rendered.
    /// - Returns: An attributed string where every token has been swapped for a badge attachment.
    static func replaceTokens(
        in attributed: NSAttributedString,
        markers: [CitationMarker],
        baseFont: UIFont,
        style: CitationStyle
    ) -> NSAttributedString {
        guard !markers.isEmpty else { return attributed }

        let mutable = NSMutableAttributedString(attributedString: attributed)
        let mutableString = mutable.mutableString

        for marker in markers {
            var searchRange = NSRange(location: 0, length: mutableString.length)
            while true {
                let range = mutableString.range(of: marker.token, options: [], range: searchRange)
                if range.location == NSNotFound { break }

                let attachment = makeAttachment(
                    for: marker,
                    baseFont: baseFont,
                    style: style
                )
                mutable.replaceCharacters(in: range, with: attachment)

                let nextLocation = range.location + attachment.length
                let remainingLength = mutable.length - nextLocation
                if remainingLength <= 0 { break }
                searchRange = NSRange(location: nextLocation, length: remainingLength)
            }
        }

        return mutable
    }

    /// Produces a single badge attachment for the given citation marker.
    ///
    /// - Parameters:
    ///   - marker: The marker describing citation number and link target.
    ///   - baseFont: Font used to align the badge with surrounding text.
    ///   - style: Colors describing badge appearance.
    /// - Returns: An attributed string containing the attachment and trailing spacing.
    private static func makeAttachment(
        for marker: CitationMarker,
        baseFont: UIFont,
        style: CitationStyle
    ) -> NSAttributedString {
        let font = style.font
        // Keep a minimum badge height for tap target and consistent layout.
        let baseHeight: CGFloat = max(16, ceil(font.lineHeight + 4))
        let text = "\(marker.citationNumber)"
        let textSize = text.size(withAttributes: [.font: font])
        let horizontalPadding: CGFloat = 8
        let badgeWidth = max(baseHeight, textSize.width + horizontalPadding)
        let badgeSize = CGSize(width: ceil(badgeWidth), height: baseHeight)
        let attachment = NSTextAttachment()
        attachment.image = drawBadgeImage(
            text: text,
            font: font,
            size: badgeSize,
            style: style
        )

        let baselineOffset = (baseFont.capHeight - badgeSize.height) / 2
        attachment.bounds = CGRect(x: 0, y: baselineOffset, width: badgeSize.width, height: badgeSize.height)

        let result = NSMutableAttributedString(attachment: attachment)
        if let url = URL(string: marker.source.url) {
            result.addAttribute(.link, value: url, range: NSRange(location: 0, length: result.length))
        }

        // Add a space after the badge to separate it from the next character.
        result.append(NSAttributedString(string: " "))
        return result
    }

    /// Draws a pill shaped badge containing the provided text.
    ///
    /// - Parameters:
    ///   - text: The citation number to show inside the badge.
    ///   - font: Font used to measure and draw the text.
    ///   - size: Final size of the badge.
    ///   - style: Colors describing badge appearance.
    /// - Returns: A rendered `UIImage` representing the badge.
    private static func drawBadgeImage(
        text: String,
        font: UIFont,
        size: CGSize,
        style: CitationStyle
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let cornerRadius = min(rect.height / 2, 5)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.cgContext.setFillColor(style.backgroundColor.cgColor)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.textColor
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
