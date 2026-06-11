// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReLaunchpad",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", from: "4.0.0"),
        // Vendored: CommandLineTools lacks the SwiftUI PreviewsMacros plugin,
        // so the upstream package's bare #Preview blocks fail to compile.
        .package(path: "Vendor/KeyboardShortcuts"),
    ],
    targets: [
        .executableTarget(
            name: "ReLaunchpad",
            dependencies: [
                .product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(
            name: "ReLaunchpadTests",
            dependencies: ["ReLaunchpad"]
        ),
    ]
)
