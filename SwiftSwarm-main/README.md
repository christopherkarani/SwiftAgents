# SwiftSwarm

<img width="1419" alt="Screenshot 2024-10-23 at 11 49 51 AM" src="https://github.com/user-attachments/assets/328f265b-3921-4721-a859-50bc56bf140f">


[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)
[![swift-package-manager](https://img.shields.io/badge/package%20manager-compatible-brightgreen.svg?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iNjJweCIgaGVpZ2h0PSI0OXB4IiB2aWV3Qm94PSIwIDAgNjIgNDkiIHZlcnNpb249IjEuMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxuczp4bGluaz0iaHR0cDovL3d3dy53My5vcmcvMTk5OS94bGluayI+CiAgICA8IS0tIEdlbmVyYXRvcjogU2tldGNoIDYzLjEgKDkyNDUyKSAtIGh0dHBzOi8vc2tldGNoLmNvbSAtLT4KICAgIDx0aXRsZT5Hcm91cDwvdGl0bGU+CiAgICA8ZGVzYz5DcmVhdGVkIHdpdGggU2tldGNoLjwvZGVzYz4KICAgIDxnIGlkPSJQYWdlLTEiIHN0cm9rZT0ibm9uZSIgc3Ryb2tlLXdpZHRoPSIxIiBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPgogICAgICAgIDxnIGlkPSJHcm91cCIgZmlsbC1ydWxlPSJub256ZXJvIj4KICAgICAgICAgICAgPHBvbHlnb24gaWQ9IlBhdGgiIGZpbGw9IiNEQkI1NTEiIHBvaW50cz0iNTEuMzEwMzQ0OCAwIDEwLjY4OTY1NTIgMCAwIDEzLjUxNzI0MTQgMCA0OSA2MiA0OSA2MiAxMy41MTcyNDE0Ij48L3BvbHlnb24+CiAgICAgICAgICAgIDxwb2x5Z29uIGlkPSJQYXRoIiBmaWxsPSIjRjdFM0FGIiBwb2ludHM9IjI3IDI1IDMxIDI1IDM1IDI1IDM3IDI1IDM3IDE0IDI1IDE0IDI1IDI1Ij48L3BvbHlnb24+CiAgICAgICAgICAgIDxwb2x5Z29uIGlkPSJQYXRoIiBmaWxsPSIjRUZDNzVFIiBwb2ludHM9IjEwLjY4OTY1NTIgMCAwIDE0IDYyIDE0IDUxLjMxMDM0NDggMCI+PC9wb2x5Z29uPgogICAgICAgICAgICA8cG9seWdvbiBpZD0iUmVjdGFuZ2xlIiBmaWxsPSIjRjdFM0FGIiBwb2ludHM9IjI3IDAgMzUgMCAzNyAxNCAyNSAxNCI+PC9wb2x5Z29uPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+)](https://github.com/apple/swift-package-manager)

Swift framework exploring ergonomic, lightweight multi-agent orchestration. Highly inspired by OpenAI library [swarm](https://github.com/openai/swarm).

The primary goal is just exploratory and a starting point for Swift engineers to explore Agents in their apps. 
SwiftSwarm is open source and accepts contributions PR's are more than welcome!

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
- [Documentation](#documentation)
- [Demo](#demo)
- [Dependencies](#dependencies)

## Overview

SwiftSwarm focuses on making agent coordination and execution lightweight. Its main use case is to enable seamless transitions between agents in a conversation.

It accomplishes this through two abstractions: AgentRepresentable and ToolResponseHandler. An AgentRepresentable contains an Agent that encompasses instructions and tools. At any point, it can hand off a conversation to another Agent through the ToolResponseHandler.

⚠️ **Important**

> Same as Swarm OpenAI library, SwiftSwarm Agents are not related to Assistants in the Assistants API. They are named similarly for convenience, 
> but are otherwise completely unrelated. SwiftSwarm is entirely powered by the Chat Completions API and is hence 
> stateless between calls.

To see demonstrations of state management in iOS applications, visit the [Examples folder](https://github.com/jamesrochabrun/SwiftSwarm/tree/main/SwiftSwarmExample) in this project. These examples are demos only and are not intended for production use.

Note: Currently, only streaming is supported. While the project uses the OpenAI API exclusively, Claude support could be added to the roadmap if there is sufficient interest.

## Installation

### Swift Package Manager

1. Open your Swift project in Xcode.
2. Go to `File` ->  `Add Package Dependency`.
3. In the search bar, enter [this URL](https://github.com/jamesrochabrun/SwiftSwarm).
4. Choose the main branch. (see the note below). 
5. Click `Add Package`.

Note: Xcode has a quirk where it defaults an SPM package's upper limit to 2.0.0. This package is beyond that
limit, so you should not accept the defaults that Xcode proposes. Instead, enter the lower bound of the
[release version](https://github.com/jamesrochabrun/SwiftOpenAI/releases) that you'd like to support, and then
tab out of the input box for Xcode to adjust the upper bound. Alternatively, you may select `branch` -> `main`
to stay on the bleeding edge.

## Documentation

### The Agent model

```swift
/// A structure representing an agent in the system.
///
/// The `Agent` structure contains the essential properties required to define
/// an agent, including the model it uses, its instructions, and its available tools.

public struct Agent {
   public var name: String
   public var model: Model
   public var instructions: String
   public var tools: [ChatCompletionParameters.Tool]
}
```

SwiftSwarm enables autonomous agents through two main interfaces: `AgentRepresentable` and `ToolResponseHandler`

### The `AgentRepresentable` interface
 
```swift
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
```

### The `ToolResponseHandler` interface

```swift
public protocol ToolResponseHandler {
   
   /// The type of agent that this handler works with.
   ///
   /// `AgentType` must conform to the `AgentRepresentable` protocol, ensuring that
   /// it can be converted to or from an agent.
   associatedtype AgentType: AgentRepresentable
   
   /// Attempts to transfer the tool parameters to a matching agent.
   ///
   /// This method checks the provided parameters to find a suitable agent
   /// that matches the given tool keys and values, returning the corresponding agent if found.
   ///
   /// - Parameter parameters: A dictionary of parameters that may contain information
   ///   for selecting an agent.
   /// - Returns: An optional `Agent` that matches the parameters or `nil` if no match is found.
   func transferToAgent(_ parameters: [String: Any]) -> Agent?
   
   /// Handles the tool response content asynchronously.
   ///
   /// Given a set of parameters, this method processes the content generated by the tools
   /// and returns the resulting string asynchronously.
   ///
   /// - Parameter parameters: A dictionary of parameters containing tool inputs.
   /// - Returns: A string representing the tool's response content.
   /// - Throws: Any errors that may occur during content handling.
   func handleToolResponseContent(parameters: [String: Any]) async throws -> String?
}
```

### Usage

In this section, we will walk through step by step what to do to use SwiftSwarm

### 1 - Defining your agents:

First, define your agents using an enum with a `String` raw value that conforms to `AgentRepresentable`. Here's an example:

```swift
enum Team: String  {
   
   case engineer = "Engineer"
   case designer = "Designer"
   case product = "Product"
}
```

In this example, we have a Team enum with 3 agents. These agents can transfer the conversation to a new agent when the user's question requires specialized expertise. 

Now let's use the AgentRepresentable protocol to define the agents. The final implementation will look like this:

```swift
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
               tools: [])) // <---- you can define specific tools for each agent.
      case .designer:
            .init(agent: Agent(
               name: self.rawValue,
               model: .gpt4o,
               instructions: "You are a UX/UI designer, if user asks about you, you answer with your name \(self.rawValue)",
               tools: [])) // <---- you can define specific tools for each agent.
      case .product:
            .init(agent: Agent(
               name: self.rawValue,
               model: .gpt4o,
               instructions: "You are a product manager, if user asks about you, you answer with your name \(self.rawValue)",
               tools: [])) // <---- you can define specific tools for each agent.
      }
   }
}
```

Note: You can define specific tools for each agent.

### 2 - Defining your tools handler.

Now that we have defined our agents, we need to create an object that conforms to ToolResponseHandler. Here's an example:

```swift
struct TeamDemoResponseHandler: ToolResponseHandler {
   
   /// 1.
   typealias AgentType = Team 
   
   /// 2.
   func handleToolResponseContent(
      parameters: [String: Any])
      async throws -> String?
   {
      /// 3.
   }
}
```

1. The `ToolResponseHandler` associated type must be an enum that conforms to AgentRepresentable.

2. The `handleToolResponseContent` function is triggered when a function call associated with your agent tools occurs. This is where you implement custom functionality based on the provided parameters. 
   
   Note: The `ToolResponseHandler` automatically manages agent switching using the `transferToAgent` function in a protocol extension. 

3. When a function call is triggered, you can retrieve values using the keys defined in your tool definition's parameter properties. For instructions in how to define a tool got to `SwiftOpenAI` [function call documentation](https://github.com/jamesrochabrun/SwiftOpenAI?tab=readme-ov-file#function-calling).

### 3 - Instantiating a Swarm object.

SwiftSwarm relies on SwiftOpenAI to manage communication with OpenAI APIs. A Swarm object requires two dependencies:

- An instance of `OpenAIService`
- An instance of `ToolResponseHandler` 

The code will look like this:

```swift
import SwiftOpenAI
import SwiftSwarm

let apiKey = "MY_API_KEY"
let openAIService = OpenAIServiceFactory.service(apiKey: apiKey)
let toolResponseHandler = TeamDemoResponseHandler()
let swarm = Swarm(client: openAIService, toolResponseHandler: toolResponseHandler)

let userMessage = "I need design input"
let message = ChatCompletionParameters.Message(role: .user, content: .text(userMessage))
var currentAgent = Team.engineer.agent

let streamChunks = await swarm.runStream(agent: currentAgent, messages: [message])

for try await streamChunk in streamChunks {
   content += streamChunk.content ?? ""
   if let response = streamChunk.response {
      currentAgent = response.agent <--- Transfer to designer here.
   }
}

print("Switched to: \(currentAgent.name)") 
print("Content: \(content)")
   
```

This will print:

```console
Switched to: Designer
Content: As a UX/UI designer, I'm here to help you with your design needs. What specific aspect of design do you need input on? Whether it's user interface design, user experience strategy, or even color schemes and typography, feel free to let me know!
```

## Demo

Note: SwiftSwarm is stateless. For examples of how to manage agent conversations with state, please visit the [examples folder](https://github.com/jamesrochabrun/SwiftSwarm/tree/main/SwiftSwarmExample) in this repository.

![Screenshot 2024-10-23 at 4 17 34 PM](https://github.com/user-attachments/assets/7a6b70bd-4ab8-4e20-a078-b032fc1ceac7)

## Dependencies

This project uses [SwiftOpenAI](https://github.com/jamesrochabrun/SwiftOpenAI) as a dependency, therefore an OpenAI API Key is needed. Go to SwiftOpenAI documentation for more information.
