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
import UIKit

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
    static var containingView: AnyView?
    static var chatTitle: String = "Concierge"
    static var chatSubtitle: String? = "Powered by Adobe"
    static var presentedUIKitController: UIViewController?
    
    let conciergeChatService: ConciergeChatService
    var chatView: ChatView? = nil
    
    // MARK: - Extension protocol methods

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        self.conciergeChatService = ConciergeChatService()
        super.init()
    }

    /// INTERNAL ONLY
    /// used for testing
    init(runtime: ExtensionRuntime, conciergeChatService: ConciergeChatService? = nil) {
        self.runtime = runtime
        self.conciergeChatService = conciergeChatService ?? ConciergeChatService()
        super.init()
    }

    public func onRegistered() {
        // register listener for handling concierge request content events
        registerListener(type: Constants.EventType.concierge,
                         source: EventSource.requestContent,
                         listener: handleEvent)
        
        conciergeChatService.clearConciergeSession()
    }

    public func onUnregistered() {
        Log.debug(label: Constants.LOG_TAG, "Extension unregistered from MobileCore: \(Constants.FRIENDLY_NAME)")
    }

    public func readyForEvent(_ event: Event) -> Bool {
        guard let configurationSharedState = getSharedState(extensionName: Constants.SharedState.Configuration.NAME, event: event),
              configurationSharedState.status == .set
        else {
            Log.trace(label: Constants.LOG_TAG, "Event processing is paused - waiting for valid configuration.")
            return false
        }
        
        // hard dependency on edge identity module for ecid
        guard let edgeIdentitySharedState = getXDMSharedState(extensionName: Constants.SharedState.EdgeIdentity.NAME, event: event),
              edgeIdentitySharedState.status == .set
        else {
            Log.trace(label: Constants.LOG_TAG, "Event processing is paused - waiting for valid XDM shared state from Edge Identity extension.")
            return false
        }
        
        return true
    }

    // MARK: - Private methods

    private func handleEvent(_ event: Event) {
        Log.trace(label: Constants.LOG_TAG, "Received show chat UI event.")
    }
    
    private func hideChatUI() {
        Task { @MainActor in
            // Hide SwiftUI overlay if present
            ConciergeOverlayManager.shared.hideChat()

            // Remove UIKit hosted controller if present
            if let controller = Concierge.presentedUIKitController {
                controller.willMove(toParent: nil)
                controller.view.removeFromSuperview()
                controller.removeFromParent()
                Concierge.presentedUIKitController = nil
            }
        }
    }
}
