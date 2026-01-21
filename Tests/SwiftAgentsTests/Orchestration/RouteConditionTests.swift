// RouteConditionTests.swift
// SwiftAgentsTests
//
// Comprehensive tests for RouteCondition and Route types from AgentRouter.swift

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - MockRouteAgent

/// A simple mock agent for testing Route initialization and properties
final class MockRouteAgent: AgentRuntime, @unchecked Sendable {
    let name: String
    let tools: [any AnyJSONTool] = []
    let instructions: String
    let configuration: AgentConfiguration = .default

    init(name: String, instructions: String = "Mock agent") {
        self.name = name
        self.instructions = instructions
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        AgentResult(
            output: "\(name) processed: \(input)",
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            duration: .milliseconds(10),
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 10),
            metadata: [:]
        )
    }

    nonisolated func stream(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                continuation.yield(.started(input: input))
                let result = try await run(input)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {}
}

// MARK: - RouteConditionBuiltInComprehensiveTests

@Suite("RouteCondition - Built-in Conditions (Comprehensive)")
struct RouteConditionBuiltInComprehensiveTests {
    // MARK: - contains()

    @Test("contains() matches substring - case insensitive by default")
    func containsCaseInsensitive() async {
        let condition = RouteCondition.contains("weather")

        #expect(await condition.matches(input: "What's the weather today?", context: nil))
        #expect(await condition.matches(input: "WEATHER forecast", context: nil))
        #expect(await condition.matches(input: "Check weather", context: nil))
        #expect(await !condition.matches(input: "What's the temperature?", context: nil))
    }

    @Test("contains() with isCaseSensitive: true")
    func containsCaseSensitive() async {
        let condition = RouteCondition.contains("Weather", isCaseSensitive: true)

        #expect(await condition.matches(input: "What's the Weather today?", context: nil))
        #expect(await !condition.matches(input: "What's the weather today?", context: nil))
        #expect(await !condition.matches(input: "WEATHER forecast", context: nil))
    }

    @Test("contains() with empty string")
    func containsEmptyString() async {
        let condition = RouteCondition.contains("")

        // Empty string contains() returns false in Swift
        #expect(await !condition.matches(input: "anything", context: nil))
        #expect(await !condition.matches(input: "", context: nil))
    }

    @Test("contains() exact match")
    func containsExactMatch() async {
        let condition = RouteCondition.contains("hello")

        #expect(await condition.matches(input: "hello", context: nil))
    }

    // MARK: - matches(pattern:)

    @Test("matches() with valid regex pattern")
    func matchesValidPattern() async {
        let condition = RouteCondition.matches(pattern: #"\d{3}-\d{4}"#)

        #expect(await condition.matches(input: "Call me at 555-1234", context: nil))
        // Note: Regex finds pattern anywhere in string, so 555-1234 is found in 555-12345
        #expect(await condition.matches(input: "Call me at 555-12345", context: nil))
        #expect(await !condition.matches(input: "No phone number here", context: nil))
    }

    @Test("matches() with email pattern")
    func matchesEmailPattern() async {
        let condition = RouteCondition.matches(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)

        #expect(await condition.matches(input: "Contact: user@example.com", context: nil))
        #expect(await condition.matches(input: "test.email+tag@domain.co.uk", context: nil))
        #expect(await !condition.matches(input: "invalid-email", context: nil))
    }

    @Test("matches() with invalid regex returns false")
    func matchesInvalidPattern() async {
        let condition = RouteCondition.matches(pattern: "[invalid(regex")

        // Invalid regex should return false without throwing
        #expect(await !condition.matches(input: "any input", context: nil))
    }

    @Test("matches() with word boundary pattern")
    func matchesWordBoundary() async {
        let condition = RouteCondition.matches(pattern: #"\bhelp\b"#)

        #expect(await condition.matches(input: "I need help", context: nil))
        #expect(await condition.matches(input: "help me", context: nil))
        #expect(await !condition.matches(input: "helpful information", context: nil))
    }

    // MARK: - startsWith()

    @Test("startsWith() matches prefix - case insensitive")
    func startsWithCaseInsensitive() async {
        let condition = RouteCondition.startsWith("calculate")

        #expect(await condition.matches(input: "calculate 2+2", context: nil))
        #expect(await condition.matches(input: "Calculate the sum", context: nil))
        #expect(await condition.matches(input: "CALCULATE NOW", context: nil))
        #expect(await !condition.matches(input: "Please calculate", context: nil))
    }

    @Test("startsWith() exact match")
    func startsWithExactMatch() async {
        let condition = RouteCondition.startsWith("hello")

        #expect(await condition.matches(input: "hello", context: nil))
    }

    @Test("startsWith() empty string")
    func startsWithEmptyString() async {
        let condition = RouteCondition.startsWith("")

        // Every string starts with empty string
        #expect(await condition.matches(input: "anything", context: nil))
        #expect(await condition.matches(input: "", context: nil))
    }

    @Test("startsWith() with whitespace")
    func startsWithWhitespace() async {
        let condition = RouteCondition.startsWith("search")

        #expect(await !condition.matches(input: "  search something", context: nil))
        #expect(await condition.matches(input: "search something", context: nil))
    }

    // MARK: - endsWith()

    @Test("endsWith() matches suffix - case insensitive")
    func endsWithCaseInsensitive() async {
        let condition = RouteCondition.endsWith("?")

        #expect(await condition.matches(input: "What's the weather?", context: nil))
        #expect(await !condition.matches(input: "Tell me the weather", context: nil))
    }

    @Test("endsWith() exact match")
    func endsWithExactMatch() async {
        let condition = RouteCondition.endsWith("world")

        #expect(await condition.matches(input: "world", context: nil))
        #expect(await condition.matches(input: "WORLD", context: nil))
        #expect(await condition.matches(input: "hello world", context: nil))
    }

    @Test("endsWith() empty string")
    func endsWithEmptyString() async {
        let condition = RouteCondition.endsWith("")

        // Every string ends with empty string
        #expect(await condition.matches(input: "anything", context: nil))
        #expect(await condition.matches(input: "", context: nil))
    }

    @Test("endsWith() with multiple question marks")
    func endsWithMultipleChars() async {
        let condition = RouteCondition.endsWith("???")

        #expect(await condition.matches(input: "Really???", context: nil))
        #expect(await !condition.matches(input: "Really??", context: nil))
    }

    // MARK: - lengthInRange()

    @Test("lengthInRange() matches within range")
    func lengthInRangeMatches() async {
        let condition = RouteCondition.lengthInRange(10...100)

        #expect(await condition.matches(input: "Exactly 10", context: nil)) // 10 chars
        #expect(await condition.matches(input: "This is a medium length input", context: nil))
        #expect(await !condition.matches(input: "Short", context: nil))
        #expect(await !condition.matches(input: String(repeating: "a", count: 101), context: nil))
    }

    @Test("lengthInRange() boundary conditions")
    func lengthInRangeBoundaries() async {
        let condition = RouteCondition.lengthInRange(5...10)

        #expect(await !condition.matches(input: "1234", context: nil)) // 4 chars
        #expect(await condition.matches(input: "12345", context: nil)) // 5 chars (min)
        #expect(await condition.matches(input: "1234567890", context: nil)) // 10 chars (max)
        #expect(await !condition.matches(input: "12345678901", context: nil)) // 11 chars
    }

    @Test("lengthInRange() single value range")
    func lengthInRangeSingleValue() async {
        let condition = RouteCondition.lengthInRange(5...5)

        #expect(await condition.matches(input: "hello", context: nil))
        #expect(await !condition.matches(input: "hi", context: nil))
        #expect(await !condition.matches(input: "hello world", context: nil))
    }

    @Test("lengthInRange() with empty string")
    func lengthInRangeEmptyString() async {
        let conditionIncludesZero = RouteCondition.lengthInRange(0...10)
        let conditionExcludesZero = RouteCondition.lengthInRange(1...10)

        #expect(await conditionIncludesZero.matches(input: "", context: nil))
        #expect(await !conditionExcludesZero.matches(input: "", context: nil))
    }

    // MARK: - contextHas(key:)

    @Test("contextHas() matches when key exists")
    func contextHasKeyExists() async {
        let condition = RouteCondition.contextHas(key: "user_id")
        let context = AgentContext(input: "test")
        await context.set("user_id", value: .string("12345"))

        #expect(await condition.matches(input: "any input", context: context))
    }

    @Test("contextHas() does not match when key is missing")
    func contextHasKeyMissing() async {
        let condition = RouteCondition.contextHas(key: "user_id")
        let context = AgentContext(input: "test")

        #expect(await !condition.matches(input: "any input", context: context))
    }

    @Test("contextHas() returns false when context is nil")
    func contextHasNilContext() async {
        let condition = RouteCondition.contextHas(key: "user_id")

        #expect(await !condition.matches(input: "any input", context: nil))
    }

    @Test("contextHas() with different value types")
    func contextHasDifferentTypes() async {
        let condition = RouteCondition.contextHas(key: "data")
        let context = AgentContext(input: "test")

        // Test with different SendableValue types
        await context.set("data", value: .int(42))
        #expect(await condition.matches(input: "test", context: context))

        await context.set("data", value: .bool(true))
        #expect(await condition.matches(input: "test", context: context))

        await context.set("data", value: .array([.string("a"), .string("b")]))
        #expect(await condition.matches(input: "test", context: context))
    }

    // MARK: - always

    @Test("always matches any input")
    func alwaysMatches() async {
        let condition = RouteCondition.always

        #expect(await condition.matches(input: "anything", context: nil))
        #expect(await condition.matches(input: "", context: nil))
        #expect(await condition.matches(input: String(repeating: "x", count: 1000), context: nil))

        let context = AgentContext(input: "test")
        #expect(await condition.matches(input: "with context", context: context))
    }

    // MARK: - never

    @Test("never does not match any input")
    func neverMatches() async {
        let condition = RouteCondition.never

        #expect(await !condition.matches(input: "anything", context: nil))
        #expect(await !condition.matches(input: "", context: nil))
        #expect(await !condition.matches(input: String(repeating: "x", count: 1000), context: nil))

        let context = AgentContext(input: "test")
        #expect(await !condition.matches(input: "with context", context: context))
    }
}

// MARK: - RouteConditionCombinatorComprehensiveTests

@Suite("RouteCondition - Combinators (Comprehensive)")
struct RouteConditionCombinatorComprehensiveTests {
    // MARK: - and()

    @Test("and() both conditions true")
    func andBothTrue() async {
        let condition = RouteCondition.contains("weather")
            .and(.lengthInRange(10...100))

        #expect(await condition.matches(input: "What's the weather today?", context: nil))
    }

    @Test("and() first true, second false")
    func andFirstTrueSecondFalse() async {
        let condition = RouteCondition.contains("weather")
            .and(.lengthInRange(10...100))

        #expect(await !condition.matches(input: "weather", context: nil)) // Too short
    }

    @Test("and() first false, second true")
    func andFirstFalseSecondTrue() async {
        let condition = RouteCondition.contains("weather")
            .and(.lengthInRange(10...100))

        #expect(await !condition.matches(input: "What's the temperature today?", context: nil))
    }

    @Test("and() both conditions false")
    func andBothFalse() async {
        let condition = RouteCondition.contains("weather")
            .and(.lengthInRange(10...100))

        #expect(await !condition.matches(input: "temp", context: nil))
    }

    @Test("and() short-circuits on first false")
    func andShortCircuits() async {
        // The second condition should not be evaluated if first is false
        let condition = RouteCondition.never
            .and(.always)

        #expect(await !condition.matches(input: "test", context: nil))
    }

    // MARK: - or()

    @Test("or() both conditions true")
    func orBothTrue() async {
        let condition = RouteCondition.contains("help")
            .or(.contains("support"))

        #expect(await condition.matches(input: "I need help and support", context: nil))
    }

    @Test("or() first true, second false")
    func orFirstTrueSecondFalse() async {
        let condition = RouteCondition.contains("help")
            .or(.contains("support"))

        #expect(await condition.matches(input: "I need help", context: nil))
    }

    @Test("or() first false, second true")
    func orFirstFalseSecondTrue() async {
        let condition = RouteCondition.contains("help")
            .or(.contains("support"))

        #expect(await condition.matches(input: "I need support", context: nil))
    }

    @Test("or() both conditions false")
    func orBothFalse() async {
        let condition = RouteCondition.contains("help")
            .or(.contains("support"))

        #expect(await !condition.matches(input: "I need information", context: nil))
    }

    @Test("or() short-circuits on first true")
    func orShortCircuits() async {
        // The second condition should not be evaluated if first is true
        let condition = RouteCondition.always
            .or(.never)

        #expect(await condition.matches(input: "test", context: nil))
    }

    // MARK: - not

    @Test("not negates true condition")
    func notNegatesTrue() async {
        let condition = RouteCondition.contains("admin").not

        #expect(await !condition.matches(input: "admin panel", context: nil))
        #expect(await condition.matches(input: "user panel", context: nil))
    }

    @Test("not negates false condition")
    func notNegatesFalse() async {
        let condition = RouteCondition.contains("admin").not

        #expect(await condition.matches(input: "regular user", context: nil))
    }

    @Test("not with always becomes never")
    func notWithAlways() async {
        let condition = RouteCondition.always.not

        #expect(await !condition.matches(input: "anything", context: nil))
    }

    @Test("not with never becomes always")
    func notWithNever() async {
        let condition = RouteCondition.never.not

        #expect(await condition.matches(input: "anything", context: nil))
    }

    @Test("double negation returns to original")
    func doubleNegation() async {
        let condition = RouteCondition.contains("test").not.not

        #expect(await condition.matches(input: "this is a test", context: nil))
        #expect(await !condition.matches(input: "no match here", context: nil))
    }

    // MARK: - Complex Combinations

    @Test("chained and conditions")
    func chainedAnd() async {
        let condition = RouteCondition.contains("weather")
            .and(.startsWith("what"))
            .and(.endsWith("?"))

        #expect(await condition.matches(input: "What's the weather?", context: nil))
        #expect(await !condition.matches(input: "What's the weather", context: nil)) // Missing ?
        #expect(await !condition.matches(input: "weather question?", context: nil)) // Doesn't start with "what"
    }

    @Test("chained or conditions")
    func chainedOr() async {
        let condition = RouteCondition.contains("help")
            .or(.contains("support"))
            .or(.contains("assist"))

        #expect(await condition.matches(input: "I need help", context: nil))
        #expect(await condition.matches(input: "Customer support", context: nil))
        #expect(await condition.matches(input: "Please assist", context: nil))
        #expect(await !condition.matches(input: "Information", context: nil))
    }

    @Test("and/or combination")
    func andOrCombination() async {
        // (contains "weather" AND length 10-100) OR contains "forecast"
        let condition = RouteCondition.contains("weather")
            .and(.lengthInRange(10...100))
            .or(.contains("forecast"))

        #expect(await condition.matches(input: "What's the weather today?", context: nil))
        #expect(await condition.matches(input: "forecast", context: nil))
        #expect(await !condition.matches(input: "weather", context: nil)) // Too short
    }

    @Test("not with and combination")
    func notWithAnd() async {
        let condition = RouteCondition.contains("admin")
            .and(.contains("delete"))
            .not

        #expect(await condition.matches(input: "admin panel", context: nil))
        #expect(await condition.matches(input: "delete user", context: nil))
        #expect(await !condition.matches(input: "admin delete operation", context: nil))
    }

    @Test("complex nested combination")
    func complexNested() async {
        // ((contains "x" AND starts with "a") OR ends with "z") AND length > 5
        let condition = RouteCondition.contains("x")
            .and(.startsWith("a"))
            .or(.endsWith("z"))
            .and(.lengthInRange(5...100))

        #expect(await condition.matches(input: "axe is cool", context: nil))
        #expect(await condition.matches(input: "super jazz", context: nil))
        #expect(await !condition.matches(input: "jazz", context: nil)) // Too short
    }

    @Test("context-based combination")
    func contextBasedCombination() async {
        let condition = RouteCondition.contains("premium")
            .and(.contextHas(key: "user_tier"))

        let context = AgentContext(input: "test")
        await context.set("user_tier", value: .string("premium"))

        #expect(await condition.matches(input: "premium feature", context: context))
        #expect(await !condition.matches(input: "premium feature", context: nil))
        #expect(await !condition.matches(input: "basic feature", context: context))
    }
}

// MARK: - RouteComprehensiveTests

@Suite("Route - Initialization and Properties (Comprehensive)")
struct RouteComprehensiveTests {
    @Test("Route initialization with all parameters")
    func routeFullInitialization() {
        let agent = MockRouteAgent(name: "WeatherAgent")
        let condition = RouteCondition.contains("weather")

        let route = Route(
            condition: condition,
            agent: agent,
            name: "WeatherRoute"
        )

        #expect(route.name == "WeatherRoute")
        #expect(route.agent.instructions == "Mock agent")
    }

    @Test("Route initialization without name")
    func routeInitializationNoName() {
        let agent = MockRouteAgent(name: "TestAgent")
        let condition = RouteCondition.always

        let route = Route(
            condition: condition,
            agent: agent
        )

        #expect(route.name == nil)
    }

    @Test("Route condition matches correctly")
    func routeConditionMatches() async {
        let agent = MockRouteAgent(name: "HelpAgent")
        let condition = RouteCondition.contains("help")

        let route = Route(
            condition: condition,
            agent: agent,
            name: "HelpRoute"
        )

        #expect(await route.condition.matches(input: "I need help", context: nil))
        #expect(await !route.condition.matches(input: "Information", context: nil))
    }

    @Test("Route with complex condition")
    func routeWithComplexCondition() async {
        let agent = MockRouteAgent(name: "AdminAgent")
        let condition = RouteCondition.contains("admin")
            .and(.lengthInRange(10...200))
            .and(.startsWith("show"))

        let route = Route(
            condition: condition,
            agent: agent,
            name: "AdminRoute"
        )

        #expect(await route.condition.matches(input: "show admin dashboard", context: nil))
        #expect(await !route.condition.matches(input: "admin", context: nil))
    }

    @Test("Route with always condition")
    func routeWithAlways() async {
        let agent = MockRouteAgent(name: "FallbackAgent")
        let route = Route(
            condition: .always,
            agent: agent,
            name: "FallbackRoute"
        )

        #expect(await route.condition.matches(input: "anything", context: nil))
        #expect(route.name == "FallbackRoute")
    }

    @Test("Route with never condition")
    func routeWithNever() async {
        let agent = MockRouteAgent(name: "DisabledAgent")
        let route = Route(
            condition: .never,
            agent: agent,
            name: "DisabledRoute"
        )

        #expect(await !route.condition.matches(input: "anything", context: nil))
    }

    @Test("Multiple routes with different conditions")
    func multipleRoutes() async {
        let weatherAgent = MockRouteAgent(name: "WeatherAgent")
        let newsAgent = MockRouteAgent(name: "NewsAgent")
        let helpAgent = MockRouteAgent(name: "HelpAgent")

        let routes = [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "Weather"),
            Route(condition: .contains("news"), agent: newsAgent, name: "News"),
            Route(condition: .contains("help"), agent: helpAgent, name: "Help")
        ]

        #expect(routes.count == 3)
        #expect(routes[0].name == "Weather")
        #expect(routes[1].name == "News")
        #expect(routes[2].name == "Help")

        #expect(await routes[0].condition.matches(input: "What's the weather?", context: nil))
        #expect(await routes[1].condition.matches(input: "Latest news", context: nil))
        #expect(await routes[2].condition.matches(input: "I need help", context: nil))
    }

    @Test("Route with context-dependent condition")
    func routeWithContextCondition() async {
        let agent = MockRouteAgent(name: "PremiumAgent")
        let condition = RouteCondition.contextHas(key: "premium_user")
            .and(.contains("exclusive"))

        let route = Route(
            condition: condition,
            agent: agent,
            name: "PremiumRoute"
        )

        let context = AgentContext(input: "test")
        await context.set("premium_user", value: .bool(true))

        #expect(await route.condition.matches(input: "exclusive content", context: context))
        #expect(await !route.condition.matches(input: "exclusive content", context: nil))
    }
}

// MARK: - RouteConditionEdgeCasesComprehensiveTests

@Suite("RouteCondition - Edge Cases (Comprehensive)")
struct RouteConditionEdgeCasesComprehensiveTests {
    @Test("Empty input handling")
    func emptyInput() async {
        let contains = RouteCondition.contains("test")
        let startsWith = RouteCondition.startsWith("test")
        let endsWith = RouteCondition.endsWith("test")
        let length = RouteCondition.lengthInRange(0...10)
        let pattern = RouteCondition.matches(pattern: "test")

        #expect(await !contains.matches(input: "", context: nil))
        #expect(await !startsWith.matches(input: "", context: nil))
        #expect(await !endsWith.matches(input: "", context: nil))
        #expect(await length.matches(input: "", context: nil))
        #expect(await !pattern.matches(input: "", context: nil))
    }

    @Test("Very long input handling")
    func veryLongInput() async {
        let longInput = String(repeating: "x", count: 10000)

        let contains = RouteCondition.contains("x")
        let length = RouteCondition.lengthInRange(1000...20000)

        #expect(await contains.matches(input: longInput, context: nil))
        #expect(await length.matches(input: longInput, context: nil))
    }

    @Test("Special characters in contains")
    func specialCharactersContains() async {
        let condition = RouteCondition.contains("$100")

        #expect(await condition.matches(input: "Price is $100", context: nil))
        #expect(await !condition.matches(input: "Price is 100", context: nil))
    }

    @Test("Unicode characters")
    func unicodeCharacters() async {
        let condition = RouteCondition.contains("🌤️")

        #expect(await condition.matches(input: "Weather is 🌤️ today", context: nil))
        #expect(await !condition.matches(input: "Weather is sunny", context: nil))
    }

    @Test("Newlines and whitespace in input")
    func newlinesAndWhitespace() async {
        let condition = RouteCondition.contains("test")

        #expect(await condition.matches(input: "this is a\ntest", context: nil))
        #expect(await condition.matches(input: "  test  ", context: nil))
        #expect(await condition.matches(input: "\ttest\n", context: nil))
    }

    @Test("Regex with special characters")
    func regexSpecialCharacters() async {
        let condition = RouteCondition.matches(pattern: #"\$\d+\.\d{2}"#)

        #expect(await condition.matches(input: "Price: $19.99", context: nil))
        #expect(await !condition.matches(input: "Price: $19.9", context: nil))
    }

    @Test("Case sensitivity edge cases")
    func caseSensitivityEdgeCases() async {
        let caseSensitive = RouteCondition.contains("Test", isCaseSensitive: true)
        let caseInsensitive = RouteCondition.contains("Test", isCaseSensitive: false)

        #expect(await caseSensitive.matches(input: "Test", context: nil))
        #expect(await !caseSensitive.matches(input: "test", context: nil))
        #expect(await !caseSensitive.matches(input: "TEST", context: nil))

        #expect(await caseInsensitive.matches(input: "Test", context: nil))
        #expect(await caseInsensitive.matches(input: "test", context: nil))
        #expect(await caseInsensitive.matches(input: "TEST", context: nil))
    }

    @Test("Length boundary at zero")
    func lengthBoundaryZero() async {
        let condition = RouteCondition.lengthInRange(0...0)

        #expect(await condition.matches(input: "", context: nil))
        #expect(await !condition.matches(input: "a", context: nil))
    }

    @Test("Context with nil values")
    func contextWithNilValues() async {
        let condition = RouteCondition.contextHas(key: "test_key")
        let context = AgentContext(input: "test")

        // Key doesn't exist
        #expect(await !condition.matches(input: "input", context: context))

        // Add key
        await context.set("test_key", value: .string("value"))
        #expect(await condition.matches(input: "input", context: context))

        // Remove key
        await context.remove("test_key")
        #expect(await !condition.matches(input: "input", context: context))
    }
}
