# Bitcoin SPV Event Oracle & State Transition Specification

---

## ⚠️ Status: Reference / Experimental

This document is a reference implementation and adversarial specification draft.

It is **not part of the core protocol** and is **not required** for any implementation.

It exists as:

* a high-rigor example of deterministic execution design
* a testing surface for adversarial review
* a toolbox resource for builders exploring SPV-based systems

Implementers may use, modify, or ignore this entirely.

---

# Preface

## What This Document Is

This document specifies a deterministic execution layer that uses Bitcoin as a source of truth via Simplified Payment Verification. It is an implementation-grade specification — not a conceptual overview. Every rule is falsifiable, reproducible, and adversarially testable.

The system maps a single primitive:

> Bitcoin transaction inclusion → deterministic state transition

onto an external execution environment (Zenon). Everything else — economic interpretation, collateral semantics, ownership claims — is application-layer responsibility.

## What This System Proves

This system proves **Event Validity**: cryptographic evidence that a Bitcoin transaction was included in a block on the best chain, to a specified confirmation depth.

Event Validity is not:
- Proof of output existence or value
- Proof of output ownership or control
- Proof that an output is unspent
- Proof of economic collateral
- Proof that any transaction is economically meaningful

Any economic consequence derived from an Event Validity proof is the responsibility of the counterparties, not this protocol.

## What This System Does Not Do

- Full Bitcoin validation (scripts, signatures, witness execution)
- UTXO spend tracking
- Price discovery or oracle-based valuation
- Output-level collateral verification
- Dynamic liquidation or margin management
- Cross-deployment coordination

These exclusions are not deficiencies. They are the necessary conditions for the core guarantee:

> No external trust dependencies within the verification and execution layer.

## Core Design Invariants

These constraints are permanent. Any revision that violates them is non-conforming.

**1. No External Trust**
All state transitions derive from Bitcoin headers, cryptographic proofs, and deterministic local state. No oracles, price feeds, governance votes, or human intervention at the protocol layer.

**2. Bitcoin Chain Is the Source of Truth**
The system continuously tracks the current best Bitcoin chain. All Bitcoin-derived state is re-evaluated on reorg until explicit finalization.

**3. Determinism**
Given identical inputs, all conforming nodes produce identical outputs. The system never depends on message arrival order, peer coordination, system clock, or non-deterministic inputs.

**4. Reversibility Until Finalization**
Any state derived from Bitcoin proofs is reversible until the protocol explicitly finalizes it. Reversibility is a feature, not a deficiency.

**5. Separation of Truth and Finality**
Truth is what Bitcoin currently says. Finality is when the protocol stops reversing state. These are separate concepts with separate thresholds.

**6. Event Validity vs Economic Validity**
The protocol guarantees Event Validity only. Economic validity — ownership, value, intent — is never asserted by this layer and must not be inferred from it.

## Oracle Operation Modes

Implementations must declare one of two modes. Mixed-mode deployments are non-conforming.

**Mode 1 — Pure Event Oracle**
State transitions are triggered by inclusion proof alone. No binding constraint is applied. No economic guarantees exist.

**Mode 2 — Bound Event Oracle**
Transactions must satisfy a declared binding constraint (Section 5.12) in addition to inclusion. The binding defines semantic meaning: ownership commitment, hash preimage, or script template. Mode 2 does not add economic guarantees at the protocol layer but narrows the misuse surface.

## Extension Layer

This specification defines a base layer only. Developers may freely add price oracles, liquidation engines, auction mechanisms, collateral ratio enforcement, or governance systems above this layer. Any such addition must not alter or weaken the guarantees defined here.

## Intended Audience

Protocol engineers, security auditors, adversarial reviewers, and implementers. Familiarity with Bitcoin's consensus rules, SHA256d, and Merkle tree construction is assumed.

## Architectural Interpretation

This protocol is structured as a three-stage deterministic machine:

**Stage 1 — Classification.** Inputs are evaluated against structural constraints. For this system, classification is performed by SPV validation: header chain verification, Merkle inclusion proof reconstruction, confirmation depth measurement, and structural bounds on proof encoding. An input either satisfies classification or is rejected. There is no partial acceptance.

**Stage 2 — Selection.** A classified input is evaluated against a binding constraint that determines whether it corresponds to a specific intended execution path. In this system, the selector is the Mode 2 OP_RETURN binding mechanism (Section 5.12): the transaction must contain a commitment derived from the target swap's parameters. In Mode 1, the selector is the identity function — all classified inputs are admitted. Selector-bound execution means that a state transition is triggered only when both classification and selection succeed.

**Stage 3 — Execution.** A selected input causes a deterministic state transition. In this system, execution is the swap state machine (Section 8) operating under the reorg model (Section 7). Execution is reversible until finalization and irreversible after it.

This specification implements a member of a broader architectural class: systems that separate input classification from execution selection, and execution selection from state mutation. It does not claim to replicate any specific artifact or encoding of that class.

The distinction between this system and a closed-form machine of the same class is explicit: this system is input-driven and operates on external Bitcoin events. Its selector (Mode 2 binding) requires an externally constructed commitment embedded in a Bitcoin transaction. A closed-form machine of this class derives its selector from internal structure, requires no external inputs, and is self-contained. The two share an architectural pattern; they do not share an execution model.

> This system is a verification machine, not an economic system. Economic interpretation of its outputs is an application-layer responsibility, not a protocol guarantee.

---

# 1. Scope

## 1.1 Covered

- Bitcoin block header validation (SPV-level)
- Best chain selection
- Transaction inclusion proof verification
- Confirmation depth policy
- Reorg handling: continuous truth-tracking with explicit finalization
- Deterministic state transitions:
  - Atomic swaps (inclusion-triggered)
  - PTLC integration (observer interface)
  - Inclusion-triggered credit (Section 9)

## 1.2 Not Covered

- Full Bitcoin script or witness validation
- Mempool and unconfirmed transaction behavior
- UTXO spend tracking or output-level verification
- Oracle-driven or price-aware lending
- Dynamic collateral management
- Cross-deployment coordination

---

# 2. Definitions

| Term | Definition |
|---|---|
| Header | 80-byte Bitcoin block header |
| txid | SHA256d of non-witness serialized transaction; 32 bytes, internal byte order (little-endian) |
| wtxid | SHA256d of witness-serialized transaction; used only in witness commitment, never in SPV Merkle proofs |
| ChainWork | Cumulative proof-of-work derived from `bits` across all headers in a chain |
| Best Chain | Valid chain rooted at genesis with maximum cumulative ChainWork |
| SPV Proof | Tuple: (header chain, Merkle branch, txIndex, txid) |
| Event Validity | Cryptographic proof that a txid is included in a block on the best chain at a specified depth |
| Confirmed Transaction | Transaction at confirmation depth ≥ N on the current best chain |
| Admission Threshold (N) | Minimum confirmations to trigger a state transition; locked at 6 |
| Finalization Depth | Confirmation depth at which a provisional state becomes irreversible; locked at 12 |
| Orphan Header | A structurally valid header whose prevHash references no known header |
| Reorg | Replacement of the current best chain by a competing chain with strictly greater ChainWork |
| PROVISIONALLY_CLAIMED | Swap state: inclusion proven, transfer held in reversible escrow |
| FINALIZED | Swap state: irreversible; no longer tied to Bitcoin chain truth |

---

# 3. Header Validation

All rules in this section are deterministic and must be applied identically across all nodes.

## 3.1 Required Fields

Each header must be exactly 80 bytes containing these fields in standard Bitcoin serialization order:

| Field | Size | Encoding |
|---|---|---|
| version | 4 bytes | little-endian int32 |
| prevHash | 32 bytes | internal byte order |
| merkleRoot | 32 bytes | internal byte order |
| timestamp | 4 bytes | little-endian uint32, Unix epoch seconds |
| bits | 4 bytes | little-endian uint32, compact target encoding |
| nonce | 4 bytes | little-endian uint32 |

Any deviation from exactly 80 bytes must be rejected immediately.

## 3.2 Validation Rules

A header is valid if and only if all of the following hold:

**Rule 1 — Parent Linkage**

`prevHash` must reference a stored header, or the header must be the genesis header (Section 3.6).

**Rule 2 — Proof-of-Work**

```
target = decode_compact(bits)
hash   = SHA256d(header_bytes)
hash  <= target
```

Comparison is performed as big-endian unsigned 256-bit integers.

**Rule 3 — Median Time Past**

```
timestamp > median(timestamps of the 11 most recent ancestor blocks)
```

This is the only timestamp rule enforced. The `timestamp < (localTime + 2h)` future-bound rule is not enforced because it introduces a clock dependency and is a Bitcoin Core policy rule, not a consensus rule. Chains accepted here may be rejected by Bitcoin Core under policy constraints. This is an acknowledged, accepted divergence.

**Rule 4a — Difficulty Continuity (non-retarget blocks)**

For all blocks where `(height % 2016) != 0`:

```
bits == parent.bits
```

**Rule 4b — Difficulty Retarget (every 2016 blocks)**

For all blocks where `(height % 2016) == 0`:

```
actual_timespan = timestamp(last block of previous window)
                - timestamp(first block of previous window)

target_timespan = 2016 × 600   (= 1,209,600 seconds)

actual_timespan = clamp(actual_timespan, target_timespan/4, target_timespan×4)

new_target = previous_target × actual_timespan / target_timespan
```

`new_target` must be ≤ MAX_TARGET. `bits` must encode `new_target` exactly. All arithmetic uses 256-bit unsigned integers.

**Policy/Consensus Boundary:** Timestamp manipulation within MTP bounds can artificially stretch the retarget window, reducing difficulty by up to 4× per window. This effect compounds across windows. This verifier follows consensus rules, not policy rules. Chains produced via sustained timestamp manipulation may be accepted here and rejected by Bitcoin Core. See ChainWork Limitation in Section 3.3.

**Rule 5 — Target Bounds**

```
target(bits) <= MAX_TARGET
```

Bitcoin mainnet MAX_TARGET:
```
0x00000000FFFF0000000000000000000000000000000000000000000000000000
```

**Rule 6 — Version**

The `version` field is accepted as any parseable 4-byte integer. BIP 9 version bits are not evaluated.

Any header failing any rule must be rejected and must not be stored.

## 3.3 ChainWork Calculation

```
target(h)     = decode_compact(h.bits)
work(h)       = floor(2^256 / (target(h) + 1))
chainWork(h)  = chainWork(parent(h)) + work(h)
```

**Genesis base case:**
```
chainWork(genesis) = work(genesis)
```

The genesis header has no parent. All arithmetic uses 256-bit unsigned integers. Overflow of a 256-bit chainWork value is not achievable within Bitcoin's current PoW parameters and may be treated as a fatal implementation error.

**ChainWork Limitation:**

ChainWork represents maximum provable work under protocol rules. It does not represent actual economic cost, true security cost, or guaranteed reorg resistance. Miners may bias timestamps within MTP bounds to reduce difficulty; this reduction compounds across retarget windows, meaning a given chainWork value may be achievable at significantly less than nominal real-world cost under sustained timestamp drift.

ChainWork is valid for exactly one purpose: deterministic best-chain selection. Implementations must not use ChainWork as a proxy for economic finality or attack-cost estimation.

## 3.4 Chain Selection

The best chain is the valid chain rooted at genesis with the maximum cumulative ChainWork at its tip.

**Tie-breaking rule:** When two chain tips have equal ChainWork, select the chain whose tip hash is lexicographically smallest.

Hash comparison MUST be performed on the raw 32-byte hash array, interpreted as a big-endian unsigned 256-bit integer, without byte reversal. Implementations MUST NOT reverse the byte order before comparison, MUST NOT compare hex string representations, and MUST NOT apply any encoding transformation. The comparison is performed directly on the 32 bytes as produced by SHA256d.

The following are explicitly prohibited as tie-breaking criteria:
- First-seen arrival time
- Network reception order
- System clock

This rule produces identical results on all conforming nodes regardless of header reception order.

## 3.5 Fork and Orphan Handling

- All valid headers must be stored regardless of which chain they belong to
- Orphan headers (valid headers with unknown prevHash) must be stored in the orphan pool
- Orphans do not contribute to ChainWork of any chain
- When a header arrives that resolves an orphan's prevHash, the orphan must be reprocessed immediately
- Chain selection is applied dynamically; nodes must switch best chain deterministically when a higher-work chain is presented

**Orphan Pool Eviction:**

The orphan pool is bounded at 1000 entries. When the pool exceeds this limit, apply the following deterministic eviction policy in order:

1. **Primary:** Evict the entry with the greatest ancestry distance from any known best-chain header. Ancestry distance is computed as follows:

   ```
   distance(h):
     current = h
     steps = 0
     loop:
       if current.hash in headerStore → return steps
       if current.prevHash in orphanPool:
         current = orphanPool[current.prevHash]
         steps += 1
       else:
         return ∞
   ```

   Lookup is by exact hash key only. If `prevHash` is not present in the orphan pool as an exact key, the path terminates and distance is ∞. No branching traversal is permitted — the lookup is a single linear chain walk. If multiple orphans share a prevHash (a structurally degenerate case), the implementation must pick the one with the lowest hash (big-endian, ascending) for the walk; this is deterministic.

   Ancestry distance is computed once, at the moment of eviction, against the header store and orphan pool snapshots at that instant. It is not retroactively recomputed when new headers arrive; distance is only evaluated at eviction time.
2. **Secondary:** Among equal ancestry distance, evict the entry with the lowest bits-derived work (highest target value).
3. **Tie-break:** Lowest header hash, big-endian bytes, ascending.
4. Arrival time must not be used as any eviction criterion.

## 3.6 Genesis Header

Bitcoin mainnet genesis hash:
```
000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
```

Any header claiming genesis position that does not match this hash must be rejected. The genesis header requires no prevHash validation.

---

# 4. Header Ingestion

## 4.1 SubmitHeaders

**Input:** One or more headers in serialization order.

**Rules:**
- Valid headers must be stored; invalid headers must be rejected and not stored in any pool
- Non-contiguous submissions are permitted; gaps resolve when intermediate headers arrive
- Orphan headers must enter the orphan pool per Section 3.5

**Intra-block evaluation snapshot:**

The following ordering is mandatory for every Zenon block:

1. Apply all SubmitHeaders transactions in the block, in canonical order, updating best-chain state fully
2. Apply all reorg effects produced by Step 1 (Section 7.5–7.6) before any swap evaluation
3. Evaluate all swap lifecycle transactions (CreateSwap, ClaimSwap, ReclaimSwap) against the single best-chain snapshot produced by Steps 1–2

`currentBestChainHeight` and all confirmation depth checks MUST reflect chain state after ALL SubmitHeaders in the block have been applied and ALL resulting reorg effects have been resolved. No ClaimSwap may be evaluated against a partial or intermediate chain state. Streaming or incremental evaluation within a block is non-conforming.

Reorg effects from Step 1 MUST be applied before any ClaimSwap evaluation in the same block. A ClaimSwap referencing a header on a chain that was orphaned by a same-block reorg MUST be rejected with `HEADER_NOT_ON_BEST_CHAIN`.

**Duplicate header submission:** If a submitted header's hash already exists in the header store or orphan pool, the submission is a no-op. The stored header must not be overwritten. ChainWork must not be recomputed. No error is returned. Rationale: recomputing ChainWork on duplicates corrupts accumulated chain state.

**Resource limits (anti-DoS policies):** The following are implementation-level safeguards, not consensus rules. They must not affect consensus outcomes or cause divergent state across nodes. Rejected inputs must not alter deterministic state.

- Maximum headers per SubmitHeaders call: 2000
- Maximum Merkle proof length: 64 nodes (covers 2^64 transactions; longer proofs are rejected with `PROOF_TOO_LONG`)
- Per-source submission rate: implementation-defined; must be documented
- Maximum concurrent ACTIVE swaps per address: implementation-defined; must be documented

## 4.2 Storage Requirements

| Store | Key | Value |
|---|---|---|
| Header store | hash → header | full 80-byte header |
| Height index | height → hash (best chain only) | best-chain header hash at height |
| ChainWork store | hash → chainWork | uint256 |
| Best chain tip | — | current best tip hash |
| Orphan pool | hash → header | orphaned valid headers |

**Height index continuity invariant:** The best-chain height index MUST form a contiguous sequence from genesis (height 0) to the current best chain tip with no gaps. Every integer height in `[0, bestChainHeight]` must have exactly one entry. Implementations that produce a non-contiguous height index are non-conforming. On reorg, the height index must be updated atomically to reflect the new best chain — entries for orphaned heights must be replaced or removed before any swap evaluation occurs in that block.

**Header store bounds:** The header store is unbounded by default. Implementations may prune with these constraints:
- Headers within `max(FINALIZATION_DEPTH, 100)` blocks of the current best tip must not be pruned
- Headers referenced by any ACTIVE or PROVISIONALLY_CLAIMED swap's `claimBlockHeight` must not be pruned
- Pruning must be deterministic and applied identically across all nodes
- If a node cannot verify a historical SPV proof due to pruning, it must return `HEADER_PRUNED`

**Pruning and deep reorg interaction:** Reorg depth is unbounded. A node that has pruned headers required to validate a higher-work competing chain MUST reject that chain with `HEADER_PRUNED` rather than accepting it unverified. This may cause temporary divergence between pruned and unpruned nodes until sufficient headers are resubmitted by the competing chain's submitter. This is an accepted operational tradeoff: pruned nodes may temporarily lag behind unpruned nodes in recognizing deep reorgs. Nodes with strict reorg-safety requirements SHOULD NOT prune headers.

---

# 5. Transaction Inclusion Proof

All rules in this section are deterministic and must be applied identically across all nodes.

## 5.1 Inputs

| Field | Type | Description |
|---|---|---|
| txid | bytes[32] | Non-witness transaction hash, internal byte order (little-endian) |
| blockHeight | uint32 | Height of the block containing the transaction |
| merkleProof | ProofNode[] | Ordered Merkle branch |
| txIndex | uint32 | 0-based transaction index within the block |

**Encoding constraint:** txid must be SHA256d of the non-witness serialized transaction, stored and compared as 32 raw bytes in internal byte order. The wtxid must never be used in SPV Merkle proofs. Submission of a wtxid must result in rejection.

## 5.2 ProofNode Structure

```
struct ProofNode {
    hash:     bytes[32]
    position: LEFT | RIGHT
}
```

`position == LEFT` means: `SHA256d(sibling || current)`
`position == RIGHT` means: `SHA256d(current || sibling)`

## 5.3 Structural Validation

A proof is structurally valid if all of the following hold:

1. `len(merkleProof) >= 0` (empty proof is valid for a single-transaction block)
2. `txIndex < 2^len(merkleProof)` — txIndex must be representable within a tree of the proof's depth; a txIndex that exceeds this bound cannot correspond to any leaf position in a tree of this height → `TXINDEX_MISMATCH`
3. At each level `i`, sibling position must be consistent with `txIndex`:
   - `txIndex % 2 == 0` → position must be `RIGHT`
   - `txIndex % 2 == 1` → position must be `LEFT`
4. After each level: `txIndex = floor(txIndex / 2)`

Violation of rule 3 or 4 → `MERKLE_STRUCTURAL_INVALID`

Note on rule 2: for an empty proof (single-transaction block), `txIndex` must be 0. Any other value with an empty proof is `TXINDEX_MISMATCH`.

## 5.4 Root Reconstruction

```
current = txid
index   = txIndex

for node in merkleProof:
    if node.position == LEFT:
        current = SHA256d(node.hash || current)
    else:
        current = SHA256d(current || node.hash)
    index = floor(index / 2)
```

`current` must equal `header.merkleRoot` exactly. Mismatch → `MERKLE_ROOT_MISMATCH`

## 5.5 Duplicate Hash Handling

Bitcoin's Merkle tree duplicates the last hash at any level with an odd node count. This is valid Bitcoin construction and must be accepted.

Duplicate adjacent hashes must not be rejected on the basis of equality alone.

What is rejected: structural inconsistency with txIndex (Section 5.3) and root mismatch (Section 5.4). These two checks are the complete and correct defense against CVE-2012-2459. Blanket hash-equality rejection incorrectly rejects valid proofs for blocks with odd transaction counts.

**Structural completeness limitation:** This verifier validates parity consistency and root correctness. It does not reconstruct or validate full tree shape. Proof depth is not validated against total block transaction count (unavailable to an SPV verifier). A malformed proof satisfying parity constraints and producing the correct root would pass. The root match provides the security guarantee; SHA256d preimage resistance makes forgery computationally infeasible.

## 5.6 Coinbase Transactions

Coinbase transactions (txIndex == 0) are valid proof subjects. The Merkle proof may be empty if the block contains exactly one transaction. No special-case logic applies.

## 5.7 SegWit and Taproot

The Merkle tree in `header.merkleRoot` commits to txid, not wtxid. Witness data is not verified. The witness commitment in the coinbase output is not evaluated. This verifier proves inclusion, not execution.

## 5.8 Verification Rules

A transaction is validly included if and only if all of the following hold:

1. The best-chain height index contains an entry for `blockHeight`
2. The header hash stored at `blockHeight` in the height index matches the header used for Merkle root comparison — verifiers must retrieve the header by `bestChainHeightIndex[blockHeight]` and use that specific header's `merkleRoot`; using a header at the same height from a different fork is non-conforming
3. Proof passes structural validation (Section 5.3)
4. Reconstructed root equals `header.merkleRoot` of the best-chain header at `blockHeight`
5. Confirmation depth satisfies Section 6

## 5.9 Proof Output

```
result: VALID | REJECTED

rejectionCode:
  HEADER_NOT_FOUND
  HEADER_NOT_ON_BEST_CHAIN
  HEADER_PRUNED
  MERKLE_STRUCTURAL_INVALID
  MERKLE_ROOT_MISMATCH
  PROOF_TOO_LONG
  TXINDEX_MISMATCH
  RAW_TX_MISSING              (Mode 2 only: rawTx not provided)
  MALFORMED_TX_ENCODING       (Mode 2 only: rawTx unparseable or exceeds MAX_RAW_TX_SIZE)
  BINDING_CONSTRAINT_FAILED   (Mode 2 only: no output matches expected OP_RETURN commitment)
  SELECTOR_HEIGHT_INVALID     (DELAYED_HEADER_SELECTOR_V1 only: blockHeight < 1)
  SELECTOR_HEADER_MISSING     (DELAYED_HEADER_SELECTOR_V1 only: H0 or H1 not retrievable from best-chain height index)
  INSUFFICIENT_CONFIRMATIONS
  PROOF_REPLAYED
```

## 5.10 Security Properties

A VALID result guarantees:
- The transaction exists in a block on the current best chain
- The transaction is committed to by that block's Merkle root
- Inclusion cannot be forged without breaking SHA256d preimage resistance

A VALID result does not guarantee output existence, value, unspentness, ownership, or economic soundness.

## 5.11 Invariant

> No state transition may rely on a Bitcoin transaction unless inclusion is proven via this section.

## 5.12 Transaction Intent Binding (Mode 2 — Strict OP_RETURN Commitment)

Mode 1 deployments impose no binding constraint: any transaction satisfying SPV inclusion is sufficient to trigger a state transition.

Mode 2 deployments require that the referenced Bitcoin transaction contains a deterministic commitment binding it to the specific swap. This eliminates arbitrary transaction triggering, including the coinbase-as-proof vector (Section 18.3.9).

**Mode declaration:** Binding mode is a deployment-wide constant, not a per-transaction field. All nodes in a deployment must operate in the same mode. Mixed-mode deployments are non-conforming. Mode 2 deployments must declare:

```
bindingMode   = MODE_2_STRICT_OP_RETURN_32
bindingDomain = ZENON_BTC_BIND_V1
```

**Binding value computation:**

```
DOMAIN_SEPARATOR = 5a454e4f4e5f4254435f42494e445f5631
                   (ASCII: "ZENON_BTC_BIND_V1", 17 bytes, no null terminator)

bindingValue = SHA256d(
    DOMAIN_SEPARATOR
    || swapId        (32 bytes, as defined in Section 8.3)
    || counterparty  (20 bytes, canonical address payload only —
                      no prefix, no checksum, no variable-length encoding)
    || outputIndex   (4 bytes, little-endian uint32)
)
```

`bindingValue` is exactly 32 bytes. No length prefixes, delimiters, or alternate encodings are permitted at any field boundary. The domain separator provides cross-protocol collision resistance.

**Bitcoin binding rule:**

A transaction satisfies the binding constraint if and only if it contains at least one output whose scriptPubKey is exactly:

```
Byte offset  Value       Meaning
0            0x6a        OP_RETURN opcode
1            0x20        push 32 bytes (decimal 32)
2–33         bindingValue  32-byte commitment

Total scriptPubKey: exactly 34 bytes
```

Exact byte equality is required across all 34 bytes. No prefix matching, no partial matching, no payload decoding beyond byte comparison. If multiple outputs satisfy the match, the transaction is still valid; the scan halts on the first match.

**Output scan procedure:**

Outputs are scanned in transaction serialization order (output index 0, 1, 2, ...). The scan halts on first match. Output count is determined from `rawTx` serialization; no external block data is consulted.

**Security boundary:**

Binding proves only that the transaction contains a commitment matching this swap. Binding does not prove output ownership, output existence or value, UTXO unspentness, or economic validity. The economic/misuse surface classification from Section 17.2 is unchanged.

**Determinism requirements:**

All binding validation must operate on raw bytes only, perform exact byte equality comparisons, avoid script execution entirely, ignore witness data completely, and depend only on `rawTx` and swap state. Results must be identical across all conforming nodes.

---

## 5.13 Structural Selector (Optional Extension — Delayed Header Selector)

**Status:** This section defines an optional execution-layer extension. It is non-conformance-critical unless explicitly enabled. Deployments must declare selector mode. Mixed selector modes are non-conforming.

**Mode declaration:**

```
selectorMode = DISABLED | DELAYED_HEADER_SELECTOR_V1
```

If `selectorMode = DISABLED`: this section is ignored entirely.

If `selectorMode = DELAYED_HEADER_SELECTOR_V1`: all ClaimSwap executions must compute the structural selector per this section in addition to all existing validation rules. The selector is computed and recorded but does not gate execution — it imposes no admission threshold. This preserves the architecture's three-stage pattern (classification → selection → execution) without introducing a probabilistic liveness constraint.

**Purpose:** The structural selector binds execution to a specific Bitcoin chain placement by deriving a deterministic value from the swap's fixed parameters and the best-chain headers at the claimed block height. This value is available for application-layer use (logging, auditing, cross-system verification) without altering protocol-level admission.

### 5.13.1 Selector Seed

```
SELECTOR_DOMAIN = 5a454e4f4e5f4254435f53454c4543544f525f5631
                  (ASCII: "ZENON_BTC_SELECTOR_V1", 21 bytes)

selectorSeed = SHA256d(
    SELECTOR_DOMAIN
    || swapId            (32 bytes, as defined in Section 8.3)
    || creationBlockHash (32 bytes, Zenon block hash at swap creation)
)
```

`selectorSeed` is exactly 32 bytes and is fixed at swap creation time. It does not depend on transaction layout, Merkle siblings, txIndex, or any value that could be mutated by a claimant.

### 5.13.2 Header Inputs

```
H0 = bestChainHeaderHashAt(blockHeight)
H1 = bestChainHeaderHashAt(blockHeight - 1)
```

Height constraint: if `blockHeight < 1`, reject with `SELECTOR_HEIGHT_INVALID`.

Both H0 and H1 must be retrieved from the best-chain height index (Section 4.2). They are raw 32-byte header hashes in internal byte order. No byte reversal is applied.

**Lookup failure semantics:** The best-chain height index must be contiguous (Section 4.2 invariant). If either `bestChainHeaderHashAt(blockHeight)` or `bestChainHeaderHashAt(blockHeight - 1)` cannot be retrieved — due to pruning, index corruption, or any other cause — the implementation must reject with `SELECTOR_HEADER_MISSING`. Silent failure or substitution of a zero value is non-conforming. Note: `blockHeight >= 1` is enforced by Step S1, so `blockHeight - 1 >= 0` (genesis) is always a valid height; a conforming implementation with an unpruned index will always have this entry.

### 5.13.3 Structural Selector Computation

```
structuralSelector = SHA256d(
    selectorSeed
    || H0
    || H1
)
```

`structuralSelector` is exactly 32 bytes.

**Acceptance rule:** The structural selector is computed and emitted as a non-consensus trace event. It does not gate ClaimSwap admission. No threshold, leading-byte, or partial-match constraint is applied. Execution continues unconditionally after Step S5.

**Storage (Option A — ephemeral derivation):** `structuralSelector` is ephemeral. It must not be written to consensus state, must not be stored in any registry or index, and must not be included in any consensus hash. It is recomputed on demand from its inputs (`swapId`, `creationBlockHash`, `H0`, `H1`) whenever needed. This eliminates hidden consensus surface: if a node recomputes the selector at any future point, it will produce the same value if and only if the same best-chain headers exist at those heights.

**Lifecycle under reorg:** Because `structuralSelector` is not stored, it has no reorg lifecycle. On Case D reversal, no selector cleanup is required — there is nothing to remove. A subsequent ClaimSwap on a different best chain recomputes the selector against the then-current `H0` and `H1`. The recomputed value may differ from the prior attempt; this is correct behavior and requires no reconciliation.

**Rationale for non-gating:** A leading-byte acceptance rule (e.g. `structuralSelector[0] == 0x00`) would permanently lock 255/256 swaps at any given block height, because the selector inputs are fixed after swap creation and block confirmation — the claimant cannot grind the result. This is a hard liveness defect incompatible with Section 7.9's liveness model. The selector is therefore a deterministic derivation, not an admission filter.

### 5.13.4 Determinism Constraints

The selector must:
- Use only `swapId`, `creationBlockHash`, and best-chain header hashes
- Operate on raw bytes only
- Perform no byte reversal
- Avoid string or hex comparison
- Not depend on `txIndex`
- Not depend on Merkle siblings
- Not depend on transaction layout
- Not inspect witness data
- Not use local time or peer order

Any implementation violating these constraints is non-conforming.

### 5.13.5 Security Boundary

The structural selector:
- Binds a computed value to specific Bitcoin chain placement
- Does not prove ownership, value, UTXO validity, or economic intent
- Does not prevent adversarial economic behavior
- Does not gate admission

It is a deterministic derivation for application-layer use. Its security properties derive from SHA256d preimage resistance applied to swap-fixed inputs and chain-state inputs.

---

# 6. Confirmation Policy

## 6.1 Admission Threshold

A transaction is considered confirmed for state transition purposes if and only if:

```
currentBestChainHeight - txBlockHeight >= N
```

Where:
- **N = 6** (admission threshold; not runtime-configurable)
- `currentBestChainHeight` = height of the current best chain tip at evaluation time
- `txBlockHeight` = height of the block containing the transaction

`currentBestChainHeight` reflects chain state after all SubmitHeaders in the same block have been applied (Section 4.1). Confirmation checks must be evaluated at claim time, not cached.

N = 6 is an admission threshold, not a finality guarantee. Claims admitted at depth 6 remain reversible until FINALIZATION_DEPTH = 12.

## 6.2 Finalization Depth

```
FINALIZATION_DEPTH = 12
```

A provisionally claimed swap becomes irreversible when `currentBestChainHeight - claimBlockHeight >= 12`. See Section 8.5.

---

# 7. Reorg Model

## 7.1 Definition

A reorg occurs when a competing header chain accumulates strictly greater cumulative ChainWork than the current best chain, causing the best-chain tip to change.

## 7.2 Reorg Depth

```
reorgDepth = oldBestHeight - commonAncestorHeight
```

Where `commonAncestorHeight` is the height of the last shared header between the old and new best chains.

There is no protocol-level maximum reorg depth. Any valid higher-work chain must be processed by these rules regardless of depth. Implementations may emit monitoring alerts for deep reorgs; alerts must not alter protocol behavior.

## 7.3 Canonical Rule

> Bitcoin best-chain truth is authoritative until FINALIZATION_DEPTH is reached.

Whenever the best chain changes, all Bitcoin-derived state must be re-evaluated against the new best chain. N = 6 is an admission threshold. FINALIZATION_DEPTH = 12 is the rollback boundary. Between 6 and 12 confirmations, state is provisional and reversible.

## 7.4 Confirmation Thresholds

| Depth | Meaning |
|---|---|
| 0–5 | Not eligible for ClaimSwap |
| 6–11 | Eligible for ClaimSwap; state is PROVISIONALLY_CLAIMED; reversible by reorg |
| ≥ 12 | FINALIZED; irreversible within this protocol |

## 7.5 Reorg Procedure

When a reorg occurs, execute in order:

**Step 1:** Update best-chain tip per Section 3.4. Update height index to reflect new best chain.

**Step 2:** Identify affected objects:
- Swaps in ACTIVE state whose btcTxid was previously considered included on the old chain
- Swaps in PROVISIONALLY_CLAIMED state whose claim was justified by the old chain

**Step 3:** For each affected swap, determine whether `swap.btcTxid` is included on the new best chain and recompute confirmation depth.

**Step 4:** Apply state repair rules (Section 7.6).

## 7.6 State Repair Rules

**Case A — ACTIVE, proof still valid on new chain**
btcTxid remains included; confirmations ≥ 6 on new best chain.
→ No change. Swap remains ACTIVE and claimable.

**Case B — ACTIVE, proof no longer valid**
btcTxid not included on new best chain, or confirmations < 6.
→ No change. Swap remains ACTIVE, not currently claimable. No rollback required; no claim was finalized.

**Case C — PROVISIONALLY_CLAIMED, proof still valid**
btcTxid remains included; confirmations ≥ 6 on new best chain.
→ No change. Remains PROVISIONALLY_CLAIMED.

**Case D — PROVISIONALLY_CLAIMED, proof invalidated**
btcTxid not included on new best chain, or confirmations < 6.
→ Reversal required (all steps atomic):
- Reverse provisional asset transfer (return to escrow)
- Clear `swap.claimBlockHeight` and `swap.claimChainTip`
- Remove `swapId` from `claimedSwaps` registry
- Remove `(swap.btcTxid, swap.outputIndex)` from `btcTxUsage`
- Set `swap.status = ACTIVE`
- Swap is again eligible for ClaimSwap when valid proof is re-established

`btcTxUsage` entries are reversible until FINALIZED. Once a swap reaches FINALIZED (Case E), its `btcTxUsage` entry is permanent. Before FINALIZED, the entry must be removed on any reorg that invalidates the claim.

**Case E — FINALIZED (any reorg depth)**
`swap.status == FINALIZED`

→ No rollback. FINALIZED is a one-way commitment.

**FINALIZED Divergence — Hard Boundary:**

Once FINALIZED, a swap's validity is no longer tied to Bitcoin best-chain truth. A FINALIZED swap may permanently reference a Bitcoin transaction that no longer exists on the best chain. This is an accepted, irreversible divergence condition.

After divergence:
- Zenon-side state remains FINALIZED and canonical
- Bitcoin-side reality may differ permanently
- No reconciliation mechanism exists
- The system continues operating normally; FINALIZED state is canonical regardless of subsequent Bitcoin history
- New swaps are evaluated only against the current best chain
- The `btcTxUsage` entry for a FINALIZED swap persists; the same `(btcTxid, outputIndex)` returns `OUTPUT_ALREADY_USED` regardless of chain state

**PTLC implication:** If a PTLC triggered on `onSwapFinalized`, scalar revelation is irreversible. Bitcoin-side unlock paths activated by that scalar remain exposed. Subsequent reorgs do not revoke revealed secrets. Cross-chain systems must treat FINALIZED divergence as a terminal event.

Implementations must treat FINALIZED as:

> A one-way commitment that may permanently diverge from Bitcoin consensus.

Applications must not assume post-finalization consistency between chains.

## 7.7 RECLAIMED Under Reorg

RECLAIMED is time-based. If a swap was reclaimed because `currentTime > expirationTime` and no prior claim was finalized, the reclaim stands regardless of subsequent chain changes. A Bitcoin transaction that existed on the old chain but was never used to claim before expiry cannot retroactively defeat the reclaim. First-valid-state-transition wins.

## 7.8 No Freeze, No Manual Intervention

The following are prohibited:
- Manual operator intervention for reorg handling
- Discretionary freeze logic
- Protocol behavior that varies based on alert state
- Special-case handling based on subjective reorg assessment

All reorg behavior is handled deterministically by protocol rules alone.

## 7.9 Liveness

This protocol prioritizes truth-tracking correctness over liveness. PROVISIONALLY_CLAIMED swaps may oscillate back to ACTIVE under repeated reorgs. An adversary with sustained majority hash power can prevent finalization indefinitely. This is a liveness failure; safety (no fund loss) is preserved. Mitigations are application-layer concerns.

## 7.10 Reorg Invariants

1. No swap may remain PROVISIONALLY_CLAIMED if its Bitcoin proof is invalid on the current best chain with depth ≥ 6
2. No FINALIZED swap may be rolled back for any reason
3. Reorg handling is purely deterministic
4. Alert emission must not affect consensus behavior
5. Bitcoin-derived state tracks current best-chain truth until FINALIZATION_DEPTH

## 7.11 Required Compliance Tests

Conforming implementations must demonstrate:
- Shallow reorg invalidating an unclaimed proof (Case B)
- Shallow reorg invalidating a PROVISIONALLY_CLAIMED proof (Case D → reversal)
- Reorg restoring a previously invalidated proof (B → A, claimable again)
- Reorg with no impact on unaffected swaps
- Reclaim after expiry remaining stable across later chain changes (Section 7.7)
- FINALIZED swap surviving a reorg with no state change (Case E)

---

# 8. State Transition Rules

All transitions must be deterministic, replay-safe, and reorg-safe per Section 7.

## 8.1 Swap Lifecycle

```
          CreateSwap
               │
            ACTIVE ─────────────────────────────┐
               │                                │
         ClaimSwap                        ReclaimSwap
         (depth ≥ 6)                      (expired)
               │                                │
    PROVISIONALLY_CLAIMED              RECLAIMED (terminal)
               │
      ┌────────┴────────┐
      │                 │
   Reorg           depth ≥ 12
   invalidates     (finalization)
      │                 │
    ACTIVE         FINALIZED (terminal)
```

## 8.2 State Definitions

| State | Terminal | Description |
|---|---|---|
| ACTIVE | No | Swap exists; not yet claimed or reclaimed |
| PROVISIONALLY_CLAIMED | No | Inclusion proven; transfer in reversible escrow; reorg-reversible |
| FINALIZED | Yes | Irreversible; no longer tied to Bitcoin chain truth |
| RECLAIMED | Yes | Expired; asset returned to creator |

## 8.3 CreateSwap

**Input:**

| Field | Type | Constraint |
|---|---|---|
| counterparty | address | Valid Zenon address |
| btcTxid | bytes[32] | Little-endian non-witness txid |
| outputIndex | uint32 | 0-based index of the referenced output |
| expirationTime | uint64 | Unix epoch seconds; must be > `currentTime + MIN_EXPIRY` |

`currentTime` is the Zenon block timestamp of the block in which CreateSwap is evaluated. System clock must not be used.

`MIN_EXPIRY = 3600` seconds.

**Timestamp Safety:** Block producers may skew Zenon block timestamps within consensus bounds. Applications must define `expirationTime = intended_expiry + safety_buffer` where `safety_buffer ≥ maximum expected timestamp skew`. The protocol does not enforce timestamp fairness.

**`swapId` generation:**
```
swapId = SHA256d(counterparty || btcTxid || outputIndex || expirationTime || creationBlockHash)
```

`creationBlockHash` is the Zenon block hash at creation time.

**Effects:**
- Create swap entry
- Lock Zenon-side asset in protocol-controlled escrow
- Set `swap.status = ACTIVE`

`btcTxUsage` is not written at CreateSwap. Output binding is registered atomically at ClaimSwap (Section 8.4).

## 8.4 ClaimSwap

**Input:**

| Field | Type | Description |
|---|---|---|
| swapId | bytes[32] | Swap identifier |
| blockHeight | uint32 | Bitcoin block height containing the referenced tx |
| merkleProof | ProofNode[] | Merkle inclusion proof |
| txIndex | uint32 | Transaction index in block |
| rawTx | bytes | Full non-witness serialized Bitcoin transaction (Mode 2 only; see below) |

**`rawTx` constraints (Mode 2):**

- Must be the exact non-witness serialization of the Bitcoin transaction — specifically, the serialization whose SHA256d produces `swap.btcTxid`
- Must not exceed `MAX_RAW_TX_SIZE = 100000` bytes; exceeding this limit is rejected with `MALFORMED_TX_ENCODING` before any parsing
- Must be parseable as a valid Bitcoin transaction in non-witness format; if not parseable, reject with `MALFORMED_TX_ENCODING`
- `rawTx` is consumed during validation only and is not stored

**Failure boundary (crisp):**

- `MALFORMED_TX_ENCODING` — `rawTx` exceeds size limit, or cannot be parsed as a Bitcoin transaction in non-witness format
- `TXID_MISMATCH` — `rawTx` is parseable but `SHA256d(rawTx) != swap.btcTxid`; this covers both incorrect non-witness serializations and witness-serialized input that happens to parse (witness serialization does not hash to the non-witness txid and will fail here)

A segwit-capable transaction submitted in witness serialization format will either fail `MALFORMED_TX_ENCODING` (if the witness marker/flag bytes cause a parse failure under non-witness rules) or `TXID_MISMATCH` (if it parses but hashes to the wtxid rather than the txid). Either path correctly rejects it. No separate rejection code for "witness serialization" is defined.

In Mode 1 deployments, `rawTx` is not required and must be ignored if submitted.

**Preconditions — all must hold:**

1. `swap.status == ACTIVE`
2. SPV proof is VALID per Section 5
3. Proof txid matches `swap.btcTxid` (32-byte exact comparison, internal byte order)
4. `currentBestChainHeight - blockHeight >= 6`
5. `swapId` not present in `claimedSwaps` registry

**SPV Proof Boundary:** SPV proves transaction inclusion in a block. It does not verify that `outputIndex` exists, has non-zero value, is unspent, or is controlled by any particular script. These guarantees require a UTXO proof layer not defined in this spec.

**Mode 2 binding validation (inserted after precondition 5, before atomic effects):**

All steps terminate immediately on failure. Steps M1–M5 execute only in Mode 2 deployments.

```
Step M1 — rawTx integrity:
  if rawTx not provided:
      reject RAW_TX_MISSING
  if len(rawTx) > 100000:
      reject MALFORMED_TX_ENCODING
  txid_computed = SHA256d(rawTx)   ← non-witness serialization
  if txid_computed != swap.btcTxid:
      reject TXID_MISMATCH

Step M2 — bindingValue computation:
  bindingValue = SHA256d(
      DOMAIN_SEPARATOR
      || swap.swapId                              (32 bytes)
      || canonical_20_byte_payload(swap.counterparty)  (20 bytes)
      || to_le_uint32(swap.outputIndex)           (4 bytes)
  )

Step M3 — expected scriptPubKey:
  expected = bytes([0x6a, 0x20]) || bindingValue
  (34 bytes total)

Step M4 — output scan:
  for output in parse_outputs(rawTx):
      if output.scriptPubKey == expected:
          goto Step M5
  reject BINDING_CONSTRAINT_FAILED

Step M5 — binding satisfied:
  continue to atomic effects block
```

**`parse_outputs(rawTx)` requirements:**

Parse the non-witness Bitcoin transaction format in serialization order:
- `version` (4 bytes, little-endian int32)
- `input_count` (varint) + inputs (consumed but not inspected for binding)
- `output_count` (varint) + outputs: for each output, `value` (8 bytes, ignored) and `scriptPubKey` (varint length + bytes)
- `locktime` (4 bytes)

Witness data must not be parsed or inspected. Script execution must not be performed. If `rawTx` cannot be parsed in this format, reject with `MALFORMED_TX_ENCODING`.

**Structural selector computation (Mode DELAYED_HEADER_SELECTOR_V1 only):**

Steps S1–S6 execute only when `selectorMode = DELAYED_HEADER_SELECTOR_V1`. Steps terminate immediately on failure.

```
Step S1 — height check:
  if blockHeight < 1:
      reject SELECTOR_HEIGHT_INVALID

Step S2 — retrieve headers:
  H0 = bestChainHeaderHashAt(blockHeight)
  H1 = bestChainHeaderHashAt(blockHeight - 1)
  (both from best-chain height index; raw 32-byte internal byte order)
  if either lookup fails for any reason:
      reject SELECTOR_HEADER_MISSING

Step S3 — selector seed:
  selectorSeed = SHA256d(
      SELECTOR_DOMAIN
      || swap.swapId           (32 bytes)
      || swap.creationBlockHash (32 bytes)
  )

Step S4 — structural selector:
  structuralSelector = SHA256d(
      selectorSeed
      || H0
      || H1
  )

Step S5 — ephemeral output:
  emit structuralSelector as a non-consensus trace event (log/event/audit)
  structuralSelector MUST NOT be written to consensus state
  structuralSelector MUST NOT be stored in any registry or index
  structuralSelector is recomputed on demand from its inputs when needed
  (no admission gate; execution continues unconditionally)

Step S6 — continue:
  proceed to atomic effects
```

**Effects (atomic — all must succeed or none apply):**

1. Check `(swap.btcTxid, swap.outputIndex)` is not present in `btcTxUsage`; if present → reject with `OUTPUT_ALREADY_USED`
2. Write `(swap.btcTxid, swap.outputIndex)` → `swapId` to `btcTxUsage`
3. Transfer Zenon asset from escrow to provisional allocation (reversible — see Section 8.10)
4. Set `swap.status = PROVISIONALLY_CLAIMED`
5. Set `swap.claimBlockHeight = blockHeight`
6. Set `swap.claimChainTip = currentBestChainTip`
7. Register `swapId → PROVISIONALLY_CLAIMED` in `claimedSwaps`

All seven steps are atomic. If any step fails, none are committed. No irreversible external transfer is permitted at ClaimSwap stage.

**Rationale for binding at ClaimSwap:** Binding at CreateSwap would allow an attacker to permanently lock arbitrary `(btcTxid, outputIndex)` pairs by creating swaps with no intent to claim, poisoning the registry. Binding at ClaimSwap ties the registry entry to an actual proven inclusion event, preventing state poisoning.

## 8.5 Claim Finalization

A PROVISIONALLY_CLAIMED swap transitions to FINALIZED when:

```
currentBestChainHeight - swap.claimBlockHeight >= 12
```

**Effects:**
- Set `swap.status = FINALIZED`
- Asset transfer becomes irreversible
- No further rollback permitted under any circumstances

Finalization is evaluated eagerly. At the end of every Zenon block, after all SubmitHeaders and swap lifecycle transactions have been processed, all swaps in PROVISIONALLY_CLAIMED state MUST be checked for the finalization condition. Any swap satisfying `currentBestChainHeight - swap.claimBlockHeight >= 12` MUST immediately transition to FINALIZED.

Finalization MUST iterate over PROVISIONALLY_CLAIMED swaps in ascending `swapId` order (byte-wise comparison, big-endian, ascending). This ordering is mandatory even if no current state dependency exists between finalization events — it prevents future nondeterminism if PTLC triggers or cross-swap interactions are added above this layer.

Lazy evaluation (on access), event-driven evaluation (only on new header submission), and deferred evaluation are non-conforming. Finalization must be applied identically at the end of every block across all conforming nodes.

## 8.6 Reorg Integration

Reorg handling follows Section 7.6 exactly. On Case D (PROVISIONALLY_CLAIMED proof invalidated):
- Reverse provisional transfer; return asset to escrow
- Clear claim metadata
- Remove `swapId` from `claimedSwaps`
- Set `swap.status = ACTIVE`

On Case E (FINALIZED): no rollback, no state change.

## 8.7 ReclaimSwap

**Preconditions — all must hold:**

1. `swap.status == ACTIVE`
2. `currentTime > swap.expirationTime`

`currentTime` is the Zenon block timestamp of the evaluating block. System clock must not be used. Block producers may bias this value within Zenon consensus bounds; counterparties should account for variance in expiration design.

**Effects:**
- Return escrowed asset to swap creator
- Set `swap.status = RECLAIMED`

**Conflict resolution:** If a valid SPV proof exists and the swap is also expired, canonical ordering determines which executes first:
1. Lower Zenon block height executes first
2. Within the same block: lower index in the block's canonical transaction list

Conflict resolution is defined only at finalized block level. Pre-block execution ordering — mempool ordering, propagation order, block producer selection — must not affect final committed state. Any node producing different state from the same finalized block is non-conforming.

## 8.8 Replay Protection

```
claimedSwaps: Map<swapId → status>
```

Status transitions are forward-only: ACTIVE → PROVISIONALLY_CLAIMED → FINALIZED. A `swapId` may re-enter ACTIVE only via reorg-driven Case D reversal.

- Replaying ClaimSwap when `status == PROVISIONALLY_CLAIMED` → no-op (idempotent)
- Replaying ClaimSwap when `status == FINALIZED` → `PROOF_REPLAYED`
- Replaying ClaimSwap when `status == RECLAIMED` → `SWAP_ALREADY_RECLAIMED`

## 8.9 Output Binding

```
btcTxUsage: Map<(btcTxid, outputIndex) → swapId>
```

A single `(btcTxid, outputIndex)` pair may be bound to exactly one `swapId`. The entry is written atomically during ClaimSwap (Step 1–2 of Section 8.4 effects), not at CreateSwap. This prevents state poisoning: only proven inclusion events create registry entries.

`btcTxUsage` entries are reversible until FINALIZED:
- Written atomically at ClaimSwap (PROVISIONALLY_CLAIMED transition)
- Removed atomically on Case D reorg reversal (return to ACTIVE)
- Permanent once swap reaches FINALIZED

Before FINALIZED, entries may be written and removed multiple times if a swap oscillates between ACTIVE and PROVISIONALLY_CLAIMED under reorg. After FINALIZED, the entry is permanent and must not be removed for any reason.

This prevents double-claiming of the same output reference within the swap subsystem of a single deployment. It does not prevent the same `(btcTxid, outputIndex)` from being referenced in a loan (Section 9), from being pledged in a separate deployment, or from referencing an already-spent or unowned output. Cross-primitive and cross-deployment exclusivity are economic/misuse surfaces, not protocol correctness properties.

**`btcTxUsage` size:** The registry size is bounded by the number of currently PROVISIONALLY_CLAIMED and FINALIZED swaps. Entries for ACTIVE swaps are not present. Implementations must account for the permanent growth of FINALIZED entries.

## 8.10 Escrow Model

All Zenon-side assets must remain in protocol-controlled escrow until `swap.status == FINALIZED`.

- Escrow must support deterministic reversal
- Provisional transfers must not escape protocol control
- External irreversible transfers are permitted only after FINALIZED
- Implementations that cannot safely reverse a PROVISIONALLY_CLAIMED transfer must not claim conformance with this spec

## 8.11 Rejection Codes

```
SWAP_NOT_FOUND
SWAP_NOT_ACTIVE
INSUFFICIENT_CONFIRMATIONS
SPV_PROOF_INVALID
TXID_MISMATCH
RAW_TX_MISSING
MALFORMED_TX_ENCODING
BINDING_CONSTRAINT_FAILED
SELECTOR_HEIGHT_INVALID
SELECTOR_HEADER_MISSING
PROOF_REPLAYED
SWAP_ALREADY_RECLAIMED
SWAP_NOT_EXPIRED
OUTPUT_ALREADY_USED
```

## 8.12 Invariants

1. No irreversible asset transfer before `swap.status == FINALIZED`
2. All PROVISIONALLY_CLAIMED transfers are escrow-held and reversible
3. FINALIZED and RECLAIMED are absorbing states
4. No swap may remain PROVISIONALLY_CLAIMED if its Bitcoin proof is invalid on the current best chain
5. Escrow balance equals total locked assets across all ACTIVE and PROVISIONALLY_CLAIMED swaps at all times
6. A single `(btcTxid, outputIndex)` is bound to at most one `swapId` at any moment; this binding is established atomically at ClaimSwap and removed atomically on Case D reorg reversal; it becomes permanent at FINALIZED
7. After FINALIZED, no assertion is made that the referenced Bitcoin output remains on the current best chain. FINALIZED state may permanently diverge from Bitcoin chain truth. This divergence is accepted, explicit, and irreversible.

---

# 9. Inclusion-Triggered Credit Model

## 9.1 What This Section Defines

A deterministic, oracle-free credit primitive anchored to Bitcoin transaction inclusion. This is not a collateralized lending system. This protocol proves transaction inclusion. It does not verify that the referenced output exists, is unspent, has value, or is controlled by the borrower. Credit terms are agreed off-protocol between counterparties. This system enforces the agreed lifecycle deterministically — it does not enforce economic soundness.

More precisely: this section defines a **time-locked, inclusion-triggered credit instrument**. The Bitcoin inclusion proof serves as a trigger event, not as verified collateral.

## 9.2 Design Constraint

Without a price oracle, continuous collateral valuation is impossible. Therefore:
- No mark-to-market lending
- No dynamic collateral ratios
- No oracle-driven liquidation
- No UTXO spend verification

## 9.3 Selected Model — Fixed-Term Binary Credit

Of the oracle-free models available, this protocol selects the fixed-term binary structure. Two alternatives are explicitly rejected:

- **Auction-Based Liquidation** — requires active bidders, on-chain market, and timing assumptions; introduces liveness dependencies incompatible with this spec's trust model
- **Same-Unit Debt** — requires BTC representation inside Zenon; too restrictive

**Lifecycle:**
```
Prove tx inclusion (SPV)
    → Loan issued to borrower
    → Repay before T → Bitcoin unlock path (borrower)
    └→ Expiry, no repayment → Bitcoin unlock path (lender)
```

Properties: no oracle required, fully deterministic, PTLC-enforceable, no liquidation logic.

Acknowledged tradeoffs: no protection against Bitcoin price drop; lender assumes volatility and counterparty risk; borrower can reference unowned or spent outputs.

## 9.4 Loan Creation

**Preconditions:**
1. Valid BTC inclusion proof per Section 5
2. Confirmation depth ≥ 6 on current best chain
3. No prior ClaimSwap has registered `(btcTxid, outputIndex)` in `btcTxUsage` (checked at claim time, not loan creation)

**Inclusion-Only Boundary:** This protocol proves transaction inclusion only. It does not verify that `outputIndex` exists, has value, is unspent, or is controlled by the borrower. Economic validity of the referenced output is assumed by the counterparties, not enforced by the protocol. Applications requiring output-level verification must add a UTXO proof layer above this spec.

**Input:**

| Field | Type | Description |
|---|---|---|
| btcTxid | bytes[32] | Reference transaction ID (non-witness, little-endian) |
| outputIndex | uint32 | 0-based index of the reference output |
| loanAmount | uint256 | Fixed Zenon asset amount |
| duration | uint64 | Loan duration in seconds |
| borrower | address | Borrower's Zenon address |
| lender | address | Lender's Zenon address |

**Derived fields:**
```
expirationTime = creationTime + duration
loanId = SHA256d(btcTxid || outputIndex || loanAmount || expirationTime
                 || borrower || lender || creationBlockHash)
```

**Effects:**
- Loan entry created with `loan.status = ACTIVE`
- Bitcoin inclusion proof recorded against `loanId`
- `loanAmount` transferred to borrower
- Repayment obligation established with `expirationTime`

## 9.5 Repayment

**Preconditions:**
1. `loan.status == ACTIVE`
2. `currentTime <= loan.expirationTime`
3. Borrower submits exactly `loanAmount`

`currentTime` is the Zenon block timestamp of the evaluating block. System clock must not be used.

**Effects:**
- `loan.status = REPAID`
- Bitcoin unlock path enabled for borrower via PTLC

## 9.6 Default

**Condition:**
```
currentTime > loan.expirationTime AND loan.status == ACTIVE
```

`currentTime` is the Zenon block timestamp of the evaluating block. System clock must not be used.

**Timestamp manipulation risk:** Block producers may skew Zenon block timestamps within consensus bounds, potentially triggering default conditions early or delaying them. Applications must define `expirationTime = intended_expiry + safety_buffer` where `safety_buffer ≥ maximum expected timestamp skew`.

**Effects:**
- `loan.status = DEFAULTED`
- Lender gains the Bitcoin-side unlock path via PTLC

## 9.7 PTLC Enforcement

PTLC enforces mutual exclusivity of unlock paths:
- Borrower unlock path: activated when `loan.status == REPAID`
- Lender unlock path: activated when `loan.status == DEFAULTED`

Only one party can complete an unlock path. PTLC internal cryptography is out of scope; this spec defines only the state conditions that activate each path.

## 9.8 No Liquidation

This system does not include margin calls, liquidation thresholds, or partial liquidation. These require price knowledge, which is prohibited.

## 9.9 Risk Model

| Party | Favorable | Unfavorable |
|---|---|---|
| Borrower | Bitcoin value rises; repay fixed debt, retain access | Bitcoin value drops; rational to default |
| Lender | Borrower repays; or defaults and lender gains unlock path | Borrower referenced unowned/spent output; Bitcoin price drops; unlock path has reduced value |

**Ownership and UTXO Risk:** This protocol does not verify that the borrower controls the referenced output, that it is unspent, or that it has any value. A borrower may reference any valid transaction regardless of ownership. Lenders must perform independent off-protocol verification of output ownership and UTXO status before extending credit. The protocol enforces the agreed lifecycle; it does not enforce economic soundness.

**Griefing:** A borrower may lock a reference proof and never intend to repay, forcing the lender to hold risk for the full duration. This is a counterparty risk, not a protocol flaw. The protocol provides enforcement guarantees, not fairness guarantees. Applications requiring fairness must implement reputation, bond, or other counterparty risk mechanisms at the application layer.

## 9.10 Invariants

1. Every loan references a provable Bitcoin transaction inclusion
2. No loan depends on external price data
3. Default condition is time-based only; no price trigger exists
4. Repayment condition is deterministic
5. No partial liquidation is possible
6. Within the swap subsystem, a single `(btcTxid, outputIndex)` is bound to at most one active swap at any moment. Cross-primitive exclusivity between loans and swaps is NOT enforced at the protocol layer — see Section 9.11

## 9.11 Limitations

This system cannot:
- Maintain stable collateral ratios
- Guarantee overcollateralization at any time after loan creation
- React to price volatility
- Provide DeFi-style lending markets with dynamic rates
- Verify that referenced outputs are economically meaningful

**Cross-primitive exclusivity:** This protocol does NOT enforce exclusivity between loans and swaps referencing the same `(btcTxid, outputIndex)`. The `btcTxUsage` registry is maintained only within the swap subsystem (enforced at ClaimSwap). A loan may reference the same output as an existing swap, and vice versa. This is an economic/misuse surface, not a protocol constraint. Applications requiring cross-primitive exclusivity must enforce it at the application layer.

---

# 10. PTLC Integration

## 10.1 Purpose

Point Time-Locked Contracts provide conditional unlock via scalar revelation, linking Bitcoin-side payment revelation to Zenon-side state transitions.

## 10.2 Interface Contract

The PTLC layer is a downstream observer of swap and loan state. It does not trigger state transitions; it observes them.

**Events emitted:**

```
onSwapProvisional(swapId, counterparty, btcTxid)
    → emitted when swap.status = PROVISIONALLY_CLAIMED

onSwapFinalized(swapId, counterparty, btcTxid)
    → emitted when swap.status = FINALIZED

onSwapReclaimed(swapId, creator, expirationTime)
    → emitted when swap.status = RECLAIMED

onLoanRepaid(loanId, borrower, btcTxid)
    → emitted when loan.status = REPAID

onLoanDefaulted(loanId, lender, btcTxid)
    → emitted when loan.status = DEFAULTED
```

The PTLC layer should use `onSwapFinalized` — not `onSwapProvisional` — as the trigger for irreversible scalar revelation. Using the provisional event exposes the PTLC to reorg-driven reversal. Once `onSwapFinalized` fires, scalar revelation is irreversible regardless of subsequent Bitcoin chain history.

## 10.3 Security Boundary

The SPV and swap layers provide: proof of Bitcoin transaction inclusion with confirmation depth and finalization guarantees.

The PTLC layer provides: conditional unlock based on scalar revelation.

These layers are independent. PTLC failure does not affect SPV proof validity or swap state. Swap finality does not depend on PTLC success.

## 10.4 Out of Scope

- Cryptographic correctness of adaptor signatures
- Scalar extraction from Bitcoin transactions
- PTLC timeout handling

---

# 11. Failure Modes and Mitigations

| Attack | Mechanism | Defense |
|---|---|---|
| Fake header injection | Headers with invalid PoW submitted | Rule 3.2 Rule 2: hash ≤ target, strictly enforced |
| Low-difficulty chain attack | Long chain at low difficulty submitted | ChainWork-based selection; low-difficulty chains cannot exceed honest ChainWork |
| Deep reorg against PROVISIONAL | Reorg removes claim's Bitcoin tx | Case D reversal; claim returns to ACTIVE; adversary must also undo their own Bitcoin tx |
| Deep reorg against FINALIZED | Reorg depth ≥ 12 | FINALIZED survives; protocol accepts bounded residual divergence risk |
| Reorg oscillation | Repeated slight-heavier forks preventing finalization | Accepted liveness tradeoff; safety preserved; mitigations are application-layer |
| Proof replay | Valid proof resubmitted for different swap | `claimedSwaps` registry; FINALIZED → `PROOF_REPLAYED`; RECLAIMED → `SWAP_ALREADY_RECLAIMED` |
| Output double-pledge | Same `(btcTxid, outputIndex)` claimed in two swaps | `btcTxUsage` map checked atomically at ClaimSwap; second successful claim → `OUTPUT_ALREADY_USED` |
| btcTxUsage state poisoning | Attacker creates swaps with arbitrary txids to permanently lock outputs in registry | Binding moved to ClaimSwap; only proven inclusion events write to registry; CreateSwap does not touch `btcTxUsage` |
| txIndex range attack | Huge txIndex with shallow proof reconstructs valid root, creating multiple valid encodings | txIndex must be < 2^len(merkleProof); enforced in structural validation |
| Same-height fork header substitution | Header from a non-best-chain fork at same height used for Merkle root comparison | Best-chain height index consulted by hash; header used for root comparison must match `bestChainHeightIndex[blockHeight]` exactly |
| Cross-deployment double-pledge | Same output pledged in two deployments | Not preventable at this layer; UTXO proof layer required |
| Loan-swap cross-primitive reuse | Same (btcTxid, outputIndex) used in both a loan and a swap | Not enforced at protocol layer; explicitly an economic/misuse surface; application-layer responsibility |
| btcTxUsage reorg gap | Reorg reverts PROVISIONALLY_CLAIMED but btcTxUsage entry persists, deadlocking swap | btcTxUsage entry removed atomically in Case D reversal; entry is reversible until FINALIZED |
| Merkle duplicate-hash attack (CVE-2012-2459) | Duplicate adjacent hashes produce valid-looking root | Structural parity check against txIndex; root match; blanket hash-equality rejection explicitly not applied |
| wtxid substitution | wtxid submitted instead of txid | txid encoding locked to non-witness hash; wtxid → rejected |
| Mode 2 rawTx witness serialization | rawTx submitted in segwit serialization format instead of non-witness | non-witness serialization required; witness format → `MALFORMED_TX_ENCODING` |
| Mode 2 binding prefix attack | OP_RETURN payload of ≠ 34 bytes or partial match | exact 34-byte equality required; no prefix or partial match accepted |
| Mode 2 rawTx size attack | Oversized rawTx submitted to exhaust parsing resources | `MAX_RAW_TX_SIZE = 100000` bytes enforced; rejection before parsing |
| Transaction-layout selector grinding | Claimant mutates tx structure (txIndex, Merkle siblings) until selector passes | Selector depends only on `swapId`, `creationBlockHash`, and best-chain headers; layout-dependent inputs are non-conforming |
| Partial chain submission | Headers with gaps submitted | Orphan pool; gaps do not contribute to best chain until resolved |
| Delayed header submission | Headers withheld to keep chain stale | Liveness attack only; confirmation evaluated at claim time |
| Future-timestamp header injection | Headers with far-future timestamps | MTP rule is chain-derived; no clock dependency |
| Orphan pool flooding | High-work orphan fragments flood pool | Ancestry-distance-first eviction retains near-anchor orphans |
| Timestamp-based expiry manipulation | Block producer skews Zenon timestamp near expiry | Acknowledged; applications must apply safety_buffer |

---

# 12. Global Invariants

The following must hold at all times across all conforming implementations:

1. No state transition relies on a Bitcoin transaction without a valid inclusion proof per Section 5
2. No swap transitions to PROVISIONALLY_CLAIMED without confirmation depth ≥ 6
3. No irreversible asset transfer before `swap.status == FINALIZED`
4. All PROVISIONALLY_CLAIMED transfers are escrow-held and reversible
5. FINALIZED and RECLAIMED are absorbing states; no exit transitions are defined
6. No FINALIZED swap is rolled back for any reason
7. No swap remains PROVISIONALLY_CLAIMED if its Bitcoin proof is invalid on the current best chain
8. Deterministic chain selection: identical inputs produce identical best-chain outputs
9. A FINALIZED `swapId` cannot re-enter PROVISIONALLY_CLAIMED
10. Within the swap subsystem only: a single `(btcTxid, outputIndex)` is bound to at most one `swapId` at any moment (enforced via `btcTxUsage`; reversible until FINALIZED; permanent after FINALIZED). This registry is local to the swap subsystem. Loans and other primitives do not participate in `btcTxUsage` and are not subject to this constraint. System-wide uniqueness of `(btcTxid, outputIndex)` across all primitives is not enforced and not guaranteed.
11. RECLAIMED is terminal; a RECLAIMED swap cannot be claimed even if a valid Bitcoin proof later appears
12. Escrow balance equals total locked assets across all ACTIVE and PROVISIONALLY_CLAIMED swaps
13. After FINALIZED, no assertion is made that the referenced Bitcoin output remains on the current best chain
14. The best-chain height index is contiguous from genesis to current tip with no gaps at all times
15. `btcTxUsage` entries for PROVISIONALLY_CLAIMED swaps are removed on Case D reorg reversal; entries for FINALIZED swaps are permanent

---

# 13. Test Vectors

## 13.1 Valid Header Chain

**Block 0 — Genesis (Bitcoin mainnet):**
```
version:    01000000
prevHash:   0000000000000000000000000000000000000000000000000000000000000000
merkleRoot: 3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a
timestamp:  29ab5f49   (1231006505)
bits:       ffff001d
nonce:      1dac2b7c
hash:       000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
```

**Block 1:**
```
version:    01000000
prevHash:   6fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000
merkleRoot: 982051fd1e4ba744bbbe680e1fee14677ba1a3c3540bf7b1cdb606e857233e0e
timestamp:  6c493f5f   (1231469665)
bits:       ffff001d
nonce:      e293cdbe
hash:       00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048
```

Expected: both headers accepted; Block 1 becomes best chain tip.

## 13.2 Invalid Header — Insufficient PoW

```
version:    01000000
prevHash:   6fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000
merkleRoot: ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
timestamp:  6c493f5f
bits:       ffff001d
nonce:      00000000
```

Expected: SHA256d(header) > target(bits). Rejected with `INVALID_POW`.

## 13.3 Valid Merkle Proof — Single Transaction Block

```
txid:        b1fea52486ce0c62bb442b530a3f0132b826c74e473d1f2c220bfa78111c5082
blockHeight: 170
txIndex:     0
merkleProof: []
```

Expected: empty proof; computedHash == txid == merkleRoot. VALID.

## 13.4 Invalid Merkle Proof — Root Mismatch

```
txid:        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
blockHeight: 170
txIndex:     0
merkleProof: []
```

Expected: computedHash ≠ header.merkleRoot. `MERKLE_ROOT_MISMATCH`.

## 13.5 Invalid Merkle Proof — Parity Violation

```
txid:        abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234
blockHeight: 200000
txIndex:     2       (even → sibling must be RIGHT)
merkleProof: [{ hash: deadbeef...deadbeef, position: LEFT }]
```

Expected: parity inconsistent with txIndex. `MERKLE_STRUCTURAL_INVALID`.

## 13.5b Invalid Merkle Proof — txIndex Out of Range

```
txid:        abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234
blockHeight: 200000
txIndex:     8       (= 2^3; proof has 3 nodes → valid range is 0–7 only)
merkleProof: [node0, node1, node2]   (len = 3 → max valid txIndex = 2^3 - 1 = 7)
```

Expected: txIndex >= 2^len(merkleProof). `TXINDEX_MISMATCH`.

## 13.5c Invalid Proof — txIndex Non-Zero with Empty Proof

```
txid:        abcd1234...
blockHeight: 200000
txIndex:     1
merkleProof: []
```

Expected: empty proof requires txIndex == 0. `TXINDEX_MISMATCH`.

## 13.6 Valid Proof — Odd-Leaf Duplication (Bitcoin-Compatible)

Block with 3 transactions; tx2 duplicated at level 0:
```
Level 0: [tx0, tx1, tx2, tx2]
Level 1: [SHA256d(tx0||tx1), SHA256d(tx2||tx2)]
Root:    SHA256d(level1_left || level1_right)
```

Proof for tx2 (txIndex=2):
```
merkleProof: [
  { hash: <tx2>,          position: RIGHT },   ← index=2, even → RIGHT ✓
  { hash: SHA256d(tx0||tx1), position: LEFT },  ← index=1, odd  → LEFT ✓
]
```

Expected: parity checks pass; root correct; duplicate hash is not a rejection criterion. VALID.

## 13.7 Confirmation Depth Check

```
txBlockHeight:       700000
currentBestHeight:   700005
actualConfirmations: 5
```

Expected: `INSUFFICIENT_CONFIRMATIONS`.

```
currentBestHeight:   700006
actualConfirmations: 6
```

Expected: passes (6 ≥ 6).

## 13.8 Reorg Scenarios

**13.8a — PROVISIONALLY_CLAIMED reversal:**
```
Swap S1: status = PROVISIONALLY_CLAIMED, claimBlockHeight = 700000
currentBestChainHeight = 700006 (depth = 6; not yet FINALIZED)
Chain B reorg diverges at 700001; S1.btcTxid absent from Chain B
```
Expected: Case D. Provisional transfer reversed. S1.status = ACTIVE. swapId removed from claimedSwaps.

**13.8b — FINALIZED survives reorg:**
```
Swap S2: status = FINALIZED, claimBlockHeight = 700000
currentBestChainHeight = 700012 (depth = 12)
Chain B reorg back to height 700005
```
Expected: Case E. No state change. FINALIZED is irreversible.

**13.8c — No impact on unaffected swap:**
```
Swap S3: status = ACTIVE, btcTxid not confirmed on any chain
Chain B reorg back 3 blocks
```
Expected: S3 remains ACTIVE. No change.

## 13.9 Finalization Transition

```
Swap S1: status = PROVISIONALLY_CLAIMED, claimBlockHeight = 700000
currentBestChainHeight = 700011 (depth = 11)
```
Expected: remains PROVISIONALLY_CLAIMED.

```
New block: currentBestChainHeight = 700012 (depth = 12)
```
Expected: swap.status → FINALIZED. Transfer irreversible. `onSwapFinalized` emitted.

## 13.10 Replay Protection

**13.10a — Replay against PROVISIONALLY_CLAIMED:**
```
ClaimSwap → PROVISIONALLY_CLAIMED
Replay ClaimSwap (same swapId)
```
Expected: no-op; idempotent.

**13.10b — Replay against FINALIZED:**
```
swap.status = FINALIZED
Replay ClaimSwap
```
Expected: `PROOF_REPLAYED`.

**13.10c — Replay against RECLAIMED:**
```
swap.status = RECLAIMED
ClaimSwap attempt
```
Expected: `SWAP_ALREADY_RECLAIMED`.

**13.10d — Output double-pledge, same output:**
```
(btcTxid, outputIndex=0) → swapId_1 registered
Attempt: new swap referencing (btcTxid, outputIndex=0)
```
Expected: `OUTPUT_ALREADY_USED`.

**13.10e — Output double-pledge, different output:**
```
(btcTxid, outputIndex=0) → swapId_1 registered
New swap referencing (btcTxid, outputIndex=1)
```
Expected: succeeds. Different outputs of the same transaction are independent.

---

# 14. Versioning

This document is identified by the version string `BTC-SPV-SPEC`. Implementations claiming conformance must embed this string in their conformance declaration.

Any breaking change to this spec requires a new version identifier. Nodes running different spec versions are not guaranteed to be interoperable.

Bitcoin's `version` header field is accepted as any parseable 4-byte integer and does not require a corresponding update to this spec unless the 80-byte header structure or hash algorithm changes.

---

# 15. Implementation Requirements

- Fully deterministic: identical inputs produce identical outputs across all conforming nodes
- Replay-safe: `claimedSwaps` enforces forward-only status transitions
- No external trust: clock dependency eliminated; no oracle, no peer coordination
- Independently verifiable: no inter-node coordination required for state computation
- SubmitHeaders processed before swap lifecycle operations within each block
- Two-stage claim model: PROVISIONALLY_CLAIMED → FINALIZED
- Finalization evaluated eagerly at end of each block; lazy or event-driven evaluation is non-conforming
- Intra-block evaluation snapshot: SubmitHeaders → reorg effects → swap operations; no partial visibility
- Escrow model supporting reversible provisional transfers
- `btcTxUsage` registry keyed on `(btcTxid, outputIndex)`
- Merkle structural validation per Section 5.3
- Ancestry-distance-first orphan eviction per Section 3.5
- Reorg procedure per Section 7.5; state repair per Section 7.6
- Compliance tests per Section 7.11
- Oracle mode declared explicitly; mixed-mode deployments prohibited
- Mode 2: `rawTx` validated against `swap.btcTxid` via SHA256d before binding check
- Mode 2: OP_RETURN binding verified via exact 34-byte comparison in serialization order
- Mode 2: `rawTx` size bounded at `MAX_RAW_TX_SIZE = 100000` bytes before parsing
- If `selectorMode = DELAYED_HEADER_SELECTOR_V1`: structural selector computation executes after Mode 2 binding validation (or after SPV validation in Mode 1) and before atomic effects
- Selector inputs must be limited to `swapId`, `creationBlockHash`, and best-chain header hashes
- Use of `txIndex`, Merkle siblings, or transaction layout in selector logic is non-conforming
- Structural selector does not gate admission; it is computed and recorded only

---

# 16. Conformance

An implementation claiming conformance to this spec must:

1. Pass all test vectors in Section 13
2. Implement all rules without deviation
3. Declare oracle operation mode (Mode 1 or Mode 2)
4. If Mode 2: declare `bindingMode = MODE_2_STRICT_OP_RETURN_32` and `bindingDomain = ZENON_BTC_BIND_V1`
5. Document all implementation-defined limits (submission rate, concurrent swap caps)
6. If `selectorMode = DELAYED_HEADER_SELECTOR_V1`: declare selector mode explicitly and implement Section 5.13 exactly
7. Embed version string `BTC-SPV-SPEC` in its conformance declaration

> Core guarantee: given identical header submissions and identical swap parameters, all conforming nodes produce identical state outputs.

---

---

# 17. Adversarial Economic Boundary

## 17.1 Scope of Guarantees

This protocol guarantees correctness of state transitions, not economic soundness.

The protocol guarantees:
- Deterministic verification of Bitcoin transaction inclusion
- Deterministic execution of state transitions based on that inclusion
- Reversibility of provisional state prior to finalization
- Irreversibility of state after finalization

The protocol does not guarantee:
- That referenced Bitcoin outputs exist, are unspent, or have value
- That a party controls any referenced Bitcoin output
- That counterparties behave rationally or in good faith
- That any transaction has economic meaning beyond inclusion
- That outcomes are fair, efficient, or economically balanced

## 17.2 Inclusion Is Not Collateral

A valid SPV proof establishes only:

> A transaction exists in a block on the best chain.

It does not establish ownership, spendability, value, exclusivity, or economic intent. Any system that interprets inclusion as collateral, guarantee, or economic backing is operating outside this protocol's guarantees.

## 17.3 Determinism vs Fairness

This protocol enforces deterministic outcomes, not fair outcomes. Adversaries may use valid state transitions to lock counterparty capital for the full duration of a contract, exploit timing boundaries near expiry or finalization, structure agreements that are unfavorable but valid, or trigger and avoid transitions based on strategic timing. The protocol executes these outcomes exactly as defined.

**Timing surfaces:** Three distinct timing boundaries exist in this protocol, each exploitable by the applicable attacker class:

| Boundary | Surface | Attacker Class | Mitigation |
|---|---|---|---|
| Expiry (`expirationTime`) | Block producer skew triggers RECLAIMED early or delays it | A3 | Mandatory `safety_buffer` in Section 8.3; applications must apply it |
| Admission depth (≥ 6) | Strategic timing of ClaimSwap submission relative to reorg risk | A4 | No mitigation at protocol layer; application-layer risk |
| Finalization depth (≥ 12) | Reorg oscillation prevents FINALIZED; optionality window exploitable | A5 | Accepted liveness tradeoff; Section 7.9 |

## 17.4 Reorg-Induced Economic Effects

Reorg behavior is fully deterministic but may produce economically adverse conditions: PROVISIONALLY_CLAIMED state may revert to ACTIVE repeatedly under oscillating reorgs; finalization may be delayed indefinitely under sustained chain instability; counterparties may be forced to hold positions longer than intended; selective reorg targeting may impact specific high-value positions. These are liveness and usability failures, not correctness failures.

## 17.5 Finalization and Irreversible Divergence

Finalization creates a one-way boundary. After FINALIZED, state is no longer tied to Bitcoin chain truth. A FINALIZED swap may reference a Bitcoin transaction that no longer exists on the best chain. No rollback or reconciliation is possible. Zenon-side state remains canonical regardless of Bitcoin history. This is an explicit and permanent divergence condition.

## 17.6 Information Release and Cross-Domain Effects

Finalization may trigger irreversible external effects, including PTLC scalar revelation, activation of Bitcoin-side unlock paths, and exposure of cryptographic secrets. Once revealed, secrets cannot be revoked, external systems may act on revealed information, and subsequent Bitcoin reorgs do not reverse these effects.

Finalization must be treated as:

> An irreversible export of information and rights beyond this system.

## 17.7 Timing and Timestamp Manipulation

All time-based conditions rely on Zenon block timestamps. Block producers may skew timestamps within consensus bounds, which may accelerate or delay expiry conditions, shift boundary conditions for repayment or reclaim, and create advantage near timing edges.

Section 8.3 mandates a protocol-level safety buffer: `expirationTime = intended_expiry + safety_buffer` where `safety_buffer ≥ maximum expected timestamp skew`. This is a binding protocol requirement, not optional guidance. The adversarial consequence is that any application that omits the safety buffer is vulnerable to A3-class timing attacks that the protocol explicitly cannot prevent.

## 17.8 Cross-Primitive and Cross-Deployment Reuse

This protocol enforces output binding only within the swap subsystem of a single deployment. It does not prevent reuse of the same `(btcTxid, outputIndex)` across loans and swaps, reuse across independent deployments, or multiple economic claims referencing the same Bitcoin transaction. Local uniqueness does not imply global uniqueness.

## 17.9 Optionality and Strategic Behavior

The reversible window between admission (depth ≥ 6) and finalization (depth ≥ 12) introduces economic optionality. Participants may benefit from reorg-driven reversals, optimize the timing of ClaimSwap submission, or employ external hedging strategies that exploit provisional state. This optionality is a direct consequence of Bitcoin's probabilistic finality model and is not mitigated at this layer.

## 17.10 Adversarial Model

Implementations and applications must assume participants will use the cheapest valid inclusion event available, participants may not control referenced Bitcoin outputs, participants may act to maximize counterparty loss rather than mutual benefit, and participants may combine on-chain actions with off-chain strategies. The protocol does not constrain adversarial economic behavior. It only ensures that all behavior remains within deterministic and verifiable bounds.

## 17.11 Design Boundary

This protocol is a verification and execution primitive, not a financial system.

It provides:

> Deterministic mapping from Bitcoin inclusion → state transition

It does not provide market mechanisms, risk management, collateral guarantees, or fairness enforcement. All economic structure must be built above this layer.

## 17.12 Invariant

> The protocol guarantees correctness of execution, not correctness of interpretation. Any system that depends on economic assumptions beyond transaction inclusion must enforce those assumptions independently.

---

# 18. Adversarial Playbooks

## 18.1 Purpose

This section defines adversarial strategies against the protocol and classifies them as either:

- **Protocol Correctness Attacks** — attempts to violate deterministic execution, verification guarantees, or state invariants. A conforming implementation must eliminate all of these.
- **Economic / Misuse Attacks** — strategies that exploit valid protocol behavior to produce unfavorable or deceptive economic outcomes. These are explicitly permitted surfaces and must be understood, not suppressed, at this layer.

## 18.2 Correctness Attacks

### 18.2.1 Same-Block Partial Visibility

**Objective:** Cause divergent ClaimSwap evaluation within a single Zenon block.

**Attack:** A block contains: (1) SubmitHeaders extending chain A, (2) SubmitHeaders extending competing chain B with greater ChainWork, (3) ClaimSwap referencing a transaction valid only on chain A. An implementation that evaluates ClaimSwap before processing all headers may accept the claim while another rejects it.

**Required behavior:** All SubmitHeaders must be processed first. All reorg effects must be applied second. All swap lifecycle operations execute against the final best-chain snapshot only. Intermediate chain states within the same block must not be visible to swap evaluation.

**Status:** Must be prevented. Any deviation is non-conforming.

---

### 18.2.2 Same-Height Fork Substitution

**Objective:** Validate inclusion using a header from a non-best-chain fork at the same height.

**Attack:** Attacker supplies a Merkle proof matching a fork header at height H while the best chain has a different header at H.

**Required behavior:** Verifier must retrieve the header via `bestChainHeightIndex[H]`. Merkle root comparison must use that exact header. Headers from alternate forks must not be considered valid for proof verification.

**Status:** Must be prevented.

---

### 18.2.3 txIndex Encoding Ambiguity

**Objective:** Create multiple valid encodings of a Merkle proof using an oversized txIndex.

**Attack:** Submit a shallow proof with an oversized txIndex that still reconstructs the correct root via the reconstruction algorithm, creating a non-canonical but passing encoding.

**Required behavior:** `txIndex < 2^len(merkleProof)` must be enforced. For empty proofs, `txIndex == 0` must be enforced.

**Status:** Must be prevented.

---

### 18.2.4 btcTxUsage Deadlock on Reorg

**Objective:** Permanently prevent a swap from being claimable after reorg invalidation.

**Attack:** (1) ClaimSwap writes `(btcTxid, outputIndex)` to `btcTxUsage`. (2) Reorg invalidates the claim. (3) Swap returns to ACTIVE. (4) Registry entry persists, blocking all future ClaimSwap attempts with `OUTPUT_ALREADY_USED`. Swap is permanently unclaimed with no recovery path.

**Required behavior:** Case D reversal must atomically remove `(btcTxid, outputIndex)` from `btcTxUsage` alongside all other reversal steps. `btcTxUsage` entries are reversible until FINALIZED.

**Status:** Must be prevented.

---

### 18.2.5 CreateSwap Registry Poisoning

**Objective:** Reserve arbitrary Bitcoin outputs without proving inclusion, permanently blocking legitimate claims.

**Attack:** Populate `btcTxUsage` at CreateSwap stage using arbitrary `(btcTxid, outputIndex)` pairs. Zero inclusion cost required; attacker only needs to create swaps, never claim them.

**Required behavior:** `btcTxUsage` must be written only at successful ClaimSwap. CreateSwap must not modify the registry.

**Status:** Must be prevented.

---

### 18.2.6 Non-Deterministic Finalization Ordering

**Objective:** Cause state divergence through inconsistent iteration order during same-block finalization.

**Attack:** Multiple swaps cross finalization depth in the same block. Different implementations iterate in different orders. If PTLC triggers or cross-swap interactions fire during finalization, ordering determines which fires first. Implementations that finalize in hash-map iteration order, insertion order, or any non-canonical order will diverge from implementations that use swapId order. This is the same class of vulnerability that has caused divergence in EVM-based systems when multiple events fire in the same block.

**Required behavior:** Finalization must iterate over PROVISIONALLY_CLAIMED swaps in ascending `swapId` order (byte-wise comparison, big-endian, ascending). This ordering is mandatory regardless of whether any current interaction exists between simultaneous finalizations.

**Status:** Must be prevented.

---

### 18.2.7 Non-Contiguous Height Index

**Objective:** Break proof verification via inconsistent height mapping after reorg.

**Attack:** Reorg updates best tip but leaves gaps or stale entries in the height index. A subsequent ClaimSwap at a previously-orphaned height retrieves the wrong header or no header, causing incorrect Merkle root comparison.

**Required behavior:** Height index must be contiguous from genesis to best tip at all times. Updates must be atomic on reorg and must complete before any swap evaluation in that block.

**Status:** Must be prevented.

---

### 18.2.8 Transaction-Layout Selector Grinding

**Objective:** Force selector success by mutating transaction structure.

**Attack:** A selector that depends on `txIndex`, Merkle siblings, or transaction layout allows a claimant to submit multiple transactions with different structures until the selector produces a favorable value. Transaction layout is under partial claimant control.

**Required behavior:** Selectors must depend only on swap-fixed data (`swapId`, `creationBlockHash`) and best-chain header hashes. These inputs are not under claimant control after swap creation and block confirmation. Any selector incorporating `txIndex`, Merkle siblings, or transaction layout is non-conforming.

**Status:** Must be prevented. The structural selector in Section 5.13 satisfies this constraint by construction.

## 18.3 Economic and Misuse Attacks

The following behaviors are valid under protocol rules. They are not prevented. They must be understood by application builders.

### 18.3.1 Inclusion Without Ownership

A participant references a Bitcoin transaction they do not control. The protocol verifies inclusion only; ownership is not checked. Consequence: counterparties may falsely assume economic backing from a reference the other party cannot act on.

### 18.3.2 Spent or Worthless Output Reference

A participant references an already-spent output or an output with no meaningful value. Protocol behavior remains correct. Consequence: economic interpretation may be entirely invalid while protocol execution is fully conforming.

### 18.3.3 Cross-Deployment Reuse

The same `(btcTxid, outputIndex)` is used in multiple independent deployments. The `btcTxUsage` registry is local to each deployment. Consequence: global uniqueness is not enforced; multiple independent economic claims may exist on the same Bitcoin reference simultaneously.

### 18.3.4 Cross-Primitive Reuse

The same `(btcTxid, outputIndex)` is used in both a swap and a loan, or across other primitives, within the same deployment. The protocol does not enforce cross-primitive exclusivity. Consequence: multiple economic claims may exist on the same reference within a single deployment.

### 18.3.5 Reorg Optionality Exploitation

Between depths 6 and 12, state is provisional and reversible. A participant may benefit from reorg-driven reversal — for example, by having submitted ClaimSwap on a chain that is subsequently reorganized, returning to ACTIVE and potentially claiming under more favorable conditions on the new chain. Consequence: the provisional window is an economic option and may be deliberately exploited.

### 18.3.6 Reorg Oscillation

An adversary with sufficient hash power repeatedly invalidates provisional claims without allowing finalization. Consequence: liveness degradation without correctness failure. Funds remain locked in escrow; no funds are lost; finalization is blocked indefinitely.

### 18.3.7 Timestamp Boundary Manipulation

Zenon block timestamps may be skewed within consensus bounds by block producers. Consequence: expiry conditions may trigger earlier or later than intended; advantage exists near timing boundaries. The mandatory safety buffer in Section 8.3 reduces but does not eliminate this surface.

### 18.3.8 Counterparty Capital Lock

A participant initiates a swap or loan with no intent to complete it, forcing the counterparty to wait for the full expiry duration before reclaiming escrowed assets. Consequence: capital inefficiency and griefing. No protocol rule is violated.

### 18.3.9 Meaningless but Valid Inclusion (Mode 1)

In Mode 1, any valid Bitcoin transaction may serve as the inclusion trigger. The strongest variant of this attack uses a coinbase transaction: coinbase txids appear at txIndex 0 in every block, are provably included in the block's Merkle root, require no special access, and carry no economic relationship to the swap counterparties whatsoever. An attacker can use any historical coinbase as an inclusion proof for any swap, triggering a fully valid state transition with zero economic meaning.

**Mode 2 closure:** This surface is eliminated in Mode 2 deployments. The binding validation (Section 5.12, Steps M1–M5) requires the transaction to contain an OP_RETURN output committing to the exact `swapId`, `counterparty`, and `outputIndex`. A coinbase transaction cannot satisfy this constraint without the counterparty having constructed the transaction with a specific OP_RETURN output — which requires knowledge of the `swapId` before the transaction is mined. An attacker cannot repurpose an arbitrary historical transaction because the binding value is swap-specific and computationally irreversible.

**Residual surface (Mode 1 only):** State transitions may be triggered by semantically unrelated transactions. Mode 2 deployments are not affected.

## 18.4 Finalization Risk Surface

Finalization is an irreversible boundary with cross-domain consequences:
- State becomes independent of Bitcoin chain truth
- PTLC scalars may be revealed
- External actions may be triggered that cannot be undone
- Subsequent Bitcoin reorgs do not affect finalized state or revealed secrets

Applications that treat `onSwapProvisional` as an action trigger bear full reorg risk. `onSwapFinalized` is the correct and safe trigger for irreversible actions.

## 18.5 Adversarial Model Summary

The protocol assumes: participants act adversarially; inclusion proofs may be economically meaningless; timing and reorg behavior may be exploited; off-chain strategies may be combined with on-chain actions. The protocol does not restrict adversarial economic behavior. It only ensures all behavior remains within deterministic and verifiable bounds.

## 18.6 Boundary Statement

> This protocol guarantees correctness of execution, not correctness of economic interpretation. All economic guarantees must be enforced outside this layer.

---

# 19. Threat Model Matrix

## 19.1 Purpose

This section defines attacker capabilities, target outcomes, and the protocol's guarantees under each condition. The matrix separates:

- **Safety** — correctness of state: no invalid transitions, no unauthorized fund loss
- **Liveness** — ability for honest participants to complete intended actions
- **Economic Soundness** — whether outcomes align with participant economic expectations

The protocol guarantees Safety unconditionally. Liveness is conditional on Bitcoin chain stability. Economic Soundness is not guaranteed under any attacker model.

## 19.2 Attacker Capability Classes

| Class | Description |
|---|---|
| A0 | Passive observer; no control |
| A1 | User-level adversary; can submit valid transactions |
| A2 | Coordinated participants; multiple users colluding |
| A3 | Zenon block producer; controls ordering and timestamp within consensus bounds |
| A4 | Bitcoin miner minority (< 50% hashpower) |
| A5 | Bitcoin miner majority (≥ 50% hashpower) |

## 19.3 Legend

| Symbol | Meaning |
|---|---|
| ✔ | Guaranteed |
| △ | Conditionally preserved / degraded |
| ✖ | Not guaranteed |

## 19.4 Threat Matrix

| Attack Scenario | Class | Safety | Liveness | Economic Soundness | Notes |
|---|---|---|---|---|---|
| Invalid header injection | A1 | ✔ | ✔ | ✔ | Rejected by PoW validation |
| Merkle proof forgery | A1 | ✔ | ✔ | ✔ | Requires SHA256d preimage break |
| Same-block partial visibility | A3 | ✔ | ✔ | ✔ | Prevented by mandatory execution ordering |
| Same-height fork substitution | A1 | ✔ | ✔ | ✔ | Prevented by best-chain height index lookup |
| txIndex encoding ambiguity | A1 | ✔ | ✔ | ✔ | Prevented by structural bounds check |
| btcTxUsage deadlock on reorg | A1 | ✔ | ✔ | ✔ | Prevented by reversible binding in Case D |
| CreateSwap registry poisoning | A1 | ✔ | ✔ | ✔ | Binding deferred to ClaimSwap |
| Non-deterministic finalization order | A3 | ✔ | ✔ | ✔ | Prevented by mandatory ascending swapId iteration |
| Non-contiguous height index | A3 | ✔ | ✔ | ✔ | Prevented by atomic height index update on reorg |
| Reorg invalidates provisional claim | A4 | ✔ | △ | ✖ | State rolls back correctly; applications using `onSwapProvisional` as action trigger bear economic reorg risk; `onSwapFinalized` is the safe trigger |
| Reorg oscillation (no finalization) | A5 | ✔ | ✖ | ✖ | Liveness failure; safety preserved; funds locked not lost |
| Deep reorg after FINALIZED | A5 | ✔ | ✔ | ✖ | Permanent divergence: FINALIZED state contradicts Bitcoin truth; accepted and explicit consequence of finality boundary |
| Deep reorg against pruned node | A4–A5 | △ | ✖ | ✖ | Pruned node rejects higher-work chain with `HEADER_PRUNED`; temporarily operates on stale best chain; resolves when headers resubmitted; nodes with strict reorg-safety must not prune |
| Inclusion without ownership | A1 | ✔ | ✔ | ✖ | Protocol does not verify ownership |
| Spent or worthless output reference | A1 | ✔ | ✔ | ✖ | No UTXO validation at this layer |
| Cross-deployment double pledge | A2 | ✔ | ✔ | ✖ | No global uniqueness enforcement |
| Cross-primitive reuse (loan + swap) | A2 | ✔ | ✔ | ✖ | Explicitly out of scope; application-layer responsibility |
| Timestamp manipulation near expiry | A3 | ✔ | △ | ✖ | Bounded by consensus skew rules; affects timing edges; mandatory safety buffer reduces exposure |
| Counterparty capital lock (griefing) | A2 | ✔ | △ | ✖ | No protocol rule violated; capital locked for full duration |
| Meaningless inclusion — coinbase (Mode 1) | A1 | ✔ | ✔ | ✖ | Valid per protocol; Mode 2 OP_RETURN binding eliminates this surface |
| Reorg optionality exploitation | A4 | ✔ | △ | ✖ | Provisional window is an economic option; no protocol mitigation |
| PTLC premature trigger on provisional event | A2 | ✔ | △ | ✖ | Application-layer misuse of `onSwapProvisional`; use `onSwapFinalized` |
| Finalization-triggered secret exposure | A2 | ✔ | ✔ | ✖ | Irreversible once `onSwapFinalized` fires; design intent |
| Header withholding (delay attack) | A4 | ✔ | △ | ✔ | Delays confirmation visibility only; no permanent economic harm once headers submitted |
| Orphan pool flooding | A1 | ✔ | △ | ✔ | Bounded by ancestry-distance eviction policy; legitimate near-anchor orphans retained |

## 19.5 Interpretation

**Safety** is preserved across all attacker classes. No invalid state transitions occur. No funds are lost due to protocol violation. No proof can be forged without breaking SHA256d preimage resistance. Safety is unconditional.

**Liveness** depends on attacker capability. Under A0–A3, liveness is generally preserved with minor degradation. Under A4, delays are possible due to header withholding or shallow reorgs. Under A5, liveness can fail completely via reorg oscillation. Liveness is conditional on Bitcoin chain stability.

**Economic Soundness** is not guaranteed under any attacker class. Failures include fake collateral signaling, cross-system reuse, timing exploitation, and irreversible divergence after finalization. Economic soundness must be enforced at the application layer.

## 19.6 Strongest Adversary: A5 (Majority Hashpower)

Under A5:
- Reorg depth is unbounded
- Finalization may never occur for targeted swaps
- Any provisional state can be repeatedly invalidated
- Selective reorg targeting of specific high-value positions is possible

Protocol response:
- Safety remains intact under all conditions
- Liveness may collapse for targeted swaps
- Finalized state remains irreversible within this protocol

**FINALIZED under A5:** Under reorg depth ≥ FINALIZATION_DEPTH, FINALIZED state may permanently diverge from Bitcoin chain truth. This is an accepted and explicit consequence of the finality boundary design — the protocol has chosen application-layer irreversibility over Bitcoin-layer truth at this depth. It is not an unqualified strength; it is a deliberate tradeoff.

This is the maximum adversarial boundary inherited from Bitcoin's PoW model.

## 19.7 Finalization Boundary

| Property | Before Finalization | After Finalization |
|---|---|---|
| Reversible | Yes | No |
| Bitcoin chain-dependent | Yes | No |
| Subject to reorg | Yes | No |
| Information leakage | Provisional | Irreversible |

This boundary defines the protocol's core tradeoff:

> Reversible truth-tracking → irreversible execution

## 19.8 Assumption Summary

The protocol relies on four load-bearing assumptions:

1. **SHA256d preimage resistance** — violation breaks Safety
2. **Honest-majority Bitcoin PoW** — violation breaks Liveness (not Safety)
3. **Deterministic Zenon block execution** — violation breaks determinism at the execution layer
4. **Bounded Zenon timestamp skew within consensus rules** — violation breaks time-based transition correctness

## 19.9 Boundary Statement

> This protocol guarantees Safety under all defined attacker classes. It guarantees Liveness only under bounded adversarial conditions. It does not guarantee Economic Soundness under any attacker model.

---

---

# Appendix A: Implementation Notes — Cryptographic Operations

## A.1 Genesis ChainWork Computation

The genesis ChainWork is computed identically to any other block — there is no special case beyond the absence of a parent. The formula in Section 3.3 applies directly.

**Bitcoin mainnet genesis parameters:**

```
bits:         ffff001d
version:      01000000
prevHash:     0000000000000000000000000000000000000000000000000000000000000000
merkleRoot:   3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a
timestamp:    29ab5f49  (= 1231006505 decimal)
nonce:        1dac2b7c
hash:         000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
```

**Step-by-step genesis ChainWork derivation:**

```
# Step 1: decode_compact(bits)
# bits = 0x1d00ffff  (stored little-endian as ffff001d on disk)
# compact encoding: exponent = bits >> 24 = 0x1d = 29
#                   mantissa = bits & 0x00ffffff = 0x00ffff

exponent = 29
mantissa = 0x00ffff

target = mantissa * 256^(exponent - 3)
       = 0x00ffff * 256^26
       = 0x00000000FFFF0000000000000000000000000000000000000000000000000000

# Step 2: work(genesis)
work = floor(2^256 / (target + 1))

# Numerator:
2^256 = 0x10000000000000000000000000000000000000000000000000000000000000000
      (65 hex digits, 257 bits)

# Denominator:
target + 1 = 0x00000000FFFF0000000000000000000000000000000000000000000000000001

# Result (256-bit integer division):
work(genesis) = 0x0000000100010001

# Step 3: chainWork(genesis) = work(genesis)  (no parent)
chainWork(genesis) = 0x0000000000000000000000000000000000000000000000000100010001
```

**Pseudocode (big-integer arithmetic):**

```python
def decode_compact(bits: int) -> int:
    # bits is a 32-bit unsigned integer
    exponent = (bits >> 24) & 0xff
    mantissa  = bits & 0x007fffff
    # Handle sign bit in compact encoding
    if bits & 0x00800000:
        mantissa = -(mantissa)
    if exponent <= 3:
        return mantissa >> (8 * (3 - exponent))
    else:
        return mantissa << (8 * (exponent - 3))

def block_work(bits: int) -> int:
    target = decode_compact(bits)
    if target <= 0:
        return 0
    # 2^256 as a Python int (exact, arbitrary precision)
    numerator = 1 << 256
    return numerator // (target + 1)

def chain_work(headers: list) -> int:
    # headers[0] is genesis; each header has a .bits field
    cumulative = 0
    for h in headers:
        cumulative += block_work(h.bits)
    return cumulative

# Genesis validation:
genesis_bits = 0x1d00ffff
assert block_work(genesis_bits) == 0x0000000100010001
assert hex(block_work(genesis_bits)) == '0x100010001'
```

**Verification:** The genesis block hash `000000000019d6689c...` satisfies `hash <= target` (the hash has 10 leading zero bytes; the target has leading zero bytes 0–3 and then `0x00ffff...`). `work(genesis)` = `0x100010001` in hex, which equals `4295032833` in decimal. This value is stable and deterministic; any implementation producing a different genesis ChainWork is non-conforming.

## A.2 ChainWork Arithmetic — Big-Integer Requirements

All ChainWork values are 256-bit unsigned integers. Implementations must use one of:

- Language-native arbitrary-precision integers (Python `int`, Go `big.Int`, Rust `num-bigint`)
- A fixed 256-bit type with defined wrapping behavior (overflow is not achievable in practice)
- A uint256 library that implements unsigned division and addition without signed overflow

The division `floor(2^256 / (target + 1))` must be integer division (floor), not floating-point. Floating-point approximation introduces rounding errors that will produce incorrect ChainWork values and break chain selection determinism.

**Comparison for tie-breaking (Section 3.4):** The 32-byte header hash is treated as a big-endian unsigned 256-bit integer for comparison. In most implementations, this means comparing the raw byte array lexicographically from index 0 (most significant byte) to index 31 (least significant byte), with no byte reversal.

```python
def hash_as_int(hash_bytes: bytes) -> int:
    # hash_bytes is 32 bytes, SHA256d output in internal byte order
    # Interpret as big-endian unsigned 256-bit integer
    assert len(hash_bytes) == 32
    return int.from_bytes(hash_bytes, byteorder='big')

def select_best_chain(tip_a: bytes, tip_b: bytes,
                      work_a: int, work_b: int) -> str:
    if work_a > work_b:
        return 'A'
    if work_b > work_a:
        return 'B'
    # Equal ChainWork: smallest hash wins
    if hash_as_int(tip_a) < hash_as_int(tip_b):
        return 'A'
    return 'B'
```

## A.3 Merkle Root Reconstruction — Reference Implementation

```python
import hashlib

def sha256d(data: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()

def verify_merkle_proof(
    txid: bytes,          # 32 bytes, internal byte order
    tx_index: int,        # 0-based
    proof: list,          # list of (bytes[32], 'LEFT'|'RIGHT')
    merkle_root: bytes    # 32 bytes, from block header
) -> bool:
    # Structural validation
    if tx_index < 0:
        raise ValueError("TXINDEX_MISMATCH: negative index")
    max_index = (1 << len(proof)) - 1 if proof else 0
    if tx_index > max_index:
        raise ValueError("TXINDEX_MISMATCH: index exceeds tree depth")
    if not proof and tx_index != 0:
        raise ValueError("TXINDEX_MISMATCH: empty proof requires index 0")

    current = txid
    index   = tx_index

    for sibling_hash, position in proof:
        # Parity check
        if index % 2 == 0 and position != 'RIGHT':
            raise ValueError("MERKLE_STRUCTURAL_INVALID: parity violation")
        if index % 2 == 1 and position != 'LEFT':
            raise ValueError("MERKLE_STRUCTURAL_INVALID: parity violation")

        if position == 'LEFT':
            current = sha256d(sibling_hash + current)
        else:
            current = sha256d(current + sibling_hash)

        index = index // 2

    return current == merkle_root
```

---

# Appendix B: Extended Test Vectors

This appendix provides complete test vectors for the compliance tests required in Section 7.11, plus additional Merkle proof cases. All values are hex-encoded unless stated otherwise.

## B.1 Genesis and Block 1 ChainWork

```
Block 0 (Genesis):
  bits:             1d00ffff
  target:           00000000FFFF0000000000000000000000000000000000000000000000000000
  work:             0000000000000000000000000000000000000000000000000000000100010001
  chainWork:        0000000000000000000000000000000000000000000000000000000100010001

Block 1:
  bits:             1d00ffff   (same difficulty epoch)
  target:           00000000FFFF0000000000000000000000000000000000000000000000000000
  work:             0000000000000000000000000000000000000000000000000000000100010001
  chainWork:        0000000000000000000000000000000000000000000000000000000200020002
  (= genesis.chainWork + block1.work)

Conformance check:
  Any implementation where chainWork(block1) != 0x200020002 is non-conforming.
```

## B.2 Merkle Proof — Single Transaction (Empty Proof)

```
Block height:   170
txid:           b1fea52486ce0c62bb442b530a3f0132b826c74e473d1f2c220bfa78111c5082
txIndex:        0
merkleProof:    []   (empty — block contains exactly one transaction)
merkleRoot:     b1fea52486ce0c62bb442b530a3f0132b826c74e473d1f2c220bfa78111c5082

Verification:
  computedHash = txid = b1fea52...
  computedHash == merkleRoot  →  VALID

Structural check:
  len(proof) = 0  →  max valid txIndex = 0
  txIndex = 0     →  within range  ✓
```

## B.3 Merkle Proof — Even-Leaf Tree (4 transactions, txIndex=2)

```
Transactions:   [tx0, tx1, tx2, tx3]

Tree:
  Level 0 (leaves):  tx0        tx1        tx2        tx3
  Level 1:           H(tx0,tx1)            H(tx2,tx3)
  Root:              H(H(tx0,tx1), H(tx2,tx3))

Proof for tx2 (txIndex=2):
  Level 0: sibling = tx3,          position = RIGHT  (index=2, even)
  Level 1: sibling = H(tx0,tx1),   position = LEFT   (index=1, odd)

txIndex traversal:
  Level 0: index=2, even → sibling RIGHT ✓ → index = floor(2/2) = 1
  Level 1: index=1, odd  → sibling LEFT  ✓ → index = floor(1/2) = 0

Reconstruction:
  current = tx2
  current = SHA256d(current || tx3)     = H(tx2,tx3)
  current = SHA256d(H(tx0,tx1) || current) = root

Result: VALID if current == header.merkleRoot
```

## B.4 Merkle Proof — Odd-Leaf Tree (3 transactions, Bitcoin duplicate padding)

```
Transactions:   [tx0, tx1, tx2]

Bitcoin Merkle construction (odd count → duplicate last):
  Level 0 (leaves):  tx0   tx1   tx2   tx2   ← tx2 duplicated
  Level 1:           H(tx0,tx1)   H(tx2,tx2)
  Root:              H(H(tx0,tx1), H(tx2,tx2))

Proof for tx2 (txIndex=2):
  Level 0: sibling = tx2,          position = RIGHT  (index=2, even)
  Level 1: sibling = H(tx0,tx1),   position = LEFT   (index=1, odd)

Note: sibling hash equals txid (both are tx2). Duplicate adjacent hashes
      MUST be accepted — this is valid Bitcoin Merkle construction.
      Blanket duplicate rejection would incorrectly invalidate this proof.

txIndex traversal:
  Level 0: index=2, even → RIGHT ✓ → index=1
  Level 1: index=1, odd  → LEFT  ✓ → index=0

Result: VALID — parity consistent; root matches; duplicate is not a rejection criterion.
```

## B.5 Merkle Proof — Invalid: Parity Violation

```
txid:        abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234
txIndex:     2   (binary: 10 → even → sibling MUST be RIGHT at level 0)
merkleProof: [{ hash: deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef,
                position: LEFT }]   ← WRONG: index=2 is even, LEFT is invalid

Structural check:
  index=2, even → expected RIGHT, got LEFT → MERKLE_STRUCTURAL_INVALID
```

## B.6 Merkle Proof — Invalid: txIndex Out of Range

```
txid:        abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234
txIndex:     8   (= 2^3; proof depth = 3 → valid range [0,7])
merkleProof: [node0, node1, node2]

Structural check:
  2^len(proof) = 2^3 = 8
  txIndex=8 >= 8 → TXINDEX_MISMATCH
```

## B.7 Merkle Proof — Invalid: Non-Zero Index with Empty Proof

```
txid:     abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234
txIndex:  1
proof:    []

Structural check:
  empty proof → max valid index = 0
  txIndex=1 > 0 → TXINDEX_MISMATCH
```

## B.8 Section 7.11 Reorg Compliance Test Vectors

### B.8.1 — Case B: Shallow reorg invalidating an unclaimed proof

```
Initial state:
  Best chain:     genesis → A1 → A2 → A3 → A4 → A5 → A6 (height 6)
  Swap S1:        status = ACTIVE
                  btcTxid = tx_alpha (included in A1, 6 confirmations)

Reorg event:
  Chain B submitted: genesis → B1 → B2 → B3 → B4 → B5 → B6 → B7
  chainWork(B) > chainWork(A)
  tx_alpha NOT present in any B-chain block

Post-reorg state:
  Best chain:     B (height 7)
  S1.status:      ACTIVE  (unchanged — no claim was in flight)
  S1 claimable:  NO (tx_alpha not on new best chain)

Expected outputs:
  Case B applies: no state change, no rollback required
  btcTxUsage:     unmodified (no entry was written)
```

### B.8.2 — Case D: Shallow reorg invalidating a PROVISIONALLY_CLAIMED swap

```
Initial state:
  Best chain:     genesis → A1 → ... → A706 (height 706)
  Swap S2:        status = PROVISIONALLY_CLAIMED
                  claimBlockHeight = 700000
                  btcTxid = tx_beta
                  (btcTxid, outputIndex=0) registered in btcTxUsage → swapId_S2
  Depth:          706 - 700000 = 6 (not yet FINALIZED; requires 12)

Reorg event:
  Chain B diverges at height 700001
  A706 ... A700001 orphaned
  tx_beta NOT present in Chain B

Post-reorg state (Case D):
  S2.status:               ACTIVE
  S2.claimBlockHeight:     cleared
  S2.claimChainTip:        cleared
  swapId_S2 in claimedSwaps: removed
  (tx_beta, 0) in btcTxUsage: removed
  Asset:                   returned to escrow

Claimable again:           YES, when valid proof re-established on best chain
```

### B.8.3 — Case E: FINALIZED swap survives any reorg

```
Initial state:
  Best chain:     genesis → ... → H712 (height 712)
  Swap S3:        status = FINALIZED
                  claimBlockHeight = 700000
                  depth = 712 - 700000 = 12  ✓ (finalized at block 700012)

Reorg event:
  Chain B submitted, diverges at height 700005
  Reorg depth = 712 - 700005 = 7

Post-reorg state (Case E):
  S3.status:      FINALIZED  (no change)
  Asset:          irreversible (no rollback)
  btcTxUsage entry: permanent

Expected output:
  No state change of any kind. FINALIZED is not evaluated in reorg procedure.
```

### B.8.4 — Reorg restoring a previously invalidated proof (B → A → claimable)

```
Phase 1: Initial claim
  Best chain A, height 706
  S4: ClaimSwap executed → PROVISIONALLY_CLAIMED (depth=6)

Phase 2: Reorg removes tx
  Chain B wins (higher ChainWork)
  tx_gamma absent from Chain B
  Case D: S4 reverts to ACTIVE, btcTxUsage entry removed

Phase 3: Chain A re-establishes with more work
  Chain A' submitted with greater ChainWork than B
  tx_gamma present in A' (same position)
  S4 may now execute ClaimSwap again (status=ACTIVE, btcTxUsage entry absent)

Expected: ClaimSwap succeeds → S4 status = PROVISIONALLY_CLAIMED
          btcTxUsage entry re-written atomically
          No replay rejection (claimedSwaps entry was removed in Phase 2)
```

### B.8.5 — RECLAIMED swap stable across chain changes

```
Initial state:
  Best chain, height 1000
  Swap S5: status = ACTIVE, expirationTime = T_exp
  tx_delta exists on best chain but was never claimed before T_exp

At Zenon block with timestamp > T_exp:
  ReclaimSwap executed → S5.status = RECLAIMED
  Asset returned to creator

Subsequent chain changes:
  Any reorg (any depth) after RECLAIMED transition

Expected:
  S5.status: RECLAIMED (terminal — no change under any reorg)
  Rationale: RECLAIMED is time-based; first-valid-state-transition wins
  Even if tx_delta reappears on a subsequent best chain, RECLAIMED stands
```

### B.8.6 — FINALIZED swap, deep reorg (divergence condition)

```
Initial state:
  S6: status = FINALIZED, claimBlockHeight = 500000
  current best height = 500012 (depth = 12 at finalization)

Reorg event:
  Deep reorg of depth 15 (new chain diverges at height 499997)
  tx_epsilon not present in new best chain

Expected (Case E — hard boundary):
  S6.status:   FINALIZED  (permanent — no rollback)
  btcTxUsage:  entry persists
  Asset:       irreversible

Divergence condition activated:
  FINALIZED state now permanently contradicts Bitcoin chain truth
  Zenon-side state remains canonical
  No reconciliation mechanism exists or is defined
  System continues operating normally
  PTLC scalar already revealed — cannot be revoked
```

## B.9 Structural Selector Test Vectors (Section 5.13)

### B.9.1 — Selector mode DISABLED: ClaimSwap unaffected

```
selectorMode:   DISABLED
ClaimSwap:      executes normally per Section 8.4
Steps S1–S6:    not executed
Expected:       selector section ignored entirely; no additional rejection codes possible
```

### B.9.2 — Selector mode ENABLED, blockHeight = 0: SELECTOR_HEIGHT_INVALID

```
selectorMode:   DELAYED_HEADER_SELECTOR_V1
blockHeight:    0
Step S1:        blockHeight < 1 → true
Expected:       reject SELECTOR_HEIGHT_INVALID
Steps S2–S6:    not reached
```

### B.9.3 — Selector determinism: identical inputs produce identical output

```
selectorMode:       DELAYED_HEADER_SELECTOR_V1
swapId:             deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
creationBlockHash:  0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
blockHeight:        700001
H0:                 bestChainHeaderHashAt(700001)  =  <deterministic from test chain>
H1:                 bestChainHeaderHashAt(700000)  =  <deterministic from test chain>

SELECTOR_DOMAIN:    5a454e4f4e5f4254435f53454c4543544f525f5631

selectorSeed = SHA256d(
    5a454e4f4e5f4254435f53454c4543544f525f5631
    || deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
    || 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20
)

structuralSelector = SHA256d(selectorSeed || H0 || H1)

Expected: any two conforming implementations given identical inputs produce
          identical structuralSelector output (SHA256d is fully deterministic).
          No platform-specific encoding variance is permitted.
```

### B.9.4 — Selector does not gate admission

```
selectorMode:   DELAYED_HEADER_SELECTOR_V1
blockHeight:    700001   (valid, H0 and H1 retrievable)
All preconditions: satisfied
Mode 2 binding: satisfied (if Mode 2 enabled)

Step S5: structuralSelector emitted as non-consensus trace event
Step S6: execution continues to atomic effects unconditionally

Expected: ClaimSwap succeeds regardless of structuralSelector value.
          structuralSelector[0] is NOT checked.
          No SELECTOR_CONSTRAINT_FAILED rejection code exists.
```

### B.9.5 — Selector recomputes after Case D reversal and re-claim on different chain

```
Phase 1 — Initial claim on Chain A:
  blockHeight = 700001
  H0_A = bestChainHeaderHashAt(700001) on Chain A
  H1_A = bestChainHeaderHashAt(700000) on Chain A
  structuralSelector_A = SHA256d(SHA256d(SELECTOR_DOMAIN || swapId || creationBlockHash) || H0_A || H1_A)
  Swap S1: PROVISIONALLY_CLAIMED

Phase 2 — Reorg to Chain B:
  Chain B orphans block 700001; swap S1 returns to ACTIVE (Case D)
  structuralSelector_A: no cleanup required (ephemeral; was never stored)

Phase 3 — Re-claim on Chain B:
  blockHeight = 700001 (same btcTxid block, different chain)
  H0_B = bestChainHeaderHashAt(700001) on Chain B  ← may differ from H0_A
  H1_B = bestChainHeaderHashAt(700000) on Chain B  ← may differ from H1_A
  structuralSelector_B = SHA256d(SHA256d(SELECTOR_DOMAIN || swapId || creationBlockHash) || H0_B || H1_B)

Expected: structuralSelector_B may differ from structuralSelector_A.
          This is correct behavior — the selector reflects current chain state.
          No reconciliation with prior selector value is required or possible.
          ClaimSwap proceeds normally if all other preconditions are satisfied.
```

### B.9.6 — Selector independence from txIndex and proof layout

```
selectorMode:   DELAYED_HEADER_SELECTOR_V1
swapId:         (fixed)
creationBlockHash: (fixed)
H0, H1:         (fixed, from best-chain)

Attempt 1: ClaimSwap with txIndex = 0, merkleProof = [node_A, node_B]
  structuralSelector: SHA256d(selectorSeed || H0 || H1)

Attempt 2: ClaimSwap with txIndex = 2, merkleProof = [node_C, node_D]
  structuralSelector: SHA256d(selectorSeed || H0 || H1)

Expected: structuralSelector is identical in both cases.
          txIndex and merkleProof do not appear in selector inputs.
          Transaction layout mutation cannot alter the selector value.
```

---

# Appendix C: Timestamp Policy Security Analysis

## C.1 MTP-Only Validation Is Consensus-Correct

Bitcoin's timestamp validation comprises two rules operating at different layers of the protocol stack:

**Rule 1 — Median Time Past (MTP):** A header is invalid if its timestamp does not exceed the median of the preceding 11 blocks' timestamps. This rule is enforced by all Bitcoin nodes and is part of Bitcoin's consensus definition. A chain that violates MTP cannot achieve consensus on any honest Bitcoin network.

**Rule 2 — Future-bound policy rule:** Bitcoin Core additionally rejects headers with `timestamp > (networkAdjustedTime + 7200)`. This rule is explicitly classified as a *relay policy*, not a consensus rule, in Bitcoin Core's source (`src/validation.cpp`: `CheckBlockHeader` vs `ContextualCheckBlockHeader`). It is not enforced uniformly — different node implementations apply different clock sources, different peer-adjustment algorithms, and different tolerances. A block that violates the future-bound policy may still be mined and included in the canonical chain once sufficient time has passed; no Bitcoin-valid chain has ever been invalidated retroactively because a header had a future timestamp at the time of relay.

**This verifier enforces Rule 1 only.** This is the correct choice for an SPV verifier because:

1. MTP is computed entirely from chain data — no clock dependency, fully deterministic across all nodes
2. The future-bound rule requires a trusted clock source, introducing the only external dependency the spec explicitly prohibits
3. Any chain passing MTP that fails the future-bound rule on a given node will pass that rule on any node evaluated two hours later — the rule is ephemeral, not permanent
4. SPV verifiers operating on submitted headers (rather than live peer connections) have no basis for evaluating "network time" — the submission may occur hours or days after the header was mined

## C.2 Policy Divergence — Quantified Bounds

The divergence between this verifier and Bitcoin Core under the future-bound rule is bounded and characterizable:

**Scenario:** A miner produces a header with `timestamp = currentNetworkTime + T` where `T > 7200`. The header satisfies PoW and MTP.

- **This verifier:** Accepts the header immediately upon submission
- **Bitcoin Core:** Rejects the header until `networkTime >= timestamp - 7200`

**Maximum temporary divergence:** A header with the maximum exploitable future timestamp satisfies MTP, which means its timestamp cannot be arbitrarily large. Specifically, MTP requires `timestamp > median(last 11 blocks)`. The maximum forward bias achievable within MTP rules over sustained mining is bounded by the rate at which the MTP window advances — approximately 10 minutes per block. Over a 2016-block retarget window, the maximum accumulated forward bias is bounded by the 4x clamp on the retarget computation (a chain cannot sustain forward bias indefinitely without the MTP window catching up). In practice, observed Bitcoin timestamp bias is under 10 minutes per block.

**Maximum observable divergence window:** A header this verifier accepts that Bitcoin Core temporarily rejects will be accepted by Bitcoin Core within `timestamp - (networkTime + 7200)` seconds — at most a few hours for any plausible mining operation. After that window, both verifiers agree.

**Implication:** The divergence is temporary and self-correcting. It does not affect chain selection finality for any confirmed transaction — a transaction confirmed to depth 6+ on this verifier's best chain will be on Bitcoin Core's best chain as well, because the temporary policy divergence resolves before the SPV confirmation window closes.

**Permanent divergence cases:** None. A chain that is permanently better on this verifier but permanently rejected by Bitcoin Core cannot exist, because the future-bound policy rule always resolves as time passes. The divergence is bounded above by the temporal gap between header timestamp and actual network time.

## C.3 MTP Security Guarantees

MTP enforces a monotonically non-decreasing effective time across the chain. Specifically, for any block B at height H:

```
MTP(B) = median(timestamps of blocks H-11 through H-1)
timestamp(B) > MTP(B)
```

This guarantees:
- **Replay prevention:** A transaction with a time-lock based on MTP cannot be replayed against a chain where MTP is lower, because MTP only increases
- **Ordering consistency:** Block timestamps are weakly monotone with respect to MTP, providing a deterministic time ordering for all time-based state transitions
- **No clock trust:** MTP is computed from the header chain itself. No node need trust any external time source to validate this rule

For this protocol's time-based transitions (ReclaimSwap, Loan Default), `currentTime` is defined as the Zenon block timestamp — not MTP, not network time. The MTP discussion is relevant to Bitcoin header validation only. Zenon-side time-based rules are subject to the block producer timestamp variance described in Section 8.3 and Section 17.7, which is a separate and independently bounded risk surface.

# End
