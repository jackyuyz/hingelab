// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Synth",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Synth", targets: ["Synth"]),
    ],
    targets: [
        .target(name: "Synth", dependencies: []),
        .testTarget(name: "SynthTests", dependencies: ["Synth"]),
    ]
)
