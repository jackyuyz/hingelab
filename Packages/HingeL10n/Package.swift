// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HingeL10n",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HingeL10n", targets: ["HingeL10n"]),
    ],
    targets: [
        .target(
            name: "HingeL10n",
            resources: [.process("Locales")]
        ),
        .testTarget(
            name: "HingeL10nTests",
            dependencies: ["HingeL10n"]
        ),
    ]
)
