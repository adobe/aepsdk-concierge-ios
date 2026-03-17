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
import UIKit
import AEPBrandConcierge

/// Manual testing view for the three URL types handled by `ConciergeLinkHandler`:
/// deep links, universal/app links, and standard web links.
struct LinkTestView: View {
    @Binding var deepLinkURL: URL?
    @State private var resultLog: [LinkTestResult] = []

    private let testLinks: [TestLink] = [
        TestLink(
            label: "Deep Link (this app -> Magic tab)",
            urlString: "conciergedemo://magic",
            category: .deepLink
        ),
        TestLink(
            label: "Deep Link (custom scheme)",
            urlString: "myapp://products/123",
            category: .deepLink
        ),
        TestLink(
            label: "Deep Link (mailto)",
            urlString: "mailto:test@example.com",
            category: .deepLink
        ),
        TestLink(
            label: "Deep Link (tel)",
            urlString: "tel:+15551234567",
            category: .deepLink
        ),
        TestLink(
            label: "Apple Maps (search query)",
            urlString: "https://maps.apple.com/?q=coffee",
            category: .universalLink
        ),
        TestLink(
            label: "Apple Maps (coordinates)",
            urlString: "https://maps.apple.com/?ll=37.7749,-122.4194&q=San+Francisco",
            category: .universalLink
        ),
        TestLink(
            label: "Apple Maps (directions)",
            urlString: "https://maps.apple.com/?daddr=1+Infinite+Loop,+Cupertino,+CA",
            category: .universalLink
        ),
        TestLink(
            label: "Web Link (adobe.com)",
            urlString: "https://www.adobe.com",
            category: .webLink
        ),
        TestLink(
            label: "Web Link with fragment",
            urlString: "https://www.example.com/page#section",
            category: .webLink
        )
    ]

    var body: some View {
        List {
            if let receivedURL = deepLinkURL {
                Section(header: Text("Deep Link Received")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.down.app.fill")
                                .foregroundStyle(.green)
                            Text("App opened via deep link")
                                .font(.subheadline.weight(.semibold))
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                deepLinkDetail(label: "Scheme", value: receivedURL.scheme ?? "—")
                                deepLinkDetail(label: "Host", value: receivedURL.host ?? "—")
                                deepLinkDetail(label: "Path", value: receivedURL.path)
                                deepLinkDetail(label: "Full URL", value: receivedURL.absoluteString)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button("Dismiss") {
                            deepLinkURL = nil
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Text("Tests the SDK's ConciergeLinkHandler routing — tap a URL to see whether it routes to openInWebView or openWithSystem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(groupedCategories, id: \.category) { group in
                Section(header: Text(group.category.rawValue)) {
                    ForEach(group.links) { link in
                        Button {
                            testLink(link)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(link.label)
                                    .font(.subheadline.weight(.medium))
                                Text(link.urlString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section(header: resultHeaderView) {
                if resultLog.isEmpty {
                    Text("No results yet — tap a link above.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(resultLog) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: result.iconName)
                                    .foregroundColor(result.iconColor)
                                Text(result.handler)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text(result.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(result.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .tint(.primary)
    }

    private var resultHeaderView: some View {
        HStack {
            Text("Results")
            Spacer()
            if !resultLog.isEmpty {
                Button("Clear") {
                    resultLog.removeAll()
                }
                .font(.caption)
            }
        }
    }

    private var groupedCategories: [(category: LinkCategory, links: [TestLink])] {
        LinkCategory.allCases.compactMap { category in
            let links = testLinks.filter { $0.category == category }
            return links.isEmpty ? nil : (category: category, links: links)
        }
    }

    private func testLink(_ link: TestLink) {
        guard let url = URL(string: link.urlString) else {
            appendResult(urlString: link.urlString, handler: "Invalid URL", route: .invalid)
            return
        }

        ConciergeLinkHandler.handleURL(
            url,
            openInWebView: { handledURL in
                appendResult(urlString: handledURL.absoluteString, handler: "openInWebView", route: .webView)
            },
            openWithSystem: { handledURL in
                appendResult(urlString: handledURL.absoluteString, handler: "openWithSystem", route: .system)
                UIApplication.shared.open(handledURL)
            }
        )
    }

    private func deepLinkDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func appendResult(urlString: String, handler: String, route: LinkTestRoute) {
        let result = LinkTestResult(
            urlString: urlString,
            handler: handler,
            route: route,
            timestamp: Date()
        )
        resultLog.insert(result, at: 0)
    }
}

// MARK: - Models

private enum LinkCategory: String, CaseIterable {
    case deepLink = "Deep Link"
    case universalLink = "Universal / App Link"
    case webLink = "Web Link"
}

private struct TestLink: Identifiable {
    let id = UUID()
    let label: String
    let urlString: String
    let category: LinkCategory
}

private enum LinkTestRoute {
    case webView
    case system
    case invalid
}

private struct LinkTestResult: Identifiable {
    let id = UUID()
    let urlString: String
    let handler: String
    let route: LinkTestRoute
    let timestamp: Date

    var iconName: String {
        switch route {
        case .webView: return "globe"
        case .system: return "arrow.up.forward.app"
        case .invalid: return "exclamationmark.triangle"
        }
    }

    var iconColor: Color {
        switch route {
        case .webView: return .blue
        case .system: return .orange
        case .invalid: return .red
        }
    }
}

#Preview {
    LinkTestView(deepLinkURL: .constant(URL(string: "conciergedemo://products/123")))
}
