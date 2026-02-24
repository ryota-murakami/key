// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Key",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Key",
            path: "Sources/Key",
            resources: [.process("Resources")]
        )
    ]
)
