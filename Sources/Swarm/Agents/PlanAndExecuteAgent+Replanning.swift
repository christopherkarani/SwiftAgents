// PlanAndExecuteAgent+Replanning.swift
// Swarm Framework
//
// Replanning and synthesis logic for Plan-and-Execute agent.

import Foundation

// MARK: - PlanAndExecuteAgent Replanning

extension PlanAndExecuteAgent {
    // MARK: - Replanning

    /// Creates a revised plan after step failures.
    /// - Parameters:
    ///   - original: The original plan that had failures.
    ///   - input: The original user input.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: A revised execution plan.
    /// - Throws: `AgentError` if replanning fails.
    func replan(
        original: ExecutionPlan,
        input: String,
        hooks: (any RunHooks)? = nil
    ) async throws -> ExecutionPlan {
        let prompt = buildReplanPrompt(original: original, input: input)
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
        let response = try await generateResponse(prompt: prompt)
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        var newPlan = parsePlan(from: response, goal: input)
        newPlan.revisionCount = original.revisionCount + 1
        return newPlan
    }

    /// Builds the prompt for replanning.
    /// - Parameters:
    ///   - original: The original plan that had failures.
    ///   - input: The original user input.
    /// - Returns: The formatted prompt string.
    func buildReplanPrompt(original: ExecutionPlan, input: String) -> String {
        let toolDescriptions = buildToolDescriptions()

        // Summarize what worked and what failed
        var completedSummary = ""
        for step in original.completedSteps {
            completedSummary += "- Step \(step.stepNumber) (completed): \(step.stepDescription)"
            if let result = step.result {
                completedSummary += " -> Result: \(result.prefix(100))"
            }
            completedSummary += "\n"
        }

        var failedSummary = ""
        for step in original.failedSteps {
            failedSummary += "- Step \(step.stepNumber) (failed): \(step.stepDescription)"
            if let error = step.error {
                failedSummary += " -> Error: \(error)"
            }
            failedSummary += "\n"
        }

        return """
        \(instructions.isEmpty ? "You are a helpful AI assistant that creates structured plans." : instructions)

        The previous plan encountered failures and needs revision.

        Original Goal: \(input)

        \(completedSummary.isEmpty ? "No steps completed." : "Completed steps:\n\(completedSummary)")

        \(failedSummary.isEmpty ? "" : "Failed steps:\n\(failedSummary)")

        \(toolDescriptions.isEmpty ? "No tools are available." : "Available Tools:\n\(toolDescriptions)")

        Create a REVISED plan that:
        1. Builds on the successful steps (do not repeat them)
        2. Addresses the failures with alternative approaches
        3. Achieves the original goal

        Format your response as a JSON object with the following structure:
        {
          "steps": [
            {
              "stepNumber": 1,
              "description": "Clear description of the step",
              "toolName": "tool_name",
              "toolArguments": {"arg1": "value1"},
              "dependsOn": []
            }
          ]
        }

        Rules:
        1. Be specific and actionable in each step.
        2. Only use tools that are available.
        3. Specify dependencies as an array of step numbers.
        4. If a step has no tool, set toolName to null and toolArguments to {}.
        5. Respond ONLY with valid JSON - no additional text before or after.

        Create your revised plan in JSON format:
        """
    }

    // MARK: - Final Answer Synthesis

    /// Synthesizes a final answer from the completed plan.
    /// - Parameters:
    ///   - plan: The completed execution plan.
    ///   - input: The original user input.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The synthesized final answer.
    /// - Throws: `AgentError` if synthesis fails.
    func synthesizeFinalAnswer(
        plan: ExecutionPlan,
        input: String,
        hooks: (any RunHooks)? = nil
    ) async throws -> String {
        // Gather all results
        var results = ""
        for step in plan.steps where step.status == .completed {
            if let result = step.result {
                results += "Step \(step.stepNumber) (\(step.stepDescription)): \(result)\n"
            }
        }

        let prompt = """
        \(instructions.isEmpty ? "You are a helpful AI assistant." : instructions)

        You have completed executing a plan to answer the user's question.

        User Question: \(input)

        Results from execution:
        \(results.isEmpty ? "No results were gathered." : results)

        \(plan.hasFailed ? "Note: Some steps failed during execution. Provide the best answer you can with the available information." : "")

        Synthesize a clear, concise final answer for the user based on the results above.
        """

        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
        let response: String
        if configuration.enableStreaming, hooks != nil {
            response = try await generateResponseStreamed(prompt: prompt, hooks: hooks)
        } else {
            response = try await generateResponse(prompt: prompt)
        }
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        return response
    }

    func generateResponseStreamed(prompt: String, hooks: (any RunHooks)?) async throws -> String {
        let provider = inferenceProvider ?? AgentEnvironmentValues.current.inferenceProvider
        guard let provider else {
            throw AgentError.inferenceProviderUnavailable(
                reason: "No inference provider configured. Please provide an InferenceProvider."
            )
        }

        var content = ""
        content.reserveCapacity(1024)
        let stream = provider.stream(prompt: prompt, options: configuration.inferenceOptions)
        for try await token in stream {
            if !token.isEmpty {
                content += token
            }
            await hooks?.onOutputToken(context: nil, agent: self, token: token)
        }
        return content
    }
}
