// OrchestrationHiveEngine+SmartSteps.swift
// Swarm Framework
//
// Native Hive compilation for orchestration steps that benefit from graph-level visibility.

import Foundation
import HiveCore

extension OrchestrationHiveEngine {
    static func entryNodeIDs(for step: OrchestrationStep, nodePrefix: String) -> [HiveNodeID] {
        if let dag = step as? DAG {
            let dagNodeIDs = Dictionary(
                uniqueKeysWithValues: dag.nodes.map { ($0.name, HiveNodeID("\(nodePrefix).dag.\($0.name)")) }
            )
            return dag.nodes.filter { $0.dependencies.isEmpty }.compactMap { dagNodeIDs[$0.name] }
        }

        if let parallel = step as? Parallel, !parallel.items.isEmpty {
            return [HiveNodeID("\(nodePrefix).parallel.dispatch")]
        }

        if step is Router {
            return [HiveNodeID("\(nodePrefix).router.eval")]
        }

        if let approval = step as? HumanApproval, approval.handler == nil {
            return [HiveNodeID("\(nodePrefix).human_approval")]
        }

        return [HiveNodeID("orchestration.\(nodePrefix)")]
    }

    static func compileTopLevelStep(
        _ step: OrchestrationStep,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext: OrchestrationStepContext,
        nodePrefix: String,
        orchestrationStepPrefix: String
    ) -> CompiledStepFragment {
        if let dag = step as? DAG {
            return compileDAG(
                dag,
                into: &builder,
                stepContext: stepContext,
                nodePrefix: nodePrefix
            )
        }

        if let parallel = step as? Parallel, !parallel.items.isEmpty {
            return compileParallel(
                parallel,
                into: &builder,
                stepContext: stepContext,
                nodePrefix: nodePrefix,
                orchestrationStepPrefix: orchestrationStepPrefix
            )
        }

        if let router = step as? Router {
            return compileRouter(
                router,
                into: &builder,
                stepContext: stepContext,
                nodePrefix: nodePrefix,
                orchestrationStepPrefix: orchestrationStepPrefix
            )
        }

        if let approval = step as? HumanApproval, approval.handler == nil {
            return compileHumanApprovalInterrupt(
                approval,
                into: &builder,
                stepContext: stepContext,
                nodePrefix: nodePrefix,
                orchestrationStepPrefix: orchestrationStepPrefix
            )
        }

        return compileFallbackStep(
            step,
            into: &builder,
            stepContext: stepContext,
            nodePrefix: nodePrefix,
            orchestrationStepPrefix: orchestrationStepPrefix
        )
    }

    static func compileFallbackStep(
        _ step: OrchestrationStep,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext _: OrchestrationStepContext,
        nodePrefix: String,
        orchestrationStepPrefix: String
    ) -> CompiledStepFragment {
        let nodeID = HiveNodeID("orchestration.\(nodePrefix)")
        builder.addNode(nodeID) { input in
            let currentInput = try input.store.get(Schema.currentInputKey)
            let result = try await step.execute(currentInput, context: input.context)
            let metadataUpdate = metadataWithOrchestrationNamespace(
                base: result.metadata,
                prefix: orchestrationStepPrefix
            )

            let delta = Accumulator(
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                metadata: metadataUpdate
            )

            await input.context.agentContext.setPreviousOutput(result)

            return HiveNodeOutput(
                writes: [
                    AnyHiveWrite(Schema.currentInputKey, result.output),
                    AnyHiveWrite(Schema.accumulatorKey, delta),
                ]
            )
        }

        return CompiledStepFragment(
            entryNodes: [nodeID],
            exitNodes: [nodeID],
            nodeCount: 1,
            maxParallelism: 1
        )
    }

    static func compileParallel(
        _ parallel: Parallel,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext: OrchestrationStepContext,
        nodePrefix: String,
        orchestrationStepPrefix: String
    ) -> CompiledStepFragment {
        let namedItems = parallel.items.enumerated().map { index, item in
            let resolvedName = item.name ?? stepContext.agentName(for: item.agent)
            return (index, resolvedName, item.agent)
        }
        let effectiveParallelism = max(
            1,
            parallel.maxConcurrency.map { max(1, min($0, namedItems.count)) } ?? namedItems.count
        )
        let groupID = "parallel.\(nodePrefix)"
        let startKey = "orchestration.parallel.\(nodePrefix).start_ns"
        let dispatchID = HiveNodeID("\(nodePrefix).parallel.dispatch")
        let mergeID = HiveNodeID("\(nodePrefix).parallel.merge")
        let branchIDs = namedItems.map { HiveNodeID("\(nodePrefix).parallel.branch.\($0.0)") }

        builder.addNode(dispatchID) { input in
            let startNs = Int(truncatingIfNeeded: input.environment.clock.nowNanoseconds())
            let delta = Accumulator(metadata: [startKey: .int(startNs)])
            return HiveNodeOutput(
                writes: [AnyHiveWrite(Schema.accumulatorKey, delta)],
                next: .useGraphEdges
            )
        }

        for (index, name, agent) in namedItems {
            let branchID = branchIDs[index]
            builder.addNode(branchID) { input in
                let currentInput = try input.store.get(Schema.currentInputKey)
                do {
                    await input.context.agentContext.recordExecution(agentName: name)

                    let effectiveInput = try await input.context.applyHandoffConfiguration(
                        for: agent,
                        input: currentInput,
                        targetName: name
                    )

                    if let orchestrator = input.context.orchestrator {
                        await input.context.hooks?.onHandoff(
                            context: input.context.agentContext,
                            fromAgent: orchestrator,
                            toAgent: agent
                        )
                    }

                    let result = try await agent.run(
                        effectiveInput,
                        session: input.context.session,
                        hooks: input.context.hooks
                    )
                    let branch = ParallelBranchResult.success(
                        groupID: groupID,
                        branchIndex: index,
                        branchName: name,
                        result: result
                    )
                    return HiveNodeOutput(
                        writes: [
                            AnyHiveWrite(Schema.parallelBranchResultsKey, [branch]),
                        ]
                    )
                } catch {
                    guard parallel.errorHandling != .failFast else {
                        throw error
                    }
                    let branch = ParallelBranchResult.failure(
                        groupID: groupID,
                        branchIndex: index,
                        branchName: name,
                        error: error.localizedDescription
                    )
                    return HiveNodeOutput(
                        writes: [
                            AnyHiveWrite(Schema.parallelBranchResultsKey, [branch]),
                        ]
                    )
                }
            }
            builder.addEdge(from: dispatchID, to: branchID)
            builder.addEdge(from: branchID, to: mergeID)
        }

        builder.addNode(mergeID) { input in
            let allBranches = try input.store.get(Schema.parallelBranchResultsKey)
            let branches = allBranches
                .filter { $0.groupID == groupID }
                .sorted { $0.branchIndex < $1.branchIndex }

            let successes = branches.filter(\.isSuccess)
            let failures = branches.filter { !$0.isSuccess }

            if successes.isEmpty, !failures.isEmpty {
                throw OrchestrationError.allAgentsFailed(
                    errors: failures.compactMap(\.error)
                )
            }

            let mergedOutput: String
            switch parallel.mergeStrategy {
            case .concatenate:
                mergedOutput = successes.compactMap(\.output).joined(separator: "\n\n")
            case .first:
                mergedOutput = successes.first?.output ?? ""
            case .longest:
                mergedOutput = successes
                    .compactMap(\.output)
                    .max(by: { $0.count < $1.count }) ?? ""
            case .structured:
                mergedOutput = successes.map { branch in
                    "## \(branch.branchName)\n\n\(branch.output ?? "")\n\n"
                }.joined()
            case .custom(let merger):
                let orderedPairs = successes.map { branch -> (String, AgentResult) in
                    let result = AgentResult(
                        output: branch.output ?? "",
                        toolCalls: branch.toolCalls,
                        toolResults: branch.toolResults,
                        iterationCount: branch.iterationCount,
                        duration: .zero,
                        tokenUsage: nil,
                        metadata: branch.metadata
                    )
                    return (branch.branchName, result)
                }
                mergedOutput = merger(orderedPairs)
            }

            var allToolCalls: [ToolCall] = []
            var allToolResults: [ToolResult] = []
            var totalIterations = 0
            var allMetadata: [String: SendableValue] = [:]

            for branch in successes {
                allToolCalls.append(contentsOf: branch.toolCalls)
                allToolResults.append(contentsOf: branch.toolResults)
                totalIterations += branch.iterationCount
                for (key, value) in branch.metadata {
                    allMetadata["parallel.\(branch.branchName).\(key)"] = value
                }
            }

            allMetadata["parallel.agent_count"] = .int(parallel.items.count)
            allMetadata["parallel.success_count"] = .int(successes.count)
            allMetadata["parallel.error_count"] = .int(failures.count)
            if !failures.isEmpty {
                let errors = failures.compactMap(\.error).map(SendableValue.string)
                allMetadata["parallel.errors"] = .array(errors)
            }

            let accumulator = try input.store.get(Schema.accumulatorKey)
            if case .int(let startNs)? = accumulator.metadata[startKey] {
                let durationNs = max(0, Int(truncatingIfNeeded: input.environment.clock.nowNanoseconds()) - startNs)
                allMetadata["parallel.total_duration"] = .double(Double(durationNs) / 1_000_000_000)
            }

            allMetadata = metadataWithOrchestrationNamespace(
                base: allMetadata,
                prefix: orchestrationStepPrefix
            )
            let delta = Accumulator(
                toolCalls: allToolCalls,
                toolResults: allToolResults,
                iterationCount: totalIterations,
                metadata: allMetadata
            )

            await input.context.agentContext.setPreviousOutput(AgentResult(output: mergedOutput))

            return HiveNodeOutput(
                writes: [
                    AnyHiveWrite(Schema.currentInputKey, mergedOutput),
                    AnyHiveWrite(Schema.accumulatorKey, delta),
                ]
            )
        }

        return CompiledStepFragment(
            entryNodes: [dispatchID],
            exitNodes: [mergeID],
            nodeCount: namedItems.count + 2,
            maxParallelism: effectiveParallelism
        )
    }

    static func compileRouter(
        _ router: Router,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext: OrchestrationStepContext,
        nodePrefix: String,
        orchestrationStepPrefix: String
    ) -> CompiledStepFragment {
        let evalID = HiveNodeID("\(nodePrefix).router.eval")
        let convergeID = HiveNodeID("\(nodePrefix).router.converge")
        let fallbackStep = router.fallback
        let startKey = "orchestration.router.\(nodePrefix).start_ns"
        let routeKey = "orchestration.router.\(nodePrefix).matched_route"

        let routeNodes = router.routes.enumerated().map { index, route in
            (
                route: route,
                index: index,
                nodeID: HiveNodeID("\(nodePrefix).router.route.\(index)")
            )
        }
        let fallbackNodeID = fallbackStep.map { _ in HiveNodeID("\(nodePrefix).router.fallback") }

        builder.addNode(evalID) { input in
            let currentInput = try input.store.get(Schema.currentInputKey)
            let startNs = Int(truncatingIfNeeded: input.environment.clock.nowNanoseconds())

            for routeNode in routeNodes {
                if await routeNode.route.condition.matches(input: currentInput, context: input.context.agentContext) {
                    let routeName = resolvedRouteName(
                        for: routeNode.route,
                        index: routeNode.index,
                        context: input.context
                    )
                    let delta = Accumulator(
                        metadata: [
                            startKey: .int(startNs),
                            routeKey: .string(routeName),
                        ]
                    )
                    return HiveNodeOutput(
                        writes: [AnyHiveWrite(Schema.accumulatorKey, delta)],
                        next: .nodes([routeNode.nodeID])
                    )
                }
            }

            if let fallbackStep, let fallbackNodeID {
                let routeName = resolvedFallbackName(for: fallbackStep, context: input.context)
                let delta = Accumulator(
                    metadata: [
                        startKey: .int(startNs),
                        routeKey: .string(routeName),
                    ]
                )
                return HiveNodeOutput(
                    writes: [AnyHiveWrite(Schema.accumulatorKey, delta)],
                    next: .nodes([fallbackNodeID])
                )
            }

            throw OrchestrationError.routingFailed(
                reason: "No route matched input and no fallback step configured"
            )
        }

        for routeNode in routeNodes {
            builder.addNode(routeNode.nodeID) { input in
                let currentInput = try input.store.get(Schema.currentInputKey)
                let result = try await routeNode.route.step.execute(currentInput, context: input.context)
                var metadata = result.metadata
                metadata = metadataWithOrchestrationNamespace(
                    base: metadata,
                    prefix: orchestrationStepPrefix
                )
                let delta = Accumulator(
                    toolCalls: result.toolCalls,
                    toolResults: result.toolResults,
                    iterationCount: result.iterationCount,
                    metadata: metadata
                )
                await input.context.agentContext.setPreviousOutput(result)
                return HiveNodeOutput(
                    writes: [
                        AnyHiveWrite(Schema.currentInputKey, result.output),
                        AnyHiveWrite(Schema.accumulatorKey, delta),
                    ]
                )
            }
            builder.addEdge(from: routeNode.nodeID, to: convergeID)
        }

        if let fallbackStep, let fallbackNodeID {
            builder.addNode(fallbackNodeID) { input in
                let currentInput = try input.store.get(Schema.currentInputKey)
                let result = try await fallbackStep.execute(currentInput, context: input.context)
                var metadata = result.metadata
                metadata = metadataWithOrchestrationNamespace(
                    base: metadata,
                    prefix: orchestrationStepPrefix
                )
                let delta = Accumulator(
                    toolCalls: result.toolCalls,
                    toolResults: result.toolResults,
                    iterationCount: result.iterationCount,
                    metadata: metadata
                )
                await input.context.agentContext.setPreviousOutput(result)
                return HiveNodeOutput(
                    writes: [
                        AnyHiveWrite(Schema.currentInputKey, result.output),
                        AnyHiveWrite(Schema.accumulatorKey, delta),
                    ]
                )
            }
            builder.addEdge(from: fallbackNodeID, to: convergeID)
        }

        builder.addNode(convergeID) { input in
            let accumulator = try input.store.get(Schema.accumulatorKey)
            let routeName = accumulator.metadata[routeKey]?.stringValue ?? "unknown"

            var metadata: [String: SendableValue] = [
                "router.matched_route": .string(routeName),
                "router.total_routes": .int(router.routes.count),
            ]
            if case .int(let startNs)? = accumulator.metadata[startKey] {
                let durationNs = max(0, Int(truncatingIfNeeded: input.environment.clock.nowNanoseconds()) - startNs)
                metadata["router.duration"] = .double(Double(durationNs) / 1_000_000_000)
            } else {
                metadata["router.duration"] = .double(0)
            }

            metadata = metadataWithOrchestrationNamespace(
                base: metadata,
                prefix: orchestrationStepPrefix
            )
            return HiveNodeOutput(
                writes: [
                    AnyHiveWrite(Schema.accumulatorKey, Accumulator(metadata: metadata)),
                ]
            )
        }

        let branchCount = routeNodes.count + (fallbackNodeID == nil ? 0 : 1)
        return CompiledStepFragment(
            entryNodes: [evalID],
            exitNodes: [convergeID],
            nodeCount: branchCount + 2,
            maxParallelism: 1
        )
    }

    static func compileHumanApprovalInterrupt(
        _ step: HumanApproval,
        into builder: inout HiveGraphBuilder<Schema>,
        stepContext _: OrchestrationStepContext,
        nodePrefix: String,
        orchestrationStepPrefix: String
    ) -> CompiledStepFragment {
        let nodeID = HiveNodeID("\(nodePrefix).human_approval")
        builder.addNode(nodeID) { input in
            let currentInput = try input.store.get(Schema.currentInputKey)
            if let resume = input.run.resume?.payload {
                switch resume {
                case .humanApproval(let response):
                    var metadata: [String: SendableValue] = [
                        "approval.prompt": .string(step.prompt),
                    ]
                    let output: String
                    switch response {
                    case .approved:
                        metadata["approval.response"] = .string("approved")
                        output = currentInput
                    case .modified(let newInput):
                        metadata["approval.response"] = .string("modified")
                        output = newInput
                    case .rejected(let reason):
                        metadata["approval.response"] = .string("rejected")
                        metadata["approval.rejection_reason"] = .string(reason)
                        throw OrchestrationError.humanApprovalRejected(prompt: step.prompt, reason: reason)
                    }

                    metadata = metadataWithOrchestrationNamespace(
                        base: metadata,
                        prefix: orchestrationStepPrefix
                    )

                    return HiveNodeOutput(
                        writes: [
                            AnyHiveWrite(Schema.currentInputKey, output),
                            AnyHiveWrite(Schema.accumulatorKey, Accumulator(metadata: metadata)),
                        ]
                    )
                }
            }

            return HiveNodeOutput(
                interrupt: HiveInterruptRequest(
                    payload: .humanApprovalRequired(prompt: step.prompt, currentOutput: currentInput)
                )
            )
        }

        return CompiledStepFragment(
            entryNodes: [nodeID],
            exitNodes: [nodeID],
            nodeCount: 1,
            maxParallelism: 1
        )
    }

    static func metadataWithOrchestrationNamespace(
        base: [String: SendableValue],
        prefix: String
    ) -> [String: SendableValue] {
        var merged = base
        for (key, value) in base {
            merged["\(prefix).\(key)"] = value
        }
        return merged
    }

    static func declaredMaxParallelism(in steps: [OrchestrationStep]) -> Int {
        steps.map(declaredMaxParallelism).max() ?? 1
    }

    static func declaredMaxParallelism(_ step: OrchestrationStep) -> Int {
        if let parallel = step as? Parallel {
            let raw = parallel.maxConcurrency.map { max(1, min($0, parallel.items.count)) } ?? parallel.items.count
            return max(1, raw)
        }
        if let sequential = step as? Sequential {
            return declaredMaxParallelism(in: sequential.steps)
        }
        if let group = step as? OrchestrationGroup {
            return declaredMaxParallelism(in: group.steps)
        }
        if let router = step as? Router {
            var values = router.routes.map { declaredMaxParallelism($0.step) }
            if let fallback = router.fallback {
                values.append(declaredMaxParallelism(fallback))
            }
            return max(1, values.max() ?? 1)
        }
        if let dag = step as? DAG {
            return max(1, dagMaxParallelism(dag.nodes))
        }
        return 1
    }

    static func resolvedRouteName(
        for route: RouteBranch,
        index: Int,
        context: OrchestrationStepContext
    ) -> String {
        if let name = route.name {
            return name
        }
        if let agentStep = route.step as? AgentStep {
            let agentName = agentStep.name ?? context.agentName(for: agentStep.agent)
            return "route.\(index).\(agentName)"
        }
        return "route.\(index)"
    }

    static func resolvedFallbackName(
        for step: OrchestrationStep,
        context: OrchestrationStepContext
    ) -> String {
        if let agentStep = step as? AgentStep {
            let agentName = agentStep.name ?? context.agentName(for: agentStep.agent)
            return "fallback.\(agentName)"
        }
        return "fallback"
    }
}
