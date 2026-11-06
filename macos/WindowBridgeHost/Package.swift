// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import AppKit

let package = Package(
    name: "WindowBridgeHost",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "WindowBridgeHost"
        ),
        .testTarget(
            name: "WindowBridgeHostTests",
            dependencies: ["WindowBridgeHost"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
