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

import Foundation
import SwiftUI
import Combine
import AEPCore
import AEPServices

/// Main controller orchestrating chat functionality.
/// Manages messages, chat state, and coordinates between services.
@MainActor
final class ChatController: ObservableObject {
    // MARK: - Published State

    @Published var messages: [Message] = []
    @Published private(set) var chatState: ChatState = .idle
    @Published var userScrollTick: Int = 0
    @Published var userMessageToScrollId: UUID?
    @Published var showPermissionDialog: Bool = false
    @Published var audioLevel: Float = 0

    /// Mirror of `inputController.state`, updated only on state transitions (not per-keystroke text
    /// changes). Lets views react to input state without observing `InputController` directly.
    @Published private(set) var composerState: InputState = .empty

    /// Copy rendered into the transcript when a turn fails. Pushed in from the view's theme (see
    /// `ChatView`) because the theme lives in the SwiftUI environment rather than on the session.
    var networkErrorMessage: String = ConciergeCopy.defaultErrorNetwork

    // MARK: - Input Controller

    let inputController = InputController()

    var inputText: String { inputController.data.text }
    var inputState: InputState { inputController.state }

    // MARK: - Private Properties

    private let LOG_TAG = "ChatController"
    private let chatService: ConciergeChatService
    private let configuration: ConciergeConfiguration?
    private let speechController: SpeechController
    private let dispatch: ((_ event: Event) -> Void)?

    private var welcomeMessagesLoaded: Bool = false

    /// The turn currently in flight, or `nil` when the chat is idle. At most one exists at a time:
    /// `ConciergeChatService` keeps a single `dataTask`/handler pair per instance, so a second
    /// concurrent turn would strand the first one's completion.
    ///
    /// This is the controller's single source of truth for "is a turn running", and the only writer
    /// of `chatState`. Chat state used to be assigned from every path that started or ended a turn,
    /// and a path that ended one without assigning left the chat parked in `.processing` with a
    /// dead composer - the failure mode behind several of this feature's bugs. Deriving it here
    /// makes that state unreachable: there is nowhere left to end a turn without also going idle.
    private var activeTurn: ChatTurn? {
        didSet { chatState = activeTurn == nil ? .idle : .processing }
    }

    /// Injectable so tests can exercise the caps without waiting out the production values.
    private let handoffFirstChunkTimeout: TimeInterval
    private let handoffTurnTimeout: TimeInterval

    private var latestSources: [Source] = []
    private var latestLinkHints: [LinkHint] = []
    private var latestPromptSuggestions: [String] = []
    private var chatOpenTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isRecording: Bool { inputState == .recording }
    var isProcessing: Bool { chatState == .processing }
    var composerEditable: Bool { chatState != .processing }
    var micEnabled: Bool { chatState == .idle }
    var sendEnabled: Bool { chatState == .idle && inputController.data.canSend }

    /// Whether the transcript holds at least one real turn. Welcome content doesn't count.
    ///
    /// Deliberately not "has the *user* sent a message": a data handoff appends only agent-styled
    /// messages, so a checkout-driven conversation would otherwise still look untouched.
    var hasConversationStarted: Bool {
        messages.contains { message in
            switch message.template {
            case .welcomeHeader, .welcomePromptSuggestion:
                return false
            default:
                return true
            }
        }
    }

    // MARK: - Initialization

    init(configuration: ConciergeConfiguration, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?, dispatch: ((_ event: Event) -> Void)? = nil, urlSessionConfiguration: URLSessionConfiguration = .default) {
        self.configuration = configuration
        self.chatService = ConciergeChatService(configuration: configuration, urlSessionConfiguration: urlSessionConfiguration)
        self.speechController = SpeechController(capturer: speechCapturer, speaker: speaker)
        self.dispatch = dispatch
        self.handoffTurnTimeout = ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT
        self.handoffFirstChunkTimeout = ConciergeConstants.Request.DATA_HANDOFF_FIRST_CHUNK_TIMEOUT

        configureSpeech()
        observeComposerState()
    }

    #if DEBUG
    // Internal for testing only
    init(configuration: ConciergeConfiguration?, chatService: ConciergeChatService, speechCapturer: SpeechCapturing?, speaker: TextSpeaking?, dispatch: ((_ event: Event) -> Void)? = nil, handoffTurnTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_TURN_TIMEOUT, handoffFirstChunkTimeout: TimeInterval = ConciergeConstants.Request.DATA_HANDOFF_FIRST_CHUNK_TIMEOUT) {
        self.configuration = configuration
        self.chatService = chatService
        self.speechController = SpeechController(capturer: speechCapturer, speaker: speaker)
        self.dispatch = dispatch
        self.handoffTurnTimeout = handoffTurnTimeout
        self.handoffFirstChunkTimeout = handoffFirstChunkTimeout

        configureSpeech()
        observeComposerState()
    }
    #endif

    // MARK: - Input Handling

    private func observeComposerState() {
        inputController.$state
            .sink { [weak self] newState in
                self?.composerState = newState
            }
            .store(in: &cancellables)
    }

    func applyTextChange(_ newText: String) {
        inputController.applyTextChange(newText)
    }

    // MARK: - Speech Output

    func speak(_ text: String) {
        speechController.speak(text)
    }

    // MARK: - Mic Control

    /// Applies voice capture settings from the current theme before recording starts.
    func applyVoiceInputBehavior(_ input: ConciergeInputBehavior) {
        speechController.configureSilenceDetection(threshold: input.silenceThreshold, duration: input.silenceDuration)
    }

    func toggleMic(currentSelectionLocation: Int) {
        if isRecording { completeMic() } else { startRecording(currentSelectionLocation: currentSelectionLocation) }
    }

    func cancelMic() {
        guard isRecording else {
            Log.warning(label: LOG_TAG, "cancelMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputController.apply(.cancelRecording)
        speechController.endCapture { _, _ in }
    }

    func completeMic() {
        guard isRecording else {
            Log.warning(label: LOG_TAG, "completeMic ignored. Expected inputState to be 'recording', but was '\(inputState)'.")
            return
        }
        inputController.apply(.recordingComplete)
        speechController.endCapture { [weak self] transcript, _ in
            Task { @MainActor in
                if let transcript = transcript, !transcript.isEmpty {
                    self?.inputController.apply(.transcriptionComplete(transcript))
                } else {
                    self?.inputController.apply(.transcriptionError("empty transcript"))
                }
            }
        }
    }

    func startRecording(currentSelectionLocation: Int) {
        guard chatState == .idle else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }
        guard inputState == .empty || inputState == .editing || {
            if case .error = inputState { return true } else { return false }
        }() else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Expected inputState to be 'empty' or 'editing', but was '\(inputState)'.")
            return
        }
        guard speechController.isCapturerAvailable else {
            Log.warning(label: LOG_TAG, "startRecording ignored. Speech capturer instance is nil.")
            return
        }

        // Only request permissions if the user has never been asked before
        if speechController.hasNeverBeenAskedForPermission {
            Log.debug(label: LOG_TAG, "Requesting speech and microphone permissions for the first time.")
            speechController.requestPermissions { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    // After user responds to system prompts, check if permissions were granted
                    if self.speechController.isAvailable {
                        Log.debug(label: self.LOG_TAG, "Permissions granted. Starting recording.")
                        self.beginCaptureSession(currentSelectionLocation: currentSelectionLocation)
                    } else {
                        Log.debug(label: self.LOG_TAG, "Permissions not granted after request. Showing permission dialog.")
                        self.showPermissionDialog = true
                    }
                }
            }
            return
        }

        // Always check if permissions are available before proceeding
        if !speechController.isAvailable {
            // Permissions were asked but not granted - show custom dialog
            Log.debug(label: LOG_TAG, "Speech or microphone permissions not granted. Showing permission dialog.")
            showPermissionDialog = true
            return
        }

        // Permissions granted - proceed with recording
        beginCaptureSession(currentSelectionLocation: currentSelectionLocation)
    }

    private func beginCaptureSession(currentSelectionLocation: Int) {
        speechController.setAudioLevelHandler { [weak self] level in
            self?.audioLevel = level
        }
        speechController.setSilenceHandler { [weak self] in
            self?.completeMic()
        }
        inputController.apply(.startMic(currentSelectionLocation: currentSelectionLocation))
        speechController.beginCapture()
    }

    // MARK: - Permission Dialog

    func dismissPermissionDialog() {
        showPermissionDialog = false
    }

    func requestOpenSettings() {
        showPermissionDialog = false
    }

    // MARK: - Message Sending

    func sendMessage(isUser: Bool) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            Log.warning(label: LOG_TAG, "sendMessage ignored. Expected non-empty text, but was empty.")
            return
        }
        guard chatState == .idle else {
            Log.warning(label: LOG_TAG, "sendMessage ignored. Expected chatState to be 'idle', but was '\(chatState)'.")
            return
        }

        if isRecording { completeMic() }

        // Clear input via controller to keep state machine consistent
        inputController.apply(.sendMessage)

        let newMessage = Message(template: .basic(isUserMessage: isUser), messageBody: text)
        messages.append(newMessage)

        if isUser {
            // Store the user message ID first
            scrollToTop(messageId: newMessage.id)
        }

        if isUser {
            dispatchTrackingEvent(.querySubmitted(query: text))
            streamAgentResponse(for: text)
        } else {
            clearState()
        }
    }

    /// Forwards an app-originated data-handoff turn (e.g. a checkout outcome) to Brand Concierge.
    /// The routing hint never renders; only `localMessage` and the eventual reply do. The turn is
    /// scrolled to the top like `sendMessage` does, since a handoff is triggered from app UI rather
    /// than the composer and the transcript would otherwise stay where the user left it.
    ///
    /// Returns `false` without starting anything when a turn is already in flight:
    /// `ConciergeChatService` keeps a single `dataTask`/handler pair per instance, so a second
    /// concurrent turn would strand the first one's completion. `.error` is *not* in flight.
    @discardableResult
    func handleDataHandoff(routingHint: String,
                           xdmFields: [String: Any],
                           localMessage: String? = nil,
                           completion: ((ConciergeError?) -> Void)? = nil) -> Bool {
        guard activeTurn == nil else {
            Log.warning(label: LOG_TAG, "handleDataHandoff ignored. A Concierge turn is already in progress.")
            return false
        }

        var anchorMessageId: UUID?
        if let localMessage, !localMessage.isEmpty {
            let message = Message(template: .basic(isUserMessage: false), messageBody: localMessage)
            messages.append(message)
            anchorMessageId = message.id
        }

        let kind = TurnKind.handoff(noResponse: handoffFirstChunkTimeout, ceiling: handoffTurnTimeout)
        let turn = streamAgentResponse(for: routingHint, extraXDMFields: xdmFields,
                                       kind: kind, completion: completion)

        // `streamAgentResponse` appends its placeholder synchronously, so with no local message
        // that placeholder is the turn's anchor instead.
        scrollToTop(messageId: anchorMessageId ?? turn.placeholderId)
        return true
    }

    /// Ends `turn` because one of its deadlines elapsed.
    ///
    /// The unwind must not depend on the cancellation below. Until the turn's auth token resolves
    /// there is no `dataTask` to cancel, and cancelling nothing reports nothing - which left the
    /// chat parked in `.processing` with a dead composer. Unwinding here directly makes it
    /// unconditional, and dropping the turn drops the late callbacks that would otherwise revive it.
    private func cap(_ turn: ChatTurn, after interval: TimeInterval, reason: String) {
        guard activeTurn === turn else { return }
        Log.warning(label: LOG_TAG, "Data handoff turn \(reason).")

        turn.resolve(.timeout(Int(interval)))
        discardPlaceholder(of: turn)
        endTurn(turn)
        chatService.cancelActiveStream()
    }

    /// Removes `turn`'s streaming placeholder from the transcript, if it is still there.
    ///
    /// Looked up by id: the transcript shifts under a turn as cards and suggestions are appended,
    /// so an index captured when the turn started may no longer point at its own message.
    private func discardPlaceholder(of turn: ChatTurn) {
        guard let index = messages.firstIndex(where: { $0.id == turn.placeholderId }) else { return }
        messages.remove(at: index)
    }

    /// Releases `turn` if it is still the live one, returning the chat to idle.
    ///
    /// Guarded by identity so a superseded turn's late callback cannot clear the state belonging to
    /// whichever turn is running now.
    private func endTurn(_ turn: ChatTurn) {
        guard activeTurn === turn else { return }
        clearState()
    }

    #if DEBUG
    /// Test seam: renders a given chat state without running a real turn.
    ///
    /// Production has exactly one writer of `chatState` - see `activeTurn` - which is the point of
    /// the property being `private(set)`. View snapshots still need to draw a state directly, and
    /// this makes that an explicit, test-only exception rather than a hole in the invariant.
    func setChatStateForTesting(_ state: ChatState) {
        chatState = state
    }
    #endif

    /// Abandons the turn in flight, if any, returning the chat to idle.
    ///
    /// Replaces a direct `chatState = .idle` write from the view layer. Forcing the state flag
    /// alone left the turn running: it went on streaming into a transcript the composer was now
    /// live against, and its caller was never told. Ending the turn properly reports it, removes
    /// its placeholder and releases the request.
    ///
    /// Discarding the placeholder is deliberate for *both* turn kinds, not just `.handoff`. A
    /// typed turn's placeholder may already hold partial text, and that text is an answer to a
    /// question the chat is no longer in a position to finish - leaving a truncated reply behind
    /// with no indication it was cut short reads as a complete answer. Note this is currently
    /// unreachable: the only caller is `ChatView`'s `onToggleMode`, and `ChatTopBar` never invokes
    /// it because its `body` doesn't render the toggle.
    func abandonActiveTurn() {
        guard let turn = activeTurn else { return }
        turn.resolve(.unknown)
        discardPlaceholder(of: turn)
        endTurn(turn)
        chatService.cancelActiveStream()
    }

    /// Scrolls the transcript so `messageId` sits at the top, leaving the rest of the screen for
    /// the response that follows.
    ///
    /// The tick is bumped on the next main-queue pass so the id is published *before* the change
    /// `MessageListView` observes; a same-pass update would scroll to the previous turn's anchor.
    private func scrollToTop(messageId: UUID) {
        userMessageToScrollId = messageId
        DispatchQueue.main.async {
            self.userScrollTick &+= 1
        }
    }

    // MARK: - Welcome Content

    /// Loads initial welcome header and examples if not already loaded.
    func loadWelcomeIfNeeded(theme: ConciergeTheme) async {
        // Prevent loading if already loaded OR if messages is not empty
        guard !welcomeMessagesLoaded && messages.isEmpty else { return }
        welcomeMessagesLoaded = true

        // Prefer welcome content provided by the theme when available.
        let title = theme.copy.welcomeHeading
        let body = theme.copy.welcomeSubheading
        let examples = theme.welcomeExamples

        if !title.isEmpty || !body.isEmpty {
            messages.append(Message(template: .welcomeHeader(title: title, body: body)))
        }

        if !examples.isEmpty {
            for example in examples {
                let url = example.image.flatMap { URL(string: $0) }
                let background = example.backgroundColor?.color ?? Color(UIColor.secondarySystemBackground)
                let message = Message(
                    template: .welcomePromptSuggestion(
                        imageSource: .remote(url),
                        text: example.text,
                        background: background
                    )
                )
                messages.append(message)
            }
        }

        dispatchTrackingEvent(.sessionInitialized)
    }

    // MARK: - Feedback

    func sendFeedbackFor(messageId: UUID?, with feedbackPayload: FeedbackPayload) {
        guard let messageId = messageId, let index = messages.firstIndex(where: { $0.id == messageId }) else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, the message was not retrievable from the chat.")
            return
        }

        guard let configuration = configuration else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, configuration is not available.")
            return
        }

        // Get the message information for which feedback was provided
        var currentMessage = messages[index]

        guard let messagePayload = currentMessage.payload else {
            Log.debug(label: LOG_TAG, "Unable to send feedback, message payload is not available.")
            return
        }

        // Attach sentiment
        currentMessage.feedbackSentiment = feedbackPayload.sentiment

        // Write the updated message back to the array so UI updates
        messages[index] = currentMessage

        // Generate an edge event to track the feedback
        let feedbackEventData: [String: Any] = [
            ConciergeConstants.Request.Keys.XDM: [
                ConciergeConstants.Request.Keys.EVENT_TYPE: ConciergeConstants.Request.EventType.CONVERSATION_FEEDBACK,
                // Forward identityMap verbatim; falls back to an ECID-only map
                ConciergeConstants.Request.Keys.IDENTITY_MAP: configuration.identityMapPayload,
                ConciergeConstants.Request.Keys.CONVERSATION: [
                    ConciergeConstants.Request.Keys.Feedback.FEEDBACK: [
                        ConciergeConstants.Request.Keys.Feedback.SOURCE: ConciergeConstants.Request.Values.Feedback.END_USER,
                        ConciergeConstants.Request.Keys.Feedback.RAW: [
                            [
                                ConciergeConstants.Request.Keys.Feedback.TEXT: feedbackPayload.notes,
                                ConciergeConstants.Request.Keys.Feedback.PURPOSE: ConciergeConstants.Request.Values.Feedback.USER_INPUT
                            ]
                        ],
                        ConciergeConstants.Request.Keys.Feedback.RATING: [
                            ConciergeConstants.Request.Keys.Feedback.SCORE: feedbackPayload.sentiment == .positive ? 1 : 0,
                            ConciergeConstants.Request.Keys.Feedback.CLASSIFICATION: feedbackPayload.sentiment.thumbsValue(),
                            ConciergeConstants.Request.Keys.Feedback.REASONS: feedbackPayload.selectedOptions
                        ]
                    ],
                    ConciergeConstants.Request.Keys.Feedback.CONVERSATION_ID: messagePayload.conversationId ?? "unknown",
                    ConciergeConstants.Request.Keys.Feedback.TURN_ID: messagePayload.interactionId ?? "unknown"
                ]
            ]
        ]

        Task { [weak self] in
            guard let self else { return }
            let token = await ConciergeAuthTokenResolver.shared.resolveToken()
            self.chatService.sendFeedback(data: feedbackEventData, token: token)
        }

        dispatchTrackingEvent(.feedbackSubmitted(
            conversationId: messagePayload.conversationId ?? "unknown",
            interactionId: messagePayload.interactionId ?? "unknown",
            feedbackType: feedbackPayload.sentiment == .positive ? "positive" : "negative",
            selectedOptions: feedbackPayload.selectedOptions,
            notes: feedbackPayload.notes
        ))
    }

    // MARK: - Tracking

    func trackChatOpened() {
        let now = Date()
        chatOpenTime = now
        let epochTime = Int64(now.timeIntervalSince1970 * 1000)
        dispatchTrackingEvent(.chatOpened(epochTime: epochTime))
    }

    func trackChatClosed() {
        let now = Date()
        let epochTime = Int64(now.timeIntervalSince1970 * 1000)
        let durationMillis = chatOpenTime.map { Int64(now.timeIntervalSince($0) * 1000) } ?? 0
        chatOpenTime = nil
        dispatchTrackingEvent(.chatClosed(epochTime: epochTime, durationMillis: durationMillis))
    }

    func trackPromptSuggestionClicked(suggestion: String) {
        dispatchTrackingEvent(.promptSuggestionClicked(suggestion: suggestion))
    }

    func trackWelcomePromptSuggestionClicked(suggestion: String) {
        dispatchTrackingEvent(.welcomePromptSuggestionClicked(suggestion: suggestion))
    }

    func trackMicButtonClicked() {
        dispatchTrackingEvent(.micButtonClicked)
    }

    func trackDisclaimerLinkClicked(url: URL) {
        dispatchTrackingEvent(.disclaimerLinkClicked(url: url.absoluteString))
        trackLinkClicked(url: url.absoluteString, origin: ConciergeConstants.TrackingEvent.LinkClickOrigin.DISCLAIMER)
    }

    func trackCtaButtonClicked(label: String, url: String) {
        dispatchTrackingEvent(.ctaButtonClicked(label: label, linkUrl: url))
        trackLinkClicked(url: url, origin: ConciergeConstants.TrackingEvent.LinkClickOrigin.CTA)
    }

    func trackCardClicked(cardData: ProductCardData) {
        var element: [String: Any] = ["productName": cardData.title]
        if let subtitle = cardData.subtitle { element["productDescription"] = subtitle }
        if let url = cardData.destinationURL?.absoluteString { element["productPageURL"] = url }
        if let price = cardData.price { element["productPrice"] = price }
        if let badge = cardData.badge { element["productBadge"] = badge }
        dispatchTrackingEvent(.cardClicked(element: element))
        if let url = cardData.destinationURL?.absoluteString {
            trackLinkClicked(url: url, origin: ConciergeConstants.TrackingEvent.LinkClickOrigin.PRODUCT_CARD)
        }
    }

    func trackLinkClicked(url: String, origin: String) {
        dispatchTrackingEvent(.linkClicked(url: url, origin: origin))
    }

    private func dispatchTrackingEvent(_ trackingEvent: ConciergeTrackingEvent) {
        let event = trackingEvent.toEvent()
        Log.debug(label: LOG_TAG, "Dispatching tracking event - name: \(event.name), type: \(event.type), source: \(event.source), data: \(event.data ?? [:])")
        dispatch?(event)
    }

    // MARK: - Private Methods

    private func configureSpeech() {
        speechController.configureForStreaming { [weak self] text in
            Task { @MainActor in
                self?.inputController.apply(.streamingPartial(text))
            }
        }
    }

    /// Starts a turn: appends its streaming placeholder, sends the query, and streams the reply
    /// back into that placeholder. Returns the turn, which becomes the controller's `activeTurn`.
    ///
    /// `kind` decides the two ways turns differ - whether failures render, and whether the turn is
    /// bounded. See `TurnKind`.
    @discardableResult
    private func streamAgentResponse(for query: String,
                                     extraXDMFields: [String: Any]? = nil,
                                     kind: TurnKind = .typed,
                                     completion: ((ConciergeError?) -> Void)? = nil) -> ChatTurn {
        let placeholder = Message(template: .basic(isUserMessage: false), messageBody: "")
        messages.append(placeholder)

        let turn = ChatTurn(placeholderId: placeholder.id, kind: kind, outcome: completion)
        activeTurn = turn

        // Armed from submission, so it also bounds the auth-token wait below.
        turn.armCeiling { [weak self] interval in
            self?.cap(turn, after: interval, reason: "exceeded its wall-clock cap")
        }

        // Accumulators are used to handle the progressive building up of response content from the server
        // and to be able to effectively do a diff of what has already been received and what is new.
        var accumulatedContent = ""
        var latestElements: [MultimodalElement] = []
        var responseStartedDispatched = false

        // Resolve the auth token off the UI thread, then send the turn on the main actor.
        //
        // `self` is captured strongly on purpose: an app that drops its reference to the chat
        // mid-turn has not cancelled the turn, and the request still has to go out and be reported.
        // A weak capture would abandon it the moment the caller let go. The hold is bounded by one
        // turn. `turn` is held strongly for the same reason - it owns the caller's completion.
        Task { [self] in
            let token = await ConciergeAuthTokenResolver.shared.resolveToken()

            // A deadline may have fired while the token resolved. Sending the request now would
            // render a reply into a turn whose caller has already been told it failed - but the
            // caller is still owed an answer either way, so the turn reports here. `resolve` is
            // idempotent, so a turn a deadline already ended keeps that more specific outcome.
            guard self.activeTurn === turn else {
                Log.debug(label: self.LOG_TAG, "Turn abandoned before it reached the service; not sending.")
                turn.resolve(.unknown)
                return
            }
            turn.armNoResponseCap { [weak self] interval in
                self?.cap(turn, after: interval, reason: "produced no response")
            }
            self.chatService.streamChat(query, token: token, extraXDMFields: extraXDMFields,
            onChunk: { [weak self] payload in
                Task { @MainActor in
                    guard let self = self, self.activeTurn === turn else { return }

                    // The service is alive, so the fast "never answered" cap has done its job.
                    //
                    // Deliberately *any* chunk, including a content-free heartbeat, rather than the
                    // `hasVisibleContent` gate used a few lines below for `responseStarted`. The two
                    // answer different questions: this one asks "is the backend wedged?", which a
                    // heartbeat disproves, while that one asks "is there something to show the
                    // user?". Cancelling a turn that is demonstrably alive but still warming up
                    // would be worse than letting the ceiling bound it, and a backend that
                    // heartbeats forever without ever answering is still caught there. Matches
                    // Android, which stands its first-chunk cap down on any emission for the same
                    // reason.
                    turn.noteResponseStarted()

                    let state = payload.state

                    // Serializing + pretty-printing the response is only useful for local debugging,
                    #if DEBUG
                    if let response = payload.response {
                        if let data = try? JSONEncoder().encode(response),
                           let json = String(data: data, encoding: .utf8) {
                            Log.debug(label: self.LOG_TAG, "SSE chunk (state=\(state ?? "n/a")): \(json.prettyPrintedJSON())")
                        }
                    } else {
                        Log.debug(label: self.LOG_TAG, "SSE chunk: state=\(state ?? "n/a") (no response)")
                    }
                    #endif

                    // Dispatch responseStarted exactly once per turn, on the first chunk that
                    // carries any user-visible content (text OR multimodal elements). Mirrors
                    // the Android `hasVisibleContent` gate so cards-only responses still produce
                    // a paired responseStarted/responseCompleted, and pure heartbeat chunks
                    // (response present but empty) do not.
                    let chunkMessage = payload.response?.message ?? ""
                    let chunkElements = payload.response?.multimodalElements?.elements ?? []
                    let hasVisibleContent = !chunkMessage.isEmpty || !chunkElements.isEmpty
                    if hasVisibleContent && !responseStartedDispatched {
                        responseStartedDispatched = true
                        self.dispatchTrackingEvent(.responseStarted(
                            conversationId: payload.conversationId ?? "unknown",
                            interactionId: payload.interactionId ?? "unknown"
                        ))
                    }

                    // Handle messages
                    if let message = payload.response?.message {
                        if state == ConciergeConstants.StreamState.IN_PROGRESS {
                            accumulatedContent += message
                            Log.trace(label: self.LOG_TAG, "SSE chunk (len=\(message.count)): \"\(message)\"")
                            Log.trace(label: self.LOG_TAG, "Accumulated (len=\(accumulatedContent.count))")

                            // Update the streaming message with accumulated content (preserve id)
                            self.updatePlaceholder(of: turn) { current in
                                current.messageBody = accumulatedContent
                                current.payload = payload
                            }
                        } else if state == ConciergeConstants.StreamState.COMPLETED {
                            let fullText = message
                            Log.trace(label: self.LOG_TAG, "Completion received. Full text length=\(fullText.count)")

                            self.updatePlaceholder(of: turn) { current in
                                current.messageBody = fullText
                                current.payload = payload
                            }

                            accumulatedContent = fullText
                        }
                    }

                    // Capture multimodal elements for rendering on completion
                    if let elements = payload.response?.multimodalElements?.elements, !elements.isEmpty {
                        latestElements = elements
                    }

                    // Capture prompt suggestions if present
                    if let suggestions = payload.response?.promptSuggestions, !suggestions.isEmpty {
                        self.latestPromptSuggestions = suggestions
                    }

                    // Capture sources from payload as they arrive (used on completion)
                    if let sources = payload.response?.sources {
                        self.latestSources = sources
                    }

                    // Capture link hints from payload as they arrive (used on completion)
                    if let hints = payload.response?.linkHints, !hints.isEmpty {
                        self.latestLinkHints = hints
                    }
                }
            },
            onComplete: { [weak self] error in
                Task { @MainActor in
                    // A turn ended by a deadline has already reported its outcome and unwound the
                    // transcript. Its late completion must not do either a second time.
                    guard !turn.isResolved else { return }

                    // The caller must hear back on every path out of this closure, including the
                    // early `return`s below and a deallocated controller. `resolve` is idempotent,
                    // so the `defer` can fire unconditionally without racing the paths that report
                    // a more specific outcome first.
                    var outcome: ConciergeError? = error
                    defer { turn.resolve(outcome) }

                    guard let self = self, self.activeTurn === turn else {
                        // The session went away mid-stream; nothing was rendered.
                        outcome = outcome ?? .unknown
                        return
                    }

                    if let error = error {
                        Log.error(label: self.LOG_TAG, "Streaming error: \(error)")
                        self.dispatchTrackingEvent(.errorOccurred(errorMessage: error.localizedDescription))

                        self.discardPlaceholder(of: turn)

                        // A failed turn is a *finished* turn: surface the failure and return to
                        // idle. Parking in `.error` would deadlock the chat - `sendMessage`,
                        // `sendEnabled`, and `micEnabled` all require `.idle`, and the only path
                        // back to `.idle` runs inside a turn those guards prevent from starting.
                        if turn.rendersFailures {
                            self.messages.append(Message(template: .basic(isUserMessage: false),
                                                         messageBody: self.networkErrorMessage))
                        }

                        self.endTurn(turn)
                    } else if accumulatedContent.isEmpty && latestElements.isEmpty {
                        outcome = .invalidResponseData
                        // Genuinely empty response — no text and no multimodal elements.
                        self.discardPlaceholder(of: turn)

                        if turn.rendersFailures {
                            self.messages.append(Message(template: .basic(isUserMessage: false), messageBody: "Sorry, I wasn't able to get a response from the Concierge Service. \n\nPlease try again later."))
                        }

                        self.endTurn(turn)
                    } else {
                        let completed = self.updatePlaceholder(of: turn) { current in
                            current.messageBody = accumulatedContent
                            current.shouldSpeakMessage = !accumulatedContent.isEmpty
                            if !self.latestSources.isEmpty {
                                Log.trace(label: self.LOG_TAG, "Using sources: count=\(self.latestSources.count)")
                                current.sources = self.latestSources
                            }
                            if !self.latestLinkHints.isEmpty {
                                Log.trace(label: self.LOG_TAG, "Using linkHints: count=\(self.latestLinkHints.count)")
                                current.linkHints = self.latestLinkHints
                            }
                            current.feedbackEligible = current.payload?.response?.feedback?.eligible ?? false
                            current.isStreamComplete = true
                        }

                        guard let completedPayload = completed?.payload else {
                            Log.warning(label: self.LOG_TAG, "responseCompleted skipped: the turn's message is no longer in the transcript")
                            self.endTurn(turn)
                            return
                        }

                        // A cards-only response has nothing for the text bubble, so drop the
                        // placeholder rather than leave an empty one above the cards. Deliberately
                        // after the guard above: removing it on a path that then returns early
                        // would strip the turn's only message and still report success.
                        if accumulatedContent.isEmpty && !latestElements.isEmpty {
                            self.discardPlaceholder(of: turn)
                        }
                        self.dispatchTrackingEvent(.responseCompleted(
                            conversationId: completedPayload.conversationId ?? "unknown",
                            interactionId: completedPayload.interactionId ?? "unknown"
                        ))

                        // Render multimodal elements (cards, CTAs) from the completed response
                        if !latestElements.isEmpty {
                            self.renderMultimodalElements(latestElements)
                        }

                        // Append prompt suggestions as their own message bubbles at the end
                        if !self.latestPromptSuggestions.isEmpty {
                            for suggestion in self.latestPromptSuggestions {
                                self.messages.append(Message(template: .promptSuggestion(text: suggestion)))
                            }
                        }

                        self.endTurn(turn)
                    }
                }
            }
            )
        }

        return turn
    }

    /// Applies `edit` to `turn`'s streaming message and returns the result, or `nil` when that
    /// message is no longer in the transcript.
    ///
    /// Looked up by id rather than by a captured index: the transcript shifts under a turn as cards
    /// and prompt suggestions are appended, and a stale index silently edits a neighbouring
    /// message instead of failing.
    @discardableResult
    private func updatePlaceholder(of turn: ChatTurn, _ edit: (inout Message) -> Void) -> Message? {
        guard let index = messages.firstIndex(where: { $0.id == turn.placeholderId }) else { return nil }
        var current = messages[index]
        edit(&current)
        messages[index] = current
        return current
    }

    /// Returns the chat to idle and drops the per-turn accumulators.
    ///
    /// Clearing `activeTurn` is what publishes `.idle`; see the property's note.
    private func clearState() {
        activeTurn = nil
        latestSources = []
        latestLinkHints = []
        latestPromptSuggestions = []
    }

    /// Appends multimodal elements to `messages`, respecting their relative order from
    /// the server. Card-type elements are collapsed into a single card or carousel at
    /// the position of the first card encountered.
    private func renderMultimodalElements(_ elements: [MultimodalElement]) {
        let cardElements = elements.filter { $0.elementType != .ctaButton }

        // If any cards exist in the multimodal elements list, 
        // resolves to either single card or carousel of cards depending on number of card elements
        let cardMessage: Message? = {
            if cardElements.count == 1, let card = cardElements.first, let entityInfo = card.entityInfo {
                let cardData = ProductCardData(entityInfo: entityInfo, element: card)
                return Message(template: .productCard(cardData))
            } else if cardElements.count > 1 {
                var carouselItems: [Message] = []
                for card in cardElements {
                    guard let entityInfo = card.entityInfo else { continue }
                    let cardData = ProductCardData(entityInfo: entityInfo, element: card)
                    carouselItems.append(Message(template: .productCarouselCard(cardData)))
                }
                return Message(template: .carouselGroup(carouselItems))
            }
            return nil
        }()

        var cardElementEmitted = false

        for element in elements {
            if element.elementType == .ctaButton {
                guard let action = element.entityInfo?.primary else {
                    Log.warning(label: LOG_TAG, "Skipping ctaButton element '\(element.id ?? "unknown")': missing entity_info.primary.")
                    continue
                }
                messages.append(Message(template: .ctaButton(action)))
            } else if !cardElementEmitted {
                if let cardMessage = cardMessage {
                    messages.append(cardMessage)
                }
                cardElementEmitted = true
            }
        }

        let elementDicts: [[String: Any]] = cardElements.compactMap { element in
            guard let entityInfo = element.entityInfo else { return nil }
            var dict: [String: Any] = [:]
            if let name = entityInfo.productName { dict["productName"] = name }
            if let url = entityInfo.productPageURL { dict["productPageURL"] = url }
            if let price = entityInfo.productPrice { dict["productPrice"] = price }
            return dict
        }
        guard !elementDicts.isEmpty else { return }
        let displayMode = elementDicts.count == 1 ? "single" : "carousel"
        dispatchTrackingEvent(.cardsRendered(displayMode: displayMode, elements: elementDicts))
    }
}

// MARK: - Array Safe Access Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
