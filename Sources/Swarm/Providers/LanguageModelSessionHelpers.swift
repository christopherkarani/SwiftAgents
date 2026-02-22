//
//  LanguageModelSessionHelpers.swift
//  Swarm
//
//  Internal helpers for LanguageModelSession prompt building and tool call parsing.
//  Extracted to enable unit testing without requiring FoundationModels.
//

import Foundation

// MARK: - LanguageModelSessionToolPromptBuilder

/// Builds tool-aware prompts for use with Foundation Models' prompt-based tool calling.
enum LanguageModelSessionToolPromptBuilder {
    /// Builds a prompt that includes tool definitions and format instructions.
    /// - Parameters:
    ///   - basePrompt: The original user prompt.
    ///   - tools: Available tool schemas to include in the prompt.
    /// - Returns: The base prompt if no tools, or an enhanced prompt with tool definitions.
    static func buildToolPrompt(basePrompt: String, tools: [ToolSchema]) -> String {
        guard !tools.isEmpty else { return basePrompt }

        var toolDefinitions: [String] = []
        for tool in tools {
            let params = tool.parameters.map { param in
                let typeDesc = parameterTypeDescription(param.type)
                let required = param.isRequired ? " (required)" : ""
                return "  - \(param.name): \(typeDesc)\(required) - \(param.description)"
            }.joined(separator: "\n")

            let paramSection = params.isEmpty ? "  (no parameters)" : params

            let toolDef = """
                \(tool.name):
                  Description: \(tool.description)
                  Parameters:
                \(paramSection)
                """
            toolDefinitions.append(toolDef)
        }

        return """
            \(basePrompt)

            Available tools:
            \(toolDefinitions.joined(separator: "\n\n"))

            To use a tool, respond with a JSON object in this exact format:
            {"tool": "tool_name", "arguments": {"param1": "value1", "param2": "value2"}}

            If no tool is needed, respond normally without JSON.
            """
    }

    /// Converts a ToolParameter type to a human-readable description.
    static func parameterTypeDescription(_ type: ToolParameter.ParameterType) -> String {
        switch type {
        case .string:
            return "string"
        case .int:
            return "integer"
        case .double:
            return "number"
        case .bool:
            return "boolean"
        case let .array(elementType):
            return "array of \(parameterTypeDescription(elementType))"
        case .object:
            return "object"
        case let .oneOf(options):
            return "one of: \(options.joined(separator: ", "))"
        case .any:
            return "any type"
        }
    }
}

// MARK: - LanguageModelSessionToolParser

/// Parses tool calls from model response text for Foundation Models' prompt-based tool calling.
enum LanguageModelSessionToolParser {
    /// Parses tool calls from a model's text response.
    /// - Parameters:
    ///   - content: The model's response text.
    ///   - availableTools: The tools that were made available to the model.
    /// - Returns: Parsed tool calls if a valid tool call is found, nil otherwise.
    static func parseToolCalls(
        from content: String,
        availableTools: [ToolSchema]
    ) -> [InferenceResponse.ParsedToolCall]? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for JSON tool call format: {"tool": "name", "arguments": {...}}
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(trimmed[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            // Extract tool name (support both "tool" and "name" keys)
            let toolName = (jsonObject["tool"] as? String) ?? (jsonObject["name"] as? String)
            guard let toolName = toolName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            // Verify the tool exists in available tools
            guard availableTools.contains(where: { $0.name == toolName }) else {
                return nil
            }

            // Extract arguments
            var arguments: [String: SendableValue] = [:]
            if let argsObject = jsonObject["arguments"] as? [String: Any] {
                for (key, value) in argsObject {
                    arguments[key] = SendableValue.fromJSONValue(value)
                }
            }

            // Extract optional call ID
            let callId = jsonObject["id"] as? String

            return [InferenceResponse.ParsedToolCall(
                id: callId,
                name: toolName,
                arguments: arguments
            )]
        } catch {
            // JSON parsing failed - not a valid tool call
            return nil
        }
    }
}
