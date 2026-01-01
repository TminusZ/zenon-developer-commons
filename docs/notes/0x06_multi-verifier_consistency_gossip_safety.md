Multi-Verifier Consistency & Gossip Safety

Status

Draft / Notes
Non-normative
Builds on: Verification Frontiers & Local Finality

⸻

Motivation

Genesis-anchored light clients do not operate in isolation.

They exchange:

	•	headers
	•	commitments
	•	proofs
	•	refusal signals

This note defines how multiple independent verifiers interact safely without assuming global agreement, shared trust, or synchronized verification states.

⸻

Independence as a First Principle

Each verifier maintains:

	•	its own frontier
	•	its own proof cache
	•	its own refusal policy
	•	its own local finality rules

No verifier assumes another verifier is honest, complete, or synchronized.

Consistency is emergent, not enforced.

⸻

Gossip as a Transport, Not a Truth Source

Gossip provides availability, not validity.

From gossip, a verifier may receive:

	•	headers it has not yet seen
	•	proofs it did not request
	•	commitments outside its frontier
	•	contradictory claims

None are trusted by default.

⸻

Acceptance Conditions

A verifier accepts gossiped data only if:

	•	it references known lineage
	•	it falls within the verifier’s frontier
	•	required proofs are locally verifiable
	•	acceptance does not violate refusal constraints

Acceptance is unilateral.

⸻

Partial Overlap Is Expected

Two verifiers may share:

	•	some headers
	•	some verified commitments
	•	some proofs

They are not expected to share all state.

Consistency is defined over overlap, not total state.

⸻

Non-Agreement Is Not a Fault

Disagreement between verifiers does not imply:

	•	forks
	•	attacks
	•	invalidity

It implies:

	•	different frontiers
	•	different resource limits
	•	different verification priorities

The protocol tolerates this explicitly.

⸻

Gossip Safety Invariant

A verifier must never accept state solely because:

	•	many peers report it
	•	a majority advertises it
	•	it is “widely seen”

Only local verification confers acceptance.

This prevents social consensus attacks.

⸻

Contradictory Proof Handling

If a verifier receives conflicting proofs:

	•	only proofs verifiable against its lineage are considered
	•	unverifiable proofs are ignored, not stored
	•	contradictory proofs within the frontier trigger refusal escalation

Conflict resolution is local.

⸻

Proof Flood Resistance

To prevent denial-of-service via proof spam:

	•	proofs outside the frontier are dropped
	•	proofs without requested context are ignored
	•	storage quotas are enforced
	•	verification cost is bounded per peer

Gossip does not override resource policy.

⸻

Frontier-Aligned Gossip

A verifier may optionally advertise:

	•	its frontier bounds
	•	refusal thresholds
	•	proof interests

This allows peers to send relevant data without requiring trust.

Disclosure is optional.

⸻

Emergent Convergence

Over time, verifiers may converge if:

	•	proofs are widely available
	•	frontiers advance
	•	refusal does not occur

Convergence is probabilistic and voluntary.

There is no forced synchronization.

⸻

Safety Guarantees

Multi-verifier safety holds because:

	•	no verifier trusts peer assertions
	•	gossip cannot bypass verification
	•	refusal is always available
	•	genesis anchoring provides a shared immutable root

Global disagreement cannot corrupt local correctness.

⸻

Implications

This model supports:

	•	browser-native participation
	•	offline verification
	•	heterogeneous devices
	•	adversarial networks
	•	non-hierarchical trust

Verifiers remain sovereign at all times.

⸻

What Follows

Once multiple verifiers coexist safely, the system must explain how applications reason about partially verified state.

The next note introduces application-level interaction:

0x07 — Application Semantics Over Bounded Verification
