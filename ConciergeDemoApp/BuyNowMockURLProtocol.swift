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

/// Intercepts the Concierge chat network request and returns a canned SSE response containing
/// product cards with a `primary` action (`entity_info.primary`) — the real payload shape that
/// drives the "Buy now" CTA — so the SDK's actual production pipeline (`ChatController` parsing,
/// `CarouselGroupView`, `ProductDetailCardView`, tracking) renders it exactly as it would for a
/// live response, with zero new public API on the SDK.
///
/// Must be added to the injected `URLSessionConfiguration.protocolClasses` (see
/// `Concierge.urlSessionConfigurationForTesting` in `AppDelegate.swift`) rather than registered
/// via `URLProtocol.registerClass` — that isn't reliably consulted for `ConciergeChatService`'s
/// custom `URLSession`, or once the connection negotiates HTTP/3 (QUIC). Inert unless `isEnabled`
/// is explicitly turned on from the "Buy Now" tab.
final class BuyNowMockURLProtocol: URLProtocol {
    static var isEnabled = false

    override class func canInit(with request: URLRequest) -> Bool {
        isEnabled && request.url?.host == "edge-int.adobedc.net" && request.url?.path == "/brand-concierge/conversations"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.cannedSSEData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Two product cards (so this exercises the real `CarouselGroupView` carousel path, not just a
    /// single card): one with a `primary` action (the "Buy now" CTA shows), one without (it
    /// doesn't) — matching the `ConversationHandle` -> `HandleItem` -> `ConversationPayload` ->
    /// `ConversationResponse` -> `MultimodalElements` shape in `ConversationHandle.swift` /
    /// `ConversationResponse.swift`.
    ///
    /// Built via `JSONSerialization` (not a multi-line string literal): the SSE parser in
    /// `ConciergeChatService` splits incoming data on newlines and only treats lines starting with
    /// `"data: "` as a complete JSON object, so the JSON itself must be a single line.
    private static let cannedSSEData: Data = {
        let productWithBuyNow: [String: Any] = [
            "id": "mock-product-1",
            "type": "productCard",
            "thumbnail_width": 150,
            "thumbnail_height": 150,
            "entity_info": [
                "productName": "Wireless Noise-Cancelling Headphones",
                "productImageURL": "https://picsum.photos/seed/headphones/300/300",
                "productPrice": "$249.99",
                "primary": [
                    "text": "Buy now",
                    "url": "demoapp://buy-now?title=Wireless%20Noise-Cancelling%20Headphones&price=%24249.99"
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
                "productImageURL": "https://picsum.photos/seed/waterbottle/300/300",
                "productPrice": "$18.00"
            ]
        ]
        let handle: [String: Any] = [
            "handle": [
                [
                    "payload": [
                        [
                            "conversationId": "mock-conversation-id",
                            "interactionId": "mock-interaction-id",
                            "state": "completed",
                            "response": [
                                "message": "Here are a couple of products for you:",
                                "promptSuggestions": [],
                                "multimodalElements": [
                                    "type": "cards",
                                    "elements": [productWithBuyNow, productWithoutBuyNow]
                                ],
                                "sources": [],
                                "linkHints": []
                            ]
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
    }()
}
