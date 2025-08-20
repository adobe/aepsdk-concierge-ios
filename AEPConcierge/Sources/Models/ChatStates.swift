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

// MARK: - Input Stream State Machine

public enum InputError: Error, Equatable {
    case permissionDenied
    case transcriptionFailed
    case unknown
}

public enum InputState: Equatable {
    case empty
    case editing
    case recording
    case transcribing
    case error(InputError)
}

// MARK: - Chat Controller State Machine

public enum ChatError: Error, Equatable {
    case networkFailure
    case modelError
    case cancelled
}

public enum ChatState: Equatable {
    case idle
    case processing
    case error(ChatError)
}


