// BuilderMacro.swift
// SwiftAgentsMacros
//
// Implementation of the @Builder macro for generating fluent setter methods.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - BuilderMacro

/// The `@Builder` macro generates fluent setter methods for all stored `var` properties.
///
/// Usage:
/// ```swift
/// @Builder
/// public struct Configuration {
///     public var timeout: Duration
///     public var maxRetries: Int
///     public var enableLogging: Bool
///
///     public init(timeout: Duration = .seconds(30), maxRetries: Int = 3, enableLogging: Bool = true) {
///         self.timeout = timeout
///         self.maxRetries = maxRetries
///         self.enableLogging = enableLogging
///     }
/// }
/// ```
///
/// Generates:
/// ```swift
/// @discardableResult
/// public func timeout(_ value: Duration) -> Self {
///     var copy = self
///     copy.timeout = value
///     return copy
/// }
///
/// @discardableResult
/// public func maxRetries(_ value: Int) -> Self {
///     var copy = self
///     copy.maxRetries = value
///     return copy
/// }
///
/// @discardableResult
/// public func enableLogging(_ value: Bool) -> Self {
///     var copy = self
///     copy.enableLogging = value
///     return copy
/// }
/// ```
///
/// ## Requirements
/// - Can only be applied to structs
/// - Only generates setters for stored `var` properties
/// - Skips computed properties (those with getters)
/// - Skips `let` constants
/// - Preserves access level (public/internal)
public struct BuilderMacro: MemberMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate: must be a struct
        guard declaration.is(StructDeclSyntax.self) else {
            throw BuilderMacroError.onlyApplicableToStruct
        }

        // Extract stored var properties
        let properties = extractStoredProperties(from: declaration)

        // Ensure there's at least one stored property
        guard !properties.isEmpty else {
            throw BuilderMacroError.noStoredProperties
        }

        // Generate fluent setter methods
        var members: [DeclSyntax] = []
        for property in properties {
            let setter = generateFluentSetter(for: property)
            members.append(setter)
        }

        return members
    }

    // MARK: - Helper Methods

    /// Extracts stored var properties from the declaration.
    private static func extractStoredProperties(from declaration: some DeclGroupSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in declaration.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

            // Must be a var (not let)
            guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else { continue }

            // Extract property information
            for binding in varDecl.bindings {
                // Skip computed properties (those with accessor blocks)
                // Accessor blocks indicate computed properties or properties with custom getters/setters
                if binding.accessorBlock != nil {
                    continue
                }

                // Get property name
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let propertyName = pattern.identifier.text

                // Get type annotation
                guard let typeAnnotation = binding.typeAnnotation else { continue }
                let propertyType = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)

                // Determine access level (public or internal)
                let isPublic = varDecl.modifiers.contains { modifier in
                    modifier.name.tokenKind == .keyword(.public)
                }

                properties.append(PropertyInfo(
                    name: propertyName,
                    type: propertyType,
                    isPublic: isPublic
                ))
            }
        }

        return properties
    }

    /// Generates a fluent setter method for the given property.
    private static func generateFluentSetter(for property: PropertyInfo) -> DeclSyntax {
        let accessLevel = property.isPublic ? "public " : ""

        return """
            @discardableResult
            \(raw: accessLevel)func \(raw: property.name)(_ value: \(raw: property.type)) -> Self {
                var copy = self
                copy.\(raw: property.name) = value
                return copy
            }
            """
    }
}

// MARK: - PropertyInfo

/// Information about a stored property.
struct PropertyInfo {
    /// The property name.
    let name: String

    /// The property type.
    let type: String

    /// Whether the property is public.
    let isPublic: Bool
}

// MARK: - BuilderMacroError

/// Errors that can occur during @Builder macro expansion.
enum BuilderMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct
    case noStoredProperties

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Builder can only be applied to structs"
        case .noStoredProperties:
            return "@Builder requires at least one stored var property"
        }
    }
}
