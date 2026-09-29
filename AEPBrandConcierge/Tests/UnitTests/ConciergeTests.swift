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
        mockRuntime = TestableExtensionRuntime()
        concierge = Concierge(runtime: mockRuntime)
        concierge.onRegistered()
    }

    @MainActor
    override func tearDown() async throws {
        Concierge.currentSession = nil
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

    func test_showUiEvent_routesToShowUiHandler_notDataHandoff() {
        let event = Event(name: ConciergeConstants.EventName.SHOW_UI,
                          type: ConciergeConstants.EventType.concierge,
                          source: EventSource.requestContent,
                          data: nil)

        mockRuntime.simulateComingEvents(event)
        let response = mockRuntime.firstEvent

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

    func test_readyForEvent_dataHandoffEvent_stillRequiresConfigurationAndEdgeIdentity() {
        // No Configuration/EdgeIdentity shared state has been set up on mockRuntime at all -
        // data-handoff events are not exempted from the extension's hard dependency on both.
        let event = Event(name: ConciergeConstants.EventName.DATA_HANDOFF,
                          type: ConciergeConstants.EventType.concierge,
                          source: EventSource.requestContent,
                          data: nil)

        XCTAssertFalse(concierge.readyForEvent(event))
    }
}
