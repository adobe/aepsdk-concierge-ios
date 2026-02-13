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

import AEPServices
import Foundation

/// Service handling communication with the Brand Concierge backend.
class ConciergeChatService: NSObject {

    // MARK: - Temporary Configuration (Remove before release)

    private let USE_TEMPS = false
    private let TEMP_serviceEndpoint = "https://edge-int.adobedc.net/brand-concierge/conversations?sessionId=71476c26-7003-4002-bc2f-aa13416d5b4e&requestId=831b1723-38fc-49f6-8e58-f9d413c918d0&configId=6acf9d12-5018-4f84-8224-aac4900782f0"
    private let TEMP_ecid = "23460916906658555991704675673209093097"
    private let TEMP_surface = "web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"

    // MARK: - Constants

    private let LOG_TAG = "ConciergeChatService"
    private let apiPath = "/brand-concierge/conversations"

    // MARK: - Private Properties

    private var configuration: ConciergeConfiguration
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var onChunkHandler: ((ConversationPayload) -> Void)?
    private var onCompleteHandler: ((ConciergeError?) -> Void)?

    // MARK: - Initialization

    init(configuration: ConciergeConfiguration) {
        self.configuration = configuration
        super.init()

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    // MARK: - Streaming Chat / Queries

    func streamChat(_ query: String, onChunk: @escaping (ConversationPayload) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        do {
            let url = try createUrl()

            // Register handlers for this streaming session
            self.onChunkHandler = onChunk
            self.onCompleteHandler = onComplete

            let payload = try createChatPayload(query: query)

            var request = URLRequest(url: url)
            request.httpMethod = ConciergeConstants.HTTPMethods.POST
            request.httpBody = payload
            request.setValue(ConciergeConstants.ContentTypes.APPLICATION_JSON, forHTTPHeaderField: ConciergeConstants.HeaderFields.CONTENT_TYPE)
            request.setValue(ConciergeConstants.AcceptTypes.TEXT_EVENT_STREAM, forHTTPHeaderField: ConciergeConstants.HeaderFields.ACCEPT)
            request.timeoutInterval = ConciergeConstants.Request.READ_TIMEOUT

            dataTask = session.dataTask(with: request)
            Log.debug(label: LOG_TAG, "Sending request to Concierge Service: \(url) \n\(String(data: payload, encoding: .utf8)?.prettyPrintedJSON() ?? "unknown body")")

            // Refresh session activity timestamp when starting a request
            SessionManager.shared.refreshSessionActivity()

            dataTask?.resume()
        } catch {
            if let error = error as? ConciergeError {
                Log.warning(label: LOG_TAG, error.localizedDescription)
                onComplete(error)
            } else {
                Log.warning(label: LOG_TAG, ConciergeError.unknown.localizedDescription)
                onComplete(.unknown)
            }

            return
        }
    }

    // MARK: - Feedback reporting

    func sendFeedback(data: [String: Any]) {
        do {
            let url = try createUrl()

            let payload = try createFeedbackPayload(data: data)
            var request = URLRequest(url: url)
            request.httpMethod = ConciergeConstants.HTTPMethods.POST
            request.httpBody = payload
            request.setValue(ConciergeConstants.ContentTypes.APPLICATION_JSON, forHTTPHeaderField: ConciergeConstants.HeaderFields.CONTENT_TYPE)
            request.timeoutInterval = ConciergeConstants.Request.READ_TIMEOUT

            Log.debug(label: LOG_TAG, "Sending feedback event to Concierge Service: \(url) \n\(String(data: payload, encoding: .utf8)?.prettyPrintedJSON() ?? "unknown body")")

            // Refresh session activity timestamp when sending feedback
            SessionManager.shared.refreshSessionActivity()

            session.dataTask(with: request) { _, response, error in
                if let error = error {
                    Log.warning(label: self.LOG_TAG, error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    Log.debug(label: self.LOG_TAG, "Feedback request completed with statusCode=\(httpResponse.statusCode)")
                }
            }.resume()

        } catch {
            if let error = error as? ConciergeError {
                Log.warning(label: LOG_TAG, error.localizedDescription)
            } else {
                Log.warning(label: LOG_TAG, ConciergeError.unknown.localizedDescription)
            }

            return
        }
    }

    // MARK: - Private Methods

    private func createUrl() throws -> URL {
        // TODO: Remove prior to release
        if USE_TEMPS {
            return URL(string: TEMP_serviceEndpoint)!
        }

        guard let endpoint = configuration.server else {
            throw ConciergeError.invalidEndpoint("Unable to create URL for Concierge Service request. Server unavailable from configuration.")
        }

        guard let datastream = configuration.datastream else {
            throw ConciergeError.invalidDatastream("Unable to create URL for Concierge Service request. Datastream unavailable from configuration.")
        }

        var queryItems = [
            URLQueryItem(name: ConciergeConstants.Request.Keys.CONFIG_ID, value: datastream)
        ]

        if let sessionId = configuration.sessionId {
            queryItems.append(URLQueryItem(name: ConciergeConstants.Request.Keys.SESSION_ID, value: sessionId))
        }

        if let conversationId = configuration.conversationId {
            queryItems.append(URLQueryItem(name: ConciergeConstants.Request.Keys.CONVERSATION_ID, value: conversationId))
        }

        var urlComponents = URLComponents(string: "\(ConciergeConstants.Request.HTTPS)\(endpoint)\(apiPath)")
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw ConciergeError.invalidEndpoint("Unable to create URL for Concierge Service request. Unable to create URL from components.")
        }

        return url
    }

    /// Creates the JSON payload for a chat request.
    /// - Parameter query: The user's message
    /// - Returns: JSON data for the request body
    /// - Note: Internal visibility for testing
    func createChatPayload(query: String) throws -> Data {
        guard let ecid = configuration.ecid else { throw ConciergeError.invalidEcid("Unable to create concierge request payload. ECID is nil.") }
        guard !configuration.surfaces.isEmpty else { throw ConciergeError.invalidSurfaces("Unable to create concierge request payload. No surfaces were provided.") }

        let consentState = ConsentState(configValue: configuration.consentCollectValue).payloadValue

        let payload = [
            ConciergeConstants.Request.Keys.EVENTS: [
                [
                    ConciergeConstants.Request.Keys.QUERY: [
                        ConciergeConstants.Request.Keys.CONVERSATION: [
                            ConciergeConstants.Request.Keys.SURFACES: USE_TEMPS ? [TEMP_surface] : configuration.surfaces,
                            ConciergeConstants.Request.Keys.MESSAGE: query
                        ]
                    ],
                    ConciergeConstants.Request.Keys.XDM: [
                        ConciergeConstants.Request.Keys.IDENTITY_MAP: [
                            ConciergeConstants.Request.Keys.ECID: [
                                [
                                    ConciergeConstants.Request.Keys.ID: USE_TEMPS ? TEMP_ecid : ecid
                                ]
                            ]
                        ]
                    ],
                    ConciergeConstants.Request.Keys.Consent.META: [
                        ConciergeConstants.Request.Keys.Consent.CONSENT: [
                            ConciergeConstants.Request.Keys.Consent.STATE: consentState
                        ]
                    ]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw ConciergeError.invalidData("Unable to create JSON payload for request to Brand Concierge chat service.")
        }
        return jsonData
    }

    /// Creates the JSON payload for a feedback request.
    /// - Parameter data: The feedback data dictionary
    /// - Returns: JSON data for the request body
    /// - Note: Internal visibility for testing
    func createFeedbackPayload(data: [String: Any]) throws -> Data {
        let consentState = ConsentState(configValue: configuration.consentCollectValue).payloadValue

        var payload = data
        payload[ConciergeConstants.Request.Keys.Consent.META] = [
            ConciergeConstants.Request.Keys.Consent.CONSENT: [
                ConciergeConstants.Request.Keys.Consent.STATE: consentState
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw ConciergeError.invalidData("Unable to create JSON payload for Brand Concierge feedback event.")
        }

        return jsonData
    }

    private func disconnect() {
        dataTask?.cancel()
        dataTask = nil
    }
}

// MARK: - URLSessionDataDelegate

extension ConciergeChatService: URLSessionDataDelegate {

    /// Called each time the server sends a streaming event
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        // The response may have multiple chunks of data, we need to process them all
        let dataComponents = dataString.components(separatedBy: .newlines)
        for component in dataComponents {
            // Skip newlines
            if !component.hasPrefix(ConciergeConstants.SSE.DATA_PREFIX) {
                continue
            }

            let trimmedHandle = String(component.dropFirst(6))
            guard let handleData = trimmedHandle.data(using: .utf8) else {
                return
            }

            do {
                let handle = try JSONDecoder().decode(ConversationHandle.self, from: handleData)
                if let handler = self.onChunkHandler,
                   let payload = handle.handle.first?.payload.first {
                    handler(payload)
                }
            } catch {
                Log.warning(label: LOG_TAG, "An error occurred while decoding the chat response. \(error)")
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle connection errors
            Log.warning(label: LOG_TAG, "An error occurred while connecting to the Concierge server: \(error.localizedDescription)")
            onCompleteHandler?(.unreachable)
        } else {
            // Connection completed (e.g., server closed connection)
            Log.trace(label: LOG_TAG, "Concierge server connection closed.")
            onCompleteHandler?(nil)
            disconnect()
        }
        // Clean up handlers
        onChunkHandler = nil
        onCompleteHandler = nil
    }
}
