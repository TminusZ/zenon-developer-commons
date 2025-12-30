Minimal State Tracking for Genesis-Anchored Light Clients

A Research Note

Abstract

Genesis-Anchored Lineage Verification (GALV) establishes an unforgeable starting point and time anchor for light clients by binding a chain’s origin to an external proof-of-work timechain. However, a trusted origin alone is insufficient for ongoing verification. A light client must also determine whether the current observed state remains consistent with that origin, without downloading or executing the full chain.

This note introduces Minimal State Tracking, a verification model that defines the smallest state summary a light client must maintain to remain synchronized with a genesis-anchored ledger. The goal is not full execution verification, but bounded, deterministic confidence that the client remains on the same lineage and state trajectory over time.

This document is non-normative and exploratory. It defines verification primitives, invariants, and threat boundaries rather than a complete protocol.

⸻

1. Motivation

Light clients face a fundamental tension:
	•	Security requires strong guarantees about chain history and state.
	•	Accessibility requires bounded bandwidth, storage, and computation.

GALV resolves the first half of this tension by anchoring trust in genesis. Minimal State Tracking addresses the second by answering:

Given a trusted genesis, what is the smallest amount of information a light client must track to know it is still observing the same chain?

This question is especially relevant for:

	•	Browser-based clients
	•	Offline or intermittently connected environments
	•	Satellite or broadcast-only data feeds
	•	Resource-constrained verification contexts

⸻

2. Scope and Non-Goals

In Scope

	•	Deterministic state summaries
	•	Bounded verification memory
	•	Lineage continuity after genesis
	•	Offline-resilient synchronization

Explicitly Out of Scope

	•	Full transaction execution verification
	•	Fraud proofs or validity proofs
	•	Data availability guarantees
	•	MEV or ordering guarantees
	•	Zero-knowledge constructions

This model is intended to compose with, not replace, other verification techniques.

⸻

3. Model Overview

We assume the following:

	1.	Genesis Trust
The client possesses a trusted genesis anchor (e.g., via GALV).

	2.	Monotonic State Evolution
The ledger evolves through discrete global state transitions (e.g., momentums).

	3.	Deterministic State Commitments
Each global transition commits to a canonical representation of state.

Under these assumptions, a light client does not need:

	•	All transactions
	•	All account states
	•	All historical blocks

It only needs a state frontier.

⸻

4. The State Frontier

Definition

A state frontier is a compact, deterministic summary of the ledger’s global state at a given transition height.

Formally, the state frontier must satisfy:

	•	Determinism
Given the same prior frontier and the same transition, all honest validators derive the same new frontier.

	•	Monotonicity
Each frontier strictly advances from its predecessor.

	•	Binding
The frontier commits to all state changes up to that point.

	•	Bounded Size
The frontier is constant-size or logarithmically bounded.

⸻

5. Minimal Tracking Invariant

A light client maintains only:

	•	The trusted genesis anchor
	•	The most recent accepted state frontier
	•	The height (or sequence number) of that frontier

Verification reduces to checking:

“Does this new frontier validly descend from the previous frontier?”

If yes, the client remains synchronized.
If no, the client halts or requests additional data.

⸻

6. Update Verification

For each proposed state update, the client verifies:

	1.	Lineage Continuity
The new frontier references the prior frontier.

	2.	Height Progression
The transition index strictly increases.

	3.	Commitment Consistency
The state commitment format matches the canonical specification.

No execution, replay, or transaction inspection is required.

⸻

7. Threat Model

This model protects against:

	•	History rewriting after genesis
	•	Fork substitution attacks
	•	Fake chain injection
	•	Offline eclipse attacks with bounded duration

It does not protect against:

	•	Invalid execution within a committed state
	•	Data withholding attacks
	•	Collusion among a majority of validators

These risks must be addressed by higher-layer mechanisms.

⸻

8. Relationship to Existing Work

Minimal State Tracking is orthogonal to:

	•	Bitcoin SPV (transaction inclusion)
	•	Flyclient (probabilistic block sampling)
	•	zk-based light clients (execution proofs)

Instead, it occupies a distinct niche:

State continuity verification without execution verification

This distinction is critical for low-resource environments.

⸻

9. Composition with GALV

GALV establishes where trust begins.
Minimal State Tracking establishes how trust continues.

Together, they form:

	•	A genesis-anchored
	•	Offline-resilient
	•	Bounded-resource
	•	Light client verification stack

Neither component is sufficient alone.

⸻

10. Limitations and Future Work

This note intentionally stops short of:

	•	Defining concrete commitment formats
	•	Specifying validator behavior
	•	Proposing protocol changes

Future work may explore:

	•	Concrete frontier constructions
	•	Partial execution verification
	•	Cross-chain state commitments
	•	Data availability extensions

⸻

11. Conclusion

Minimal State Tracking reframes light client security as a problem of state continuity, not execution replay. By maintaining only a trusted genesis anchor and a bounded state frontier, a client can remain confidently synchronized with a ledger over time, even in constrained or adversarial network conditions.

This approach does not eliminate trust—it minimizes and localizes it.
