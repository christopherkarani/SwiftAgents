Prompt:
Preserve Base.Loop type in ConfiguredAgent instead of erasing to AgentLoopSequence.

Goal:
Maintain loop type fidelity for compile-time guarantees.

Task Breakdown:
- Update ConfiguredAgent to use associatedtype Loop = Base.Loop.
- Return `Base.Loop` from loop property.
- Validate AgentLoopBuilder compatibility.

Expected Output:
- ConfiguredAgent loop type preserved and compiling.

Constraints:
- Avoid type erasure unless necessary.
