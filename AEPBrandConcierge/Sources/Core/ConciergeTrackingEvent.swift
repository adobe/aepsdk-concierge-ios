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
import Foundation

/// Defines the tracking events dispatched by the Brand Concierge extension to the Event Hub.
///
/// Produces an `Event` with:
/// - `type`: `com.adobe.eventType.concierge`
/// - `source`: `com.adobe.eventSource.notification`
/// - `data`: contains `concierge.eventType` plus event specific payload
///    - Each case maps to a web client event type (see `ConciergeConstants.TrackingEventSubtype`)
enum ConciergeTrackingEvent {
    case sessionInitialized
    case chatOpened(epochTime: Int64)
    case chatClosed(epochTime: Int64, durationMillis: Int64)
    case querySubmitted(query: String)
    case promptSuggestionClicked(suggestion: String)
    case welcomePromptSuggestionClicked(suggestion: String)
    case cardClicked(element: [String: Any])
    case micButtonClicked
    case responseStarted(conversationId: String, interactionId: String)
    case responseCompleted(conversationId: String, interactionId: String)
    case cardsRendered(displayMode: String, elements: [[String: Any]])
    case feedbackSubmitted(conversationId: String, interactionId: String, feedbackType: String, selectedOptions: [String], notes: String)
    case disclaimerLinkClicked(url: String)
    case errorOccurred(errorMessage: String)
    case ctaButtonClicked(label: String, linkUrl: String)

    /// Builds an `AEPCore.Event` for dispatch to the Event Hub.
    func toEvent() -> Event {
        Event(
            name: eventName,
            type: ConciergeConstants.EventType.concierge,
            source: EventSource.notification,
            data: eventData
        )
    }

    private var eventName: String {
        switch self {
        case .sessionInitialized:
            return ConciergeConstants.TrackingEvent.Name.SESSION_INITIALIZED
        case .chatOpened:
            return ConciergeConstants.TrackingEvent.Name.CHAT_OPENED
        case .chatClosed:
            return ConciergeConstants.TrackingEvent.Name.CHAT_CLOSED
        case .querySubmitted:
            return ConciergeConstants.TrackingEvent.Name.QUERY_SUBMITTED
        case .promptSuggestionClicked:
            return ConciergeConstants.TrackingEvent.Name.PROMPT_SUGGESTION_CLICKED
        case .welcomePromptSuggestionClicked:
            return ConciergeConstants.TrackingEvent.Name.WELCOME_PROMPT_SUGGESTION_CLICKED
        case .cardClicked:
            return ConciergeConstants.TrackingEvent.Name.CARD_CLICKED
        case .micButtonClicked:
            return ConciergeConstants.TrackingEvent.Name.MIC_BUTTON_CLICKED
        case .responseStarted:
            return ConciergeConstants.TrackingEvent.Name.RESPONSE_STARTED
        case .responseCompleted:
            return ConciergeConstants.TrackingEvent.Name.RESPONSE_COMPLETED
        case .cardsRendered:
            return ConciergeConstants.TrackingEvent.Name.CARDS_RENDERED
        case .feedbackSubmitted:
            return ConciergeConstants.TrackingEvent.Name.FEEDBACK_SUBMITTED
        case .disclaimerLinkClicked:
            return ConciergeConstants.TrackingEvent.Name.DISCLAIMER_LINK_CLICKED
        case .errorOccurred:
            return ConciergeConstants.TrackingEvent.Name.ERROR_OCCURRED
        case .ctaButtonClicked:
            return ConciergeConstants.TrackingEvent.Name.CTA_BUTTON_CLICKED
        }
    }

    private var xdmType: String {
        switch self {
        case .sessionInitialized:
            return ConciergeConstants.TrackingEvent.XDMType.SESSION_INITIALIZED
        case .chatOpened:
            return ConciergeConstants.TrackingEvent.XDMType.CHAT_OPENED
        case .chatClosed:
            return ConciergeConstants.TrackingEvent.XDMType.CHAT_CLOSED
        case .querySubmitted:
            return ConciergeConstants.TrackingEvent.XDMType.QUERY_SUBMITTED
        case .promptSuggestionClicked:
            return ConciergeConstants.TrackingEvent.XDMType.PROMPT_SUGGESTION_CLICKED
        case .welcomePromptSuggestionClicked:
            return ConciergeConstants.TrackingEvent.XDMType.WELCOME_PROMPT_SUGGESTION_CLICKED
        case .cardClicked:
            return ConciergeConstants.TrackingEvent.XDMType.CARD_CLICKED
        case .micButtonClicked:
            return ConciergeConstants.TrackingEvent.XDMType.MIC_BUTTON_CLICKED
        case .responseStarted:
            return ConciergeConstants.TrackingEvent.XDMType.RESPONSE_STARTED
        case .responseCompleted:
            return ConciergeConstants.TrackingEvent.XDMType.RESPONSE_COMPLETED
        case .cardsRendered:
            return ConciergeConstants.TrackingEvent.XDMType.CARDS_RENDERED
        case .feedbackSubmitted:
            return ConciergeConstants.TrackingEvent.XDMType.FEEDBACK_SUBMITTED
        case .disclaimerLinkClicked:
            return ConciergeConstants.TrackingEvent.XDMType.DISCLAIMER_LINK_CLICKED
        case .errorOccurred:
            return ConciergeConstants.TrackingEvent.XDMType.ERROR_OCCURRED
        case .ctaButtonClicked:
            return ConciergeConstants.TrackingEvent.XDMType.CTA_BUTTON_CLICKED
        }
    }

    private var eventData: [String: Any] {
        typealias Key = ConciergeConstants.TrackingEvent.EventData.Key

        var data: [String: Any] = [
            Key.EVENT_TYPE: xdmType
        ]

        switch self {
        case .sessionInitialized:
            break

        case .chatOpened(let epochTime):
            data[Key.EPOCH_TIME] = epochTime

        case .chatClosed(let epochTime, let durationMillis):
            data[Key.EPOCH_TIME] = epochTime
            data[Key.DURATION_MILLIS] = durationMillis

        case .querySubmitted(let query):
            data[Key.QUERY] = query

        case .promptSuggestionClicked(let suggestion),
             .welcomePromptSuggestionClicked(let suggestion):
            data[Key.SUGGESTION] = suggestion

        case .cardClicked(let element):
            data[Key.ELEMENT] = element

        case .micButtonClicked:
            break

        case .responseStarted(let conversationId, let interactionId),
             .responseCompleted(let conversationId, let interactionId):
            data[Key.CONVERSATION_ID] = conversationId
            data[Key.INTERACTION_ID] = interactionId

        case .cardsRendered(let displayMode, let elements):
            data[Key.DISPLAY_MODE] = displayMode
            data[Key.ELEMENTS] = elements

        case .feedbackSubmitted(let conversationId, let interactionId, let feedbackType, let selectedOptions, let notes):
            data[Key.CONVERSATION_ID] = conversationId
            data[Key.INTERACTION_ID] = interactionId
            data[Key.FEEDBACK_TYPE] = feedbackType
            data[Key.SELECTED_OPTIONS] = selectedOptions
            data[Key.NOTES] = notes

        case .disclaimerLinkClicked(let url):
            data[Key.URL] = url

        case .errorOccurred(let errorMessage):
            data[Key.ERROR_MESSAGE] = errorMessage

        case .ctaButtonClicked(let label, let linkUrl):
            data[Key.LABEL] = label
            data[Key.URL] = linkUrl
        }

        return data
    }
}
