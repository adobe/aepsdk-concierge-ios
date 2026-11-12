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

#### Before you start

- **Brand Concierge version.** Voice needs a Brand Concierge version that includes `VoiceTransport`; 5.10.3 and earlier don't.
- **Xcode 16.3 or later**, which LiveKit Swift SDK 2.17.0 requires.
- **Voice enabled for your Brand Concierge.** Ask your Adobe contact to confirm it. The agent's voice and language are set there, not in the app.
- **A physical iPhone** for the checks in [Audio quality](#audio-quality).

#### 1. Add LiveKit to your app

Add the package `https://github.com/livekit/client-sdk-swift.git` with Swift Package Manager and link its `LiveKit` product to your app target. LiveKit is your app's dependency: you choose and update its version, and Brand Concierge does not constrain it. The demo app pins 2.17.0, the version Brand Concierge voice was tested with on devices.

- **Link `LiveKit` to the app target itself**, so Xcode embeds its binary frameworks. If it reaches the app only through another framework target, the app can crash at launch with `Library not loaded: @rpath/LiveKitWebRTC.framework`.
- **Use Swift Package Manager for LiveKit**, even if you add Brand Concierge with CocoaPods. Current LiveKit releases are not on CocoaPods trunk, and LiveKit has deprecated its CocoaPods support. A CocoaPods project can add Swift packages too: the demo app gets the AEP SDKs from CocoaPods and LiveKit from Swift Package Manager.

#### 2. Add the microphone usage description and background mode

Add `NSMicrophoneUsageDescription` to your app's `Info.plist`. iOS terminates the app when it accesses the microphone without it. For conversations that continue in the background, also add `audio` to `UIBackgroundModes`; see [Background conversations](#background-conversations).

#### 3. Copy the transport

Copy [`LiveKitTransport.swift`](../ConciergeDemoApp/LiveKitTransport.swift) into your app (change the logger subsystem to your own). A `VoiceTransport` connects to the URL and token in the `VoiceConnection` Brand Concierge passes to `connect(_:)`, publishes the microphone, plays the agent's audio, and reports its state and incoming data messages to its `delegate`. The reference transport also records the microphone while the room connects and sends that audio once the agent joins, so the user can start speaking right away.

If you change the transport, keep the rules in the `VoiceTransport` documentation. When you update LiveKit, check that the file still builds and repeat the device checks below.

#### 4. Pass the transport when showing the chat

Keep one instance for the life of the app: Brand Concierge reuses it for each conversation, sets the delegate before connecting and clears it before disconnecting.

```swift
enum Voice {
    static let transport = LiveKitTransport()
}

Concierge.show(surfaces: ["my-surface"], voiceTransport: Voice.transport)
```

`Concierge.present(on:...)` takes the same `voiceTransport` parameter. The transport is kept for re-shows of the same chat, like `textSpeaker`; a chat first shown without a transport stays without one. For chats opened from the floating button, pass it to `Concierge.wrap(...)`:

```swift
Concierge.wrap(AppRootView(), surfaces: ["my-surface"], voiceTransport: Voice.transport)
```

Pass the same instance at every `wrap`, `show` and `present` call, as the demo app does.

When a transport is provided, the composer shows a voice button. While a voice conversation runs, the transcript renders in the chat and typed messages, dictation and data handoffs are paused. Only one voice conversation runs at a time across the app: if the overlay chat and a chat opened with `present(on:...)` are both open, the voice button in the other one is disabled until the conversation ends. Brand Concierge asks for microphone permission when the user starts a conversation, before it requests a voice session; if the permission is denied, no conversation starts and the chat offers to open Settings. A failed connection ends the conversation and shows an error message in the chat, as does a transport that does not report `.connected` within 20 seconds of `connect(_:)` (Brand Concierge then calls `disconnect()`). The same message appears when the voice agent ends the session because of a server error; when it ends an idle session, the conversation ends without a message. While the transport reports `.reconnecting`, the conversation stays open and the voice button shows a spinner; if the transport does not report `.connected` again within 30 seconds, the conversation ends with the same error message.

Every voice conversation ends 60 minutes after the transport first reports `.connected`, in the foreground or the background, as a normal end without a message (Brand Concierge calls `disconnect()`). Reconnects don't restart the count; a new conversation gets its own 60 minutes.

#### Background conversations

A voice conversation keeps running while the screen is locked or the user is in another app only if the transport opts in. Otherwise it ends when the app goes to the background, including when the user locks the screen. The reference transport opts in:

```swift
final class LiveKitTransport: VoiceTransport {
    var continuesInBackground: Bool { true }
    // ...
}
```

It needs the `audio` background mode in your app's `Info.plist` (step 2), so iOS keeps the app running with the microphone live:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

Without it, iOS suspends the app seconds after it leaves the foreground and the conversation fails. If you don't want background conversations, return `false` (or offer an in-app setting and return its value) and leave out the background mode.

- Brand Concierge reads `continuesInBackground` once per conversation, when it calls `connect(_:)`. The reference transport starts the microphone there. A conversation still asking for microphone permission or fetching its credentials ends when the app goes to the background, because iOS doesn't let an app start the microphone from there.
- While the conversation runs in the background, iOS shows the microphone indicator in the status bar; tapping it returns to the app. Transcripts and product cards that arrive meanwhile are in the chat when the user returns.
- It ends when the user ends it, closes the chat, force-quits the app, after 60 minutes, or when the voice agent ends an idle session (after about a minute without activity).
- App Review: describe the voice conversation, which the user starts and hears, in your review notes as the reason for the `audio` background mode.

#### Audio quality

The transport, and therefore LiveKit, owns the audio session and the audio processing:

- **Keep Apple's voice processing on.** LiveKit uses it by default for echo cancellation and noise suppression. Without it, the agent's voice from the speaker reaches the microphone and the agent can interrupt itself. Even with it, loud speaker playback can occasionally be heard as the user speaking; headphones avoid this.
- **Speaker output.** The reference transport prefers the built-in speaker over the receiver (`AudioManager.shared.isSpeakerOutputPreferred`). Headphones and Bluetooth devices take over when connected. The setting is LiveKit-wide, so it also applies to any other LiveKit use in your app; the transport puts back your app's value when the conversation ends.
- **Interruptions.** Brand Concierge mutes the microphone through the transport during an audio interruption (a call, Siri), including one that began while connecting, and unmutes it afterwards. If iOS does not allow the audio to resume, the conversation ends with an error message, because the chat has no unmute control.
- **Test on a device.** The simulator proves the wiring and the connection, but not echo, audio routes or interruptions. Check a conversation on the speaker, connecting and disconnecting wired and Bluetooth headphones mid-session, a call or Siri during a session, and locking the screen or switching to another app mid-session (with and without the background mode, if you offer a setting). Repeat these checks when you update LiveKit or change its audio settings (for example `AudioManager.shared.sessionConfiguration`) elsewhere in your app.

#### Limitations

- **No authentication token or XDM context.** Brand Concierge doesn't send the token from `Concierge.setAuthTokenProvider` or the context from `Concierge.updateXDMContext(_:)` when it starts a voice conversation, so the voice agent works without them. Typed and dictated messages in the same chat still include them.
- **Language.** The app doesn't send a locale with voice; the agent speaks the language set for your Brand Concierge.
- **Voice UI text is English** and not configurable: the voice button's accessibility labels ("Start voice conversation", "Stop voice conversation") and the microphone permission message.
- **Network.** Voice uses WebRTC (UDP, with TCP and TLS fallback) in addition to the HTTPS chat requests. Networks that block it, such as some corporate or venue Wi-Fi, can prevent voice from connecting while text chat works. Test on the networks your users use.
- **App Store privacy.** During a conversation, the microphone audio is streamed to Adobe's voice service, which transcribes it. Reflect this in your App Privacy details and privacy policy.
