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

import AEPCore
import XCTest
@testable import AEPBrandConcierge

final class ConciergeTrackingEventTests: XCTestCase {

    // MARK: - Common Assertions

    private func assertCommonEventProperties(_ event: Event, expectedName: String, expectedXDMType: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(event.name, expectedName, file: file, line: line)
        XCTAssertEqual(event.type, "com.adobe.eventType.concierge", file: file, line: line)
        XCTAssertEqual(event.source, EventSource.notification, file: file, line: line)
        let eventType = event.data?[ConciergeConstants.TrackingEvent.EventData.Key.EVENT_TYPE] as? String
        XCTAssertEqual(eventType, expectedXDMType, file: file, line: line)
    }

    // MARK: - sessionInitialized

    func test_sessionInitialized_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.sessionInitialized.toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.SESSION_INITIALIZED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.SESSION_INITIALIZED
        )
        XCTAssertEqual(event.data?.count, 1)
    }

    // MARK: - querySubmitted

    func test_querySubmitted_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.querySubmitted(query: "What tools do you offer?").toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.QUERY_SUBMITTED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.QUERY] as? String, "What tools do you offer?")
    }

    // MARK: - promptSuggestionClicked

    func test_promptSuggestionClicked_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.promptSuggestionClicked(suggestion: "Tell me about Photoshop").toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.PROMPT_SUGGESTION_CLICKED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.PROMPT_SUGGESTION_CLICKED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.SUGGESTION] as? String, "Tell me about Photoshop")
    }

    // MARK: - cardClicked

    func test_cardClicked_createsCorrectEvent() {
        let element: [String: Any] = [
            "productName": "Adobe Photoshop",
            "productPageURL": "https://adobe.com/photoshop"
        ]
        let event = ConciergeTrackingEvent.cardClicked(element: element).toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.CARD_CLICKED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.CARD_CLICKED
        )
        let eventElement = event.data?[ConciergeConstants.TrackingEvent.EventData.Key.ELEMENT] as? [String: Any]
        XCTAssertEqual(eventElement?["productName"] as? String, "Adobe Photoshop")
        XCTAssertEqual(eventElement?["productPageURL"] as? String, "https://adobe.com/photoshop")
    }

    // MARK: - responseStarted

    func test_responseStarted_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.responseStarted(conversationId: "conv-123", interactionId: "int-456").toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.RESPONSE_STARTED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.CONVERSATION_ID] as? String, "conv-123")
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.INTERACTION_ID] as? String, "int-456")
    }

    // MARK: - responseCompleted

    func test_responseCompleted_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.responseCompleted(conversationId: "conv-123", interactionId: "int-456").toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.RESPONSE_COMPLETED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.RESPONSE_COMPLETED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.CONVERSATION_ID] as? String, "conv-123")
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.INTERACTION_ID] as? String, "int-456")
    }

    // MARK: - cardsRendered

    func test_cardsRendered_createsCorrectEvent() {
        let elements: [[String: Any]] = [
            ["productName": "Product A"],
            ["productName": "Product B"]
        ]
        let event = ConciergeTrackingEvent.cardsRendered(displayMode: "carousel", elements: elements).toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.CARDS_RENDERED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.CARDS_RENDERED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.DISPLAY_MODE] as? String, "carousel")
        let eventElements = event.data?[ConciergeConstants.TrackingEvent.EventData.Key.ELEMENTS] as? [[String: Any]]
        XCTAssertEqual(eventElements?.count, 2)
    }

    // MARK: - feedbackSubmitted

    func test_feedbackSubmitted_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.feedbackSubmitted(
            conversationId: "conv-123",
            interactionId: "int-456",
            feedbackType: "negative",
            selectedOptions: ["Incorrect information", "Not relevant"],
            notes: "Response did not address pricing"
        ).toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.FEEDBACK_SUBMITTED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.FEEDBACK_SUBMITTED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.CONVERSATION_ID] as? String, "conv-123")
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.INTERACTION_ID] as? String, "int-456")
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.FEEDBACK_TYPE] as? String, "negative")
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.SELECTED_OPTIONS] as? [String], ["Incorrect information", "Not relevant"])
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.NOTES] as? String, "Response did not address pricing")
    }

    // MARK: - errorOccurred

    func test_errorOccurred_createsCorrectEvent() {
        let event = ConciergeTrackingEvent.errorOccurred(errorMessage: "Server was unreachable.").toEvent()

        assertCommonEventProperties(event,
            expectedName: ConciergeConstants.TrackingEvent.Name.ERROR_OCCURRED,
            expectedXDMType: ConciergeConstants.TrackingEvent.XDMType.ERROR_OCCURRED
        )
        XCTAssertEqual(event.data?[ConciergeConstants.TrackingEvent.EventData.Key.ERROR_MESSAGE] as? String, "Server was unreachable.")
    }
}
