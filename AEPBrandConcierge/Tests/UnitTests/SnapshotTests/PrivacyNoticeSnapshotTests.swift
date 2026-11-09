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

@MainActor
final class PrivacyNoticeSnapshotTests: XCTestCase {
    private let shortNotice = ConciergePrivacyNoticeBehavior(
        title: "Privacy Notice",
        text: "Information you share is used to answer your questions."
    )
    private let longNotice = ConciergePrivacyNoticeBehavior(
        title: "Privacy Notice",
        text: """
        Information you share in this chat is used to answer your questions. \
        Please read the privacy policy for details about how your information is handled.

        Do not include sensitive personal, financial, or health information in your messages.
        """
    )

    func test_shortNotice_light() {
        assertSnapshot(
            of: noticeView(shortNotice),
            as: .image(layout: .fixed(width: 390, height: 180))
        )
    }

    func test_noticeWithDisclaimerStyleLinks() {
        let notice = ConciergePrivacyNoticeBehavior(
            title: "Privacy Notice",
            text: "Read our {Privacy Policy} and {Terms of Use}. Please do not provide sensitive personal information.",
            links: [
                ConciergeDisclaimerLink(text: "Privacy Policy", url: "https://www.example.com/privacy"),
                ConciergeDisclaimerLink(text: "Terms of Use", url: "https://www.example.com/terms")
            ]
        )
        assertSnapshot(of: noticeView(notice), as: .image(layout: .fixed(width: 390, height: 300)))
    }

    func test_longNotice_narrowDark() {
        assertSnapshot(
            of: noticeView(longNotice).environment(\.colorScheme, .dark),
            as: .image(layout: .fixed(width: 320, height: 420))
        )
    }

    func test_longNotice_accessibilityText() {
        assertSnapshot(
            of: noticeView(longNotice).environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge),
            as: .image(layout: .fixed(width: 390, height: 1200))
        )
    }

    func test_blankTitle_andHiddenBody() {
        let view = VStack(spacing: 12) {
            PrivacyNoticeView(notice: ConciergePrivacyNoticeBehavior(title: " \n ", text: shortNotice.text))
            PrivacyNoticeView(notice: ConciergePrivacyNoticeBehavior(title: "Must not appear", text: " \n "))
        }
        .padding(16)
        .conciergeTheme(ConciergeTheme())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 180)))
    }

    func test_noticeInConversation() {
        let first = Message(template: .basic(isUserMessage: true), messageBody: "Where is the store?")
        let view = MessageListView(
            messages: [
                first,
                Message(template: .basic(isUserMessage: false), messageBody: "The store is at 123 Main Street."),
                Message(template: .basic(isUserMessage: true), messageBody: "What are its hours?"),
                Message(template: .basic(isUserMessage: false), messageBody: "Check the store website for current hours.")
            ],
            privacyNotice: shortNotice,
            isInputFocused: .constant(false),
            onSpeak: { _ in }
        )
        .conciergeTheme(ConciergeTheme())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 700)))
    }

    private func noticeView(_ notice: ConciergePrivacyNoticeBehavior) -> some View {
        PrivacyNoticeView(notice: notice)
            .padding(16)
            .conciergeTheme(ConciergeTheme())
    }
}
