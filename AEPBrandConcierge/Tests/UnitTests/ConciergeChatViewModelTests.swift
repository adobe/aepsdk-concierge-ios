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

import AEPCore
import XCTest
@testable import AEPBrandConcierge

// MARK: - Fakes
private final class NoopSpeaker: TextSpeaking { func utter(text: String) {} }

@MainActor
final class ChatControllerTests: XCTestCase {
    
    private var mockConciergeConfiguration = ConciergeConfiguration()
    
    func test_sendMessage_ignores_when_text_empty_or_not_idle() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // Empty text -> ignored
        controller.sendMessage(isUser: true)
        XCTAssertEqual(controller.messages.count, 0)

        // Non-idle -> ignored
        controller.applyTextChange("hi")
        controller.setChatStateForTesting(.processing)
        controller.sendMessage(isUser: true)
        XCTAssertEqual(controller.messages.count, 0)
        XCTAssertEqual(controller.chatState, .processing)
    }

    func test_handleDataHandoff_sendsRoutingHintAsQuery_andDoesNotAppendUserBubble() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        let xdmFields: [String: Any] = ["commerce": ["order": ["purchaseID": "abc123"]]]

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: xdmFields)
        spinUntil(fakeService.lastQuery != nil)

        XCTAssertEqual(fakeService.lastQuery, "successful-checkout")
        XCTAssertTrue((fakeService.lastExtraXDMFields as NSDictionary?)?.isEqual(to: xdmFields) ?? false)

        // Only the assistant placeholder should have been appended - no visible user bubble.
        XCTAssertEqual(controller.messages.count, 1)
        if case .basic(let isUserMessage) = controller.messages[0].template {
            XCTAssertFalse(isUserMessage)
        } else {
            XCTFail("Expected a basic message template")
        }
    }

    func test_handleDataHandoff_withLocalMessage_appendsItBeforeStreamingPlaceholder() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:], localMessage: "Your order is confirmed!")
        spinUntil(fakeService.lastQuery != nil)

        XCTAssertEqual(controller.messages.count, 2)
        XCTAssertEqual(controller.messages[0].messageBody, "Your order is confirmed!")
        if case .basic(let isUserMessage) = controller.messages[0].template {
            XCTAssertFalse(isUserMessage)
        } else {
            XCTFail("Expected a basic message template")
        }
    }

    func test_handleDataHandoff_withNilOrEmptyLocalMessage_appendsOnlyStreamingPlaceholder() {
        let fakeServiceNil = MockChatService(configuration: mockConciergeConfiguration)
        let controllerNil = makeController(configuration: mockConciergeConfiguration, service: fakeServiceNil)
        controllerNil.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:], localMessage: nil)
        spinUntil(fakeServiceNil.lastQuery != nil)
        XCTAssertEqual(controllerNil.messages.count, 1)

        let fakeServiceEmpty = MockChatService(configuration: mockConciergeConfiguration)
        let controllerEmpty = makeController(configuration: mockConciergeConfiguration, service: fakeServiceEmpty)
        controllerEmpty.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:], localMessage: "")
        spinUntil(fakeServiceEmpty.lastQuery != nil)
        XCTAssertEqual(controllerEmpty.messages.count, 1)
    }

    /// A handoff is refused while the *user's* own turn is streaming, not just while another
    /// handoff is. Both occupy the service's single `dataTask`/handler pair.
    func test_handleDataHandoff_whileATypedTurnIsInFlight_rejectsWithoutStartingStream() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep the typed turn in flight
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("what should I buy?")
        controller.sendMessage(isUser: true)
        spinUntil(fakeService.streamChatCallCount == 1)

        var completionCalls: [ConciergeError?] = []
        let started = controller.handleDataHandoff(routingHint: "successful-checkout",
                                                   xdmFields: ["commerce": ["order": ["purchaseID": "abc123"]]],
                                                   localMessage: "This must not render") { error in
            completionCalls.append(error)
        }

        XCTAssertFalse(started)
        XCTAssertEqual(fakeService.lastQuery, "what should I buy?")
        XCTAssertEqual(fakeService.streamChatCallCount, 1, "the rejected handoff must not reach the service")
        XCTAssertFalse(controller.messages.contains { $0.messageBody == "This must not render" })
        // A rejected handoff is reported through the `false` return, not the completion - firing
        // both would deliver two results for one request.
        XCTAssertTrue(completionCalls.isEmpty)
    }

    /// Regression: `handleDataHandoff` must mark the chat as processing itself. `sendMessage` sets
    /// `.processing` before streaming, but a handoff bypasses `sendMessage`, so without its own
    /// transition a second handoff still saw `.idle` and started an overlapping stream - which
    /// overwrites `ConciergeChatService`'s single handler pair and strands the first completion.
    func test_handleDataHandoff_whileAnotherHandoffIsInFlight_isRejected() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep the first handoff in flight
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        let first = controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:])
        spinUntil(fakeService.streamChatCallCount == 1)
        XCTAssertTrue(first)
        XCTAssertEqual(controller.chatState, .processing)

        let second = controller.handleDataHandoff(routingHint: "second-handoff",
                                                  xdmFields: [:],
                                                  localMessage: "This must not render")

        XCTAssertFalse(second)
        XCTAssertEqual(fakeService.streamChatCallCount, 1, "A second overlapping stream was started")
        XCTAssertEqual(fakeService.lastQuery, "successful-checkout")
        XCTAssertFalse(controller.messages.contains { $0.messageBody == "This must not render" })
    }

    /// A handoff in flight must also block a user-typed turn, for the same single-handler reason.
    func test_sendMessage_whileHandoffIsInFlight_isIgnored() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:])
        spinUntil(fakeService.streamChatCallCount == 1)

        controller.applyTextChange("hello")
        controller.sendMessage(isUser: true)

        // `sendMessage` appends the user bubble synchronously once past its guard, so its absence
        // is a deterministic signal that the turn was rejected - unlike `streamChatCallCount`,
        // which only rises after the async token resolution.
        XCTAssertFalse(controller.messages.contains { $0.messageBody == "hello" })
        spinUntil(timeout: 0.3, fakeService.streamChatCallCount > 1)
        XCTAssertEqual(fakeService.streamChatCallCount, 1)
        XCTAssertEqual(fakeService.lastQuery, "successful-checkout")
    }

    func test_handleDataHandoff_afterPreviousHandoffCompletes_isAccepted() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.handleDataHandoff(routingHint: "first", xdmFields: [:])
        spinUntil(fakeService.streamChatCallCount == 1)
        XCTAssertFalse(controller.handleDataHandoff(routingHint: "too-soon", xdmFields: [:]))

        // Finish the first turn; the controller returns to idle and the retry is accepted.
        fakeService.triggerCompletion()
        spinUntil(controller.chatState == .idle)

        let retry = controller.handleDataHandoff(routingHint: "retry", xdmFields: [:])
        spinUntil(fakeService.lastQuery == "retry")

        XCTAssertTrue(retry)
        XCTAssertEqual(fakeService.streamChatCallCount, 2)
    }

    /// The documented contract is that the app may retry once the chat is no longer processing.
    /// Failed turns now return to `.idle`, but the guard stays on `!= .processing` so a handoff is
    /// still accepted if anything ever leaves the controller in an error state.
    func test_handleDataHandoff_afterErrorState_isAccepted() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        controller.setChatStateForTesting(.error(.networkFailure))

        let started = controller.handleDataHandoff(routingHint: "retry-after-failure", xdmFields: [:])
        spinUntil(fakeService.lastQuery != nil)

        XCTAssertTrue(started)
        XCTAssertEqual(fakeService.lastQuery, "retry-after-failure")
    }

    // MARK: - Data handoff scrolling and conversation state

    /// A handoff is triggered from app UI, not the composer, so without its own scroll the reply
    /// streams in below the fold and the user has to scroll manually to find it.
    func test_handleDataHandoff_withLocalMessage_scrollsToTheLocalMessage() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        let tickBefore = controller.userScrollTick

        controller.handleDataHandoff(routingHint: "successful-checkout",
                                     xdmFields: [:],
                                     localMessage: "Thank you for purchasing Headphones")
        spinUntil(controller.userScrollTick > tickBefore)

        XCTAssertGreaterThan(controller.userScrollTick, tickBefore)
        let anchor = controller.messages.first { $0.messageBody == "Thank you for purchasing Headphones" }
        XCTAssertNotNil(anchor)
        XCTAssertEqual(controller.userMessageToScrollId, anchor?.id)
    }

    /// With no local message the streaming placeholder is the first thing the turn renders, so it
    /// becomes the anchor - otherwise the reply would still land off screen.
    func test_handleDataHandoff_withoutLocalMessage_scrollsToTheStreamingPlaceholder() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        let tickBefore = controller.userScrollTick

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:])
        spinUntil(controller.userScrollTick > tickBefore)

        XCTAssertEqual(controller.messages.count, 1)
        XCTAssertEqual(controller.userMessageToScrollId, controller.messages.first?.id)
    }

    func test_handleDataHandoff_whenRejected_doesNotScroll() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep the first turn in flight
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.handleDataHandoff(routingHint: "first", xdmFields: [:])
        spinUntil(fakeService.streamChatCallCount == 1)
        spinUntil(timeout: 0.3, false) // let the accepted turn's own scroll land first
        let tickBefore = controller.userScrollTick
        let anchorBefore = controller.userMessageToScrollId

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:], localMessage: "Nope")
        spinUntil(timeout: 0.3, controller.userScrollTick != tickBefore)

        XCTAssertEqual(controller.userScrollTick, tickBefore)
        XCTAssertEqual(controller.userMessageToScrollId, anchorBefore,
                       "a rejected handoff must not move the transcript off the live turn")
    }

    /// A handoff appends only agent-styled messages. Keying "the conversation has started" off a
    /// *user* message would leave a checkout-driven conversation looking untouched - welcome header
    /// rendered above the handoff turn, and no scroll-to-latest when the chat is opened.
    func test_hasConversationStarted_isTrueAfterAHandoffWithNoUserMessage() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        XCTAssertFalse(controller.hasConversationStarted)

        controller.handleDataHandoff(routingHint: "successful-checkout",
                                     xdmFields: [:],
                                     localMessage: "Thank you for purchasing Headphones")

        XCTAssertTrue(controller.hasConversationStarted)
    }

    func test_hasConversationStarted_isFalseForWelcomeContentOnly() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        controller.messages = [
            Message(template: .welcomeHeader(title: "Hi", body: "How can I help?")),
            Message(template: .welcomePromptSuggestion(imageSource: .remote(nil), text: "Find me shoes", background: .clear))
        ]

        XCTAssertFalse(controller.hasConversationStarted)
    }

    // MARK: - Data handoff completion
    func test_handleDataHandoff_onSuccessfulStream_completesWithoutError() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Here are some picks")]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        var completionCalls: [ConciergeError?] = []

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:]) { error in
            completionCalls.append(error)
        }
        spinUntil(completionCalls.count == 1)

        XCTAssertEqual(completionCalls.count, 1)
        XCTAssertNil(completionCalls.first ?? .unknown)
        spinUntil(controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_handleDataHandoff_onServiceError_completesWithThatError() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        var completionCalls: [ConciergeError?] = []

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:]) { error in
            completionCalls.append(error)
        }
        spinUntil(completionCalls.count == 1)

        XCTAssertEqual(completionCalls.count, 1)
        guard case .unreachable = completionCalls.first ?? nil else {
            return XCTFail("Expected the service error to reach the handoff completion, got \(String(describing: completionCalls.first))")
        }
    }

    /// An empty response renders a fallback bubble rather than recommendations, so the handoff
    /// did not actually deliver anything and must not be reported as a success.
    func test_handleDataHandoff_onEmptyResponse_completesWithInvalidResponseData() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        var completionCalls: [ConciergeError?] = []

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:]) { error in
            completionCalls.append(error)
        }
        spinUntil(completionCalls.count == 1)

        XCTAssertEqual(completionCalls.count, 1)
        guard case .invalidResponseData = completionCalls.first ?? nil else {
            return XCTFail("Expected .invalidResponseData, got \(String(describing: completionCalls.first))")
        }
    }

    /// The completion resolves the app's public callback, which may trigger an immediate retry.
    /// It must therefore fire only once chat state has settled, or that retry races a stale
    /// `.processing` and is rejected for no real reason.
    func test_handleDataHandoff_completionFiresAfterChatStateSettles() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Done")]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        var stateAtCompletion: ChatState?

        controller.handleDataHandoff(routingHint: "successful-checkout", xdmFields: [:]) { [weak controller] _ in
            stateAtCompletion = controller?.chatState
        }
        spinUntil(stateAtCompletion != nil)

        XCTAssertEqual(stateAtCompletion, .idle)
    }

    func test_streaming_inProgress_accumulates_and_updates_placeholder() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep streaming; do not transition to idle
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hello "),
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "world")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("q")
        XCTAssertTrue(controller.sendEnabled)
        controller.sendMessage(isUser: true)
        // Wait for streaming chunks to apply and accumulate
        spinUntil(controller.messages.count == 2 && controller.messages[1].messageBody == "Hello world")

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello world")
        XCTAssertEqual(controller.chatState, .processing)

        // Now finish the stream explicitly and verify state transitions to idle
        fakeService.triggerCompletion()
        spinUntil(controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle)
    }

    func test_streaming_completed_appends_only_delta() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hel"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Hello")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("go")
        controller.sendMessage(isUser: true)
        // Wait until final message is applied
        spinUntil(controller.messages.count == 2 && controller.messages[1].messageBody == "Hello")

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello")
    }

    func test_sendFeedbackFor_resolvesTokenAndForwardsItToService() {
        ConciergeAuthTokenResolver.shared.setProvider({ "feedback-token" }, timeout: 3)
        defer { ConciergeAuthTokenResolver.shared.setProvider(nil) }

        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "hi",
                        conversationId: "conv-1", interactionId: "turn-1")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // Produce a completed assistant message that carries a payload to give feedback on.
        controller.applyTextChange("q")
        controller.sendMessage(isUser: true)
        spinUntil(controller.messages.count == 2 && controller.messages[1].payload != nil)

        let agentMessageId = controller.messages[1].id
        controller.sendFeedbackFor(
            messageId: agentMessageId,
            with: FeedbackPayload(sentiment: .positive, selectedOptions: ["helpful"], notes: "great")
        )

        spinUntil(fakeService.sendFeedbackCallCount == 1)
        XCTAssertEqual(fakeService.sendFeedbackCallCount, 1, "feedback should be sent once")
        XCTAssertEqual(fakeService.lastFeedbackToken, "feedback-token",
                       "the resolved auth token must be forwarded to sendFeedback")
        XCTAssertNotNil(fakeService.lastFeedbackData, "feedback event data should be forwarded")
    }

    func test_streaming_error_replaces_placeholder_with_error_message_and_returns_to_idle() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        controller.networkErrorMessage = "Themed connection error"

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)

        // Allow onComplete to run
        spinUntil(controller.chatState == .idle)

        // The user message plus the failure notice; the streaming placeholder is gone.
        XCTAssertEqual(controller.messages.count, 2)
        XCTAssertEqual(controller.messages.last?.messageBody, "Themed connection error")
        if case .basic(let isUserMessage) = controller.messages.last?.template {
            XCTAssertFalse(isUserMessage, "the failure notice must read as an agent message")
        } else {
            XCTFail("expected a basic agent message")
        }
        XCTAssertEqual(controller.chatState, .idle,
                       "a failed turn must return to idle - parking in .error deadlocks the composer")
    }

    /// Regression guard for the deadlock: every composer affordance is gated on `.idle`, so if a
    /// failure left a terminal error state the user could type but never send again.
    func test_streaming_error_leavesComposerUsable_andAllowsAnotherSend() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        XCTAssertTrue(controller.micEnabled)
        XCTAssertTrue(controller.composerEditable)

        controller.applyTextChange("trying again")
        XCTAssertTrue(controller.sendEnabled)

        controller.sendMessage(isUser: true)
        // The outbound call happens after an async auth-token resolution, so pump the run loop.
        spinUntil(fakeService.streamChatCallCount == 2)

        XCTAssertEqual(fakeService.streamChatCallCount, 2, "the retry must actually reach the service")
        XCTAssertEqual(fakeService.lastQuery, "trying again")
    }

    func test_handoffCompletion_isDelivered_evenIfCallerReleasesControllerMidTurn() {
        // Regression: the auth-token `Task` captured `self` weakly. The caller's completion is only
        // guaranteed by the `defer` inside `onComplete`, which isn't registered until `streamChat`
        // runs, so a controller released before that point dropped the completion entirely and left
        // the caller to time out with a misleading `.noResponse`. The turn must now always report.
        let resolved = expectation(description: "handoff completion delivered")
        let providerEntered = expectation(description: "auth provider entered")

        ConciergeAuthTokenResolver.shared.setProvider({
            providerEntered.fulfill()
            try? await Task.sleep(nanoseconds: 200_000_000)
            return "token"
        }, timeout: 5)
        defer { ConciergeAuthTokenResolver.shared.setProvider(nil) }

        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        var controller: ChatController? = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        var completionCalls: [ConciergeError?] = []
        let started = controller?.handleDataHandoff(routingHint: "checkout complete",
                                                    xdmFields: ["orderTotal": 42],
                                                    localMessage: nil) { error in
            completionCalls.append(error)
            resolved.fulfill()
        }
        XCTAssertEqual(started, true)

        wait(for: [providerEntered], timeout: 2.0)
        controller = nil // caller drops its reference while the turn is still in flight

        wait(for: [resolved], timeout: 5.0)
        XCTAssertEqual(completionCalls.count, 1, "the completion must be delivered exactly once")
        XCTAssertNotNil(completionCalls.first ?? nil, "a failed turn must surface its error")
        XCTAssertEqual(fakeService.streamChatCallCount, 1,
                       "the in-flight turn must still reach the service after the caller lets go")
    }

    func test_dataHandoffResponseTimeout_outlastsTheControllerCap() {
        // Regression: the hub budget was `READ_TIMEOUT + token budget`. Because `READ_TIMEOUT` is
        // `URLRequest.timeoutInterval` - an *inactivity* timeout - a turn that kept chunking
        // steadily for longer than the budget succeeded and rendered, while the hub had already
        // reported `.noResponse` to the caller.
        XCTAssertGreaterThan(ConciergeConstants.Request.dataHandoffResponseTimeout,
                             ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT,
                             "the controller must always report the outcome before the hub gives up")

        XCTAssertLessThan(ConciergeConstants.Request.DATA_HANDOFF_FIRST_CHUNK_TIMEOUT,
                          ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT,
                          "the fast cap must fire before the hard ceiling")

        // The ceiling has to outlast a healthy streaming turn, or it cancels replies the user was
        // about to see. `READ_TIMEOUT` is the tolerated gap between *individual* chunks, and one
        // turn can contain several.
        XCTAssertGreaterThan(ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT,
                             ConciergeConstants.Request.READ_TIMEOUT,
                             "the ceiling must outlast the per-chunk inactivity timeout")

        // The budget is a fixed cap now, so a configured auth-token window cannot move it.
        ConciergeAuthTokenResolver.shared.setProvider(nil)
        let withoutProvider = ConciergeConstants.Request.dataHandoffResponseTimeout

        ConciergeAuthTokenResolver.shared.setProvider({ "token" }, timeout: 30)
        defer { ConciergeAuthTokenResolver.shared.setProvider(nil) }

        XCTAssertEqual(ConciergeConstants.Request.dataHandoffResponseTimeout, withoutProvider, accuracy: 0.001,
                       "the response budget must not depend on the auth-token configuration")
    }

    func test_handoffThatNeverResponds_reportsTimeoutAndUnwindsTheTurn() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 5.0, handoffFirstChunkTimeout: 0.2)

        var completions: [ConciergeError?] = []
        let started = controller.handleDataHandoff(routingHint: "silent-turn", xdmFields: [:]) { error in
            completions.append(error)
        }
        XCTAssertTrue(started)

        spinUntil(timeout: 2.0, !completions.isEmpty)

        XCTAssertEqual(completions.count, 1, "the caller must hear back exactly once")
        guard case .timeout = completions.first ?? nil else {
            return XCTFail("a silent turn must report .timeout, got \(String(describing: completions.first ?? nil))")
        }
        XCTAssertEqual(fakeService.cancelActiveStreamCallCount, 1,
                       "a turn that produced nothing must be cancelled, not left running")

        // Cancelling drives the delegate's failure path, which tries to complete a second time.
        spinUntil(timeout: 1.0, controller.chatState == .idle)
        XCTAssertEqual(completions.count, 1, "the cancellation must not deliver a second completion")
        XCTAssertEqual(controller.chatState, .idle, "a timed-out turn must leave the chat usable")
    }

    func test_slowButStreamingHandoff_survivesTheFirstChunkCap() {
        // The point of the two-stage design: a backend that is slow but alive must not have its
        // reply thrown away. Only a turn that produces *nothing* fails fast.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 5.0, handoffFirstChunkTimeout: 0.3)

        var completions: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "slow-turn", xdmFields: [:]) { error in
            completions.append(error)
        }

        spinUntil(timeout: 1.0, fakeService.streamChatCallCount == 1)
        fakeService.emitChunk(makePayload(state: "in-progress", message: "thinking"))

        // Outlive the first-chunk cap: the turn is alive, so nothing should fire.
        spinUntil(timeout: 0.8, false)
        XCTAssertTrue(completions.isEmpty, "a streaming turn must not be cut off by the fast cap")
        XCTAssertEqual(fakeService.cancelActiveStreamCallCount, 0,
                       "a streaming turn must never be cancelled by the fast cap")

        fakeService.triggerCompletion()
        spinUntil(!completions.isEmpty)
        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(completions.first ?? nil, "the slow turn ultimately succeeded")
    }

    func test_failedHandoff_leavesNothingInTheTranscript() {
        // A handoff is initiated by app code, not the user, so a failure must not put an error
        // bubble in front of someone who never asked for the turn. The app hears about it through
        // the completion instead. Inverse of a user-typed turn, which does render its failure.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)
        controller.networkErrorMessage = "Themed connection error"

        var completions: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "checkout", xdmFields: [:]) { completions.append($0) }

        spinUntil(controller.chatState == .idle)

        XCTAssertTrue(controller.messages.isEmpty,
                      "a failed handoff must leave no trace, not even the streaming placeholder")
        XCTAssertEqual(completions.count, 1, "the app must still be told the handoff failed")
        XCTAssertNotNil(completions.first ?? nil)
    }

    func test_failedHandoff_keepsAnAlreadyRenderedLocalMessage() {
        // The local message is the one part the user has already seen, so removing it on failure
        // would make content vanish from under them.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        _ = controller.handleDataHandoff(routingHint: "checkout", xdmFields: [:],
                                         localMessage: "Your order is confirmed!")

        spinUntil(controller.chatState == .idle)

        XCTAssertEqual(controller.messages.count, 1, "only the local message should remain")
        XCTAssertEqual(controller.messages.first?.messageBody, "Your order is confirmed!")
    }

    func test_handoffWithNoCompletion_isStillCapped() {
        // Regression: the caps were keyed off `handoffCompletion`, so a caller that passed no
        // completion armed them and then had every fire no-op - parking the chat in `.processing`
        // with no way back and no error.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 5.0, handoffFirstChunkTimeout: 0.2)

        let started = controller.handleDataHandoff(routingHint: "no-callback", xdmFields: [:])
        XCTAssertTrue(started)

        spinUntil(timeout: 2.0, fakeService.cancelActiveStreamCallCount == 1)
        XCTAssertEqual(fakeService.cancelActiveStreamCallCount, 1,
                       "the cap must fire even when the caller wants no callback")

        spinUntil(timeout: 1.0, controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle, "the chat must not be left stuck in .processing")
    }

    func test_handoffCappedBeforeTheTurnReachesTheService_stillUnwindsTheChat() {
        // Regression: the turn ceiling is armed before `streamAgentResponse` has finished awaiting
        // the auth token, so it can fire while the service still has no `dataTask`. The unwind
        // used to depend on `cancelActiveStream()` producing a delegate failure - but cancelling
        // nothing reports nothing, so the chat stayed in `.processing` with a dead composer.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false

        // A provider slower than the turn ceiling, so the ceiling fires mid-resolution. Apps can
        // configure this: `setProvider(_:timeout:)` accepts anything up to `maxTimeout` (600s).
        // The ceiling is the cap that runs during the token wait; the fast no-response cap only
        // starts once a request is actually in flight.
        ConciergeAuthTokenResolver.shared.setProvider({
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return "late-token"
        }, timeout: 30)
        defer { ConciergeAuthTokenResolver.shared.setProvider(nil) }

        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 0.2, handoffFirstChunkTimeout: 5.0)

        var completions: [ConciergeError?] = []
        let started = controller.handleDataHandoff(routingHint: "slow-token", xdmFields: [:]) { error in
            completions.append(error)
        }
        XCTAssertTrue(started)

        spinUntil(timeout: 2.0, !completions.isEmpty)
        XCTAssertEqual(completions.count, 1, "the caller must hear back exactly once")
        guard case .timeout = completions.first ?? nil else {
            return XCTFail("a turn capped before it started must report .timeout, got \(String(describing: completions.first ?? nil))")
        }
        XCTAssertEqual(fakeService.streamChatCallCount, 0,
                       "the cap must have fired before the turn reached the service")

        spinUntil(timeout: 2.0, controller.chatState == .idle)
        XCTAssertEqual(controller.chatState, .idle,
                       "a turn capped before it started must still leave the chat usable")
    }

    func test_handoffCappedBeforeTheTurnStarts_doesNotLaterReviveTheTurn() {
        // The second half of the same defect: once the token finally resolved, the abandoned turn
        // went on to hit the network and render a reply into the transcript - for a handoff the app
        // had already been told had timed out.
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false

        ConciergeAuthTokenResolver.shared.setProvider({
            try? await Task.sleep(nanoseconds: 500_000_000)
            return "late-token"
        }, timeout: 30)
        defer { ConciergeAuthTokenResolver.shared.setProvider(nil) }

        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 0.2, handoffFirstChunkTimeout: 5.0)

        var completions: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "slow-token", xdmFields: [:], localMessage: "Your order is confirmed!") { error in
            completions.append(error)
        }

        spinUntil(timeout: 2.0, !completions.isEmpty)
        spinUntil(timeout: 2.0, controller.chatState == .idle)

        // Outlive the token resolution: the superseded turn must stay abandoned.
        spinUntil(timeout: 1.5, false)

        XCTAssertEqual(fakeService.streamChatCallCount, 0,
                       "an abandoned turn must not reach the service once its token resolves")
        XCTAssertEqual(completions.count, 1, "the abandoned turn must not deliver a second completion")
        XCTAssertEqual(controller.chatState, .idle, "the revived turn must not put the chat back into .processing")
        XCTAssertEqual(controller.messages.count, 1, "only the local message should remain")
        XCTAssertEqual(controller.messages.first?.messageBody, "Your order is confirmed!")
    }

    func test_handoffThatCompletesInTime_disarmsBothCaps() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService,
                                        handoffTurnTimeout: 0.3, handoffFirstChunkTimeout: 0.2)

        var completions: [ConciergeError?] = []
        _ = controller.handleDataHandoff(routingHint: "prompt-turn", xdmFields: [:]) { error in
            completions.append(error)
        }

        spinUntil(!completions.isEmpty)
        XCTAssertEqual(completions.count, 1)

        // Outlive both caps: a disarmed timer must not fire a second, spurious completion.
        spinUntil(timeout: 0.8, false)
        XCTAssertEqual(completions.count, 1, "the caps must be disarmed once the turn completes")
        XCTAssertEqual(fakeService.cancelActiveStreamCallCount, 0,
                       "a turn that finished on time must not be cancelled")
    }

    func test_streaming_success_sets_idle_marks_shouldSpeak_and_attaches_sources() {
        let sources = [
            Source(url: "https://example.com/1", title: "One", startIndex: 0, endIndex: 1, citationNumber: 1),
            Source(url: "https://example.com/2", title: "Two", startIndex: 0, endIndex: 1, citationNumber: 2)
        ]
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hi"),
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: " there")
        ]
        fakeService.plannedError = nil
        // Also include a chunk that carries sources
        fakeService.plannedChunks.append(makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "!", sources: sources))

        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("x")
        controller.sendMessage(isUser: true)

        // Wait for chunks applied
        spinUntil(controller.messages.count == 2)

        // Completion happens immediately after chunks in fake
        spinUntil(controller.chatState == .idle)

        XCTAssertEqual(controller.messages.count, 2)
        let agent = controller.messages[1]
        XCTAssertEqual(agent.messageBody, "Hi there!")
        XCTAssertTrue(agent.shouldSpeakMessage)
        let urls = agent.sources?.map { $0.url } ?? []
        XCTAssertEqual(urls.sorted(), ["https://example.com/1", "https://example.com/2"].sorted())
    }

    func test_toggleMic_flows_and_endCapture_transcript_updates_input() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = true
        capturer.transcriptToReturn = "return"
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)

        // Seed initial text and place cursor at end (4)
        controller.applyTextChange("set ")
        controller.toggleMic(currentSelectionLocation: 4)
        XCTAssertTrue(controller.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 1)

        // Toggle again to complete and deliver transcript
        controller.toggleMic(currentSelectionLocation: 4)

        // Wait for transcription completion to apply to controller input state machine
        spinUntil(controller.inputController.state == .editing && controller.inputController.data.text.contains("return"))

        XCTAssertEqual(capturer.endCaptures, 1)
        XCTAssertEqual(controller.inputController.data.text, "set return")
    }
    
    func test_startRecording_whenPermissionsNotGranted_showsPermissionDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false // Already asked before
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertFalse(controller.showPermissionDialog)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertTrue(controller.showPermissionDialog)
        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 0)
        XCTAssertEqual(capturer.permissionRequests, 0) // Should not request again
    }
    
    func test_dismissPermissionDialog_hidesDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.showPermissionDialog)
        
        controller.dismissPermissionDialog()
        
        XCTAssertFalse(controller.showPermissionDialog)
    }
    
    func test_requestOpenSettings_hidesDialog() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        XCTAssertTrue(controller.showPermissionDialog)
        
        controller.requestOpenSettings()
        
        XCTAssertFalse(controller.showPermissionDialog)
        // Note: The actual URL opening is handled by the view layer using SwiftUI's openURL
    }
    
    func test_startRecording_requestsPermissionsWhenNeverAsked() async {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = true // First time asking
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertEqual(capturer.permissionRequests, 0)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertEqual(capturer.permissionRequests, 1)
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertFalse(controller.isRecording) // Should not start recording because permissions still not available
        XCTAssertTrue(controller.showPermissionDialog) // Should show dialog after user denies
    }
    
    func test_startRecording_requestsPermissionsAndStartsRecordingWhenGranted() async {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.neverAsked = true // First time asking
        capturer.available = false // Not available initially
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        XCTAssertEqual(capturer.permissionRequests, 0)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertEqual(capturer.permissionRequests, 1)
        
        // Simulate user granting permissions
        capturer.available = true
        
        // Wait for async completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertTrue(controller.isRecording) // Should start recording after permissions granted
        XCTAssertFalse(controller.showPermissionDialog) // Should not show dialog
        XCTAssertEqual(capturer.beginCaptures, 1)
    }
    
    func test_startRecording_showsDialogWhenPreviouslyDenied() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let capturer = MockSpeechCapturer()
        capturer.available = false
        capturer.neverAsked = false // Already asked before
        capturer.denied = false // Not explicitly denied (could be restricted or just not granted)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)
        
        controller.toggleMic(currentSelectionLocation: 0)
        
        XCTAssertTrue(controller.showPermissionDialog) // Should show dialog if already asked but not available
        XCTAssertEqual(capturer.permissionRequests, 0) // Should not request again
        XCTAssertFalse(controller.isRecording)
    }
    
    // MARK: - Product Card Rendering Tests

    func test_streaming_singleProduct_appendsProductCardMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element = MultimodalElement(
            id: "prod-1",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Widget Pro",
                productDescription: "A versatile tool",
                description: nil,
                productPageURL: "https://example.com/products/widget-pro",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/widget-pro.png",
                backgroundColor: nil,
                logo: nil,
                primary: ActionButton(text: "Buy", url: "https://example.com/buy"),
                secondary: nil,
                productPrice: "$9.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here's a product:"),
            makePayloadWithProducts(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [element],
                message: "Here's a product:"
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me a product")
        controller.sendMessage(isUser: true)

        // Then — wait for streaming to complete
        spinUntil(controller.chatState == .idle)

        // Messages: [user, agent text, product card]
        XCTAssertGreaterThanOrEqual(controller.messages.count, 3)

        let productMessage = controller.messages.last { message in
            if case .productCard = message.template { return true }
            return false
        }
        XCTAssertNotNil(productMessage, "Expected a .productCard message in the message list")
    }

    func test_streaming_multipleProducts_appendsCarouselGroupMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element1 = MultimodalElement(
            id: "prod-1",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Widget Pro",
                productDescription: nil,
                description: nil,
                productPageURL: "https://example.com/products/widget-pro",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/widget-pro.png",
                backgroundColor: nil,
                logo: nil,
                primary: nil,
                secondary: nil,
                productPrice: "$22.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )
        let element2 = MultimodalElement(
            id: "prod-2",
            type: "product",
            thumbnailWidth: 150,
            thumbnailHeight: 150,
            entityInfo: EntityInfo(
                productName: "Gadget Basic",
                productDescription: nil,
                description: nil,
                productPageURL: "https://example.com/products/gadget-basic",
                details: nil,
                learningResource: nil,
                productImageURL: "https://example.com/images/gadget-basic.png",
                backgroundColor: nil,
                logo: nil,
                primary: nil,
                secondary: nil,
                productPrice: "$22.99",
                productWasPrice: nil,
                productBadge: nil
            )
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here are some products:"),
            makePayloadWithProducts(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [element1, element2],
                message: "Here are some products:"
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me products")
        controller.sendMessage(isUser: true)

        // Then — wait for streaming to complete
        spinUntil(controller.chatState == .idle)

        // Expect a carouselGroup message containing the product carousel cards
        let carouselMessage = controller.messages.last { message in
            if case .carouselGroup = message.template { return true }
            return false
        }
        XCTAssertNotNil(carouselMessage, "Expected a .carouselGroup message in the message list")

        if case .carouselGroup(let items) = carouselMessage?.template {
            XCTAssertEqual(items.count, 2)
            if case .productCarouselCard(let cardData) = items[0].template {
                XCTAssertEqual(cardData.title, "Widget Pro")
            } else {
                XCTFail("Expected first carousel item to be .productCarouselCard")
            }
            if case .productCarouselCard(let cardData) = items[1].template {
                XCTAssertEqual(cardData.title, "Gadget Basic")
            } else {
                XCTFail("Expected second carousel item to be .productCarouselCard")
            }
        } else {
            XCTFail("Expected .carouselGroup template")
        }
    }

    // MARK: - CTA Button Rendering Tests

    func test_streaming_singleCtaButton_appendsCtaButtonMessage() {
        // Given
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let ctaElement = MultimodalElement(
            id: "cta-live-chat",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Chat now", url: "https://example.com/live-chat")
        )

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Let me connect you."),
            makePayloadWithElements(state: ConciergeConstants.StreamState.COMPLETED, elements: [ctaElement], message: "Let me connect you.")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("help")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        let ctaMessage = controller.messages.first { message in
            if case .ctaButton = message.template { return true }
            return false
        }
        XCTAssertNotNil(ctaMessage, "Expected a .ctaButton message in the message list")

        if case .ctaButton(let action) = ctaMessage?.template {
            XCTAssertEqual(action.text, "Chat now")
            XCTAssertEqual(action.url, "https://example.com/live-chat")
        }
    }

    func test_streaming_ctaWithMissingPrimary_isSkipped() {
        // Given — CTA element with no primary action should be silently skipped
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let ctaWithNoPrimary = MultimodalElement(id: "cta-broken", type: "ctaButton", entityInfo: nil)

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here you go."),
            makePayloadWithElements(state: ConciergeConstants.StreamState.COMPLETED, elements: [ctaWithNoPrimary], message: "Here you go.")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("test")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        let ctaMessage = controller.messages.first { message in
            if case .ctaButton = message.template { return true }
            return false
        }
        XCTAssertNil(ctaMessage, "CTA with missing primary should not produce a message")
    }

    // MARK: - Interleaved Element Ordering Tests

    func test_streaming_interleavedCtaAndCards_respectsRelativeOrder() {
        // Given — [CTA, card, card, CTA, card] should produce [ctaButton, carousel(3), ctaButton]
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)

        let cta1 = MultimodalElement(
            id: "cta-1",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Chat with an agent", url: "https://example.com/chat")
        )
        let card1 = makeProductElement(id: "prod-1", name: "Product A", price: "$99.99")
        let card2 = makeProductElement(id: "prod-2", name: "Product B", price: "$129.99")
        let cta2 = MultimodalElement(
            id: "cta-2",
            type: "ctaButton",
            entityInfo: makeCtaEntityInfo(text: "Find a store", url: "https://example.com/stores")
        )
        let card3 = makeProductElement(id: "prod-3", name: "Product C", price: "$149.99")

        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Here are some options."),
            makePayloadWithElements(
                state: ConciergeConstants.StreamState.COMPLETED,
                elements: [cta1, card1, card2, cta2, card3],
                message: "Here are some options."
            )
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        // When
        controller.applyTextChange("show me products")
        controller.sendMessage(isUser: true)

        // Then
        spinUntil(controller.chatState == .idle)

        // Messages: [user, agent text, cta1, carousel, cta2]
        XCTAssertEqual(controller.messages.count, 5, "Expected 5 messages: user, agent text, CTA, carousel, CTA")

        // messages[0] = user message
        // messages[1] = agent text
        // messages[2] = first CTA
        if case .ctaButton(let action) = controller.messages[2].template {
            XCTAssertEqual(action.text, "Chat with an agent")
        } else {
            XCTFail("Expected messages[2] to be .ctaButton, got \(controller.messages[2].template)")
        }

        // messages[3] = carousel with 3 cards
        if case .carouselGroup(let items) = controller.messages[3].template {
            XCTAssertEqual(items.count, 3)
            if case .productCarouselCard(let cardData) = items[0].template {
                XCTAssertEqual(cardData.title, "Product A")
            } else {
                XCTFail("Expected first carousel item to be .productCarouselCard")
            }
            if case .productCarouselCard(let cardData) = items[2].template {
                XCTAssertEqual(cardData.title, "Product C")
            } else {
                XCTFail("Expected third carousel item to be .productCarouselCard")
            }
        } else {
            XCTFail("Expected messages[3] to be .carouselGroup, got \(controller.messages[3].template)")
        }

        // messages[4] = second CTA
        if case .ctaButton(let action) = controller.messages[4].template {
            XCTAssertEqual(action.text, "Find a store")
        } else {
            XCTFail("Expected messages[4] to be .ctaButton, got \(controller.messages[4].template)")
        }
    }

    // MARK: - Tracking Event Dispatch Tests

    func test_sendMessage_dispatches_querySubmitted_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("What tools do you offer?")
        controller.sendMessage(isUser: true)

        let queryEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED }
        XCTAssertEqual(queryEvents.count, 1)
        XCTAssertEqual(queryEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.QUERY] as? String, "What tools do you offer?")
    }

    func test_streaming_dispatches_responseStarted_and_responseCompleted_events() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Hello", conversationId: "conv-1", interactionId: "int-1"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Hello world", conversationId: "conv-1", interactionId: "int-1")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let startedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED }
        let completedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_COMPLETED }
        XCTAssertEqual(startedEvents.count, 1, "Expected exactly one response:started event")
        XCTAssertEqual(completedEvents.count, 1, "Expected exactly one response:completed event")
        XCTAssertEqual(startedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.CONVERSATION_ID] as? String, "conv-1")
    }

    func test_streaming_dispatches_responseStarted_only_once_for_multiple_chunks() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Chunk 1"),
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: " Chunk 2"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Chunk 1 Chunk 2")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("test")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let startedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED }
        XCTAssertEqual(startedEvents.count, 1, "response:started should fire only once per response")
    }

    func test_streaming_error_dispatches_errorOccurred_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let errorEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.ERROR_OCCURRED }
        XCTAssertEqual(errorEvents.count, 1)
        XCTAssertNotNil(errorEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.ERROR_MESSAGE] as? String)
    }

    func test_streaming_products_dispatches_cardsRendered_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element1 = makeProductElement(id: "prod-1", name: "Widget Pro", price: "$9.99")
        let element2 = makeProductElement(id: "prod-2", name: "Gadget Basic", price: "$19.99")
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Products:"),
            makePayloadWithProducts(state: ConciergeConstants.StreamState.COMPLETED, elements: [element1, element2], message: "Products:")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("show products")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let renderedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CARDS_RENDERED }
        XCTAssertEqual(renderedEvents.count, 1)
        XCTAssertEqual(renderedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.DISPLAY_MODE] as? String, "carousel")
        let elements = renderedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.ELEMENTS] as? [[String: Any]]
        XCTAssertEqual(elements?.count, 2)
    }

    func test_streaming_cards_only_dispatches_paired_responseStarted_and_responseCompleted() {
        // Mirrors the Android `cards-only response still fires paired responseStarted and
        // responseCompleted` test. Server returns no text — only multimodal cards — across
        // every chunk. The responseStarted/responseCompleted pair must remain intact.
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element = makeProductElement(id: "prod-1", name: "Widget Pro", price: "$9.99")
        fakeService.plannedChunks = [
            makePayloadWithProducts(state: ConciergeConstants.StreamState.COMPLETED, elements: [element], message: nil)
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.applyTextChange("show cards")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let startedCount = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED }.count
        let completedCount = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_COMPLETED }.count
        XCTAssertEqual(startedCount, 1, "responseStarted should fire even when message is empty but cards are present")
        XCTAssertEqual(completedCount, 1, "responseCompleted should remain paired with responseStarted")
    }

    /// A cards-only response has nothing to put in the streaming text bubble, so that placeholder
    /// must be dropped rather than left behind as an empty agent message above the carousel.
    func test_streaming_cards_only_leavesNoEmptyTextBubble() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let element = makeProductElement(id: "prod-1", name: "Widget Pro", price: "$9.99")
        fakeService.plannedChunks = [
            makePayloadWithProducts(state: ConciergeConstants.StreamState.COMPLETED, elements: [element], message: nil)
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("show cards")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        let emptyAgentBubbles = controller.messages.filter { message in
            guard case .basic(let isUserMessage) = message.template, !isUserMessage else { return false }
            return (message.messageBody ?? "").isEmpty
        }
        XCTAssertTrue(emptyAgentBubbles.isEmpty,
                      "Expected no empty agent bubble for a cards-only response, found \(emptyAgentBubbles.count)")

        let hasCard = controller.messages.contains { message in
            if case .productCard = message.template { return true }
            if case .carouselGroup = message.template { return true }
            return false
        }
        XCTAssertTrue(hasCard, "The cards themselves must still be rendered")
    }

    func test_trackPromptSuggestionClicked_dispatches_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackPromptSuggestionClicked(suggestion: "Tell me about Photoshop")

        let suggestionEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.PROMPT_SUGGESTION_CLICKED }
        XCTAssertEqual(suggestionEvents.count, 1)
        XCTAssertEqual(suggestionEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.SUGGESTION] as? String, "Tell me about Photoshop")
    }

    func test_trackCardClicked_dispatches_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        let cardData = ProductCardData(
            imageSource: .remote(nil),
            title: "Widget Pro",
            subtitle: "A versatile tool",
            price: "$9.99",
            badge: "Popular",
            destinationURL: URL(string: "https://example.com/widget"),
            primaryButton: nil,
            secondaryButton: nil,
            imageWidth: nil,
            imageHeight: nil
        )
        controller.trackCardClicked(cardData: cardData)

        let cardEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CARD_CLICKED }
        XCTAssertEqual(cardEvents.count, 1)
        let element = cardEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.ELEMENT] as? [String: Any]
        XCTAssertEqual(element?["productName"] as? String, "Widget Pro")
        XCTAssertEqual(element?["productPageURL"] as? String, "https://example.com/widget")
        XCTAssertEqual(element?["productPrice"] as? String, "$9.99")
    }

    func test_successive_conversations_dispatch_independent_tracking_events() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "First", conversationId: "conv-1", interactionId: "int-1"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "First response", conversationId: "conv-1", interactionId: "int-1")
        ]
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        // First conversation turn
        controller.applyTextChange("first question")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        // Set up second turn
        fakeService.plannedChunks = [
            makePayload(state: ConciergeConstants.StreamState.IN_PROGRESS, message: "Second", conversationId: "conv-1", interactionId: "int-2"),
            makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Second response", conversationId: "conv-1", interactionId: "int-2")
        ]
        fakeService.plannedError = nil

        // Second conversation turn
        controller.applyTextChange("second question")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)

        // Each turn should produce its own query:submitted, response:started, response:completed
        let queryEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED }
        let startedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED }
        let completedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.RESPONSE_COMPLETED }

        XCTAssertEqual(queryEvents.count, 2, "Each turn should dispatch query:submitted")
        XCTAssertEqual(startedEvents.count, 2, "Each turn should dispatch response:started")
        XCTAssertEqual(completedEvents.count, 2, "Each turn should dispatch response:completed")

        XCTAssertEqual(queryEvents[0].data?[ConciergeConstants.TrackingEvent.EventData.Key.QUERY] as? String, "first question")
        XCTAssertEqual(queryEvents[1].data?[ConciergeConstants.TrackingEvent.EventData.Key.QUERY] as? String, "second question")
        XCTAssertEqual(startedEvents[1].data?[ConciergeConstants.TrackingEvent.EventData.Key.INTERACTION_ID] as? String, "int-2")
    }

    func test_no_dispatch_closure_does_not_crash() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService)

        controller.applyTextChange("hi")
        controller.sendMessage(isUser: true)
        spinUntil(controller.chatState == .idle)
    }

    func test_trackChatOpened_dispatches_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackChatOpened()

        let openedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CHAT_OPENED }
        XCTAssertEqual(openedEvents.count, 1)
        let epochTime = openedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.EPOCH_TIME] as? Int64
        XCTAssertNotNil(epochTime)
        XCTAssertGreaterThan(epochTime ?? 0, 0)
    }

    func test_trackChatClosed_dispatches_event_with_duration() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackChatOpened()
        controller.trackChatClosed()

        let closedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CHAT_CLOSED }
        XCTAssertEqual(closedEvents.count, 1)
        let epochTime = closedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.EPOCH_TIME] as? Int64
        let durationMillis = closedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.DURATION_MILLIS] as? Int64
        XCTAssertNotNil(epochTime)
        XCTAssertGreaterThan(epochTime ?? 0, 0)
        XCTAssertGreaterThanOrEqual(durationMillis ?? -1, 0)
    }

    func test_trackChatOpened_called_twice_dispatches_twice() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackChatOpened()
        controller.trackChatOpened()

        let openedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CHAT_OPENED }
        XCTAssertEqual(openedEvents.count, 2, "Each trackChatOpened call dispatches an event and resets the open timer")
    }

    func test_trackChatClosed_without_prior_open_dispatches_zero_duration() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackChatClosed()

        let closedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CHAT_CLOSED }
        XCTAssertEqual(closedEvents.count, 1)
        XCTAssertEqual(closedEvents.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.DURATION_MILLIS] as? Int64, 0)
    }

    func test_trackChatOpened_after_close_starts_new_session() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackChatOpened()
        controller.trackChatClosed()
        controller.trackChatOpened()

        let openedEvents = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.CHAT_OPENED }
        XCTAssertEqual(openedEvents.count, 2, "A new open after a close should dispatch a second chatOpened event")
    }

    func test_trackWelcomePromptSuggestionClicked_dispatches_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackWelcomePromptSuggestionClicked(suggestion: "I want to edit photos")

        let events = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.WELCOME_PROMPT_SUGGESTION_CLICKED }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.SUGGESTION] as? String, "I want to edit photos")
    }

    func test_trackDisclaimerLinkClicked_dispatches_event() {
        var dispatchedEvents: [Event] = []
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let controller = makeController(configuration: mockConciergeConfiguration, service: fakeService) { event in
            dispatchedEvents.append(event)
        }

        controller.trackDisclaimerLinkClicked(url: URL(string: "https://example.com/terms")!)

        let events = dispatchedEvents.filter { $0.name == ConciergeConstants.TrackingEvent.Name.DISCLAIMER_LINK_CLICKED }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data?[ConciergeConstants.TrackingEvent.EventData.Key.URL] as? String, "https://example.com/terms")
    }

    // Feedback identityMap Forwarding Tests

    /// Appends a completed message with a payload so `sendFeedbackFor` can act on it; returns its id.
    private func appendFeedbackEligibleMessage(to controller: ChatController, conversationId: String = "conv-1", interactionId: String = "int-1") -> UUID {
        let message = Message(
            template: .basic(isUserMessage: false),
            messageBody: "Hello",
            feedbackEligible: true,
            payload: makePayload(state: ConciergeConstants.StreamState.COMPLETED, message: "Hello", conversationId: conversationId, interactionId: interactionId)
        )
        controller.messages.append(message)
        return message.id
    }

    func test_sendFeedbackFor_withFullIdentityMap_forwardsAllNamespacesVerbatim() {
        let identityMap: [String: Any] = [
            "ECID": [["id": "ecid-1", "authenticatedState": "ambiguous", "primary": false]],
            "hashedEmail": [["id": "hashed-email-1", "authenticatedState": "authenticated", "primary": true]],
            "CRMID": [["id": "crm-1"]]
        ]
        let configuration = ConciergeConfiguration(ecid: "ecid-1", identityMap: identityMap, surfaces: ["web://test"])
        let fakeService = MockChatService(configuration: configuration)
        let controller = makeController(configuration: configuration, service: fakeService)
        let messageId = appendFeedbackEligibleMessage(to: controller)

        controller.sendFeedbackFor(messageId: messageId, with: FeedbackPayload(sentiment: .positive, selectedOptions: [], notes: ""))
        spinUntil(fakeService.sendFeedbackCallCount == 1)

        let xdm = fakeService.lastFeedbackData?[ConciergeConstants.Request.Keys.XDM] as? [String: Any]
        let forwardedIdentityMap = xdm?[ConciergeConstants.Request.Keys.IDENTITY_MAP] as? [String: Any]
        XCTAssertNotNil(forwardedIdentityMap)

        let ecidEntries = forwardedIdentityMap?["ECID"] as? [[String: Any]]
        XCTAssertEqual(ecidEntries?.first?["id"] as? String, "ecid-1")
        XCTAssertEqual(ecidEntries?.first?["authenticatedState"] as? String, "ambiguous")
        XCTAssertEqual(ecidEntries?.first?["primary"] as? Bool, false)

        let hashedEmailEntries = forwardedIdentityMap?["hashedEmail"] as? [[String: Any]]
        XCTAssertEqual(hashedEmailEntries?.first?["id"] as? String, "hashed-email-1")
        XCTAssertEqual(hashedEmailEntries?.first?["authenticatedState"] as? String, "authenticated")
        XCTAssertEqual(hashedEmailEntries?.first?["primary"] as? Bool, true)

        let crmEntries = forwardedIdentityMap?["CRMID"] as? [[String: Any]]
        XCTAssertEqual(crmEntries?.first?["id"] as? String, "crm-1")
    }

    func test_sendFeedbackFor_withEcidOnlyIdentityMap_stillForwardsEcid() {
        // Regression: ECID-only identityMap (as before this change) still reaches the endpoint
        let identityMap: [String: Any] = ["ECID": [["id": "ecid-1"]]]
        let configuration = ConciergeConfiguration(ecid: "ecid-1", identityMap: identityMap, surfaces: ["web://test"])
        let fakeService = MockChatService(configuration: configuration)
        let controller = makeController(configuration: configuration, service: fakeService)
        let messageId = appendFeedbackEligibleMessage(to: controller)

        controller.sendFeedbackFor(messageId: messageId, with: FeedbackPayload(sentiment: .negative, selectedOptions: [], notes: ""))
        spinUntil(fakeService.sendFeedbackCallCount == 1)

        let xdm = fakeService.lastFeedbackData?[ConciergeConstants.Request.Keys.XDM] as? [String: Any]
        let forwardedIdentityMap = xdm?[ConciergeConstants.Request.Keys.IDENTITY_MAP] as? [String: Any]
        let ecidEntries = forwardedIdentityMap?["ECID"] as? [[String: Any]]
        XCTAssertEqual(ecidEntries?.first?["id"] as? String, "ecid-1")
    }

    func test_sendFeedbackFor_withNilIdentityMap_fallsBackToEcidOnlyMap() {
        // Given
        let configuration = ConciergeConfiguration(ecid: "ecid-1", identityMap: nil, surfaces: ["web://test"])
        let fakeService = MockChatService(configuration: configuration)
        let controller = makeController(configuration: configuration, service: fakeService)
        let messageId = appendFeedbackEligibleMessage(to: controller)

        controller.sendFeedbackFor(messageId: messageId, with: FeedbackPayload(sentiment: .positive, selectedOptions: [], notes: ""))
        spinUntil(fakeService.sendFeedbackCallCount == 1)

        let xdm = fakeService.lastFeedbackData?[ConciergeConstants.Request.Keys.XDM] as? [String: Any]
        let forwardedIdentityMap = xdm?[ConciergeConstants.Request.Keys.IDENTITY_MAP] as? [String: Any]

        // Then
        let ecidEntries = forwardedIdentityMap?["ECID"] as? [[String: Any]]
        XCTAssertEqual(ecidEntries?.first?["id"] as? String, "ecid-1")
    }

    func test_sendFeedbackFor_withUnserializableIdentityMap_fallsBackToEcidOnlyMap() {
        // Given: identityMap contains a value JSONSerialization can't encode (NaN)
        let configuration = ConciergeConfiguration(ecid: "ecid-1", identityMap: ["ECID": Double.nan], surfaces: ["web://test"])
        let fakeService = MockChatService(configuration: configuration)
        let controller = makeController(configuration: configuration, service: fakeService)
        let messageId = appendFeedbackEligibleMessage(to: controller)

        controller.sendFeedbackFor(messageId: messageId, with: FeedbackPayload(sentiment: .positive, selectedOptions: [], notes: ""))
        spinUntil(fakeService.sendFeedbackCallCount == 1)

        let xdm = fakeService.lastFeedbackData?[ConciergeConstants.Request.Keys.XDM] as? [String: Any]
        let forwardedIdentityMap = xdm?[ConciergeConstants.Request.Keys.IDENTITY_MAP] as? [String: Any]

        // Then
        let ecidEntries = forwardedIdentityMap?["ECID"] as? [[String: Any]]
        XCTAssertEqual(ecidEntries?.first?["id"] as? String, "ecid-1")
    }

    // MARK: - Helpers
    private func makeController(configuration: ConciergeConfiguration, service: MockChatService, capturer: MockSpeechCapturer? = nil, dispatch: ((_ event: Event) -> Void)? = nil, handoffTurnTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT, handoffFirstChunkTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_FIRST_CHUNK_TIMEOUT) -> ChatController {
        ChatController(configuration: configuration, chatService: service, speechCapturer: capturer, speaker: NoopSpeaker(), dispatch: dispatch, handoffTurnTimeout: handoffTurnTimeout, handoffFirstChunkTimeout: handoffFirstChunkTimeout)
    }

    private func makePayload(state: String, message: String? = nil, sources: [Source]? = nil, conversationId: String? = nil, interactionId: String? = nil) -> ConversationPayload {
        let response: ConversationResponse? = message != nil || sources != nil
            ? ConversationResponse(message: message ?? "", promptSuggestions: nil, multimodalElements: nil, sources: sources, linkHints: nil, state: nil, feedback: nil)
            : nil

        return ConversationPayload(
            conversationId: conversationId,
            interactionId: interactionId,
            request: nil,
            response: response,
            state: state,
            key: nil,
            value: nil,
            maxAge: nil
        )
    }

    private func makePayloadWithProducts(state: String, elements: [MultimodalElement], message: String? = nil) -> ConversationPayload {
        makePayloadWithElements(state: state, elements: elements, message: message)
    }

    private func makePayloadWithElements(state: String, elements: [MultimodalElement], message: String? = nil) -> ConversationPayload {
        let multimodal = MultimodalElements(elements: elements)
        let response = ConversationResponse(
            message: message ?? "",
            promptSuggestions: nil,
            multimodalElements: multimodal,
            sources: nil,
            linkHints: nil,
            state: nil,
            feedback: nil
        )
        return ConversationPayload(
            conversationId: nil,
            interactionId: nil,
            request: nil,
            response: response,
            state: state,
            key: nil,
            value: nil,
            maxAge: nil
        )
    }

    private func makeCtaEntityInfo(text: String, url: String) -> EntityInfo {
        EntityInfo(
            productName: nil, productDescription: nil, description: nil, productPageURL: nil,
            details: nil, learningResource: nil, productImageURL: nil, backgroundColor: nil,
            logo: nil, primary: ActionButton(text: text, url: url),
            secondary: nil, productPrice: nil, productWasPrice: nil, productBadge: nil
        )
    }

    private func makeProductElement(id: String, name: String, price: String) -> MultimodalElement {
        MultimodalElement(
            id: id,
            entityInfo: EntityInfo(
                productName: name, productDescription: nil, description: nil,
                productPageURL: "https://example.com/p/\(id)", details: nil, learningResource: nil,
                productImageURL: "https://example.com/img/\(id).png",
                backgroundColor: nil, logo: nil, primary: nil,
                secondary: nil, productPrice: price, productWasPrice: nil, productBadge: nil
            )
        )
    }

    private func spinUntil(timeout: TimeInterval = 1.0, _ predicate: @autoclosure () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
