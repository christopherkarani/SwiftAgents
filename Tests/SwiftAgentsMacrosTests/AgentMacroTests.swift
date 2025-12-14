// AgentMacroTests.swift
// SwiftAgentsMacrosTests
//
// Tests for the @Agent macro expansion.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftAgentsMacros)
import SwiftAgentsMacros

let agentMacros: [String: Macro.Type] = [
    "Agent": AgentMacro.self
]
#endif

final class AgentMacroTests: XCTestCase {

    // MARK: - Basic Agent Tests

    func testBasicAgentExpansion() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Agent("You are a helpful assistant")
            actor AssistantAgent {
                func process(_ input: String) async throws -> String {
                    return "Hello!"
                }
            }
            """,
            expandedSource: """
            actor AssistantAgent {
                func process(_ input: String) async throws -> String {
                    return "Hello!"
                }

                public let tools: [any Tool] = []

                public let instructions: String = "You are a helpful assistant"

                public let configuration: AgentConfiguration = .default

                public nonisolated var memory: (any AgentMemory)? { _memory }
                private nonisolated let _memory: (any AgentMemory)?

                public nonisolated var inferenceProvider: (any InferenceProvider)? { _inferenceProvider }
                private nonisolated let _inferenceProvider: (any InferenceProvider)?

                private var isCancelled: Bool = false

                public init(
                    tools: [any Tool] = [],
                    instructions: String? = nil,
                    configuration: AgentConfiguration = .default,
                    memory: (any AgentMemory)? = nil,
                    inferenceProvider: (any InferenceProvider)? = nil
                ) {
                    self._memory = memory
                    self._inferenceProvider = inferenceProvider
                }

                public func run(_ input: String) async throws -> AgentResult {
                    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw AgentError.invalidInput(reason: "Input cannot be empty")
                    }

                    if isCancelled {
                        throw AgentError.cancelled
                    }

                    let startTime = ContinuousClock.now

                    // Store in memory if available
                    if let mem = memory {
                        await mem.add(.user(input))
                    }

                    // Call user's process method
                    let output = try await process(input)

                    // Store output in memory
                    if let mem = memory {
                        await mem.add(.assistant(output))
                    }

                    let duration = ContinuousClock.now - startTime

                    return AgentResult(
                        output: output,
                        toolCalls: [],
                        toolResults: [],
                        iterationCount: 1,
                        duration: duration,
                        tokenUsage: nil,
                        metadata: [:]
                    )
                }

                public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
                    AsyncThrowingStream { continuation in
                        Task {
                            do {
                                continuation.yield(.started(input: input))
                                let result = try await self.run(input)
                                continuation.yield(.completed(result: result))
                                continuation.finish()
                            } catch let error as AgentError {
                                continuation.yield(.failed(error: error))
                                continuation.finish(throwing: error)
                            } catch {
                                let agentError = AgentError.internalError(reason: error.localizedDescription)
                                continuation.yield(.failed(error: agentError))
                                continuation.finish(throwing: agentError)
                            }
                        }
                    }
                }

                public func cancel() async {
                    isCancelled = true
                }
            }

            extension AssistantAgent: Agent {}
            """,
            macros: agentMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAgentWithExistingTools() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Agent("Math assistant")
            actor MathAgent {
                let tools: [any Tool] = [CalculatorTool()]

                func process(_ input: String) async throws -> String {
                    return "Calculated!"
                }
            }
            """,
            expandedSource: """
            actor MathAgent {
                let tools: [any Tool] = [CalculatorTool()]

                func process(_ input: String) async throws -> String {
                    return "Calculated!"
                }

                public let instructions: String = "Math assistant"

                public let configuration: AgentConfiguration = .default

                public nonisolated var memory: (any AgentMemory)? { _memory }
                private nonisolated let _memory: (any AgentMemory)?

                public nonisolated var inferenceProvider: (any InferenceProvider)? { _inferenceProvider }
                private nonisolated let _inferenceProvider: (any InferenceProvider)?

                private var isCancelled: Bool = false

                public init(
                    tools: [any Tool] = [],
                    instructions: String? = nil,
                    configuration: AgentConfiguration = .default,
                    memory: (any AgentMemory)? = nil,
                    inferenceProvider: (any InferenceProvider)? = nil
                ) {
                    self._memory = memory
                    self._inferenceProvider = inferenceProvider
                }

                public func run(_ input: String) async throws -> AgentResult {
                    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw AgentError.invalidInput(reason: "Input cannot be empty")
                    }

                    if isCancelled {
                        throw AgentError.cancelled
                    }

                    let startTime = ContinuousClock.now

                    // Store in memory if available
                    if let mem = memory {
                        await mem.add(.user(input))
                    }

                    // Call user's process method
                    let output = try await process(input)

                    // Store output in memory
                    if let mem = memory {
                        await mem.add(.assistant(output))
                    }

                    let duration = ContinuousClock.now - startTime

                    return AgentResult(
                        output: output,
                        toolCalls: [],
                        toolResults: [],
                        iterationCount: 1,
                        duration: duration,
                        tokenUsage: nil,
                        metadata: [:]
                    )
                }

                public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
                    AsyncThrowingStream { continuation in
                        Task {
                            do {
                                continuation.yield(.started(input: input))
                                let result = try await self.run(input)
                                continuation.yield(.completed(result: result))
                                continuation.finish()
                            } catch let error as AgentError {
                                continuation.yield(.failed(error: error))
                                continuation.finish(throwing: error)
                            } catch {
                                let agentError = AgentError.internalError(reason: error.localizedDescription)
                                continuation.yield(.failed(error: agentError))
                                continuation.finish(throwing: agentError)
                            }
                        }
                    }
                }

                public func cancel() async {
                    isCancelled = true
                }
            }

            extension MathAgent: Agent {}
            """,
            macros: agentMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Cases

    func testAgentOnlyAppliesToActor() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            @Agent("Invalid")
            struct InvalidAgent {
                func process(_ input: String) async throws -> String {
                    return ""
                }
            }
            """,
            expandedSource: """
            struct InvalidAgent {
                func process(_ input: String) async throws -> String {
                    return ""
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Agent can only be applied to actors", line: 1, column: 1)
            ],
            macros: agentMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAgentWithoutProcessMethod() throws {
        #if canImport(SwiftAgentsMacros)
        // Agent without process method should still compile but run() throws
        assertMacroExpansion(
            """
            @Agent("No process method")
            actor IncompleteAgent {
            }
            """,
            expandedSource: """
            actor IncompleteAgent {

                public let tools: [any Tool] = []

                public let instructions: String = "No process method"

                public let configuration: AgentConfiguration = .default

                public nonisolated var memory: (any AgentMemory)? { _memory }
                private nonisolated let _memory: (any AgentMemory)?

                public nonisolated var inferenceProvider: (any InferenceProvider)? { _inferenceProvider }
                private nonisolated let _inferenceProvider: (any InferenceProvider)?

                private var isCancelled: Bool = false

                public init(
                    tools: [any Tool] = [],
                    instructions: String? = nil,
                    configuration: AgentConfiguration = .default,
                    memory: (any AgentMemory)? = nil,
                    inferenceProvider: (any InferenceProvider)? = nil
                ) {
                    self._memory = memory
                    self._inferenceProvider = inferenceProvider
                }

                public func run(_ input: String) async throws -> AgentResult {
                    throw AgentError.internalError(reason: "No process method implemented")
                }

                public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
                    AsyncThrowingStream { continuation in
                        Task {
                            do {
                                continuation.yield(.started(input: input))
                                let result = try await self.run(input)
                                continuation.yield(.completed(result: result))
                                continuation.finish()
                            } catch let error as AgentError {
                                continuation.yield(.failed(error: error))
                                continuation.finish(throwing: error)
                            } catch {
                                let agentError = AgentError.internalError(reason: error.localizedDescription)
                                continuation.yield(.failed(error: agentError))
                                continuation.finish(throwing: agentError)
                            }
                        }
                    }
                }

                public func cancel() async {
                    isCancelled = true
                }
            }

            extension IncompleteAgent: Agent {}
            """,
            macros: agentMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
