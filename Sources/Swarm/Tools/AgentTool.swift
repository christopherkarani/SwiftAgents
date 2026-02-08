// AgentTool.swift
// Swarm Framework
//
// Wraps an AgentRuntime as a callable tool for agent composition.

import Foundation

// MARK: - AgentTool

/// Wraps an `AgentRuntime` as a callable tool, enabling agent composition.
///
/// `AgentTool` allows any agent to be used as a sub-tool by another agent.
/// When the outer agent calls this tool, the inner agent runs with the provided
/// input and returns its output as the tool result.
///
/// This enables hierarchical agent patterns without requiring full orchestration
/// infrastructure like `Swarm` or `SupervisorAgent`.
///
/// Example:
/// ```swift
/// let researcher = Agent(
///     name: "researcher",
///     instructions: "You research topics thoroughly.",
///     tools: [searchTool]
/// )
///
/// let writer = Agent(
///     name: "writer",
///     instructions: "Use the researcher for facts, then write clearly.",
///     tools: [researcher.asTool()]
/// )
///
/// let result = try await writer.run("Write about quantum computing")
/// ```
public struct AgentTool: AnyJSONTool, Sendable {
    // MARK: Public

    public let name: String
    public let description: String
    public let parameters: [ToolParameter]

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let input = arguments["input"]?.stringValue ?? ""
        guard !input.isEmpty else {
            throw AgentError.invalidToolArguments(
                toolName: name,
                reason: "Missing required 'input' argument"
            )
        }
        let result = try await agent.run(input, session: nil, hooks: nil)
        return .string(result.output)
    }

    // MARK: Private

    private let agent: any AgentRuntime
}

// MARK: - AgentTool Initializer

public extension AgentTool {
    /// Creates an agent tool wrapper.
    ///
    /// - Parameters:
    ///   - agent: The agent to wrap as a tool.
    ///   - name: Custom tool name. Defaults to the agent's configuration name.
    ///   - description: Custom description. Defaults to a generated description.
    init(
        agent: any AgentRuntime,
        name: String? = nil,
        description: String? = nil
    ) {
        self.agent = agent
        let agentName = agent.name
        self.name = name ?? (agentName.isEmpty ? "agent_tool" : agentName.camelCaseToSnakeCase())
        self.description = description ?? "Delegates to the \(agentName.isEmpty ? "agent" : agentName) agent for processing"
        parameters = [
            ToolParameter(
                name: "input",
                description: "The input/query to send to the agent",
                type: .string,
                isRequired: true
            )
        ]
    }
}

// MARK: - AgentRuntime Extension

public extension AgentRuntime {
    /// Wraps this agent as a callable tool for use by other agents.
    ///
    /// The returned tool has a single `input: String` parameter. When called,
    /// it runs this agent with the provided input and returns the output.
    ///
    /// - Parameters:
    ///   - name: Custom tool name. Default: derived from agent name.
    ///   - description: Custom tool description. Default: auto-generated.
    /// - Returns: An `AgentTool` wrapping this agent.
    ///
    /// Example:
    /// ```swift
    /// let researcher = Agent(name: "researcher", instructions: "Research topics")
    /// let tool = researcher.asTool(description: "Research a topic")
    /// ```
    func asTool(name: String? = nil, description: String? = nil) -> AgentTool {
        AgentTool(agent: self, name: name, description: description)
    }
}
