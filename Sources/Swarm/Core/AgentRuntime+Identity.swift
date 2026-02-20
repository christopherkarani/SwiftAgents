import Foundation

/// Stable runtime identity for deterministic agent instance matching.
///
/// For class/actor-based runtimes, identity is reference-based.
/// For value-type runtimes, identity falls back to a deterministic value fingerprint.
/// Types that need explicit identity should conform to `AgentRuntimeIdentifiable`.
public protocol AgentRuntimeIdentifiable: Sendable {
    /// A stable identifier to disambiguate runtime instances (for value types).
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
        if let identifiable = runtime as? any AgentRuntimeIdentifiable {
            storage = .custom(
                type: ObjectIdentifier(type(of: runtime)),
                id: identifiable.runtimeIdentity
            )
        } else if type(of: runtime) is AnyObject.Type {
            storage = .reference(ObjectIdentifier(runtime as AnyObject))
        } else {
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
