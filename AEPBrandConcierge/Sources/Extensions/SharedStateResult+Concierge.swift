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
import AEPCore

/// SharedStateResult extensions for accessing Concierge configuration values.
extension SharedStateResult {
    /// Extracts the ECID from the Edge Identity shared state.
    var ecid: String? {
        guard let identityMap = value?[ConciergeConstants.SharedState.EdgeIdentity.IDENTITY_MAP] as? [AnyHashable: Any] else {
            return nil
        }

        guard let ecidArray = identityMap[ConciergeConstants.SharedState.EdgeIdentity.ECID] as? [[AnyHashable: Any]],
              let firstEcid = ecidArray.first,
              let ecid = firstEcid[ConciergeConstants.SharedState.EdgeIdentity.ID] as? String,
              !ecid.isEmpty
        else {
            return nil
        }

        return ecid
    }

    /// The Concierge server endpoint from configuration.
    var conciergeServer: String? {
        value?[ConciergeConstants.SharedState.Configuration.Concierge.SERVER] as? String
    }

    /// The Concierge datastream ID from configuration.
    var conciergeDatastream: String? {
        value?[ConciergeConstants.SharedState.Configuration.Concierge.DATASTREAM] as? String
    }

    /// Value for collect out of consents shared state
    var collectValue: String {
        guard let consents = value?[ConciergeConstants.SharedState.Consent.CONSENTS] as? [String: Any],
              let collect = consents[ConciergeConstants.SharedState.Consent.COLLECT] as? [String: Any],
              let val = collect[ConciergeConstants.SharedState.Consent.VAL] as? String else {
            return ConciergeConstants.Defaults.CONSENT_VALUE
        }

        return val
    }
}
