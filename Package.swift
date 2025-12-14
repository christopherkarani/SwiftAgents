// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftAgents",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .watchOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "SwiftAgents", targets: ["SwiftAgents"]),
        .library(name: "SwiftAgentsUI", targets: ["SwiftAgentsUI"])
    ],
    dependencies: [
        // Swift Syntax for macro implementations
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
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
            dependencies: ["SwiftAgentsMacros"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - UI Library
        .target(
            name: "SwiftAgentsUI",
            dependencies: ["SwiftAgents"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SwiftAgentsTests",
            dependencies: ["SwiftAgents"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAgentsUITests",
            dependencies: ["SwiftAgentsUI"],
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
