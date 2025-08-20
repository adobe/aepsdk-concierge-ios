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

struct ConciergeChatService {
    
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
