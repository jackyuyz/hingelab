// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettingsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SettingsKit", targets: ["SettingsKit"]),
    ],
    dependencies: [
        .package(path: "../HingeInput"),
        .package(path: "../MIDIOut"),
    ],
    targets: [
        .target(
            name: "SettingsKit",
            dependencies: ["HingeInput", "MIDIOut"]
        ),
        .testTarget(
            name: "SettingsKitTests",
            dependencies: ["SettingsKit"]
        ),
    ]
)
