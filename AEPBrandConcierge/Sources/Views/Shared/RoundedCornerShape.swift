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

/// A Shape that rounds only the specified corners.
///
/// This helper exists because on the project’s current minimum target (iOS 15),
/// SwiftUI’s built in APIs only support uniform corner rounding (non-uniform possible in iOS 16):
/// - `cornerRadius(_:)` applies the same radius to all four corners
/// - `RoundedRectangle` also rounds all corners uniformly
public struct RoundedCornerShape: Shape {
    public var radius: CGFloat = 14
    public var corners: UIRectCorner = [.allCorners]

    public init(radius: CGFloat = 14, corners: UIRectCorner = [.allCorners]) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
