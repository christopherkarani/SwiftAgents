import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The `@Agent` macro generates an `AgentV3` factory for a struct.
///
/// Usage:
/// ```swift
/// @Agent("You are a helper.")
/// struct HelperBot {
///     var tools: [any ToolV3] { [SearchTool()] }
/// }
/// // Generates: static func makeAgent() -> AgentV3
/// ```
public struct AgentV3Macro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract instructions from macro argument
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.label == nil,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
        else {
            throw AgentV3MacroError.missingInstructions
        }

        let instructions = segment.content.text

        // Get the type name
        let typeName: String
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            typeName = structDecl.name.text
        } else {
            throw AgentV3MacroError.onlyApplicableToStruct
        }

        // Check if a tools property exists
        let hasTools = declaration.memberBlock.members.contains { member in
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                return varDecl.bindings.contains { binding in
                    binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "tools"
                }
            }
            return false
        }

        let factoryBody: DeclSyntax
        if hasTools {
            factoryBody = """
                static func makeAgent() -> AgentV3 {
                    let instance = \(raw: typeName)()
                    return AgentV3("\(raw: instructions)") {
                        for tool in instance.tools {
                            tool
                        }
                    }
                }
                """
        } else {
            factoryBody = """
                static func makeAgent() -> AgentV3 {
                    AgentV3("\(raw: instructions)")
                }
                """
        }

        return [factoryBody]
    }
}

enum AgentV3MacroError: Error, CustomStringConvertible {
    case missingInstructions
    case onlyApplicableToStruct

    var description: String {
        switch self {
        case .missingInstructions:
            return "@Agent requires an instructions string argument"
        case .onlyApplicableToStruct:
            return "@Agent can only be applied to structs"
        }
    }
}
