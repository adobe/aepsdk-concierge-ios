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
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: name)
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.animation = LottieAnimation.named(name)
        uiView.loopMode = .loop
        uiView.contentMode = .scaleAspectFit
        uiView.play()
    }
} 
