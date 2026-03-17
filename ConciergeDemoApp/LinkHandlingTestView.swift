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
    @Binding var customLinkHandlingEnabled: Bool
    var handleLink: (URL) -> Bool

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
            List {
                // MARK: - Toggle
                Section {
                    Toggle("Custom Link Handling", isOn: $customLinkHandlingEnabled)
                    if customLinkHandlingEnabled {
                        Label("Intercepting **demoapp://** links", systemImage: "link.badge.plus")
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
                    Text("This toggle affects all tabs — SwiftUI, Magic, and the simulated links below.")
                }

                // MARK: - Simulated Links
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

                // MARK: - Open Chat
                Section {
                    Button {
                        Concierge.show(
                            surfaces: ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"],
                            title: "Concierge",
                            subtitle: "Powered by Adobe",
                            handleLink: handleLink
                        )
                    } label: {
                        Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                } header: {
                    Text("Live Chat")
                } footer: {
                    Text("Opens the chat with the current link handling setting applied. Links in chat responses will use the interceptor.")
                }
            }
            .navigationTitle("Testing")
        }
    }
}
