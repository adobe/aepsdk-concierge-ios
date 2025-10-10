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

struct RemoteImageView: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat?

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    sized(ProgressView())
                case .success(let image):
                    sized(image.resizable().scaledToFill()).clipped()
                case .failure:
                    sized(Image(systemName: "photo"))
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            sized(Image(systemName: "photo"))
        }
    }

    @ViewBuilder
    private func sized<T: View>(_ view: T) -> some View {
        if let height = height {
            view.frame(width: width, height: height)
        } else {
            view.frame(width: width)
        }
    }
}


