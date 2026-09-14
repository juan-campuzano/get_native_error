// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "get_native_error",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "get-native-error", targets: ["get_native_error"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "get_native_error",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath(".")
            ]
        )
    ]
)
