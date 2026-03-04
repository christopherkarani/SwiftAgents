
import Foundation
import FoundationModels
import Swarm
import PlaygroundSupport

PlaygroundSupport.PlaygroundPage.current.needsIndefiniteExecution = true

Task {
    do {
        let researcher = try Agent(
            instructions: "Research the topic and provide key facts."
        )
        let writer = try Agent(
            instructions: "Summarize the research in one short paragraph."
        )

        let result = try await Workflow()
            .step(researcher)
            .step(writer)
            .run("Swift concurrency")

        print("Workflow output: \(result.output)")
    } catch {
        print("Workflow error: \(error)")
    }
}
