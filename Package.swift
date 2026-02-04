// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport
import Foundation

let includeDemo = ProcessInfo.processInfo.environment["SWIFTAGENTS_INCLUDE_DEMO"] == "1"
let includeHive = ProcessInfo.processInfo.environment["SWIFTAGENTS_INCLUDE_HIVE"] == "1"
let useLocalDependencies = ProcessInfo.processInfo.environment["SWIFTAGENTS_USE_LOCAL_DEPS"] == "1"

var packageProducts: [Product] = [
    .library(name: "SwiftAgents", targets: ["SwiftAgents"])
]

if includeHive {
    packageProducts.append(.library(name: "HiveSwiftAgents", targets: ["HiveSwiftAgents"]))
}

if includeDemo {
    packageProducts.append(.executable(name: "SwiftAgentsDemo", targets: ["SwiftAgentsDemo"]))
}

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
]

if useLocalDependencies {
    // NOTE: Local development override.
    packageDependencies.append(.package(path: "../rag/Wax"))
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

if includeHive {
    if useLocalDependencies {
        // NOTE: Opt-in; requires a local checkout of Hive.
        packageDependencies.append(.package(path: "../Hive/libs/hive"))
    } else {
        packageDependencies.append(.package(url: "https://github.com/christopherkarani/Hive", from: "0.1.0"))
    }
}

var packageTargets: [Target] = [
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
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Conduit", package: "Conduit"),
            .product(name: "Wax", package: "Wax")
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
    ),

]

if includeHive {
    packageTargets.append(
        .target(
            name: "HiveSwiftAgents",
            dependencies: [
                "SwiftAgents",
                .product(name: "HiveCore", package: "Hive")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )

    packageTargets.append(
        .testTarget(
            name: "HiveSwiftAgentsTests",
            dependencies: ["HiveSwiftAgents"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )
}

if includeDemo {
    packageTargets.append(
        .executableTarget(
            name: "SwiftAgentsDemo",
            dependencies: ["SwiftAgents"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    )
}

let package = Package(
    name: "SwiftAgents",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: packageProducts,
    dependencies: packageDependencies,
    targets: packageTargets
)
