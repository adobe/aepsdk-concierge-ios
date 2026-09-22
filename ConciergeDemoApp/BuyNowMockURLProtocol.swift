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

import Foundation
import UIKit

/// Intercepts the Concierge chat network request and answers it from a canned SSE response.
///
/// Asking `productCardsPrompt` returns product cards with a `primary` action, the real payload
/// shape that drives the "Buy now" CTA, so the SDK's production pipeline renders it exactly as it
/// would for a live response. The post-checkout handoff turn gets a Product Advisor style
/// recommendation instead, and any other turn gets a plain text reply.
///
/// Must be added to the injected `URLSessionConfiguration.protocolClasses` (see
/// `Concierge.urlSessionConfigurationForTesting` in `AppDelegate.swift`) rather than registered
/// via `URLProtocol.registerClass` — that isn't reliably consulted for `ConciergeChatService`'s
/// custom `URLSession`, or once the connection negotiates HTTP/3 (QUIC). Inert unless `isEnabled`
/// is explicitly turned on from the "Buy Now" tab.
final class BuyNowMockURLProtocol: URLProtocol {
    static var isEnabled = false

    /// Artificial time-to-first-byte, in seconds, applied to every intercepted turn. Lets the demo
    /// show a sluggish backend, and - once this exceeds `READ_TIMEOUT` (15s) - the timeout failure
    /// path. `0` delivers immediately.
    static var responseDelay: TimeInterval = 0

    /// Keeps the delayed delivery cancellable so a torn-down task (user closed the chat, SDK timed
    /// the request out) doesn't message a dead client afterwards.
    private var deliveryWorkItem: DispatchWorkItem?

    private static let deliveryQueue = DispatchQueue(label: "com.adobe.aep.ConciergeDemoApp.buyNowMockDelivery")

    /// `ConciergeChatService` builds the path as `/brand-concierge` + an optional server-provided
    /// region segment + `/conversations`. Matching prefix and suffix rather than a fixed string
    /// keeps the mock working whichever region the datastream resolves to.
    override class func canInit(with request: URLRequest) -> Bool {
        guard isEnabled, let url = request.url, url.host == "edge-int.adobedc.net" else { return false }
        return url.path.hasPrefix("/brand-concierge") && url.path.hasSuffix("/conversations")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Resolved up front: `requestInfo` drains the body stream, which is only reliably readable
        // while the loading system still considers the request live.
        let responseData = Self.responseData(for: Self.requestInfo(from: request))

        // `DispatchWorkItem.cancel()` from `stopLoading` prevents a pending item from running at
        // all, so a torn-down task never reaches `deliver`.
        let work = DispatchWorkItem { [weak self] in
            self?.deliver(responseData, for: url)
        }
        deliveryWorkItem = work

        let delay = Self.responseDelay
        if delay > 0 {
            Self.deliveryQueue.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            Self.deliveryQueue.async(execute: work)
        }
    }

    override func stopLoading() {
        deliveryWorkItem?.cancel()
        deliveryWorkItem = nil
    }

    private func deliver(_ data: Data, for url: URL) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // MARK: - Response selection

    /// The prompt a tester must type to get the product carousel, so ordinary chatter stays
    /// card-free.
    static let productCardsPrompt = "What are some good noise cancelling headphones?"

    /// Routing hints the demo app forwards via `Concierge.sendDataHandoff(...)` from checkout.
    private static let checkoutRoutingHint = "successful-checkout"
    private static let abandonedCheckoutRoutingHint = "abandoned-checkout"

    /// The parts of an outgoing chat request this mock branches on.
    private struct RequestInfo {
        /// `events[0].query.conversation.message` - the typed message, or the handoff routing hint.
        let message: String?
        /// `events[0].xdm.productListItems[0].name` - only present on the data-handoff turn.
        let purchasedProductName: String?
    }

    private static func responseData(for info: RequestInfo) -> Data {
        guard let message = info.message else { return productCardsSSEData }

        if matchesProductCardsPrompt(message) {
            return productCardsSSEData
        }
        if message.caseInsensitiveCompare(checkoutRoutingHint) == .orderedSame {
            return checkoutFollowUpSSEData(purchasedProductName: info.purchasedProductName)
        }
        if message.caseInsensitiveCompare(abandonedCheckoutRoutingHint) == .orderedSame {
            return abandonedCheckoutSSEData(abandonedProductName: info.purchasedProductName)
        }
        return sseData(message: "Ask me \"\(productCardsPrompt)\" to see the mocked product recommendations.")
    }

    /// Deliberately lenient: matches on the distinguishing words rather than the exact string, so
    /// punctuation, casing, and the British/American spelling of "cancelling" don't fail the demo.
    private static func matchesProductCardsPrompt(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("noise")
            && (normalized.contains("cancelling") || normalized.contains("canceling"))
            && normalized.contains("headphone")
    }

    /// Pulls the message and the handed-off product name out of the outgoing chat request.
    ///
    /// `URLSession` converts a request's `httpBody` into an `httpBodyStream` before handing it to a
    /// `URLProtocol`, so reading `httpBody` alone returns `nil` here. Draining the stream is safe
    /// because this protocol never forwards the request.
    private static func requestInfo(from request: URLRequest) -> RequestInfo {
        guard let body = bodyData(from: request),
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let events = json["events"] as? [[String: Any]],
              let event = events.first else {
            return RequestInfo(message: nil, purchasedProductName: nil)
        }

        let conversation = (event["query"] as? [String: Any])?["conversation"] as? [String: Any]
        let productListItems = (event["xdm"] as? [String: Any])?["productListItems"] as? [[String: Any]]

        return RequestInfo(message: conversation?["message"] as? String,
                           purchasedProductName: productListItems?.first?["name"] as? String)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4_096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }
        return data.isEmpty ? nil : data
    }

    /// Two product cards (so this exercises the real `CarouselGroupView` carousel path, not just a
    /// single card): one with a `primary` action (the "Buy now" CTA shows), one without (it
    /// doesn't) — matching the `ConversationHandle` -> `HandleItem` -> `ConversationPayload` ->
    /// `ConversationResponse` -> `MultimodalElements` shape in `ConversationHandle.swift` /
    /// `ConversationResponse.swift`.
    private static let productCardsSSEData: Data = {
        let productWithBuyNow: [String: Any] = [
            "id": "mock-product-1",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Wireless Noise-Cancelling Headphones",
                "productImageURL": BuyNowMockURLProtocol.symbolImageURL(["headphones"], tint: .systemIndigo),
                "productPrice": "$249.99",
                "primary": [
                    "text": "Buy now",
                    "url": BuyNowMockURLProtocol.buyNowURL(title: "Wireless Noise-Cancelling Headphones",
                                                           price: "$249.99",
                                                           symbol: "headphones")
                ]
            ]
        ]
        let productWithoutBuyNow: [String: Any] = [
            "id": "mock-product-2",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Stainless Steel Water Bottle",
                "productDescription": "Keeps drinks cold for 24 hours",
                "productImageURL": BuyNowMockURLProtocol.symbolImageURL(["waterbottle", "drop.fill"], tint: .systemTeal),
                "productPrice": "$18.00"
            ]
        ]
        return BuyNowMockURLProtocol.sseData(message: "Here are a couple of products for you:",
                                             elements: [productWithBuyNow, productWithoutBuyNow])
    }()

    /// Product Advisor style follow-up for the post-checkout handoff: complementary accessories
    /// rather than the headphones just bought. Neither card carries a `primary` action, so the
    /// demo can't loop straight back into checkout. `purchasedProductName` comes from the handoff's
    /// own XDM, which makes the reply double as proof the checkout data reached the service.
    private static func checkoutFollowUpSSEData(purchasedProductName: String?) -> Data {
        let headphoneCase: [String: Any] = [
            "id": "mock-accessory-1",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Hard-Shell Headphone Case",
                "productDescription": "Crush-proof travel case with a cable pocket",
                "productImageURL": symbolImageURL(["suitcase.fill", "bag.fill"], tint: .systemBrown),
                "productPrice": "$34.99"
            ]
        ]
        let cable: [String: Any] = [
            "id": "mock-accessory-2",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Braided USB-C Charging Cable",
                "productDescription": "2 m, right-angle connector",
                "productImageURL": symbolImageURL(["cable.connector", "bolt.horizontal.fill"], tint: .systemOrange),
                "productPrice": "$19.99"
            ]
        ]

        let message: String
        if let purchasedProductName {
            message = "Great pick on the \(purchasedProductName)! Here are a couple of accessories that pair well with it:"
        } else {
            message = "Thanks for your order! Here are a couple of accessories that pair well with it:"
        }

        return sseData(message: message, elements: [headphoneCase, cable])
    }

    /// Product Advisor style recovery for an abandoned cart: cheaper alternatives. The budget pick
    /// keeps its own "Buy now" CTA so the demo loop can be run again with a *different* product.
    private static func abandonedCheckoutSSEData(abandonedProductName: String?) -> Data {
        let budgetPick: [String: Any] = [
            "id": "mock-alternative-1",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "On-Ear Headphones (Budget Pick)",
                "productDescription": "Same active noise cancelling, 30-hour battery",
                "productImageURL": symbolImageURL(["headphones"], tint: .systemGreen),
                "productPrice": "$89.99",
                "primary": [
                    "text": "Buy now",
                    "url": buyNowURL(title: "On-Ear Headphones (Budget Pick)", price: "$89.99", symbol: "headphones")
                ]
            ]
        ]
        let earbuds: [String: Any] = [
            "id": "mock-alternative-2",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Wireless Earbuds",
                "productDescription": "Pocketable, sweat resistant",
                "productImageURL": symbolImageURL(["airpodspro", "earbuds"], tint: .systemPink),
                "productPrice": "$129.00"
            ]
        ]

        let message: String
        if let abandonedProductName {
            message = "No rush - the \(abandonedProductName) will still be here when you're ready. If the price was the sticking point, these are worth a look:"
        } else {
            message = "No rush - your cart is saved. If the price was the sticking point, these are worth a look:"
        }

        return sseData(message: message, elements: [budgetPick, earbuds])
    }

    /// Builds the `demoapp://buy-now` deep link a product card's CTA hands to the app. `symbol`
    /// lets the checkout screen show artwork matching the product it was opened for.
    private static func buyNowURL(title: String, price: String, symbol: String) -> String {
        var components = URLComponents()
        components.scheme = "demoapp"
        components.host = "buy-now"
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "price", value: price),
            URLQueryItem(name: "symbol", value: symbol)
        ]
        return components.url?.absoluteString ?? ""
    }

    // MARK: - Mock product imagery

    /// Renders an SF Symbol onto a flat background and returns it as a self-contained
    /// `data:image/png;base64,...` URL, so the mock stays fully offline while still exercising
    /// `RemoteImageView`'s real `AsyncImage` load (which supports the `data:` scheme).
    ///
    /// `symbolNames` is a preference list: the first name available on the running OS wins, which
    /// keeps newer symbols from rendering blank on an older deployment target.
    private static func symbolImageURL(_ symbolNames: [String], tint: UIColor) -> String {
        let canvas = CGSize(width: 300, height: 300)
        let configuration = UIImage.SymbolConfiguration(pointSize: 132, weight: .light)
        let symbol = symbolNames
            .lazy
            .compactMap { UIImage(systemName: $0, withConfiguration: configuration) }
            .first?
            .withTintColor(tint, renderingMode: .alwaysOriginal)

        let image = UIGraphicsImageRenderer(size: canvas).image { context in
            // A literal gray rather than a dynamic system color: this renders outside any trait
            // collection, where dynamic colors silently resolve to their light-appearance value.
            UIColor(white: 0.93, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvas))

            guard let symbol else { return }
            symbol.draw(at: CGPoint(x: (canvas.width - symbol.size.width) / 2,
                                    y: (canvas.height - symbol.size.height) / 2))
        }

        guard let png = image.pngData() else { return "" }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }

    /// Builds one complete SSE frame via `JSONSerialization` rather than a multi-line string
    /// literal: the SSE parser splits on newlines, so the JSON itself must be a single line.
    private static func sseData(message: String, elements: [[String: Any]] = []) -> Data {
        var response: [String: Any] = [
            "message": message,
            "promptSuggestions": [],
            "sources": [],
            "linkHints": []
        ]
        if !elements.isEmpty {
            response["multimodalElements"] = ["type": "cards", "elements": elements]
        }

        let handle: [String: Any] = [
            "handle": [
                [
                    "payload": [
                        [
                            "conversationId": "mock-conversation-id",
                            "interactionId": "mock-interaction-id",
                            "state": "completed",
                            "response": response
                        ]
                    ]
                ]
            ]
        ]

        // swiftlint:disable:next force_try
        let jsonData = try! JSONSerialization.data(withJSONObject: handle)
        var sseData = "data: ".data(using: .utf8)!
        sseData.append(jsonData)
        sseData.append("\n\n".data(using: .utf8)!)
        return sseData
    }
}
