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

/// Serializes the identity boundary with context updates and request admission.
/// The generation also invalidates controllers and configuration/auth callbacks retained by hosts.
final class ConciergeIdentityBoundary {
    static let shared = ConciergeIdentityBoundary()
    private let lock = NSRecursiveLock()
    private(set) var generation = 0
    private(set) var ready = true
    private(set) var resetTime: Date?

    func synchronized<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    func admits(_ generation: Int) -> Bool {
        synchronized { ready && self.generation == generation }
    }

    func begin(at date: Date) -> Int {
        synchronized {
            generation &+= 1
            ready = false
            resetTime = date
            return generation
        }
    }

    func complete(_ generation: Int) {
        synchronized {
            if self.generation == generation { ready = true }
        }
    }
}

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
    /// Rebound on active-turn backend session rollover; replaced after idle expiry or chat identity changes.
    @MainActor static var currentSession: ConciergeChatSession?
    @MainActor private static var resetOverlaySurfaces: [String]?
    @MainActor private static var resetUIKitSurfaces: [String]?
    private var resetTeardown: Task<Void, Never>?
    private let pendingRequestQueue = DispatchQueue(label: "com.adobe.concierge.pendingRequests")
    private var pendingRequests: [Event] = []
    // Includes handoffs transferred to MainActor but not yet admitted by a controller.
    // All accesses are serialized with identity changes by ConciergeIdentityBoundary.
    private var unsettledHandoffs: [UUID: (event: Event, generation: Int)] = [:]
    // Edge Identity dispatches uncorrelated completions in its reset-processing order.
    private var resetRequests: [(generation: Int, event: Event)] = []
    private var activeReset: (generation: Int, request: Event, completion: Event)?
    private var readinessRetry: Task<Void, Never>?

    #if DEBUG
    /// Pauses a readiness decision in deterministic concurrency tests, on the request queue.
    var pendingRequestReadinessCheckedForTesting: ((Event, Bool) -> Void)?
    var handoffTaskGateForTesting: ((Event) async -> Void)?
    var handoffTaskFinishedForTesting: ((Event) -> Void)?

    func flushPendingRequestsForTesting(completion: @escaping () -> Void) {
        pendingRequestQueue.async(execute: completion)
    }

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
        registerListener(type: EventType.genericIdentity, source: EventSource.requestReset,
                         listener: handleIdentityReset)
        registerListener(type: EventType.edgeIdentity, source: EventSource.resetComplete,
                         listener: handleIdentityResetComplete)
        registerListener(type: EventType.hub, source: EventSource.sharedState) { [weak self] _ in
            self?.attemptIdentityResetReadiness()
            self?.processPendingRequests()
        }
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
        readinessRetry?.cancel()
        Log.debug(label: ConciergeConstants.LOG_TAG, "Extension unregistered from MobileCore: \(ConciergeConstants.FRIENDLY_NAME)")
    }

    public func readyForEvent(_ event: Event) -> Bool {
        // Core queues *all* events for an extension, including events without listeners.
        // Waiting here can strand reset behind an unrelated pending Configuration event.
        // Only content requests wait, in our own queue; reset and state updates always advance.
        return true
    }

    // MARK: - Private Methods

    private func handleIdentityReset(_ event: Event) {
        let boundary = ConciergeIdentityBoundary.shared
        let snapshot = boundary.synchronized { () -> (Int, String?, Bool) in
            activeReset = nil
            readinessRetry?.cancel()
            readinessRetry = nil
            let generation = boundary.begin(at: event.timestamp)
            resetRequests.append((generation, event))
            let sessionID = SessionManager.shared.currentSessionId
            let hadContext = ConciergeXDMContextStore.shared.hasContext
            SessionManager.shared.clearSession()
            ConciergeXDMContextStore.shared.clear()
            return (generation, sessionID, hadContext)
        }
        let precedingTeardown = resetTeardown
        resetTeardown = Task { @MainActor in
            await precedingTeardown?.value
            let overlay = ConciergeOverlayManager.shared
            let hosted = Concierge.presentedUIKitController as? ConciergeHostingController
            Concierge.resetOverlaySurfaces = overlay.chatView?.identityResetController.configuration?.surfaces
            Concierge.resetUIKitSurfaces = hosted?.chatController.configuration?.surfaces
            var controllers = [ChatController]()
            for controller in [Concierge.currentSession?.controller,
                               overlay.chatView?.identityResetController, hosted?.chatController].compactMap({ $0 })
                where !controllers.contains(where: { $0 === controller }) {
                controllers.append(controller)
            }
            let hadActiveTurn = controllers.contains { $0.isProcessing }
            let conversationID = controllers.compactMap { $0.conversationID }.last
            let hadConversation = snapshot.1 != nil || snapshot.2 ||
                controllers.contains { $0.hasConversationStarted } || hadActiveTurn
            controllers.forEach { $0.endConversationForIdentityReset() }
            Concierge.currentSession = nil
            // Await an actual owner-queue drain, including any drain already in progress.
            // Deferred old-user callbacks must settle before ended/readiness is published.
            await withCheckedContinuation { continuation in
                self.processPendingRequests { continuation.resume() }
            }
            self.settleOldHandoffs(before: snapshot.0)
            if hadConversation {
                self.dispatch(event: ConciergeTrackingEvent.conversationEnded(
                    epochTime: Int64(Date().timeIntervalSince1970 * 1000),
                    sessionId: snapshot.1, conversationId: conversationID,
                    hadActiveTurn: hadActiveTurn
                ).toEvent())
            }
        }
    }

    private func handleIdentityResetComplete(_ event: Event) {
        let boundary = ConciergeIdentityBoundary.shared
        boundary.synchronized {
            guard let first = resetRequests.first, event.timestamp >= first.event.timestamp else { return }
            let reset = resetRequests.removeFirst()
            guard !boundary.ready, reset.generation == boundary.generation else { return }
            activeReset = (reset.generation, reset.event, event)
        }
        attemptIdentityResetReadiness()
    }

    private func attemptIdentityResetReadiness() {
        let boundary = ConciergeIdentityBoundary.shared
        boundary.synchronized {
            guard let reset = activeReset, !boundary.ready, readinessRetry == nil else { return }
            let teardown = resetTeardown
            readinessRetry = Task { @MainActor [weak self] in
                await teardown?.value
                guard let self else { return }
                // Re-read after teardown, and retry without blocking the Event Hub or UI.
                // Configuration/consent use current state, identity retains reset provenance.
                while !Task.isCancelled {
                    guard boundary.synchronized({ !boundary.ready && boundary.generation == reset.generation }) else { return }
                    let resetIdentity = self.getXDMSharedState(
                        extensionName: ConciergeConstants.SharedState.EdgeIdentity.NAME,
                        event: reset.request, barrier: true)
                    let completionIdentity = self.getEdgeIdentitySharedState(for: reset.completion)
                    let identity = self.getEdgeIdentitySharedState(for: nil)
                    let configState = self.getConfiguration(for: nil)
                    guard resetIdentity?.status == .set,
                          let ecid = resetIdentity?.ecid, !ecid.isEmpty,
                          completionIdentity?.ecid == ecid, identity?.ecid == ecid,
                          let server = configState?.conciergeServer, !server.isEmpty,
                          let datastream = configState?.conciergeDatastream, !datastream.isEmpty else {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        continue
                    }
                    let consent = self.getConsentSharedState(for: nil)?.collectValue ?? ConciergeConstants.Defaults.CONSENT_VALUE
                    boundary.synchronized {
                        guard !Task.isCancelled, boundary.generation == reset.generation, !boundary.ready else { return }
                        let overlay = ConciergeOverlayManager.shared
                        let parent = Concierge.presentedUIKitController?.parent
                        let uikitHidden = Concierge.presentedUIKitController?.viewIfLoaded?.isHidden ?? false
                        boundary.complete(reset.generation)
                        func configuration(_ surfaces: [String]) -> ConciergeConfiguration {
                            ConciergeConfiguration(consentCollectValue: consent, datastream: datastream,
                                ecid: ecid, identityMap: identity?.identityMap, server: server,
                                region: configState?.conciergeRegion, surfaces: surfaces)
                        }
                        if let surfaces = Concierge.resetOverlaySurfaces {
                            let session = Concierge.resolveSession(configuration: configuration(surfaces), preservingContext: true)
                            overlay.replaceChat(Concierge.makeChatView(session: session))
                        }
                        if let parent, let surfaces = Concierge.resetUIKitSurfaces {
                            Concierge.attachConciergeUIKitHost(configuration: configuration(surfaces),
                                presentingViewController: parent, preservingContext: true)
                            Concierge.presentedUIKitController?.view.isHidden = uikitHidden
                        }
                    }
                    return
                }
            }
        }
    }

    private func handleRequestContentEvent(_ event: Event) {
        pendingRequestQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRequests.append(event)
            self.drainPendingRequests()
        }
    }

    private func processPendingRequests(afterDrain completion: (() -> Void)? = nil) {
        // All triggers enqueue on the same owner. A notification arriving during a drain
        // remains queued even if that drain's already-read readiness decision is pending.
        pendingRequestQueue.async { [weak self] in
            self?.drainPendingRequests()
            completion?()
        }
    }

    private func drainPendingRequests() {
        dispatchPrecondition(condition: .onQueue(pendingRequestQueue))
        while let event = pendingRequests.first {
            let waiting = admitsRequest(event) &&
                (getConfiguration(for: event) == nil || getEdgeIdentitySharedState(for: event)?.ecid == nil)
            #if DEBUG
            pendingRequestReadinessCheckedForTesting?(event, waiting)
            #endif
            if waiting { return }
            pendingRequests.removeFirst()
            processRequestContentEvent(event)
        }
    }

    private func processRequestContentEvent(_ event: Event) {
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
        guard admitsRequest(event) else {
            errorMessage = "Unable to show Brand Concierge UI - identity reset is in progress or request is stale."
            return
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

        guard admitsRequest(event) else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .noActiveSession))
            return
        }
        let generation = ConciergeIdentityBoundary.shared.synchronized { ConciergeIdentityBoundary.shared.generation }
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

        let boundary = ConciergeIdentityBoundary.shared
        let registered = boundary.synchronized { () -> Bool in
            guard boundary.admits(generation), admitsRequest(event) else { return false }
            unsettledHandoffs[event.id] = (event, generation)
            return true
        }
        guard registered else {
            dispatch(event: createDataHandoffResponseEvent(for: event, error: .noActiveSession))
            return
        }
        #if DEBUG
        let taskGate = handoffTaskGateForTesting
        let taskFinished = handoffTaskFinishedForTesting
        #endif
        Task { @MainActor in
            #if DEBUG
            defer { taskFinished?(event) }
            await taskGate?(event)
            #endif
            guard boundary.synchronized({ unsettledHandoffs[event.id]?.generation == generation }) else { return }
            // `resolveSession` gates reuse on `isSessionActive`, so a handoff has to clear the same
            // bar - an expired session's controller is still in memory but no longer valid.
            guard ConciergeIdentityBoundary.shared.admits(generation),
                  let controller = Concierge.currentSession?.controller,
                  SessionManager.shared.isSessionActive else {
                settleHandoff(event, generation: generation, error: .noActiveSession)
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
                let error: ConciergeDataHandoffError?
                if !ConciergeIdentityBoundary.shared.admits(generation) {
                    error = .noActiveSession
                } else {
                    error = serviceError.map { ConciergeDataHandoffError(serviceError: $0) }
                }
                self.settleHandoff(event, generation: generation, error: error)
            }

            guard started else {
                settleHandoff(event, generation: generation, error: .chatInProgress)
                return
            }
        }

    }

    @MainActor
    private func settleHandoff(_ event: Event, generation: Int, error: ConciergeDataHandoffError?) {
        let boundary = ConciergeIdentityBoundary.shared
        let claimed = boundary.synchronized { () -> Bool in
            guard unsettledHandoffs[event.id]?.generation == generation else { return false }
            unsettledHandoffs.removeValue(forKey: event.id)
            return true
        }
        guard claimed else { return }
        let resolvedError = boundary.admits(generation) ? error : .noActiveSession
        dispatch(event: createDataHandoffResponseEvent(for: event, error: resolvedError))
    }

    @MainActor
    private func settleOldHandoffs(before generation: Int) {
        let old = ConciergeIdentityBoundary.shared.synchronized {
            let old = unsettledHandoffs.values.filter { $0.generation < generation }
            for handoff in old { unsettledHandoffs.removeValue(forKey: handoff.event.id) }
            return old
        }
        // MainActor settlement has no suspension between claiming and dispatching a response.
        // A later task/callback finds no ledger entry and cannot respond or start transport again.
        for handoff in old {
            dispatch(event: createDataHandoffResponseEvent(for: handoff.event, error: .noActiveSession))
        }
    }

    private func admitsRequest(_ event: Event) -> Bool {
        let boundary = ConciergeIdentityBoundary.shared
        return boundary.synchronized {
            boundary.ready && event.timestamp >= (boundary.resetTime ?? .distantPast)
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

    private func getConfiguration(for event: Event?) -> SharedStateResult? {
        guard let configurationSharedState = getSharedState(extensionName: ConciergeConstants.SharedState.Configuration.NAME, event: event),
              configurationSharedState.status == .set
        else {
            return nil
        }

        return configurationSharedState
    }

    private func getEdgeIdentitySharedState(for event: Event?) -> SharedStateResult? {
        guard let edgeIdentitySharedState = getXDMSharedState(extensionName: ConciergeConstants.SharedState.EdgeIdentity.NAME, event: event),
              edgeIdentitySharedState.status == .set
        else {
            return nil
        }

        return edgeIdentitySharedState
    }

    private func getConsentSharedState(for event: Event?) -> SharedStateResult? {
        guard let consentSharedState = getXDMSharedState(extensionName: ConciergeConstants.SharedState.Consent.NAME, event: event),
              consentSharedState.status == .set
        else {
            return nil
        }

        return consentSharedState
    }
}
