// OrchestrationHiveEngine+DAG.swift
// Swarm Framework
//
// DAG step compilation into Hive join-edge topology.

import HiveCore

extension OrchestrationHiveEngine {
    /// A compiled sub-graph fragment: the set of entry and exit nodes
    /// produced by compiling a single OrchestrationStep into Hive topology.
    struct CompiledStepFragment {
        let entryNodes: [HiveNodeID]
        let exitNodes: [HiveNodeID]
        let nodeCount: Int
        let maxParallelism: Int
    }
}

extension OrchestrationHiveEngine {
    /// Compiles a `DAG` step into a Hive graph fragment using join edges.
    ///
    /// - Parameters:
    ///   - dag: The DAG step to compile.
    ///   - builder: The graph builder to mutate.
    ///   - stepContext: The orchestration step context.
    ///   - nodePrefix: Unique prefix to avoid node ID collisions across steps.
    /// - Returns: A fragment whose entryNodes are root DAG nodes and exitNodes are leaf DAG nodes.
    static func compileDAG(
        _ dag: DAG,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext: OrchestrationStepContext,
        nodePrefix: String
    ) throws -> CompiledStepFragment {
        let nodes = dag.nodes
        let nodeIDs = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.name, HiveNodeID("\(nodePrefix).dag.\($0.name)")) }
        )

        for dagNode in nodes {
            let nodeID = nodeIDs[dagNode.name]!
            let step = dagNode.step
            let deps = dagNode.dependencies
            let depIDs = deps.compactMap { nodeIDs[$0] }
            let dagStep = try ensureHiveSupportedStep(step, feature: "DAG node '\(dagNode.name)'")

            builder.addNode(nodeID) { input in
                let currentInput = try input.store.get(Schema.currentInputKey)
                let nodeInput: String
                if deps.isEmpty {
                    nodeInput = currentInput
                } else {
                    let accumulator = try input.store.get(Schema.accumulatorKey)
                    let depOutputs: [String] = deps.compactMap { dependency in
                        let key = "orchestration.dag.output.\(nodePrefix).\(dependency)"
                        guard case .string(let value)? = accumulator.metadata[key] else { return nil }
                        return value
                    }
                    nodeInput = depOutputs.isEmpty ? currentInput : depOutputs.joined(separator: "\n")
                }

                let result = try await dagStep.execute(nodeInput, context: input.context)

                var metadataUpdate: [String: SendableValue] = result.metadata
                metadataUpdate["orchestration.dag.output.\(nodePrefix).\(dagNode.name)"] = .string(result.output)

                let delta = Accumulator(
                    toolCalls: result.toolCalls,
                    toolResults: result.toolResults,
                    iterationCount: result.iterationCount,
                    metadata: metadataUpdate
                )

                await input.context.agentContext.setPreviousOutput(result)

                return HiveNodeOutput(
                    writes: [
                        AnyHiveWrite(Schema.accumulatorKey, delta),
                    ]
                )
            }

            if !depIDs.isEmpty {
                builder.addJoinEdge(parents: depIDs, target: nodeID)
            }
        }

        let rootIDs = nodes.filter { $0.dependencies.isEmpty }.map { nodeIDs[$0.name]! }
        let leafIDs = {
            let hasDownstream = Set(nodes.flatMap(\.dependencies))
            return nodes.filter { !hasDownstream.contains($0.name) }.map { nodeIDs[$0.name]! }
        }()

        let finalizerID = HiveNodeID("\(nodePrefix).dag.__finalize")
        let sortedNodeNames = dagTopologicalOrder(nodes).map(\.name)
        builder.addNode(finalizerID) { input in
            let currentInput = try input.store.get(Schema.currentInputKey)
            let accumulator = try input.store.get(Schema.accumulatorKey)

            var finalOutput = currentInput
            for nodeName in sortedNodeNames.reversed() {
                let key = "orchestration.dag.output.\(nodePrefix).\(nodeName)"
                if case .string(let value)? = accumulator.metadata[key] {
                    finalOutput = value
                    break
                }
            }

            return HiveNodeOutput(
                writes: [
                    AnyHiveWrite(Schema.currentInputKey, finalOutput)
                ]
            )
        }
        if leafIDs.count > 1 {
            builder.addJoinEdge(parents: leafIDs, target: finalizerID)
        } else if let onlyLeaf = leafIDs.first {
            builder.addEdge(from: onlyLeaf, to: finalizerID)
        }

        return CompiledStepFragment(
            entryNodes: rootIDs,
            exitNodes: [finalizerID],
            nodeCount: nodes.count + 1,
            maxParallelism: dagMaxParallelism(nodes)
        )
    }

    private static func dagTopologicalOrder(_ nodes: [DAGNode]) -> [DAGNode] {
        let nameToNode = Dictionary(uniqueKeysWithValues: nodes.map { ($0.name, $0) })
        var inDegree: [String: Int] = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.name, $0.dependencies.count) }
        )
        var adjacency: [String: [String]] = [:]

        for node in nodes {
            for dependency in node.dependencies {
                adjacency[dependency, default: []].append(node.name)
            }
        }

        var queue = nodes
            .map(\.name)
            .filter { inDegree[$0, default: 0] == 0 }
        var ordered: [DAGNode] = []

        while !queue.isEmpty {
            let name = queue.removeFirst()
            guard let node = nameToNode[name] else { continue }
            ordered.append(node)
            for downstream in adjacency[name, default: []] {
                inDegree[downstream, default: 0] -= 1
                if inDegree[downstream, default: 0] == 0 {
                    queue.append(downstream)
                }
            }
        }

        return ordered
    }

    static func dagMaxParallelism(_ nodes: [DAGNode]) -> Int {
        let adjacency = Dictionary(
            grouping: nodes.flatMap { node in node.dependencies.map { ($0, node.name) } },
            by: \.0
        ).mapValues { pairs in pairs.map(\.1) }

        var inDegree: [String: Int] = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.name, $0.dependencies.count) }
        )

        var frontier = nodes
            .map(\.name)
            .filter { inDegree[$0] == 0 }
        var maxWidth = max(1, frontier.count)

        while !frontier.isEmpty {
            var nextFrontier: [String] = []
            for nodeName in frontier {
                for downstream in adjacency[nodeName, default: []] {
                    inDegree[downstream, default: 0] -= 1
                    if inDegree[downstream] == 0 {
                        nextFrontier.append(downstream)
                    }
                }
            }
            maxWidth = max(maxWidth, nextFrontier.count)
            frontier = nextFrontier
        }

        return max(1, maxWidth)
    }
}
