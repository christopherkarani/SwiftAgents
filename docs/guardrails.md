# Guardrails

## Overview

Guardrails provide safety validation for AI agent inputs and outputs in the SwiftAgents framework. They act as protective barriers that intercept, validate, and optionally transform data flowing through your agent systems.

The guardrails system supports four types of validation:
- **Input Guardrails**: Validate user input before agent processing
- **Output Guardrails**: Validate agent responses before returning to users
- **Tool Input Guardrails**: Validate tool arguments before execution
- **Tool Output Guardrails**: Validate tool results after execution

All guardrails return a `GuardrailResult` that indicates whether validation passed or triggered a tripwire (blocking condition).

---

## Input Guardrails

### InputGuardrail Protocol

The `InputGuardrail` protocol defines the contract for validating agent inputs before processing. Guardrails can check for sensitive data, malicious content, policy violations, or any custom validation logic.

```swift
public protocol InputGuardrail: Sendable {
    /// The name of this guardrail for identification and logging.
    var name: String { get }

    /// Validates the input and returns a result.
    func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult
}
```

### Creating Input Guardrails

#### Protocol Conformance

Define a custom type conforming to `InputGuardrail`:

```swift
struct SensitiveDataGuardrail: InputGuardrail {
    let name = "SensitiveDataGuardrail"

    func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult {
        if input.contains("SSN:") || input.contains("password:") {
            return .tripwire(message: "Sensitive data detected")
        }
        return .passed()
    }
}
```

#### Closure-Based Guardrails

Use `ClosureInputGuardrail` for quick guardrail creation without defining a new type:

```swift
let lengthGuardrail = ClosureInputGuardrail(name: "MaxLength") { input, context in
    if input.count > 1000 {
        return .tripwire(message: "Input exceeds maximum length")
    }
    return .passed()
}

let result = try await lengthGuardrail.validate("user input", context: nil)
```

#### Builder Pattern

Use `InputGuardrailBuilder` for fluent guardrail construction:

```swift
let guardrail = InputGuardrailBuilder()
    .name("ContentFilter")
    .validate { input, context in
        if input.isEmpty {
            return .tripwire(message: "Empty input not allowed")
        }
        return .passed()
    }
    .build()
```

### Built-in Input Guardrail Factories

SwiftAgents provides convenience factory methods for common scenarios:

```swift
// Maximum length validation
let maxLengthGuardrail = ClosureInputGuardrail.maxLength(1000)

// Non-empty validation
let notEmptyGuardrail = ClosureInputGuardrail.notEmpty()
```

### Input Guardrail with Metadata

Include additional information in tripwire results:

```swift
let profanityGuardrail = ClosureInputGuardrail(name: "ProfanityFilter") { input, context in
    let profanityWords = ["badword1", "badword2"]
    for word in profanityWords {
        if input.lowercased().contains(word) {
            return .tripwire(
                message: "Profanity detected",
                outputInfo: .dictionary(["word": .string(word)])
            )
        }
    }
    return .passed(message: "Content is clean")
}
```

---

## Output Guardrails

### OutputGuardrail Protocol

The `OutputGuardrail` protocol validates agent output before returning to users. Common use cases include content filtering, quality checks, policy compliance, and PII detection.

```swift
public protocol OutputGuardrail: Sendable {
    /// The name of this guardrail for identification and logging.
    var name: String { get }

    /// Validates an agent's output.
    func validate(_ output: String, agent: any Agent, context: AgentContext?) async throws -> GuardrailResult
}
```

### Creating Output Guardrails

#### Protocol Conformance

```swift
struct ContentFilterGuardrail: OutputGuardrail {
    let name = "ContentFilter"

    func validate(_ output: String, agent: any Agent, context: AgentContext?) async throws -> GuardrailResult {
        if output.contains("inappropriate") {
            return .tripwire(message: "Inappropriate content detected")
        }
        return .passed()
    }
}
```

#### Closure-Based Output Guardrails

```swift
// PII detection guardrail
let piiGuardrail = ClosureOutputGuardrail(name: "pii_detector") { output, agent, context in
    let patterns = ["\\d{3}-\\d{2}-\\d{4}", "\\d{16}"] // SSN, credit card
    for pattern in patterns {
        if let _ = output.range(of: pattern, options: .regularExpression) {
            return .tripwire(
                message: "PII detected in output",
                outputInfo: .dictionary(["pattern": .string(pattern)])
            )
        }
    }
    return .passed(message: "No PII detected")
}

// Minimum length validation
let lengthGuardrail = ClosureOutputGuardrail(name: "min_length") { output, _, _ in
    if output.count < 10 {
        return .tripwire(message: "Output too short")
    }
    return .passed()
}
```

#### Context-Aware Validation

```swift
let contextGuardrail = ClosureOutputGuardrail(name: "strict_mode") { output, _, context in
    if let mode = await context?.get("validation_mode")?.stringValue, mode == "strict" {
        // Apply stricter validation in strict mode
        if output.contains("forbidden") {
            return .tripwire(message: "Forbidden content in strict mode")
        }
    }
    return .passed()
}
```

#### Builder Pattern

```swift
let guardrail = OutputGuardrailBuilder()
    .name("QualityCheck")
    .validate { output, agent, context in
        if output.isEmpty {
            return .tripwire(message: "Empty output not allowed")
        }
        return .passed()
    }
    .build()
```

### Built-in Output Guardrail Factories

```swift
// Maximum output length validation
let maxOutputGuardrail = ClosureOutputGuardrail.maxLength(5000)
```

---

## Tool Guardrails

Tool guardrails provide fine-grained validation before and after tool execution.

### ToolGuardrailData

All tool guardrails receive a `ToolGuardrailData` container with execution context:

```swift
public struct ToolGuardrailData: Sendable {
    /// The tool being validated.
    public let tool: any AnyJSONTool

    /// The arguments passed to the tool.
    public let arguments: [String: SendableValue]

    /// The agent executing the tool, if available.
    public let agent: (any Agent)?

    /// The orchestration context, if available.
    public let context: AgentContext?
}
```

### Tool Input Guardrails

#### ToolInputGuardrail Protocol

Validates tool arguments before execution:

```swift
public protocol ToolInputGuardrail: Sendable {
    var name: String { get }
    func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult
}
```

#### Creating Tool Input Guardrails

```swift
// Protocol conformance
struct APIKeyGuardrail: ToolInputGuardrail {
    let name = "api_key_validator"

    func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult {
        guard data.arguments["api_key"] != nil else {
            return .tripwire(message: "Missing API key")
        }
        return .passed(message: "API key present")
    }
}

// Closure-based
let locationValidator = ClosureToolInputGuardrail(name: "location_validator") { data in
    guard let location = data.arguments["location"]?.stringValue,
          !location.isEmpty else {
        return .tripwire(message: "Invalid or missing location")
    }
    return .passed()
}

// Builder pattern
let guardrail = ToolInputGuardrailBuilder()
    .name("ParameterValidator")
    .validate { data in
        guard data.arguments["required_param"] != nil else {
            return .tripwire(message: "Missing required parameter")
        }
        return .passed()
    }
    .build()
```

### Tool Output Guardrails

#### ToolOutputGuardrail Protocol

Validates tool results after execution:

```swift
public protocol ToolOutputGuardrail: Sendable {
    var name: String { get }
    func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult
}
```

#### Creating Tool Output Guardrails

```swift
// Protocol conformance
struct OutputSizeGuardrail: ToolOutputGuardrail {
    let name = "output_size_limiter"
    let maxSize = 10_000

    func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult {
        if let str = output.stringValue, str.count > maxSize {
            return .tripwire(
                message: "Output exceeds maximum size",
                metadata: ["size": .int(str.count), "limit": .int(maxSize)]
            )
        }
        return .passed()
    }
}

// Closure-based
let piiDetector = ClosureToolOutputGuardrail(name: "pii_detector") { data, output in
    if let text = output.stringValue, text.contains("@") {
        return .passed(
            message: "PII detected",
            outputInfo: .dictionary(["piiDetected": .bool(true)])
        )
    }
    return .passed(outputInfo: .dictionary(["piiDetected": .bool(false)]))
}

// Builder pattern
let guardrail = ToolOutputGuardrailBuilder()
    .name("OutputValidator")
    .validate { data, output in
        if let text = output.stringValue, text.isEmpty {
            return .tripwire(message: "Empty output")
        }
        return .passed()
    }
    .build()
```

---

## GuardrailRunner

The `GuardrailRunner` actor orchestrates execution of multiple guardrails with configurable behavior.

### Configuration

```swift
public struct GuardrailRunnerConfiguration: Sendable, Equatable {
    /// Whether to run guardrails in parallel using TaskGroup.
    public let runInParallel: Bool

    /// Whether to stop immediately when a tripwire is triggered.
    public let stopOnFirstTripwire: Bool
}
```

### Static Configurations

```swift
// Default: sequential execution, stop on first tripwire
let defaultRunner = GuardrailRunner(configuration: .default)

// Parallel execution, stop on first tripwire
let parallelRunner = GuardrailRunner(configuration: .parallel)

// Custom configuration
let customRunner = GuardrailRunner(
    configuration: GuardrailRunnerConfiguration(
        runInParallel: true,
        stopOnFirstTripwire: false
    )
)
```

### Execution Modes

| Mode | Behavior |
|------|----------|
| **Sequential** | Run guardrails one-by-one in order |
| **Parallel** | Run guardrails concurrently using TaskGroup |
| **Stop on first** | Immediately throw when a tripwire is triggered |
| **Run all** | Execute all guardrails, then throw if any tripwired |

### Running Input Guardrails

```swift
let runner = GuardrailRunner()

let inputGuardrails: [any InputGuardrail] = [
    ClosureInputGuardrail.notEmpty(),
    ClosureInputGuardrail.maxLength(1000),
    SensitiveDataGuardrail()
]

do {
    let results = try await runner.runInputGuardrails(
        inputGuardrails,
        input: "user input",
        context: nil
    )
    // All guardrails passed
    for result in results {
        print("\(result.guardrailName): passed")
    }
} catch let error as GuardrailError {
    // Handle tripwire or execution error
    print("Guardrail error: \(error)")
}
```

### Running Output Guardrails

```swift
let outputGuardrails: [any OutputGuardrail] = [
    ClosureOutputGuardrail.maxLength(5000),
    piiGuardrail
]

do {
    let results = try await runner.runOutputGuardrails(
        outputGuardrails,
        output: agentResponse,
        agent: myAgent,
        context: context
    )
    // Output validated successfully
} catch let error as GuardrailError {
    print("Output validation failed: \(error)")
}
```

### Running Tool Guardrails

```swift
let toolInputGuardrails: [any ToolInputGuardrail] = [locationValidator]
let toolOutputGuardrails: [any ToolOutputGuardrail] = [piiDetector]

let toolData = ToolGuardrailData(
    tool: weatherTool,
    arguments: ["location": .string("NYC")],
    agent: myAgent,
    context: context
)

// Validate tool input
let inputResults = try await runner.runToolInputGuardrails(
    toolInputGuardrails,
    data: toolData
)

// Execute tool...
let toolOutput: SendableValue = .string("Weather data...")

// Validate tool output
let outputResults = try await runner.runToolOutputGuardrails(
    toolOutputGuardrails,
    data: toolData,
    output: toolOutput
)
```

### Execution Results

```swift
public struct GuardrailExecutionResult: Sendable, Equatable {
    /// The name of the guardrail that executed.
    public let guardrailName: String

    /// The result from the guardrail.
    public let result: GuardrailResult

    /// Whether this execution triggered a tripwire.
    public var didTriggerTripwire: Bool

    /// Whether this execution passed without triggering.
    public var passed: Bool
}
```

---

## Adding Guardrails to Agents

Configure agents with guardrails using the builder pattern:

```swift
// Create guardrails
let inputGuardrail = ClosureInputGuardrail.notEmpty()
let outputGuardrail = ClosureOutputGuardrail.maxLength(5000)

// Configure agent with guardrails (example pattern)
let agentConfig = AgentConfiguration(
    name: "SafeAgent",
    instructions: "You are a helpful assistant."
)

// Use with GuardrailRunner during agent execution
let runner = GuardrailRunner()

// Before processing input
let inputResults = try await runner.runInputGuardrails(
    [inputGuardrail],
    input: userMessage,
    context: agentContext
)

// Process with agent...
let response = try await agent.run(userMessage)

// After getting response
let outputResults = try await runner.runOutputGuardrails(
    [outputGuardrail],
    output: response,
    agent: agent,
    context: agentContext
)
```

---

## Common Patterns

### Content Filtering

```swift
let contentFilter = ClosureInputGuardrail(name: "ContentFilter") { input, _ in
    let blockedPatterns = [
        "hate speech pattern",
        "violence pattern",
        "illegal activity"
    ]

    for pattern in blockedPatterns {
        if input.lowercased().contains(pattern) {
            return .tripwire(
                message: "Blocked content detected",
                metadata: ["pattern": .string(pattern)]
            )
        }
    }
    return .passed()
}
```

### PII Redaction

```swift
let piiRedactor = ClosureOutputGuardrail(name: "PIIRedactor") { output, _, _ in
    var sanitized = output

    // Redact SSN patterns
    let ssnPattern = "\\d{3}-\\d{2}-\\d{4}"
    if let regex = try? NSRegularExpression(pattern: ssnPattern) {
        let range = NSRange(sanitized.startIndex..., in: sanitized)
        sanitized = regex.stringByReplacingMatches(
            in: sanitized,
            range: range,
            withTemplate: "[REDACTED-SSN]"
        )
    }

    // Redact email patterns
    let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    if let regex = try? NSRegularExpression(pattern: emailPattern) {
        let range = NSRange(sanitized.startIndex..., in: sanitized)
        sanitized = regex.stringByReplacingMatches(
            in: sanitized,
            range: range,
            withTemplate: "[REDACTED-EMAIL]"
        )
    }

    if sanitized != output {
        return .passed(
            message: "PII redacted",
            outputInfo: .dictionary(["redacted": .bool(true)])
        )
    }
    return .passed()
}
```

### Rate Limiting

```swift
actor RateLimiter {
    private var requestCounts: [String: Int] = [:]
    private var windowStart: Date = Date()
    private let windowDuration: TimeInterval = 60  // 1 minute
    private let maxRequests: Int = 10

    func checkLimit(for userId: String) -> Bool {
        let now = Date()
        if now.timeIntervalSince(windowStart) > windowDuration {
            requestCounts.removeAll()
            windowStart = now
        }

        let count = requestCounts[userId, default: 0]
        if count >= maxRequests {
            return false
        }
        requestCounts[userId] = count + 1
        return true
    }
}

let rateLimiter = RateLimiter()

let rateLimitGuardrail = ClosureInputGuardrail(name: "RateLimit") { input, context in
    guard let userId = await context?.get("userId")?.stringValue else {
        return .tripwire(message: "User ID required")
    }

    let allowed = await rateLimiter.checkLimit(for: userId)
    if !allowed {
        return .tripwire(
            message: "Rate limit exceeded",
            metadata: ["userId": .string(userId)]
        )
    }
    return .passed()
}
```

### Permission Checks

```swift
let permissionGuardrail = ClosureToolInputGuardrail(name: "PermissionCheck") { data in
    // Check if user has permission to use this tool
    guard let userRole = await data.context?.get("userRole")?.stringValue else {
        return .tripwire(message: "User role not found")
    }

    let toolName = data.tool.name
    let restrictedTools = ["admin_tool", "delete_tool", "system_config"]

    if restrictedTools.contains(toolName) && userRole != "admin" {
        return .tripwire(
            message: "Insufficient permissions",
            metadata: [
                "tool": .string(toolName),
                "requiredRole": .string("admin"),
                "actualRole": .string(userRole)
            ]
        )
    }
    return .passed()
}
```

### Chaining Multiple Guardrails

```swift
let guardrails: [any InputGuardrail] = [
    ClosureInputGuardrail.notEmpty(),
    ClosureInputGuardrail.maxLength(10000),
    contentFilter,
    rateLimitGuardrail
]

let runner = GuardrailRunner(configuration: .default)

do {
    let results = try await runner.runInputGuardrails(
        guardrails,
        input: userInput,
        context: context
    )
    // All validations passed
} catch GuardrailError.inputTripwireTriggered(let name, let message, _) {
    print("Blocked by \(name): \(message ?? "No message")")
}
```

---

## Best Practices

### 1. Name Guardrails Descriptively

Use clear, descriptive names for identification and logging:

```swift
// Good
let guardrail = ClosureInputGuardrail(name: "MaxInputLength_10000") { ... }

// Avoid
let guardrail = ClosureInputGuardrail(name: "g1") { ... }
```

### 2. Fail Fast with Sequential Execution

For production, use sequential execution with stop-on-first for efficiency:

```swift
let runner = GuardrailRunner(configuration: .default)
```

### 3. Use Parallel Execution for Diagnostics

When debugging or running comprehensive checks, use parallel mode without stopping:

```swift
let diagnosticRunner = GuardrailRunner(
    configuration: GuardrailRunnerConfiguration(
        runInParallel: true,
        stopOnFirstTripwire: false
    )
)
```

### 4. Include Metadata in Tripwires

Provide actionable information in tripwire results:

```swift
return .tripwire(
    message: "Input validation failed",
    metadata: [
        "field": .string("email"),
        "reason": .string("invalid_format"),
        "value": .string(maskedValue)
    ]
)
```

### 5. Handle Errors Gracefully

Always catch and handle guardrail errors appropriately:

```swift
do {
    let results = try await runner.runInputGuardrails(guardrails, input: input, context: nil)
} catch GuardrailError.inputTripwireTriggered(let name, let message, let info) {
    // Log and return user-friendly error
    Log.agents.warning("Input blocked by \(name): \(message ?? "")")
    throw UserFacingError.invalidInput(message ?? "Validation failed")
} catch GuardrailError.executionFailed(let name, let error) {
    // Log internal error, return generic message
    Log.agents.error("Guardrail \(name) failed: \(error)")
    throw UserFacingError.internalError
}
```

### 6. Keep Guardrails Focused

Each guardrail should check one concern:

```swift
// Good: Single responsibility
let lengthGuardrail = ClosureInputGuardrail.maxLength(1000)
let contentGuardrail = contentFilter
let rateGuardrail = rateLimitGuardrail

// Avoid: Multiple concerns in one guardrail
let everythingGuardrail = ClosureInputGuardrail(name: "Everything") { input, context in
    // Length check + content filter + rate limit + ...
}
```

### 7. Make Guardrails Sendable

All guardrails must conform to `Sendable` for safe concurrent execution:

```swift
struct MyGuardrail: InputGuardrail, Sendable {
    // Use only Sendable properties
    let maxLength: Int  // Sendable
    // let mutableState: [String] = []  // Not Sendable - avoid
}
```

### 8. Test Guardrails Thoroughly

Write tests for both passing and blocking scenarios:

```swift
func testMaxLengthGuardrail() async throws {
    let guardrail = ClosureInputGuardrail.maxLength(10)

    // Test passing case
    let passResult = try await guardrail.validate("short", context: nil)
    XCTAssertFalse(passResult.tripwireTriggered)

    // Test blocking case
    let blockResult = try await guardrail.validate("this is too long", context: nil)
    XCTAssertTrue(blockResult.tripwireTriggered)
}
```

### 9. Order Guardrails by Cost

Place fast, cheap checks before expensive ones:

```swift
let guardrails: [any InputGuardrail] = [
    ClosureInputGuardrail.notEmpty(),        // O(1) - fastest
    ClosureInputGuardrail.maxLength(10000),  // O(n) - fast
    contentFilter,                            // O(n*m) - moderate
    llmBasedValidator                         // API call - slowest
]
```

### 10. Use Context for Stateful Validation

Pass state through `AgentContext` rather than shared mutable state:

```swift
let contextAwareGuardrail = ClosureInputGuardrail(name: "ContextAware") { input, context in
    guard let sessionId = await context?.get("sessionId")?.stringValue else {
        return .tripwire(message: "Session required")
    }

    // Use context for validation decisions
    if let isVerified = await context?.get("userVerified")?.boolValue, !isVerified {
        return .tripwire(message: "User verification required")
    }

    return .passed()
}
```
