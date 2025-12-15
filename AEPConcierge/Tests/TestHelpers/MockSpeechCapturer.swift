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
@testable import AEPConcierge

final class MockSpeechCapturer: SpeechCapturing {
    var responseProcessor: ((String) -> Void)?
    var available: Bool = true
    var denied: Bool = false
    var neverAsked: Bool = false
    private(set) var beginCaptures: Int = 0
    private(set) var endCaptures: Int = 0
    private(set) var permissionRequests: Int = 0
    var transcriptToReturn: String? = nil

    func initialize(responseProcessor: ((String) -> Void)?) {
        self.responseProcessor = responseProcessor
    }
    func isAvailable() -> Bool { available }
    func hasPermissionBeenDenied() -> Bool { denied }
    func hasNeverBeenAskedForPermission() -> Bool { neverAsked }
    func requestSpeechAndMicrophonePermissions(completion: @escaping () -> Void) {
        permissionRequests += 1
        // Simulate async permission request completion
        DispatchQueue.main.async {
            completion()
        }
    }
    func beginCapture() { beginCaptures += 1 }
    func endCapture(completion: @escaping (String?, Error?) -> Void) {
        endCaptures += 1
        completion(transcriptToReturn, nil)
    }
}
