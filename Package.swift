// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dmarc-analyzer",
    products: [
        .library(
            name: "DMARCAnalyzer",
            targets: ["DMARCAnalyzer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/drewag/Swiftlier.git", from: "4.0.0"),
        .package(url: "https://github.com/drewag/command-line-parser.git", from: "2.0.0"),
    ]
)
