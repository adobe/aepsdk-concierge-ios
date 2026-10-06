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
import AEPCore
import AEPTestUtils
import Combine
@testable import AEPCore
@testable import AEPBrandConcierge

/// Verifies the `Concierge` extension's app-facing data-handoff listener: decodes a
/// `ConciergeDataHandoffEvent` from the request event's data, validates its shape, and
/// responds with the corresponding data-handoff result.
final class ConciergeTests: XCTestCase {
    var mockRuntime: TestableExtensionRuntime!
    var concierge: Concierge!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // These cases all assert the "no active session" branch, so make that precondition
        // explicit rather than depending on no other test having left a session behind.
        Concierge.currentSession = nil
        ConciergeOverlayManager.shared.hideChat()
        ConciergeOverlayManager.shared.replaceChat(nil)
        let boundary = ConciergeIdentityBoundary.shared
        boundary.complete(boundary.synchronized { boundary.generation })
        ConciergeXDMContextStore.shared.clear()
        SessionManager.shared.clearSession()
        mockRuntime = TestableExtensionRuntime()
        concierge = Concierge(runtime: mockRuntime)
        concierge.onRegistered()
        setConfiguration()
        setIdentity("initial-ecid")
    }

    @MainActor
    override func tearDown() async throws {
        concierge.onUnregistered()
        Concierge.currentSession = nil
        ConciergeOverlayManager.shared.hideChat()
        ConciergeOverlayManager.shared.replaceChat(nil)
        if let hosted = Concierge.presentedUIKitController {
            hosted.willMove(toParent: nil)
            hosted.view.removeFromSuperview()
            hosted.removeFromParent()
        }
        Concierge.presentedUIKitController = nil
        let boundary = ConciergeIdentityBoundary.shared
        boundary.complete(boundary.synchronized { boundary.generation })
        ConciergeXDMContextStore.shared.clear()
        SessionManager.shared.clearSession()
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Dispatches a data-handoff request event and returns the extension's response.
    ///
    /// The listener answers some cases synchronously (payload validation) and others only after
    /// hopping to the main actor to consult the active session, so this polls the runtime's
    /// thread-safe dispatch log until the response lands rather than assuming either timing.
    private func dispatchDataHandoff(payload: Any?, timeout: TimeInterval = 2) async -> Event? {
        let event = Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
                          type: ConciergeConstants.EventType.concierge,
                          source: EventSource.requestContent,
                          data: payload.map { [ConciergeConstants.DataHandoffEventData.Key.PAYLOAD: $0] })
        mockRuntime.simulateComingEvents(event)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let response = mockRuntime.dispatchedEvents.first {
                return response
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return mockRuntime.dispatchedEvents.first
    }

    private func errorCode(of response: Event?) -> String? {
        response?.data?[ConciergeConstants.DataHandoffEventData.Key.ERROR_CODE] as? String
    }

    private func accepted(_ response: Event?) -> Bool? {
        response?.data?[ConciergeConstants.DataHandoffEventData.Key.ACCEPTED] as? Bool
    }

    // MARK: - Tests

    private func resetIdentities() {
        mockRuntime.simulateComingEvents(Event(name: "Reset identities", type: EventType.genericIdentity,
                                              source: EventSource.requestReset, data: nil))
    }

    private func completeReset(status: SharedStateStatus = .set) {
        setConfiguration()
        setIdentity("new-ecid", status: status)
        mockRuntime.simulateComingEvents(Event(name: "Reset complete", type: EventType.edgeIdentity,
                                              source: EventSource.resetComplete, data: nil))
    }

    private func setConfiguration(event: Event? = nil, server: String? = "https://example.com", datastream: String? = "config") {
        var value: [String: Any] = [:]
        value[ConciergeConstants.SharedState.Configuration.Concierge.SERVER] = server
        value[ConciergeConstants.SharedState.Configuration.Concierge.DATASTREAM] = datastream
        if let event {
            mockRuntime.simulateSharedState(for: (ConciergeConstants.SharedState.Configuration.NAME, event),
                                            data: (value: value, status: .set))
            return
        }
        mockRuntime.simulateSharedState(for: ConciergeConstants.SharedState.Configuration.NAME, data: (
            value: value, status: .set
        ))
    }

    private func setIdentity(_ ecid: String, event: Event? = nil, status: SharedStateStatus = .set) {
        let value: [String: Any] = ["identityMap": ["ECID": [["id": ecid]]]]
        if let event {
            mockRuntime.simulateXDMSharedState(for: (ConciergeConstants.SharedState.EdgeIdentity.NAME, event),
                                               data: (value: value, status: status))
            return
        }
        mockRuntime.simulateXDMSharedState(for: ConciergeConstants.SharedState.EdgeIdentity.NAME, data: (
            value: value, status: status
        ))
    }

    @MainActor
    private func awaitResetReady() async throws {
        let deadline = Date().addingTimeInterval(5)
        while !ConciergeIdentityBoundary.shared.synchronized({ ConciergeIdentityBoundary.shared.ready }),
              Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
    }

    @MainActor
    func test_resetIdentities_rotatesUnexpiredSession_andClearsHeldContext() async throws {
        let oldSession = SessionManager.shared.getOrCreateSessionId()
        try ConciergeXDMContextStore.shared.update(["oldUser": true])
        resetIdentities()
        XCTAssertNil(SessionManager.shared.currentSessionId)
        XCTAssertFalse(ConciergeXDMContextStore.shared.hasContext)
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        completeReset()
        try await awaitResetReady()
        XCTAssertNotEqual(SessionManager.shared.getOrCreateSessionId(), oldSession)
        XCTAssertNil(Concierge.currentSession, "Hidden chat must stay hidden.")
    }

    @MainActor
    func test_resetIdentities_rebuildsVisibleUIKitHost_withFreshIdentityAndSession() async throws {
        let parent = UIViewController()
        parent.loadViewIfNeeded()
        let oldConfiguration = ConciergeConfiguration(
            ecid: "old-ecid", server: "https://example.com", surfaces: ["mobileapp://test/chat"]
        )
        Concierge.attachConciergeUIKitHost(configuration: oldConfiguration, presentingViewController: parent)
        let oldSession = try XCTUnwrap(Concierge.currentSession)
        oldSession.controller.applyTextChange("old draft")
        oldSession.controller.messages.append(Message(template: .basic(isUserMessage: true), messageBody: "old transcript"))
        resetIdentities()
        completeReset()
        try await awaitResetReady()
        let next = try XCTUnwrap(Concierge.currentSession)
        XCTAssertFalse(next === oldSession)
        XCTAssertNotEqual(next.sessionID, oldSession.sessionID)
        XCTAssertEqual(next.configuration.ecid, "new-ecid")
        XCTAssertTrue(oldSession.controller.messages.isEmpty)
        XCTAssertTrue(oldSession.controller.inputText.isEmpty)
        XCTAssertTrue(Concierge.presentedUIKitController?.parent === parent)
        let hosted = try XCTUnwrap(Concierge.presentedUIKitController)
        hosted.willMove(toParent: nil)
        hosted.view.removeFromSuperview()
        hosted.removeFromParent()
        Concierge.presentedUIKitController = nil
    }

    @MainActor
    func test_resetIdentities_preservesContextPushedAfterBoundary() async throws {
        try ConciergeXDMContextStore.shared.update(["oldUser": true])
        resetIdentities()
        try ConciergeXDMContextStore.shared.update(["newUser": true])
        completeReset()
        try await awaitResetReady()
        let context = ConciergeXDMContextStore.shared.snapshot(for: SessionManager.shared.getOrCreateSessionId())
        XCTAssertEqual(context["newUser"] as? Bool, true)
        XCTAssertNil(context["oldUser"])
    }

    @MainActor
    func test_resetIdentities_blocksHandoffUntilCompletion_withoutQueuing() async throws {
        resetIdentities()
        let response = await dispatchDataHandoff(payload: ConciergeDataHandoffEvent(
            routingHint: "checkout", xdmFields: ["order": "old-user-order"]
        ))
        XCTAssertEqual(errorCode(of: response), "no_active_session")
        XCTAssertEqual(accepted(response), false)
        completeReset()
        try await awaitResetReady()
        XCTAssertEqual(mockRuntime.dispatchedEvents.filter {
            $0.name == ConciergeConstants.EventName.DATA_HANDOFF_RESPONSE
        }.count, 1)
    }

    @MainActor
    func test_resetIdentities_pendingIdentity_waitsForResolvedCompletionState() async throws {
        resetIdentities()
        completeReset(status: .pending)
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        mockRuntime.simulateXDMSharedState(for: ConciergeConstants.SharedState.EdgeIdentity.NAME, data: (
            value: ["identityMap": ["ECID": [["id": "new-ecid"]]]], status: .set
        ))
        mockRuntime.simulateComingEvents(Event(name: "State changed", type: EventType.hub,
                                              source: EventSource.sharedState, data: nil))
        try await awaitResetReady()
    }

    @MainActor
    func test_resetIdentities_endedEvent_hasExactDiagnosticSchema_oncePerConversation() async throws {
        let oldSession = SessionManager.shared.getOrCreateSessionId()
        resetIdentities()
        completeReset()
        try await awaitResetReady()
        let events = mockRuntime.dispatchedEvents.filter { $0.name == "Brand Concierge Conversation Ended" }
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        let data = try XCTUnwrap(event.data)
        XCTAssertEqual(event.type, ConciergeConstants.EventType.concierge)
        XCTAssertEqual(event.source, EventSource.notification)
        XCTAssertEqual(Set(data.keys), Set(["conciergeEventType", "reason", "epochTime", "sessionId", "hadActiveTurn"]))
        XCTAssertEqual(data["conciergeEventType"] as? String, "concierge:conversation:ended")
        XCTAssertEqual(data["reason"] as? String, "identity_reset")
        XCTAssertEqual(data["sessionId"] as? String, oldSession)
        XCTAssertEqual(data["hadActiveTurn"] as? Bool, false)
        XCTAssertNotNil(data["epochTime"] as? Int64)
        resetIdentities()
        completeReset()
        try await awaitResetReady()
        XCTAssertEqual(mockRuntime.dispatchedEvents.filter { $0.name == event.name }.count, 1)
        XCTAssertNil(SessionManager.shared.currentSessionId)
    }

    func test_validPayload_withoutActiveSession_respondsNoActiveSession() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout",
                                                xdmFields: ["commerce": ["order": ["purchaseID": "123"]]])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "no_active_session")
    }

    func test_validPayload_withLocalMessage_withoutActiveSession_respondsNoActiveSession() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout",
                                                xdmFields: ["commerce": ["order": ["purchaseID": "123"]]],
                                                localMessage: "Your order is confirmed!")

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "no_active_session")
    }

    func test_emptyRoutingHint_withValidXdmFields_withoutActiveSession_respondsNoActiveSession() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "",
                                                xdmFields: ["commerce": ["order": ["purchaseID": "123"]]])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "no_active_session")
    }

    func test_missingOrMiscastPayload_respondsRejected() async {
        let response = await dispatchDataHandoff(payload: "not the right type")

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "missing_event_data")
    }

    func test_emptyXdmFields_respondsRejected() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout", xdmFields: [:])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "empty_xdm_fields")
    }

    func test_nonSerializableXdmFields_respondsRejected() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout",
                                                xdmFields: ["commerce": Date()])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "invalid_xdm_field_value")
    }

    func test_reservedTopLevelKey_respondsRejected() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout",
                                                xdmFields: ["identityMap": ["ECID": [["id": "abc"]]]])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(accepted(response), false)
        XCTAssertEqual(errorCode(of: response), "reserved_key_collision")
    }

    // MARK: - Error transport round-trip

    /// The extension writes `error.code` onto the response event and the public API rebuilds the
    /// error from that string. Nothing else pins those two halves together, so a rename on either
    /// side would silently downgrade every typed failure to `.noResponse` for consumers.
    func test_everyErrorCode_roundTripsBackToTheSameCase() {
        let errors: [ConciergeDataHandoffError] = [
            .missingEventData,
            .emptyXdmFields,
            .invalidXdmFieldValue,
            .reservedKeyCollision,
            .noActiveSession,
            .chatInProgress,
            .deliveryFailed("Server was unreachable."),
            .deliveryFailed(nil),
            .emptyResponse,
            .deliveryTimeout,
            .noResponse
        ]

        for error in errors {
            // `wireMessage` is what `createDataHandoffResponseEvent` actually puts on the event.
            let rebuilt = ConciergeDataHandoffError(code: error.code, message: error.wireMessage)
            XCTAssertEqual(rebuilt, error, "Error code '\(error.code)' did not round-trip")
        }
    }

    func test_unknownErrorCode_doesNotProduceAnError() {
        XCTAssertNil(ConciergeDataHandoffError(code: "not_a_real_code"))
    }

    /// A slow turn and a rejected turn call for different app behavior (retry vs. don't), so the
    /// transport error has to survive the hop into the public taxonomy instead of collapsing into
    /// one opaque failure.
    func test_serviceErrors_mapToDistinctPublicCases() {
        XCTAssertEqual(ConciergeDataHandoffError(serviceError: .timeout(15)), .deliveryTimeout)
        XCTAssertEqual(ConciergeDataHandoffError(serviceError: .invalidResponseData), .emptyResponse)
        XCTAssertEqual(ConciergeDataHandoffError(serviceError: .unreachable),
                       .deliveryFailed(ConciergeError.unreachable.localizedDescription))
        XCTAssertEqual(ConciergeDataHandoffError(serviceError: .unknown),
                       .deliveryFailed(ConciergeError.unknown.localizedDescription))
    }

    /// `code` is public so an app can report a failure to analytics without switching over every
    /// case, so these strings are a stable contract and must not drift.
    func test_errorCodes_areStable() {
        let expected: [(ConciergeDataHandoffError, String)] = [
            (.missingEventData, "missing_event_data"),
            (.emptyXdmFields, "empty_xdm_fields"),
            (.invalidXdmFieldValue, "invalid_xdm_field_value"),
            (.reservedKeyCollision, "reserved_key_collision"),
            (.noActiveSession, "no_active_session"),
            (.chatInProgress, "chat_in_progress"),
            (.deliveryFailed(nil), "delivery_failed"),
            (.emptyResponse, "empty_response"),
            (.deliveryTimeout, "delivery_timeout"),
            (.noResponse, "no_response")
        ]

        for (error, code) in expected {
            XCTAssertEqual(error.code, code)
        }
    }

    func test_errorCodesAreUnique() {
        let codes: [String] = [
            ConciergeDataHandoffError.missingEventData.code,
            ConciergeDataHandoffError.emptyXdmFields.code,
            ConciergeDataHandoffError.invalidXdmFieldValue.code,
            ConciergeDataHandoffError.reservedKeyCollision.code,
            ConciergeDataHandoffError.noActiveSession.code,
            ConciergeDataHandoffError.chatInProgress.code,
            ConciergeDataHandoffError.deliveryFailed("boom").code,
            ConciergeDataHandoffError.emptyResponse.code,
            ConciergeDataHandoffError.deliveryTimeout.code,
            ConciergeDataHandoffError.noResponse.code
        ]

        XCTAssertEqual(Set(codes).count, codes.count, "Two data-handoff errors share a transport code")
    }

    // MARK: - handleRequestContentEvent routing

    func test_showUiEvent_routesToShowUiHandler_notDataHandoff() async {
        let event = Event(name: ConciergeConstants.EventName.SHOW_UI,
                          type: ConciergeConstants.EventType.concierge,
                          source: EventSource.requestContent,
                          data: nil)

        mockRuntime.simulateComingEvents(event)
        await flushPendingRequests()
        let response = mockRuntime.dispatchedEvents.first

        XCTAssertEqual(response?.name, ConciergeConstants.EventName.SHOW_UI_RESPONSE)
        XCTAssertNil(response?.data?[ConciergeConstants.DataHandoffEventData.Key.ACCEPTED])
    }

    func test_dataHandoffEvent_respondsWithDataHandoffResponseName_notShowUi() async {
        let payload = ConciergeDataHandoffEvent(routingHint: "successful-checkout",
                                                xdmFields: ["commerce": ["order": ["purchaseID": "123"]]])

        let response = await dispatchDataHandoff(payload: payload)

        XCTAssertEqual(response?.name, ConciergeConstants.EventName.DATA_HANDOFF_RESPONSE)
    }

    // MARK: - readyForEvent

    private func waitingShowRequests(count: Int) -> [Event] {
        (0..<count).map { index in
            Event(name: ConciergeConstants.EventName.SHOW_UI,
                  type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
                  data: [ConciergeConstants.EventData.Key.SURFACES: ["surface-\(index)"]])
        }
    }

    private func flushPendingRequests() async {
        let flushed = expectation(description: "Pending request owner drained scheduled work")
        concierge.flushPendingRequestsForTesting { flushed.fulfill() }
        await fulfillment(of: [flushed], timeout: 5)
    }

    @MainActor
    func test_pendingRequests_concurrentTeardownAndSharedStateDrains_respondExactlyOnce() async throws {
        let old = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["chat"]))
        mockRuntime.mockedSharedStates = [:]
        let requests = (0..<12).map { index in
            Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
                  type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
                  data: [ConciergeConstants.DataHandoffEventData.Key.PAYLOAD: ConciergeDataHandoffEvent(
                    routingHint: "handoff-\(index)", xdmFields: ["value": index])])
        }
        for request in requests { mockRuntime.simulateComingEvents(request) }
        await flushPendingRequests()
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)

        let checking = expectation(description: "Drain paused after reading pending readiness")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        var paused = false // Accessed only by the dedicated request owner.
        concierge.pendingRequestReadinessCheckedForTesting = { _, waiting in
            guard !paused else { return }
            paused = true
            XCTAssertTrue(waiting)
            checking.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
        }
        let changed = Event(name: "State changed", type: EventType.hub, source: EventSource.sharedState, data: nil)
        mockRuntime.simulateComingEvents(changed)
        await fulfillment(of: [checking], timeout: 5)

        let tornDown = expectation(description: "MainActor teardown ran while drain was paused")
        let observer = old.controller.$endedForIdentityReset.filter { $0 }.sink { _ in tornDown.fulfill() }
        defer { observer.cancel() }
        resetIdentities()
        let notified = expectation(description: "Concurrent shared-state drains enqueued")
        let runtime = try XCTUnwrap(mockRuntime)
        DispatchQueue.global().async {
            for _ in 0..<12 { runtime.simulateComingEvents(changed) }
            notified.fulfill()
        }
        await fulfillment(of: [tornDown, notified], timeout: 5)
        XCTAssertTrue(old.controller.endedForIdentityReset)
        completeReset()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        XCTAssertFalse(mockRuntime.dispatchedEvents.contains { $0.name == "Brand Concierge Conversation Ended" },
                       "Local controller teardown alone must not publish ended while deferred handoffs are unsettled.")
        release.signal()
        await flushPendingRequests()
        try await awaitResetReady()

        let events = mockRuntime.dispatchedEvents
        let responses = events.filter { $0.name == ConciergeConstants.EventName.DATA_HANDOFF_RESPONSE }
        XCTAssertEqual(responses.count, requests.count)
        for request in requests {
            XCTAssertEqual(responses.filter { $0.parentID == request.id }.count, 1)
        }
        XCTAssertTrue(responses.allSatisfy { errorCode(of: $0) == "no_active_session" && accepted($0) == false })
        let endedIndex = try XCTUnwrap(events.firstIndex { $0.name == "Brand Concierge Conversation Ended" })
        for (index, event) in events.enumerated() where event.name == ConciergeConstants.EventName.DATA_HANDOFF_RESPONSE {
            XCTAssertLessThan(index, endedIndex, "Every old deferred handoff must settle before Conversation Ended.")
        }
    }

    @MainActor
    func test_pendingRequests_readinessNotificationDuringDrain_isNotLost() async throws {
        mockRuntime.mockedSharedStates = [:]
        let requests = waitingShowRequests(count: 12)
        for request in requests { mockRuntime.simulateComingEvents(request) }
        await flushPendingRequests()
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)

        let checking = expectation(description: "Pending readiness decision paused")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        var paused = false // Accessed only by the dedicated request owner.
        concierge.pendingRequestReadinessCheckedForTesting = { _, waiting in
            guard !paused else { return }
            paused = true
            XCTAssertTrue(waiting)
            checking.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
        }
        let changed = Event(name: "State changed", type: EventType.hub, source: EventSource.sharedState, data: nil)
        mockRuntime.simulateComingEvents(changed)
        await fulfillment(of: [checking], timeout: 5)
        // The paused drain already captured waiting=true. Only this queued notification,
        // not an additional request or polling, can wake the existing requests afterward.
        setConfiguration()
        let notified = expectation(description: "Ready-state notification enqueued during drain")
        let runtime = try XCTUnwrap(mockRuntime)
        DispatchQueue.global().async {
            runtime.simulateComingEvents(changed)
            notified.fulfill()
        }
        await fulfillment(of: [notified], timeout: 5)
        release.signal()
        await flushPendingRequests()

        let responses = mockRuntime.dispatchedEvents.filter { $0.name == ConciergeConstants.EventName.SHOW_UI_RESPONSE }
        XCTAssertEqual(responses.count, requests.count)
        for request in requests {
            XCTAssertEqual(responses.filter { $0.parentID == request.id }.count, 1)
        }
        XCTAssertTrue(responses.allSatisfy { $0.data?[ConciergeConstants.EventData.Key.CONFIG] != nil })
    }

    @MainActor
    func test_resetIdentities_settlesClaimedMainActorPendingHandoff_beforeEndedAndReadiness() async throws {
        let old = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["chat"]))
        let gate = ClaimedHandoffGate()
        defer { Task { await gate.release() } }
        let claimed = expectation(description: "Admitted handoff transferred to paused MainActor task")
        let finished = expectation(description: "Released old MainActor task finishes without new work")
        concierge.handoffTaskGateForTesting = { _ in await gate.pause(claimed) }
        concierge.handoffTaskFinishedForTesting = { _ in finished.fulfill() }
        let request = Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
            type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
            data: [ConciergeConstants.DataHandoffEventData.Key.PAYLOAD: ConciergeDataHandoffEvent(
                routingHint: "old", xdmFields: ["oldHandoff": true], localMessage: "old handoff")])
        mockRuntime.simulateComingEvents(request)
        await fulfillment(of: [claimed], timeout: 5)
        await flushPendingRequests()
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertFalse(old.controller.isProcessing)

        resetIdentities()
        completeReset()
        try await awaitResetReady()
        let events = mockRuntime.dispatchedEvents
        let responses = events.filter { $0.parentID == request.id }
        XCTAssertEqual(responses.count, 1, "Claimed handoff must settle without waiting for its paused MainActor task.")
        XCTAssertEqual(errorCode(of: responses.first), "no_active_session")
        XCTAssertEqual(accepted(responses.first), false)
        let responseIndex = try XCTUnwrap(events.firstIndex { $0.parentID == request.id })
        let endedIndex = try XCTUnwrap(events.firstIndex { $0.name == "Brand Concierge Conversation Ended" })
        XCTAssertLessThan(responseIndex, endedIndex)
        XCTAssertTrue(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })

        let fresh = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "new-ecid", server: "https://example.com", surfaces: ["chat"]))
        await gate.release()
        await fulfillment(of: [finished], timeout: 5)
        await flushPendingRequests()
        XCTAssertEqual(mockRuntime.dispatchedEvents.filter { $0.parentID == request.id }.count, 1)
        XCTAssertTrue(old.controller.messages.isEmpty)
        XCTAssertTrue(fresh.controller.messages.isEmpty, "Resumed old handoff must not start transport in the fresh controller.")
        XCTAssertFalse(old.controller.isProcessing)
        XCTAssertFalse(fresh.controller.isProcessing)
        XCTAssertNil(ConciergeXDMContextStore.shared.snapshot(for: fresh.sessionID)["oldHandoff"])
    }

    @MainActor
    func test_resetIdentities_unblocksDependencyWaitingRequests_andRejectsOldController() async throws {
        let session = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["overlay"]))
        mockRuntime.mockedSharedStates = [:]
        let waiting = Event(name: ConciergeConstants.EventName.SHOW_UI,
            type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
            data: [ConciergeConstants.EventData.Key.SURFACES: ["overlay"]])
        mockRuntime.simulateComingEvents(waiting)
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        resetIdentities()
        XCTAssertFalse(session.controller.composerEditable)
        completeReset()
        try await awaitResetReady()
        await flushPendingRequests()
        XCTAssertTrue(mockRuntime.dispatchedEvents.contains { $0.parentID == waiting.id })
        XCTAssertFalse(session.controller.composerEditable)
    }

    @MainActor
    func test_resetIdentities_earlierCompletionCannotReleaseLatestGeneration() async throws {
        let first = Event(name: "Reset 1", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        let second = Event(name: "Reset 2", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        mockRuntime.simulateComingEvents(first, second)
        setIdentity("first", event: first)
        setIdentity("second", event: second)
        setIdentity("second")
        let firstCompletion = Event(name: "Complete 1", type: EventType.edgeIdentity, source: EventSource.resetComplete, data: nil)
        setIdentity("first", event: firstCompletion)
        mockRuntime.simulateComingEvents(firstCompletion)
        await Task.yield()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        let secondCompletion = Event(name: "Complete 2", type: EventType.edgeIdentity, source: EventSource.resetComplete, data: nil)
        setIdentity("second", event: secondCompletion)
        mockRuntime.simulateComingEvents(secondCompletion)
        try await awaitResetReady()
    }

    @MainActor
    func test_resetIdentities_staleCompletionDoesNotConsumeActiveRequest() async throws {
        let stale = Event(name: "Old complete", type: EventType.edgeIdentity, source: EventSource.resetComplete, data: nil)
        let reset = Event(name: "Reset", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        setIdentity("old", event: stale)
        setIdentity("fresh", event: reset)
        setIdentity("fresh")
        mockRuntime.simulateComingEvents(reset, stale)
        await Task.yield()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        mockRuntime.simulateComingEvents(Event(name: "Fresh complete", type: EventType.edgeIdentity,
            source: EventSource.resetComplete, data: nil))
        try await awaitResetReady()
    }

    @MainActor
    func test_resetIdentities_waitsForActiveRequestState_andRejectsMismatchedCompletionIdentity() async throws {
        let reset = Event(name: "Reset", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        let complete = Event(name: "Complete", type: EventType.edgeIdentity, source: EventSource.resetComplete, data: nil)
        setIdentity("fresh", event: reset, status: .pending)
        setIdentity("fresh")
        setIdentity("old", event: complete)
        mockRuntime.simulateComingEvents(reset, complete)
        await Task.yield()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        setIdentity("fresh", event: reset)
        mockRuntime.simulateComingEvents(Event(name: "State", type: EventType.hub, source: EventSource.sharedState, data: nil))
        // Even after the reset request state resolves, an old completion's identity cannot release it.
        try await Task.sleep(nanoseconds: 70_000_000)
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        setIdentity("fresh", event: complete)
        try await awaitResetReady()
    }

    @MainActor
    func test_resetIdentities_usesCurrentConfiguration_afterIncompleteCompletionSnapshot() async throws {
        let parent = UIViewController()
        Concierge.attachConciergeUIKitHost(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://old.example.com", surfaces: ["uikit"]), presentingViewController: parent)
        resetIdentities()
        let complete = Event(name: "Complete", type: EventType.edgeIdentity, source: EventSource.resetComplete, data: nil)
        setConfiguration(event: complete, server: nil, datastream: nil)
        setConfiguration(server: nil, datastream: nil)
        setIdentity("fresh", event: complete)
        setIdentity("fresh")
        mockRuntime.simulateComingEvents(complete)
        await Task.yield()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        setConfiguration(server: "https://updated.example.com", datastream: "updated")
        mockRuntime.simulateComingEvents(Event(name: "Updated config", type: EventType.hub, source: EventSource.sharedState, data: nil))
        try await awaitResetReady()
        XCTAssertEqual(Concierge.currentSession?.configuration.server, "https://updated.example.com")
        XCTAssertEqual(Concierge.currentSession?.configuration.datastream, "updated")
    }

    @MainActor
    func test_resetIdentities_revalidatesConfigurationAfterTeardown() async throws {
        resetIdentities()
        completeReset()
        // MainActor teardown/readiness cannot run until this synchronous actor turn returns.
        setConfiguration(server: nil, datastream: nil)
        await Task.yield()
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        setConfiguration()
        try await awaitResetReady()
    }

    @MainActor
    private func assertRetainedHostsReset(overlayVisible: Bool) async throws {
        let overlay = ConciergeOverlayManager.shared
        let first = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["overlay"]))
        overlay.showChat(Concierge.makeChatView(session: first))
        if !overlayVisible { overlay.hideChat() }
        let parent = UIViewController()
        Concierge.attachConciergeUIKitHost(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["uikit"]), presentingViewController: parent)
        let second = try XCTUnwrap(Concierge.currentSession)
        Concierge.presentedUIKitController?.view.isHidden = !overlayVisible
        XCTAssertFalse(first.controller === second.controller)
        for controller in [first.controller, second.controller] {
            controller.messages.append(Message(template: .basic(isUserMessage: true), messageBody: "private"))
            controller.applyTextChange("private draft")
        }
        resetIdentities()
        try ConciergeXDMContextStore.shared.update(["newUser": true])
        completeReset()
        try await awaitResetReady()
        for controller in [first.controller, second.controller] {
            XCTAssertTrue(controller.endedForIdentityReset)
            XCTAssertTrue(controller.messages.isEmpty)
            XCTAssertTrue(controller.inputText.isEmpty)
        }
        let nextOverlay = try XCTUnwrap(overlay.chatView?.identityResetController)
        let nextUIKit = try XCTUnwrap((Concierge.presentedUIKitController as? ConciergeHostingController)?.chatController)
        XCTAssertFalse(nextOverlay === first.controller)
        XCTAssertFalse(nextUIKit === second.controller)
        XCTAssertEqual(nextOverlay.configuration?.surfaces, ["overlay"])
        XCTAssertEqual(nextUIKit.configuration?.surfaces, ["uikit"])
        XCTAssertEqual(nextOverlay.configuration?.ecid, "new-ecid")
        XCTAssertEqual(nextUIKit.configuration?.ecid, "new-ecid")
        XCTAssertEqual(overlay.showingConcierge, overlayVisible)
        XCTAssertTrue(Concierge.presentedUIKitController?.parent === parent)
        XCTAssertEqual(Concierge.presentedUIKitController?.view.isHidden, !overlayVisible)
        XCTAssertEqual(ConciergeXDMContextStore.shared.snapshot(for: SessionManager.shared.getOrCreateSessionId())["newUser"] as? Bool, true)
    }

    @MainActor
    func test_resetIdentities_clearsAndRebuildsHiddenOverlay_andDistinctUIKitHost() async throws {
        try await assertRetainedHostsReset(overlayVisible: false)
    }

    @MainActor
    func test_resetIdentities_clearsAndRebuildsVisibleOverlay_andDistinctUIKitHost() async throws {
        try await assertRetainedHostsReset(overlayVisible: true)
    }

    @MainActor
    func test_resetIdentities_cancelsWorkInEveryRetainedHost_andDeduplicatesSharedController() async throws {
        let configuration = ConciergeConfiguration(ecid: "old", server: "https://example.com", surfaces: ["chat"])
        let service = MockChatService(configuration: configuration)
        service.shouldCallComplete = false
        service.completesOnCancel = false
        let capturer = MockSpeechCapturer()
        let speaker = MockTextSpeaker()
        let old = ChatController(configuration: configuration, chatService: service,
                                 speechCapturer: capturer, speaker: speaker)
        let secondService = MockChatService(configuration: configuration)
        secondService.shouldCallComplete = false
        secondService.completesOnCancel = false
        let secondSpeaker = MockTextSpeaker()
        let second = ChatController(configuration: configuration, chatService: secondService,
                                    speechCapturer: nil, speaker: secondSpeaker)
        let overlay = ConciergeOverlayManager.shared
        overlay.showChat(ChatView(controller: old))
        overlay.hideChat()
        let parent = UIViewController()
        let hosting = ConciergeHostingController(chatView: ChatView(controller: second))
        parent.addChild(hosting)
        parent.view.addSubview(hosting.view)
        hosting.didMove(toParent: parent)
        Concierge.presentedUIKitController = hosting
        let settled = expectation(description: "Retained handoffs settled")
        settled.expectedFulfillmentCount = 2
        XCTAssertTrue(old.handleDataHandoff(routingHint: "old", xdmFields: [:]) { _ in settled.fulfill() })
        XCTAssertTrue(second.handleDataHandoff(routingHint: "old", xdmFields: [:]) { _ in settled.fulfill() })
        let deadline = Date().addingTimeInterval(5)
        while (service.streamChatCallCount != 1 || secondService.streamChatCallCount != 1), Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(service.streamChatCallCount, 1)
        XCTAssertEqual(secondService.streamChatCallCount, 1)
        resetIdentities()
        completeReset()
        await fulfillment(of: [settled], timeout: 5)
        try await awaitResetReady()
        XCTAssertEqual(service.cancelActiveStreamCallCount, 1)
        XCTAssertEqual(secondService.cancelActiveStreamCallCount, 1)
        XCTAssertEqual(speaker.stopCount, 1)
        XCTAssertEqual(secondSpeaker.stopCount, 1)
        XCTAssertEqual(capturer.endCaptures, 1)
        XCTAssertTrue(old.messages.isEmpty)
        XCTAssertTrue(second.messages.isEmpty)

        // The same controller can be retained by both hosts. Teardown must run only once.
        overlay.showChat(ChatView(controller: old))
        Concierge.presentedUIKitController = ConciergeHostingController(chatView: ChatView(controller: old))
        resetIdentities()
        completeReset()
        try await awaitResetReady()
        XCTAssertEqual(speaker.stopCount, 2)
    }

    @MainActor
    func test_resetIdentities_realCoreFIFO_pendingConfigureCannotStrandReset() async throws {
        let hub = EventHub()
        let registered = expectation(description: "Real Core extensions registered")
        registered.expectedFulfillmentCount = 2
        hub.registerExtension(PendingResetConfiguration.self) { error in
            XCTAssertNil(error)
            registered.fulfill()
        }
        hub.registerExtension(Concierge.self) { error in
            XCTAssertNil(error)
            registered.fulfill()
        }
        await fulfillment(of: [registered], timeout: 5)
        hub.start()
        let old = Concierge.resolveSession(configuration: ConciergeConfiguration(
            ecid: "old", server: "https://example.com", surfaces: ["overlay"]))
        let generation = ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }
        hub.dispatch(event: Event(name: "Configure with App ID", type: EventType.configuration,
            source: EventSource.requestContent, data: ["config.appId": "pending-app-id"]))
        let waiting = Event(name: ConciergeConstants.EventName.SHOW_UI,
            type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
            data: [ConciergeConstants.EventData.Key.SURFACES: ["overlay"]])
        let rejected = expectation(description: "Queued show rejected across boundary")
        hub.registerResponseListener(triggerEvent: waiting, timeout: 5) { response in
            XCTAssertNotNil(response)
            rejected.fulfill()
        }
        let handoff = Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
            type: ConciergeConstants.EventType.concierge, source: EventSource.requestContent,
            data: [ConciergeConstants.DataHandoffEventData.Key.PAYLOAD: ConciergeDataHandoffEvent(
                routingHint: "old", xdmFields: ["value": "old"])])
        let handoffSettled = expectation(description: "Deferred handoff callback settled")
        let ended = expectation(description: "Ended notification follows callback settlement")
        let settlementLock = NSLock()
        var sawHandoffCallback = false
        hub.registerResponseListener(triggerEvent: handoff, timeout: 5) { response in
            XCTAssertEqual(response?.data?[ConciergeConstants.DataHandoffEventData.Key.ERROR_CODE] as? String, "no_active_session")
            settlementLock.lock()
            sawHandoffCallback = true
            settlementLock.unlock()
            handoffSettled.fulfill()
        }
        hub.registerEventListener(type: ConciergeConstants.EventType.concierge, source: EventSource.notification) { event in
            guard event.name == "Brand Concierge Conversation Ended" else { return }
            settlementLock.lock()
            let settled = sawHandoffCallback
            settlementLock.unlock()
            XCTAssertTrue(settled, "Real Core must deliver the deferred handoff callback before Conversation Ended.")
            ended.fulfill()
        }
        hub.dispatch(event: waiting)
        hub.dispatch(event: handoff)
        hub.dispatch(event: Event(name: "Reset", type: EventType.genericIdentity,
            source: EventSource.requestReset, data: nil))
        await fulfillment(of: [rejected, handoffSettled, ended], timeout: 5)
        XCTAssertGreaterThan(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }, generation)
        XCTAssertFalse(old.controller.composerEditable)
        // Exercise the real ExtensionContainer/OperationOrderer, not simulateComingEvents.
        hub.shutdown()
    }

    @MainActor
    func test_resetIdentities_realCoreVersions_overlapAndLaterConfigurationRecovery() async throws {
        let hub = EventHub()
        let registered = expectation(description: "Versioned Core fixtures registered")
        registered.expectedFulfillmentCount = 3
        for type in [PendingResetConfiguration.self, VersionedResetIdentity.self, Concierge.self] as [Extension.Type] {
            hub.registerExtension(type) { error in
                XCTAssertNil(error)
                registered.fulfill()
            }
        }
        await fulfillment(of: [registered], timeout: 5)
        hub.createSharedState(extensionName: ConciergeConstants.SharedState.Configuration.NAME, data: [:], event: nil)
        let completed = expectation(description: "Edge's two ordered completions")
        completed.expectedFulfillmentCount = 2
        hub.registerEventListener(type: EventType.edgeIdentity, source: EventSource.resetComplete) { _ in completed.fulfill() }
        hub.start()
        let first = Event(name: "Reset 1", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        let second = Event(name: "Reset 2", type: EventType.genericIdentity, source: EventSource.requestReset, data: nil)
        let generation = ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }
        hub.dispatch(event: first)
        hub.dispatch(event: second)
        await fulfillment(of: [completed], timeout: 5)
        let deadline = Date().addingTimeInterval(5)
        while ConciergeIdentityBoundary.shared.synchronized({ ConciergeIdentityBoundary.shared.generation }) < generation + 2,
              Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertFalse(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.ready })
        let firstState = try XCTUnwrap(hub.getSharedState(
            extensionName: ConciergeConstants.SharedState.EdgeIdentity.NAME, event: first,
            barrier: true, sharedStateType: .xdm))
        let secondState = try XCTUnwrap(hub.getSharedState(
            extensionName: ConciergeConstants.SharedState.EdgeIdentity.NAME, event: second,
            barrier: true, sharedStateType: .xdm))
        XCTAssertEqual(firstState.status, .set)
        XCTAssertEqual(secondState.status, .set)
        XCTAssertEqual(firstState.ecid, "reset-1")
        XCTAssertEqual(secondState.ecid, "reset-2")
        // Completion snapshots remain SET but incomplete; only the current version can recover.
        hub.createSharedState(extensionName: ConciergeConstants.SharedState.Configuration.NAME,
            data: [ConciergeConstants.SharedState.Configuration.Concierge.SERVER: "https://updated.example.com",
                   ConciergeConstants.SharedState.Configuration.Concierge.DATASTREAM: "updated"], event: nil)
        try await awaitResetReady()
        XCTAssertEqual(ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }, generation + 2)
        hub.shutdown()
    }

    func test_readyForEvent_neverBlocksCoreFIFO() {
        let event = Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
                          type: ConciergeConstants.EventType.concierge,
                          source: EventSource.requestContent,
                          data: nil)

        mockRuntime.mockedSharedStates = [:]
        mockRuntime.mockedXdmSharedStates = [:]
        XCTAssertTrue(concierge.readyForEvent(event))
    }

    private actor ClaimedHandoffGate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false

        func pause(_ entered: XCTestExpectation) async {
            guard !released else { return }
            await withCheckedContinuation {
                continuation = $0
                entered.fulfill()
            }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

    private final class PendingResetConfiguration: NSObject, Extension {
        static let extensionVersion = "test"
        let name = ConciergeConstants.SharedState.Configuration.NAME
        let friendlyName = "Pending configuration fixture"
        let metadata: [String: String]? = nil
        let runtime: ExtensionRuntime

        required init?(runtime: ExtensionRuntime) { self.runtime = runtime }
        func onRegistered() {
            _ = createPendingSharedState(event: nil)
            registerListener(type: EventType.configuration, source: EventSource.requestContent) { [weak self] event in
                _ = self?.createPendingSharedState(event: event)
            }
        }
        func onUnregistered() {}
        func readyForEvent(_ event: Event) -> Bool { true }
    }

    private final class VersionedResetIdentity: NSObject, Extension {
        static let extensionVersion = "test"
        let name = ConciergeConstants.SharedState.EdgeIdentity.NAME
        let friendlyName = "Versioned Edge reset fixture"
        let metadata: [String: String]? = nil
        let runtime: ExtensionRuntime
        private var resets = 0

        required init?(runtime: ExtensionRuntime) { self.runtime = runtime }
        func onRegistered() {
            createXDMSharedState(data: ["identityMap": ["ECID": [["id": "old"]]]], event: nil)
            registerListener(type: EventType.genericIdentity, source: EventSource.requestReset) { [weak self] event in
                guard let self else { return }
                self.resets += 1
                let resolve = self.createPendingXDMSharedState(event: event)
                resolve(["identityMap": ["ECID": [["id": "reset-\(self.resets)"]]]])
                self.dispatch(event: Event(name: "Reset complete", type: EventType.edgeIdentity,
                    source: EventSource.resetComplete, data: nil))
            }
        }
        func onUnregistered() {}
        func readyForEvent(_ event: Event) -> Bool { true }
    }
}
