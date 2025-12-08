Momentum Header Verification (Draft Notes)

A minimal description of how a browser-native client or lightweight sentry can verify chain progress without global state.

Purpose of This Note

This document outlines the smallest viable mechanism for verifying Momentum headers in a resource-constrained environment (browser, mobile device, or minimal sentry node).

The goal is to define what a light participant needs in order to:
	•	confirm chain weight
	•	validate Pillar eligibility
	•	track account-chain finality
	•	enable zApps and local clients to operate without RPC gateways

This is not a full specification — only directional notes showing how header-level security fits into the broader architecture.

⸻

1. Why Header Verification Matters

A Zenon light node does not download global state.

Instead, it must independently verify:
	•	which Momentum chain has the highest valid weight
	•	whether the producing Pillar was eligible
	•	whether referenced account-chains can be considered finalized

Full nodes do this implicitly through execution.
Light nodes do it explicitly through headers + proofs, which is fully aligned with the whitepaper’s minimal-data design.

Header verification is the backbone of:
	•	browser light clients
	•	hybrid sentry nodes
	•	cross-chain SPV integrations
	•	deterministic zApp commitments
	•	rapid bootstrapping without RPC servers

⸻

2. What a Header Must Prove

A valid Momentum header must allow a minimal node to answer three questions:

(1) Was the Momentum produced by a valid Pillar?
	•	verify Pillar signature
	•	verify the Pillar was active at that height
	•	verify eligibility under N&T

(2) Does the header correctly link the chain?
	•	previous hash
	•	height
	•	timestamp within allowed drift
	•	cumulative weight or scoring

(3) Does the header commit to a valid set of account-chain references?
	•	Merkle / hash commitments
	•	references to included transitions
	•	no need to execute the transitions

This lets clients treat the chain as cryptographically linked commitments rather than requiring full execution.

⸻

3. Minimal Verification Workflow

A lightweight client performs:
	1.	Download headers (sequential or batched)
	2.	Verify Pillar signatures
	3.	Check continuity and timestamps
	4.	Track cumulative weight to identify the best tip
	5.	Optionally request account-chain deltas on demand

This mirrors classical SPV patterns while preserving Zenon’s dual-ledger semantics.

⸻

4. Why This Fits Zenon’s Architecture

Zenon already anticipates minimal-resource participants:
	•	account-chains isolate state
	•	global ordering is compact
	•	PoW-links decentralize anti-spam
	•	deterministic zApps remove execution from consensus

Momentum header verification is the smallest trustless synchronization unit in the system.

Without it:
	•	browsers cannot act as peers
	•	sentries cannot filter or relay securely
	•	bridging cannot be trustless
	•	zApps cannot anchor deterministic outputs
	•	SPV is impossible

With it:
	•	any device becomes a peer
	•	no RPC gateways are required
	•	scaling moves to the network edge
	•	the dual-ledger architecture reaches its intended form

⸻

5. Open Questions
	•	What is the minimal header structure required for independent validation?
	•	How should cumulative weight be represented for light clients?
	•	What is the optimal commitment structure for account-chain references?
	•	What bandwidth constraints exist for browser-based syncing?
	•	Can header gossip run over WebRTC/libp2p without a specialized relay layer?

These are guidance questions for future work, not finalized decisions.
