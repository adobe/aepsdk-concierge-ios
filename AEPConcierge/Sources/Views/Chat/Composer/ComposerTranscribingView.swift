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

struct ComposerTranscribingView: View {
    let onCancel: () -> Void
    let measuredHeight: CGFloat

    var body: some View {
        HStack {
            Button(action: onCancel) {
                BrandIcon(assetName: "S2_Icon_Close_20_N", systemName: "xmark")
                    .foregroundColor(Color.Secondary)
            }
            .buttonStyle(.plain)
            Text("Transcribing")
                .font(.system(.subheadline))
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            BrandIcon(assetName: "S2_Icon_Checkmark_20_N", systemName: "checkmark")
                .foregroundColor(Color.secondary.opacity(0.4))
        }
        .frame(height: max(40, measuredHeight))
    }
}


