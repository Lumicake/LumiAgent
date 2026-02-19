// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LumiAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LumiAgent",
            targets: ["LumiAgent"]
        )
    ],
    dependencies: [
        // SwiftAnthropic - Anthropic API client
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "1.0.0"),

        // OpenAI - OpenAI API client
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.0"),

        // GRDB - SQLite database
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),

        // swift-log - Structured logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "LumiAgent",
            dependencies: [
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "LumiAgent",
            resources: [
                .copy("Resources/Models")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
