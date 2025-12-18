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

enum TestEnvironment {
    /// Returns true when the current process appears to be running under XCTest (unit tests, UI tests,
    /// or snapshot tests).
    ///
    /// This is evaluated once per process to avoid repeatedly reading the environment dictionary.
    static let isRunningTests: Bool = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment

        // Xcode sets this when launching tests.
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        // Secondary signal in case the configuration file path is not present in a particular runner.
        if NSClassFromString("XCTestCase") != nil {
            return true
        }
        #endif

        return false
    }()
}


