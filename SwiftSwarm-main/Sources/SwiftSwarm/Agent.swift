//
//  Agent.swift
//
//
//  Created by James Rochabrun on 10/18/24.
//

import SwiftOpenAI

/// A structure representing an agent in the system.
///
/// The `Agent` structure contains the essential properties required to define
/// an agent, including the model it uses, its instructions, and its available tools.
public struct Agent {
   
   /// The name of the agent.
   public var name: String
   
   /// The model associated with the agent.
   ///
   /// This defines the language model the agent is using for generating responses,
   /// such as `gpt-4` or another variant.
   public var model: Model
   
   /// The instructions provided to the agent.
   ///
   /// These are typically guidelines or system messages that define the behavior
   /// or scope of the agent when it generates responses.
   public var instructions: String
   
   /// The list of tools available to the agent.
   ///
   /// Each tool is a callable function that the agent can use to assist in generating
   /// responses or executing actions as part of its workflow.
   public var tools: [ChatCompletionParameters.Tool]
   
   public init(
      name: String,
      model: Model,
      instructions: String,
      tools: [ChatCompletionParameters.Tool])
   {
      self.name = name
      self.model = model
      self.instructions = instructions
      self.tools = tools
   }
}
