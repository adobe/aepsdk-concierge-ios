/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

/// Maps consent configuration values to payload state values.
/// Configuration values: "y", "n", "u"
/// Payload values: "in", "out", "unknown"
enum ConsentState: String {
    case optedIn = "y"
    case optedOut = "n"
    case unknown = "u"

    /// The value to send in the request payload
    var payloadValue: String {
        switch self {
        case .optedIn:
            return "in"
        case .optedOut:
            return "out"
        case .unknown:
            return "unknown"
        }
    }

    /// Initialize from a configuration value, defaulting to unknown if invalid
    init(configValue: String?) {
        guard let value = configValue,
              let state = ConsentState(rawValue: value) else {
            self = .unknown
            return
        }
        self = state
    }
}
