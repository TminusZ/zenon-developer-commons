Application Semantics Over Bounded Verification

Status

Draft / Notes
Non-normative
Builds on: Multi-Verifier Consistency & Refusal

⸻

Motivation

Up to this point, verification has been described purely at the protocol level.

Applications must operate on top of partial, bounded, verifier-local truth.

This note defines how applications interpret and act on verified state without assuming global completeness or canonical ordering.

⸻

Fundamental Constraint

An application must never assume:

	•	global state completeness
	•	universal finality
	•	synchronized verification across users

Applications operate on locally verified facts only.

⸻

Verified Fact Model

A verified fact is:

	•	a statement proven against the verifier’s frontier
	•	derived from lineage-consistent commitments
	•	accepted within bounded resources

Examples:

	•	an account balance
	•	ownership of an asset
	•	inclusion of a state transition
	•	a resolved cross-chain proof

Facts may expire as frontiers advance.

⸻

Fact Scope

Each fact has an explicit scope:

	•	verifier-local
	•	frontier-bounded
	•	time-relative

Applications must treat facts as contextual, not absolute.

⸻

Application Read Semantics

When reading state, an application must:

	•	specify required verification depth
	•	specify acceptable frontier age
	•	handle missing or unverifiable facts

Absence of data is not an error.

It is a valid outcome.

⸻

Application Write Semantics

When submitting actions, an application must:

	•	reference the facts it depends on
	•	tolerate refusal or delay
	•	avoid assuming immediate global effect

Writes are proposals, not guarantees.

⸻

Refusal-Aware Logic

Applications must explicitly handle refusal states:

	•	retry later
	•	request alternative proofs
	•	degrade functionality
	•	halt execution safely

Refusal is a first-class outcome.

⸻

Multi-User Interaction

When multiple users interact:

	•	shared state is inferred from overlapping verified facts
	•	disagreement is expected
	•	reconciliation is explicit, not implicit

Applications cannot rely on implicit consensus.

⸻

Eventual Consistency Without Global Truth

Applications may converge over time if:

	•	frontiers advance
	•	proofs propagate
	•	refusals resolve

Convergence is opportunistic, not required.

⸻

Trust Surfaces

Applications must expose:

	•	what is verified
	•	what is assumed
	•	what is pending
	•	what is refused

Opaque trust assumptions are prohibited.

⸻

Offline Operation

Applications must support:

	•	cached facts
	•	degraded modes
	•	delayed verification

Offline correctness is local correctness.

⸻

Failure Modes

Applications must assume:

	•	proofs may never arrive
	•	some facts may never verify
	•	some actions may never complete

Safety over liveness.

⸻

Design Implication

This model favors applications that are:

	•	state-light
	•	fact-driven
	•	tolerant of delay
	•	explicit about uncertainty

Applications designed for monolithic global state do not translate.

⸻

Boundary Statement

Bounded verification does not limit applications.

It forces applications to be honest about what they know.

⸻

What Follows

Once applications operate on bounded facts, the system must address how economic and incentive mechanisms behave without global finality assumptions.

The next note introduces incentive-aware design:

0x08 — Incentives Under Partial Verification
