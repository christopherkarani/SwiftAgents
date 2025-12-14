// PromptMacroTests.swift
// SwiftAgentsMacrosTests
//
// Tests for the #Prompt freestanding macro.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftAgentsMacros)
import SwiftAgentsMacros

let promptMacros: [String: Macro.Type] = [
    "Prompt": PromptMacro.self
]
#endif

final class PromptMacroTests: XCTestCase {

    // MARK: - Basic Prompt Tests

    func testBasicPromptExpansion() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            let prompt = #Prompt("You are a helpful assistant")
            """,
            expandedSource: """
            let prompt = PromptString(content: \"\"\"You are a helpful assistant\"\"\", interpolations: [])
            """,
            macros: promptMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testPromptWithInterpolation() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            #"""
            let prompt = #Prompt("You are \(role). Help with: \(task)")
            """#,
            expandedSource: #"""
            let prompt = PromptString(content: """You are \(role). Help with: \(task)""", interpolations: ["role", "task"])
            """#,
            macros: promptMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMultilinePrompt() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            #"""
            let prompt = #Prompt("""
                You are a helpful assistant.
                Available tools: calculator, weather.
                Please help the user.
                """)
            """#,
            expandedSource: #"""
            let prompt = PromptString(content: """
                You are a helpful assistant.
                Available tools: calculator, weather.
                Please help the user.
                """, interpolations: [])
            """#,
            macros: promptMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Cases

    func testPromptRequiresArgument() throws {
        #if canImport(SwiftAgentsMacros)
        assertMacroExpansion(
            """
            let prompt = #Prompt()
            """,
            expandedSource: """
            let prompt = #Prompt()
            """,
            diagnostics: [
                DiagnosticSpec(message: "#Prompt requires a string argument", line: 1, column: 14)
            ],
            macros: promptMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - PromptString Runtime Tests

final class PromptStringTests: XCTestCase {

    func testPromptStringLiteralInit() {
        let prompt: PromptString = "Hello, world!"
        XCTAssertEqual(prompt.content, "Hello, world!")
        XCTAssertTrue(prompt.interpolations.isEmpty)
    }

    func testPromptStringInterpolation() {
        let name = "Claude"
        let task = "coding"
        let prompt: PromptString = "Hello, \(name)! Help with \(task)."
        XCTAssertEqual(prompt.content, "Hello, Claude! Help with coding.")
        XCTAssertEqual(prompt.interpolations.count, 2)
    }

    func testPromptStringDescription() {
        let prompt = PromptString(content: "Test prompt", interpolations: ["var1"])
        XCTAssertEqual(prompt.description, "Test prompt")
    }

    func testPromptStringWithArrayInterpolation() {
        let tools = ["calculator", "weather", "search"]
        let prompt: PromptString = "Available tools: \(tools)"
        XCTAssertEqual(prompt.content, "Available tools: calculator, weather, search")
    }

    func testPromptStringEquality() {
        let prompt1 = PromptString(content: "Hello", interpolations: [])
        let prompt2 = PromptString(content: "Hello", interpolations: [])
        XCTAssertEqual(prompt1.content, prompt2.content)
    }
}
