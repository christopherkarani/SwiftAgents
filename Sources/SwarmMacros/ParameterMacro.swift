// ParameterMacro.swift
// SwarmMacros
//
// Implementation of the @Parameter macro for declaring tool parameters.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - ParameterMacro

/// The `@Parameter` macro marks a property as a tool parameter.
///
/// Usage:
/// ```swift
/// @Parameter("The city name")
/// var location: String
///
/// @Parameter("Temperature units", default: "celsius")
/// var units: String = "celsius"
///
/// @Parameter("Output format", oneOf: ["json", "xml", "text"])
/// var format: String
/// ```
///
/// The macro itself doesn't generate code - it's a marker that the @Tool macro
/// uses to collect parameter information.
public struct ParameterMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // @Parameter is a marker macro - it doesn't generate peer declarations
        // The @Tool macro reads these attributes to generate the parameters array
        []
    }
}

// MARK: - Parameter Extraction Helpers

/// Extension to provide parameter extraction utilities.
extension ParameterMacro {
    /// Extracts parameter configuration from the attribute.
    static func extractConfig(from node: AttributeSyntax) -> ParameterConfig? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        var description: String?
        var defaultValue: String?
        var oneOfOptions: [String]?

        for arg in arguments {
            switch arg.label?.text {
            case nil:
                // Unlabeled argument is the description
                if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    description = segment.content.text
                }

            case "default":
                defaultValue = arg.expression.description

            case "oneOf":
                if let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                    oneOfOptions = arrayExpr.elements.compactMap { element -> String? in
                        guard let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
                            return nil
                        }
                        return segment.content.text
                    }
                }

            default:
                break
            }
        }

        return ParameterConfig(
            description: description ?? "",
            defaultValue: defaultValue,
            oneOfOptions: oneOfOptions
        )
    }
}

// MARK: - ParameterConfig

/// Configuration extracted from @Parameter attribute.
struct ParameterConfig {
    let description: String
    let defaultValue: String?
    let oneOfOptions: [String]?
}
