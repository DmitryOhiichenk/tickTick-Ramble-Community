// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TickTickLive",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TickTickLive",
            path: "Sources/TickTickLive",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
