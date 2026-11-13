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
import XCTest
@testable import AEPBrandConcierge

@MainActor
final class MessageListViewAttachedSuggestionsTests: XCTestCase {
    func testSuggestionsAttachOnlyToCardRows() throws {
        let view = MessageListView(messages: [], isInputFocused: .constant(false), onSpeak: { _ in })
        let element = try JSONDecoder().decode(MultimodalElement.self,
            from: Data(#"{"type":"product","entity_info":{"productName":"Product"}}"#.utf8))
        let product = ProductCardData(entityInfo: try XCTUnwrap(element.entityInfo), element: element)
        let suggestions = ["Continue"]
        for message in [Message(nativeCardId: "card", promptSuggestions: suggestions),
                        Message(template: .productCard(product), promptSuggestions: suggestions),
                        Message(template: .carouselGroup([]), promptSuggestions: suggestions)] {
            XCTAssertEqual(view.attachedSuggestions(for: message), suggestions, "\(message.nativeCardId ?? "built-in")")
        }
        XCTAssertNil(view.attachedSuggestions(for: Message(nativeCardId: "card", promptSuggestions: [])))
        XCTAssertNil(view.attachedSuggestions(for: Message(template: .basic(isUserMessage: false),
                                                           promptSuggestions: suggestions)))
    }

    /// A carousel row has no horizontal insets of its own, so suggestions attached to it must not
    /// inherit the card row's layout.
    func testAttachedSuggestionsAlignWithStandaloneSuggestionRows() throws {
        let standalone = try XCTUnwrap(suggestionChipLeadingEdge(in: [Message(template: .promptSuggestion(text: "Standalone"))]))
        for host in [Message(template: .carouselGroup([]), promptSuggestions: ["Attached"]),
                     Message(nativeCardId: "card", promptSuggestions: ["Attached"])] {
            let attached = suggestionChipLeadingEdge(in: [host])
            XCTAssertEqual(attached, standalone, "Suggestions attached to \(host) must align with standalone rows")
        }
    }

    /// Renders the transcript with a solid red chip background and returns the chip's leftmost column.
    private func suggestionChipLeadingEdge(in messages: [Message]) -> Int? {
        var theme = ConciergeTheme()
        CSSKeyMapper.apply(cssKey: "--suggestion-background-color", cssValue: "#FF0000", to: &theme)
        let host = UIHostingController(rootView: MessageListView(messages: messages, isInputFocused: .constant(false),
                                                                onSpeak: { _ in })
            .environment(\.conciergeTheme, theme))
        let size = CGSize(width: 390, height: 400)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            host.view.layer.render(in: context.cgContext)
        }
        return leftmostRedColumn(in: image)
    }

    private func leftmostRedColumn(in image: UIImage) -> Int? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        for column in 0..<width {
            for row in 0..<height {
                let offset = (row * width + column) * 4
                if pixels[offset] > 200, pixels[offset + 1] < 80, pixels[offset + 2] < 80 { return column }
            }
        }
        return nil
    }
}
