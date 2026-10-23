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

### Optional: voice conversations

Brand Concierge can hold a spoken conversation with the agent. The SDK runs the conversation (credentials, session lifecycle, transcript and UI), and your app supplies the audio connection by implementing the `VoiceTransport` protocol. Brand Concierge has no WebRTC dependency, so apps that don't use voice ship no WebRTC code.

Pass your transport when showing the chat:

```swift
Concierge.show(surfaces: ["my-surface"], voiceTransport: myVoiceTransport)
```

`Concierge.present(on:...)` takes the same `voiceTransport` parameter. The transport is kept for re-shows of the same chat, like `textSpeaker`.

A `VoiceTransport` connects to the URL and token Brand Concierge passes to `connect(url:token:)`, publishes the microphone, plays the agent's audio, and reports its state and incoming data messages to its `delegate`. Keep one instance for the life of the app: Brand Concierge reuses it for each conversation, sets the delegate before connecting and clears it before disconnecting. The sample app contains a complete implementation built on the LiveKit Swift SDK to copy.

When a transport is provided, the composer shows a voice button. While a voice conversation runs, the transcript renders in the chat and typed messages, dictation and data handoffs are paused. The app must provide `NSMicrophoneUsageDescription` in its `Info.plist`.
