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

import XCTest
@testable import AEPBrandConcierge

private final class ContractSpeaker: TextSpeaking { func utter(text: String) {} }

/// Behavioural contract for a data-handoff turn.
///
/// These tests deliberately know nothing about *how* a turn is implemented - no timers, flags,
/// generations, or message indices. They describe only what a caller and the transcript are
/// entitled to observe. That makes them a fixed baseline: they must keep passing across any
/// re-architecture of the turn lifecycle, and any new one should be written at this level.
///
/// Each test names the invariant it pins. The invariants are:
///
/// - **A. Exactly once** - an accepted turn reports exactly one outcome, on every path.
/// - **B. Terminal state** - after any outcome the chat is `.idle`. No path parks it.
/// - **C. Admission** - one turn at a time; a rejected turn disturbs nothing.
/// - **D. Failure leaves no residue** - a failed turn removes everything it added and nothing else.
/// - **E. Success renders** - a successful turn leaves its reply and no empty placeholder.
/// - **F. No revival** - once reported, later service activity changes nothing.
/// - **G. Deadlines** - a silent turn is capped; a streaming turn is not.
/// - **H. Token window** - awaiting a token is not a delivery failure.
/// - **I. Silence** - a failed handoff renders no error bubble.
/// - **J. Release** - a capped turn releases the underlying request.
@MainActor
final class DataHandoffTurnContractTests: XCTestCase {

    private var configuration = ConciergeConfiguration()

    override func tearDown() {
        ConciergeAuthTokenResolver.shared.setProvider(nil)
        super.tearDown()
    }

    // MARK: - A. Exactly once

    func test_A1_successfulTurn_reportsExactlyOneOutcome() {
        let service = MockChatService(configuration: configuration)
        service.plannedChunks = [payload(state: ConciergeConstants.StreamState.COMPLETED, message: "Here you go")]
        let controller = makeController(service: service)

        var outcomes: [ConciergeError?] = []
        XCTAssertTrue(controller.handleDataHandoff(routingHint: "hint", xdmFields: [:]) { outcomes.append($0) })

        spinUntil(!outcomes.isEmpty)
        settle()
        XCTAssertEqual(outcomes.count, 1, "A: exactly one outcome")
        XCTAssertNil(outcomes.first ?? nil, "a rendered reply is a success")
    }

    func test_A2_failedTurn_reportsExactlyOneOutcome() {
        let service = MockChatService(configuration: configuration)
        service.plannedError = .unreachable
        let controller = makeController(service: service)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(!outcomes.isEmpty)
        settle()
        XCTAssertEqual(outcomes.count, 1, "A: exactly one outcome")
        XCTAssertNotNil(outcomes.first ?? nil, "a failed turn must report a failure")
    }

    func test_A3_cappedTurn_reportsExactlyOneOutcome_evenWhenTheServiceAlsoReports() {
        // The cap reports, then the cancelled request reports too. The caller must hear once.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "silent", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(timeout: 2.0, !outcomes.isEmpty)
        service.triggerCompletion()
        settle()
        XCTAssertEqual(outcomes.count, 1, "A: the cancellation must not deliver a second outcome")
    }

    func test_A4_turnWithNoCompletionHandler_isStillGoverned() {
        // A caller that wants no callback must not disable the turn's own lifecycle.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        XCTAssertTrue(controller.handleDataHandoff(routingHint: "no-callback", xdmFields: [:]))

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle, "B: a turn with no callback must still terminate")
    }

    // MARK: - B. Terminal state

    func test_B1_everyOutcome_returnsTheChatToIdle() {
        let cases: [(name: String, configure: (MockChatService) -> Void)] = [
            ("success", { $0.plannedChunks = [self.payload(state: ConciergeConstants.StreamState.COMPLETED, message: "ok")] }),
            ("service failure", { $0.plannedError = .unreachable }),
            ("empty response", { $0.plannedChunks = [] })
        ]

        for testCase in cases {
            let service = MockChatService(configuration: configuration)
            testCase.configure(service)
            let controller = makeController(service: service)

            var outcomes: [ConciergeError?] = []
            _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:]) { outcomes.append($0) }

            spinUntil(!outcomes.isEmpty)
            spinUntil(controller.chatState == .idle)
            XCTAssertEqual(controller.chatState, .idle, "B: \(testCase.name) must return to idle")
        }
    }

    func test_B2_turnCappedWhileTheServiceStaysSilent_returnsTheChatToIdle() {
        // The unwind must not depend on the service reporting. The real `cancelActiveStream()` is
        // `dataTask?.cancel()`, so with nothing in flight it reports nothing at all.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        service.completesOnCancel = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        _ = controller.handleDataHandoff(routingHint: "silent-cancel", xdmFields: [:])

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle,
                       "B: the turn must unwind itself when the service reports nothing")
    }

    func test_B3_turnCancelledWhileAwaitingItsToken_returnsTheChatToIdle() {
        // The window between accepting a handoff and sending it: no request exists yet, so there
        // is nothing to cancel and no failure path to unwind through.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        ConciergeAuthTokenResolver.shared.setProvider({
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            return "late"
        }, timeout: 30)

        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)
        _ = controller.handleDataHandoff(routingHint: "slow-token", xdmFields: [:])

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle,
                       "B: a turn capped before it was sent must still leave the chat usable")
    }

    // MARK: - C. Admission

    func test_C1_secondTurnIsRejectedWhileOneIsInFlight() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service)

        XCTAssertTrue(controller.handleDataHandoff(routingHint: "first", xdmFields: [:]))
        XCTAssertFalse(controller.handleDataHandoff(routingHint: "second", xdmFields: [:]),
                       "C: only one turn may be in flight")
    }

    func test_C2_rejectedTurn_doesNotDisturbTheOneInFlight() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service)

        var firstOutcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "first", xdmFields: [:], localMessage: "Order confirmed") {
            firstOutcomes.append($0)
        }
        let transcriptBefore = controller.messages.map(\.id)

        _ = controller.handleDataHandoff(routingHint: "second", xdmFields: [:], localMessage: "Second")

        settle()
        XCTAssertEqual(controller.messages.map(\.id), transcriptBefore,
                       "C: a rejected turn must not touch the transcript")
        XCTAssertTrue(firstOutcomes.isEmpty, "C: a rejected turn must not resolve the live one")
        XCTAssertEqual(controller.chatState, .processing, "C: the live turn must stay in flight")
    }

    func test_C3_chatIsAcceptingAgainOnceATurnEnds() {
        let service = MockChatService(configuration: configuration)
        service.plannedChunks = [payload(state: ConciergeConstants.StreamState.COMPLETED, message: "ok")]
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "first", xdmFields: [:])
        spinUntil(controller.chatState == .idle)

        XCTAssertTrue(controller.handleDataHandoff(routingHint: "second", xdmFields: [:]),
                      "C: a finished turn must release admission")
    }

    // MARK: - D. Failure leaves no residue

    func test_D1_failedTurn_leavesNothingItAdded() {
        let service = MockChatService(configuration: configuration)
        service.plannedError = .unreachable
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:])

        spinUntil(controller.chatState == .idle)
        XCTAssertTrue(controller.messages.isEmpty, "D: a failed turn must leave no residue")
    }

    func test_D2_failedTurn_keepsWhatTheUserAlreadySaw() {
        // A `localMessage` is shown the moment the handoff is accepted. Removing it on failure
        // would take content off screen that the user has already read.
        let service = MockChatService(configuration: configuration)
        service.plannedError = .unreachable
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:], localMessage: "Order confirmed")

        spinUntil(controller.chatState == .idle)
        XCTAssertEqual(controller.messages.count, 1, "D: only the local message may remain")
        XCTAssertEqual(controller.messages.first?.messageBody, "Order confirmed")
    }

    func test_D3_cappedTurn_leavesNoPlaceholder() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        service.completesOnCancel = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        _ = controller.handleDataHandoff(routingHint: "silent", xdmFields: [:])

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        XCTAssertTrue(controller.messages.isEmpty, "D: a capped turn must not strand its placeholder")
    }

    // MARK: - E. Success renders

    func test_E1_successfulTurn_rendersItsReply() {
        let service = MockChatService(configuration: configuration)
        service.plannedChunks = [payload(state: ConciergeConstants.StreamState.COMPLETED, message: "Here you go")]
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:], localMessage: "Order confirmed")

        spinUntil(controller.chatState == .idle)
        let bodies = controller.messages.compactMap(\.messageBody)
        XCTAssertTrue(bodies.contains("Order confirmed"), "E: the local message must survive")
        XCTAssertTrue(bodies.contains("Here you go"), "E: the reply must be rendered")
        XCTAssertFalse(bodies.contains(""), "E: no empty placeholder may remain")
    }

    func test_E2_routingHintIsSentButNeverRendered() {
        let service = MockChatService(configuration: configuration)
        service.plannedChunks = [payload(state: ConciergeConstants.StreamState.COMPLETED, message: "reply")]
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:])

        spinUntil(controller.chatState == .idle)
        XCTAssertEqual(service.lastQuery, "successful-checkout", "E: the hint is the query")
        XCTAssertFalse(controller.messages.compactMap(\.messageBody).contains("successful-checkout"),
                       "E: the hint must never appear in the transcript")
    }

    // MARK: - F. No revival

    func test_F1_lateServiceActivity_doesNotChangeAResolvedTurn() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        service.completesOnCancel = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "silent", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        let transcriptAfterResolution = controller.messages.map(\.id)

        // The abandoned request finally answers.
        service.emitChunk(payload(state: ConciergeConstants.StreamState.COMPLETED, message: "too late"))
        service.triggerCompletion()
        settle()

        XCTAssertEqual(outcomes.count, 1, "F: no second outcome")
        XCTAssertEqual(controller.chatState, .idle, "F: a resolved turn must not re-enter processing")
        XCTAssertEqual(controller.messages.map(\.id), transcriptAfterResolution,
                       "F: a resolved turn must not render late content")
    }

    func test_F2_turnAbandonedBeforeSending_neverReachesTheService() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        ConciergeAuthTokenResolver.shared.setProvider({
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return "late"
        }, timeout: 30)

        // The ceiling, not the fast cap, is what bounds a turn still waiting on its token.
        // The 10x gap between the ceiling and the token is margin, not precision: the assertion
        // only means anything if the ceiling fires first, and a loaded CI runner can delay a
        // `DispatchQueue.main.asyncAfter` work item well past its deadline.
        let controller = makeController(service: service, turnTimeout: 0.2, firstChunkTimeout: 5.0)
        _ = controller.handleDataHandoff(routingHint: "slow-token", xdmFields: [:])

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        spinUntil(timeout: 2.5, false) // outlive the token window

        XCTAssertEqual(service.streamChatCallCount, 0,
                       "F: an abandoned turn must not hit the network when its token arrives")
    }

    // MARK: - G. Deadlines

    func test_G1_silentTurn_isCapped() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "silent", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(timeout: 2.0, !outcomes.isEmpty)
        guard case .timeout = outcomes.first ?? nil else {
            return XCTFail("G: a silent turn must report .timeout, got \(String(describing: outcomes.first ?? nil))")
        }
    }

    func test_G2_streamingTurn_survivesTheFastCap() {
        // The point of a two-stage deadline: a slow but living turn keeps its reply.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.3)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "slow", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(timeout: 1.0, service.streamChatCallCount == 1)
        service.emitChunk(payload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "thinking"))

        spinUntil(timeout: 0.6, false) // outlive the fast cap
        XCTAssertTrue(outcomes.isEmpty, "G: a streaming turn must not be killed by the fast cap")
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "G: a living turn must not be cancelled")
    }

    func test_G3_turnThatCompletesPromptly_isNotCapped() {
        let service = MockChatService(configuration: configuration)
        service.plannedChunks = [payload(state: ConciergeConstants.StreamState.COMPLETED, message: "quick")]
        let controller = makeController(service: service, turnTimeout: 0.3, firstChunkTimeout: 0.2)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "quick", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(!outcomes.isEmpty)
        spinUntil(timeout: 0.8, false) // outlive both deadlines
        XCTAssertEqual(outcomes.count, 1, "G: deadlines must be disarmed by completion")
        XCTAssertEqual(service.cancelActiveStreamCallCount, 0, "G: a finished turn must not be cancelled")
    }

    // MARK: - H. Token window

    func test_H1_waitingOnATokenIsNotADeliveryFailure() {
        // A provider window longer than the fast cap is legal: `setProvider(_:timeout:)` accepts up
        // to `maxTimeout`. Time spent waiting for a token is not time the service failed to answer.
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        ConciergeAuthTokenResolver.shared.setProvider({
            try? await Task.sleep(nanoseconds: 600_000_000)
            return "late"
        }, timeout: 30)

        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        var outcomes: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "slow-token", xdmFields: [:]) { outcomes.append($0) }

        spinUntil(timeout: 2.0, service.streamChatCallCount == 1)
        XCTAssertEqual(service.streamChatCallCount, 1, "H: the turn must be sent once its token arrives")
        XCTAssertTrue(outcomes.isEmpty, "H: awaiting a token must not be reported as a delivery timeout")
    }

    // MARK: - I. Silence

    func test_I1_failedHandoff_rendersNoErrorBubble() {
        let service = MockChatService(configuration: configuration)
        service.plannedError = .unreachable
        let controller = makeController(service: service)

        _ = controller.handleDataHandoff(routingHint: "hint", xdmFields: [:])

        spinUntil(controller.chatState == .idle)
        XCTAssertTrue(controller.messages.isEmpty,
                      "I: the user never asked for this turn, so its failure must stay invisible")
    }

    func test_I2_failedTypedTurn_doesRenderAnErrorBubble() {
        // The counterpart: a user waiting on a visible answer must be told it failed.
        let service = MockChatService(configuration: configuration)
        service.plannedError = .unreachable
        let controller = makeController(service: service)

        controller.applyTextChange("hello")
        controller.sendMessage(isUser: true)

        spinUntil(controller.chatState == .idle)
        XCTAssertGreaterThan(controller.messages.count, 1,
                             "I: a failed typed turn must leave a visible failure")
    }

    // MARK: - J. Release

    func test_J1_cappedTurn_releasesTheRequestExactlyOnce() {
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        let controller = makeController(service: service, turnTimeout: 5.0, firstChunkTimeout: 0.2)

        _ = controller.handleDataHandoff(routingHint: "silent", xdmFields: [:])

        spinUntil(timeout: 2.0, service.cancelActiveStreamCallCount > 0)
        spinUntil(timeout: 0.5, false)
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1,
                       "J: a capped turn must release its request exactly once")
    }

    // MARK: - Helpers

    private func makeController(service: MockChatService,
                                turnTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT,
                                firstChunkTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_FIRST_CHUNK_TIMEOUT) -> ChatController {
        ChatController(configuration: configuration,
                       chatService: service,
                       speechCapturer: nil,
                       speaker: ContractSpeaker(),
                       dispatch: nil,
                       handoffTurnTimeout: turnTimeout,
                       handoffFirstChunkTimeout: firstChunkTimeout)
    }

    private func payload(state: String, message: String? = nil) -> ConversationPayload {
        let response = message.map {
            ConversationResponse(message: $0, promptSuggestions: nil, multimodalElements: nil,
                                 sources: nil, linkHints: nil, state: nil, feedback: nil)
        }
        return ConversationPayload(conversationId: nil, interactionId: nil, request: nil,
                                   response: response, state: state,
                                   key: nil, value: nil, maxAge: nil)
    }

    private func spinUntil(timeout: TimeInterval = 1.0, _ predicate: @autoclosure () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    /// Lets any already-scheduled work drain, so "nothing more happens" can be asserted.
    private func settle() {
        spinUntil(timeout: 0.3, false)
    }
}
