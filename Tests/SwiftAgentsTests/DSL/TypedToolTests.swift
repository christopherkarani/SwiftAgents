// TypedToolTests.swift
// SwiftAgentsTests
//
// Tests for TypedTool generic protocol with type-safe outputs.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - TypedToolTests

@Suite("TypedTool Protocol Tests")
struct TypedToolTests {
    // MARK: - Basic TypedTool Usage

    @Test("TypedTool returns strongly typed output")
    func typedToolReturnsStronglyTypedOutput() async throws {
        let tool = WeatherTypedTool()

        let result: WeatherData = try await tool.executeTyped(arguments: [
            "location": .string("San Francisco")
        ])

        #expect(result.temperature == 72.0)
        #expect(result.condition == "Sunny")
        #expect(result.location == "San Francisco")
    }

    @Test("TypedTool conforms to base Tool protocol")
    func typedToolConformsToBaseTool() async throws {
        let tool = WeatherTypedTool()

        // Should work with the base AnyJSONTool protocol
        let baseTool: any AnyJSONTool = tool
        let result = try await baseTool.execute(arguments: [
            "location": .string("New York")
        ])

        // Result should be a dictionary (auto-encoded from WeatherData)
        #expect(result.dictionaryValue != nil)
    }

    @Test("TypedTool with Codable output")
    func typedToolWithCodableOutput() async throws {
        let tool = UserInfoTypedTool()

        let result: UserInfo = try await tool.executeTyped(arguments: [
            "userId": .string("123")
        ])

        #expect(result.id == "123")
        #expect(result.name == "Test User")
    }

    // MARK: - TypedTool Error Handling

    @Test("TypedTool throws on invalid arguments")
    func typedToolThrowsOnInvalidArguments() async {
        let tool = WeatherTypedTool()

        do {
            _ = try await tool.executeTyped(arguments: [:])
            Issue.record("Expected error for missing location")
        } catch let error as AgentError {
            switch error {
            case let .invalidToolArguments(toolName, _):
                #expect(toolName == "weather_typed")
            default:
                Issue.record("Expected invalidToolArguments error")
            }
        } catch {
            Issue.record("Expected AgentError")
        }
    }

    @Test("TypedTool validates argument types at runtime")
    func typedToolValidatesArgumentTypes() async {
        let tool = CalculatorTypedTool()

        do {
            // Pass string instead of expected expression
            _ = try await tool.executeTyped(arguments: [
                "expression": .int(42) // Should be string
            ])
            Issue.record("Expected error for wrong argument type")
        } catch {
            // Expected error
            #expect(true)
        }
    }

    // MARK: - TypedTool in ToolRegistry

    @Test("TypedTool works with ToolRegistry")
    func typedToolWorksWithRegistry() async throws {
        let registry = ToolRegistry()
        let tool = WeatherTypedTool()

        await registry.register(tool)

        // Execute via registry (returns SendableValue)
        let result = try await registry.execute(
            toolNamed: "weather_typed",
            arguments: ["location": .string("Boston")]
        )

        #expect(result.dictionaryValue != nil)
    }

    // MARK: - TypedTool with Complex Types

    @Test("TypedTool with array output")
    func typedToolWithArrayOutput() async throws {
        let tool = SearchResultsTypedTool()

        let results: [SearchResult] = try await tool.executeTyped(arguments: [
            "query": .string("swift programming")
        ])

        #expect(!results.isEmpty)
        #expect(results.first?.title.contains("Swift") == true)
    }

    @Test("TypedTool with nested types")
    func typedToolWithNestedTypes() async throws {
        let tool = OrderTypedTool()

        let order: Order = try await tool.executeTyped(arguments: [
            "orderId": .string("ORD-123")
        ])

        #expect(order.id == "ORD-123")
        #expect(!order.items.isEmpty)
        #expect(!order.customer.name.isEmpty)
    }

    // MARK: - TypedTool Output Type Inference

    @Test("TypedTool output type is inferred from protocol")
    func typedToolOutputTypeInference() async throws {
        // The Output associated type should be inferred
        let tool = WeatherTypedTool()

        // Type should be inferred as WeatherData
        let result = try await tool.executeTyped(arguments: [
            "location": .string("Miami")
        ])

        // Compiler should know this is WeatherData
        let temp: Double = result.temperature
        #expect(temp > 0)
    }
}

// MARK: - WeatherData

/// Weather data returned by WeatherTypedTool
struct WeatherData: Sendable, Codable, Equatable {
    let temperature: Double
    let condition: String
    let location: String
}

// MARK: - WeatherTypedTool

/// Mock TypedTool for weather
struct WeatherTypedTool: TypedTool {
    typealias Output = WeatherData

    let name = "weather_typed"
    let description = "Gets weather with typed output"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "location", description: "City name", type: .string)
    ]

    func executeTyped(arguments: [String: SendableValue]) async throws -> WeatherData {
        guard let location = arguments["location"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing location")
        }
        return WeatherData(temperature: 72.0, condition: "Sunny", location: location)
    }
}

// MARK: - UserInfo

/// User info returned by UserInfoTypedTool
struct UserInfo: Sendable, Codable, Equatable {
    let id: String
    let name: String
    let email: String?
}

// MARK: - UserInfoTypedTool

/// Mock TypedTool for user info
struct UserInfoTypedTool: TypedTool {
    typealias Output = UserInfo

    let name = "user_info"
    let description = "Gets user info"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "userId", description: "User ID", type: .string)
    ]

    func executeTyped(arguments: [String: SendableValue]) async throws -> UserInfo {
        guard let userId = arguments["userId"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing userId")
        }
        return UserInfo(id: userId, name: "Test User", email: "test@example.com")
    }
}

// MARK: - CalculatorTypedTool

/// Calculator with typed output
struct CalculatorTypedTool: TypedTool {
    typealias Output = CalculationResult

    let name = "calculator_typed"
    let description = "Calculates expressions"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "expression", description: "Math expression", type: .string)
    ]

    func executeTyped(arguments: [String: SendableValue]) async throws -> CalculationResult {
        guard let expr = arguments["expression"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing expression")
        }
        return CalculationResult(expression: expr, result: 42.0)
    }
}

// MARK: - CalculationResult

struct CalculationResult: Sendable, Codable, Equatable {
    let expression: String
    let result: Double
}

// MARK: - SearchResultsTypedTool

/// Search results tool
struct SearchResultsTypedTool: TypedTool {
    typealias Output = [SearchResult]

    let name = "search"
    let description = "Searches for items"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "query", description: "Search query", type: .string)
    ]

    func executeTyped(arguments _: [String: SendableValue]) async throws -> [SearchResult] {
        [
            SearchResult(title: "Swift Programming Guide", url: "https://example.com/1"),
            SearchResult(title: "Swift Best Practices", url: "https://example.com/2")
        ]
    }
}

// MARK: - SearchResult

struct SearchResult: Sendable, Codable, Equatable {
    let title: String
    let url: String
}

// MARK: - OrderTypedTool

/// Order with nested types
struct OrderTypedTool: TypedTool {
    typealias Output = Order

    let name = "order"
    let description = "Gets order info"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "orderId", description: "Order ID", type: .string)
    ]

    func executeTyped(arguments: [String: SendableValue]) async throws -> Order {
        Order(
            id: arguments["orderId"]?.stringValue ?? "unknown",
            items: [OrderItem(productId: "P1", quantity: 2, price: 29.99)],
            customer: Customer(name: "John Doe", email: "john@example.com")
        )
    }
}

// MARK: - Order

struct Order: Sendable, Codable, Equatable {
    let id: String
    let items: [OrderItem]
    let customer: Customer
}

// MARK: - OrderItem

struct OrderItem: Sendable, Codable, Equatable {
    let productId: String
    let quantity: Int
    let price: Double
}

// MARK: - Customer

struct Customer: Sendable, Codable, Equatable {
    let name: String
    let email: String
}
