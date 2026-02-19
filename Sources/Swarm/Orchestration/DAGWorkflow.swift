// DAGWorkflow.swift
// Swarm Framework
//
// Directed acyclic graph workflow primitive for orchestration.

import Foundation

// MARK: - DAGNode

/// A node in a DAG workflow with a name, step, and dependency list.
///
/// Each node wraps an ``OrchestrationStep`` and declares its dependencies
/// by name. Nodes without dependencies execute immediately; nodes with
/// dependencies wait until all named predecessors complete.
///
/// Example:
/// ```swift
/// DAGNode("summarize", agent: summaryAgent)
///     .dependsOn("fetch", "parse")
/// ```
public struct DAGNode: Sendable {
    /// The unique name identifying this node within the DAG.
    public let name: String

    /// The orchestration step this node executes.
    public let step: OrchestrationStep

    /// Names of other nodes that must complete before this node can execute.
    public var dependencies: [String]

    /// Creates a DAG node wrapping an agent.
    /// - Parameters:
    ///   - name: A unique name for this node.
    ///   - agent: The agent to execute.
    public init(_ name: String, agent: any AgentRuntime) {
        self.name = name
        self.step = AgentStep(agent, name: name)
        self.dependencies = []
    }

    /// Creates a DAG node wrapping any orchestration step.
    /// - Parameters:
    ///   - name: A unique name for this node.
    ///   - step: The orchestration step to execute.
    public init(_ name: String, step: OrchestrationStep) {
        self.name = name
        self.step = step
        self.dependencies = []
    }

    /// Declares dependencies on other named nodes.
    /// - Parameter names: The names of nodes that must complete before this one.
    /// - Returns: A copy of this node with the additional dependencies.
    public func dependsOn(_ names: String...) -> DAGNode {
        var copy = self
        copy.dependencies.append(contentsOf: names)
        return copy
    }
}

// MARK: - DAGBuilder

/// A result builder for constructing DAG node arrays declaratively.
@resultBuilder
public struct DAGBuilder {
    /// Builds an array of DAG nodes from multiple components.
    public static func buildBlock(_ components: [DAGNode]...) -> [DAGNode] {
        components.flatMap(\.self)
    }

    /// Wraps a single DAG node into an array.
    public static func buildExpression(_ node: DAGNode) -> [DAGNode] {
        [node]
    }

    /// Builds an array from an optional component.
    public static func buildOptional(_ component: [DAGNode]?) -> [DAGNode] {
        component ?? []
    }

    /// Builds an array from the first branch of a conditional.
    public static func buildEither(first component: [DAGNode]) -> [DAGNode] {
        component
    }

    /// Builds an array from the second branch of a conditional.
    public static func buildEither(second component: [DAGNode]) -> [DAGNode] {
        component
    }

    /// Builds an array from nested arrays (for-in loops).
    public static func buildArray(_ components: [[DAGNode]]) -> [DAGNode] {
        components.flatMap(\.self)
    }
}

// MARK: - DAG

/// A directed acyclic graph workflow that executes steps respecting dependency ordering.
///
/// `DAG` enables expressing complex workflows where steps have explicit dependency
/// relationships. Nodes without dependencies execute concurrently, and downstream
/// nodes begin as soon as all their dependencies complete.
///
/// Example:
/// ```swift
/// let workflow = DAG {
///     DAGNode("fetch", agent: fetchAgent)
///     DAGNode("parse", agent: parseAgent)
///         .dependsOn("fetch")
///     DAGNode("summarize", agent: summaryAgent)
///         .dependsOn("parse")
///     DAGNode("translate", agent: translateAgent)
///         .dependsOn("parse")
/// }
/// ```
///
/// In this example, `fetch` runs first, then `parse`, and finally `summarize` and
/// `translate` run concurrently since they both only depend on `parse`.
public struct DAG: OrchestrationStep, Sendable {
    /// The nodes comprising this DAG.
    public let nodes: [DAGNode]

    /// Creates a new DAG workflow from a builder closure.
    ///
    /// Validates the graph structure at construction time. A `preconditionFailure`
    /// is triggered if the graph contains cycles or references missing dependencies,
    /// since these represent programming errors.
    ///
    /// - Parameter content: A builder closure producing DAG nodes.
    public init(@DAGBuilder _ content: () -> [DAGNode]) {
        let builtNodes = content()
        DAG.validate(builtNodes)
        self.nodes = builtNodes
    }

    /// Internal initializer for testing with pre-validated nodes.
    init(validatedNodes: [DAGNode]) {
        self.nodes = validatedNodes
    }

    // MARK: - Validation

    /// Validates that the DAG has no missing dependencies and no cycles.
    private static func validate(_ nodes: [DAGNode]) {
        do {
            try validateNodes(nodes)
        } catch {
            preconditionFailure("Invalid DAG: \(error)")
        }
    }

    /// Validates DAG structure without triggering a precondition failure.
    static func validateNodes(_ nodes: [DAGNode]) throws {
        guard !nodes.isEmpty else {
            throw DAGValidationError.emptyNodes
        }

        for (index, node) in nodes.enumerated() {
            if node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DAGValidationError.emptyName(index: index)
            }
        }

        var nameCounts: [String: Int] = [:]
        for name in nodes.map(\.name) {
            nameCounts[name, default: 0] += 1
        }
        let duplicates = nameCounts.filter { $0.value > 1 }.map(\.key).sorted()
        if !duplicates.isEmpty {
            throw DAGValidationError.duplicateNames(duplicates)
        }

        let nodeNames = Set(nodes.map(\.name))

        // Check for missing dependencies
        for node in nodes {
            for dep in node.dependencies {
                if !nodeNames.contains(dep) {
                    throw DAGValidationError.missingDependency(
                        node: node.name,
                        dependency: dep,
                        available: Array(nodeNames).sorted()
                    )
                }
            }
        }

        // Detect cycles via topological sort
        let sorted = topologicalSort(nodes)
        if sorted.count != nodes.count {
            let sortedNames = Set(sorted.map(\.name))
            let cycleNodes = nodes.filter { !sortedNames.contains($0.name) }.map(\.name)
            throw DAGValidationError.cycle(cycleNodes.sorted())
        }
    }

    // MARK: - Topological Sort (Kahn's Algorithm)

    /// Performs a topological sort using Kahn's algorithm.
    ///
    /// Returns the sorted nodes. If the returned array's count is less than the
    /// input count, a cycle exists in the graph.
    private static func topologicalSort(_ nodes: [DAGNode]) -> [DAGNode] {
        let nameToNode = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        var inDegree: [String: Int] = [:]
        var adjacency: [String: [String]] = [:]

        for node in nodes {
            inDegree[node.name, default: 0] += 0
            for dep in node.dependencies {
                adjacency[dep, default: []].append(node.name)
                inDegree[node.name, default: 0] += 1
            }
        }

        var queue = nodes.filter { inDegree[$0.name, default: 0] == 0 }.map(\.name)
        var sorted: [DAGNode] = []

        while !queue.isEmpty {
            let name = queue.removeFirst()
            guard let node = nameToNode[name] else { continue }
            sorted.append(node)
            for downstream in adjacency[name, default: []] {
                inDegree[downstream, default: 0] -= 1
                if inDegree[downstream, default: 0] == 0 {
                    queue.append(downstream)
                }
            }
        }

        return sorted
    }

    // MARK: - Execution

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !nodes.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        let sorted = DAG.topologicalSort(nodes)
        let state = DAGExecutionState()

        // Build adjacency: node name -> downstream node names
        var downstreamMap: [String: [String]] = [:]
        for node in nodes {
            for dep in node.dependencies {
                downstreamMap[dep, default: []].append(node.name)
            }
        }

        let nameToNode = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })

        try await withThrowingTaskGroup(of: (String, AgentResult).self) { group in
            // Launch root nodes (no dependencies) immediately
            for node in nodes where node.dependencies.isEmpty {
                let nodeName = node.name
                let nodeStep = node.step
                group.addTask {
                    let nodeStart = ContinuousClock.now
                    let result = try await nodeStep.execute(input, context: context)
                    let nodeDuration = ContinuousClock.now - nodeStart
                    return (nodeName, DAG.enrichResult(result, nodeName: nodeName, duration: nodeDuration))
                }
            }

            // Process completed nodes and launch newly-ready downstream nodes
            while let (completedName, completedResult) = try await group.next() {
                await state.markCompleted(completedName, result: completedResult)

                // Check each downstream node of the completed node
                for downstreamName in downstreamMap[completedName, default: []] {
                    guard let downstreamNode = nameToNode[downstreamName] else { continue }
                    let ready = await state.allDependenciesMet(for: downstreamNode)
                    if ready {
                        let nodeStep = downstreamNode.step
                        group.addTask {
                            let nodeInput = await state.dependencyOutput(for: downstreamNode, fallback: input)
                            let nodeStart = ContinuousClock.now
                            let result = try await nodeStep.execute(nodeInput, context: context)
                            let nodeDuration = ContinuousClock.now - nodeStart
                            return (downstreamName, DAG.enrichResult(result, nodeName: downstreamName, duration: nodeDuration))
                        }
                    }
                }
            }
        }

        // Collect results in topological order
        let allResults = await state.allResults()
        let totalDuration = ContinuousClock.now - startTime

        // Accumulate outputs, tool calls, and metadata
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var allMetadata: [String: SendableValue] = [:]

        for node in sorted {
            guard let result = allResults[node.name] else { continue }
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount
            for (key, value) in result.metadata {
                allMetadata["dag.node.\(node.name).\(key)"] = value
            }
        }

        // DAG-level metadata
        allMetadata["dag.total_nodes"] = .int(nodes.count)
        allMetadata["dag.total_duration"] = .double(
            Double(totalDuration.components.seconds)
            + Double(totalDuration.components.attoseconds) / 1e18
        )

        // Calculate critical path duration (longest chain through the DAG)
        let criticalPathDuration = await computeCriticalPathDuration(sorted: sorted, state: state)
        allMetadata["dag.critical_path_duration"] = .double(criticalPathDuration)

        // Output is collected from terminal nodes (no downstream dependencies).
        let terminalNodes = sorted.filter { downstreamMap[$0.name, default: []].isEmpty }
        let terminalOutputs = terminalNodes.compactMap { allResults[$0.name]?.output }
        let finalOutput: String
        if terminalOutputs.isEmpty {
            finalOutput = input
        } else if terminalOutputs.count == 1 {
            finalOutput = terminalOutputs[0]
        } else {
            finalOutput = terminalOutputs.joined(separator: "\n")
        }

        return AgentResult(
            output: finalOutput,
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: totalDuration,
            tokenUsage: nil,
            metadata: allMetadata
        )
    }

    /// Creates an enriched result with per-node duration metadata.
    private static func enrichResult(
        _ result: AgentResult,
        nodeName: String,
        duration: Duration
    ) -> AgentResult {
        var enrichedMetadata = result.metadata
        enrichedMetadata["dag.node.\(nodeName).duration"] = .double(
            Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
        )
        return AgentResult(
            output: result.output,
            toolCalls: result.toolCalls,
            toolResults: result.toolResults,
            iterationCount: result.iterationCount,
            duration: duration,
            tokenUsage: result.tokenUsage,
            metadata: enrichedMetadata
        )
    }

    /// Computes the critical path duration through the DAG.
    ///
    /// The critical path is the longest chain of sequential dependencies,
    /// representing the minimum possible execution time even with unlimited parallelism.
    private func computeCriticalPathDuration(
        sorted: [DAGNode],
        state: DAGExecutionState
    ) async -> Double {
        let allResults = await state.allResults()
        var longestPath: [String: Double] = [:]

        for node in sorted {
            let nodeDuration: Double
            if let result = allResults[node.name] {
                let dur = result.duration
                nodeDuration = Double(dur.components.seconds) + Double(dur.components.attoseconds) / 1e18
            } else {
                nodeDuration = 0
            }

            let maxDepDuration = node.dependencies.map { longestPath[$0, default: 0] }.max() ?? 0
            longestPath[node.name] = maxDepDuration + nodeDuration
        }

        return longestPath.values.max() ?? 0
    }
}

// MARK: - DAGValidationError

enum DAGValidationError: Error, Equatable, CustomStringConvertible {
    case emptyNodes
    case emptyName(index: Int)
    case duplicateNames([String])
    case missingDependency(node: String, dependency: String, available: [String])
    case cycle([String])

    var description: String {
        switch self {
        case .emptyNodes:
            return "DAG must contain at least one node."
        case let .emptyName(index):
            return "DAG node at index \(index) has an empty name."
        case let .duplicateNames(names):
            return "DAG node names must be unique. Duplicates: \(names.joined(separator: ", "))"
        case let .missingDependency(node, dependency, available):
            return "DAG node '\(node)' depends on unknown node '\(dependency)'. Available nodes: \(available.joined(separator: ", "))"
        case let .cycle(nodes):
            return "Cycle detected in DAG involving nodes: \(nodes.joined(separator: ", "))"
        }
    }
}

// MARK: - DAGExecutionState

/// Actor managing thread-safe shared state during DAG execution.
private actor DAGExecutionState {
    /// Results keyed by node name.
    private var results: [String: AgentResult] = [:]

    /// Set of completed node names.
    private var completed: Set<String> = []

    /// Records a node as completed with its result.
    func markCompleted(_ name: String, result: AgentResult) {
        results[name] = result
        completed.insert(name)
    }

    /// Checks whether all dependencies of a node have completed.
    func allDependenciesMet(for node: DAGNode) -> Bool {
        node.dependencies.allSatisfy { completed.contains($0) }
    }

    /// Returns the concatenated output of a node's dependencies.
    func dependencyOutput(for node: DAGNode, fallback: String) -> String {
        let outputs = node.dependencies.compactMap { results[$0]?.output }
        return outputs.isEmpty ? fallback : outputs.joined(separator: "\n")
    }

    /// Returns a snapshot of all results.
    func allResults() -> [String: AgentResult] {
        results
    }
}

// MARK: - DAG + _AgentLoopNestedSteps

extension DAG: _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] {
        nodes.map(\.step)
    }
}
