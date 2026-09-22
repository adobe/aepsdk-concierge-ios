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
import AEPCore
import AEPServices

/// Main AEP SDK Extension class for Brand Concierge.
/// Manages SDK registration, event handling, and shared state coordination.
@objc(AEPMobileConcierge)
public class Concierge: NSObject, Extension {
    // MARK: - Extension Properties

    public static var extensionVersion: String = ConciergeConstants.EXTENSION_VERSION
    public var name = ConciergeConstants.EXTENSION_NAME
    public var friendlyName = ConciergeConstants.FRIENDLY_NAME
    public var metadata: [String: String]?
    public var runtime: ExtensionRuntime

    // MARK: - Static Properties

    static var speechCapturer: SpeechCapturing?
    static var textSpeaker: TextSpeaking?
    static var chatTitle: String = ConciergeConstants.Defaults.TITLE
    static var chatSubtitle: String? = ConciergeConstants.Defaults.SUBTITLE
    static var surfaces: [String] = []
    static var linkInterceptor: ConciergeLinkInterceptor = ConciergeLinkInterceptor()
    static var presentedUIKitController: UIViewController?

    /// The active chat session, shared by both SwiftUI and UIKit presentation paths.
    /// Cleared and replaced when the server session expires or the chat identity changes.
    @MainActor static var currentSession: ConciergeChatSession?

    #if DEBUG
    /// Testing-only override for the `URLSessionConfiguration` used when creating a new chat
    /// session's network service. Lets a host app inject `URLProtocol` stubs for local mock
    /// responses — set this *before* calling `show(...)`. `URLProtocol.registerClass(_:)` isn't
    /// reliably consulted for custom `URLSession` instances or HTTP/3 (QUIC) connections, so
    /// stubs must instead be added to this configuration's `protocolClasses`. `nil` (the default)
    /// uses the SDK's normal configuration. Only exists in Debug builds.
    public static var urlSessionConfigurationForTesting: URLSessionConfiguration?
    #endif

    // MARK: - Extension Protocol Methods

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    /// Internal initializer for testing
    init(runtime: ExtensionRuntime, conciergeChatService: ConciergeChatService? = nil) {
        self.runtime = runtime
        super.init()
    }

    public func onRegistered() {
        // Register listener for handling concierge request content events
        registerListener(type: ConciergeConstants.EventType.concierge,
                         source: EventSource.requestContent,
                         listener: handleRequestContentEvent)

        // Register listener for forwarding Concierge notification events to Edge
        registerListener(type: ConciergeConstants.EventType.concierge,
                         source: EventSource.notification,
                         listener: handleNotificationEvent)
    }

    public func onUnregistered() {
        Log.debug(label: ConciergeConstants.LOG_TAG, "Extension unregistered from MobileCore: \(ConciergeConstants.FRIENDLY_NAME)")
    }

    public func readyForEvent(_ event: Event) -> Bool {
        // Hard dependency on configuration for server and datastream information
        guard let _ = getConfiguration(for: event) else {
            Log.trace(label: ConciergeConstants.LOG_TAG, "Event processing is paused - waiting for valid configuration.")
            return false
        }

        // Hard dependency on edge identity module for ecid
        guard let _ = getEdgeIdentitySharedState(for: event) else {
            Log.trace(label: ConciergeConstants.LOG_TAG, "Event processing is paused - waiting for valid XDM shared state from Edge Identity extension.")
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func handleRequestContentEvent(_ event: Event) {
        switch event.name {
        case ConciergeConstants.EventName.SHOW_UI:
            handleShowChatUIRequestEvent(event)
        case ConciergeConstants.EventName.DATA_HANDOFF:
            handleDataHandoffEvent(event)
        default:
            break
        }
    }

    private func handleNotificationEvent(_ event: Event) {
        Log.trace(label: ConciergeConstants.LOG_TAG, "Concierge notification event received - '\(event.id.uuidString)'.")
        ConciergeEventTracker.trackEvent(event)
    }

    private func handleShowChatUIRequestEvent(_ event: Event) {
        Log.trace(label: ConciergeConstants.LOG_TAG, "Received show chat UI event - '\(event.id.uuidString)'.")

        // If we run into an error, populate an error message to be logged
        // and send an empty response event in the defer block
        var errorMessage: String?
        defer {
            if let message = errorMessage {
                Log.warning(label: ConciergeConstants.LOG_TAG, message)
                dispatch(event: createEmptyResponseEvent(for: event))
            }
        }

        guard let configSharedState = getConfiguration(for: event) else {
            errorMessage = "Unable to show Brand Concierge UI - Configuration shared state is not available."
            return
        }

        let consentValue = getConsentSharedState(for: event)?.collectValue ?? ConciergeConstants.Defaults.CONSENT_VALUE

        guard let edgeIdentitySharedState = getEdgeIdentitySharedState(for: event) else {
            errorMessage = "Unable to show Brand Concierge UI - EdgeIdentity shared state is not available."
            return
        }

        guard let ecid = edgeIdentitySharedState.ecid else {
            errorMessage = "Unable to show Brand Concierge UI - ECID is not available in the profile identity map."
            return
        }

        // Log namespace names only, never id values (PII)
        let identityMap = edgeIdentitySharedState.identityMap
        Log.debug(label: ConciergeConstants.LOG_TAG, "Updating concierge configuration with identityMap namespaces: \(identityMap?.keys.sorted() ?? [])")

        guard let server = configSharedState.conciergeServer else {
            errorMessage = "Unable to show Brand Concierge UI - server information is unavailable from configuration."
            return
        }

        guard let datastream = configSharedState.conciergeDatastream else {
            errorMessage = "Unable to show Brand Concierge UI - datastream information is unavailable from configuration."
            return
        }
        
        let region = configSharedState.conciergeRegion

        guard let surfaces = event.data?[ConciergeConstants.EventData.Key.SURFACES] as? [String], !surfaces.isEmpty else {
            errorMessage = "Unable to show Brand Concierge UI - no surfaces were provided in the show() call."
            return
        }

        let config = ConciergeConfiguration(consentCollectValue: consentValue, datastream: datastream, ecid: ecid, identityMap: identityMap, server: server, region: region, surfaces: surfaces)
        let responseEvent = event.createResponseEvent(name: ConciergeConstants.EventName.SHOW_UI_RESPONSE,
                                                      type: ConciergeConstants.EventType.concierge,
                                                      source: EventSource.responseContent,
                                                      data: [
                                                        ConciergeConstants.EventData.Key.CONFIG: config
                                                      ])
        dispatch(event: responseEvent)
    }

    private func createEmptyResponseEvent(for event: Event) -> Event {
        event.createResponseEvent(name: ConciergeConstants.EventName.SHOW_UI_RESPONSE,
                                  type: ConciergeConstants.EventType.concierge,
                                  source: EventSource.responseContent,
                                  data: nil)
    }

    private func handleDataHandoffEvent(_ event: Event) {
        Log.trace(label: ConciergeConstants.LOG_TAG, "Received data handoff event - '\(event.id.uuidString)'.")

        guard let payload = event.data?[ConciergeConstants.DataHandoffEventData.Key.PAYLOAD] as? ConciergeDataHandoffEvent else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .missingEventData))
            return
        }

        guard !payload.xdmFields.isEmpty else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .emptyXdmFields))
            return
        }

        guard JSONSerialization.isValidJSONObject(payload.xdmFields) else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .invalidXdmFieldValue))
            return
        }

        guard payload.xdmFields[ConciergeConstants.Request.Keys.IDENTITY_MAP] == nil else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .reservedKeyCollision))
            return
        }

        Task { @MainActor in
            // `resolveSession` gates reuse on `isSessionActive`, so a handoff has to clear the same
            // bar - an expired session's controller is still in memory but no longer valid.
            guard let controller = Concierge.currentSession?.controller,
                  SessionManager.shared.isSessionActive else {
                dispatch(event: createDataHandoffResponseEvent(for: event, error: .noActiveSession))
                return
            }

            // The controller owns chat state, so it is the single authority on whether a turn can
            // start. It reports back `false` without side effects when one is already in flight.
            let started = controller.handleDataHandoff(routingHint: payload.routingHint,
                                                       xdmFields: payload.xdmFields,
                                                       localMessage: payload.localMessage) { serviceError in
                // `self` is captured strongly on purpose. This closure lives only for one turn and
                // the extension is an app-lifetime singleton, so there is no retain cycle. A weak
                // capture could drop the response event entirely.
                let error = serviceError.map { ConciergeDataHandoffError(serviceError: $0) }
                self.dispatch(event: self.createDataHandoffResponseEvent(for: event, error: error))
            }

            guard started else {
                dispatch(event: createDataHandoffResponseEvent(for: event, error: .chatInProgress))
                return
            }
        }
    }

    private func createDataHandoffResponseEvent(for event: Event, error: ConciergeDataHandoffError?) -> Event {
        if let error {
            Log.warning(label: ConciergeConstants.LOG_TAG, "Data handoff failed for event '\(event.id.uuidString)': \(error.code)")
        }

        var data: [String: Any] = [
            ConciergeConstants.DataHandoffEventData.Key.ACCEPTED: error == nil
        ]
        data[ConciergeConstants.DataHandoffEventData.Key.ERROR_CODE] = error?.code
        data[ConciergeConstants.DataHandoffEventData.Key.ERROR_MESSAGE] = error?.wireMessage

        return event.createResponseEvent(name: ConciergeConstants.EventName.DATA_HANDOFF_RESPONSE,
                                         type: ConciergeConstants.EventType.concierge,
                                         source: EventSource.responseContent,
                                         data: data)
    }

    private func getConfiguration(for event: Event) -> SharedStateResult? {
        guard let configurationSharedState = getSharedState(extensionName: ConciergeConstants.SharedState.Configuration.NAME, event: event),
              configurationSharedState.status == .set
        else {
            return nil
        }

        return configurationSharedState
    }

    private func getEdgeIdentitySharedState(for event: Event) -> SharedStateResult? {
        guard let edgeIdentitySharedState = getXDMSharedState(extensionName: ConciergeConstants.SharedState.EdgeIdentity.NAME, event: event),
              edgeIdentitySharedState.status == .set
        else {
            return nil
        }

        return edgeIdentitySharedState
    }

    private func getConsentSharedState(for event: Event) -> SharedStateResult? {
        guard let consentSharedState = getXDMSharedState(extensionName: ConciergeConstants.SharedState.Consent.NAME, event: event),
              consentSharedState.status == .set
        else {
            return nil
        }

        return consentSharedState
    }
}
