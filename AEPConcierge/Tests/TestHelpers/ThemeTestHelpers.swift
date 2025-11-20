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
import XCTest
@testable import AEPConcierge

/// Helper utilities for theme tests
enum ThemeTestHelpers {
    /// Loads a JSON file from the test bundle
    /// - Parameter name: Name of the JSON file (without extension)
    /// - Returns: Data from the JSON file, or nil if not found
    static func loadThemeJSON(named name: String) -> Data? {
        guard let url = Bundle(for: ThemeTestBundleClass.self).url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
    
    /// Gets the test bundle reference
    /// - Returns: Bundle for the test target
    static func makeTestBundle() -> Bundle {
        Bundle(for: ThemeTestBundleClass.self)
    }
    
}

/// Private class used to locate the test bundle
private class ThemeTestBundleClass {}

