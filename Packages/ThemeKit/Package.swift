// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ThemeKit", targets: ["ThemeKit"]),
    ],
    targets: [
        .target(name: "ThemeKit", dependencies: []),
        .testTarget(name: "ThemeKitTests", dependencies: ["ThemeKit"]),
    ]
)
