// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MemoryJar",
    platforms: [
        .iOS(.v14),
        .tvOS(.v14),
    ],
    products: [
        .library(name: "MemoryJar", targets: ["MemoryJar"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "MemoryJar", dependencies: [], path: "MemoryJar"),
    ],
    swiftLanguageVersions: [.v5]
)
