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

import AEPCore
import AEPBrandConcierge
import AEPEdge
import AEPEdgeIdentity
import AEPEdgeConsent

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        MobileCore.setLogLevel(.trace)

        let extensions = [
            AEPEdgeIdentity.Identity.self,
            Edge.self,
            Consent.self,
            Concierge.self
        ]

        MobileCore.registerExtensions(extensions) {
            MobileCore.configureWith(appId: "staging/1b50a869c4a2/570831bce333/launch-bcc070a55cca-development")

            // TODO: - temporary override of datastream and server until we get that sorted out
            MobileCore.updateConfigurationWith(configDict: [
                "concierge.configId": "6acf9d12-5018-4f84-8224-aac4900782f0",
                "concierge.server": "edge-int.adobedc.net"
            ])
        }

        return true
    }
}
