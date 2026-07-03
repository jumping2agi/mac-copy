// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuBarTool",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarTool",
            path: "Sources/MenuBarTool"
        )
    ]
)
