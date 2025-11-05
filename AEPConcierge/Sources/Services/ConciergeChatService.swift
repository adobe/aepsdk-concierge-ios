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

class ConciergeChatService: NSObject {
    
    // MARK: - REMOVE ME LATER WHEN WE CAN USE REAL VALUES
    let USE_TEMPS = true
    let TEMP_serviceEndpoint = "https://edge-int.adobedc.net/brand-concierge/conversations?sessionId=f774384a-68ce-472f-a454-ec6432c0484b&requestId=1c3222a5-686b-4cc0-aaa8-1ecc0be7dd97&configId=6acf9d12-5018-4f84-8224-aac4900782f0"
    let TEMP_ecid = "38311589222118362203934607554670412837"
    let TEMP_surface = "web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"
    
    
    // MARK: - constants
    private let LOG_TAG = "ConciergeChatService"
    private let apiPath = "/brand-concierge/conversations"
    
    // MARK: - private members
    private var conicergeConfiguration: ConciergeConfiguration
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var serverEventHandler: ((ConciergeResponse?, ConciergeError?) -> Void)?
    private var onChunkHandler: ((TempPayload) -> Void)?
    private var onCompleteHandler: ((ConciergeError?) -> Void)?
    private var lastEmittedResponseText: String = ""
    
    // TODO: remove the temp code, this is for the demo and testing the UI
    private var tempServerEventHandler: ((TempPayload) -> Void)?
    
    init(configuration: ConciergeConfiguration) {
        self.conicergeConfiguration = configuration
        super.init()
        
        // TODO: research the use of a delegateQueue here
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func setServerEventHandler(_ handler: @escaping (ConciergeResponse?, ConciergeError?) -> Void) {
        self.serverEventHandler = handler
    }
    
    func setTempServerEventHandler(_ handler: @escaping (TempPayload) -> Void) {
        self.tempServerEventHandler = handler
    }
    
    func streamChat(_ query: String, onChunk: @escaping (TempPayload) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        do {
            let url = try createUrl()

            // Register handlers for this streaming session
            self.onChunkHandler = onChunk
            self.onCompleteHandler = onComplete
            self.lastEmittedResponseText = ""

            let payload = try createChatPayload(query: query)

            var request = URLRequest(url: url)
            request.httpMethod = Constants.HTTPMethods.POST
            request.httpBody = payload
            request.setValue(Constants.ContentTypes.APPLICATION_JSON, forHTTPHeaderField: Constants.HeaderFields.CONTENT_TYPE)
            request.setValue(Constants.AcceptTypes.TEXT_EVENT_STREAM, forHTTPHeaderField: Constants.HeaderFields.ACCEPT)
            request.timeoutInterval = Constants.Request.READ_TIMEOUT

            dataTask = session.dataTask(with: request)
            Log.debug(label: LOG_TAG, "Sending request to Concierge Service: \(url) \n\(String(data: payload, encoding: .utf8) ?? "unknown body")")
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
           
    private func createUrl() throws -> URL {
        // TODO: remove prior to release
        if USE_TEMPS {
            return URL(string: TEMP_serviceEndpoint)!
        }
                
        guard let endpoint = conicergeConfiguration.server else {
            throw ConciergeError.invalidEndpoint("Unable to create URL for Concierge Service request. Server unavailable from configuration.")
        }
        guard let datastream = conicergeConfiguration.datastream else {
            throw ConciergeError.invalidDatastream("Unable to create URL for Concierge Service request. Datastream unavailable from configuration.")
        }

        var queryItems = [
            URLQueryItem(name: Constants.Request.Keys.CONFIG_ID, value: datastream)
        ]

        if let sessionId = conicergeConfiguration.sessionId {
            queryItems.append(URLQueryItem(name: Constants.Request.Keys.SESSION_ID, value: sessionId))
        }

        if let conversationId = conicergeConfiguration.conversationId {
            queryItems.append(URLQueryItem(name: Constants.Request.Keys.CONVERSATION_ID, value: conversationId))
        }

        var urlComponents = URLComponents(string: "\(Constants.Request.HTTPS)\(endpoint)\(apiPath)")
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw ConciergeError.invalidEndpoint("Unable to create URL for Concierge Service request. Unable to create URL from components.")
        }
        
        return url
    }
    
    private func createChatPayload(query: String) throws -> Data {
        guard let ecid = conicergeConfiguration.ecid else { throw ConciergeError.invalidEcid("Unable to create concierge request payload. ECID is nil.") }
        guard !conicergeConfiguration.surfaces.isEmpty else { throw ConciergeError.invalidSurfaces("Unable to create concierge request payload. No surfaces were provided.") }

        let payload = [
            Constants.Request.Keys.EVENTS: [
                [
                    Constants.Request.Keys.QUERY: [
                        Constants.Request.Keys.CONVERSATION: [
                            Constants.Request.Keys.FETCH_CONVERSATIONAL_EXPERIENCE: true,
                            Constants.Request.Keys.SURFACES: USE_TEMPS ? [TEMP_surface] : conicergeConfiguration.surfaces,
                            Constants.Request.Keys.MESSAGE: query
                        ]
                    ],
                    Constants.Request.Keys.XDM: [
                        Constants.Request.Keys.IDENTITY_MAP: [
                            Constants.Request.Keys.ECID: [
                                [
                                    Constants.Request.Keys.ID: USE_TEMPS ? TEMP_ecid : ecid
                                ]
                            ]
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
    
    private func disconnect() {
        dataTask?.cancel()
        dataTask = nil
    }
}

extension ConciergeChatService: URLSessionDataDelegate {
    // MARK: - URLSessionDataDelegate

    /// Called each time the server sends a streaming event
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // NEW STUFF
        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }
        
        // the response may have multiple chunks of data, we need to process them all
        let dataComponents = dataString.components(separatedBy: .newlines)
        for component in dataComponents {
            // skip newlines
            if !component.hasPrefix(Constants.SSE.DATA_PREFIX) {
                continue
            }
            
            let trimmedHandle = String(component.dropFirst(6))
            print(trimmedHandle)
            guard let handleData = trimmedHandle.data(using: .utf8) else {
                return
            }
            
            do {
                let handle = try JSONDecoder().decode(TempHandle.self, from: handleData)
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
        lastEmittedResponseText = ""
    }
}
