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

import XCTest
@testable import AEPConcierge

// MARK: - Fakes
private final class NoopSpeaker: TextSpeaking { func utter(text: String) {} }

@MainActor
final class ConciergeChatViewModelTests: XCTestCase {
    
    private var mockConciergeConfiguration = ConciergeConfiguration()
    
    func test_sendMessage_ignores_when_text_empty_or_not_idle() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService)

        // Empty text -> ignored
        vm.sendMessage(isUser: true)
        XCTAssertEqual(vm.messages.count, 0)

        // Non-idle -> ignored
        vm.applyTextChange("hi")
        vm.chatState = .processing
        vm.sendMessage(isUser: true)
        XCTAssertEqual(vm.messages.count, 0)
        XCTAssertEqual(vm.chatState, .processing)
    }

    func test_streaming_inProgress_accumulates_and_updates_placeholder() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.shouldCallComplete = false // keep streaming; do not transition to idle
        fakeService.plannedChunks = [
            makePayload(state: Constants.StreamState.IN_PROGRESS, message: "Hello "),
            makePayload(state: Constants.StreamState.IN_PROGRESS, message: "world")
        ]
        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService)

        vm.applyTextChange("q")
        XCTAssertTrue(vm.sendEnabled)
        vm.sendMessage(isUser: true)
        // Wait for streaming chunks to apply and accumulate
        spinUntil(vm.messages.count == 2 && vm.messages[1].messageBody == "Hello world")

        XCTAssertEqual(vm.messages.count, 2)
        let agent = vm.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello world")
        XCTAssertEqual(vm.chatState, .processing)

        // Now finish the stream explicitly and verify state transitions to idle
        fakeService.triggerCompletion()
        spinUntil(vm.chatState == .idle)
        XCTAssertEqual(vm.chatState, .idle)
    }

    func test_streaming_completed_appends_only_delta() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: Constants.StreamState.IN_PROGRESS, message: "Hel"),
            makePayload(state: Constants.StreamState.COMPLETED, message: "Hello")
        ]
        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService)

        vm.applyTextChange("go")
        vm.sendMessage(isUser: true)
        // Wait until final message is applied
        spinUntil(vm.messages.count == 2 && vm.messages[1].messageBody == "Hello")

        XCTAssertEqual(vm.messages.count, 2)
        let agent = vm.messages[1]
        XCTAssertEqual(agent.messageBody, "Hello")
    }

    func test_streaming_error_removes_placeholder_and_sets_error_state() {
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = []
        fakeService.plannedError = .unreachable
        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService)

        vm.applyTextChange("hi")
        vm.sendMessage(isUser: true)

        // Allow onComplete to run
        spinUntil(vm.chatState == .error(.networkFailure))

        XCTAssertEqual(vm.messages.count, 1) // only user message remains
        XCTAssertEqual(vm.chatState, .error(.networkFailure))
    }

    func test_streaming_success_sets_idle_marks_shouldSpeak_and_attaches_sources() {
        let sources = [
            TempSource(url: "https://example.com/1", title: "One", startIndex: 0, endIndex: 1, citationNumber: 1),
            TempSource(url: "https://example.com/2", title: "Two", startIndex: 0, endIndex: 1, citationNumber: 2)
        ]
        let fakeService = MockChatService(configuration: mockConciergeConfiguration)
        fakeService.plannedChunks = [
            makePayload(state: Constants.StreamState.IN_PROGRESS, message: "Hi"),
            makePayload(state: Constants.StreamState.IN_PROGRESS, message: " there")
        ]
        fakeService.plannedError = nil
        // Also include a chunk that carries sources
        fakeService.plannedChunks.append(makePayload(state: Constants.StreamState.IN_PROGRESS, message: "!", sources: sources))

        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService)
        vm.stubAgentSources = false

        vm.applyTextChange("x")
        vm.sendMessage(isUser: true)

        // Wait for chunks applied
        spinUntil(vm.messages.count == 2)

        // Completion happens immediately after chunks in fake
        spinUntil(vm.chatState == .idle)

        XCTAssertEqual(vm.messages.count, 2)
        let agent = vm.messages[1]
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
        let vm = makeVM(configuration: mockConciergeConfiguration, service: fakeService, capturer: capturer)

        // Seed initial text and place cursor at end (4)
        vm.applyTextChange("set ")
        vm.toggleMic(currentSelectionLocation: 4)
        XCTAssertTrue(vm.isRecording)
        XCTAssertEqual(capturer.beginCaptures, 1)

        // Toggle again to complete and deliver transcript
        vm.toggleMic(currentSelectionLocation: 4)

        // Wait for transcription completion to apply to reducer
        spinUntil(vm.inputReducer.state == .editing && vm.inputReducer.data.text.contains("return"))

        XCTAssertEqual(capturer.endCaptures, 1)
        XCTAssertEqual(vm.inputReducer.data.text, "set return")
    }
    
    // MARK: - Helpers
    private func makeVM(configuration: ConciergeConfiguration, service: MockChatService, capturer: MockSpeechCapturer? = nil) -> ConciergeChatViewModel {
        ConciergeChatViewModel(configuration: configuration, chatService: service, speechCapturer: capturer, speaker: NoopSpeaker())
    }

    private func makePayload(state: String, message: String? = nil, sources: [TempSource]? = nil) -> TempPayload {
        let response: TempResponse? = message != nil || sources != nil ? TempResponse(message: message ?? "", promptSuggestions: nil, multimodalElements: nil, sources: sources, state: nil) : nil
        return TempPayload(conversationId: nil, interactionId: nil, request: nil, response: response, state: state, key: nil, value: nil, maxAge: nil)
    }

    private func spinUntil(timeout: TimeInterval = 1.0, _ predicate: @autoclosure () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
