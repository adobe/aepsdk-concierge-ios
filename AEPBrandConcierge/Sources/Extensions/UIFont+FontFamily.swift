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

import UIKit

extension UIFont {
    /// Resolves a font from a family name + weight using `UIFontDescriptor` trait matching,
    /// so the correct named face (e.g. Raleway-SemiBold) is loaded without SwiftUI trying
    /// to synthesize a weight variant from a single face.
    static func fromFamily(_ family: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: weight.rawValue]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            .traits: traits
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
