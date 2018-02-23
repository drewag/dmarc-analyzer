// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DMARCAnalyzer",
    products: [
        .library(
            name: "DMARCAnalyzer",
            targets: ["DMARCAnalyzer"]),
        .executable(
            name: "analyze",
            targets: ["analyze"])
    ],
    dependencies: [
        .package(url: "https://github.com/drewag/Swiftlier.git", from: "4.0.0"),
        .package(url: "https://github.com/drewag/command-line-parser.git", from: "2.0.0"),
        .package(url: "https://github.com/drewag/swift-serve.git", from: "11.0.0"),
        .package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "DMARCAnalyzer",
            dependencies: ["Swiftlier","CommandLineParser","SwiftServe", "SWCompression"]),
        .target(
            name: "analyze",
            dependencies: ["DMARCAnalyzer"]),
    ]
)
