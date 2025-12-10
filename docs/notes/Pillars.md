Pillars: Deterministic Consensus & Momentum Production (Draft Notes)

Research Draft — Not a Formal Specification

These notes describe how Pillars function inside Zenon’s dual-ledger architecture, how they finalize ordering, and how they interact with Sentries and Sentinels.
They are intended for researchers exploring browser-native verification, proof-first consensus, and lightweight execution models.

⸻

1. Purpose of Pillars

Pillars are the consensus layer in Zenon. They:

• Produce Momentum blocks

• Apply deterministic state transitions

• Validate ordered account-chain updates

• Weight votes according to staked ZNN

• Maintain global chain continuity

Unlike traditional validators, they do not execute user application logic or run a global VM.
Their role is strictly ordering + finality.

⸻

2. What a Pillar Actually Does

A Pillar performs a focused, deterministic set of actions:

• Collects valid account-chain updates from Sentinels

• Applies deterministic state rules (balances, confirmation heights, contract state, etc.)

• Builds and signs the next Momentum block

• Updates chain difficulty and consensus weight

• Broadcasts the Momentum to peers

• Participates in weighted consensus rounds

Pillars do not handle:

• Local execution

• Application semantics

• Merkle proofs

• Gas markets

Their job is to maintain global ordering efficiently.

⸻

3. Why Pillars Work in a Dual-Ledger Architecture

Because Zenon stores state in account-chains, not a global trie, Pillars do not need to:

• Replay transitions

• Recompute arbitrary logic

• Validate smart-contract execution

Instead, they:

• Verify structure

• Verify signatures

• Verify state deltas

• Verify consensus eligibility

Pillars commit the result, not the process.
This keeps Momentum production lightweight.

⸻

4. Momentum Block Construction

Each Momentum includes:

• Ordered list of account-block headers

• The aggregated state patch created by applying all transitions

• ChangesHash (cryptographic commitment to the state delta)

• Difficulty and weight metadata

• Timestamp and version

• Producer signature

A Momentum does not contain:

• Full state

• Merkle proofs

• Replay of contract results

Momentum blocks are commitments, not execution logs.

⸻

5. Consensus Flow (Simplified)

	1.	Sentries generate user transitions.

	2.	Sentinels filter malformed transitions and verify structure.

	3.	A Pillar collects valid transitions for its slot.

	4.	The Pillar applies deterministic state changes.

	5.	The Pillar computes ChangesHash.

	6.	The Pillar builds and signs the Momentum.

	7.	Other Pillars verify eligibility, signatures, and state deltas.

	8.	The Momentum becomes part of the canonical chain.

No gas.

No mempool market.

No bidding for inclusion.

⸻

6. Pillars vs. Sentinels vs. Sentries

Sentry

• Browser, mobile, or lightweight runtime

• Executes user logic locally

• Builds account-chain transitions

• Computes micro-PoW

Sentinel

• Middle-layer verification node

• Validates structure, signatures, PoW, and basic invariants

• Filters spam before it reaches consensus

• Does not run application code

Pillar

• Finalizes ordering

• Applies deterministic state deltas

• Signs Momentum blocks

• Maintains historical continuity

This separation enables a feeless architecture without central bottlenecks.

⸻

7. Why Pillars Enable Browser-Native Verification

Because Pillars produce predictable header-level commitments, a light client only requires:

• Momentum headers

• Account-chain frontier

• Signature verification

• Difficulty / weight validation

No RPC gateways.
No global execution.
No Merkle-proof complexity.

This aligns naturally with SPV and browser-native clients.

⸻

8. Pillars and Future Extensions

Active research directions include:

• Expanding the Momentum Data field for cross-chain commitments

• zk-anchoring or succinct proof integration

• Pillar reputation scoring

• Incentives for serving light clients

• Slot-allocation redesigns

• Weighting and scheduling mechanisms

Pillars are the backbone of deterministic ordering in Zenon.

⸻

9. Open Questions

• Should Pillars expose a standardized header format for light clients?

• How should the Momentum Data field evolve without breaking deterministic hashing?

• What is the ideal verification load split between Sentinels and Pillars?

• Should Pillars provide partial state snapshots for browser nodes?

• How does the Pillar set size affect throughput and latency?

These questions will be expanded in future research drafts.
