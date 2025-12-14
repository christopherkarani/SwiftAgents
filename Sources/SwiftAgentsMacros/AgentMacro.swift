// AgentMacro.swift
// SwiftAgentsMacros
//
// Implementation of the @Agent macro for generating Agent protocol conformance.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - AgentMacro

/// The `@Agent` macro generates Agent protocol conformance for an actor.
///
/// Usage:
/// ```swift
/// @Agent("You are a helpful assistant")
/// actor MyAgent {
///     @Tools var tools = [CalculatorTool(), DateTimeTool()]
///
///     func process(_ input: String) async throws -> String {
///         // Custom processing logic
///         return "Response"
///     }
/// }
/// ```
///
/// Generates:
/// - All Agent protocol properties with defaults
/// - Standard initializer
/// - `run()` implementation
/// - `stream()` wrapper
/// - `cancel()` implementation
public struct AgentMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract the instructions from macro argument
        let instructions = extractInstructions(from: node) ?? ""

        // Verify this is an actor
        guard declaration.is(ActorDeclSyntax.self) else {
            throw AgentMacroError.onlyApplicableToActor
        }

        // Check for existing properties to avoid duplicates
        let existingMembers = getExistingMemberNames(from: declaration)

        var members: [DeclSyntax] = []

        // 1. Generate tools property if not present
        if !existingMembers.contains("tools") {
            members.append("""
                public let tools: [any Tool] = []
                """)
        }

        // 2. Generate instructions property
        if !existingMembers.contains("instructions") {
            members.append("""
                public let instructions: String = \(literal: instructions)
                """)
        }

        // 3. Generate configuration property
        if !existingMembers.contains("configuration") {
            members.append("""
                public let configuration: AgentConfiguration = .default
                """)
        }

        // 4. Generate memory property
        if !existingMembers.contains("memory") {
            members.append("""
                public nonisolated var memory: (any AgentMemory)? { _memory }
                private nonisolated let _memory: (any AgentMemory)?
                """)
        }

        // 5. Generate inferenceProvider property
        if !existingMembers.contains("inferenceProvider") {
            members.append("""
                public nonisolated var inferenceProvider: (any InferenceProvider)? { _inferenceProvider }
                private nonisolated let _inferenceProvider: (any InferenceProvider)?
                """)
        }

        // 6. Generate isCancelled state
        if !existingMembers.contains("isCancelled") {
            members.append("""
                private var isCancelled: Bool = false
                """)
        }

        // 7. Generate initializer
        if !hasInit(in: declaration) {
            members.append("""
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
                """)
        }

        // 8. Generate run() method
        if !existingMembers.contains("run") {
            let hasProcess = hasProcessMethod(in: declaration)
            if hasProcess {
                members.append("""
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
                    """)
            } else {
                members.append("""
                    public func run(_ input: String) async throws -> AgentResult {
                        throw AgentError.internalError(reason: "No process method implemented")
                    }
                    """)
            }
        }

        // 9. Generate stream() method
        if !existingMembers.contains("stream") {
            members.append("""
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
                """)
        }

        // 10. Generate cancel() method
        if !existingMembers.contains("cancel") {
            members.append("""
                public func cancel() async {
                    isCancelled = true
                }
                """)
        }

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let agentExtension = try ExtensionDeclSyntax("extension \(type): Agent {}")
        return [agentExtension]
    }

    // MARK: - Helper Methods

    /// Extracts the instructions string from the macro attribute.
    private static func extractInstructions(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// Gets names of existing members in the declaration.
    private static func getExistingMemberNames(from declaration: some DeclGroupSyntax) -> Set<String> {
        var names = Set<String>()

        for member in declaration.memberBlock.members {
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings {
                    if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                        names.insert(pattern.identifier.text)
                    }
                }
            } else if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                names.insert(funcDecl.name.text)
            }
        }

        return names
    }

    /// Checks if the declaration has an init.
    private static func hasInit(in declaration: some DeclGroupSyntax) -> Bool {
        for member in declaration.memberBlock.members {
            if member.decl.is(InitializerDeclSyntax.self) {
                return true
            }
        }
        return false
    }

    /// Checks if the declaration has a process method.
    private static func hasProcessMethod(in declaration: some DeclGroupSyntax) -> Bool {
        for member in declaration.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.name.text == "process" {
                return true
            }
        }
        return false
    }
}

// MARK: - AgentMacroError

/// Errors that can occur during @Agent macro expansion.
enum AgentMacroError: Error, CustomStringConvertible {
    case onlyApplicableToActor
    case missingProcessMethod

    var description: String {
        switch self {
        case .onlyApplicableToActor:
            return "@Agent can only be applied to actors"
        case .missingProcessMethod:
            return "@Agent requires a process(_ input: String) method"
        }
    }
}
