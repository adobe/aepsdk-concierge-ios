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
import UIKit
import XCTest
@testable import AEPBrandConcierge

final class MessageTests: XCTestCase {

    // MARK: - chatMessageView(onCtaButtonTap:)

    func test_chatMessageView_threadsOnCtaButtonTapThrough() {
        var capturedLabel: String?
        var capturedUrl: String?
        let message = Message(template: .divider)

        let view = message.chatMessageView(onCtaButtonTap: { label, url in
            capturedLabel = label
            capturedUrl = url
        })
        view?.onCtaButtonTap?("Buy now", "https://example.com/buy")

        XCTAssertEqual(capturedLabel, "Buy now")
        XCTAssertEqual(capturedUrl, "https://example.com/buy")
    }

    func test_chatMessageView_defaultsOnCtaButtonTapToNil() throws {
        let message = Message(template: .divider)

        let view = try XCTUnwrap(message.chatMessageView())

        XCTAssertNil(view.onCtaButtonTap)
    }

    func test_chatMessageView_isNilForNativeCardRows() {
        XCTAssertNil(Message(nativeCardId: "card").chatMessageView())
    }

    // MARK: - isWelcomeContent

    func test_isWelcomeContent_onlyForWelcomeTemplates() {
        XCTAssertTrue(Message(template: .welcomeHeader(title: "Hi", body: "Welcome")).isWelcomeContent)
        XCTAssertTrue(Message(template: .welcomePromptSuggestion(imageSource: .remote(nil), text: "Shoes",
                                                                 background: .clear)).isWelcomeContent)
        XCTAssertFalse(Message(template: .basic(isUserMessage: false)).isWelcomeContent)
        XCTAssertFalse(Message(nativeCardId: "card").isWelcomeContent)
    }

    // MARK: - BasicMessageView.markdownBlockSpacing

    func test_markdownBlockSpacing_defaultLineHeight_usesFontLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        let spacing = BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 1.0)

        XCTAssertEqual(spacing, font.lineHeight, accuracy: 0.001)
    }

    func test_markdownBlockSpacing_themedLineHeight_usesThemedLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        let spacing = BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 1.75)

        XCTAssertEqual(spacing, 28, accuracy: 0.001)
    }

    func test_markdownBlockSpacing_invalidMultiplier_fallsBackToFontLineHeight() {
        let font = UIFont.systemFont(ofSize: 16)

        XCTAssertEqual(BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: 0), font.lineHeight, accuracy: 0.001)
        XCTAssertEqual(BasicMessageView.markdownBlockSpacing(font: font, lineHeightMultiplier: .nan), font.lineHeight, accuracy: 0.001)
    }

    @MainActor
    func test_agentMessage_headingColorFromThemeKeepsBodyAndLinkColors() throws {
        let configurations: [(json: String, heading: String)] = [
            (##"{"theme":{"--message-concierge-text":"#123456","--message-concierge-link-color":"#0077CC"}}"##, "#123456"),
            (##"{"theme":{"--message-concierge-text":"#123456","--message-concierge-link-color":"#0077CC","--message-concierge-heading-color":"#D83426"}}"##, "#D83426")
        ]
        let markdown = "# Heading [link](https://example.com)\n\nBody text"

        for configuration in configurations {
            let theme = try JSONDecoder().decode(ConciergeTheme.self, from: Data(configuration.json.utf8))
            let view = BasicMessageView(isUserMessage: false, messageBody: markdown).conciergeTheme(theme)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
            let hosting = UIHostingController(rootView: view)
            window.rootViewController = hosting
            window.isHidden = false
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            hosting.view.layoutIfNeeded()

            let textViews = markdownTextViews(in: hosting.view)
            let heading = try XCTUnwrap(textViews.first { $0.text.contains("Heading") }?.attributedText)
            let body = try XCTUnwrap(textViews.first { $0.text.contains("Body text") }?.attributedText)
            let headingColor = try XCTUnwrap(heading.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
            let bodyColor = try XCTUnwrap(body.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
            let linkRange = (heading.string as NSString).range(of: "link")
            XCTAssertNotEqual(linkRange.location, NSNotFound)
            guard linkRange.location != NSNotFound else { return }
            let linkColor = try XCTUnwrap(heading.attribute(.foregroundColor, at: linkRange.location, effectiveRange: nil) as? UIColor)

            XCTAssertEqual(Color(uiColor: headingColor).toHexString(), configuration.heading)
            XCTAssertEqual(Color(uiColor: bodyColor).toHexString(), "#123456")
            XCTAssertEqual(Color(uiColor: linkColor).toHexString(), "#0077CC")
        }
    }

    @MainActor
    private func markdownTextViews(in view: UIView) -> [MarkdownText.AutoSizingTextView] {
        let current = (view as? MarkdownText.AutoSizingTextView).map { [$0] } ?? []
        return current + view.subviews.flatMap { markdownTextViews(in: $0) }
    }
}
