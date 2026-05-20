// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "nomospace",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "nomospace", targets: ["nomospace"])
    ],
    targets: [
        .executableTarget(
            name: "nomospace",
            path: "Sources/nomospace",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
