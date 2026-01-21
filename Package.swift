// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JSBeautify",
    platforms: [
        .macOS(.v11),
        .iOS(.v12),
        .tvOS(.v12),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "JSBeautify",
            targets: ["JSBeautify"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "JSBeautify",
            resources: [
                .copy("Assets/beautify.min.js"),
                .copy("Assets/beautify-css.min.js"),
                .copy("Assets/beautify-html.min.js"),
                .copy("Assets/JSBeautify-LICENSE"),
                .copy("Assets/LICENSE")
            ]
        ),
        .testTarget(
            name: "JSBeautifyTests",
            dependencies: ["JSBeautify"],
            exclude: [
                "Fixtures/beautify-node.js"
            ]
        ),
    ]
)
