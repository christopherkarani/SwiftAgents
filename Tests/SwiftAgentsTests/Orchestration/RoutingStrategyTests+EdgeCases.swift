// RoutingStrategyTests+EdgeCases.swift
// SwiftAgentsTests
//
// Edge cases and advanced scoring tests for routing strategies

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - KeywordRoutingStrategy Edge Cases and Advanced Tests

extension KeywordRoutingStrategyTests {

    // MARK: - Confidence Threshold Tests

    @Test("Minimum confidence threshold respected")
    func testMinimumConfidenceThreshold() async throws {
        let strategy = KeywordRoutingStrategy(minimumConfidence: 0.9)
        let agents = createTestAgents()

        // Weak match should fall below threshold
        let decision = try await strategy.selectAgent(
            for: "calculator",  // Only name match, low score
            from: agents,
            context: nil
        )

        // Should fallback to first agent with 0 confidence
        #expect(decision.confidence == 0.0)
        #expect(decision.reasoning?.contains("fallback") == true)
    }

    @Test("Returns nil when no match meets threshold")
    func testNoMatchMeetsThreshold() async throws {
        let strategy = KeywordRoutingStrategy(minimumConfidence: 1.0)
        let agents = createTestAgents()

        // No perfect match possible
        let decision = try await strategy.selectAgent(
            for: "unrelated query",
            from: agents,
            context: nil
        )

        // Falls back to first agent with 0 confidence
        #expect(decision.confidence == 0.0)
        #expect(decision.selectedAgentName == agents[0].name)
    }

    // MARK: - Scoring Algorithm Tests

    @Test("Scoring algorithm verification - keyword worth 10 points")
    func testScoringAlgorithmKeyword() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "agent1",
                description: "Test",
                capabilities: [],
                keywords: ["unique_keyword"]
            ),
            AgentDescription(
                name: "agent2",
                description: "Test",
                capabilities: [],
                keywords: []
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "unique_keyword",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "agent1")
        #expect(decision.reasoning?.contains("10") == true) // 10 points for keyword
    }

    @Test("Scoring algorithm verification - capability worth 5 points")
    func testScoringAlgorithmCapability() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "agent1",
                description: "Test",
                capabilities: ["unique_capability"],
                keywords: []
            ),
            AgentDescription(
                name: "agent2",
                description: "Test",
                capabilities: [],
                keywords: []
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "unique_capability",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "agent1")
        #expect(decision.reasoning?.contains("5") == true) // 5 points for capability
    }

    @Test("Scoring algorithm verification - name worth 3 points")
    func testScoringAlgorithmName() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "unique_agent",
                description: "Test",
                capabilities: [],
                keywords: []
            ),
            AgentDescription(
                name: "other_agent",
                description: "Test",
                capabilities: [],
                keywords: []
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "unique_agent",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "unique_agent")
        #expect(decision.reasoning?.contains("3") == true) // 3 points for name
    }

    @Test("Scoring algorithm - keywords score higher than capabilities")
    func testScoringKeywordScoreHigher() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "agent1",
                description: "Test",
                capabilities: ["match"],  // 5 points
                keywords: []
            ),
            AgentDescription(
                name: "agent2",
                description: "Test",
                capabilities: [],
                keywords: ["match"]  // 10 points - keywords score higher
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "match",
            from: agents,
            context: nil
        )

        // Keywords score 10 points, capabilities only 5
        #expect(decision.selectedAgentName == "agent2")
    }

    // MARK: - Multiple Matching Agents Tests

    @Test("Multiple matching agents - picks highest score")
    func testMultipleMatchingAgentsPicksHighest() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "agent1",
                description: "Test",
                capabilities: [],
                keywords: ["test"]  // 10 points
            ),
            AgentDescription(
                name: "agent2",
                description: "Test",
                capabilities: [],
                keywords: ["test", "example"]  // 20 points for "test example"
            ),
            AgentDescription(
                name: "agent3",
                description: "Test",
                capabilities: ["test"],  // 5 points
                keywords: []
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "test example query",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "agent2")
    }

    // MARK: - Edge Cases

    @Test("Empty agents array throws error")
    func testEmptyAgentsArrayThrows() async throws {
        let strategy = KeywordRoutingStrategy()

        await #expect(throws: AgentError.self, performing: {
            _ = try await strategy.selectAgent(
                for: "test query",
                from: [],
                context: nil
            )
        })
    }

    @Test("Single agent always selected")
    func testSingleAgentAlwaysSelected() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "only_agent",
                description: "The only agent",
                capabilities: [],
                keywords: []
            )
        ]

        let decision = try await strategy.selectAgent(
            for: "any query at all",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "only_agent")
        #expect(decision.confidence == 1.0)
        #expect(decision.reasoning == "Only one agent available")
    }

    @Test("No keyword matches uses fallback")
    func testNoKeywordMatchesUsesFallback() async throws {
        let strategy = KeywordRoutingStrategy()
        let agents = createTestAgents()

        let decision = try await strategy.selectAgent(
            for: "xyz abc def completely unrelated",
            from: agents,
            context: nil
        )

        // Should fallback to first agent
        #expect(decision.selectedAgentName == agents[0].name)
        #expect(decision.confidence == 0.0)
        #expect(decision.reasoning?.contains("No keyword matches") == true)
    }

    @Test("Empty input string")
    func testEmptyInputString() async throws {
        let strategy = KeywordRoutingStrategy()
        let agents = createTestAgents()

        let decision = try await strategy.selectAgent(
            for: "",
            from: agents,
            context: nil
        )

        // Should fallback to first agent
        #expect(decision.selectedAgentName == agents[0].name)
        #expect(decision.confidence == 0.0)
    }

    @Test("Whitespace-only input")
    func testWhitespaceOnlyInput() async throws {
        let strategy = KeywordRoutingStrategy()
        let agents = createTestAgents()

        let decision = try await strategy.selectAgent(
            for: "   \n\t  ",
            from: agents,
            context: nil
        )

        // Should fallback to first agent
        #expect(decision.selectedAgentName == agents[0].name)
        #expect(decision.confidence == 0.0)
    }

    @Test("Partial keyword matches")
    func testPartialKeywordMatches() async throws {
        let strategy = KeywordRoutingStrategy()
        let agents = createTestAgents()

        // "calculating" contains "calculate"
        let decision = try await strategy.selectAgent(
            for: "I am calculating something",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "calculator")
    }

    @Test("Confidence calculation with maximum score")
    func testConfidenceCalculationMaxScore() async throws {
        let strategy = KeywordRoutingStrategy()

        let agents = [
            AgentDescription(
                name: "perfect_match",
                description: "Test",
                capabilities: ["cap1", "cap2"],
                keywords: ["key1", "key2"]
            )
        ]

        // Match all keywords, all capabilities, and name
        let decision = try await strategy.selectAgent(
            for: "perfect_match key1 key2 cap1 cap2",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "perfect_match")
        // Max score = 2*10 (keywords) + 2*5 (capabilities) + 3 (name) = 33
        // Confidence should be close to 1.0
        #expect(decision.confidence > 0.9)
    }

    // MARK: - Context Parameter Tests

    @Test("Context parameter is optional and unused")
    func testContextParameterUnused() async throws {
        let strategy = KeywordRoutingStrategy()
        let agents = createTestAgents()

        // Context is passed but currently unused by KeywordRoutingStrategy
        let decision = try await strategy.selectAgent(
            for: "weather forecast",
            from: agents,
            context: nil
        )

        #expect(decision.selectedAgentName == "weather")
    }
}
