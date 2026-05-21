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

import AEPAnalytics
import AEPCore
import AEPBrandConcierge
import AEPEdge
import AEPEdgeIdentity
import AEPEdgeConsent
import AEPIdentity

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        MobileCore.setLogLevel(.trace)

        let extensions = [
            AEPEdgeIdentity.Identity.self,
            AEPIdentity.Identity.self,
            Edge.self,
            Analytics.self,
            Concierge.self
        ]

        MobileCore.registerExtensions(extensions) {
            MobileCore.configureWith(appId: "3149c49c3910/629a865c475d/launch-82c478370074")
                       MobileCore.updateConfigurationWith(configDict: [
                           "concierge.server": "edge.adobedc.net",
                           "concierge.configId": "4eb99a22-309c-471c-a1ab-f82560d87a0d"
                       ])
        }

        ConciergeTracker.start()
        Concierge.enableTracking()

        return true
    }
}
