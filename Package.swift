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
    targets: [
        .executableTarget(
            name: "LoqClock"
        ),
        .testTarget(
            name: "LoqClockTests",
            dependencies: ["LoqClock"]
        )
    ]
)
