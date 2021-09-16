// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MemoryJar",
    platforms: [
        .iOS(.v10),
        .tvOS(.v11),
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
