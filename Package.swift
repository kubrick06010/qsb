// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QSB",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QSBCore", targets: ["QSBCore"]),
        .executable(name: "qsb", targets: ["QSBCLI"]),
        .executable(name: "QSBMacApp", targets: ["QSBMacApp"])
    ],
    targets: [
        .target(name: "QSBCore"),
        .executableTarget(
            name: "QSBCLI",
            dependencies: ["QSBCore"]
        ),
        .executableTarget(
            name: "QSBMacApp",
            dependencies: ["QSBCore"]
        ),
        .testTarget(
            name: "QSBCoreTests",
            dependencies: ["QSBCore"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
