// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StikiCore",
    platforms: [
        .iOS("26.0"),
        .macOS("13.0")
    ],
    products: [
        .library(name: "StikiCore", targets: ["StikiCore"])
    ],
    targets: [
        .target(
            name: "StikiCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StikiCoreTests",
            dependencies: ["StikiCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
