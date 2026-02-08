// Swarm.swift
// Swarm Framework
//
// LangChain for Apple Platforms - A comprehensive Swift framework
// for building AI agents with Apple's Foundation Models.

/// Swarm Framework
///
/// Provides agent orchestration, memory systems, tool integration,
/// and multi-agent coordination for Apple platforms.
///
/// ## Overview
///
/// Swarm is the agent layer that sits on top of inference providers
/// like Foundation Models or SwiftAI SDK, enabling autonomous reasoning
/// and complex task execution.
///
/// ## Quick Start
///
/// ```swift
/// import Swarm
///
/// // Create an agent with tools and an inference provider
/// let agent = ReActAgent(
///     tools: [CalculatorTool(), DateTimeTool()],
///     instructions: "You are a helpful assistant that can perform calculations.",
///     inferenceProvider: myProvider
/// )
///
/// // Run the agent
/// let result = try await agent.run("What is 25 * 4?")
/// print(result.output)
///
/// // Or use the fluent builder API
/// let agent2 = ReActAgent.Builder()
///     .tools([CalculatorTool()])
///     .instructions("You are a math assistant.")
///     .inferenceProvider(myProvider)
///     .build()
/// ```
///
/// ## Supported Platforms
///
/// - macOS 15.0+
/// - iOS 17.0+
/// - watchOS 10.0+
/// - tvOS 17.0+
/// - visionOS 1.0+
///
public enum Swarm {
    /// The current version of the Swarm framework.
    public static let version = "0.1.0"

    /// The minimum macOS platform version required by Swarm.
    public static let minimumMacOSVersion = "15.0"

    /// The minimum iOS platform version required by Swarm.
    public static let minimumiOSVersion = "17.0"
}
