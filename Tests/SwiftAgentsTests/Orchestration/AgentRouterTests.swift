// AgentRouterTests.swift
// SwiftAgentsTests
//
// Comprehensive tests for AgentRouter actor - condition-based routing.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - TestAgent

/// Simple test agent that returns a predefined response.
final class TestAgent: AgentRuntime, @unchecked Sendable {
    let name: String
    let responsePrefix: String
    let tools: [any AnyJSONTool] = []
    let instructions: String
    let configuration: AgentConfiguration

    var memory: (any Memory)? { nil }
    var inferenceProvider: (any InferenceProvider)? { nil }

    init(name: String, responsePrefix: String) {
        self.name = name
        self.responsePrefix = responsePrefix
        instructions = "Test agent: \(name)"
        configuration = .default
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        try await Task.sleep(for: .milliseconds(10))
        return AgentResult(
            output: "\(responsePrefix): \(input)",
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            duration: .milliseconds(10),
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 10),
            metadata: ["agent_name": .string(name)]
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

// MARK: - AgentRouterInitializationTests

@Suite("AgentRouter - Initialization")
struct AgentRouterInitializationTests {
    @Test("Array-based initializer")
    func arrayBasedInitializer() {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute"),
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        ])

        #expect(router.tools.isEmpty)
        #expect(router.instructions.contains("Routes requests"))
    }

    @Test("Array-based initializer with fallback")
    func arrayBasedInitializerWithFallback() {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [
                Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            ],
            fallbackAgent: fallbackAgent
        )

        let description = router.description
        #expect(description.contains("hasFallback: true"))
    }

    @Test("DSL-based initializer")
    func dslBasedInitializer() {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")

        let router = AgentRouter {
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        }

        #expect(router.tools.isEmpty)
        #expect(router.instructions.contains("Routes requests"))
    }

    @Test("DSL-based initializer with fallback")
    func dslBasedInitializerWithFallback() {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(fallbackAgent: fallbackAgent) {
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        }

        let description = router.description
        #expect(description.contains("hasFallback: true"))
        #expect(description.contains("routes: 2"))
    }

    @Test("Empty routes with fallback")
    func emptyRoutesWithFallback() {
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [],
            fallbackAgent: fallbackAgent
        )

        let description = router.description
        #expect(description.contains("routes: 0"))
        #expect(description.contains("hasFallback: true"))
    }

    @Test("Empty routes without fallback")
    func emptyRoutesWithoutFallback() {
        let router = AgentRouter(routes: [])

        let description = router.description
        #expect(description.contains("routes: 0"))
        #expect(description.contains("hasFallback: false"))
    }
}

// MARK: - AgentRouterRoutingTests

@Suite("AgentRouter - Routing Logic")
struct AgentRouterRoutingTests {
    @Test("Routes to first matching route")
    func routesToFirstMatch() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute"),
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        ])

        let result = try await router.run("What's the weather today?")

        #expect(result.output.starts(with: "Weather:"))
        #expect(result.metadata["router.matched_route"]?.stringValue == "WeatherRoute")
    }

    @Test("Routes to second route when first doesn't match")
    func routesToSecondRoute() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute"),
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        ])

        let result = try await router.run("What's the latest news?")

        #expect(result.output.starts(with: "News:"))
        #expect(result.metadata["router.matched_route"]?.stringValue == "NewsRoute")
    }

    @Test("First matching route wins with overlapping conditions")
    func firstMatchWinsWithOverlap() async throws {
        let agent1 = TestAgent(name: "agent1", responsePrefix: "Agent1")
        let agent2 = TestAgent(name: "agent2", responsePrefix: "Agent2")

        // Both conditions would match "weather", but first should win
        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: agent1, name: "Route1"),
            Route(condition: .always, agent: agent2, name: "Route2")
        ])

        let result = try await router.run("What's the weather?")

        #expect(result.output.starts(with: "Agent1:"))
        #expect(result.metadata["router.matched_route"]?.stringValue == "Route1")
    }

    @Test("Routes with complex conditions")
    func routesWithComplexConditions() async throws {
        let shortAgent = TestAgent(name: "short", responsePrefix: "Short")
        let longAgent = TestAgent(name: "long", responsePrefix: "Long")

        let router = AgentRouter(routes: [
            Route(
                condition: .contains("weather").and(.lengthInRange(1...20)),
                agent: shortAgent,
                name: "ShortRoute"
            ),
            Route(
                condition: .contains("weather").and(.lengthInRange(21...1000)),
                agent: longAgent,
                name: "LongRoute"
            )
        ])

        let shortResult = try await router.run("weather?")
        #expect(shortResult.output.starts(with: "Short:"))
        #expect(shortResult.metadata["router.matched_route"]?.stringValue == "ShortRoute")

        let longResult = try await router.run("Can you tell me about the weather forecast for tomorrow?")
        #expect(longResult.output.starts(with: "Long:"))
        #expect(longResult.metadata["router.matched_route"]?.stringValue == "LongRoute")
    }

    @Test("Routes to multiple different agents sequentially")
    func routesToMultipleAgents() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")
        let sportsAgent = TestAgent(name: "sports", responsePrefix: "Sports")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute"),
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute"),
            Route(condition: .contains("sports"), agent: sportsAgent, name: "SportsRoute")
        ])

        let weatherResult = try await router.run("weather forecast")
        #expect(weatherResult.output.starts(with: "Weather:"))

        let newsResult = try await router.run("latest news")
        #expect(newsResult.output.starts(with: "News:"))

        let sportsResult = try await router.run("sports scores")
        #expect(sportsResult.output.starts(with: "Sports:"))
    }
}

// MARK: - AgentRouterFallbackTests

@Suite("AgentRouter - Fallback Behavior")
struct AgentRouterFallbackTests {
    @Test("Uses fallback when no route matches")
    func usesFallbackWhenNoMatch() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [
                Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            ],
            fallbackAgent: fallbackAgent
        )

        let result = try await router.run("Tell me about sports")

        #expect(result.output.starts(with: "Fallback:"))
        #expect(result.output.contains("sports"))
    }

    @Test("Throws routingFailed when no match and no fallback")
    func throwsWhenNoMatchNoFallback() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
        ])

        do {
            _ = try await router.run("Tell me about sports")
            Issue.record("Expected routingFailed error but succeeded")
        } catch let error as OrchestrationError {
            switch error {
            case let .routingFailed(reason):
                #expect(reason.contains("no fallback") || reason.contains("No route matched"))
            default:
                Issue.record("Expected routingFailed but got: \(error)")
            }
        } catch {
            Issue.record("Expected OrchestrationError but got: \(error)")
        }
    }

    @Test("Uses fallback when routes are empty")
    func usesFallbackWhenRoutesEmpty() async throws {
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [],
            fallbackAgent: fallbackAgent
        )

        let result = try await router.run("Any query")

        #expect(result.output.starts(with: "Fallback:"))
    }

    @Test("Throws when routes are empty and no fallback")
    func throwsWhenEmptyRoutesNoFallback() async throws {
        let router = AgentRouter(routes: [])

        do {
            _ = try await router.run("Any query")
            Issue.record("Expected routingFailed error but succeeded")
        } catch let error as OrchestrationError {
            switch error {
            case .routingFailed:
                break // Expected
            default:
                Issue.record("Expected routingFailed but got: \(error)")
            }
        } catch {
            Issue.record("Expected OrchestrationError but got: \(error)")
        }
    }

    @Test("Fallback receives original input")
    func fallbackReceivesOriginalInput() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [
                Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            ],
            fallbackAgent: fallbackAgent
        )

        let testInput = "Tell me something interesting"
        let result = try await router.run(testInput)

        #expect(result.output.contains(testInput))
    }
}

// MARK: - AgentRouterMetadataTests

@Suite("AgentRouter - Metadata and Duration")
struct AgentRouterMetadataTests {
    @Test("Adds matched route name to metadata")
    func addsMatchedRouteToMetadata() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        let result = try await router.run("test")

        #expect(result.metadata["router.matched_route"] != nil)
        #expect(result.metadata["router.matched_route"]?.stringValue == "TestRoute")
    }

    @Test("Adds duration to metadata")
    func addsDurationToMetadata() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        let result = try await router.run("test")

        #expect(result.metadata["router.duration"] != nil)
        #expect(result.metadata["router.duration"]?.doubleValue != nil)

        if let duration = result.metadata["router.duration"]?.doubleValue {
            #expect(duration >= 0.0)
        }
    }

    @Test("Preserves agent metadata")
    func preservesAgentMetadata() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        let result = try await router.run("test")

        // Should have both router and agent metadata
        #expect(result.metadata["router.matched_route"] != nil)
        #expect(result.metadata["agent_name"] != nil)
        #expect(result.metadata["agent_name"]?.stringValue == "test")
    }

    @Test("Adds unnamed route to metadata")
    func addsUnnamedRouteToMetadata() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent) // No name provided
        ])

        let result = try await router.run("test")

        #expect(result.metadata["router.matched_route"]?.stringValue == "unnamed")
    }
}

// MARK: - AgentRouterCancellationTests

@Suite("AgentRouter - Cancellation")
struct AgentRouterCancellationTests {
    @Test("Cancel sets cancelled flag")
    func cancelSetsCancelledFlag() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        await router.cancel()

        do {
            _ = try await router.run("test")
            Issue.record("Expected cancelled error but succeeded")
        } catch let error as AgentError {
            switch error {
            case .cancelled:
                break // Expected
            default:
                Issue.record("Expected cancelled but got: \(error)")
            }
        } catch {
            Issue.record("Expected AgentError but got: \(error)")
        }
    }

    @Test("Cancel before any execution")
    func cancelBeforeExecution() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        // Cancel immediately
        await router.cancel()

        // Try to run
        do {
            _ = try await router.run("test")
            Issue.record("Expected cancelled error")
        } catch let error as AgentError {
            #expect(error == .cancelled)
        }
    }
}

// MARK: - AgentRouterStreamingTests

@Suite("AgentRouter - Streaming")
struct AgentRouterStreamingTests {
    @Test("Stream emits events")
    func streamEmitsEvents() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        var events: [AgentEvent] = []
        for try await event in router.stream("test query") {
            events.append(event)
        }

        #expect(!events.isEmpty)

        // Should have started event
        let hasStarted = events.contains { event in
            if case .started = event { true } else { false }
        }
        #expect(hasStarted)

        // Should have completed event
        let hasCompleted = events.contains { event in
            if case .completed = event { true } else { false }
        }
        #expect(hasCompleted)
    }

    @Test("Stream uses fallback when no match")
    func streamUsesFallback() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let fallbackAgent = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let router = AgentRouter(
            routes: [
                Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
            ],
            fallbackAgent: fallbackAgent
        )

        var completed = false
        for try await event in router.stream("sports news") {
            if case let .completed(result) = event {
                #expect(result.output.starts(with: "Fallback:"))
                completed = true
            }
        }

        #expect(completed)
    }

    @Test("Stream fails when no match and no fallback")
    func streamFailsWhenNoMatchNoFallback() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute")
        ])

        var hasFailed = false
        do {
            for try await event in router.stream("sports news") {
                if case let .failed(error) = event,
                   case let .internalError(reason) = error
                {
                    #expect(reason.contains("no fallback") || reason.contains("No route matched"))
                    hasFailed = true
                }
            }
        } catch let error as AgentError {
            if case let .internalError(reason) = error {
                #expect(reason.contains("no fallback") || reason.contains("No route matched"))
                hasFailed = true
            } else {
                throw error
            }
        }

        #expect(hasFailed)
    }

    @Test("Stream cancelled after cancel() called")
    func streamCancelledAfterCancel() async throws {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        await router.cancel()

        var hasCancelled = false
        do {
            for try await event in router.stream("test") {
                if case let .failed(error) = event, error == .cancelled {
                    hasCancelled = true
                }
            }
        } catch let error as AgentError {
            if error == .cancelled {
                hasCancelled = true
            } else {
                throw error
            }
        }

        #expect(hasCancelled)
    }

    @Test("Stream routes to correct agent")
    func streamRoutesToCorrectAgent() async throws {
        let weatherAgent = TestAgent(name: "weather", responsePrefix: "Weather")
        let newsAgent = TestAgent(name: "news", responsePrefix: "News")

        let router = AgentRouter(routes: [
            Route(condition: .contains("weather"), agent: weatherAgent, name: "WeatherRoute"),
            Route(condition: .contains("news"), agent: newsAgent, name: "NewsRoute")
        ])

        var weatherCompleted = false
        for try await event in router.stream("What's the weather?") {
            if case let .completed(result) = event {
                #expect(result.output.starts(with: "Weather:"))
                weatherCompleted = true
            }
        }
        #expect(weatherCompleted)

        var newsCompleted = false
        for try await event in router.stream("What's the news?") {
            if case let .completed(result) = event {
                #expect(result.output.starts(with: "News:"))
                newsCompleted = true
            }
        }
        #expect(newsCompleted)
    }
}

// MARK: - AgentRouterDescriptionTests

@Suite("AgentRouter - Description")
struct AgentRouterDescriptionTests {
    @Test("Description shows route count")
    func descriptionShowsRouteCount() {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let router = AgentRouter(routes: [
            Route(condition: .always, agent: agent, name: "TestRoute")
        ])

        let description = router.description
        #expect(description.contains("AgentRouter"))
        #expect(description.contains("routes: 1"))
    }

    @Test("Description shows fallback status")
    func descriptionShowsFallbackStatus() {
        let agent = TestAgent(name: "test", responsePrefix: "Test")
        let fallback = TestAgent(name: "fallback", responsePrefix: "Fallback")

        let withFallback = AgentRouter(
            routes: [Route(condition: .always, agent: agent, name: "TestRoute")],
            fallbackAgent: fallback
        )
        #expect(withFallback.description.contains("hasFallback: true"))

        let withoutFallback = AgentRouter(
            routes: [Route(condition: .always, agent: agent, name: "TestRoute")]
        )
        #expect(withoutFallback.description.contains("hasFallback: false"))
    }

    @Test("Description with multiple routes")
    func descriptionWithMultipleRoutes() {
        let agent1 = TestAgent(name: "agent1", responsePrefix: "A1")
        let agent2 = TestAgent(name: "agent2", responsePrefix: "A2")
        let agent3 = TestAgent(name: "agent3", responsePrefix: "A3")

        let router = AgentRouter(routes: [
            Route(condition: .contains("a"), agent: agent1, name: "Route1"),
            Route(condition: .contains("b"), agent: agent2, name: "Route2"),
            Route(condition: .contains("c"), agent: agent3, name: "Route3")
        ])

        let description = router.description
        #expect(description.contains("routes: 3"))
    }
}
