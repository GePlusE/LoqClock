// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LoqClock",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LoqClock",
            targets: ["LoqClock"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LoqClock",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "LoqClockTests",
            dependencies: ["LoqClock"]
        )
    ]
)
