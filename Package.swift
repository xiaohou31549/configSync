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
    targets: [
        .target(
            name: "SecretSyncKit"
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
