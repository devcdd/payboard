// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PayBoard",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "AppCore", targets: ["AppCore"]),
        .executable(name: "PayBoardApp", targets: ["PayBoardApp"])
    ],
    targets: [
        .target(name: "Domain"),
        .target(
            name: "Data",
            dependencies: ["Domain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "DesignSystem",
            dependencies: []
        ),
        .target(
            name: "Features",
            dependencies: ["Domain", "Data", "DesignSystem"]
        ),
        .target(
            name: "AppCore",
            dependencies: ["Domain", "Data"]
        ),
        .executableTarget(
            name: "PayBoardApp",
            dependencies: ["AppCore", "Features", "DesignSystem"]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
        .testTarget(
            name: "DataTests",
            dependencies: ["Data", "Domain"]
        )
    ]
)
