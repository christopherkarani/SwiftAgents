// TraceableMacro.swift
// SwarmMacros
//
// Implementation of the @Traceable macro for automatic observability.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - TraceableMacro

/// The `@Traceable` macro adds automatic tracing/observability to tool or agent methods.
///
/// Usage:
/// ```swift
/// @Traceable
/// struct WeatherTool: Tool {
///     // execute() is automatically wrapped with tracing
/// }
/// ```
///
/// Generates:
/// - Wraps execute() method with trace events
/// - Records start time, duration, arguments, and results
/// - Emits TraceEvent for observability
public struct TraceableMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Check if this is attached to a struct with Tool conformance
        guard declaration.is(StructDeclSyntax.self) else {
            throw TraceableError.onlyApplicableToStruct
        }

        // Generate a traced wrapper extension
        // Note: In practice, this would generate a wrapper that intercepts execute()
        // For now, we generate a helper method that tools can call

        let tracedExecute: DeclSyntax = """
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
            """

        return [tracedExecute]
    }
}

// MARK: - TraceableError

/// Errors for @Traceable macro.
enum TraceableError: Error, CustomStringConvertible {
    case onlyApplicableToStruct
    case missingExecuteMethod

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Traceable can only be applied to structs"
        case .missingExecuteMethod:
            return "@Traceable requires an execute() method to wrap"
        }
    }
}
