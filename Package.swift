// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SecretSync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SecretSyncKit",
            targets: ["SecretSyncKit"]
        ),
        .executable(
            name: "SecretSyncApp",
            targets: ["SecretSyncApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jedisct1/swift-sodium.git", from: "0.9.1")
    ],
    targets: [
        .target(
            name: "SecretSyncKit",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium")
            ]
        ),
        .executableTarget(
            name: "SecretSyncApp",
            dependencies: ["SecretSyncKit"]
        ),
        .testTarget(
            name: "SecretSyncKitTests",
            dependencies: ["SecretSyncKit"]
        )
    ]
)
