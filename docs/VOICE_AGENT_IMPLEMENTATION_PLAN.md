# Voice Agent Implementation Plan

## Executive Summary

This document provides a comprehensive implementation plan for adding voice agent capabilities to Swarm. The architecture introduces a `VoiceTransport` protocol abstraction layer and `VoiceAgent` implementation that integrates seamlessly with existing Swarm infrastructure.

---

## Problem Analysis

### Core Challenge
Swarm is a text-centric agent orchestration framework. Voice agents require:
1. **Real-time bidirectional audio streaming** - Not just request/response
2. **Multiple transport mechanisms** - WebRTC, WebSocket, on-device
3. **Voice-specific lifecycle events** - Audio levels, VAD, interruptions
4. **Tool execution during voice conversations** - Function calling mid-stream
5. **Integration with existing agent infrastructure** - Memory, guardrails, orchestration

### Key Constraints
- **Swift 6.2 concurrency** - Must use actors, Sendable, async/await
- **Cross-platform** - iOS 14+, macOS 11+ (iOS 26+ for SpeechAnalyzer)
- **Protocol-first design** - Consistent with existing Swarm patterns
- **Backward compatibility** - Existing text agents must continue to work

### Critical Success Factors
1. Voice agents work with existing `Memory`, `Tool`, and `Handoff` systems
2. `VoiceEvent` extends `AgentEvent` for unified streaming
3. Provider implementations are swappable at runtime
4. Latency is acceptable for real-time conversation (<500ms round-trip)

---

## Architecture Design

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        User Application                              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  VoiceAgent (actor)                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ • Conforms to Agent protocol                                    ││
│  │ • Manages VoiceTransport lifecycle                              ││
│  │ • Emits VoiceEvent stream                                       ││
│  │ • Coordinates tool execution during voice                       ││
│  │ • Handles interruptions and turn-taking                         ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
           │                        │                        │
           ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐
│ VoiceTransport  │    │ VoiceTransport  │    │ VoiceTransport      │
│ (Protocol)      │    │ (Protocol)      │    │ (Protocol)          │
├─────────────────┤    ├─────────────────┤    ├─────────────────────┤
│ OpenAIRealtime  │    │ ElevenLabs      │    │ CascadedTransport   │
│ Transport       │    │ Transport       │    │ (STT→Agent→TTS)     │
│ • WebRTC/WS     │    │ • WebRTC        │    │ • AppleSpeech STT   │
│ • S2S model     │    │ • S2S model     │    │ • Any LLM           │
│ • Native tools  │    │ • MCP support   │    │ • Any TTS           │
└─────────────────┘    └─────────────────┘    └─────────────────────┘
```

### Protocol Hierarchy

```
Agent (existing)
  │
  ├── VoiceAgent (new) ─── conforms to Agent
  │
  └── uses ─┬─ VoiceTransport (new protocol)
            │     ├── OpenAIRealtimeTransport
            │     ├── ElevenLabsTransport
            │     └── CascadedTransport
            │
            ├─ VoiceConfiguration (new)
            │
            └─ VoiceEvent (extends AgentEvent)
```

---

## Detailed Protocol Designs

### 1. VoiceTransport Protocol

```swift
// Sources/Swarm/Voice/VoiceTransport.swift

import Foundation

/// Connection state for voice transports
public enum VoiceConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int)
    case failed(reason: String)
}

/// Voice activity detection result
public struct VoiceActivityResult: Sendable {
    public let isSpeaking: Bool
    public let confidence: Float  // 0.0 - 1.0
    public let timestamp: Date
}

/// Audio format configuration
public struct AudioFormat: Sendable, Equatable {
    public let sampleRate: Int      // e.g., 16000, 24000, 44100
    public let channels: Int         // 1 (mono) or 2 (stereo)
    public let bitsPerSample: Int    // 16 or 32

    public static let pcm16kMono = AudioFormat(sampleRate: 16000, channels: 1, bitsPerSample: 16)
    public static let pcm24kMono = AudioFormat(sampleRate: 24000, channels: 1, bitsPerSample: 16)
}

/// Protocol for voice transport implementations
///
/// VoiceTransport abstracts the underlying voice service (OpenAI Realtime,
/// ElevenLabs, Apple Speech) providing a unified interface for voice agents.
///
/// Example:
/// ```swift
/// let transport = OpenAIRealtimeTransport(apiKey: "...")
/// try await transport.connect()
///
/// for try await event in transport.events {
///     switch event {
///     case .transcript(let text, let isFinal):
///         print("User said: \(text)")
///     case .audioOutput(let data):
///         audioPlayer.play(data)
///     }
/// }
/// ```
public protocol VoiceTransport: Actor {
    /// Current connection state
    var connectionState: VoiceConnectionState { get }

    /// Whether the transport is currently connected
    var isConnected: Bool { get }

    /// The audio format used for input
    var inputFormat: AudioFormat { get }

    /// The audio format used for output
    var outputFormat: AudioFormat { get }

    /// Stream of events from the transport
    nonisolated var events: AsyncThrowingStream<VoiceTransportEvent, Error> { get }

    /// Connects to the voice service
    /// - Throws: `VoiceTransportError` if connection fails
    func connect() async throws

    /// Disconnects from the voice service
    func disconnect() async

    /// Sends audio data to the service
    /// - Parameter audioData: PCM audio data in the configured input format
    /// - Throws: `VoiceTransportError` if not connected or send fails
    func sendAudio(_ audioData: Data) async throws

    /// Sends a text message (for text-to-speech or as user input)
    /// - Parameter text: The text to send
    /// - Throws: `VoiceTransportError` if not connected
    func sendText(_ text: String) async throws

    /// Commits the current audio buffer (signals end of user speech)
    func commitAudioBuffer() async throws

    /// Interrupts the current response (barge-in)
    func interrupt() async throws

    /// Registers tools available during the voice session
    /// - Parameter tools: Tool definitions to register
    func registerTools(_ tools: [ToolSchema]) async throws

    /// Sends tool execution results back to the service
    /// - Parameters:
    ///   - toolCallId: The ID of the tool call
    ///   - result: The result of tool execution
    func sendToolResult(toolCallId: String, result: SendableValue) async throws

    /// Updates session configuration
    /// - Parameter configuration: New configuration to apply
    func updateConfiguration(_ configuration: VoiceSessionConfiguration) async throws
}

/// Events emitted by voice transports
public enum VoiceTransportEvent: Sendable {
    // MARK: - Connection Events
    case connectionStateChanged(VoiceConnectionState)

    // MARK: - Audio Events
    /// Audio data received from the service (assistant speaking)
    case audioOutput(data: Data, format: AudioFormat)

    /// Audio playback should be interrupted
    case audioInterrupted

    /// Voice activity detected in user input
    case voiceActivity(VoiceActivityResult)

    // MARK: - Transcript Events
    /// User speech transcribed
    case userTranscript(text: String, isFinal: Bool)

    /// Assistant response transcript
    case assistantTranscript(text: String, isFinal: Bool)

    // MARK: - Turn Events
    /// User started speaking
    case userSpeechStarted

    /// User stopped speaking
    case userSpeechEnded

    /// Assistant started responding
    case assistantResponseStarted

    /// Assistant finished responding
    case assistantResponseEnded

    // MARK: - Tool Events
    /// Service is requesting a tool call
    case toolCallRequested(id: String, name: String, arguments: [String: SendableValue])

    /// Tool call completed (acknowledgment)
    case toolCallCompleted(id: String)

    // MARK: - Error Events
    case error(VoiceTransportError)
}

/// Errors from voice transports
public enum VoiceTransportError: Error, Sendable {
    case notConnected
    case connectionFailed(reason: String)
    case authenticationFailed(reason: String)
    case audioFormatMismatch(expected: AudioFormat, received: AudioFormat)
    case sendFailed(reason: String)
    case timeout(operation: String, duration: Duration)
    case serviceError(code: Int, message: String)
    case interrupted
    case invalidConfiguration(reason: String)
}

/// Configuration for voice sessions
public struct VoiceSessionConfiguration: Sendable {
    /// System instructions for the voice agent
    public var instructions: String

    /// Voice ID or name (provider-specific)
    public var voice: String?

    /// Temperature for response generation
    public var temperature: Double

    /// Enable/disable voice activity detection
    public var vadEnabled: Bool

    /// VAD sensitivity threshold (0.0 - 1.0)
    public var vadThreshold: Float

    /// Whether to enable automatic turn detection
    public var autoTurnDetection: Bool

    /// Maximum response duration
    public var maxResponseDuration: Duration?

    /// Input audio transcription settings
    public var transcribeInput: Bool

    public init(
        instructions: String = "",
        voice: String? = nil,
        temperature: Double = 0.8,
        vadEnabled: Bool = true,
        vadThreshold: Float = 0.5,
        autoTurnDetection: Bool = true,
        maxResponseDuration: Duration? = nil,
        transcribeInput: Bool = true
    ) {
        self.instructions = instructions
        self.voice = voice
        self.temperature = temperature
        self.vadEnabled = vadEnabled
        self.vadThreshold = vadThreshold
        self.autoTurnDetection = autoTurnDetection
        self.maxResponseDuration = maxResponseDuration
        self.transcribeInput = transcribeInput
    }

    public static let `default` = VoiceSessionConfiguration()
}
```

### 2. VoiceEvent Extension

```swift
// Sources/Swarm/Voice/VoiceEvent.swift

import Foundation

/// Voice-specific events that extend AgentEvent
///
/// These events are emitted during voice agent execution to provide
/// real-time visibility into the voice conversation lifecycle.
public enum VoiceEvent: Sendable {
    // MARK: - Audio Lifecycle

    /// Voice session started
    case voiceSessionStarted(sessionId: String)

    /// Voice session ended
    case voiceSessionEnded(sessionId: String, reason: VoiceSessionEndReason)

    /// Connection state changed
    case connectionStateChanged(VoiceConnectionState)

    // MARK: - Speech Events

    /// User started speaking
    case userSpeechStarted(timestamp: Date)

    /// User stopped speaking
    case userSpeechEnded(timestamp: Date, duration: Duration)

    /// User speech was transcribed
    case userTranscript(text: String, isFinal: Bool, confidence: Float?)

    /// Assistant started speaking
    case assistantSpeechStarted(timestamp: Date)

    /// Assistant stopped speaking
    case assistantSpeechEnded(timestamp: Date, duration: Duration)

    /// Assistant response text (for display)
    case assistantTranscript(text: String, isFinal: Bool)

    // MARK: - Audio Data Events

    /// Raw audio output for playback
    case audioOutput(data: Data, format: AudioFormat)

    /// Audio input level (for visualization)
    case inputAudioLevel(level: Float)  // 0.0 - 1.0

    /// Audio output level (for visualization)
    case outputAudioLevel(level: Float)  // 0.0 - 1.0

    // MARK: - Conversation Flow

    /// User interrupted the assistant (barge-in)
    case userInterrupted(timestamp: Date)

    /// Turn changed
    case turnChanged(from: VoiceTurnParticipant, to: VoiceTurnParticipant)

    /// Silence detected
    case silenceDetected(duration: Duration)

    // MARK: - Tool Events (Voice-Specific)

    /// Tool call requested during voice conversation
    case voiceToolCallStarted(id: String, toolName: String)

    /// Tool call completed during voice conversation
    case voiceToolCallCompleted(id: String, toolName: String, duration: Duration)
}

/// Reason for voice session ending
public enum VoiceSessionEndReason: Sendable, Equatable {
    case userEnded
    case assistantEnded
    case timeout(Duration)
    case error(String)
    case connectionLost
}

/// Participant in voice conversation turn
public enum VoiceTurnParticipant: Sendable, Equatable {
    case user
    case assistant
    case system
}

// MARK: - AgentEvent Extension for Voice

extension AgentEvent {
    /// Creates an AgentEvent from a VoiceEvent
    ///
    /// This bridges voice-specific events into the standard AgentEvent stream,
    /// allowing voice agents to work with existing event handlers.
    public static func voice(_ voiceEvent: VoiceEvent) -> AgentEvent {
        switch voiceEvent {
        case .voiceSessionStarted:
            return .started(input: "[Voice Session Started]")
        case let .voiceSessionEnded(_, reason):
            switch reason {
            case .error(let message):
                return .failed(error: .internalError(reason: message))
            default:
                return .cancelled
            }
        case let .userTranscript(text, isFinal, _) where isFinal:
            return .started(input: text)
        case let .assistantTranscript(text, isFinal) where isFinal:
            return .outputChunk(chunk: text)
        case let .voiceToolCallStarted(_, toolName):
            return .toolCallStarted(call: ToolCall(toolName: toolName))
        default:
            // Voice-specific events that don't map to AgentEvent
            // Consumers should handle VoiceEvent directly for full fidelity
            return .outputToken(token: "")
        }
    }
}
```

### 3. VoiceAgent Implementation

```swift
// Sources/Swarm/Voice/VoiceAgent.swift

import Foundation

/// Configuration for VoiceAgent
public struct VoiceAgentConfiguration: Sendable {
    /// Base agent configuration
    public var agentConfiguration: AgentConfiguration

    /// Voice session configuration
    public var voiceConfiguration: VoiceSessionConfiguration

    /// Whether to emit audio data events (can be disabled for bandwidth)
    public var emitAudioData: Bool

    /// Whether to emit audio level events (for visualization)
    public var emitAudioLevels: Bool

    /// Timeout for waiting on transport connection
    public var connectionTimeout: Duration

    /// Enable automatic reconnection on connection loss
    public var autoReconnect: Bool

    /// Maximum reconnection attempts
    public var maxReconnectAttempts: Int

    public init(
        agentConfiguration: AgentConfiguration = .default,
        voiceConfiguration: VoiceSessionConfiguration = .default,
        emitAudioData: Bool = true,
        emitAudioLevels: Bool = true,
        connectionTimeout: Duration = .seconds(30),
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 3
    ) {
        self.agentConfiguration = agentConfiguration
        self.voiceConfiguration = voiceConfiguration
        self.emitAudioData = emitAudioData
        self.emitAudioLevels = emitAudioLevels
        self.connectionTimeout = connectionTimeout
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
    }

    public static let `default` = VoiceAgentConfiguration()
}

/// A voice-enabled agent that conducts conversations via audio
///
/// VoiceAgent wraps a VoiceTransport to provide agent capabilities over
/// voice channels. It integrates with the existing Swarm infrastructure
/// including tools, memory, guardrails, and handoffs.
///
/// Example:
/// ```swift
/// let transport = OpenAIRealtimeTransport(apiKey: apiKey)
/// let agent = VoiceAgent(
///     transport: transport,
///     tools: [WeatherTool(), CalculatorTool()],
///     instructions: "You are a helpful voice assistant."
/// )
///
/// // Start voice conversation
/// let stream = agent.startVoiceSession()
/// for try await event in stream {
///     switch event {
///     case .voice(let voiceEvent):
///         handleVoiceEvent(voiceEvent)
///     case .completed(let result):
///         print("Conversation ended: \(result.output)")
///     }
///     }
/// }
///
/// // Send audio from microphone
/// try await agent.sendAudio(microphoneBuffer)
/// ```
public actor VoiceAgent: Agent {
    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any Tool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Voice-Specific Properties

    /// The voice transport used for audio communication
    public let transport: any VoiceTransport

    /// Voice-specific configuration
    nonisolated public let voiceConfiguration: VoiceAgentConfiguration

    /// Current session ID (nil if not in session)
    public private(set) var currentSessionId: String?

    /// Whether a voice session is active
    public var isSessionActive: Bool { currentSessionId != nil }

    // MARK: - Private State

    private let _handoffs: [AnyHandoffConfiguration]
    private let toolRegistry: ToolRegistry
    private var isCancelled: Bool = false
    private var eventContinuation: AsyncThrowingStream<AgentEvent, Error>.Continuation?
    private var transportTask: Task<Void, Never>?
    private var conversationHistory: [MemoryMessage] = []

    // MARK: - Initialization

    /// Creates a new VoiceAgent
    ///
    /// - Parameters:
    ///   - transport: The voice transport to use
    ///   - tools: Tools available to the agent
    ///   - instructions: System instructions
    ///   - configuration: Voice agent configuration
    ///   - memory: Optional memory system
    ///   - inferenceProvider: Optional inference provider (for cascaded mode)
    ///   - tracer: Optional tracer for observability
    ///   - inputGuardrails: Input validation guardrails
    ///   - outputGuardrails: Output validation guardrails
    ///   - handoffs: Handoff configurations
    public init(
        transport: any VoiceTransport,
        tools: [any Tool] = [],
        instructions: String = "",
        configuration: VoiceAgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.transport = transport
        self.tools = tools
        self.instructions = instructions
        self.configuration = configuration.agentConfiguration
        self.voiceConfiguration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self._handoffs = handoffs
        self.toolRegistry = ToolRegistry(tools: tools)
    }

    // MARK: - Agent Protocol Methods

    /// Runs the agent with text input (converts to voice internally)
    ///
    /// For pure voice interactions, use `startVoiceSession()` instead.
    public func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        // Start voice session if not active
        if !isSessionActive {
            _ = try await startVoiceSession(hooks: hooks)
        }

        // Send text input
        try await transport.sendText(input)

        // Wait for response completion
        // This is a simplified implementation - full version tracks conversation turns
        let resultBuilder = AgentResult.Builder()
        _ = resultBuilder.start()

        // TODO: Wait for assistant response completion
        // For now, return immediately with pending result

        _ = resultBuilder.setOutput("[Voice response pending]")
        return resultBuilder.build()
    }

    /// Streams agent events including voice-specific events
    nonisolated public func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            do {
                // Start session and forward events
                let voiceStream = try await agent.startVoiceSession(hooks: hooks)

                // Send the text input
                try await agent.transport.sendText(input)

                // Forward voice events as AgentEvents
                for try await event in voiceStream {
                    continuation.yield(event)

                    // Check for completion
                    if case .completed = event {
                        break
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// Cancels the current voice session
    public func cancel() async {
        isCancelled = true
        transportTask?.cancel()
        transportTask = nil
        await transport.disconnect()
        currentSessionId = nil
    }

    // MARK: - Voice-Specific Methods

    /// Starts a voice session and returns an event stream
    ///
    /// - Parameter hooks: Optional lifecycle hooks
    /// - Returns: Stream of agent events including voice events
    /// - Throws: `VoiceTransportError` if connection fails
    public func startVoiceSession(hooks: (any RunHooks)? = nil) async throws -> AsyncThrowingStream<AgentEvent, Error> {
        guard !isSessionActive else {
            throw VoiceTransportError.invalidConfiguration(reason: "Session already active")
        }

        isCancelled = false
        let sessionId = UUID().uuidString
        currentSessionId = sessionId

        // Connect transport
        try await transport.connect()

        // Configure session
        var sessionConfig = voiceConfiguration.voiceConfiguration
        sessionConfig.instructions = instructions
        try await transport.updateConfiguration(sessionConfig)

        // Register tools
        let toolDefinitions = tools.map { tool in
            ToolSchema(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }
        try await transport.registerTools(toolDefinitions)

        // Notify hooks
        await hooks?.onAgentStart(context: nil, agent: self, input: "[Voice Session]")

        // Create event stream
        return StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            // Emit session started
            continuation.yield(.voice(.voiceSessionStarted(sessionId: sessionId)))

            // Process transport events
            do {
                for try await transportEvent in await agent.transport.events {
                    let agentEvent = try await agent.processTransportEvent(
                        transportEvent,
                        hooks: hooks,
                        continuation: continuation
                    )

                    if let event = agentEvent {
                        continuation.yield(event)
                    }

                    // Check for cancellation
                    if await agent.isCancelled {
                        break
                    }
                }

                // Session ended normally
                continuation.yield(.voice(.voiceSessionEnded(
                    sessionId: sessionId,
                    reason: .userEnded
                )))
                continuation.finish()
            } catch {
                continuation.yield(.voice(.voiceSessionEnded(
                    sessionId: sessionId,
                    reason: .error(error.localizedDescription)
                )))
                continuation.finish(throwing: error)
            }
        }
    }

    /// Sends audio data to the voice transport
    ///
    /// - Parameter audioData: PCM audio data
    /// - Throws: `VoiceTransportError` if not connected
    public func sendAudio(_ audioData: Data) async throws {
        guard isSessionActive else {
            throw VoiceTransportError.notConnected
        }
        try await transport.sendAudio(audioData)
    }

    /// Signals end of user speech
    public func commitAudio() async throws {
        try await transport.commitAudioBuffer()
    }

    /// Interrupts the assistant's response
    public func interrupt() async throws {
        try await transport.interrupt()
    }

    /// Ends the current voice session
    public func endSession() async {
        await cancel()
    }

    // MARK: - Private Methods

    private func processTransportEvent(
        _ event: VoiceTransportEvent,
        hooks: (any RunHooks)?,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> AgentEvent? {
        switch event {
        case let .connectionStateChanged(state):
            return .voice(.connectionStateChanged(state))

        case let .audioOutput(data, format):
            if voiceConfiguration.emitAudioData {
                return .voice(.audioOutput(data: data, format: format))
            }
            return nil

        case let .userTranscript(text, isFinal):
            // Store in memory if final
            if isFinal, let mem = memory {
                await mem.add(.user(text))
                conversationHistory.append(.user(text))
            }
            return .voice(.userTranscript(text: text, isFinal: isFinal, confidence: nil))

        case let .assistantTranscript(text, isFinal):
            // Store in memory if final
            if isFinal, let mem = memory {
                await mem.add(.assistant(text))
                conversationHistory.append(.assistant(text))
            }
            return .voice(.assistantTranscript(text: text, isFinal: isFinal))

        case let .toolCallRequested(id, name, arguments):
            // Execute tool
            return try await handleToolCall(
                id: id,
                name: name,
                arguments: arguments,
                hooks: hooks
            )

        case .userSpeechStarted:
            return .voice(.userSpeechStarted(timestamp: Date()))

        case .userSpeechEnded:
            return .voice(.userSpeechEnded(timestamp: Date(), duration: .zero))

        case .assistantResponseStarted:
            return .voice(.assistantSpeechStarted(timestamp: Date()))

        case .assistantResponseEnded:
            return .voice(.assistantSpeechEnded(timestamp: Date(), duration: .zero))

        case .audioInterrupted:
            return .voice(.userInterrupted(timestamp: Date()))

        case let .error(error):
            return .failed(error: .internalError(reason: error.localizedDescription))

        default:
            return nil
        }
    }

    private func handleToolCall(
        id: String,
        name: String,
        arguments: [String: SendableValue],
        hooks: (any RunHooks)?
    ) async throws -> AgentEvent {
        // Notify hooks
        if let tool = await toolRegistry.tool(named: name) {
            await hooks?.onToolStart(context: nil, agent: self, tool: tool, arguments: arguments)
        }

        // Emit tool call started
        let toolCall = ToolCall(toolName: name, arguments: arguments)

        do {
            // Execute tool
            let result = try await toolRegistry.execute(
                toolNamed: name,
                arguments: arguments,
                agent: self,
                context: nil
            )

            // Send result back to transport
            try await transport.sendToolResult(toolCallId: id, result: result)

            // Notify hooks
            if let tool = await toolRegistry.tool(named: name) {
                await hooks?.onToolEnd(context: nil, agent: self, tool: tool, result: result)
            }

            return .toolCallCompleted(
                call: toolCall,
                result: .success(callId: toolCall.id, output: result, duration: .zero)
            )
        } catch {
            // Send error result
            try await transport.sendToolResult(
                toolCallId: id,
                result: .string("Error: \(error.localizedDescription)")
            )

            return .toolCallFailed(
                call: toolCall,
                error: .toolExecutionFailed(toolName: name, underlyingError: error.localizedDescription)
            )
        }
    }
}

// MARK: - VoiceAgent.Builder

public extension VoiceAgent {
    /// Builder for creating VoiceAgent instances
    struct Builder: Sendable {
        private var transport: (any VoiceTransport)?
        private var tools: [any Tool] = []
        private var instructions: String = ""
        private var configuration: VoiceAgentConfiguration = .default
        private var memory: (any Memory)?
        private var inferenceProvider: (any InferenceProvider)?
        private var tracer: (any Tracer)?
        private var inputGuardrails: [any InputGuardrail] = []
        private var outputGuardrails: [any OutputGuardrail] = []
        private var handoffs: [AnyHandoffConfiguration] = []

        public init() {}

        @discardableResult
        public func transport(_ transport: any VoiceTransport) -> Builder {
            var copy = self
            copy.transport = transport
            return copy
        }

        @discardableResult
        public func tools(_ tools: [any Tool]) -> Builder {
            var copy = self
            copy.tools = tools
            return copy
        }

        @discardableResult
        public func instructions(_ instructions: String) -> Builder {
            var copy = self
            copy.instructions = instructions
            return copy
        }

        @discardableResult
        public func configuration(_ configuration: VoiceAgentConfiguration) -> Builder {
            var copy = self
            copy.configuration = configuration
            return copy
        }

        @discardableResult
        public func memory(_ memory: any Memory) -> Builder {
            var copy = self
            copy.memory = memory
            return copy
        }

        @discardableResult
        public func inferenceProvider(_ provider: any InferenceProvider) -> Builder {
            var copy = self
            copy.inferenceProvider = provider
            return copy
        }

        public func build() throws -> VoiceAgent {
            guard let transport = transport else {
                throw VoiceTransportError.invalidConfiguration(reason: "Transport is required")
            }

            return VoiceAgent(
                transport: transport,
                tools: tools,
                instructions: instructions,
                configuration: configuration,
                memory: memory,
                inferenceProvider: inferenceProvider,
                tracer: tracer,
                inputGuardrails: inputGuardrails,
                outputGuardrails: outputGuardrails,
                handoffs: handoffs
            )
        }
    }
}
```

---

## Provider Implementations

### 4. OpenAI Realtime Transport

```swift
// Sources/Swarm/Voice/Transports/OpenAIRealtimeTransport.swift

import Foundation

/// Transport mode for OpenAI Realtime API
public enum OpenAIRealtimeMode: Sendable {
    case webRTC(ephemeralKey: String)
    case webSocket(apiKey: String)
}

/// OpenAI Realtime API transport implementation
///
/// Provides speech-to-speech voice conversations using OpenAI's
/// Realtime API via WebRTC or WebSocket.
///
/// Example:
/// ```swift
/// let transport = OpenAIRealtimeTransport(
///     mode: .webRTC(ephemeralKey: ephemeralKey),
///     model: "gpt-4o-realtime-preview"
/// )
/// ```
public actor OpenAIRealtimeTransport: VoiceTransport {
    // MARK: - VoiceTransport Properties

    public private(set) var connectionState: VoiceConnectionState = .disconnected
    public var isConnected: Bool { connectionState == .connected }
    public let inputFormat: AudioFormat = .pcm24kMono
    public let outputFormat: AudioFormat = .pcm24kMono

    nonisolated public var events: AsyncThrowingStream<VoiceTransportEvent, Error> {
        _events
    }

    // MARK: - Configuration

    private let mode: OpenAIRealtimeMode
    private let model: String
    private let _events: AsyncThrowingStream<VoiceTransportEvent, Error>
    private let eventContinuation: AsyncThrowingStream<VoiceTransportEvent, Error>.Continuation

    // MARK: - Internal State

    // Note: Actual WebRTC/WebSocket implementation would use:
    // - swift-realtime-openai package for WebRTC
    // - URLSessionWebSocketTask for WebSocket
    private var webSocketTask: URLSessionWebSocketTask?

    // MARK: - Initialization

    public init(
        mode: OpenAIRealtimeMode,
        model: String = "gpt-4o-realtime-preview"
    ) {
        self.mode = mode
        self.model = model

        let (stream, continuation) = StreamHelper.makeStream(bufferSize: 200)
        self._events = stream
        self.eventContinuation = continuation
    }

    // MARK: - VoiceTransport Methods

    public func connect() async throws {
        connectionState = .connecting
        eventContinuation.yield(.connectionStateChanged(.connecting))

        switch mode {
        case .webRTC(let ephemeralKey):
            try await connectWebRTC(ephemeralKey: ephemeralKey)
        case .webSocket(let apiKey):
            try await connectWebSocket(apiKey: apiKey)
        }

        connectionState = .connected
        eventContinuation.yield(.connectionStateChanged(.connected))
    }

    public func disconnect() async {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        eventContinuation.yield(.connectionStateChanged(.disconnected))
    }

    public func sendAudio(_ audioData: Data) async throws {
        guard isConnected else {
            throw VoiceTransportError.notConnected
        }

        // Encode as base64 and send via WebSocket
        let base64Audio = audioData.base64EncodedString()
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]

        try await sendWebSocketMessage(message)
    }

    public func sendText(_ text: String) async throws {
        guard isConnected else {
            throw VoiceTransportError.notConnected
        }

        let message: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    ["type": "input_text", "text": text]
                ]
            ]
        ]

        try await sendWebSocketMessage(message)

        // Trigger response
        let responseMessage: [String: Any] = [
            "type": "response.create"
        ]
        try await sendWebSocketMessage(responseMessage)
    }

    public func commitAudioBuffer() async throws {
        let message: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        try await sendWebSocketMessage(message)
    }

    public func interrupt() async throws {
        let message: [String: Any] = [
            "type": "response.cancel"
        ]
        try await sendWebSocketMessage(message)
        eventContinuation.yield(.audioInterrupted)
    }

    public func registerTools(_ tools: [ToolSchema]) async throws {
        // Tools are registered during session update
        // Store for inclusion in session configuration
    }

    public func sendToolResult(toolCallId: String, result: SendableValue) async throws {
        let message: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": toolCallId,
                "output": result.description
            ]
        ]
        try await sendWebSocketMessage(message)

        // Continue response generation
        let responseMessage: [String: Any] = [
            "type": "response.create"
        ]
        try await sendWebSocketMessage(responseMessage)
    }

    public func updateConfiguration(_ configuration: VoiceSessionConfiguration) async throws {
        let message: [String: Any] = [
            "type": "session.update",
            "session": [
                "instructions": configuration.instructions,
                "voice": configuration.voice ?? "alloy",
                "temperature": configuration.temperature,
                "turn_detection": configuration.autoTurnDetection ? [
                    "type": "server_vad",
                    "threshold": configuration.vadThreshold
                ] : nil
            ].compactMapValues { $0 }
        ]
        try await sendWebSocketMessage(message)
    }

    // MARK: - Private Methods

    private func connectWebRTC(ephemeralKey: String) async throws {
        // WebRTC implementation would use swift-realtime-openai package
        // This is a placeholder for the actual implementation
        throw VoiceTransportError.invalidConfiguration(reason: "WebRTC requires swift-realtime-openai package")
    }

    private func connectWebSocket(apiKey: String) async throws {
        let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession.shared
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        Task {
            await receiveMessages()
        }
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }

        do {
            while true {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    try await handleServerMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        try await handleServerMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            eventContinuation.yield(.error(.connectionFailed(reason: error.localizedDescription)))
        }
    }

    private func handleServerMessage(_ text: String) async throws {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "response.audio.delta":
            if let audioBase64 = json["delta"] as? String,
               let audioData = Data(base64Encoded: audioBase64) {
                eventContinuation.yield(.audioOutput(data: audioData, format: outputFormat))
            }

        case "response.audio_transcript.delta":
            if let text = json["delta"] as? String {
                eventContinuation.yield(.assistantTranscript(text: text, isFinal: false))
            }

        case "response.audio_transcript.done":
            if let text = json["transcript"] as? String {
                eventContinuation.yield(.assistantTranscript(text: text, isFinal: true))
            }

        case "input_audio_buffer.speech_started":
            eventContinuation.yield(.userSpeechStarted)

        case "input_audio_buffer.speech_stopped":
            eventContinuation.yield(.userSpeechEnded)

        case "conversation.item.input_audio_transcription.completed":
            if let text = json["transcript"] as? String {
                eventContinuation.yield(.userTranscript(text: text, isFinal: true))
            }

        case "response.function_call_arguments.done":
            if let callId = json["call_id"] as? String,
               let name = json["name"] as? String,
               let argsString = json["arguments"] as? String,
               let argsData = argsString.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                let arguments = args.mapValues { SendableValue(any: $0) }
                eventContinuation.yield(.toolCallRequested(id: callId, name: name, arguments: arguments))
            }

        case "response.done":
            eventContinuation.yield(.assistantResponseEnded)

        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                eventContinuation.yield(.error(.serviceError(code: 0, message: message)))
            }

        default:
            break
        }
    }

    private func sendWebSocketMessage(_ message: [String: Any]) async throws {
        guard let task = webSocketTask else {
            throw VoiceTransportError.notConnected
        }

        let data = try JSONSerialization.data(withJSONObject: message)
        let string = String(data: data, encoding: .utf8)!
        try await task.send(.string(string))
    }
}
```

### 5. ElevenLabs Transport

```swift
// Sources/Swarm/Voice/Transports/ElevenLabsTransport.swift

import Foundation

/// ElevenLabs Conversational AI transport implementation
///
/// Provides voice conversations using ElevenLabs' WebRTC-based
/// Conversational AI platform.
///
/// Example:
/// ```swift
/// let transport = ElevenLabsTransport(agentId: "your-agent-id")
/// // Or with a private agent:
/// let transport = ElevenLabsTransport(conversationToken: token)
/// ```
public actor ElevenLabsTransport: VoiceTransport {
    // MARK: - VoiceTransport Properties

    public private(set) var connectionState: VoiceConnectionState = .disconnected
    public var isConnected: Bool { connectionState == .connected }
    public let inputFormat: AudioFormat = .pcm16kMono
    public let outputFormat: AudioFormat = .pcm16kMono

    nonisolated public var events: AsyncThrowingStream<VoiceTransportEvent, Error> {
        _events
    }

    // MARK: - Configuration

    private let agentId: String?
    private let conversationToken: String?
    private let _events: AsyncThrowingStream<VoiceTransportEvent, Error>
    private let eventContinuation: AsyncThrowingStream<VoiceTransportEvent, Error>.Continuation

    // Note: Actual implementation would use elevenlabs-swift-sdk
    // private var conversation: Conversation?

    // MARK: - Initialization

    /// Creates transport for a public ElevenLabs agent
    public init(agentId: String) {
        self.agentId = agentId
        self.conversationToken = nil

        let (stream, continuation) = StreamHelper.makeStream(bufferSize: 200)
        self._events = stream
        self.eventContinuation = continuation
    }

    /// Creates transport for a private ElevenLabs agent
    public init(conversationToken: String) {
        self.agentId = nil
        self.conversationToken = conversationToken

        let (stream, continuation) = StreamHelper.makeStream(bufferSize: 200)
        self._events = stream
        self.eventContinuation = continuation
    }

    // MARK: - VoiceTransport Methods

    public func connect() async throws {
        connectionState = .connecting
        eventContinuation.yield(.connectionStateChanged(.connecting))

        // Actual implementation would use:
        // if let agentId = agentId {
        //     conversation = try await ElevenLabs.startConversation(
        //         agentId: agentId,
        //         config: ConversationConfig(...)
        //     )
        // }

        connectionState = .connected
        eventContinuation.yield(.connectionStateChanged(.connected))
    }

    public func disconnect() async {
        // conversation?.endConversation()
        connectionState = .disconnected
        eventContinuation.yield(.connectionStateChanged(.disconnected))
    }

    public func sendAudio(_ audioData: Data) async throws {
        guard isConnected else {
            throw VoiceTransportError.notConnected
        }
        // ElevenLabs SDK handles audio automatically via microphone
        // This method would be used for custom audio input
    }

    public func sendText(_ text: String) async throws {
        guard isConnected else {
            throw VoiceTransportError.notConnected
        }
        // try await conversation?.sendMessage(text)
    }

    public func commitAudioBuffer() async throws {
        // ElevenLabs handles this automatically via VAD
    }

    public func interrupt() async throws {
        // Handled automatically when user speaks
    }

    public func registerTools(_ tools: [ToolSchema]) async throws {
        // ElevenLabs tools are configured on the agent in the dashboard
        // or via API before conversation starts
    }

    public func sendToolResult(toolCallId: String, result: SendableValue) async throws {
        // try await conversation?.sendToolResult(
        //     for: toolCallId,
        //     result: result.description
        // )
    }

    public func updateConfiguration(_ configuration: VoiceSessionConfiguration) async throws {
        // Configuration is set at conversation start
    }
}
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)

**Files to Create:**
```
Sources/Swarm/Voice/
├── VoiceTransport.swift          # Protocol + events
├── VoiceEvent.swift              # Voice-specific events
├── VoiceAgent.swift              # Agent implementation
├── VoiceError.swift              # Error types
└── VoiceConfiguration.swift      # Configuration types
```

**Tasks:**
1. [ ] Create `VoiceTransport` protocol with all methods
2. [ ] Define `VoiceTransportEvent` enum
3. [ ] Create `VoiceEvent` enum and AgentEvent extension
4. [ ] Implement `VoiceAgent` actor
5. [ ] Create `VoiceAgentConfiguration`
6. [ ] Add `VoiceAgent.Builder`
7. [ ] Write unit tests with mock transport

### Phase 2: OpenAI Realtime Transport (Week 3-4)

**Files to Create:**
```
Sources/Swarm/Voice/Transports/
├── OpenAIRealtimeTransport.swift
└── OpenAIRealtimeTypes.swift     # API message types
```

**Dependencies:**
- Add `swift-realtime-openai` package (optional, for WebRTC)

**Tasks:**
1. [ ] Implement WebSocket connection to OpenAI Realtime API
2. [ ] Handle all server event types
3. [ ] Implement audio buffer management
4. [ ] Add tool calling support
5. [ ] Add session configuration
6. [ ] Write integration tests

### Phase 3: ElevenLabs Transport (Week 5-6)

**Files to Create:**
```
Sources/Swarm/Voice/Transports/
├── ElevenLabsTransport.swift
└── ElevenLabsTypes.swift
```

**Dependencies:**
- Add `elevenlabs-swift-sdk` package

**Tasks:**
1. [ ] Wrap ElevenLabs SDK with VoiceTransport protocol
2. [ ] Map ElevenLabs events to VoiceTransportEvent
3. [ ] Handle client tools / MCP integration
4. [ ] Add authentication (public/private agents)
5. [ ] Write integration tests

### Phase 4: Cascaded Transport (Week 7-8)

**Files to Create:**
```
Sources/Swarm/Voice/Transports/
├── CascadedTransport.swift       # STT → Agent → TTS
├── AudioPipeline.swift           # Audio capture/playback
└── AppleSpeechProvider.swift     # SpeechAnalyzer wrapper
```

**Tasks:**
1. [ ] Create `AudioPipeline` for AVAudioEngine integration
2. [ ] Implement `AppleSpeechProvider` for iOS 26+ SpeechAnalyzer
3. [ ] Create `CascadedTransport` that composes STT + InferenceProvider + TTS
4. [ ] Add VAD using SpeechDetector
5. [ ] Integrate with existing Swarm text agents
6. [ ] Write integration tests

### Phase 5: Audio Utilities (Week 9)

**Files to Create:**
```
Sources/Swarm/Voice/Audio/
├── AudioCapture.swift            # Microphone input
├── AudioPlayback.swift           # Speaker output
├── AudioLevelMeter.swift         # Level monitoring
└── AudioFormat+Conversion.swift  # Format conversion
```

**Tasks:**
1. [ ] Create `AudioCapture` actor for microphone
2. [ ] Create `AudioPlayback` actor for speaker
3. [ ] Add audio format conversion utilities
4. [ ] Add audio level monitoring for UI
5. [ ] Write unit tests

### Phase 6: Integration & Documentation (Week 10)

**Tasks:**
1. [ ] Add `SwarmVoice` product to Package.swift
2. [ ] Create conditional compilation for voice features
3. [ ] Write comprehensive documentation
4. [ ] Add example code and playground
5. [ ] Create migration guide
6. [ ] Performance testing and optimization

---

## Package.swift Updates

```swift
// Package.swift additions

let package = Package(
    name: "Swarm",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "Swarm", targets: ["Swarm"]),
        .library(name: "SwarmVoice", targets: ["SwarmVoice"]),
    ],
    dependencies: [
        // Existing dependencies...

        // Voice dependencies (conditional)
        .package(
            url: "https://github.com/elevenlabs/elevenlabs-swift-sdk.git",
            from: "2.0.17"
        ),
        .package(
            url: "https://github.com/m1guelpf/swift-realtime-openai.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Swarm",
            // ... existing configuration
        ),
        .target(
            name: "SwarmVoice",
            dependencies: [
                "Swarm",
                .product(
                    name: "ElevenLabs",
                    package: "elevenlabs-swift-sdk",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
                .product(
                    name: "RealtimeOpenAI",
                    package: "swift-realtime-openai",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
            ],
            path: "Sources/SwarmVoice"
        ),
        .testTarget(
            name: "SwarmVoiceTests",
            dependencies: ["SwarmVoice"],
            path: "Tests/SwarmVoiceTests"
        ),
    ]
)
```

---

## Testing Strategy

### Mock Transport for Unit Tests

```swift
// Tests/SwarmVoiceTests/Mocks/MockVoiceTransport.swift

public actor MockVoiceTransport: VoiceTransport {
    public var connectionState: VoiceConnectionState = .disconnected
    public var isConnected: Bool { connectionState == .connected }
    public let inputFormat: AudioFormat = .pcm16kMono
    public let outputFormat: AudioFormat = .pcm16kMono

    private let eventContinuation: AsyncThrowingStream<VoiceTransportEvent, Error>.Continuation
    nonisolated public let events: AsyncThrowingStream<VoiceTransportEvent, Error>

    // Recorded calls for verification
    public private(set) var sentAudio: [Data] = []
    public private(set) var sentTexts: [String] = []
    public private(set) var toolResults: [(id: String, result: SendableValue)] = []

    public init() {
        let (stream, continuation) = StreamHelper.makeStream(bufferSize: 100)
        self.events = stream
        self.eventContinuation = continuation
    }

    public func connect() async throws {
        connectionState = .connected
        eventContinuation.yield(.connectionStateChanged(.connected))
    }

    public func disconnect() async {
        connectionState = .disconnected
        eventContinuation.yield(.connectionStateChanged(.disconnected))
    }

    public func sendAudio(_ audioData: Data) async throws {
        sentAudio.append(audioData)
    }

    public func sendText(_ text: String) async throws {
        sentTexts.append(text)
    }

    // ... other methods

    // Test helpers
    public func simulateUserTranscript(_ text: String, isFinal: Bool) {
        eventContinuation.yield(.userTranscript(text: text, isFinal: isFinal))
    }

    public func simulateAssistantResponse(_ text: String) {
        eventContinuation.yield(.assistantTranscript(text: text, isFinal: true))
    }

    public func simulateToolCall(id: String, name: String, arguments: [String: SendableValue]) {
        eventContinuation.yield(.toolCallRequested(id: id, name: name, arguments: arguments))
    }
}
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| WebRTC complexity | High | High | Use existing swift-realtime-openai package |
| Audio format incompatibility | Medium | Medium | Comprehensive format conversion utilities |
| Latency issues | Medium | High | Profiling, buffer optimization |
| Swift 6 concurrency issues | Medium | Medium | Strict actor isolation, Sendable conformance |
| API breaking changes | Low | High | Version pinning, abstraction layers |

---

## Success Metrics

1. **Latency**: Voice round-trip < 500ms for S2S transports
2. **Reliability**: 99%+ connection success rate
3. **Integration**: All existing agent features work with voice
4. **Test Coverage**: > 80% code coverage for voice module
5. **Documentation**: Complete API documentation and examples

---

## File Structure Summary

```
Sources/
├── Swarm/                    # Existing
│   ├── Core/
│   ├── Agents/
│   ├── Memory/
│   ├── Tools/
│   └── Orchestration/
│
└── SwarmVoice/               # NEW
    ├── VoiceTransport.swift
    ├── VoiceEvent.swift
    ├── VoiceAgent.swift
    ├── VoiceConfiguration.swift
    ├── VoiceError.swift
    │
    ├── Transports/
    │   ├── OpenAIRealtimeTransport.swift
    │   ├── ElevenLabsTransport.swift
    │   └── CascadedTransport.swift
    │
    └── Audio/
        ├── AudioCapture.swift
        ├── AudioPlayback.swift
        └── AudioFormat.swift

Tests/
└── SwarmVoiceTests/
    ├── VoiceAgentTests.swift
    ├── VoiceTransportTests.swift
    └── Mocks/
        └── MockVoiceTransport.swift
```

---

## Next Steps

1. **Review this plan** - Gather feedback on architecture decisions
2. **Create feature branch** - `feature/voice-agents`
3. **Start Phase 1** - Core infrastructure
4. **Iterate** - Refine based on implementation learnings

---

*Document Version: 1.0*
*Created: 2025-12-30*
*Author: Swarm Team*
