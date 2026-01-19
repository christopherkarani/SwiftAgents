//
//  Team.swift
//  SwiftSwarmExample
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI
import SwiftSwarm

enum Team: String, AgentRepresentable  {
   
   case engineer = "Engineer"
   case designer = "Designer"
   case product = "Product"
   
   var agentDefinition: AgentDefinition {
      switch self {
      case .engineer:
            .init(agent: Agent(
               name: self.rawValue,
               model: .gpt4o,
               instructions: "You are a technical engineer, if user asks about you, you answer with your name \(self.rawValue)",
               tools: []))
      case .designer:
            .init(agent: Agent(
               name: self.rawValue,
               model: .gpt4o,
               instructions: "You are a UX/UI designer, if user asks about you, you answer with your name \(self.rawValue)",
               tools: []))
      case .product:
            .init(agent: Agent(
               name: self.rawValue,
               model: .gpt4o,
               instructions: "You are a product manager, if user asks about you, you answer with your name \(self.rawValue)",
               tools: []))
      }
   }
}
