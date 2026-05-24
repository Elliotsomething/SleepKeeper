// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SleepKeeper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SleepKeeper", targets: ["SleepKeeper"]),
        .library(name: "SleepKeeperCore", targets: ["SleepKeeperCore"])
    ],
    targets: [
        .target(
            name: "SleepKeeperCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "SleepKeeper",
            dependencies: ["SleepKeeperCore"]
        ),
        .testTarget(
            name: "SleepKeeperCoreTests",
            dependencies: ["SleepKeeperCore"]
        )
    ]
)
