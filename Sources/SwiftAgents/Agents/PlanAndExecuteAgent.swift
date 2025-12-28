// PlanAndExecuteAgent.swift
// SwiftAgents Framework
//
// Plan-and-Execute agent implementation.
// Implements a three-phase paradigm: Plan, Execute, and Replan.

import Foundation
import Logging

// MARK: - StepStatus

/// The execution status of a plan step.
public enum StepStatus: String, Sendable, Equatable, Codable {
    /// Step has not yet started.
    case pending
    /// Step is currently being executed.
    case inProgress
    /// Step completed successfully.
    case completed
    /// Step execution failed.
    case failed
    /// Step was skipped due to dependency failure or plan revision.
    case skipped
}

// MARK: - PlanStep

/// An individual step in an execution plan.
///
/// Each step represents a discrete action that the agent needs to perform
/// to achieve the overall goal. Steps may depend on other steps and can
/// optionally invoke tools.
public struct PlanStep: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for this step.
    public let id: UUID

    /// The ordinal position of this step in the plan.
    public let stepNumber: Int

    /// A description of what this step accomplishes.
    public let stepDescription: String

    /// The name of the tool to invoke, if any.
    public let toolName: String?

    /// Arguments to pass to the tool.
    public let toolArguments: [String: SendableValue]

    /// IDs of steps that must complete before this step can execute.
    public let dependsOn: [UUID]

    /// Current execution status of this step.
    public var status: StepStatus

    /// Result output from executing this step.
    public var result: String?

    /// Error message if the step failed.
    public var error: String?

    /// Creates a new plan step.
    /// - Parameters:
    ///   - id: Unique identifier. Default: new UUID
    ///   - stepNumber: The step's position in the plan.
    ///   - stepDescription: What this step accomplishes.
    ///   - toolName: Optional tool to invoke. Default: nil
    ///   - toolArguments: Arguments for the tool. Default: [:]
    ///   - dependsOn: Dependencies on other steps. Default: []
    ///   - status: Initial status. Default: .pending
    ///   - result: Step result. Default: nil
    ///   - error: Error message. Default: nil
    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        stepDescription: String,
        toolName: String? = nil,
        toolArguments: [String: SendableValue] = [:],
        dependsOn: [UUID] = [],
        status: StepStatus = .pending,
        result: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.stepDescription = stepDescription
        self.toolName = toolName
        self.toolArguments = toolArguments
        self.dependsOn = dependsOn
        self.status = status
        self.result = result
        self.error = error
    }
}

// MARK: CustomStringConvertible

extension PlanStep: CustomStringConvertible {
    public var description: String {
        let toolInfo = toolName.map { " [tool: \($0)]" } ?? ""
        return "Step \(stepNumber): \(stepDescription)\(toolInfo) (\(status.rawValue))"
    }
}

// MARK: - ExecutionPlan

/// A collection of steps that form a complete plan to achieve a goal.
///
/// The execution plan maintains the sequence of steps, tracks their status,
/// and provides utilities for determining which steps can be executed next.
public struct ExecutionPlan: Sendable, Equatable {
    /// The steps in this plan.
    public var steps: [PlanStep]

    /// The goal this plan is designed to achieve.
    public let goal: String

    /// When this plan was created.
    public let createdAt: Date

    /// Number of times this plan has been revised.
    public var revisionCount: Int

    /// Whether all steps have completed successfully.
    public var isComplete: Bool {
        steps.allSatisfy { $0.status == .completed || $0.status == .skipped }
    }

    /// Whether any step has failed.
    public var hasFailed: Bool {
        steps.contains { $0.status == .failed }
    }

    /// The next step that can be executed.
    ///
    /// Returns the first pending step whose dependencies have all completed.
    public var nextExecutableStep: PlanStep? {
        for step in steps where step.status == .pending {
            let dependenciesMet = step.dependsOn.allSatisfy { depId in
                steps.first { $0.id == depId }?.status == .completed
            }
            if dependenciesMet {
                return step
            }
        }
        return nil
    }

    /// Steps that have completed successfully.
    public var completedSteps: [PlanStep] {
        steps.filter { $0.status == .completed }
    }

    /// Steps that are still pending.
    public var pendingSteps: [PlanStep] {
        steps.filter { $0.status == .pending }
    }

    /// Steps that failed during execution.
    public var failedSteps: [PlanStep] {
        steps.filter { $0.status == .failed }
    }

    /// Creates a new execution plan.
    /// - Parameters:
    ///   - steps: The steps in the plan.
    ///   - goal: The goal to achieve.
    ///   - createdAt: Creation timestamp. Default: now
    ///   - revisionCount: Number of revisions. Default: 0
    public init(
        steps: [PlanStep],
        goal: String,
        createdAt: Date = Date(),
        revisionCount: Int = 0
    ) {
        self.steps = steps
        self.goal = goal
        self.createdAt = createdAt
        self.revisionCount = revisionCount
    }

    /// Updates a step's status by its ID.
    /// - Parameters:
    ///   - id: The step ID to update.
    ///   - status: The new status.
    ///   - result: Optional result to set.
    ///   - error: Optional error to set.
    public mutating func updateStep(
        id: UUID,
        status: StepStatus,
        result: String? = nil,
        error: String? = nil
    ) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        steps[index].status = status
        if let result { steps[index].result = result }
        if let error { steps[index].error = error }
    }

    /// Marks all pending steps that depend on a failed step as skipped.
    /// - Parameter failedStepId: The ID of the failed step.
    public mutating func skipDependentSteps(of failedStepId: UUID) {
        for index in steps.indices {
            if steps[index].dependsOn.contains(failedStepId), steps[index].status == .pending {
                steps[index].status = .skipped
                steps[index].error = "Skipped due to dependency failure"
                // Recursively skip steps that depend on this one
                skipDependentSteps(of: steps[index].id)
            }
        }
    }
}

// MARK: CustomStringConvertible

extension ExecutionPlan: CustomStringConvertible {
    public var description: String {
        let stepDescriptions = steps.map { "  \($0)" }.joined(separator: "\n")
        return """
        ExecutionPlan(goal: "\(goal)", revision: \(revisionCount))
        Steps:
        \(stepDescriptions)
        """
    }
}

// MARK: - PlanAndExecuteAgent

/// A Plan-and-Execute agent that uses structured planning before execution.
///
/// The Plan-and-Execute paradigm separates planning from execution:
/// 1. **Plan**: Generate a multi-step plan to achieve the goal.
/// 2. **Execute**: Execute each step in order, using tools as needed.
/// 3. **Replan**: If a step fails, generate a revised plan and continue.
///
/// This approach is beneficial for complex tasks that require multiple steps
/// and can benefit from explicit planning and error recovery.
///
/// Example:
/// ```swift
/// let agent = PlanAndExecuteAgent(
///     tools: [WebSearchTool(), CalculatorTool()],
///     instructions: "You are a research assistant."
/// )
///
/// let result = try await agent.run("Find the population of Tokyo and calculate 10% of it")
/// print(result.output)
/// ```
public actor PlanAndExecuteAgent: Agent {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any Tool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]
    nonisolated public let guardrailRunnerConfiguration: GuardrailRunnerConfiguration

    // MARK: - Plan-and-Execute Specific Configuration

    /// Maximum number of replan attempts when steps fail.
    nonisolated public let maxReplanAttempts: Int

    /// Configured handoffs for this agent.
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Initialization

    /// Creates a new PlanAndExecuteAgent.
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions. Default: ""
    ///   - configuration: Agent configuration. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - maxReplanAttempts: Maximum replan attempts. Default: 3
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    public init(
        tools: [any Tool] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        maxReplanAttempts: Int = 3,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.tools = tools
        self.instructions = instructions
        self.configuration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self.guardrailRunnerConfiguration = guardrailRunnerConfiguration
        self.maxReplanAttempts = maxReplanAttempts
        _handoffs = handoffs
        toolRegistry = ToolRegistry(tools: tools)
    }

    // MARK: - Agent Protocol Methods

    /// Executes the agent with the given input and returns a result.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional hooks for observing agent execution events.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails, or `GuardrailError` if guardrails trigger.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Input cannot be empty")
        }

        // Notify hooks of agent start
        await hooks?.onAgentStart(context: nil, agent: self, input: input)

        do {
            // Run input guardrails at the start before any processing
            let runner = GuardrailRunner(configuration: guardrailRunnerConfiguration)
            _ = try await runner.runInputGuardrails(inputGuardrails, input: input, context: nil)

            cancellationState = .active
            let resultBuilder = AgentResult.Builder()
            _ = resultBuilder.start()

            // Load conversation history from session (limit to recent messages)
            var sessionHistory: [MemoryMessage] = []
            if let session {
                sessionHistory = try await session.getItems(limit: configuration.sessionHistoryLimit)
            }

            // Create user message for this turn
            let userMessage = MemoryMessage.user(input)

            // Store in memory (for AI context) if available
            if let mem = memory {
                // Add session history to memory
                for msg in sessionHistory {
                    await mem.add(msg)
                }
                await mem.add(userMessage)
            }

            // Execute the Plan-and-Execute loop with session context
            let output = try await executePlanAndExecuteLoop(
                input: input,
                sessionHistory: sessionHistory,
                resultBuilder: resultBuilder,
                hooks: hooks
            )

            _ = resultBuilder.setOutput(output)

            // Run output guardrails BEFORE storing in memory/session
            _ = try await runner.runOutputGuardrails(outputGuardrails, output: output, agent: self, context: nil)

            // Store turn in session (user + assistant messages)
            if let session {
                let assistantMessage = MemoryMessage.assistant(output)
                try await session.addItems([userMessage, assistantMessage])
            }

            // Only store output in memory if validation passed
            if let mem = memory {
                await mem.add(.assistant(output))
            }

            let result = resultBuilder.build()
            await hooks?.onAgentEnd(context: nil, agent: self, result: result)
            return result
        } catch {
            await hooks?.onError(context: nil, agent: self, error: error)
            throw error
        }
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional hooks for observing agent execution events.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await agent.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    /// Cancels any ongoing execution.
    public func cancel() async {
        cancellationState = .cancelled
    }

    // MARK: Private

    // MARK: - Cancellation State

    private enum CancellationState: Sendable {
        case active
        case cancelled
    }

    // MARK: - Plan JSON Structures

    /// Decodable structure for plan responses.
    private struct PlanResponse: Codable {
        let steps: [StepData]
    }

    /// Decodable structure for individual step data.
    private struct StepData: Codable {
        let stepNumber: Int
        let description: String
        let toolName: String?
        let toolArguments: [String: SendableValue]?
        let dependsOn: [Int]
    }

    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Internal State

    private var cancellationState: CancellationState = .active
    private let toolRegistry: ToolRegistry

    // MARK: - Plan-and-Execute Loop

    private func executePlanAndExecuteLoop(
        input: String,
        sessionHistory: [MemoryMessage] = [],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)? = nil
    ) async throws -> String {
        var replanAttempts = 0
        let startTime = ContinuousClock.now

        // Phase 1: Generate initial plan
        var plan = try await generatePlan(for: input, sessionHistory: sessionHistory, hooks: hooks)
        _ = resultBuilder.setMetadata("initialPlan", .string(plan.description))

        // Phase 2: Execute steps
        while !plan.isComplete {
            try Task.checkCancellation()
            if cancellationState == .cancelled {
                throw AgentError.cancelled
            }

            // Timeout enforcement
            let elapsed = ContinuousClock.now - startTime
            if elapsed > configuration.timeout {
                Log.agents.warning("Plan execution timed out after \(elapsed)")
                throw AgentError.timeout(duration: configuration.timeout)
            }

            guard let step = plan.nextExecutableStep else {
                // No executable step but plan not complete - something is wrong
                if plan.hasFailed {
                    // Phase 3: Replan if possible
                    if replanAttempts < maxReplanAttempts {
                        replanAttempts += 1
                        _ = resultBuilder.incrementIteration()
                        plan = try await replan(original: plan, input: input, hooks: hooks)
                        _ = resultBuilder.setMetadata("replan_\(replanAttempts)", .string(plan.description))
                        continue
                    } else {
                        // Max replans exceeded, synthesize answer with partial results
                        break
                    }
                }

                // CRITICAL: Check for deadlock - pending steps with unsatisfiable dependencies
                if !plan.pendingSteps.isEmpty {
                    for index in plan.steps.indices {
                        if plan.steps[index].status == .pending {
                            plan.steps[index].status = .skipped
                            plan.steps[index].error = "Skipped: dependency deadlock or circular dependency detected"
                        }
                    }
                }
                break
            }

            _ = resultBuilder.incrementIteration()

            // Mark step as in progress
            plan.updateStep(id: step.id, status: .inProgress)

            // Execute the step
            do {
                let stepResult = try await executeStep(step, plan: plan, resultBuilder: resultBuilder, hooks: hooks)
                plan.updateStep(id: step.id, status: .completed, result: stepResult)
            } catch {
                let errorMessage = (error as? AgentError)?.localizedDescription ?? error.localizedDescription

                // Log the failure with context
                Log.agents.error("Step \(step.stepNumber) failed: \(errorMessage)")

                plan.updateStep(id: step.id, status: .failed, error: errorMessage)
                plan.skipDependentSteps(of: step.id)

                if configuration.stopOnToolError {
                    throw error
                }
            }
        }

        // Phase 4: Synthesize final answer
        return try await synthesizeFinalAnswer(plan: plan, input: input, hooks: hooks)
    }

    // MARK: - Plan Generation

    private func generatePlan(for input: String, sessionHistory: [MemoryMessage] = [], hooks: (any RunHooks)? = nil) async throws -> ExecutionPlan {
        let prompt = buildPlanningPrompt(for: input, sessionHistory: sessionHistory)
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
        let response = try await generateResponse(prompt: prompt)
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        return parsePlan(from: response, goal: input)
    }

    private func buildPlanningPrompt(for input: String, sessionHistory: [MemoryMessage] = []) -> String {
        let toolDescriptions = buildToolDescriptions()
        let conversationContext = buildConversationContext(from: sessionHistory)

        return """
        \(instructions.isEmpty ? "You are a helpful AI assistant that creates structured plans." : instructions)

        You are a planning agent. Your task is to create a step-by-step plan to accomplish the user's goal.

        \(toolDescriptions.isEmpty ? "No tools are available." : "Available Tools:\n\(toolDescriptions)")

        Create a plan with numbered steps. For each step, provide:
        1. A clear description of what the step accomplishes
        2. If a tool is needed, specify the tool name and arguments
        3. If the step depends on previous steps, specify their step numbers

        Format your response as a JSON object with the following structure:
        {
          "steps": [
            {
              "stepNumber": 1,
              "description": "Clear description of the step",
              "toolName": "tool_name",
              "toolArguments": {"arg1": "value1", "arg2": 42},
              "dependsOn": []
            },
            {
              "stepNumber": 2,
              "description": "Another step description",
              "toolName": null,
              "toolArguments": {},
              "dependsOn": [1]
            }
          ]
        }

        Rules:
        1. Be specific and actionable in each step.
        2. Only use tools that are available.
        3. Keep the plan concise but complete.
        4. Specify dependencies as an array of step numbers.
        5. If a step has no tool, set toolName to null and toolArguments to {}.
        6. Respond ONLY with valid JSON - no additional text before or after.
        \(conversationContext.isEmpty ? "" : "\nConversation History:\n\(conversationContext)")

        User Goal: \(input)

        Create your plan in JSON format:
        """
    }

    private func buildConversationContext(from sessionHistory: [MemoryMessage]) -> String {
        guard !sessionHistory.isEmpty else { return "" }

        var lines: [String] = []
        for message in sessionHistory {
            switch message.role {
            case .user:
                lines.append("User: \(message.content)")
            case .assistant:
                lines.append("Assistant: \(message.content)")
            case .system:
                lines.append("System: \(message.content)")
            case .tool:
                lines.append("Tool: \(message.content)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func parsePlan(from response: String, goal: String) -> ExecutionPlan {
        // Try to parse as JSON first
        if let plan = parseJSONPlan(from: response, goal: goal) {
            return plan
        }

        // Fallback: If JSON parsing fails, create a single generic step
        Log.agents.warning("Failed to parse plan as JSON, creating fallback plan")
        let step = PlanStep(
            stepNumber: 1,
            stepDescription: "Execute the task: \(goal)",
            toolName: nil
        )
        return ExecutionPlan(steps: [step], goal: goal)
    }

    /// Parses a JSON-formatted plan response.
    /// - Parameters:
    ///   - response: The LLM response containing JSON.
    ///   - goal: The goal being planned for.
    /// - Returns: An ExecutionPlan if parsing succeeds, nil otherwise.
    private func parseJSONPlan(from response: String, goal: String) -> ExecutionPlan? {
        // Extract JSON from response (handle cases where LLM adds extra text)
        let jsonString = extractJSON(from: response)
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        // Decode the plan
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let planResponse = try? decoder.decode(PlanResponse.self, from: jsonData) else {
            return nil
        }

        // Convert PlanResponse to ExecutionPlan
        var steps: [PlanStep] = []
        var stepNumberToId: [Int: UUID] = [:]

        // First pass: Create all steps with UUIDs
        for stepData in planResponse.steps {
            let stepId = UUID()
            stepNumberToId[stepData.stepNumber] = stepId
        }

        // Second pass: Build PlanSteps with resolved dependencies
        for stepData in planResponse.steps {
            guard let stepId = stepNumberToId[stepData.stepNumber] else { continue }

            // Resolve dependencies from step numbers to UUIDs
            let dependencyIds = stepData.dependsOn.compactMap { stepNumberToId[$0] }

            let step = PlanStep(
                id: stepId,
                stepNumber: stepData.stepNumber,
                stepDescription: stepData.description,
                toolName: stepData.toolName,
                toolArguments: stepData.toolArguments ?? [:],
                dependsOn: dependencyIds
            )
            steps.append(step)
        }

        // If no steps were parsed, return nil to trigger fallback
        guard !steps.isEmpty else {
            return nil
        }

        return ExecutionPlan(steps: steps, goal: goal)
    }

    /// Extracts JSON content from a response that may contain additional text.
    private func extractJSON(from response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // If response starts with {, try to find the matching closing brace
        if let firstBrace = trimmed.firstIndex(of: "{") {
            var depth = 0
            var inString = false
            var escapeNext = false

            for (index, char) in trimmed[firstBrace...].enumerated() {
                if escapeNext {
                    escapeNext = false
                    continue
                }

                if char == "\\" {
                    escapeNext = true
                    continue
                }

                if char == "\"", !escapeNext {
                    inString.toggle()
                    continue
                }

                if !inString {
                    if char == "{" {
                        depth += 1
                    } else if char == "}" {
                        depth -= 1
                        if depth == 0 {
                            let endIndex = trimmed.index(firstBrace, offsetBy: index + 1)
                            return String(trimmed[firstBrace..<endIndex])
                        }
                    }
                }
            }
        }

        // If extraction failed, return original (might still be valid JSON)
        return trimmed
    }

    // MARK: - Step Execution

    private func executeStep(
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

    private func buildStepExecutionPrompt(step: PlanStep, plan: ExecutionPlan) -> String {
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

    // MARK: - Replanning

    private func replan(original: ExecutionPlan, input: String, hooks: (any RunHooks)? = nil) async throws -> ExecutionPlan {
        let prompt = buildReplanPrompt(original: original, input: input)
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
        let response = try await generateResponse(prompt: prompt)
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        var newPlan = parsePlan(from: response, goal: input)
        newPlan.revisionCount = original.revisionCount + 1
        return newPlan
    }

    private func buildReplanPrompt(original: ExecutionPlan, input: String) -> String {
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

    private func synthesizeFinalAnswer(plan: ExecutionPlan, input: String, hooks: (any RunHooks)? = nil) async throws -> String {
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
        let response = try await generateResponse(prompt: prompt)
        await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)
        return response
    }

    // MARK: - Helper Methods

    private func buildToolDescriptions() -> String {
        var descriptions: [String] = []
        for tool in tools {
            let toolDesc = formatToolDescription(tool)
            descriptions.append(toolDesc)
        }
        return descriptions.joined(separator: "\n\n")
    }

    private func formatToolDescription(_ tool: any Tool) -> String {
        let params = formatParameterDescriptions(tool.parameters)
        if params.isEmpty {
            return "- \(tool.name): \(tool.description)"
        } else {
            return "- \(tool.name): \(tool.description)\n  Parameters:\n\(params)"
        }
    }

    private func formatParameterDescriptions(_ parameters: [ToolParameter]) -> String {
        var lines: [String] = []
        for param in parameters {
            let reqStr = param.isRequired ? "(required)" : "(optional)"
            let line = "    - \(param.name) \(reqStr): \(param.description)"
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private func generateResponse(prompt: String) async throws -> String {
        if let provider = inferenceProvider {
            let options = InferenceOptions(
                temperature: configuration.temperature,
                maxTokens: configuration.maxTokens
            )
            return try await provider.generate(prompt: prompt, options: options)
        }

        throw AgentError.inferenceProviderUnavailable(
            reason: "No inference provider configured. Please provide an InferenceProvider."
        )
    }
}

// MARK: PlanAndExecuteAgent.Builder

public extension PlanAndExecuteAgent {
    /// Builder for creating PlanAndExecuteAgent instances with a fluent API.
    ///
    /// Uses value semantics (struct) for Swift 6 concurrency safety.
    ///
    /// Example:
    /// ```swift
    /// let agent = PlanAndExecuteAgent.Builder()
    ///     .tools([CalculatorTool(), DateTimeTool()])
    ///     .instructions("You are a research assistant.")
    ///     .maxReplanAttempts(5)
    ///     .build()
    /// ```
    struct Builder: Sendable {
        // MARK: Public

        /// Creates a new builder.
        public init() {}

        /// Sets the tools.
        /// - Parameter tools: The tools to use.
        /// - Returns: Self for chaining.
        @discardableResult
        public func tools(_ tools: [any Tool]) -> Builder {
            var copy = self
            copy._tools = tools
            return copy
        }

        /// Adds a tool.
        /// - Parameter tool: The tool to add.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addTool(_ tool: any Tool) -> Builder {
            var copy = self
            copy._tools.append(tool)
            return copy
        }

        /// Adds built-in tools.
        /// - Returns: Self for chaining.
        @discardableResult
        public func withBuiltInTools() -> Builder {
            var copy = self
            copy._tools.append(contentsOf: BuiltInTools.all)
            return copy
        }

        /// Sets the instructions.
        /// - Parameter instructions: The system instructions.
        /// - Returns: Self for chaining.
        @discardableResult
        public func instructions(_ instructions: String) -> Builder {
            var copy = self
            copy._instructions = instructions
            return copy
        }

        /// Sets the configuration.
        /// - Parameter configuration: The agent configuration.
        /// - Returns: Self for chaining.
        @discardableResult
        public func configuration(_ configuration: AgentConfiguration) -> Builder {
            var copy = self
            copy._configuration = configuration
            return copy
        }

        /// Sets the memory system.
        /// - Parameter memory: The memory to use.
        /// - Returns: Self for chaining.
        @discardableResult
        public func memory(_ memory: any Memory) -> Builder {
            var copy = self
            copy._memory = memory
            return copy
        }

        /// Sets the inference provider.
        /// - Parameter provider: The provider to use.
        /// - Returns: Self for chaining.
        @discardableResult
        public func inferenceProvider(_ provider: any InferenceProvider) -> Builder {
            var copy = self
            copy._inferenceProvider = provider
            return copy
        }

        /// Sets the tracer.
        /// - Parameter tracer: The tracer to use.
        /// - Returns: Self for chaining.
        @discardableResult
        public func tracer(_ tracer: (any Tracer)?) -> Builder {
            var copy = self
            copy._tracer = tracer
            return copy
        }

        /// Sets the maximum number of replan attempts.
        /// - Parameter attempts: The maximum replan attempts.
        /// - Returns: Self for chaining.
        @discardableResult
        public func maxReplanAttempts(_ attempts: Int) -> Builder {
            var copy = self
            copy._maxReplanAttempts = attempts
            return copy
        }

        /// Sets the input guardrails.
        /// - Parameter guardrails: The input guardrails.
        /// - Returns: Self for chaining.
        @discardableResult
        public func inputGuardrails(_ guardrails: [any InputGuardrail]) -> Builder {
            var copy = self
            copy._inputGuardrails = guardrails
            return copy
        }

        /// Adds an input guardrail.
        /// - Parameter guardrail: The input guardrail to add.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addInputGuardrail(_ guardrail: any InputGuardrail) -> Builder {
            var copy = self
            copy._inputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the output guardrails.
        /// - Parameter guardrails: The output guardrails.
        /// - Returns: Self for chaining.
        @discardableResult
        public func outputGuardrails(_ guardrails: [any OutputGuardrail]) -> Builder {
            var copy = self
            copy._outputGuardrails = guardrails
            return copy
        }

        /// Adds an output guardrail.
        /// - Parameter guardrail: The output guardrail to add.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addOutputGuardrail(_ guardrail: any OutputGuardrail) -> Builder {
            var copy = self
            copy._outputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the guardrail runner configuration.
        /// - Parameter configuration: The guardrail runner configuration.
        /// - Returns: Self for chaining.
        @discardableResult
        public func guardrailRunnerConfiguration(_ configuration: GuardrailRunnerConfiguration) -> Builder {
            var copy = self
            copy._guardrailRunnerConfiguration = configuration
            return copy
        }

        /// Sets the handoff configurations.
        /// - Parameter handoffs: The handoff configurations to use.
        /// - Returns: Self for chaining.
        @discardableResult
        public func handoffs(_ handoffs: [AnyHandoffConfiguration]) -> Builder {
            var copy = self
            copy._handoffs = handoffs
            return copy
        }

        /// Adds a handoff configuration.
        /// - Parameter handoff: The handoff configuration to add.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addHandoff(_ handoff: AnyHandoffConfiguration) -> Builder {
            var copy = self
            copy._handoffs.append(handoff)
            return copy
        }

        /// Builds the agent.
        /// - Returns: A new PlanAndExecuteAgent instance.
        public func build() -> PlanAndExecuteAgent {
            PlanAndExecuteAgent(
                tools: _tools,
                instructions: _instructions,
                configuration: _configuration,
                memory: _memory,
                inferenceProvider: _inferenceProvider,
                tracer: _tracer,
                inputGuardrails: _inputGuardrails,
                outputGuardrails: _outputGuardrails,
                guardrailRunnerConfiguration: _guardrailRunnerConfiguration,
                maxReplanAttempts: _maxReplanAttempts,
                handoffs: _handoffs
            )
        }

        // MARK: Private

        private var _tools: [any Tool] = []
        private var _instructions: String = ""
        private var _configuration: AgentConfiguration = .default
        private var _memory: (any Memory)?
        private var _inferenceProvider: (any InferenceProvider)?
        private var _tracer: (any Tracer)?
        private var _inputGuardrails: [any InputGuardrail] = []
        private var _outputGuardrails: [any OutputGuardrail] = []
        private var _guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default
        private var _maxReplanAttempts: Int = 3
        private var _handoffs: [AnyHandoffConfiguration] = []
    }
}

// MARK: - PlanAndExecuteAgent DSL Extension

public extension PlanAndExecuteAgent {
    /// Creates a PlanAndExecuteAgent using the declarative builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let agent = PlanAndExecuteAgent {
    ///     Instructions("You are a research assistant.")
    ///
    ///     Tools {
    ///         WebSearchTool()
    ///         CalculatorTool()
    ///     }
    ///
    ///     Configuration(.default.maxIterations(15))
    /// }
    /// ```
    ///
    /// - Parameter content: A closure that builds the agent components.
    init(@AgentBuilder _ content: () -> AgentBuilder.Components) {
        let components = content()
        self.init(
            tools: components.tools,
            instructions: components.instructions ?? "",
            configuration: components.configuration ?? .default,
            memory: components.memory,
            inferenceProvider: components.inferenceProvider,
            tracer: components.tracer,
            inputGuardrails: components.inputGuardrails,
            outputGuardrails: components.outputGuardrails,
            guardrailRunnerConfiguration: components.guardrailRunnerConfiguration ?? .default,
            handoffs: components.handoffs
        )
    }
}
