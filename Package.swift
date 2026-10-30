// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OnDeviceAI",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "OnDeviceAI", targets: ["OnDeviceAI"]),
    ],
    targets: [
        .target(name: "OnDeviceAI"),
        .testTarget(name: "OnDeviceAITests", dependencies: ["OnDeviceAI"]),
    ],
    swiftLanguageModes: [.v6]
)
