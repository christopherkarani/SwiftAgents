# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using SwiftAgents.

## Table of Contents

- [Tool Issues](#tool-issues)
- [Agent Issues](#agent-issues)
- [Handoff Issues](#handoff-issues)
- [Performance Issues](#performance-issues)
- [Error Messages](#error-messages)
- [Debugging Tips](#debugging-tips)

## Tool Issues

### Tool Not Found

**Symptoms:**
- `AgentError.toolNotFound(name: "tool_name")`
- Agent fails to execute tool calls

**Common Causes:**
1. Tool not registered with the agent
2. Tool name mismatch (case-sensitive)
3. Tool registered after agent creation

**Solutions:**

```swift
// 1. Ensure tool is registered
let registry = ToolRegistry(tools: [CalculatorTool()])
let agent = MyAgent(tools: registry.allTools)

// 2. Check name matches exactly
struct CalculatorTool: AnyJSONTool {
    let name = "calculator"  // Must match exactly
}

// 3. Use type-safe registration
registry.register(CalculatorTool())
let tool = await registry.tool(ofType: CalculatorTool.self)
```

**Debug:**
```swift
// Check available tools
print("Available tools: \(registry.toolNames)")

// Verify tool registration
let exists = await registry.contains(named: "calculator")
print("Calculator tool registered: \(exists)")
```

### Invalid Tool Arguments

**Symptoms:**
- `AgentError.invalidToolArguments(toolName: "tool", reason: "...")`
- Tool execution fails with parameter errors

**Common Causes:**
1. Missing required parameters
2. Wrong parameter types
3. Parameter name typos

**Solutions:**

```swift
// 1. Check parameter definitions
struct MyTool: AnyJSONTool {
    let parameters: [ToolParameter] = [
        ToolParameter(name: "input", description: "Input data", type: .string), // Required by default
        ToolParameter(name: "count", description: "Count", type: .int, isRequired: false, defaultValue: .int(1))
    ]
}

// 2. Provide all required parameters
let result = try await tool.execute(arguments: [
    "input": .string("data"),  // Required
    "count": .int(5)          // Optional
])

// 3. Use correct types
let result = try await tool.execute(arguments: [
    "count": .int(5),        // ✅ Correct
    "count": .string("5")    // ❌ Wrong type
])
```

### Tool Execution Failed

**Symptoms:**
- `AgentError.toolExecutionFailed(toolName: "tool", underlyingError: "...")`
- Tool throws unexpected errors

**Common Causes:**
1. Tool implementation bugs
2. Network failures (for API tools)
3. Invalid input data
4. Resource limitations

**Solutions:**

```swift
// 1. Add error handling to tool implementation
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    do {
        return try await performOperation(arguments)
    } catch let error as MyCustomError {
        throw AgentError.toolExecutionFailed(
            toolName: name,
            underlyingError: error.localizedDescription
        )
    } catch {
        throw AgentError.toolExecutionFailed(
            toolName: name,
            underlyingError: "Unexpected error: \(error.localizedDescription)"
        )
    }
}

// 2. Add input validation
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    guard let input = arguments["input"]?.stringValue, !input.isEmpty else {
        throw AgentError.invalidToolArguments(
            toolName: name,
            reason: "Input parameter is required and cannot be empty"
        )
    }
    // Continue with validated input...
}
```

## Agent Issues

### Agent Timeout

**Symptoms:**
- `AgentError.timeout(duration: ...)`
- Agent execution takes too long

**Common Causes:**
1. Complex tasks requiring more time
2. Infinite loops in agent logic
3. Slow inference provider
4. Network latency

**Solutions:**

```swift
// 1. Increase timeout for complex tasks
let config = AgentConfiguration(
    name: "ComplexAgent",
    maxIterations: 10,
    timeout: .seconds(60)  // Increase timeout
)

// 2. Reduce iterations for simple tasks
let config = AgentConfiguration(
    name: "SimpleAgent",
    maxIterations: 3,
    timeout: .seconds(10)
)

// 3. Add timeout handling
do {
    let result = try await agent.run(input, timeout: .seconds(30))
} catch AgentError.timeout {
    // Handle timeout gracefully
    return "The request timed out. Please try a simpler query."
}
```

### Max Iterations Exceeded

**Symptoms:**
- `AgentError.maxIterationsExceeded(iterations: 10)`
- Agent doesn't converge on a solution

**Common Causes:**
1. Task too complex for iteration limit
2. Agent stuck in reasoning loop
3. Poor prompt engineering

**Solutions:**

```swift
// 1. Increase max iterations for complex tasks
let config = AgentConfiguration(
    name: "ReasoningAgent",
    maxIterations: 15  // Increase limit
)

// 2. Improve prompts for convergence
let instructions = """
Solve this step by step. After each step, evaluate if you have enough information to provide a final answer.

If you have a final answer, provide it clearly.
If you need more information, ask specific questions.
Do not repeat previous steps.
"""

// 3. Handle iteration limits gracefully
do {
    let result = try await agent.run(input)
} catch AgentError.maxIterationsExceeded {
    return "This is a complex query. Please break it down into smaller questions."
}
```

### Inference Provider Issues

**Symptoms:**
- `AgentError.inferenceProviderUnavailable(reason: "...")`
- Model-related errors

**Common Causes:**
1. API key issues
2. Network connectivity
3. Service outages
4. Rate limiting

**Solutions:**

```swift
// 1. Check API key configuration
let provider = OpenAIProvider(apiKey: "sk-...")  // Valid key?

// 2. Add retry logic
func runWithRetry(_ input: String) async throws -> AgentResult {
    let maxRetries = 3
    for attempt in 1...maxRetries {
        do {
            return try await agent.run(input)
        } catch AgentError.inferenceProviderUnavailable {
            if attempt < maxRetries {
                try await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
                continue
            }
            throw error
        }
    }
}

// 3. Handle rate limits
do {
    let result = try await agent.run(input)
} catch AgentError.rateLimitExceeded(let retryAfter) {
    if let delay = retryAfter {
        try await Task.sleep(for: .seconds(delay))
        // Retry...
    }
}
```

## Handoff Issues

### Handoff Not Executing

**Symptoms:**
- Handoffs are configured but not triggered
- Agent doesn't transfer to other agents

**Common Causes:**
1. Handoff conditions not met
2. Wrong handoff configuration
3. Agent doesn't support handoffs

**Solutions:**

```swift
// 1. Check handoff conditions
let config = handoff(
    to: executorAgent,
    isEnabled: { context, _ in
        await context.get("ready")?.boolValue ?? false  // Condition met?
    }
)

// 2. Use correct agent types
struct CoordinatorAgent: Agent {
    let handoffs: [AnyHandoffConfiguration] = [
        anyHandoff(to: executorAgent),  // Correct type
        anyHandoff(to: plannerAgent)
    ]
}

// 3. Debug handoff execution
let config = handoff(
    to: executorAgent,
    onHandoff: { context, data in
        print("Handoff triggered: \(data.sourceAgentName) -> \(data.targetAgentName)")
        await context.set("debug_handoff", value: .bool(true))
    }
)
```

### Context Not Transferred

**Symptoms:**
- Handoff executes but target agent lacks context
- Information lost between agents

**Common Causes:**
1. Context not properly set before handoff
2. Context keys don't match
3. Context serialization issues

**Solutions:**

```swift
// 1. Set context before handoff
let result = try await coordinator.run("plan and execute task", context: context)
await context.set("task_plan", value: .string("step1, step2, step3"))

// 2. Use consistent context keys
await context.set("current_task", value: .string("execute_step_1"))
await context.set("task_data", value: .object([
    "step": .int(1),
    "action": .string("fetch_data")
]))

// 3. Verify context in target agent
let handoffConfig = handoff(
    to: executorAgent,
    onHandoff: { context, data in
        let task = await context.get("current_task")?.stringValue
        print("Received task: \(task ?? "none")")
    }
)
```

## Performance Issues

### Slow Tool Execution

**Symptoms:**
- Tool calls take longer than expected
- Overall agent response time is slow

**Common Causes:**
1. Inefficient tool implementation
2. Network latency
3. Large data processing

**Solutions:**

```swift
// 1. Profile tool execution
let start = CFAbsoluteTimeGetCurrent()
let result = try await tool.execute(arguments: args)
let elapsed = CFAbsoluteTimeGetCurrent() - start
print("Tool execution took: \(elapsed) seconds")

// 2. Optimize tool implementation
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    // Cache expensive operations
    if let cached = cache[cacheKey] {
        return cached
    }

    let result = try await expensiveOperation(arguments)
    cache[cacheKey] = result
    return result
}

// 3. Use async/await properly
func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
    // Don't block the thread
    return try await networkRequest()  // ✅ Async
    // return try networkRequest()     // ❌ Blocking
}
```

### Memory Issues

**Symptoms:**
- Out of memory errors
- App becomes unresponsive
- High memory usage

**Common Causes:**
1. Large conversation history
2. Memory leaks in tools
3. Inefficient data structures

**Solutions:**

```swift
// 1. Limit conversation history
let memory = ConversationMemory(maxMessages: 50)  // Limit size

// 2. Use summary memory for long conversations
let memory = SummaryMemory(
    summarizer: InferenceProviderSummarizer(provider: myProvider),
    maxSummaries: 10
)

// 3. Clear memory periodically
await memory.clear()  // Manual cleanup

// 4. Use weak references in tools
class MyTool: Tool {
    weak var delegate: MyDelegate?  // Prevent retain cycles
}
```

### High CPU Usage

**Symptoms:**
- App uses excessive CPU
- Battery drains quickly
- System becomes slow

**Common Causes:**
1. Tight loops in agent logic
2. Inefficient algorithms
3. Too many concurrent operations

**Solutions:**

```swift
// 1. Add delays in loops
for attempt in 1...maxRetries {
    do {
        return try await operation()
    } catch {
        if attempt < maxRetries {
            try await Task.sleep(for: .milliseconds(100 * attempt))  // Exponential backoff
        }
    }
}

// 2. Limit concurrency
let results = await withTaskGroup(of: Result.self) { group in
    for item in items.prefix(5) {  // Limit concurrent operations
        group.addTask {
            await processItem(item)
        }
    }
}

// 3. Use appropriate QoS
Task(priority: .background) {
    await performBackgroundWork()
}
```

## Error Messages

### Common Error Patterns

**"Tool 'name' not found"**
- Check tool registration
- Verify exact name match
- Ensure tool is in agent's tool list

**"Invalid arguments for tool 'name'"**
- Check parameter definitions
- Verify argument names and types
- Ensure required parameters are provided

**"Rate limit exceeded"**
- Implement exponential backoff
- Reduce request frequency
- Consider upgrading API plan

**"Context window exceeded"**
- Use shorter prompts
- Summarize conversation history
- Switch to larger model

**"Model not available"**
- Check model availability in your region
- Verify API credentials
- Try different model

### Error Recovery

```swift
func runWithRecovery(_ input: String) async throws -> AgentResult {
    do {
        return try await agent.run(input)
    } catch let error as AgentError {
        // Log the error
        Log.agents.error("Agent error", error: error)

        // Try recovery based on error type
        switch error {
        case .toolNotFound(let name):
            // Try to register missing tool
            if let tool = availableTools[name] {
                registry.register(tool)
                return try await agent.run(input)  // Retry
            }

        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                try await Task.sleep(for: .seconds(delay))
                return try await agent.run(input)  // Retry
            }

        case .contextWindowExceeded:
            // Summarize and retry
            let summary = await summarizeConversation()
            return try await agent.run("Summary: \(summary)\n\n\(input)")

        default:
            throw error  // Re-throw unrecoverable errors
        }
    }
}
```

## Debugging Tips

### Enable Verbose Logging

```swift
let config = AgentConfiguration(
    name: "DebugAgent",
    verbose: true  // Enable detailed logging
)

let agent = MyAgent(configuration: config)
```

### Add Debug Hooks

```swift
let hooks = RunHooks(
    onToolStart: { context, agent, tool, arguments in
        print("🔧 Starting tool: \(tool.name)")
        print("Arguments: \(arguments)")
    },
    onToolEnd: { context, agent, tool, result in
        print("✅ Tool completed: \(tool.name)")
        print("Result: \(result)")
    },
    onError: { context, agent, error in
        print("❌ Error: \(error.localizedDescription)")
        if let suggestion = (error as? AgentError)?.recoverySuggestion {
            print("💡 \(suggestion)")
        }
    }
)

let result = try await agent.run(input, hooks: hooks)
```

### Inspect Agent State

```swift
// Check tool availability
print("Available tools: \(registry.toolNames)")

// Check agent configuration
print("Agent config: \(agent.configuration)")

// Check memory state
if let memory = agent.memory {
    print("Memory messages: \(await memory.retrieve(query: "", limit: 10).count)")
}

// Check inference provider
if let provider = agent.inferenceProvider {
    print("Provider available: \(await provider.isAvailable())")
}
```

### Use Breakpoints

Set breakpoints in:
- Tool execution methods
- Agent run methods
- Error handling code
- Handoff logic

### Test Isolations

Test components separately:
```swift
// Test tool in isolation
let tool = CalculatorTool()
let result = try await tool.execute(arguments: ["expression": .string("2+2")])

// Test agent without tools
let agent = SimpleAgent(tools: [])  // No tools
let result = try await agent.run("simple response")

// Test handoffs separately
let handoffResult = try await coordinator.executeHandoff(request, context: context)
```

### Performance Profiling

```swift
import os.signpost

let signpostID = OSSignpostID(log: .agents)
os_signpost(.begin, log: .agents, name: "agent_run", signpostID: signpostID)

let result = try await agent.run(input)

os_signpost(.end, log: .agents, name: "agent_run", signpostID: signpostID)
```

Use Instruments to profile:
- Time Profiler for CPU usage
- Allocations for memory usage
- Network for API calls

## Getting Help

If you can't resolve an issue:

1. **Check the documentation:**
   - [API Reference](API_REFERENCE.md)
   - [Best Practices](BEST_PRACTICES.md)
   - [Migration Guide](MIGRATION_GUIDE.md)

2. **Gather diagnostic information:**
   ```swift
   let diagnostics = await collectDiagnostics()
   print(diagnostics)
   ```

3. **Create a minimal reproduction case:**
   ```swift
   // Minimal code that reproduces the issue
   let registry = ToolRegistry(tools: [CalculatorTool()])
   let agent = SimpleAgent(tools: registry.allTools)
   let result = try await agent.run("2+2")
   ```

4. **File an issue** with:
   - SwiftAgents version
   - iOS/macOS version
   - Minimal reproduction code
   - Expected vs actual behavior
   - Diagnostic logs

5. **Community support:**
   - GitHub Discussions
   - Stack Overflow (tag: swiftagents)
   - Discord/Slack communities

Remember: Most issues are configuration-related. Start with the basics and work your way up to complex scenarios.
