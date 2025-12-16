# Account-Chain Commitments & ChangesHash

Research Note — Draft Notes

These notes clarify how account-chain transitions are committed inside Momentum blocks, how ChangesHash functions in practice, and why this structure is sufficient for lightweight verification without Merkle inclusion proofs.

This is not a full specification. It is an architectural description for researchers exploring SPV, browser-native execution, and potential cross-chain extensions.

---

## 1. Why This Matters

In Bitcoin, SPV depends on Merkle proofs because each transaction is an independent leaf inside a block.

Zenon does not work this way.

Zenon's dual-ledger structure means:

- user activity forms an account-chain
- Momentum blocks finalize references to those chains
- global consensus never re-executes account logic
- the system commits to state transitions, not transactions

Understanding this difference removes many perceived "roadblocks" around SPV and light verification.

---

## 2. What a Momentum Actually Commits To

A Momentum includes:

- the ordered list of account-block headers
- the resulting state modifications after applying all included account blocks
- a single cryptographic commitment to these changes (ChangesHash)
- metadata such as timestamp, producer, version, and the optional future Data field

Key point:
ChangesHash is a commitment to the aggregate effect of all included account-chain transitions.

It does not need to expose:

- Merkle roots
- per-block inclusion proofs
- contract execution details
- global state snapshots

A verifier only needs to know that:

1. the Pillar was eligible to produce the Momentum
2. the included account-block headers are valid
3. the resulting state transition is correct and reproducible

This is a much lighter model than Bitcoin-style SPV.

---

## 3. Why No Merkle Tree Is Required

Because Zenon's execution model is local-first:

- each account-chain is internally ordered and self-verifying
- a new account-block implicitly validates the previous one
- Momentum commits to the frontier state after applying included blocks

So instead of asking:

"Was this individual transaction included in the block?"

A verifier asks:

"Does this Momentum commit to the correct frontier of this account-chain?"

This makes SPV fundamentally simpler:

- proving inclusion of account-block N implicitly proves N-1, N-2, …
- no Merkle branches are required
- the Momentum header + the account-chain frontier hash become the proof object

---

## 4. How ChangesHash Fits Into This Model

ChangesHash represents the cryptographic digest of:

- balance updates
- account-chain header updates
- confirmation heights
- mailbox changes
- sequencer queue updates
- embedded contract state changes
- staking and fusion metadata
- token definitions
- any deterministic component of the state machine

It is the global commitment object.

A light verifier does not need to recompute these values.
It only needs to:

1. verify the Momentum header signature
2. verify chain continuity
3. verify the referenced account-chain block

This is the core of header-first SPV for Zenon.

---

## 5. Account-Chain Frontier Verification (The Lightest Possible Model)

A minimal browser or sentry verifier only requires:

1. the Momentum header
2. the account-chain frontier header referenced by that Momentum
3. the parent account-block hash

From this it can verify:

- the account-chain is valid
- the Momentum references the correct frontier
- the Momentum originates from a valid Pillar
- cumulative weight / score is correct
- timestamps and eligibility rules match

No Merkle proofs are needed.

---

## 6. Why This Enables SPV, zApps, and Cross-Chain Work

**SPV:**
Verifiers only need Momentum headers + account-chain frontiers.

**zApps:**
Logic executes locally; the output becomes an account-chain transition anchored by the Momentum.

**Cross-chain:**
Momentum's reserved Data field can eventually support:

- external Merkle roots
- succinct proofs
- state commitments
- interoperability metadata

The model is structurally ready for these extensions.

---

## 7. Open Questions

These research directions remain:

- What subset of ChangesHash should be exposed to light clients?
- How should account-chain frontier data be packaged for verifiers?
- Should Momentum Data evolve into a commitment extension field?
- Which proof systems best fit browser-native verification?
- How to formalize a light-client spec without modifying consensus?

Future drafts will explore these topics in more detail.
