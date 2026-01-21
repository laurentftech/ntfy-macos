// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ntfy-macos",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ntfy-macos",
            targets: ["ntfy-macos"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ntfy-macos",
            dependencies: ["Yams"],
            path: "Sources"
        ),
        .testTarget(
            name: "ntfy-macosTests",
            dependencies: ["ntfy-macos", "Yams"],
            path: "Tests/ntfy-macosTests"
        )
    ]
)
