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
/// - Builder class (optional, enabled by default)
public struct AgentMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    // swiftlint:disable:next function_body_length
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
                public let tools: [any Tool]
                """)
        }

        // 2. Generate instructions property
        if !existingMembers.contains("instructions") {
            members.append("""
                public let instructions: String
                """)
        }

        // 3. Generate configuration property
        if !existingMembers.contains("configuration") {
            members.append("""
                public let configuration: AgentConfiguration
                """)
        }

        // 4. Generate memory property
        if !existingMembers.contains("memory") {
            members.append("""
                public nonisolated var memory: (any Memory)? { _memory }
                private nonisolated let _memory: (any Memory)?
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
            let defaultInstructions = instructions.isEmpty ? "" : instructions
            members.append("""
                public init(
                    tools: [any Tool] = [],
                    instructions: String = \(literal: defaultInstructions),
                    configuration: AgentConfiguration = .default,
                    memory: (any Memory)? = nil,
                    inferenceProvider: (any InferenceProvider)? = nil
                ) {
                    self.tools = tools
                    self.instructions = instructions
                    self.configuration = configuration
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
                    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
                    Task { @Sendable [weak self] in
                        guard let self else {
                            continuation.finish()
                            return
                        }
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
                    return stream
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

        // 11. Generate Builder class (enabled by default)
        // Disable with @Agent(instructions: "...", generateBuilder: false)
        if shouldGenerateBuilder(from: node) {
            let typeName: String
            if let actorDecl = declaration.as(ActorDeclSyntax.self) {
                typeName = actorDecl.name.text
            } else {
                typeName = "Agent"
            }
            members.append(generateBuilderClass(typeName: typeName))
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
        // Only add extension for actors
        guard declaration.is(ActorDeclSyntax.self) else {
            return []
        }
        let agentExtension = try ExtensionDeclSyntax("extension \(type): AgentRuntime {}")
        return [agentExtension]
    }

    // MARK: - Helper Methods

    /// Extracts the instructions string from the macro attribute.
    /// Supports both labeled and unlabeled argument formats for backward compatibility.
    private static func extractInstructions(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }
        
        // Try to find labeled "instructions" argument first
        for argument in arguments {
            if argument.label?.text == "instructions",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
        }
        
        // Fallback to unlabeled first argument for backward compatibility
        if let firstArg = arguments.first,
           firstArg.label == nil,
           let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
           let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return segment.content.text
        }
        
        return nil
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
        for member in declaration.memberBlock.members where member.decl.is(InitializerDeclSyntax.self) {
            return true
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

    /// Extracts the generateBuilder parameter from the macro arguments.
    static func shouldGenerateBuilder(from node: AttributeSyntax) -> Bool {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return true // Default to generating builder
        }

        for argument in arguments {
            if argument.label?.text == "generateBuilder",
               let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                return boolLiteral.literal.tokenKind == .keyword(.true)
            }
        }

        return true // Default to generating builder
    }

    /// Generates the Builder struct for the agent.
    /// Uses value semantics for Swift 6 concurrency safety.
    static func generateBuilderClass(typeName: String) -> DeclSyntax {
        """
        /// A fluent builder for creating \(raw: typeName) instances.
        /// Uses value semantics (struct) for Swift 6 concurrency safety.
        public struct Builder: Sendable {
            private var _tools: [any Tool] = []
            private var _instructions: String = ""
            private var _configuration: AgentConfiguration = .default
            private var _memory: (any Memory)?
            private var _inferenceProvider: (any InferenceProvider)?

            /// Creates a new builder with default values.
            public init() {}

            /// Sets the tools for the agent.
            public func tools(_ tools: [any Tool]) -> Builder {
                var copy = self
                copy._tools = tools
                return copy
            }

            /// Adds a tool to the agent's tool set.
            public func addTool(_ tool: any Tool) -> Builder {
                var copy = self
                copy._tools.append(tool)
                return copy
            }

            /// Sets the instructions for the agent.
            public func instructions(_ instructions: String) -> Builder {
                var copy = self
                copy._instructions = instructions
                return copy
            }

            /// Sets the configuration for the agent.
            public func configuration(_ configuration: AgentConfiguration) -> Builder {
                var copy = self
                copy._configuration = configuration
                return copy
            }

            /// Sets the memory system for the agent.
            public func memory(_ memory: any Memory) -> Builder {
                var copy = self
                copy._memory = memory
                return copy
            }

            /// Sets the inference provider for the agent.
            public func inferenceProvider(_ provider: any InferenceProvider) -> Builder {
                var copy = self
                copy._inferenceProvider = provider
                return copy
            }

            /// Builds the agent with the configured values.
            public func build() -> \(raw: typeName) {
                \(raw: typeName)(
                    tools: _tools,
                    instructions: _instructions,
                    configuration: _configuration,
                    memory: _memory,
                    inferenceProvider: _inferenceProvider
                )
            }
        }
        """
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
