// PlanAndExecuteAgent+Execution.swift
// SwiftAgents Framework
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
        hooks: (any RunHooks)? = nil
    ) async throws -> String {
        // If the step has a tool, execute it
        if let toolName = step.toolName {
            let toolCall = ToolCall(
                toolName: toolName,
                arguments: step.toolArguments
            )
            _ = resultBuilder.addToolCall(toolCall)

            let startTime = ContinuousClock.now
            do {
                // Notify hooks before tool execution
                if let tool = await toolRegistry.tool(named: toolName) {
                    await hooks?.onToolStart(context: nil, agent: self, tool: tool, arguments: step.toolArguments)
                }

                let toolResult = try await toolRegistry.execute(
                    toolNamed: toolName,
                    arguments: step.toolArguments,
                    agent: self,
                    context: nil
                )
                let duration = ContinuousClock.now - startTime

                let result = ToolResult.success(
                    callId: toolCall.id,
                    output: toolResult,
                    duration: duration
                )
                _ = resultBuilder.addToolResult(result)

                // Notify hooks after successful tool execution
                if let tool = await toolRegistry.tool(named: toolName) {
                    await hooks?.onToolEnd(context: nil, agent: self, tool: tool, result: toolResult)
                }

                return toolResult.description
            } catch {
                let duration = ContinuousClock.now - startTime
                let errorMessage = (error as? AgentError)?.localizedDescription ?? error.localizedDescription

                let result = ToolResult.failure(
                    callId: toolCall.id,
                    error: errorMessage,
                    duration: duration
                )
                _ = resultBuilder.addToolResult(result)

                throw AgentError.toolExecutionFailed(
                    toolName: toolName,
                    underlyingError: errorMessage
                )
            }
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
