// PerformanceMetrics.swift
// Swarm Framework
//
// Performance tracking types for measuring parallel execution benefits.
// Provides metrics collection during execution and immutable snapshots for analysis.

import Foundation

// MARK: - PerformanceMetrics

/// Performance metrics snapshot for agent execution.
///
/// `PerformanceMetrics` captures timing information and parallel execution statistics
/// to measure performance improvements from concurrent tool execution.
///
/// This is an immutable snapshot created by ``PerformanceTracker/finish()``.
/// All properties are read-only and the type is `Sendable` for safe concurrent access.
///
/// ## Features
///
/// - Captures total, LLM, and tool execution durations
/// - Tracks parallel execution usage
/// - Calculates speedup ratio when parallel execution was used
/// - Immutable and thread-safe
///
/// ## Example
///
/// ```swift
/// let tracker = PerformanceTracker()
/// await tracker.start()
/// // ... execute agent operations ...
/// await tracker.recordLLMCall(duration: .milliseconds(500))
/// await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: true)
/// await tracker.recordToolExecution(duration: .milliseconds(150), wasParallel: true)
/// await tracker.recordSequentialEstimate(.milliseconds(250))
///
/// let metrics = await tracker.finish()
/// print("Total: \(metrics.totalDuration)")
/// print("LLM: \(metrics.llmDuration)")
/// print("Tools: \(metrics.toolDuration)")
///
/// if let speedup = metrics.parallelSpeedup {
///     print("Speedup: \(String(format: "%.2f", speedup))x faster with parallel execution")
/// }
/// ```
public struct PerformanceMetrics: Sendable, Equatable {
    /// Total execution time from start to finish.
    ///
    /// This captures the wall-clock time for the entire operation,
    /// including LLM calls, tool executions, and any overhead.
    public let totalDuration: Duration

    /// Time spent in LLM inference calls.
    ///
    /// Accumulated duration of all LLM API calls during execution.
    /// This helps identify whether performance is bound by inference time.
    public let llmDuration: Duration

    /// Time spent in tool executions.
    ///
    /// For parallel execution, this is the wall-clock time of the longest
    /// parallel batch, not the sum of individual tool durations.
    public let toolDuration: Duration

    /// Number of tools executed.
    ///
    /// Total count of individual tool executions, regardless of whether
    /// they were executed sequentially or in parallel.
    public let toolCount: Int

    /// Whether parallel execution was used.
    ///
    /// Set to `true` if any tool batch was executed in parallel.
    /// Use this to filter metrics when comparing parallel vs sequential.
    public let usedParallelExecution: Bool

    /// Estimated sequential duration for parallel tool batches.
    ///
    /// When parallel execution is used, this captures the estimated
    /// time if tools had been executed sequentially. Used to calculate
    /// the ``parallelSpeedup`` ratio.
    ///
    /// This value is `nil` when parallel execution was not used.
    public let estimatedSequentialDuration: Duration?

    /// Parallel execution speedup factor.
    ///
    /// Returns the ratio of estimated sequential time to actual parallel time.
    /// A value of `3.0` means parallel execution was 3x faster than sequential
    /// would have been.
    ///
    /// Returns `nil` if:
    /// - Parallel execution wasn't used
    /// - Estimated sequential duration is not available
    /// - Tool duration is zero
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let speedup = metrics.parallelSpeedup {
    ///     if speedup > 1.0 {
    ///         print("Parallel execution was \(speedup)x faster")
    ///     } else {
    ///         print("Parallel execution provided no speedup")
    ///     }
    /// }
    /// ```
    public var parallelSpeedup: Double? {
        guard let sequential = estimatedSequentialDuration,
              usedParallelExecution,
              toolDuration > .zero else {
            return nil
        }

        // Convert durations to seconds for division
        let sequentialSeconds = Double(sequential.components.seconds) +
            Double(sequential.components.attoseconds) / 1e18
        let parallelSeconds = Double(toolDuration.components.seconds) +
            Double(toolDuration.components.attoseconds) / 1e18

        guard parallelSeconds > 0 else { return nil }
        return sequentialSeconds / parallelSeconds
    }

    // MARK: - Initialization

    /// Creates a new performance metrics snapshot.
    ///
    /// - Parameters:
    ///   - totalDuration: Total execution time from start to finish.
    ///   - llmDuration: Time spent in LLM inference calls.
    ///   - toolDuration: Time spent in tool executions.
    ///   - toolCount: Number of tools executed.
    ///   - usedParallelExecution: Whether parallel execution was used.
    ///   - estimatedSequentialDuration: Estimated sequential duration for parallel batches.
    public init(
        totalDuration: Duration,
        llmDuration: Duration,
        toolDuration: Duration,
        toolCount: Int,
        usedParallelExecution: Bool,
        estimatedSequentialDuration: Duration? = nil
    ) {
        self.totalDuration = totalDuration
        self.llmDuration = llmDuration
        self.toolDuration = toolDuration
        self.toolCount = toolCount
        self.usedParallelExecution = usedParallelExecution
        self.estimatedSequentialDuration = estimatedSequentialDuration
    }
}

// MARK: - PerformanceTracker

/// Tracks performance metrics during agent execution.
///
/// `PerformanceTracker` is an actor that collects timing information during
/// agent execution. Call ``start()`` at the beginning, record events during
/// execution, and call ``finish()`` to create an immutable ``PerformanceMetrics``
/// snapshot.
///
/// ## Thread Safety
///
/// As an actor, `PerformanceTracker` provides thread-safe metric collection.
/// All methods are isolated to the actor and can be called from any context.
///
/// ## Usage Pattern
///
/// ```swift
/// let tracker = PerformanceTracker()
///
/// // Start tracking
/// await tracker.start()
///
/// // Record LLM call
/// let llmStart = ContinuousClock.now
/// let response = try await llm.generate(prompt)
/// await tracker.recordLLMCall(duration: ContinuousClock.now - llmStart)
///
/// // Record parallel tool execution
/// let toolStart = ContinuousClock.now
/// let results = try await executor.executeInParallel(tools)
/// let parallelDuration = ContinuousClock.now - toolStart
/// let sequentialEstimate = results.reduce(.zero) { $0 + $1.duration }
///
/// await tracker.recordToolExecution(duration: parallelDuration, wasParallel: true)
/// await tracker.recordSequentialEstimate(sequentialEstimate)
///
/// // Get final metrics
/// let metrics = await tracker.finish()
/// ```
///
/// ## Reuse
///
/// Call ``reset()`` to reuse the tracker for a new execution:
///
/// ```swift
/// await tracker.reset()
/// await tracker.start()
/// // ... track new execution ...
/// ```
public actor PerformanceTracker {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new performance tracker.
    ///
    /// The tracker starts in an idle state. Call ``start()`` to begin tracking.
    public init() {}

    // MARK: - Tracking Methods

    /// Marks the start of execution.
    ///
    /// Call this method at the beginning of the operation you want to track.
    /// The start time is used to calculate ``PerformanceMetrics/totalDuration``.
    ///
    /// If called multiple times, the most recent call sets the start time.
    ///
    /// ```swift
    /// await tracker.start()
    /// // ... perform operations ...
    /// let metrics = await tracker.finish()
    /// ```
    public func start() {
        startTime = ContinuousClock.now
    }

    /// Records an LLM call duration.
    ///
    /// Call this method after each LLM inference call to accumulate LLM time.
    /// Multiple calls are summed to produce ``PerformanceMetrics/llmDuration``.
    ///
    /// - Parameter duration: The duration of the LLM call.
    ///
    /// ```swift
    /// let start = ContinuousClock.now
    /// let response = try await llm.generate(prompt)
    /// await tracker.recordLLMCall(duration: ContinuousClock.now - start)
    /// ```
    public func recordLLMCall(duration: Duration) {
        llmTime += duration
    }

    /// Records a tool execution.
    ///
    /// Call this method after each tool execution or batch of parallel executions.
    /// For parallel batches, pass the wall-clock duration, `wasParallel: true`, and
    /// the actual count of tools executed.
    ///
    /// - Parameters:
    ///   - duration: The duration of the tool execution.
    ///   - wasParallel: Whether this was a parallel execution batch.
    ///   - count: Number of tools executed. Default: 1. For parallel batches,
    ///     pass the actual number of tools in the batch.
    ///
    /// ```swift
    /// // Single tool
    /// await tracker.recordToolExecution(duration: toolDuration, wasParallel: false)
    ///
    /// // Parallel batch of 5 tools
    /// await tracker.recordToolExecution(duration: parallelBatchDuration, wasParallel: true, count: 5)
    /// ```
    public func recordToolExecution(duration: Duration, wasParallel: Bool, count: Int = 1) {
        toolTime += duration
        toolCount += count
        usedParallel = usedParallel || wasParallel
    }

    /// Records the estimated sequential duration.
    ///
    /// When executing tools in parallel, call this method with the sum of
    /// individual tool durations. This enables ``PerformanceMetrics/parallelSpeedup``
    /// calculation.
    ///
    /// - Parameter duration: The estimated sequential duration.
    ///
    /// ```swift
    /// // Sum individual tool durations from parallel results
    /// let sequentialTime = results.reduce(.zero) { $0 + $1.duration }
    /// await tracker.recordSequentialEstimate(sequentialTime)
    /// ```
    public func recordSequentialEstimate(_ duration: Duration) {
        sequentialEstimate = duration
    }

    /// Creates the final metrics snapshot.
    ///
    /// Call this method when the tracked operation completes. Returns an
    /// immutable ``PerformanceMetrics`` snapshot with all collected data.
    ///
    /// The tracker can be reused after calling ``reset()``.
    ///
    /// - Returns: An immutable metrics snapshot.
    ///
    /// ```swift
    /// let metrics = await tracker.finish()
    /// print("Total: \(metrics.totalDuration)")
    /// print("Tools: \(metrics.toolCount)")
    /// ```
    public func finish() -> PerformanceMetrics {
        let total: Duration = if let start = startTime {
            ContinuousClock.now - start
        } else {
            .zero
        }

        return PerformanceMetrics(
            totalDuration: total,
            llmDuration: llmTime,
            toolDuration: toolTime,
            toolCount: toolCount,
            usedParallelExecution: usedParallel,
            estimatedSequentialDuration: usedParallel ? sequentialEstimate : nil
        )
    }

    /// Resets the tracker for reuse.
    ///
    /// Clears all tracked data and returns the tracker to its initial state.
    /// Call ``start()`` to begin tracking a new operation.
    ///
    /// ```swift
    /// await tracker.reset()
    /// await tracker.start()
    /// // ... track new execution ...
    /// ```
    public func reset() {
        startTime = nil
        llmTime = .zero
        toolTime = .zero
        toolCount = 0
        usedParallel = false
        sequentialEstimate = .zero
    }

    // MARK: Private

    // MARK: - Private State

    /// Start time for total duration calculation.
    private var startTime: ContinuousClock.Instant?

    /// Accumulated LLM call duration.
    private var llmTime: Duration = .zero

    /// Accumulated tool execution duration.
    private var toolTime: Duration = .zero

    /// Count of tool executions.
    private var toolCount: Int = 0

    /// Flag indicating parallel execution was used.
    private var usedParallel: Bool = false

    /// Estimated sequential duration for parallel batches.
    private var sequentialEstimate: Duration = .zero
}

// MARK: - PerformanceMetrics + CustomStringConvertible

extension PerformanceMetrics: CustomStringConvertible {
    public var description: String {
        var lines = [
            "PerformanceMetrics(",
            "  totalDuration: \(totalDuration)",
            "  llmDuration: \(llmDuration)",
            "  toolDuration: \(toolDuration)",
            "  toolCount: \(toolCount)",
            "  usedParallelExecution: \(usedParallelExecution)",
        ]

        if let sequential = estimatedSequentialDuration {
            lines.append("  estimatedSequentialDuration: \(sequential)")
        }

        if let speedup = parallelSpeedup {
            lines.append("  parallelSpeedup: \(String(format: "%.2f", speedup))x")
        }

        lines.append(")")

        return lines.joined(separator: "\n")
    }
}

// MARK: - PerformanceMetrics + CustomDebugStringConvertible

extension PerformanceMetrics: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        PerformanceMetrics {
            totalDuration: \(totalDuration)
            llmDuration: \(llmDuration)
            toolDuration: \(toolDuration)
            toolCount: \(toolCount)
            usedParallelExecution: \(usedParallelExecution)
            estimatedSequentialDuration: \(estimatedSequentialDuration.map { "\($0)" } ?? "nil")
            parallelSpeedup: \(parallelSpeedup.map { String(format: "%.4f", $0) } ?? "nil")
        }
        """
    }
}
