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

import SwiftUI
import XCTest
@testable import AEPBrandConcierge

@MainActor
final class MessageListViewShouldFillRemainingHeightTests: XCTestCase {
    func testPrivacyNoticeUsesFirstTypedQueryRowEvenAfterHandoff() {
        let handoff = message("Order request sent", turnId: UUID())
        let first = Message(template: .basic(isUserMessage: true), messageBody: "Where is the store?").inTurn(UUID())
        let latest = Message(template: .basic(isUserMessage: true), messageBody: "Hours?").inTurn(UUID())
        let view = MessageListView(messages: [handoff, first, latest],
                                   privacyNotice: ConciergePrivacyNoticeBehavior(text: "Configured privacy copy"),
                                   isInputFocused: .constant(false), onSpeak: { _ in })
        XCTAssertEqual(view.transcriptRows.filter(\.showsPrivacyNotice).map(\.id), [first.id])
        XCTAssertEqual(MessageListView.newestTurn(in: view.messages)?.anchorId, latest.id)
    }

    func testHandoffAnchorsToLocalMessageUntilNextTurn() throws {
        let preceding = Message(template: .basic(isUserMessage: true), messageBody: "Show my cart").inTurn(UUID())
        let turnId = UUID()
        let local = message("Order request sent", turnId: turnId)
        let response = message("Check the cart", turnId: turnId)
        let card = Message(nativeCardId: "cart").inTurn(turnId)
        let initial = try XCTUnwrap(MessageListView.newestTurn(in: [preceding, local]))
        let completed = try XCTUnwrap(MessageListView.newestTurn(in: [preceding, local, response, card]))
        XCTAssertEqual(initial, completed)
        XCTAssertEqual(completed.anchorId, local.id)
    }

    func testPlaceholderReplacementAndRollbackDoNotNavigateAgain() throws {
        let previous = Message(template: .basic(isUserMessage: true), messageBody: "Earlier").inTurn(UUID())
        let handoffId = UUID()
        let placeholder = message("", turnId: handoffId)
        let card = Message(nativeCardId: "cart").inTurn(handoffId)
        var navigation = MessageListView.TurnNavigation()
        let first = try XCTUnwrap(MessageListView.newestTurn(in: [previous, placeholder]))
        let replacement = try XCTUnwrap(MessageListView.newestTurn(in: [previous, card]))
        let rollback = try XCTUnwrap(MessageListView.newestTurn(in: [previous]))
        XCTAssertTrue(navigation.consume(first, older: [previous][...]))
        XCTAssertEqual(replacement.anchorId, card.id)
        XCTAssertFalse(navigation.consume(replacement, older: [previous][...]))
        XCTAssertFalse(navigation.consume(rollback, older: []))
        var reopened = MessageListView.TurnNavigation()
        XCTAssertTrue(reopened.consume(replacement, older: [previous][...]))
    }

    func testLegacyHistoryUsesLastUserAndShortTurnGetsOnlyMissingSpace() {
        let user = Message(template: .basic(isUserMessage: true), messageBody: "Legacy")
        let reply = Message(template: .basic(isUserMessage: false), messageBody: "Reply")
        XCTAssertEqual(MessageListView.newestTurn(in: [user, reply])?.anchorId, user.id)
        XCTAssertNil(MessageListView.newestTurn(in: [reply]))
        XCTAssertEqual(MessageListView.trailingSpace(viewport: 500, turnHeight: 100, bottomPadding: 20), 380)
        XCTAssertEqual(MessageListView.trailingSpace(viewport: 500, turnHeight: 550, bottomPadding: 20), 0)
        XCTAssertEqual(MessageListView.trailingSpace(viewport: 500, turnHeight: nil, bottomPadding: 20), 0)
    }

    private func message(_ text: String, turnId: UUID) -> Message {
        Message(template: .basic(isUserMessage: false), messageBody: text).inTurn(turnId)
    }
}
