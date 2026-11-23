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

/// Native card rows have no built-in template, so every transcript helper has to classify them by
/// their content. These run each helper with native rows in the positions that used to need guards.
@MainActor
final class MessageListViewNativeRowTests: NativeCardTestCase {
    private let privacyNotice = ConciergePrivacyNoticeBehavior(title: "Privacy Notice", text: "Configured privacy copy.")

    func testPrivacyNoticeSkipsLeadingNativeRows() {
        let messages = [Message(nativeCardId: "card"), Message(template: .basic(isUserMessage: true), messageBody: "Hi")]
        let view = MessageListView(messages: messages, privacyNotice: privacyNotice,
                                   isInputFocused: .constant(false), onSpeak: { _ in })

        XCTAssertEqual(view.privacyNoticeIndex, 1)
        XCTAssertEqual(view.transcriptRows.map(\.showsPrivacyNotice), [false, true])
    }

    func testNativeRowsRetainHandoffTurnWhenPlaceholderIsRemoved() {
        let user = Message(template: .basic(isUserMessage: true), messageBody: "Hi")
        let turnID = UUID()
        let card = Message(nativeCardId: "card").inTurn(turnID)
        let target = MessageListView.newestTurn(in: [user, card])
        XCTAssertEqual(target?.id, turnID)
        XCTAssertEqual(target?.anchorId, card.id)
    }

    func testWelcomeFilteringKeepsNativeRows() {
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let welcome = Message(template: .welcomeHeader(title: "Hi", body: "How can I help?"))
        controller.messages = [welcome]
        XCTAssertFalse(controller.hasConversationStarted)

        controller.messages = [welcome, Message(nativeCardId: "card")]

        XCTAssertTrue(controller.hasConversationStarted)
        XCTAssertEqual(controller.messages.filter { !$0.isWelcomeContent }.map(\.nativeCardId), ["card"],
                       "ChatView's welcome filter keeps native rows")
    }

    /// Renders a transcript that puts native rows before a user query, between suggestion rows, and
    /// last, so the private row, padding, suggestion-group and speech paths all run over them.
    func testTranscriptRendersNativeRowsAmongBuiltInRows() throws {
        var renderCount = 0
        NativeCardRegistry.register(rendererId: "test.row") { _, _, _ in
            renderCount += 1
            return AnyView(Color.clear.frame(height: 40))
        }
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let elements = try CardJSONValue.decode([MultimodalElement].self, from: Data(
            #"[{"type":"custom","rendererId":"test.row","id":"first"},{"type":"custom","rendererId":"test.row","id":"second"}]"#.utf8))
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"),
                                            promptSuggestions: ["Attached"])
        XCTAssertEqual(controller.messages.count, 2)
        var unspokenNativeRow = controller.messages[0]
        unspokenNativeRow.shouldSpeakMessage = true
        unspokenNativeRow.messageBody = "Never spoken"
        var spokenReply = Message(template: .basic(isUserMessage: false), messageBody: "Spoken")
        spokenReply.shouldSpeakMessage = true
        let messages = [unspokenNativeRow,
                        Message(template: .basic(isUserMessage: true), messageBody: "Hi"),
                        Message(template: .promptSuggestion(text: "Standalone")),
                        controller.messages[1],
                        Message(template: .promptSuggestion(text: "After card")),
                        spokenReply]
        var spoken: [String] = []
        var theme = ConciergeTheme()
        theme.behavior.promptSuggestions = ConciergePromptSuggestionsBehavior(showHeader: true)
        let list = MessageListView(messages: messages, privacyNotice: privacyNotice,
                                   isInputFocused: .constant(false), onSpeak: { spoken.append($0) })
            .environment(\.conciergeTheme, theme)
            .environment(\.conciergeNativeCardStore, controller.nativeCards)
        let window = showInWindow(list)
        defer { window.isHidden = true }

        XCTAssertGreaterThanOrEqual(renderCount, 2, "Both native rows render through the transcript")
        XCTAssertEqual(spoken, ["Spoken"], "Native rows are never spoken")
    }

    /// `isStale` is reserved and currently always `false`, so renderers only ever receive `false`.
    /// An identity reset removes a card together with its row, and a removed card doesn't render again.
    func testRenderersAlwaysReceiveIsStaleFalseAcrossIdentityReset() throws {
        var staleValues: [Bool?] = []
        NativeCardRegistry.register(rendererId: "test.row") { _, cardContext, _ in
            staleValues.append(cardContext["isStale"] as? Bool)
            return AnyView(Color.clear.frame(height: 40))
        }
        let controller = ChatController(configuration: nil,
            chatService: MockChatService(configuration: ConciergeConfiguration()), speechCapturer: nil, speaker: nil)
        let elements = try CardJSONValue.decode([MultimodalElement].self,
            from: Data(#"[{"type":"custom","rendererId":"test.row"}]"#.utf8))
        controller.renderElementsForTesting(elements, turnId: UUID(), payload: streamPayload(state: "completed"))
        let window = showInWindow(TranscriptHost(controller: controller))
        defer { window.isHidden = true }
        XCTAssertFalse(staleValues.isEmpty, "The native card rendered")
        XCTAssertTrue(staleValues.allSatisfy { $0 == false }, "Every render reports isStale as false")
        let rendersBeforeReset = staleValues.count

        controller.endConversationForIdentityReset()
        window.rootViewController?.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertTrue(controller.messages.isEmpty)
        XCTAssertEqual(staleValues.count, rendersBeforeReset, "The reset card is removed without rendering again")
    }

    /// Hosts `view` in a visible window and lets it lay out and run its appearance callbacks.
    private func showInWindow<Content: View>(_ view: Content) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1200))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        window.rootViewController?.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        return window
    }
}

/// A transcript bound to its controller, the way `ChatView` hosts it.
private struct TranscriptHost: View {
    @ObservedObject var controller: ChatController

    var body: some View {
        MessageListView(messages: controller.messages, isInputFocused: .constant(false), onSpeak: { _ in })
            .environment(\.conciergeNativeCardStore, controller.nativeCards)
    }
}
