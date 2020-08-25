// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "DMARCAnalyzer",
    platforms: [.macOS(.v10_11)],
    products: [
        .library(name: "DMARCAnalyzer", targets: ["DMARCAnalyzer"]),
        .executable(name: "analyze", targets: ["analyze"])
    ],
    dependencies: [
        .package(url: "https://github.com/drewag/Swiftlier.git", from: "6.0.0"),
        .package(url: "https://github.com/drewag/command-line-parser.git", from: "3.0.0"),
        .package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.5.2"),
    ],
    targets: [
        .target(name: "DMARCAnalyzer", dependencies: ["Swiftlier","CommandLineParser","SWCompression"]),
        .target(name: "analyze", dependencies: ["DMARCAnalyzer"]),
        .testTarget(name: "DMARCAnalyzerTests", dependencies: ["DMARCAnalyzer"]),
    ]
)
