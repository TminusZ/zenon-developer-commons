# Taxonomy Note: Deterministic Fact Acceptance

Research Note — Terminology & Classification

## Purpose

This note clarifies the architectural category explored in this repository and distinguishes it from adjacent but non-equivalent blockchain models. Its goal is to reduce misclassification, not to assert novelty or superiority.

---

## Core Term: Deterministic Fact Acceptance (DFA)

**Definition:**
A ledger model in which consensus admits state transitions based solely on deterministic verification of facts, while the computation or execution that produces those facts is local, discardable, and non-authoritative.

In a DFA model:

- execution is permitted but never trusted
- verification predicates are consensus-relevant
- execution traces are not replayed globally
- correctness is established without running foreign logic

---

## What DFA Is Not

DFA is often conflated with existing categories due to shared primitives. These mappings are incorrect:

### Not Smart Contract Platforms

- Smart contracts require global execution or replay.
- DFA systems do not execute application logic in consensus.
- Determinism arises from structural predicates, not VM execution.

### Not Light Clients

- Light clients are clients of an execution chain.
- DFA describes a ledger model itself, not a client optimization.

### Not Stateless Clients

- Stateless clients optimize state access.
- DFA changes which computations are consensus-critical.

### Not Rollups

- Rollups execute off-chain but still require fraud/validity proofs tied to execution correctness.
- DFA accepts facts without referencing execution traces at all.

### Not Oracles or Bridges

- Oracles introduce trust assumptions.
- DFA relies only on cryptographic verification of supplied facts.

---

## Canonical Comparison Axis

Most blockchains are classified by what is committed.
DFA is classified by what must be executed.

| Dimension | Execution-Centric Chains | DFA Model |
|-----------|--------------------------|-----------|
| Execution | Global, authoritative | Local, non-authoritative |
| Verification | Implied by execution | Explicit predicate |
| Commitment | Execution outcome | Fact only |
| Failure Mode | Fork / consensus fault | Verification fails → no-op |
| Scalability Cost | Validator count × execution | Bounded verification only |

---

## Relationship to Known Systems

### Bitcoin SPV

- Bitcoin SPV is an instance of DFA applied to transaction inclusion.
- DFA generalizes the pattern beyond Bitcoin.

### Ethereum / Verkle / Statelessness

- These optimize proof size and state access.
- They do not remove execution from consensus.

### Algorand State Proofs

- Compress attestation of executed state.
- Still rely on protocol-defined execution correctness.

---

## Why DFA Is Easy to Misclassify

- It uses familiar cryptographic tools (Merkle proofs, headers).
- It removes an implicit assumption (global execution).
- Most blockchain literature does not separate execution from acceptance.

As a result, readers often map DFA to the nearest known category (SPV, light clients) unless the distinction is made explicit.

---

## Non-Goals of DFA

DFA does not attempt to:

- prevent malicious software
- verify user intent
- sandbox arbitrary computation
- provide general-purpose on-chain execution

It enforces outcome correctness, not behavioral guarantees.

---

## Summary

Deterministic Fact Acceptance names a ledger-level responsibility split that is usually implicit or conflated:

**Consensus verifies facts, not execution.**

This taxonomy clarifies how systems can support interoperability, external verification, and scalable admission control without inheriting the costs of global execution.
