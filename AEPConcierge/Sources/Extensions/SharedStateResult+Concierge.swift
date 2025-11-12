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

extension SharedStateResult {
    var ecid: String? {
        guard let identityMap = value?[Constants.SharedState.EdgeIdentity.IDENTITY_MAP] as? [AnyHashable: Any] else {
            return nil
        }

        guard let ecidArray = identityMap[Constants.SharedState.EdgeIdentity.ECID] as? [[AnyHashable: Any]],
              let firstEcid = ecidArray.first,
              let ecid = firstEcid[Constants.SharedState.EdgeIdentity.ID] as? String,
              !ecid.isEmpty
        else {
            return nil
        }
        
        return ecid
    }
    
    var conciergeServer: String? {
        value?[Constants.SharedState.Configuration.Concierge.SERVER] as? String
    }
    
    var conciergeDatastream: String? {
        value?[Constants.SharedState.Configuration.Concierge.DATASTREAM] as? String
    }
    
    var conciergeSurfaces: [String]? {
        value?[Constants.SharedState.Configuration.Concierge.SURFACES] as? [String]
    }
}
