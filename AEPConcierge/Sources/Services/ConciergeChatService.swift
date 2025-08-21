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
    let testPayload = """
{
    "events":[
        {
            "query":{
                "conversation":{
                    "fetchConversationalExperience": true,
                    "surfaces":[
                        "web://git.corp.adobe.com/pages/nciocanu/concierge-demo/streaming"
                    ],
                    "message":"Help me find a beach trip for summer getaway"
                }
            }
        }
    ]
}
"""
    
    // MARK: - private members
    private var session: URLSession!
    private var dataTask: URLSessionDataTask?
    private var serverEventHandler: ((ConciergeResponse?, ConciergeError?) -> Void)?
    
    override init() {
        super.init()
        // TODO: research the use of a delegateQueue here
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func setServerEventHandler(_ handler: @escaping (ConciergeResponse?, ConciergeError?) -> Void) {
        self.serverEventHandler = handler
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
    
    private func handleStreamingResponse(_ connection: HttpConnection, onChunk: @escaping (String) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        guard connection.error == nil else {
            Log.error(label: "ConciergeChatService", "Streaming connection error: \(connection.error?.localizedDescription ?? "Unknown error")")
//            onComplete(.networkFailure)
            return
        }
        
        guard let data = connection.data else {
            onComplete(.invalidResponseData)
            return
        }
        
        // Parse SSE data format
        let dataString = String(data: data, encoding: .utf8) ?? ""
        parseSSEEvents(dataString, onChunk: onChunk, onComplete: onComplete)
    }
    
    private func parseSSEEvents(_ data: String, onChunk: @escaping (String) -> Void, onComplete: @escaping (ConciergeError?) -> Void) {
        let lines = data.components(separatedBy: .newlines)
        var eventData = ""
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let content = String(line.dropFirst(6)) // Remove "data: " prefix
                
                if content == "[DONE]" {
                    // Stream complete
                    onComplete(nil)
                    return
                }
                
                // Try to parse JSON chunk
                if let jsonData = content.data(using: .utf8),
                   let chunk = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = chunk["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    onChunk(content)
                } else if !content.isEmpty {
                    // Fallback: use content directly
                    onChunk(content)
                }
            } else if line.isEmpty {
                // End of event
                continue
            }
        }
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
            return testPayload.data(using: .utf8) // Fallback to your test payload
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
    
    func clearConciergeSession() {
//        guard let url = URL(string: Constants.SharedState.Concierge.DELETE_ENDPOINT) else {
//            Log.warning(label: Constants.LOG_TAG, "Unable to create URL to clear the Concierge session. The session will not be cleared.")
//            return
//        }
//        
//        let networkRequest = NetworkRequest(url: url,
//                                            httpMethod: .delete,
//                                            connectTimeout: 2.0)
//        
//        ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest) { connection in
//            guard let responseCode = connection.responseCode else {
//                Log.warning(label: Constants.LOG_TAG, "API request to clear the Concierge session failed: response code is not obtainable or empty.")
//                return
//            }
//            
//            if responseCode != 204 {
//                Log.warning(label: Constants.LOG_TAG, "API request to clear the Concierge session failed: response code == \(responseCode).")
//            } else {
//                Log.debug(label: Constants.LOG_TAG, "API request to clear the Concierge session succeeded.")
//            }
//        }
    }
}


/// example response of streamed data:
/**
 
 data: {"handle":[{"type":"brand-concierge:conversation","payload":[{"conversationId":"4ce9cca4-5b15-46f0-bdd0-b3a0345f94c8","interactionId":"","request":{"message":"Help me find a beach trip for summer getaway","context":{"application":"bc-southwest"},"featureOverride":{"application_enablement":"SOUTHWEST_BRAND_CONCIERGE","collection_name_mapping":{"bc-southwest":{"document_retrieval":{"collection_name":"test_southwest_docs_small_v3"},"prompt_collections":{"examples":"southwest_concierge_examples_v0","prompts":"southwest_concierge_prompts_v0"},"question_retrieval":{"collection_name":"southwest_copilot_question_index_v1"},"hyperlink_rules_retrieval":{"collection_name":"summit_concierge_hyperlink_rules_v0"}}}}},"response":{"message":"Looking for your next adventure? Let's explore some fantastic beach destinations for your summer getaway! Here are a few options to consider:\n\n","promptSuggestions":[]},"state":"in-progress"}]},{"type":"state:store","payload":[{"key":"kndctr_52C418126318FCD90A494134_AdobeOrg_bc_session_id","value":"c300837c-dee1-4d4c-87cd-0508902596cd","maxAge":1800}]}]}
 
 */

extension ConciergeChatService: URLSessionDataDelegate {
    // MARK: - URLSessionDataDelegate

    /// Called each time the server sends a streaming event
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        print("data: \(String(data:data, encoding:.utf8) ?? "none")")
        
        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }
        
        let handle = dataString.hasPrefix("data: ") ? String(dataString.dropFirst(6)) : dataString
        guard let handleData = handle.data(using: .utf8) else {
            return
        }
                
        let handleMap = try? JSONSerialization.jsonObject(with: handleData) as? [String: Any]
        
        let firstHandle = (handleMap?["handle"] as? [Any])?.first as? [String: Any]
        
        let handleType = firstHandle?["type"]
        let handlePayload = firstHandle?["payload"] as? [Any]?
        let firstPayload = handlePayload??.first as? [String: Any]
        let responseObject = firstPayload?["response"] as? [String: Any]
        guard let responseMessage = responseObject?["message"] as? String else {
            return
        }
        
        let response = ConciergeResponse(id: "abc", status: "abc", message: responseMessage)
        
        serverEventHandler?(response, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle connection errors
            print("SSE connection error: \(error.localizedDescription)")
        } else {
            // Connection completed (e.g., server closed connection)
            print("SSE connection completed.")
        }
    }
}
