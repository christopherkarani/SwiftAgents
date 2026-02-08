// ToolMacro.swift
// SwarmMacros
//
// Implementation of the @Tool macro for generating Tool protocol conformance.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

// MARK: - ToolMacro

/// The `@Tool` macro generates Tool protocol conformance for a struct.
///
/// Usage:
/// ```swift
/// @Tool("Calculates mathematical expressions")
/// struct CalculatorTool {
///     @Parameter("The expression to evaluate")
///     var expression: String
///
///     func execute() async throws -> Double {
///         // Implementation
///     }
/// }
/// ```
///
/// Generates:
/// - `name` property (derived from type name)
/// - `description` property (from macro argument)
/// - `parameters` array (from @Parameter properties)
/// - `execute(arguments:)` wrapper method
/// - Tool and Sendable conformances
///
/// ## Return Type Encoding
///
/// The macro automatically converts your tool's return type to `SendableValue`:
///
/// - **Primitive types** (String, Int, Double, Bool) are encoded directly
/// - **SendableValue** returns are passed through unchanged
/// - **Void/()** returns become `.null`
/// - **Complex types** (custom structs, enums, etc.) are handled in two ways:
///   1. First, the macro attempts to encode them using `SendableValue(encoding:)`, which uses `Codable`
///   2. If encoding fails, the value is converted to a string using `String(describing:)` as a fallback
///
/// **Important**: The `String(describing:)` fallback means type information is lost. For complex return types:
/// - Ensure your type conforms to `Codable` for proper encoding
/// - Or manually return `SendableValue` from your `execute()` method
/// - Be aware that sensitive data may be exposed in string representations
///
/// Example with complex type:
/// ```swift
/// struct CustomResult: Codable, Sendable {
///     let value: Int
///     let metadata: String
/// }
///
/// @Tool("Returns custom data")
/// struct MyTool {
///     func execute() async throws -> CustomResult {
///         // Will be encoded via Codable automatically
///         return CustomResult(value: 42, metadata: "success")
///     }
/// }
/// ```
public struct ToolMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract the description from macro argument
        guard let description = extractDescription(from: node) else {
            throw MacroError.missingDescription
        }

        // Get the type name
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyApplicableToStruct
        }
        let typeName = structDecl.name.text

        // Derive tool name from type name (lowercase, remove "Tool" suffix)
        let toolName = deriveToolName(from: typeName)

        // Find all @Parameter annotated properties
        let parameters = extractParameters(from: declaration)

        // Generate members
        var members: [DeclSyntax] = []

        // 1. Generate name property
        members.append("""
            public let name: String = "\(raw: toolName)"
            """)

        // 2. Generate description property
        members.append("""
            public let description: String = \(literal: description)
            """)

        // 3. Generate parameters array
        let parametersArray = generateParametersArray(parameters)
        members.append("""
            public let parameters: [ToolParameter] = \(raw: parametersArray)
            """)

        // 4. Generate init if not present
        if !hasInit(in: declaration) {
            members.append("""
                public init() {}
                """)
        }

        // 5. Generate execute(arguments:) wrapper
        let executeWrapper = generateExecuteWrapper(parameters: parameters, declaration: declaration)
        members.append(executeWrapper)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Only add extension for valid Tool declarations
        // Must be a struct with a description argument
        guard declaration.is(StructDeclSyntax.self),
              extractDescription(from: node) != nil else {
            return []
        }
        // Add AnyJSONTool and Sendable conformance
        let toolExtension = try ExtensionDeclSyntax("extension \(type): AnyJSONTool, Sendable {}")
        return [toolExtension]
    }

    // MARK: - Helper Methods

    /// Extracts the description string from the macro attribute.
    private static func extractDescription(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// Derives the tool name from the type name.
    private static func deriveToolName(from typeName: String) -> String {
        var name = typeName
        // Remove "Tool" suffix if present
        if name.hasSuffix("Tool") {
            name = String(name.dropLast(4))
        }
        // Convert to lowercase
        return name.lowercased()
    }

    /// Extracts @Parameter annotated properties from the declaration.
    private static func extractParameters(from declaration: some DeclGroupSyntax) -> [ParameterInfo] {
        var parameters: [ParameterInfo] = []

        for member in declaration.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

            // Check for @Parameter attribute
            let parameterAttr = varDecl.attributes.first { attr in
                guard let attr = attr.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                    return false
                }
                return identifier.name.text == "Parameter"
            }

            guard let attr = parameterAttr?.as(AttributeSyntax.self) else { continue }

            // Extract parameter info
            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let propertyName = pattern.identifier.text

                // Get the type
                let typeAnnotation = binding.typeAnnotation?.type
                let swiftType = typeAnnotation?.description.trimmingCharacters(in: .whitespaces) ?? "String"

                // Check if optional
                let isOptional = typeAnnotation?.is(OptionalTypeSyntax.self) == true ||
                                 typeAnnotation?.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) == true

                // Get default value if present
                let defaultValue = binding.initializer?.value.description

                // Extract description from @Parameter attribute
                let paramDescription = extractParameterDescription(from: attr)

                // Extract default from @Parameter attribute
                let paramDefault = extractParameterDefault(from: attr)

                // Extract oneOf options
                let oneOfOptions = extractOneOfOptions(from: attr)

                parameters.append(ParameterInfo(
                    name: propertyName,
                    description: paramDescription ?? "Parameter \(propertyName)",
                    swiftType: swiftType,
                    isOptional: isOptional || paramDefault != nil || defaultValue != nil,
                    defaultValue: paramDefault ?? defaultValue,
                    oneOfOptions: oneOfOptions
                ))
            }
        }

        return parameters
    }

    /// Extracts description from @Parameter attribute.
    private static func extractParameterDescription(from attr: AttributeSyntax) -> String? {
        guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else { return nil }

        // First unlabeled argument is the description
        for arg in arguments {
            if arg.label == nil,
               let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
        }
        return nil
    }

    /// Extracts default value from @Parameter attribute.
    private static func extractParameterDefault(from attr: AttributeSyntax) -> String? {
        guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else { return nil }

        for arg in arguments where arg.label?.text == "default" {
            return arg.expression.description
        }
        return nil
    }

    /// Extracts oneOf options from @Parameter attribute.
    private static func extractOneOfOptions(from attr: AttributeSyntax) -> [String]? {
        guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else { return nil }

        for arg in arguments {
            if arg.label?.text == "oneOf",
               let arrayExpr = arg.expression.as(ArrayExprSyntax.self) {
                var options: [String] = []
                for element in arrayExpr.elements {
                    if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        options.append(segment.content.text)
                    }
                }
                return options
            }
        }
        return nil
    }

    /// Checks if the declaration already has an init.
    private static func hasInit(in declaration: some DeclGroupSyntax) -> Bool {
        for member in declaration.memberBlock.members where member.decl.is(InitializerDeclSyntax.self) {
            return true
        }
        return false
    }

    /// Generates the parameters array code.
    private static func generateParametersArray(_ parameters: [ParameterInfo]) -> String {
        if parameters.isEmpty {
            return "[]"
        }

        let parameterStrings = parameters.map { param -> String in
            let paramType = mapSwiftTypeToParameterType(param.swiftType, oneOf: param.oneOfOptions)
            let isRequired = !param.isOptional

            var defaultValueStr = ""
            if let defaultValue = param.defaultValue {
                defaultValueStr = ", defaultValue: \(convertToSendableValue(defaultValue, type: param.swiftType))"
            }

            return """
                ToolParameter(
                    name: "\(param.name)",
                    description: "\(param.description)",
                    type: \(paramType),
                    isRequired: \(isRequired)\(defaultValueStr)
                )
            """
        }

        return "[\n        " + parameterStrings.joined(separator: ",\n        ") + "\n    ]"
    }

    /// Maps Swift type to ParameterType.
    private static func mapSwiftTypeToParameterType(_ swiftType: String, oneOf: [String]?) -> String {
        // Handle oneOf first
        if let options = oneOf, !options.isEmpty {
            let optionsStr = options.map { "\"\($0)\"" }.joined(separator: ", ")
            return ".oneOf([\(optionsStr)])"
        }

        // Clean up the type (remove Optional wrapper)
        let cleanType = swiftType
            .replacingOccurrences(of: "Optional<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Handle array types
        if cleanType.hasPrefix("[") && cleanType.hasSuffix("]") {
            let elementType = String(cleanType.dropFirst().dropLast())
            let elementParamType = mapSwiftTypeToParameterType(elementType, oneOf: nil)
            return ".array(elementType: \(elementParamType))"
        }

        // Map basic types
        switch cleanType {
        case "String":
            return ".string"
        case "Int":
            return ".int"
        case "Double", "Float":
            return ".double"
        case "Bool":
            return ".bool"
        default:
            return ".string"
        }
    }

    /// Converts a default value to SendableValue syntax.
    private static func convertToSendableValue(_ value: String, type: String) -> String {
        let cleanValue = value.trimmingCharacters(in: .whitespaces)
        
        if cleanValue == "nil" {
            return "nil"
        }

        let cleanType = type.replacingOccurrences(of: "?", with: "").trimmingCharacters(in: .whitespaces)

        switch cleanType {
        case "String":
            return ".string(\(cleanValue))"
        case "Int":
            return ".int(\(cleanValue))"
        case "Double", "Float":
            return ".double(\(cleanValue))"
        case "Bool":
            return ".bool(\(cleanValue))"
        default:
            return ".string(\(cleanValue))"
        }
    }

    /// Generates the execute(arguments:) wrapper method.
    private static func generateExecuteWrapper(parameters: [ParameterInfo], declaration: some DeclGroupSyntax) -> DeclSyntax {
        // Find the user's execute() method to determine return type
        var userExecuteReturnType = "SendableValue"
        var hasUserExecute = false

        for member in declaration.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self),
               funcDecl.name.text == "execute" {
                hasUserExecute = true
                if let returnClause = funcDecl.signature.returnClause {
                    userExecuteReturnType = returnClause.type.description.trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }

        // Generate parameter extraction code
        var extractionCode = ""
        for param in parameters {
            let extraction = generateParameterExtraction(param)
            extractionCode += extraction + "\n        "
        }

        // Generate the wrapper
        let conversionCode = generateReturnConversion(userExecuteReturnType)

        if hasUserExecute {
            // Generate property assignments using a local copy for thread safety
            let propertyAssignments = parameters.map { "toolCopy.\($0.name) = \($0.name)" }.joined(separator: "\n        ")

            return """
                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    \(raw: extractionCode)
                    var toolCopy = self
                    \(raw: propertyAssignments)
                    let result = try await toolCopy.execute()
                    \(raw: conversionCode)
                }
                """
        } else {
            return """
                public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                    \(raw: extractionCode)
                    return .null
                }
                """
        }
    }

    /// Generates code to extract a parameter from arguments.
    private static func generateParameterExtraction(_ param: ParameterInfo) -> String {
        let accessor = getValueAccessor(for: param.swiftType)

        if param.isOptional {
            if let defaultValue = param.defaultValue {
                return "let \(param.name) = arguments[\"\(param.name)\"]?\(accessor) ?? \(defaultValue)"
            } else {
                return "let \(param.name) = arguments[\"\(param.name)\"]?\(accessor)"
            }
        } else {
            return """
guard let \(param.name) = arguments["\(param.name)"]?\(accessor) else {
                throw AgentError.invalidToolArguments(toolName: name, reason: "Missing required parameter '\(param.name)'")
            }
"""
        }
    }

    /// Gets the value accessor method for a Swift type.
    private static func getValueAccessor(for swiftType: String) -> String {
        let cleanType = swiftType
            .replacingOccurrences(of: "Optional<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)

        switch cleanType {
        case "String":
            return ".stringValue"
        case "Int":
            return ".intValue"
        case "Double", "Float":
            return ".doubleValue"
        case "Bool":
            return ".boolValue"
        default:
            return ".stringValue"
        }
    }

    /// Generates code to convert return value to SendableValue.
    private static func generateReturnConversion(_ returnType: String) -> String {
        let cleanType = returnType.trimmingCharacters(in: .whitespaces)

        switch cleanType {
        case "String":
            return "return .string(result)"
        case "Int":
            return "return .int(result)"
        case "Double", "Float":
            return "return .double(result)"
        case "Bool":
            return "return .bool(result)"
        case "SendableValue":
            return "return result"
        case "Void", "()":
            return "return .null"
        default:
            // For complex types, try to encode as Codable
            // If encoding fails, throw an error rather than silently converting to string
            // (which could expose sensitive data like PII)
            return """
do {
                    return try SendableValue(encoding: result)
                } catch {
                    throw AgentError.toolExecutionFailed(
                        toolName: name,
                        underlyingError: "Unsupported return type '\\(type(of: result))'. " +
                            "Tool return types must be String, Int, Double, Bool, SendableValue, Void, or Codable."
                    )
                }
"""
        }
    }
}

// MARK: - ParameterInfo

/// Information about a tool parameter.
struct ParameterInfo {
    let name: String
    let description: String
    let swiftType: String
    let isOptional: Bool
    let defaultValue: String?
    let oneOfOptions: [String]?
}

// MARK: - MacroError

/// Errors that can occur during macro expansion.
enum MacroError: Error, CustomStringConvertible {
    case missingDescription
    case onlyApplicableToStruct
    case invalidParameterType
    case missingExecuteMethod

    var description: String {
        switch self {
        case .missingDescription:
            return "@Tool requires a description string argument"
        case .onlyApplicableToStruct:
            return "@Tool can only be applied to structs"
        case .invalidParameterType:
            return "Invalid parameter type"
        case .missingExecuteMethod:
            return "@Tool requires an execute() method"
        }
    }
}
