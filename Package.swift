// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Leanwave",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LeanwaveCore", targets: ["LeanwaveCore"]),
    ],
    targets: [
        .target(name: "LeanwaveCore"),
        .testTarget(name: "LeanwaveCoreTests", dependencies: ["LeanwaveCore"]),
    ]
)
