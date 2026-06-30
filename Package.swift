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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "Ghost",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
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
