// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clutch",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Clutch",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Clutch",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
