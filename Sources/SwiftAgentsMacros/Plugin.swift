// Plugin.swift
// SwiftAgentsMacros
//
// Compiler plugin entry point for SwiftAgents macros.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The compiler plugin that provides all SwiftAgents macros.
@main
struct SwiftAgentsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ToolMacro.self,
        ParameterMacro.self,
        AgentMacro.self,
        TraceableMacro.self,
        PromptMacro.self
    ]
}
