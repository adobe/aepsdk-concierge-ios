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
import AEPServices
import AEPBrandConcierge

struct ContentView: View {
    private enum DemoThemeFile: String, CaseIterable, Identifiable {
        case defaultTheme = "theme-default"
        case allProperties = "theme-all-properties"
        case demoTheme = "themeDemo"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .defaultTheme:
                return "Default"
            case .allProperties:
                return "All Props"
            case .demoTheme:
                return "Demo"
            }
        }
    }

    enum DemoTab: Hashable {
        case swiftUI, magic, uiKit, testing
    }

    @ObservedObject var deepLinkState: DeepLinkState

    @State private var selectedThemeFile: DemoThemeFile = .demoTheme
    @State private var loadedTheme: ConciergeTheme = ConciergeThemeLoader.default()
    @State private var themeLoadStatusText: String = ""
    @State private var interceptedLinkURL: URL?
    /// Drives the checkout sheet. Cleared on dismissal; `pendingCheckout` keeps the product around
    /// long enough for the dismissal handler to build the handoff.
    @State private var checkoutProduct: CheckoutProduct?
    @State private var pendingCheckout: CheckoutProduct?
    @State private var checkoutWasCompleted = false
    @State private var customLinkHandlingEnabled: Bool = true
    @State private var closeChatOnIntercept: Bool = false
    @State private var selectedTab: DemoTab = .swiftUI

    /// The "Mock \"Buy now\" response" toggle's value. Lifted out of `BuyNowMockView` so the single
    /// place that owns `BuyNowMockURLProtocol.isEnabled` can combine it with the current tab.
    @State private var buyNowMockRequested: Bool = true
    /// Whether the Testing tab is currently showing the Buy Now Mock scenario.
    @State private var buyNowMockScenarioSelected: Bool = false
    /// The "Slow response" toggle and its delay, used to see how the chat behaves when Brand
    /// Concierge takes a long time to answer - including past the SDK's read timeout.
    @State private var buyNowMockSlowResponse: Bool = false
    @State private var buyNowMockSlowResponseDelay: Double = 5

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: - manual call

            Concierge.wrap(
                VStack {
                    VStack {
                        Picker("Theme", selection: $selectedThemeFile) {
                            ForEach(DemoThemeFile.allCases) { themeFile in
                                Text(themeFile.title).tag(themeFile)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        Text("Loaded theme: \(loadedTheme.metadata.brandName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        Text(themeLoadStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 2)

                        Button(action: {
                            Concierge.show(
                                surfaces: ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"],
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
                },
                hideButton: true
            )

            // Apply theme above ConciergeWrapper so the overlay (and chat view) can read it
            .conciergeTheme(loadedTheme)
            .tag(DemoTab.swiftUI)
            .tabItem { Label("SwiftUI", systemImage: "swift") }

            // MARK: - floating button

            Concierge.wrap(
                Label(
                    "hello, world", systemImage: "world"
                ),
                surfaces: ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"]
            )
            .conciergeTheme(loadedTheme)
            .tag(DemoTab.magic)
            .tabItem { Label("Magic", systemImage: "sparkles.square.filled.on.square") }

            // MARK: - UIKit example

            UIKitDemoScreen()
                .tag(DemoTab.uiKit)
                .tabItem { Label("UIKit", systemImage: "square.stack.3d.up.fill") }

            // MARK: - Testing (link handling, auth token, "Buy now" mock — see TestingHubView)

            TestingHubView(
                customLinkHandlingEnabled: $customLinkHandlingEnabled,
                closeChatOnIntercept: $closeChatOnIntercept,
                deepLinkURL: $deepLinkState.receivedURL,
                buyNowMockRequested: $buyNowMockRequested,
                buyNowMockScenarioSelected: $buyNowMockScenarioSelected,
                buyNowMockSlowResponse: $buyNowMockSlowResponse,
                buyNowMockSlowResponseDelay: $buyNowMockSlowResponseDelay,
                handleLink: handleLink,
                onOpenChatViaSwiftUITab: {
                    selectedTab = .swiftUI
                    Concierge.show(
                        surfaces: ["web://edge-int.adobedc.net/brand-concierge/pages/745F37C35E4B776E0A49421B@AdobeOrg/acom_m15/index.html"],
                        title: "Concierge",
                        subtitle: "Powered by Adobe",
                        handleLink: handleLink
                    )
                }
            )
            .tag(DemoTab.testing)
            .tabItem { Label("Testing", systemImage: "flask") }
        }
        .onAppear {
            loadTheme()
            syncBuyNowMock()
        }
        .onChange(of: selectedThemeFile) { _ in
            loadTheme()
        }
        .onChange(of: selectedTab) { _ in
            syncBuyNowMock()
        }
        .onChange(of: buyNowMockRequested) { _ in
            syncBuyNowMock()
        }
        .onChange(of: buyNowMockScenarioSelected) { _ in
            syncBuyNowMock()
        }
        .onChange(of: buyNowMockSlowResponse) { _ in
            syncBuyNowMock()
        }
        .onChange(of: buyNowMockSlowResponseDelay) { _ in
            syncBuyNowMock()
        }
        .onChange(of: deepLinkState.targetTab) { tab in
            if let tab {
                selectedTab = tab
                deepLinkState.targetTab = nil
            }
        }
        .alert("Link Intercepted", isPresented: showInterceptedAlert, presenting: interceptedLinkURL) { _ in
            Button("OK") {
                interceptedLinkURL = nil
            }
        } message: { url in
            if closeChatOnIntercept {
                Text("The app intercepted this link and closed the chat:\n\(url.absoluteString)")
            } else {
                Text("The app intercepted this link:\n\(url.absoluteString)")
            }
        }
        .sheet(item: $checkoutProduct, onDismiss: finishCheckout) { product in
            CheckoutView(
                product: product,
                onComplete: {
                    checkoutWasCompleted = true
                    checkoutProduct = nil
                },
                onCancel: { checkoutProduct = nil }
            )
        }
    }

    private var showInterceptedAlert: Binding<Bool> {
        Binding(
            get: { interceptedLinkURL != nil },
            set: { if !$0 { interceptedLinkURL = nil } }
        )
    }

    /// Scopes the canned "Buy now" responses to the Testing tab's Buy Now Mock scenario, so chat
    /// opened from anywhere else talks to the real Concierge service.
    ///
    /// Gated at request time via `isEnabled` rather than by swapping
    /// `Concierge.urlSessionConfigurationForTesting`: the SDK resolves that configuration once,
    /// when it *creates* a session, and reuses an existing session across tabs here - so a
    /// session-level swap would be ignored for whichever tab opened the chat second.
    private func syncBuyNowMock() {
        let isActive = selectedTab == .testing
            && buyNowMockScenarioSelected
            && buyNowMockRequested

        BuyNowMockURLProtocol.isEnabled = isActive
        // Tied to the same condition so the artificial delay can't survive the mock being disarmed.
        BuyNowMockURLProtocol.responseDelay = (isActive && buyNowMockSlowResponse) ? buyNowMockSlowResponseDelay : 0
    }

    private func handleLink(_ url: URL) -> Bool {
        guard customLinkHandlingEnabled else { return false }

        // A "Buy now" CTA opens the mock checkout screen rather than the generic intercept alert:
        // the whole point of the handoff API is that the transaction happens in the app's own UI.
        // The chat is left open behind the sheet so the forwarded turn is visible after checkout.
        if url.host == "buy-now", let product = CheckoutProduct(buyNowURL: url) {
            // A second "Buy now" tapped during the sheet's dismissal animation would overwrite
            // `pendingCheckout` and reset `checkoutWasCompleted` *before* `onDismiss` runs for the
            // first one, reporting the previous outcome against the newly tapped product.
            guard pendingCheckout == nil else { return true }

            pendingCheckout = product
            checkoutWasCompleted = false
            checkoutProduct = product
            return true
        }

        if url.scheme == "demoapp" || url.host == "adobe.com" || url.host == "www.adobe.com" {
            if closeChatOnIntercept {
                Concierge.hide()
            }
            interceptedLinkURL = url
            return true
        }
        return false
    }

    /// Runs when the checkout sheet goes away for *any* reason, so no exit path can silently skip
    /// the handoff. `checkoutWasCompleted` is the only thing that distinguishes them.
    private func finishCheckout() {
        guard let product = pendingCheckout else { return }
        pendingCheckout = nil

        let outcome: CheckoutOutcome = checkoutWasCompleted ? .purchased : .abandoned
        checkoutWasCompleted = false
        dispatchCheckoutDataHandoff(for: product, outcome: outcome)
    }

    /// Demo-only: forwards the checkout result to the SDK the same way a real integrator's
    /// post-checkout code would. Both outcomes are reported - an abandoned cart is a useful signal
    /// too, and forwarding only the happy path would make the API look purchase-specific.
    private func dispatchCheckoutDataHandoff(for product: CheckoutProduct, outcome: CheckoutOutcome) {
        var productListItem: [String: Any] = ["name": product.name, "quantity": 1]
        if let priceTotal = product.priceTotal {
            productListItem["priceTotal"] = priceTotal
        }

        var commerce: [String: Any] = [:]
        let routingHint: String
        let localMessage: String?

        switch outcome {
        case .purchased:
            routingHint = "successful-checkout"
            localMessage = "Thank you for purchasing \(product.name)"

            var order: [String: Any] = ["purchaseID": UUID().uuidString, "currencyCode": "USD"]
            if let priceTotal = product.priceTotal {
                order["priceTotal"] = priceTotal
            }
            commerce["order"] = order
            commerce["purchases"] = ["value": 1]

        case .abandoned:
            routingHint = "abandoned-checkout"
            // No local message: nothing happened worth confirming in the transcript, so the only
            // thing that should appear is whatever Product Advisor decides to say about it.
            localMessage = nil
            commerce["abandons"] = ["value": 1]
        }

        Concierge.sendDataHandoff(
            routingHint: routingHint,
            xdmFields: [
                "commerce": commerce,
                "productListItems": [productListItem]
            ],
            localMessage: localMessage
        ) { result in
            Log.debug(label: "ConciergeDemoApp", "Checkout data handoff (\(routingHint)) response: \(String(describing: result))")
        }
    }

    private func loadTheme() {
        let filename = selectedThemeFile.rawValue

        if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
            themeLoadStatusText = "Theme file: \(url.lastPathComponent)"
        } else {
            themeLoadStatusText = "Theme file missing in main bundle: \(filename).json"
        }

        loadedTheme = ConciergeThemeLoader.load(from: filename, in: .main) ?? ConciergeThemeLoader.default()
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
    ContentView(deepLinkState: DeepLinkState())
}
