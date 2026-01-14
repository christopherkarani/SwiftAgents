// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftAgents",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftAgents", targets: ["SwiftAgents"])
    ],
    dependencies: [
        // Swift Syntax for macro implementations
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        // Swift Logging API
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),

    ],
    targets: [
        // MARK: - Macro Implementation (Compiler Plugin)
        .macro(
            name: "SwiftAgentsMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Main Library
        .target(
            name: "SwiftAgents",
            dependencies: [
                "SwiftAgentsMacros",
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SwiftAgentsTests",
            dependencies: ["SwiftAgents"],
            resources: [
                .copy("Guardrails/INTEGRATION_TEST_SUMMARY.md"),
                .copy("Guardrails/QUICK_REFERENCE.md")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAgentsMacrosTests",
            dependencies: [
                "SwiftAgentsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
