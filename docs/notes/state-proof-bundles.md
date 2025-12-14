# State Proof Bundles: A Minimal Verification Primitive for Dual-Ledger Blockchains

Research Draft: Exploratory and Non-Normative

## 1. Motivation

In dual-ledger architectures such as Zenon's account-chain + Momentum model:

- local state evolution occurs independently in user account-chains, while
- global consensus and ordering occur only through Momentum blocks.

This separation reduces global validation overhead but introduces a challenge:
Light clients require a compact method to verify the correctness of account-chain frontiers and individual transitions without downloading global state or replaying execution.

Traditional blockchains use Merkle proofs or global state tries to provide these guarantees.
Dual-ledger systems require a different primitive—one based on local determinism and header-first validation.

State proof bundles are proposed as such a primitive.

## 2. Structure of a State Proof Bundle

A state proof bundle contains only the data required for deterministic verification of one account-chain transition.

**Mandatory components**

- Account-block header (the transition being validated)
- Parent header hash (chain linkage)
- Minimal local state inputs necessary for transition rules
- Momentum reference committing to this frontier (hash or equivalent)

**Optional components (depending on transition type)**

- Balance/stake deltas
- Embedded contract I/O metadata
- Receive-pointer updates
- Fusion/staking context
- zApp commitment fragments

Bundles explicitly exclude:

- global state
- Merkle proofs
- historical replay data

Each bundle is scoped to a single account-chain frontier.

## 3. Why Bundles Work Without Merkle Trees

In Bitcoin:

"Prove this transaction is inside this block (Merkle branch)."

In Zenon:

"Prove this account-chain frontier is the one referenced by the Momentum."

This inversion is possible because:

- Account-chains are sequential and self-contained
- Each block commits to its predecessor
- The Momentum includes a cryptographic commitment to the aggregated state delta (ChangesHash)

Thus, a verifier only needs:

- the frontier header,
- its parent reference, and
- the Momentum's commitment.

Merkle subtrees are unnecessary.
Frontier validation replaces membership proofs.

## 4. Light-Client Workflow

A browser or minimal runtime verifies the system in five steps:

1. Sync Momentum headers (small, append-only, low bandwidth).
2. Identify which frontier references are relevant.
3. Request the corresponding state proof bundle.
4. Deterministically validate:
   - signature correctness
   - parent/header linkage
   - transition rules
   - Momentum inclusion
5. Update its local account-chain view.

This workflow enables securely synchronized light clients without global state or heavy computation.

## 5. Interaction With zApps

zApps run locally and anchor commitments rather than execution traces.

A bundle provides:

- the local state context, and
- the commitment references necessary to validate outputs.

This allows:

- deterministic re-execution anywhere
- no global VM replay
- multi-party verification
- trust-minimized off-chain computation

Bundles act as the proof boundary between local execution and global settlement.

## 6. SPV, Cross-Chain Work, and Interoperability

State proof bundles unify multiple verification needs:

**Zenon-native SPV**

Light clients require only:

- Momentum headers
- account-chain frontier validation
- bundles for specific transitions

**Browser-native operation**

Bundles are small enough for:

- WebRTC
- WebSocket
- libp2p substreams

**Cross-chain interoperability**

Bundles can be embedded into Momentum Data for:

- Bitcoin SPV headers
- Ethereum receipts
- zk-proofs
- multi-chain commitments

This enables general-purpose bridging without full-state proofs.

## 7. Open Research Questions

- What is the minimal canonical bundle schema?
- Should bundles be served by Sentinels, peers, or optional Pillars?
- How should malformed bundles be penalized?
- What caching policies suit browser clients?
- Can bundles evolve into succinct proofs (zk)?
- How will extended Momentum Data usage interact with bundle validation?

These questions define the research surface for future contributors.

## 8. Summary

State proof bundles offer a lightweight, header-first verification primitive suitable for:

- browser-native light clients
- zApp determinism
- dual-ledger SPV
- cross-chain anchoring
- resource-efficient decentralization

They align naturally with architectures that prioritize:

- local determinism,
- global ordering,
- minimal proof footprints,
- no execution replay,
- and low-resource participation.

While this design is not yet formalized in any production system, it represents a plausible verification layer for next-generation dual-ledger blockchains.
