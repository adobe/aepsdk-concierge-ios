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
import AEPBrandConcierge

struct LinkHandlingTestView: View {
    enum TestMode: String, CaseIterable, Identifiable {
        case interceptor = "Interceptor"
        case linkTypes = "Link Types"

        var id: String { rawValue }
    }

    @Binding var customLinkHandlingEnabled: Bool
    @Binding var closeChatOnIntercept: Bool
    @Binding var deepLinkURL: URL?
    var handleLink: (URL) -> Bool
    var onOpenChat: () -> Void

    @State private var selectedMode: TestMode = .interceptor
    @State private var simulatedResults: [URL: Bool] = [:]

    private let testURLs: [(label: String, url: URL)] = [
        ("demoapp://products/123", URL(string: "demoapp://products/123")!),
        ("demoapp://checkout", URL(string: "demoapp://checkout")!),
        ("https://www.adobe.com", URL(string: "https://www.adobe.com")!),
        ("https://special.adobe.com/page", URL(string: "https://special.adobe.com/page")!),
        ("tel:+1234567890", URL(string: "tel:+1234567890")!),
        ("mailto:test@adobe.com", URL(string: "mailto:test@adobe.com")!)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Test Mode", selection: $selectedMode) {
                    ForEach(TestMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedMode {
                case .interceptor:
                    interceptorContent
                case .linkTypes:
                    LinkTestView(deepLinkURL: $deepLinkURL)
                }
            }
            .navigationTitle("Testing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Interceptor content

    private var interceptorContent: some View {
        List {
            Section {
                Text("Tests the handleLink callback — when enabled, demoapp:// and adobe.com links are intercepted by the app. Optionally closes the chat on intercept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Custom Link Handling", isOn: $customLinkHandlingEnabled)
                if customLinkHandlingEnabled {
                    Toggle("Close Chat on Intercept", isOn: $closeChatOnIntercept)
                    Label("Intercepting **demoapp://** and **adobe.com** links", systemImage: "link.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("All links fall through to SDK", systemImage: "link")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Link Interceptor")
            } footer: {
                Text("This toggle only affects the chat when opened using the Open Chat button below. Chat opened from the SwiftUI and Magic tabs use default SDK link handling.")
            }

            Section {
                ForEach(testURLs, id: \.url) { item in
                    Button {
                        let result = handleLink(item.url)
                        simulatedResults[item.url] = result
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                if let result = simulatedResults[item.url] {
                                    Text(result ? "Handled by app" : "Fell through to SDK")
                                        .font(.caption)
                                        .foregroundStyle(result ? .green : .orange)
                                }
                            }
                            Spacer()
                            if let result = simulatedResults[item.url] {
                                Image(systemName: result ? "checkmark.circle.fill" : "arrow.right.circle")
                                    .foregroundStyle(result ? .green : .orange)
                            } else {
                                Image(systemName: "hand.tap")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !simulatedResults.isEmpty {
                    Button("Clear Results", role: .destructive) {
                        simulatedResults.removeAll()
                    }
                }
            } header: {
                Text("Simulated Link Taps")
            } footer: {
                Text("Tapping calls handleLink() directly, simulating what happens when a link is tapped in the chat.")
            }

            Section {
                Button {
                    onOpenChat()
                } label: {
                    Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                }
            } header: {
                Text("Chat view")
            } footer: {
                Text("Switches to the SwiftUI tab and opens the chat with the current link handling setting applied.")
            }
        }
    }
}
