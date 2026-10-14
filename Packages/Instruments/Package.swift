// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Instruments",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Instruments", targets: ["Instruments"]),
    ],
    dependencies: [
        .package(path: "../HingeInput"),
        .package(path: "../Synth"),
        .package(path: "../MIDIOut"),
        .package(path: "../SettingsKit"),
    ],
    targets: [
        .target(
            name: "Instruments",
            dependencies: ["HingeInput", "Synth", "MIDIOut", "SettingsKit"]
        ),
        .testTarget(
            name: "InstrumentsTests",
            dependencies: ["Instruments"]
        ),
    ]
)
