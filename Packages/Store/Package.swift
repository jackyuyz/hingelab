// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Store",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Store", targets: ["Store"]),
    ],
    dependencies: [
        .package(path: "../Instruments"),
    ],
    targets: [
        .target(name: "Store", dependencies: ["Instruments"]),
        .testTarget(name: "StoreTests", dependencies: ["Store"]),
    ]
)
