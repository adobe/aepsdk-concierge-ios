# Adobe Experience Platform - Brand Concierge extension for iOS

<!-- [![Cocoapods](https://img.shields.io/github/v/release/adobe/aepsdk-concierge-ios?label=CocoaPods&logo=apple&logoColor=white&color=orange&sort=semver)](https://cocoapods.org/pods/AEPBrandConcierge)
[![SPM](https://img.shields.io/github/v/release/adobe/aepsdk-concierge-ios?label=SPM&logo=apple&logoColor=white&color=orange&sort=semver)](https://github.com/adobe/aepsdk-concierge-ios/releases)
[![CircleCI](https://img.shields.io/circleci/project/github/adobe/aepsdk-concierge-ios/main.svg?logo=circleci&label=Build)](https://circleci.com/gh/adobe/workflows/aepsdk-concierge-ios)
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-concierge-ios/main.svg?logo=codecov&label=Coverage)](https://codecov.io/gh/adobe/aepsdk-concierge-ios/branch/main) -->

Adobe Brand Concierge. Guide customer journeys with personalized, conversational discovery.

For more information, see [official documentation](https://business.adobe.com/products/brand-concierge.html)

## About this project

Adobe Experience Platform (AEP) Brand Concierge Extension is an extension for the [Adobe Experience Platform Swift SDK](https://github.com/adobe/aepsdk-core-ios).

The AEPBrandConcierge extension is used to enable Brand Concierge experiences in your iOS app.

For further information about Adobe SDKs, visit the [developer documentation](https://developer.adobe.com/client-sdks/documentation/).

## Requirements
- Xcode 15 (or newer)
- Swift 5.1 (or newer)

## Installation

For installation instructions, visit the [getting started guide](./Documentation/getting-started.md).

## Implementation

For implementation instructions, visit the [implementation guide](./Documentation/Implementation/implementation-guide.md).

## Documentation

Additional documentation for SDK usage and configuration can be found in the [Documentation](./Documentation/README.md) directory.

## Related Projects

| Project                                                      | Description                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [AEPCore Extensions](https://github.com/adobe/aepsdk-core-ios) | The AEPCore and AEPServices represent the foundation of the Adobe Experience Platform SDK. |
| [AEPEdge Extension](https://github.com/adobe/aepsdk-edge-ios) | The AEPEdge extension allows you to send data to the Adobe Experience Platform (AEP) from a mobile application. |
| [AEPEdgeIdentity Extension](https://github.com/adobe/aepsdk-edgeidentity-ios) | The AEPEdgeIdentity enables handling of user identity data from a mobile app when using the AEPEdge extension. |
| [AEP SDK Sample App for iOS](https://github.com/adobe/aepsdk-sample-app-ios) | Contains iOS sample apps for the AEP SDK. Apps are provided for both Objective-C and Swift implementations. |

## Contributing
Looking to contribute to this project? Please review our [Contributing guidelines](./.github/CONTRIBUTING.md) prior to opening a pull request.

We look forward to working with you!

#### Development

The first time you clone or download the project, you should run the following from the root directory to setup the environment:

~~~
make pod-install
~~~

Subsequently, you can make sure your environment is updated by running the following:

~~~
make pod-update
~~~

##### Open the Xcode workspace
Open the workspace in Xcode by running the following command from the root directory of the repository:

~~~
make open
~~~

##### Command line integration

You can run all the test suites from command line:

~~~
make test
~~~

## Licensing
This project is licensed under the Apache V2 License. See [LICENSE](./LICENSE) for more information.
