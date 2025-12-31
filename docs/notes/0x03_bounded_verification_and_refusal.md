Bounded Verification & Refusal

Status

Draft / Notes
Non-normative
Builds on: Genesis-Anchored Lineage, Minimal State Tracking, Verifier Lifecycle

⸻

Motivation

Once a verifier is anchored at genesis and tracking a minimal state frontier, verification is no longer an abstract property of the network — it is a concrete, resource-bounded process executed by a specific device.

For edge verifiers (browsers, mobile clients, intermittently connected nodes), verification is constrained by finite limits on memory, computation, bandwidth, and time.

Traditional blockchain designs implicitly assume that verification should always succeed if the verifier is “honest.” This assumption fails under realistic edge constraints.

This note formalizes a different principle:

Verification is explicitly bounded, and refusal to verify is a correct and safe outcome.

⸻

Bounded Verification

A verifier operates under fixed limits:

	•	finite memory
	•	finite computation
	•	finite bandwidth
	•	finite wall-clock time

A verification procedure is admissible only if it completes within those limits.

If a proof, transition, or claim exceeds any bound, the verifier must stop.

This is not a failure condition. It is correct behavior.

⸻

Refusal as a First-Class Outcome

Verification outcomes are explicitly tri-valued:

	•	accept
	•	reject
	•	refuse

Accept means the claim is verified within bounds.

Reject means the claim is provably invalid.

Refuse means the verifier cannot determine validity within bounds.

Refusal does not assert invalidity, and it does not imply trust. It preserves local safety while deferring judgment.

⸻

Safety Properties of Refusal

Refusal preserves the following invariants:

	•	The verifier never accepts unverifiable state.
	•	The verifier does not escalate trust to intermediaries.
	•	The verifier’s local state remains consistent with the last verified frontier.
	•	Refused claims may be retried later without altering trust assumptions.

A refusing verifier is safe by construction.

⸻

Why Refusal Is Necessary

Without refusal, an edge verifier is forced into one of three unsafe behaviors:

	•	attempt unbounded verification
	•	accept unverifiable claims
	•	rely on trusted third parties

Bounded refusal introduces a fourth option: delay.

Delay preserves safety under partial connectivity, adversarial bandwidth conditions, proof unavailability, or resource exhaustion.

⸻

Relationship to Zenon’s Architecture

Zenon enables bounded verification because execution and ordering are decoupled.

Account-chains localize execution.

Momentum commits global order and state roots without requiring replay.

Genesis anchoring fixes the trust root permanently.

State proofs are fetched on demand rather than streamed globally.

As a result, verification cost scales with local interest, not global chain growth, and refusal affects only the local verifier.

⸻

Refusal Is Not Failure

Refusal is not a liveness guarantee.

Refusal is not probabilistic trust.

Refusal is not optimistic execution.

It is a safety boundary that prevents silent trust escalation and resource exhaustion.

A verifier that refuses remains correct.

⸻

Implications

Bounded verification with explicit refusal enables:

	•	browser-native verification
	•	offline and delay-tolerant operation
	•	resistance to bandwidth and proof-flooding attacks
	•	verifier diversity without weakening security assumptions

This shifts the design objective from universal verification to safe, localized verification.

⸻

What Follows

Once refusal is allowed, the next question is how verification progresses over time.

The next note formalizes deferred verification and proof availability:

0x04 — Proof Availability & Deferred Verification
