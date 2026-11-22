// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LirikTouchBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LirikTouchBar", targets: ["LirikTouchBar"])
    ],
    targets: [
        .executableTarget(
            name: "LirikTouchBar",
            path: "Sources/LirikTouchBar",
            resources: [.copy("Assets")]
        )
    ]
)
