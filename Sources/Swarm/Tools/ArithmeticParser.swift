// ArithmeticParser.swift
// Swarm Framework
//
// Pure Swift recursive descent arithmetic parser for cross-platform support.

import Foundation

// MARK: - ArithmeticParser

/// A pure Swift recursive descent parser for arithmetic expressions.
///
/// This parser provides cross-platform arithmetic evaluation without relying
/// on NSExpression (which is unavailable on Linux). It supports basic arithmetic
/// operations with proper operator precedence (PEMDAS).
///
/// Supported operations:
/// - Addition (+)
/// - Subtraction (-)
/// - Multiplication (*)
/// - Division (/)
/// - Parentheses for grouping
/// - Unary plus and minus
/// - Decimal numbers
///
/// Example:
/// ```swift
/// let result = try ArithmeticParser.evaluate("2 + 3 * 4")
/// // result == 14.0
///
/// let complex = try ArithmeticParser.evaluate("(10 + 5) / 3 - 2.5")
/// // complex == 2.5
/// ```
///
/// Grammar:
/// ```
/// Expression := Term (('+' | '-') Term)*
/// Term       := Factor (('*' | '/') Factor)*
/// Factor     := Number | '(' Expression ')' | '-' Factor | '+' Factor
/// Number     := [0-9]+ ('.' [0-9]+)?
/// ```
struct ArithmeticParser: Sendable {
    // MARK: Internal

    // MARK: - Parsing Error

    /// Errors that can occur during arithmetic expression parsing.
    enum ParserError: Error, Equatable, Sendable {
        /// The expression is empty.
        case emptyExpression

        /// The expression ended unexpectedly.
        case unexpectedEndOfExpression

        /// An unexpected token was encountered.
        case unexpectedToken(String)

        /// Division by zero was attempted.
        case divisionByZero

        /// A closing parenthesis is missing.
        case missingClosingParenthesis

        /// An invalid number format was encountered.
        case invalidNumber(String)
    }

    // MARK: - Token

    /// Represents a lexical token in an arithmetic expression.
    enum Token: Equatable, Sendable {
        case number(Double)
        case plus
        case minus
        case multiply
        case divide
        case leftParen
        case rightParen
        case end
    }

    // MARK: - Public API

    /// Evaluates an arithmetic expression and returns the result.
    ///
    /// - Parameter expression: The arithmetic expression to evaluate.
    /// - Returns: The numeric result of the expression.
    /// - Throws: `ParserError` if the expression is invalid or cannot be evaluated.
    ///
    /// Example:
    /// ```swift
    /// let result = try ArithmeticParser.evaluate("2 + 3 * 4")
    /// // result == 14.0
    /// ```
    static func evaluate(_ expression: String) throws -> Double {
        // Check for empty expression
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ParserError.emptyExpression
        }

        // Tokenize
        var tokenizer = Tokenizer(trimmed)
        let tokens = try tokenizer.tokenize()

        // Parse and evaluate
        var parser = Parser(tokens: tokens)
        return try parser.parse()
    }

    // MARK: Private

    // MARK: - Tokenizer

    /// Tokenizes an arithmetic expression into a sequence of tokens.
    private struct Tokenizer: Sendable {
        // MARK: Internal

        init(_ expression: String) {
            input = expression
            currentIndex = expression.startIndex
        }

        /// Tokenizes the entire expression.
        mutating func tokenize() throws -> [Token] {
            var tokens: [Token] = []

            while currentIndex < input.endIndex {
                skipWhitespace()

                guard currentIndex < input.endIndex else { break }

                let char = input[currentIndex]

                switch char {
                case "+":
                    tokens.append(.plus)
                    advance()
                case "-":
                    tokens.append(.minus)
                    advance()
                case "*":
                    tokens.append(.multiply)
                    advance()
                case "/":
                    tokens.append(.divide)
                    advance()
                case "(":
                    tokens.append(.leftParen)
                    advance()
                case ")":
                    tokens.append(.rightParen)
                    advance()
                case ".",
                     "0"..."9":
                    try tokens.append(parseNumber())
                default:
                    throw ParserError.unexpectedToken(String(char))
                }
            }

            tokens.append(.end)
            return tokens
        }

        // MARK: Private

        private let input: String
        private var currentIndex: String.Index

        /// Parses a number from the current position.
        private mutating func parseNumber() throws -> Token {
            let start = currentIndex
            var hasDecimalPoint = false

            while currentIndex < input.endIndex {
                let char = input[currentIndex]

                if char.isWholeNumber {
                    advance()
                } else if char == "." {
                    if hasDecimalPoint {
                        // Second decimal point is not part of this number
                        break
                    }
                    hasDecimalPoint = true
                    advance()
                } else {
                    break
                }
            }

            let numberString = String(input[start..<currentIndex])
            guard let value = Double(numberString) else {
                throw ParserError.invalidNumber(numberString)
            }

            return .number(value)
        }

        /// Skips whitespace characters.
        private mutating func skipWhitespace() {
            while currentIndex < input.endIndex, input[currentIndex].isWhitespace {
                advance()
            }
        }

        /// Advances the current index by one position.
        private mutating func advance() {
            currentIndex = input.index(after: currentIndex)
        }
    }

    // MARK: - Parser

    /// Parses tokens into an evaluated result.
    private struct Parser: Sendable {
        // MARK: Internal

        init(tokens: [Token]) {
            self.tokens = tokens
        }

        /// Parses and evaluates the expression.
        mutating func parse() throws -> Double {
            let result = try parseExpression()

            guard currentToken == .end else {
                throw ParserError.unexpectedToken(tokenDescription(currentToken))
            }

            return result
        }

        // MARK: Private

        private let tokens: [Token]
        private var position: Int = 0

        /// Gets the current token.
        private var currentToken: Token {
            guard position < tokens.count else {
                return .end
            }
            return tokens[position]
        }

        /// Parses an expression: Term (('+' | '-') Term)*
        private mutating func parseExpression() throws -> Double {
            var result = try parseTerm()

            while true {
                switch currentToken {
                case .plus:
                    advance()
                    result += try parseTerm()
                case .minus:
                    advance()
                    result -= try parseTerm()
                default:
                    return result
                }
            }
        }

        /// Parses a term: Factor (('*' | '/') Factor)*
        private mutating func parseTerm() throws -> Double {
            var result = try parseFactor()

            while true {
                switch currentToken {
                case .multiply:
                    advance()
                    result *= try parseFactor()
                case .divide:
                    advance()
                    let divisor = try parseFactor()
                    guard divisor != 0 else {
                        throw ParserError.divisionByZero
                    }
                    result /= divisor
                default:
                    return result
                }
            }
        }

        /// Parses a factor: Number | '(' Expression ')' | '-' Factor | '+' Factor
        private mutating func parseFactor() throws -> Double {
            switch currentToken {
            case let .number(value):
                advance()
                return value

            case .leftParen:
                advance()
                let result = try parseExpression()
                guard currentToken == .rightParen else {
                    throw ParserError.missingClosingParenthesis
                }
                advance()
                return result

            case .minus:
                advance()
                return try -parseFactor()

            case .plus:
                advance()
                return try parseFactor()

            case .end:
                throw ParserError.unexpectedEndOfExpression

            default:
                throw ParserError.unexpectedToken(tokenDescription(currentToken))
            }
        }

        /// Advances to the next token.
        private mutating func advance() {
            position += 1
        }

        /// Gets a string description of a token for error messages.
        private func tokenDescription(_ token: Token) -> String {
            switch token {
            case let .number(value): String(value)
            case .plus: "+"
            case .minus: "-"
            case .multiply: "*"
            case .divide: "/"
            case .leftParen: "("
            case .rightParen: ")"
            case .end: "end of expression"
            }
        }
    }
}

// MARK: - ArithmeticParser.ParserError + LocalizedError

extension ArithmeticParser.ParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyExpression:
            "Expression is empty"
        case .unexpectedEndOfExpression:
            "Unexpected end of expression"
        case let .unexpectedToken(token):
            "Unexpected token: \(token)"
        case .divisionByZero:
            "Division by zero"
        case .missingClosingParenthesis:
            "Missing closing parenthesis"
        case let .invalidNumber(value):
            "Invalid number: \(value)"
        }
    }
}

// MARK: - ArithmeticParser.ParserError + CustomDebugStringConvertible

extension ArithmeticParser.ParserError: CustomDebugStringConvertible {
    var debugDescription: String {
        "ArithmeticParser.ParserError.\(self)"
    }
}
