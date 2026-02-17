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

/// Errors that can occur during Concierge service operations.
enum ConciergeError: Error {
    case invalidData(String)
    case invalidEndpoint(String)
    case invalidDatastream(String)
    case invalidEcid(String)
    case invalidSurfaces(String)
    case invalidResponseData
    case timeout(Int)
    case unknown
    case unreachable
}

extension ConciergeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidData(let message),
            .invalidEndpoint(let message),
            .invalidDatastream(let message),
            .invalidEcid(let message),
            .invalidSurfaces(let message):
            return message
        case .invalidResponseData:
            return "Response data returned was invalid."
        case .timeout(let duration):
            return "Request has timed out after \(duration) seconds."
        case .unknown:
            return "Unknown error."
        case .unreachable:
            return "Server was unreachable."
        }
    }
}
