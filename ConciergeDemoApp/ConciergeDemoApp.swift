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

import SwiftUI

@main
struct ConciergeDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var deepLinkState = DeepLinkState()

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkState: deepLinkState)
                .tint(Color.Brand.red)
                .onOpenURL { url in
                    deepLinkState.receivedURL = url
                    let path = url.host ?? ""
                    switch path {
                    case "magic":
                        deepLinkState.targetTab = .magic
                    default:
                        deepLinkState.targetTab = .testing
                    }
                }
        }
    }
}

class DeepLinkState: ObservableObject {
    @Published var receivedURL: URL?
    @Published var targetTab: ContentView.DemoTab?
}
