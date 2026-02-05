// TraceableMacroTests.swift
// SwarmMacrosTests
//
// Tests for the @Traceable macro expansion.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwarmMacros)
    import SwarmMacros

    let traceableMacros: [String: Macro.Type] = [
        "Traceable": TraceableMacro.self
    ]
#endif

// MARK: - TraceableMacroTests

final class TraceableMacroTests: XCTestCase {
    // MARK: - Basic Traceable Tests

    // swiftlint:disable:next function_body_length
    func testTraceableMacroExpansion() throws {
        #if canImport(SwarmMacros)
            assertMacroExpansion(
                """
                @Traceable
                struct WeatherTool: Tool {
                    let name = "weather"
                    let description = "Gets weather"
                    let parameters: [ToolParameter] = []

                    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                        return .string("Sunny")
                    }
                }
                """,
                expandedSource: """
                struct WeatherTool: Tool {
                    let name = "weather"
                    let description = "Gets weather"
                    let parameters: [ToolParameter] = []

                    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                        return .string("Sunny")
                    }
                }

                /// Executes the tool with tracing enabled.
                /// - Parameters:
                ///   - arguments: The tool arguments.
                ///   - tracer: Optional tracer for recording events.
                /// - Returns: The result of execution.
                public func executeWithTracing(
                    arguments: [String: SendableValue],
                    tracer: (any Tracer)? = nil
                ) async throws -> SendableValue {
                    let startTime = ContinuousClock.now
                    let traceId = UUID()

                    // Emit start event
                    if let tracer = tracer {
                        await tracer.record(TraceEvent(
                            id: traceId,
                            type: .toolCall,
                            name: name,
                            timestamp: Date(),
                            duration: nil,
                            metadata: ["arguments": .object(arguments)]
                        ))
                    }

                    do {
                        let result = try await execute(arguments: arguments)
                        let duration = ContinuousClock.now - startTime

                        // Emit success event
                        if let tracer = tracer {
                            await tracer.record(TraceEvent(
                                id: traceId,
                                type: .toolResult,
                                name: name,
                                timestamp: Date(),
                                duration: duration,
                                metadata: [
                                    "result": result,
                                    "success": .bool(true)
                                ]
                            ))
                        }

                        return result
                    } catch {
                        let duration = ContinuousClock.now - startTime

                        // Emit error event
                        if let tracer = tracer {
                            await tracer.record(TraceEvent(
                                id: traceId,
                                type: .error,
                                name: name,
                                timestamp: Date(),
                                duration: duration,
                                metadata: [
                                    "error": .string(error.localizedDescription),
                                    "success": .bool(false)
                                ]
                            ))
                        }

                        throw error
                    }
                }
                """,
                macros: traceableMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Cases

    func testTraceableOnlyAppliesToStruct() throws {
        #if canImport(SwarmMacros)
            assertMacroExpansion(
                """
                @Traceable
                class InvalidTool {
                }
                """,
                expandedSource: """
                class InvalidTool {
                }
                """,
                diagnostics: [
                    DiagnosticSpec(message: "@Traceable can only be applied to structs", line: 1, column: 1)
                ],
                macros: traceableMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
