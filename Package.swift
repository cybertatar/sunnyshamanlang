// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SunboyShaman",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ShamanCore"),
        .executableTarget(name: "SunboyShaman", dependencies: ["ShamanCore"]),
        .testTarget(name: "ShamanCoreTests", dependencies: ["ShamanCore"]),
    ]
)
