// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Looper",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Looper", targets: ["Looper"]),
    ],
    dependencies: [
        .package(path: "../Synth"),
    ],
    targets: [
        .target(name: "Looper", dependencies: ["Synth"]),
        .testTarget(name: "LooperTests", dependencies: ["Looper"]),
    ]
)
