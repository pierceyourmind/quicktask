// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuickTask",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "QuickTask",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
