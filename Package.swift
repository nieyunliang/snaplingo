// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Snaplingo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Snaplingo", targets: ["Snaplingo"])
    ],
    targets: [
        .executableTarget(
            name: "Snaplingo",
            path: "Sources/Snaplingo",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SnaplingoTests",
            dependencies: ["Snaplingo"],
            path: "Tests/SnaplingoTests"
        )
    ]
)
