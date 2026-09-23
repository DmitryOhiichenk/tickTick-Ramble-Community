// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DictateForTickTick",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DictateForTickTick",
            path: "Sources/DictateForTickTick",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
