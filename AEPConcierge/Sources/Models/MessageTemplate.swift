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

public enum MessageTemplate {
    case basic(isUserMessage: Bool)
    case thumbnail(imageSource: ImageSource, title: String?, text: String)
    case numbered(number: Int?, title: String?, body: String?)
    case carousel(imageSource: ImageSource, title: String, body: String)
    case carouselGroup([Message])
    case divider
}

public enum ImageSource {
    case local(Image)
    case remote(URL)
} 
