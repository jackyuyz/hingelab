// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoldKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FoldKit",
            targets: ["FoldKit"]
        ),
    ],
    targets: [
        .target(
            name: "FoldKit",
            dependencies: []
        ),
        .testTarget(
            name: "FoldKitTests",
            dependencies: ["FoldKit"]
        ),
    ]
)
