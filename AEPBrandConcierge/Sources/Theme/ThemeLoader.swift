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
import AEPServices

/// Helper for loading ConciergeTheme from a bundled JSON file
public enum ConciergeThemeLoader {
    /// Loads a ConciergeTheme from a bundled JSON file
    /// - Parameters:
    ///   - filename: Name of the JSON file (without extension) in the bundle
    ///   - bundle: Bundle to search for the file (defaults to main bundle)
    /// - Returns: Decoded ConciergeTheme instance, or nil if loading/decoding fails
    /// - Note: JSON keys should match the web styleConfiguration format for cross platform compatibility
    public static func load(from filename: String, in bundle: Bundle = .main) -> ConciergeTheme? {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            print("[ConciergeThemeLoader] Missing resource \(filename).json in bundle \(bundle.bundlePath)")
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("[ConciergeThemeLoader] Failed to read data for \(filename).json at \(url.path)")
            return nil
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ConciergeTheme.self, from: data)
        } catch let decodingError as DecodingError {
            let message: String
            switch decodingError {
            case .typeMismatch(_, let context),
                 .valueNotFound(_, let context),
                 .keyNotFound(_, let context),
                 .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                message = "\(context.debugDescription) codingPath=\(path)"
            @unknown default:
                message = "\(decodingError)"
            }
            print("[ConciergeThemeLoader] Failed to decode theme '\(filename).json': \(message)")
            return nil
        } catch {
            print("[ConciergeThemeLoader] Failed to decode theme '\(filename).json': \(error)")
            return nil
        }
    }
    
    /// Creates a default ConciergeTheme instance
    /// - Returns: A ConciergeTheme with all default values
    public static func `default`() -> ConciergeTheme {
        ConciergeTheme()
    }
}
