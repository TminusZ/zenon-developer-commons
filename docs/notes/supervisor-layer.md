# Supervisor Layer — Research Draft

A Coordination Layer for Proof-First, Dual-Ledger Architectures

This document is conceptual and non-normative.
It outlines a potential intermediate verification role ("Supervisor Layer") that can exist between Sentry nodes and Sentinel nodes in a deterministic, proof-first blockchain architecture such as Zenon's dual-ledger model.

## 1. Introduction

Dual-ledger architectures separate local state evolution (account-chains) from global ordering (Momentum blocks). While this separation improves scalability, it introduces a structural gap:

- Sentries can generate many independent state transitions,
- Sentinels are responsible for validating and forwarding only structurally-sound transitions toward consensus,

…but without an intermediate layer, the system lacks:

- deterministic aggregation,
- fraud filtering,
- cross-transition dependency validation,
- and structured state-proof formation.

The Supervisor Layer is proposed as the missing coordination tier enabling scalable, proof-first execution without burdening Sentinels or Pillars.

## 2. Position in the Node Hierarchy

The architecture is organized into four conceptual layers:

**Sentries**

- Lightweight nodes (desktop, mobile, browser)
- Execute zApps locally
- Produce account-chain blocks
- Attach micro-PoW for spam resistance

**Supervisors (Proposed Layer)**

- Aggregate Sentry outputs
- Validate proof completeness
- Enforce deterministic ordering
- Construct compact State Proof Bundles

**Sentinels**

- Perform structural validation
- Filter malformed or adversarial transitions
- Prepare transitions for inclusion in Momentum ordering

**Pillars**

- Apply deterministic state deltas
- Produce and sign Momentum blocks
- Finalize global ordering

Supervisors create a shared intermediate representation between local execution and global verification.

## 3. Responsibilities of the Supervisor Layer

### 3.1 Proof Aggregation

Supervisors collect:

- account-chain block headers
- micro-PoW links
- zApp execution receipts
- dependency metadata

They consolidate these into verifiable State Proof Bundles suitable for light clients and Sentinels.

### 3.2 Deterministic Ordering

Supervisors enforce consistent ordering rules based on:

- timestamps
- dependency graphs
- difficulty thresholds
- execution ordering constraints

Any honest Supervisor should derive the same ordered bundle from the same Sentry inputs, ensuring global determinism.

### 3.3 Fraud Detection

Supervisors reject:

- invalid signatures
- malformed account-block structures
- duplicate or conflicting proofs
- missing inputs for zApp transitions
- insufficient or invalid micro-PoW

They serve as a local fraud-proof layer, reducing Sentinel workload and improving network hygiene.

### 3.4 QSR-Based Rate Governance

Supervisors use QSR-linked signals to regulate load:

- Excess Sentry activity → increased micro-PoW threshold
- Low Sentry throughput → reduced micro-PoW threshold

This creates a self-balancing, feeless rate-control mechanism without economic gas markets.

## 4. Interaction With zApps

Supervisors do not execute zApps.

Sentries execute deterministic zApp logic locally. Supervisors verify:

- execution receipts
- declared input/output commitments
- dependency satisfaction
- proof completeness

Thus, zApps resemble unikernel-style execution units producing concise state commitments.

Supervisors confirm those commitments are reproducible and safe to anchor upward.

## 5. Local → Global Convergence Model

**Local Verification (Supervisor Level)**

Each Supervisor maintains:

- recent Momentum windows
- local dependency graphs
- trust heuristics for Sentries
- partial views of zApp channels

Multiple Supervisors independently derive identical bundles from the same Sentry activity.

**Global Verification (Sentinel Level)**

Sentinels compare bundles:

- If multiple Supervisors converge → bundle accepted
- If bundles diverge → malformed or adversarial inputs rejected

This produces a naturally convergent verification tree without a global mempool or leader-driven block assembly.

## 6. Security Objectives

The Supervisor Layer must guarantee:

- Proof completeness — all dependencies included
- Proof correctness — signatures, PoW, receipts valid
- Deterministic output — verifiers derive identical bundles
- Fork resistance — no ambiguity when Sentinels compare bundles
- Scalability — Supervisor work remains local and parallel

This strengthens network integrity without increasing consensus overhead.

## 7. Browser-Native Implications

Supervisors produce compact bundles that browsers can:

- download via WebRTC/libp2p
- verify with WASM
- reconstruct deterministically
- store locally (IndexedDB, Service Workers)

This explains how a browser can function as a first-class light client without relying on RPC gateways or full nodes.

The Supervisor Layer, not Pillars, is responsible for packaging state into browser-friendly proofs.

## 8. Why the Supervisor Layer Matters

Supervisors resolve numerous open questions in dual-ledger architectures:

- How can Sentries scale horizontally without overwhelming Sentinels?
- How do zApps remain deterministic without global execution?
- How can state proofs become small enough for browser clients?
- How does the network maintain coherence without a mempool?

The Supervisor Layer is the organizing principle that makes the architecture modular, scalable, and verifiable.

## 9. Open Research Questions

- Should Supervisors be incentivized (e.g., via QSR rewards)?
- What cryptographic format should State Proof Bundles adopt?
- How many Supervisors are required for redundancy?
- How do Supervisors detect and penalize equivocation?
- Should Supervisors maintain partial state or remain stateless?
- What trust model is required between Supervisors and Sentinels?
- Can Supervisor logic be executed fully in WASM for portable deployment?

These questions define the research direction for maturing the Supervisor concept.

## 10. Summary

The Supervisor Layer provides:

- deterministic aggregation,
- fraud detection,
- proof bundling,
- rate control,
- and zApp validation between Sentries and Sentinels.

It explains how a proof-first system can scale to millions of lightweight Sentries—including browser clients—while preserving deterministic, low-cost global consensus.
