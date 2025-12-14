// ToolMacroTests.swift
// SwiftAgentsMacrosTests
//
// Tests for the @Tool macro expansion.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftAgentsMacros)
import SwiftAgentsMacros

let toolMacros: [String: Macro.Type] = [
    "Tool": ToolMacro.self,
    "Parameter": ParameterMacro.self
]
#endif

final class ToolMacroTests: XCTestCase {

    // MARK: - Basic Tool Tests

    func testBasicToolExpansion() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Calculates mathematical expressions")
            struct CalculatorTool {
                @Parameter("The expression to evaluate")
                var expression: String

                func execute() async throws -> Double {
                    return 42.0
                }
            }
            """,
            expandedSource: """
            struct CalculatorTool {
                var expression: String

                func execute() async throws -> Double {
                    return 42.0
                }

                public let name: String = "calculator"

                public let description: String = "Calculates mathematical expressions"

                public let parameters: [ToolParameter] = [
                    ToolParameter(
                        name: "expression",
                        description: "The expression to evaluate",
                        type: .string,
                        isRequired: true
                    )
                ]

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    guard let expression = arguments["expression"]?.stringValue else {
                        throw AgentError.invalidToolArguments(toolName: name, reason: "Missing required parameter 'expression'")
                    }

                    let result = try await self._userExecute(expression: expression)
                    return .double(result)
                }

                private func _userExecute(expression: String) async throws -> Double {
                    try await execute()
                }
            }

            extension CalculatorTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolWithMultipleParameters() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Gets weather for a location")
            struct WeatherTool {
                @Parameter("City name")
                var location: String

                @Parameter("Temperature units", default: "celsius")
                var units: String = "celsius"

                func execute() async throws -> String {
                    return "Sunny"
                }
            }
            """,
            expandedSource: """
            struct WeatherTool {
                var location: String

                var units: String = "celsius"

                func execute() async throws -> String {
                    return "Sunny"
                }

                public let name: String = "weather"

                public let description: String = "Gets weather for a location"

                public let parameters: [ToolParameter] = [
                    ToolParameter(
                        name: "location",
                        description: "City name",
                        type: .string,
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "units",
                        description: "Temperature units",
                        type: .string,
                        isRequired: false,
                        defaultValue: .string("celsius")
                    )
                ]

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    guard let location = arguments["location"]?.stringValue else {
                        throw AgentError.invalidToolArguments(toolName: name, reason: "Missing required parameter 'location'")
                    }
                    let units = arguments["units"]?.stringValue ?? "celsius"

                    let result = try await self._userExecute(location: location, units: units)
                    return .string(result)
                }

                private func _userExecute(location: String, units: String) async throws -> String {
                    try await execute()
                }
            }

            extension WeatherTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolWithOneOfParameter() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Formats output")
            struct FormatTool {
                @Parameter("Output format", oneOf: ["json", "xml", "text"])
                var format: String

                func execute() async throws -> String {
                    return "{}"
                }
            }
            """,
            expandedSource: """
            struct FormatTool {
                var format: String

                func execute() async throws -> String {
                    return "{}"
                }

                public let name: String = "format"

                public let description: String = "Formats output"

                public let parameters: [ToolParameter] = [
                    ToolParameter(
                        name: "format",
                        description: "Output format",
                        type: .oneOf(["json", "xml", "text"]),
                        isRequired: true
                    )
                ]

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    guard let format = arguments["format"]?.stringValue else {
                        throw AgentError.invalidToolArguments(toolName: name, reason: "Missing required parameter 'format'")
                    }

                    let result = try await self._userExecute(format: format)
                    return .string(result)
                }

                private func _userExecute(format: String) async throws -> String {
                    try await execute()
                }
            }

            extension FormatTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolWithIntParameter() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Counts items")
            struct CountTool {
                @Parameter("Number of items")
                var count: Int

                func execute() async throws -> Int {
                    return count * 2
                }
            }
            """,
            expandedSource: """
            struct CountTool {
                var count: Int

                func execute() async throws -> Int {
                    return count * 2
                }

                public let name: String = "count"

                public let description: String = "Counts items"

                public let parameters: [ToolParameter] = [
                    ToolParameter(
                        name: "count",
                        description: "Number of items",
                        type: .int,
                        isRequired: true
                    )
                ]

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    guard let count = arguments["count"]?.intValue else {
                        throw AgentError.invalidToolArguments(toolName: name, reason: "Missing required parameter 'count'")
                    }

                    let result = try await self._userExecute(count: count)
                    return .int(result)
                }

                private func _userExecute(count: Int) async throws -> Int {
                    try await execute()
                }
            }

            extension CountTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolWithBoolParameter() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Toggles a flag")
            struct ToggleTool {
                @Parameter("Enable the feature", default: false)
                var enabled: Bool = false

                func execute() async throws -> Bool {
                    return !enabled
                }
            }
            """,
            expandedSource: """
            struct ToggleTool {
                var enabled: Bool = false

                func execute() async throws -> Bool {
                    return !enabled
                }

                public let name: String = "toggle"

                public let description: String = "Toggles a flag"

                public let parameters: [ToolParameter] = [
                    ToolParameter(
                        name: "enabled",
                        description: "Enable the feature",
                        type: .bool,
                        isRequired: false,
                        defaultValue: .bool(false)
                    )
                ]

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    let enabled = arguments["enabled"]?.boolValue ?? false

                    let result = try await self._userExecute(enabled: enabled)
                    return .bool(result)
                }

                private func _userExecute(enabled: Bool) async throws -> Bool {
                    try await execute()
                }
            }

            extension ToggleTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Cases

    func testToolRequiresDescription() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool
            struct InvalidTool {
                func execute() async throws -> String {
                    return ""
                }
            }
            """,
            expandedSource: """
            struct InvalidTool {
                func execute() async throws -> String {
                    return ""
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tool requires a description string argument", line: 1, column: 1)
            ],
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testToolOnlyAppliesToStruct() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Tool("Not valid")
            class InvalidTool {
                func execute() async throws -> String {
                    return ""
                }
            }
            """,
            expandedSource: """
            class InvalidTool {
                func execute() async throws -> String {
                    return ""
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Tool can only be applied to structs", line: 1, column: 1)
            ],
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Tool Name Derivation

    func testToolNameDerivation() throws {
        #if canImport(SwiftAgentsMacros)
        // Test that "CalculatorTool" becomes "calculator"
        // Test that "Weather" becomes "weather"

        assertMacroExpansion(
            """
            @Tool("Simple tool")
            struct MyAwesomeTool {
                func execute() async throws -> String {
                    return ""
                }
            }
            """,
            expandedSource: """
            struct MyAwesomeTool {
                func execute() async throws -> String {
                    return ""
                }

                public let name: String = "myawesome"

                public let description: String = "Simple tool"

                public let parameters: [ToolParameter] = []

                public init() {}

                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {

                    let result = try await self._userExecute()
                    return .string(result)
                }

                private func _userExecute() async throws -> String {
                    try await execute()
                }
            }

            extension MyAwesomeTool: Tool, Sendable {}
            """,
            macros: toolMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
