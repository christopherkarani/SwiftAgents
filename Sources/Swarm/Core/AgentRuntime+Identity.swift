import Foundation

/// Stable runtime identity for deterministic agent instance matching.
///
/// For class/actor-based runtimes, identity is reference-based.
/// For value-type runtimes, identity falls back to a deterministic value fingerprint.
/// Types that need explicit identity should conform to `AgentRuntimeIdentifiable`.
///
/// ## Conforming to `AgentRuntimeIdentifiable`
///
/// Conform to this protocol when your agent is a value type and you need two
/// separate instances with the same logical identity to compare as equal in the
/// orchestration layer (e.g., the same agent registered twice in different
/// contexts). Class- and actor-based runtimes automatically use reference
/// identity and do **not** need to conform.
///
/// ```swift
/// struct MyAgent: AgentRuntime, AgentRuntimeIdentifiable {
///     let id: String
///     var runtimeIdentity: String { id }
///     // ...
/// }
/// ```
///
/// - Note: `runtimeIdentity` is consumed internally by `areSameRuntime`. The
///   `AgentRuntimeIdentity` type used for matching is not part of the public API.
public protocol AgentRuntimeIdentifiable: Sendable {
    /// A stable string identifier used to disambiguate runtime instances.
    ///
    /// Must be stable across calls for the lifetime of the agent instance.
    /// Used only for value-type agents; class/actor runtimes use reference identity.
    var runtimeIdentity: String { get }
}

struct AgentRuntimeIdentity: Hashable, Sendable {
    private enum Storage: Hashable, Sendable {
        case custom(type: ObjectIdentifier, id: String)
        case reference(ObjectIdentifier)
        case value(type: ObjectIdentifier, fingerprint: String)
    }

    private let storage: Storage

    init(_ runtime: any AgentRuntime) {
        // Reference types (class/actor) always use object identity — checked first so
        // that conforming to `AgentRuntimeIdentifiable` on a class/actor does not
        // silently replace stable pointer-based identity with a potentially colliding
        // string identity.
        if type(of: runtime) is AnyObject.Type {
            storage = .reference(ObjectIdentifier(runtime as AnyObject))
        } else if let identifiable = runtime as? any AgentRuntimeIdentifiable {
            // Value-type agents that explicitly declare identity via the protocol.
            storage = .custom(
                type: ObjectIdentifier(type(of: runtime)),
                id: identifiable.runtimeIdentity
            )
        } else {
            // `String(reflecting:)` is used as a best-effort fingerprint for value
            // types that don't conform to `AgentRuntimeIdentifiable`. Two instances
            // with identical stored properties will compare as equal (intended), but
            // the string can include reference-type descriptions that vary across
            // runs. For stable, cross-run identity, conform to `AgentRuntimeIdentifiable`.
            storage = .value(
                type: ObjectIdentifier(type(of: runtime)),
                fingerprint: String(reflecting: runtime)
            )
        }
    }
}

@inline(__always)
func areSameRuntime(_ lhs: any AgentRuntime, _ rhs: any AgentRuntime) -> Bool {
    AgentRuntimeIdentity(lhs) == AgentRuntimeIdentity(rhs)
}
