// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DJAnthemMapper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(
            name: "DJAnthemMapper",
            targets: ["DJAnthemMapper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DJAnthemMapper"
        ),
        .testTarget(
            name: "DJAnthemMapperTests",
            dependencies: ["DJAnthemMapper"]
        )
    ],
    swiftLanguageModes: [.v5]
)
