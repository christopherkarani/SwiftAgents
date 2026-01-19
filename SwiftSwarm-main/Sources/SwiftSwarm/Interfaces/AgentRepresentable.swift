//
//  AgentRepresentable.swift
//  
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI

/// A protocol that defines the requirements for an agent to be representable.
///
/// `AgentRepresentable` ensures that conforming types can be iterated over (via `CaseIterable`),
/// represented by a raw value (via `RawRepresentable`), and associated with an `Agent` instance.
///
/// This is useful for creating enums or other structures that represent different agents in the system.
public protocol AgentRepresentable: CaseIterable, RawRepresentable where RawValue == String {
   
   /// The `Agent` that contains all tools for agent orchestration.
   var agent: Agent { get }
   
   /// The base definition for this agent type.
   ///
   /// This property allows each conforming type to provide its base configuration
   /// such as model, instructions, and custom tools.
   /// This should only be used internally - consumers should always use the `agent`
   /// property when making run requests.
   var agentDefinition: AgentDefinition { get }
}

/// A wrapper structure that holds the base configuration for an agent.
///
/// This structure serves as an intermediate layer between the raw agent configuration
/// and its final form with orchestration tools. It helps separate the basic agent setup
/// from its runtime capabilities.
public struct AgentDefinition {
   
    /// The base agent configuration without orchestration tools.
    var agent: Agent
    
    /// Creates a new agent definition with the specified base configuration.
    ///
    /// - Parameter agent: The base agent configuration to use.
    public init(agent: Agent) {
        self.agent = agent
    }
}

public extension AgentRepresentable {
   
   var agent: Agent {
      let base = agentDefinition.agent
       return Agent(
           name: base.name,
           model: base.model,
           instructions: base.instructions,
           tools: base.tools + orchestrationTools)
   }
   
   /// A collection of tools that enable agent-to-agent communication and task delegation.
   ///
   /// This property automatically generates tools for each agent type in the system, allowing:
   /// - Seamless transitions between different agent roles
   /// - Dynamic task handoffs between agents
   ///
   /// Each generated tool:
   /// - Is named after its corresponding agent type
   /// - Can transfer control to the specified agent
   private var orchestrationTools: [ChatCompletionParameters.Tool] {
      var tools: [ChatCompletionParameters.Tool] = []
      for item in Self.allCases {
         tools.append(.init(function: .init(
            name: "\(item.rawValue)",
            strict: nil,
            description: "Transfer to \(item.rawValue) agent, for agent \(item.rawValue) perspective",
            parameters: .init(
               type: .object,
               properties: [
                  "agent": .init(type: .string, description: "Returns \(item.rawValue)")
               ],
               required: ["agent"]))))
      }
      return tools
   }
}
