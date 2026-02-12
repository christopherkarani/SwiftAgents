// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport
import Foundation

let includeDemo = ProcessInfo.processInfo.environment["SWARM_INCLUDE_DEMO"] == "1"

// Hive integration target is enabled by default for migration/cutover branches.
// Set SWARM_INCLUDE_HIVE=0 to opt out explicitly.
let includeHiveIntegration = ProcessInfo.processInfo.environment["SWARM_INCLUDE_HIVE"] != "0"

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let useLocalDependencies = ProcessInfo.processInfo.environment["SWARM_USE_LOCAL_DEPS"] == "1"

var packageProducts: [Product] = [
    .library(name: "Swarm", targets: ["Swarm"]),
    .library(name: "SwarmMCP", targets: ["SwarmMCP"]),
]

if includeHiveIntegration {
    packageProducts.append(.library(name: "HiveSwarm", targets: ["HiveSwarm"]))
}

if includeDemo {
    packageProducts.append(.executable(name: "SwarmDemo", targets: ["SwarmDemo"]))
    packageProducts.append(.executable(name: "SwarmMCPServerDemo", targets: ["SwarmMCPServerDemo"]))
}

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
]

if useLocalDependencies {
    // NOTE: Local development override.
    let waxCandidates = ["../Wax", "../rag/Wax"]
    let waxPath = waxCandidates.first(where: { candidate in
        FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(candidate).path)
    }) ?? "../Wax"

    packageDependencies.append(.package(path: waxPath))
    packageDependencies.append(.package(path: "../Conduit"))
} else {
    packageDependencies.append(
        .package(
            url: "https://github.com/christopherkarani/Wax.git",
            from: "0.1.3"
        )
    )
    packageDependencies.append(.package(url: "https://github.com/christopherkarani/Conduit", from: "0.3.1"))
}

packageDependencies.append(.package(url: "https://github.com/christopherkarani/Hive", from: "0.1.0"))

var swarmDependencies: [Target.Dependency] = [
    "SwarmMacros",
    .product(name: "Logging", package: "swift-log"),
    .product(name: "Conduit", package: "Conduit"),
    .product(name: "Wax", package: "Wax")
]

swarmDependencies.append(
    .product(
        name: "HiveCore",
        package: "Hive"
    )
)

var swarmSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency")
]

var packageTargets: [Target] = [
    // MARK: - Macro Implementation (Compiler Plugin)
    .macro(
        name: "SwarmMacros",
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
        name: "Swarm",
        dependencies: swarmDependencies,
        swiftSettings: swarmSwiftSettings
    ),
    .target(
        name: "SwarmMCP",
        dependencies: [
            "Swarm",
            .product(name: "MCP", package: "swift-sdk"),
        ],
        swiftSettings: swarmSwiftSettings
    ),

    // MARK: - Tests
    .testTarget(
        name: "SwarmTests",
        dependencies: [
            "Swarm",
            "SwarmMCP",
        ],
        resources: [
            .copy("Guardrails/INTEGRATION_TEST_SUMMARY.md"),
            .copy("Guardrails/QUICK_REFERENCE.md")
        ],
        swiftSettings: swarmSwiftSettings
    ),
    .testTarget(
        name: "SwarmMacrosTests",
        dependencies: [
            "SwarmMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ],
        swiftSettings: [
            .enableExperimentalFeature("StrictConcurrency")
        ]
    )
]

if includeHiveIntegration {
    packageTargets.append(
        .target(
            name: "HiveSwarm",
            dependencies: [
                "Swarm",
                .product(name: "HiveCore", package: "Hive")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )

    packageTargets.append(
        .testTarget(
            name: "HiveSwarmTests",
            dependencies: ["HiveSwarm"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )
}

if includeDemo {
    packageTargets.append(
        .executableTarget(
            name: "SwarmDemo",
            dependencies: ["Swarm"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )

    packageTargets.append(
        .executableTarget(
            name: "SwarmMCPServerDemo",
            dependencies: [
                "Swarm",
                "SwarmMCP",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )
}

let package = Package(
    name: "Swarm",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: packageProducts,
    dependencies: packageDependencies,
    targets: packageTargets
)
