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
    let serviceEndpoint = "https://bc-conversation-service-stage.corp.ethos12-stage-va7.ethos.adobe.net/brand-concierge/conversations?configId=211312ed-d9ca-4f51-b09c-2de37a2a24d0&sessionId=c300837c-dee1-4d4c-87cd-0508902596cd"
    
    // MARK: - private members
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var serverEventHandler: ((ConciergeResponse?, ConciergeError?) -> Void)?
    
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
        
        let payload = createChatPayload(query: "Help me find a beach trip for summer getaway")//query)
                
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
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
            "events": [
                [
                    "query": [
                        "conversation": [
                            "fetchConversationalExperience": true,
                            "surfaces": ["web://git.corp.adobe.com/pages/nciocanu/concierge-demo/streaming"],
                            "message": query
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
    
    func processChat(_ query: String, completionHandler: @escaping ((ConciergeResponse?, ConciergeError?) -> Void)) {
        guard let url = URL(string: Constants.SharedState.Concierge.CHAT_ENDPOINT) else {
            Log.warning(label: Constants.LOG_TAG, "Unable to create a URL for the Concierge chat API.")
            completionHandler(nil, .invalidEndpoint)
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode([Constants.Request.Keys.MESSAGE: query]) else {
            Log.warning(label: Constants.LOG_TAG, "Unable to encode the post body for Concierge chat API request.")
            completionHandler(nil, .invalidData)
            return
        }
        
        let headers = [Constants.HeaderFields.CONTENT_TYPE: Constants.ContentTypes.APPLICATION_JSON]
        
        let networkRequest = NetworkRequest(url: url,
                                            httpMethod: .post,
                                            connectPayloadData: jsonData,
                                            httpHeaders: headers,
                                            connectTimeout: Constants.Request.CONNECT_TIMEOUT,
                                            readTimeout: Constants.Request.READ_TIMEOUT)
        
        ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest) { connection in
            if let error = connection.error {
                print(error)
                if connection.responseCode == 404 {
                    completionHandler(nil, .unreachable)
                    return
                }
            }
            
            guard let data = connection.data, !data.isEmpty else {
                completionHandler(nil, .invalidResponseData)
                return
            }
            
            if let conciergeResponse = try? JSONDecoder().decode(ConciergeResponse.self, from: data) {
                completionHandler(conciergeResponse, nil)
            }
        }
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
            if !component.hasPrefix("data: ") {
                continue
            }
            
            let trimmedHandle = String(component.dropFirst(6))
            guard let handleData = trimmedHandle.data(using: .utf8) else {
                return
            }
            
            do {
                let handle = try JSONDecoder().decode(TempHandle.self, from: handleData)
                
                // pass back the payload of the first handle
                tempServerEventHandler?(handle.handle.first!.payload.first!)
            } catch {
                print("error decoding to TempHandle: \(error)")
            }
        }
        
        // END NEW STUFF
        
//        print("raw data from response: \(String(data:data, encoding:.utf8) ?? "none")")
//        guard let dataString = String(data: data, encoding: .utf8) else {
//            return
//        }
//        
//        let trimmedHandle = dataString.hasPrefix("data: ") ? String(dataString.dropFirst(6)) : dataString
//        guard let handleData = trimmedHandle.data(using: .utf8) else {
//            return
//        }
//                
//        let handleMap = try? JSONSerialization.jsonObject(with: handleData) as? [String: Any]
//        
//        let firstHandle = (handleMap?["handle"] as? [Any])?.first as? [String: Any]
//        
//        let handleType = firstHandle?["type"]
//        let handlePayload = firstHandle?["payload"] as? [Any]?
//        let firstPayload = handlePayload??.first as? [String: Any]
//        let responseObject = firstPayload?["response"] as? [String: Any]
//        guard let responseMessage = responseObject?["message"] as? String else {
//            return
//        }
//        
//        let response = ConciergeResponse(id: "abc", status: "abc", message: responseMessage)
//        
//        serverEventHandler?(response, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle connection errors
            print("SSE connection error: \(error.localizedDescription)")
        } else {
            // Connection completed (e.g., server closed connection)
            print("SSE connection completed.")
            disconnect()
        }
    }
}
