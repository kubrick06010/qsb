// swift-tools-version: 6.0

import PackageDescription

var products: [Product] = [
    .library(name: "QSBCore", targets: ["QSBCore"]),
    .executable(name: "qsb", targets: ["QSBCLI"])
]

var targets: [Target] = [
    .target(name: "QSBCore"),
    .executableTarget(name: "QSBCLI", dependencies: ["QSBCore"]),
    .testTarget(
        name: "QSBCoreTests",
        dependencies: ["QSBCore", "QSBCLI"],
        resources: [.copy("Fixtures")]
    ),
    .testTarget(
        name: "QSBCorePortableTests",
        dependencies: ["QSBCore"]
    )
]

#if os(macOS)
products.append(.executable(name: "QSBMacApp", targets: ["QSBMacApp"]))
targets.append(.executableTarget(name: "QSBMacApp", dependencies: ["QSBCore"]))
#endif

let package = Package(
    name: "QSB",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    targets: targets
)
