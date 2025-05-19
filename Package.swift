// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KDL",
    platforms: [
        .macOS("13.3"), .iOS("16.4"), .macCatalyst("13.3"), .tvOS("16.4"),
        .watchOS("9.4")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "KDL",
            targets: ["KDL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mgriebling/BigDecimal.git", from: "3.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "KDL",
            dependencies: ["BigDecimal"]),
        .testTarget(
            name: "KDLTests",
            dependencies: ["KDL"]),
    ]
)
