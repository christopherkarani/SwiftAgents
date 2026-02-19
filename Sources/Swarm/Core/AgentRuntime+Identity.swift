import Foundation

/// Stable runtime identity for deterministic agent instance matching.
///
/// For class/actor-based runtimes, identity is reference-based.
/// For value-type runtimes, identity falls back to a deterministic value fingerprint.
struct AgentRuntimeIdentity: Hashable, Sendable {
    private enum Storage: Hashable, Sendable {
        case reference(ObjectIdentifier)
        case value(type: ObjectIdentifier, fingerprint: String)
    }

    private let storage: Storage

    init(_ runtime: any AgentRuntime) {
        if type(of: runtime) is AnyObject.Type {
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
