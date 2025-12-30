Verifier Lifecycle for Genesis-Anchored Light Clients

Abstract

This note defines the lifecycle of a Genesis-Anchored Light Client verifier: the distinct operational phases a verifier transitions through while maintaining trust guarantees derived from a genesis anchor.
The lifecycle formalizes when a verifier accepts, rejects, defers, or refuses verification based on available state, resources, and connectivity.

This model treats verification as a stateful process over time, not a one-shot computation.

⸻

1. Scope and Non-Goals

In Scope

	•	Verifier state transitions
	•	Conditions for acceptance and refusal
	•	Offline and intermittent operation
	•	Bounded resource assumptions

Out of Scope

	•	Execution of transactions
	•	Consensus participation
	•	Network topology or gossip mechanisms
	•	Full node or validator behavior

This document concerns verification only.

⸻

2. Lifecycle Overview

A Genesis-Anchored Light Client verifier progresses through the following phases:

	1.	Initialization
	2.	Anchored Validation
	3.	Steady-State Verification
	4.	Bounded Operation
	5.	Refusal
	6.	Recovery / Resumption

These phases are logical states, not necessarily sequential or permanent.

⸻

3. Phase 1 — Initialization

Description

The verifier is instantiated with:

	•	The genesis anchor (as defined in GALV)
	•	The minimal persistent state (as defined in 0x01)

At this phase, the verifier does not assume:

	•	Network connectivity
	•	Liveness of peers
	•	Availability of historical data

Guarantees

	•	The verifier knows where trust begins
	•	No claims beyond the anchor are accepted

Initialization is a trust bootstrapping step, not a synchronization step.

⸻

4. Phase 2 — Anchored Validation

Description

The verifier validates that:

	•	All observed statements trace back to the genesis anchor
	•	No alternative lineage is substituted
	•	The anchor has not been altered or replaced

This may include:

	•	Hash linkage checks
	•	Header continuity checks
	•	Statement lineage verification

Guarantees

	•	Lineage integrity
	•	Temporal ordering derived from the anchor
	•	Protection against hidden restarts or rewrites

At this phase, verification is structural, not semantic.

⸻

5. Phase 3 — Steady-State Verification

Description

The verifier operates normally by:

	•	Accepting new statements
	•	Verifying them against the current state frontier
	•	Advancing its internal verification state

The verifier does not require:

	•	Full history
	•	Full execution traces
	•	Continuous connectivity

Guarantees

	•	Deterministic verification results
	•	Monotonic advancement of trusted state
	•	Bounded growth of stored state

This is the expected long-running mode of operation.

⸻

6. Phase 4 — Bounded Operation

Description

The verifier encounters one or more constraints:

	•	Memory limits
	•	Compute limits
	•	Proof size limits
	•	Time or latency constraints

Rather than degrade security, the verifier restricts behavior.

Possible actions:

	•	Stop accepting new statements
	•	Require stronger proofs
	•	Delay verification
	•	Enter refusal state

Guarantees

	•	No silent acceptance of unverifiable data
	•	Explicit enforcement of resource bounds

Bounded operation is designed behavior, not an error condition.

⸻

7. Phase 5 — Refusal

Description

The verifier enters refusal when:

	•	Required verification conditions cannot be met
	•	Proofs are missing or malformed
	•	Resource limits are exceeded
	•	Lineage cannot be established

In refusal:

	•	No claims are accepted
	•	No state is advanced
	•	Existing verified state remains trusted

Guarantees

	•	Safety over liveness
	•	No false positives
	•	Explicit signaling of uncertainty

Refusal is a correct and secure outcome.

This phase is essential to bounded verification.

⸻

8. Phase 6 — Recovery / Resumption

Description

The verifier resumes verification when:

	•	Missing data becomes available
	•	Connectivity is restored
	•	Resource pressure is reduced
	•	Stronger proofs are supplied

Recovery does not require:

	•	Restarting from genesis
	•	Re-executing history
	•	Trusting external actors

Guarantees

	•	Continuity of trust
	•	Deterministic resumption
	•	No rollback of verified state

⸻

9. Lifecycle Invariants

Across all phases, the verifier maintains:

	•	Anchor immutability
	•	Deterministic verification
	•	Explicit refusal semantics
	•	Bounded resource usage

These invariants ensure that the verifier never:

	•	Accepts unverifiable claims
	•	Assumes hidden trust
	•	Violates its own constraints

⸻

10. Relationship to Other Notes

	•	0x00 (GALV): Defines the anchor that enables the lifecycle
	•	0x01 (Minimal State Tracking): Defines what state persists across phases
	•	0x03 (Bounded Verification & Refusal): Formalizes refusal semantics introduced here
	•	Later notes: Build on this lifecycle to reach edge-native verification

⸻

11. Summary

Verification is not a binary event — it is a lifecycle governed by constraints.

A Genesis-Anchored Light Client verifier:

	•	Starts with a fixed point of truth
	•	Advances deterministically
	•	Refuses safely when limits are reached
	•	Recovers without trust regression

This lifecycle is the foundation for offline-resilient, edge-native verification systems.
