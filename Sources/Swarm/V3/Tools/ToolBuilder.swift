// ToolBuilder.swift
// Swarm V3 API
//
// Result builder for composing ToolV3 instances in a trailing closure.

// MARK: - @ToolV3Builder

/// Result builder that collects `ToolV3` instances into an array.
///
/// Used with V3 workflow and agent APIs that accept `[any ToolV3]`.
/// The primary `ToolBuilder` in `ToolParameterBuilder.swift` works with `AnyJSONTool`.
@resultBuilder
public struct ToolV3Builder {
    public static func buildBlock(_ components: [any ToolV3]...) -> [any ToolV3] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: any ToolV3) -> [any ToolV3] {
        [expression]
    }

    public static func buildArray(_ components: [[any ToolV3]]) -> [any ToolV3] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [any ToolV3]?) -> [any ToolV3] {
        component ?? []
    }

    public static func buildEither(first component: [any ToolV3]) -> [any ToolV3] {
        component
    }

    public static func buildEither(second component: [any ToolV3]) -> [any ToolV3] {
        component
    }
}
