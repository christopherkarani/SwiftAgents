# Swarm Public API Catalog (Complete)

Generated: 2026-03-05
Source: swift package dump-symbol-graph --enable-all-traits --minimum-access-level public
Coverage: Swarm, SwarmHive, SwarmMCP, SwarmMembrane (+ extension symbol graphs)
Total symbols listed: 3910

Columns: symbol_path<TAB>kind<TAB>access<TAB>declaration<TAB>source

## Swarm (3609 symbols)
AgentError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
SessionError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
SendableValue.ConversionError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
WorkflowError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
GuardrailError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
ToolChainError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
ResilienceError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
MultiProviderError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
OpenRouterProviderError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
WorkflowValidationError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
ModelSettingsValidationError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
OpenRouterConfigurationError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
MCPError.helpAnchor	swift.property	public	var helpAnchor: String? { get }	
AgentError.failureReason	swift.property	public	var failureReason: String? { get }	
SessionError.failureReason	swift.property	public	var failureReason: String? { get }	
SendableValue.ConversionError.failureReason	swift.property	public	var failureReason: String? { get }	
WorkflowError.failureReason	swift.property	public	var failureReason: String? { get }	
GuardrailError.failureReason	swift.property	public	var failureReason: String? { get }	
ToolChainError.failureReason	swift.property	public	var failureReason: String? { get }	
ResilienceError.failureReason	swift.property	public	var failureReason: String? { get }	
MultiProviderError.failureReason	swift.property	public	var failureReason: String? { get }	
OpenRouterProviderError.failureReason	swift.property	public	var failureReason: String? { get }	
WorkflowValidationError.failureReason	swift.property	public	var failureReason: String? { get }	
ModelSettingsValidationError.failureReason	swift.property	public	var failureReason: String? { get }	
OpenRouterConfigurationError.failureReason	swift.property	public	var failureReason: String? { get }	
MCPError.failureReason	swift.property	public	var failureReason: String? { get }	
SessionError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
SendableValue.ConversionError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
WorkflowError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
GuardrailError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
ToolChainError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
ResilienceError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
MultiProviderError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
OpenRouterProviderError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
WorkflowValidationError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
ModelSettingsValidationError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
OpenRouterConfigurationError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
MCPError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	
WaxEmbeddingProviderAdapter.executionMode	swift.property	public	var executionMode: ProviderExecutionMode { get }	.build/checkouts/Wax/Sources/WaxVectorSearch/Embeddings/EmbeddingProvider.swift:20
SwarmRuntimeMode	swift.enum	public	enum SwarmRuntimeMode	Sources/Swarm/Core/AgentConfiguration.swift:19
SwarmRuntimeMode.requireHive	swift.enum.case	public	case requireHive	Sources/Swarm/Core/AgentConfiguration.swift:29
SwarmRuntimeMode.hive	swift.enum.case	public	case hive	Sources/Swarm/Core/AgentConfiguration.swift:21
SwarmRuntimeMode.swift	swift.enum.case	public	case swift	Sources/Swarm/Core/AgentConfiguration.swift:25
SwarmHiveRunOptionsOverride	swift.struct	public	struct SwarmHiveRunOptionsOverride	Sources/Swarm/Core/AgentConfiguration.swift:33
SwarmHiveRunOptionsOverride.debugPayloads	swift.property	public	var debugPayloads: Bool?	Sources/Swarm/Core/AgentConfiguration.swift:36
SwarmHiveRunOptionsOverride.maxConcurrentTasks	swift.property	public	var maxConcurrentTasks: Int?	Sources/Swarm/Core/AgentConfiguration.swift:35
SwarmHiveRunOptionsOverride.eventBufferCapacity	swift.property	public	var eventBufferCapacity: Int?	Sources/Swarm/Core/AgentConfiguration.swift:38
SwarmHiveRunOptionsOverride.deterministicTokenStreaming	swift.property	public	var deterministicTokenStreaming: Bool?	Sources/Swarm/Core/AgentConfiguration.swift:37
SwarmHiveRunOptionsOverride.init(maxSteps:maxConcurrentTasks:debugPayloads:deterministicTokenStreaming:eventBufferCapacity:)	swift.init	public	init(maxSteps: Int? = nil, maxConcurrentTasks: Int? = nil, debugPayloads: Bool? = nil, deterministicTokenStreaming: Bool? = nil, eventBufferCapacity: Int? = nil)	Sources/Swarm/Core/AgentConfiguration.swift:40
SwarmHiveRunOptionsOverride.maxSteps	swift.property	public	var maxSteps: Int?	Sources/Swarm/Core/AgentConfiguration.swift:34
SwarmEmbeddingProviderAdapter	swift.struct	public	struct SwarmEmbeddingProviderAdapter	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:5
SwarmEmbeddingProviderAdapter.dimensions	swift.property	public	var dimensions: Int { get }	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:12
SwarmEmbeddingProviderAdapter.modelIdentifier	swift.property	public	var modelIdentifier: String { get }	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:14
SwarmEmbeddingProviderAdapter.base	swift.property	public	let base: any EmbeddingProvider	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:6
SwarmEmbeddingProviderAdapter.embed(_:)	swift.method	public	func embed(_ texts: [String]) async throws -> [[Float]]	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:22
SwarmEmbeddingProviderAdapter.embed(_:)	swift.method	public	func embed(_ text: String) async throws -> [Float]	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:18
SwarmEmbeddingProviderAdapter.init(_:)	swift.init	public	init(_ base: any EmbeddingProvider)	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:8
AgentActor(instructions:generateBuilder:)	swift.macro	public	@attached(member, names: named(tools), named(instructions), named(configuration), named(memory), named(inferenceProvider), named(tracer), named(_memory), named(_inferenceProvider), named(_tracer), named(isCancelled), named(init), named(run), named(stream), named(cancel), named(Builder)) @attached(extension, conformances: AgentRuntime) macro AgentActor(instructions: String, generateBuilder: Bool = true)	Sources/Swarm/Macros/MacroDeclarations.swift:183
AgentActor(_:)	swift.macro	public	@attached(member, names: named(tools), named(instructions), named(configuration), named(memory), named(inferenceProvider), named(tracer), named(_memory), named(_inferenceProvider), named(_tracer), named(isCancelled), named(init), named(run), named(stream), named(cancel), named(Builder)) @attached(extension, conformances: AgentRuntime) macro AgentActor(_ instructions: String)	Sources/Swarm/Macros/MacroDeclarations.swift:250
AgentError	swift.enum	public	enum AgentError	Sources/Swarm/Core/AgentError.swift:11
AgentError.internalError(reason:)	swift.enum.case	public	case internalError(reason: String)	Sources/Swarm/Core/AgentError.swift:81
AgentError.invalidLoop(reason:)	swift.enum.case	public	case invalidLoop(reason: String)	Sources/Swarm/Core/AgentError.swift:29
AgentError.invalidInput(reason:)	swift.enum.case	public	case invalidInput(reason: String)	Sources/Swarm/Core/AgentError.swift:15
AgentError.toolNotFound(name:)	swift.enum.case	public	case toolNotFound(name: String)	Sources/Swarm/Core/AgentError.swift:34
AgentError.agentNotFound(name:)	swift.enum.case	public	case agentNotFound(name: String)	Sources/Swarm/Core/AgentError.swift:78
AgentError.contentFiltered(reason:)	swift.enum.case	public	case contentFiltered(reason: String)	Sources/Swarm/Core/AgentError.swift:54
AgentError.embeddingFailed(reason:)	swift.enum.case	public	case embeddingFailed(reason: String)	Sources/Swarm/Core/AgentError.swift:73
AgentError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Core/AgentError.swift:152
AgentError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Core/AgentError.swift:90
AgentError.generationFailed(reason:)	swift.enum.case	public	case generationFailed(reason: String)	Sources/Swarm/Core/AgentError.swift:60
AgentError.modelNotAvailable(model:)	swift.enum.case	public	case modelNotAvailable(model: String)	Sources/Swarm/Core/AgentError.swift:63
AgentError.rateLimitExceeded(retryAfter:)	swift.enum.case	public	case rateLimitExceeded(retryAfter: TimeInterval?)	Sources/Swarm/Core/AgentError.swift:68
AgentError.guardrailViolation(reason:)	swift.enum.case	public	case guardrailViolation(reason: String)	Sources/Swarm/Core/AgentError.swift:51
AgentError.recoverySuggestion	swift.property	public	var recoverySuggestion: String? { get }	Sources/Swarm/Core/AgentError.swift:139
AgentError.toolExecutionFailed(toolName:underlyingError:)	swift.enum.case	public	case toolExecutionFailed(toolName: String, underlyingError: String)	Sources/Swarm/Core/AgentError.swift:37
AgentError.unsupportedLanguage(language:)	swift.enum.case	public	case unsupportedLanguage(language: String)	Sources/Swarm/Core/AgentError.swift:57
AgentError.invalidToolArguments(toolName:reason:)	swift.enum.case	public	case invalidToolArguments(toolName: String, reason: String)	Sources/Swarm/Core/AgentError.swift:40
AgentError.contextWindowExceeded(tokenCount:limit:)	swift.enum.case	public	case contextWindowExceeded(tokenCount: Int, limit: Int)	Sources/Swarm/Core/AgentError.swift:48
AgentError.maxIterationsExceeded(iterations:)	swift.enum.case	public	case maxIterationsExceeded(iterations: Int)	Sources/Swarm/Core/AgentError.swift:23
AgentError.inferenceProviderUnavailable(reason:)	swift.enum.case	public	case inferenceProviderUnavailable(reason: String)	Sources/Swarm/Core/AgentError.swift:45
AgentError.toolCallingRequiresCloudProvider	swift.enum.case	public	case toolCallingRequiresCloudProvider	Sources/Swarm/Core/AgentError.swift:84
AgentError.timeout(duration:)	swift.enum.case	public	case timeout(duration: Duration)	Sources/Swarm/Core/AgentError.swift:26
AgentError.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/Core/AgentError.swift:20
AgentEvent	swift.enum	public	enum AgentEvent	Sources/Swarm/Core/AgentEvent.swift:32
AgentEvent.llmStarted(model:promptTokens:)	swift.enum.case	public	case llmStarted(model: String?, promptTokens: Int?)	Sources/Swarm/Core/AgentEvent.swift:134
AgentEvent.outputChunk(chunk:)	swift.enum.case	public	case outputChunk(chunk: String)	Sources/Swarm/Core/AgentEvent.swift:80
AgentEvent.outputToken(token:)	swift.enum.case	public	case outputToken(token: String)	Sources/Swarm/Core/AgentEvent.swift:77
AgentEvent.planUpdated(plan:stepCount:)	swift.enum.case	public	case planUpdated(plan: String, stepCount: Int)	Sources/Swarm/Core/AgentEvent.swift:96
AgentEvent.llmCompleted(model:promptTokens:completionTokens:duration:)	swift.enum.case	public	case llmCompleted(model: String?, promptTokens: Int?, completionTokens: Int?, duration: TimeInterval)	Sources/Swarm/Core/AgentEvent.swift:137
AgentEvent.handoffSkipped(from:to:reason:)	swift.enum.case	public	case handoffSkipped(from: String, to: String, reason: String)	Sources/Swarm/Core/AgentEvent.swift:113
AgentEvent.handoffStarted(from:to:input:)	swift.enum.case	public	case handoffStarted(from: String, to: String, input: String)	Sources/Swarm/Core/AgentEvent.swift:107
AgentEvent.memoryAccessed(operation:count:)	swift.enum.case	public	case memoryAccessed(operation: MemoryOperation, count: Int)	Sources/Swarm/Core/AgentEvent.swift:129
AgentEvent.toolCallFailed(call:error:)	swift.enum.case	public	case toolCallFailed(call: ToolCall, error: AgentError)	Sources/Swarm/Core/AgentEvent.swift:72
AgentEvent.guardrailFailed(error:)	swift.enum.case	public	case guardrailFailed(error: GuardrailError)	Sources/Swarm/Core/AgentEvent.swift:48
AgentEvent.guardrailPassed(name:type:)	swift.enum.case	public	case guardrailPassed(name: String, type: GuardrailType)	Sources/Swarm/Core/AgentEvent.swift:121
AgentEvent.thinkingPartial(partialThought:)	swift.enum.case	public	case thinkingPartial(partialThought: String)	Sources/Swarm/Core/AgentEvent.swift:56
AgentEvent.toolCallPartial(update:)	swift.enum.case	public	case toolCallPartial(update: PartialToolCallUpdate)	Sources/Swarm/Core/AgentEvent.swift:66
AgentEvent.toolCallStarted(call:)	swift.enum.case	public	case toolCallStarted(call: ToolCall)	Sources/Swarm/Core/AgentEvent.swift:61
AgentEvent.guardrailStarted(name:type:)	swift.enum.case	public	case guardrailStarted(name: String, type: GuardrailType)	Sources/Swarm/Core/AgentEvent.swift:118
AgentEvent.handoffCompleted(fromAgent:toAgent:)	swift.enum.case	public	case handoffCompleted(fromAgent: String, toAgent: String)	Sources/Swarm/Core/AgentEvent.swift:104
AgentEvent.handoffRequested(fromAgent:toAgent:reason:)	swift.enum.case	public	case handoffRequested(fromAgent: String, toAgent: String, reason: String?)	Sources/Swarm/Core/AgentEvent.swift:101
AgentEvent.iterationStarted(number:)	swift.enum.case	public	case iterationStarted(number: Int)	Sources/Swarm/Core/AgentEvent.swift:85
AgentEvent.toolCallCompleted(call:result:)	swift.enum.case	public	case toolCallCompleted(call: ToolCall, result: ToolResult)	Sources/Swarm/Core/AgentEvent.swift:69
AgentEvent.guardrailTriggered(name:type:message:)	swift.enum.case	public	case guardrailTriggered(name: String, type: GuardrailType, message: String?)	Sources/Swarm/Core/AgentEvent.swift:124
AgentEvent.iterationCompleted(number:)	swift.enum.case	public	case iterationCompleted(number: Int)	Sources/Swarm/Core/AgentEvent.swift:88
AgentEvent.handoffCompletedWithResult(from:to:result:)	swift.enum.case	public	case handoffCompletedWithResult(from: String, to: String, result: AgentResult)	Sources/Swarm/Core/AgentEvent.swift:110
AgentEvent.==(_:_:)	swift.func.op	public	static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool	Sources/Swarm/Core/AgentEvent.swift:321
AgentEvent.failed(error:)	swift.enum.case	public	case failed(error: AgentError)	Sources/Swarm/Core/AgentEvent.swift:42
AgentEvent.started(input:)	swift.enum.case	public	case started(input: String)	Sources/Swarm/Core/AgentEvent.swift:36
AgentEvent.decision(decision:options:)	swift.enum.case	public	case decision(decision: String, options: [String]?)	Sources/Swarm/Core/AgentEvent.swift:93
AgentEvent.thinking(thought:)	swift.enum.case	public	case thinking(thought: String)	Sources/Swarm/Core/AgentEvent.swift:53
AgentEvent.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/Core/AgentEvent.swift:45
AgentEvent.completed(result:)	swift.enum.case	public	case completed(result: AgentResult)	Sources/Swarm/Core/AgentEvent.swift:39
ContextKey	swift.struct	public	struct ContextKey<Value> where Value : Sendable	Sources/Swarm/Core/Execution/ContextKey.swift:30
ContextKey.==(_:_:)	swift.func.op	public	static func == (lhs: ContextKey<Value>, rhs: ContextKey<Value>) -> Bool	Sources/Swarm/Core/Execution/ContextKey.swift:43
ContextKey.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	Sources/Swarm/Core/Execution/ContextKey.swift:49
ContextKey.name	swift.property	public	let name: String	Sources/Swarm/Core/Execution/ContextKey.swift:32
ContextKey.expiresAt	swift.type.property	public	static let expiresAt: ContextKey<Date>	Sources/Swarm/Core/Execution/ContextKey.swift:125
ContextKey.timestamp	swift.type.property	public	static let timestamp: ContextKey<Date>	Sources/Swarm/Core/Execution/ContextKey.swift:122
ContextKey.apiVersion	swift.type.property	public	static let apiVersion: ContextKey<String>	Sources/Swarm/Core/Execution/ContextKey.swift:70
ContextKey.correlationID	swift.type.property	public	static let correlationID: ContextKey<String>	Sources/Swarm/Core/Execution/ContextKey.swift:64
ContextKey.userID	swift.type.property	public	static let userID: ContextKey<String>	Sources/Swarm/Core/Execution/ContextKey.swift:58
ContextKey.language	swift.type.property	public	static let language: ContextKey<String>	Sources/Swarm/Core/Execution/ContextKey.swift:67
ContextKey.sessionID	swift.type.property	public	static let sessionID: ContextKey<String>	Sources/Swarm/Core/Execution/ContextKey.swift:61
ContextKey.permissions	swift.type.property	public	static let permissions: ContextKey<[String]>	Sources/Swarm/Core/Execution/ContextKey.swift:109
ContextKey.featureFlags	swift.type.property	public	static let featureFlags: ContextKey<[String]>	Sources/Swarm/Core/Execution/ContextKey.swift:115
ContextKey.tags	swift.type.property	public	static let tags: ContextKey<[String]>	Sources/Swarm/Core/Execution/ContextKey.swift:112
ContextKey.isDebugMode	swift.type.property	public	static let isDebugMode: ContextKey<Bool>	Sources/Swarm/Core/Execution/ContextKey.swift:96
ContextKey.verboseLogging	swift.type.property	public	static let verboseLogging: ContextKey<Bool>	Sources/Swarm/Core/Execution/ContextKey.swift:99
ContextKey.isAuthenticated	swift.type.property	public	static let isAuthenticated: ContextKey<Bool>	Sources/Swarm/Core/Execution/ContextKey.swift:93
ContextKey.isDryRun	swift.type.property	public	static let isDryRun: ContextKey<Bool>	Sources/Swarm/Core/Execution/ContextKey.swift:102
ContextKey.retryCount	swift.type.property	public	static let retryCount: ContextKey<Int>	Sources/Swarm/Core/Execution/ContextKey.swift:80
ContextKey.requestCount	swift.type.property	public	static let requestCount: ContextKey<Int>	Sources/Swarm/Core/Execution/ContextKey.swift:77
ContextKey.iterationCount	swift.type.property	public	static let iterationCount: ContextKey<Int>	Sources/Swarm/Core/Execution/ContextKey.swift:83
ContextKey.depth	swift.type.property	public	static let depth: ContextKey<Int>	Sources/Swarm/Core/Execution/ContextKey.swift:86
ContextKey.init(_:)	swift.init	public	init(_ name: String)	Sources/Swarm/Core/Execution/ContextKey.swift:37
EventLevel	swift.enum	public	enum EventLevel	Sources/Swarm/Observability/TraceEvent.swift:12
EventLevel.description	swift.property	public	var description: String { get }	Sources/Swarm/Observability/TraceEvent.swift:533
EventLevel.<(_:_:)	swift.func.op	public	static func < (lhs: EventLevel, rhs: EventLevel) -> Bool	Sources/Swarm/Observability/TraceEvent.swift:15
EventLevel.info	swift.enum.case	public	case info	Sources/Swarm/Observability/TraceEvent.swift:21
EventLevel.debug	swift.enum.case	public	case debug	Sources/Swarm/Observability/TraceEvent.swift:20
EventLevel.error	swift.enum.case	public	case error	Sources/Swarm/Observability/TraceEvent.swift:23
EventLevel.trace	swift.enum.case	public	case trace	Sources/Swarm/Observability/TraceEvent.swift:19
EventLevel.warning	swift.enum.case	public	case warning	Sources/Swarm/Observability/TraceEvent.swift:22
EventLevel.critical	swift.enum.case	public	case critical	Sources/Swarm/Observability/TraceEvent.swift:24
EventLevel.init(rawValue:)	swift.init	public	init?(rawValue: Int)	
InputGuard	swift.struct	public	struct InputGuard	Sources/Swarm/Guardrails/InputGuardrail.swift:137
InputGuard.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/InputGuardrail.swift:138
InputGuard.validate(_:context:)	swift.method	public	func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/InputGuardrail.swift:158
InputGuard.init(_:_:)	swift.init	public	init(_ name: String, _ validate: @escaping (String) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/InputGuardrail.swift:140
InputGuard.init(_:_:)	swift.init	public	init(_ name: String, _ validate: @escaping (String, AgentContext?) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/InputGuardrail.swift:150
MCPRequest	swift.struct	public	struct MCPRequest	Sources/Swarm/MCP/MCPProtocol.swift:43
MCPRequest.init(id:method:params:)	swift.init	public	init(id: String = UUID().uuidString, method: String, params: [String : SendableValue]? = nil)	Sources/Swarm/MCP/MCPProtocol.swift:93
MCPRequest.id	swift.property	public	let id: String	Sources/Swarm/MCP/MCPProtocol.swift:53
MCPRequest.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/MCP/MCPProtocol.swift:115
MCPRequest.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/MCP/MCPProtocol.swift:155
MCPRequest.method	swift.property	public	let method: String	Sources/Swarm/MCP/MCPProtocol.swift:65
MCPRequest.params	swift.property	public	let params: [String : SendableValue]?	Sources/Swarm/MCP/MCPProtocol.swift:71
MCPRequest.jsonrpc	swift.property	public	let jsonrpc: String	Sources/Swarm/MCP/MCPProtocol.swift:47
NoOpTracer	swift.class	public	actor NoOpTracer	Sources/Swarm/Observability/AgentTracer.swift:196
NoOpTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:206
NoOpTracer.trace(_:)	swift.method	public	func trace(_: TraceEvent) async	Sources/Swarm/Observability/AgentTracer.swift:201
NoOpTracer.init()	swift.init	public	init()	Sources/Swarm/Observability/AgentTracer.swift:198
SpanStatus	swift.enum	public	enum SpanStatus	Sources/Swarm/Observability/TraceSpan.swift:11
SpanStatus.ok	swift.enum.case	public	case ok	Sources/Swarm/Observability/TraceSpan.swift:15
SpanStatus.error	swift.enum.case	public	case error	Sources/Swarm/Observability/TraceSpan.swift:17
SpanStatus.active	swift.enum.case	public	case active	Sources/Swarm/Observability/TraceSpan.swift:13
SpanStatus.init(rawValue:)	swift.init	public	init?(rawValue: String)	
SpanStatus.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/Observability/TraceSpan.swift:19
Statistics	swift.struct	public	struct Statistics	Sources/Swarm/Resilience/CircuitBreaker.swift:251
Statistics.successRate	swift.property	public	var successRate: Double? { get }	Sources/Swarm/Resilience/CircuitBreaker.swift:268
Statistics.failureCount	swift.property	public	let failureCount: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:259
Statistics.successCount	swift.property	public	let successCount: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:262
Statistics.lastFailureTime	swift.property	public	let lastFailureTime: Date?	Sources/Swarm/Resilience/CircuitBreaker.swift:265
Statistics.name	swift.property	public	let name: String	Sources/Swarm/Resilience/CircuitBreaker.swift:253
Statistics.state	swift.property	public	let state: CircuitBreaker.State	Sources/Swarm/Resilience/CircuitBreaker.swift:256
StringTool	swift.struct	public	struct StringTool	Sources/Swarm/Tools/BuiltInTools.swift:201
StringTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/BuiltInTools.swift:208
StringTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/BuiltInTools.swift:203
StringTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/BuiltInTools.swift:202
StringTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/BuiltInTools.swift:253
StringTool.init()	swift.init	public	init()	Sources/Swarm/Tools/BuiltInTools.swift:251
Summarizer	swift.protocol	public	protocol Summarizer : Sendable	Sources/Swarm/Memory/Summarizer.swift:14
Summarizer.isAvailable	swift.property	public	var isAvailable: Bool { get async }	Sources/Swarm/Memory/Summarizer.swift:16
Summarizer.summarize(_:maxTokens:)	swift.method	public	func summarize(_ text: String, maxTokens: Int) async throws -> String	Sources/Swarm/Memory/Summarizer.swift:25
TokenUsage	swift.struct	public	struct TokenUsage	Sources/Swarm/Core/AgentResult.swift:79
TokenUsage.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentResult.swift:290
TokenUsage.init(inputTokens:outputTokens:)	swift.init	public	init(inputTokens: Int, outputTokens: Int)	Sources/Swarm/Core/AgentResult.swift:95
TokenUsage.inputTokens	swift.property	public	let inputTokens: Int	Sources/Swarm/Core/AgentResult.swift:81
TokenUsage.totalTokens	swift.property	public	var totalTokens: Int { get }	Sources/Swarm/Core/AgentResult.swift:87
TokenUsage.outputTokens	swift.property	public	let outputTokens: Int	Sources/Swarm/Core/AgentResult.swift:84
TokenUsage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ToolChoice	swift.enum	public	enum ToolChoice	Sources/Swarm/Core/ModelSettings.swift:424
ToolChoice.auto	swift.enum.case	public	case auto	Sources/Swarm/Core/ModelSettings.swift:468
ToolChoice.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Core/ModelSettings.swift:427
ToolChoice.none	swift.enum.case	public	case none	Sources/Swarm/Core/ModelSettings.swift:471
ToolChoice.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Core/ModelSettings.swift:451
ToolChoice.required	swift.enum.case	public	case required	Sources/Swarm/Core/ModelSettings.swift:474
ToolChoice.specific(toolName:)	swift.enum.case	public	case specific(toolName: String)	Sources/Swarm/Core/ModelSettings.swift:477
ToolFilter	swift.struct	public	struct ToolFilter	Sources/Swarm/Tools/ToolChainBuilder.swift:386
ToolFilter.execute(input:)	swift.method	public	func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:411
ToolFilter.init(_:defaultValue:)	swift.init	public	init(_ predicate: @escaping (SendableValue) async throws -> Bool, defaultValue: SendableValue = .null)	Sources/Swarm/Tools/ToolChainBuilder.swift:396
ToolResult	swift.struct	public	struct ToolResult	Sources/Swarm/Core/AgentEvent.swift:238
ToolResult.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentEvent.swift:307
ToolResult.errorMessage	swift.property	public	let errorMessage: String?	Sources/Swarm/Core/AgentEvent.swift:252
ToolResult.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ToolResult.callId	swift.property	public	let callId: UUID	Sources/Swarm/Core/AgentEvent.swift:240
ToolResult.init(callId:isSuccess:output:duration:errorMessage:)	swift.init	public	init(callId: UUID, isSuccess: Bool, output: SendableValue, duration: Duration, errorMessage: String? = nil)	Sources/Swarm/Core/AgentEvent.swift:261
ToolResult.output	swift.property	public	let output: SendableValue	Sources/Swarm/Core/AgentEvent.swift:246
ToolResult.failure(callId:error:duration:)	swift.type.method	public	static func failure(callId: UUID, error: String, duration: Duration) -> ToolResult	Sources/Swarm/Core/AgentEvent.swift:291
ToolResult.success(callId:output:duration:)	swift.type.method	public	static func success(callId: UUID, output: SendableValue, duration: Duration) -> ToolResult	Sources/Swarm/Core/AgentEvent.swift:281
ToolResult.duration	swift.property	public	let duration: Duration	Sources/Swarm/Core/AgentEvent.swift:249
ToolResult.isSuccess	swift.property	public	let isSuccess: Bool	Sources/Swarm/Core/AgentEvent.swift:243
ToolSchema	swift.struct	public	struct ToolSchema	Sources/Swarm/Tools/ToolSchema.swift:16
ToolSchema.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/ToolSchema.swift:19
ToolSchema.description	swift.property	public	let description: String	Sources/Swarm/Tools/ToolSchema.swift:18
ToolSchema.init(name:description:parameters:)	swift.init	public	init(name: String, description: String, parameters: [ToolParameter])	Sources/Swarm/Tools/ToolSchema.swift:21
ToolSchema.name	swift.property	public	let name: String	Sources/Swarm/Tools/ToolSchema.swift:17
TraceEvent	swift.struct	public	struct TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:137
TraceEvent.agentError(traceId:spanId:agentName:error:metadata:source:)	swift.type.method	public	static func agentError(traceId: UUID, spanId: UUID, agentName: String, error: any Error, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:418
TraceEvent.agentStart(traceId:spanId:agentName:metadata:source:)	swift.type.method	public	static func agentStart(traceId: UUID, spanId: UUID = UUID(), agentName: String, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:386
TraceEvent.toolResult(traceId:spanId:toolName:duration:metadata:source:)	swift.type.method	public	static func toolResult(traceId: UUID, spanId: UUID, toolName: String, duration: TimeInterval, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:452
TraceEvent.description	swift.property	public	var description: String { get }	Sources/Swarm/Observability/TraceEvent.swift:506
TraceEvent.parentSpanId	swift.property	public	let parentSpanId: UUID?	Sources/Swarm/Observability/TraceEvent.swift:148
TraceEvent.agentComplete(traceId:spanId:agentName:duration:metadata:source:)	swift.type.method	public	static func agentComplete(traceId: UUID, spanId: UUID, agentName: String, duration: TimeInterval, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:401
TraceEvent.id	swift.property	public	let id: UUID	Sources/Swarm/Observability/TraceEvent.swift:139
TraceEvent.init(id:traceId:spanId:parentSpanId:timestamp:duration:kind:level:message:metadata:agentName:toolName:error:source:)	swift.init	public	init(id: UUID = UUID(), traceId: UUID, spanId: UUID = UUID(), parentSpanId: UUID? = nil, timestamp: Date = Date(), duration: TimeInterval? = nil, kind: EventKind, level: EventLevel = .info, message: String, metadata: [String : SendableValue] = [:], agentName: String? = nil, toolName: String? = nil, error: ErrorInfo? = nil, source: SourceLocation? = nil)	Sources/Swarm/Observability/TraceEvent.swift:181
TraceEvent.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
TraceEvent.kind	swift.property	public	let kind: EventKind	Sources/Swarm/Observability/TraceEvent.swift:157
TraceEvent.error	swift.property	public	let error: ErrorInfo?	Sources/Swarm/Observability/TraceEvent.swift:175
TraceEvent.level	swift.property	public	let level: EventLevel	Sources/Swarm/Observability/TraceEvent.swift:160
TraceEvent.custom(traceId:spanId:message:level:metadata:source:)	swift.type.method	public	static func custom(traceId: UUID, spanId: UUID = UUID(), message: String, level: EventLevel = .info, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:488
TraceEvent.source	swift.property	public	let source: SourceLocation?	Sources/Swarm/Observability/TraceEvent.swift:178
TraceEvent.spanId	swift.property	public	let spanId: UUID	Sources/Swarm/Observability/TraceEvent.swift:145
TraceEvent.Builder	swift.class	public	final class Builder	Sources/Swarm/Observability/TraceEvent.swift:218
TraceEvent.Builder.parentSpan(_:)	swift.method	public	@discardableResult func parentSpan(_ id: UUID) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:243
TraceEvent.Builder.addingMetadata(_:)	swift.method	public	@discardableResult func addingMetadata(_ additional: [String : SendableValue]) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:292
TraceEvent.Builder.tool(_:)	swift.method	public	@discardableResult func tool(_ name: String) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:306
TraceEvent.Builder.agent(_:)	swift.method	public	@discardableResult func agent(_ name: String) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:299
TraceEvent.Builder.build()	swift.method	public	func build() -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:344
TraceEvent.Builder.error(_:)	swift.method	public	@discardableResult func error(_ error: any Error) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:313
TraceEvent.Builder.error(_:)	swift.method	public	@discardableResult func error(_ errorInfo: ErrorInfo) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:320
TraceEvent.Builder.level(_:)	swift.method	public	@discardableResult func level(_ level: EventLevel) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:264
TraceEvent.Builder.source(file:function:line:)	swift.method	public	@discardableResult func source(file: String = #file, function: String = #function, line: Int = #line) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:327
TraceEvent.Builder.source(_:)	swift.method	public	@discardableResult func source(_ location: SourceLocation) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:338
TraceEvent.Builder.message(_:)	swift.method	public	@discardableResult func message(_ message: String) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:271
TraceEvent.Builder.init(traceId:kind:message:id:spanId:timestamp:level:)	swift.init	public	init(traceId: UUID, kind: EventKind, message: String, id: UUID = UUID(), spanId: UUID = UUID(), timestamp: Date = Date(), level: EventLevel = .info)	Sources/Swarm/Observability/TraceEvent.swift:222
TraceEvent.Builder.duration(_:)	swift.method	public	@discardableResult func duration(_ duration: TimeInterval) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:257
TraceEvent.Builder.metadata(key:value:)	swift.method	public	@discardableResult func metadata(key: String, value: SendableValue) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:278
TraceEvent.Builder.metadata(_:)	swift.method	public	@discardableResult func metadata(_ metadata: [String : SendableValue]) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:285
TraceEvent.Builder.timestamp(_:)	swift.method	public	@discardableResult func timestamp(_ date: Date) -> TraceEvent.Builder	Sources/Swarm/Observability/TraceEvent.swift:250
TraceEvent.message	swift.property	public	let message: String	Sources/Swarm/Observability/TraceEvent.swift:163
TraceEvent.thought(traceId:spanId:agentName:thought:metadata:source:)	swift.type.method	public	static func thought(traceId: UUID, spanId: UUID, agentName: String, thought: String, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:469
TraceEvent.traceId	swift.property	public	let traceId: UUID	Sources/Swarm/Observability/TraceEvent.swift:142
TraceEvent.duration	swift.property	public	let duration: TimeInterval?	Sources/Swarm/Observability/TraceEvent.swift:154
TraceEvent.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Observability/TraceEvent.swift:166
TraceEvent.toolCall(traceId:spanId:parentSpanId:toolName:metadata:source:)	swift.type.method	public	static func toolCall(traceId: UUID, spanId: UUID = UUID(), parentSpanId: UUID?, toolName: String, metadata: [String : SendableValue] = [:], source: SourceLocation? = nil) -> TraceEvent	Sources/Swarm/Observability/TraceEvent.swift:435
TraceEvent.toolName	swift.property	public	let toolName: String?	Sources/Swarm/Observability/TraceEvent.swift:172
TraceEvent.agentName	swift.property	public	let agentName: String?	Sources/Swarm/Observability/TraceEvent.swift:169
TraceEvent.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Observability/TraceEvent.swift:151
AgentResult	swift.struct	public	struct AgentResult	Sources/Swarm/Core/AgentResult.swift:23
AgentResult.tokenUsage	swift.property	public	let tokenUsage: TokenUsage?	Sources/Swarm/Core/AgentResult.swift:40
AgentResult.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentResult.swift:264
AgentResult.toolResults	swift.property	public	let toolResults: [ToolResult]	Sources/Swarm/Core/AgentResult.swift:31
AgentResult.runtimeEngine	swift.property	public	var runtimeEngine: String? { get }	Sources/Swarm/Core/AgentResult.swift:281
AgentResult.iterationCount	swift.property	public	let iterationCount: Int	Sources/Swarm/Core/AgentResult.swift:34
AgentResult.init(output:toolCalls:toolResults:iterationCount:duration:tokenUsage:metadata:)	swift.init	public	init(output: String, toolCalls: [ToolCall] = [], toolResults: [ToolResult] = [], iterationCount: Int = 1, duration: Duration = .zero, tokenUsage: TokenUsage? = nil, metadata: [String : SendableValue] = [:])	Sources/Swarm/Core/AgentResult.swift:54
AgentResult.output	swift.property	public	let output: String	Sources/Swarm/Core/AgentResult.swift:25
AgentResult.Builder	swift.class	public	final class Builder	Sources/Swarm/Core/AgentResult.swift:117
AgentResult.Builder.addToolResult(_:)	swift.method	public	@discardableResult func addToolResult(_ result: ToolResult) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:160
AgentResult.Builder.addToolCall(_:)	swift.method	public	@discardableResult func addToolCall(_ call: ToolCall) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:149
AgentResult.Builder.setMetadata(_:_:)	swift.method	public	@discardableResult func setMetadata(_ key: String, _ value: SendableValue) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:204
AgentResult.Builder.appendOutput(_:)	swift.method	public	@discardableResult func appendOutput(_ value: String) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:138
AgentResult.Builder.setTokenUsage(_:)	swift.method	public	@discardableResult func setTokenUsage(_ usage: TokenUsage) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:191
AgentResult.Builder.getIterationCount()	swift.method	public	func getIterationCount() -> Int	Sources/Swarm/Core/AgentResult.swift:219
AgentResult.Builder.incrementIteration()	swift.method	public	@discardableResult func incrementIteration() -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:170
AgentResult.Builder.build()	swift.method	public	func build() -> AgentResult	Sources/Swarm/Core/AgentResult.swift:227
AgentResult.Builder.start()	swift.method	public	@discardableResult func start() -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:180
AgentResult.Builder.getOutput()	swift.method	public	func getOutput() -> String	Sources/Swarm/Core/AgentResult.swift:212
AgentResult.Builder.setOutput(_:)	swift.method	public	@discardableResult func setOutput(_ value: String) -> AgentResult.Builder	Sources/Swarm/Core/AgentResult.swift:127
AgentResult.Builder.init()	swift.init	public	init()	Sources/Swarm/Core/AgentResult.swift:121
AgentResult.duration	swift.property	public	let duration: Duration	Sources/Swarm/Core/AgentResult.swift:37
AgentResult.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Core/AgentResult.swift:43
AgentResult.toolCalls	swift.property	public	let toolCalls: [ToolCall]	Sources/Swarm/Core/AgentResult.swift:28
AnyJSONTool	swift.protocol	public	protocol AnyJSONTool : Sendable	Sources/Swarm/Tools/Tool.swift:32
AnyJSONTool.parameters	swift.property	public	var parameters: [ToolParameter] { get }	Sources/Swarm/Tools/Tool.swift:40
AnyJSONTool.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/Tool.swift:37
AnyJSONTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:43
AnyJSONTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:46
AnyJSONTool.name	swift.property	public	var name: String { get }	Sources/Swarm/Tools/Tool.swift:34
AnyJSONTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/Tool.swift:61
AnyJSONTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:55
AnyJSONTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
StringTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
DateTimeTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
FunctionTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
WebSearchTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
CalculatorTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
ZoniSearchTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
AnyJSONToolAdapter.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
SemanticCompactorTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
AnyTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
AgentTool.optionalString(_:from:default:)	swift.method	public	func optionalString(_ key: String, from arguments: [String : SendableValue], default defaultValue: String? = nil) -> String?	Sources/Swarm/Tools/Tool.swift:130
AnyJSONTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
StringTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
DateTimeTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
FunctionTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
WebSearchTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
CalculatorTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
ZoniSearchTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
AnyJSONToolAdapter.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
SemanticCompactorTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
AnyTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
AgentTool.requiredString(_:from:)	swift.method	public	func requiredString(_ key: String, from arguments: [String : SendableValue]) throws -> String	Sources/Swarm/Tools/Tool.swift:114
AnyJSONTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
StringTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
DateTimeTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
FunctionTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
WebSearchTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
CalculatorTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
ZoniSearchTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
SemanticCompactorTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
AgentTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:73
AnyJSONTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
StringTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
DateTimeTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
FunctionTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
WebSearchTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
CalculatorTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
ZoniSearchTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
SemanticCompactorTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
AgentTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/Tool.swift:76
AnyJSONTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
StringTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
DateTimeTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
FunctionTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
WebSearchTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
CalculatorTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
ZoniSearchTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
AnyJSONToolAdapter.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
SemanticCompactorTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
AnyTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
AgentTool.validateArguments(_:)	swift.method	public	func validateArguments(_ arguments: [String : SendableValue]) throws	Sources/Swarm/Tools/Tool.swift:84
AnyJSONTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
StringTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
DateTimeTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
FunctionTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
WebSearchTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
CalculatorTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
ZoniSearchTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
AnyJSONToolAdapter.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
SemanticCompactorTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
AnyTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
AgentTool.normalizeArguments(_:)	swift.method	public	func normalizeArguments(_ arguments: [String : SendableValue]) throws -> [String : SendableValue]	Sources/Swarm/Tools/Tool.swift:100
AnyJSONTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
StringTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
DateTimeTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
FunctionTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
WebSearchTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
CalculatorTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
ZoniSearchTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
AnyJSONToolAdapter.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
SemanticCompactorTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
AnyTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
AgentTool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/Tool.swift:68
AnyJSONTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
StringTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
DateTimeTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
FunctionTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
WebSearchTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
CalculatorTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
ZoniSearchTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
AnyJSONToolAdapter.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
SemanticCompactorTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
AnyTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
AgentTool.execute(input:)	swift.method	public	mutating func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:135
AnyJSONTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
StringTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
DateTimeTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
FunctionTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
WebSearchTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
CalculatorTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
ZoniSearchTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
AnyJSONToolAdapter.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
SemanticCompactorTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
AnyTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
AgentTool.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Tools/Tool.swift:79
ContextMode	swift.enum	public	enum ContextMode	Sources/Swarm/Core/AgentConfiguration.swift:10
ContextMode.adaptive	swift.enum.case	public	case adaptive	Sources/Swarm/Core/AgentConfiguration.swift:12
ContextMode.strict4k	swift.enum.case	public	case strict4k	Sources/Swarm/Core/AgentConfiguration.swift:15
Environment	swift.struct	public	@propertyWrapper struct Environment<Value> where Value : Sendable	Sources/Swarm/Core/Environment.swift:12
Environment.wrappedValue	swift.property	public	var wrappedValue: Value { get }	Sources/Swarm/Core/Environment.swift:19
Environment.init(_:)	swift.init	public	init(_ keyPath: KeyPath<AgentEnvironment, Value>)	Sources/Swarm/Core/Environment.swift:15
MCPResource	swift.struct	public	struct MCPResource	Sources/Swarm/MCP/MCPResource.swift:24
MCPResource.description	swift.property	public	let description: String?	Sources/Swarm/MCP/MCPResource.swift:40
MCPResource.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/MCP/MCPResource.swift:149
MCPResource.init(uri:name:description:mimeType:)	swift.init	public	init(uri: String, name: String, description: String? = nil, mimeType: String? = nil)	Sources/Swarm/MCP/MCPResource.swift:55
MCPResource.uri	swift.property	public	let uri: String	Sources/Swarm/MCP/MCPResource.swift:29
MCPResource.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MCPResource.name	swift.property	public	let name: String	Sources/Swarm/MCP/MCPResource.swift:35
MCPResource.mimeType	swift.property	public	let mimeType: String?	Sources/Swarm/MCP/MCPResource.swift:46
MCPResponse	swift.struct	public	struct MCPResponse	Sources/Swarm/MCP/MCPProtocol.swift:200
MCPResponse.id	swift.property	public	let id: String	Sources/Swarm/MCP/MCPProtocol.swift:207
MCPResponse.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/MCP/MCPProtocol.swift:262
MCPResponse.error	swift.property	public	let error: MCPErrorObject?	Sources/Swarm/MCP/MCPProtocol.swift:219
MCPResponse.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/MCP/MCPProtocol.swift:304
MCPResponse.result	swift.property	public	let result: SendableValue?	Sources/Swarm/MCP/MCPProtocol.swift:213
MCPResponse.failure(id:error:)	swift.type.method	public	static func failure(id: String, error: MCPErrorObject) -> MCPResponse	Sources/Swarm/MCP/MCPProtocol.swift:371
MCPResponse.init(jsonrpc:id:result:error:)	swift.init	public	init(jsonrpc: String = "2.0", id: String, result: SendableValue? = nil, error: MCPErrorObject? = nil) throws	Sources/Swarm/MCP/MCPProtocol.swift:237
MCPResponse.jsonrpc	swift.property	public	let jsonrpc: String	Sources/Swarm/MCP/MCPProtocol.swift:204
MCPResponse.success(id:result:)	swift.type.method	public	static func success(id: String, result: SendableValue) -> MCPResponse	Sources/Swarm/MCP/MCPProtocol.swift:352
OSLogTracer	swift.class	public	actor OSLogTracer	Sources/Swarm/Observability/OSLogTracer.swift:51
OSLogTracer.production(subsystem:)	swift.type.method	public	static func production(subsystem: String) -> OSLogTracer	Sources/Swarm/Observability/OSLogTracer.swift:379
OSLogTracer.debug(subsystem:)	swift.type.method	public	static func debug(subsystem: String) -> OSLogTracer	Sources/Swarm/Observability/OSLogTracer.swift:395
OSLogTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/OSLogTracer.swift:79
OSLogTracer.Builder	swift.struct	public	struct Builder	Sources/Swarm/Observability/OSLogTracer.swift:290
OSLogTracer.Builder.minimumLevel(_:)	swift.method	public	func minimumLevel(_ level: EventLevel) -> OSLogTracer.Builder	Sources/Swarm/Observability/OSLogTracer.swift:317
OSLogTracer.Builder.emitSignposts(_:)	swift.method	public	func emitSignposts(_ emit: Bool) -> OSLogTracer.Builder	Sources/Swarm/Observability/OSLogTracer.swift:327
OSLogTracer.Builder.build()	swift.method	public	func build() -> OSLogTracer	Sources/Swarm/Observability/OSLogTracer.swift:336
OSLogTracer.Builder.category(_:)	swift.method	public	func category(_ category: String) -> OSLogTracer.Builder	Sources/Swarm/Observability/OSLogTracer.swift:307
OSLogTracer.Builder.init(subsystem:)	swift.init	public	init(subsystem: String)	Sources/Swarm/Observability/OSLogTracer.swift:296
OSLogTracer.default(subsystem:)	swift.type.method	public	static func `default`(subsystem: String) -> OSLogTracer	Sources/Swarm/Observability/OSLogTracer.swift:366
OSLogTracer.init(subsystem:category:minimumLevel:emitSignposts:)	swift.init	public	init(subsystem: String, category: String, minimumLevel: EventLevel = .debug, emitSignposts: Bool = true)	Sources/Swarm/Observability/OSLogTracer.swift:63
OutputGuard	swift.struct	public	struct OutputGuard	Sources/Swarm/Guardrails/OutputGuardrail.swift:181
OutputGuard.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/OutputGuardrail.swift:182
OutputGuard.validate(_:agent:context:)	swift.method	public	func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/OutputGuardrail.swift:212
OutputGuard.init(_:_:)	swift.init	public	init(_ name: String, _ validate: @escaping (String) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/OutputGuardrail.swift:184
OutputGuard.init(_:_:)	swift.init	public	init(_ name: String, _ validate: @escaping (String, AgentContext?) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/OutputGuardrail.swift:194
OutputGuard.init(_:_:)	swift.init	public	init(_ name: String, _ validate: @escaping OutputValidationHandler)	Sources/Swarm/Guardrails/OutputGuardrail.swift:204
RateLimiter	swift.class	public	actor RateLimiter	Sources/Swarm/Resilience/RateLimiter.swift:30
RateLimiter.tryAcquire()	swift.method	public	func tryAcquire() -> Bool	Sources/Swarm/Resilience/RateLimiter.swift:78
RateLimiter.init(maxRequestsPerMinute:)	swift.init	public	init(maxRequestsPerMinute: Int)	Sources/Swarm/Resilience/RateLimiter.swift:40
RateLimiter.reset()	swift.method	public	func reset()	Sources/Swarm/Resilience/RateLimiter.swift:88
RateLimiter.acquire()	swift.method	public	func acquire() async throws	Sources/Swarm/Resilience/RateLimiter.swift:62
RateLimiter.available	swift.property	public	var available: Int { get }	Sources/Swarm/Resilience/RateLimiter.swift:34
RateLimiter.init(maxTokens:refillRatePerSecond:)	swift.init	public	init(maxTokens: Int, refillRatePerSecond: Double)	Sources/Swarm/Resilience/RateLimiter.swift:49
RetryPolicy	swift.struct	public	struct RetryPolicy	Sources/Swarm/Resilience/RetryPolicy.swift:152
RetryPolicy.noRetry	swift.type.property	public	static let noRetry: RetryPolicy	Sources/Swarm/Resilience/RetryPolicy.swift:160
RetryPolicy.onRetry	swift.property	public	let onRetry: ((Int, any Error) async -> Void)?	Sources/Swarm/Resilience/RetryPolicy.swift:184
RetryPolicy.shouldRetry	swift.property	public	let shouldRetry: (any Error) -> Bool	Sources/Swarm/Resilience/RetryPolicy.swift:181
RetryPolicy.aggressive	swift.type.property	public	static let aggressive: RetryPolicy	Sources/Swarm/Resilience/RetryPolicy.swift:169
RetryPolicy.init(maxAttempts:backoff:shouldRetry:onRetry:)	swift.init	public	init(maxAttempts: Int = 3, backoff: BackoffStrategy = .exponential(base: 1.0, multiplier: 2.0, maxDelay: 60.0), shouldRetry: @escaping (any Error) -> Bool = { _ in true }, onRetry: ((Int, any Error) async -> Void)? = nil)	Sources/Swarm/Resilience/RetryPolicy.swift:194
RetryPolicy.maxAttempts	swift.property	public	let maxAttempts: Int	Sources/Swarm/Resilience/RetryPolicy.swift:175
RetryPolicy.==(_:_:)	swift.func.op	public	static func == (lhs: RetryPolicy, rhs: RetryPolicy) -> Bool	Sources/Swarm/Resilience/RetryPolicy.swift:271
RetryPolicy.backoff	swift.property	public	let backoff: BackoffStrategy	Sources/Swarm/Resilience/RetryPolicy.swift:178
RetryPolicy.execute(_:)	swift.method	public	func execute<T>(_ operation: () async throws -> T) async throws -> T where T : Sendable	Sources/Swarm/Resilience/RetryPolicy.swift:213
RetryPolicy.standard	swift.type.property	public	static let standard: RetryPolicy	Sources/Swarm/Resilience/RetryPolicy.swift:163
AgentBuilder	swift.struct	public	@resultBuilder struct AgentBuilder	Sources/Swarm/Agents/AgentBuilder.swift:447
AgentBuilder.Components	swift.struct	public	struct Components	Sources/Swarm/Agents/AgentBuilder.swift:451
AgentBuilder.buildBlock()	swift.type.method	public	static func buildBlock() -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:532
AgentBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: AgentBuilder.Components...) -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:484
AgentBuilder.buildEither(first:)	swift.type.method	public	static func buildEither(first component: AgentBuilder.Components) -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:542
AgentBuilder.buildEither(second:)	swift.type.method	public	static func buildEither(second component: AgentBuilder.Components) -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:547
AgentBuilder.buildOptional(_:)	swift.type.method	public	static func buildOptional(_ component: AgentBuilder.Components?) -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:537
AgentBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: any AgentComponent) -> AgentBuilder.Components	Sources/Swarm/Agents/AgentBuilder.swift:552
AgentContext	swift.class	public	actor AgentContext	Sources/Swarm/Core/Execution/AgentContext.swift:98
AgentContext.addMessage(_:)	swift.method	public	func addMessage(_ message: MemoryMessage)	Sources/Swarm/Core/Execution/AgentContext.swift:193
AgentContext.description	swift.property	public	nonisolated var description: String { get }	Sources/Swarm/Core/Execution/AgentContext.swift:383
AgentContext.executionId	swift.property	public	nonisolated let executionId: UUID	Sources/Swarm/Core/Execution/AgentContext.swift:105
AgentContext.getMessages()	swift.method	public	func getMessages() -> [MemoryMessage]	Sources/Swarm/Core/Execution/AgentContext.swift:203
AgentContext.removeTyped(_:)	swift.method	public	@discardableResult func removeTyped<T>(_: T.Type) -> T? where T : AgentContextProviding	Sources/Swarm/Core/Execution/AgentContext.swift:351
AgentContext.removeTyped(_:)	swift.method	public	func removeTyped(_ key: ContextKey<some Sendable>)	Sources/Swarm/Core/Execution/ContextKey.swift:227
AgentContext.clearMessages()	swift.method	public	func clearMessages()	Sources/Swarm/Core/Execution/AgentContext.swift:208
AgentContext.originalInput	swift.property	public	nonisolated let originalInput: String	Sources/Swarm/Core/Execution/AgentContext.swift:102
AgentContext.recordExecution(agentName:)	swift.method	public	func recordExecution(agentName: String)	Sources/Swarm/Core/Execution/AgentContext.swift:220
AgentContext.debugDescription	swift.property	public	nonisolated var debugDescription: String { get }	Sources/Swarm/Core/Execution/AgentContext.swift:397
AgentContext.getExecutionPath()	swift.method	public	func getExecutionPath() -> [String]	Sources/Swarm/Core/Execution/AgentContext.swift:231
AgentContext.getPreviousOutput()	swift.method	public	func getPreviousOutput() -> String?	Sources/Swarm/Core/Execution/AgentContext.swift:250
AgentContext.setPreviousOutput(_:)	swift.method	public	func setPreviousOutput(_ result: AgentResult)	Sources/Swarm/Core/Execution/AgentContext.swift:243
AgentContext.get(_:)	swift.method	public	func get(_ key: AgentContextKey) -> SendableValue?	Sources/Swarm/Core/Execution/AgentContext.swift:157
AgentContext.get(_:)	swift.method	public	func get(_ key: String) -> SendableValue?	Sources/Swarm/Core/Execution/AgentContext.swift:149
AgentContext.set(_:value:)	swift.method	public	func set(_ key: AgentContextKey, value: SendableValue)	Sources/Swarm/Core/Execution/AgentContext.swift:175
AgentContext.set(_:value:)	swift.method	public	func set(_ key: String, value: SendableValue)	Sources/Swarm/Core/Execution/AgentContext.swift:166
AgentContext.copy(additionalValues:)	swift.method	public	func copy(additionalValues: [String : SendableValue] = [:]) -> AgentContext	Sources/Swarm/Core/Execution/AgentContext.swift:309
AgentContext.init(input:initialValues:)	swift.init	public	init(input: String, initialValues: [String : SendableValue] = [:])	Sources/Swarm/Core/Execution/AgentContext.swift:130
AgentContext.merge(from:overwrite:)	swift.method	public	func merge(from other: AgentContext, overwrite: Bool = false) async	Sources/Swarm/Core/Execution/AgentContext.swift:270
AgentContext.typed(_:)	swift.method	public	func typed<T>(_: T.Type) -> T? where T : AgentContextProviding	Sources/Swarm/Core/Execution/AgentContext.swift:342
AgentContext.remove(_:)	swift.method	public	@discardableResult func remove(_ key: String) -> SendableValue?	Sources/Swarm/Core/Execution/AgentContext.swift:184
AgentContext.allKeys	swift.property	public	var allKeys: [String] { get }	Sources/Swarm/Core/Execution/AgentContext.swift:111
AgentContext.getTyped(_:default:)	swift.method	public	func getTyped<T>(_ key: ContextKey<T>, default defaultValue: T) -> T where T : Decodable, T : Sendable	Sources/Swarm/Core/Execution/ContextKey.swift:215
AgentContext.getTyped(_:)	swift.method	public	func getTyped<T>(_ key: ContextKey<T>) -> T? where T : Decodable, T : Sendable	Sources/Swarm/Core/Execution/ContextKey.swift:162
AgentContext.hasTyped(_:)	swift.method	public	func hasTyped(_ key: ContextKey<some Sendable>) -> Bool	Sources/Swarm/Core/Execution/ContextKey.swift:242
AgentContext.hasTyped(_:)	swift.method	public	func hasTyped<T>(_: T.Type) -> Bool where T : AgentContextProviding	Sources/Swarm/Core/Execution/AgentContext.swift:359
AgentContext.setTyped(_:value:)	swift.method	public	func setTyped<T>(_ key: ContextKey<T>, value: T) where T : Encodable, T : Sendable	Sources/Swarm/Core/Execution/ContextKey.swift:142
AgentContext.setTyped(_:)	swift.method	public	func setTyped<T>(_ context: T) where T : AgentContextProviding	Sources/Swarm/Core/Execution/AgentContext.swift:334
AgentContext.snapshot	swift.property	public	var snapshot: [String : SendableValue] { get }	Sources/Swarm/Core/Execution/AgentContext.swift:119
AgentContext.createdAt	swift.property	public	nonisolated let createdAt: Date	Sources/Swarm/Core/Execution/AgentContext.swift:108
AgentRuntime	swift.protocol	public	protocol AgentRuntime : Sendable	Sources/Swarm/Core/AgentRuntime.swift:31
AgentRuntime.instructions	swift.property	public	nonisolated var instructions: String { get }	Sources/Swarm/Core/AgentRuntime.swift:42
AgentRuntime.configuration	swift.property	public	nonisolated var configuration: AgentConfiguration { get }	Sources/Swarm/Core/AgentRuntime.swift:45
AgentRuntime.inputGuardrails	swift.property	public	nonisolated var inputGuardrails: [any InputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:60
AgentRuntime.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:108
AgentRuntime.outputGuardrails	swift.property	public	nonisolated var outputGuardrails: [any OutputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:66
AgentRuntime.inferenceProvider	swift.property	public	nonisolated var inferenceProvider: (any InferenceProvider)? { get }	Sources/Swarm/Core/AgentRuntime.swift:51
AgentRuntime.run(_:session:observer:)	swift.method	public	func run(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:81
AgentRuntime.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:36
AgentRuntime.tools	swift.property	public	nonisolated var tools: [any AnyJSONTool] { get }	Sources/Swarm/Core/AgentRuntime.swift:39
AgentRuntime.cancel()	swift.method	public	func cancel() async	Sources/Swarm/Core/AgentRuntime.swift:92
AgentRuntime.memory	swift.property	public	nonisolated var memory: (any Memory)? { get }	Sources/Swarm/Core/AgentRuntime.swift:48
AgentRuntime.stream(_:session:observer:)	swift.method	public	nonisolated func stream(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:89
AgentRuntime.tracer	swift.property	public	nonisolated var tracer: (any Tracer)? { get }	Sources/Swarm/Core/AgentRuntime.swift:54
AgentRuntime.handoffs	swift.property	public	nonisolated var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Core/AgentRuntime.swift:72
AgentRuntime.environment(_:_:)	swift.method	public	func environment<V>(_ keyPath: WritableKeyPath<AgentEnvironment, V>, _ value: V) -> EnvironmentAgent where V : Sendable	Sources/Swarm/Core/EnvironmentAgent.swift:86
EnvironmentAgent.environment(_:_:)	swift.method	public	func environment<V>(_ keyPath: WritableKeyPath<AgentEnvironment, V>, _ value: V) -> EnvironmentAgent where V : Sendable	Sources/Swarm/Core/EnvironmentAgent.swift:86
Agent.environment(_:_:)	swift.method	public	func environment<V>(_ keyPath: WritableKeyPath<AgentEnvironment, V>, _ value: V) -> EnvironmentAgent where V : Sendable	Sources/Swarm/Core/EnvironmentAgent.swift:86
AnyAgent.environment(_:_:)	swift.method	public	func environment<V>(_ keyPath: WritableKeyPath<AgentEnvironment, V>, _ value: V) -> EnvironmentAgent where V : Sendable	Sources/Swarm/Core/EnvironmentAgent.swift:86
AgentRuntime.callAsFunction(_:)	swift.method	public	func callAsFunction(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:58
EnvironmentAgent.callAsFunction(_:)	swift.method	public	func callAsFunction(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:58
Agent.callAsFunction(_:)	swift.method	public	func callAsFunction(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:58
AnyAgent.callAsFunction(_:)	swift.method	public	func callAsFunction(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:58
AgentRuntime.inputGuardrails	swift.property	public	nonisolated var inputGuardrails: [any InputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:131
AgentRuntime.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:164
EnvironmentAgent.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:164
Agent.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:164
AgentRuntime.runWithResponse(_:observer:)	swift.method	public	func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:202
EnvironmentAgent.runWithResponse(_:observer:)	swift.method	public	func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:202
Agent.runWithResponse(_:observer:)	swift.method	public	func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:202
AnyAgent.runWithResponse(_:observer:)	swift.method	public	func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:202
AgentRuntime.outputGuardrails	swift.property	public	nonisolated var outputGuardrails: [any OutputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:134
AgentRuntime.inferenceProvider	swift.property	public	nonisolated var inferenceProvider: (any InferenceProvider)? { get }	Sources/Swarm/Core/AgentRuntime.swift:125
AgentRuntime.run(_:observer:)	swift.method	public	func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:144
EnvironmentAgent.run(_:observer:)	swift.method	public	func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:144
Agent.run(_:observer:)	swift.method	public	func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:144
AnyAgent.run(_:observer:)	swift.method	public	func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:144
AgentRuntime.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:119
EnvironmentAgent.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:119
Agent.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:119
AnyAgent.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:119
AgentRuntime.asTool(name:description:)	swift.method	public	func asTool(name: String? = nil, description: String? = nil) -> AgentTool	Sources/Swarm/Tools/AgentTool.swift:106
EnvironmentAgent.asTool(name:description:)	swift.method	public	func asTool(name: String? = nil, description: String? = nil) -> AgentTool	Sources/Swarm/Tools/AgentTool.swift:106
Agent.asTool(name:description:)	swift.method	public	func asTool(name: String? = nil, description: String? = nil) -> AgentTool	Sources/Swarm/Tools/AgentTool.swift:106
AnyAgent.asTool(name:description:)	swift.method	public	func asTool(name: String? = nil, description: String? = nil) -> AgentTool	Sources/Swarm/Tools/AgentTool.swift:106
AgentRuntime.memory	swift.property	public	nonisolated var memory: (any Memory)? { get }	Sources/Swarm/Core/AgentRuntime.swift:122
AgentRuntime.memory(_:)	swift.method	public	func memory(_ memory: any Memory) -> EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:97
EnvironmentAgent.memory(_:)	swift.method	public	func memory(_ memory: any Memory) -> EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:97
Agent.memory(_:)	swift.method	public	func memory(_ memory: any Memory) -> EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:97
AnyAgent.memory(_:)	swift.method	public	func memory(_ memory: any Memory) -> EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:97
AgentRuntime.stream(_:observer:)	swift.method	public	nonisolated func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:149
EnvironmentAgent.stream(_:observer:)	swift.method	public	nonisolated func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:149
Agent.stream(_:observer:)	swift.method	public	nonisolated func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:149
AnyAgent.stream(_:observer:)	swift.method	public	nonisolated func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:149
AgentRuntime.tracer	swift.property	public	nonisolated var tracer: (any Tracer)? { get }	Sources/Swarm/Core/AgentRuntime.swift:128
AgentRuntime.handoffs	swift.property	public	nonisolated var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Core/AgentRuntime.swift:137
AgentRuntime.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> some AgentRuntime 	Sources/Swarm/Core/ObservedAgent.swift:54
EnvironmentAgent.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> some AgentRuntime 	Sources/Swarm/Core/ObservedAgent.swift:54
Agent.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> some AgentRuntime 	Sources/Swarm/Core/ObservedAgent.swift:54
AnyAgent.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> some AgentRuntime 	Sources/Swarm/Core/ObservedAgent.swift:54
AgentRuntime.asHandoff()	swift.method	public	func asHandoff() -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:252
EnvironmentAgent.asHandoff()	swift.method	public	func asHandoff() -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:252
Agent.asHandoff()	swift.method	public	func asHandoff() -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:252
AnyAgent.asHandoff()	swift.method	public	func asHandoff() -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:252
AgentRuntime.asHandoff(_:)	swift.method	public	func asHandoff(_ configure: (HandoffOptions<Self>) -> HandoffOptions<Self>) -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:257
EnvironmentAgent.asHandoff(_:)	swift.method	public	func asHandoff(_ configure: (HandoffOptions<Self>) -> HandoffOptions<Self>) -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:257
Agent.asHandoff(_:)	swift.method	public	func asHandoff(_ configure: (HandoffOptions<Self>) -> HandoffOptions<Self>) -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:257
AnyAgent.asHandoff(_:)	swift.method	public	func asHandoff(_ configure: (HandoffOptions<Self>) -> HandoffOptions<Self>) -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:257
BuiltInTools	swift.enum	public	enum BuiltInTools	Sources/Swarm/Tools/BuiltInTools.swift:362
BuiltInTools.calculator	swift.type.property	public	static let calculator: CalculatorTool	Sources/Swarm/Tools/BuiltInTools.swift:367
BuiltInTools.semanticCompactor	swift.type.property	public	static let semanticCompactor: SemanticCompactorTool	Sources/Swarm/Tools/BuiltInTools.swift:377
BuiltInTools.all	swift.type.property	public	static var all: [any AnyJSONTool] { get }	Sources/Swarm/Tools/BuiltInTools.swift:383
BuiltInTools.string	swift.type.property	public	static let string: StringTool	Sources/Swarm/Tools/BuiltInTools.swift:374
BuiltInTools.dateTime	swift.type.property	public	static let dateTime: DateTimeTool	Sources/Swarm/Tools/BuiltInTools.swift:371
Conversation	swift.class	public	actor Conversation	Sources/Swarm/Core/Conversation.swift:7
Conversation.streamText(_:)	swift.method	public	@discardableResult func streamText(_ input: String) async throws -> String	Sources/Swarm/Core/Conversation.swift:57
Conversation.send(_:)	swift.method	public	@discardableResult func send(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/Conversation.swift:43
Conversation.init(with:session:observer:)	swift.init	public	init(with agent: some AgentRuntime, session: (any Session)? = nil, observer: (any AgentObserver)? = nil)	Sources/Swarm/Core/Conversation.swift:35
Conversation.stream(_:)	swift.method	public	nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/Conversation.swift:51
Conversation.Message	swift.struct	public	struct Message	Sources/Swarm/Core/Conversation.swift:9
Conversation.Message.Role	swift.enum	public	enum Role	Sources/Swarm/Core/Conversation.swift:10
Conversation.Message.Role.user	swift.enum.case	public	case user	Sources/Swarm/Core/Conversation.swift:11
Conversation.Message.Role.init(rawValue:)	swift.init	public	init?(rawValue: String)	
Conversation.Message.Role.assistant	swift.enum.case	public	case assistant	Sources/Swarm/Core/Conversation.swift:12
Conversation.Message.init(role:text:)	swift.init	public	init(role: Conversation.Message.Role, text: String)	Sources/Swarm/Core/Conversation.swift:18
Conversation.Message.role	swift.property	public	let role: Conversation.Message.Role	Sources/Swarm/Core/Conversation.swift:15
Conversation.Message.text	swift.property	public	let text: String	Sources/Swarm/Core/Conversation.swift:16
Conversation.messages	swift.property	public	var messages: [Conversation.Message] { get }	Sources/Swarm/Core/Conversation.swift:24
Conversation.observer	swift.property	public	var observer: (any AgentObserver)?	Sources/Swarm/Core/Conversation.swift:29
DateTimeTool	swift.struct	public	struct DateTimeTool	Sources/Swarm/Tools/BuiltInTools.swift:109
DateTimeTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/BuiltInTools.swift:113
DateTimeTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/BuiltInTools.swift:111
DateTimeTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/BuiltInTools.swift:110
DateTimeTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/BuiltInTools.swift:135
DateTimeTool.init()	swift.init	public	init()	Sources/Swarm/Tools/BuiltInTools.swift:133
FunctionTool	swift.struct	public	struct FunctionTool	Sources/Swarm/Tools/FunctionTool.swift:96
FunctionTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/FunctionTool.swift:101
FunctionTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/FunctionTool.swift:100
FunctionTool.init(name:description:parameters:handler:)	swift.init	public	init(name: String, description: String, parameters: [ToolParameter] = [], handler: @escaping (ToolArguments) async throws -> SendableValue)	Sources/Swarm/Tools/FunctionTool.swift:109
FunctionTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/FunctionTool.swift:99
FunctionTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/FunctionTool.swift:121
HybridMemory	swift.class	public	actor HybridMemory	Sources/Swarm/Memory/HybridMemory.swift:45
HybridMemory.hasSummary	swift.property	public	var hasSummary: Bool { get }	Sources/Swarm/Memory/HybridMemory.swift:107
HybridMemory.setSummary(_:)	swift.method	public	func setSummary(_ newSummary: String) async	Sources/Swarm/Memory/HybridMemory.swift:319
HybridMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/HybridMemory.swift:183
HybridMemory.diagnostics()	swift.method	public	func diagnostics() async -> HybridMemoryDiagnostics	Sources/Swarm/Memory/HybridMemory.swift:334
HybridMemory.clearSummary()	swift.method	public	func clearSummary() async	Sources/Swarm/Memory/HybridMemory.swift:324
HybridMemory.Configuration	swift.struct	public	struct Configuration	Sources/Swarm/Memory/HybridMemory.swift:49
HybridMemory.Configuration.summaryTokenRatio	swift.property	public	let summaryTokenRatio: Double	Sources/Swarm/Memory/HybridMemory.swift:60
HybridMemory.Configuration.init(shortTermMaxMessages:longTermSummaryTokens:summaryTokenRatio:summarizationThreshold:)	swift.init	public	init(shortTermMaxMessages: Int = 30, longTermSummaryTokens: Int = 1000, summaryTokenRatio: Double = 0.3, summarizationThreshold: Int = 60)	Sources/Swarm/Memory/HybridMemory.swift:72
HybridMemory.Configuration.shortTermMaxMessages	swift.property	public	let shortTermMaxMessages: Int	Sources/Swarm/Memory/HybridMemory.swift:54
HybridMemory.Configuration.longTermSummaryTokens	swift.property	public	let longTermSummaryTokens: Int	Sources/Swarm/Memory/HybridMemory.swift:57
HybridMemory.Configuration.summarizationThreshold	swift.property	public	let summarizationThreshold: Int	Sources/Swarm/Memory/HybridMemory.swift:63
HybridMemory.Configuration.default	swift.type.property	public	static let `default`: HybridMemory.Configuration	Sources/Swarm/Memory/HybridMemory.swift:51
HybridMemory.init(configuration:summarizer:tokenEstimator:)	swift.init	public	init(configuration: HybridMemory.Configuration = .default, summarizer: any Summarizer = TruncatingSummarizer.shared, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/HybridMemory.swift:122
HybridMemory.configuration	swift.property	public	let configuration: HybridMemory.Configuration	Sources/Swarm/Memory/HybridMemory.swift:86
HybridMemory.totalMessages	swift.property	public	var totalMessages: Int { get }	Sources/Swarm/Memory/HybridMemory.swift:112
HybridMemory.forceSummarize()	swift.method	public	func forceSummarize() async	Sources/Swarm/Memory/HybridMemory.swift:311
HybridMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/HybridMemory.swift:138
HybridMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/HybridMemory.swift:187
HybridMemory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/HybridMemory.swift:88
HybridMemory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/HybridMemory.swift:149
HybridMemory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/HybridMemory.swift:95
HybridMemory.summary	swift.property	public	var summary: String { get }	Sources/Swarm/Memory/HybridMemory.swift:102
Instructions	swift.struct	public	struct Instructions	Sources/Swarm/Agents/AgentBuilder.swift:25
Instructions.text	swift.property	public	let text: String	Sources/Swarm/Agents/AgentBuilder.swift:27
Instructions.init(_:)	swift.init	public	init(_ text: String)	Sources/Swarm/Agents/AgentBuilder.swift:32
PromptString	swift.struct	public	struct PromptString	Sources/Swarm/Macros/MacroDeclarations.swift:320
PromptString.StringInterpolation	swift.struct	public	struct StringInterpolation	Sources/Swarm/Macros/MacroDeclarations.swift:422
PromptString.StringInterpolation.appendInterpolation(_:)	swift.method	public	mutating func appendInterpolation(_ value: String)	Sources/Swarm/Macros/MacroDeclarations.swift:439
PromptString.StringInterpolation.appendInterpolation(_:)	swift.method	public	mutating func appendInterpolation(_ value: [String])	Sources/Swarm/Macros/MacroDeclarations.swift:449
PromptString.StringInterpolation.appendInterpolation(_:)	swift.method	public	mutating func appendInterpolation(_ value: Int)	Sources/Swarm/Macros/MacroDeclarations.swift:444
PromptString.StringInterpolation.appendInterpolation(_:)	swift.method	public	mutating func appendInterpolation(_ value: some Any)	Sources/Swarm/Macros/MacroDeclarations.swift:434
PromptString.StringInterpolation.appendLiteral(_:)	swift.method	public	mutating func appendLiteral(_ literal: String)	Sources/Swarm/Macros/MacroDeclarations.swift:430
PromptString.StringInterpolation.init(literalCapacity:interpolationCount:)	swift.init	public	init(literalCapacity: Int, interpolationCount: Int)	Sources/Swarm/Macros/MacroDeclarations.swift:425
PromptString.description	swift.property	public	var description: String { get }	Sources/Swarm/Macros/MacroDeclarations.swift:329
PromptString.init(stringLiteral:)	swift.init	public	init(stringLiteral value: String)	Sources/Swarm/Macros/MacroDeclarations.swift:338
PromptString.interpolations	swift.property	public	let interpolations: [String]	Sources/Swarm/Macros/MacroDeclarations.swift:326
PromptString.init(stringInterpolation:)	swift.init	public	init(stringInterpolation: PromptString.StringInterpolation)	Sources/Swarm/Macros/MacroDeclarations.swift:460
PromptString.init(content:interpolations:)	swift.init	public	init(content: String, interpolations: [String] = [])	Sources/Swarm/Macros/MacroDeclarations.swift:332
PromptString.content	swift.property	public	let content: String	Sources/Swarm/Macros/MacroDeclarations.swift:323
PromptString.init(_:)	swift.init	public	init(_ string: String)	Sources/Swarm/Macros/MacroDeclarations.swift:344
SessionError	swift.enum	public	enum SessionError	Sources/Swarm/Memory/Session.swift:105
SessionError.backendError(reason:underlyingError:)	swift.enum.case	public	case backendError(reason: String, underlyingError: String? = nil)	Sources/Swarm/Memory/Session.swift:122
SessionError.invalidState(reason:)	swift.enum.case	public	case invalidState(reason: String)	Sources/Swarm/Memory/Session.swift:119
SessionError.storageFailed(reason:underlyingError:)	swift.enum.case	public	case storageFailed(reason: String, underlyingError: String? = nil)	Sources/Swarm/Memory/Session.swift:113
SessionError.deletionFailed(reason:underlyingError:)	swift.enum.case	public	case deletionFailed(reason: String, underlyingError: String? = nil)	Sources/Swarm/Memory/Session.swift:116
SessionError.retrievalFailed(reason:underlyingError:)	swift.enum.case	public	case retrievalFailed(reason: String, underlyingError: String? = nil)	Sources/Swarm/Memory/Session.swift:110
SessionError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Memory/Session.swift:149
SessionError.==(_:_:)	swift.func.op	public	static func == (lhs: SessionError, rhs: SessionError) -> Bool	Sources/Swarm/Memory/Session.swift:128
StreamHelper	swift.enum	public	enum StreamHelper	Sources/Swarm/Core/StreamHelper.swift:26
StreamHelper.makeTrackedStream(bufferSize:operation:)	swift.type.method	public	static func makeTrackedStream<T>(bufferSize: Int = defaultBufferSize, operation: @escaping (AsyncThrowingStream<T, any Error>.Continuation) async throws -> Void) -> AsyncThrowingStream<T, any Error> where T : Sendable	Sources/Swarm/Core/StreamHelper.swift:89
StreamHelper.makeTrackedStream(for:bufferSize:operation:)	swift.type.method	public	static func makeTrackedStream<A, T>(for actor: A, bufferSize: Int = defaultBufferSize, operation: @escaping (A, AsyncThrowingStream<T, any Error>.Continuation) async throws -> Void) -> AsyncThrowingStream<T, any Error> where A : Actor, T : Sendable	Sources/Swarm/Core/StreamHelper.swift:127
StreamHelper.makeStream(bufferSize:)	swift.type.method	public	static func makeStream<T>(bufferSize: Int = defaultBufferSize) -> (stream: AsyncThrowingStream<T, any Error>, continuation: AsyncThrowingStream<T, any Error>.Continuation) where T : Sendable	Sources/Swarm/Core/StreamHelper.swift:39
StreamHelper.defaultBufferSize	swift.type.property	public	static let defaultBufferSize: Int	Sources/Swarm/Core/StreamHelper.swift:28
ToolCallGoal	swift.protocol	public	protocol ToolCallGoal : Sendable	Sources/Swarm/Tools/ToolCallGoal.swift:12
ToolCallGoal.providerCallId	swift.property	public	var providerCallId: String? { get }	Sources/Swarm/Tools/ToolCallGoal.swift:14
ToolCallGoal.toolName	swift.property	public	var toolName: String { get }	Sources/Swarm/Tools/ToolCallGoal.swift:17
ToolCallGoal.arguments	swift.property	public	var arguments: [String : SendableValue] { get }	Sources/Swarm/Tools/ToolCallGoal.swift:20
ToolCallGoal.providerCallId	swift.property	public	var providerCallId: String? { get }	Sources/Swarm/Tools/ToolCallGoal.swift:24
ToolRegistry	swift.class	public	actor ToolRegistry	Sources/Swarm/Tools/Tool.swift:508
ToolRegistry.unregister(named:)	swift.method	public	func unregister(named name: String)	Sources/Swarm/Tools/Tool.swift:607
ToolRegistry.tool(named:)	swift.method	public	func tool(named name: String) -> (any AnyJSONTool)?	Sources/Swarm/Tools/Tool.swift:614
ToolRegistry.count	swift.property	public	var count: Int { get }	Sources/Swarm/Tools/Tool.swift:527
ToolRegistry.init(tools:)	swift.init	public	init(tools: [any AnyJSONTool]) throws	Sources/Swarm/Tools/Tool.swift:537
ToolRegistry.init(tools:)	swift.init	public	init(tools: [some Tool]) throws	Sources/Swarm/Tools/Tool.swift:549
ToolRegistry.execute(toolNamed:arguments:agent:context:observer:)	swift.method	public	func execute(toolNamed name: String, arguments: [String : SendableValue], agent: (any AgentRuntime)? = nil, context: AgentContext? = nil, observer: (any AgentObserver)? = nil) async throws -> SendableValue	Sources/Swarm/Tools/Tool.swift:636
ToolRegistry.schemas	swift.property	public	var schemas: [ToolSchema] { get }	Sources/Swarm/Tools/Tool.swift:522
ToolRegistry.allTools	swift.property	public	var allTools: [any AnyJSONTool] { get }	Sources/Swarm/Tools/Tool.swift:512
ToolRegistry.contains(named:)	swift.method	public	func contains(named name: String) -> Bool	Sources/Swarm/Tools/Tool.swift:621
ToolRegistry.register(_:)	swift.method	public	func register(_ tool: any AnyJSONTool) throws	Sources/Swarm/Tools/Tool.swift:562
ToolRegistry.register(_:)	swift.method	public	func register(_ newTools: [any AnyJSONTool]) throws	Sources/Swarm/Tools/Tool.swift:596
ToolRegistry.register(_:)	swift.method	public	func register(_ newTools: [some Tool]) throws	Sources/Swarm/Tools/Tool.swift:583
ToolRegistry.register(_:)	swift.method	public	func register(_ tool: some Tool) throws	Sources/Swarm/Tools/Tool.swift:572
ToolRegistry.toolNames	swift.property	public	var toolNames: [String] { get }	Sources/Swarm/Tools/Tool.swift:517
ToolRegistry.init()	swift.init	public	init()	Sources/Swarm/Tools/Tool.swift:532
TraceContext	swift.class	public	actor TraceContext	Sources/Swarm/Observability/TraceContext.swift:33
TraceContext.withTrace(_:groupId:metadata:operation:)	swift.type.method	public	static func withTrace<T>(_ name: String, groupId: String? = nil, metadata: [String : SendableValue] = [:], operation: () async throws -> T) async rethrows -> T where T : Sendable	Sources/Swarm/Observability/TraceContext.swift:115
TraceContext.description	swift.property	public	nonisolated var description: String { get }	Sources/Swarm/Observability/TraceContext.swift:240
TraceContext.name	swift.property	public	let name: String	Sources/Swarm/Observability/TraceContext.swift:71
TraceContext.addSpan(_:)	swift.method	public	func addSpan(_ span: TraceSpan)	Sources/Swarm/Observability/TraceContext.swift:192
TraceContext.current	swift.type.property	public	static var current: TraceContext? { get }	Sources/Swarm/Observability/TraceContext.swift:66
TraceContext.endSpan(_:status:)	swift.method	public	func endSpan(_ span: TraceSpan, status: SpanStatus = .ok)	Sources/Swarm/Observability/TraceContext.swift:174
TraceContext.groupId	swift.property	public	let groupId: String?	Sources/Swarm/Observability/TraceContext.swift:79
TraceContext.traceId	swift.property	public	let traceId: UUID	Sources/Swarm/Observability/TraceContext.swift:75
TraceContext.duration	swift.property	public	var duration: TimeInterval { get }	Sources/Swarm/Observability/TraceContext.swift:90
TraceContext.getSpans()	swift.method	public	func getSpans() -> [TraceSpan]	Sources/Swarm/Observability/TraceContext.swift:199
TraceContext.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Observability/TraceContext.swift:82
TraceContext.withSpan(_:metadata:operation:)	swift.method	public	func withSpan<T>(_ name: String, metadata: [String : SendableValue] = [:], operation: () async throws -> T) async rethrows -> T where T : Sendable	Sources/Swarm/Observability/TraceContext.swift:266
TraceContext.startSpan(_:metadata:)	swift.method	public	func startSpan(_ name: String, metadata: [String : SendableValue] = [:]) -> TraceSpan	Sources/Swarm/Observability/TraceContext.swift:148
TraceContext.startTime	swift.property	public	let startTime: Date	Sources/Swarm/Observability/TraceContext.swift:85
VectorMemory	swift.class	public	actor VectorMemory	Sources/Swarm/Memory/VectorMemory.swift:55
VectorMemory.maxResults	swift.property	public	let maxResults: Int	Sources/Swarm/Memory/VectorMemory.swift:72
VectorMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/VectorMemory.swift:183
VectorMemory.diagnostics()	swift.method	public	func diagnostics() async -> VectorMemoryDiagnostics	Sources/Swarm/Memory/VectorMemory.swift:360
VectorMemory.SearchResult	swift.struct	public	struct SearchResult	Sources/Swarm/Memory/VectorMemory.swift:59
VectorMemory.SearchResult.similarity	swift.property	public	let similarity: Float	Sources/Swarm/Memory/VectorMemory.swift:63
VectorMemory.SearchResult.message	swift.property	public	let message: MemoryMessage	Sources/Swarm/Memory/VectorMemory.swift:61
VectorMemory.cosineSimilarity(_:_:)	swift.type.method	public	static func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Float	Sources/Swarm/Memory/VectorMemory.swift:119
VectorMemory.init(embeddingProvider:similarityThreshold:maxResults:tokenEstimator:)	swift.init	public	init(embeddingProvider: any EmbeddingProvider, similarityThreshold: Float = 0.7, maxResults: Int = 10, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/VectorMemory.swift:96
VectorMemory.embeddingProvider	swift.property	public	let embeddingProvider: any EmbeddingProvider	Sources/Swarm/Memory/VectorMemory.swift:75
VectorMemory.similarityThreshold	swift.property	public	let similarityThreshold: Float	Sources/Swarm/Memory/VectorMemory.swift:69
VectorMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/VectorMemory.swift:137
VectorMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/VectorMemory.swift:188
VectorMemory.count	swift.property	public	var count: Int { get }	Sources/Swarm/Memory/VectorMemory.swift:79
VectorMemory.addAll(_:)	swift.method	public	func addAll(_ newMessages: [MemoryMessage]) async	Sources/Swarm/Memory/VectorMemory.swift:244
VectorMemory.filter(_:)	swift.method	public	func filter(_ predicate: (MemoryMessage) -> Bool) async -> [MemoryMessage]	Sources/Swarm/Memory/VectorMemory.swift:270
VectorMemory.search(queryEmbedding:)	swift.method	public	func search(queryEmbedding: [Float]) -> [VectorMemory.SearchResult]	Sources/Swarm/Memory/VectorMemory.swift:211
VectorMemory.search(query:)	swift.method	public	func search(query: String) async throws -> [VectorMemory.SearchResult]	Sources/Swarm/Memory/VectorMemory.swift:198
VectorMemory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/VectorMemory.swift:158
VectorMemory.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Memory/VectorMemory.swift:83
VectorMemory.messages(withRole:)	swift.method	public	func messages(withRole role: MemoryMessage.Role) async -> [MemoryMessage]	Sources/Swarm/Memory/VectorMemory.swift:278
WhenCallback	swift.typealias	public	typealias WhenCallback = (AgentContext, any AgentRuntime) async -> Bool	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:150
AgentObserver	swift.protocol	public	protocol AgentObserver : Sendable	Sources/Swarm/Core/RunHooks.swift:43
AgentObserver.onAgentEnd(context:agent:result:)	swift.method	public	func onAgentEnd(context: AgentContext?, agent: any AgentRuntime, result: AgentResult) async	Sources/Swarm/Core/RunHooks.swift:59
AgentObserver.onAgentStart(context:agent:input:)	swift.method	public	func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async	Sources/Swarm/Core/RunHooks.swift:51
AgentObserver.onLLMStart(context:agent:systemPrompt:inputMessages:)	swift.method	public	func onLLMStart(context: AgentContext?, agent: any AgentRuntime, systemPrompt: String?, inputMessages: [MemoryMessage]) async	Sources/Swarm/Core/RunHooks.swift:107
AgentObserver.onThinking(context:agent:thought:)	swift.method	public	func onThinking(context: AgentContext?, agent: any AgentRuntime, thought: String) async	Sources/Swarm/Core/RunHooks.swift:133
AgentObserver.onToolStart(context:agent:call:)	swift.method	public	func onToolStart(context: AgentContext?, agent: any AgentRuntime, call: ToolCall) async	Sources/Swarm/Core/RunHooks.swift:84
AgentObserver.onOutputToken(context:agent:token:)	swift.method	public	func onOutputToken(context: AgentContext?, agent: any AgentRuntime, token: String) async	Sources/Swarm/Core/RunHooks.swift:149
AgentObserver.onIterationEnd(context:agent:number:)	swift.method	public	func onIterationEnd(context: AgentContext?, agent: any AgentRuntime, number: Int) async	Sources/Swarm/Core/RunHooks.swift:165
AgentObserver.onIterationStart(context:agent:number:)	swift.method	public	func onIterationStart(context: AgentContext?, agent: any AgentRuntime, number: Int) async	Sources/Swarm/Core/RunHooks.swift:157
AgentObserver.onThinkingPartial(context:agent:partialThought:)	swift.method	public	func onThinkingPartial(context: AgentContext?, agent: any AgentRuntime, partialThought: String) async	Sources/Swarm/Core/RunHooks.swift:141
AgentObserver.onToolCallPartial(context:agent:update:)	swift.method	public	func onToolCallPartial(context: AgentContext?, agent: any AgentRuntime, update: PartialToolCallUpdate) async	Sources/Swarm/Core/RunHooks.swift:89
AgentObserver.onGuardrailTriggered(context:guardrailName:guardrailType:result:)	swift.method	public	func onGuardrailTriggered(context: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async	Sources/Swarm/Core/RunHooks.swift:125
AgentObserver.onError(context:agent:error:)	swift.method	public	func onError(context: AgentContext?, agent: any AgentRuntime, error: any Error) async	Sources/Swarm/Core/RunHooks.swift:67
AgentObserver.onLLMEnd(context:agent:response:usage:)	swift.method	public	func onLLMEnd(context: AgentContext?, agent: any AgentRuntime, response: String, usage: InferenceResponse.TokenUsage?) async	Sources/Swarm/Core/RunHooks.swift:116
AgentObserver.onHandoff(context:fromAgent:toAgent:)	swift.method	public	func onHandoff(context: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async	Sources/Swarm/Core/RunHooks.swift:75
AgentObserver.onToolEnd(context:agent:result:)	swift.method	public	func onToolEnd(context: AgentContext?, agent: any AgentRuntime, result: ToolResult) async	Sources/Swarm/Core/RunHooks.swift:98
AgentObserver.onAgentEnd(context:agent:result:)	swift.method	public	func onAgentEnd(context _: AgentContext?, agent _: any AgentRuntime, result _: AgentResult) async	Sources/Swarm/Core/RunHooks.swift:175
AgentObserver.onAgentStart(context:agent:input:)	swift.method	public	func onAgentStart(context _: AgentContext?, agent _: any AgentRuntime, input _: String) async	Sources/Swarm/Core/RunHooks.swift:172
AgentObserver.onLLMStart(context:agent:systemPrompt:inputMessages:)	swift.method	public	func onLLMStart(context _: AgentContext?, agent _: any AgentRuntime, systemPrompt _: String?, inputMessages _: [MemoryMessage]) async	Sources/Swarm/Core/RunHooks.swift:193
AgentObserver.onThinking(context:agent:thought:)	swift.method	public	func onThinking(context _: AgentContext?, agent _: any AgentRuntime, thought _: String) async	Sources/Swarm/Core/RunHooks.swift:202
AgentObserver.onToolStart(context:agent:call:)	swift.method	public	func onToolStart(context: AgentContext?, agent: any AgentRuntime, call: ToolCall) async	Sources/Swarm/Core/RunHooks.swift:184
AgentObserver.onOutputToken(context:agent:token:)	swift.method	public	func onOutputToken(context _: AgentContext?, agent _: any AgentRuntime, token _: String) async	Sources/Swarm/Core/RunHooks.swift:208
AgentObserver.onIterationEnd(context:agent:number:)	swift.method	public	func onIterationEnd(context _: AgentContext?, agent _: any AgentRuntime, number _: Int) async	Sources/Swarm/Core/RunHooks.swift:214
LoggingObserver.onIterationEnd(context:agent:number:)	swift.method	public	func onIterationEnd(context _: AgentContext?, agent _: any AgentRuntime, number _: Int) async	Sources/Swarm/Core/RunHooks.swift:214
AgentObserver.onIterationStart(context:agent:number:)	swift.method	public	func onIterationStart(context _: AgentContext?, agent _: any AgentRuntime, number _: Int) async	Sources/Swarm/Core/RunHooks.swift:211
AgentObserver.onThinkingPartial(context:agent:partialThought:)	swift.method	public	func onThinkingPartial(context _: AgentContext?, agent _: any AgentRuntime, partialThought _: String) async	Sources/Swarm/Core/RunHooks.swift:205
LoggingObserver.onThinkingPartial(context:agent:partialThought:)	swift.method	public	func onThinkingPartial(context _: AgentContext?, agent _: any AgentRuntime, partialThought _: String) async	Sources/Swarm/Core/RunHooks.swift:205
AgentObserver.onToolCallPartial(context:agent:update:)	swift.method	public	func onToolCallPartial(context: AgentContext?, agent: any AgentRuntime, update: PartialToolCallUpdate) async	Sources/Swarm/Core/RunHooks.swift:187
LoggingObserver.onToolCallPartial(context:agent:update:)	swift.method	public	func onToolCallPartial(context: AgentContext?, agent: any AgentRuntime, update: PartialToolCallUpdate) async	Sources/Swarm/Core/RunHooks.swift:187
AgentObserver.onGuardrailTriggered(context:guardrailName:guardrailType:result:)	swift.method	public	func onGuardrailTriggered(context _: AgentContext?, guardrailName _: String, guardrailType _: GuardrailType, result _: GuardrailResult) async	Sources/Swarm/Core/RunHooks.swift:199
AgentObserver.onError(context:agent:error:)	swift.method	public	func onError(context _: AgentContext?, agent _: any AgentRuntime, error _: any Error) async	Sources/Swarm/Core/RunHooks.swift:178
AgentObserver.onLLMEnd(context:agent:response:usage:)	swift.method	public	func onLLMEnd(context _: AgentContext?, agent _: any AgentRuntime, response _: String, usage _: InferenceResponse.TokenUsage?) async	Sources/Swarm/Core/RunHooks.swift:196
AgentObserver.onHandoff(context:fromAgent:toAgent:)	swift.method	public	func onHandoff(context _: AgentContext?, fromAgent _: any AgentRuntime, toAgent _: any AgentRuntime) async	Sources/Swarm/Core/RunHooks.swift:181
AgentObserver.onToolEnd(context:agent:result:)	swift.method	public	func onToolEnd(context: AgentContext?, agent: any AgentRuntime, result: ToolResult) async	Sources/Swarm/Core/RunHooks.swift:190
AgentResponse	swift.struct	public	struct AgentResponse	Sources/Swarm/Core/AgentResponse.swift:145
AgentResponse.init(responseId:output:agentName:timestamp:metadata:toolCalls:usage:iterationCount:)	swift.init	public	init(responseId: String = UUID().uuidString, output: String, agentName: String, timestamp: Date = Date(), metadata: [String : SendableValue] = [:], toolCalls: [ToolCallRecord] = [], usage: TokenUsage? = nil, iterationCount: Int = 1)	Sources/Swarm/Core/AgentResponse.swift:251
AgentResponse.responseId	swift.property	public	let responseId: String	Sources/Swarm/Core/AgentResponse.swift:150
AgentResponse.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentResponse.swift:290
AgentResponse.iterationCount	swift.property	public	let iterationCount: Int	Sources/Swarm/Core/AgentResponse.swift:181
AgentResponse.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Core/AgentResponse.swift:306
AgentResponse.==(_:_:)	swift.func.op	public	static func == (lhs: AgentResponse, rhs: AgentResponse) -> Bool	Sources/Swarm/Core/AgentResponse.swift:275
AgentResponse.usage	swift.property	public	let usage: TokenUsage?	Sources/Swarm/Core/AgentResponse.swift:174
AgentResponse.output	swift.property	public	let output: String	Sources/Swarm/Core/AgentResponse.swift:153
AgentResponse.asResult	swift.property	public	var asResult: AgentResult { get }	Sources/Swarm/Core/AgentResponse.swift:201
AgentResponse.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Core/AgentResponse.swift:165
AgentResponse.agentName	swift.property	public	let agentName: String	Sources/Swarm/Core/AgentResponse.swift:156
AgentResponse.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Core/AgentResponse.swift:159
AgentResponse.toolCalls	swift.property	public	let toolCalls: [ToolCallRecord]	Sources/Swarm/Core/AgentResponse.swift:171
CallableAgent	swift.struct	public	@dynamicCallable struct CallableAgent	Sources/Swarm/Core/CallableAgent.swift:21
CallableAgent.dynamicallyCall(withArguments:)	swift.method	public	func dynamicallyCall(withArguments args: [String]) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:33
CallableAgent.dynamicallyCall(withKeywordArguments:)	swift.method	public	func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, String>) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:41
CallableAgent.init(_:)	swift.init	public	init(_ agent: any AgentRuntime)	Sources/Swarm/Core/CallableAgent.swift:26
Configuration	swift.struct	public	struct Configuration	Sources/Swarm/Agents/AgentBuilder.swift:111
Configuration.configuration	swift.property	public	let configuration: AgentConfiguration	Sources/Swarm/Agents/AgentBuilder.swift:113
Configuration.init(_:)	swift.init	public	init(_ configuration: AgentConfiguration)	Sources/Swarm/Agents/AgentBuilder.swift:118
ConsoleTracer	swift.class	public	actor ConsoleTracer	Sources/Swarm/Observability/ConsoleTracer.swift:45
ConsoleTracer.init(minimumLevel:colorized:includeTimestamp:includeSource:)	swift.init	public	init(minimumLevel: EventLevel = .trace, colorized: Bool = true, includeTimestamp: Bool = true, includeSource: Bool = false)	Sources/Swarm/Observability/ConsoleTracer.swift:55
ConsoleTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/ConsoleTracer.swift:71
ContextBudget	swift.struct	public	struct ContextBudget	Sources/Swarm/Core/ContextProfile.swift:455
ContextBudget.maxContextTokens	swift.property	public	let maxContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:457
ContextBudget.maxTotalContextTokens	swift.property	public	let maxTotalContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:456
ContextBudget.bucketCaps	swift.property	public	let bucketCaps: ContextBucketCaps?	Sources/Swarm/Core/ContextProfile.swift:469
ContextBudget.memoryTokens	swift.property	public	let memoryTokens: Int	Sources/Swarm/Core/ContextProfile.swift:461
ContextBudget.toolIOTokens	swift.property	public	let toolIOTokens: Int	Sources/Swarm/Core/ContextProfile.swift:462
ContextBudget.workingTokens	swift.property	public	let workingTokens: Int	Sources/Swarm/Core/ContextProfile.swift:460
ContextBudget.maxInputTokens	swift.property	public	let maxInputTokens: Int	Sources/Swarm/Core/ContextProfile.swift:458
ContextBudget.maxOutputTokens	swift.property	public	let maxOutputTokens: Int	Sources/Swarm/Core/ContextProfile.swift:459
ContextBudget.maxRetrievedItems	swift.property	public	let maxRetrievedItems: Int	Sources/Swarm/Core/ContextProfile.swift:467
ContextBudget.safetyMarginTokens	swift.property	public	let safetyMarginTokens: Int	Sources/Swarm/Core/ContextProfile.swift:465
ContextBudget.maxToolOutputTokens	swift.property	public	let maxToolOutputTokens: Int	Sources/Swarm/Core/ContextProfile.swift:466
ContextBudget.outputReserveTokens	swift.property	public	let outputReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:463
ContextBudget.maxRetrievedItemTokens	swift.property	public	let maxRetrievedItemTokens: Int	Sources/Swarm/Core/ContextProfile.swift:468
ContextBudget.protocolOverheadReserveTokens	swift.property	public	let protocolOverheadReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:464
FallbackChain	swift.struct	public	struct FallbackChain<Output> where Output : Sendable	Sources/Swarm/Resilience/FallbackChain.swift:115
FallbackChain.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Resilience/FallbackChain.swift:345
FallbackChain.executeWithResult()	swift.method	public	func executeWithResult() async throws -> ExecutionResult<Output>	Sources/Swarm/Resilience/FallbackChain.swift:234
FallbackChain.from(_:)	swift.type.method	public	static func from(_ operations: (name: String, operation: () async throws -> Output)...) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:131
FallbackChain.attempt(name:_:)	swift.method	public	func attempt(name: String, _ operation: @escaping () async throws -> Output) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:146
FallbackChain.execute()	swift.method	public	func execute() async throws -> Output	Sources/Swarm/Resilience/FallbackChain.swift:226
FallbackChain.fallback(name:_:)	swift.method	public	func fallback(name: String, _ value: Output) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:180
FallbackChain.fallback(name:_:)	swift.method	public	func fallback(name: String, _ operation: @escaping () async -> Output) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:197
FallbackChain.attemptIf(name:condition:_:)	swift.method	public	func attemptIf(name: String, condition: @escaping () async -> Bool, _ operation: @escaping () async throws -> Output) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:163
FallbackChain.onFailure(_:)	swift.method	public	func onFailure(_ callback: @escaping (String, any Error) async -> Void) -> FallbackChain<Output>	Sources/Swarm/Resilience/FallbackChain.swift:215
FallbackChain.init()	swift.init	public	init()	Sources/Swarm/Resilience/FallbackChain.swift:121
GuardrailType	swift.enum	public	enum GuardrailType	Sources/Swarm/Core/AgentEvent.swift:143
GuardrailType.toolOutput	swift.enum.case	public	case toolOutput	Sources/Swarm/Core/AgentEvent.swift:147
GuardrailType.input	swift.enum.case	public	case input	Sources/Swarm/Core/AgentEvent.swift:144
GuardrailType.output	swift.enum.case	public	case output	Sources/Swarm/Core/AgentEvent.swift:145
GuardrailType.init(rawValue:)	swift.init	public	init?(rawValue: String)	
GuardrailType.toolInput	swift.enum.case	public	case toolInput	Sources/Swarm/Core/AgentEvent.swift:146
HTTPMCPServer	swift.class	public	actor HTTPMCPServer	Sources/Swarm/MCP/HTTPMCPServer.swift:50
HTTPMCPServer.initialize()	swift.method	public	func initialize() async throws -> MCPCapabilities	Sources/Swarm/MCP/HTTPMCPServer.swift:114
HTTPMCPServer.capabilities	swift.property	public	var capabilities: MCPCapabilities { get }	Sources/Swarm/MCP/HTTPMCPServer.swift:62
HTTPMCPServer.readResource(uri:)	swift.method	public	func readResource(uri: String) async throws -> MCPResourceContent	Sources/Swarm/MCP/HTTPMCPServer.swift:209
HTTPMCPServer.listResources()	swift.method	public	func listResources() async throws -> [MCPResource]	Sources/Swarm/MCP/HTTPMCPServer.swift:189
HTTPMCPServer.init(url:name:apiKey:timeout:maxRetries:session:)	swift.init	public	init(url: URL, name: String, apiKey: String? = nil, timeout: TimeInterval = 30.0, maxRetries: Int = 3, session: URLSession = .shared)	Sources/Swarm/MCP/HTTPMCPServer.swift:77
HTTPMCPServer.name	swift.property	public	let name: String	Sources/Swarm/MCP/HTTPMCPServer.swift:56
HTTPMCPServer.close()	swift.method	public	func close() async throws	Sources/Swarm/MCP/HTTPMCPServer.swift:255
HTTPMCPServer.callTool(name:arguments:)	swift.method	public	func callTool(name: String, arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/MCP/HTTPMCPServer.swift:165
HTTPMCPServer.listTools()	swift.method	public	func listTools() async throws -> [ToolSchema]	Sources/Swarm/MCP/HTTPMCPServer.swift:143
HandoffPolicy	swift.enum	public	enum HandoffPolicy	Sources/Swarm/Core/Handoff/HandoffOptions.swift:33
HandoffPolicy.strict	swift.enum.case	public	case strict	Sources/Swarm/Core/Handoff/HandoffOptions.swift:41
HandoffPolicy.minimal	swift.enum.case	public	case minimal	Sources/Swarm/Core/Handoff/HandoffOptions.swift:35
HandoffPolicy.balanced	swift.enum.case	public	case balanced	Sources/Swarm/Core/Handoff/HandoffOptions.swift:38
HandoffResult	swift.struct	public	struct HandoffResult	Sources/Swarm/Core/Handoff/Handoff.swift:83
HandoffResult.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/Handoff/Handoff.swift:538
HandoffResult.init(targetAgentName:input:result:transferredContext:timestamp:)	swift.init	public	init(targetAgentName: String, input: String, result: AgentResult, transferredContext: [String : SendableValue], timestamp: Date = Date())	Sources/Swarm/Core/Handoff/Handoff.swift:107
HandoffResult.targetAgentName	swift.property	public	let targetAgentName: String	Sources/Swarm/Core/Handoff/Handoff.swift:85
HandoffResult.transferredContext	swift.property	public	let transferredContext: [String : SendableValue]	Sources/Swarm/Core/Handoff/Handoff.swift:94
HandoffResult.input	swift.property	public	let input: String	Sources/Swarm/Core/Handoff/Handoff.swift:88
HandoffResult.result	swift.property	public	let result: AgentResult	Sources/Swarm/Core/Handoff/Handoff.swift:91
HandoffResult.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Core/Handoff/Handoff.swift:97
MCPToolBridge	swift.class	public	actor MCPToolBridge	Sources/Swarm/MCP/MCPToolBridge.swift:36
MCPToolBridge.bridgeTools()	swift.method	public	func bridgeTools() async throws -> [any AnyJSONTool]	Sources/Swarm/MCP/MCPToolBridge.swift:69
MCPToolBridge.init(server:)	swift.init	public	init(server: any MCPServer)	Sources/Swarm/MCP/MCPToolBridge.swift:44
MemoryBuilder	swift.struct	public	@resultBuilder struct MemoryBuilder	Sources/Swarm/Memory/MemoryBuilder.swift:26
MemoryBuilder.buildArray(_:)	swift.type.method	public	static func buildArray(_ components: [[MemoryComponent]]) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:58
MemoryBuilder.buildBlock()	swift.type.method	public	static func buildBlock() -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:38
MemoryBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: MemoryComponent...) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:28
MemoryBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: [MemoryComponent]...) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:33
MemoryBuilder.buildEither(first:)	swift.type.method	public	static func buildEither(first component: [MemoryComponent]) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:48
MemoryBuilder.buildEither(second:)	swift.type.method	public	static func buildEither(second component: [MemoryComponent]) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:53
MemoryBuilder.buildOptional(_:)	swift.type.method	public	static func buildOptional(_ component: [MemoryComponent]?) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:43
MemoryBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: any Memory) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:63
MemoryBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: MemoryComponent) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:68
MemoryBuilder.buildFinalResult(_:)	swift.type.method	public	static func buildFinalResult(_ component: [MemoryComponent]) -> [MemoryComponent]	Sources/Swarm/Memory/MemoryBuilder.swift:73
MemoryMessage	swift.struct	public	struct MemoryMessage	Sources/Swarm/Memory/MemoryMessage.swift:14
MemoryMessage.description	swift.property	public	var description: String { get }	Sources/Swarm/Memory/MemoryMessage.swift:117
MemoryMessage.formattedContent	swift.property	public	var formattedContent: String { get }	Sources/Swarm/Memory/MemoryMessage.swift:43
MemoryMessage.id	swift.property	public	let id: UUID	Sources/Swarm/Memory/MemoryMessage.swift:28
MemoryMessage.init(id:role:content:timestamp:metadata:)	swift.init	public	init(id: UUID = UUID(), role: MemoryMessage.Role, content: String, timestamp: Date = Date(), metadata: [String : String] = [:])	Sources/Swarm/Memory/MemoryMessage.swift:55
MemoryMessage.Role	swift.enum	public	enum Role	Sources/Swarm/Memory/MemoryMessage.swift:16
MemoryMessage.Role.tool	swift.enum.case	public	case tool	Sources/Swarm/Memory/MemoryMessage.swift:24
MemoryMessage.Role.user	swift.enum.case	public	case user	Sources/Swarm/Memory/MemoryMessage.swift:18
MemoryMessage.Role.system	swift.enum.case	public	case system	Sources/Swarm/Memory/MemoryMessage.swift:22
MemoryMessage.Role.init(rawValue:)	swift.init	public	init?(rawValue: String)	
MemoryMessage.Role.assistant	swift.enum.case	public	case assistant	Sources/Swarm/Memory/MemoryMessage.swift:20
MemoryMessage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MemoryMessage.role	swift.property	public	let role: MemoryMessage.Role	Sources/Swarm/Memory/MemoryMessage.swift:31
MemoryMessage.tool(_:toolName:)	swift.type.method	public	static func tool(_ content: String, toolName: String) -> MemoryMessage	Sources/Swarm/Memory/MemoryMessage.swift:109
MemoryMessage.user(_:metadata:)	swift.type.method	public	static func user(_ content: String, metadata: [String : String] = [:]) -> MemoryMessage	Sources/Swarm/Memory/MemoryMessage.swift:79
MemoryMessage.system(_:metadata:)	swift.type.method	public	static func system(_ content: String, metadata: [String : String] = [:]) -> MemoryMessage	Sources/Swarm/Memory/MemoryMessage.swift:99
MemoryMessage.content	swift.property	public	let content: String	Sources/Swarm/Memory/MemoryMessage.swift:34
MemoryMessage.metadata	swift.property	public	let metadata: [String : String]	Sources/Swarm/Memory/MemoryMessage.swift:40
MemoryMessage.assistant(_:metadata:)	swift.type.method	public	static func assistant(_ content: String, metadata: [String : String] = [:]) -> MemoryMessage	Sources/Swarm/Memory/MemoryMessage.swift:89
MemoryMessage.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Memory/MemoryMessage.swift:37
ModelSettings	swift.struct	public	struct ModelSettings	Sources/Swarm/Core/ModelSettings.swift:42
ModelSettings.providerSettings	swift.property	public	var providerSettings: [String : SendableValue]?	Sources/Swarm/Core/ModelSettings.swift:156
ModelSettings.providerSettings(_:)	swift.method	public	@discardableResult func providerSettings(_ value: [String : SendableValue]?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.toolChoice	swift.property	public	var toolChoice: ToolChoice?	Sources/Swarm/Core/ModelSettings.swift:102
ModelSettings.toolChoice(_:)	swift.method	public	@discardableResult func toolChoice(_ value: ToolChoice?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.truncation	swift.property	public	var truncation: TruncationStrategy?	Sources/Swarm/Core/ModelSettings.swift:115
ModelSettings.truncation(_:)	swift.method	public	@discardableResult func truncation(_ value: TruncationStrategy?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/ModelSettings.swift:531
ModelSettings.init(temperature:topP:topK:maxTokens:frequencyPenalty:presencePenalty:stopSequences:seed:toolChoice:parallelToolCalls:truncation:verbosity:promptCacheRetention:repetitionPenalty:minP:providerSettings:)	swift.init	public	init(temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil, maxTokens: Int? = nil, frequencyPenalty: Double? = nil, presencePenalty: Double? = nil, stopSequences: [String]? = nil, seed: Int? = nil, toolChoice: ToolChoice? = nil, parallelToolCalls: Bool? = nil, truncation: TruncationStrategy? = nil, verbosity: Verbosity? = nil, promptCacheRetention: CacheRetention? = nil, repetitionPenalty: Double? = nil, minP: Double? = nil, providerSettings: [String : SendableValue]? = nil)	Sources/Swarm/Core/ModelSettings.swift:164
ModelSettings.temperature	swift.property	public	var temperature: Double?	Sources/Swarm/Core/ModelSettings.swift:50
ModelSettings.temperature(_:)	swift.method	public	@discardableResult func temperature(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.stopSequences	swift.property	public	var stopSequences: [String]?	Sources/Swarm/Core/ModelSettings.swift:89
ModelSettings.stopSequences(_:)	swift.method	public	@discardableResult func stopSequences(_ value: [String]?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.presencePenalty	swift.property	public	var presencePenalty: Double?	Sources/Swarm/Core/ModelSettings.swift:84
ModelSettings.presencePenalty(_:)	swift.method	public	@discardableResult func presencePenalty(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.frequencyPenalty	swift.property	public	var frequencyPenalty: Double?	Sources/Swarm/Core/ModelSettings.swift:77
ModelSettings.frequencyPenalty(_:)	swift.method	public	@discardableResult func frequencyPenalty(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.parallelToolCalls	swift.property	public	var parallelToolCalls: Bool?	Sources/Swarm/Core/ModelSettings.swift:108
ModelSettings.parallelToolCalls(_:)	swift.method	public	@discardableResult func parallelToolCalls(_ value: Bool?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.repetitionPenalty	swift.property	public	var repetitionPenalty: Double?	Sources/Swarm/Core/ModelSettings.swift:133
ModelSettings.repetitionPenalty(_:)	swift.method	public	@discardableResult func repetitionPenalty(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.promptCacheRetention	swift.property	public	var promptCacheRetention: CacheRetention?	Sources/Swarm/Core/ModelSettings.swift:125
ModelSettings.promptCacheRetention(_:)	swift.method	public	@discardableResult func promptCacheRetention(_ value: CacheRetention?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ModelSettings.minP	swift.property	public	var minP: Double?	Sources/Swarm/Core/ModelSettings.swift:139
ModelSettings.minP(_:)	swift.method	public	@discardableResult func minP(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.seed	swift.property	public	var seed: Int?	Sources/Swarm/Core/ModelSettings.swift:95
ModelSettings.seed(_:)	swift.method	public	@discardableResult func seed(_ value: Int?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.topK	swift.property	public	var topK: Int?	Sources/Swarm/Core/ModelSettings.swift:64
ModelSettings.topK(_:)	swift.method	public	@discardableResult func topK(_ value: Int?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.topP	swift.property	public	var topP: Double?	Sources/Swarm/Core/ModelSettings.swift:57
ModelSettings.topP(_:)	swift.method	public	@discardableResult func topP(_ value: Double?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.merged(with:)	swift.method	public	func merged(with other: ModelSettings) throws -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:331
ModelSettings.default	swift.type.property	public	static var `default`: ModelSettings { get }	Sources/Swarm/Core/ModelSettings.swift:207
ModelSettings.precise	swift.type.property	public	static var precise: ModelSettings { get }	Sources/Swarm/Core/ModelSettings.swift:223
ModelSettings.balanced	swift.type.property	public	static var balanced: ModelSettings { get }	Sources/Swarm/Core/ModelSettings.swift:231
ModelSettings.creative	swift.type.property	public	static var creative: ModelSettings { get }	Sources/Swarm/Core/ModelSettings.swift:215
ModelSettings.validate()	swift.method	public	func validate() throws	Sources/Swarm/Core/ModelSettings.swift:254
ModelSettings.maxTokens	swift.property	public	var maxTokens: Int?	Sources/Swarm/Core/ModelSettings.swift:70
ModelSettings.maxTokens(_:)	swift.method	public	@discardableResult func maxTokens(_ value: Int?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
ModelSettings.verbosity	swift.property	public	var verbosity: Verbosity?	Sources/Swarm/Core/ModelSettings.swift:120
ModelSettings.verbosity(_:)	swift.method	public	@discardableResult func verbosity(_ value: Verbosity?) -> ModelSettings	Sources/Swarm/Core/ModelSettings.swift:41
MultiProvider	swift.class	public	actor MultiProvider	Sources/Swarm/Providers/MultiProvider.swift:74
MultiProvider.hasProvider(for:)	swift.method	public	func hasProvider(for prefix: String) -> Bool	Sources/Swarm/Providers/MultiProvider.swift:219
MultiProvider.init(defaultProvider:)	swift.init	public	init(defaultProvider: any InferenceProvider)	Sources/Swarm/Providers/MultiProvider.swift:102
MultiProvider.clearModel()	swift.method	public	func clearModel()	Sources/Swarm/Providers/MultiProvider.swift:150
MultiProvider.unregister(prefix:)	swift.method	public	func unregister(prefix: String)	Sources/Swarm/Providers/MultiProvider.swift:131
MultiProvider.description	swift.property	public	nonisolated var description: String { get }	Sources/Swarm/Providers/MultiProvider.swift:314
MultiProvider.providerCount	swift.property	public	var providerCount: Int { get }	Sources/Swarm/Providers/MultiProvider.swift:83
MultiProvider.withOpenRouter(apiKey:defaultModel:)	swift.type.method	public	static func withOpenRouter(apiKey: String, defaultModel: OpenRouterModel = .gpt4o) throws -> MultiProvider	Sources/Swarm/Providers/MultiProvider.swift:332
MultiProvider.registeredPrefixes	swift.property	public	var registeredPrefixes: [String] { get }	Sources/Swarm/Providers/MultiProvider.swift:78
MultiProvider.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/MultiProvider.swift:206
MultiProvider.model	swift.property	public	var model: String? { get }	Sources/Swarm/Providers/MultiProvider.swift:88
MultiProvider.stream(prompt:options:)	swift.method	public	nonisolated func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/MultiProvider.swift:178
MultiProvider.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/MultiProvider.swift:165
MultiProvider.provider(for:)	swift.method	public	func provider(for prefix: String) -> (any InferenceProvider)?	Sources/Swarm/Providers/MultiProvider.swift:228
MultiProvider.register(prefix:provider:)	swift.method	public	func register(prefix: String, provider: any InferenceProvider) throws	Sources/Swarm/Providers/MultiProvider.swift:118
MultiProvider.setModel(_:)	swift.method	public	func setModel(_ model: String)	Sources/Swarm/Providers/MultiProvider.swift:145
SendableValue	swift.enum	public	enum SendableValue	Sources/Swarm/Core/SendableValue.swift:12
SendableValue.dictionaryValue	swift.property	public	var dictionaryValue: [String : SendableValue]? { get }	Sources/Swarm/Core/SendableValue.swift:51
SendableValue.intValue	swift.property	public	var intValue: Int? { get }	Sources/Swarm/Core/SendableValue.swift:24
SendableValue.boolValue	swift.property	public	var boolValue: Bool? { get }	Sources/Swarm/Core/SendableValue.swift:18
SendableValue.arrayValue	swift.property	public	var arrayValue: [SendableValue]? { get }	Sources/Swarm/Core/SendableValue.swift:45
SendableValue.doubleValue	swift.property	public	var doubleValue: Double? { get }	Sources/Swarm/Core/SendableValue.swift:30
SendableValue.stringValue	swift.property	public	var stringValue: String? { get }	Sources/Swarm/Core/SendableValue.swift:39
SendableValue.dictionary(_:)	swift.enum.case	public	case dictionary([String : SendableValue])	Sources/Swarm/Core/SendableValue.swift:91
SendableValue.init(nilLiteral:)	swift.init	public	init(nilLiteral _: ())	Sources/Swarm/Core/SendableValue.swift:97
SendableValue.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/SendableValue.swift:141
SendableValue.init(arrayLiteral:)	swift.init	public	init(arrayLiteral elements: SendableValue...)	Sources/Swarm/Core/SendableValue.swift:127
SendableValue.init(floatLiteral:)	swift.init	public	init(floatLiteral value: Double)	Sources/Swarm/Core/SendableValue.swift:115
SendableValue.fromJSONValue(_:)	swift.type.method	public	static func fromJSONValue(_ value: Any) -> SendableValue	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:356
SendableValue.init(stringLiteral:)	swift.init	public	init(stringLiteral value: String)	Sources/Swarm/Core/SendableValue.swift:121
SendableValue.init(booleanLiteral:)	swift.init	public	init(booleanLiteral value: Bool)	Sources/Swarm/Core/SendableValue.swift:103
SendableValue.init(integerLiteral:)	swift.init	public	init(integerLiteral value: Int)	Sources/Swarm/Core/SendableValue.swift:109
SendableValue.ConversionError	swift.enum	public	enum ConversionError	Sources/Swarm/Core/SendableValue.swift:185
SendableValue.ConversionError.decodingFailed(_:)	swift.enum.case	public	case decodingFailed(String)	Sources/Swarm/Core/SendableValue.swift:200
SendableValue.ConversionError.encodingFailed(_:)	swift.enum.case	public	case encodingFailed(String)	Sources/Swarm/Core/SendableValue.swift:199
SendableValue.ConversionError.unsupportedType(_:)	swift.enum.case	public	case unsupportedType(String)	Sources/Swarm/Core/SendableValue.swift:201
SendableValue.ConversionError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Core/SendableValue.swift:188
SendableValue.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Core/SendableValue.swift:166
SendableValue.init(dictionaryLiteral:)	swift.init	public	init(dictionaryLiteral elements: (String, SendableValue)...)	Sources/Swarm/Core/SendableValue.swift:133
SendableValue.int(_:)	swift.enum.case	public	case int(Int)	Sources/Swarm/Core/SendableValue.swift:87
SendableValue.bool(_:)	swift.enum.case	public	case bool(Bool)	Sources/Swarm/Core/SendableValue.swift:86
SendableValue.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
SendableValue.null	swift.enum.case	public	case null	Sources/Swarm/Core/SendableValue.swift:85
SendableValue.array(_:)	swift.enum.case	public	case array([SendableValue])	Sources/Swarm/Core/SendableValue.swift:90
SendableValue.decode()	swift.method	public	func decode<T>() throws -> T where T : Decodable	Sources/Swarm/Core/SendableValue.swift:283
SendableValue.double(_:)	swift.enum.case	public	case double(Double)	Sources/Swarm/Core/SendableValue.swift:88
SendableValue.isNull	swift.property	public	var isNull: Bool { get }	Sources/Swarm/Core/SendableValue.swift:57
SendableValue.string(_:)	swift.enum.case	public	case string(String)	Sources/Swarm/Core/SendableValue.swift:89
SendableValue.init(encoding:)	swift.init	public	init(encoding value: some Encodable) throws	Sources/Swarm/Core/SendableValue.swift:224
SendableValue.init(_:)	swift.init	public	init(_ value: [String : SendableValue])	Sources/Swarm/Core/SendableValue.swift:69
SendableValue.init(_:)	swift.init	public	init(_ value: String)	Sources/Swarm/Core/SendableValue.swift:67
SendableValue.init(_:)	swift.init	public	init(_ value: [SendableValue])	Sources/Swarm/Core/SendableValue.swift:68
SendableValue.init(_:)	swift.init	public	init(_ value: Bool)	Sources/Swarm/Core/SendableValue.swift:64
SendableValue.init(_:)	swift.init	public	init(_ value: Double)	Sources/Swarm/Core/SendableValue.swift:66
SendableValue.subscript(_:)	swift.subscript	public	subscript(key: String) -> SendableValue? { get }	Sources/Swarm/Core/SendableValue.swift:74
SendableValue.subscript(_:)	swift.subscript	public	subscript(index: Int) -> SendableValue? { get }	Sources/Swarm/Core/SendableValue.swift:80
SendableValue.init(_:)	swift.init	public	init(_ value: Int)	Sources/Swarm/Core/SendableValue.swift:65
SummaryMemory	swift.class	public	actor SummaryMemory	Sources/Swarm/Memory/SummaryMemory.swift:36
SummaryMemory.hasSummary	swift.property	public	var hasSummary: Bool { get }	Sources/Swarm/Memory/SummaryMemory.swift:89
SummaryMemory.setSummary(_:)	swift.method	public	func setSummary(_ newSummary: String) async	Sources/Swarm/Memory/SummaryMemory.swift:252
SummaryMemory.currentSummary	swift.property	public	var currentSummary: String { get }	Sources/Swarm/Memory/SummaryMemory.swift:84
SummaryMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/SummaryMemory.swift:158
SummaryMemory.diagnostics()	swift.method	public	func diagnostics() async -> SummaryMemoryDiagnostics	Sources/Swarm/Memory/SummaryMemory.swift:261
SummaryMemory.Configuration	swift.struct	public	struct Configuration	Sources/Swarm/Memory/SummaryMemory.swift:40
SummaryMemory.Configuration.init(recentMessageCount:summarizationThreshold:summaryTokenTarget:)	swift.init	public	init(recentMessageCount: Int = 20, summarizationThreshold: Int = 50, summaryTokenTarget: Int = 500)	Sources/Swarm/Memory/SummaryMemory.swift:59
SummaryMemory.Configuration.recentMessageCount	swift.property	public	let recentMessageCount: Int	Sources/Swarm/Memory/SummaryMemory.swift:45
SummaryMemory.Configuration.summaryTokenTarget	swift.property	public	let summaryTokenTarget: Int	Sources/Swarm/Memory/SummaryMemory.swift:51
SummaryMemory.Configuration.summarizationThreshold	swift.property	public	let summarizationThreshold: Int	Sources/Swarm/Memory/SummaryMemory.swift:48
SummaryMemory.Configuration.default	swift.type.property	public	static let `default`: SummaryMemory.Configuration	Sources/Swarm/Memory/SummaryMemory.swift:42
SummaryMemory.init(configuration:summarizer:fallbackSummarizer:tokenEstimator:)	swift.init	public	init(configuration: SummaryMemory.Configuration = .default, summarizer: any Summarizer = TruncatingSummarizer.shared, fallbackSummarizer: any Summarizer = TruncatingSummarizer.shared, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/SummaryMemory.swift:105
SummaryMemory.configuration	swift.property	public	let configuration: SummaryMemory.Configuration	Sources/Swarm/Memory/SummaryMemory.swift:72
SummaryMemory.totalMessages	swift.property	public	var totalMessages: Int { get }	Sources/Swarm/Memory/SummaryMemory.swift:94
SummaryMemory.forceSummarize()	swift.method	public	func forceSummarize() async	Sources/Swarm/Memory/SummaryMemory.swift:244
SummaryMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/SummaryMemory.swift:119
SummaryMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/SummaryMemory.swift:162
SummaryMemory.count	swift.property	public	var count: Int { get }	Sources/Swarm/Memory/SummaryMemory.swift:74
SummaryMemory.context(for:tokenLimit:)	swift.method	public	func context(for _: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/SummaryMemory.swift:129
SummaryMemory.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Memory/SummaryMemory.swift:79
ToolArguments	swift.struct	public	struct ToolArguments	Sources/Swarm/Tools/FunctionTool.swift:9
ToolArguments.int(_:default:)	swift.method	public	func int(_ key: String, default defaultValue: Int = 0) -> Int	Sources/Swarm/Tools/FunctionTool.swift:62
ToolArguments.raw	swift.property	public	let raw: [String : SendableValue]	Sources/Swarm/Tools/FunctionTool.swift:10
ToolArguments.string(_:default:)	swift.method	public	func string(_ key: String, default defaultValue: String = "") -> String	Sources/Swarm/Tools/FunctionTool.swift:57
ToolArguments.require(_:as:)	swift.method	public	func require<T>(_ key: String, as type: T.Type = T.self) throws -> T	Sources/Swarm/Tools/FunctionTool.swift:19
ToolArguments.optional(_:as:)	swift.method	public	func optional<T>(_ key: String, as type: T.Type = T.self) -> T?	Sources/Swarm/Tools/FunctionTool.swift:45
ToolArguments.toolName	swift.property	public	let toolName: String	Sources/Swarm/Tools/FunctionTool.swift:11
ToolArguments.init(_:toolName:)	swift.init	public	init(_ arguments: [String : SendableValue], toolName: String = "tool")	Sources/Swarm/Tools/FunctionTool.swift:13
ToolChainStep	swift.protocol	public	protocol ToolChainStep : Sendable	Sources/Swarm/Tools/ToolChainBuilder.swift:114
ToolChainStep.execute(input:)	swift.method	public	func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:120
ToolParameter	swift.struct	public	struct ToolParameter	Sources/Swarm/Tools/Tool.swift:422
ToolParameter.ParameterType	swift.enum	public	indirect enum ParameterType	Sources/Swarm/Tools/Tool.swift:424
ToolParameter.ParameterType.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/Tool.swift:427
ToolParameter.ParameterType.any	swift.enum.case	public	case any	Sources/Swarm/Tools/Tool.swift:447
ToolParameter.ParameterType.int	swift.enum.case	public	case int	Sources/Swarm/Tools/Tool.swift:441
ToolParameter.ParameterType.bool	swift.enum.case	public	case bool	Sources/Swarm/Tools/Tool.swift:443
ToolParameter.ParameterType.array(elementType:)	swift.enum.case	public	case array(elementType: ToolParameter.ParameterType)	Sources/Swarm/Tools/Tool.swift:444
ToolParameter.ParameterType.oneOf(_:)	swift.enum.case	public	case oneOf([String])	Sources/Swarm/Tools/Tool.swift:446
ToolParameter.ParameterType.double	swift.enum.case	public	case double	Sources/Swarm/Tools/Tool.swift:442
ToolParameter.ParameterType.object(properties:)	swift.enum.case	public	case object(properties: [ToolParameter])	Sources/Swarm/Tools/Tool.swift:445
ToolParameter.ParameterType.string	swift.enum.case	public	case string	Sources/Swarm/Tools/Tool.swift:440
ToolParameter.isRequired	swift.property	public	let isRequired: Bool	Sources/Swarm/Tools/Tool.swift:460
ToolParameter.description	swift.property	public	let description: String	Sources/Swarm/Tools/Tool.swift:454
ToolParameter.defaultValue	swift.property	public	let defaultValue: SendableValue?	Sources/Swarm/Tools/Tool.swift:463
ToolParameter.init(name:description:type:isRequired:defaultValue:)	swift.init	public	init(name: String, description: String, type: ToolParameter.ParameterType, isRequired: Bool = true, defaultValue: SendableValue? = nil)	Sources/Swarm/Tools/Tool.swift:472
ToolParameter.name	swift.property	public	let name: String	Sources/Swarm/Tools/Tool.swift:451
ToolParameter.type	swift.property	public	let type: ToolParameter.ParameterType	Sources/Swarm/Tools/Tool.swift:457
ToolTransform	swift.struct	public	struct ToolTransform	Sources/Swarm/Tools/ToolChainBuilder.swift:346
ToolTransform.execute(input:)	swift.method	public	func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:365
ToolTransform.init(_:)	swift.init	public	init(_ transform: @escaping (SendableValue) async throws -> SendableValue)	Sources/Swarm/Tools/ToolChainBuilder.swift:354
TracingHelper	swift.struct	public	struct TracingHelper	Sources/Swarm/Observability/TracingHelper.swift:28
TracingHelper.traceError(_:)	swift.method	public	func traceError(_ error: any Error) async	Sources/Swarm/Observability/TracingHelper.swift:95
TracingHelper.traceStart(input:)	swift.method	public	func traceStart(input: String) async	Sources/Swarm/Observability/TracingHelper.swift:57
TracingHelper.traceCustom(kind:message:metadata:)	swift.method	public	func traceCustom(kind: EventKind, message: String, metadata: [String : SendableValue] = [:]) async	Sources/Swarm/Observability/TracingHelper.swift:329
TracingHelper.traceThought(_:)	swift.method	public	func traceThought(_ thought: String) async	Sources/Swarm/Observability/TracingHelper.swift:119
TracingHelper.traceComplete(result:)	swift.method	public	func traceComplete(result: AgentResult) async	Sources/Swarm/Observability/TracingHelper.swift:74
TracingHelper.traceDecision(_:options:)	swift.method	public	func traceDecision(_ decision: String, options: [String] = []) async	Sources/Swarm/Observability/TracingHelper.swift:284
TracingHelper.traceToolCall(name:arguments:)	swift.method	public	func traceToolCall(name: String, arguments: [String : SendableValue]) async -> UUID	Sources/Swarm/Observability/TracingHelper.swift:158
TracingHelper.traceToolError(spanId:name:error:)	swift.method	public	func traceToolError(spanId: UUID, name: String, error: any Error) async	Sources/Swarm/Observability/TracingHelper.swift:216
TracingHelper.traceCheckpoint(name:metadata:)	swift.method	public	func traceCheckpoint(name: String, metadata: [String : SendableValue] = [:]) async	Sources/Swarm/Observability/TracingHelper.swift:308
TracingHelper.traceMemoryRead(count:source:)	swift.method	public	func traceMemoryRead(count: Int, source: String) async	Sources/Swarm/Observability/TracingHelper.swift:242
TracingHelper.traceToolResult(spanId:name:result:duration:)	swift.method	public	func traceToolResult(spanId: UUID, name: String, result: String, duration: Duration) async	Sources/Swarm/Observability/TracingHelper.swift:185
TracingHelper.traceMemoryWrite(count:destination:)	swift.method	public	func traceMemoryWrite(count: Int, destination: String) async	Sources/Swarm/Observability/TracingHelper.swift:262
TracingHelper.init(tracer:agentName:)	swift.init	public	init(tracer: (any Tracer)?, agentName: String)	Sources/Swarm/Observability/TracingHelper.swift:45
TracingHelper.tracer	swift.property	public	let tracer: (any Tracer)?	Sources/Swarm/Observability/TracingHelper.swift:32
TracingHelper.traceId	swift.property	public	let traceId: UUID	Sources/Swarm/Observability/TracingHelper.swift:35
TracingHelper.agentName	swift.property	public	let agentName: String	Sources/Swarm/Observability/TracingHelper.swift:38
TracingHelper.tracePlan(_:)	swift.method	public	func tracePlan(_ plan: String) async	Sources/Swarm/Observability/TracingHelper.swift:137
WebSearchTool	swift.struct	public	struct WebSearchTool	Sources/Swarm/Tools/WebSearchTool.swift:22
WebSearchTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/WebSearchTool.swift:21
WebSearchTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/WebSearchTool.swift:21
WebSearchTool.fromEnvironment()	swift.type.method	public	static func fromEnvironment() -> WebSearchTool	Sources/Swarm/Tools/BuiltInTools.swift:345
WebSearchTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/WebSearchTool.swift:21
WebSearchTool.init(apiKey:)	swift.init	public	init(apiKey: String)	Sources/Swarm/Tools/WebSearchTool.swift:57
WebSearchTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/WebSearchTool.swift:21
WebSearchTool.execute()	swift.method	public	func execute() async throws -> String	Sources/Swarm/Tools/WebSearchTool.swift:68
WorkflowError	swift.enum	public	enum WorkflowError	Sources/Swarm/Core/Handoff/WorkflowError.swift:11
WorkflowError.invalidWorkflow(reason:)	swift.enum.case	public	case invalidWorkflow(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:62
WorkflowError.invalidGraph(_:)	swift.enum.case	public	case invalidGraph(WorkflowValidationError)	Sources/Swarm/Core/Handoff/WorkflowError.swift:53
WorkflowError.agentNotFound(name:)	swift.enum.case	public	case agentNotFound(name: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:15
WorkflowError.handoffFailed(source:target:reason:)	swift.enum.case	public	case handoffFailed(source: String, target: String, reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:23
WorkflowError.routingFailed(reason:)	swift.enum.case	public	case routingFailed(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:31
WorkflowError.handoffSkipped(from:to:reason:)	swift.enum.case	public	case handoffSkipped(from: String, to: String, reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:26
WorkflowError.allAgentsFailed(errors:)	swift.enum.case	public	case allAgentsFailed(errors: [String])	Sources/Swarm/Core/Handoff/WorkflowError.swift:42
WorkflowError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Core/Handoff/WorkflowError.swift:121
WorkflowError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Core/Handoff/WorkflowError.swift:77
WorkflowError.checkpointNotFound(id:)	swift.enum.case	public	case checkpointNotFound(id: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:68
WorkflowError.noAgentsConfigured	swift.enum.case	public	case noAgentsConfigured	Sources/Swarm/Core/Handoff/WorkflowError.swift:18
WorkflowError.mergeStrategyFailed(reason:)	swift.enum.case	public	case mergeStrategyFailed(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:39
WorkflowError.workflowInterrupted(reason:)	swift.enum.case	public	case workflowInterrupted(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:50
WorkflowError.humanApprovalTimeout(prompt:)	swift.enum.case	public	case humanApprovalTimeout(prompt: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:56
WorkflowError.humanApprovalRejected(prompt:reason:)	swift.enum.case	public	case humanApprovalRejected(prompt: String, reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:59
WorkflowError.invalidRouteCondition(reason:)	swift.enum.case	public	case invalidRouteCondition(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:34
WorkflowError.hiveRuntimeUnavailable(reason:)	swift.enum.case	public	case hiveRuntimeUnavailable(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:45
WorkflowError.checkpointStoreRequired	swift.enum.case	public	case checkpointStoreRequired	Sources/Swarm/Core/Handoff/WorkflowError.swift:65
WorkflowError.resumeDefinitionMismatch(reason:)	swift.enum.case	public	case resumeDefinitionMismatch(reason: String)	Sources/Swarm/Core/Handoff/WorkflowError.swift:71
AgentComponent	swift.protocol	public	protocol AgentComponent	Sources/Swarm/Agents/AgentBuilder.swift:13
BufferedTracer	swift.class	public	actor BufferedTracer	Sources/Swarm/Observability/AgentTracer.swift:243
BufferedTracer.init(destination:maxBufferSize:flushInterval:)	swift.init	public	init(destination: any Tracer, maxBufferSize: Int = 100, flushInterval: Duration = .seconds(5))	Sources/Swarm/Observability/AgentTracer.swift:252
BufferedTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:283
BufferedTracer.start()	swift.method	public	func start()	Sources/Swarm/Observability/AgentTracer.swift:265
BufferedTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/AgentTracer.swift:274
CacheRetention	swift.enum	public	enum CacheRetention	Sources/Swarm/Core/ModelSettings.swift:517
CacheRetention.fiveMinutes	swift.enum.case	public	case fiveMinutes	Sources/Swarm/Core/ModelSettings.swift:525
CacheRetention.twentyFourHours	swift.enum.case	public	case twentyFourHours	Sources/Swarm/Core/ModelSettings.swift:522
CacheRetention.inMemory	swift.enum.case	public	case inMemory	Sources/Swarm/Core/ModelSettings.swift:519
CacheRetention.init(rawValue:)	swift.init	public	init?(rawValue: String)	
CalculatorTool	swift.struct	public	struct CalculatorTool	Sources/Swarm/Tools/BuiltInTools.swift:27
CalculatorTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/BuiltInTools.swift:36
CalculatorTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/BuiltInTools.swift:31
CalculatorTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/BuiltInTools.swift:30
CalculatorTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/BuiltInTools.swift:48
CalculatorTool.init()	swift.init	public	init()	Sources/Swarm/Tools/BuiltInTools.swift:46
CircuitBreaker	swift.class	public	actor CircuitBreaker	Sources/Swarm/Resilience/CircuitBreaker.swift:32
CircuitBreaker.statistics()	swift.method	public	func statistics() -> Statistics	Sources/Swarm/Resilience/CircuitBreaker.swift:141
CircuitBreaker.currentState()	swift.method	public	func currentState() -> CircuitBreaker.State	Sources/Swarm/Resilience/CircuitBreaker.swift:121
CircuitBreaker.resetTimeout	swift.property	public	let resetTimeout: TimeInterval	Sources/Swarm/Resilience/CircuitBreaker.swift:59
CircuitBreaker.failureThreshold	swift.property	public	let failureThreshold: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:53
CircuitBreaker.successThreshold	swift.property	public	let successThreshold: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:56
CircuitBreaker.isAllowingRequests()	swift.method	public	func isAllowingRequests() -> Bool	Sources/Swarm/Resilience/CircuitBreaker.swift:403
CircuitBreaker.halfOpenMaxRequests	swift.property	public	let halfOpenMaxRequests: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:62
CircuitBreaker.init(name:failureThreshold:successThreshold:resetTimeout:halfOpenMaxRequests:)	swift.init	public	init(name: String, failureThreshold: Int = 5, successThreshold: Int = 2, resetTimeout: TimeInterval = 60.0, halfOpenMaxRequests: Int = 1)	Sources/Swarm/Resilience/CircuitBreaker.swift:73
CircuitBreaker.name	swift.property	public	let name: String	Sources/Swarm/Resilience/CircuitBreaker.swift:50
CircuitBreaker.trip()	swift.method	public	func trip() async	Sources/Swarm/Resilience/CircuitBreaker.swift:134
CircuitBreaker.State	swift.enum	public	enum State	Sources/Swarm/Resilience/CircuitBreaker.swift:38
CircuitBreaker.State.open(until:)	swift.enum.case	public	case open(until: Date)	Sources/Swarm/Resilience/CircuitBreaker.swift:43
CircuitBreaker.State.closed	swift.enum.case	public	case closed	Sources/Swarm/Resilience/CircuitBreaker.swift:40
CircuitBreaker.State.halfOpen	swift.enum.case	public	case halfOpen	Sources/Swarm/Resilience/CircuitBreaker.swift:46
CircuitBreaker.reset()	swift.method	public	func reset() async	Sources/Swarm/Resilience/CircuitBreaker.swift:126
CircuitBreaker.execute(_:)	swift.method	public	func execute<T>(_ operation: () async throws -> T) async throws -> T where T : Sendable	Sources/Swarm/Resilience/CircuitBreaker.swift:93
CircularBuffer	swift.struct	public	struct CircularBuffer<Element> where Element : Sendable	Sources/Swarm/Core/CircularBuffer.swift:26
CircularBuffer.startIndex	swift.property	public	var startIndex: Int { get }	Sources/Swarm/Core/CircularBuffer.swift:134
CircularBuffer.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/CircularBuffer.swift:165
CircularBuffer.init(arrayLiteral:)	swift.init	public	init(arrayLiteral elements: Element...)	Sources/Swarm/Core/CircularBuffer.swift:154
CircularBuffer.totalAppended	swift.property	public	var totalAppended: Int { get }	Sources/Swarm/Core/CircularBuffer.swift:60
CircularBuffer.last	swift.property	public	var last: Element? { get }	Sources/Swarm/Core/CircularBuffer.swift:75
CircularBuffer.count	swift.property	public	var count: Int { get }	Sources/Swarm/Core/CircularBuffer.swift:53
CircularBuffer.first	swift.property	public	var first: Element? { get }	Sources/Swarm/Core/CircularBuffer.swift:82
CircularBuffer.index(after:)	swift.method	public	func index(after i: Int) -> Int	Sources/Swarm/Core/CircularBuffer.swift:137
CircularBuffer.append(_:)	swift.method	public	mutating func append(_ element: Element)	Sources/Swarm/Core/CircularBuffer.swift:107
CircularBuffer.isFull	swift.property	public	var isFull: Bool { get }	Sources/Swarm/Core/CircularBuffer.swift:70
CircularBuffer.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Core/CircularBuffer.swift:65
CircularBuffer.init(capacity:)	swift.init	public	init(capacity: Int)	Sources/Swarm/Core/CircularBuffer.swift:94
CircularBuffer.capacity	swift.property	public	let capacity: Int	Sources/Swarm/Core/CircularBuffer.swift:30
CircularBuffer.elements	swift.property	public	var elements: [Element] { get }	Sources/Swarm/Core/CircularBuffer.swift:36
CircularBuffer.endIndex	swift.property	public	var endIndex: Int { get }	Sources/Swarm/Core/CircularBuffer.swift:135
CircularBuffer.removeAll()	swift.method	public	mutating func removeAll()	Sources/Swarm/Core/CircularBuffer.swift:118
CircularBuffer.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	Sources/Swarm/Core/CircularBuffer.swift:181
CircularBuffer.==(_:_:)	swift.func.op	public	static func == (lhs: CircularBuffer<Element>, rhs: CircularBuffer<Element>) -> Bool	Sources/Swarm/Core/CircularBuffer.swift:173
CircularBuffer.subscript(_:)	swift.subscript	public	subscript(position: Int) -> Element { get }	Sources/Swarm/Core/CircularBuffer.swift:141
ContextProfile	swift.struct	public	struct ContextProfile	Sources/Swarm/Core/ContextProfile.swift:15
ContextProfile.maxContextTokens	swift.property	public	let maxContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:235
ContextProfile.maxTotalContextTokens	swift.property	public	let maxTotalContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:238
ContextProfile.bucketCaps	swift.property	public	let bucketCaps: ContextBucketCaps?	Sources/Swarm/Core/ContextProfile.swift:277
ContextProfile.platformDefault	swift.type.property	public	static var platformDefault: ContextProfile { get }	Sources/Swarm/Core/ContextProfile.swift:119
ContextProfile.PlatformDefaults	swift.struct	public	struct PlatformDefaults	Sources/Swarm/Core/ContextProfile.swift:99
ContextProfile.PlatformDefaults.maxContextTokens	swift.property	public	let maxContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:115
ContextProfile.PlatformDefaults.iOS	swift.type.property	public	static let iOS: ContextProfile.PlatformDefaults	Sources/Swarm/Core/ContextProfile.swift:101
ContextProfile.PlatformDefaults.macOS	swift.type.property	public	static let macOS: ContextProfile.PlatformDefaults	Sources/Swarm/Core/ContextProfile.swift:103
ContextProfile.PlatformDefaults.current	swift.type.property	public	static var current: ContextProfile.PlatformDefaults { get }	Sources/Swarm/Core/ContextProfile.swift:106
ContextProfile.Strict4kTemplate	swift.struct	public	struct Strict4kTemplate	Sources/Swarm/Core/ContextProfile.swift:26
ContextProfile.Strict4kTemplate.init(maxTotalContextTokens:systemTokens:historyTokens:memoryTokens:toolIOTokens:outputReserveTokens:protocolOverheadReserveTokens:safetyMarginTokens:maxToolOutputTokens:maxRetrievedItems:maxRetrievedItemTokens:summaryCadenceTurns:summaryTriggerUtilization:)	swift.init	public	init(maxTotalContextTokens: Int = 4096, systemTokens: Int = 512, historyTokens: Int = 1400, memoryTokens: Int = 900, toolIOTokens: Int = 600, outputReserveTokens: Int = 500, protocolOverheadReserveTokens: Int = 120, safetyMarginTokens: Int = 64, maxToolOutputTokens: Int = 600, maxRetrievedItems: Int = 3, maxRetrievedItemTokens: Int = 300, summaryCadenceTurns: Int = 2, summaryTriggerUtilization: Double = 0.65)	Sources/Swarm/Core/ContextProfile.swift:47
ContextProfile.Strict4kTemplate.maxTotalContextTokens	swift.property	public	var maxTotalContextTokens: Int	Sources/Swarm/Core/ContextProfile.swift:29
ContextProfile.Strict4kTemplate.memoryTokens	swift.property	public	var memoryTokens: Int	Sources/Swarm/Core/ContextProfile.swift:32
ContextProfile.Strict4kTemplate.systemTokens	swift.property	public	var systemTokens: Int	Sources/Swarm/Core/ContextProfile.swift:30
ContextProfile.Strict4kTemplate.toolIOTokens	swift.property	public	var toolIOTokens: Int	Sources/Swarm/Core/ContextProfile.swift:33
ContextProfile.Strict4kTemplate.historyTokens	swift.property	public	var historyTokens: Int	Sources/Swarm/Core/ContextProfile.swift:31
ContextProfile.Strict4kTemplate.maxInputTokens	swift.property	public	var maxInputTokens: Int { get }	Sources/Swarm/Core/ContextProfile.swift:43
ContextProfile.Strict4kTemplate.maxRetrievedItems	swift.property	public	var maxRetrievedItems: Int	Sources/Swarm/Core/ContextProfile.swift:38
ContextProfile.Strict4kTemplate.safetyMarginTokens	swift.property	public	var safetyMarginTokens: Int	Sources/Swarm/Core/ContextProfile.swift:36
ContextProfile.Strict4kTemplate.maxToolOutputTokens	swift.property	public	var maxToolOutputTokens: Int	Sources/Swarm/Core/ContextProfile.swift:37
ContextProfile.Strict4kTemplate.outputReserveTokens	swift.property	public	var outputReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:34
ContextProfile.Strict4kTemplate.summaryCadenceTurns	swift.property	public	var summaryCadenceTurns: Int	Sources/Swarm/Core/ContextProfile.swift:40
ContextProfile.Strict4kTemplate.maxRetrievedItemTokens	swift.property	public	var maxRetrievedItemTokens: Int	Sources/Swarm/Core/ContextProfile.swift:39
ContextProfile.Strict4kTemplate.summaryTriggerUtilization	swift.property	public	var summaryTriggerUtilization: Double	Sources/Swarm/Core/ContextProfile.swift:41
ContextProfile.Strict4kTemplate.protocolOverheadReserveTokens	swift.property	public	var protocolOverheadReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:35
ContextProfile.Strict4kTemplate.default	swift.type.property	public	static let `default`: ContextProfile.Strict4kTemplate	Sources/Swarm/Core/ContextProfile.swift:27
ContextProfile.memoryTokenLimit	swift.property	public	var memoryTokenLimit: Int { get }	Sources/Swarm/Core/ContextProfile.swift:407
ContextProfile.memoryTokenRatio	swift.property	public	let memoryTokenRatio: Double	Sources/Swarm/Core/ContextProfile.swift:244
ContextProfile.toolIOTokenRatio	swift.property	public	let toolIOTokenRatio: Double	Sources/Swarm/Core/ContextProfile.swift:247
ContextProfile.maxRetrievedItems	swift.property	public	let maxRetrievedItems: Int	Sources/Swarm/Core/ContextProfile.swift:256
ContextProfile.summaryTokenLimit	swift.property	public	var summaryTokenLimit: Int { get }	Sources/Swarm/Core/ContextProfile.swift:412
ContextProfile.summaryTokenRatio	swift.property	public	let summaryTokenRatio: Double	Sources/Swarm/Core/ContextProfile.swift:250
ContextProfile.workingTokenRatio	swift.property	public	let workingTokenRatio: Double	Sources/Swarm/Core/ContextProfile.swift:241
ContextProfile.safetyMarginTokens	swift.property	public	let safetyMarginTokens: Int	Sources/Swarm/Core/ContextProfile.swift:274
ContextProfile.maxToolOutputTokens	swift.property	public	let maxToolOutputTokens: Int	Sources/Swarm/Core/ContextProfile.swift:253
ContextProfile.outputReserveTokens	swift.property	public	let outputReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:268
ContextProfile.summaryCadenceTurns	swift.property	public	let summaryCadenceTurns: Int	Sources/Swarm/Core/ContextProfile.swift:262
ContextProfile.maxRetrievedItemTokens	swift.property	public	let maxRetrievedItemTokens: Int	Sources/Swarm/Core/ContextProfile.swift:259
ContextProfile.summaryTriggerUtilization	swift.property	public	let summaryTriggerUtilization: Double	Sources/Swarm/Core/ContextProfile.swift:265
ContextProfile.protocolOverheadReserveTokens	swift.property	public	let protocolOverheadReserveTokens: Int	Sources/Swarm/Core/ContextProfile.swift:271
ContextProfile.lite(maxContextTokens:)	swift.type.method	public	static func lite(maxContextTokens: Int) -> ContextProfile	Sources/Swarm/Core/ContextProfile.swift:144
ContextProfile.lite	swift.type.property	public	static var lite: ContextProfile { get }	Sources/Swarm/Core/ContextProfile.swift:124
ContextProfile.heavy(maxContextTokens:)	swift.type.method	public	static func heavy(maxContextTokens: Int) -> ContextProfile	Sources/Swarm/Core/ContextProfile.swift:178
ContextProfile.heavy	swift.type.property	public	static var heavy: ContextProfile { get }	Sources/Swarm/Core/ContextProfile.swift:134
ContextProfile.Preset	swift.enum	public	enum Preset	Sources/Swarm/Core/ContextProfile.swift:18
ContextProfile.Preset.lite	swift.enum.case	public	case lite	Sources/Swarm/Core/ContextProfile.swift:19
ContextProfile.Preset.heavy	swift.enum.case	public	case heavy	Sources/Swarm/Core/ContextProfile.swift:21
ContextProfile.Preset.balanced	swift.enum.case	public	case balanced	Sources/Swarm/Core/ContextProfile.swift:20
ContextProfile.Preset.init(rawValue:)	swift.init	public	init?(rawValue: String)	
ContextProfile.Preset.strict4k	swift.enum.case	public	case strict4k	Sources/Swarm/Core/ContextProfile.swift:22
ContextProfile.budget	swift.property	public	var budget: ContextBudget { get }	Sources/Swarm/Core/ContextProfile.swift:370
ContextProfile.init(preset:maxContextTokens:workingTokenRatio:memoryTokenRatio:toolIOTokenRatio:summaryTokenRatio:maxToolOutputTokens:maxRetrievedItems:maxRetrievedItemTokens:summaryCadenceTurns:summaryTriggerUtilization:maxTotalContextTokens:outputReserveTokens:protocolOverheadReserveTokens:safetyMarginTokens:bucketCaps:)	swift.init	public	init(preset: ContextProfile.Preset, maxContextTokens: Int, workingTokenRatio: Double, memoryTokenRatio: Double, toolIOTokenRatio: Double, summaryTokenRatio: Double, maxToolOutputTokens: Int, maxRetrievedItems: Int, maxRetrievedItemTokens: Int, summaryCadenceTurns: Int, summaryTriggerUtilization: Double, maxTotalContextTokens: Int? = nil, outputReserveTokens: Int = 0, protocolOverheadReserveTokens: Int = 0, safetyMarginTokens: Int = 0, bucketCaps: ContextBucketCaps? = nil)	Sources/Swarm/Core/ContextProfile.swift:300
ContextProfile.preset	swift.property	public	let preset: ContextProfile.Preset	Sources/Swarm/Core/ContextProfile.swift:232
ContextProfile.balanced(maxContextTokens:)	swift.type.method	public	static func balanced(maxContextTokens: Int) -> ContextProfile	Sources/Swarm/Core/ContextProfile.swift:161
ContextProfile.balanced	swift.type.property	public	static var balanced: ContextProfile { get }	Sources/Swarm/Core/ContextProfile.swift:129
ContextProfile.strict4k(template:)	swift.type.method	public	static func strict4k(template: ContextProfile.Strict4kTemplate = .default) -> ContextProfile	Sources/Swarm/Core/ContextProfile.swift:195
ContextProfile.strict4k	swift.type.property	public	static var strict4k: ContextProfile { get }	Sources/Swarm/Core/ContextProfile.swift:139
EmbeddingError	swift.enum	public	enum EmbeddingError	Sources/Swarm/Memory/EmbeddingProvider.swift:89
EmbeddingError.networkError(underlying:)	swift.enum.case	public	case networkError(underlying: any Error)	Sources/Swarm/Memory/EmbeddingProvider.swift:129
EmbeddingError.emptyInput	swift.enum.case	public	case emptyInput	Sources/Swarm/Memory/EmbeddingProvider.swift:123
EmbeddingError.description	swift.property	public	var description: String { get }	Sources/Swarm/Memory/EmbeddingProvider.swift:92
EmbeddingError.batchTooLarge(size:limit:)	swift.enum.case	public	case batchTooLarge(size: Int, limit: Int)	Sources/Swarm/Memory/EmbeddingProvider.swift:126
EmbeddingError.embeddingFailed(reason:)	swift.enum.case	public	case embeddingFailed(reason: String)	Sources/Swarm/Memory/EmbeddingProvider.swift:138
EmbeddingError.modelUnavailable(reason:)	swift.enum.case	public	case modelUnavailable(reason: String)	Sources/Swarm/Memory/EmbeddingProvider.swift:117
EmbeddingError.dimensionMismatch(expected:got:)	swift.enum.case	public	case dimensionMismatch(expected: Int, got: Int)	Sources/Swarm/Memory/EmbeddingProvider.swift:120
EmbeddingError.rateLimitExceeded(retryAfter:)	swift.enum.case	public	case rateLimitExceeded(retryAfter: TimeInterval?)	Sources/Swarm/Memory/EmbeddingProvider.swift:132
EmbeddingError.authenticationFailed	swift.enum.case	public	case authenticationFailed	Sources/Swarm/Memory/EmbeddingProvider.swift:135
EmbeddingUtils	swift.enum	public	enum EmbeddingUtils	Sources/Swarm/Memory/EmbeddingProvider.swift:186
EmbeddingUtils.cosineSimilarity(_:_:)	swift.type.method	public	static func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Float	Sources/Swarm/Memory/EmbeddingProvider.swift:193
EmbeddingUtils.euclideanDistance(_:_:)	swift.type.method	public	static func euclideanDistance(_ embedding1: [Float], _ embedding2: [Float]) -> Float	Sources/Swarm/Memory/EmbeddingProvider.swift:216
EmbeddingUtils.normalize(_:)	swift.type.method	public	static func normalize(_ vector: [Float]) -> [Float]	Sources/Swarm/Memory/EmbeddingProvider.swift:232
GuardrailError	swift.enum	public	enum GuardrailError	Sources/Swarm/Guardrails/GuardrailError.swift:11
GuardrailError.executionFailed(guardrailName:underlyingError:)	swift.enum.case	public	case executionFailed(guardrailName: String, underlyingError: String)	Sources/Swarm/Guardrails/GuardrailError.swift:61
GuardrailError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Guardrails/GuardrailError.swift:67
GuardrailError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Guardrails/GuardrailError.swift:14
GuardrailError.inputTripwireTriggered(guardrailName:message:outputInfo:)	swift.enum.case	public	case inputTripwireTriggered(guardrailName: String, message: String?, outputInfo: SendableValue?)	Sources/Swarm/Guardrails/GuardrailError.swift:30
GuardrailError.outputTripwireTriggered(guardrailName:agentName:message:outputInfo:)	swift.enum.case	public	case outputTripwireTriggered(guardrailName: String, agentName: String, message: String?, outputInfo: SendableValue?)	Sources/Swarm/Guardrails/GuardrailError.swift:37
GuardrailError.toolInputTripwireTriggered(guardrailName:toolName:message:outputInfo:)	swift.enum.case	public	case toolInputTripwireTriggered(guardrailName: String, toolName: String, message: String?, outputInfo: SendableValue?)	Sources/Swarm/Guardrails/GuardrailError.swift:45
GuardrailError.toolOutputTripwireTriggered(guardrailName:toolName:message:outputInfo:)	swift.enum.case	public	case toolOutputTripwireTriggered(guardrailName: String, toolName: String, message: String?, outputInfo: SendableValue?)	Sources/Swarm/Guardrails/GuardrailError.swift:53
HandoffBuilder	swift.struct	public	struct HandoffBuilder<Target> where Target : AgentRuntime	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:35
HandoffBuilder.onTransfer(_:)	swift.method	public	func onTransfer(_ callback: @escaping OnTransferCallback) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:105
HandoffBuilder.toolDescription(_:)	swift.method	public	func toolDescription(_ description: String) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:82
HandoffBuilder.init(to:)	swift.init	public	init(to target: Target)	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:43
HandoffBuilder.when(_:)	swift.method	public	func when(_ check: @escaping WhenCallback) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:150
HandoffBuilder.build()	swift.method	public	func build() -> HandoffConfiguration<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:189
HandoffBuilder.history(_:)	swift.method	public	func history(_ history: HandoffHistory) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:170
HandoffBuilder.toolName(_:)	swift.method	public	func toolName(_ name: String) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:63
HandoffBuilder.transform(_:)	swift.method	public	func transform(_ filter: @escaping TransformCallback) -> HandoffBuilder<Target>	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:128
HandoffHistory	swift.enum	public	enum HandoffHistory	Sources/Swarm/Core/Handoff/HandoffOptions.swift:9
HandoffHistory.summarized(maxTokens:)	swift.enum.case	public	case summarized(maxTokens: Int = 600)	Sources/Swarm/Core/Handoff/HandoffOptions.swift:20
HandoffHistory.none	swift.enum.case	public	case none	Sources/Swarm/Core/Handoff/HandoffOptions.swift:11
HandoffHistory.nested	swift.enum.case	public	case nested	Sources/Swarm/Core/Handoff/HandoffOptions.swift:14
HandoffOptions	swift.struct	public	struct HandoffOptions<Target> where Target : AgentRuntime	Sources/Swarm/Core/Handoff/HandoffOptions.swift:118
HandoffOptions.onTransfer(_:)	swift.method	public	func onTransfer(_ callback: @escaping OnTransferCallback) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:149
HandoffOptions.description(_:)	swift.method	public	func description(_ value: String) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:144
HandoffOptions.name(_:)	swift.method	public	func name(_ value: String) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:139
HandoffOptions.when(_:)	swift.method	public	func when(_ callback: @escaping WhenCallback) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:159
HandoffOptions.policy(_:)	swift.method	public	func policy(_ policy: HandoffPolicy) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:172
HandoffOptions.history(_:)	swift.method	public	func history(_ strategy: HandoffHistory) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:164
HandoffOptions.transform(_:)	swift.method	public	func transform(_ callback: @escaping TransformCallback) -> HandoffOptions<Target>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:154
HandoffOptions.init()	swift.init	public	init()	Sources/Swarm/Core/Handoff/HandoffOptions.swift:128
HandoffRequest	swift.struct	public	struct HandoffRequest	Sources/Swarm/Core/Handoff/Handoff.swift:29
HandoffRequest.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/Handoff/Handoff.swift:523
HandoffRequest.init(sourceAgentName:targetAgentName:input:reason:context:)	swift.init	public	init(sourceAgentName: String, targetAgentName: String, input: String, reason: String? = nil, context: [String : SendableValue] = [:])	Sources/Swarm/Core/Handoff/Handoff.swift:53
HandoffRequest.sourceAgentName	swift.property	public	let sourceAgentName: String	Sources/Swarm/Core/Handoff/Handoff.swift:31
HandoffRequest.targetAgentName	swift.property	public	let targetAgentName: String	Sources/Swarm/Core/Handoff/Handoff.swift:34
HandoffRequest.input	swift.property	public	let input: String	Sources/Swarm/Core/Handoff/Handoff.swift:37
HandoffRequest.reason	swift.property	public	let reason: String?	Sources/Swarm/Core/Handoff/Handoff.swift:40
HandoffRequest.context	swift.property	public	let context: [String : SendableValue]	Sources/Swarm/Core/Handoff/Handoff.swift:43
InputGuardrail	swift.protocol	public	protocol InputGuardrail : Guardrail	Sources/Swarm/Guardrails/InputGuardrail.swift:37
InputGuardrail.name	swift.property	public	override var name: String { get }	Sources/Swarm/Guardrails/InputGuardrail.swift:39
InputGuardrail.validate(_:context:)	swift.method	public	func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/InputGuardrail.swift:48
MCPErrorObject	swift.struct	public	struct MCPErrorObject	Sources/Swarm/MCP/MCPProtocol.swift:412
MCPErrorObject.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/MCP/MCPProtocol.swift:478
MCPErrorObject.init(code:message:data:)	swift.init	public	init(code: Int, message: String, data: SendableValue? = nil)	Sources/Swarm/MCP/MCPProtocol.swift:441
MCPErrorObject.code	swift.property	public	let code: Int	Sources/Swarm/MCP/MCPProtocol.swift:418
MCPErrorObject.data	swift.property	public	let data: SendableValue?	Sources/Swarm/MCP/MCPProtocol.swift:431
MCPErrorObject.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MCPErrorObject.from(_:)	swift.type.method	public	static func from(_ error: MCPError) -> MCPErrorObject	Sources/Swarm/MCP/MCPProtocol.swift:456
MCPErrorObject.message	swift.property	public	let message: String	Sources/Swarm/MCP/MCPProtocol.swift:424
MCPServerState	swift.enum	public	enum MCPServerState	Sources/Swarm/MCP/MCPServer.swift:301
MCPServerState.initializing	swift.enum.case	public	case initializing	Sources/Swarm/MCP/MCPServer.swift:324
MCPServerState.isTerminated	swift.property	public	var isTerminated: Bool { get }	Sources/Swarm/MCP/MCPServer.swift:310
MCPServerState.error(_:)	swift.enum.case	public	case error(String)	Sources/Swarm/MCP/MCPServer.swift:336
MCPServerState.ready	swift.enum.case	public	case ready	Sources/Swarm/MCP/MCPServer.swift:327
MCPServerState.closed	swift.enum.case	public	case closed	Sources/Swarm/MCP/MCPServer.swift:333
MCPServerState.closing	swift.enum.case	public	case closing	Sources/Swarm/MCP/MCPServer.swift:330
MCPServerState.created	swift.enum.case	public	case created	Sources/Swarm/MCP/MCPServer.swift:321
MCPServerState.isReady	swift.property	public	var isReady: Bool { get }	Sources/Swarm/MCP/MCPServer.swift:305
MemoryPriority	swift.enum	public	enum MemoryPriority	Sources/Swarm/Memory/MemoryBuilder.swift:121
MemoryPriority.<(_:_:)	swift.func.op	public	static func < (lhs: MemoryPriority, rhs: MemoryPriority) -> Bool	Sources/Swarm/Memory/MemoryBuilder.swift:124
MemoryPriority.low	swift.enum.case	public	case low	Sources/Swarm/Memory/MemoryBuilder.swift:128
MemoryPriority.high	swift.enum.case	public	case high	Sources/Swarm/Memory/MemoryBuilder.swift:130
MemoryPriority.normal	swift.enum.case	public	case normal	Sources/Swarm/Memory/MemoryBuilder.swift:129
MemoryPriority.init(rawValue:)	swift.init	public	init?(rawValue: Int)	
OllamaSettings	swift.struct	public	struct OllamaSettings	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:9
OllamaSettings.healthCheck	swift.property	public	var healthCheck: Bool	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:17
OllamaSettings.pullOnMissing	swift.property	public	var pullOnMissing: Bool	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:13
OllamaSettings.init(host:port:keepAlive:pullOnMissing:numGPU:lowVRAM:numCtx:healthCheck:)	swift.init	public	init(host: String = "localhost", port: Int = 11434, keepAlive: String? = nil, pullOnMissing: Bool = false, numGPU: Int? = nil, lowVRAM: Bool = false, numCtx: Int? = nil, healthCheck: Bool = true)	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:19
OllamaSettings.host	swift.property	public	var host: String	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:10
OllamaSettings.port	swift.property	public	var port: Int	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:11
OllamaSettings.numCtx	swift.property	public	var numCtx: Int?	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:16
OllamaSettings.numGPU	swift.property	public	var numGPU: Int?	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:14
OllamaSettings.default	swift.type.property	public	static let `default`: OllamaSettings	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:39
OllamaSettings.lowVRAM	swift.property	public	var lowVRAM: Bool	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:15
OllamaSettings.keepAlive	swift.property	public	var keepAlive: String?	Sources/Swarm/Providers/Conduit/OllamaSettings.swift:12
OpenRouterTool	swift.struct	public	struct OpenRouterTool	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:409
OpenRouterTool.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterTool.type	swift.property	public	let type: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:411
OpenRouterTool.function(name:description:parameters:)	swift.type.method	public	static func function(name: String, description: String?, parameters: SendableValue?) -> OpenRouterTool	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:423
OpenRouterTool.function	swift.property	public	let function: OpenRouterToolFunction	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:414
OpenRouterTool.init(function:)	swift.init	public	init(function: OpenRouterToolFunction)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:417
SourceLocation	swift.struct	public	struct SourceLocation	Sources/Swarm/Observability/TraceEvent.swift:70
SourceLocation.init(file:function:line:)	swift.init	public	init(file: String = #file, function: String = #function, line: Int = #line)	Sources/Swarm/Observability/TraceEvent.swift:86
SourceLocation.file	swift.property	public	let file: String	Sources/Swarm/Observability/TraceEvent.swift:71
SourceLocation.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
SourceLocation.line	swift.property	public	let line: Int	Sources/Swarm/Observability/TraceEvent.swift:73
SourceLocation.filename	swift.property	public	var filename: String { get }	Sources/Swarm/Observability/TraceEvent.swift:76
SourceLocation.function	swift.property	public	let function: String	Sources/Swarm/Observability/TraceEvent.swift:72
SourceLocation.formatted	swift.property	public	var formatted: String { get }	Sources/Swarm/Observability/TraceEvent.swift:81
SwiftLogTracer	swift.class	public	actor SwiftLogTracer	Sources/Swarm/Observability/SwiftLogTracer.swift:36
SwiftLogTracer.production()	swift.type.method	public	static func production() -> SwiftLogTracer	Sources/Swarm/Observability/SwiftLogTracer.swift:154
SwiftLogTracer.development()	swift.type.method	public	static func development() -> SwiftLogTracer	Sources/Swarm/Observability/SwiftLogTracer.swift:147
SwiftLogTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/SwiftLogTracer.swift:76
SwiftLogTracer.init(label:minimumLevel:)	swift.init	public	init(label: String = "com.swarm.tracer", minimumLevel: EventLevel = .debug)	Sources/Swarm/Observability/SwiftLogTracer.swift:44
SwiftLogTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/SwiftLogTracer.swift:54
TokenEstimator	swift.protocol	public	protocol TokenEstimator : Sendable	Sources/Swarm/Memory/TokenEstimator.swift:14
TokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for text: String) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:19
TokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for texts: [String]) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:25
TokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for texts: [String]) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:31
ToolCallRecord	swift.struct	public	struct ToolCallRecord	Sources/Swarm/Core/AgentResponse.swift:30
ToolCallRecord.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentResponse.swift:84
ToolCallRecord.errorMessage	swift.property	public	let errorMessage: String?	Sources/Swarm/Core/AgentResponse.swift:50
ToolCallRecord.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Core/AgentResponse.swift:92
ToolCallRecord.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ToolCallRecord.result	swift.property	public	let result: SendableValue	Sources/Swarm/Core/AgentResponse.swift:38
ToolCallRecord.duration	swift.property	public	let duration: Duration	Sources/Swarm/Core/AgentResponse.swift:41
ToolCallRecord.init(toolName:arguments:result:duration:timestamp:isSuccess:errorMessage:)	swift.init	public	init(toolName: String, arguments: [String : SendableValue] = [:], result: SendableValue = .null, duration: Duration = .zero, timestamp: Date = Date(), isSuccess: Bool = true, errorMessage: String? = nil)	Sources/Swarm/Core/AgentResponse.swift:62
ToolCallRecord.toolName	swift.property	public	let toolName: String	Sources/Swarm/Core/AgentResponse.swift:32
ToolCallRecord.arguments	swift.property	public	let arguments: [String : SendableValue]	Sources/Swarm/Core/AgentResponse.swift:35
ToolCallRecord.isSuccess	swift.property	public	let isSuccess: Bool	Sources/Swarm/Core/AgentResponse.swift:47
ToolCallRecord.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Core/AgentResponse.swift:44
ToolChainError	swift.enum	public	enum ToolChainError	Sources/Swarm/Tools/ToolChainBuilder.swift:563
ToolChainError.emptyChain	swift.enum.case	public	case emptyChain	Sources/Swarm/Tools/ToolChainBuilder.swift:592
ToolChainError.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/ToolChainBuilder.swift:568
ToolChainError.executionFailed(toolName:reason:)	swift.enum.case	public	case executionFailed(toolName: String, reason: String)	Sources/Swarm/Tools/ToolChainBuilder.swift:589
ToolChainError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Tools/ToolChainBuilder.swift:581
ToolChainError.timeout(toolName:duration:)	swift.enum.case	public	case timeout(toolName: String, duration: Duration)	Sources/Swarm/Tools/ToolChainBuilder.swift:586
WaxIntegration	swift.struct	public	struct WaxIntegration	Sources/Swarm/Integration/Wax/WaxIntegration.swift:4
WaxIntegration.debugDescription	swift.type.property	public	static var debugDescription: String { get }	Sources/Swarm/Integration/Wax/WaxIntegration.swift:13
WaxIntegration.isEnabled	swift.property	public	var isEnabled: Bool { get }	Sources/Swarm/Integration/Wax/WaxIntegration.swift:8
WaxIntegration.init()	swift.init	public	init()	Sources/Swarm/Integration/Wax/WaxIntegration.swift:5
ZoniSearchTool	swift.struct	public	struct ZoniSearchTool	Sources/Swarm/Tools/ZoniSearchTool.swift:16
ZoniSearchTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/ZoniSearchTool.swift:15
ZoniSearchTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/ZoniSearchTool.swift:15
ZoniSearchTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/ZoniSearchTool.swift:15
ZoniSearchTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/ZoniSearchTool.swift:15
ZoniSearchTool.execute()	swift.method	public	func execute() async throws -> String	Sources/Swarm/Tools/ZoniSearchTool.swift:37
ZoniSearchTool.init()	swift.init	public	init()	Sources/Swarm/Tools/ZoniSearchTool.swift:28
AgentContextKey	swift.enum	public	enum AgentContextKey	Sources/Swarm/Core/Execution/AgentContext.swift:22
AgentContextKey.currentAgentName	swift.enum.case	public	case currentAgentName	Sources/Swarm/Core/Execution/AgentContext.swift:30
AgentContextKey.executionPath	swift.enum.case	public	case executionPath	Sources/Swarm/Core/Execution/AgentContext.swift:33
AgentContextKey.originalInput	swift.enum.case	public	case originalInput	Sources/Swarm/Core/Execution/AgentContext.swift:24
AgentContextKey.previousOutput	swift.enum.case	public	case previousOutput	Sources/Swarm/Core/Execution/AgentContext.swift:27
AgentContextKey.metadata	swift.enum.case	public	case metadata	Sources/Swarm/Core/Execution/AgentContext.swift:39
AgentContextKey.init(rawValue:)	swift.init	public	init?(rawValue: String)	
AgentContextKey.startTime	swift.enum.case	public	case startTime	Sources/Swarm/Core/Execution/AgentContext.swift:36
BackoffStrategy	swift.enum	public	enum BackoffStrategy	Sources/Swarm/Resilience/RetryPolicy.swift:55
BackoffStrategy.exponential(base:multiplier:maxDelay:)	swift.enum.case	public	case exponential(base: TimeInterval, multiplier: Double, maxDelay: TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:103
BackoffStrategy.decorrelatedJitter(base:maxDelay:)	swift.enum.case	public	case decorrelatedJitter(base: TimeInterval, maxDelay: TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:109
BackoffStrategy.exponentialWithJitter(base:multiplier:maxDelay:)	swift.enum.case	public	case exponentialWithJitter(base: TimeInterval, multiplier: Double, maxDelay: TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:106
BackoffStrategy.==(_:_:)	swift.func.op	public	static func == (lhs: BackoffStrategy, rhs: BackoffStrategy) -> Bool	Sources/Swarm/Resilience/RetryPolicy.swift:126
BackoffStrategy.delay(forAttempt:)	swift.method	public	func delay(forAttempt attempt: Int) -> TimeInterval	Sources/Swarm/Resilience/RetryPolicy.swift:61
BackoffStrategy.fixed(delay:)	swift.enum.case	public	case fixed(delay: TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:97
BackoffStrategy.custom(_:)	swift.enum.case	public	case custom((Int) -> TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:120
BackoffStrategy.linear(initial:increment:maxDelay:)	swift.enum.case	public	case linear(initial: TimeInterval, increment: TimeInterval, maxDelay: TimeInterval)	Sources/Swarm/Resilience/RetryPolicy.swift:100
BackoffStrategy.immediate	swift.enum.case	public	case immediate	Sources/Swarm/Resilience/RetryPolicy.swift:112
CompositeMemory	swift.class	public	actor CompositeMemory	Sources/Swarm/Memory/MemoryBuilder.swift:193
CompositeMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/MemoryBuilder.swift:290
CompositeMemory.buildContext(maxTokens:)	swift.method	public	func buildContext(maxTokens: Int) async -> String	Sources/Swarm/Memory/MemoryBuilder.swift:331
CompositeMemory.componentCount	swift.property	public	nonisolated var componentCount: Int { get }	Sources/Swarm/Memory/MemoryBuilder.swift:197
CompositeMemory.init(tokenEstimator:_:)	swift.init	public	init(tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared, @MemoryBuilder _ content: () -> [MemoryComponent])	Sources/Swarm/Memory/MemoryBuilder.swift:225
CompositeMemory.withMergeStrategy(_:)	swift.method	public	nonisolated func withMergeStrategy(_ strategy: MemoryMergeStrategy) -> CompositeMemory	Sources/Swarm/Memory/MemoryBuilder.swift:255
CompositeMemory.withTokenEstimator(_:)	swift.method	public	nonisolated func withTokenEstimator(_ estimator: any TokenEstimator) -> CompositeMemory	Sources/Swarm/Memory/MemoryBuilder.swift:268
CompositeMemory.withRetrievalStrategy(_:)	swift.method	public	nonisolated func withRetrievalStrategy(_ strategy: RetrievalStrategy) -> CompositeMemory	Sources/Swarm/Memory/MemoryBuilder.swift:242
CompositeMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/MemoryBuilder.swift:279
CompositeMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/MemoryBuilder.swift:301
CompositeMemory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/MemoryBuilder.swift:201
CompositeMemory.store(_:)	swift.method	public	func store(_ message: MemoryMessage) async	Sources/Swarm/Memory/MemoryBuilder.swift:314
CompositeMemory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/MemoryBuilder.swift:285
CompositeMemory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/MemoryBuilder.swift:211
CompositeMemory.retrieve(limit:)	swift.method	public	func retrieve(limit: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/MemoryBuilder.swift:322
CompositeTracer	swift.class	public	actor CompositeTracer	Sources/Swarm/Observability/AgentTracer.swift:101
CompositeTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:151
CompositeTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/AgentTracer.swift:130
CompositeTracer.init(tracers:minimumLevel:shouldExecuteInParallel:)	swift.init	public	init(tracers: [any Tracer], minimumLevel: EventLevel = .trace, shouldExecuteInParallel: Bool = true)	Sources/Swarm/Observability/AgentTracer.swift:110
CompositeTracer.init(tracers:parallel:)	swift.init	public	convenience init(tracers: [any Tracer], parallel: Bool)	Sources/Swarm/Observability/AgentTracer.swift:126
ExecutionResult	swift.struct	public	struct ExecutionResult<Output> where Output : Sendable	Sources/Swarm/Resilience/FallbackChain.swift:50
ExecutionResult.totalAttempts	swift.property	public	let totalAttempts: Int	Sources/Swarm/Resilience/FallbackChain.swift:61
ExecutionResult.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Resilience/FallbackChain.swift:91
ExecutionResult.errors	swift.property	public	let errors: [StepError]	Sources/Swarm/Resilience/FallbackChain.swift:64
ExecutionResult.init(output:stepName:stepIndex:totalAttempts:errors:)	swift.init	public	init(output: Output, stepName: String, stepIndex: Int, totalAttempts: Int, errors: [StepError])	Sources/Swarm/Resilience/FallbackChain.swift:73
ExecutionResult.output	swift.property	public	let output: Output	Sources/Swarm/Resilience/FallbackChain.swift:52
ExecutionResult.stepName	swift.property	public	let stepName: String	Sources/Swarm/Resilience/FallbackChain.swift:55
ExecutionResult.stepIndex	swift.property	public	let stepIndex: Int	Sources/Swarm/Resilience/FallbackChain.swift:58
GuardrailResult	swift.struct	public	struct GuardrailResult	Sources/Swarm/Guardrails/GuardrailResult.swift:35
GuardrailResult.outputInfo	swift.property	public	let outputInfo: SendableValue?	Sources/Swarm/Guardrails/GuardrailResult.swift:53
GuardrailResult.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Guardrails/GuardrailResult.swift:143
GuardrailResult.init(tripwireTriggered:outputInfo:message:metadata:)	swift.init	public	init(tripwireTriggered: Bool, outputInfo: SendableValue? = nil, message: String? = nil, metadata: [String : SendableValue] = [:])	Sources/Swarm/Guardrails/GuardrailResult.swift:85
GuardrailResult.tripwireTriggered	swift.property	public	let tripwireTriggered: Bool	Sources/Swarm/Guardrails/GuardrailResult.swift:38
GuardrailResult.passed(message:outputInfo:metadata:)	swift.type.method	public	static func passed(message: String? = nil, outputInfo: SendableValue? = nil, metadata: [String : SendableValue] = [:]) -> GuardrailResult	Sources/Swarm/Guardrails/GuardrailResult.swift:106
GuardrailResult.message	swift.property	public	let message: String?	Sources/Swarm/Guardrails/GuardrailResult.swift:56
GuardrailResult.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Guardrails/GuardrailResult.swift:74
GuardrailResult.tripwire(message:outputInfo:metadata:)	swift.type.method	public	static func tripwire(message: String, outputInfo: SendableValue? = nil, metadata: [String : SendableValue] = [:]) -> GuardrailResult	Sources/Swarm/Guardrails/GuardrailResult.swift:126
GuardrailRunner	swift.class	public	actor GuardrailRunner	Sources/Swarm/Guardrails/GuardrailRunner.swift:165
GuardrailRunner.init(configuration:observer:)	swift.init	public	init(configuration: GuardrailRunnerConfiguration = .default, observer: (any AgentObserver)? = nil)	Sources/Swarm/Guardrails/GuardrailRunner.swift:179
GuardrailRunner.configuration	swift.property	public	let configuration: GuardrailRunnerConfiguration	Sources/Swarm/Guardrails/GuardrailRunner.swift:167
GuardrailRunner.runInputGuardrails(_:input:context:)	swift.method	public	func runInputGuardrails(_ guardrails: [any InputGuardrail], input: String, context: AgentContext?) async throws -> [GuardrailExecutionResult]	Sources/Swarm/Guardrails/GuardrailRunner.swift:218
GuardrailRunner.runOutputGuardrails(_:output:agent:context:)	swift.method	public	func runOutputGuardrails(_ guardrails: [any OutputGuardrail], output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> [GuardrailExecutionResult]	Sources/Swarm/Guardrails/GuardrailRunner.swift:247
GuardrailRunner.runToolInputGuardrails(_:data:)	swift.method	public	func runToolInputGuardrails(_ guardrails: [any ToolInputGuardrail], data: ToolGuardrailData) async throws -> [GuardrailExecutionResult]	Sources/Swarm/Guardrails/GuardrailRunner.swift:275
GuardrailRunner.runToolOutputGuardrails(_:data:output:)	swift.method	public	func runToolOutputGuardrails(_ guardrails: [any ToolOutputGuardrail], data: ToolGuardrailData, output: SendableValue) async throws -> [GuardrailExecutionResult]	Sources/Swarm/Guardrails/GuardrailRunner.swift:302
GuardrailRunner.observer	swift.property	public	let observer: (any AgentObserver)?	Sources/Swarm/Guardrails/GuardrailRunner.swift:170
HandoffReceiver	swift.protocol	public	protocol HandoffReceiver : AgentRuntime	Sources/Swarm/Core/Handoff/Handoff.swift:159
HandoffReceiver.handleHandoff(_:context:)	swift.method	public	func handleHandoff(_ request: HandoffRequest, context: AgentContext) async throws -> AgentResult	Sources/Swarm/Core/Handoff/Handoff.swift:174
HandoffReceiver.handleHandoff(_:context:)	swift.method	public	func handleHandoff(_ request: HandoffRequest, context: AgentContext) async throws -> AgentResult	Sources/Swarm/Core/Handoff/Handoff.swift:197
InMemoryBackend	swift.class	public	actor InMemoryBackend	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:26
InMemoryBackend.messageCount(conversationId:)	swift.method	public	func messageCount(conversationId: String) async throws -> Int	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:64
InMemoryBackend.fetchMessages(conversationId:)	swift.method	public	func fetchMessages(conversationId: String) async throws -> [MemoryMessage]	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:49
InMemoryBackend.deleteMessages(conversationId:)	swift.method	public	func deleteMessages(conversationId: String) async throws	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:60
InMemoryBackend.conversationCount	swift.property	public	var conversationCount: Int { get }	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:35
InMemoryBackend.deleteLastMessage(conversationId:)	swift.method	public	func deleteLastMessage(conversationId: String) async throws -> MemoryMessage?	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:85
InMemoryBackend.totalMessageCount	swift.property	public	var totalMessageCount: Int { get }	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:30
InMemoryBackend.allConversationIds()	swift.method	public	func allConversationIds() async throws -> [String]	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:68
InMemoryBackend.fetchRecentMessages(conversationId:limit:)	swift.method	public	func fetchRecentMessages(conversationId: String, limit: Int) async throws -> [MemoryMessage]	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:54
InMemoryBackend.deleteOldestMessages(conversationId:keepRecent:)	swift.method	public	func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:78
InMemoryBackend.store(_:conversationId:)	swift.method	public	func store(_ message: MemoryMessage, conversationId: String) async throws	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:44
InMemoryBackend.clearAll()	swift.method	public	func clearAll() async	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:100
InMemoryBackend.storeAll(_:conversationId:)	swift.method	public	func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:72
InMemoryBackend.init()	swift.init	public	init()	Sources/Swarm/Memory/Backends/InMemoryBackend.swift:40
InMemorySession	swift.class	public	actor InMemorySession	Sources/Swarm/Memory/InMemorySession.swift:40
InMemorySession.clearSession()	swift.method	public	func clearSession() async throws	Sources/Swarm/Memory/InMemorySession.swift:131
InMemorySession.getItemCount()	swift.method	public	func getItemCount() async throws -> Int	Sources/Swarm/Memory/InMemorySession.swift:74
InMemorySession.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Memory/InMemorySession.swift:54
InMemorySession.popItem()	swift.method	public	func popItem() async throws -> MemoryMessage?	Sources/Swarm/Memory/InMemorySession.swift:120
InMemorySession.addItems(_:)	swift.method	public	func addItems(_ newItems: [MemoryMessage]) async throws	Sources/Swarm/Memory/InMemorySession.swift:111
InMemorySession.getItems(limit:)	swift.method	public	func getItems(limit: Int?) async throws -> [MemoryMessage]	Sources/Swarm/Memory/InMemorySession.swift:91
InMemorySession.itemCount	swift.property	public	var itemCount: Int { get }	Sources/Swarm/Memory/InMemorySession.swift:49
InMemorySession.init(sessionId:)	swift.init	public	init(sessionId: String = UUID().uuidString)	Sources/Swarm/Memory/InMemorySession.swift:64
InMemorySession.sessionId	swift.property	public	nonisolated let sessionId: String	Sources/Swarm/Memory/InMemorySession.swift:44
InferencePolicy	swift.struct	public	struct InferencePolicy	Sources/Swarm/Core/AgentConfiguration.swift:60
InferencePolicy.LatencyTier	swift.enum	public	enum LatencyTier	Sources/Swarm/Core/AgentConfiguration.swift:62
InferencePolicy.LatencyTier.background	swift.enum.case	public	case background	Sources/Swarm/Core/AgentConfiguration.swift:66
InferencePolicy.LatencyTier.interactive	swift.enum.case	public	case interactive	Sources/Swarm/Core/AgentConfiguration.swift:64
InferencePolicy.LatencyTier.init(rawValue:)	swift.init	public	init?(rawValue: String)	
InferencePolicy.init(latencyTier:privacyRequired:tokenBudget:networkState:)	swift.init	public	init(latencyTier: InferencePolicy.LatencyTier = .interactive, privacyRequired: Bool = false, tokenBudget: Int? = nil, networkState: InferencePolicy.NetworkState = .online)	Sources/Swarm/Core/AgentConfiguration.swift:92
InferencePolicy.latencyTier	swift.property	public	var latencyTier: InferencePolicy.LatencyTier	Sources/Swarm/Core/AgentConfiguration.swift:77
InferencePolicy.tokenBudget	swift.property	public	var tokenBudget: Int?	Sources/Swarm/Core/AgentConfiguration.swift:87
InferencePolicy.NetworkState	swift.enum	public	enum NetworkState	Sources/Swarm/Core/AgentConfiguration.swift:70
InferencePolicy.NetworkState.online	swift.enum.case	public	case online	Sources/Swarm/Core/AgentConfiguration.swift:72
InferencePolicy.NetworkState.metered	swift.enum.case	public	case metered	Sources/Swarm/Core/AgentConfiguration.swift:73
InferencePolicy.NetworkState.offline	swift.enum.case	public	case offline	Sources/Swarm/Core/AgentConfiguration.swift:71
InferencePolicy.NetworkState.init(rawValue:)	swift.init	public	init?(rawValue: String)	
InferencePolicy.networkState	swift.property	public	var networkState: InferencePolicy.NetworkState	Sources/Swarm/Core/AgentConfiguration.swift:90
InferencePolicy.privacyRequired	swift.property	public	var privacyRequired: Bool	Sources/Swarm/Core/AgentConfiguration.swift:80
LoggingObserver	swift.struct	public	struct LoggingObserver	Sources/Swarm/Core/RunHooks.swift:437
LoggingObserver.onAgentEnd(context:agent:result:)	swift.method	public	func onAgentEnd(context: AgentContext?, agent _: any AgentRuntime, result: AgentResult) async	Sources/Swarm/Core/RunHooks.swift:457
LoggingObserver.onLLMStart(context:agent:systemPrompt:inputMessages:)	swift.method	public	func onLLMStart(context: AgentContext?, agent _: any AgentRuntime, systemPrompt _: String?, inputMessages: [MemoryMessage]) async	Sources/Swarm/Core/RunHooks.swift:507
LoggingObserver.onThinking(context:agent:thought:)	swift.method	public	func onThinking(context: AgentContext?, agent _: any AgentRuntime, thought: String) async	Sources/Swarm/Core/RunHooks.swift:540
LoggingObserver.onToolStart(context:agent:call:)	swift.method	public	func onToolStart(context: AgentContext?, agent _: any AgentRuntime, call: ToolCall) async	Sources/Swarm/Core/RunHooks.swift:486
LoggingObserver.onAgentStart(context:agent:input:)	swift.method	public	func onAgentStart(context: AgentContext?, agent _: any AgentRuntime, input: String) async	Sources/Swarm/Core/RunHooks.swift:447
LoggingObserver.onOutputToken(context:agent:token:)	swift.method	public	func onOutputToken(context: AgentContext?, agent _: any AgentRuntime, token: String) async	Sources/Swarm/Core/RunHooks.swift:550
LoggingObserver.onIterationStart(context:agent:number:)	swift.method	public	func onIterationStart(context: AgentContext?, agent _: any AgentRuntime, number: Int) async	Sources/Swarm/Core/RunHooks.swift:559
LoggingObserver.onGuardrailTriggered(context:guardrailName:guardrailType:result:)	swift.method	public	func onGuardrailTriggered(context: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async	Sources/Swarm/Core/RunHooks.swift:530
LoggingObserver.onError(context:agent:error:)	swift.method	public	func onError(context: AgentContext?, agent _: any AgentRuntime, error: any Error) async	Sources/Swarm/Core/RunHooks.swift:466
LoggingObserver.onLLMEnd(context:agent:response:usage:)	swift.method	public	func onLLMEnd(context: AgentContext?, agent _: any AgentRuntime, response _: String, usage: InferenceResponse.TokenUsage?) async	Sources/Swarm/Core/RunHooks.swift:516
LoggingObserver.onHandoff(context:fromAgent:toAgent:)	swift.method	public	func onHandoff(context: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async	Sources/Swarm/Core/RunHooks.swift:475
LoggingObserver.onToolEnd(context:agent:result:)	swift.method	public	func onToolEnd(context: AgentContext?, agent _: any AgentRuntime, result: ToolResult) async	Sources/Swarm/Core/RunHooks.swift:495
LoggingObserver.init()	swift.init	public	init()	Sources/Swarm/Core/RunHooks.swift:443
MCPCapabilities	swift.struct	public	struct MCPCapabilities	Sources/Swarm/MCP/MCPCapabilities.swift:29
MCPCapabilities.description	swift.property	public	var description: String { get }	Sources/Swarm/MCP/MCPCapabilities.swift:84
MCPCapabilities.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MCPCapabilities.empty	swift.type.property	public	static let empty: MCPCapabilities	Sources/Swarm/MCP/MCPCapabilities.swift:33
MCPCapabilities.init(tools:resources:prompts:sampling:)	swift.init	public	init(tools: Bool = false, resources: Bool = false, prompts: Bool = false, sampling: Bool = false)	Sources/Swarm/MCP/MCPCapabilities.swift:68
MCPCapabilities.tools	swift.property	public	let tools: Bool	Sources/Swarm/MCP/MCPCapabilities.swift:39
MCPCapabilities.prompts	swift.property	public	let prompts: Bool	Sources/Swarm/MCP/MCPCapabilities.swift:51
MCPCapabilities.sampling	swift.property	public	let sampling: Bool	Sources/Swarm/MCP/MCPCapabilities.swift:57
MCPCapabilities.resources	swift.property	public	let resources: Bool	Sources/Swarm/MCP/MCPCapabilities.swift:45
MemoryComponent	swift.struct	public	struct MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:81
MemoryComponent.identified(by:)	swift.method	public	func identified(by identifier: String) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:113
MemoryComponent.identifier	swift.property	public	let identifier: String?	Sources/Swarm/Memory/MemoryBuilder.swift:89
MemoryComponent.init(memory:priority:identifier:)	swift.init	public	init(memory: any Memory, priority: MemoryPriority = .normal, identifier: String? = nil)	Sources/Swarm/Memory/MemoryBuilder.swift:97
MemoryComponent.memory	swift.property	public	let memory: any Memory	Sources/Swarm/Memory/MemoryBuilder.swift:83
MemoryComponent.priority	swift.property	public	let priority: MemoryPriority	Sources/Swarm/Memory/MemoryBuilder.swift:86
MemoryComponent.priority(_:)	swift.method	public	func priority(_ priority: MemoryPriority) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:108
MemoryOperation	swift.enum	public	enum MemoryOperation	Sources/Swarm/Core/AgentEvent.swift:153
MemoryOperation.read	swift.enum.case	public	case read	Sources/Swarm/Core/AgentEvent.swift:154
MemoryOperation.clear	swift.enum.case	public	case clear	Sources/Swarm/Core/AgentEvent.swift:157
MemoryOperation.write	swift.enum.case	public	case write	Sources/Swarm/Core/AgentEvent.swift:155
MemoryOperation.search	swift.enum.case	public	case search	Sources/Swarm/Core/AgentEvent.swift:156
MemoryOperation.init(rawValue:)	swift.init	public	init?(rawValue: String)	
MetricsReporter	swift.protocol	public	protocol MetricsReporter : Sendable	Sources/Swarm/Observability/MetricsCollector.swift:444
MetricsReporter.report(_:)	swift.method	public	func report(_ snapshot: MetricsSnapshot) async throws	Sources/Swarm/Observability/MetricsCollector.swift:449
MetricsSnapshot	swift.struct	public	struct MetricsSnapshot	Sources/Swarm/Observability/MetricsCollector.swift:30
MetricsSnapshot.toolErrors	swift.property	public	let toolErrors: [String : Int]	Sources/Swarm/Observability/MetricsCollector.swift:56
MetricsSnapshot.description	swift.property	public	var description: String { get }	Sources/Swarm/Observability/MetricsCollector.swift:558
MetricsSnapshot.successRate	swift.property	public	var successRate: Double { get }	Sources/Swarm/Observability/MetricsCollector.swift:69
MetricsSnapshot.toolDurations	swift.property	public	let toolDurations: [String : [TimeInterval]]	Sources/Swarm/Observability/MetricsCollector.swift:59
MetricsSnapshot.totalToolCalls	swift.property	public	var totalToolCalls: Int { get }	Sources/Swarm/Observability/MetricsCollector.swift:87
MetricsSnapshot.init(totalExecutions:successfulExecutions:failedExecutions:cancelledExecutions:executionDurations:toolCalls:toolErrors:toolDurations:timestamp:)	swift.init	public	init(totalExecutions: Int, successfulExecutions: Int, failedExecutions: Int, cancelledExecutions: Int, executionDurations: [TimeInterval], toolCalls: [String : Int], toolErrors: [String : Int], toolDurations: [String : [TimeInterval]], timestamp: Date = Date())	Sources/Swarm/Observability/MetricsCollector.swift:143
MetricsSnapshot.totalExecutions	swift.property	public	let totalExecutions: Int	Sources/Swarm/Observability/MetricsCollector.swift:34
MetricsSnapshot.totalToolErrors	swift.property	public	var totalToolErrors: Int { get }	Sources/Swarm/Observability/MetricsCollector.swift:92
MetricsSnapshot.cancellationRate	swift.property	public	var cancellationRate: Double { get }	Sources/Swarm/Observability/MetricsCollector.swift:81
MetricsSnapshot.failedExecutions	swift.property	public	let failedExecutions: Int	Sources/Swarm/Observability/MetricsCollector.swift:40
MetricsSnapshot.executionDurations	swift.property	public	let executionDurations: [TimeInterval]	Sources/Swarm/Observability/MetricsCollector.swift:48
MetricsSnapshot.cancelledExecutions	swift.property	public	let cancelledExecutions: Int	Sources/Swarm/Observability/MetricsCollector.swift:43
MetricsSnapshot.p95ExecutionDuration	swift.property	public	var p95ExecutionDuration: TimeInterval? { get }	Sources/Swarm/Observability/MetricsCollector.swift:125
MetricsSnapshot.p99ExecutionDuration	swift.property	public	var p99ExecutionDuration: TimeInterval? { get }	Sources/Swarm/Observability/MetricsCollector.swift:133
MetricsSnapshot.successfulExecutions	swift.property	public	let successfulExecutions: Int	Sources/Swarm/Observability/MetricsCollector.swift:37
MetricsSnapshot.medianExecutionDuration	swift.property	public	var medianExecutionDuration: TimeInterval? { get }	Sources/Swarm/Observability/MetricsCollector.swift:113
MetricsSnapshot.averageExecutionDuration	swift.property	public	var averageExecutionDuration: TimeInterval { get }	Sources/Swarm/Observability/MetricsCollector.swift:97
MetricsSnapshot.maximumExecutionDuration	swift.property	public	var maximumExecutionDuration: TimeInterval? { get }	Sources/Swarm/Observability/MetricsCollector.swift:108
MetricsSnapshot.minimumExecutionDuration	swift.property	public	var minimumExecutionDuration: TimeInterval? { get }	Sources/Swarm/Observability/MetricsCollector.swift:103
MetricsSnapshot.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MetricsSnapshot.errorRate	swift.property	public	var errorRate: Double { get }	Sources/Swarm/Observability/MetricsCollector.swift:75
MetricsSnapshot.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Observability/MetricsCollector.swift:64
MetricsSnapshot.toolCalls	swift.property	public	let toolCalls: [String : Int]	Sources/Swarm/Observability/MetricsCollector.swift:53
OpenRouterDelta	swift.struct	public	struct OpenRouterDelta	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:674
OpenRouterDelta.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterDelta.role	swift.property	public	let role: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:678
OpenRouterDelta.content	swift.property	public	let content: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:681
OpenRouterDelta.toolCalls	swift.property	public	let toolCalls: [OpenRouterDeltaToolCall]?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:684
OpenRouterModel	swift.struct	public	struct OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:61
OpenRouterModel.geminiPro3	swift.type.property	public	static let geminiPro3: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:83
OpenRouterModel.identifier	swift.property	public	let identifier: String	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:101
OpenRouterModel.llama3170B	swift.type.property	public	static let llama3170B: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:92
OpenRouterModel.description	swift.property	public	var description: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:128
OpenRouterModel.llama31405B	swift.type.property	public	static let llama31405B: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:89
OpenRouterModel.claude45Opus	swift.type.property	public	static let claude45Opus: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:80
OpenRouterModel.geminiFlash3	swift.type.property	public	static let geminiFlash3: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:86
OpenRouterModel.mistralLarge	swift.type.property	public	static let mistralLarge: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:95
OpenRouterModel.claude45Haiku	swift.type.property	public	static let claude45Haiku: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:77
OpenRouterModel.deepseekCoder	swift.type.property	public	static let deepseekCoder: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:98
OpenRouterModel.init(stringLiteral:)	swift.init	public	init(stringLiteral value: StringLiteralType)	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:117
OpenRouterModel.claude35Sonnet	swift.type.property	public	static let claude35Sonnet: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:74
OpenRouterModel.gpt4o	swift.type.property	public	static let gpt4o: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:65
OpenRouterModel.gpt4Turbo	swift.type.property	public	static let gpt4Turbo: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:71
OpenRouterModel.gpt4oMini	swift.type.property	public	static let gpt4oMini: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:68
OpenRouterModel.init(_:)	swift.init	public	init(_ identifier: String) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:108
OpenRouterUsage	swift.struct	public	struct OpenRouterUsage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:613
OpenRouterUsage.totalTokens	swift.property	public	let totalTokens: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:623
OpenRouterUsage.init(promptTokens:completionTokens:totalTokens:)	swift.init	public	init(promptTokens: Int?, completionTokens: Int?, totalTokens: Int?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:626
OpenRouterUsage.promptTokens	swift.property	public	let promptTokens: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:617
OpenRouterUsage.completionTokens	swift.property	public	let completionTokens: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:620
OpenRouterUsage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OutputGuardrail	swift.protocol	public	protocol OutputGuardrail : Guardrail	Sources/Swarm/Guardrails/OutputGuardrail.swift:47
OutputGuardrail.name	swift.property	public	override var name: String { get }	Sources/Swarm/Guardrails/OutputGuardrail.swift:49
OutputGuardrail.validate(_:agent:context:)	swift.method	public	func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/OutputGuardrail.swift:59
ResilienceError	swift.enum	public	enum ResilienceError	Sources/Swarm/Resilience/RetryPolicy.swift:11
ResilienceError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Resilience/RetryPolicy.swift:40
ResilienceError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Resilience/RetryPolicy.swift:25
ResilienceError.retriesExhausted(attempts:lastError:)	swift.enum.case	public	case retriesExhausted(attempts: Int, lastError: String)	Sources/Swarm/Resilience/RetryPolicy.swift:13
ResilienceError.allFallbacksFailed(errors:)	swift.enum.case	public	case allFallbacksFailed(errors: [String])	Sources/Swarm/Resilience/RetryPolicy.swift:19
ResilienceError.circuitBreakerOpen(serviceName:)	swift.enum.case	public	case circuitBreakerOpen(serviceName: String)	Sources/Swarm/Resilience/RetryPolicy.swift:16
ResponseTracker	swift.class	public	actor ResponseTracker	Sources/Swarm/Core/ResponseTracker.swift:106
ResponseTracker.getResponse(responseId:sessionId:)	swift.method	public	func getResponse(responseId: String, sessionId: String) -> AgentResponse?	Sources/Swarm/Core/ResponseTracker.swift:272
ResponseTracker.recordResponse(_:sessionId:)	swift.method	public	func recordResponse(_ response: AgentResponse, sessionId: String)	Sources/Swarm/Core/ResponseTracker.swift:194
ResponseTracker.getTotalResponseCount()	swift.method	public	func getTotalResponseCount() -> Int	Sources/Swarm/Core/ResponseTracker.swift:405
ResponseTracker.getLatestResponseId(for:)	swift.method	public	func getLatestResponseId(for sessionId: String) -> String?	Sources/Swarm/Core/ResponseTracker.swift:248
ResponseTracker.getHistory(for:limit:)	swift.method	public	func getHistory(for sessionId: String, limit: Int? = nil) -> [AgentResponse]	Sources/Swarm/Core/ResponseTracker.swift:303
ResponseTracker.maxSessions	swift.property	public	nonisolated let maxSessions: Int?	Sources/Swarm/Core/ResponseTracker.swift:125
ResponseTracker.clearHistory(for:)	swift.method	public	func clearHistory(for sessionId: String)	Sources/Swarm/Core/ResponseTracker.swift:333
ResponseTracker.init(maxHistorySize:maxSessions:)	swift.init	public	init(maxHistorySize: Int = 100, maxSessions: Int? = 1000)	Sources/Swarm/Core/ResponseTracker.swift:153
ResponseTracker.maxHistorySize	swift.property	public	nonisolated let maxHistorySize: Int	Sources/Swarm/Core/ResponseTracker.swift:115
ResponseTracker.removeSessions(notAccessedWithin:)	swift.method	public	@discardableResult func removeSessions(notAccessedWithin interval: TimeInterval) -> Int	Sources/Swarm/Core/ResponseTracker.swift:468
ResponseTracker.removeSessions(lastAccessedBefore:)	swift.method	public	@discardableResult func removeSessions(lastAccessedBefore date: Date) -> Int	Sources/Swarm/Core/ResponseTracker.swift:438
ResponseTracker.clearAllHistory()	swift.method	public	func clearAllHistory()	Sources/Swarm/Core/ResponseTracker.swift:352
ResponseTracker.getAllSessionIds()	swift.method	public	func getAllSessionIds() -> [String]	Sources/Swarm/Core/ResponseTracker.swift:391
ResponseTracker.getSessionMetadata(for:)	swift.method	public	func getSessionMetadata(for sessionId: String) -> SessionMetadata?	Sources/Swarm/Core/ResponseTracker.swift:496
ResponseTracker.getAllSessionMetadata()	swift.method	public	func getAllSessionMetadata() -> [SessionMetadata]	Sources/Swarm/Core/ResponseTracker.swift:534
ResponseTracker.getCount(for:)	swift.method	public	func getCount(for sessionId: String) -> Int	Sources/Swarm/Core/ResponseTracker.swift:370
SessionMetadata	swift.struct	public	struct SessionMetadata	Sources/Swarm/Core/ResponseTracker.swift:15
SessionMetadata.responseCount	swift.property	public	let responseCount: Int	Sources/Swarm/Core/ResponseTracker.swift:23
SessionMetadata.lastAccessTime	swift.property	public	let lastAccessTime: Date	Sources/Swarm/Core/ResponseTracker.swift:20
SessionMetadata.init(sessionId:lastAccessTime:responseCount:)	swift.init	public	init(sessionId: String, lastAccessTime: Date, responseCount: Int)	Sources/Swarm/Core/ResponseTracker.swift:31
SessionMetadata.sessionId	swift.property	public	let sessionId: String	Sources/Swarm/Core/ResponseTracker.swift:17
SummarizerError	swift.enum	public	enum SummarizerError	Sources/Swarm/Memory/Summarizer.swift:31
SummarizerError.description	swift.property	public	var description: String { get }	Sources/Swarm/Memory/Summarizer.swift:34
SummarizerError.unavailable	swift.enum.case	public	case unavailable	Sources/Swarm/Memory/Summarizer.swift:48
SummarizerError.inputTooShort	swift.enum.case	public	case inputTooShort	Sources/Swarm/Memory/Summarizer.swift:52
SummarizerError.summarizationFailed(underlying:)	swift.enum.case	public	case summarizationFailed(underlying: any Error)	Sources/Swarm/Memory/Summarizer.swift:50
SummarizerError.timeout	swift.enum.case	public	case timeout	Sources/Swarm/Memory/Summarizer.swift:54
SwiftDataMemory	swift.class	public	actor SwiftDataMemory	Sources/Swarm/Memory/SwiftDataMemory.swift:28
SwiftDataMemory.inMemory(conversationId:maxMessages:)	swift.type.method	public	static func inMemory(conversationId: String = "default", maxMessages: Int = 0) throws -> SwiftDataMemory	Sources/Swarm/Memory/SwiftDataMemory.swift:303
SwiftDataMemory.persistent(conversationId:maxMessages:)	swift.type.method	public	static func persistent(conversationId: String = "default", maxMessages: Int = 0) throws -> SwiftDataMemory	Sources/Swarm/Memory/SwiftDataMemory.swift:322
SwiftDataMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/SwiftDataMemory.swift:108
SwiftDataMemory.diagnostics()	swift.method	public	func diagnostics() async -> SwiftDataMemoryDiagnostics	Sources/Swarm/Memory/SwiftDataMemory.swift:263
SwiftDataMemory.maxMessages	swift.property	public	let maxMessages: Int	Sources/Swarm/Memory/SwiftDataMemory.swift:35
SwiftDataMemory.messageCount(forConversation:)	swift.method	public	func messageCount(forConversation id: String) async -> Int	Sources/Swarm/Memory/SwiftDataMemory.swift:247
SwiftDataMemory.conversationId	swift.property	public	let conversationId: String	Sources/Swarm/Memory/SwiftDataMemory.swift:32
SwiftDataMemory.init(modelContainer:conversationId:maxMessages:tokenEstimator:)	swift.init	public	init(modelContainer: ModelContainer, conversationId: String = "default", maxMessages: Int = 0, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/SwiftDataMemory.swift:71
SwiftDataMemory.getRecentMessages(_:)	swift.method	public	func getRecentMessages(_ n: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/SwiftDataMemory.swift:195
SwiftDataMemory.allConversationIds()	swift.method	public	func allConversationIds() async -> [String]	Sources/Swarm/Memory/SwiftDataMemory.swift:215
SwiftDataMemory.deleteConversation(_:)	swift.method	public	func deleteConversation(_ id: String) async	Sources/Swarm/Memory/SwiftDataMemory.swift:229
SwiftDataMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/SwiftDataMemory.swift:86
SwiftDataMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/SwiftDataMemory.swift:120
SwiftDataMemory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/SwiftDataMemory.swift:37
SwiftDataMemory.addAll(_:)	swift.method	public	func addAll(_ messages: [MemoryMessage]) async	Sources/Swarm/Memory/SwiftDataMemory.swift:174
SwiftDataMemory.context(for:tokenLimit:)	swift.method	public	func context(for _: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/SwiftDataMemory.swift:103
SwiftDataMemory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/SwiftDataMemory.swift:51
ToolConditional	swift.struct	public	struct ToolConditional	Sources/Swarm/Tools/ToolChainBuilder.swift:436
ToolConditional.init(if:then:else:)	swift.init	public	init(if condition: @escaping (SendableValue) async throws -> Bool, then thenStep: any ToolChainStep, else elseStep: (any ToolChainStep)? = nil)	Sources/Swarm/Tools/ToolChainBuilder.swift:447
ToolConditional.execute(input:)	swift.method	public	func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:464
TracerComponent	swift.struct	public	struct TracerComponent	Sources/Swarm/Agents/AgentBuilder.swift:164
TracerComponent.tracer	swift.property	public	let tracer: any Tracer	Sources/Swarm/Agents/AgentBuilder.swift:166
TracerComponent.init(_:)	swift.init	public	init(_ tracer: any Tracer)	Sources/Swarm/Agents/AgentBuilder.swift:171
AgentEnvironment	swift.struct	public	struct AgentEnvironment	Sources/Swarm/Core/AgentEnvironment.swift:15
AgentEnvironment.init(inferenceProvider:tracer:memory:membrane:)	swift.init	public	init(inferenceProvider: (any InferenceProvider)? = nil, tracer: (any Tracer)? = nil, memory: (any Memory)? = nil, membrane: MembraneEnvironment? = nil)	Sources/Swarm/Core/AgentEnvironment.swift:21
AgentEnvironment.inferenceProvider	swift.property	public	var inferenceProvider: (any InferenceProvider)?	Sources/Swarm/Core/AgentEnvironment.swift:16
AgentEnvironment.memory	swift.property	public	var memory: (any Memory)?	Sources/Swarm/Core/AgentEnvironment.swift:18
AgentEnvironment.tracer	swift.property	public	var tracer: (any Tracer)?	Sources/Swarm/Core/AgentEnvironment.swift:17
AgentEnvironment.membrane	swift.property	public	var membrane: MembraneEnvironment?	Sources/Swarm/Core/AgentEnvironment.swift:19
AgentEventStream	swift.enum	public	enum AgentEventStream	Sources/Swarm/Core/StreamOperations.swift:833
AgentEventStream.fail(_:)	swift.type.method	public	static func fail(_ error: any Error) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:944
AgentEventStream.from(_:)	swift.type.method	public	static func from(_ events: [AgentEvent]) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:923
AgentEventStream.just(_:)	swift.type.method	public	static func just(_ event: AgentEvent) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:936
AgentEventStream.empty()	swift.type.method	public	static func empty() -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:904
AgentEventStream.merge(_:errorStrategy:)	swift.type.method	public	static func merge(_ streams: AsyncThrowingStream<AgentEvent, any Error>..., errorStrategy: MergeErrorStrategy = .continueAndCollect) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:860
EnvironmentAgent	swift.struct	public	struct EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:9
EnvironmentAgent.instructions	swift.property	public	var instructions: String { get }	Sources/Swarm/Core/EnvironmentAgent.swift:24
EnvironmentAgent.configuration	swift.property	public	var configuration: AgentConfiguration { get }	Sources/Swarm/Core/EnvironmentAgent.swift:25
EnvironmentAgent.inputGuardrails	swift.property	public	var inputGuardrails: [any InputGuardrail] { get }	Sources/Swarm/Core/EnvironmentAgent.swift:29
EnvironmentAgent.outputGuardrails	swift.property	public	var outputGuardrails: [any OutputGuardrail] { get }	Sources/Swarm/Core/EnvironmentAgent.swift:30
EnvironmentAgent.inferenceProvider	swift.property	public	var inferenceProvider: (any InferenceProvider)? { get }	Sources/Swarm/Core/EnvironmentAgent.swift:27
EnvironmentAgent.run(_:session:observer:)	swift.method	public	func run(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResult	Sources/Swarm/Core/EnvironmentAgent.swift:33
EnvironmentAgent.init(base:modify:)	swift.init	public	init(base: any AgentRuntime, modify: @escaping (inout AgentEnvironment) -> Void)	Sources/Swarm/Core/EnvironmentAgent.swift:13
EnvironmentAgent.tools	swift.property	public	var tools: [any AnyJSONTool] { get }	Sources/Swarm/Core/EnvironmentAgent.swift:23
EnvironmentAgent.cancel()	swift.method	public	func cancel() async	Sources/Swarm/Core/EnvironmentAgent.swift:61
EnvironmentAgent.memory	swift.property	public	var memory: (any Memory)? { get }	Sources/Swarm/Core/EnvironmentAgent.swift:26
EnvironmentAgent.stream(_:session:observer:)	swift.method	public	nonisolated func stream(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/EnvironmentAgent.swift:46
EnvironmentAgent.tracer	swift.property	public	var tracer: (any Tracer)? { get }	Sources/Swarm/Core/EnvironmentAgent.swift:28
EnvironmentAgent.handoffs	swift.property	public	var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Core/EnvironmentAgent.swift:31
HandoffInputData	swift.struct	public	struct HandoffInputData	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:29
HandoffInputData.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:79
HandoffInputData.settingMetadata(_:_:)	swift.method	public	func settingMetadata<Value>(_ key: HandoffMetadataKey<Value>, _ value: Value) -> HandoffInputData where Value : Sendable	Sources/Swarm/Core/Handoff/HandoffOptions.swift:110
HandoffInputData.init(sourceAgentName:targetAgentName:input:context:metadata:)	swift.init	public	init(sourceAgentName: String, targetAgentName: String, input: String, context: [String : SendableValue] = [:], metadata: [String : SendableValue] = [:])	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:61
HandoffInputData.sourceAgentName	swift.property	public	let sourceAgentName: String	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:31
HandoffInputData.targetAgentName	swift.property	public	let targetAgentName: String	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:34
HandoffInputData.input	swift.property	public	let input: String	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:37
HandoffInputData.context	swift.property	public	let context: [String : SendableValue]	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:43
HandoffInputData.metadata(for:)	swift.method	public	func metadata<Value>(for key: HandoffMetadataKey<Value>) -> Value? where Value : Sendable	Sources/Swarm/Core/Handoff/HandoffOptions.swift:104
HandoffInputData.metadata	swift.property	public	var metadata: [String : SendableValue]	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:49
InferenceOptions	swift.struct	public	struct InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:263
InferenceOptions.toolChoice	swift.property	public	var toolChoice: ToolChoice?	Sources/Swarm/Core/AgentRuntime.swift:323
InferenceOptions.toolChoice(_:)	swift.method	public	@discardableResult func toolChoice(_ value: ToolChoice?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.truncation	swift.property	public	var truncation: TruncationStrategy?	Sources/Swarm/Core/AgentRuntime.swift:332
InferenceOptions.truncation(_:)	swift.method	public	@discardableResult func truncation(_ value: TruncationStrategy?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.init(temperature:maxTokens:stopSequences:topP:topK:presencePenalty:frequencyPenalty:toolChoice:seed:parallelToolCalls:truncation:verbosity:providerSettings:)	swift.init	public	init(temperature: Double = 1.0, maxTokens: Int? = nil, stopSequences: [String] = [], topP: Double? = nil, topK: Int? = nil, presencePenalty: Double? = nil, frequencyPenalty: Double? = nil, toolChoice: ToolChoice? = nil, seed: Int? = nil, parallelToolCalls: Bool? = nil, truncation: TruncationStrategy? = nil, verbosity: Verbosity? = nil, providerSettings: [String : SendableValue]? = nil)	Sources/Swarm/Core/AgentRuntime.swift:355
InferenceOptions.temperature	swift.property	public	var temperature: Double	Sources/Swarm/Core/AgentRuntime.swift:300
InferenceOptions.temperature(_:)	swift.method	public	@discardableResult func temperature(_ value: Double) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.stopSequences	swift.property	public	var stopSequences: [String]	Sources/Swarm/Core/AgentRuntime.swift:306
InferenceOptions.stopSequences(_:)	swift.method	public	func stopSequences(_ sequences: String...) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:390
InferenceOptions.stopSequences(_:)	swift.method	public	@discardableResult func stopSequences(_ value: [String]) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.codeGeneration	swift.type.property	public	static var codeGeneration: InferenceOptions { get }	Sources/Swarm/Core/AgentRuntime.swift:285
InferenceOptions.addStopSequence(_:)	swift.method	public	func addStopSequence(_ sequence: String) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:399
InferenceOptions.presencePenalty	swift.property	public	var presencePenalty: Double?	Sources/Swarm/Core/AgentRuntime.swift:315
InferenceOptions.presencePenalty(_:)	swift.method	public	@discardableResult func presencePenalty(_ value: Double?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.frequencyPenalty	swift.property	public	var frequencyPenalty: Double?	Sources/Swarm/Core/AgentRuntime.swift:318
InferenceOptions.frequencyPenalty(_:)	swift.method	public	@discardableResult func frequencyPenalty(_ value: Double?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.providerSettings	swift.property	public	var providerSettings: [String : SendableValue]?	Sources/Swarm/Core/AgentRuntime.swift:338
InferenceOptions.providerSettings(_:)	swift.method	public	@discardableResult func providerSettings(_ value: [String : SendableValue]?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.parallelToolCalls	swift.property	public	var parallelToolCalls: Bool?	Sources/Swarm/Core/AgentRuntime.swift:329
InferenceOptions.parallelToolCalls(_:)	swift.method	public	@discardableResult func parallelToolCalls(_ value: Bool?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.clearStopSequences()	swift.method	public	func clearStopSequences() -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:407
InferenceOptions.chat	swift.type.property	public	static var chat: InferenceOptions { get }	Sources/Swarm/Core/AgentRuntime.swift:295
InferenceOptions.seed	swift.property	public	var seed: Int?	Sources/Swarm/Core/AgentRuntime.swift:326
InferenceOptions.seed(_:)	swift.method	public	@discardableResult func seed(_ value: Int?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.topK	swift.property	public	var topK: Int?	Sources/Swarm/Core/AgentRuntime.swift:312
InferenceOptions.topK(_:)	swift.method	public	@discardableResult func topK(_ value: Int?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.topP	swift.property	public	var topP: Double?	Sources/Swarm/Core/AgentRuntime.swift:309
InferenceOptions.topP(_:)	swift.method	public	@discardableResult func topP(_ value: Double?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.with(_:)	swift.method	public	func with(_ modifications: (inout InferenceOptions) -> Void) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:416
InferenceOptions.default	swift.type.property	public	static let `default`: InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:265
InferenceOptions.precise	swift.type.property	public	static var precise: InferenceOptions { get }	Sources/Swarm/Core/AgentRuntime.swift:275
InferenceOptions.balanced	swift.type.property	public	static var balanced: InferenceOptions { get }	Sources/Swarm/Core/AgentRuntime.swift:280
InferenceOptions.creative	swift.type.property	public	static var creative: InferenceOptions { get }	Sources/Swarm/Core/AgentRuntime.swift:270
InferenceOptions.maxTokens	swift.property	public	var maxTokens: Int?	Sources/Swarm/Core/AgentRuntime.swift:303
InferenceOptions.maxTokens(_:)	swift.method	public	@discardableResult func maxTokens(_ value: Int?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
InferenceOptions.verbosity	swift.property	public	var verbosity: Verbosity?	Sources/Swarm/Core/AgentRuntime.swift:335
InferenceOptions.verbosity(_:)	swift.method	public	@discardableResult func verbosity(_ value: Verbosity?) -> InferenceOptions	Sources/Swarm/Core/AgentRuntime.swift:262
MetricsCollector	swift.class	public	actor MetricsCollector	Sources/Swarm/Observability/MetricsCollector.swift:199
MetricsCollector.init(maxMetricsHistory:)	swift.init	public	init(maxMetricsHistory: Int = 10000)	Sources/Swarm/Observability/MetricsCollector.swift:211
MetricsCollector.maxMetricsHistory	swift.property	public	let maxMetricsHistory: Int	Sources/Swarm/Observability/MetricsCollector.swift:205
MetricsCollector.getToolCalls()	swift.method	public	func getToolCalls() -> [String : Int]	Sources/Swarm/Observability/MetricsCollector.swift:372
MetricsCollector.getToolErrors()	swift.method	public	func getToolErrors() -> [String : Int]	Sources/Swarm/Observability/MetricsCollector.swift:377
MetricsCollector.getToolDurations()	swift.method	public	func getToolDurations() -> [String : [TimeInterval]]	Sources/Swarm/Observability/MetricsCollector.swift:382
MetricsCollector.getTotalExecutions()	swift.method	public	func getTotalExecutions() -> Int	Sources/Swarm/Observability/MetricsCollector.swift:352
MetricsCollector.getFailedExecutions()	swift.method	public	func getFailedExecutions() -> Int	Sources/Swarm/Observability/MetricsCollector.swift:362
MetricsCollector.getCancelledExecutions()	swift.method	public	func getCancelledExecutions() -> Int	Sources/Swarm/Observability/MetricsCollector.swift:367
MetricsCollector.getSuccessfulExecutions()	swift.method	public	func getSuccessfulExecutions() -> Int	Sources/Swarm/Observability/MetricsCollector.swift:357
MetricsCollector.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/MetricsCollector.swift:301
MetricsCollector.reset()	swift.method	public	func reset()	Sources/Swarm/Observability/MetricsCollector.swift:337
MetricsCollector.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/MetricsCollector.swift:230
MetricsCollector.snapshot()	swift.method	public	func snapshot() -> MetricsSnapshot	Sources/Swarm/Observability/MetricsCollector.swift:312
OpenRouterChoice	swift.struct	public	struct OpenRouterChoice	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:501
OpenRouterChoice.finishReason	swift.property	public	let finishReason: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:511
OpenRouterChoice.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterChoice.init(index:message:finishReason:)	swift.init	public	init(index: Int, message: OpenRouterResponseMessage, finishReason: String?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:514
OpenRouterChoice.index	swift.property	public	let index: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:505
OpenRouterChoice.message	swift.property	public	let message: OpenRouterResponseMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:508
PersistedMessage	swift.class	public	final class PersistedMessage	Sources/Swarm/Memory/PersistedMessage.swift:28
PersistedMessage.toMemoryMessage()	swift.method	public	func toMemoryMessage() -> MemoryMessage?	Sources/Swarm/Memory/PersistedMessage.swift:98
PersistedMessage.init(backingData:)	swift.init	public	init(backingData: any BackingData<PersistedMessage>)	Sources/Swarm/Memory/PersistedMessage.swift:27
PersistedMessage.metadataJSON	swift.property	public	var metadataJSON: String { get set }	Sources/Swarm/Memory/PersistedMessage.swift:42
PersistedMessage.makeContainer(inMemory:)	swift.type.method	public	static func makeContainer(inMemory: Bool = false) throws -> ModelContainer	Sources/Swarm/Memory/PersistedMessage.swift:179
PersistedMessage.conversationId	swift.property	public	var conversationId: String { get set }	Sources/Swarm/Memory/PersistedMessage.swift:45
PersistedMessage.schemaMetadata	swift.type.property	public	class var schemaMetadata: [Schema.PropertyMetadata] { get }	Sources/Swarm/Memory/PersistedMessage.swift:27
PersistedMessage.fetchDescriptor(forConversation:limit:)	swift.type.method	public	static func fetchDescriptor(forConversation conversationId: String, limit: Int) -> FetchDescriptor<PersistedMessage>	Sources/Swarm/Memory/PersistedMessage.swift:158
PersistedMessage.fetchDescriptor(forConversation:)	swift.type.method	public	static func fetchDescriptor(forConversation conversationId: String) -> FetchDescriptor<PersistedMessage>	Sources/Swarm/Memory/PersistedMessage.swift:143
PersistedMessage.persistentBackingData	swift.property	public	var persistentBackingData: any BackingData<PersistedMessage> { get set }	Sources/Swarm/Memory/PersistedMessage.swift:27
PersistedMessage.allConversationsDescriptor	swift.type.property	public	static var allConversationsDescriptor: FetchDescriptor<PersistedMessage> { get }	Sources/Swarm/Memory/PersistedMessage.swift:133
PersistedMessage.id	swift.property	public	var id: UUID { get set }	Sources/Swarm/Memory/PersistedMessage.swift:30
PersistedMessage.init(id:role:content:timestamp:metadataJSON:conversationId:)	swift.init	public	init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), metadataJSON: String = "{}", conversationId: String = "default")	Sources/Swarm/Memory/PersistedMessage.swift:56
PersistedMessage.init(from:conversationId:)	swift.init	public	convenience init(from message: MemoryMessage, conversationId: String = "default")	Sources/Swarm/Memory/PersistedMessage.swift:77
PersistedMessage.role	swift.property	public	var role: String { get set }	Sources/Swarm/Memory/PersistedMessage.swift:33
PersistedMessage.content	swift.property	public	var content: String { get set }	Sources/Swarm/Memory/PersistedMessage.swift:36
PersistedMessage.timestamp	swift.property	public	var timestamp: Date { get set }	Sources/Swarm/Memory/PersistedMessage.swift:39
PersistentMemory	swift.class	public	actor PersistentMemory	Sources/Swarm/Memory/PersistentMemory.swift:32
PersistentMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/PersistentMemory.swift:107
PersistentMemory.maxMessages	swift.property	public	let maxMessages: Int	Sources/Swarm/Memory/PersistentMemory.swift:39
PersistentMemory.conversationId	swift.property	public	let conversationId: String	Sources/Swarm/Memory/PersistentMemory.swift:36
PersistentMemory.tokenEstimator	swift.property	public	let tokenEstimator: any TokenEstimator	Sources/Swarm/Memory/PersistentMemory.swift:42
PersistentMemory.getRecentMessages(limit:)	swift.method	public	func getRecentMessages(limit: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/PersistentMemory.swift:130
PersistentMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/PersistentMemory.swift:86
PersistentMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/PersistentMemory.swift:116
PersistentMemory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/PersistentMemory.swift:44
PersistentMemory.addAll(_:)	swift.method	public	func addAll(_ messages: [MemoryMessage]) async	Sources/Swarm/Memory/PersistentMemory.swift:145
PersistentMemory.init(backend:conversationId:maxMessages:tokenEstimator:)	swift.init	public	init(backend: any PersistentMemoryBackend, conversationId: String = UUID().uuidString, maxMessages: Int = 0, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/PersistentMemory.swift:72
PersistentMemory.context(for:tokenLimit:)	swift.method	public	func context(for _: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/PersistentMemory.swift:98
PersistentMemory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/PersistentMemory.swift:54
SwiftDataBackend	swift.class	public	actor SwiftDataBackend	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:24
SwiftDataBackend.persistent()	swift.type.method	public	static func persistent() throws -> SwiftDataBackend	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:48
SwiftDataBackend.messageCount(conversationId:)	swift.method	public	func messageCount(conversationId: String) async throws -> Int	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:88
SwiftDataBackend.fetchMessages(conversationId:)	swift.method	public	func fetchMessages(conversationId: String) async throws -> [MemoryMessage]	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:62
SwiftDataBackend.deleteMessages(conversationId:)	swift.method	public	func deleteMessages(conversationId: String) async throws	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:78
SwiftDataBackend.init(modelContainer:)	swift.init	public	init(modelContainer: ModelContainer)	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:30
SwiftDataBackend.deleteLastMessage(conversationId:)	swift.method	public	func deleteLastMessage(conversationId: String) async throws -> MemoryMessage?	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:152
SwiftDataBackend.allConversationIds()	swift.method	public	func allConversationIds() async throws -> [String]	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:93
SwiftDataBackend.fetchRecentMessages(conversationId:limit:)	swift.method	public	func fetchRecentMessages(conversationId: String, limit: Int) async throws -> [MemoryMessage]	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:68
SwiftDataBackend.deleteOldestMessages(conversationId:keepRecent:)	swift.method	public	func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:131
SwiftDataBackend.store(_:conversationId:)	swift.method	public	func store(_ message: MemoryMessage, conversationId: String) async throws	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:55
SwiftDataBackend.inMemory()	swift.type.method	public	static func inMemory() throws -> SwiftDataBackend	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:40
SwiftDataBackend.storeAll(_:conversationId:)	swift.method	public	func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws	Sources/Swarm/Memory/Backends/SwiftDataBackend.swift:99
ToolArrayBuilder	swift.struct	public	@resultBuilder struct ToolArrayBuilder	Sources/Swarm/Tools/ToolParameterBuilder.swift:255
ToolArrayBuilder.buildArray(_:)	swift.type.method	public	static func buildArray(_ components: [[any AnyJSONTool]]) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:282
ToolArrayBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: [any AnyJSONTool]...) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:262
ToolArrayBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: any AnyJSONTool...) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:257
ToolArrayBuilder.buildEither(first:)	swift.type.method	public	static func buildEither(first component: [any AnyJSONTool]) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:272
ToolArrayBuilder.buildEither(second:)	swift.type.method	public	static func buildEither(second component: [any AnyJSONTool]) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:277
ToolArrayBuilder.buildOptional(_:)	swift.type.method	public	static func buildOptional(_ component: [any AnyJSONTool]?) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:267
ToolArrayBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: [any AnyJSONTool]) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:297
ToolArrayBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: any AnyJSONTool) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:287
ToolArrayBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression<T>(_ expression: T) -> [any AnyJSONTool] where T : Tool	Sources/Swarm/Tools/ToolParameterBuilder.swift:292
ToolArrayBuilder.buildLimitedAvailability(_:)	swift.type.method	public	static func buildLimitedAvailability(_ component: [any AnyJSONTool]) -> [any AnyJSONTool]	Sources/Swarm/Tools/ToolParameterBuilder.swift:302
ToolChainBuilder	swift.struct	public	@resultBuilder struct ToolChainBuilder	Sources/Swarm/Tools/ToolChainBuilder.swift:38
ToolChainBuilder.buildArray(_:)	swift.type.method	public	static func buildArray(_ components: [[any ToolChainStep]]) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:70
ToolChainBuilder.buildBlock()	swift.type.method	public	static func buildBlock() -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:45
ToolChainBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ steps: [any ToolChainStep]...) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:50
ToolChainBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ steps: any ToolChainStep...) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:40
ToolChainBuilder.buildEither(first:)	swift.type.method	public	static func buildEither(first component: [any ToolChainStep]) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:60
ToolChainBuilder.buildEither(second:)	swift.type.method	public	static func buildEither(second component: [any ToolChainStep]) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:65
ToolChainBuilder.buildOptional(_:)	swift.type.method	public	static func buildOptional(_ component: [any ToolChainStep]?) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:55
ToolChainBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ tool: any AnyJSONTool) -> any ToolChainStep	Sources/Swarm/Tools/ToolChainBuilder.swift:75
ToolChainBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ step: any ToolChainStep) -> any ToolChainStep	Sources/Swarm/Tools/ToolChainBuilder.swift:85
ToolChainBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression<T>(_ tool: T) -> any ToolChainStep where T : Tool	Sources/Swarm/Tools/ToolChainBuilder.swift:80
ToolChainBuilder.buildFinalResult(_:)	swift.type.method	public	static func buildFinalResult(_ component: [any ToolChainStep]) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:95
ToolChainBuilder.buildLimitedAvailability(_:)	swift.type.method	public	static func buildLimitedAvailability(_ component: [any ToolChainStep]) -> [any ToolChainStep]	Sources/Swarm/Tools/ToolChainBuilder.swift:90
CompositeObserver	swift.struct	public	struct CompositeObserver	Sources/Swarm/Core/RunHooks.swift:246
CompositeObserver.onAgentEnd(context:agent:result:)	swift.method	public	func onAgentEnd(context: AgentContext?, agent: any AgentRuntime, result: AgentResult) async	Sources/Swarm/Core/RunHooks.swift:270
CompositeObserver.onLLMStart(context:agent:systemPrompt:inputMessages:)	swift.method	public	func onLLMStart(context: AgentContext?, agent: any AgentRuntime, systemPrompt: String?, inputMessages: [MemoryMessage]) async	Sources/Swarm/Core/RunHooks.swift:330
CompositeObserver.onThinking(context:agent:thought:)	swift.method	public	func onThinking(context: AgentContext?, agent: any AgentRuntime, thought: String) async	Sources/Swarm/Core/RunHooks.swift:360
CompositeObserver.onToolStart(context:agent:call:)	swift.method	public	func onToolStart(context: AgentContext?, agent: any AgentRuntime, call: ToolCall) async	Sources/Swarm/Core/RunHooks.swift:300
CompositeObserver.onAgentStart(context:agent:input:)	swift.method	public	func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async	Sources/Swarm/Core/RunHooks.swift:260
CompositeObserver.onOutputToken(context:agent:token:)	swift.method	public	func onOutputToken(context: AgentContext?, agent: any AgentRuntime, token: String) async	Sources/Swarm/Core/RunHooks.swift:380
CompositeObserver.onIterationEnd(context:agent:number:)	swift.method	public	func onIterationEnd(context: AgentContext?, agent: any AgentRuntime, number: Int) async	Sources/Swarm/Core/RunHooks.swift:400
CompositeObserver.onIterationStart(context:agent:number:)	swift.method	public	func onIterationStart(context: AgentContext?, agent: any AgentRuntime, number: Int) async	Sources/Swarm/Core/RunHooks.swift:390
CompositeObserver.onThinkingPartial(context:agent:partialThought:)	swift.method	public	func onThinkingPartial(context: AgentContext?, agent: any AgentRuntime, partialThought: String) async	Sources/Swarm/Core/RunHooks.swift:370
CompositeObserver.onToolCallPartial(context:agent:update:)	swift.method	public	func onToolCallPartial(context: AgentContext?, agent: any AgentRuntime, update: PartialToolCallUpdate) async	Sources/Swarm/Core/RunHooks.swift:310
CompositeObserver.onGuardrailTriggered(context:guardrailName:guardrailType:result:)	swift.method	public	func onGuardrailTriggered(context: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async	Sources/Swarm/Core/RunHooks.swift:350
CompositeObserver.onError(context:agent:error:)	swift.method	public	func onError(context: AgentContext?, agent: any AgentRuntime, error: any Error) async	Sources/Swarm/Core/RunHooks.swift:280
CompositeObserver.onLLMEnd(context:agent:response:usage:)	swift.method	public	func onLLMEnd(context: AgentContext?, agent: any AgentRuntime, response: String, usage: InferenceResponse.TokenUsage?) async	Sources/Swarm/Core/RunHooks.swift:340
CompositeObserver.init(observers:)	swift.init	public	init(observers: [any AgentObserver])	Sources/Swarm/Core/RunHooks.swift:254
CompositeObserver.onHandoff(context:fromAgent:toAgent:)	swift.method	public	func onHandoff(context: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async	Sources/Swarm/Core/RunHooks.swift:290
CompositeObserver.onToolEnd(context:agent:result:)	swift.method	public	func onToolEnd(context: AgentContext?, agent: any AgentRuntime, result: ToolResult) async	Sources/Swarm/Core/RunHooks.swift:320
ContextBucketCaps	swift.struct	public	struct ContextBucketCaps	Sources/Swarm/Core/ContextProfile.swift:473
ContextBucketCaps.memory	swift.property	public	let memory: Int	Sources/Swarm/Core/ContextProfile.swift:476
ContextBucketCaps.init(system:history:memory:toolIO:)	swift.init	public	init(system: Int, history: Int, memory: Int, toolIO: Int)	Sources/Swarm/Core/ContextProfile.swift:479
ContextBucketCaps.system	swift.property	public	let system: Int	Sources/Swarm/Core/ContextProfile.swift:474
ContextBucketCaps.toolIO	swift.property	public	let toolIO: Int	Sources/Swarm/Core/ContextProfile.swift:477
ContextBucketCaps.history	swift.property	public	let history: Int	Sources/Swarm/Core/ContextProfile.swift:475
EmbeddingProvider	swift.protocol	public	protocol EmbeddingProvider : Sendable	Sources/Swarm/Memory/EmbeddingProvider.swift:35
EmbeddingProvider.dimensions	swift.property	public	var dimensions: Int { get }	Sources/Swarm/Memory/EmbeddingProvider.swift:40
EmbeddingProvider.modelIdentifier	swift.property	public	var modelIdentifier: String { get }	Sources/Swarm/Memory/EmbeddingProvider.swift:43
EmbeddingProvider.embed(_:)	swift.method	public	func embed(_ texts: [String]) async throws -> [[Float]]	Sources/Swarm/Memory/EmbeddingProvider.swift:60
EmbeddingProvider.embed(_:)	swift.method	public	func embed(_ text: String) async throws -> [Float]	Sources/Swarm/Memory/EmbeddingProvider.swift:50
EmbeddingProvider.modelIdentifier	swift.property	public	var modelIdentifier: String { get }	Sources/Swarm/Memory/EmbeddingProvider.swift:67
EmbeddingProvider.embed(_:)	swift.method	public	func embed(_ texts: [String]) async throws -> [[Float]]	Sources/Swarm/Memory/EmbeddingProvider.swift:72
SwarmEmbeddingProviderAdapter.embed(_:)	swift.method	public	func embed(_ texts: [String]) async throws -> [[Float]]	Sources/Swarm/Memory/EmbeddingProvider.swift:72
HandoffsComponent	swift.struct	public	struct HandoffsComponent	Sources/Swarm/Agents/AgentBuilder.swift:253
HandoffsComponent.handoffs	swift.property	public	let handoffs: [AnyHandoffConfiguration]	Sources/Swarm/Agents/AgentBuilder.swift:255
HandoffsComponent.init(_:)	swift.init	public	init(_ handoffs: [AnyHandoffConfiguration])	Sources/Swarm/Agents/AgentBuilder.swift:260
HandoffsComponent.init(_:)	swift.init	public	init<each T>(_ configs: repeat HandoffConfiguration<each T>) where repeat each T : AgentRuntime	Sources/Swarm/Agents/AgentBuilder.swift:277
HandoffsComponent.init(_:)	swift.init	public	init(_ handoffs: AnyHandoffConfiguration...)	Sources/Swarm/Agents/AgentBuilder.swift:267
InferenceProvider	swift.protocol	public	protocol InferenceProvider : Sendable	Sources/Swarm/Core/AgentRuntime.swift:218
InferenceProvider.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Core/AgentRuntime.swift:241
InferenceProvider.stream(prompt:options:)	swift.method	public	func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Core/AgentRuntime.swift:232
InferenceProvider.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Core/AgentRuntime.swift:225
InferenceProvider.openRouter(key:model:)	swift.type.method	public	static func openRouter(key: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:181
LLM.openRouter(key:model:)	swift.type.method	public	static func openRouter(key: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:181
InferenceProvider.openRouter(apiKey:model:)	swift.type.method	public	static func openRouter(apiKey: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:177
LLM.openRouter(apiKey:model:)	swift.type.method	public	static func openRouter(apiKey: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:177
InferenceProvider.openAI(key:model:)	swift.type.method	public	static func openAI(key: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:165
LLM.openAI(key:model:)	swift.type.method	public	static func openAI(key: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:165
InferenceProvider.openAI(apiKey:model:)	swift.type.method	public	static func openAI(apiKey: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:161
LLM.openAI(apiKey:model:)	swift.type.method	public	static func openAI(apiKey: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:161
InferenceProvider.anthropic(key:model:)	swift.type.method	public	static func anthropic(key: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:173
LLM.anthropic(key:model:)	swift.type.method	public	static func anthropic(key: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:173
InferenceProvider.anthropic(apiKey:model:)	swift.type.method	public	static func anthropic(apiKey: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:169
LLM.anthropic(apiKey:model:)	swift.type.method	public	static func anthropic(apiKey: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:169
InferenceResponse	swift.struct	public	struct InferenceResponse	Sources/Swarm/Core/AgentRuntime.swift:429
InferenceResponse.TokenUsage	swift.struct	public	struct TokenUsage	Sources/Swarm/Core/AgentRuntime.swift:468
InferenceResponse.TokenUsage.init(inputTokens:outputTokens:)	swift.init	public	init(inputTokens: Int, outputTokens: Int)	Sources/Swarm/Core/AgentRuntime.swift:482
InferenceResponse.TokenUsage.inputTokens	swift.property	public	let inputTokens: Int	Sources/Swarm/Core/AgentRuntime.swift:470
InferenceResponse.TokenUsage.totalTokens	swift.property	public	var totalTokens: Int { get }	Sources/Swarm/Core/AgentRuntime.swift:476
InferenceResponse.TokenUsage.outputTokens	swift.property	public	let outputTokens: Int	Sources/Swarm/Core/AgentRuntime.swift:473
InferenceResponse.FinishReason	swift.enum	public	enum FinishReason	Sources/Swarm/Core/AgentRuntime.swift:431
InferenceResponse.FinishReason.contentFilter	swift.enum.case	public	case contentFilter	Sources/Swarm/Core/AgentRuntime.swift:439
InferenceResponse.FinishReason.init(rawValue:)	swift.init	public	init?(rawValue: String)	
InferenceResponse.FinishReason.toolCall	swift.enum.case	public	case toolCall	Sources/Swarm/Core/AgentRuntime.swift:435
InferenceResponse.FinishReason.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/Core/AgentRuntime.swift:441
InferenceResponse.FinishReason.completed	swift.enum.case	public	case completed	Sources/Swarm/Core/AgentRuntime.swift:433
InferenceResponse.FinishReason.maxTokens	swift.enum.case	public	case maxTokens	Sources/Swarm/Core/AgentRuntime.swift:437
InferenceResponse.finishReason	swift.property	public	let finishReason: InferenceResponse.FinishReason	Sources/Swarm/Core/AgentRuntime.swift:495
InferenceResponse.hasToolCalls	swift.property	public	var hasToolCalls: Bool { get }	Sources/Swarm/Core/AgentRuntime.swift:501
InferenceResponse.ParsedToolCall	swift.struct	public	struct ParsedToolCall	Sources/Swarm/Core/AgentRuntime.swift:445
InferenceResponse.ParsedToolCall.providerCallId	swift.property	public	var providerCallId: String? { get }	Sources/Swarm/Tools/ToolCallGoal.swift:32
InferenceResponse.ParsedToolCall.init(id:name:arguments:)	swift.init	public	init(id: String? = nil, name: String, arguments: [String : SendableValue])	Sources/Swarm/Core/AgentRuntime.swift:460
InferenceResponse.ParsedToolCall.id	swift.property	public	let id: String?	Sources/Swarm/Core/AgentRuntime.swift:447
InferenceResponse.ParsedToolCall.name	swift.property	public	let name: String	Sources/Swarm/Core/AgentRuntime.swift:450
InferenceResponse.ParsedToolCall.toolName	swift.property	public	var toolName: String { get }	Sources/Swarm/Tools/ToolCallGoal.swift:33
InferenceResponse.ParsedToolCall.arguments	swift.property	public	let arguments: [String : SendableValue]	Sources/Swarm/Core/AgentRuntime.swift:453
InferenceResponse.usage	swift.property	public	let usage: InferenceResponse.TokenUsage?	Sources/Swarm/Core/AgentRuntime.swift:498
InferenceResponse.init(content:toolCalls:finishReason:usage:)	swift.init	public	init(content: String? = nil, toolCalls: [InferenceResponse.ParsedToolCall] = [], finishReason: InferenceResponse.FinishReason = .completed, usage: InferenceResponse.TokenUsage? = nil)	Sources/Swarm/Core/AgentRuntime.swift:511
InferenceResponse.content	swift.property	public	let content: String?	Sources/Swarm/Core/AgentRuntime.swift:489
InferenceResponse.toolCalls	swift.property	public	let toolCalls: [InferenceResponse.ParsedToolCall]	Sources/Swarm/Core/AgentRuntime.swift:492
OpenRouterMessage	swift.struct	public	struct OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:103
OpenRouterMessage.toolCallId	swift.property	public	let toolCallId: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:116
OpenRouterMessage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterMessage.init(role:content:toolCalls:toolCallId:)	swift.init	public	init(role: String, content: OpenRouterMessageContent?, toolCalls: [OpenRouterToolCall]? = nil, toolCallId: String? = nil)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:119
OpenRouterMessage.role	swift.property	public	let role: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:107
OpenRouterMessage.tool(content:toolCallId:)	swift.type.method	public	static func tool(content: String, toolCallId: String) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:175
OpenRouterMessage.user(_:)	swift.type.method	public	static func user(_ content: String) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:142
OpenRouterMessage.user(_:)	swift.type.method	public	static func user(_ parts: [OpenRouterContentPart]) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:150
OpenRouterMessage.system(_:)	swift.type.method	public	static func system(_ content: String) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:134
OpenRouterMessage.content	swift.property	public	let content: OpenRouterMessageContent?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:110
OpenRouterMessage.assistant(toolCalls:)	swift.type.method	public	static func assistant(toolCalls: [OpenRouterToolCall]) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:166
OpenRouterMessage.assistant(_:)	swift.type.method	public	static func assistant(_ content: String) -> OpenRouterMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:158
OpenRouterMessage.toolCalls	swift.property	public	let toolCalls: [OpenRouterToolCall]?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:113
OpenRouterRequest	swift.struct	public	struct OpenRouterRequest	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:14
OpenRouterRequest.toolChoice	swift.property	public	let toolChoice: OpenRouterToolChoice?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:51
OpenRouterRequest.temperature	swift.property	public	let temperature: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:27
OpenRouterRequest.presencePenalty	swift.property	public	let presencePenalty: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:39
OpenRouterRequest.frequencyPenalty	swift.property	public	let frequencyPenalty: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:36
OpenRouterRequest.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterRequest.stop	swift.property	public	let stop: [String]?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:45
OpenRouterRequest.topK	swift.property	public	let topK: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:33
OpenRouterRequest.topP	swift.property	public	let topP: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:30
OpenRouterRequest.init(model:messages:stream:temperature:topP:topK:frequencyPenalty:presencePenalty:maxTokens:stop:tools:toolChoice:)	swift.init	public	init(model: String, messages: [OpenRouterMessage], stream: Bool? = nil, temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil, frequencyPenalty: Double? = nil, presencePenalty: Double? = nil, maxTokens: Int? = nil, stop: [String]? = nil, tools: [OpenRouterTool]? = nil, toolChoice: OpenRouterToolChoice? = nil)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:54
OpenRouterRequest.model	swift.property	public	let model: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:18
OpenRouterRequest.tools	swift.property	public	let tools: [OpenRouterTool]?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:48
OpenRouterRequest.stream	swift.property	public	let stream: Bool?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:24
OpenRouterRequest.messages	swift.property	public	let messages: [OpenRouterMessage]	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:21
OpenRouterRequest.maxTokens	swift.property	public	let maxTokens: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:42
OpenRouterRouting	swift.struct	public	struct OpenRouterRouting	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:10
OpenRouterRouting.DataCollection	swift.enum	public	enum DataCollection	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:28
OpenRouterRouting.DataCollection.deny	swift.enum.case	public	case deny	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:30
OpenRouterRouting.DataCollection.allow	swift.enum.case	public	case allow	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:29
OpenRouterRouting.DataCollection.init(rawValue:)	swift.init	public	init?(rawValue: String)	
OpenRouterRouting.dataCollection	swift.property	public	var dataCollection: OpenRouterRouting.DataCollection?	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:38
OpenRouterRouting.routeByLatency	swift.property	public	var routeByLatency: Bool	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:35
OpenRouterRouting.appName	swift.property	public	var appName: String?	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:37
OpenRouterRouting.siteURL	swift.property	public	var siteURL: URL?	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:36
OpenRouterRouting.Provider	swift.enum	public	enum Provider	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:11
OpenRouterRouting.Provider.perplexity	swift.enum.case	public	case perplexity	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:18
OpenRouterRouting.Provider.googleAIStudio	swift.enum.case	public	case googleAIStudio	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:15
OpenRouterRouting.Provider.ai21	swift.enum.case	public	case ai21	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:23
OpenRouterRouting.Provider.groq	swift.enum.case	public	case groq	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:20
OpenRouterRouting.Provider.azure	swift.enum.case	public	case azure	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:25
OpenRouterRouting.Provider.cohere	swift.enum.case	public	case cohere	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:22
OpenRouterRouting.Provider.google	swift.enum.case	public	case google	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:14
OpenRouterRouting.Provider.openai	swift.enum.case	public	case openai	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:12
OpenRouterRouting.Provider.bedrock	swift.enum.case	public	case bedrock	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:24
OpenRouterRouting.Provider.mistral	swift.enum.case	public	case mistral	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:19
OpenRouterRouting.Provider.deepseek	swift.enum.case	public	case deepseek	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:21
OpenRouterRouting.Provider.init(rawValue:)	swift.init	public	init?(rawValue: String)	
OpenRouterRouting.Provider.together	swift.enum.case	public	case together	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:16
OpenRouterRouting.Provider.anthropic	swift.enum.case	public	case anthropic	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:13
OpenRouterRouting.Provider.fireworks	swift.enum.case	public	case fireworks	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:17
OpenRouterRouting.fallbacks	swift.property	public	var fallbacks: Bool	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:34
OpenRouterRouting.init(providers:fallbacks:routeByLatency:siteURL:appName:dataCollection:)	swift.init	public	init(providers: [OpenRouterRouting.Provider]? = nil, fallbacks: Bool = true, routeByLatency: Bool = false, siteURL: URL? = nil, appName: String? = nil, dataCollection: OpenRouterRouting.DataCollection? = nil)	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:40
OpenRouterRouting.providers	swift.property	public	var providers: [OpenRouterRouting.Provider]?	Sources/Swarm/Providers/Conduit/OpenRouterRouting.swift:33
ParallelToolCalls	swift.struct	public	struct ParallelToolCalls	Sources/Swarm/Agents/AgentBuilder.swift:298
ParallelToolCalls.enabled	swift.property	public	let enabled: Bool	Sources/Swarm/Agents/AgentBuilder.swift:300
ParallelToolCalls.init(_:)	swift.init	public	init(_ enabled: Bool = true)	Sources/Swarm/Agents/AgentBuilder.swift:305
PersistentSession	swift.class	public	actor PersistentSession	Sources/Swarm/Memory/PersistentSession.swift:55
PersistentSession.clearSession()	swift.method	public	func clearSession() async throws	Sources/Swarm/Memory/PersistentSession.swift:221
PersistentSession.persistent(sessionId:)	swift.type.method	public	static func persistent(sessionId: String) throws -> PersistentSession	Sources/Swarm/Memory/PersistentSession.swift:125
PersistentSession.getItemCount()	swift.method	public	func getItemCount() async throws -> Int	Sources/Swarm/Memory/PersistentSession.swift:150
PersistentSession.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/PersistentSession.swift:94
PersistentSession.popItem()	swift.method	public	func popItem() async throws -> MemoryMessage?	Sources/Swarm/Memory/PersistentSession.swift:211
PersistentSession.addItems(_:)	swift.method	public	func addItems(_ items: [MemoryMessage]) async throws	Sources/Swarm/Memory/PersistentSession.swift:197
PersistentSession.getItems(limit:)	swift.method	public	func getItems(limit: Int?) async throws -> [MemoryMessage]	Sources/Swarm/Memory/PersistentSession.swift:175
PersistentSession.inMemory(sessionId:)	swift.type.method	public	static func inMemory(sessionId: String) throws -> PersistentSession	Sources/Swarm/Memory/PersistentSession.swift:138
PersistentSession.itemCount	swift.property	public	var itemCount: Int { get async }	Sources/Swarm/Memory/PersistentSession.swift:79
PersistentSession.init(sessionId:backend:)	swift.init	public	init(sessionId: String, backend: SwiftDataBackend)	Sources/Swarm/Memory/PersistentSession.swift:110
PersistentSession.sessionId	swift.property	public	nonisolated let sessionId: String	Sources/Swarm/Memory/PersistentSession.swift:62
RetrievalStrategy	swift.enum	public	enum RetrievalStrategy	Sources/Swarm/Memory/MemoryBuilder.swift:136
RetrievalStrategy.custom(_:)	swift.enum.case	public	case custom(([MemoryMessage], String) async -> [MemoryMessage])	Sources/Swarm/Memory/MemoryBuilder.swift:147
RetrievalStrategy.hybrid(recencyWeight:relevanceWeight:)	swift.enum.case	public	case hybrid(recencyWeight: Double, relevanceWeight: Double)	Sources/Swarm/Memory/MemoryBuilder.swift:144
RetrievalStrategy.recency	swift.enum.case	public	case recency	Sources/Swarm/Memory/MemoryBuilder.swift:138
RetrievalStrategy.relevance	swift.enum.case	public	case relevance	Sources/Swarm/Memory/MemoryBuilder.swift:141
ToolGuardrailData	swift.struct	public	struct ToolGuardrailData	Sources/Swarm/Guardrails/ToolGuardrails.swift:33
ToolGuardrailData.init(tool:arguments:agent:context:)	swift.init	public	init(tool: any AnyJSONTool, arguments: [String : SendableValue], agent: (any AgentRuntime)?, context: AgentContext?)	Sources/Swarm/Guardrails/ToolGuardrails.swift:55
ToolGuardrailData.tool	swift.property	public	let tool: any AnyJSONTool	Sources/Swarm/Guardrails/ToolGuardrails.swift:35
ToolGuardrailData.agent	swift.property	public	let agent: (any AgentRuntime)?	Sources/Swarm/Guardrails/ToolGuardrails.swift:41
ToolGuardrailData.context	swift.property	public	let context: AgentContext?	Sources/Swarm/Guardrails/ToolGuardrails.swift:44
ToolGuardrailData.arguments	swift.property	public	let arguments: [String : SendableValue]	Sources/Swarm/Guardrails/ToolGuardrails.swift:38
ToolRegistryError	swift.enum	public	enum ToolRegistryError	Sources/Swarm/Tools/Tool.swift:503
ToolRegistryError.duplicateToolName(name:)	swift.enum.case	public	case duplicateToolName(name: String)	Sources/Swarm/Tools/Tool.swift:505
TransformCallback	swift.typealias	public	typealias TransformCallback = (HandoffInputData) -> HandoffInputData	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:131
VectorMemoryError	swift.enum	public	enum VectorMemoryError	Sources/Swarm/Memory/VectorMemory.swift:470
VectorMemoryError.description	swift.property	public	var description: String { get }	Sources/Swarm/Memory/VectorMemory.swift:473
VectorMemoryError.searchFailed(underlying:)	swift.enum.case	public	case searchFailed(underlying: any Error)	Sources/Swarm/Memory/VectorMemory.swift:486
VectorMemoryError.missingEmbeddingProvider	swift.enum.case	public	case missingEmbeddingProvider	Sources/Swarm/Memory/VectorMemory.swift:483
AgentConfiguration	swift.struct	public	struct AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:123
AgentConfiguration.contextMode	swift.property	public	var contextMode: ContextMode	Sources/Swarm/Core/AgentConfiguration.swift:186
AgentConfiguration.contextMode(_:)	swift.method	public	@discardableResult func contextMode(_ value: ContextMode) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentConfiguration.swift:361
AgentConfiguration.temperature	swift.property	public	var temperature: Double	Sources/Swarm/Core/AgentConfiguration.swift:149
AgentConfiguration.temperature(_:)	swift.method	public	@discardableResult func temperature(_ value: Double) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.maxIterations	swift.property	public	var maxIterations: Int	Sources/Swarm/Core/AgentConfiguration.swift:139
AgentConfiguration.maxIterations(_:)	swift.method	public	@discardableResult func maxIterations(_ value: Int) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.modelSettings	swift.property	public	var modelSettings: ModelSettings?	Sources/Swarm/Core/AgentConfiguration.swift:173
AgentConfiguration.modelSettings(_:)	swift.method	public	@discardableResult func modelSettings(_ value: ModelSettings?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.stopSequences	swift.property	public	var stopSequences: [String]	Sources/Swarm/Core/AgentConfiguration.swift:157
AgentConfiguration.stopSequences(_:)	swift.method	public	@discardableResult func stopSequences(_ value: [String]) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.contextProfile	swift.property	public	var contextProfile: ContextProfile	Sources/Swarm/Core/AgentConfiguration.swift:180
AgentConfiguration.contextProfile(_:)	swift.method	public	@discardableResult func contextProfile(_ value: ContextProfile) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.enableStreaming	swift.property	public	var enableStreaming: Bool	Sources/Swarm/Core/AgentConfiguration.swift:207
AgentConfiguration.enableStreaming(_:)	swift.method	public	@discardableResult func enableStreaming(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.inferencePolicy	swift.property	public	var inferencePolicy: InferencePolicy?	Sources/Swarm/Core/AgentConfiguration.swift:201
AgentConfiguration.inferencePolicy(_:)	swift.method	public	@discardableResult func inferencePolicy(_ value: InferencePolicy?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.stopOnToolError	swift.property	public	var stopOnToolError: Bool	Sources/Swarm/Core/AgentConfiguration.swift:215
AgentConfiguration.stopOnToolError(_:)	swift.method	public	@discardableResult func stopOnToolError(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.includeReasoning	swift.property	public	var includeReasoning: Bool	Sources/Swarm/Core/AgentConfiguration.swift:219
AgentConfiguration.includeReasoning(_:)	swift.method	public	@discardableResult func includeReasoning(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.inferenceOptions	swift.property	public	var inferenceOptions: InferenceOptions { get }	Sources/Swarm/Core/AgentConfiguration+InferenceOptions.swift:22
AgentConfiguration.parallelToolCalls	swift.property	public	var parallelToolCalls: Bool	Sources/Swarm/Core/AgentConfiguration.swift:249
AgentConfiguration.parallelToolCalls(_:)	swift.method	public	@discardableResult func parallelToolCalls(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.previousResponseId	swift.property	public	var previousResponseId: String?	Sources/Swarm/Core/AgentConfiguration.swift:259
AgentConfiguration.previousResponseId(_:)	swift.method	public	@discardableResult func previousResponseId(_ value: String?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.sessionHistoryLimit	swift.property	public	var sessionHistoryLimit: Int?	Sources/Swarm/Core/AgentConfiguration.swift:229
AgentConfiguration.sessionHistoryLimit(_:)	swift.method	public	@discardableResult func sessionHistoryLimit(_ value: Int?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.defaultTracingEnabled	swift.property	public	var defaultTracingEnabled: Bool	Sources/Swarm/Core/AgentConfiguration.swift:278
AgentConfiguration.defaultTracingEnabled(_:)	swift.method	public	@discardableResult func defaultTracingEnabled(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.autoPreviousResponseId	swift.property	public	var autoPreviousResponseId: Bool	Sources/Swarm/Core/AgentConfiguration.swift:267
AgentConfiguration.autoPreviousResponseId(_:)	swift.method	public	@discardableResult func autoPreviousResponseId(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.hiveRunOptionsOverride	swift.property	public	var hiveRunOptionsOverride: SwarmHiveRunOptionsOverride?	Sources/Swarm/Core/AgentConfiguration.swift:193
AgentConfiguration.hiveRunOptionsOverride(_:)	swift.method	public	@discardableResult func hiveRunOptionsOverride(_ value: SwarmHiveRunOptionsOverride?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.includeToolCallDetails	swift.property	public	var includeToolCallDetails: Bool	Sources/Swarm/Core/AgentConfiguration.swift:211
AgentConfiguration.includeToolCallDetails(_:)	swift.method	public	@discardableResult func includeToolCallDetails(_ value: Bool) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.effectiveContextProfile	swift.property	public	var effectiveContextProfile: ContextProfile { get }	Sources/Swarm/Core/AgentConfiguration+InferenceOptions.swift:10
AgentConfiguration.init(name:maxIterations:timeout:temperature:maxTokens:stopSequences:modelSettings:contextProfile:hiveRunOptionsOverride:inferencePolicy:enableStreaming:includeToolCallDetails:stopOnToolError:includeReasoning:sessionHistoryLimit:contextMode:parallelToolCalls:previousResponseId:autoPreviousResponseId:defaultTracingEnabled:)	swift.init	public	init(name: String = "Agent", maxIterations: Int = 10, timeout: Duration = .seconds(60), temperature: Double = 1.0, maxTokens: Int? = nil, stopSequences: [String] = [], modelSettings: ModelSettings? = nil, contextProfile: ContextProfile = .platformDefault, hiveRunOptionsOverride: SwarmHiveRunOptionsOverride? = nil, inferencePolicy: InferencePolicy? = nil, enableStreaming: Bool = true, includeToolCallDetails: Bool = true, stopOnToolError: Bool = false, includeReasoning: Bool = true, sessionHistoryLimit: Int? = 50, contextMode: ContextMode = .adaptive, parallelToolCalls: Bool = false, previousResponseId: String? = nil, autoPreviousResponseId: Bool = false, defaultTracingEnabled: Bool = true)	Sources/Swarm/Core/AgentConfiguration.swift:304
AgentConfiguration.name	swift.property	public	var name: String	Sources/Swarm/Core/AgentConfiguration.swift:133
AgentConfiguration.name(_:)	swift.method	public	@discardableResult func name(_ value: String) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.default	swift.type.property	public	static let `default`: AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:127
AgentConfiguration.timeout	swift.property	public	var timeout: Duration	Sources/Swarm/Core/AgentConfiguration.swift:143
AgentConfiguration.timeout(_:)	swift.method	public	@discardableResult func timeout(_ value: Duration) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AgentConfiguration.maxTokens	swift.property	public	var maxTokens: Int?	Sources/Swarm/Core/AgentConfiguration.swift:153
AgentConfiguration.maxTokens(_:)	swift.method	public	@discardableResult func maxTokens(_ value: Int?) -> AgentConfiguration	Sources/Swarm/Core/AgentConfiguration.swift:122
AnyJSONToolAdapter	swift.struct	public	struct AnyJSONToolAdapter<T> where T : Tool	Sources/Swarm/Tools/ToolBridging.swift:11
AnyJSONToolAdapter.parameters	swift.property	public	var parameters: [ToolParameter] { get }	Sources/Swarm/Tools/ToolBridging.swift:18
AnyJSONToolAdapter.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/ToolBridging.swift:17
AnyJSONToolAdapter.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/ToolBridging.swift:19
AnyJSONToolAdapter.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/ToolBridging.swift:20
AnyJSONToolAdapter.name	swift.property	public	var name: String { get }	Sources/Swarm/Tools/ToolBridging.swift:16
AnyJSONToolAdapter.tool	swift.property	public	let tool: T	Sources/Swarm/Tools/ToolBridging.swift:14
AnyJSONToolAdapter.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/ToolBridging.swift:26
AnyJSONToolAdapter.init(_:)	swift.init	public	init(_ tool: T)	Sources/Swarm/Tools/ToolBridging.swift:22
ConversationMemory	swift.class	public	actor ConversationMemory	Sources/Swarm/Memory/ConversationMemory.swift:29
ConversationMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/ConversationMemory.swift:70
ConversationMemory.diagnostics()	swift.method	public	func diagnostics() async -> ConversationMemoryDiagnostics	Sources/Swarm/Memory/ConversationMemory.swift:155
ConversationMemory.lastMessage	swift.property	public	var lastMessage: MemoryMessage? { get }	Sources/Swarm/Memory/ConversationMemory.swift:125
ConversationMemory.init(maxMessages:tokenEstimator:)	swift.init	public	init(maxMessages: Int = 100, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/ConversationMemory.swift:47
ConversationMemory.maxMessages	swift.property	public	let maxMessages: Int	Sources/Swarm/Memory/ConversationMemory.swift:33
ConversationMemory.firstMessage	swift.property	public	var firstMessage: MemoryMessage? { get }	Sources/Swarm/Memory/ConversationMemory.swift:130
ConversationMemory.withTokenLimit(_:)	swift.method	public	nonisolated func withTokenLimit(_: Int) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:476
ConversationMemory.getOldestMessages(_:)	swift.method	public	func getOldestMessages(_ n: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/ConversationMemory.swift:116
ConversationMemory.getRecentMessages(_:)	swift.method	public	func getRecentMessages(_ n: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/ConversationMemory.swift:108
ConversationMemory.withSummarization(after:)	swift.method	public	nonisolated func withSummarization(after _: Int) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:466
ConversationMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/ConversationMemory.swift:57
ConversationMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/ConversationMemory.swift:74
ConversationMemory.count	swift.property	public	var count: Int { get }	Sources/Swarm/Memory/ConversationMemory.swift:35
ConversationMemory.addAll(_:)	swift.method	public	func addAll(_ newMessages: [MemoryMessage]) async	Sources/Swarm/Memory/ConversationMemory.swift:96
ConversationMemory.filter(_:)	swift.method	public	func filter(_ predicate: (MemoryMessage) -> Bool) async -> [MemoryMessage]	Sources/Swarm/Memory/ConversationMemory.swift:138
ConversationMemory.context(for:tokenLimit:)	swift.method	public	func context(for _: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/ConversationMemory.swift:66
ConversationMemory.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Memory/ConversationMemory.swift:40
ConversationMemory.messages(withRole:)	swift.method	public	func messages(withRole role: MemoryMessage.Role) async -> [MemoryMessage]	Sources/Swarm/Memory/ConversationMemory.swift:146
ConversationMemory.priority(_:)	swift.method	public	nonisolated func priority(_ priority: MemoryPriority) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:484
FallbackSummarizer	swift.struct	public	struct FallbackSummarizer	Sources/Swarm/Memory/Summarizer.swift:201
FallbackSummarizer.isAvailable	swift.property	public	var isAvailable: Bool { get async }	Sources/Swarm/Memory/Summarizer.swift:204
FallbackSummarizer.init(primary:fallback:)	swift.init	public	init(primary: any Summarizer, fallback: any Summarizer = TruncatingSummarizer.shared)	Sources/Swarm/Memory/Summarizer.swift:217
FallbackSummarizer.summarize(_:maxTokens:)	swift.method	public	func summarize(_ text: String, maxTokens: Int) async throws -> String	Sources/Swarm/Memory/Summarizer.swift:222
HandoffCoordinator	swift.class	public	actor HandoffCoordinator	Sources/Swarm/Core/Handoff/Handoff.swift:251
HandoffCoordinator.executeHandoff(_:context:configuration:observer:)	swift.method	public	func executeHandoff(_ request: HandoffRequest, context: AgentContext, configuration: AnyHandoffConfiguration?, observer: (any AgentObserver)?) async throws -> HandoffResult	Sources/Swarm/Core/Handoff/Handoff.swift:399
HandoffCoordinator.executeHandoff(_:context:)	swift.method	public	func executeHandoff(_ request: HandoffRequest, context: AgentContext) async throws -> HandoffResult	Sources/Swarm/Core/Handoff/Handoff.swift:321
HandoffCoordinator.unregister(_:)	swift.method	public	func unregister(_ name: String)	Sources/Swarm/Core/Handoff/Handoff.swift:283
HandoffCoordinator.registeredAgents	swift.property	public	var registeredAgents: [String] { get }	Sources/Swarm/Core/Handoff/Handoff.swift:257
HandoffCoordinator.agent(named:)	swift.method	public	func agent(named name: String) -> (any AgentRuntime)?	Sources/Swarm/Core/Handoff/Handoff.swift:291
HandoffCoordinator.register(_:as:)	swift.method	public	func register(_ agent: any AgentRuntime, as name: String)	Sources/Swarm/Core/Handoff/Handoff.swift:276
HandoffCoordinator.init()	swift.init	public	init()	Sources/Swarm/Core/Handoff/Handoff.swift:264
HandoffMetadataKey	swift.struct	public	struct HandoffMetadataKey<Value> where Value : Sendable	Sources/Swarm/Core/Handoff/HandoffOptions.swift:56
HandoffMetadataKey.rawValue	swift.property	public	let rawValue: String	Sources/Swarm/Core/Handoff/HandoffOptions.swift:57
HandoffMetadataKey.string(_:)	swift.type.method	public	static func string(_ rawValue: String) -> HandoffMetadataKey<Value>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:73
HandoffMetadataKey.bool(_:)	swift.type.method	public	static func bool(_ rawValue: String) -> HandoffMetadataKey<Value>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:93
HandoffMetadataKey.int(_:)	swift.type.method	public	static func int(_ rawValue: String) -> HandoffMetadataKey<Value>	Sources/Swarm/Core/Handoff/HandoffOptions.swift:83
HandoffMetadataKey.init(_:encode:decode:)	swift.init	public	init(_ rawValue: String, encode: @escaping (Value) -> SendableValue, decode: @escaping (SendableValue) -> Value?)	Sources/Swarm/Core/Handoff/HandoffOptions.swift:61
MCPClientComponent	swift.struct	public	struct MCPClientComponent	Sources/Swarm/Agents/AgentBuilder.swift:408
MCPClientComponent.client	swift.property	public	let client: MCPClient	Sources/Swarm/Agents/AgentBuilder.swift:410
MCPClientComponent.init(_:)	swift.init	public	init(_ client: MCPClient)	Sources/Swarm/Agents/AgentBuilder.swift:415
MCPResourceContent	swift.struct	public	struct MCPResourceContent	Sources/Swarm/MCP/MCPResource.swift:92
MCPResourceContent.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/MCP/MCPResource.swift:162
MCPResourceContent.init(uri:mimeType:text:blob:)	swift.init	public	init(uri: String, mimeType: String? = nil, text: String? = nil, blob: String? = nil)	Sources/Swarm/MCP/MCPResource.swift:133
MCPResourceContent.uri	swift.property	public	let uri: String	Sources/Swarm/MCP/MCPResource.swift:94
MCPResourceContent.blob	swift.property	public	let blob: String?	Sources/Swarm/MCP/MCPResource.swift:110
MCPResourceContent.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MCPResourceContent.text	swift.property	public	let text: String?	Sources/Swarm/MCP/MCPResource.swift:104
MCPResourceContent.isText	swift.property	public	var isText: Bool { get }	Sources/Swarm/MCP/MCPResource.swift:115
MCPResourceContent.isBinary	swift.property	public	var isBinary: Bool { get }	Sources/Swarm/MCP/MCPResource.swift:122
MCPResourceContent.mimeType	swift.property	public	let mimeType: String?	Sources/Swarm/MCP/MCPResource.swift:99
MemoryPriorityHint	swift.enum	public	enum MemoryPriorityHint	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:9
MemoryPriorityHint.primary	swift.enum.case	public	case primary	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:10
MemoryPriorityHint.secondary	swift.enum.case	public	case secondary	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:11
MergeErrorStrategy	swift.enum	public	enum MergeErrorStrategy	Sources/Swarm/Core/StreamOperations.swift:817
MergeErrorStrategy.ignoreErrors	swift.enum.case	public	case ignoreErrors	Sources/Swarm/Core/StreamOperations.swift:827
MergeErrorStrategy.continueAndCollect	swift.enum.case	public	case continueAndCollect	Sources/Swarm/Core/StreamOperations.swift:823
MergeErrorStrategy.failFast	swift.enum.case	public	case failFast	Sources/Swarm/Core/StreamOperations.swift:819
MultiProviderError	swift.enum	public	enum MultiProviderError	Sources/Swarm/Providers/MultiProvider.swift:11
MultiProviderError.emptyPrefix	swift.enum.case	public	case emptyPrefix	Sources/Swarm/Providers/MultiProvider.swift:26
MultiProviderError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Providers/MultiProvider.swift:14
MultiProviderError.providerNotFound(prefix:)	swift.enum.case	public	case providerNotFound(prefix: String)	Sources/Swarm/Providers/MultiProvider.swift:29
MultiProviderError.invalidModelFormat(model:)	swift.enum.case	public	case invalidModelFormat(model: String)	Sources/Swarm/Providers/MultiProvider.swift:32
OnTransferCallback	swift.typealias	public	typealias OnTransferCallback = (AgentContext, HandoffInputData) async throws -> Void	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:111
OpenRouterProvider	swift.class	public	actor OpenRouterProvider	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:30
OpenRouterProvider.description	swift.property	public	nonisolated var description: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:787
OpenRouterProvider.init(configuration:)	swift.init	public	init(configuration: OpenRouterConfiguration)	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:37
OpenRouterProvider.streamWithToolCalls(prompt:tools:options:)	swift.method	public	nonisolated func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamEvent, any Error>	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:165
OpenRouterProvider.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:199
OpenRouterProvider.init(apiKey:model:)	swift.init	public	convenience init(apiKey: String, model: OpenRouterModel = .gpt4o) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:56
OpenRouterProvider.stream(prompt:options:)	swift.method	public	nonisolated func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:141
OpenRouterProvider.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:68
OpenRouterResponse	swift.struct	public	struct OpenRouterResponse	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:466
OpenRouterResponse.init(id:created:model:choices:usage:)	swift.init	public	init(id: String, created: Int, model: String, choices: [OpenRouterChoice], usage: OpenRouterUsage?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:483
OpenRouterResponse.id	swift.property	public	let id: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:468
OpenRouterResponse.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterResponse.model	swift.property	public	let model: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:474
OpenRouterResponse.usage	swift.property	public	let usage: OpenRouterUsage?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:480
OpenRouterResponse.choices	swift.property	public	let choices: [OpenRouterChoice]	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:477
OpenRouterResponse.created	swift.property	public	let created: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:471
OpenRouterToolCall	swift.struct	public	struct OpenRouterToolCall	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:571
OpenRouterToolCall.init(id:type:function:)	swift.init	public	init(id: String, type: String = "function", function: OpenRouterFunctionCall)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:582
OpenRouterToolCall.id	swift.property	public	let id: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:573
OpenRouterToolCall.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterToolCall.type	swift.property	public	let type: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:576
OpenRouterToolCall.function	swift.property	public	let function: OpenRouterFunctionCall	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:579
PerformanceMetrics	swift.struct	public	struct PerformanceMetrics	Sources/Swarm/Observability/PerformanceMetrics.swift:46
PerformanceMetrics.description	swift.property	public	var description: String { get }	Sources/Swarm/Observability/PerformanceMetrics.swift:364
PerformanceMetrics.llmDuration	swift.property	public	let llmDuration: Duration	Sources/Swarm/Observability/PerformanceMetrics.swift:57
PerformanceMetrics.toolDuration	swift.property	public	let toolDuration: Duration	Sources/Swarm/Observability/PerformanceMetrics.swift:63
PerformanceMetrics.init(totalDuration:llmDuration:toolDuration:toolCount:usedParallelExecution:estimatedSequentialDuration:)	swift.init	public	init(totalDuration: Duration, llmDuration: Duration, toolDuration: Duration, toolCount: Int, usedParallelExecution: Bool, estimatedSequentialDuration: Duration? = nil)	Sources/Swarm/Observability/PerformanceMetrics.swift:136
PerformanceMetrics.totalDuration	swift.property	public	let totalDuration: Duration	Sources/Swarm/Observability/PerformanceMetrics.swift:51
PerformanceMetrics.parallelSpeedup	swift.property	public	var parallelSpeedup: Double? { get }	Sources/Swarm/Observability/PerformanceMetrics.swift:108
PerformanceMetrics.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Observability/PerformanceMetrics.swift:391
PerformanceMetrics.usedParallelExecution	swift.property	public	let usedParallelExecution: Bool	Sources/Swarm/Observability/PerformanceMetrics.swift:75
PerformanceMetrics.estimatedSequentialDuration	swift.property	public	let estimatedSequentialDuration: Duration?	Sources/Swarm/Observability/PerformanceMetrics.swift:84
PerformanceMetrics.toolCount	swift.property	public	let toolCount: Int	Sources/Swarm/Observability/PerformanceMetrics.swift:69
PerformanceTracker	swift.class	public	actor PerformanceTracker	Sources/Swarm/Observability/PerformanceMetrics.swift:202
PerformanceTracker.recordLLMCall(duration:)	swift.method	public	func recordLLMCall(duration: Duration)	Sources/Swarm/Observability/PerformanceMetrics.swift:242
PerformanceTracker.recordToolExecution(duration:wasParallel:count:)	swift.method	public	func recordToolExecution(duration: Duration, wasParallel: Bool, count: Int = 1)	Sources/Swarm/Observability/PerformanceMetrics.swift:265
PerformanceTracker.recordSequentialEstimate(_:)	swift.method	public	func recordSequentialEstimate(_ duration: Duration)	Sources/Swarm/Observability/PerformanceMetrics.swift:284
PerformanceTracker.reset()	swift.method	public	func reset()	Sources/Swarm/Observability/PerformanceMetrics.swift:329
PerformanceTracker.start()	swift.method	public	func start()	Sources/Swarm/Observability/PerformanceMetrics.swift:226
PerformanceTracker.finish()	swift.method	public	func finish() -> PerformanceMetrics	Sources/Swarm/Observability/PerformanceMetrics.swift:302
PerformanceTracker.init()	swift.init	public	init()	Sources/Swarm/Observability/PerformanceMetrics.swift:210
PreviousResponseId	swift.struct	public	struct PreviousResponseId	Sources/Swarm/Agents/AgentBuilder.swift:324
PreviousResponseId.responseId	swift.property	public	let responseId: String?	Sources/Swarm/Agents/AgentBuilder.swift:326
PreviousResponseId.init(_:)	swift.init	public	init(_ responseId: String?)	Sources/Swarm/Agents/AgentBuilder.swift:331
ToolInputGuardrail	swift.protocol	public	protocol ToolInputGuardrail : Sendable	Sources/Swarm/Guardrails/ToolGuardrails.swift:93
ToolInputGuardrail.name	swift.property	public	var name: String { get }	Sources/Swarm/Guardrails/ToolGuardrails.swift:95
ToolInputGuardrail.validate(_:)	swift.method	public	func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:102
TruncationStrategy	swift.enum	public	enum TruncationStrategy	Sources/Swarm/Core/ModelSettings.swift:492
TruncationStrategy.auto	swift.enum.case	public	case auto	Sources/Swarm/Core/ModelSettings.swift:494
TruncationStrategy.disabled	swift.enum.case	public	case disabled	Sources/Swarm/Core/ModelSettings.swift:497
TruncationStrategy.init(rawValue:)	swift.init	public	init?(rawValue: String)	
JSONMetricsReporter	swift.struct	public	struct JSONMetricsReporter	Sources/Swarm/Observability/MetricsCollector.swift:469
JSONMetricsReporter.jsonString(from:)	swift.method	public	func jsonString(from snapshot: MetricsSnapshot) throws -> String	Sources/Swarm/Observability/MetricsCollector.swift:537
JSONMetricsReporter.init(outputPath:prettyPrint:)	swift.init	public	init(outputPath: String? = nil, prettyPrint: Bool = true)	Sources/Swarm/Observability/MetricsCollector.swift:481
JSONMetricsReporter.outputPath	swift.property	public	let outputPath: String?	Sources/Swarm/Observability/MetricsCollector.swift:471
JSONMetricsReporter.prettyPrint	swift.property	public	let prettyPrint: Bool	Sources/Swarm/Observability/MetricsCollector.swift:474
JSONMetricsReporter.report(_:)	swift.method	public	func report(_ snapshot: MetricsSnapshot) async throws	Sources/Swarm/Observability/MetricsCollector.swift:490
JSONMetricsReporter.jsonData(from:)	swift.method	public	func jsonData(from snapshot: MetricsSnapshot) throws -> Data	Sources/Swarm/Observability/MetricsCollector.swift:519
MembraneEnvironment	swift.struct	public	struct MembraneEnvironment	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:44
MembraneEnvironment.configuration	swift.property	public	var configuration: MembraneFeatureConfiguration	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:46
MembraneEnvironment.adapter	swift.property	public	var adapter: (any MembraneAgentAdapter)?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:47
MembraneEnvironment.enabled	swift.type.property	public	static let enabled: MembraneEnvironment	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:60
MembraneEnvironment.disabled	swift.type.property	public	static let disabled: MembraneEnvironment	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:59
MembraneEnvironment.init(isEnabled:configuration:adapter:)	swift.init	public	init(isEnabled: Bool = true, configuration: MembraneFeatureConfiguration = .default, adapter: (any MembraneAgentAdapter)? = nil)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:49
MembraneEnvironment.isEnabled	swift.property	public	var isEnabled: Bool	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:45
MemoryMergeStrategy	swift.enum	public	enum MemoryMergeStrategy	Sources/Swarm/Memory/MemoryBuilder.swift:153
MemoryMergeStrategy.interleave	swift.enum.case	public	case interleave	Sources/Swarm/Memory/MemoryBuilder.swift:158
MemoryMergeStrategy.concatenate	swift.enum.case	public	case concatenate	Sources/Swarm/Memory/MemoryBuilder.swift:155
MemoryMergeStrategy.deduplicate	swift.enum.case	public	case deduplicate	Sources/Swarm/Memory/MemoryBuilder.swift:161
MemoryMergeStrategy.primaryOnly	swift.enum.case	public	case primaryOnly	Sources/Swarm/Memory/MemoryBuilder.swift:164
MemoryMergeStrategy.custom(_:)	swift.enum.case	public	case custom(([[MemoryMessage]]) -> [MemoryMessage])	Sources/Swarm/Memory/MemoryBuilder.swift:167
PrettyConsoleTracer	swift.class	public	actor PrettyConsoleTracer	Sources/Swarm/Observability/ConsoleTracer.swift:276
PrettyConsoleTracer.init(minimumLevel:colorized:includeTimestamp:includeSource:)	swift.init	public	init(minimumLevel: EventLevel = .trace, colorized: Bool = true, includeTimestamp: Bool = true, includeSource: Bool = false)	Sources/Swarm/Observability/ConsoleTracer.swift:286
PrettyConsoleTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/ConsoleTracer.swift:302
SlidingWindowMemory	swift.class	public	actor SlidingWindowMemory	Sources/Swarm/Memory/SlidingWindowMemory.swift:29
SlidingWindowMemory.tokenCount	swift.property	public	var tokenCount: Int { get }	Sources/Swarm/Memory/SlidingWindowMemory.swift:45
SlidingWindowMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/SlidingWindowMemory.swift:100
SlidingWindowMemory.diagnostics()	swift.method	public	func diagnostics() async -> SlidingWindowDiagnostics	Sources/Swarm/Memory/SlidingWindowMemory.swift:175
SlidingWindowMemory.getMessages(withinTokenBudget:)	swift.method	public	func getMessages(withinTokenBudget tokenBudget: Int) async -> [MemoryMessage]	Sources/Swarm/Memory/SlidingWindowMemory.swift:153
SlidingWindowMemory.isNearCapacity	swift.property	public	var isNearCapacity: Bool { get }	Sources/Swarm/Memory/SlidingWindowMemory.swift:55
SlidingWindowMemory.remainingTokens	swift.property	public	var remainingTokens: Int { get }	Sources/Swarm/Memory/SlidingWindowMemory.swift:50
SlidingWindowMemory.withOverlapSize(_:)	swift.method	public	nonisolated func withOverlapSize(_: Int) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:496
SlidingWindowMemory.recalculateTokenCount()	swift.method	public	func recalculateTokenCount() async	Sources/Swarm/Memory/SlidingWindowMemory.swift:212
SlidingWindowMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/SlidingWindowMemory.swift:74
SlidingWindowMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/SlidingWindowMemory.swift:104
SlidingWindowMemory.count	swift.property	public	var count: Int { get }	Sources/Swarm/Memory/SlidingWindowMemory.swift:35
SlidingWindowMemory.addAll(_:)	swift.method	public	func addAll(_ newMessages: [MemoryMessage]) async	Sources/Swarm/Memory/SlidingWindowMemory.swift:143
SlidingWindowMemory.context(for:tokenLimit:)	swift.method	public	func context(for _: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/SlidingWindowMemory.swift:95
SlidingWindowMemory.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Memory/SlidingWindowMemory.swift:40
SlidingWindowMemory.priority(_:)	swift.method	public	nonisolated func priority(_ priority: MemoryPriority) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:504
SlidingWindowMemory.init(maxTokens:tokenEstimator:)	swift.init	public	init(maxTokens: Int = 4000, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/SlidingWindowMemory.swift:64
SlidingWindowMemory.maxTokens	swift.property	public	let maxTokens: Int	Sources/Swarm/Memory/SlidingWindowMemory.swift:33
ToolExecutionEngine	swift.struct	public	struct ToolExecutionEngine	Sources/Swarm/Tools/ToolExecutionEngine.swift:15
ToolExecutionEngine.Outcome	swift.struct	public	struct Outcome	Sources/Swarm/Tools/ToolExecutionEngine.swift:18
ToolExecutionEngine.Outcome.call	swift.property	public	let call: ToolCall	Sources/Swarm/Tools/ToolExecutionEngine.swift:19
ToolExecutionEngine.Outcome.result	swift.property	public	let result: ToolResult	Sources/Swarm/Tools/ToolExecutionEngine.swift:20
ToolExecutionEngine.execute(toolName:arguments:providerCallId:registry:agent:context:resultBuilder:observer:tracing:stopOnToolError:)	swift.method	public	func execute(toolName: String, arguments: [String : SendableValue], providerCallId: String? = nil, registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext?, resultBuilder: AgentResult.Builder, observer: (any AgentObserver)?, tracing: TracingHelper?, stopOnToolError: Bool) async throws -> ToolExecutionEngine.Outcome	Sources/Swarm/Tools/ToolExecutionEngine.swift:23
ToolExecutionEngine.execute(_:registry:agent:context:resultBuilder:observer:tracing:stopOnToolError:)	swift.method	public	func execute(_ goal: some ToolCallGoal, registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext?, resultBuilder: AgentResult.Builder, observer: (any AgentObserver)?, tracing: TracingHelper?, stopOnToolError: Bool) async throws -> ToolExecutionEngine.Outcome	Sources/Swarm/Tools/ToolCallGoal.swift:40
ToolExecutionEngine.init()	swift.init	public	init()	Sources/Swarm/Tools/ToolExecutionEngine.swift:16
ToolExecutionResult	swift.struct	public	struct ToolExecutionResult	Sources/Swarm/Tools/ToolExecutionResult.swift:86
ToolExecutionResult.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/ToolExecutionResult.swift:216
ToolExecutionResult.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Tools/ToolExecutionResult.swift:237
ToolExecutionResult.==(_:_:)	swift.func.op	public	static func == (lhs: ToolExecutionResult, rhs: ToolExecutionResult) -> Bool	Sources/Swarm/Tools/ToolExecutionResult.swift:256
ToolExecutionResult.error	swift.property	public	var error: (any Error)? { get }	Sources/Swarm/Tools/ToolExecutionResult.swift:129
ToolExecutionResult.value	swift.property	public	var value: SendableValue? { get }	Sources/Swarm/Tools/ToolExecutionResult.swift:119
ToolExecutionResult.result	swift.property	public	let result: Result<SendableValue, any Error>	Sources/Swarm/Tools/ToolExecutionResult.swift:97
ToolExecutionResult.failure(toolName:arguments:error:duration:timestamp:)	swift.type.method	public	static func failure(toolName: String, arguments: [String : SendableValue], error: any Error, duration: Duration, timestamp: Date = Date()) -> ToolExecutionResult	Sources/Swarm/Tools/ToolExecutionResult.swift:196
ToolExecutionResult.success(toolName:arguments:value:duration:timestamp:)	swift.type.method	public	static func success(toolName: String, arguments: [String : SendableValue], value: SendableValue, duration: Duration, timestamp: Date = Date()) -> ToolExecutionResult	Sources/Swarm/Tools/ToolExecutionResult.swift:171
ToolExecutionResult.duration	swift.property	public	let duration: Duration	Sources/Swarm/Tools/ToolExecutionResult.swift:103
ToolExecutionResult.init(toolName:arguments:result:duration:timestamp:)	swift.init	public	init(toolName: String, arguments: [String : SendableValue], result: Result<SendableValue, any Error>, duration: Duration, timestamp: Date = Date())	Sources/Swarm/Tools/ToolExecutionResult.swift:148
ToolExecutionResult.toolName	swift.property	public	let toolName: String	Sources/Swarm/Tools/ToolExecutionResult.swift:88
ToolExecutionResult.arguments	swift.property	public	let arguments: [String : SendableValue]	Sources/Swarm/Tools/ToolExecutionResult.swift:91
ToolExecutionResult.isSuccess	swift.property	public	var isSuccess: Bool { get }	Sources/Swarm/Tools/ToolExecutionResult.swift:109
ToolExecutionResult.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Tools/ToolExecutionResult.swift:106
ToolOutputGuardrail	swift.protocol	public	protocol ToolOutputGuardrail : Sendable	Sources/Swarm/Guardrails/ToolGuardrails.swift:134
ToolOutputGuardrail.name	swift.property	public	var name: String { get }	Sources/Swarm/Guardrails/ToolGuardrails.swift:136
ToolOutputGuardrail.validate(_:output:)	swift.method	public	func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:145
VectorMemoryBuilder	swift.struct	public	struct VectorMemoryBuilder	Sources/Swarm/Memory/VectorMemory.swift:396
VectorMemoryBuilder.maxResults(_:)	swift.method	public	func maxResults(_ max: Int) -> VectorMemoryBuilder	Sources/Swarm/Memory/VectorMemory.swift:426
VectorMemoryBuilder.tokenEstimator(_:)	swift.method	public	func tokenEstimator(_ estimator: any TokenEstimator) -> VectorMemoryBuilder	Sources/Swarm/Memory/VectorMemory.swift:436
VectorMemoryBuilder.embeddingProvider(_:)	swift.method	public	func embeddingProvider(_ provider: any EmbeddingProvider) -> VectorMemoryBuilder	Sources/Swarm/Memory/VectorMemory.swift:406
VectorMemoryBuilder.similarityThreshold(_:)	swift.method	public	func similarityThreshold(_ threshold: Float) -> VectorMemoryBuilder	Sources/Swarm/Memory/VectorMemory.swift:416
VectorMemoryBuilder.build()	swift.method	public	func build() throws -> VectorMemory	Sources/Swarm/Memory/VectorMemory.swift:446
VectorMemoryBuilder.init()	swift.init	public	init()	Sources/Swarm/Memory/VectorMemory.swift:400
AgentMemoryComponent	swift.struct	public	struct AgentMemoryComponent	Sources/Swarm/Agents/AgentBuilder.swift:88
AgentMemoryComponent.memory	swift.property	public	let memory: any Memory	Sources/Swarm/Agents/AgentBuilder.swift:90
AgentMemoryComponent.init(_:)	swift.init	public	init(_ memory: any Memory)	Sources/Swarm/Agents/AgentBuilder.swift:95
HandoffConfiguration	swift.struct	public	struct HandoffConfiguration<Target> where Target : AgentRuntime	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:187
HandoffConfiguration.nestHandoffHistory	swift.property	public	let nestHandoffHistory: Bool	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:229
HandoffConfiguration.onTransfer	swift.property	public	let onTransfer: OnTransferCallback?	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:209
HandoffConfiguration.init(targetAgent:toolNameOverride:toolDescription:onTransfer:transform:when:nestHandoffHistory:)	swift.init	public	init(targetAgent: Target, toolNameOverride: String? = nil, toolDescription: String? = nil, onTransfer: OnTransferCallback? = nil, transform: TransformCallback? = nil, when: WhenCallback? = nil, nestHandoffHistory: Bool = false)	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:243
HandoffConfiguration.targetAgent	swift.property	public	let targetAgent: Target	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:189
HandoffConfiguration.toolDescription	swift.property	public	let toolDescription: String?	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:202
HandoffConfiguration.toolNameOverride	swift.property	public	let toolNameOverride: String?	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:196
HandoffConfiguration.effectiveToolName	swift.property	public	var effectiveToolName: String { get }	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:269
HandoffConfiguration.effectiveToolDescription	swift.property	public	var effectiveToolDescription: String { get }	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:282
HandoffConfiguration.when	swift.property	public	let when: WhenCallback?	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:222
HandoffConfiguration.transform	swift.property	public	let transform: TransformCallback?	Sources/Swarm/Core/Handoff/HandoffConfiguration.swift:216
InferenceStreamEvent	swift.enum	public	enum InferenceStreamEvent	Sources/Swarm/Core/InferenceStreamEvent.swift:14
InferenceStreamEvent.finishReason(_:)	swift.enum.case	public	case finishReason(String)	Sources/Swarm/Core/InferenceStreamEvent.swift:27
InferenceStreamEvent.toolCallDelta(index:id:name:arguments:)	swift.enum.case	public	case toolCallDelta(index: Int, id: String?, name: String?, arguments: String)	Sources/Swarm/Core/InferenceStreamEvent.swift:24
InferenceStreamEvent.done	swift.enum.case	public	case done	Sources/Swarm/Core/InferenceStreamEvent.swift:33
InferenceStreamEvent.usage(promptTokens:completionTokens:)	swift.enum.case	public	case usage(promptTokens: Int, completionTokens: Int)	Sources/Swarm/Core/InferenceStreamEvent.swift:30
InferenceStreamEvent.textDelta(_:)	swift.enum.case	public	case textDelta(String)	Sources/Swarm/Core/InferenceStreamEvent.swift:16
MembraneAgentAdapter	swift.protocol	public	protocol MembraneAgentAdapter : Sendable	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:90
MembraneAgentAdapter.transformToolResult(toolName:output:)	swift.method	public	func transformToolResult(toolName: String, output: String) async throws -> MembraneToolResultBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:97
MembraneAgentAdapter.handleInternalToolCall(name:arguments:)	swift.method	public	func handleInternalToolCall(name: String, arguments: [String : SendableValue]) async throws -> String?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:102
MembraneAgentAdapter.snapshotCheckpointData()	swift.method	public	func snapshotCheckpointData() async throws -> Data?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:108
MembraneAgentAdapter.plan(prompt:toolSchemas:profile:)	swift.method	public	func plan(prompt: String, toolSchemas: [ToolSchema], profile: ContextProfile) async throws -> MembranePlannedBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:91
MembraneAgentAdapter.restore(checkpointData:)	swift.method	public	func restore(checkpointData: Data?) async throws	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:107
MetricsReporterError	swift.enum	public	enum MetricsReporterError	Sources/Swarm/Observability/MetricsCollector.swift:549
MetricsReporterError.invalidPath(_:)	swift.enum.case	public	case invalidPath(String)	Sources/Swarm/Observability/MetricsCollector.swift:552
MetricsReporterError.writeFailed(_:)	swift.enum.case	public	case writeFailed(String)	Sources/Swarm/Observability/MetricsCollector.swift:551
MetricsReporterError.encodingFailed	swift.enum.case	public	case encodingFailed	Sources/Swarm/Observability/MetricsCollector.swift:550
OpenRouterJSONSchema	swift.struct	public	struct OpenRouterJSONSchema	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:80
OpenRouterJSONSchema.init(properties:required:)	swift.init	public	init(properties: [String : OpenRouterPropertySchema], required: [String])	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:94
OpenRouterJSONSchema.properties	swift.property	public	let properties: [String : OpenRouterPropertySchema]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:85
OpenRouterJSONSchema.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterJSONSchema.type	swift.property	public	let type: String	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:82
OpenRouterJSONSchema.required	swift.property	public	let required: [String]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:88
OpenRouterToolChoice	swift.enum	public	enum OpenRouterToolChoice	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:318
OpenRouterToolChoice.auto	swift.enum.case	public	case auto	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:323
OpenRouterToolChoice.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:368
OpenRouterToolChoice.none	swift.enum.case	public	case none	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:320
OpenRouterToolChoice.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:337
OpenRouterToolChoice.function(name:)	swift.enum.case	public	case function(name: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:329
OpenRouterToolChoice.required	swift.enum.case	public	case required	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:326
ParallelToolExecutor	swift.class	public	actor ParallelToolExecutor	Sources/Swarm/Tools/ParallelToolExecutor.swift:73
ParallelToolExecutor.executeInParallel(_:using:agent:context:errorStrategy:)	swift.method	public	func executeInParallel(_ calls: [ToolCall], using registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext?, errorStrategy: ParallelExecutionErrorStrategy) async throws -> [ToolExecutionResult]	Sources/Swarm/Tools/ParallelToolExecutor.swift:237
ParallelToolExecutor.executeInParallel(_:using:agent:context:)	swift.method	public	func executeInParallel(_ calls: [ToolCall], using registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext?) async throws -> [ToolExecutionResult]	Sources/Swarm/Tools/ParallelToolExecutor.swift:122
ParallelToolExecutor.executeAllOrFail(_:using:agent:context:)	swift.method	public	func executeAllOrFail(_ calls: [ToolCall], using registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext? = nil) async throws -> [ToolExecutionResult]	Sources/Swarm/Tools/ParallelToolExecutor.swift:393
ParallelToolExecutor.executeAllCapturingErrors(_:using:agent:context:)	swift.method	public	func executeAllCapturingErrors(_ calls: [ToolCall], using registry: ToolRegistry, agent: any AgentRuntime, context: AgentContext? = nil) async throws -> [ToolExecutionResult]	Sources/Swarm/Tools/ParallelToolExecutor.swift:365
ParallelToolExecutor.init()	swift.init	public	init()	Sources/Swarm/Tools/ParallelToolExecutor.swift:79
SendableErrorWrapper	swift.struct	public	struct SendableErrorWrapper	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:12
SendableErrorWrapper.init(description:)	swift.init	public	init(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:28
SendableErrorWrapper.description	swift.property	public	var description: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:16
SendableErrorWrapper.errorDescription	swift.property	public	let errorDescription: String	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:14
SendableErrorWrapper.init(_:)	swift.init	public	init(_ error: any Error)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:22
ToolParameterBuilder	swift.struct	public	@resultBuilder struct ToolParameterBuilder	Sources/Swarm/Tools/ToolParameterBuilder.swift:37
ToolParameterBuilder.buildArray(_:)	swift.type.method	public	static func buildArray(_ components: [[ToolParameter]]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:69
ToolParameterBuilder.buildBlock()	swift.type.method	public	static func buildBlock() -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:44
ToolParameterBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: ToolParameter...) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:39
ToolParameterBuilder.buildBlock(_:)	swift.type.method	public	static func buildBlock(_ components: [ToolParameter]...) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:49
ToolParameterBuilder.buildEither(first:)	swift.type.method	public	static func buildEither(first component: [ToolParameter]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:59
ToolParameterBuilder.buildEither(second:)	swift.type.method	public	static func buildEither(second component: [ToolParameter]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:64
ToolParameterBuilder.buildOptional(_:)	swift.type.method	public	static func buildOptional(_ component: [ToolParameter]?) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:54
ToolParameterBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: ToolParameter) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:74
ToolParameterBuilder.buildExpression(_:)	swift.type.method	public	static func buildExpression(_ expression: [ToolParameter]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:79
ToolParameterBuilder.buildFinalResult(_:)	swift.type.method	public	static func buildFinalResult(_ component: [ToolParameter]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:89
ToolParameterBuilder.buildLimitedAvailability(_:)	swift.type.method	public	static func buildLimitedAvailability(_ component: [ToolParameter]) -> [ToolParameter]	Sources/Swarm/Tools/ToolParameterBuilder.swift:84
TruncatingSummarizer	swift.struct	public	struct TruncatingSummarizer	Sources/Swarm/Memory/Summarizer.swift:70
TruncatingSummarizer.isAvailable	swift.property	public	var isAvailable: Bool { get async }	Sources/Swarm/Memory/Summarizer.swift:76
TruncatingSummarizer.init(tokenEstimator:)	swift.init	public	init(tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared)	Sources/Swarm/Memory/Summarizer.swift:83
TruncatingSummarizer.shared	swift.type.property	public	static let shared: TruncatingSummarizer	Sources/Swarm/Memory/Summarizer.swift:74
TruncatingSummarizer.summarize(_:maxTokens:)	swift.method	public	func summarize(_ text: String, maxTokens: Int) async throws -> String	Sources/Swarm/Memory/Summarizer.swift:87
AgentContextProviding	swift.protocol	public	protocol AgentContextProviding : Sendable	Sources/Swarm/Core/Execution/AgentContext.swift:66
AgentContextProviding.contextKey	swift.type.property	public	static var contextKey: String { get }	Sources/Swarm/Core/Execution/AgentContext.swift:68
ClosureInputGuardrail	swift.struct	public	struct ClosureInputGuardrail	Sources/Swarm/Guardrails/InputGuardrail.swift:76
ClosureInputGuardrail.init(name:handler:)	swift.init	public	init(name: String, handler: @escaping (String, AgentContext?) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/InputGuardrail.swift:105
ClosureInputGuardrail.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/InputGuardrail.swift:80
ClosureInputGuardrail.notEmpty(name:)	swift.type.method	public	static func notEmpty(name: String = "NotEmptyGuardrail") -> ClosureInputGuardrail	Sources/Swarm/Guardrails/InputGuardrail.swift:307
ClosureInputGuardrail.validate(_:context:)	swift.method	public	func validate(_ input: String, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/InputGuardrail.swift:122
ClosureInputGuardrail.maxLength(_:name:)	swift.type.method	public	static func maxLength(_ maxLength: Int, name: String = "MaxLengthGuardrail") -> ClosureInputGuardrail	Sources/Swarm/Guardrails/InputGuardrail.swift:294
InferenceStreamUpdate	swift.enum	public	enum InferenceStreamUpdate	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:9
InferenceStreamUpdate.outputChunk(_:)	swift.enum.case	public	case outputChunk(String)	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:11
InferenceStreamUpdate.toolCallPartial(_:)	swift.enum.case	public	case toolCallPartial(PartialToolCallUpdate)	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:14
InferenceStreamUpdate.toolCallsCompleted(_:)	swift.enum.case	public	case toolCallsCompleted([InferenceResponse.ParsedToolCall])	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:17
InferenceStreamUpdate.usage(_:)	swift.enum.case	public	case usage(InferenceResponse.TokenUsage)	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:20
InputGuardrailBuilder	swift.struct	public	struct InputGuardrailBuilder	Sources/Swarm/Guardrails/InputGuardrail.swift:189
InputGuardrailBuilder.name(_:)	swift.method	public	@discardableResult func name(_ name: String) -> InputGuardrailBuilder	Sources/Swarm/Guardrails/InputGuardrail.swift:220
InputGuardrailBuilder.build()	swift.method	public	func build() -> ClosureInputGuardrail	Sources/Swarm/Guardrails/InputGuardrail.swift:263
InputGuardrailBuilder.validate(_:)	swift.method	public	@discardableResult func validate(_ handler: @escaping (String, AgentContext?) async throws -> GuardrailResult) -> InputGuardrailBuilder	Sources/Swarm/Guardrails/InputGuardrail.swift:239
InputGuardrailBuilder.init()	swift.init	public	init()	Sources/Swarm/Guardrails/InputGuardrail.swift:200
MockEmbeddingProvider	swift.struct	public	struct MockEmbeddingProvider	Sources/Swarm/Memory/EmbeddingProvider.swift:147
MockEmbeddingProvider.init(dimensions:)	swift.init	public	init(dimensions: Int = 384)	Sources/Swarm/Memory/EmbeddingProvider.swift:154
MockEmbeddingProvider.dimensions	swift.property	public	let dimensions: Int	Sources/Swarm/Memory/EmbeddingProvider.swift:148
MockEmbeddingProvider.modelIdentifier	swift.property	public	let modelIdentifier: String	Sources/Swarm/Memory/EmbeddingProvider.swift:149
MockEmbeddingProvider.embed(_:)	swift.method	public	func embed(_ text: String) async throws -> [Float]	Sources/Swarm/Memory/EmbeddingProvider.swift:158
OpenRouterContentPart	swift.enum	public	enum OpenRouterContentPart	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:260
OpenRouterContentPart.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:263
OpenRouterContentPart.text(_:)	swift.enum.case	public	case text(String)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:296
OpenRouterContentPart.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:283
OpenRouterContentPart.imageUrl(url:detail:)	swift.enum.case	public	case imageUrl(url: String, detail: String?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:299
OpenRouterErrorDetail	swift.struct	public	struct OpenRouterErrorDetail	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:886
OpenRouterErrorDetail.code	swift.property	public	let code: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:897
OpenRouterErrorDetail.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterErrorDetail.type	swift.property	public	let type: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:891
OpenRouterErrorDetail.param	swift.property	public	let param: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:894
OpenRouterErrorDetail.message	swift.property	public	let message: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:888
OpenRouterStreamChunk	swift.struct	public	struct OpenRouterStreamChunk	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:47
OpenRouterStreamChunk.StreamError	swift.struct	public	struct StreamError	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:190
OpenRouterStreamChunk.StreamError.code	swift.property	public	let code: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:198
OpenRouterStreamChunk.StreamError.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.StreamError.type	swift.property	public	let type: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:195
OpenRouterStreamChunk.StreamError.message	swift.property	public	let message: String	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:192
OpenRouterStreamChunk.StreamUsage	swift.struct	public	struct StreamUsage	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:146
OpenRouterStreamChunk.StreamUsage.totalTokens	swift.property	public	let totalTokens: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:156
OpenRouterStreamChunk.StreamUsage.promptTokens	swift.property	public	let promptTokens: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:150
OpenRouterStreamChunk.StreamUsage.completionTokens	swift.property	public	let completionTokens: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:153
OpenRouterStreamChunk.StreamUsage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.StreamChoice	swift.struct	public	struct StreamChoice	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:51
OpenRouterStreamChunk.StreamChoice.finishReason	swift.property	public	let finishReason: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:61
OpenRouterStreamChunk.StreamChoice.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.StreamChoice.delta	swift.property	public	let delta: OpenRouterStreamChunk.Delta?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:58
OpenRouterStreamChunk.StreamChoice.index	swift.property	public	let index: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:55
OpenRouterStreamChunk.StreamChoice.logprobs	swift.property	public	let logprobs: OpenRouterStreamChunk.LogProbs?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:64
OpenRouterStreamChunk.FunctionDelta	swift.struct	public	struct FunctionDelta	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:124
OpenRouterStreamChunk.FunctionDelta.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.FunctionDelta.name	swift.property	public	let name: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:126
OpenRouterStreamChunk.FunctionDelta.arguments	swift.property	public	let arguments: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:129
OpenRouterStreamChunk.ToolCallDelta	swift.struct	public	struct ToolCallDelta	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:107
OpenRouterStreamChunk.ToolCallDelta.id	swift.property	public	let id: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:112
OpenRouterStreamChunk.ToolCallDelta.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.ToolCallDelta.type	swift.property	public	let type: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:115
OpenRouterStreamChunk.ToolCallDelta.index	swift.property	public	let index: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:109
OpenRouterStreamChunk.ToolCallDelta.function	swift.property	public	let function: OpenRouterStreamChunk.FunctionDelta?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:118
OpenRouterStreamChunk.FunctionCallDelta	swift.struct	public	struct FunctionCallDelta	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:135
OpenRouterStreamChunk.FunctionCallDelta.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.FunctionCallDelta.name	swift.property	public	let name: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:137
OpenRouterStreamChunk.FunctionCallDelta.arguments	swift.property	public	let arguments: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:140
OpenRouterStreamChunk.id	swift.property	public	let id: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:202
OpenRouterStreamChunk.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.Delta	swift.struct	public	struct Delta	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:79
OpenRouterStreamChunk.Delta.functionCall	swift.property	public	let functionCall: OpenRouterStreamChunk.FunctionCallDelta?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:92
OpenRouterStreamChunk.Delta.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.Delta.role	swift.property	public	let role: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:83
OpenRouterStreamChunk.Delta.content	swift.property	public	let content: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:86
OpenRouterStreamChunk.Delta.toolCalls	swift.property	public	let toolCalls: [OpenRouterStreamChunk.ToolCallDelta]?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:89
OpenRouterStreamChunk.error	swift.property	public	let error: OpenRouterStreamChunk.StreamError?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:220
OpenRouterStreamChunk.model	swift.property	public	let model: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:211
OpenRouterStreamChunk.usage	swift.property	public	let usage: OpenRouterStreamChunk.StreamUsage?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:217
OpenRouterStreamChunk.object	swift.property	public	let object: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:205
OpenRouterStreamChunk.choices	swift.property	public	let choices: [OpenRouterStreamChunk.StreamChoice]?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:214
OpenRouterStreamChunk.created	swift.property	public	let created: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:208
OpenRouterStreamChunk.LogProbs	swift.struct	public	struct LogProbs	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:170
OpenRouterStreamChunk.LogProbs.TokenLogProb	swift.struct	public	struct TokenLogProb	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:172
OpenRouterStreamChunk.LogProbs.TokenLogProb.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.LogProbs.TokenLogProb.bytes	swift.property	public	let bytes: [Int]?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:180
OpenRouterStreamChunk.LogProbs.TokenLogProb.token	swift.property	public	let token: String	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:174
OpenRouterStreamChunk.LogProbs.TokenLogProb.logprob	swift.property	public	let logprob: Double	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:177
OpenRouterStreamChunk.LogProbs.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChunk.LogProbs.content	swift.property	public	let content: [OpenRouterStreamChunk.LogProbs.TokenLogProb]?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:184
OpenRouterStreamEvent	swift.enum	public	enum OpenRouterStreamEvent	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:14
OpenRouterStreamEvent.finishReason(_:)	swift.enum.case	public	case finishReason(String)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:27
OpenRouterStreamEvent.toolCallDelta(index:id:name:arguments:)	swift.enum.case	public	case toolCallDelta(index: Int, id: String?, name: String?, arguments: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:24
OpenRouterStreamEvent.done	swift.enum.case	public	case done	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:36
OpenRouterStreamEvent.error(_:)	swift.enum.case	public	case error(OpenRouterProviderError)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:39
OpenRouterStreamEvent.usage(prompt:completion:)	swift.enum.case	public	case usage(prompt: Int, completion: Int)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:33
OpenRouterStreamEvent.textDelta(_:)	swift.enum.case	public	case textDelta(String)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:16
PartialToolCallUpdate	swift.struct	public	struct PartialToolCallUpdate	Sources/Swarm/Core/PartialToolCallUpdate.swift:12
PartialToolCallUpdate.init(providerCallId:toolName:index:argumentsFragment:)	swift.init	public	init(providerCallId: String, toolName: String, index: Int, argumentsFragment: String)	Sources/Swarm/Core/PartialToolCallUpdate.swift:27
PartialToolCallUpdate.providerCallId	swift.property	public	let providerCallId: String	Sources/Swarm/Core/PartialToolCallUpdate.swift:14
PartialToolCallUpdate.argumentsFragment	swift.property	public	let argumentsFragment: String	Sources/Swarm/Core/PartialToolCallUpdate.swift:25
PartialToolCallUpdate.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
PartialToolCallUpdate.index	swift.property	public	let index: Int	Sources/Swarm/Core/PartialToolCallUpdate.swift:20
PartialToolCallUpdate.toolName	swift.property	public	let toolName: String	Sources/Swarm/Core/PartialToolCallUpdate.swift:17
PersistentMemoryError	swift.enum	public	enum PersistentMemoryError	Sources/Swarm/Memory/PersistentMemoryBackend.swift:151
PersistentMemoryError.description	swift.property	public	var description: String { get }	Sources/Swarm/Memory/PersistentMemoryBackend.swift:154
PersistentMemoryError.fetchFailed(_:)	swift.enum.case	public	case fetchFailed(String)	Sources/Swarm/Memory/PersistentMemoryBackend.swift:172
PersistentMemoryError.storeFailed(_:)	swift.enum.case	public	case storeFailed(String)	Sources/Swarm/Memory/PersistentMemoryBackend.swift:171
PersistentMemoryError.deleteFailed(_:)	swift.enum.case	public	case deleteFailed(String)	Sources/Swarm/Memory/PersistentMemoryBackend.swift:173
PersistentMemoryError.notConfigured	swift.enum.case	public	case notConfigured	Sources/Swarm/Memory/PersistentMemoryBackend.swift:175
PersistentMemoryError.connectionFailed(_:)	swift.enum.case	public	case connectionFailed(String)	Sources/Swarm/Memory/PersistentMemoryBackend.swift:174
PersistentMemoryError.invalidConversationId	swift.enum.case	public	case invalidConversationId	Sources/Swarm/Memory/PersistentMemoryBackend.swift:176
SemanticCompactorTool	swift.struct	public	struct SemanticCompactorTool	Sources/Swarm/Tools/SemanticCompactorTool.swift:18
SemanticCompactorTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/SemanticCompactorTool.swift:17
SemanticCompactorTool.init(summarizer:)	swift.init	public	init(summarizer: (any Summarizer)? = nil)	Sources/Swarm/Tools/SemanticCompactorTool.swift:40
SemanticCompactorTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/SemanticCompactorTool.swift:17
SemanticCompactorTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/SemanticCompactorTool.swift:17
SemanticCompactorTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/SemanticCompactorTool.swift:17
SemanticCompactorTool.execute()	swift.method	public	func execute() async throws -> String	Sources/Swarm/Tools/SemanticCompactorTool.swift:66
WorkflowCheckpointing	swift.struct	public	struct WorkflowCheckpointing	Sources/Swarm/Workflow/WorkflowCheckpointing.swift:5
WorkflowCheckpointing.fileSystem(directory:)	swift.type.method	public	static func fileSystem(directory: URL) -> WorkflowCheckpointing	Sources/Swarm/Workflow/WorkflowCheckpointing.swift:19
WorkflowCheckpointing.inMemory()	swift.type.method	public	static func inMemory() -> WorkflowCheckpointing	Sources/Swarm/Workflow/WorkflowCheckpointing.swift:13
AgentEnvironmentValues	swift.enum	public	enum AgentEnvironmentValues	Sources/Swarm/Core/AgentEnvironment.swift:38
AgentEnvironmentValues.current	swift.type.property	public	static var current: AgentEnvironment { get }	Sources/Swarm/Core/AgentEnvironment.swift:39
AgentEnvironmentValues.$current	swift.type.property	public	static let $current: TaskLocal<AgentEnvironment>	
AutoPreviousResponseId	swift.struct	public	struct AutoPreviousResponseId	Sources/Swarm/Agents/AgentBuilder.swift:350
AutoPreviousResponseId.enabled	swift.property	public	let enabled: Bool	Sources/Swarm/Agents/AgentBuilder.swift:352
AutoPreviousResponseId.init(_:)	swift.init	public	init(_ enabled: Bool = true)	Sources/Swarm/Agents/AgentBuilder.swift:357
CircuitBreakerRegistry	swift.class	public	actor CircuitBreakerRegistry	Sources/Swarm/Resilience/CircuitBreaker.swift:295
CircuitBreakerRegistry.allBreakers()	swift.method	public	func allBreakers() -> [CircuitBreaker]	Sources/Swarm/Resilience/CircuitBreaker.swift:358
CircuitBreakerRegistry.Configuration	swift.struct	public	struct Configuration	Sources/Swarm/Resilience/CircuitBreaker.swift:301
CircuitBreakerRegistry.Configuration.resetTimeout	swift.property	public	var resetTimeout: TimeInterval	Sources/Swarm/Resilience/CircuitBreaker.swift:309
CircuitBreakerRegistry.Configuration.failureThreshold	swift.property	public	var failureThreshold: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:303
CircuitBreakerRegistry.Configuration.successThreshold	swift.property	public	var successThreshold: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:306
CircuitBreakerRegistry.Configuration.halfOpenMaxRequests	swift.property	public	var halfOpenMaxRequests: Int	Sources/Swarm/Resilience/CircuitBreaker.swift:312
CircuitBreakerRegistry.Configuration.init()	swift.init	public	init()	Sources/Swarm/Resilience/CircuitBreaker.swift:314
CircuitBreakerRegistry.allStatistics()	swift.method	public	func allStatistics() async -> [Statistics]	Sources/Swarm/Resilience/CircuitBreaker.swift:381
CircuitBreakerRegistry.init(defaultConfiguration:)	swift.init	public	init(defaultConfiguration: CircuitBreakerRegistry.Configuration = Configuration())	Sources/Swarm/Resilience/CircuitBreaker.swift:321
CircuitBreakerRegistry.remove(named:)	swift.method	public	func remove(named name: String)	Sources/Swarm/Resilience/CircuitBreaker.swift:371
CircuitBreakerRegistry.breaker(named:configure:)	swift.method	public	func breaker(named name: String, configure: ((inout CircuitBreakerRegistry.Configuration) -> Void)? = nil) -> CircuitBreaker	Sources/Swarm/Resilience/CircuitBreaker.swift:332
CircuitBreakerRegistry.resetAll()	swift.method	public	func resetAll() async	Sources/Swarm/Resilience/CircuitBreaker.swift:363
CircuitBreakerRegistry.removeAll()	swift.method	public	func removeAll()	Sources/Swarm/Resilience/CircuitBreaker.swift:376
ClosureOutputGuardrail	swift.struct	public	struct ClosureOutputGuardrail	Sources/Swarm/Guardrails/OutputGuardrail.swift:111
ClosureOutputGuardrail.init(name:handler:)	swift.init	public	init(name: String, handler: @escaping (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/OutputGuardrail.swift:134
ClosureOutputGuardrail.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/OutputGuardrail.swift:115
ClosureOutputGuardrail.validate(_:agent:context:)	swift.method	public	func validate(_ output: String, agent: any AgentRuntime, context: AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/OutputGuardrail.swift:152
ClosureOutputGuardrail.maxLength(_:name:)	swift.type.method	public	static func maxLength(_ maxLength: Int, name: String = "MaxOutputLengthGuardrail") -> ClosureOutputGuardrail	Sources/Swarm/Guardrails/OutputGuardrail.swift:348
InputValidationHandler	swift.typealias	public	typealias InputValidationHandler = (String, AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/InputGuardrail.swift:10
MemoryPromptDescriptor	swift.protocol	public	protocol MemoryPromptDescriptor : Sendable	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:18
MemoryPromptDescriptor.memoryPromptTitle	swift.property	public	var memoryPromptTitle: String { get }	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:20
MemoryPromptDescriptor.memoryPromptGuidance	swift.property	public	var memoryPromptGuidance: String? { get }	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:23
MemoryPromptDescriptor.memoryPriority	swift.property	public	var memoryPriority: MemoryPriorityHint { get }	Sources/Swarm/Memory/MemoryPromptDescriptor.swift:26
MemorySessionLifecycle	swift.protocol	public	protocol MemorySessionLifecycle : Memory	Sources/Swarm/Memory/MemorySessionLifecycle.swift:7
MemorySessionLifecycle.endMemorySession()	swift.method	public	func endMemorySession() async	Sources/Swarm/Memory/MemorySessionLifecycle.swift:12
MemorySessionLifecycle.beginMemorySession()	swift.method	public	func beginMemorySession() async	Sources/Swarm/Memory/MemorySessionLifecycle.swift:9
ModelSettingsComponent	swift.struct	public	struct ModelSettingsComponent	Sources/Swarm/Agents/AgentBuilder.swift:379
ModelSettingsComponent.settings	swift.property	public	let settings: ModelSettings	Sources/Swarm/Agents/AgentBuilder.swift:381
ModelSettingsComponent.init(_:)	swift.init	public	init(_ settings: ModelSettings)	Sources/Swarm/Agents/AgentBuilder.swift:386
OpenRouterFunctionCall	swift.struct	public	struct OpenRouterFunctionCall	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:596
OpenRouterFunctionCall.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterFunctionCall.init(name:arguments:)	swift.init	public	init(name: String, arguments: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:604
OpenRouterFunctionCall.name	swift.property	public	let name: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:598
OpenRouterFunctionCall.arguments	swift.property	public	let arguments: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:601
OpenRouterStreamChoice	swift.struct	public	struct OpenRouterStreamChoice	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:650
OpenRouterStreamChoice.finishReason	swift.property	public	let finishReason: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:660
OpenRouterStreamChoice.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterStreamChoice.delta	swift.property	public	let delta: OpenRouterDelta	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:657
OpenRouterStreamChoice.index	swift.property	public	let index: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:654
OpenRouterStreamParser	swift.struct	public	struct OpenRouterStreamParser	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:251
OpenRouterStreamParser.parse(line:)	swift.method	public	func parse(line: String) -> [OpenRouterStreamEvent]?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:267
OpenRouterStreamParser.init()	swift.init	public	init()	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:255
OpenRouterToolFunction	swift.struct	public	struct OpenRouterToolFunction	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:441
OpenRouterToolFunction.parameters	swift.property	public	let parameters: SendableValue?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:449
OpenRouterToolFunction.description	swift.property	public	let description: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:446
OpenRouterToolFunction.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterToolFunction.init(name:description:parameters:)	swift.init	public	init(name: String, description: String?, parameters: SendableValue?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:452
OpenRouterToolFunction.name	swift.property	public	let name: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:443
OutputGuardrailBuilder	swift.struct	public	struct OutputGuardrailBuilder	Sources/Swarm/Guardrails/OutputGuardrail.swift:243
OutputGuardrailBuilder.name(_:)	swift.method	public	@discardableResult func name(_ name: String) -> OutputGuardrailBuilder	Sources/Swarm/Guardrails/OutputGuardrail.swift:274
OutputGuardrailBuilder.build()	swift.method	public	func build() -> ClosureOutputGuardrail	Sources/Swarm/Guardrails/OutputGuardrail.swift:317
OutputGuardrailBuilder.validate(_:)	swift.method	public	@discardableResult func validate(_ handler: @escaping (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult) -> OutputGuardrailBuilder	Sources/Swarm/Guardrails/OutputGuardrail.swift:293
OutputGuardrailBuilder.init()	swift.init	public	init()	Sources/Swarm/Guardrails/OutputGuardrail.swift:254
AnyHandoffConfiguration	swift.struct	public	struct AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:262
AnyHandoffConfiguration.nestHandoffHistory	swift.property	public	let nestHandoffHistory: Bool	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:282
AnyHandoffConfiguration.onTransfer	swift.property	public	let onTransfer: OnTransferCallback?	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:273
AnyHandoffConfiguration.init(targetAgent:toolNameOverride:toolDescription:onTransfer:transform:when:nestHandoffHistory:)	swift.init	public	init(targetAgent: any AgentRuntime, toolNameOverride: String? = nil, toolDescription: String? = nil, onTransfer: OnTransferCallback? = nil, transform: TransformCallback? = nil, when: WhenCallback? = nil, nestHandoffHistory: Bool = false)	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:309
AnyHandoffConfiguration.targetAgent	swift.property	public	let targetAgent: any AgentRuntime	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:264
AnyHandoffConfiguration.toolDescription	swift.property	public	let toolDescription: String?	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:270
AnyHandoffConfiguration.toolNameOverride	swift.property	public	let toolNameOverride: String?	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:267
AnyHandoffConfiguration.effectiveToolName	swift.property	public	var effectiveToolName: String { get }	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:332
AnyHandoffConfiguration.effectiveToolDescription	swift.property	public	var effectiveToolDescription: String { get }	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:341
AnyHandoffConfiguration.when	swift.property	public	let when: WhenCallback?	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:279
AnyHandoffConfiguration.transform	swift.property	public	let transform: TransformCallback?	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:276
AnyHandoffConfiguration.init(_:)	swift.init	public	init(_ configuration: HandoffConfiguration<some AgentRuntime>)	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:289
AveragingTokenEstimator	swift.struct	public	struct AveragingTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:108
AveragingTokenEstimator.init(estimators:)	swift.init	public	init(estimators: [any TokenEstimator])	Sources/Swarm/Memory/TokenEstimator.swift:120
AveragingTokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for text: String) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:126
AveragingTokenEstimator.shared	swift.type.property	public	static let shared: AveragingTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:112
HybridMemoryDiagnostics	swift.struct	public	struct HybridMemoryDiagnostics	Sources/Swarm/Memory/HybridMemory.swift:351
HybridMemoryDiagnostics.hasSummary	swift.property	public	let hasSummary: Bool	Sources/Swarm/Memory/HybridMemory.swift:361
HybridMemoryDiagnostics.pendingMessages	swift.property	public	let pendingMessages: Int	Sources/Swarm/Memory/HybridMemory.swift:357
HybridMemoryDiagnostics.summaryTokenCount	swift.property	public	let summaryTokenCount: Int	Sources/Swarm/Memory/HybridMemory.swift:363
HybridMemoryDiagnostics.summarizationCount	swift.property	public	let summarizationCount: Int	Sources/Swarm/Memory/HybridMemory.swift:365
HybridMemoryDiagnostics.nextSummarizationIn	swift.property	public	let nextSummarizationIn: Int	Sources/Swarm/Memory/HybridMemory.swift:367
HybridMemoryDiagnostics.shortTermMaxMessages	swift.property	public	let shortTermMaxMessages: Int	Sources/Swarm/Memory/HybridMemory.swift:355
HybridMemoryDiagnostics.shortTermMessageCount	swift.property	public	let shortTermMessageCount: Int	Sources/Swarm/Memory/HybridMemory.swift:353
HybridMemoryDiagnostics.totalMessagesProcessed	swift.property	public	let totalMessagesProcessed: Int	Sources/Swarm/Memory/HybridMemory.swift:359
MembranePlannedBoundary	swift.struct	public	struct MembranePlannedBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:63
MembranePlannedBoundary.toolSchemas	swift.property	public	let toolSchemas: [ToolSchema]	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:65
MembranePlannedBoundary.mode	swift.property	public	let mode: String	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:66
MembranePlannedBoundary.init(prompt:toolSchemas:mode:)	swift.init	public	init(prompt: String, toolSchemas: [ToolSchema], mode: String)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:68
MembranePlannedBoundary.prompt	swift.property	public	let prompt: String	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:64
OpenRouterConfiguration	swift.struct	public	struct OpenRouterConfiguration	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:351
OpenRouterConfiguration.description	swift.property	public	var description: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:521
OpenRouterConfiguration.temperature	swift.property	public	let temperature: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:383
OpenRouterConfiguration.systemPrompt	swift.property	public	let systemPrompt: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:380
OpenRouterConfiguration.retryStrategy	swift.property	public	let retryStrategy: OpenRouterRetryStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:407
OpenRouterConfiguration.defaultBaseURL	swift.type.property	public	static let defaultBaseURL: URL	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:356
OpenRouterConfiguration.defaultTimeout	swift.type.property	public	static let defaultTimeout: Duration	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:359
OpenRouterConfiguration.fallbackModels	swift.property	public	let fallbackModels: [OpenRouterModel]	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:401
OpenRouterConfiguration.routingStrategy	swift.property	public	let routingStrategy: OpenRouterRoutingStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:404
OpenRouterConfiguration.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:529
OpenRouterConfiguration.defaultMaxTokens	swift.type.property	public	static let defaultMaxTokens: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:362
OpenRouterConfiguration.providerPreferences	swift.property	public	let providerPreferences: OpenRouterProviderPreferences?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:398
OpenRouterConfiguration.==(_:_:)	swift.func.op	public	static func == (lhs: OpenRouterConfiguration, rhs: OpenRouterConfiguration) -> Bool	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:499
OpenRouterConfiguration.topK	swift.property	public	let topK: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:389
OpenRouterConfiguration.topP	swift.property	public	let topP: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:386
OpenRouterConfiguration.model	swift.property	public	let model: OpenRouterModel	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:368
OpenRouterConfiguration.init(apiKey:model:baseURL:timeout:maxTokens:systemPrompt:temperature:topP:topK:appName:siteURL:providerPreferences:fallbackModels:routingStrategy:retryStrategy:)	swift.init	public	init(apiKey: String, model: OpenRouterModel, baseURL: URL = defaultBaseURL, timeout: Duration = defaultTimeout, maxTokens: Int = defaultMaxTokens, systemPrompt: String? = nil, temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil, appName: String? = nil, siteURL: URL? = nil, providerPreferences: OpenRouterProviderPreferences? = nil, fallbackModels: [OpenRouterModel] = [], routingStrategy: OpenRouterRoutingStrategy = .fallback, retryStrategy: OpenRouterRetryStrategy = .default) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:429
OpenRouterConfiguration.apiKey	swift.property	public	let apiKey: String	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:365
OpenRouterConfiguration.Builder	swift.struct	public	struct Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:22
OpenRouterConfiguration.Builder.temperature(_:)	swift.method	public	@discardableResult func temperature(_ value: Double?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:182
OpenRouterConfiguration.Builder.systemPrompt(_:)	swift.method	public	@discardableResult func systemPrompt(_ value: String?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:160
OpenRouterConfiguration.Builder.retryStrategy(_:)	swift.method	public	@discardableResult func retryStrategy(_ value: OpenRouterRetryStrategy) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:358
OpenRouterConfiguration.Builder.fallbackModels(_:)	swift.method	public	@discardableResult func fallbackModels(_ value: [OpenRouterModel]) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:314
OpenRouterConfiguration.Builder.routingStrategy(_:)	swift.method	public	@discardableResult func routingStrategy(_ value: OpenRouterRoutingStrategy) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:336
OpenRouterConfiguration.Builder.providerPreferences(_:)	swift.method	public	@discardableResult func providerPreferences(_ value: OpenRouterProviderPreferences?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:292
OpenRouterConfiguration.Builder.topK(_:)	swift.method	public	@discardableResult func topK(_ value: Int?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:226
OpenRouterConfiguration.Builder.topP(_:)	swift.method	public	@discardableResult func topP(_ value: Double?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:204
OpenRouterConfiguration.Builder.build()	swift.method	public	func build() throws -> OpenRouterConfiguration	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:381
OpenRouterConfiguration.Builder.model(_:)	swift.method	public	@discardableResult func model(_ value: OpenRouterModel) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:72
OpenRouterConfiguration.Builder.apiKey(_:)	swift.method	public	@discardableResult func apiKey(_ value: String) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:50
OpenRouterConfiguration.Builder.appName(_:)	swift.method	public	@discardableResult func appName(_ value: String?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:248
OpenRouterConfiguration.Builder.baseURL(_:)	swift.method	public	@discardableResult func baseURL(_ value: URL) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:94
OpenRouterConfiguration.Builder.siteURL(_:)	swift.method	public	@discardableResult func siteURL(_ value: URL?) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:270
OpenRouterConfiguration.Builder.timeout(_:)	swift.method	public	@discardableResult func timeout(_ value: Duration) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:116
OpenRouterConfiguration.Builder.maxTokens(_:)	swift.method	public	@discardableResult func maxTokens(_ value: Int) -> OpenRouterConfiguration.Builder	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:138
OpenRouterConfiguration.Builder.init()	swift.init	public	init()	Sources/Swarm/Providers/OpenRouter/OpenRouterConfigurationBuilder.swift:28
OpenRouterConfiguration.appName	swift.property	public	let appName: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:392
OpenRouterConfiguration.baseURL	swift.property	public	let baseURL: URL	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:371
OpenRouterConfiguration.siteURL	swift.property	public	let siteURL: URL?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:395
OpenRouterConfiguration.timeout	swift.property	public	let timeout: Duration	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:374
OpenRouterConfiguration.maxTokens	swift.property	public	let maxTokens: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:377
OpenRouterDeltaFunction	swift.struct	public	struct OpenRouterDeltaFunction	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:715
OpenRouterDeltaFunction.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterDeltaFunction.name	swift.property	public	let name: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:717
OpenRouterDeltaFunction.arguments	swift.property	public	let arguments: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:720
OpenRouterDeltaToolCall	swift.struct	public	struct OpenRouterDeltaToolCall	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:698
OpenRouterDeltaToolCall.id	swift.property	public	let id: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:703
OpenRouterDeltaToolCall.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterDeltaToolCall.type	swift.property	public	let type: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:706
OpenRouterDeltaToolCall.index	swift.property	public	let index: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:700
OpenRouterDeltaToolCall.function	swift.property	public	let function: OpenRouterDeltaFunction?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:709
OpenRouterErrorResponse	swift.struct	public	struct OpenRouterErrorResponse	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:878
OpenRouterErrorResponse.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterErrorResponse.error	swift.property	public	let error: OpenRouterErrorDetail	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:880
OpenRouterProviderError	swift.enum	public	enum OpenRouterProviderError	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:36
OpenRouterProviderError.apiError(code:message:statusCode:)	swift.enum.case	public	case apiError(code: String, message: String, statusCode: Int)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:43
OpenRouterProviderError.networkError(_:)	swift.enum.case	public	case networkError(SendableErrorWrapper)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:55
OpenRouterProviderError.toAgentError()	swift.method	public	func toAgentError() -> AgentError	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:162
OpenRouterProviderError.unknownError(statusCode:)	swift.enum.case	public	case unknownError(statusCode: Int)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:61
OpenRouterProviderError.decodingError(_:)	swift.enum.case	public	case decodingError(SendableErrorWrapper)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:58
OpenRouterProviderError.streamingError(message:)	swift.enum.case	public	case streamingError(message: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:83
OpenRouterProviderError.emptyPrompt	swift.enum.case	public	case emptyPrompt	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:94
OpenRouterProviderError.fromURLError(_:)	swift.type.method	public	static func fromURLError(_ urlError: URLError) -> OpenRouterProviderError	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:263
OpenRouterProviderError.fromHTTPStatus(_:body:headers:)	swift.type.method	public	static func fromHTTPStatus(_ statusCode: Int, body: Data?, headers: [AnyHashable : Any]? = nil) -> OpenRouterProviderError	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:225
OpenRouterProviderError.contentFiltered	swift.enum.case	public	case contentFiltered	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:72
OpenRouterProviderError.invalidResponse	swift.enum.case	public	case invalidResponse	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:40
OpenRouterProviderError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:375
OpenRouterProviderError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:100
OpenRouterProviderError.fallbackExhausted(reason:)	swift.enum.case	public	case fallbackExhausted(reason: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:78
OpenRouterProviderError.modelNotAvailable(model:)	swift.enum.case	public	case modelNotAvailable(model: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:66
OpenRouterProviderError.rateLimitExceeded(retryAfter:)	swift.enum.case	public	case rateLimitExceeded(retryAfter: TimeInterval?)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:47
OpenRouterProviderError.insufficientCredits	swift.enum.case	public	case insufficientCredits	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:69
OpenRouterProviderError.providerUnavailable(providers:)	swift.enum.case	public	case providerUnavailable(providers: [String])	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:75
OpenRouterProviderError.authenticationFailed	swift.enum.case	public	case authenticationFailed	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:50
OpenRouterProviderError.timeout(duration:)	swift.enum.case	public	case timeout(duration: Duration)	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:91
OpenRouterProviderError.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/Providers/OpenRouter/OpenRouterError.swift:88
OpenRouterRateLimitInfo	swift.struct	public	struct OpenRouterRateLimitInfo	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:726
OpenRouterRateLimitInfo.tokensLimit	swift.property	public	let tokensLimit: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:739
OpenRouterRateLimitInfo.init(requestsLimit:requestsRemaining:requestsReset:tokensLimit:tokensRemaining:tokensReset:)	swift.init	public	init(requestsLimit: Int?, requestsRemaining: Int?, requestsReset: Date?, tokensLimit: Int?, tokensRemaining: Int?, tokensReset: Date?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:758
OpenRouterRateLimitInfo.requestsLimit	swift.property	public	let requestsLimit: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:730
OpenRouterRateLimitInfo.tokensReset	swift.property	public	let tokensReset: Date?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:745
OpenRouterRateLimitInfo.requestsReset	swift.property	public	let requestsReset: Date?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:736
OpenRouterRateLimitInfo.tokensRemaining	swift.property	public	let tokensRemaining: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:742
OpenRouterRateLimitInfo.requestsRemaining	swift.property	public	let requestsRemaining: Int?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:733
OpenRouterRateLimitInfo.parse(from:)	swift.type.method	public	static func parse(from headers: [AnyHashable : Any]) -> OpenRouterRateLimitInfo	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:786
OpenRouterRateLimitInfo.parse(from:)	swift.type.method	public	static func parse(from response: HTTPURLResponse) -> OpenRouterRateLimitInfo	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:809
OpenRouterRateLimitInfo.init()	swift.init	public	init()	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:748
OpenRouterRetryStrategy	swift.struct	public	struct OpenRouterRetryStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:144
OpenRouterRetryStrategy.init(maxRetries:baseDelay:maxDelay:backoffMultiplier:retryableStatusCodes:)	swift.init	public	init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0, backoffMultiplier: Double = 2.0, retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504])	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:189
OpenRouterRetryStrategy.maxRetries	swift.property	public	let maxRetries: Int	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:166
OpenRouterRetryStrategy.backoffMultiplier	swift.property	public	let backoffMultiplier: Double	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:175
OpenRouterRetryStrategy.retryableStatusCodes	swift.property	public	let retryableStatusCodes: Set<Int>	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:178
OpenRouterRetryStrategy.none	swift.type.property	public	static let none: OpenRouterRetryStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:157
OpenRouterRetryStrategy.delay(forAttempt:)	swift.method	public	func delay(forAttempt attempt: Int) -> TimeInterval	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:208
OpenRouterRetryStrategy.default	swift.type.property	public	static let `default`: OpenRouterRetryStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:148
OpenRouterRetryStrategy.maxDelay	swift.property	public	let maxDelay: TimeInterval	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:172
OpenRouterRetryStrategy.baseDelay	swift.property	public	let baseDelay: TimeInterval	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:169
OutputValidationHandler	swift.typealias	public	typealias OutputValidationHandler = (String, any AgentRuntime, AgentContext?) async throws -> GuardrailResult	Sources/Swarm/Guardrails/OutputGuardrail.swift:9
PersistentMemoryBackend	swift.protocol	public	protocol PersistentMemoryBackend : Actor	Sources/Swarm/Memory/PersistentMemoryBackend.swift:40
PersistentMemoryBackend.messageCount(conversationId:)	swift.method	public	func messageCount(conversationId: String) async throws -> Int	Sources/Swarm/Memory/PersistentMemoryBackend.swift:71
PersistentMemoryBackend.fetchMessages(conversationId:)	swift.method	public	func fetchMessages(conversationId: String) async throws -> [MemoryMessage]	Sources/Swarm/Memory/PersistentMemoryBackend.swift:52
PersistentMemoryBackend.deleteMessages(conversationId:)	swift.method	public	func deleteMessages(conversationId: String) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:65
PersistentMemoryBackend.deleteLastMessage(conversationId:)	swift.method	public	func deleteLastMessage(conversationId: String) async throws -> MemoryMessage?	Sources/Swarm/Memory/PersistentMemoryBackend.swift:108
PersistentMemoryBackend.allConversationIds()	swift.method	public	func allConversationIds() async throws -> [String]	Sources/Swarm/Memory/PersistentMemoryBackend.swift:76
PersistentMemoryBackend.fetchRecentMessages(conversationId:limit:)	swift.method	public	func fetchRecentMessages(conversationId: String, limit: Int) async throws -> [MemoryMessage]	Sources/Swarm/Memory/PersistentMemoryBackend.swift:60
PersistentMemoryBackend.deleteOldestMessages(conversationId:keepRecent:)	swift.method	public	func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:96
PersistentMemoryBackend.store(_:conversationId:)	swift.method	public	func store(_ message: MemoryMessage, conversationId: String) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:46
PersistentMemoryBackend.storeAll(_:conversationId:)	swift.method	public	func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:86
PersistentMemoryBackend.deleteLastMessage(conversationId:)	swift.method	public	func deleteLastMessage(conversationId: String) async throws -> MemoryMessage?	Sources/Swarm/Memory/PersistentMemoryBackend.swift:130
PersistentMemoryBackend.deleteOldestMessages(conversationId:keepRecent:)	swift.method	public	func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:120
PersistentMemoryBackend.storeAll(_:conversationId:)	swift.method	public	func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws	Sources/Swarm/Memory/PersistentMemoryBackend.swift:114
VectorMemoryDiagnostics	swift.struct	public	struct VectorMemoryDiagnostics	Sources/Swarm/Memory/VectorMemory.swift:376
VectorMemoryDiagnostics.maxResults	swift.property	public	let maxResults: Int	Sources/Swarm/Memory/VectorMemory.swift:384
VectorMemoryDiagnostics.messageCount	swift.property	public	let messageCount: Int	Sources/Swarm/Memory/VectorMemory.swift:378
VectorMemoryDiagnostics.modelIdentifier	swift.property	public	let modelIdentifier: String	Sources/Swarm/Memory/VectorMemory.swift:386
VectorMemoryDiagnostics.newestTimestamp	swift.property	public	let newestTimestamp: Date?	Sources/Swarm/Memory/VectorMemory.swift:390
VectorMemoryDiagnostics.oldestTimestamp	swift.property	public	let oldestTimestamp: Date?	Sources/Swarm/Memory/VectorMemory.swift:388
VectorMemoryDiagnostics.embeddingDimensions	swift.property	public	let embeddingDimensions: Int	Sources/Swarm/Memory/VectorMemory.swift:380
VectorMemoryDiagnostics.similarityThreshold	swift.property	public	let similarityThreshold: Float	Sources/Swarm/Memory/VectorMemory.swift:382
WordBasedTokenEstimator	swift.struct	public	struct WordBasedTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:83
WordBasedTokenEstimator.init(tokensPerWord:)	swift.init	public	init(tokensPerWord: Double = 1.3)	Sources/Swarm/Memory/TokenEstimator.swift:93
WordBasedTokenEstimator.tokensPerWord	swift.property	public	let tokensPerWord: Double	Sources/Swarm/Memory/TokenEstimator.swift:88
WordBasedTokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for text: String) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:97
WordBasedTokenEstimator.shared	swift.type.property	public	static let shared: WordBasedTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:85
WorkflowValidationError	swift.enum	public	enum WorkflowValidationError	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:9
WorkflowValidationError.emptyGraph	swift.enum.case	public	case emptyGraph	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:11
WorkflowValidationError.cycleDetected(nodes:)	swift.enum.case	public	case cycleDetected(nodes: [String])	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:20
WorkflowValidationError.duplicateNode(name:)	swift.enum.case	public	case duplicateNode(name: String)	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:14
WorkflowValidationError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:24
WorkflowValidationError.unknownDependency(node:dependency:availableNodes:)	swift.enum.case	public	case unknownDependency(node: String, dependency: String, availableNodes: [String])	Sources/Swarm/Core/Handoff/WorkflowValidationError.swift:17
AgentRuntimeIdentifiable	swift.protocol	public	protocol AgentRuntimeIdentifiable : Sendable	Sources/Swarm/Core/AgentRuntime+Identity.swift:27
AgentRuntimeIdentifiable.runtimeIdentity	swift.property	public	var runtimeIdentity: String { get }	Sources/Swarm/Core/AgentRuntime+Identity.swift:32
ConduitInferenceProvider	swift.struct	public	struct ConduitInferenceProvider<Provider> where Provider : TextGenerator	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:8
ConduitInferenceProvider.streamWithToolCalls(prompt:tools:options:)	swift.method	public	func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamUpdate, any Error>	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:65
ConduitInferenceProvider.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:29
ConduitInferenceProvider.stream(prompt:options:)	swift.method	public	func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:24
ConduitInferenceProvider.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:19
ConduitInferenceProvider.init(provider:model:baseConfig:)	swift.init	public	init(provider: Provider, model: Provider.ModelID, baseConfig: GenerateConfig = .default)	Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:9
ConduitProviderSelection	swift.enum	public	enum ConduitProviderSelection	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:11
ConduitProviderSelection.makeProvider()	swift.method	public	func makeProvider() -> any InferenceProvider	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:63
ConduitProviderSelection.openRouter(apiKey:model:routing:)	swift.type.method	public	static func openRouter(apiKey: String, model: String, routing: OpenRouterRouting? = nil) -> ConduitProviderSelection	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:34
ConduitProviderSelection.streamWithToolCalls(prompt:tools:options:)	swift.method	public	func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamUpdate, any Error>	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:90
ConduitProviderSelection.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:78
ConduitProviderSelection.ollama(model:settings:)	swift.type.method	public	static func ollama(model: String, settings: OllamaSettings = .default) -> ConduitProviderSelection	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:50
ConduitProviderSelection.openAI(apiKey:model:)	swift.type.method	public	static func openAI(apiKey: String, model: String) -> ConduitProviderSelection	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:23
ConduitProviderSelection.stream(prompt:options:)	swift.method	public	func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:74
ConduitProviderSelection.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:70
ConduitProviderSelection.provider(_:)	swift.enum.case	public	case provider(any InferenceProvider)	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:12
ConduitProviderSelection.anthropic(apiKey:model:)	swift.type.method	public	static func anthropic(apiKey: String, model: String) -> ConduitProviderSelection	Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:15
GuardrailExecutionResult	swift.struct	public	struct GuardrailExecutionResult	Sources/Swarm/Guardrails/GuardrailRunner.swift:94
GuardrailExecutionResult.init(guardrailName:result:)	swift.init	public	init(guardrailName: String, result: GuardrailResult)	Sources/Swarm/Guardrails/GuardrailRunner.swift:120
GuardrailExecutionResult.guardrailName	swift.property	public	let guardrailName: String	Sources/Swarm/Guardrails/GuardrailRunner.swift:96
GuardrailExecutionResult.didTriggerTripwire	swift.property	public	var didTriggerTripwire: Bool { get }	Sources/Swarm/Guardrails/GuardrailRunner.swift:104
GuardrailExecutionResult.passed	swift.property	public	var passed: Bool { get }	Sources/Swarm/Guardrails/GuardrailRunner.swift:109
GuardrailExecutionResult.result	swift.property	public	let result: GuardrailResult	Sources/Swarm/Guardrails/GuardrailRunner.swift:99
InputGuardrailsComponent	swift.struct	public	struct InputGuardrailsComponent	Sources/Swarm/Agents/AgentBuilder.swift:187
InputGuardrailsComponent.guardrails	swift.property	public	let guardrails: [any InputGuardrail]	Sources/Swarm/Agents/AgentBuilder.swift:189
InputGuardrailsComponent.init(_:)	swift.init	public	init(_ guardrails: [any InputGuardrail])	Sources/Swarm/Agents/AgentBuilder.swift:194
InputGuardrailsComponent.init(_:)	swift.init	public	init(_ guardrails: any InputGuardrail...)	Sources/Swarm/Agents/AgentBuilder.swift:201
OpenRouterMessageContent	swift.enum	public	enum OpenRouterMessageContent	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:196
OpenRouterMessageContent.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:225
OpenRouterMessageContent.text(_:)	swift.enum.case	public	case text(String)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:216
OpenRouterMessageContent.parts(_:)	swift.enum.case	public	case parts([OpenRouterContentPart])	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:219
OpenRouterMessageContent.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:246
OpenRouterMessageContent.textValue	swift.property	public	var textValue: String? { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:200
OpenRouterPropertySchema	swift.enum	public	indirect enum OpenRouterPropertySchema	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:111
OpenRouterPropertySchema.enumeration(values:description:)	swift.enum.case	public	case enumeration(values: [String], description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:250
OpenRouterPropertySchema.any(description:)	swift.enum.case	public	case any(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:253
OpenRouterPropertySchema.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:114
OpenRouterPropertySchema.from(_:description:)	swift.type.method	public	static func from(_ parameterType: ToolParameter.ParameterType, description: String) -> OpenRouterPropertySchema	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:151
OpenRouterPropertySchema.array(items:description:)	swift.enum.case	public	case array(items: OpenRouterPropertySchema, description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:244
OpenRouterPropertySchema.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:190
OpenRouterPropertySchema.number(description:)	swift.enum.case	public	case number(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:238
OpenRouterPropertySchema.object(properties:required:description:)	swift.enum.case	public	case object(properties: [String : OpenRouterPropertySchema], required: [String], description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:247
OpenRouterPropertySchema.string(description:)	swift.enum.case	public	case string(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:232
OpenRouterPropertySchema.boolean(description:)	swift.enum.case	public	case boolean(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:241
OpenRouterPropertySchema.integer(description:)	swift.enum.case	public	case integer(description: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:235
OpenRouterToolCallParser	swift.enum	public	enum OpenRouterToolCallParser	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:291
OpenRouterToolCallParser.toParsedToolCalls(_:)	swift.type.method	public	static func toParsedToolCalls(_ toolCalls: [OpenRouterToolCall]) throws -> [InferenceResponse.ParsedToolCall]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:345
OpenRouterToolCallParser.toParsedToolCall(_:)	swift.type.method	public	static func toParsedToolCall(_ toolCall: OpenRouterToolCall) throws -> InferenceResponse.ParsedToolCall	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:332
OpenRouterToolCallParser.parseArguments(_:)	swift.type.method	public	static func parseArguments(_ jsonString: String) throws -> [String : SendableValue]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:296
OpenRouterToolDefinition	swift.struct	public	struct OpenRouterToolDefinition	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:19
OpenRouterToolDefinition.toOpenRouterTool()	swift.method	public	func toOpenRouterTool() -> OpenRouterTool	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:401
OpenRouterToolDefinition.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterToolDefinition.type	swift.property	public	let type: String	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:21
OpenRouterToolDefinition.function	swift.property	public	let function: OpenRouterFunctionDefinition	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:24
OpenRouterToolDefinition.init(function:)	swift.init	public	init(function: OpenRouterFunctionDefinition)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:28
SlidingWindowDiagnostics	swift.struct	public	struct SlidingWindowDiagnostics	Sources/Swarm/Memory/SlidingWindowMemory.swift:190
SlidingWindowDiagnostics.messageCount	swift.property	public	let messageCount: Int	Sources/Swarm/Memory/SlidingWindowMemory.swift:192
SlidingWindowDiagnostics.currentTokens	swift.property	public	let currentTokens: Int	Sources/Swarm/Memory/SlidingWindowMemory.swift:194
SlidingWindowDiagnostics.remainingTokens	swift.property	public	let remainingTokens: Int	Sources/Swarm/Memory/SlidingWindowMemory.swift:200
SlidingWindowDiagnostics.utilizationPercent	swift.property	public	let utilizationPercent: Double	Sources/Swarm/Memory/SlidingWindowMemory.swift:198
SlidingWindowDiagnostics.averageTokensPerMessage	swift.property	public	let averageTokensPerMessage: Double	Sources/Swarm/Memory/SlidingWindowMemory.swift:202
SlidingWindowDiagnostics.maxTokens	swift.property	public	let maxTokens: Int	Sources/Swarm/Memory/SlidingWindowMemory.swift:196
SummaryMemoryDiagnostics	swift.struct	public	struct SummaryMemoryDiagnostics	Sources/Swarm/Memory/SummaryMemory.swift:276
SummaryMemoryDiagnostics.hasSummary	swift.property	public	let hasSummary: Bool	Sources/Swarm/Memory/SummaryMemory.swift:282
SummaryMemoryDiagnostics.summaryTokenCount	swift.property	public	let summaryTokenCount: Int	Sources/Swarm/Memory/SummaryMemory.swift:284
SummaryMemoryDiagnostics.recentMessageCount	swift.property	public	let recentMessageCount: Int	Sources/Swarm/Memory/SummaryMemory.swift:278
SummaryMemoryDiagnostics.summarizationCount	swift.property	public	let summarizationCount: Int	Sources/Swarm/Memory/SummaryMemory.swift:286
SummaryMemoryDiagnostics.nextSummarizationIn	swift.property	public	let nextSummarizationIn: Int	Sources/Swarm/Memory/SummaryMemory.swift:288
SummaryMemoryDiagnostics.totalMessagesProcessed	swift.property	public	let totalMessagesProcessed: Int	Sources/Swarm/Memory/SummaryMemory.swift:280
VectorMemoryConfigurable	swift.protocol	public	protocol VectorMemoryConfigurable : Memory	Sources/Swarm/Memory/MemoryBuilder.swift:512
VectorMemoryConfigurable.withMaxResults(_:)	swift.method	public	func withMaxResults(_ max: Int) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:517
VectorMemoryConfigurable.withSimilarityThreshold(_:)	swift.method	public	func withSimilarityThreshold(_ threshold: Double) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:514
VectorMemoryConfigurable.withMaxResults(_:)	swift.method	public	nonisolated func withMaxResults(_: Int) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:529
VectorMemoryConfigurable.withSimilarityThreshold(_:)	swift.method	public	nonisolated func withSimilarityThreshold(_: Double) -> MemoryComponent	Sources/Swarm/Memory/MemoryBuilder.swift:524
formatMessagesForContext(_:tokenLimit:tokenEstimator:)	swift.func	public	func formatMessagesForContext(_ messages: [MemoryMessage], tokenLimit: Int, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared) -> String	Sources/Swarm/Memory/AgentMemory.swift:95
formatMessagesForContext(_:tokenLimit:separator:tokenEstimator:)	swift.func	public	func formatMessagesForContext(_ messages: [MemoryMessage], tokenLimit: Int, separator: String, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared) -> String	Sources/Swarm/Memory/AgentMemory.swift:127
ClosureToolInputGuardrail	swift.struct	public	struct ClosureToolInputGuardrail	Sources/Swarm/Guardrails/ToolGuardrails.swift:165
ClosureToolInputGuardrail.init(name:handler:)	swift.init	public	init(name: String, handler: @escaping (ToolGuardrailData) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/ToolGuardrails.swift:178
ClosureToolInputGuardrail.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/ToolGuardrails.swift:169
ClosureToolInputGuardrail.validate(_:)	swift.method	public	func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:193
MembraneAgentAdapterError	swift.enum	public	enum MembraneAgentAdapterError	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:85
MembraneAgentAdapterError.unsupportedInternalTool(name:)	swift.enum.case	public	case unsupportedInternalTool(name: String)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:86
MembraneAgentAdapterError.invalidInternalToolArguments(name:reason:)	swift.enum.case	public	case invalidInternalToolArguments(name: String, reason: String)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:87
OpenRouterResponseMessage	swift.struct	public	struct OpenRouterResponseMessage	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:536
OpenRouterResponseMessage.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterResponseMessage.init(role:content:toolCalls:)	swift.init	public	init(role: String, content: String?, toolCalls: [OpenRouterToolCall]?)	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:549
OpenRouterResponseMessage.role	swift.property	public	let role: String	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:540
OpenRouterResponseMessage.content	swift.property	public	let content: String?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:543
OpenRouterResponseMessage.toolCalls	swift.property	public	let toolCalls: [OpenRouterToolCall]?	Sources/Swarm/Providers/OpenRouter/OpenRouterTypes.swift:546
OpenRouterRoutingStrategy	swift.enum	public	enum OpenRouterRoutingStrategy	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:321
OpenRouterRoutingStrategy.roundRobin	swift.enum.case	public	case roundRobin	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:326
OpenRouterRoutingStrategy.fallback	swift.enum.case	public	case fallback	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:323
OutputGuardrailsComponent	swift.struct	public	struct OutputGuardrailsComponent	Sources/Swarm/Agents/AgentBuilder.swift:217
OutputGuardrailsComponent.guardrails	swift.property	public	let guardrails: [any OutputGuardrail]	Sources/Swarm/Agents/AgentBuilder.swift:219
OutputGuardrailsComponent.init(_:)	swift.init	public	init(_ guardrails: [any OutputGuardrail])	Sources/Swarm/Agents/AgentBuilder.swift:224
OutputGuardrailsComponent.init(_:)	swift.init	public	init(_ guardrails: any OutputGuardrail...)	Sources/Swarm/Agents/AgentBuilder.swift:231
ToolInputGuardrailBuilder	swift.struct	public	struct ToolInputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:286
ToolInputGuardrailBuilder.name(_:)	swift.method	public	@discardableResult func name(_ name: String) -> ToolInputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:317
ToolInputGuardrailBuilder.build()	swift.method	public	func build() -> ClosureToolInputGuardrail	Sources/Swarm/Guardrails/ToolGuardrails.swift:360
ToolInputGuardrailBuilder.validate(_:)	swift.method	public	@discardableResult func validate(_ handler: @escaping (ToolGuardrailData) async throws -> GuardrailResult) -> ToolInputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:336
ToolInputGuardrailBuilder.init()	swift.init	public	init()	Sources/Swarm/Guardrails/ToolGuardrails.swift:297
ClosureToolOutputGuardrail	swift.struct	public	struct ClosureToolOutputGuardrail	Sources/Swarm/Guardrails/ToolGuardrails.swift:222
ClosureToolOutputGuardrail.init(name:handler:)	swift.init	public	init(name: String, handler: @escaping (ToolGuardrailData, SendableValue) async throws -> GuardrailResult)	Sources/Swarm/Guardrails/ToolGuardrails.swift:235
ClosureToolOutputGuardrail.name	swift.property	public	let name: String	Sources/Swarm/Guardrails/ToolGuardrails.swift:226
ClosureToolOutputGuardrail.validate(_:output:)	swift.method	public	func validate(_ data: ToolGuardrailData, output: SendableValue) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:252
FoundationModelsSummarizer	swift.class	public	actor FoundationModelsSummarizer	Sources/Swarm/Memory/Summarizer.swift:138
FoundationModelsSummarizer.isAvailable	swift.property	public	var isAvailable: Bool { get async }	Sources/Swarm/Memory/Summarizer.swift:141
FoundationModelsSummarizer.resetSession()	swift.method	public	func resetSession()	Sources/Swarm/Memory/Summarizer.swift:185
FoundationModelsSummarizer.summarize(_:maxTokens:)	swift.method	public	func summarize(_ text: String, maxTokens _: Int) async throws -> String	Sources/Swarm/Memory/Summarizer.swift:152
FoundationModelsSummarizer.init()	swift.init	public	init()	Sources/Swarm/Memory/Summarizer.swift:150
InferenceProviderComponent	swift.struct	public	struct InferenceProviderComponent	Sources/Swarm/Agents/AgentBuilder.swift:134
InferenceProviderComponent.provider	swift.property	public	let provider: any InferenceProvider	Sources/Swarm/Agents/AgentBuilder.swift:136
InferenceProviderComponent.init(_:)	swift.init	public	init(_ selection: ConduitProviderSelection)	Sources/Swarm/Agents/AgentBuilder.swift:148
InferenceProviderComponent.init(_:)	swift.init	public	init(_ provider: any InferenceProvider)	Sources/Swarm/Agents/AgentBuilder.swift:141
InferenceStreamingProvider	swift.protocol	public	protocol InferenceStreamingProvider : Sendable	Sources/Swarm/Core/InferenceStreamEvent.swift:39
InferenceStreamingProvider.streamWithToolCalls(prompt:tools:options:)	swift.method	public	func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamEvent, any Error>	Sources/Swarm/Core/InferenceStreamEvent.swift:47
MembraneToolResultBoundary	swift.struct	public	struct MembraneToolResultBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:75
MembraneToolResultBoundary.init(textForConversation:pointerID:)	swift.init	public	init(textForConversation: String, pointerID: String? = nil)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:79
MembraneToolResultBoundary.textForConversation	swift.property	public	let textForConversation: String	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:76
MembraneToolResultBoundary.pointerID	swift.property	public	let pointerID: String?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:77
SwiftDataMemoryDiagnostics	swift.struct	public	struct SwiftDataMemoryDiagnostics	Sources/Swarm/Memory/SwiftDataMemory.swift:278
SwiftDataMemoryDiagnostics.isUnlimited	swift.property	public	let isUnlimited: Bool	Sources/Swarm/Memory/SwiftDataMemory.swift:288
SwiftDataMemoryDiagnostics.maxMessages	swift.property	public	let maxMessages: Int	Sources/Swarm/Memory/SwiftDataMemory.swift:284
SwiftDataMemoryDiagnostics.messageCount	swift.property	public	let messageCount: Int	Sources/Swarm/Memory/SwiftDataMemory.swift:282
SwiftDataMemoryDiagnostics.conversationId	swift.property	public	let conversationId: String	Sources/Swarm/Memory/SwiftDataMemory.swift:280
SwiftDataMemoryDiagnostics.totalConversations	swift.property	public	let totalConversations: Int	Sources/Swarm/Memory/SwiftDataMemory.swift:286
ToolInputValidationHandler	swift.typealias	public	typealias ToolInputValidationHandler = (ToolGuardrailData) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:10
ToolOutputGuardrailBuilder	swift.struct	public	struct ToolOutputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:411
ToolOutputGuardrailBuilder.name(_:)	swift.method	public	@discardableResult func name(_ name: String) -> ToolOutputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:442
ToolOutputGuardrailBuilder.build()	swift.method	public	func build() -> ClosureToolOutputGuardrail	Sources/Swarm/Guardrails/ToolGuardrails.swift:488
ToolOutputGuardrailBuilder.validate(_:)	swift.method	public	@discardableResult func validate(_ handler: @escaping (ToolGuardrailData, SendableValue) async throws -> GuardrailResult) -> ToolOutputGuardrailBuilder	Sources/Swarm/Guardrails/ToolGuardrails.swift:461
ToolOutputGuardrailBuilder.init()	swift.init	public	init()	Sources/Swarm/Guardrails/ToolGuardrails.swift:422
DefaultMembraneAgentAdapter	swift.class	public	actor DefaultMembraneAgentAdapter	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:111
DefaultMembraneAgentAdapter.init(configuration:)	swift.init	public	init(configuration: MembraneFeatureConfiguration = .default)	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:112
DefaultMembraneAgentAdapter.transformToolResult(toolName:output:)	swift.method	public	func transformToolResult(toolName: String, output: String) async throws -> MembraneToolResultBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:193
DefaultMembraneAgentAdapter.handleInternalToolCall(name:arguments:)	swift.method	public	func handleInternalToolCall(name: String, arguments: [String : SendableValue]) async throws -> String?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:221
DefaultMembraneAgentAdapter.snapshotCheckpointData()	swift.method	public	func snapshotCheckpointData() async throws -> Data?	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:296
DefaultMembraneAgentAdapter.plan(prompt:toolSchemas:profile:)	swift.method	public	func plan(prompt: String, toolSchemas: [ToolSchema], profile: ContextProfile) async throws -> MembranePlannedBoundary	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:135
DefaultMembraneAgentAdapter.restore(checkpointData:)	swift.method	public	func restore(checkpointData _: Data?) async throws	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:292
InferenceProviderSummarizer	swift.class	public	actor InferenceProviderSummarizer	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:37
InferenceProviderSummarizer.conversationSummarizer(provider:)	swift.type.method	public	static func conversationSummarizer(provider: any InferenceProvider) -> InferenceProviderSummarizer	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:115
InferenceProviderSummarizer.reasoningSummarizer(provider:)	swift.type.method	public	static func reasoningSummarizer(provider: any InferenceProvider) -> InferenceProviderSummarizer	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:137
InferenceProviderSummarizer.isAvailable	swift.property	public	var isAvailable: Bool { get async }	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:40
InferenceProviderSummarizer.init(provider:systemPrompt:temperature:)	swift.init	public	init(provider: any InferenceProvider, systemPrompt: String = "Summarize the following conversation concisely, preserving key information and context:", temperature: Double = 0.3)	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:50
InferenceProviderSummarizer.summarize(_:maxTokens:)	swift.method	public	func summarize(_ text: String, maxTokens: Int) async throws -> String	Sources/Swarm/Memory/InferenceProviderSummarizer.swift:62
ToolOutputValidationHandler	swift.typealias	public	typealias ToolOutputValidationHandler = (ToolGuardrailData, SendableValue) async throws -> GuardrailResult	Sources/Swarm/Guardrails/ToolGuardrails.swift:13
WaxEmbeddingProviderAdapter	swift.struct	public	struct WaxEmbeddingProviderAdapter	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:38
WaxEmbeddingProviderAdapter.dimensions	swift.property	public	var dimensions: Int { get }	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:58
WaxEmbeddingProviderAdapter.base	swift.property	public	let base: any EmbeddingProvider	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:39
WaxEmbeddingProviderAdapter.embed(_:)	swift.method	public	func embed(_ text: String) async throws -> [Float]	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:60
WaxEmbeddingProviderAdapter.identity	swift.property	public	let identity: EmbeddingIdentity?	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:41
WaxEmbeddingProviderAdapter.normalize	swift.property	public	let normalize: Bool	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:40
WaxEmbeddingProviderAdapter.init(_:normalize:providerName:)	swift.init	public	init(_ base: any EmbeddingProvider, normalize: Bool = false, providerName: String? = "swarm")	Sources/Swarm/Integration/Wax/WaxEmbeddingProviderAdapters.swift:43
CharacterBasedTokenEstimator	swift.struct	public	struct CharacterBasedTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:50
CharacterBasedTokenEstimator.init(charactersPerToken:)	swift.init	public	init(charactersPerToken: Int = 4)	Sources/Swarm/Memory/TokenEstimator.swift:60
CharacterBasedTokenEstimator.charactersPerToken	swift.property	public	let charactersPerToken: Int	Sources/Swarm/Memory/TokenEstimator.swift:55
CharacterBasedTokenEstimator.estimateTokens(for:)	swift.method	public	func estimateTokens(for text: String) -> Int	Sources/Swarm/Memory/TokenEstimator.swift:64
CharacterBasedTokenEstimator.shared	swift.type.property	public	static let shared: CharacterBasedTokenEstimator	Sources/Swarm/Memory/TokenEstimator.swift:52
GuardrailRunnerConfiguration	swift.struct	public	struct GuardrailRunnerConfiguration	Sources/Swarm/Guardrails/GuardrailRunner.swift:33
GuardrailRunnerConfiguration.init(runInParallel:stopOnFirstTripwire:)	swift.init	public	init(runInParallel: Bool = false, stopOnFirstTripwire: Bool = true)	Sources/Swarm/Guardrails/GuardrailRunner.swift:69
GuardrailRunnerConfiguration.runInParallel	swift.property	public	let runInParallel: Bool	Sources/Swarm/Guardrails/GuardrailRunner.swift:45
GuardrailRunnerConfiguration.stopOnFirstTripwire	swift.property	public	let stopOnFirstTripwire: Bool	Sources/Swarm/Guardrails/GuardrailRunner.swift:50
GuardrailRunnerConfiguration.default	swift.type.property	public	static let `default`: GuardrailRunnerConfiguration	Sources/Swarm/Guardrails/GuardrailRunner.swift:37
GuardrailRunnerConfiguration.parallel	swift.type.property	public	static let parallel: GuardrailRunnerConfiguration	Sources/Swarm/Guardrails/GuardrailRunner.swift:40
MembraneFeatureConfiguration	swift.struct	public	struct MembraneFeatureConfiguration	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:11
MembraneFeatureConfiguration.runtimeFeatureFlags	swift.property	public	var runtimeFeatureFlags: [String : Bool]	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:23
MembraneFeatureConfiguration.init(jitMinToolCount:defaultJITLoadCount:pointerThresholdBytes:pointerSummaryMaxChars:runtimeFeatureFlags:runtimeModelAllowlist:)	swift.init	public	init(jitMinToolCount: Int = 12, defaultJITLoadCount: Int = 6, pointerThresholdBytes: Int = 1024, pointerSummaryMaxChars: Int = 240, runtimeFeatureFlags: [String : Bool] = [:], runtimeModelAllowlist: [String] = [])	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:27
MembraneFeatureConfiguration.jitMinToolCount	swift.property	public	var jitMinToolCount: Int	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:14
MembraneFeatureConfiguration.defaultJITLoadCount	swift.property	public	var defaultJITLoadCount: Int	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:15
MembraneFeatureConfiguration.pointerThresholdBytes	swift.property	public	var pointerThresholdBytes: Int	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:16
MembraneFeatureConfiguration.runtimeModelAllowlist	swift.property	public	var runtimeModelAllowlist: [String]	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:25
MembraneFeatureConfiguration.pointerSummaryMaxChars	swift.property	public	var pointerSummaryMaxChars: Int	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:17
MembraneFeatureConfiguration.default	swift.type.property	public	static let `default`: MembraneFeatureConfiguration	Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift:12
ModelSettingsValidationError	swift.enum	public	enum ModelSettingsValidationError	Sources/Swarm/Core/ModelSettings.swift:372
ModelSettingsValidationError.invalidMinP(_:)	swift.enum.case	public	case invalidMinP(Double)	Sources/Swarm/Core/ModelSettings.swift:415
ModelSettingsValidationError.invalidTopK(_:)	swift.enum.case	public	case invalidTopK(Int)	Sources/Swarm/Core/ModelSettings.swift:403
ModelSettingsValidationError.invalidTopP(_:)	swift.enum.case	public	case invalidTopP(Double)	Sources/Swarm/Core/ModelSettings.swift:400
ModelSettingsValidationError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Core/ModelSettings.swift:375
ModelSettingsValidationError.invalidMaxTokens(_:)	swift.enum.case	public	case invalidMaxTokens(Int)	Sources/Swarm/Core/ModelSettings.swift:406
ModelSettingsValidationError.invalidTemperature(_:)	swift.enum.case	public	case invalidTemperature(Double)	Sources/Swarm/Core/ModelSettings.swift:397
ModelSettingsValidationError.invalidPresencePenalty(_:)	swift.enum.case	public	case invalidPresencePenalty(Double)	Sources/Swarm/Core/ModelSettings.swift:412
ModelSettingsValidationError.invalidFrequencyPenalty(_:)	swift.enum.case	public	case invalidFrequencyPenalty(Double)	Sources/Swarm/Core/ModelSettings.swift:409
ModelSettingsValidationError.invalidRepetitionPenalty(_:)	swift.enum.case	public	case invalidRepetitionPenalty(Double)	Sources/Swarm/Core/ModelSettings.swift:418
OpenRouterConfigurationError	swift.enum	public	enum OpenRouterConfigurationError	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:11
OpenRouterConfigurationError.emptyAPIKey	swift.enum.case	public	case emptyAPIKey	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:34
OpenRouterConfigurationError.invalidTopK(_:)	swift.enum.case	public	case invalidTopK(Int)	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:44
OpenRouterConfigurationError.invalidTopP(_:)	swift.enum.case	public	case invalidTopP(Double)	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:42
OpenRouterConfigurationError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:14
OpenRouterConfigurationError.invalidMaxTokens(_:)	swift.enum.case	public	case invalidMaxTokens(Int)	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:38
OpenRouterConfigurationError.invalidTemperature(_:)	swift.enum.case	public	case invalidTemperature(Double)	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:40
OpenRouterConfigurationError.emptyModelIdentifier	swift.enum.case	public	case emptyModelIdentifier	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:36
OpenRouterConfigurationError.conflictingProviderPreferences	swift.enum.case	public	case conflictingProviderPreferences	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:46
OpenRouterFunctionDefinition	swift.struct	public	struct OpenRouterFunctionDefinition	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:46
OpenRouterFunctionDefinition.parameters	swift.property	public	let parameters: OpenRouterJSONSchema	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:54
OpenRouterFunctionDefinition.description	swift.property	public	let description: String	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:51
OpenRouterFunctionDefinition.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterFunctionDefinition.init(name:description:parameters:)	swift.init	public	init(name: String, description: String, parameters: OpenRouterJSONSchema)	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:61
OpenRouterFunctionDefinition.name	swift.property	public	let name: String	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:48
ConversationMemoryDiagnostics	swift.struct	public	struct ConversationMemoryDiagnostics	Sources/Swarm/Memory/ConversationMemory.swift:169
ConversationMemoryDiagnostics.maxMessages	swift.property	public	let maxMessages: Int	Sources/Swarm/Memory/ConversationMemory.swift:173
ConversationMemoryDiagnostics.messageCount	swift.property	public	let messageCount: Int	Sources/Swarm/Memory/ConversationMemory.swift:171
ConversationMemoryDiagnostics.newestTimestamp	swift.property	public	let newestTimestamp: Date?	Sources/Swarm/Memory/ConversationMemory.swift:179
ConversationMemoryDiagnostics.oldestTimestamp	swift.property	public	let oldestTimestamp: Date?	Sources/Swarm/Memory/ConversationMemory.swift:177
ConversationMemoryDiagnostics.utilizationPercent	swift.property	public	let utilizationPercent: Double	Sources/Swarm/Memory/ConversationMemory.swift:175
OpenRouterProviderPreferences	swift.struct	public	struct OpenRouterProviderPreferences	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:230
OpenRouterProviderPreferences.SortPreference	swift.enum	public	enum SortPreference	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:240
OpenRouterProviderPreferences.SortPreference.throughput	swift.enum.case	public	case throughput	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:242
OpenRouterProviderPreferences.SortPreference.price	swift.enum.case	public	case price	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:241
OpenRouterProviderPreferences.SortPreference.latency	swift.enum.case	public	case latency	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:243
OpenRouterProviderPreferences.SortPreference.init(rawValue:)	swift.init	public	init?(rawValue: String)	
OpenRouterProviderPreferences.allowFallbacks	swift.property	public	let allowFallbacks: Bool?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:259
OpenRouterProviderPreferences.dataCollection	swift.property	public	let dataCollection: OpenRouterProviderPreferences.DataCollectionPreference?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:256
OpenRouterProviderPreferences.DataCollectionPreference	swift.enum	public	enum DataCollectionPreference	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:234
OpenRouterProviderPreferences.DataCollectionPreference.deny	swift.enum.case	public	case deny	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:236
OpenRouterProviderPreferences.DataCollectionPreference.allow	swift.enum.case	public	case allow	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:235
OpenRouterProviderPreferences.DataCollectionPreference.init(rawValue:)	swift.init	public	init?(rawValue: String)	
OpenRouterProviderPreferences.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterProviderPreferences.sort	swift.property	public	let sort: OpenRouterProviderPreferences.SortPreference?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:262
OpenRouterProviderPreferences.init(order:allowList:denyList:dataCollection:allowFallbacks:sort:maxPrice:)	swift.init	public	init(order: [String]? = nil, allowList: [String]? = nil, denyList: [String]? = nil, dataCollection: OpenRouterProviderPreferences.DataCollectionPreference? = nil, allowFallbacks: Bool? = nil, sort: OpenRouterProviderPreferences.SortPreference? = nil, maxPrice: Double? = nil) throws	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:280
OpenRouterProviderPreferences.order	swift.property	public	let order: [String]?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:247
OpenRouterProviderPreferences.denyList	swift.property	public	let denyList: [String]?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:253
OpenRouterProviderPreferences.maxPrice	swift.property	public	let maxPrice: Double?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:265
OpenRouterProviderPreferences.allowList	swift.property	public	let allowList: [String]?	Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift:250
OpenRouterToolCallAccumulator	swift.struct	public	struct OpenRouterToolCallAccumulator	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:435
OpenRouterToolCallAccumulator.getCompletedToolCalls()	swift.method	public	func getCompletedToolCalls() -> [OpenRouterToolCallAccumulator.CompletedToolCall]	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:509
OpenRouterToolCallAccumulator.hasToolCalls	swift.property	public	var hasToolCalls: Bool { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:458
OpenRouterToolCallAccumulator.toolCall(at:)	swift.method	public	func toolCall(at index: Int) -> OpenRouterToolCallAccumulator.CompletedToolCall?	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:561
OpenRouterToolCallAccumulator.getAllToolCalls()	swift.method	public	func getAllToolCalls() -> [OpenRouterToolCallAccumulator.CompletedToolCall]	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:540
OpenRouterToolCallAccumulator.CompletedToolCall	swift.struct	public	struct CompletedToolCall	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:439
OpenRouterToolCallAccumulator.CompletedToolCall.init(id:name:arguments:)	swift.init	public	init(id: String, name: String, arguments: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:450
OpenRouterToolCallAccumulator.CompletedToolCall.id	swift.property	public	let id: String	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:441
OpenRouterToolCallAccumulator.CompletedToolCall.name	swift.property	public	let name: String	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:444
OpenRouterToolCallAccumulator.CompletedToolCall.arguments	swift.property	public	let arguments: String	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:447
OpenRouterToolCallAccumulator.accumulate(index:id:name:arguments:)	swift.method	public	mutating func accumulate(index: Int, id: String?, name: String?, arguments: String)	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:479
OpenRouterToolCallAccumulator.count	swift.property	public	var count: Int { get }	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:463
OpenRouterToolCallAccumulator.reset()	swift.method	public	mutating func reset()	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:553
OpenRouterToolCallAccumulator.init()	swift.init	public	init()	Sources/Swarm/Providers/OpenRouter/OpenRouterStreamParser.swift:468
ParallelExecutionErrorStrategy	swift.enum	public	enum ParallelExecutionErrorStrategy	Sources/Swarm/Tools/ToolExecutionResult.swift:37
ParallelExecutionErrorStrategy.continueOnError	swift.enum.case	public	case continueOnError	Sources/Swarm/Tools/ToolExecutionResult.swift:57
ParallelExecutionErrorStrategy.collectErrors	swift.enum.case	public	case collectErrors	Sources/Swarm/Tools/ToolExecutionResult.swift:50
ParallelExecutionErrorStrategy.failFast	swift.enum.case	public	case failFast	Sources/Swarm/Tools/ToolExecutionResult.swift:43
ToolCallStreamingInferenceProvider	swift.protocol	public	protocol ToolCallStreamingInferenceProvider : InferenceProvider	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:26
ToolCallStreamingInferenceProvider.streamWithToolCalls(prompt:tools:options:)	swift.method	public	func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamUpdate, any Error>	Sources/Swarm/Providers/ToolCallStreamingInferenceProvider.swift:28
LLM	swift.enum	public	enum LLM	Sources/Swarm/Providers/Conduit/LLM.swift:12
LLM.openRouter(key:model:)	swift.type.method	public	static func openRouter(key: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:54
LLM.openRouter(apiKey:model:)	swift.type.method	public	static func openRouter(apiKey: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:47
LLM.openRouter(_:)	swift.enum.case	public	case openRouter(LLM.OpenRouterConfig)	Sources/Swarm/Providers/Conduit/LLM.swift:15
LLM.OpenAIConfig	swift.struct	public	struct OpenAIConfig	Sources/Swarm/Providers/Conduit/LLM.swift:189
LLM.OpenAIConfig.model	swift.property	public	var model: String	Sources/Swarm/Providers/Conduit/LLM.swift:191
LLM.OpenAIConfig.init(apiKey:model:)	swift.init	public	init(apiKey: String, model: String)	Sources/Swarm/Providers/Conduit/LLM.swift:194
LLM.OpenAIConfig.apiKey	swift.property	public	var apiKey: String	Sources/Swarm/Providers/Conduit/LLM.swift:190
LLM.OpenAIConfig.advanced	swift.property	public	var advanced: LLM.AdvancedOptions	Sources/Swarm/Providers/Conduit/LLM.swift:192
LLM.AdvancedOptions	swift.struct	public	struct AdvancedOptions	Sources/Swarm/Providers/Conduit/LLM.swift:222
LLM.AdvancedOptions.init(baseConfig:openRouter:)	swift.init	public	init(baseConfig: GenerateConfig = .default, openRouter: LLM.OpenRouterOptions = .default)	Sources/Swarm/Providers/Conduit/LLM.swift:232
LLM.AdvancedOptions.baseConfig	swift.property	public	var baseConfig: GenerateConfig	Sources/Swarm/Providers/Conduit/LLM.swift:228
LLM.AdvancedOptions.openRouter	swift.property	public	var openRouter: LLM.OpenRouterOptions	Sources/Swarm/Providers/Conduit/LLM.swift:230
LLM.AdvancedOptions.default	swift.type.property	public	static let `default`: LLM.AdvancedOptions	Sources/Swarm/Providers/Conduit/LLM.swift:223
LLM.AnthropicConfig	swift.struct	public	struct AnthropicConfig	Sources/Swarm/Providers/Conduit/LLM.swift:200
LLM.AnthropicConfig.model	swift.property	public	var model: String	Sources/Swarm/Providers/Conduit/LLM.swift:202
LLM.AnthropicConfig.init(apiKey:model:)	swift.init	public	init(apiKey: String, model: String)	Sources/Swarm/Providers/Conduit/LLM.swift:205
LLM.AnthropicConfig.apiKey	swift.property	public	var apiKey: String	Sources/Swarm/Providers/Conduit/LLM.swift:201
LLM.AnthropicConfig.advanced	swift.property	public	var advanced: LLM.AdvancedOptions	Sources/Swarm/Providers/Conduit/LLM.swift:203
LLM.OpenRouterConfig	swift.struct	public	struct OpenRouterConfig	Sources/Swarm/Providers/Conduit/LLM.swift:211
LLM.OpenRouterConfig.model	swift.property	public	var model: String	Sources/Swarm/Providers/Conduit/LLM.swift:213
LLM.OpenRouterConfig.init(apiKey:model:)	swift.init	public	init(apiKey: String, model: String)	Sources/Swarm/Providers/Conduit/LLM.swift:216
LLM.OpenRouterConfig.apiKey	swift.property	public	var apiKey: String	Sources/Swarm/Providers/Conduit/LLM.swift:212
LLM.OpenRouterConfig.advanced	swift.property	public	var advanced: LLM.AdvancedOptions	Sources/Swarm/Providers/Conduit/LLM.swift:214
LLM.OpenRouterOptions	swift.struct	public	struct OpenRouterOptions	Sources/Swarm/Providers/Conduit/LLM.swift:241
LLM.OpenRouterOptions.default	swift.type.property	public	static let `default`: LLM.OpenRouterOptions	Sources/Swarm/Providers/Conduit/LLM.swift:242
LLM.OpenRouterOptions.routing	swift.property	public	var routing: OpenRouterRouting?	Sources/Swarm/Providers/Conduit/LLM.swift:244
LLM.OpenRouterOptions.init(routing:)	swift.init	public	init(routing: OpenRouterRouting? = nil)	Sources/Swarm/Providers/Conduit/LLM.swift:246
LLM.streamWithToolCalls(prompt:tools:options:)	swift.method	public	func streamWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamUpdate, any Error>	Sources/Swarm/Providers/Conduit/LLM.swift:143
LLM.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/Conduit/LLM.swift:88
LLM.openAI(key:model:)	swift.type.method	public	static func openAI(key: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:26
LLM.openAI(apiKey:model:)	swift.type.method	public	static func openAI(apiKey: String, model: String = "gpt-4o-mini") -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:19
LLM.openAI(_:)	swift.enum.case	public	case openAI(LLM.OpenAIConfig)	Sources/Swarm/Providers/Conduit/LLM.swift:13
LLM.stream(prompt:options:)	swift.method	public	func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/Conduit/LLM.swift:84
LLM.advanced(_:)	swift.method	public	func advanced(_ update: (inout LLM.AdvancedOptions) -> Void) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:64
LLM.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/Conduit/LLM.swift:80
LLM.anthropic(key:model:)	swift.type.method	public	static func anthropic(key: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:40
LLM.anthropic(apiKey:model:)	swift.type.method	public	static func anthropic(apiKey: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM	Sources/Swarm/Providers/Conduit/LLM.swift:33
LLM.anthropic(_:)	swift.enum.case	public	case anthropic(LLM.AnthropicConfig)	Sources/Swarm/Providers/Conduit/LLM.swift:14
Log	swift.enum	public	enum Log	Sources/Swarm/Core/Logger+Swarm.swift:35
Log.orchestration	swift.type.property	public	static let orchestration: Logger	Sources/Swarm/Core/Logger+Swarm.swift:79
Log.agents	swift.type.property	public	static let agents: Logger	Sources/Swarm/Core/Logger+Swarm.swift:43
Log.memory	swift.type.property	public	static let memory: Logger	Sources/Swarm/Core/Logger+Swarm.swift:52
Log.metrics	swift.type.property	public	static let metrics: Logger	Sources/Swarm/Core/Logger+Swarm.swift:70
Log.tracing	swift.type.property	public	static let tracing: Logger	Sources/Swarm/Core/Logger+Swarm.swift:61
Log.bootstrap(_:)	swift.type.method	public	static func bootstrap(_ factory: @escaping (String) -> any LogHandler)	Sources/Swarm/Core/Logger+Swarm.swift:109
Log.bootstrap()	swift.type.method	public	static func bootstrap()	Sources/Swarm/Core/Logger+Swarm.swift:90
Tool	swift.protocol	public	protocol Tool : Sendable	Sources/Swarm/Tools/TypedToolProtocol.swift:15
Tool.parameters	swift.property	public	var parameters: [ToolParameter] { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:26
Tool.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:23
Tool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:29
Tool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:32
Tool.name	swift.property	public	var name: String { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:20
Tool.Input	swift.associatedtype	public	associatedtype Input : Decodable, Encodable, Sendable	Sources/Swarm/Tools/TypedToolProtocol.swift:16
Tool.Output	swift.associatedtype	public	associatedtype Output : Encodable, Sendable	Sources/Swarm/Tools/TypedToolProtocol.swift:17
Tool.execute(_:)	swift.method	public	func execute(_ input: Self.Input) async throws -> Self.Output	Sources/Swarm/Tools/TypedToolProtocol.swift:35
Tool.asAnyJSONTool()	swift.method	public	func asAnyJSONTool() -> AnyJSONToolAdapter<Self>	Sources/Swarm/Tools/ToolBridging.swift:54
Tool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:39
Tool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:40
Tool.schema	swift.property	public	var schema: ToolSchema { get }	Sources/Swarm/Tools/TypedToolProtocol.swift:42
Tool(_:)	swift.macro	public	@attached(member, names: named(name), named(description), named(parameters), named(init), named(execute), named(_userExecute)) @attached(extension, conformances: AnyJSONTool, Sendable) macro Tool(_ description: String)	Sources/Swarm/Macros/MacroDeclarations.swift:95
Agent	swift.class	public	actor Agent	Sources/Swarm/Agents/Agent.swift:45
Agent.instructions	swift.property	public	nonisolated let instructions: String	Sources/Swarm/Agents/Agent.swift:51
Agent.configuration	swift.property	public	nonisolated let configuration: AgentConfiguration	Sources/Swarm/Agents/Agent.swift:52
Agent.inputGuardrails	swift.property	public	nonisolated let inputGuardrails: [any InputGuardrail]	Sources/Swarm/Agents/Agent.swift:55
Agent.outputGuardrails	swift.property	public	nonisolated let outputGuardrails: [any OutputGuardrail]	Sources/Swarm/Agents/Agent.swift:56
Agent.inferenceProvider	swift.property	public	nonisolated let inferenceProvider: (any InferenceProvider)?	Sources/Swarm/Agents/Agent.swift:54
Agent.guardrailRunnerConfiguration	swift.property	public	nonisolated let guardrailRunnerConfiguration: GuardrailRunnerConfiguration	Sources/Swarm/Agents/Agent.swift:58
Agent.run(_:session:observer:)	swift.method	public	func run(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Agents/Agent.swift:245
Agent.init(name:instructions:tools:inferenceProvider:memory:tracer:configuration:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffAgents:)	swift.init	public	convenience init(name: String, instructions: String = "", tools: [any AnyJSONTool] = [], inferenceProvider: (any InferenceProvider)? = nil, memory: (any Memory)? = nil, tracer: (any Tracer)? = nil, configuration: AgentConfiguration = .default, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffAgents: [any AgentRuntime]) throws	Sources/Swarm/Agents/Agent.swift:1532
Agent.init(name:instructions:tools:inferenceProvider:memory:tracer:configuration:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffs:)	swift.init	public	convenience init(name: String, instructions: String = "", tools: [any AnyJSONTool] = [], inferenceProvider: (any InferenceProvider)? = nil, memory: (any Memory)? = nil, tracer: (any Tracer)? = nil, configuration: AgentConfiguration = .default, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffs: [AnyHandoffConfiguration] = []) throws	Sources/Swarm/Agents/Agent.swift:1470
Agent.init(tools:instructions:configuration:memory:inferenceProvider:tracer:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffAgents:)	swift.init	public	convenience init(tools: [any AnyJSONTool] = [], instructions: String = "", configuration: AgentConfiguration = .default, memory: (any Memory)? = nil, inferenceProvider: (any InferenceProvider)? = nil, tracer: (any Tracer)? = nil, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffAgents: [any AgentRuntime]) throws	Sources/Swarm/Agents/Agent.swift:203
Agent.init(tools:instructions:configuration:memory:inferenceProvider:tracer:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffs:)	swift.init	public	init(tools: [any AnyJSONTool] = [], instructions: String = "", configuration: AgentConfiguration = .default, memory: (any Memory)? = nil, inferenceProvider: (any InferenceProvider)? = nil, tracer: (any Tracer)? = nil, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffs: [AnyHandoffConfiguration] = []) throws	Sources/Swarm/Agents/Agent.swift:80
Agent.init(tools:instructions:configuration:memory:inferenceProvider:tracer:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffs:)	swift.init	public	convenience init(tools: [some Tool] = [], instructions: String = "", configuration: AgentConfiguration = .default, memory: (any Memory)? = nil, inferenceProvider: (any InferenceProvider)? = nil, tracer: (any Tracer)? = nil, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffs: [AnyHandoffConfiguration] = []) throws	Sources/Swarm/Agents/Agent.swift:150
Agent.tools	swift.property	public	nonisolated let tools: [any AnyJSONTool]	Sources/Swarm/Agents/Agent.swift:50
Agent.cancel()	swift.method	public	func cancel() async	Sources/Swarm/Agents/Agent.swift:303
Agent.memory	swift.property	public	nonisolated let memory: (any Memory)?	Sources/Swarm/Agents/Agent.swift:53
Agent.stream(_:session:observer:)	swift.method	public	nonisolated func stream(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Agents/Agent.swift:280
Agent.tracer	swift.property	public	nonisolated let tracer: (any Tracer)?	Sources/Swarm/Agents/Agent.swift:57
Agent.Builder	swift.struct	public	struct Builder	Sources/Swarm/Agents/Agent.swift:1149
Agent.Builder.addHandoff(_:)	swift.method	public	@discardableResult func addHandoff(_ handoff: AnyHandoffConfiguration) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1332
Agent.Builder.instructions(_:)	swift.method	public	@discardableResult func instructions(_ instructions: String) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1222
Agent.Builder.configuration(_:)	swift.method	public	@discardableResult func configuration(_ configuration: AgentConfiguration) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1232
Agent.Builder.inputGuardrails(_:)	swift.method	public	@discardableResult func inputGuardrails(_ guardrails: [any InputGuardrail]) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1272
Agent.Builder.outputGuardrails(_:)	swift.method	public	@discardableResult func outputGuardrails(_ guardrails: [any OutputGuardrail]) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1292
Agent.Builder.withBuiltInTools()	swift.method	public	@discardableResult func withBuiltInTools() -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1212
Agent.Builder.addInputGuardrail(_:)	swift.method	public	@discardableResult func addInputGuardrail(_ guardrail: any InputGuardrail) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1282
Agent.Builder.inferenceProvider(_:)	swift.method	public	@discardableResult func inferenceProvider(_ provider: any InferenceProvider) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1252
Agent.Builder.addOutputGuardrail(_:)	swift.method	public	@discardableResult func addOutputGuardrail(_ guardrail: any OutputGuardrail) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1302
Agent.Builder.guardrailRunnerConfiguration(_:)	swift.method	public	@discardableResult func guardrailRunnerConfiguration(_ configuration: GuardrailRunnerConfiguration) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1312
Agent.Builder.build()	swift.method	public	func build() throws -> Agent	Sources/Swarm/Agents/Agent.swift:1375
Agent.Builder.tools(_:)	swift.method	public	@discardableResult func tools(_ tools: [any AnyJSONTool]) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1163
Agent.Builder.tools(_:)	swift.method	public	@discardableResult func tools(_ tools: [some Tool]) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1173
Agent.Builder.memory(_:)	swift.method	public	@discardableResult func memory(_ memory: any Memory) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1242
Agent.Builder.tracer(_:)	swift.method	public	@discardableResult func tracer(_ tracer: any Tracer) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1262
Agent.Builder.addTool(_:)	swift.method	public	@discardableResult func addTool(_ tool: some Tool) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1203
Agent.Builder.addTool(_:)	swift.method	public	@discardableResult func addTool(_ tool: some AnyJSONTool) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1183
Agent.Builder.addTool(_:)	swift.method	public	@discardableResult func addTool(_ tool: any AnyJSONTool) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1193
Agent.Builder.handoff(to:configure:)	swift.method	public	@discardableResult func handoff<Target>(to target: Target, configure: (HandoffOptions<Target>) -> HandoffOptions<Target> = { $0 }) -> Agent.Builder where Target : AgentRuntime	Sources/Swarm/Agents/Agent.swift:1347
Agent.Builder.handoffs(_:)	swift.method	public	@discardableResult func handoffs(_ handoffs: [AnyHandoffConfiguration]) -> Agent.Builder	Sources/Swarm/Agents/Agent.swift:1322
Agent.Builder.handoffs(_:)	swift.method	public	@discardableResult func handoffs<each Target>(_ targets: repeat each Target) -> Agent.Builder where repeat each Target : AgentRuntime	Sources/Swarm/Agents/Agent.swift:1366
Agent.Builder.init()	swift.init	public	init()	Sources/Swarm/Agents/Agent.swift:1155
Agent.handoffs	swift.property	public	nonisolated var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Agents/Agent.swift:61
Agent.init(_:tools:instructions:configuration:memory:tracer:inputGuardrails:outputGuardrails:guardrailRunnerConfiguration:handoffs:)	swift.init	public	convenience init(_ inferenceProvider: any InferenceProvider, tools: [any AnyJSONTool] = [], instructions: String = "", configuration: AgentConfiguration = .default, memory: (any Memory)? = nil, tracer: (any Tracer)? = nil, inputGuardrails: [any InputGuardrail] = [], outputGuardrails: [any OutputGuardrail] = [], guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default, handoffs: [AnyHandoffConfiguration] = []) throws	Sources/Swarm/Agents/Agent.swift:111
Agent.init(_:)	swift.init	public	convenience init(@AgentBuilder _ content: () -> AgentBuilder.Components) throws	Sources/Swarm/Agents/Agent.swift:1426
Tools	swift.struct	public	struct Tools	Sources/Swarm/Agents/AgentBuilder.swift:51
Tools.tools	swift.property	public	let tools: [any AnyJSONTool]	Sources/Swarm/Agents/AgentBuilder.swift:53
Tools.init(_:)	swift.init	public	init(_ tools: [any AnyJSONTool])	Sources/Swarm/Agents/AgentBuilder.swift:65
Tools.init(_:)	swift.init	public	init(@ToolArrayBuilder _ content: () -> [any AnyJSONTool])	Sources/Swarm/Agents/AgentBuilder.swift:58
Tools.init(_:)	swift.init	public	init<T>(_ tools: [T]) where T : Tool	Sources/Swarm/Agents/AgentBuilder.swift:72
Memory	swift.protocol	public	protocol Memory : Actor	Sources/Swarm/Memory/AgentMemory.swift:47
Memory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/AgentMemory.swift:77
Memory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/AgentMemory.swift:60
Memory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/AgentMemory.swift:80
Memory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/AgentMemory.swift:49
Memory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/AgentMemory.swift:72
Memory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/AgentMemory.swift:55
Prompt(_:)	swift.macro	public	@freestanding(expression) macro Prompt(_ content: String) -> PromptString	Sources/Swarm/Macros/MacroDeclarations.swift:309
Tracer	swift.protocol	public	protocol Tracer : Actor	Sources/Swarm/Observability/AgentTracer.swift:50
Tracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:63
Tracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/AgentTracer.swift:57
Tracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:72
OSLogTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:72
ConsoleTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:72
PrettyConsoleTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:72
Tracer.trace(_:)	swift.method	public	func trace(_ events: [TraceEvent]) async	Sources/Swarm/Observability/AgentTracer.swift:358
AnyTool	swift.struct	public	struct AnyTool	Sources/Swarm/Tools/AnyTool.swift:26
AnyTool.parameters	swift.property	public	var parameters: [ToolParameter] { get }	Sources/Swarm/Tools/AnyTool.swift:31
AnyTool.description	swift.property	public	var description: String { get }	Sources/Swarm/Tools/AnyTool.swift:30
AnyTool.inputGuardrails	swift.property	public	var inputGuardrails: [any ToolInputGuardrail] { get }	Sources/Swarm/Tools/AnyTool.swift:32
AnyTool.outputGuardrails	swift.property	public	var outputGuardrails: [any ToolOutputGuardrail] { get }	Sources/Swarm/Tools/AnyTool.swift:33
AnyTool.name	swift.property	public	var name: String { get }	Sources/Swarm/Tools/AnyTool.swift:29
AnyTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/AnyTool.swift:43
AnyTool.init(_:)	swift.init	public	init(_ tool: some AnyJSONTool)	Sources/Swarm/Tools/AnyTool.swift:35
AnyTool.init(_:)	swift.init	public	init(_ tool: some Tool)	Sources/Swarm/Tools/AnyTool.swift:39
Builder()	swift.macro	public	@attached(member, names: arbitrary) macro Builder()	Sources/Swarm/Macros/MacroDeclarations.swift:417
Session	swift.protocol	public	protocol Session : Actor	Sources/Swarm/Memory/Session.swift:31
Session.clearSession()	swift.method	public	func clearSession() async throws	Sources/Swarm/Memory/Session.swift:99
Session.getItemCount()	swift.method	public	func getItemCount() async throws -> Int	Sources/Swarm/Memory/Session.swift:59
Session.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/Session.swift:50
Session.popItem()	swift.method	public	func popItem() async throws -> MemoryMessage?	Sources/Swarm/Memory/Session.swift:91
Session.addItems(_:)	swift.method	public	func addItems(_ items: [MemoryMessage]) async throws	Sources/Swarm/Memory/Session.swift:82
Session.getItems(limit:)	swift.method	public	func getItems(limit: Int?) async throws -> [MemoryMessage]	Sources/Swarm/Memory/Session.swift:73
Session.itemCount	swift.property	public	var itemCount: Int { get async }	Sources/Swarm/Memory/Session.swift:45
Session.sessionId	swift.property	public	nonisolated var sessionId: String { get }	Sources/Swarm/Memory/Session.swift:39
Session.getAllItems()	swift.method	public	func getAllItems() async throws -> [MemoryMessage]	Sources/Swarm/Memory/Session.swift:201
InMemorySession.getAllItems()	swift.method	public	func getAllItems() async throws -> [MemoryMessage]	Sources/Swarm/Memory/Session.swift:201
PersistentSession.getAllItems()	swift.method	public	func getAllItems() async throws -> [MemoryMessage]	Sources/Swarm/Memory/Session.swift:201
Session.getItemCount()	swift.method	public	func getItemCount() async throws -> Int	Sources/Swarm/Memory/Session.swift:208
Session.addItem(_:)	swift.method	public	func addItem(_ item: MemoryMessage) async throws	Sources/Swarm/Memory/Session.swift:191
InMemorySession.addItem(_:)	swift.method	public	func addItem(_ item: MemoryMessage) async throws	Sources/Swarm/Memory/Session.swift:191
PersistentSession.addItem(_:)	swift.method	public	func addItem(_ item: MemoryMessage) async throws	Sources/Swarm/Memory/Session.swift:191
handoff(to:name:description:onTransfer:transform:when:history:)	swift.func	public	func handoff<T>(to target: T, name: String? = nil, description: String? = nil, onTransfer: OnTransferCallback? = nil, transform: TransformCallback? = nil, when: WhenCallback? = nil, history: HandoffHistory = .none) -> HandoffConfiguration<T> where T : AgentRuntime	Sources/Swarm/Core/Handoff/HandoffBuilder.swift:227
AnyAgent	swift.struct	public	struct AnyAgent	Sources/Swarm/Core/AnyAgent.swift:30
AnyAgent.instructions	swift.property	public	nonisolated var instructions: String { get }	Sources/Swarm/Core/AnyAgent.swift:41
AnyAgent.configuration	swift.property	public	nonisolated var configuration: AgentConfiguration { get }	Sources/Swarm/Core/AnyAgent.swift:46
AnyAgent.inputGuardrails	swift.property	public	nonisolated var inputGuardrails: [any InputGuardrail] { get }	Sources/Swarm/Core/AnyAgent.swift:66
AnyAgent.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AnyAgent.swift:106
AnyAgent.outputGuardrails	swift.property	public	nonisolated var outputGuardrails: [any OutputGuardrail] { get }	Sources/Swarm/Core/AnyAgent.swift:71
AnyAgent.inferenceProvider	swift.property	public	nonisolated var inferenceProvider: (any InferenceProvider)? { get }	Sources/Swarm/Core/AnyAgent.swift:56
AnyAgent.run(_:session:observer:)	swift.method	public	func run(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AnyAgent.swift:95
AnyAgent.tools	swift.property	public	nonisolated var tools: [any AnyJSONTool] { get }	Sources/Swarm/Core/AnyAgent.swift:36
AnyAgent.cancel()	swift.method	public	func cancel() async	Sources/Swarm/Core/AnyAgent.swift:125
AnyAgent.memory	swift.property	public	nonisolated var memory: (any Memory)? { get }	Sources/Swarm/Core/AnyAgent.swift:51
AnyAgent.stream(_:session:observer:)	swift.method	public	nonisolated func stream(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AnyAgent.swift:120
AnyAgent.tracer	swift.property	public	nonisolated var tracer: (any Tracer)? { get }	Sources/Swarm/Core/AnyAgent.swift:61
AnyAgent.handoffs	swift.property	public	nonisolated var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Core/AnyAgent.swift:76
AnyAgent.init(_:)	swift.init	public	init(_ agent: some AgentRuntime)	Sources/Swarm/Core/AnyAgent.swift:82
MCPError	swift.struct	public	struct MCPError	Sources/Swarm/MCP/MCPError.swift:34
MCPError.parseError(_:)	swift.type.method	public	static func parseError(_ details: String? = nil) -> MCPError	Sources/Swarm/MCP/MCPError.swift:93
MCPError.internalError(_:)	swift.type.method	public	static func internalError(_ details: String? = nil) -> MCPError	Sources/Swarm/MCP/MCPError.swift:139
MCPError.invalidParams(_:)	swift.type.method	public	static func invalidParams(_ details: String? = nil) -> MCPError	Sources/Swarm/MCP/MCPError.swift:128
MCPError.invalidRequest(_:)	swift.type.method	public	static func invalidRequest(_ details: String? = nil) -> MCPError	Sources/Swarm/MCP/MCPError.swift:104
MCPError.methodNotFound(_:)	swift.type.method	public	static func methodNotFound(_ method: String? = nil) -> MCPError	Sources/Swarm/MCP/MCPError.swift:115
MCPError.parseErrorCode	swift.type.property	public	static let parseErrorCode: Int	Sources/Swarm/MCP/MCPError.swift:71
MCPError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/MCP/MCPError.swift:162
MCPError.errorDescription	swift.property	public	var errorDescription: String? { get }	Sources/Swarm/MCP/MCPError.swift:150
MCPError.internalErrorCode	swift.type.property	public	static let internalErrorCode: Int	Sources/Swarm/MCP/MCPError.swift:83
MCPError.invalidParamsCode	swift.type.property	public	static let invalidParamsCode: Int	Sources/Swarm/MCP/MCPError.swift:80
MCPError.invalidRequestCode	swift.type.property	public	static let invalidRequestCode: Int	Sources/Swarm/MCP/MCPError.swift:74
MCPError.methodNotFoundCode	swift.type.property	public	static let methodNotFoundCode: Int	Sources/Swarm/MCP/MCPError.swift:77
MCPError.init(code:message:data:)	swift.init	public	init(code: Int, message: String, data: SendableValue? = nil)	Sources/Swarm/MCP/MCPError.swift:60
MCPError.code	swift.property	public	let code: Int	Sources/Swarm/MCP/MCPError.swift:39
MCPError.data	swift.property	public	let data: SendableValue?	Sources/Swarm/MCP/MCPError.swift:50
MCPError.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/MCP/MCPError.swift:176
MCPError.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/MCP/MCPError.swift:183
MCPError.message	swift.property	public	let message: String	Sources/Swarm/MCP/MCPError.swift:44
ToolCall	swift.struct	public	struct ToolCall	Sources/Swarm/Core/AgentEvent.swift:166
ToolCall.providerCallId	swift.property	public	let providerCallId: String?	Sources/Swarm/Core/AgentEvent.swift:173
ToolCall.description	swift.property	public	var description: String { get }	Sources/Swarm/Core/AgentEvent.swift:299
ToolCall.init(id:providerCallId:toolName:arguments:timestamp:)	swift.init	public	init(id: UUID = UUID(), providerCallId: String? = nil, toolName: String, arguments: [String : SendableValue] = [:], timestamp: Date = Date())	Sources/Swarm/Core/AgentEvent.swift:191
ToolCall.id	swift.property	public	let id: UUID	Sources/Swarm/Core/AgentEvent.swift:168
ToolCall.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	Sources/Swarm/Core/AgentEvent.swift:213
ToolCall.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	Sources/Swarm/Core/AgentEvent.swift:222
ToolCall.toolName	swift.property	public	let toolName: String	Sources/Swarm/Core/AgentEvent.swift:176
ToolCall.arguments	swift.property	public	let arguments: [String : SendableValue]	Sources/Swarm/Core/AgentEvent.swift:179
ToolCall.timestamp	swift.property	public	let timestamp: Date	Sources/Swarm/Core/AgentEvent.swift:182
ToolStep	swift.struct	public	struct ToolStep	Sources/Swarm/Tools/ToolChainBuilder.swift:158
ToolStep.retry(count:delay:)	swift.method	public	func retry(count: Int, delay: Duration = .seconds(1)) -> ToolStep	Sources/Swarm/Tools/ToolChainBuilder.swift:184
ToolStep.execute(input:)	swift.method	public	func execute(input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:233
ToolStep.timeout(_:)	swift.method	public	func timeout(_ duration: Duration) -> ToolStep	Sources/Swarm/Tools/ToolChainBuilder.swift:200
ToolStep.fallback(to:)	swift.method	public	func fallback(to tool: any AnyJSONTool) -> ToolStep	Sources/Swarm/Tools/ToolChainBuilder.swift:216
ToolStep.init(_:)	swift.init	public	init(_ tool: any AnyJSONTool)	Sources/Swarm/Tools/ToolChainBuilder.swift:166
Workflow	swift.struct	public	struct Workflow	Sources/Swarm/Workflow/Workflow.swift:4
Workflow.repeatUntil(maxIterations:_:)	swift.method	public	func repeatUntil(maxIterations: Int = 100, _ condition: @escaping (AgentResult) -> Bool) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:45
Workflow.MergeStrategy	swift.enum	public	enum MergeStrategy	Sources/Swarm/Workflow/Workflow.swift:12
Workflow.MergeStrategy.structured	swift.enum.case	public	case structured	Sources/Swarm/Workflow/Workflow.swift:15
Workflow.MergeStrategy.first	swift.enum.case	public	case first	Sources/Swarm/Workflow/Workflow.swift:20
Workflow.MergeStrategy.custom(_:)	swift.enum.case	public	case custom(([AgentResult]) -> String)	Sources/Swarm/Workflow/Workflow.swift:22
Workflow.MergeStrategy.indexed	swift.enum.case	public	case indexed	Sources/Swarm/Workflow/Workflow.swift:18
Workflow.run(_:)	swift.method	public	func run(_ input: String) async throws -> AgentResult	Sources/Swarm/Workflow/Workflow.swift:67
Workflow.step(_:)	swift.method	public	func step(_ agent: some AgentRuntime) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:27
Workflow.route(_:)	swift.method	public	func route(_ condition: @escaping (String) -> (any AgentRuntime)?) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:39
Workflow.stream(_:)	swift.method	public	func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Workflow/Workflow.swift:73
Workflow.Durable	swift.struct	public	struct Durable	Sources/Swarm/Workflow/Workflow+Durable.swift:8
Workflow.durable	swift.property	public	var durable: Workflow.Durable { get }	Sources/Swarm/Workflow/Workflow+Durable.swift:6
Workflow.timeout(_:)	swift.method	public	func timeout(_ duration: Duration) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:55
Workflow.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:61
Workflow.parallel(_:merge:)	swift.method	public	func parallel(_ agents: [any AgentRuntime], merge: Workflow.MergeStrategy = .structured) -> Workflow	Sources/Swarm/Workflow/Workflow.swift:33
Workflow.init()	swift.init	public	init()	Sources/Swarm/Workflow/Workflow.swift:25
AgentTool	swift.struct	public	struct AgentTool	Sources/Swarm/Tools/AgentTool.swift:35
AgentTool.parameters	swift.property	public	let parameters: [ToolParameter]	Sources/Swarm/Tools/AgentTool.swift:40
AgentTool.description	swift.property	public	let description: String	Sources/Swarm/Tools/AgentTool.swift:39
AgentTool.name	swift.property	public	let name: String	Sources/Swarm/Tools/AgentTool.swift:38
AgentTool.init(agent:name:description:)	swift.init	public	init(agent: any AgentRuntime, name: String? = nil, description: String? = nil)	Sources/Swarm/Tools/AgentTool.swift:68
AgentTool.execute(arguments:)	swift.method	public	func execute(arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/AgentTool.swift:42
AnyMemory	swift.class	public	actor AnyMemory	Sources/Swarm/Memory/AgentMemory.swift:167
AnyMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Memory/AgentMemory.swift:202
AnyMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Memory/AgentMemory.swift:194
AnyMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Memory/AgentMemory.swift:206
AnyMemory.count	swift.property	public	var count: Int { get async }	Sources/Swarm/Memory/AgentMemory.swift:170
AnyMemory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Memory/AgentMemory.swift:198
AnyMemory.isEmpty	swift.property	public	var isEmpty: Bool { get async }	Sources/Swarm/Memory/AgentMemory.swift:176
AnyMemory.init(_:)	swift.init	public	init(_ memory: some Memory)	Sources/Swarm/Memory/AgentMemory.swift:185
AnyTracer	swift.class	public	actor AnyTracer	Sources/Swarm/Observability/AgentTracer.swift:371
AnyTracer.flush()	swift.method	public	func flush() async	Sources/Swarm/Observability/AgentTracer.swift:390
AnyTracer.trace(_:)	swift.method	public	func trace(_ event: TraceEvent) async	Sources/Swarm/Observability/AgentTracer.swift:386
AnyTracer.init(_:)	swift.init	public	init(_ tracer: some Tracer)	Sources/Swarm/Observability/AgentTracer.swift:377
ErrorInfo	swift.struct	public	struct ErrorInfo	Sources/Swarm/Observability/TraceEvent.swift:100
ErrorInfo.underlyingError	swift.property	public	let underlyingError: String?	Sources/Swarm/Observability/TraceEvent.swift:104
ErrorInfo.stackTrace	swift.property	public	let stackTrace: [String]?	Sources/Swarm/Observability/TraceEvent.swift:103
ErrorInfo.init(from:)	swift.init	public	init(from error: any Error)	Sources/Swarm/Observability/TraceEvent.swift:120
ErrorInfo.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ErrorInfo.init(type:message:stackTrace:underlyingError:)	swift.init	public	init(type: String, message: String, stackTrace: [String]? = nil, underlyingError: String? = nil)	Sources/Swarm/Observability/TraceEvent.swift:107
ErrorInfo.type	swift.property	public	let type: String	Sources/Swarm/Observability/TraceEvent.swift:101
ErrorInfo.message	swift.property	public	let message: String	Sources/Swarm/Observability/TraceEvent.swift:102
EventKind	swift.enum	public	enum EventKind	Sources/Swarm/Observability/TraceEvent.swift:30
EventKind.agentError	swift.enum.case	public	case agentError	Sources/Swarm/Observability/TraceEvent.swift:36
EventKind.agentStart	swift.enum.case	public	case agentStart	Sources/Swarm/Observability/TraceEvent.swift:32
EventKind.checkpoint	swift.enum.case	public	case checkpoint	Sources/Swarm/Observability/TraceEvent.swift:60
EventKind.memoryRead	swift.enum.case	public	case memoryRead	Sources/Swarm/Observability/TraceEvent.swift:55
EventKind.toolResult	swift.enum.case	public	case toolResult	Sources/Swarm/Observability/TraceEvent.swift:43
EventKind.memoryWrite	swift.enum.case	public	case memoryWrite	Sources/Swarm/Observability/TraceEvent.swift:57
EventKind.agentComplete	swift.enum.case	public	case agentComplete	Sources/Swarm/Observability/TraceEvent.swift:34
EventKind.agentCancelled	swift.enum.case	public	case agentCancelled	Sources/Swarm/Observability/TraceEvent.swift:38
EventKind.plan	swift.enum.case	public	case plan	Sources/Swarm/Observability/TraceEvent.swift:52
EventKind.custom	swift.enum.case	public	case custom	Sources/Swarm/Observability/TraceEvent.swift:64
EventKind.metric	swift.enum.case	public	case metric	Sources/Swarm/Observability/TraceEvent.swift:62
EventKind.thought	swift.enum.case	public	case thought	Sources/Swarm/Observability/TraceEvent.swift:48
EventKind.decision	swift.enum.case	public	case decision	Sources/Swarm/Observability/TraceEvent.swift:50
EventKind.init(rawValue:)	swift.init	public	init?(rawValue: String)	
EventKind.toolCall	swift.enum.case	public	case toolCall	Sources/Swarm/Observability/TraceEvent.swift:41
EventKind.toolError	swift.enum.case	public	case toolError	Sources/Swarm/Observability/TraceEvent.swift:45
Guardrail	swift.protocol	public	protocol Guardrail : Sendable	Sources/Swarm/Guardrails/Guardrail.swift:12
Guardrail.name	swift.property	public	var name: String { get }	Sources/Swarm/Guardrails/Guardrail.swift:14
MCPClient	swift.class	public	actor MCPClient	Sources/Swarm/MCP/MCPClient.swift:56
MCPClient.getAllTools()	swift.method	public	func getAllTools() async throws -> [any AnyJSONTool]	Sources/Swarm/MCP/MCPClient.swift:174
MCPClient.readResource(uri:)	swift.method	public	func readResource(uri: String) async throws -> MCPResourceContent	Sources/Swarm/MCP/MCPClient.swift:468
MCPClient.refreshTools()	swift.method	public	func refreshTools() async throws -> [any AnyJSONTool]	Sources/Swarm/MCP/MCPClient.swift:279
MCPClient.removeServer(named:)	swift.method	public	func removeServer(named name: String) async throws	Sources/Swarm/MCP/MCPClient.swift:135
MCPClient.getAllResources()	swift.method	public	func getAllResources() async throws -> [MCPResource]	Sources/Swarm/MCP/MCPClient.swift:340
MCPClient.invalidateCache()	swift.method	public	func invalidateCache()	Sources/Swarm/MCP/MCPClient.swift:295
MCPClient.connectedServers	swift.property	public	var connectedServers: [String] { get }	Sources/Swarm/MCP/MCPClient.swift:68
MCPClient.refreshResources()	swift.method	public	func refreshResources() async throws -> [MCPResource]	Sources/Swarm/MCP/MCPClient.swift:403
MCPClient.setResourceCacheTTL(_:)	swift.method	public	func setResourceCacheTTL(_ ttl: TimeInterval)	Sources/Swarm/MCP/MCPClient.swift:446
MCPClient.invalidateResourceCache()	swift.method	public	func invalidateResourceCache()	Sources/Swarm/MCP/MCPClient.swift:425
MCPClient.closeAll()	swift.method	public	func closeAll() async throws	Sources/Swarm/MCP/MCPClient.swift:548
MCPClient.addServer(_:)	swift.method	public	func addServer(_ server: any MCPServer) async throws	Sources/Swarm/MCP/MCPClient.swift:99
MCPClient.init()	swift.init	public	init()	Sources/Swarm/MCP/MCPClient.swift:77
MCPServer	swift.protocol	public	protocol MCPServer : Sendable	Sources/Swarm/MCP/MCPServer.swift:90
MCPServer.initialize()	swift.method	public	func initialize() async throws -> MCPCapabilities	Sources/Swarm/MCP/MCPServer.swift:138
MCPServer.capabilities	swift.property	public	var capabilities: MCPCapabilities { get async }	Sources/Swarm/MCP/MCPServer.swift:112
MCPServer.readResource(uri:)	swift.method	public	func readResource(uri: String) async throws -> MCPResourceContent	Sources/Swarm/MCP/MCPServer.swift:265
MCPServer.listResources()	swift.method	public	func listResources() async throws -> [MCPResource]	Sources/Swarm/MCP/MCPServer.swift:239
MCPServer.name	swift.property	public	var name: String { get }	Sources/Swarm/MCP/MCPServer.swift:95
MCPServer.close()	swift.method	public	func close() async throws	Sources/Swarm/MCP/MCPServer.swift:159
MCPServer.callTool(name:arguments:)	swift.method	public	func callTool(name: String, arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/MCP/MCPServer.swift:216
MCPServer.listTools()	swift.method	public	func listTools() async throws -> [ToolSchema]	Sources/Swarm/MCP/MCPServer.swift:182
MCPServer.requireToolsCapability()	swift.method	public	func requireToolsCapability() async throws	Sources/Swarm/MCP/MCPServer.swift:276
HTTPMCPServer.requireToolsCapability()	swift.method	public	func requireToolsCapability() async throws	Sources/Swarm/MCP/MCPServer.swift:276
MCPServer.requireResourcesCapability()	swift.method	public	func requireResourcesCapability() async throws	Sources/Swarm/MCP/MCPServer.swift:288
HTTPMCPServer.requireResourcesCapability()	swift.method	public	func requireResourcesCapability() async throws	Sources/Swarm/MCP/MCPServer.swift:288
Parameter(_:description:type:required:default:)	swift.func	public	func Parameter(_ name: String, description: String, type: ToolParameter.ParameterType, required: Bool = true, default defaultValue: Bool) -> ToolParameter	Sources/Swarm/Tools/ToolParameterBuilder.swift:194
Parameter(_:description:type:required:default:)	swift.func	public	func Parameter(_ name: String, description: String, type: ToolParameter.ParameterType, required: Bool = true, default defaultValue: SendableValue? = nil) -> ToolParameter	Sources/Swarm/Tools/ToolParameterBuilder.swift:119
Parameter(_:description:type:required:default:)	swift.func	public	func Parameter(_ name: String, description: String, type: ToolParameter.ParameterType, required: Bool = true, default defaultValue: String) -> ToolParameter	Sources/Swarm/Tools/ToolParameterBuilder.swift:169
Parameter(_:description:type:required:default:)	swift.func	public	func Parameter(_ name: String, description: String, type: ToolParameter.ParameterType, required: Bool = true, default defaultValue: Double) -> ToolParameter	Sources/Swarm/Tools/ToolParameterBuilder.swift:219
Parameter(_:description:type:required:default:)	swift.func	public	func Parameter(_ name: String, description: String, type: ToolParameter.ParameterType, required: Bool = true, default defaultValue: Int) -> ToolParameter	Sources/Swarm/Tools/ToolParameterBuilder.swift:144
Parameter(_:default:oneOf:)	swift.macro	public	@attached(peer) macro Parameter(_ description: String, default defaultValue: Any? = nil, oneOf options: [String]? = nil)	Sources/Swarm/Macros/MacroDeclarations.swift:142
StepError	swift.struct	public	struct StepError	Sources/Swarm/Resilience/FallbackChain.swift:11
StepError.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Resilience/FallbackChain.swift:42
StepError.==(_:_:)	swift.func.op	public	static func == (lhs: StepError, rhs: StepError) -> Bool	Sources/Swarm/Resilience/FallbackChain.swift:32
StepError.error	swift.property	public	let error: any Error	Sources/Swarm/Resilience/FallbackChain.swift:19
StepError.init(stepName:stepIndex:error:)	swift.init	public	init(stepName: String, stepIndex: Int, error: any Error)	Sources/Swarm/Resilience/FallbackChain.swift:26
StepError.stepName	swift.property	public	let stepName: String	Sources/Swarm/Resilience/FallbackChain.swift:13
StepError.stepIndex	swift.property	public	let stepIndex: Int	Sources/Swarm/Resilience/FallbackChain.swift:16
ToolChain	swift.struct	public	struct ToolChain	Sources/Swarm/Tools/ToolChainBuilder.swift:501
ToolChain.execute(with:)	swift.method	public	func execute(with arguments: [String : SendableValue]) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:520
ToolChain.execute(query:)	swift.method	public	func execute(query: String) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:531
ToolChain.execute(_:)	swift.method	public	func execute(_ input: SendableValue) async throws -> SendableValue	Sources/Swarm/Tools/ToolChainBuilder.swift:540
ToolChain.init(_:)	swift.init	public	init(@ToolChainBuilder _ content: () -> [any ToolChainStep])	Sources/Swarm/Tools/ToolChainBuilder.swift:509
TraceSpan	swift.struct	public	struct TraceSpan	Sources/Swarm/Observability/TraceSpan.swift:38
TraceSpan.parentSpanId	swift.property	public	let parentSpanId: UUID?	Sources/Swarm/Observability/TraceSpan.swift:44
TraceSpan.description	swift.property	public	var description: String { get }	Sources/Swarm/Observability/TraceSpan.swift:135
TraceSpan.debugDescription	swift.property	public	var debugDescription: String { get }	Sources/Swarm/Observability/TraceSpan.swift:154
TraceSpan.init(id:parentSpanId:name:startTime:endTime:status:metadata:)	swift.init	public	init(id: UUID = UUID(), parentSpanId: UUID? = nil, name: String, startTime: Date = Date(), endTime: Date? = nil, status: SpanStatus = .active, metadata: [String : SendableValue] = [:])	Sources/Swarm/Observability/TraceSpan.swift:85
TraceSpan.id	swift.property	public	let id: UUID	Sources/Swarm/Observability/TraceSpan.swift:40
TraceSpan.name	swift.property	public	let name: String	Sources/Swarm/Observability/TraceSpan.swift:47
TraceSpan.status	swift.property	public	let status: SpanStatus	Sources/Swarm/Observability/TraceSpan.swift:57
TraceSpan.endTime	swift.property	public	let endTime: Date?	Sources/Swarm/Observability/TraceSpan.swift:54
TraceSpan.duration	swift.property	public	var duration: TimeInterval? { get }	Sources/Swarm/Observability/TraceSpan.swift:66
TraceSpan.metadata	swift.property	public	let metadata: [String : SendableValue]	Sources/Swarm/Observability/TraceSpan.swift:60
TraceSpan.completed(status:)	swift.method	public	func completed(status: SpanStatus = .ok) -> TraceSpan	Sources/Swarm/Observability/TraceSpan.swift:119
TraceSpan.startTime	swift.property	public	let startTime: Date	Sources/Swarm/Observability/TraceSpan.swift:50
Traceable()	swift.macro	public	@attached(peer, names: named(executeWithTracing)) macro Traceable()	Sources/Swarm/Macros/MacroDeclarations.swift:281
Verbosity	swift.enum	public	enum Verbosity	Sources/Swarm/Core/ModelSettings.swift:503
Verbosity.low	swift.enum.case	public	case low	Sources/Swarm/Core/ModelSettings.swift:505
Verbosity.high	swift.enum.case	public	case high	Sources/Swarm/Core/ModelSettings.swift:511
Verbosity.medium	swift.enum.case	public	case medium	Sources/Swarm/Core/ModelSettings.swift:508
Verbosity.init(rawValue:)	swift.init	public	init?(rawValue: String)	
WaxMemory	swift.class	public	actor WaxMemory	Sources/Swarm/Integration/Wax/WaxMemory.swift:6
WaxMemory.endMemorySession()	swift.method	public	func endMemorySession() async	Sources/Swarm/Integration/Wax/WaxMemory.swift:126
WaxMemory.beginMemorySession()	swift.method	public	func beginMemorySession() async	Sources/Swarm/Integration/Wax/WaxMemory.swift:121
WaxMemory.allMessages()	swift.method	public	func allMessages() async -> [MemoryMessage]	Sources/Swarm/Integration/Wax/WaxMemory.swift:96
WaxMemory.Configuration	swift.struct	public	struct Configuration	Sources/Swarm/Integration/Wax/WaxMemory.swift:10
WaxMemory.Configuration.promptTitle	swift.property	public	var promptTitle: String	Sources/Swarm/Integration/Wax/WaxMemory.swift:16
WaxMemory.Configuration.promptGuidance	swift.property	public	var promptGuidance: String?	Sources/Swarm/Integration/Wax/WaxMemory.swift:17
WaxMemory.Configuration.tokenEstimator	swift.property	public	var tokenEstimator: any TokenEstimator	Sources/Swarm/Integration/Wax/WaxMemory.swift:15
WaxMemory.Configuration.orchestratorConfig	swift.property	public	var orchestratorConfig: OrchestratorConfig	Sources/Swarm/Integration/Wax/WaxMemory.swift:13
WaxMemory.Configuration.init(orchestratorConfig:queryEmbeddingPolicy:tokenEstimator:promptTitle:promptGuidance:)	swift.init	public	init(orchestratorConfig: OrchestratorConfig = .default, queryEmbeddingPolicy: MemoryOrchestrator.QueryEmbeddingPolicy = .ifAvailable, tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared, promptTitle: String = "Wax Memory Context (primary)", promptGuidance: String? = "Use Wax memory context as the primary source of truth. Prefer it before calling tools.")	Sources/Swarm/Integration/Wax/WaxMemory.swift:19
WaxMemory.Configuration.queryEmbeddingPolicy	swift.property	public	var queryEmbeddingPolicy: MemoryOrchestrator.QueryEmbeddingPolicy	Sources/Swarm/Integration/Wax/WaxMemory.swift:14
WaxMemory.Configuration.default	swift.type.property	public	static let `default`: WaxMemory.Configuration	Sources/Swarm/Integration/Wax/WaxMemory.swift:11
WaxMemory.memoryPriority	swift.property	public	nonisolated let memoryPriority: MemoryPriorityHint	Sources/Swarm/Integration/Wax/WaxMemory.swift:39
WaxMemory.memoryPromptTitle	swift.property	public	nonisolated let memoryPromptTitle: String	Sources/Swarm/Integration/Wax/WaxMemory.swift:37
WaxMemory.memoryPromptGuidance	swift.property	public	nonisolated let memoryPromptGuidance: String?	Sources/Swarm/Integration/Wax/WaxMemory.swift:38
WaxMemory.add(_:)	swift.method	public	func add(_ message: MemoryMessage) async	Sources/Swarm/Integration/Wax/WaxMemory.swift:72
WaxMemory.init(url:embedder:configuration:)	swift.init	public	init(url: URL, embedder: (any EmbeddingProvider)? = nil, configuration: WaxMemory.Configuration = .default) async throws	Sources/Swarm/Integration/Wax/WaxMemory.swift:46
WaxMemory.clear()	swift.method	public	func clear() async	Sources/Swarm/Integration/Wax/WaxMemory.swift:100
WaxMemory.count	swift.property	public	var count: Int { get }	Sources/Swarm/Integration/Wax/WaxMemory.swift:34
WaxMemory.context(for:tokenLimit:)	swift.method	public	func context(for query: String, tokenLimit: Int) async -> String	Sources/Swarm/Integration/Wax/WaxMemory.swift:86
WaxMemory.isEmpty	swift.property	public	var isEmpty: Bool { get }	Sources/Swarm/Integration/Wax/WaxMemory.swift:35
Swarm	swift.enum	public	enum Swarm	Sources/Swarm/Swarm.swift:50
Swarm.Configuration	swift.class	public	actor Configuration	Sources/Swarm/Core/SwarmConfiguration.swift:26
Swarm.cloudProvider	swift.type.property	public	static var cloudProvider: (any InferenceProvider)? { get async }	Sources/Swarm/Core/SwarmConfiguration.swift:52
Swarm.defaultProvider	swift.type.property	public	static var defaultProvider: (any InferenceProvider)? { get async }	Sources/Swarm/Core/SwarmConfiguration.swift:47
Swarm.minimumiOSVersion	swift.type.property	public	static let minimumiOSVersion: String	Sources/Swarm/Swarm.swift:58
Swarm.minimumMacOSVersion	swift.type.property	public	static let minimumMacOSVersion: String	Sources/Swarm/Swarm.swift:55
Swarm.reset()	swift.type.method	public	static func reset() async	Sources/Swarm/Core/SwarmConfiguration.swift:81
Swarm.version	swift.type.property	public	static let version: String	Sources/Swarm/Swarm.swift:52
Swarm.configure(cloudProvider:)	swift.type.method	public	static func configure(cloudProvider: some InferenceProvider) async	Sources/Swarm/Core/SwarmConfiguration.swift:76
Swarm.configure(provider:)	swift.type.method	public	static func configure(provider: some InferenceProvider) async	Sources/Swarm/Core/SwarmConfiguration.swift:67
PersistedMessage.persistentModelID	swift.property	public	var persistentModelID: PersistentIdentifier { get }	
PersistedMessage.createBackingData()	swift.type.method	public	static func createBackingData<P>() -> some BackingData<P> where P : PersistentModel 	
PersistedMessage.hasChanges	swift.property	public	var hasChanges: Bool { get }	
PersistedMessage.modelContext	swift.property	public	var modelContext: ModelContext? { get }	
PersistedMessage.getTransformableValue(forKey:)	swift.method	public	func getTransformableValue<Value>(forKey: KeyPath<Self, Value>) -> Value	
PersistedMessage.setTransformableValue(forKey:to:)	swift.method	public	func setTransformableValue<Value>(forKey: KeyPath<Self, Value>, to newValue: Value)	
PersistedMessage.==(_:_:)	swift.func.op	public	static func == (lhs: Self, rhs: Self) -> Bool	
PersistedMessage.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
PersistedMessage.getValue(forKey:)	swift.method	public	func getValue<Value>(forKey: KeyPath<Self, Value?>) -> Value? where Value : PersistentModel	
PersistedMessage.getValue(forKey:)	swift.method	public	func getValue<Value, OtherModel>(forKey: KeyPath<Self, Value>) -> Value where Value : RelationshipCollection, OtherModel == Value.PersistentElement	
PersistedMessage.getValue(forKey:)	swift.method	public	func getValue<Value>(forKey: KeyPath<Self, Value>) -> Value where Value : PersistentModel	
PersistedMessage.getValue(forKey:)	swift.method	public	func getValue<Value, OtherModel>(forKey: KeyPath<Self, Value>) -> Value where Value : Decodable, Value : RelationshipCollection, OtherModel == Value.PersistentElement	
PersistedMessage.getValue(forKey:)	swift.method	public	func getValue<Value>(forKey: KeyPath<Self, Value>) -> Value where Value : Decodable	
PersistedMessage.setValue(forKey:to:)	swift.method	public	func setValue<Value, OtherModel>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : RelationshipCollection, OtherModel == Value.PersistentElement	
PersistedMessage.setValue(forKey:to:)	swift.method	public	func setValue<Value>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : PersistentModel	
PersistedMessage.setValue(forKey:to:)	swift.method	public	func setValue<Value, OtherModel>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : Encodable, Value : RelationshipCollection, OtherModel == Value.PersistentElement	
PersistedMessage.setValue(forKey:to:)	swift.method	public	func setValue<Value>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : Encodable	
PersistedMessage.setValue(forKey:to:)	swift.method	public	func setValue<Value>(forKey: KeyPath<Self, Value?>, to newValue: Value?) where Value : PersistentModel	
PersistedMessage.isDeleted	swift.property	public	var isDeleted: Bool { get }	
EventLevel.>(_:_:)	swift.func.op	public	static func > (lhs: Self, rhs: Self) -> Bool	
MemoryPriority.>(_:_:)	swift.func.op	public	static func > (lhs: Self, rhs: Self) -> Bool	
EventLevel.>=(_:_:)	swift.func.op	public	static func >= (lhs: Self, rhs: Self) -> Bool	
MemoryPriority.>=(_:_:)	swift.func.op	public	static func >= (lhs: Self, rhs: Self) -> Bool	
EventLevel.<=(_:_:)	swift.func.op	public	static func <= (lhs: Self, rhs: Self) -> Bool	
MemoryPriority.<=(_:_:)	swift.func.op	public	static func <= (lhs: Self, rhs: Self) -> Bool	
EventLevel...<(_:_:)	swift.func.op	public	static func ..< (minimum: Self, maximum: Self) -> Range<Self>	
MemoryPriority...<(_:_:)	swift.func.op	public	static func ..< (minimum: Self, maximum: Self) -> Range<Self>	
EventLevel...<(_:)	swift.func.op	public	static func ..< (maximum: Self) -> PartialRangeUpTo<Self>	
MemoryPriority...<(_:)	swift.func.op	public	static func ..< (maximum: Self) -> PartialRangeUpTo<Self>	
EventLevel....(_:)	swift.func.op	public	static func ... (minimum: Self) -> PartialRangeFrom<Self>	
MemoryPriority....(_:)	swift.func.op	public	static func ... (minimum: Self) -> PartialRangeFrom<Self>	
EventLevel....(_:_:)	swift.func.op	public	static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self>	
MemoryPriority....(_:_:)	swift.func.op	public	static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self>	
EventLevel....(_:)	swift.func.op	public	static func ... (maximum: Self) -> PartialRangeThrough<Self>	
MemoryPriority....(_:)	swift.func.op	public	static func ... (maximum: Self) -> PartialRangeThrough<Self>	
SwarmRuntimeMode.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SwarmHiveRunOptionsOverride.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentEvent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextKey.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
EventLevel.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPRequest.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SpanStatus.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
Statistics.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
TokenUsage.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolChoice.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolSchema.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
TraceEvent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextMode.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPResource.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPResponse.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
RetryPolicy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
Conversation.Message.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
Conversation.Message.Role.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SessionError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentResponse.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextBudget.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
GuardrailType.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HandoffPolicy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HandoffResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MemoryMessage.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MemoryMessage.Role.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ModelSettings.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SendableValue.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolParameter.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolParameter.ParameterType.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
WorkflowError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
CacheRetention.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
CircuitBreaker.State.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
CircularBuffer.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextProfile.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextProfile.PlatformDefaults.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextProfile.Strict4kTemplate.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextProfile.Preset.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
GuardrailError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HandoffHistory.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPErrorObject.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPServerState.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MemoryPriority.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OllamaSettings.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterTool.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SourceLocation.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolCallRecord.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentContextKey.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
BackoffStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
GuardrailResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferencePolicy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferencePolicy.LatencyTier.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferencePolicy.NetworkState.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPCapabilities.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MemoryOperation.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MetricsSnapshot.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterModel.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ResilienceError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SessionMetadata.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HandoffInputData.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceOptions.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
PersistedMessage.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ContextBucketCaps.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceResponse.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceResponse.TokenUsage.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceResponse.FinishReason.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceResponse.ParsedToolCall.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterMessage.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRouting.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRouting.DataCollection.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRouting.Provider.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
AgentConfiguration.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPResourceContent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MemoryPriorityHint.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MergeErrorStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MultiProviderError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterToolCall.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
PerformanceMetrics.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
TruncationStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolExecutionResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceStreamEvent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterJSONSchema.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterToolChoice.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SendableErrorWrapper.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
InferenceStreamUpdate.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterContentPart.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterStreamEvent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
PartialToolCallUpdate.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterFunctionCall.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterToolFunction.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterConfiguration.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterProviderError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRateLimitInfo.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRetryStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
WorkflowValidationError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
GuardrailExecutionResult.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterMessageContent.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterPropertySchema.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterToolDefinition.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MembraneAgentAdapterError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterRoutingStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
GuardrailRunnerConfiguration.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MembraneFeatureConfiguration.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterFunctionDefinition.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterProviderPreferences.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterProviderPreferences.SortPreference.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterProviderPreferences.DataCollectionPreference.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
OpenRouterToolCallAccumulator.CompletedToolCall.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ParallelExecutionErrorStrategy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
MCPError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolCall.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ErrorInfo.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
EventKind.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
StepError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
TraceSpan.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
Verbosity.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
CircularBuffer.sorted(using:)	swift.method	public	func sorted<Comparator>(using comparator: Comparator) -> [Self.Element] where Comparator : SortComparator, Self.Element == Comparator.Compared	
CircularBuffer.sorted(using:)	swift.method	public	func sorted<S, Comparator>(using comparators: S) -> [Self.Element] where S : Sequence, Comparator : SortComparator, Comparator == S.Element, Self.Element == Comparator.Compared	
CircularBuffer.compare(_:_:)	swift.method	public	func compare<Comparator>(_ lhs: Comparator.Compared, _ rhs: Comparator.Compared) -> ComparisonResult where Comparator : SortComparator, Comparator == Self.Element	
CircularBuffer.formatted(_:)	swift.method	public	func formatted<S>(_ style: S) -> S.FormatOutput where Self == S.FormatInput, S : FormatStyle	
CircularBuffer.formatted()	swift.method	public	func formatted() -> String	
CircularBuffer.contains(_:)	swift.method	public	func contains(_ element: some SQLSpecificExpressible) -> SQLExpression	.build/checkouts/GRDB.swift/GRDB/QueryInterface/SQL/SQLOperators.swift:297
CircularBuffer.contains(_:)	swift.method	public	func contains(_ element: some SQLSpecificExpressible) -> SQLExpression	.build/checkouts/GRDB.swift/GRDB/QueryInterface/SQL/SQLOperators.swift:312
CircularBuffer.joined(operator:)	swift.method	public	func joined(operator: SQLExpression.AssociativeBinaryOperator) -> SQLExpression	.build/checkouts/GRDB.swift/GRDB/QueryInterface/SQL/SQLExpression.swift:2270
CircularBuffer.joined(operator:)	swift.method	public	func joined(operator: SQLExpression.AssociativeBinaryOperator) -> SQLExpression	.build/checkouts/GRDB.swift/GRDB/QueryInterface/SQL/SQLExpression.swift:2301
CircularBuffer.joined(separator:)	swift.method	public	func joined(separator: String = "") -> SQL	.build/checkouts/GRDB.swift/GRDB/Core/SQL.swift:334
CircularBuffer.flatMap(_:)	swift.method	public	func flatMap<SegmentOfResult>(_ transform: @escaping (Self.Iterator.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<AnyCursor<Self.Iterator.Element>, SegmentOfResult>> where SegmentOfResult : Cursor	.build/checkouts/GRDB.swift/GRDB/Core/Cursor.swift:253
CircularBuffer.clip()	swift.method	public	func clip()	
CircularBuffer.fill(using:)	swift.method	public	func fill(using operation: NSCompositingOperation = NSGraphicsContext.current?.compositingOperation ?? .sourceOver)	
CircularBuffer.fill(using:)	swift.method	public	func fill(using operation: NSCompositingOperation = NSGraphicsContext.current?.compositingOperation ?? .sourceOver)	
CircularBuffer.fill(using:)	swift.method	public	func fill(using operation: NSCompositingOperation = NSGraphicsContext.current?.compositingOperation ?? .sourceOver)	
CircularBuffer.publisher	swift.property	public	var publisher: Publishers.Sequence<Self, Never> { get }	
CircularBuffer.firstValue(matchingCategory:)	swift.method	public	func firstValue<T>(matchingCategory category: CMTypedTag<T>.Category) -> T? where T : Sendable	
CircularBuffer.first(matchingCategory:)	swift.method	public	func first<T>(matchingCategory category: CMTypedTag<T>.Category) -> CMTypedTag<T>? where T : Sendable	
CircularBuffer.filter(matchingCategory:)	swift.method	public	func filter<T>(matchingCategory category: CMTypedTag<T>.Category) -> [CMTypedTag<T>] where T : Sendable	
CircularBuffer.allSatisfy(_:)	swift.method	public	func allSatisfy(_ predicate: (Self.Element) throws -> Bool) rethrows -> Bool	
CircularBuffer.compactMap(_:)	swift.method	public	func compactMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult]	
CircularBuffer.enumerated()	swift.method	public	func enumerated() -> EnumeratedSequence<Self>	
CircularBuffer.elementsEqual(_:by:)	swift.method	public	func elementsEqual<OtherSequence>(_ other: OtherSequence, by areEquivalent: (Self.Element, OtherSequence.Element) throws -> Bool) rethrows -> Bool where OtherSequence : Sequence	
CircularBuffer.lexicographicallyPrecedes(_:by:)	swift.method	public	func lexicographicallyPrecedes<OtherSequence>(_ other: OtherSequence, by areInIncreasingOrder: (Self.Element, Self.Element) throws -> Bool) rethrows -> Bool where OtherSequence : Sequence, Self.Element == OtherSequence.Element	
CircularBuffer.withContiguousStorageIfAvailable(_:)	swift.method	public	func withContiguousStorageIfAvailable<R>(_ body: (UnsafeBufferPointer<Self.Element>) throws -> R) rethrows -> R?	
CircularBuffer.map(_:)	swift.method	public	func map<T, E>(_ transform: (Self.Element) throws(E) -> T) throws(E) -> [T] where E : Error	
CircularBuffer.max(by:)	swift.method	public	@warn_unqualified_access func max(by areInIncreasingOrder: (Self.Element, Self.Element) throws -> Bool) rethrows -> Self.Element?	
CircularBuffer.min(by:)	swift.method	public	@warn_unqualified_access func min(by areInIncreasingOrder: (Self.Element, Self.Element) throws -> Bool) rethrows -> Self.Element?	
CircularBuffer.lazy	swift.property	public	var lazy: LazySequence<Self> { get }	
CircularBuffer.count(where:)	swift.method	public	func count<E>(where predicate: (Self.Element) throws(E) -> Bool) throws(E) -> Int where E : Error	
CircularBuffer.first(where:)	swift.method	public	func first(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element?	
CircularBuffer.filter(_:)	swift.method	public	func filter(_ isIncluded: (Self.Element) throws -> Bool) rethrows -> [Self.Element]	
CircularBuffer.reduce(into:_:)	swift.method	public	func reduce<Result>(into initialResult: Result, _ updateAccumulatingResult: (inout Result, Self.Element) throws -> ()) rethrows -> Result	
CircularBuffer.reduce(_:_:)	swift.method	public	func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Self.Element) throws -> Result) rethrows -> Result	
CircularBuffer.sorted(by:)	swift.method	public	func sorted(by areInIncreasingOrder: (Self.Element, Self.Element) throws -> Bool) rethrows -> [Self.Element]	
CircularBuffer.starts(with:by:)	swift.method	public	func starts<PossiblePrefix>(with possiblePrefix: PossiblePrefix, by areEquivalent: (Self.Element, PossiblePrefix.Element) throws -> Bool) rethrows -> Bool where PossiblePrefix : Sequence	
CircularBuffer.flatMap(_:)	swift.method	public	func flatMap<SegmentOfResult>(_ transform: (Self.Element) throws -> SegmentOfResult) rethrows -> [SegmentOfResult.Element] where SegmentOfResult : Sequence	
CircularBuffer.flatMap(_:)	swift.method	public	func flatMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult]	
CircularBuffer.forEach(_:)	swift.method	public	func forEach(_ body: (Self.Element) throws -> Void) rethrows	
CircularBuffer.contains(where:)	swift.method	public	func contains(where predicate: (Self.Element) throws -> Bool) rethrows -> Bool	
CircularBuffer.reversed()	swift.method	public	func reversed() -> [Self.Element]	
CircularBuffer.shuffled(using:)	swift.method	public	func shuffled<T>(using generator: inout T) -> [Self.Element] where T : RandomNumberGenerator	
CircularBuffer.shuffled()	swift.method	public	func shuffled() -> [Self.Element]	
CircularBuffer.lexicographicallyPrecedes(_:)	swift.method	public	func lexicographicallyPrecedes<OtherSequence>(_ other: OtherSequence) -> Bool where OtherSequence : Sequence, Self.Element == OtherSequence.Element	
CircularBuffer.max()	swift.method	public	@warn_unqualified_access func max() -> Self.Element?	
CircularBuffer.min()	swift.method	public	@warn_unqualified_access func min() -> Self.Element?	
CircularBuffer.sorted()	swift.method	public	func sorted() -> [Self.Element]	
CircularBuffer.elementsEqual(_:)	swift.method	public	func elementsEqual<OtherSequence>(_ other: OtherSequence) -> Bool where OtherSequence : Sequence, Self.Element == OtherSequence.Element	
CircularBuffer.split(separator:maxSplits:omittingEmptySubsequences:)	swift.method	public	func split(separator: Self.Element, maxSplits: Int = Int.max, omittingEmptySubsequences: Bool = true) -> [ArraySlice<Self.Element>]	
CircularBuffer.starts(with:)	swift.method	public	func starts<PossiblePrefix>(with possiblePrefix: PossiblePrefix) -> Bool where PossiblePrefix : Sequence, Self.Element == PossiblePrefix.Element	
CircularBuffer.contains(_:)	swift.method	public	func contains(_ element: Self.Element) -> Bool	
CircularBuffer.joined(separator:)	swift.method	public	func joined<Separator>(separator: Separator) -> JoinedSequence<Self> where Separator : Sequence, Separator.Element == Self.Element.Element	
CircularBuffer.joined()	swift.method	public	func joined() -> FlattenSequence<Self>	
CircularBuffer.joined(separator:)	swift.method	public	func joined(separator: String = "") -> String	
SpanStatus.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
GuardrailType.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
MemoryMessage.Role.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
CacheRetention.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
MemoryOperation.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
InferenceResponse.FinishReason.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
TruncationStrategy.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
OpenRouterProviderPreferences.SortPreference.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
OpenRouterProviderPreferences.DataCollectionPreference.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
EventKind.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
Verbosity.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
EventLevel.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
EventLevel.hashValue	swift.property	public	var hashValue: Int { get }	
SpanStatus.hashValue	swift.property	public	var hashValue: Int { get }	
Conversation.Message.Role.hashValue	swift.property	public	var hashValue: Int { get }	
GuardrailType.hashValue	swift.property	public	var hashValue: Int { get }	
MemoryMessage.Role.hashValue	swift.property	public	var hashValue: Int { get }	
CacheRetention.hashValue	swift.property	public	var hashValue: Int { get }	
ContextProfile.Preset.hashValue	swift.property	public	var hashValue: Int { get }	
MemoryPriority.hashValue	swift.property	public	var hashValue: Int { get }	
AgentContextKey.hashValue	swift.property	public	var hashValue: Int { get }	
InferencePolicy.LatencyTier.hashValue	swift.property	public	var hashValue: Int { get }	
InferencePolicy.NetworkState.hashValue	swift.property	public	var hashValue: Int { get }	
MemoryOperation.hashValue	swift.property	public	var hashValue: Int { get }	
InferenceResponse.FinishReason.hashValue	swift.property	public	var hashValue: Int { get }	
OpenRouterRouting.DataCollection.hashValue	swift.property	public	var hashValue: Int { get }	
OpenRouterRouting.Provider.hashValue	swift.property	public	var hashValue: Int { get }	
TruncationStrategy.hashValue	swift.property	public	var hashValue: Int { get }	
OpenRouterProviderPreferences.SortPreference.hashValue	swift.property	public	var hashValue: Int { get }	
OpenRouterProviderPreferences.DataCollectionPreference.hashValue	swift.property	public	var hashValue: Int { get }	
EventKind.hashValue	swift.property	public	var hashValue: Int { get }	
Verbosity.hashValue	swift.property	public	var hashValue: Int { get }	
EventLevel.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
SpanStatus.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
Conversation.Message.Role.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
GuardrailType.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
MemoryMessage.Role.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
CacheRetention.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
ContextProfile.Preset.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
MemoryPriority.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
AgentContextKey.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
InferencePolicy.LatencyTier.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
InferencePolicy.NetworkState.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
MemoryOperation.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
InferenceResponse.FinishReason.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
OpenRouterRouting.DataCollection.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
OpenRouterRouting.Provider.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
TruncationStrategy.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
OpenRouterProviderPreferences.SortPreference.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
OpenRouterProviderPreferences.DataCollectionPreference.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
EventKind.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
Verbosity.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
SpanStatus.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
GuardrailType.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MemoryMessage.Role.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
CacheRetention.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
MemoryOperation.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
InferenceResponse.FinishReason.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
TruncationStrategy.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterProviderPreferences.SortPreference.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
OpenRouterProviderPreferences.DataCollectionPreference.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
EventKind.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
Verbosity.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
EventLevel.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
NoOpTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
OSLogTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
RateLimiter.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AgentContext.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Conversation.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HybridMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ToolRegistry.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
TraceContext.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
VectorMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ConsoleTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HTTPMCPServer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MCPToolBridge.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MultiProvider.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SummaryMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
BufferedTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CircuitBreaker.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftLogTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CompositeMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CompositeTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
GuardrailRunner.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InMemoryBackend.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InMemorySession.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ResponseTracker.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftDataMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MetricsCollector.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PersistentMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftDataBackend.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PersistentSession.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ConversationMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HandoffCoordinator.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
OpenRouterProvider.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PerformanceTracker.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PrettyConsoleTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SlidingWindowMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ParallelToolExecutor.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CircuitBreakerRegistry.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
FoundationModelsSummarizer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
DefaultMembraneAgentAdapter.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InferenceProviderSummarizer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Agent.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AnyMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AnyTracer.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MCPClient.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
WaxMemory.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Swarm.Configuration.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
NoOpTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
OSLogTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
RateLimiter.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
AgentContext.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
Conversation.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
HybridMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
ToolRegistry.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
TraceContext.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
VectorMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
ConsoleTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
HTTPMCPServer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
MCPToolBridge.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
MultiProvider.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SummaryMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
BufferedTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
CircuitBreaker.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SwiftLogTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
CompositeMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
CompositeTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
GuardrailRunner.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
InMemoryBackend.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
InMemorySession.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
ResponseTracker.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SwiftDataMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
MetricsCollector.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
PersistentMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SwiftDataBackend.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
PersistentSession.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
ConversationMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
HandoffCoordinator.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
OpenRouterProvider.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
PerformanceTracker.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
PrettyConsoleTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SlidingWindowMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
ParallelToolExecutor.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
CircuitBreakerRegistry.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
FoundationModelsSummarizer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
DefaultMembraneAgentAdapter.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
InferenceProviderSummarizer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
Agent.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
AnyMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
AnyTracer.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
MCPClient.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
WaxMemory.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
Swarm.Configuration.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
NoOpTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
OSLogTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
RateLimiter.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AgentContext.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Conversation.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HybridMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ToolRegistry.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
TraceContext.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
VectorMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ConsoleTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HTTPMCPServer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MCPToolBridge.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MultiProvider.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SummaryMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
BufferedTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CircuitBreaker.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftLogTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CompositeMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CompositeTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
GuardrailRunner.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InMemoryBackend.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InMemorySession.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ResponseTracker.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftDataMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MetricsCollector.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PersistentMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwiftDataBackend.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PersistentSession.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ConversationMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
HandoffCoordinator.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
OpenRouterProvider.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PerformanceTracker.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
PrettyConsoleTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SlidingWindowMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
ParallelToolExecutor.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CircuitBreakerRegistry.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
FoundationModelsSummarizer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
DefaultMembraneAgentAdapter.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
InferenceProviderSummarizer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Agent.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AnyMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
AnyTracer.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
MCPClient.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
WaxMemory.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
Swarm.Configuration.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
CircularBuffer.trimmingPrefix(while:)	swift.method	public	func trimmingPrefix(while predicate: (Self.Element) throws -> Bool) rethrows -> Self.SubSequence	
CircularBuffer.firstRange(of:)	swift.method	public	func firstRange<C>(of other: C) -> Range<Self.Index>? where C : Collection, Self.Element == C.Element	
CircularBuffer.trimmingPrefix(_:)	swift.method	public	func trimmingPrefix<Prefix>(_ prefix: Prefix) -> Self.SubSequence where Prefix : Sequence, Self.Element == Prefix.Element	
CircularBuffer.split(separator:maxSplits:omittingEmptySubsequences:)	swift.method	public	func split<C>(separator: C, maxSplits: Int = .max, omittingEmptySubsequences: Bool = true) -> [Self.SubSequence] where C : Collection, Self.Element == C.Element	
CircularBuffer.ranges(of:)	swift.method	public	func ranges<C>(of other: C) -> [Range<Self.Index>] where C : Collection, Self.Element == C.Element	
CircularBuffer.contains(_:)	swift.method	public	func contains<C>(_ other: C) -> Bool where C : Collection, Self.Element == C.Element	
CircularBuffer.joined(separator:)	swift.method	public	func joined(separator: String = "") -> SQL	.build/checkouts/GRDB.swift/GRDB/Core/SQL.swift:359
CircularBuffer.call(named:)	swift.method	public	func call(named name: String) -> Transcript.ToolCall?	.build/checkouts/Conduit/Sources/Conduit/Core/Types/ToolMessage.swift:171
CircularBuffer.calls(named:)	swift.method	public	func calls(named name: String) -> [Transcript.ToolCall]	.build/checkouts/Conduit/Sources/Conduit/Core/Types/ToolMessage.swift:179
CircularBuffer.firstIndex(where:)	swift.method	public	func firstIndex(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Index?	
CircularBuffer.randomElement()	swift.method	public	func randomElement() -> Self.Element?	
CircularBuffer.randomElement(using:)	swift.method	public	func randomElement<T>(using generator: inout T) -> Self.Element? where T : RandomNumberGenerator	
CircularBuffer.removingSubranges(_:)	swift.method	public	func removingSubranges(_ subranges: RangeSet<Self.Index>) -> DiscontiguousSlice<Self>	
CircularBuffer.underestimatedCount	swift.property	public	var underestimatedCount: Int { get }	
CircularBuffer.map(_:)	swift.method	public	func map<T, E>(_ transform: (Self.Element) throws(E) -> T) throws(E) -> [T] where E : Error	
CircularBuffer.drop(while:)	swift.method	public	func drop(while predicate: (Self.Element) throws -> Bool) rethrows -> Self.SubSequence	
CircularBuffer.index(_:offsetBy:limitedBy:)	swift.method	public	func index(_ i: Self.Index, offsetBy distance: Int, limitedBy limit: Self.Index) -> Self.Index?	
CircularBuffer.index(_:offsetBy:)	swift.method	public	func index(_ i: Self.Index, offsetBy distance: Int) -> Self.Index	
CircularBuffer.split(maxSplits:omittingEmptySubsequences:whereSeparator:)	swift.method	public	func split(maxSplits: Int = Int.max, omittingEmptySubsequences: Bool = true, whereSeparator isSeparator: (Self.Element) throws -> Bool) rethrows -> [Self.SubSequence]	
CircularBuffer.prefix(upTo:)	swift.method	public	func prefix(upTo end: Self.Index) -> Self.SubSequence	
CircularBuffer.prefix(while:)	swift.method	public	func prefix(while predicate: (Self.Element) throws -> Bool) rethrows -> Self.SubSequence	
CircularBuffer.prefix(through:)	swift.method	public	func prefix(through position: Self.Index) -> Self.SubSequence	
CircularBuffer.prefix(_:)	swift.method	public	func prefix(_ maxLength: Int) -> Self.SubSequence	
CircularBuffer.suffix(from:)	swift.method	public	func suffix(from start: Self.Index) -> Self.SubSequence	
CircularBuffer.suffix(_:)	swift.method	public	func suffix(_ maxLength: Int) -> Self.SubSequence	
CircularBuffer.indices(where:)	swift.method	public	func indices(where predicate: (Self.Element) throws -> Bool) rethrows -> RangeSet<Self.Index>	
CircularBuffer.distance(from:to:)	swift.method	public	func distance(from start: Self.Index, to end: Self.Index) -> Int	
CircularBuffer.dropLast(_:)	swift.method	public	func dropLast(_ k: Int = 1) -> Self.SubSequence	
CircularBuffer.dropFirst(_:)	swift.method	public	func dropFirst(_ k: Int = 1) -> Self.SubSequence	
CircularBuffer.formIndex(after:)	swift.method	public	func formIndex(after i: inout Self.Index)	
CircularBuffer.formIndex(_:offsetBy:limitedBy:)	swift.method	public	func formIndex(_ i: inout Self.Index, offsetBy distance: Int, limitedBy limit: Self.Index) -> Bool	
CircularBuffer.formIndex(_:offsetBy:)	swift.method	public	func formIndex(_ i: inout Self.Index, offsetBy distance: Int)	
CircularBuffer.indices	swift.property	public	var indices: DefaultIndices<Self> { get }	
CircularBuffer.firstIndex(of:)	swift.method	public	func firstIndex(of element: Self.Element) -> Self.Index?	
CircularBuffer.index(of:)	swift.method	public	func index(of element: Self.Element) -> Self.Index?	
CircularBuffer.split(separator:maxSplits:omittingEmptySubsequences:)	swift.method	public	func split(separator: Self.Element, maxSplits: Int = Int.max, omittingEmptySubsequences: Bool = true) -> [Self.SubSequence]	
CircularBuffer.indices(of:)	swift.method	public	func indices(of element: Self.Element) -> RangeSet<Self.Index>	
CircularBuffer.makeIterator()	swift.method	public	func makeIterator() -> IndexingIterator<Self>	
PromptString.init(extendedGraphemeClusterLiteral:)	swift.init	public	init(extendedGraphemeClusterLiteral value: Self.StringLiteralType)	
SendableValue.init(extendedGraphemeClusterLiteral:)	swift.init	public	init(extendedGraphemeClusterLiteral value: Self.StringLiteralType)	
OpenRouterModel.init(extendedGraphemeClusterLiteral:)	swift.init	public	init(extendedGraphemeClusterLiteral value: Self.StringLiteralType)	
PromptString.init(unicodeScalarLiteral:)	swift.init	public	init(unicodeScalarLiteral value: Self.ExtendedGraphemeClusterLiteralType)	
SendableValue.init(unicodeScalarLiteral:)	swift.init	public	init(unicodeScalarLiteral value: Self.ExtendedGraphemeClusterLiteralType)	
OpenRouterModel.init(unicodeScalarLiteral:)	swift.init	public	init(unicodeScalarLiteral value: Self.ExtendedGraphemeClusterLiteralType)	
AgentError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
SessionError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
SendableValue.ConversionError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
WorkflowError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
EmbeddingError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
GuardrailError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
ToolChainError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
ResilienceError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
SummarizerError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
ToolRegistryError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
VectorMemoryError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
MultiProviderError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
MetricsReporterError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
PersistentMemoryError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
OpenRouterProviderError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
WorkflowValidationError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
MembraneAgentAdapterError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
ModelSettingsValidationError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
OpenRouterConfigurationError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
MCPError.localizedDescription	swift.property	public	var localizedDescription: String { get }	

## Swarm@FoundationModels (3 symbols)
LanguageModelSession.generateWithToolCalls(prompt:tools:options:)	swift.method	public	func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse	Sources/Swarm/Providers/LanguageModelSession.swift:54
LanguageModelSession.stream(prompt:options:)	swift.method	public	func stream(prompt: String, options _: InferenceOptions) -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Providers/LanguageModelSession.swift:38
LanguageModelSession.generate(prompt:options:)	swift.method	public	func generate(prompt: String, options: InferenceOptions) async throws -> String	Sources/Swarm/Providers/LanguageModelSession.swift:16

## Swarm@Swift (4 symbols)
Array.toOpenRouterToolDefinitions()	swift.method	public	func toOpenRouterToolDefinitions() -> [OpenRouterToolDefinition]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:515
Array.toOpenRouterTools()	swift.method	public	func toOpenRouterTools() -> [OpenRouterTool]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:540
Array.toOpenRouterTools()	swift.method	public	func toOpenRouterTools() -> [OpenRouterToolDefinition]	Sources/Swarm/Providers/OpenRouter/OpenRouterToolConverter.swift:486
Duration.timeInterval	swift.property	public	var timeInterval: TimeInterval { get }	Sources/Swarm/Extensions/Extensions.swift:34

## Swarm@_Concurrency (27 symbols)
AsyncThrowingStream.onError(_:)	swift.method	public	func onError(_ action: @escaping (AgentError) -> Void) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:520
AsyncThrowingStream.compactMap(_:)	swift.method	public	func compactMap<T>(_ transform: @escaping (AgentEvent) async throws -> T?) -> AsyncThrowingStream<T, any Error> where T : Sendable	Sources/Swarm/Core/StreamOperations.swift:719
AsyncThrowingStream.onComplete(_:)	swift.method	public	func onComplete(_ action: @escaping (AgentResult) -> Void) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:499
AsyncThrowingStream.catchErrors(_:)	swift.method	public	func catchErrors(_ handler: @escaping (any Error) -> AgentEvent) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:543
AsyncThrowingStream.toolResults	swift.property	public	var toolResults: AsyncThrowingStream<ToolResult, any Error> { get }	Sources/Swarm/Core/StreamOperations.swift:62
AsyncThrowingStream.mapToThoughts()	swift.method	public	func mapToThoughts() -> AsyncThrowingStream<String, any Error>	Sources/Swarm/Core/StreamOperations.swift:249
AsyncThrowingStream.filterThinking()	swift.method	public	func filterThinking() -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:158
AsyncThrowingStream.filterToolEvents()	swift.method	public	func filterToolEvents() -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:173
AsyncThrowingStream.distinctUntilChanged()	swift.method	public	func distinctUntilChanged() -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:747
AsyncThrowingStream.map(_:)	swift.method	public	func map<T>(_ transform: @escaping (AgentEvent) -> T) -> AsyncThrowingStream<T, any Error> where T : Sendable	Sources/Swarm/Core/StreamOperations.swift:228
AsyncThrowingStream.drop(_:)	swift.method	public	func drop(_ count: Int) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:407
AsyncThrowingStream.last()	swift.method	public	func last() async throws -> AgentEvent?	Sources/Swarm/Core/StreamOperations.swift:333
AsyncThrowingStream.scan(_:_:)	swift.method	public	func scan<T>(_ initial: T, _ combine: @escaping (T, AgentEvent) async throws -> T) -> AsyncThrowingStream<T, any Error> where T : Sendable	Sources/Swarm/Core/StreamOperations.swift:798
AsyncThrowingStream.take(_:)	swift.method	public	func take(_ count: Int) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:384
AsyncThrowingStream.first(where:)	swift.method	public	func first(where predicate: @escaping (AgentEvent) -> Bool) async throws -> AgentEvent?	Sources/Swarm/Core/StreamOperations.swift:313
AsyncThrowingStream.retry(maxAttempts:delay:factory:)	swift.type.method	public	static func retry(maxAttempts: Int = 3, delay: Duration = .zero, factory: @escaping () async -> AsyncThrowingStream<AgentEvent, any Error>) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:104
AsyncThrowingStream.buffer(count:)	swift.method	public	func buffer(count: Int) -> AsyncThrowingStream<[AgentEvent], any Error>	Sources/Swarm/Core/StreamOperations.swift:678
AsyncThrowingStream.filter(_:)	swift.method	public	func filter(_ predicate: @escaping (AgentEvent) -> Bool) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:201
AsyncThrowingStream.onEach(_:)	swift.method	public	func onEach(_ action: @escaping (AgentEvent) -> Void) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:476
AsyncThrowingStream.reduce(_:_:)	swift.method	public	func reduce<T>(_ initial: T, _ combine: @escaping (T, AgentEvent) -> T) async throws -> T where T : Sendable	Sources/Swarm/Core/StreamOperations.swift:360
AsyncThrowingStream.collect(maxCount:)	swift.method	public	func collect(maxCount: Int) async throws -> [AgentEvent]	Sources/Swarm/Core/StreamOperations.swift:289
AsyncThrowingStream.collect()	swift.method	public	func collect() async throws -> [AgentEvent]	Sources/Swarm/Core/StreamOperations.swift:271
AsyncThrowingStream.timeout(after:)	swift.method	public	func timeout(after duration: Duration) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:434
AsyncThrowingStream.debounce(for:)	swift.method	public	func debounce(for duration: Duration) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:580
AsyncThrowingStream.thoughts	swift.property	public	var thoughts: AsyncThrowingStream<String, any Error> { get }	Sources/Swarm/Core/StreamOperations.swift:31
AsyncThrowingStream.throttle(for:)	swift.method	public	func throttle(for interval: Duration) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/StreamOperations.swift:633
AsyncThrowingStream.toolCalls	swift.property	public	var toolCalls: AsyncThrowingStream<ToolCall, any Error> { get }	Sources/Swarm/Core/StreamOperations.swift:43

## SwarmHive (227 symbols)
GraphAgent.environment(_:_:)	swift.method	public	func environment<V>(_ keyPath: WritableKeyPath<AgentEnvironment, V>, _ value: V) -> EnvironmentAgent where V : Sendable	Sources/Swarm/Core/EnvironmentAgent.swift:86
GraphAgent.callAsFunction(_:)	swift.method	public	func callAsFunction(_ input: String) async throws -> AgentResult	Sources/Swarm/Core/CallableAgent.swift:58
GraphAgent.inputGuardrails	swift.property	public	nonisolated var inputGuardrails: [any InputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:131
GraphAgent.runWithResponse(_:session:observer:)	swift.method	public	func runWithResponse(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:164
GraphAgent.runWithResponse(_:observer:)	swift.method	public	func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse	Sources/Swarm/Core/AgentRuntime.swift:202
GraphAgent.outputGuardrails	swift.property	public	nonisolated var outputGuardrails: [any OutputGuardrail] { get }	Sources/Swarm/Core/AgentRuntime.swift:134
GraphAgent.inferenceProvider	swift.property	public	nonisolated var inferenceProvider: (any InferenceProvider)? { get }	Sources/Swarm/Core/AgentRuntime.swift:125
GraphAgent.run(_:observer:)	swift.method	public	func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/Core/AgentRuntime.swift:144
GraphAgent.name	swift.property	public	nonisolated var name: String { get }	Sources/Swarm/Core/AgentRuntime.swift:119
GraphAgent.asTool(name:description:)	swift.method	public	func asTool(name: String? = nil, description: String? = nil) -> AgentTool	Sources/Swarm/Tools/AgentTool.swift:106
GraphAgent.memory	swift.property	public	nonisolated var memory: (any Memory)? { get }	Sources/Swarm/Core/AgentRuntime.swift:122
GraphAgent.memory(_:)	swift.method	public	func memory(_ memory: any Memory) -> EnvironmentAgent	Sources/Swarm/Core/EnvironmentAgent.swift:97
GraphAgent.stream(_:observer:)	swift.method	public	nonisolated func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/Core/AgentRuntime.swift:149
GraphAgent.tracer	swift.property	public	nonisolated var tracer: (any Tracer)? { get }	Sources/Swarm/Core/AgentRuntime.swift:128
GraphAgent.handoffs	swift.property	public	nonisolated var handoffs: [AnyHandoffConfiguration] { get }	Sources/Swarm/Core/AgentRuntime.swift:137
GraphAgent.observed(by:)	swift.method	public	func observed(by observer: some AgentObserver) -> some AgentRuntime 	Sources/Swarm/Core/ObservedAgent.swift:54
GraphAgent.asHandoff()	swift.method	public	func asHandoff() -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:252
GraphAgent.asHandoff(_:)	swift.method	public	func asHandoff(_ configure: (HandoffOptions<Self>) -> HandoffOptions<Self>) -> AnyHandoffConfiguration	Sources/Swarm/Core/Handoff/HandoffOptions.swift:257
HiveDeterminism	swift.enum	public	enum HiveDeterminism	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:200
HiveDeterminism.finalStateHash(_:includeRuntimeIdentity:)	swift.type.method	public	static func finalStateHash(_ snapshot: HiveRuntimeStateSnapshot<some HiveSchema>, includeRuntimeIdentity: Bool = false) throws -> String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:294
HiveDeterminism.firstStateDiff(expected:actual:includeRuntimeIdentity:)	swift.type.method	public	static func firstStateDiff<Schema>(expected: HiveRuntimeStateSnapshot<Schema>, actual: HiveRuntimeStateSnapshot<Schema>, includeRuntimeIdentity: Bool = false) -> HiveDeterminismDiff? where Schema : HiveSchema	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:378
HiveDeterminism.transcriptHash(_:expectedSchemaVersion:)	swift.type.method	public	static func transcriptHash(_ events: [HiveEvent], expectedSchemaVersion: String = EventSchemaVersion.current) throws -> String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:253
HiveDeterminism.projectTranscript(_:expectedSchemaVersion:)	swift.type.method	public	static func projectTranscript(_ events: [HiveEvent], expectedSchemaVersion: String = EventSchemaVersion.current) throws -> HiveCanonicalTranscript	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:203
HiveDeterminism.firstTranscriptDiff(expected:actual:)	swift.type.method	public	static func firstTranscriptDiff(expected: HiveCanonicalTranscript, actual: HiveCanonicalTranscript) -> HiveDeterminismDiff?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:324
HiveDeterminism.classifyCancelCheckpointRace(events:outcome:)	swift.type.method	public	static func classifyCancelCheckpointRace(events: [HiveEvent], outcome: HiveRunOutcome<some HiveSchema>) -> HiveCancelCheckpointResolution	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:483
HiveDeterminismDiff	swift.struct	public	struct HiveDeterminismDiff	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:171
HiveDeterminismDiff.init(path:expected:actual:)	swift.init	public	init(path: String, expected: String, actual: String)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:176
HiveDeterminismDiff.path	swift.property	public	let path: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:172
HiveDeterminismDiff.actual	swift.property	public	let actual: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:174
HiveDeterminismDiff.expected	swift.property	public	let expected: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:173
HiveCodableJSONCodec	swift.struct	public	struct HiveCodableJSONCodec<Value> where Value : Decodable, Value : Encodable, Value : Sendable	Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift:7
HiveCodableJSONCodec.init(id:)	swift.init	public	init(id: String? = nil)	Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift:10
HiveCodableJSONCodec.id	swift.property	public	let id: String	Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift:8
HiveCodableJSONCodec.decode(_:)	swift.method	public	func decode(_ data: Data) throws -> Value	Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift:20
HiveCodableJSONCodec.encode(_:)	swift.method	public	func encode(_ value: Value) throws -> Data	Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift:14
HiveCompactionPolicy	swift.struct	public	struct HiveCompactionPolicy	Sources/Swarm/HiveSwarm/ChatGraph.swift:181
HiveCompactionPolicy.preserveLastMessages	swift.property	public	let preserveLastMessages: Int	Sources/Swarm/HiveSwarm/ChatGraph.swift:183
HiveCompactionPolicy.init(maxTokens:preserveLastMessages:)	swift.init	public	init(maxTokens: Int, preserveLastMessages: Int)	Sources/Swarm/HiveSwarm/ChatGraph.swift:185
HiveCompactionPolicy.maxTokens	swift.property	public	let maxTokens: Int	Sources/Swarm/HiveSwarm/ChatGraph.swift:182
HiveCanonicalTranscript	swift.struct	public	struct HiveCanonicalTranscript	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:159
HiveCanonicalTranscript.init(schemaVersion:events:)	swift.init	public	init(schemaVersion: String, events: [HiveCanonicalEventRecord])	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:163
HiveCanonicalTranscript.schemaVersion	swift.property	public	let schemaVersion: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:160
HiveCanonicalTranscript.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
HiveCanonicalTranscript.events	swift.property	public	let events: [HiveCanonicalEventRecord]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:161
HiveStateSnapshotSource	swift.enum	public	enum HiveStateSnapshotSource	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:23
HiveStateSnapshotSource.checkpoint	swift.enum.case	public	case checkpoint	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:25
HiveStateSnapshotSource.trackerOnly	swift.enum.case	public	case trackerOnly	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:27
HiveStateSnapshotSource.memoryAndCheckpoint	swift.enum.case	public	case memoryAndCheckpoint	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:26
HiveStateSnapshotSource.memory	swift.enum.case	public	case memory	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:24
HiveCanonicalEventRecord	swift.struct	public	struct HiveCanonicalEventRecord	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:132
HiveCanonicalEventRecord.attributes	swift.property	public	let attributes: [String : String]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:137
HiveCanonicalEventRecord.init(eventIndex:stepIndex:taskOrdinal:kind:attributes:metadata:)	swift.init	public	init(eventIndex: UInt64, stepIndex: Int?, taskOrdinal: Int?, kind: String, attributes: [String : String], metadata: [String : String])	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:140
HiveCanonicalEventRecord.eventIndex	swift.property	public	let eventIndex: UInt64	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:133
HiveCanonicalEventRecord.taskOrdinal	swift.property	public	let taskOrdinal: Int?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:135
HiveCanonicalEventRecord.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
HiveCanonicalEventRecord.kind	swift.property	public	let kind: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:136
HiveCanonicalEventRecord.metadata	swift.property	public	let metadata: [String : String]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:138
HiveCanonicalEventRecord.stepIndex	swift.property	public	let stepIndex: Int?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:134
HiveRuntimeStateSnapshot	swift.struct	public	struct HiveRuntimeStateSnapshot<Schema> where Schema : HiveSchema	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:96
HiveRuntimeStateSnapshot.channelState	swift.property	public	let channelState: HiveRuntimeChannelStateSummary?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:103
HiveRuntimeStateSnapshot.checkpointID	swift.property	public	let checkpointID: HiveCheckpointID?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:101
HiveRuntimeStateSnapshot.interruption	swift.property	public	let interruption: HiveRuntimeInterruptionSummary<Schema>?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:100
HiveRuntimeStateSnapshot.eventSchemaVersion	swift.property	public	let eventSchemaVersion: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:104
HiveRuntimeStateSnapshot.runID	swift.property	public	let runID: HiveRunID?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:98
HiveRuntimeStateSnapshot.source	swift.property	public	let source: HiveStateSnapshotSource	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:105
HiveRuntimeStateSnapshot.frontier	swift.property	public	let frontier: HiveRuntimeFrontierSummary	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:102
HiveRuntimeStateSnapshot.init(threadID:runID:stepIndex:interruption:checkpointID:frontier:channelState:eventSchemaVersion:source:)	swift.init	public	init(threadID: HiveThreadID, runID: HiveRunID?, stepIndex: Int?, interruption: HiveRuntimeInterruptionSummary<Schema>?, checkpointID: HiveCheckpointID?, frontier: HiveRuntimeFrontierSummary, channelState: HiveRuntimeChannelStateSummary?, eventSchemaVersion: String, source: HiveStateSnapshotSource)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:107
HiveRuntimeStateSnapshot.threadID	swift.property	public	let threadID: HiveThreadID	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:97
HiveRuntimeStateSnapshot.stepIndex	swift.property	public	let stepIndex: Int?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:99
HiveRuntimeFrontierSummary	swift.struct	public	struct HiveRuntimeFrontierSummary	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:32
HiveRuntimeFrontierSummary.hash	swift.property	public	let hash: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:50
HiveRuntimeFrontierSummary.Entry	swift.struct	public	struct Entry	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:33
HiveRuntimeFrontierSummary.Entry.provenance	swift.property	public	let provenance: HiveTaskProvenance	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:35
HiveRuntimeFrontierSummary.Entry.localFingerprintHash	swift.property	public	let localFingerprintHash: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:36
HiveRuntimeFrontierSummary.Entry.nodeID	swift.property	public	let nodeID: HiveNodeID	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:34
HiveRuntimeFrontierSummary.Entry.init(nodeID:provenance:localFingerprintHash:)	swift.init	public	init(nodeID: HiveNodeID, provenance: HiveTaskProvenance, localFingerprintHash: String)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:38
HiveRuntimeFrontierSummary.init(count:hash:entries:)	swift.init	public	init(count: Int, hash: String, entries: [HiveRuntimeFrontierSummary.Entry])	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:53
HiveRuntimeFrontierSummary.count	swift.property	public	let count: Int	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:49
HiveRuntimeFrontierSummary.entries	swift.property	public	let entries: [HiveRuntimeFrontierSummary.Entry]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:51
HiveCheckpointQueryCapability	swift.enum	public	enum HiveCheckpointQueryCapability	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:15
HiveCheckpointQueryCapability.latestOnly	swift.enum.case	public	case latestOnly	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:17
HiveCheckpointQueryCapability.unavailable	swift.enum.case	public	case unavailable	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:16
HiveCheckpointQueryCapability.queryable	swift.enum.case	public	case queryable	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:18
HiveCancelCheckpointResolution	swift.enum	public	enum HiveCancelCheckpointResolution	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:192
HiveCancelCheckpointResolution.cancelledAfterCheckpointSaved(checkpointID:)	swift.enum.case	public	case cancelledAfterCheckpointSaved(checkpointID: HiveCheckpointID)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:195
HiveCancelCheckpointResolution.cancelledWithoutCheckpoint(latestCheckpointID:)	swift.enum.case	public	case cancelledWithoutCheckpoint(latestCheckpointID: HiveCheckpointID?)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:194
HiveCancelCheckpointResolution.notCancelled	swift.enum.case	public	case notCancelled	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:193
HiveRuntimeChannelStateSummary	swift.struct	public	struct HiveRuntimeChannelStateSummary	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:62
HiveRuntimeChannelStateSummary.init(hash:entries:)	swift.init	public	init(hash: String, entries: [HiveRuntimeChannelStateSummary.Entry])	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:76
HiveRuntimeChannelStateSummary.hash	swift.property	public	let hash: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:73
HiveRuntimeChannelStateSummary.Entry	swift.struct	public	struct Entry	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:63
HiveRuntimeChannelStateSummary.Entry.payloadHash	swift.property	public	let payloadHash: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:65
HiveRuntimeChannelStateSummary.Entry.channelID	swift.property	public	let channelID: HiveChannelID	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:64
HiveRuntimeChannelStateSummary.Entry.init(channelID:payloadHash:)	swift.init	public	init(channelID: HiveChannelID, payloadHash: String)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:67
HiveRuntimeChannelStateSummary.entries	swift.property	public	let entries: [HiveRuntimeChannelStateSummary.Entry]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:74
HiveRuntimeInterruptionSummary	swift.struct	public	struct HiveRuntimeInterruptionSummary<Schema> where Schema : HiveSchema	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:84
HiveRuntimeInterruptionSummary.interruptID	swift.property	public	let interruptID: HiveInterruptID	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:85
HiveRuntimeInterruptionSummary.init(interruptID:payloadHash:)	swift.init	public	init(interruptID: HiveInterruptID, payloadHash: String?)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:88
HiveRuntimeInterruptionSummary.payloadHash	swift.property	public	let payloadHash: String?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:86
HiveTranscriptCompatibilityError	swift.enum	public	enum HiveTranscriptCompatibilityError	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:185
HiveTranscriptCompatibilityError.missingSchemaVersion(eventIndex:)	swift.enum.case	public	case missingSchemaVersion(eventIndex: Int)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:186
HiveTranscriptCompatibilityError.incompatibleSchemaVersion(expected:found:eventIndex:)	swift.enum.case	public	case incompatibleSchemaVersion(expected: String, found: String, eventIndex: Int)	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:187
HiveTokenizer	swift.protocol	public	protocol HiveTokenizer : Sendable	Sources/Swarm/HiveSwarm/ChatGraph.swift:177
HiveTokenizer.countTokens(_:)	swift.method	public	func countTokens(_ messages: [HiveChatMessage]) -> Int	Sources/Swarm/HiveSwarm/ChatGraph.swift:178
GraphAgent	swift.struct	public	struct GraphAgent	Sources/Swarm/HiveSwarm/GraphAgent.swift:35
GraphAgent.instructions	swift.property	public	nonisolated let instructions: String	Sources/Swarm/HiveSwarm/GraphAgent.swift:53
GraphAgent.configuration	swift.property	public	nonisolated let configuration: AgentConfiguration	Sources/Swarm/HiveSwarm/GraphAgent.swift:54
GraphAgent.run(_:session:observer:)	swift.method	public	func run(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) async throws -> AgentResult	Sources/Swarm/HiveSwarm/GraphAgent.swift:102
GraphAgent.tools	swift.property	public	nonisolated let tools: [any AnyJSONTool]	Sources/Swarm/HiveSwarm/GraphAgent.swift:52
GraphAgent.cancel()	swift.method	public	func cancel() async	Sources/Swarm/HiveSwarm/GraphAgent.swift:256
GraphAgent.stream(_:session:observer:)	swift.method	public	nonisolated func stream(_ input: String, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, any Error>	Sources/Swarm/HiveSwarm/GraphAgent.swift:151
GraphAgent.init(runtime:name:instructions:threadID:runOptions:configuration:)	swift.init	public	init(runtime: GraphRuntimeAdapter, name: String, instructions: String = "", threadID: HiveThreadID = HiveThreadID(UUID().uuidString), runOptions: HiveRunOptions = HiveRunOptions(maxSteps: 20, checkpointPolicy: .disabled), configuration: AgentConfiguration? = nil)	Sources/Swarm/HiveSwarm/GraphAgent.swift:69
PreModelHook	swift.protocol	public	protocol PreModelHook : Sendable	Sources/Swarm/HiveSwarm/ChatGraph.swift:12
PreModelHook.transform(messages:systemPrompt:context:)	swift.method	public	func transform(messages: [HiveChatMessage], systemPrompt: String, context: RuntimeContext) async -> (messages: [HiveChatMessage], systemPrompt: String)	Sources/Swarm/HiveSwarm/ChatGraph.swift:20
ToolProvider	swift.typealias	public	typealias ToolProvider = () async -> [HiveToolDefinition]	Sources/Swarm/HiveSwarm/ChatGraph.swift:27
RuntimeContext	swift.struct	public	struct RuntimeContext	Sources/Swarm/HiveSwarm/ChatGraph.swift:197
RuntimeContext.retryPolicy	swift.property	public	let retryPolicy: HiveRetryPolicy?	Sources/Swarm/HiveSwarm/ChatGraph.swift:203
RuntimeContext.systemPrompt	swift.property	public	let systemPrompt: String?	Sources/Swarm/HiveSwarm/ChatGraph.swift:199
RuntimeContext.compactionPolicy	swift.property	public	let compactionPolicy: HiveCompactionPolicy?	Sources/Swarm/HiveSwarm/ChatGraph.swift:201
RuntimeContext.toolApprovalPolicy	swift.property	public	let toolApprovalPolicy: ToolApprovalPolicy	Sources/Swarm/HiveSwarm/ChatGraph.swift:200
RuntimeContext.membraneCheckpointAdapter	swift.property	public	let membraneCheckpointAdapter: (any MembraneCheckpointAdapter)?	Sources/Swarm/HiveSwarm/ChatGraph.swift:204
RuntimeContext.init(modelName:systemPrompt:toolApprovalPolicy:compactionPolicy:tokenizer:retryPolicy:membraneCheckpointAdapter:)	swift.init	public	init(modelName: String, systemPrompt: String? = nil, toolApprovalPolicy: ToolApprovalPolicy = .never, compactionPolicy: HiveCompactionPolicy? = nil, tokenizer: (any HiveTokenizer)? = nil, retryPolicy: HiveRetryPolicy? = nil, membraneCheckpointAdapter: (any MembraneCheckpointAdapter)? = nil)	Sources/Swarm/HiveSwarm/ChatGraph.swift:206
RuntimeContext.modelName	swift.property	public	let modelName: String	Sources/Swarm/HiveSwarm/ChatGraph.swift:198
RuntimeContext.tokenizer	swift.property	public	let tokenizer: (any HiveTokenizer)?	Sources/Swarm/HiveSwarm/ChatGraph.swift:202
MessageIDFactory	swift.protocol	public	protocol MessageIDFactory : Sendable	Sources/Swarm/HiveSwarm/ChatGraph.swift:29
MessageIDFactory.messageID(for:taskID:stepIndex:)	swift.method	public	func messageID(for role: String, taskID: HiveTaskID, stepIndex: Int) -> String	Sources/Swarm/HiveSwarm/ChatGraph.swift:37
NoopPreModelHook	swift.struct	public	struct NoopPreModelHook	Sources/Swarm/HiveSwarm/ChatGraph.swift:59
NoopPreModelHook.transform(messages:systemPrompt:context:)	swift.method	public	func transform(messages: [HiveChatMessage], systemPrompt: String, context _: RuntimeContext) async -> (messages: [HiveChatMessage], systemPrompt: String)	Sources/Swarm/HiveSwarm/ChatGraph.swift:62
NoopPreModelHook.init()	swift.init	public	init()	Sources/Swarm/HiveSwarm/ChatGraph.swift:60
RetryPolicyBridge	swift.enum	public	enum RetryPolicyBridge	Sources/Swarm/HiveSwarm/RetryPolicyBridge.swift:22
RetryPolicyBridge.toHive(_:)	swift.type.method	public	static func toHive(_ policy: RetryPolicy) -> HiveRetryPolicy	Sources/Swarm/HiveSwarm/RetryPolicyBridge.swift:28
EventSchemaVersion	swift.enum	public	enum EventSchemaVersion	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:8
EventSchemaVersion.metadataKey	swift.type.property	public	static let metadataKey: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:9
EventSchemaVersion.current	swift.type.property	public	static let current: String	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:10
GraphRunController	swift.struct	public	struct GraphRunController	Sources/Swarm/HiveSwarm/ChatGraph.swift:235
GraphRunController.validateRunOptions(_:)	swift.method	public	func validateRunOptions(_ options: HiveRunOptions) throws	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:695
GraphRunController.getCheckpoint(threadID:id:)	swift.method	public	func getCheckpoint(threadID: HiveThreadID, id: HiveCheckpointID) async throws -> HiveCheckpoint<ChatGraph.Schema>?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:880
GraphRunController.applyExternalWrites(threadID:writes:options:)	swift.method	public	func applyExternalWrites(threadID: HiveThreadID, writes: [AnyHiveWrite<ChatGraph.Schema>], options: HiveRunOptions = HiveRunOptions()) async throws -> HiveRunHandle<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:832
GraphRunController.getCheckpointHistory(threadID:limit:)	swift.method	public	func getCheckpointHistory(threadID: HiveThreadID, limit: Int? = nil) async throws -> [HiveCheckpointSummary]	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:873
GraphRunController.validateResumeRequest(threadID:interruptID:)	swift.method	public	func validateResumeRequest(threadID: HiveThreadID, interruptID: HiveInterruptID) async throws	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:760
GraphRunController.checkpointQueryCapability(probeThreadID:)	swift.method	public	func checkpointQueryCapability(probeThreadID: HiveThreadID = HiveThreadID("__hive_checkpoint_capability_probe__")) async -> HiveCheckpointQueryCapability	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:854
GraphRunController.start(threadID:input:options:)	swift.method	public	func start(threadID: HiveThreadID, input: String, options: HiveRunOptions = HiveRunOptions()) async throws -> HiveRunHandle<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/ChatGraph.swift:246
GraphRunController.resume(threadID:interruptID:payload:options:)	swift.method	public	func resume(threadID: HiveThreadID, interruptID: HiveInterruptID, payload: ChatGraph.Resume, options: HiveRunOptions = HiveRunOptions()) async throws -> HiveRunHandle<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/ChatGraph.swift:257
GraphRunController.runtime	swift.property	public	let runtime: HiveRuntime<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/ChatGraph.swift:236
GraphRunController.init(runtime:)	swift.init	public	init(runtime: HiveRuntime<ChatGraph.Schema>)	Sources/Swarm/HiveSwarm/ChatGraph.swift:239
GraphRunController.decorate(event:)	swift.type.method	public	static func decorate(event: HiveEvent) -> HiveEvent	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:687
GraphRunController.decorate(handle:threadID:eventBufferCapacity:)	swift.method	public	func decorate(handle: HiveRunHandle<ChatGraph.Schema>, threadID: HiveThreadID, eventBufferCapacity: Int) -> HiveRunHandle<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:799
GraphRunController.getState(threadID:)	swift.method	public	func getState(threadID: HiveThreadID) async throws -> HiveRuntimeStateSnapshot<ChatGraph.Schema>?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:887
ToolApprovalPolicy	swift.enum	public	enum ToolApprovalPolicy	Sources/Swarm/HiveSwarm/ChatGraph.swift:6
ToolApprovalPolicy.never	swift.enum.case	public	case never	Sources/Swarm/HiveSwarm/ChatGraph.swift:7
ToolApprovalPolicy.always	swift.enum.case	public	case always	Sources/Swarm/HiveSwarm/ChatGraph.swift:8
ToolApprovalPolicy.allowList(_:)	swift.enum.case	public	case allowList(Set<String>)	Sources/Swarm/HiveSwarm/ChatGraph.swift:9
GraphRuntimeAdapter	swift.struct	public	struct GraphRuntimeAdapter	Sources/Swarm/HiveSwarm/ChatGraph.swift:225
GraphRuntimeAdapter.runControl	swift.property	public	let runControl: GraphRunController	Sources/Swarm/HiveSwarm/ChatGraph.swift:226
GraphRuntimeAdapter.init(runControl:)	swift.init	public	init(runControl: GraphRunController)	Sources/Swarm/HiveSwarm/ChatGraph.swift:228
ToolRegistryAdapter	swift.struct	public	struct ToolRegistryAdapter	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:18
ToolRegistryAdapter.fromRegistry(_:)	swift.type.method	public	static func fromRegistry(_ registry: ToolRegistry) async throws -> ToolRegistryAdapter	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:38
ToolRegistryAdapter.init(tools:)	swift.init	public	init(tools: [any AnyJSONTool]) throws	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:22
ToolRegistryAdapter.invoke(_:)	swift.method	public	func invoke(_ call: HiveToolCall) async throws -> HiveToolResult	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:50
ToolRegistryAdapter.listTools()	swift.method	public	func listTools() -> [HiveToolDefinition]	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:46
ToolResultTransformer	swift.protocol	public	protocol ToolResultTransformer : Sendable	Sources/Swarm/HiveSwarm/ChatGraph.swift:40
ToolResultTransformer.transform(result:toolName:tokenEstimate:)	swift.method	public	func transform(result: String, toolName: String, tokenEstimate: Int) async -> String	Sources/Swarm/HiveSwarm/ChatGraph.swift:48
DefaultMessageIDFactory	swift.struct	public	struct DefaultMessageIDFactory	Sources/Swarm/HiveSwarm/ChatGraph.swift:71
DefaultMessageIDFactory.messageID(for:taskID:stepIndex:)	swift.method	public	func messageID(for role: String, taskID: HiveTaskID, stepIndex: Int) -> String	Sources/Swarm/HiveSwarm/ChatGraph.swift:74
DefaultMessageIDFactory.init()	swift.init	public	init()	Sources/Swarm/HiveSwarm/ChatGraph.swift:72
ToolRegistryAdapterError	swift.enum	public	enum ToolRegistryAdapterError	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:5
ToolRegistryAdapterError.duplicateToolName(_:)	swift.enum.case	public	case duplicateToolName(String)	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:12
ToolRegistryAdapterError.toolNotFound(name:)	swift.enum.case	public	case toolNotFound(name: String)	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:10
ToolRegistryAdapterError.invalidArgumentsJSON	swift.enum.case	public	case invalidArgumentsJSON	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:6
ToolRegistryAdapterError.resultEncodingFailed	swift.enum.case	public	case resultEncodingFailed	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:8
ToolRegistryAdapterError.schemaEncodingFailed	swift.enum.case	public	case schemaEncodingFailed	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:9
ToolRegistryAdapterError.toolInvocationFailed(name:reason:)	swift.enum.case	public	case toolInvocationFailed(name: String, reason: String)	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:11
ToolRegistryAdapterError.argumentsMustBeJSONObject	swift.enum.case	public	case argumentsMustBeJSONObject	Sources/Swarm/HiveSwarm/ToolRegistryAdapter.swift:7
MembraneCheckpointAdapter	swift.protocol	public	protocol MembraneCheckpointAdapter : Sendable	Sources/Swarm/HiveSwarm/ChatGraph.swift:51
MembraneCheckpointAdapter.snapshotCheckpointData()	swift.method	public	func snapshotCheckpointData() async throws -> Data?	Sources/Swarm/HiveSwarm/ChatGraph.swift:56
MembraneCheckpointAdapter.restore(checkpointData:)	swift.method	public	func restore(checkpointData: Data?) async throws	Sources/Swarm/HiveSwarm/ChatGraph.swift:53
NoopToolResultTransformer	swift.struct	public	struct NoopToolResultTransformer	Sources/Swarm/HiveSwarm/ChatGraph.swift:92
NoopToolResultTransformer.transform(result:toolName:tokenEstimate:)	swift.method	public	func transform(result: String, toolName _: String, tokenEstimate _: Int) async -> String	Sources/Swarm/HiveSwarm/ChatGraph.swift:95
NoopToolResultTransformer.init()	swift.init	public	init()	Sources/Swarm/HiveSwarm/ChatGraph.swift:93
ChatGraph	swift.enum	public	enum ChatGraph	Sources/Swarm/HiveSwarm/ChatGraph.swift:100
ChatGraph.makeToolUsingChatAgent(preModel:postModel:preModelHook:toolProvider:messageIDFactory:toolResultTransformer:)	swift.type.method	public	static func makeToolUsingChatAgent(preModel: HiveNode<ChatGraph.Schema>? = nil, postModel: HiveNode<ChatGraph.Schema>? = nil, preModelHook: (any PreModelHook)? = nil, toolProvider: ToolProvider? = nil, messageIDFactory: (any MessageIDFactory)? = nil, toolResultTransformer: (any ToolResultTransformer)? = nil) throws -> CompiledHiveGraph<ChatGraph.Schema>	Sources/Swarm/HiveSwarm/ChatGraph.swift:131
ChatGraph.removeAllMessagesID	swift.type.property	public	static let removeAllMessagesID: String	Sources/Swarm/HiveSwarm/ChatGraph.swift:101
ChatGraph.ToolApprovalDecision	swift.enum	public	enum ToolApprovalDecision	Sources/Swarm/HiveSwarm/ChatGraph.swift:103
ChatGraph.ToolApprovalDecision.approved	swift.enum.case	public	case approved	Sources/Swarm/HiveSwarm/ChatGraph.swift:104
ChatGraph.ToolApprovalDecision.init(rawValue:)	swift.init	public	init?(rawValue: String)	
ChatGraph.ToolApprovalDecision.rejected	swift.enum.case	public	case rejected	Sources/Swarm/HiveSwarm/ChatGraph.swift:105
ChatGraph.ToolApprovalDecision.cancelled	swift.enum.case	public	case cancelled	Sources/Swarm/HiveSwarm/ChatGraph.swift:106
ChatGraph.Resume	swift.enum	public	enum Resume	Sources/Swarm/HiveSwarm/ChatGraph.swift:113
ChatGraph.Resume.toolApproval(decision:)	swift.enum.case	public	case toolApproval(decision: ChatGraph.ToolApprovalDecision)	Sources/Swarm/HiveSwarm/ChatGraph.swift:114
ChatGraph.Resume.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
ChatGraph.Schema	swift.struct	public	struct Schema	Sources/Swarm/HiveSwarm/ChatGraph.swift:277
ChatGraph.Schema.inputWrites(_:inputContext:)	swift.type.method	public	static func inputWrites(_ input: String, inputContext: HiveInputContext) throws -> [AnyHiveWrite<ChatGraph.Schema>]	Sources/Swarm/HiveSwarm/ChatGraph.swift:349
ChatGraph.Schema.messagesKey	swift.type.property	public	static let messagesKey: HiveChannelKey<ChatGraph.Schema, [HiveChatMessage]>	Sources/Swarm/HiveSwarm/ChatGraph.swift:283
ChatGraph.Schema.channelSpecs	swift.type.property	public	static var channelSpecs: [AnyHiveChannelSpec<ChatGraph.Schema>] { get }	Sources/Swarm/HiveSwarm/ChatGraph.swift:289
ChatGraph.Schema.ResumePayload	swift.typealias	public	typealias ResumePayload = ChatGraph.Resume	Sources/Swarm/HiveSwarm/ChatGraph.swift:281
ChatGraph.Schema.finalAnswerKey	swift.type.property	public	static let finalAnswerKey: HiveChannelKey<ChatGraph.Schema, String?>	Sources/Swarm/HiveSwarm/ChatGraph.swift:285
ChatGraph.Schema.InterruptPayload	swift.typealias	public	typealias InterruptPayload = ChatGraph.Interrupt	Sources/Swarm/HiveSwarm/ChatGraph.swift:280
ChatGraph.Schema.llmInputMessagesKey	swift.type.property	public	static let llmInputMessagesKey: HiveChannelKey<ChatGraph.Schema, [HiveChatMessage]?>	Sources/Swarm/HiveSwarm/ChatGraph.swift:286
ChatGraph.Schema.pendingToolCallsKey	swift.type.property	public	static let pendingToolCallsKey: HiveChannelKey<ChatGraph.Schema, [HiveToolCall]>	Sources/Swarm/HiveSwarm/ChatGraph.swift:284
ChatGraph.Schema.membraneCheckpointDataKey	swift.type.property	public	static let membraneCheckpointDataKey: HiveChannelKey<ChatGraph.Schema, Data?>	Sources/Swarm/HiveSwarm/ChatGraph.swift:287
ChatGraph.Schema.Input	swift.typealias	public	typealias Input = String	Sources/Swarm/HiveSwarm/ChatGraph.swift:279
ChatGraph.Schema.Context	swift.typealias	public	typealias Context = RuntimeContext	Sources/Swarm/HiveSwarm/ChatGraph.swift:278
ChatGraph.Interrupt	swift.enum	public	enum Interrupt	Sources/Swarm/HiveSwarm/ChatGraph.swift:109
ChatGraph.Interrupt.toolApprovalRequired(toolCalls:)	swift.enum.case	public	case toolApprovalRequired(toolCalls: [HiveToolCall])	Sources/Swarm/HiveSwarm/ChatGraph.swift:110
ChatGraph.Interrupt.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
HiveDeterminismDiff.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveCanonicalTranscript.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveStateSnapshotSource.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveCanonicalEventRecord.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeStateSnapshot.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeFrontierSummary.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeFrontierSummary.Entry.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveCheckpointQueryCapability.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveCancelCheckpointResolution.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeChannelStateSummary.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeChannelStateSummary.Entry.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveRuntimeInterruptionSummary.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
HiveTranscriptCompatibilityError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolApprovalPolicy.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ToolRegistryAdapterError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ChatGraph.ToolApprovalDecision.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
ChatGraph.ToolApprovalDecision.encode(to:)	swift.method	public	func encode(to encoder: any Encoder) throws	
ChatGraph.ToolApprovalDecision.hashValue	swift.property	public	var hashValue: Int { get }	
ChatGraph.ToolApprovalDecision.hash(into:)	swift.method	public	func hash(into hasher: inout Hasher)	
ChatGraph.ToolApprovalDecision.init(from:)	swift.init	public	init(from decoder: any Decoder) throws	
HiveTranscriptCompatibilityError.localizedDescription	swift.property	public	var localizedDescription: String { get }	
ToolRegistryAdapterError.localizedDescription	swift.property	public	var localizedDescription: String { get }	

## SwarmHive@HiveCore (1 symbols)
HiveRuntime.getState(threadID:)	swift.method	public	func getState(threadID: HiveThreadID) async throws -> HiveRuntimeStateSnapshot<Schema>?	Sources/Swarm/HiveSwarm/RuntimeHardening.swift:1146

## SwarmMCP (39 symbols)
SwarmMCPToolCatalog	swift.protocol	public	protocol SwarmMCPToolCatalog : Sendable	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:5
SwarmMCPToolCatalog.listTools()	swift.method	public	func listTools() async throws -> [ToolSchema]	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:7
SwarmMCPToolExecutor	swift.protocol	public	protocol SwarmMCPToolExecutor : Sendable	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:11
SwarmMCPToolExecutor.executeTool(named:arguments:)	swift.method	public	func executeTool(named toolName: String, arguments: [String : SendableValue]) async throws -> SendableValue	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:13
SwarmMCPServerService	swift.class	public	actor SwarmMCPServerService	Sources/SwarmMCP/SwarmMCPServerService.swift:6
SwarmMCPServerService.startStdio(initializeHook:)	swift.method	public	func startStdio(initializeHook: ((Client.Info, Client.Capabilities) async throws -> Void)? = nil) async throws	Sources/SwarmMCP/SwarmMCPServerService.swift:115
SwarmMCPServerService.snapshotMetrics()	swift.method	public	func snapshotMetrics() -> SwarmMCPServerService.Metrics	Sources/SwarmMCP/SwarmMCPServerService.swift:136
SwarmMCPServerService.waitUntilCompleted()	swift.method	public	func waitUntilCompleted() async	Sources/SwarmMCP/SwarmMCPServerService.swift:131
SwarmMCPServerService.init(name:version:instructions:toolCatalog:toolExecutor:configuration:maxRequestsPerSecond:maxConcurrentRequests:)	swift.init	public	init(name: String = "swarm-mcp-server", version: String = Swarm.version, instructions: String? = nil, toolCatalog: some SwarmMCPToolCatalog, toolExecutor: some SwarmMCPToolExecutor, configuration: Server.Configuration = .strict, maxRequestsPerSecond: Double = 10, maxConcurrentRequests: Int = 50)	Sources/SwarmMCP/SwarmMCPServerService.swift:57
SwarmMCPServerService.name	swift.property	public	nonisolated let name: String	Sources/SwarmMCP/SwarmMCPServerService.swift:38
SwarmMCPServerService.stop()	swift.method	public	func stop() async	Sources/SwarmMCP/SwarmMCPServerService.swift:123
SwarmMCPServerService.start(transport:initializeHook:)	swift.method	public	func start(transport: any Transport, initializeHook: ((Client.Info, Client.Capabilities) async throws -> Void)? = nil) async throws	Sources/SwarmMCP/SwarmMCPServerService.swift:86
SwarmMCPServerService.Metrics	swift.struct	public	struct Metrics	Sources/SwarmMCP/SwarmMCPServerService.swift:7
SwarmMCPServerService.Metrics.listedToolCount	swift.property	public	var listedToolCount: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:9
SwarmMCPServerService.Metrics.callToolFailures	swift.property	public	var callToolFailures: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:12
SwarmMCPServerService.Metrics.callToolRequests	swift.property	public	var callToolRequests: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:10
SwarmMCPServerService.Metrics.callToolSuccesses	swift.property	public	var callToolSuccesses: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:11
SwarmMCPServerService.Metrics.init(listToolsRequests:listedToolCount:callToolRequests:callToolSuccesses:callToolFailures:approvalRequiredCount:approvalRejectedCount:cumulativeCallToolLatencyMs:)	swift.init	public	init(listToolsRequests: Int = 0, listedToolCount: Int = 0, callToolRequests: Int = 0, callToolSuccesses: Int = 0, callToolFailures: Int = 0, approvalRequiredCount: Int = 0, approvalRejectedCount: Int = 0, cumulativeCallToolLatencyMs: Double = 0)	Sources/SwarmMCP/SwarmMCPServerService.swift:17
SwarmMCPServerService.Metrics.listToolsRequests	swift.property	public	var listToolsRequests: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:8
SwarmMCPServerService.Metrics.approvalRejectedCount	swift.property	public	var approvalRejectedCount: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:14
SwarmMCPServerService.Metrics.approvalRequiredCount	swift.property	public	var approvalRequiredCount: Int	Sources/SwarmMCP/SwarmMCPServerService.swift:13
SwarmMCPServerService.Metrics.cumulativeCallToolLatencyMs	swift.property	public	var cumulativeCallToolLatencyMs: Double	Sources/SwarmMCP/SwarmMCPServerService.swift:15
SwarmMCPServerService.version	swift.property	public	nonisolated let version: String	Sources/SwarmMCP/SwarmMCPServerService.swift:39
SwarmMCPToolExecutionError	swift.enum	public	enum SwarmMCPToolExecutionError	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:17
SwarmMCPToolExecutionError.approvalRequired(prompt:reason:metadata:)	swift.enum.case	public	case approvalRequired(prompt: String, reason: String?, metadata: [String : SendableValue])	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:19
SwarmMCPToolExecutionError.permissionDenied(reason:metadata:)	swift.enum.case	public	case permissionDenied(reason: String, metadata: [String : SendableValue])	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:26
SwarmMCPToolRegistryAdapter	swift.class	public	actor SwarmMCPToolRegistryAdapter	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:33
SwarmMCPToolRegistryAdapter.executeTool(named:arguments:)	swift.method	public	func executeTool(named toolName: String, arguments: [String : SendableValue]) async throws -> SendableValue	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:44
SwarmMCPToolRegistryAdapter.init(registry:)	swift.init	public	init(registry: ToolRegistry)	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:36
SwarmMCPToolRegistryAdapter.listTools()	swift.method	public	func listTools() async throws -> [ToolSchema]	Sources/SwarmMCP/SwarmMCPToolAdapter.swift:40
SwarmMCPServerService.Metrics.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SwarmMCPToolExecutionError.!=(_:_:)	swift.func.op	public	static func != (lhs: Self, rhs: Self) -> Bool	
SwarmMCPServerService.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwarmMCPToolRegistryAdapter.assertIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func assertIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwarmMCPServerService.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SwarmMCPToolRegistryAdapter.assumeIsolated(_:file:line:)	swift.method	public	nonisolated func assumeIsolated<T>(_ operation: (isolated Self) throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows -> T where T : Sendable	
SwarmMCPServerService.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwarmMCPToolRegistryAdapter.preconditionIsolated(_:file:line:)	swift.method	public	@backDeployed(before: macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0) nonisolated func preconditionIsolated(_ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line)	
SwarmMCPToolExecutionError.localizedDescription	swift.property	public	var localizedDescription: String { get }	

## SwarmMembrane (0 symbols)
(No public symbols)

