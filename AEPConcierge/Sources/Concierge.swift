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

@objc(AEPMobileConcierge)
public class Concierge: NSObject, Extension {
    // MARK: - Extension properties
    public static var extensionVersion: String = Constants.EXTENSION_VERSION
    public var name = Constants.EXTENSION_NAME
    public var friendlyName = Constants.FRIENDLY_NAME
    public var metadata: [String: String]?
    public var runtime: ExtensionRuntime
    
    // MARK: - class properties
    static var speechCapturer: SpeechCapturing?
    static var textSpeaker: TextSpeaking?
    static var chatTitle: String = "Concierge"
    static var chatSubtitle: String? = "Powered by Adobe"
    static var presentedUIKitController: UIViewController?
    
    var chatView: ChatView? = nil
    
    // MARK: - Extension protocol methods

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
    }

    /// INTERNAL ONLY
    /// used for testing
    init(runtime: ExtensionRuntime, conciergeChatService: ConciergeChatService? = nil) {
        self.runtime = runtime
        super.init()
    }

    public func onRegistered() {
        // register listener for handling concierge request content events
        registerListener(type: Constants.EventType.concierge,
                         source: EventSource.requestContent,
                         listener: handleRequestContentEvent)
    }

    public func onUnregistered() {
        Log.debug(label: Constants.LOG_TAG, "Extension unregistered from MobileCore: \(Constants.FRIENDLY_NAME)")
    }

    public func readyForEvent(_ event: Event) -> Bool {
        // hard dependency on configuration for server and datastream information
        guard let _ = getConfiguration(for: event) else {
            Log.trace(label: Constants.LOG_TAG, "Event processing is paused - waiting for valid configuration.")
            return false
        }
        
        // hard dependency on edge identity module for ecid
        guard let _ = getEdgeIdentitySharedState(for: event) else {
            Log.trace(label: Constants.LOG_TAG, "Event processing is paused - waiting for valid XDM shared state from Edge Identity extension.")
            return false
        }
        
        return true
    }

    // MARK: - Private methods

    private func handleRequestContentEvent(_ event: Event) {
        if event.isShowUiEvent {
            handleShowChatUIRequestEvent(event)
        }
    }
    
    private func handleShowChatUIRequestEvent(_ event: Event) {
        Log.trace(label: Constants.LOG_TAG, "Received show chat UI event - '\(event.id.uuidString)'.")

        // if we run into an error, populate an error message to be logged
        // and send an empty response event in the defer block
        var errorMessage: String? = nil
        defer {
            if let message = errorMessage {
                Log.warning(label: Constants.LOG_TAG, message)
                dispatch(event: createEmptyResponseEvent(for: event))
            }
        }
                
        guard let configSharedState = getConfiguration(for: event) else {
            errorMessage = "Unable to show Brand Concierge UI - Configuration shared state is not available."
            return
        }
        
        guard let edgeIdentitySharedState = getEdgeIdentitySharedState(for: event) else {
            errorMessage = "Unable to show Brand Concierge UI - EdgeIdentity shared state is not available."
            return
        }
        
        guard let ecid = edgeIdentitySharedState.ecid else {
            errorMessage = "Unable to show Brand Concierge UI - ECID is not available in the profile identity map."
            return
        }
        
        // TODO: use server from config
        let server = "edge-int.adobedc.net"
//        guard let server = configSharedState.conciergeServer else {
//            errorMessage = "Unable to show Brand Concierge UI - server information is unavailable from configuration."
//            return
//        }
                
        // TODO: use datastream from config
        let datastream = "6acf9d12-5018-4f84-8224-aac4900782f0"
//        guard let datastream = configSharedState.conciergeDatastream else {
//            errorMessage = "Unable to show Brand Concierge UI - datastream information is unavailable from configuration."
//            return
//        }
        
        // TODO: use surfaces provided in configuration
        let surfaces = ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"]
                
        
        let config = ConciergeConfiguration(server: server, datastream: datastream, ecid: ecid, surfaces: surfaces)
        let responseEvent = event.createResponseEvent(name: Constants.EventName.SHOW_UI_RESPONSE,
                                                      type: Constants.EventType.concierge,
                                                      source: EventSource.responseContent,
                                                      data: [
                                                        Constants.EventData.Key.CONFIG : config
                                                      ])
        dispatch(event: responseEvent)
    }
    
    private func createEmptyResponseEvent(for event: Event) -> Event {
        event.createResponseEvent(name: Constants.EventName.SHOW_UI_RESPONSE,
                                  type: Constants.EventType.concierge,
                                  source: EventSource.responseContent,
                                  data: nil)
    }
    
    private func getConfiguration(for event: Event) -> SharedStateResult? {
        guard let configurationSharedState = getSharedState(extensionName: Constants.SharedState.Configuration.NAME, event: event),
              configurationSharedState.status == .set
        else {
            return nil
        }
        
        return configurationSharedState
    }
    
    private func getEdgeIdentitySharedState(for event: Event) -> SharedStateResult? {
        guard let edgeIdentitySharedState = getXDMSharedState(extensionName: Constants.SharedState.EdgeIdentity.NAME, event: event),
              edgeIdentitySharedState.status == .set
        else {
            return nil
        }
        
        return edgeIdentitySharedState
    }
}
