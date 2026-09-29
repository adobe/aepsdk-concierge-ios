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

/// The product a "Buy now" CTA handed off to the app, parsed from its `demoapp://buy-now` deep
/// link, so the flow is driven by the response payload rather than hardcoded in the demo app.
struct CheckoutProduct: Identifiable, Equatable {
    let id = UUID()
    let name: String
    /// The price exactly as the product card displayed it, e.g. "$249.99".
    let displayPrice: String?
    /// `displayPrice` as a number for the XDM payload, e.g. 249.99.
    let priceTotal: Double?
    let symbolName: String

    init?(buyNowURL url: URL) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        guard let name = value("title"), !name.isEmpty else { return nil }

        self.name = name
        self.displayPrice = value("price")
        self.priceTotal = Double((value("price") ?? "").filter { $0.isNumber || $0 == "." })
        self.symbolName = value("symbol") ?? "shippingbox.fill"
    }
}

/// How the shopper left the checkout screen. Both outcomes are handed back to Concierge - an
/// abandoned cart is just as useful a signal to Product Advisor as a completed one.
enum CheckoutOutcome {
    case purchased
    case abandoned
}

/// Mock checkout screen presented when a "Buy now" CTA is tapped in the chat. Stands in for the
/// native transaction flow a real integrator would run before calling `Concierge.sendDataHandoff`.
struct CheckoutView: View {
    let product: CheckoutProduct
    let onComplete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    productImage
                        .padding(.top, 28)

                    Text(product.name)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)

                    orderSummary
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            actions
        }
    }

    private var header: some View {
        ZStack {
            Text("Checkout")
                .font(.headline)

            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close checkout")
            }
        }
        .padding()
    }

    private var productImage: some View {
        Image(systemName: product.symbolName)
            .font(.system(size: 72, weight: .light))
            .foregroundStyle(Color.accentColor)
            .frame(width: 160, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private var orderSummary: some View {
        VStack(spacing: 10) {
            summaryRow("Subtotal", product.displayPrice ?? "—")
            summaryRow("Shipping", "Free")
            Divider()
            summaryRow("Total", product.displayPrice ?? "—", emphasized: true)
        }
    }

    private func summaryRow(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(emphasized ? .body.weight(.semibold) : .subheadline)
        .foregroundStyle(emphasized ? Color.primary : Color.secondary)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: onComplete) {
                Text("Complete Purchase")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Button(role: .cancel, action: onCancel) {
                Text("Abandon purchase")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

#Preview {
    CheckoutView(
        product: CheckoutProduct(buyNowURL: URL(string: "demoapp://buy-now?title=Wireless%20Noise-Cancelling%20Headphones&price=%24249.99&symbol=headphones")!)!,
        onComplete: {},
        onCancel: {}
    )
}
