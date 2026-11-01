// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlueClip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BlueClip", targets: ["BlueClip"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "BlueClip",
            dependencies: [],
            path: "Sources"
        )
    ]
)
