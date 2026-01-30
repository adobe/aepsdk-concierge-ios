#  Getting started with AEPBrandConcierge SDK

> ⚠️ Important - 
>
> Until the `AEPBrandConcierge` extension is generally available, it needs to be installed from the dev branch.

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
    pod 'AEPBrandConcierge', :git => 'https://github.com/adobe/aepsdk-concierge-ios.git', :branch => 'dev'
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
    .package(url: "https://github.com/adobe/aepsdk-concierge-ios.git", .branch: "dev")
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

### ⚠️ Important

Until the Brand Concierge extension in Adobe Data Collection is generally available, its SDK configuration must be performed manually.

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ...

    MobileCore.registerExtensions(extensions) {
        MobileCore.configureWith(appId: "MY_APP_ID")

        // manually configure Brand Concierge settings
        MobileCore.updateConfigurationWith(configDict: [
            "concierge.server": "MY_CONCIERGE_SERVER",
            "concierge.configId": "MY_DATASTREAM_ID",
            "concierge.surfaces": [ "MY_BRAND_CONCIERGE_SURFACE", ... ]
        ])
    }

    return true
}
```