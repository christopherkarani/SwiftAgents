// Logger+SwiftAgents.swift
// SwiftAgents Framework
//
// Cross-platform structured logging using swift-log.

import Foundation
import Logging

/// Structured logging for SwiftAgents framework components.
///
/// Provides category-specific loggers for different framework subsystems.
/// Uses swift-log for cross-platform compatibility (Apple + Linux).
///
/// ## Usage
///
/// ```swift
/// Log.agents.info("Starting agent execution")
/// Log.memory.debug("Retrieved \(count) messages from memory")
/// Log.tracing.trace("Span started: \(spanName)")
/// ```
///
/// ## Bootstrap
///
/// Call `Log.bootstrap()` once at application startup to configure logging:
///
/// ```swift
/// // Default console logging
/// Log.bootstrap()
///
/// // Or with custom handler
/// Log.bootstrap { label in
///     MyCustomLogHandler(label: label)
/// }
/// ```
public enum Log {
    /// Logger for agent-related operations.
    ///
    /// Use for:
    /// - Agent initialization and configuration
    /// - Agent execution lifecycle
    /// - Tool invocations
    /// - Agent state transitions
    public static let agents = Logger(label: "com.swiftagents.agents")

    /// Logger for memory system operations.
    ///
    /// Use for:
    /// - Memory storage and retrieval
    /// - Context window management
    /// - Memory pruning and optimization
    /// - Vector operations
    public static let memory = Logger(label: "com.swiftagents.memory")

    /// Logger for observability and tracing events.
    ///
    /// Use for:
    /// - Span creation and completion
    /// - Distributed tracing
    /// - Performance tracking
    /// - Execution flow visualization
    public static let tracing = Logger(label: "com.swiftagents.tracing")

    /// Logger for metrics and performance data.
    ///
    /// Use for:
    /// - Token usage tracking
    /// - Latency measurements
    /// - Resource utilization
    /// - Performance benchmarks
    public static let metrics = Logger(label: "com.swiftagents.metrics")

    /// Logger for multi-agent orchestration.
    ///
    /// Use for:
    /// - Agent coordination
    /// - Message passing between agents
    /// - Orchestration state transitions
    /// - Delegation and handoffs
    public static let orchestration = Logger(label: "com.swiftagents.orchestration")

    /// Bootstrap the logging system with default console output.
    ///
    /// Call once at application startup before using any loggers.
    ///
    /// ```swift
    /// Log.bootstrap()
    /// ```
    public static func bootstrap() {
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
    }

    /// Bootstrap the logging system with a custom log handler factory.
    ///
    /// Call once at application startup before using any loggers.
    ///
    /// ```swift
    /// Log.bootstrap { label in
    ///     var handler = StreamLogHandler.standardError(label: label)
    ///     handler.logLevel = .debug
    ///     return handler
    /// }
    /// ```
    ///
    /// - Parameter factory: A closure that creates a LogHandler for the given label.
    public static func bootstrap(_ factory: @escaping @Sendable (String) -> LogHandler) {
        LoggingSystem.bootstrap(factory)
    }

}
