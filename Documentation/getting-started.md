#  Getting started with AEPBrandConcierge SDK

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

```ruby
# Podfile
use_frameworks!

# for app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPEdge'
    pod 'AEPEdgeIdentity'
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'AEPBrandConcierge'
end
```

Replace `YOUR_TARGET_NAME` and then, in the `Podfile` directory, type:

```ruby
$ pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPBrandConcierge Package to your application, from the Xcode menu select:

`File > Add Packages...`

> **Note**: the menu options may vary depending on the version of Xcode being used.

Enter the URL for the AEPBrandConcierge package repository: `https://github.com/adobe/aepsdk-concierge-ios.git`.

For `Dependency Rule`, select `Up to Next Major Version`.

Alternatively, if your project has a `Package.swift` file, you can add AEPBrandConcierge directly to your dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-concierge-ios.git", .upToNextMajor(from: "5.0.0"))
],
targets: [
    .target(name: "YourTarget",
            dependencies: ["AEPBrandConcierge"],
            path: "your/path")
]
```

### Binaries

To generate `AEPBrandConcierge.xcframework`, run the following command from the root directory:

```
make archive
```

This will generate an XCFramework under the `build` folder. Drag and drop `AEPBrandConcierge.xcframework` to your app target.

### Import and register the Brand Concierge extension

Import the AEPBrandConcierge framework and its dependencies, then register the Brand Concierge extension and dependencies in the `application(_: didFinishLaunchingWithOptions:)` method in the `AppDelegate`:

```swift
import AEPBrandConcierge
import AEPCore
import AEPEdge
import AEPEdgeIdentity
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // optionally enable debug logging
        MobileCore.setLogLevel(.trace)

        // create a list of extensions that will be registered
        let extensions = [
            Concierge.self,
            Identity.self,
            Edge.self
        ]

        MobileCore.registerExtensions(extensions) {
            // use the App ID assigned for this application from Adobe Data Collection (formerly Adobe Launch)
            MobileCore.configureWith(appId: "MY_APP_ID")
        }

        return true
    }
}
```
## Native multimodal cards

Register a SwiftUI renderer during client application setup, before starting a
conversation. Register each exact, case-sensitive server element `type` separately:

```swift
import SwiftUI
import AEPBrandConcierge

Concierge.registerCardRenderer(type: "myapp.info") { element, context, saveState in
    let title = element["title"] as? String ?? "Information"
    let details = element["details"] as? String ?? ""
    let state = context["state"] as? [String: Any]
    let expanded = state?["expanded"] as? Bool ?? false
    let unavailable = (context["isBusy"] as? Bool ?? false)
        || (context["isStale"] as? Bool ?? false)

    return AnyView(
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if expanded {
                Text(details)
            }
            Button(expanded ? "Show less" : "Show details") {
                saveState(["expanded": !expanded])
            }
            .disabled(unavailable)
        }
        .padding()
    )
}
```

For example, the server can include this object in its response's multimodal
`elements` array:

```json
{
  "id": "info-1",
  "type": "myapp.info",
  "title": "Collection information",
  "details": "Your collection point is open until 8 PM."
}
```

When the response completes, the SDK adds a native transcript row and invokes the
registered renderer to display it. The renderer returns the card content; the SDK
manages its position in the conversation. In this example, `saveState` updates the
expanded state and the SDK refreshes the view with the new `context["state"]`.
The last registration for a type applies to future cards; existing occurrences
keep their original renderer.

The renderer receives the complete JSON element (including unknown fields and `NSNull`).
Numbers and booleans bridge through `NSNumber`, as with `JSONSerialization`,
so numeric fields can be read using `as? Int` or `as? Double`.
Non-integer numbers and integers outside the 64-bit ranges use `NSDecimalNumber`
when the original JSON value can be represented exactly. Native activation is rejected rather than
rounding numbers outside Foundation's supported precision or exponent range.
The SDK validates these values against their original response bytes.
Read `NSDecimalNumber` values directly when decimal precision matters; converting
them to `Double` can lose precision.
The renderer also receives a live context
containing `cardId`, `sequence`, optional originating `sessionId`/
`conversationId`/`interactionId`, `isBusy`, `isStale`, `isLatest`, and the last saved `state`.
`saveState` replaces this card occurrence's private JSON dictionary; it does **not**
send data to the backend. Do not send actions when busy or stale. Use the existing
`Concierge.sendDataHandoff` and `Concierge.updateXDMContext` APIs for card actions
and context. Native cards activate when the stream finishes, using elements from the
`completed` response only; receiving a completed payload alone does not activate them
while the transport remains open. Elements received only in streaming updates do not activate native cards;
built-in elements retain iOS's existing buffering behavior. Registered types take priority.
Unregistered and untyped elements are decoded and rendered exactly as before
(built-in product card/carousel). Only elements whose `type` has a registered
renderer have their raw JSON captured, and only those are decoded leniently (for
example, a numeric top-level `id`). If native activation is rejected (for example,
because its raw JSON exceeds the safety budget), the element falls back to the
built-in rendering when available. Nonempty string and numeric IDs identify native
occurrences within a turn; empty, null, and missing IDs use the element's array
position. Reprocessing the same occurrence does not activate it again. A later
element reusing an ID in the same response uses its built-in fallback, or is omitted
if it has none. When a response renders a native card, its prompt suggestions attach
to that response's built-in product-card row if present, otherwise to the last native card row; other responses
keep the separate suggestion rows.

Card state belongs to the chat, not to a SwiftUI row's lifetime. Recreating a row
retains its occurrence and saved state, and later turns leave older cards active.
Removing transcript rows disposes only those card occurrences; clearing the chat
or resetting identity disposes all of them. Disposed cards become stale and ignore
queued or late state saves.

Session expiry or replacement does not automatically mark cards stale. The
originating session and conversation identifiers in context are metadata, not
automatic action-availability rules.

On iOS, a `response` object must include a string `message`; use an empty string
for a card-only response.

The only public native-card integration API is
`registerCardRenderer(type:_:)`. For app-owned first-display effects, trigger them
from the view lifecycle, gate them on `isStale`, and deduplicate them by `cardId`;
do not publish state from view-body evaluation.

Card order comes from the SDK, never from the view lifecycle: SwiftUI doesn't create
or show transcript rows in transcript order (lazy rows, recreated rows), so "the last
card whose `onAppear` fired" is not the newest card.
- `isLatest` covers the common rule "only the newest card of a type is actionable":
  gate controls on `isLatest && !isStale && !isBusy`. It reports order, not
  host-app action availability. Activating a newer card of the
  same `type` sets the older one to `false`. If the newest card is rolled back, the
  newest remaining card of that type becomes latest again.
- `sequence` supports other cross-card rules (for example, newest per location): it
  strictly increases in transcript order (including element order within one
  response), is fixed for the card's lifetime, and is never reused in the chat.
  Rejected elements don't use a number. Compare it only between cards of the same
  chat; it is not meaningful across chats or app launches.

Raw native elements and saved state must be valid JSON within depth 64 (root at depth
zero) and 100,000 total value/container nodes. These are structural validation limits,
not byte-size or peak-memory limits. Saved-state copying reserves an array's full
capacity before validating all its nodes, so oversized arrays can allocate memory
before rejection. Invalid or over-budget saved state is logged and leaves the last
valid state unchanged. Over-budget elements are logged and
rejected before a native occurrence is activated; when the built-in projection parsed
successfully, it remains eligible for fallback rendering.
When at least one native renderer is registered, streaming SSE `data:` lines that
span multiple network reads (large card payloads) are reassembled before decoding,
including fragmented UTF-8 and a final line without a newline. Lines have no size
limit, matching the existing stream handling; the structural JSON budget does not
bound the buffered line's memory usage. A final unterminated line is decoded when
possible; malformed or truncated JSON is logged and skipped, not automatically
reported as a transport error. Without a registered renderer, the
existing stream handling remains unchanged.

For stateful renderers, keep runtime state in an observable SwiftUI owner and initialize
it from the SDK snapshot supplied in `context["state"]`. Save complete JSON snapshots
after local state changes so a recreated row can restore the in-flight action state
without sending again. For example:

```swift
@MainActor
final class CardRuntime: ObservableObject {
    @Published var expanded: Bool

    init(savedState: [String: Any]?) {
        expanded = savedState?["expanded"] as? Bool ?? false
    }

    func snapshot() -> [String: Any] { ["expanded": expanded] }
}

struct StatefulCard: View {
    @StateObject private var runtime: CardRuntime
    private let saveState: ([String: Any]) -> Void

    init(context: [String: Any], saveState: @escaping ([String: Any]) -> Void) {
        _runtime = StateObject(wrappedValue: CardRuntime(savedState: context["state"] as? [String: Any]))
        self.saveState = saveState
    }

    var body: some View {
        Button(runtime.expanded ? "Show less" : "Show details") {
            runtime.expanded.toggle()
            saveState(runtime.snapshot())
        }
    }
}
```

Use it from the canonical renderer registration:

```swift
Concierge.registerCardRenderer(type: "myapp.stateful") { _, context, saveState in
    AnyView(StatefulCard(context: context, saveState: saveState))
}
```

Keep the runtime owned by the card view tree and hold action completion state
strongly enough to process callbacks even if the row scrolls offscreen. Check the
latest `isStale`/`isBusy` context before sending; late callbacks must not mutate a
stale card. Saved state is private to the in-memory transcript and is not persisted
across app restarts. Use one state owner per occurrence; independent owners writing
the same snapshot are not transactionally merged.

Client-specific models, action payloads, navigation, and client-owned context reset
remain the host application's responsibility. The SDK does not supply client
renderers or interpret their action schemas.
