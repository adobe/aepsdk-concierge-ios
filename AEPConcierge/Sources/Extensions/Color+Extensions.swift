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

// TODO: - this needs to not be public and colors should be read from configuration
public extension Color {
    static var TextTitle: Color {
        // white
        Color.white
    }
    
    static var TextBody: Color {
        // grey
        Color(hex: 0xFFD6D6D6)
    }
    
    static var PrimaryLight: Color {
        // navy
        Color(hex: 0xFF001A36)
    }
    
    static var PrimaryDark: Color {
        // navy
        Color(hex: 0xFF001F48)
    }
    
    static var Secondary: Color {
        // maroon
        Color(hex: 0xFF8F0000)
    }
    
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
} 
