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
    let serviceEndpoint = "https://bc-conversation-service-dev.corp.ethos11-stage-va7.ethos.adobe.net/brand-concierge/conversations?sessionId=083f7d55-df46-43f3-a70d-626cc324d1ef&requestId=f199b4ed-50db-44cd-9371-291778e81927&configId=51ee226f-9327-4b97-99fb-d5f9877d8198"
    let tempQuery = "I want to turn my clips into polished videos."
    let tempSurface = "web://bc-conversation-service-dev.corp.ethos11-stage-va7.ethos.adobe.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/index.html"
    
    let LOG_TAG = "ConciergeChatService"
    
    // MARK: - private members
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var serverEventHandler: ((ConciergeResponse?, ConciergeError?) -> Void)?
    private var onChunkHandler: ((String) -> Void)?
    private var onCompleteHandler: ((ConciergeError?) -> Void)?
    
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
    
    func streamChat(_ query: String, onChunk: @escaping (String) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        guard let url = URL(string: serviceEndpoint) else {
            onComplete(.invalidEndpoint)
            return
        }
        
        let payload = createChatPayload(query: tempQuery)
        
        // TODO: use the actual query
        //let payload = createChatPayload(query: query)
                
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
                
                // pass back the payload of the first handle
                tempServerEventHandler?(handle.handle.first!.payload.first!)
            } catch {
                Log.warning(label: LOG_TAG, "An error occurred while decoding the chat response. \(error)")
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle connection errors
            Log.warning(label: LOG_TAG, "An error occurred while connecting to the Concierge server: \(error.localizedDescription)")
        } else {
            // Connection completed (e.g., server closed connection)
            Log.trace(label: LOG_TAG, "Concierge server connection closed.")
            disconnect()
        }
        // Clean up handlers
        onChunkHandler = nil
        onCompleteHandler = nil
    }
}
