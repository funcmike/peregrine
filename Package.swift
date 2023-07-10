// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "peregrine",
    products: [
        .library(name: "SMTPProtocol", targets: ["SMTPProtocol"]),
        .library(name: "SMTPClient", targets: ["SMTPClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.54.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.24.0"),
        .package(url: "https://github.com/apple/swift-collections.git",  .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SMTPProtocol",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
        .target(
            name: "SMTPClient",
            dependencies: [
                "SMTPProtocol",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .executableTarget(
            name: "Peregrine",
            dependencies: [
                "SMTPClient",
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SMTPProtocolTests",
            dependencies: ["SMTPProtocol"]),
        .testTarget(
            name: "SMTPConnectionTests",
            dependencies: ["SMTPClient"]),
    ]
)
