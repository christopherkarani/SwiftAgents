//
//  StreamChunk.swift
//
//
//  Created by James Rochabrun on 10/22/24.
//

import Foundation
import SwiftOpenAI

/// A structure representing a chunk of streamed data during an agent's response generation.
///
/// The `StreamChunk` structure is used to capture portions of the response as they are streamed
/// from the agent, including any content, tool calls, delimiters, or a final response.
public struct StreamChunk {
   
   /// The content of the current chunk, if available.
   ///
   /// This represents a portion of the agent's response as a string, which may be incomplete or streamed progressively.
   public var content: String?
   
   /// A list of tool calls associated with the current chunk, if any.
   ///
   /// These tool calls represent actions that the agent may request or perform as part of generating the response.
   public var toolCalls: [ToolCall]?
   
   /// A delimiter that may indicate the start or end of a streamed section.
   ///
   /// This optional string can be used to signify when a chunk starts or ends, for example, with `"start"` or `"end"`.
   public var delim: String?
   
   /// The final response, if this chunk represents the conclusion of the stream.
   ///
   /// This property is set when the streaming process completes and the full `Response` is ready.
   public var response: Response?
}

