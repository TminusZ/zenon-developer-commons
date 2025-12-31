0x04 — Proof Availability & Deferred Verification

Status

Draft / Notes
Non-normative
Builds on: Bounded Verification & Refusal

⸻

Motivation

Bounded verification introduces refusal as a correct outcome.
Refusal, however, raises a follow-up question:

What happens after refusal?

If verification can be deferred, the system must define how proofs appear, disappear, and reappear over time without compromising safety.

This note formalizes proof availability and deferred verification as explicit components of the verifier model.

⸻

Proof Availability

A proof is considered available if it can be obtained and verified within the verifier’s resource bounds at the time of request.

Availability is not binary globally. It is local and temporal.

A proof may be:

	•	available now
	•	unavailable now but available later
	•	permanently unavailable to a given verifier

Availability is a property of the verifier’s environment, not the protocol alone.

⸻

Deferred Verification

Deferred verification occurs when a verifier refuses a claim due to unavailable proofs and later retries verification.

Deferred verification preserves safety because:

	•	no state is accepted prematurely
	•	no trust assumptions change between attempts
	•	verification logic remains identical across retries

Only environmental conditions change.

⸻

Idempotence of Verification

Verification must be idempotent with respect to time.

Re-running verification on the same claim with the same inputs must yield the same result unless new proofs are supplied.

Time does not alter truth.
Only evidence does.

⸻

Separation of Claim and Proof

Claims and proofs are decoupled.

The network may propagate claims faster than proofs.

The verifier may observe:

	•	a state transition commitment
	•	without possessing the proof required to validate it

This separation is intentional and required for scalability and offline operation.

⸻

No Global Proof Availability Assumption

The verifier does not assume:

	•	global data availability
	•	honest majority relays
	•	persistent connectivity
	•	synchronized clocks
	•	archival access

Any such assumption would reintroduce implicit trust or unbounded resource requirements.

⸻

Proof Discovery Is Opportunistic

Proofs may be obtained via:

	•	peer-to-peer gossip
	•	cached local storage
	•	delayed relay
	•	physical reconnection
	•	alternative transport layers

The protocol does not privilege any transport mechanism.

Verification correctness depends only on proof validity, not how the proof arrived.

⸻

Safety Under Partial Availability

If proofs never arrive, the verifier remains safe.

Safety is defined as:

	•	never accepting unverifiable state
	•	never mutating state based on unverified claims

Liveness is explicitly not guaranteed at the verifier level.

⸻

Deferred Verification and Finality

Finality exists at the network level but is realized locally only when proofs are verified.

A verifier may acknowledge global finality without accepting local state transitions until proofs are available.

This distinction prevents conflating consensus finality with local verification completeness.

⸻

Relationship to Genesis Anchoring

Genesis anchoring ensures that deferred verification never drifts.

All proofs ultimately reference a fixed, immutable origin.

Deferred verification is bounded because the lineage being verified cannot be rewritten.

⸻

Implications

Explicit proof availability and deferred verification enable:

	•	offline-first verification
	•	delay-tolerant applications
	•	intermittent connectivity
	•	verifier mobility
	•	heterogeneous hardware participation

These properties are impossible if verification is assumed to be immediate and universal.

⸻

What Follows

Once verification can be deferred, the system must constrain what a verifier is willing to wait for.

The next note defines explicit verification frontiers and refusal escalation:

0x05 — Verification Frontiers & Local Finality
