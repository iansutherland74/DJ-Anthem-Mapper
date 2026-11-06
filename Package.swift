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
    dependencies: [
        .package(url: "https://github.com/ondeinference/demucs-swift", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "DJAnthemMapper",
            dependencies: [
                .product(name: "Demucs", package: "demucs-swift")
            ]
        ),
        .testTarget(
            name: "DJAnthemMapperTests",
            dependencies: ["DJAnthemMapper"]
        )
    ],
    swiftLanguageModes: [.v5]
)
