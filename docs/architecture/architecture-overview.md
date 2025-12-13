# Zenon Architecture Overview

This document provides a high-level overview of the architectural components of Zenon — The Network of Momentum (NoM).
It does not represent official documentation; it is a community-driven attempt to describe the system in accessible, technical terms.

## 1. Momentum-Based Consensus

Zenon does not use traditional blockchains.
Instead, it uses units called momentums.

A momentum contains:

- a snapshot of recent account blocks
- a reference to prior momentums
- signatures from the consensus quorum (Pillars)

This creates a sequential chain of momentums while allowing accounts to update asynchronously.

## 2. Account-Based DAG

Zenon uses a block-lattice structure, where:

- every address has its own mini-blockchain
- account blocks represent send/receive actions
- all account chains are anchored into global momentums

This design reduces contention and enables parallelism.

## 3. Node Types

### 3.1 Pillars

- Participate in consensus
- Sign momentums
- Receive ZNN emission rewards

### 3.2 Delegators

- Bond ZNN to support Pillars
- Earn a share of Pillar rewards

### 3.3 Sentinels (Conceptual Role)

- A planned layer for proof-serving
- Expected to deliver momentum proofs, state roots, and execution commitments
- Would reduce the workload for light clients

### 3.4 Full Nodes

- Maintain the entire chain state
- Validate all account-block activity
- Serve historical data

### 3.5 Light Clients

- Verify momentums using proofs
- Do not maintain full state
- Rely on SPV-style checks or proof-serving nodes

## 4. Application Contract Interfaces (ACIs)

Zenon uses deterministic, schema-defined ACIs rather than a general-purpose VM.

An ACI defines:

- inputs
- outputs
- state transitions
- cryptographic commitments

Execution does not occur on-chain; instead, proofs or commitments are submitted.

This reduces on-chain load and supports off-chain or client-side logic.

## 5. Proof & State Model

Zenon supports lightweight verification through:

- momentum header checks
- signature validation
- Merkle-style proofs for account-block inclusion
- deterministic execution proofs for ACIs

This model allows non-full nodes to operate trustlessly with limited data.

## 6. Networking Layer (High-Level)

Zenon's current networking uses custom transports and relays.
However, its modularity suggests that alternate transports (such as libp2p + WebRTC) could be integrated.

This opens the door to browser-native clients.

## 7. Summary

Zenon's architecture is built around several core ideas:

- parallel account chains
- momentum-based anchoring
- modular consensus roles
- deterministic contract interfaces
- lightweight verifiability
- potential for browser-friendly execution paths

Future documents will expand individual components in greater detail
