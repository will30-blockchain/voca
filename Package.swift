// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VOCA",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VOCA", targets: ["VOCA"]),
        .library(name: "VOCACore", targets: ["VOCACore"])
    ],
    targets: [
        .target(
            name: "VOCACore",
            path: "Sources/VOCACore"
        ),
        .executableTarget(
            name: "VOCA",
            dependencies: ["VOCACore"],
            path: "Sources/VOCA",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "VOCACoreTests",
            dependencies: ["VOCACore"],
            path: "Tests/VOCACoreTests"
        )
    ]
)
