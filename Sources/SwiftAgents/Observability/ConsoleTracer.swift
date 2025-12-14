// ConsoleTracer.swift
// SwiftAgents Framework
//
// Console-based tracer implementations with formatted output and ANSI color support.
// Provides both standard and pretty (emoji-enhanced) console tracers.

import Foundation
import os

// MARK: - Console Tracer

/// A console tracer that outputs formatted trace events to the terminal.
///
/// `ConsoleTracer` provides customizable console output with support for:
/// - ANSI color coding based on event level
/// - Configurable timestamp display
/// - Source location information
/// - Minimum log level filtering
/// - Optional colorization (can be disabled for non-terminal outputs)
///
/// ## Features
///
/// - **Color Coding**: Events are colored based on severity (trace=gray, debug=cyan, info=green, warning=yellow, error=red, critical=magenta)
/// - **Filtering**: Only events at or above `minimumLevel` are displayed
/// - **Timestamps**: Optional ISO8601 timestamps with configurable formatting
/// - **Source Location**: Shows file:line information when enabled
/// - **Thread-Safe**: Actor-isolated for safe concurrent access
///
/// ## Example
///
/// ```swift
/// let tracer = ConsoleTracer(
///     minimumLevel: .info,
///     colorized: true,
///     includeTimestamp: true,
///     includeSource: false
/// )
///
/// await tracer.trace(.agentStart(
///     traceId: traceId,
///     agentName: "MyAgent"
/// ))
/// // Output: [2024-12-12T10:30:45Z] [INFO] agentStart agent=MyAgent Agent started
/// ```
public actor ConsoleTracer: AgentTracer {
    /// The minimum event level to display. Events below this level are filtered out.
    private let minimumLevel: EventLevel

    /// Whether to colorize output using ANSI escape codes.
    private let colorized: Bool

    /// Whether to include timestamps in output.
    private let includeTimestamp: Bool

    /// Whether to include source location (file:line) in output.
    private let includeSource: Bool

    /// The date formatter used for timestamps.
    private let dateFormatter: ISO8601DateFormatter

    /// Creates a console tracer with the specified configuration.
    ///
    /// - Parameters:
    ///   - minimumLevel: Minimum event level to display. Default: `.trace` (all events).
    ///   - colorized: Whether to use ANSI color codes. Default: `true`.
    ///   - includeTimestamp: Whether to include timestamps. Default: `true`.
    ///   - includeSource: Whether to include source location. Default: `false`.
    public init(
        minimumLevel: EventLevel = .trace,
        colorized: Bool = true,
        includeTimestamp: Bool = true,
        includeSource: Bool = false
    ) {
        self.minimumLevel = minimumLevel
        self.colorized = colorized
        self.includeTimestamp = includeTimestamp
        self.includeSource = includeSource

        // Configure ISO8601 date formatter
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func trace(_ event: TraceEvent) async {
        // Filter events below minimum level
        guard event.level >= minimumLevel else { return }

        // Build the formatted output
        var parts: [String] = []

        // Add timestamp if enabled
        if includeTimestamp {
            let timestamp = dateFormatter.string(from: event.timestamp)
            parts.append("[\(timestamp)]")
        }

        // Add level with color
        let levelIndicator = formatLevel(event.level)
        parts.append(levelIndicator)

        // Add event kind indicator
        let kindIndicator = formatKind(event.kind)
        parts.append(kindIndicator)

        // Add agent name if present
        if let agentName = event.agentName {
            parts.append("agent=\(agentName)")
        }

        // Add tool name if present
        if let toolName = event.toolName {
            parts.append("tool=\(toolName)")
        }

        // Add message
        parts.append(event.message)

        // Add duration if present
        if let duration = event.duration {
            parts.append("(\(String(format: "%.2f", duration * 1000))ms)")
        }

        // Add source location if enabled and present
        if includeSource, let source = event.source {
            parts.append("[\(source.filename):\(source.line)]")
        }

        // Join parts and log
        let output = parts.joined(separator: " ")
        Logger.tracing.info("\(output)")

        // Print error details if present
        if let error = event.error {
            printError(error)
        }

        // Print metadata if not empty
        if !event.metadata.isEmpty {
            printMetadata(event.metadata)
        }
    }

    // MARK: - Formatting Helpers

    /// Formats the event level with color coding.
    private func formatLevel(_ level: EventLevel) -> String {
        let text = "[\(level.description)]"

        guard colorized else { return text }

        let colorCode: String
        switch level {
        case .trace:
            colorCode = "\u{001B}[37m" // gray
        case .debug:
            colorCode = "\u{001B}[36m" // cyan
        case .info:
            colorCode = "\u{001B}[32m" // green
        case .warning:
            colorCode = "\u{001B}[33m" // yellow
        case .error:
            colorCode = "\u{001B}[31m" // red
        case .critical:
            colorCode = "\u{001B}[35m" // magenta
        }

        let resetCode = "\u{001B}[0m"
        return "\(colorCode)\(text)\(resetCode)"
    }

    /// Formats the event kind with emoji indicators.
    private func formatKind(_ kind: EventKind) -> String {
        let emoji: String
        switch kind {
        case .agentStart:
            emoji = "▶️"
        case .agentComplete:
            emoji = "✅"
        case .agentError:
            emoji = "❌"
        case .agentCancelled:
            emoji = "⏹️"
        case .toolCall:
            emoji = "🔧"
        case .toolResult:
            emoji = "📦"
        case .toolError:
            emoji = "⚠️"
        case .thought:
            emoji = "💭"
        case .decision:
            emoji = "🎯"
        case .plan:
            emoji = "📋"
        case .memoryRead:
            emoji = "📖"
        case .memoryWrite:
            emoji = "💾"
        case .checkpoint:
            emoji = "🏁"
        case .metric:
            emoji = "📊"
        case .custom:
            emoji = "📌"
        }

        return "\(emoji) \(kind.rawValue)"
    }

    /// Prints error information with proper formatting.
    private func printError(_ error: ErrorInfo) {
        let prefix = colorized ? "\u{001B}[31m" : ""
        let reset = colorized ? "\u{001B}[0m" : ""

        Logger.tracing.error("\(prefix)  Error: \(error.type)\(reset)")
        Logger.tracing.error("\(prefix)  Message: \(error.message)\(reset)")

        if let underlyingError = error.underlyingError {
            Logger.tracing.error("\(prefix)  Underlying: \(underlyingError)\(reset)")
        }

        if let stackTrace = error.stackTrace {
            Logger.tracing.error("\(prefix)  Stack Trace:\(reset)")
            for frame in stackTrace {
                Logger.tracing.error("\(prefix)    \(frame)\(reset)")
            }
        }
    }

    /// Prints metadata with proper formatting.
    private func printMetadata(_ metadata: [String: SendableValue]) {
        let prefix = colorized ? "\u{001B}[37m" : ""
        let reset = colorized ? "\u{001B}[0m" : ""

        Logger.tracing.debug("\(prefix)  Metadata:\(reset)")
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            Logger.tracing.debug("\(prefix)    \(key): \(value)\(reset)")
        }
    }
}

// MARK: - Pretty Console Tracer

/// An enhanced console tracer with emoji-rich output for better visual scanning.
///
/// `PrettyConsoleTracer` extends the standard `ConsoleTracer` with more visual,
/// emoji-based formatting. It's designed for interactive development and debugging
/// where visual scanning is important.
///
/// ## Features
///
/// - **Heavy Emoji Usage**: Every event kind has a distinctive emoji
/// - **Structured Output**: Metadata and errors are displayed on separate lines with indentation
/// - **Color Coding**: Same ANSI color support as `ConsoleTracer`
/// - **Visual Hierarchy**: Uses indentation and formatting to show relationships
///
/// ## Example Output
///
/// ```
/// [2024-12-12T10:30:45Z] ✨ [INFO] ▶️ Agent Started
///   📛 Agent: MyAgent
///   🆔 Trace: 123e4567-e89b-12d3-a456-426614174000
///
/// [2024-12-12T10:30:46Z] 🔍 [DEBUG] 🔧 Tool Call
///   🔨 Tool: web_search
///   📝 Query: "SwiftAgents framework"
///
/// [2024-12-12T10:30:47Z] ⚡ [INFO] 📦 Tool Result
///   ⏱️  Duration: 1250.45ms
///   📊 Metadata:
///     results_count: 42
///     search_time: 1.2
/// ```
public actor PrettyConsoleTracer: AgentTracer {
    /// The minimum event level to display. Events below this level are filtered out.
    private let minimumLevel: EventLevel

    /// Whether to colorize output using ANSI escape codes.
    private let colorized: Bool

    /// Whether to include timestamps in output.
    private let includeTimestamp: Bool

    /// Whether to include source location (file:line) in output.
    private let includeSource: Bool

    /// The date formatter used for timestamps.
    private let dateFormatter: ISO8601DateFormatter

    /// Creates a pretty console tracer with the specified configuration.
    ///
    /// - Parameters:
    ///   - minimumLevel: Minimum event level to display. Default: `.trace` (all events).
    ///   - colorized: Whether to use ANSI color codes. Default: `true`.
    ///   - includeTimestamp: Whether to include timestamps. Default: `true`.
    ///   - includeSource: Whether to include source location. Default: `false`.
    public init(
        minimumLevel: EventLevel = .trace,
        colorized: Bool = true,
        includeTimestamp: Bool = true,
        includeSource: Bool = false
    ) {
        self.minimumLevel = minimumLevel
        self.colorized = colorized
        self.includeTimestamp = includeTimestamp
        self.includeSource = includeSource

        // Configure ISO8601 date formatter
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func trace(_ event: TraceEvent) async {
        // Filter events below minimum level
        guard event.level >= minimumLevel else { return }

        // Print header line
        printHeader(event)

        // Print details with indentation
        printDetails(event)

        // Print error information if present
        if let error = event.error {
            printError(error)
        }

        // Print metadata if not empty
        if !event.metadata.isEmpty {
            printMetadata(event.metadata)
        }

        // Add blank line for visual separation
        Logger.tracing.debug("")
    }

    // MARK: - Pretty Formatting

    /// Prints the event header line.
    private func printHeader(_ event: TraceEvent) {
        var parts: [String] = []

        // Add timestamp if enabled
        if includeTimestamp {
            let timestamp = dateFormatter.string(from: event.timestamp)
            parts.append("[\(timestamp)]")
        }

        // Add sparkle emoji for visual separation
        parts.append("✨")

        // Add level with color
        let levelIndicator = formatLevel(event.level)
        parts.append(levelIndicator)

        // Add event kind with large emoji
        let kindIndicator = formatKindLarge(event.kind)
        parts.append(kindIndicator)

        // Add message
        parts.append(event.message)

        Logger.tracing.info("\(parts.joined(separator: " "))")
    }

    /// Prints event details with indentation.
    private func printDetails(_ event: TraceEvent) {
        // Print agent name if present
        if let agentName = event.agentName {
            Logger.tracing.debug("  📛 Agent: \(agentName)")
        }

        // Print tool name if present
        if let toolName = event.toolName {
            Logger.tracing.debug("  🔨 Tool: \(toolName)")
        }

        // Print duration if present
        if let duration = event.duration {
            Logger.tracing.debug("  ⏱️  Duration: \(String(format: "%.2f", duration * 1000))ms")
        }

        // Print trace ID
        Logger.tracing.debug("  🆔 Trace: \(event.traceId)")

        // Print span ID
        Logger.tracing.debug("  📍 Span: \(event.spanId)")

        // Print parent span ID if present
        if let parentSpanId = event.parentSpanId {
            Logger.tracing.debug("  ⬆️  Parent: \(parentSpanId)")
        }

        // Print source location if enabled and present
        if includeSource, let source = event.source {
            Logger.tracing.debug("  📂 Source: \(source.filename):\(source.line) - \(source.function)")
        }
    }

    /// Formats the event level with color coding.
    private func formatLevel(_ level: EventLevel) -> String {
        let emoji: String
        switch level {
        case .trace:
            emoji = "🔍"
        case .debug:
            emoji = "🐛"
        case .info:
            emoji = "ℹ️"
        case .warning:
            emoji = "⚠️"
        case .error:
            emoji = "❗"
        case .critical:
            emoji = "🚨"
        }

        let text = "[\(level.description)]"

        guard colorized else { return "\(emoji) \(text)" }

        let colorCode: String
        switch level {
        case .trace:
            colorCode = "\u{001B}[37m" // gray
        case .debug:
            colorCode = "\u{001B}[36m" // cyan
        case .info:
            colorCode = "\u{001B}[32m" // green
        case .warning:
            colorCode = "\u{001B}[33m" // yellow
        case .error:
            colorCode = "\u{001B}[31m" // red
        case .critical:
            colorCode = "\u{001B}[35m" // magenta
        }

        let resetCode = "\u{001B}[0m"
        return "\(emoji) \(colorCode)\(text)\(resetCode)"
    }

    /// Formats the event kind with large emoji indicators.
    private func formatKindLarge(_ kind: EventKind) -> String {
        let emoji: String
        let text: String

        switch kind {
        case .agentStart:
            emoji = "▶️"
            text = "Agent Started"
        case .agentComplete:
            emoji = "✅"
            text = "Agent Completed"
        case .agentError:
            emoji = "❌"
            text = "Agent Error"
        case .agentCancelled:
            emoji = "⏹️"
            text = "Agent Cancelled"
        case .toolCall:
            emoji = "🔧"
            text = "Tool Call"
        case .toolResult:
            emoji = "📦"
            text = "Tool Result"
        case .toolError:
            emoji = "💥"
            text = "Tool Error"
        case .thought:
            emoji = "💭"
            text = "Thought"
        case .decision:
            emoji = "🎯"
            text = "Decision"
        case .plan:
            emoji = "📋"
            text = "Plan"
        case .memoryRead:
            emoji = "📖"
            text = "Memory Read"
        case .memoryWrite:
            emoji = "💾"
            text = "Memory Write"
        case .checkpoint:
            emoji = "🏁"
            text = "Checkpoint"
        case .metric:
            emoji = "📊"
            text = "Metric"
        case .custom:
            emoji = "📌"
            text = "Custom"
        }

        return "\(emoji) \(text)"
    }

    /// Prints error information with emoji formatting.
    private func printError(_ error: ErrorInfo) {
        let prefix = colorized ? "\u{001B}[31m" : ""
        let reset = colorized ? "\u{001B}[0m" : ""

        Logger.tracing.error("\(prefix)  ❌ Error Details:\(reset)")
        Logger.tracing.error("\(prefix)    🏷️  Type: \(error.type)\(reset)")
        Logger.tracing.error("\(prefix)    💬 Message: \(error.message)\(reset)")

        if let underlyingError = error.underlyingError {
            Logger.tracing.error("\(prefix)    ⚡ Underlying: \(underlyingError)\(reset)")
        }

        if let stackTrace = error.stackTrace {
            Logger.tracing.error("\(prefix)    📚 Stack Trace:\(reset)")
            for frame in stackTrace {
                Logger.tracing.error("\(prefix)      • \(frame)\(reset)")
            }
        }
    }

    /// Prints metadata with emoji formatting.
    private func printMetadata(_ metadata: [String: SendableValue]) {
        let prefix = colorized ? "\u{001B}[37m" : ""
        let reset = colorized ? "\u{001B}[0m" : ""

        Logger.tracing.debug("\(prefix)  📊 Metadata:\(reset)")
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            Logger.tracing.debug("\(prefix)    • \(key): \(value)\(reset)")
        }
    }
}
