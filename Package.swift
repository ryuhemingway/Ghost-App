// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Ghost",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Ghost", targets: ["Ghost"])
    ],
    targets: [
        .executableTarget(
            name: "Ghost",
            path: "Sources/Ghost",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GhostTests",
            dependencies: ["Ghost"]
        )
    ]
)
