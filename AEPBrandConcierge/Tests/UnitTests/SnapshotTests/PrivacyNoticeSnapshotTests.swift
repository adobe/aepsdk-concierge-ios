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

    func test_firstSubmissionShowsNotice_andNoticeScrollsWithTranscript() async throws {
        let configuration = ConciergeConfiguration()
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = ChatController(configuration: configuration, chatService: service, speechCapturer: nil, speaker: nil)
        var theme = ConciergeTheme()
        theme.behavior.privacyNotice = shortNotice
        let host = UIHostingController(rootView: PrivacyTranscriptHarness(controller: controller).conciergeTheme(theme))
        let previousKeyWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            controller.abandonActiveTurn()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.applyTextChange("Where is the store?")
        controller.sendMessage(isUser: true)
        controller.messages[controller.messages.count - 1].messageBody = "The store is at 123 Main Street."
        try await Task.sleep(nanoseconds: 700_000_000)
        host.view.layoutIfNeeded()
        let scrollView = try XCTUnwrap(findScrollView(in: host.view))
        let firstOffset = scrollView.contentOffset.y
        let firstID = controller.messages.first?.id
        assertSnapshot(of: renderedImage(of: host.view), as: .image, named: "first-submission")

        controller.abandonActiveTurn()
        controller.messages.append(Message(
            template: .basic(isUserMessage: false),
            messageBody: String(repeating: "The store is at 123 Main Street. ", count: 25)
        ))
        controller.applyTextChange("What are its hours?")
        controller.sendMessage(isUser: true)
        controller.messages[controller.messages.count - 1].messageBody = "Checking current hours."
        XCTAssertEqual(controller.chatState, .processing)
        XCTAssertNotEqual(controller.userMessageToScrollId, firstID)
        try await Task.sleep(nanoseconds: 700_000_000)
        host.view.layoutIfNeeded()
        let updatedScrollView = try XCTUnwrap(findScrollView(in: host.view))
        // Drive the native scroll offset: ScrollViewReader animations do not advance in
        // this framework test host, including with the pre-notice transcript implementation.
        let bottomOffset = updatedScrollView.contentSize.height - updatedScrollView.bounds.height
            + updatedScrollView.adjustedContentInset.bottom
        updatedScrollView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: false)
        XCTAssertGreaterThan(updatedScrollView.contentOffset.y, firstOffset + 100)
        XCTAssertEqual(controller.userScrollTick, 2)
        XCTAssertEqual(controller.messages.first?.id, firstID)
        assertSnapshot(of: renderedImage(of: host.view), as: .image, named: "later-submission")

        updatedScrollView.setContentOffset(CGPoint(x: 0, y: -updatedScrollView.adjustedContentInset.top), animated: false)
        XCTAssertEqual(updatedScrollView.contentOffset.y, -updatedScrollView.adjustedContentInset.top, accuracy: 1)
        XCTAssertEqual(controller.messages.first?.id, firstID)
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        return view.subviews.lazy.compactMap { self.findScrollView(in: $0) }.first
    }

    private func renderedImage(of view: UIView) -> UIImage {
        UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            view.layer.render(in: context.cgContext)
        }
    }

    private func noticeView(_ notice: ConciergePrivacyNoticeBehavior) -> some View {
        PrivacyNoticeView(notice: notice)
            .padding(16)
            .conciergeTheme(ConciergeTheme())
    }

    private struct PrivacyTranscriptHarness: View {
        @Environment(\.conciergeTheme) private var theme
        @ObservedObject var controller: ChatController

        var body: some View {
            MessageListView(
                messages: controller.messages,
                privacyNotice: theme.behavior.privacyNotice,
                userScrollTick: controller.userScrollTick,
                userMessageToScrollId: controller.userMessageToScrollId,
                scrollToLastOnAppear: controller.hasConversationStarted,
                chatState: controller.chatState,
                isInputFocused: .constant(false),
                onSpeak: { _ in }
            )
        }
    }
}
