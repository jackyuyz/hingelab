// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MIDIOut",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MIDIOut", targets: ["MIDIOut"]),
    ],
    targets: [
        .target(name: "MIDIOut", dependencies: []),
        .testTarget(name: "MIDIOutTests", dependencies: ["MIDIOut"]),
    ]
)
