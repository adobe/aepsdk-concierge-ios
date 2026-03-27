/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import SwiftUI

/// Animated waveform bars that respond to the current audio input level.
struct AudioWaveformView: View {
    let audioLevel: Float
    let barColor: Color
    let barCount: Int

    init(audioLevel: Float, barColor: Color, barCount: Int = 5) {
        self.audioLevel = audioLevel
        self.barColor = barColor
        self.barCount = barCount
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = sin(time * 4.0 + Double(index) * 0.8)
                    let levelFactor = Double(max(audioLevel, 0.05))
                    let scale = 0.3 + 0.7 * levelFactor * ((phase + 1.0) / 2.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: 3, height: 20 * scale)
                }
            }
            .frame(height: 20)
        }
    }
}
