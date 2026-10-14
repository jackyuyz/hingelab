// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HingeInput",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HingeInput", targets: ["HingeInput"]),
    ],
    dependencies: [
        .package(path: "../FoldKit"),
    ],
    targets: [
        .target(
            name: "HingeInput",
            dependencies: ["FoldKit"]
        ),
        .testTarget(
            name: "HingeInputTests",
            dependencies: ["HingeInput"]
        ),
    ]
)
