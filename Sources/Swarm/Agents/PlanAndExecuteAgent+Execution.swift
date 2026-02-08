// PlanAndExecuteAgent+Execution.swift
// Swarm Framework
//
// Step execution logic for Plan-and-Execute agent.

import Foundation

// MARK: - PlanAndExecuteAgent Execution

extension PlanAndExecuteAgent {
    // MARK: - Step Execution

    /// Executes a single step of the plan.
    /// - Parameters:
    ///   - step: The step to execute.
    ///   - plan: The current execution plan.
    ///   - resultBuilder: The result builder to record tool calls and results.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The result of executing the step.
    /// - Throws: `AgentError` if step execution fails.
    func executeStep(
        _ step: PlanStep,
        plan: ExecutionPlan,
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)? = nil,
        tracing: TracingHelper? = nil
    ) async throws -> String {
        // If the step has a tool, execute it
        if let toolName = step.toolName {
            let engine = ToolExecutionEngine()
            let outcome = try await engine.execute(
                toolName: toolName,
                arguments: step.toolArguments,
                registry: toolRegistry,
                agent: self,
                context: nil,
                resultBuilder: resultBuilder,
                hooks: hooks,
                tracing: tracing,
                stopOnToolError: true
            )
            return outcome.result.output.description
        }

        // For steps without tools, use the LLM to execute
        let prompt = buildStepExecutionPrompt(step: step, plan: plan)
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
        let response = try await generateResponse(prompt: prompt)
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        return response
    }

    /// Builds the prompt for executing a non-tool step.
    /// - Parameters:
    ///   - step: The step to execute.
    ///   - plan: The current execution plan.
    /// - Returns: The formatted prompt string.
    func buildStepExecutionPrompt(step: PlanStep, plan: ExecutionPlan) -> String {
        // Gather results from completed dependencies
        var contextFromDeps = ""
        for depId in step.dependsOn {
            if let depStep = plan.steps.first(where: { $0.id == depId }),
               let result = depStep.result {
                contextFromDeps += "Result from Step \(depStep.stepNumber): \(result)\n"
            }
        }

        return """
        \(instructions.isEmpty ? "You are a helpful AI assistant." : instructions)

        You are executing step \(step.stepNumber) of a plan to achieve: \(plan.goal)

        Step description: \(step.stepDescription)

        \(contextFromDeps.isEmpty ? "" : "Context from previous steps:\n\(contextFromDeps)")

        Execute this step and provide the result. Be concise and focused.
        """
    }
}
