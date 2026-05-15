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

        // Build the badge as its own attributed fragment
        let badge = NSMutableAttributedString(attachment: attachment)
        if let url = URL(string: marker.source.url) {
            badge.addAttribute(.link, value: url, range: NSRange(location: 0, length: badge.length))
        }

        // Prepend a space so the badge sits slightly away from the preceding word, while keeping 
        // it flush against any trailing punctuation like periods or commas. 
        // * ex: `swift.org [1].` rather than `swift.org[1].`
        // The space is injected here after the markdown parser has already finished 
        // so it doesn't affect paragraph/block detection.
        let result = NSMutableAttributedString(string: " ")
        result.append(badge)
        return result
    }

    /// Scans the attributed string for `.link` attribute ranges and appends a small icon attachment
    /// immediately after each one. The icon is selected per-link via `iconResolver`, which maps a
    /// URL to an asset name and SF Symbol fallback. Citation badge attachments (which also carry
    /// `.link`) are skipped because they are already tappable visual indicators.
    ///
    /// - Parameters:
    ///   - attributed: The attributed string to process.
    ///   - baseFont: The surrounding font, used to baseline-align the icon.
    ///   - color: The tint color applied to every icon.
    ///   - iconSize: Render size of the icon in points.
    ///   - spacing: Horizontal gap in points between the link text and the icon.
    ///     When `nil` a Unicode thin space character is used.
    ///   - baselineAdjust: Additional vertical offset on top of the automatic cap-height alignment.
    ///     Positive values shift the icon up; negative values shift it down.
    ///   - iconResolver: A closure that maps each link URL to `(assetName, sfSymbol, image)`.
    ///     When `image` is non-nil it is used directly, bypassing the asset catalog lookup.
    ///     Otherwise `assetName` is tried via `BrandIcon.resolvedUIImage`; if absent or empty the
    ///     SF Symbol is used as the final fallback.
    /// - Returns: A new attributed string with icon attachments appended after each link run.
    static func appendLinkIcons(
        to attributed: NSAttributedString,
        baseFont: UIFont,
        color: UIColor,
        iconSize: CGFloat = 10,
        spacing: CGFloat? = nil,
        baselineAdjust: CGFloat = 0,
        iconResolver: (URL) -> (assetName: String, sfSymbol: String, image: UIImage?)
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)

        // Collect (range, url) pairs in reverse order so insertions don't shift earlier indices.
        var linkEntries: [(NSRange, URL)] = []
        mutable.enumerateAttribute(.link, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            guard let url = value as? URL else { return }
            // Skip NSTextAttachment characters (citation badges) — they are already tappable.
            let isAttachment = mutable.attribute(.attachment, at: range.location, effectiveRange: nil) != nil
            if !isAttachment {
                linkEntries.append((range, url))
            }
        }

        for (range, url) in linkEntries.reversed() {
            let (assetName, sfSymbol, overrideImage) = iconResolver(url)
            let icon = makeLinkIconAttachment(
                assetName: assetName,
                sfSymbol: sfSymbol,
                overrideImage: overrideImage,
                baseFont: baseFont,
                color: color,
                iconSize: iconSize,
                spacing: spacing,
                baselineAdjust: baselineAdjust
            )
            mutable.insert(icon, at: range.upperBound)
        }

        return mutable
    }

    /// Produces a small icon attachment sized and baseline-aligned to sit inline with text.
    /// Resolution priority: `overrideImage` → named asset (via `BrandIcon.resolvedUIImage`) → SF Symbol.
    ///
    /// - Parameters:
    ///   - assetName: Named image asset to try. Pass an empty string to skip straight to the SF Symbol.
    ///   - sfSymbol: SF Symbol name used when neither `overrideImage` nor the named asset is available.
    ///   - overrideImage: A `UIImage` that, when non-nil, is used directly without any catalog lookup.
    ///   - baseFont: The surrounding font used for baseline alignment.
    ///   - color: The tint color to apply to the icon.
    ///   - iconSize: Render size in points.
    ///   - spacing: Horizontal gap before the icon in points. When `nil` a thin space character is used.
    ///   - baselineAdjust: Additional vertical nudge on top of the auto cap-height alignment.
    /// - Returns: An attributed string containing a space/gap and the icon attachment.
    private static func makeLinkIconAttachment(
        assetName: String,
        sfSymbol: String,
        overrideImage: UIImage? = nil,
        baseFont: UIFont,
        color: UIColor,
        iconSize: CGFloat,
        spacing: CGFloat?,
        baselineAdjust: CGFloat
    ) -> NSAttributedString {
        let resolvedBase = overrideImage
            ?? BrandIcon.resolvedUIImage(assetName: assetName, systemName: sfSymbol, pointSize: iconSize)
            ?? UIImage()
        let image = resolvedBase.withTintColor(color, renderingMode: .alwaysOriginal)

        let attachment = NSTextAttachment()
        attachment.image = image
        let autoBaseline = (baseFont.capHeight - iconSize) / 2
        attachment.bounds = CGRect(x: 0, y: autoBaseline + baselineAdjust, width: iconSize, height: iconSize)

        let result = NSMutableAttributedString()
        if let spacingPt = spacing {
            // A zero-height NSTextAttachment with a fixed width acts as a reliable horizontal
            // spacer — UITextView's layout manager always honours attachment bounds exactly,
            // unlike kern on invisible Unicode characters which can be ignored.
            let spacer = NSTextAttachment()
            spacer.image = nil
            spacer.bounds = CGRect(x: 0, y: 0, width: spacingPt, height: 0)
            result.append(NSAttributedString(attachment: spacer))
        } else {
            result.append(NSAttributedString(string: "\u{2009}")) // thin space (~2 pt)
        }
        result.append(NSAttributedString(attachment: attachment))
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
