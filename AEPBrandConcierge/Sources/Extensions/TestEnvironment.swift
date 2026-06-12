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
        // XCUITest launches the app as a separate process. That process needs normal focus
        // The test runner passes --ui-testing so we can opt out of the unit-test guard here.
        if CommandLine.arguments.contains("--ui-testing") {
            return false
        }

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

    /// Returns true when the app was launched by an XCUITest runner (which passes the
    /// `--ui-testing` launch argument).
    ///
    /// Launch arguments are immutable for the lifetime of the process, so this is evaluated
    /// once and cached (mirroring `isRunningTests`). It is read in hot paths such as
    /// `SelectableTextView.updateUIView`, so it must not re-scan the arguments on every call.
    static let isUITesting: Bool = {
        #if DEBUG
        return CommandLine.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }()
}
