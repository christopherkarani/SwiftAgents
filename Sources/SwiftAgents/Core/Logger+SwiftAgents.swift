// Logger+SwiftAgents.swift
// SwiftAgents Framework
//
// Structured logging extensions using Apple's os.Logger framework.

import Foundation
import os

/// Structured logging for SwiftAgents framework components.
///
/// Provides category-specific loggers for different framework subsystems,
/// enabling structured logging with appropriate categorization and filtering.
///
/// ## Usage
///
/// ```swift
/// Logger.agents.info("Starting agent execution")
/// Logger.memory.debug("Retrieved \(count) messages from memory")
/// Logger.tracing.trace("Span started: \(spanName)")
/// ```
///
/// ## Categories
///
/// - `agents`: Agent lifecycle and execution logging
/// - `memory`: Memory system operations
/// - `tracing`: Observability and tracing events
/// - `metrics`: Performance and usage metrics
/// - `orchestration`: Multi-agent coordination
///
/// ## Log Levels
///
/// Use appropriate levels for different scenarios:
/// - `.trace`: Fine-grained debug information
/// - `.debug`: Diagnostic information for development
/// - `.info`: General informational messages
/// - `.notice`: Significant events that are not errors
/// - `.warning`: Warning conditions
/// - `.error`: Error conditions
/// - `.fault`: Critical failures
extension Logger {
    /// Subsystem identifier for all SwiftAgents loggers.
    private static let subsystem = "com.swiftagents"

    /// Logger for agent-related operations.
    ///
    /// Use for:
    /// - Agent initialization and configuration
    /// - Agent execution lifecycle
    /// - Tool invocations
    /// - Agent state transitions
    ///
    /// ```swift
    /// Logger.agents.info("Agent initialized: \(agentType)")
    /// Logger.agents.debug("Executing step \(step) of \(totalSteps)")
    /// ```
    public static let agents = Logger(subsystem: subsystem, category: "agents")

    /// Logger for memory system operations.
    ///
    /// Use for:
    /// - Memory storage and retrieval
    /// - Context window management
    /// - Memory pruning and optimization
    /// - Vector operations
    ///
    /// ```swift
    /// Logger.memory.debug("Stored message: \(messageId)")
    /// Logger.memory.warning("Memory approaching capacity: \(usage)%")
    /// ```
    public static let memory = Logger(subsystem: subsystem, category: "memory")

    /// Logger for observability and tracing events.
    ///
    /// Use for:
    /// - Span creation and completion
    /// - Distributed tracing
    /// - Performance tracking
    /// - Execution flow visualization
    ///
    /// ```swift
    /// Logger.tracing.trace("Span started: \(spanName, privacy: .public)")
    /// Logger.tracing.info("Span completed: duration=\(duration)ms")
    /// ```
    public static let tracing = Logger(subsystem: subsystem, category: "tracing")

    /// Logger for metrics and performance data.
    ///
    /// Use for:
    /// - Token usage tracking
    /// - Latency measurements
    /// - Resource utilization
    /// - Performance benchmarks
    ///
    /// ```swift
    /// Logger.metrics.info("Tokens used: \(tokens)")
    /// Logger.metrics.debug("Request latency: \(latency)ms")
    /// ```
    public static let metrics = Logger(subsystem: subsystem, category: "metrics")

    /// Logger for multi-agent orchestration.
    ///
    /// Use for:
    /// - Agent coordination
    /// - Message passing between agents
    /// - Orchestration state transitions
    /// - Delegation and handoffs
    ///
    /// ```swift
    /// Logger.orchestration.info("Delegating task to agent: \(agentId)")
    /// Logger.orchestration.debug("Coordination complete: \(agentsCount) agents")
    /// ```
    public static let orchestration = Logger(subsystem: subsystem, category: "orchestration")
}
