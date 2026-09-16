// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

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

import PackageDescription

let package = Package(
    name: "AEPBrandConcierge",
    // macOS minimum added because LiveKit's own manifest requires macOS 10.15; this SDK still only
    // targets iOS in practice (no macOS product/build here), but SPM requires every platform's
    // minimum to be consistent across the whole dependency graph.
    platforms: [.iOS(.v15), .macOS(.v10_15)],
    products: [
        .library(name: "AEPBrandConcierge", targets: ["AEPBrandConcierge"])
    ],
    dependencies: [
        .package(url: "https://github.com/adobe/aepsdk-core-ios.git", .upToNextMajor(from: "5.7.0")),
        .package(url: "https://github.com/adobe/aepsdk-edgeidentity-ios.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/livekit/client-sdk-swift.git", .upToNextMajor(from: "2.17.0"))
    ],
    targets: [
        .target(name: "AEPBrandConcierge",
            dependencies: [
                .product(name: "AEPCore", package: "aepsdk-core-ios"),
                .product(name: "AEPServices", package: "aepsdk-core-ios"),
                .product(name: "AEPEdgeIdentity", package: "aepsdk-edgeidentity-ios"),
                .product(name: "LiveKit", package: "client-sdk-swift")
            ],
            path: "AEPBrandConcierge/Sources",
            exclude: ["Info.plist", "AEPBrandConcierge.h"])
    ]
)
