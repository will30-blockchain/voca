// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiceType", targets: ["VoiceTypeApp"]),
        .library(name: "VoiceTypeCore", targets: ["VoiceTypeCore"])
    ],
    targets: [
        .target(
            name: "VoiceTypeCore",
            path: "Sources/VoiceTypeCore"
        ),
        .executableTarget(
            name: "VoiceTypeApp",
            dependencies: ["VoiceTypeCore"],
            path: "Sources/VoiceTypeApp",
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
            name: "VoiceTypeCoreTests",
            dependencies: ["VoiceTypeCore"],
            path: "Tests/VoiceTypeCoreTests"
        )
    ]
)
