
import Foundation
import AnyLanguageModel
import SwiftAgents

struct ResearchAgent: Agent {
    var instructions: String { "You are a careful research agent." }

    var loop: some AgentLoop {
        Generate()
    }
}

var greeting = "Hello, playground"
