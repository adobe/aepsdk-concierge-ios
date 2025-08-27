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
import UIKit
import AVFoundation
import Speech
import AudioToolbox
@testable import AEPConcierge

struct ContentView: View {
    let stringToRender = """
# Header 1

This is a paragraph with inline styles: **bold**, _italic_, `inline code`, and a [link](https://example.com).

## Header 2

> Block quote line one
>
> Block quote line two

---

1. First ordered item
   1. Nested ordered (child 1)
   2. Nested ordered (child 2)
2. Second ordered item

- First unordered item
  - Nested unordered (child1)
  - Nested unordered (child2)
    - Extra nested unordered (child3) with lots of extra text to see how line wrapping works for these elements
- Second unordered item

```swift
// Code block with language hint
print("Hello, Markdown blocks!")
```

| Column A | Column B | Column C |
|:-------:|---------:|---------:|
| A1      | B1       | C1       |
| A2      | B2       | C2       |

Final paragraph to verify trailing layout.
"""

    var body: some View {
        TabView {
            // SwiftUI sample
            Concierge.wrap(
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        MarkdownBlockView(
                            markdown: stringToRender,
                            textColor: UIColor(.black)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                    VStack(spacing: 0) {
                        Button(action: {
                            MarkdownRenderer.debugDump(stringToRender, syntax: .full)
                        }) {
                            Text("DEBUG MARKDOWN")
                        }
                        Button(action: {
                            Concierge.show(
                                title: "Concierge",
                                subtitle: "Powered by Adobe"
                            )
                        }) {
                            Text("Open chat (SwiftUI)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 28)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.red)
                                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .conciergeTheme(
                        ConciergeTheme(
                            primary: .Brand.red,
                            secondary: .Brand.red,
                            onPrimary: .white,
                            textBody: .primary,
                            agentBubble: Color(UIColor.systemGray5),
                            onAgent: .primary,
                            surfaceLight: Color(UIColor.secondarySystemBackground),
                            surfaceDark: Color(UIColor.systemBackground)
                        )
                    )
                }

            )
            .tabItem { Label("SwiftUI", systemImage: "swift") }

            // UIKit sample
            UIKitDemoScreen()
                .tabItem { Label("UIKit", systemImage: "square.stack.3d.up.fill") }
        }
    }
}

/// SwiftUI wrapper that hosts the UIKit demo controller inside the tab.
private struct UIKitDemoScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let root = ConciergeUIKitDemoViewController()
        let nav = UINavigationController(rootViewController: root)
        return nav
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

#Preview {
    ContentView()
}
