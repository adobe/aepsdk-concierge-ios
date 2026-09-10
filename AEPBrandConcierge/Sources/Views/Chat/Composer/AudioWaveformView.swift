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
    let gradient: ConciergeGradient?

    init(audioLevel: Float, barColor: Color, barCount: Int = 5, gradient: ConciergeGradient? = nil) {
        self.audioLevel = audioLevel
        self.barColor = barColor
        self.barCount = barCount
        self.gradient = gradient
    }

    private var barFill: AnyShapeStyle {
        conciergeShapeStyle(color: nil, gradient: gradient, fallback: barColor)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let fill = barFill
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = sin(time * 4.0 + Double(index) * 1.2)
                    let levelFactor = pow(Double(max(audioLevel, 0.02)), 0.6)
                    let scale = 0.12 + 0.88 * levelFactor * ((phase + 1.0) / 2.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill)
                        .frame(width: 3, height: 20 * scale)
                }
            }
            .frame(height: 20)
        }
    }
}
