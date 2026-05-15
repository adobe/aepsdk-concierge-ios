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

import AEPBrandConcierge
import AEPCore
import Foundation
import os.log

/// Sample tracker that listens to all Brand Concierge notification events and logs
/// their event-specific payloads. A consumer app would replace the `log` calls with
/// calls to its analytics pipeline (Edge.sendEvent, Adobe Analytics, a custom backend,
/// etc.). See `Documentation/edge-tracking-guide.md` in the Android repo for an Edge
/// mapping that applies equally on iOS.
enum ConciergeTracker {

    private static let logger = Logger(subsystem: "com.adobe.concierge.demo", category: "ConciergeTracker")

    static func start() {
        MobileCore.registerEventListener(
            type: ConciergeConstants.EventType.concierge,
            source: EventSource.notification
        ) { event in
            handleEvent(event)
        }
    }

    private static func handleEvent(_ event: Event) {
        guard let data = event.data else {
            logger.warning("Concierge notification event has no data (name=\(event.name, privacy: .public))")
            return
        }
        typealias Key = ConciergeConstants.TrackingEvent.EventData.Key
        guard let xdmType = data[Key.EVENT_TYPE] as? String else {
            logger.warning("Concierge notification event missing concierge.eventType: data=\(String(describing: data), privacy: .public)")
            return
        }

        typealias Types = ConciergeConstants.TrackingEvent.XDMType
        switch xdmType {
        case Types.SESSION_INITIALIZED:
            logger.debug("session:initialized")

        case Types.CHAT_OPENED:
            let epoch = data[Key.EPOCH_TIME] as? Int64
            logger.debug("chat:opened epochTime=\(String(describing: epoch), privacy: .public)")

        case Types.CHAT_CLOSED:
            let epoch = data[Key.EPOCH_TIME] as? Int64
            let duration = data[Key.DURATION_MILLIS] as? Int64
            logger.debug("chat:closed epochTime=\(String(describing: epoch), privacy: .public) durationMillis=\(String(describing: duration), privacy: .public)")

        case Types.QUERY_SUBMITTED:
            let query = data[Key.QUERY] as? String
            logger.debug("query:submitted query=\"\(query ?? "", privacy: .public)\"")

        case Types.PROMPT_SUGGESTION_CLICKED:
            let suggestion = data[Key.SUGGESTION] as? String
            logger.debug("promptSuggestion:clicked suggestion=\"\(suggestion ?? "", privacy: .public)\"")

        case Types.WELCOME_PROMPT_SUGGESTION_CLICKED:
            let suggestion = data[Key.SUGGESTION] as? String
            logger.debug("welcomePromptSuggestion:clicked suggestion=\"\(suggestion ?? "", privacy: .public)\"")

        case Types.CARD_CLICKED:
            let element = data[Key.ELEMENT] as? [String: Any]
            logger.debug("card:clicked element=\(String(describing: element), privacy: .public)")

        case Types.MIC_BUTTON_CLICKED:
            logger.debug("micButton:clicked")

        case Types.RESPONSE_STARTED:
            let conversationId = data[Key.CONVERSATION_ID] as? String
            let interactionId = data[Key.INTERACTION_ID] as? String
            logger.debug("response:started conversationId=\(conversationId ?? "nil", privacy: .public) interactionId=\(interactionId ?? "nil", privacy: .public)")

        case Types.RESPONSE_COMPLETED:
            let conversationId = data[Key.CONVERSATION_ID] as? String
            let interactionId = data[Key.INTERACTION_ID] as? String
            logger.debug("response:completed conversationId=\(conversationId ?? "nil", privacy: .public) interactionId=\(interactionId ?? "nil", privacy: .public)")

        case Types.CARDS_RENDERED:
            let displayMode = data[Key.DISPLAY_MODE] as? String
            let elements = data[Key.ELEMENTS] as? [[String: Any]]
            logger.debug("cards:rendered displayMode=\(displayMode ?? "nil", privacy: .public) elementCount=\(elements?.count ?? 0, privacy: .public) elements=\(String(describing: elements), privacy: .public)")

        case Types.FEEDBACK_SUBMITTED:
            let conversationId = data[Key.CONVERSATION_ID] as? String
            let interactionId = data[Key.INTERACTION_ID] as? String
            let feedbackType = data[Key.FEEDBACK_TYPE] as? String
            let selectedOptions = data[Key.SELECTED_OPTIONS] as? [String]
            let notes = data[Key.NOTES] as? String
            logger.debug("""
                feedback:submitted \
                conversationId=\(conversationId ?? "nil", privacy: .public) \
                interactionId=\(interactionId ?? "nil", privacy: .public) \
                feedbackType=\(feedbackType ?? "nil", privacy: .public) \
                selectedOptions=\(String(describing: selectedOptions), privacy: .public) \
                notes="\(notes ?? "", privacy: .public)"
                """)

        case Types.DISCLAIMER_LINK_CLICKED:
            let url = data[Key.URL] as? String
            logger.debug("disclaimerLink:clicked url=\(url ?? "nil", privacy: .public)")

        case Types.ERROR_OCCURRED:
            let errorMessage = data[Key.ERROR_MESSAGE] as? String
            logger.warning("error:occurred errorMessage=\"\(errorMessage ?? "", privacy: .public)\"")

        default:
            logger.debug("\(xdmType, privacy: .public) (unhandled) data=\(String(describing: data), privacy: .public)")
        }
    }
}
