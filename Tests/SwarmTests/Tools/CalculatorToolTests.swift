// CalculatorToolTests.swift
// SwarmTests
//
// Comprehensive integration tests for CalculatorTool.
// Note: CalculatorTool is only available on Apple platforms (requires NSExpression).

import Foundation
@testable import Swarm
import Testing

#if canImport(Darwin)

    // MARK: - CalculatorTool Integration Tests

    @Suite("CalculatorTool Integration Tests")
    struct CalculatorToolTests {
        // MARK: - Tool Protocol Conformance Tests

        @Test("Tool has correct name")
        func toolNameIsCalculator() {
            var calculator = CalculatorTool()

            #expect(calculator.name == "calculator")
        }

        @Test("Tool has description")
        func toolHasDescription() {
            var calculator = CalculatorTool()

            #expect(!calculator.description.isEmpty)
            #expect(calculator.description.contains("mathematical"))
        }

        @Test("Tool has single required expression parameter")
        func toolHasExpressionParameter() {
            var calculator = CalculatorTool()

            #expect(calculator.parameters.count == 1)

            let param = calculator.parameters[0]
            #expect(param.name == "expression")
            #expect(param.type == .string)
            #expect(param.isRequired == true)
            #expect(!param.description.isEmpty)
        }

        // MARK: - Basic Calculation Tests

        @Test("Addition: 2 + 3 equals 5.0")
        func additionCalculation() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("2 + 3")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(5.0))
        }

        @Test("Subtraction: 10 - 4 equals 6.0")
        func subtractionCalculation() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("10 - 4")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(6.0))
        }

        @Test("Multiplication: 6 * 7 equals 42.0")
        func multiplicationCalculation() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("6 * 7")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(42.0))
        }

        @Test("Division: 20 / 4 equals 5.0")
        func divisionCalculation() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("20 / 4")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(5.0))
        }

        // MARK: - Complex Expression Tests

        @Test("Complex expression with parentheses: (10 + 5) / 3 equals 5.0")
        func complexExpressionWithParentheses() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("(10 + 5) / 3")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(5.0))
        }

        @Test("Operator precedence: 2 + 3 * 4 equals 14.0")
        func operatorPrecedence() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("2 + 3 * 4")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(14.0))
        }

        @Test("Nested parentheses: ((10 + 5) * 2) - 6 equals 24.0")
        func nestedParentheses() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("((10 + 5) * 2) - 6")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(24.0))
        }

        @Test("Multiple operations: 100 / 5 + 3 * 2 equals 26.0")
        func multipleOperations() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("100 / 5 + 3 * 2")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(26.0))
        }

        // MARK: - Decimal Number Tests

        @Test("Decimal addition: 2.5 + 3.5 equals 6.0")
        func decimalAddition() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("2.5 + 3.5")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(6.0))
        }

        @Test("Decimal division: 7.5 / 2.5 equals 3.0")
        func decimalDivision() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("7.5 / 2.5")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(3.0))
        }

        @Test("Mixed decimal and integer: 10.5 + 5 equals 15.5")
        func mixedDecimalAndInteger() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("10.5 + 5")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(15.5))
        }

        // MARK: - Whitespace Handling Tests

        @Test("Expression with spaces: '  5 + 3  ' equals 8.0")
        func expressionWithSpaces() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("  5 + 3  ")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(8.0))
        }

        @Test("Expression with no spaces: '10+5' equals 15.0")
        func expressionWithoutSpaces() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("10+5")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(15.0))
        }

        // MARK: - Error Handling Tests

        @Test("Missing expression parameter throws invalidToolArguments")
        func missingExpressionParameter() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = [:]

            var thrownError: AgentError?
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                thrownError = error
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(thrownError == .invalidToolArguments(
                toolName: "calculator",
                reason: "Missing required parameter 'expression'"
            ))
        }

        @Test("Wrong parameter type throws invalidToolArguments")
        func wrongParameterType() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .int(42)]

            var thrownError: AgentError?
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                thrownError = error
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(thrownError == .invalidToolArguments(
                toolName: "calculator",
                reason: "Missing required parameter 'expression'"
            ))
        }

        @Test("Empty expression string throws invalidToolArguments")
        func emptyExpressionString() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("")]

            var thrownError: AgentError?
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                thrownError = error
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(thrownError == .invalidToolArguments(
                toolName: "calculator",
                reason: "Expression is empty"
            ))
        }

        @Test("Whitespace-only expression throws invalidToolArguments")
        func whitespaceOnlyExpression() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("   ")]

            var thrownError: AgentError?
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                thrownError = error
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(thrownError == .invalidToolArguments(
                toolName: "calculator",
                reason: "Expression is empty"
            ))
        }

        @Test("Invalid characters in expression throws invalidToolArguments")
        func invalidCharactersInExpression() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("2 + abc")]

            var caughtError = false
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                caughtError = true
                // Verify it's an invalidToolArguments error about invalid characters
                if case let .invalidToolArguments(toolName, reason) = error {
                    #expect(toolName == "calculator")
                    #expect(reason.contains("invalid characters") || reason.contains("Invalid characters"))
                } else {
                    Issue.record("Expected invalidToolArguments error but got: \(error)")
                }
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(caughtError, "Should throw error for invalid characters")
        }

        @Test("Special characters like '@' throw invalidToolArguments")
        func specialCharactersThrowError() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("5 @ 3")]

            var caughtError = false
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                caughtError = true
                if case let .invalidToolArguments(toolName, reason) = error {
                    #expect(toolName == "calculator")
                    #expect(reason.contains("invalid characters") || reason.contains("Invalid characters"))
                }
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(caughtError, "Should throw error for special characters")
        }

        @Test("Alphabetic characters throw invalidToolArguments")
        func alphabeticCharactersThrowError() async {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("x + y")]

            var caughtError = false
            do {
                _ = try await calculator.execute(arguments: arguments)
            } catch let error as AgentError {
                caughtError = true
                if case let .invalidToolArguments(toolName, _) = error {
                    #expect(toolName == "calculator")
                }
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(caughtError, "Should throw error for alphabetic characters")
        }

        // MARK: - Edge Case Tests

        @Test("Single number: '42' equals 42.0")
        func singleNumber() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("42")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(42.0))
        }

        @Test("Single decimal number: '3.14' equals 3.14")
        func singleDecimalNumber() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("3.14")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(3.14))
        }

        @Test("Negative result: 5 - 10 equals -5.0")
        func negativeResult() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("5 - 10")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(-5.0))
        }

        @Test("Division resulting in decimal: 5 / 2 equals 2.5")
        func divisionResultingInDecimal() async throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("5 / 2")]

            let result = try await calculator.execute(arguments: arguments)

            #expect(result == .double(2.5))
        }

        // MARK: - Tool Definition Tests

        @Test("Tool definition contains correct information")
        func toolDefinition() {
            var calculator = CalculatorTool()
            let definition = calculator.schema

            #expect(definition.name == "calculator")
            #expect(definition.description == calculator.description)
            #expect(definition.parameters.count == 1)
            #expect(definition.parameters[0].name == "expression")
        }

        // MARK: - Argument Validation Tests

        @Test("validateArguments succeeds with valid expression")
        func validateArgumentsSuccess() throws {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = ["expression": .string("2 + 2")]

            // Should not throw
            try calculator.validateArguments(arguments)
        }

        @Test("validateArguments fails with missing expression")
        func validateArgumentsFailure() {
            var calculator = CalculatorTool()
            let arguments: [String: SendableValue] = [:]

            var thrownError: AgentError?
            do {
                try calculator.validateArguments(arguments)
            } catch let error as AgentError {
                thrownError = error
            } catch {
                Issue.record("Expected AgentError but got: \(error)")
            }

            #expect(thrownError == .invalidToolArguments(
                toolName: "calculator",
                reason: "Missing required parameter: expression"
            ))
        }

        // MARK: - Concurrent Execution Tests

        @Test("Multiple concurrent executions produce correct results")
        func concurrentExecutions() async throws {
            var calculator = CalculatorTool()

            // Execute multiple calculations concurrently
            async let result1 = calculator.execute(arguments: ["expression": .string("10 + 5")])
            async let result2 = calculator.execute(arguments: ["expression": .string("20 * 2")])
            async let result3 = calculator.execute(arguments: ["expression": .string("100 / 4")])
            async let result4 = calculator.execute(arguments: ["expression": .string("7 - 3")])

            let results = try await [result1, result2, result3, result4]

            #expect(results[0] == .double(15.0))
            #expect(results[1] == .double(40.0))
            #expect(results[2] == .double(25.0))
            #expect(results[3] == .double(4.0))
        }

        // MARK: - Integration with Tool Registry Tests

        @Test("Calculator tool works in ToolRegistry")
        func calculatorInToolRegistry() async throws {
            var calculator = CalculatorTool()
            let registry = ToolRegistry(tools: [calculator])

            let result = try await registry.execute(
                toolNamed: "calculator",
                arguments: ["expression": .string("15 + 10")]
            )

            #expect(result == .double(25.0))
        }

        @Test("Calculator tool can be found in registry")
        func calculatorFoundInRegistry() async {
            var calculator = CalculatorTool()
            let registry = ToolRegistry(tools: [calculator])

            let hasCalculator = await registry.contains(named: "calculator")
            let tool = await registry.tool(named: "calculator")

            #expect(hasCalculator == true)
            #expect(tool?.name == "calculator")
        }
    }

#endif // canImport(Darwin)
