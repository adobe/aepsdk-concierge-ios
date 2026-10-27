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

Brand Concierge can hold a spoken conversation with the agent. The SDK runs the conversation (credentials, microphone permission, session lifecycle, transcript and UI), and your app supplies the audio connection by implementing the `VoiceTransport` protocol. Brand Concierge has no WebRTC dependency, so apps that don't use voice ship no WebRTC code.

The demo app's [`LiveKitTransport.swift`](../ConciergeDemoApp/LiveKitTransport.swift) is a complete transport built on the [LiveKit Swift SDK](https://github.com/livekit/client-sdk-swift). To add voice to your app:

#### 1. Add LiveKit to your app

Add the package `https://github.com/livekit/client-sdk-swift.git` with Swift Package Manager and link its `LiveKit` product to your app target. LiveKit is your app's dependency: you choose and update its version, and Brand Concierge does not constrain it. The demo app pins 2.17.0.

- **Link `LiveKit` to the app target itself**, so Xcode embeds its binary frameworks. If it reaches the app only through another framework target, the app can crash at launch with `Library not loaded: @rpath/LiveKitWebRTC.framework`.
- **Use Swift Package Manager for LiveKit**, even if you add Brand Concierge with CocoaPods. Current LiveKit releases are not on CocoaPods trunk, and LiveKit has deprecated its CocoaPods support. A CocoaPods project can add Swift packages too: the demo app gets the AEP SDKs from CocoaPods and LiveKit from Swift Package Manager.

#### 2. Add the microphone usage description

Add `NSMicrophoneUsageDescription` to your app's `Info.plist`. iOS terminates the app when it accesses the microphone without it. No background mode is needed: a voice session ends when the app moves to the background.

#### 3. Copy the transport

Copy [`LiveKitTransport.swift`](../ConciergeDemoApp/LiveKitTransport.swift) into your app (change the logger subsystem to your own). A `VoiceTransport` connects to the URL and token Brand Concierge passes to `connect(url:token:)`, publishes the microphone, plays the agent's audio, and reports its state and incoming data messages to its `delegate`. The reference transport also records the microphone while the room connects and sends that audio once the agent joins, so the user can start speaking right away.

If you change the transport, keep the rules in the `VoiceTransport` documentation. When you update LiveKit, check that the file still builds and repeat the device checks below.

#### 4. Pass the transport when showing the chat

Keep one instance for the life of the app: Brand Concierge reuses it for each conversation, sets the delegate before connecting and clears it before disconnecting.

```swift
enum Voice {
    static let transport = LiveKitTransport()
}

Concierge.show(surfaces: ["my-surface"], voiceTransport: Voice.transport)
```

`Concierge.present(on:...)` takes the same `voiceTransport` parameter. The transport is kept for re-shows of the same chat, like `textSpeaker`; a chat first shown without a transport stays without one. `Concierge.wrap` takes no transport: its floating button reopens the chat with the transport of the last `show` or `present` call. Pass the same instance at every `show` and `present` call, as the demo app does.

When a transport is provided, the composer shows a voice button. While a voice conversation runs, the transcript renders in the chat and typed messages, dictation and data handoffs are paused. Brand Concierge asks for microphone permission before connecting; a denied permission or a failed connection ends the session and shows an error message in the chat.

#### Audio quality

The transport, and therefore LiveKit, owns the audio session and the audio processing:

- **Keep Apple's voice processing on.** LiveKit uses it by default for echo cancellation and noise suppression. Without it, the agent's voice from the speaker reaches the microphone and the agent can interrupt itself. Even with it, loud speaker playback can occasionally be heard as the user speaking; headphones avoid this.
- **Speaker output.** The reference transport prefers the built-in speaker over the receiver (`AudioManager.shared.isSpeakerOutputPreferred`). Headphones and Bluetooth devices take over when connected.
- **Interruptions.** Brand Concierge mutes the microphone through the transport during an audio interruption (a call, Siri) and unmutes it afterwards.
- **Test on a device.** The simulator proves the wiring and the connection, but not echo, audio routes or interruptions. Check a conversation on the speaker, connecting and disconnecting wired and Bluetooth headphones mid-session, a call or Siri during a session, and moving the app to the background. Repeat these checks when you update LiveKit or change its audio settings (for example `AudioManager.shared.sessionConfiguration`) elsewhere in your app.
