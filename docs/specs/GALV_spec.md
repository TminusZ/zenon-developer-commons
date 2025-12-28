Genesis-Anchored Lineage Verification (GALV)

A Minimal Verification Specification for Offline-Resilient Light Clients

⸻

1. Purpose

This document specifies Genesis-Anchored Lineage Verification (GALV), a minimal verification primitive enabling light clients to cryptographically verify network identity and origin continuity without replaying full history.

GALV addresses the following problem:

How can a resource-constrained or offline light client verify that a presented state belongs to the same network instance it previously observed, rather than a fabricated, restarted, or backdated alternative?

This specification defines what must be verified to establish origin authenticity and lineage continuity.
It does not specify consensus rules, execution validity, data availability, fork choice, or networking.

⸻

2. Definitions

Genesis
The initial state commitment from which all valid states of a system are deterministically derived.

External Anchor
A cryptographically immutable reference external to the system (e.g., a proof-of-work blockchain block) that provides a verifiable lower bound on the earliest possible existence time of genesis.

Genesis Anchor Commitment
A cryptographic commitment within genesis that binds it to a specific external anchor.

Lineage
The property that a state is a deterministic descendant of a specific genesis via cryptographic parent commitments.

Continuity
Local adjacency between states (e.g., parent → child), without reference to the ultimate origin.

Frontier
The minimal set of state commitments sufficient to represent the current boundary of the system’s state space for verification purposes.

Light Client
A verifier that cannot replay full system history and relies on cryptographic commitments rather than execution replay.

Offline Reentry
The act of a light client resuming verification after an unbounded period of disconnection.

⸻

3. Threat Model

This specification assumes the following adversarial conditions:
	•	Peers may be malicious or colluding
	•	Network connectivity may be intermittent or unavailable
	•	The system may experience partial or full downtime
	•	Adversaries may attempt to present:
	•	fabricated histories
	•	restarted networks
	•	mirror universes
	•	backdated genesis states

The specification assumes no trusted bootstrap servers and no socially trusted genesis.

⸻

4. Assumptions

GALV relies on the following minimal assumptions:
	1.	Hash Collision Resistance
Cryptographic hash functions used for commitments are collision-resistant.
	2.	External Anchor Immutability
Rewriting the external anchor requires computational resources exceeding feasible adversarial capacity.
	3.	Deterministic State Derivation
Valid system states are deterministically derived from genesis via cryptographic parent commitments.

No assumptions are made about honest majorities, liveness, availability, or execution correctness.

⸻

5. Verification Invariant

A light client MUST accept a proposed state if and only if it can cryptographically verify that:

The state’s lineage terminates at a genesis whose existence is externally time-bounded by an immutable anchor.

This invariant is the sole acceptance criterion defined by this specification.

⸻

6. Required Inputs

A conforming light client MUST possess or obtain the following:
	•	The expected genesis hash
	•	The external anchor reference committed to by genesis
	•	A method to verify the existence and immutability of the external anchor
	•	A proposed frontier representing the current state boundary
	•	Cryptographic parent commitments sufficient to verify ancestry

No full history, transaction data, or execution traces are required.

⸻

7. Verification Algorithm (Normative)

A light client SHALL perform verification as follows:
	1.	Genesis Identity Check
Verify that the presented genesis hash matches the expected genesis hash.
	2.	Anchor Commitment Check
Verify that genesis cryptographically commits to the specified external anchor.
	3.	Anchor Verification
Verify that the external anchor exists and is immutable under the assumed threat model.
	4.	Frontier Ancestry Check
Verify that each element of the proposed frontier cryptographically commits to its parent state(s).
	5.	Lineage Termination Check
Verify that all ancestry paths terminate at the verified genesis.

If any step fails, the light client MUST reject the proposed state.

⸻

8. Security Guarantees

If verification succeeds, GALV guarantees:
	•	Origin Authenticity
The accepted state descends from the same genesis previously observed.
	•	Non-Rewindability
The system’s origin cannot be backdated without rewriting the external anchor.
	•	Resistance to Fabricated Histories
Adversaries cannot present an alternate network instance with a different origin.

These guarantees hold regardless of offline duration.

⸻

9. Non-Goals

GALV explicitly does not guarantee:
	•	Execution correctness
	•	Consensus safety
	•	Data availability
	•	Fork resolution
	•	Liveness

These properties are orthogonal and MUST be addressed by separate mechanisms.

⸻

10. Applicability (Non-Normative)

GALV is applicable to systems that satisfy:
	•	Deterministic state derivation
	•	Hash-based ancestry
	•	Genesis anchoring to an immutable external reference

This includes chain-based, DAG-based, and metagraph-style architectures, particularly in browser-based or mobile environments.

⸻

11. Instantiation Notes (Non-Normative)

A concrete instantiation of GALV exists where a system’s genesis embeds a cryptographic reference to an external proof-of-work blockchain block, thereby time-bounding genesis creation. Deterministic state derivation extends this bound to all descendant states.

This document intentionally abstracts away system-specific details to preserve generality.

⸻

12. Conclusion

Genesis-Anchored Lineage Verification formalizes a minimal but sufficient method for light clients to verify network identity and origin continuity without trusting genesis socially or replaying full history.

By converting genesis from an assumed constant into a cryptographically time-bounded root of trust, GALV enables offline-resilient verification through hash-based lineage alone.

⸻

Status

Specification Draft — Normative Core Complete
