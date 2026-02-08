// FunctionToolTests.swift
// SwarmTests
//
// Tests for FunctionTool and ToolArguments.

import Foundation
@testable import Swarm
import XCTest

final class FunctionToolTests: XCTestCase {
    // MARK: - FunctionTool Basic Tests

    func testFunctionToolBasicExecution() async throws {
        let tool = FunctionTool(
            name: "greet",
            description: "Greets a user",
            parameters: [
                ToolParameter(name: "name", description: "User name", type: .string, isRequired: true)
            ]
        ) { args in
            let name = try args.require("name", as: String.self)
            return .string("Hello, \(name)!")
        }

        let result = try await tool.execute(arguments: ["name": .string("Alice")])
        XCTAssertEqual(result, .string("Hello, Alice!"))
    }

    func testFunctionToolNameAndDescription() {
        let tool = FunctionTool(
            name: "search",
            description: "Searches the web"
        ) { _ in .null }

        XCTAssertEqual(tool.name, "search")
        XCTAssertEqual(tool.description, "Searches the web")
    }

    func testFunctionToolDefaultParameters() {
        let tool = FunctionTool(
            name: "noop",
            description: "Does nothing"
        ) { _ in .null }

        XCTAssertTrue(tool.parameters.isEmpty)
    }

    func testFunctionToolWithMultipleParameters() async throws {
        let tool = FunctionTool(
            name: "calculate",
            description: "Basic math",
            parameters: [
                ToolParameter(name: "a", description: "First number", type: .int, isRequired: true),
                ToolParameter(name: "b", description: "Second number", type: .int, isRequired: true),
            ]
        ) { args in
            let a = try args.require("a", as: Int.self)
            let b = try args.require("b", as: Int.self)
            return .int(a + b)
        }

        let result = try await tool.execute(arguments: ["a": .int(3), "b": .int(7)])
        XCTAssertEqual(result, .int(10))
    }

    func testFunctionToolConformsToAnyJSONTool() {
        let tool: any AnyJSONTool = FunctionTool(
            name: "test",
            description: "A test tool"
        ) { _ in .null }

        XCTAssertEqual(tool.name, "test")
        XCTAssertEqual(tool.description, "A test tool")
        XCTAssertTrue(tool.isEnabled)
    }

    func testFunctionToolSchema() {
        let tool = FunctionTool(
            name: "lookup",
            description: "Look up a value",
            parameters: [
                ToolParameter(name: "key", description: "The key", type: .string, isRequired: true)
            ]
        ) { _ in .null }

        let schema = tool.schema
        XCTAssertEqual(schema.name, "lookup")
        XCTAssertEqual(schema.description, "Look up a value")
        XCTAssertEqual(schema.parameters.count, 1)
    }

    // MARK: - ToolArguments Tests

    func testToolArgumentsRequire() throws {
        let args = ToolArguments(["city": .string("Tokyo"), "count": .int(5)])
        let city: String = try args.require("city", as: String.self)
        let count: Int = try args.require("count", as: Int.self)

        XCTAssertEqual(city, "Tokyo")
        XCTAssertEqual(count, 5)
    }

    func testToolArgumentsRequireMissingKeyThrows() {
        let args = ToolArguments([:])
        XCTAssertThrowsError(try args.require("missing", as: String.self))
    }

    func testToolArgumentsRequireWrongTypeThrows() {
        let args = ToolArguments(["value": .int(42)])
        XCTAssertThrowsError(try args.require("value", as: String.self))
    }

    func testToolArgumentsOptional() {
        let args = ToolArguments(["name": .string("Alice")])
        let name: String? = args.optional("name", as: String.self)
        let missing: String? = args.optional("missing", as: String.self)

        XCTAssertEqual(name, "Alice")
        XCTAssertNil(missing)
    }

    func testToolArgumentsOptionalWrongTypeReturnsNil() {
        let args = ToolArguments(["value": .int(42)])
        let result: String? = args.optional("value", as: String.self)
        XCTAssertNil(result)
    }

    func testToolArgumentsStringWithDefault() {
        let args = ToolArguments(["greeting": .string("hi")])
        XCTAssertEqual(args.string("greeting", default: "hello"), "hi")
        XCTAssertEqual(args.string("missing", default: "hello"), "hello")
    }

    func testToolArgumentsIntWithDefault() {
        let args = ToolArguments(["count": .int(10)])
        XCTAssertEqual(args.int("count", default: 0), 10)
        XCTAssertEqual(args.int("missing", default: 0), 0)
    }
}
