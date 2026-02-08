// PerformanceMetricsTests.swift
// SwarmTests
//
// Tests for performance metrics collection.

import Foundation
@testable import Swarm
import Testing

// MARK: - PerformanceMetricsTests

@Suite("PerformanceMetrics Tests")
struct PerformanceMetricsTests {
    // MARK: - Basic Initialization

    @Test("PerformanceMetrics initializes with provided values")
    func initialization() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        #expect(metrics.totalDuration == .seconds(10))
        #expect(metrics.llmDuration == .seconds(5))
        #expect(metrics.toolDuration == .seconds(3))
        #expect(metrics.toolCount == 5)
        #expect(metrics.usedParallelExecution == true)
        #expect(metrics.estimatedSequentialDuration == .seconds(9))
    }

    @Test("PerformanceMetrics without parallel execution has nil sequential estimate")
    func noParallelExecution() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: false
        )

        #expect(metrics.estimatedSequentialDuration == nil)
    }

    // MARK: - Parallel Speedup Calculation

    @Test("parallelSpeedup calculates correct ratio")
    func parallelSpeedupCalculation() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        // Speedup = 9 / 3 = 3.0
        let speedup = metrics.parallelSpeedup
        #expect(speedup != nil)
        #expect(abs(speedup! - 3.0) < 0.01)
    }

    @Test("parallelSpeedup returns nil when parallel not used")
    func parallelSpeedupNilWhenNotParallel() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: false,
            estimatedSequentialDuration: .seconds(9)
        )

        #expect(metrics.parallelSpeedup == nil)
    }

    @Test("parallelSpeedup returns nil when no sequential estimate")
    func parallelSpeedupNilWhenNoEstimate() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: nil
        )

        #expect(metrics.parallelSpeedup == nil)
    }

    @Test("parallelSpeedup returns nil when tool duration is zero")
    func parallelSpeedupNilWhenZeroToolDuration() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .zero,
            toolCount: 0,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        #expect(metrics.parallelSpeedup == nil)
    }

    @Test("parallelSpeedup handles millisecond precision")
    func parallelSpeedupMillisecondPrecision() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(1),
            llmDuration: .milliseconds(500),
            toolDuration: .milliseconds(100),
            toolCount: 3,
            usedParallelExecution: true,
            estimatedSequentialDuration: .milliseconds(300)
        )

        // Speedup = 300ms / 100ms = 3.0
        let speedup = metrics.parallelSpeedup
        #expect(speedup != nil)
        #expect(abs(speedup! - 3.0) < 0.01)
    }

    // MARK: - Equatable

    @Test("PerformanceMetrics equality")
    func equatable() {
        let metrics1 = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        let metrics2 = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        #expect(metrics1 == metrics2)
    }

    @Test("PerformanceMetrics inequality")
    func notEquatable() {
        let metrics1 = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        let metrics2 = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 6, // Different
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        #expect(metrics1 != metrics2)
    }

    // MARK: - Description

    @Test("PerformanceMetrics description includes all fields")
    func description() {
        let metrics = PerformanceMetrics(
            totalDuration: .seconds(10),
            llmDuration: .seconds(5),
            toolDuration: .seconds(3),
            toolCount: 5,
            usedParallelExecution: true,
            estimatedSequentialDuration: .seconds(9)
        )

        let description = metrics.description
        #expect(description.contains("totalDuration"))
        #expect(description.contains("llmDuration"))
        #expect(description.contains("toolDuration"))
        #expect(description.contains("toolCount: 5"))
        #expect(description.contains("usedParallelExecution: true"))
        #expect(description.contains("parallelSpeedup"))
    }
}

// MARK: - PerformanceTrackerTests

@Suite("PerformanceTracker Tests")
struct PerformanceTrackerTests {
    // MARK: - Basic Lifecycle

    @Test("PerformanceTracker records LLM calls")
    func recordLLMCall() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordLLMCall(duration: .milliseconds(100))
        await tracker.recordLLMCall(duration: .milliseconds(200))

        let metrics = await tracker.finish()
        #expect(metrics.llmDuration == .milliseconds(300))
    }

    @Test("PerformanceTracker records single tool execution")
    func recordSingleToolExecution() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordToolExecution(duration: .milliseconds(50), wasParallel: false)

        let metrics = await tracker.finish()
        #expect(metrics.toolDuration == .milliseconds(50))
        #expect(metrics.toolCount == 1)
        #expect(metrics.usedParallelExecution == false)
    }

    @Test("PerformanceTracker records parallel tool execution with count")
    func recordParallelToolExecutionWithCount() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        // Parallel batch of 5 tools taking 100ms wall-clock
        await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: true, count: 5)

        let metrics = await tracker.finish()
        #expect(metrics.toolDuration == .milliseconds(100))
        #expect(metrics.toolCount == 5)
        #expect(metrics.usedParallelExecution == true)
    }

    @Test("PerformanceTracker accumulates tool count correctly")
    func accumulatesToolCount() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordToolExecution(duration: .milliseconds(50), wasParallel: false, count: 1)
        await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: true, count: 3)
        await tracker.recordToolExecution(duration: .milliseconds(25), wasParallel: false, count: 1)

        let metrics = await tracker.finish()
        #expect(metrics.toolCount == 5) // 1 + 3 + 1
        #expect(metrics.usedParallelExecution == true)
    }

    @Test("PerformanceTracker records sequential estimate")
    func recordSequentialEstimate() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: true, count: 3)
        await tracker.recordSequentialEstimate(.milliseconds(300))

        let metrics = await tracker.finish()
        #expect(metrics.estimatedSequentialDuration == .milliseconds(300))
    }

    @Test("PerformanceTracker sequential estimate only set when parallel used")
    func sequentialEstimateOnlyWhenParallel() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: false)
        await tracker.recordSequentialEstimate(.milliseconds(100)) // Should be ignored

        let metrics = await tracker.finish()
        #expect(metrics.estimatedSequentialDuration == nil)
    }

    // MARK: - Total Duration

    @Test("PerformanceTracker calculates total duration")
    func totalDuration() async {
        let tracker = PerformanceTracker()

        await tracker.start()

        // Simulate some work
        try? await Task.sleep(for: .milliseconds(50))

        let metrics = await tracker.finish()
        #expect(metrics.totalDuration >= .milliseconds(50))
    }

    @Test("PerformanceTracker returns zero total when not started")
    func zeroWhenNotStarted() async {
        let tracker = PerformanceTracker()

        // Never called start()
        let metrics = await tracker.finish()
        #expect(metrics.totalDuration == .zero)
    }

    // MARK: - Reset

    @Test("PerformanceTracker reset clears all state")
    func reset() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordLLMCall(duration: .milliseconds(100))
        await tracker.recordToolExecution(duration: .milliseconds(50), wasParallel: true, count: 3)
        await tracker.recordSequentialEstimate(.milliseconds(150))

        await tracker.reset()
        await tracker.start()

        let metrics = await tracker.finish()
        #expect(metrics.llmDuration == .zero)
        #expect(metrics.toolDuration == .zero)
        #expect(metrics.toolCount == 0)
        #expect(metrics.usedParallelExecution == false)
        #expect(metrics.estimatedSequentialDuration == nil)
    }

    @Test("PerformanceTracker can be reused after reset")
    func reuseAfterReset() async {
        let tracker = PerformanceTracker()

        // First run
        await tracker.start()
        await tracker.recordLLMCall(duration: .milliseconds(100))
        _ = await tracker.finish()

        // Reset and second run
        await tracker.reset()
        await tracker.start()
        await tracker.recordLLMCall(duration: .milliseconds(200))

        let metrics = await tracker.finish()
        #expect(metrics.llmDuration == .milliseconds(200))
    }

    // MARK: - Parallel Flag

    @Test("PerformanceTracker usedParallel stays true once set")
    func usedParallelStaysTrue() async {
        let tracker = PerformanceTracker()

        await tracker.start()
        await tracker.recordToolExecution(duration: .milliseconds(50), wasParallel: false)
        await tracker.recordToolExecution(duration: .milliseconds(100), wasParallel: true, count: 2)
        await tracker.recordToolExecution(duration: .milliseconds(25), wasParallel: false)

        let metrics = await tracker.finish()
        #expect(metrics.usedParallelExecution == true)
    }
}
