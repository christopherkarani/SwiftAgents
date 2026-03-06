import Foundation

enum MembraneInternalToolName {
    static let loadToolSchema = "membrane_load_tool_schema"
    static let resolvePointer = "resolve_pointer"
    static let addTools = "Add_Tools"
    static let removeTools = "Remove_Tools"

    static let all: [String] = [
        addTools,
        loadToolSchema,
        removeTools,
        resolvePointer,
    ]
}

enum MembraneInternalTools {
    static func isInternalTool(_ name: String) -> Bool {
        MembraneInternalToolName.all.contains(name)
    }

    static func schemaSet() -> [ToolSchema] {
        sortedSchemas([
            ToolSchema(
                name: MembraneInternalToolName.loadToolSchema,
                description: "Load a tool schema into the current JIT active set by name.",
                parameters: [
                    ToolParameter(
                        name: "tool_name",
                        description: "Exact tool name to activate.",
                        type: .string
                    ),
                ]
            ),
            ToolSchema(
                name: MembraneInternalToolName.resolvePointer,
                description: "Resolve a Membrane pointer ID to the original payload.",
                parameters: [
                    ToolParameter(
                        name: "pointer_id",
                        description: "Pointer identifier returned by the membrane pointer summary.",
                        type: .string
                    ),
                ]
            ),
            ToolSchema(
                name: MembraneInternalToolName.addTools,
                description: "Add multiple tool names to the current JIT active set.",
                parameters: [
                    ToolParameter(
                        name: "tool_names",
                        description: "List of tool names to activate.",
                        type: .array(elementType: .string)
                    ),
                ]
            ),
            ToolSchema(
                name: MembraneInternalToolName.removeTools,
                description: "Remove multiple tool names from the current JIT active set.",
                parameters: [
                    ToolParameter(
                        name: "tool_names",
                        description: "List of tool names to deactivate.",
                        type: .array(elementType: .string)
                    ),
                ]
            ),
        ])
    }

    static func sortedSchemas(_ schemas: [ToolSchema]) -> [ToolSchema] {
        schemas.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.description.utf8.lexicographicallyPrecedes(rhs.description.utf8)
            }
            return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
        }
    }
}
