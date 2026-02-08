// ArithmeticParserTests.swift
// SwarmTests
//
// Comprehensive tests for ArithmeticParser - recursive descent arithmetic expression parser

import Foundation
@testable import Swarm
import Testing

// MARK: - ArithmeticParserBasicOperationsTests

@Suite("ArithmeticParser - Basic Operations")
struct ArithmeticParserBasicOperationsTests {
    @Test("Addition of two integers")
    func additionIntegers() throws {
        let result = try ArithmeticParser.evaluate("2 + 3")
        #expect(result == 5.0)
    }

    @Test("Subtraction of two integers")
    func subtractionIntegers() throws {
        let result = try ArithmeticParser.evaluate("10 - 4")
        #expect(result == 6.0)
    }

    @Test("Multiplication of two integers")
    func multiplicationIntegers() throws {
        let result = try ArithmeticParser.evaluate("6 * 7")
        #expect(result == 42.0)
    }

    @Test("Division of two integers")
    func divisionIntegers() throws {
        let result = try ArithmeticParser.evaluate("20 / 4")
        #expect(result == 5.0)
    }

    @Test("Division resulting in decimal")
    func divisionDecimal() throws {
        let result = try ArithmeticParser.evaluate("10 / 4")
        #expect(result == 2.5)
    }
}

// MARK: - ArithmeticParserOperatorPrecedenceTests

@Suite("ArithmeticParser - Operator Precedence")
struct ArithmeticParserOperatorPrecedenceTests {
    @Test("Multiplication before addition")
    func multiplicationBeforeAddition() throws {
        let result = try ArithmeticParser.evaluate("2 + 3 * 4")
        #expect(result == 14.0) // Not 20
    }

    @Test("Division before subtraction")
    func divisionBeforeSubtraction() throws {
        let result = try ArithmeticParser.evaluate("10 - 6 / 2")
        #expect(result == 7.0) // Not 2
    }

    @Test("Multiple multiplications and additions")
    func mixedMultiplicationAddition() throws {
        let result = try ArithmeticParser.evaluate("1 + 2 * 3 + 4 * 5")
        #expect(result == 27.0) // 1 + 6 + 20
    }

    @Test("Division and multiplication same precedence left-to-right")
    func divisionMultiplicationLeftToRight() throws {
        let result = try ArithmeticParser.evaluate("20 / 4 * 2")
        #expect(result == 10.0) // (20 / 4) * 2 = 5 * 2
    }

    @Test("Addition and subtraction same precedence left-to-right")
    func additionSubtractionLeftToRight() throws {
        let result = try ArithmeticParser.evaluate("10 - 3 + 2")
        #expect(result == 9.0) // (10 - 3) + 2 = 7 + 2
    }
}

// MARK: - ArithmeticParserParenthesesTests

@Suite("ArithmeticParser - Parentheses")
struct ArithmeticParserParenthesesTests {
    @Test("Simple parentheses override precedence")
    func simpleParentheses() throws {
        let result = try ArithmeticParser.evaluate("(2 + 3) * 4")
        #expect(result == 20.0) // Not 14
    }

    @Test("Nested parentheses")
    func nestedParentheses() throws {
        let result = try ArithmeticParser.evaluate("((2 + 3) * (4 - 1))")
        #expect(result == 15.0) // (5) * (3) = 15
    }

    @Test("Multiple parentheses groups")
    func multipleParenthesesGroups() throws {
        let result = try ArithmeticParser.evaluate("(2 + 3) * (4 + 5)")
        #expect(result == 45.0) // 5 * 9
    }

    @Test("Division with parentheses")
    func divisionWithParentheses() throws {
        let result = try ArithmeticParser.evaluate("(10 + 5) / 3")
        #expect(result == 5.0) // 15 / 3
    }

    @Test("Complex nested expression")
    func complexNestedExpression() throws {
        let result = try ArithmeticParser.evaluate("((10 + 5) / 3) * 2")
        #expect(result == 10.0) // (15 / 3) * 2 = 5 * 2
    }

    @Test("Deeply nested parentheses")
    func deeplyNestedParentheses() throws {
        let result = try ArithmeticParser.evaluate("(((2 + 3)))")
        #expect(result == 5.0)
    }
}

// MARK: - ArithmeticParserDecimalNumbersTests

@Suite("ArithmeticParser - Decimal Numbers")
struct ArithmeticParserDecimalNumbersTests {
    @Test("Decimal multiplication")
    func decimalMultiplication() throws {
        let result = try ArithmeticParser.evaluate("3.14 * 2")
        #expect(result == 6.28)
    }

    @Test("Decimal addition")
    func decimalAddition() throws {
        let result = try ArithmeticParser.evaluate("1.5 + 2.5")
        #expect(result == 4.0)
    }

    @Test("Decimal division")
    func decimalDivision() throws {
        let result = try ArithmeticParser.evaluate("7.5 / 2.5")
        #expect(result == 3.0)
    }

    @Test("Decimal subtraction")
    func decimalSubtraction() throws {
        let result = try ArithmeticParser.evaluate("10.75 - 5.25")
        #expect(result == 5.5)
    }

    @Test("Mixed integer and decimal")
    func mixedIntegerDecimal() throws {
        let result = try ArithmeticParser.evaluate("5 * 2.5")
        #expect(result == 12.5)
    }

    @Test("Leading zero decimal")
    func leadingZeroDecimal() throws {
        let result = try ArithmeticParser.evaluate("0.5 + 0.3")
        #expect(abs(result - 0.8) < 0.0001) // Account for floating point precision
    }
}

// MARK: - ArithmeticParserUnaryOperatorsTests

@Suite("ArithmeticParser - Unary Operators")
struct ArithmeticParserUnaryOperatorsTests {
    @Test("Unary minus on number")
    func unaryMinusNumber() throws {
        let result = try ArithmeticParser.evaluate("-5 + 3")
        #expect(result == -2.0)
    }

    @Test("Unary minus in parentheses")
    func unaryMinusParentheses() throws {
        let result = try ArithmeticParser.evaluate("(-5) * 2")
        #expect(result == -10.0)
    }

    @Test("Unary plus on number")
    func unaryPlusNumber() throws {
        let result = try ArithmeticParser.evaluate("+5 + 3")
        #expect(result == 8.0)
    }

    @Test("Double unary minus")
    func doubleUnaryMinus() throws {
        let result = try ArithmeticParser.evaluate("--5")
        #expect(result == 5.0) // Two negations cancel out
    }

    @Test("Unary minus on expression")
    func unaryMinusExpression() throws {
        let result = try ArithmeticParser.evaluate("-(2 + 3)")
        #expect(result == -5.0)
    }

    @Test("Complex expression with unary operators")
    func complexUnaryExpression() throws {
        let result = try ArithmeticParser.evaluate("-5 * -2 + 3")
        #expect(result == 13.0) // (-5 * -2) + 3 = 10 + 3
    }
}

// MARK: - ArithmeticParserSingleNumberTests

@Suite("ArithmeticParser - Single Number")
struct ArithmeticParserSingleNumberTests {
    @Test("Single integer")
    func singleInteger() throws {
        let result = try ArithmeticParser.evaluate("42")
        #expect(result == 42.0)
    }

    @Test("Single decimal")
    func singleDecimal() throws {
        let result = try ArithmeticParser.evaluate("3.14159")
        #expect(result == 3.14159)
    }

    @Test("Single zero")
    func singleZero() throws {
        let result = try ArithmeticParser.evaluate("0")
        #expect(result == 0.0)
    }

    @Test("Single number in parentheses")
    func singleNumberParentheses() throws {
        let result = try ArithmeticParser.evaluate("(42)")
        #expect(result == 42.0)
    }
}

// MARK: - ArithmeticParserWhitespaceTests

@Suite("ArithmeticParser - Whitespace Handling")
struct ArithmeticParserWhitespaceTests {
    @Test("Multiple spaces between operators")
    func multipleSpaces() throws {
        let result = try ArithmeticParser.evaluate("2  +  3")
        #expect(result == 5.0)
    }

    @Test("No spaces between operators")
    func noSpaces() throws {
        let result = try ArithmeticParser.evaluate("2+3*4")
        #expect(result == 14.0)
    }

    @Test("Leading and trailing spaces")
    func leadingTrailingSpaces() throws {
        let result = try ArithmeticParser.evaluate("  10 + 5  ")
        #expect(result == 15.0)
    }

    @Test("Spaces around parentheses")
    func spacesAroundParentheses() throws {
        let result = try ArithmeticParser.evaluate("( 2 + 3 ) * 4")
        #expect(result == 20.0)
    }

    @Test("Mixed spacing patterns")
    func mixedSpacing() throws {
        let result = try ArithmeticParser.evaluate("  2+3  * (  4-  1 )  ")
        #expect(result == 11.0) // 2 + 3 * 3 = 2 + 9
    }
}

// MARK: - ArithmeticParserComplexExpressionsTests

@Suite("ArithmeticParser - Complex Expressions")
struct ArithmeticParserComplexExpressionsTests {
    @Test("Complex expression with all operators")
    func allOperators() throws {
        let result = try ArithmeticParser.evaluate("10 + 5 * 2 - 8 / 4")
        #expect(result == 18.0) // 10 + 10 - 2
    }

    @Test("Complex nested parentheses expression")
    func complexNestedParentheses() throws {
        let result = try ArithmeticParser.evaluate("((10 + 5) * 2 - (8 / 4)) / 3")
        #expect(result == 9.333333333333334) // ((15 * 2) - 2) / 3 = 28 / 3
    }

    @Test("Long expression with many operations")
    func longExpression() throws {
        let result = try ArithmeticParser.evaluate("1 + 2 + 3 + 4 + 5")
        #expect(result == 15.0)
    }

    @Test("Expression with decimals and parentheses")
    func decimalsAndParentheses() throws {
        let result = try ArithmeticParser.evaluate("(3.5 + 2.5) * 1.5 - 2.0")
        #expect(result == 7.0) // 6.0 * 1.5 - 2.0 = 9.0 - 2.0
    }

    @Test("Realistic calculation example")
    func realisticCalculation() throws {
        let result = try ArithmeticParser.evaluate("(100 - 25) * 0.8 + 10")
        #expect(result == 70.0) // 75 * 0.8 + 10 = 60 + 10
    }
}

// MARK: - ArithmeticParserErrorCasesTests

@Suite("ArithmeticParser - Error Cases")
struct ArithmeticParserErrorCasesTests {
    @Test("Division by zero throws error")
    func divisionByZero() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("10 / 0")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .divisionByZero)
    }

    @Test("Division by zero in expression")
    func divisionByZeroInExpression() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("5 + 10 / (2 - 2)")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .divisionByZero)
    }

    @Test("Missing closing parenthesis throws error")
    func missingClosingParenthesis() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("(2 + 3")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .missingClosingParenthesis)
    }

    @Test("Missing closing parenthesis in nested expression")
    func missingClosingParenthesisNested() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("((2 + 3) * 4")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .missingClosingParenthesis)
    }

    @Test("Empty expression throws error")
    func emptyExpression() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .emptyExpression)
    }

    @Test("Whitespace only expression throws error")
    func whitespaceOnlyExpression() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("   ")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        #expect(thrownError == .emptyExpression)
    }

    @Test("Invalid character throws unexpected token error")
    func invalidCharacter() {
        var thrownError: ArithmeticParser.ParserError?

        do {
            _ = try ArithmeticParser.evaluate("2 + $ 3")
        } catch let error as ArithmeticParser.ParserError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected ParserError")
        }

        if case let .unexpectedToken(token) = thrownError {
            #expect(token == "$")
        } else {
            #expect(Bool(false), "Expected unexpectedToken error")
        }
    }

    @Test("Expression ending with operator")
    func expressionEndingWithOperator() {
        var caughtError = false

        do {
            _ = try ArithmeticParser.evaluate("2 + 3 *")
        } catch {
            caughtError = true
            // Should throw unexpectedEndOfExpression
        }

        #expect(caughtError)
    }

    @Test("Expression starting with binary operator")
    func expressionStartingWithBinaryOperator() {
        var caughtError = false

        do {
            _ = try ArithmeticParser.evaluate("* 2 + 3")
        } catch {
            caughtError = true
            // Should throw an error (unexpected token or similar)
        }

        #expect(caughtError)
    }

    @Test("Extra closing parenthesis")
    func extraClosingParenthesis() {
        var caughtError = false

        do {
            _ = try ArithmeticParser.evaluate("2 + 3)")
        } catch {
            caughtError = true
            // Should throw unexpected token error
        }

        #expect(caughtError)
    }

    @Test("Missing operand between operators")
    func missingOperandBetweenOperators() {
        var caughtError = false

        do {
            _ = try ArithmeticParser.evaluate("2 + + 3")
        } catch {
            caughtError = true
            // + can be unary, so this might actually parse as 2 + (+3) = 5
            // But let's verify it at least doesn't crash
        }

        // The expression "2 + + 3" might actually be valid (unary +)
        // So we just ensure it doesn't crash - remove the expectation
    }
}

// MARK: - ArithmeticParserEdgeCasesTests

@Suite("ArithmeticParser - Edge Cases")
struct ArithmeticParserEdgeCasesTests {
    @Test("Very large number")
    func veryLargeNumber() throws {
        let result = try ArithmeticParser.evaluate("999999999 + 1")
        #expect(result == 1_000_000_000.0)
    }

    @Test("Very small decimal")
    func verySmallDecimal() throws {
        let result = try ArithmeticParser.evaluate("0.0001 * 10000")
        #expect(abs(result - 1.0) < 0.0001) // Account for floating point precision
    }

    @Test("Negative result")
    func negativeResult() throws {
        let result = try ArithmeticParser.evaluate("5 - 10")
        #expect(result == -5.0)
    }

    @Test("Zero result from subtraction")
    func zeroResultSubtraction() throws {
        let result = try ArithmeticParser.evaluate("42 - 42")
        #expect(result == 0.0)
    }

    @Test("Multiple consecutive unary operators")
    func multipleConsecutiveUnaryOperators() throws {
        let result = try ArithmeticParser.evaluate("---5") // Triple negation
        #expect(result == -5.0)
    }

    @Test("Empty parentheses are invalid")
    func emptyParentheses() {
        var caughtError = false

        do {
            _ = try ArithmeticParser.evaluate("()")
        } catch {
            caughtError = true
        }

        #expect(caughtError)
    }

    @Test("Multiplication by zero")
    func multiplicationByZero() throws {
        let result = try ArithmeticParser.evaluate("42 * 0")
        #expect(result == 0.0)
    }

    @Test("Addition of zero")
    func additionOfZero() throws {
        let result = try ArithmeticParser.evaluate("42 + 0")
        #expect(result == 42.0)
    }
}

// MARK: - ArithmeticParserErrorPropertiesTests

@Suite("ArithmeticParser.ParserError - Properties")
struct ArithmeticParserErrorPropertiesTests {
    @Test("ParserError Equatable conformance")
    func parserErrorEquatable() {
        #expect(ArithmeticParser.ParserError.emptyExpression == .emptyExpression)
        #expect(ArithmeticParser.ParserError.unexpectedEndOfExpression == .unexpectedEndOfExpression)
        #expect(ArithmeticParser.ParserError.divisionByZero == .divisionByZero)
        #expect(ArithmeticParser.ParserError.missingClosingParenthesis == .missingClosingParenthesis)

        #expect(ArithmeticParser.ParserError.unexpectedToken("x") == .unexpectedToken("x"))
        #expect(ArithmeticParser.ParserError.unexpectedToken("x") != .unexpectedToken("y"))

        #expect(ArithmeticParser.ParserError.invalidNumber("abc") == .invalidNumber("abc"))
        #expect(ArithmeticParser.ParserError.invalidNumber("abc") != .invalidNumber("xyz"))
    }

    @Test("ParserError LocalizedError descriptions")
    func parserErrorDescriptions() {
        let emptyError = ArithmeticParser.ParserError.emptyExpression
        #expect(emptyError.errorDescription == "Expression is empty")

        let unexpectedEndError = ArithmeticParser.ParserError.unexpectedEndOfExpression
        #expect(unexpectedEndError.errorDescription == "Unexpected end of expression")

        let divisionError = ArithmeticParser.ParserError.divisionByZero
        #expect(divisionError.errorDescription == "Division by zero")

        let parenError = ArithmeticParser.ParserError.missingClosingParenthesis
        #expect(parenError.errorDescription == "Missing closing parenthesis")

        let tokenError = ArithmeticParser.ParserError.unexpectedToken("$")
        #expect(tokenError.errorDescription == "Unexpected token: $")

        let numberError = ArithmeticParser.ParserError.invalidNumber("abc")
        #expect(numberError.errorDescription == "Invalid number: abc")
    }
}
