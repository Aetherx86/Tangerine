// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tangerine",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Tangerine", targets: ["TangerineApp"]),
        .library(name: "TangerineKit", targets: ["TangerineKit"]),
        .executable(name: "ShowcaseGenerator", targets: ["ShowcaseGenerator"])
    ],
    targets: [
        .target(
            name: "TangerineKit",
            path: "Sources"
        ),
        .executableTarget(
            name: "TangerineApp",
            dependencies: ["TangerineKit"],
            path: "App"
        ),
        .executableTarget(
            name: "ShowcaseGenerator",
            dependencies: ["TangerineKit"],
            path: "Showcase"
        ),
        .testTarget(
            name: "TangerineTests",
            dependencies: ["TangerineKit"],
            path: "Tests"
        )
    ]
)
