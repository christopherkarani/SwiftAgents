
import Foundation
import FoundationModels
import Swarm
import PlaygroundSupport

PlaygroundSupport.PlaygroundPage.current.needsIndefiniteExecution = true

struct ResearchAgent: Agent {
    var provider: any InferenceProvider {
        
    }
    
    var instructions: String {
        "You are a careful research agent."
    }
    
    

    var loop: some AgentLoop {
        
        Generate()

    }
}


Task {
    print("Starting")
    let response = try! await ResearchAgent().run("Hello").output

    print("Agent Response: ", response)
    var greeting = "Hello, playground"
}

