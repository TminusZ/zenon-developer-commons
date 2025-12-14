# zApps: Deterministic Local Execution (Draft Notes)

These are early notes outlining how our team views application logic in Zenon can run locally, remain deterministic, and anchor verifiable results to the dual-ledger without requiring a global VM.
This document is not a formal specification. It exists to clarify how "zApps" fit into a proof-first, browser-native execution model.

---

## 1. Purpose of zApps

The whitepaper introduced the idea of application-level logic that does not execute inside consensus and does not rely on a shared global state machine.
Instead, each user runs the relevant logic locally and only commits:

- a deterministic result
- a minimal proof or commitment
- a state transition for their own account-chain

Consensus does not re-execute any of this.
It only verifies that the commitment is valid and that the account-chain transition is well-formed.

This model fits naturally with:

- browser execution (WASM or JS)
- minimal sentry nodes
- SPV-style verification
- the dual-ledger structure

---

## 2. What a zApp Actually Is

A zApp is not a smart contract and not a VM program.
The simplest definition:

A zApp is a deterministic program executed by the user, with the result anchored to the user's account-chain.

"Deterministic" simply means:

- same inputs → same outputs
- no system clock, randomness, or external state unless explicitly included
- reproducible by any verifier if needed

The runtime can be:

- WASM module
- JavaScript bundle
- native binary / unikernel
- any environment that behaves deterministically for the given input set

Zenon does not require a specific language or runtime.
The only requirement is reproducibility.

---

## 3. Why This Model Exists

The architecture already avoids:

- global state
- global execution
- fee markets
- a heavy VM layer

Because of the dual-ledger design, each user has:

- their own account-chain
- their own local zApp state
- their own execution environment

Consensus only needs to anchor commitments.
It never interprets or runs application code.

This allows:

- parallel execution
- local-first design
- extremely cheap interactions
- browser-native behavior
- higher throughput than VM-based systems

---

## 4. Minimal Workflow for a zApp Execution

A typical flow looks like this:

1. User runs the zApp locally.
2. zApp computes the next state or result.
3. The Sentry (or browser light client) verifies the output is well-formed.
4. A commitment representing this output is attached to an account-chain transition.
5. The Sentry performs micro-PoW and forwards the transition to a Sentinel.
6. Pillars finalize the included transition in a Momentum.
7. The updated account-chain becomes the new reference state for future zApp actions.

No part of the above requires:

- a smart contract VM
- global state replay
- RPC servers
- centralized execution

---

## 5. Data Model Expectations

A zApp should define:

- input format
- output format
- how to compute the next deterministic state
- what must be included in the commitment

Commitments must be:

- minimal
- hash-based
- verifiable by any external observer if they have the input and rules

This is closer to client-side proof generation than classical contract execution.

---

## 6. Interaction Between Multiple Users

Since each user maintains their own account-chain, multi-party interaction requires exchanging:

- signed messages
- commitments
- local state fragments

These exchanges can occur:

- directly between Sentries
- over WebRTC/libp2p
- via relays or shared infrastructure

The network itself does not resolve application-level disputes.
It only guarantees ordering and validity of transitions.

This follows the intent-first style emerging in modern architectures, where the base layer secures ordering while clients coordinate logic.

---

## 7. Why This Fits the Broader Architecture

zApps rely on several architectural properties already documented:

- browser-friendly light verification
- minimal header synchronization
- local account-chain execution
- proof-first transitions
- micro-PoW for rate-limiting
- no global VM

Together, they support scalable application behavior without requiring full nodes or heavy computation.

The zApp model is therefore a natural extension of the earlier drafts:

- Browser Light Client
- SPV / Header Verification
- Minimal Sentry Node

All three components support zApps by enabling local execution + global verification.

---

## 8. Open Questions

- What commitment format is ideal for reproducible local execution?
- How should zApp runtimes signal invalid transitions to the Sentry?
- What portion of zApp state should be kept client-side vs. anchored?
- How should multi-party coordination be standardized (if at all)?

These questions remain open and require further exploration.
