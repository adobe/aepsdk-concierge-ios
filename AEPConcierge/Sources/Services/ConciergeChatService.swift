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
    // MARK: - temporary constants for testing
    let serviceEndpoint = "https://edge-int.adobedc.net/brand-concierge/conversations?sessionId=161c33da-7b02-4ca4-a9d4-d934282486f3&requestId=dcbd50b6-2094-4cb7-9561-9c41f800da85&configId=3849362c-f325-4418-8cc8-993342b254f7"
    let tempQuery = "Tell me about Photoshop"
    let tempSurface = "web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/ao/index.html"
    
    let LOG_TAG = "ConciergeChatService"
    
    // MARK: - private members
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var serverEventHandler: ((ConciergeResponse?, ConciergeError?) -> Void)?
    private var onChunkHandler: ((TempPayload) -> Void)?
    private var onCompleteHandler: ((ConciergeError?) -> Void)?
    private var lastEmittedResponseText: String = ""
    
    // TODO: remove the temp code, this is for the demo and testing the UI
    private var tempServerEventHandler: ((TempPayload) -> Void)?
    
    override init() {
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
        guard let url = URL(string: serviceEndpoint) else {
            onComplete(.invalidEndpoint)
            return
        }
        
        // Register handlers for this streaming session
        self.onChunkHandler = onChunk
        self.onCompleteHandler = onComplete
        self.lastEmittedResponseText = ""

        // Use the actual user-provided query
        let payload = createChatPayload(query: query)
                
        var request = URLRequest(url: url)
        request.httpMethod = Constants.HTTPMethods.POST
        request.httpBody = payload
        request.setValue(Constants.ContentTypes.APPLICATION_JSON, forHTTPHeaderField: Constants.HeaderFields.CONTENT_TYPE)
        request.setValue(Constants.AcceptTypes.TEXT_EVENT_STREAM, forHTTPHeaderField: Constants.HeaderFields.ACCEPT)
        request.timeoutInterval = Constants.Request.READ_TIMEOUT
        
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    private func disconnect() {
        dataTask?.cancel()
        dataTask = nil
    }
        
    private func createChatPayload(query: String) -> Data? {
        // Create proper payload for your API
        let payload = [
            Constants.Request.Keys.EVENTS: [
                [
                    Constants.Request.Keys.QUERY: [
                        Constants.Request.Keys.CONVERSATION: [
                            Constants.Request.Keys.FETCH_CONVERSATIONAL_EXPERIENCE: true,
                            Constants.Request.Keys.SURFACES: [
                                // TODO: use a surface from configuration
                                tempSurface
                            ],
                            Constants.Request.Keys.MESSAGE: query
                        ]
                    ],
                    Constants.Request.Keys.XDM: [
                        Constants.Request.Keys.IDENTITY_MAP: [
                            Constants.Request.Keys.ECID: [
                                [
                                    Constants.Request.Keys.ID: "90441736653237303030763364899130413871"
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        
        return jsonData
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
