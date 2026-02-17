// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuickTask",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "2.4.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", exact: "9.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "QuickTask",
            dependencies: ["KeyboardShortcuts", "Defaults"],
            path: "Sources",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
