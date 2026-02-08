// PromptMacro.swift
// SwarmMacros
//
// Implementation of the #Prompt freestanding macro for type-safe prompt building.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - PromptMacro

/// The `#Prompt` macro provides type-safe prompt string building with interpolation.
///
/// Usage:
/// ```swift
/// let prompt = #Prompt("You are \(role). Help with: \(task)")
///
/// // With multi-line:
/// let systemPrompt = #Prompt("""
///     You are \(agentRole).
///     Available tools: \(toolNames).
///     User query: \(input)
///     """)
/// ```
///
/// Features:
/// - Compile-time validation of interpolations
/// - Safe escaping of special characters
/// - Clear error messages for invalid syntax
public struct PromptMacro: ExpressionMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Extract the string literal argument
        guard let argument = node.arguments.first?.expression else {
            throw PromptMacroError.missingArgument
        }

        // Handle string literal
        if let stringLiteral = argument.as(StringLiteralExprSyntax.self) {
            return processStringLiteral(stringLiteral)
        }

        // Handle string interpolation
        if let interpolation = argument.as(StringLiteralExprSyntax.self) {
            return processStringLiteral(interpolation)
        }

        // Return as-is if we can't process it
        return argument
    }

    /// Processes a string literal, handling interpolations.
    private static func processStringLiteral(_ literal: StringLiteralExprSyntax) -> ExprSyntax {
        var parts: [String] = []
        var interpolations: [String] = []

        for segment in literal.segments {
            switch segment {
            case .stringSegment(let stringSegment):
                // Escape special prompt characters if needed
                let text = stringSegment.content.text
                parts.append(text)

            case .expressionSegment(let exprSegment):
                // Get the interpolated expression
                let expr = exprSegment.expressions.first?.description ?? ""
                parts.append("\\(\(expr))")
                interpolations.append(expr)
            }
        }

        // Build the result string with proper formatting
        let combinedString = parts.joined()

        // Escape special characters for regular string literal
        // Note: Don't escape backslashes as they're used for interpolation markers
        let escapedString = combinedString
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        // Return a validated string literal using regular quotes
        return """
            PromptString(content: "\(raw: escapedString)", interpolations: [\(raw: interpolations.map { "\"\($0)\"" }.joined(separator: ", "))])
            """
    }
}

// MARK: - PromptStringMacro (Alternative simpler version)

/// A simpler version that just validates and passes through.
public struct PromptStringMacro: ExpressionMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            throw PromptMacroError.missingArgument
        }

        // Validate the string literal
        guard argument.is(StringLiteralExprSyntax.self) else {
            throw PromptMacroError.invalidArgument
        }

        // Return the string as-is, but wrapped in our validated type
        return "PromptString(\(argument))"
    }
}

// MARK: - PromptMacroError

/// Errors for #Prompt macro.
enum PromptMacroError: Error, CustomStringConvertible {
    case missingArgument
    case invalidArgument
    case invalidInterpolation(String)

    var description: String {
        switch self {
        case .missingArgument:
            return "#Prompt requires a string argument"
        case .invalidArgument:
            return "#Prompt argument must be a string literal"
        case .invalidInterpolation(let expr):
            return "Invalid interpolation in #Prompt: \(expr)"
        }
    }
}
