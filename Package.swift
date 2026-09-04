// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Leanwave",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LeanwaveCore", targets: ["LeanwaveCore"]),
        .executable(name: "Leanwave", targets: ["LeanwaveApp"]),
    ],
    targets: [
        .target(name: "LeanwaveCore"),
        .executableTarget(name: "LeanwaveApp", dependencies: ["LeanwaveCore"]),
        .testTarget(name: "LeanwaveCoreTests", dependencies: ["LeanwaveCore"]),
        .testTarget(name: "LeanwaveAppTests", dependencies: ["LeanwaveApp"]),
    ]
)
