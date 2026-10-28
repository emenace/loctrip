// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocTrip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocTrip", targets: ["LocTrip"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "LocTrip",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/LocTrip",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
    ]
)
