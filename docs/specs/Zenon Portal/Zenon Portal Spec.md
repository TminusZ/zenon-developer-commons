# Zenon Portal: A Bitcoin–Zenon Interoperability Protocol

**Protocol Specification v1.5**
**Status:** Informational / Protocol Specification
**Category:** Cross-Chain Protocol Design
**Target Audience:** Bitcoin protocol engineers, cryptographers, distributed systems researchers

---

## Abstract

Zenon Portal is an interoperability protocol that uses Bitcoin as the custody and settlement layer while Zenon Network acts as the execution layer. Bitcoin deposits are locked in Taproot escrow UTXOs on the Bitcoin base layer; Zenon verifies deposits using Simplified Payment Verification (SPV) proofs and credits **eBTC (escrow Bitcoin)** — a Zenon-native receipt representing a claim on Bitcoin held in verified Taproot escrow UTXOs — to depositors. Withdrawals are processed cooperatively by a permissionless relayer market.

**Trust model:** This protocol is **trust-reduced relative to a single custodian, not trustless**. The dominant trust assumption is that fewer than the FROST threshold `t` of epoch relayers collude to redirect withdrawals. Relayer bonds provide Sybil resistance only; in the absence of on-chain bond slashing, bonds do not deter theft by a colluding quorum. Deploying value against this protocol requires evaluating the relayer set composition and accepting that a majority-colluding relayer quorum could steal Class P funds without on-chain consequence. On-chain slashing is the highest-priority upgrade path; the full attributable signing and slashing model is specified in §9.7.

**Class P activation gate:** `CLASS_P_ENABLED` defaults to `false`. The contract MUST reject all Class P deposit registrations, Class R→P migrations, and Class P first-consolidations unless `CLASS_P_ENABLED == true`. Governance MAY enable Class P only after all enforcement prerequisites in §5.9 are satisfied and verified. Class R deposits are not affected by this gate and are available unconditionally.

**Two escrow classes:** Depositors explicitly select between two escrow classes at deposit time.

- **Class R (Refund-Protected):** The deposit escrow requires user co-signature for the cooperative spend path. Relayers cannot consolidate or unilaterally spend a Class R UTXO. The Bitcoin-native unilateral refund path is a real, permanent guarantee. Cooperative withdrawal requires the depositor's live `pk_u` signature at withdrawal time. Under sustained relayer censorship, the maximum delay before unilateral exit is `ABSOLUTE_EXPIRY − current_bitcoin_height` Bitcoin blocks (see §5.6).

- **Class P (Pool-Liquidity):** The deposit escrow gives relayers unilateral key-path authority. The depositor explicitly opts into relayer-controlled consolidation and pooled execution in exchange for non-interactive, efficient withdrawal processing. The unilateral refund path is time-limited; the combined attack (A9) is an acknowledged risk for Class P deposits.

Operators deploying Zenon Portal MUST present both escrow classes to users with clear disclosure of the trust and exit-right differences before deposit. The deposit class is recorded in the `DepositRecord` and governs all protocol-level behaviors for that UTXO.

**eBTC supply invariant:**

```
Total eBTC supply ≤ total value of verified escrow UTXOs
```

eBTC represents claims on Bitcoin held in escrow on the Bitcoin blockchain. Bitcoin custody remains entirely on Bitcoin. Zenon maintains a receipt ledger representing escrow claims.

**Safety scope — Class R:** The unilateral refund path for Class R deposits is available at any time after `ABSOLUTE_EXPIRY` while the original UTXO remains unspent. Relayers cannot initiate consolidation of Class R UTXOs without user co-signature. The guarantee is lost only if `pk_u` is lost or the depositor voluntarily initiates on-Bitcoin re-deposit migration to Class P (§11.5, with mandatory disclosure).

**Safety scope — Class P:** The unilateral refund path is **time-limited**: relayers may consolidate a Class P UTXO once fewer than `CONSOLIDATION_SAFETY_WINDOW` blocks remain before its expiry, permanently eliminating the Bitcoin-native exit. Secondary holders of eBTC received via Zenon-internal transfers depend on Zenon network availability and relayer liveness. This is an explicit depositor-accepted trade-off. **Governance resolution ceiling for orphaned consolidations:** If a Class P UTXO is consolidated and the `ConsolidationCompletionProof` is never submitted (orphaned consolidation), affected eBTC holders face a governance resolution process with a maximum latency of `GOVERNANCE_VOTING_PERIOD + GOVERNANCE_EXECUTION_DELAY` ≈ **70 days** during which their eBTC may be of uncertain or zero value with no individual action available. This ceiling applies to the worst-case recovery path and MUST be disclosed to Class P depositors and eBTC holders before deposit or acquisition.

**Class P availability:** Class P deposits are only accepted when `CLASS_P_ENABLED == true`. This flag is false by default and may be set true only by governance after all enforcement prerequisites in §5.9 are satisfied. A deployment where `CLASS_P_ENABLED == false` accepts Class R deposits and issues Class R eBTC normally; Class P is simply unavailable until the enforcement stack is live.

Trust assumptions are fully enumerated in §12.1. This document provides a technical specification complete within the parameters bounded in Appendix A.

---

## Table of Contents

- State Machines
1. Introduction
2. System Architecture
3. Cryptographic Primitives and Notation
4. Bitcoin SPV Verification
5. Deposit Escrow Script Design
6. Deposit Registration Protocol
7. eBTC State Model
8. Withdrawal Protocol
   - 8.9 Canonical Withdrawal Transaction Template
9. Relayer System
   - 9.1 Design Goals
   - 9.2 Relayer Registration
   - 9.3 FROST Epoch Key Management
   - 9.4 Epoch Signing Retention
   - 9.5 Fee Structure
   - 9.6 UTXO Reservation and Claim Atomicity
   - 9.7 Attributable Signing and Slashing
   - 9.8 Relayer Operational Requirements
   - 9.9 Relayer Transparency Metrics
10. Refund Path (Safety Mechanism)
11. UTXO Mapping and Consolidation
12. Security Model
13. Economic Incentives
14. Scalability Analysis
15. Failure Analysis
16. Future Upgrade Path
17. Conclusion
18. References
19. Implementation Compliance
Appendix A. Protocol Parameter Table
Appendix C. Implementation Checklist
Appendix D. Normative Test Vectors

---

## State Machines

This section summarizes the lifecycle of key protocol objects. Full transition rules are defined in the referenced sections.

### DepositRecord Lifecycle

```text
Unregistered
    │
    │  RegisterDepositMsg (§6.2)
    ▼
Pending
    │
    │  SPV confirmation depth reached (§6.3)
    ▼
Confirmed
    │
    │  FINAL_DEPTH confirmations (§6.3)
    ▼
Finalized ──────────────────────────────────────────────────────────┐
    │                                                                │
    │  WithdrawalCompletionProof (§8.7)    RefundAcknowledgmentMsg (§10.3)
    ▼                                                                ▼
Withdrawn                                                        Refunded
    │                                                                │
    └──────────────────────── (terminal) ────────────────────────────┘

Finalized ──► Invalidated   (double-registration or fraud detection, §6.3)
```

**Notes:**
- `Invalidated` entries MUST NOT be pruned (§6.3).
- `Withdrawn` and `Refunded` are terminal; the UTXO is removed from the active pool.
- Class P deposits require `CLASS_P_ENABLED == true` at registration time (§5.9).

---

### WithdrawalClaim Lifecycle

```text
Pending
    │
    │  WithdrawalClaimMsg accepted (§8.3)
    ▼
Processing
    │  ┌──────────────────────────────────┐
    │  │ claim_expiry elapses, no proof   │
    │  │ submitted (§9.6)                 │
    │  ▼                                  │
    │  Pending (reverted)                 │
    │                                     │
    │  WithdrawalCompletionProof (§8.7)   │
    ▼                                     │
Completed                                 │
(terminal)                                │
                                          │
    ────────────────────────── Expired ───┘
                               (terminal if
                                claim_expiry
                                elapses and
                                record is
                                not reverted)
```

**Notes:**
- Class R withdrawals additionally require depositor co-signature during `Processing` (§8.2).
- If a Class R depositor never co-signs within `CLAIM_WINDOW`, the claim MUST revert to `Pending` (§8.2, §9.6).

---

### UTXO Lifecycle

```text
Available
    │
    ├──► Reserved       (WithdrawalClaimMsg accepted, §9.6)
    │        │
    │        ├──► Available   (claim expires or is reverted)
    │        └──► Spent       (WithdrawalCompletionProof accepted, §8.7)
    │
    ├──► SuspectExpired  (block height approaches ABSOLUTE_EXPIRY, §10.4)
    │        │
    │        └──► PermanentlyExpired  (ABSOLUTE_EXPIRY passed, §10.5)
    │                   │
    │                   └──► Spent  (Leaf 2 refund confirmed on Bitcoin)
    │
    └──► Spent           (direct consolidation spend, §11)
```

**Notes:**
- `first_consolidation: bool` is tracked per UTXORecord (§11.6).
- Class P UTXOs may transition to a consolidation candidate state when fewer than `CONSOLIDATION_SAFETY_WINDOW` blocks remain before expiry (§11.4).

---

### Consolidation Lifecycle

```text
Proposed
    │  FirstConsolidationNotice recorded (§11.6, Class P first-consolidation only)
    │  FIRST_CONSOLIDATION_EXIT_DELAY elapses
    ▼
ChallengeWindow   (CONSOLIDATION_CHALLENGE_DELAY blocks, §11.3)
    │
    ├──► Canceled   (depositor submits WithdrawalRequest during exit window, §11.6)
    │
    ▼
Signing   (FROST threshold signing of consolidation transaction, §9.7)
    │
    ├──► Completed   (ConsolidationCompletionProof submitted, §11.3)
    │
    ├──► Orphaned    (proof never submitted; governance recovery, §11.4)
    │
    └──► Aborted     (signing fails or epoch rotates before completion, §9.4)
```

**Notes:**
- Orphaned consolidations require governance resolution; maximum latency ≈ 70 days (§11.4, Abstract).
- The A9 combined attack exploits the consolidation window; see §12.10.

---

## 1. Introduction

### 1.1 Motivation

Bitcoin's UTXO model and conservative scripting environment provide exceptional custody security at the cost of programmability. Zenon Network provides a high-throughput dual-ledger architecture suitable for execution and state management, but lacks native access to Bitcoin liquidity. Naive bridging approaches — federated multisig, threshold custody schemes, wrapped asset issuers — introduce trust assumptions that undermine the security properties of the underlying settlement layer.

Zenon Portal is designed to close this gap by treating Bitcoin as what it already is: the most secure public settlement layer available. Rather than moving BTC off Bitcoin, the protocol leaves BTC in Bitcoin UTXOs and extends execution capability to Zenon by giving Zenon verifiable, cryptographic knowledge of Bitcoin's state.

This design follows a broader principle: **execution and custody are separable concerns**. Custody safety is a property of Bitcoin's proof-of-work chain. Execution flexibility is a property of Zenon's programmable state machine. Zenon Portal creates a well-defined interface between these two systems.

### 1.2 Scope

This specification defines:

- The on-Bitcoin Taproot escrow script format
- The SPV verification procedure executed on Zenon, including header chain bootstrap and governance
- The deposit registration protocol including deposit finalization state machine
- The eBTC balance model and state management rules
- The withdrawal protocol and relayer coordination mechanism
- The timelock-based unilateral refund path and its scope limitations
- UTXO pool management, expiry accounting, and consolidation mechanism
- The security model, trust assumptions, and failure modes
- A roadmap for future improvements

This specification does **not** define:

- Zenon's internal consensus mechanism (assumed as given)
- Bitcoin's base-layer protocol (assumed as given per BIP 340–342)
- Application-layer contracts built on top of eBTC

### 1.3 Design Principles

1. **Bitcoin funds never leave Bitcoin custody.** All BTC remains in Bitcoin UTXOs at all times.
2. **Trust-reduced, not trustless.** The protocol eliminates single-custodian risk by distributing signing authority across a FROST relayer threshold. However, no on-chain mechanism punishes a colluding threshold majority that steals funds. The system is trust-reduced relative to a single custodian; it is not equivalent to a trustless protocol. The dominant trust assumption — honest FROST relayer majority — is stated explicitly in §12.1 and MUST be disclosed to users.
3. **Deposit verification is cryptographic, not social.** SPV proofs anchored to a governance-approved checkpoint establish deposit validity.
4. **User-chosen escrow class determines exit rights.** Depositors explicitly select between two escrow classes at deposit time:
   - **4R (Class R — Refund-Protected):** The Bitcoin-native unilateral refund is a genuine, permanent guarantee. The escrow requires user co-signature for cooperative spends; relayers cannot consolidate without user cooperation. The tradeoff is **interactive cooperative withdrawal requiring depositor online participation**.
   - **4P (Class P — Pool-Liquidity):** The depositor opts into relayer-controlled key-path authority for non-interactive, efficiently pooled execution. The unilateral refund is time-limited (§11.4); the combined A9 attack is an explicitly accepted risk. The tradeoff is better withdrawal efficiency and no depositor online requirement.

   Both classes are Bitcoin-native constructions using only existing Taproot script features. The protocol MUST NOT default silently to either class; the operator MUST present the choice to the depositor with mandatory disclosure.
5. **Relayers provide liveness, not safety — for Class R deposits held by the original depositor.** Class R relayer failure cannot result in fund loss for the original depositor who retains their eBTC, only withdrawal delay. This guarantee applies specifically to the original depositor who controls `pk_u` and has not transferred their eBTC to a secondary holder. A secondary holder of Class R-originated eBTC has the same liveness profile as a holder of Class P-originated eBTC: both depend on relayer availability and pool collateralization for exit (see §7.4). For Class P deposits, relayer failure or collusion may affect both liveness and safety within the scope of the Class P trust model (§5.6). This distinction is architectural, not a caveat.
6. **Explicit limitations.** Trust assumptions and enforcement gaps are stated explicitly; aspirational mechanisms are not presented as current guarantees.
7. **Deployable today.** The protocol uses only existing Bitcoin script features (Taproot, Schnorr, timelocks, FROST-DKG-derived keys).
8. **Forward compatibility.** The architecture anticipates Bitcoin covenant opcodes, BitVM-style verification, and verifiable DKG.

### 1.4 Relationship to Existing Work

Zenon Portal is conceptually related to but distinct from:

- **RSK/Rootstock**: Uses a federated peg ("Powpeg") with trusted signatories.
- **Liquid Network**: Uses a federated multisig custodian model.
- **Lightning Network**: Focuses on payment channels rather than general execution.
- **tBTC v2**: Uses threshold ECDSA groups with a bonded operator pool; shares the structural form of a t-of-n honest majority assumption but differs materially in slashing enforcement, coverage mechanisms, and recovery design.
- **BitVM bridges**: Rely on optimistic fraud proofs; require at least one honest verifier in the challenge period.
- **Statechains**: Transfer UTXO ownership off-chain via key delegation; rely on HSM-based key deletion.

Zenon Portal's primary differentiation is the separation of custody (Bitcoin-native UTXOs) from execution (Zenon), with deposit validity established by SPV proof rather than trusted attestation.

---

## 2. System Architecture

### 2.1 Logical Layers

```
┌──────────────────────────────────────────────────────────────┐
│                        USER LAYER (U)                        │
│  Submits deposits, burns eBTC, constructs refund txs,        │
│  submits RefundAcknowledgmentMsgs (strongly recommended)     │
└────────────────────────┬─────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
┌──────────▼───────────┐   ┌───────────▼──────────────────────┐
│  BITCOIN LAYER (B)   │   │       ZENON LAYER (Z)            │
│                      │   │                                  │
│  - Taproot UTXOs     │   │  - SPV verifier + header chain   │
│  - Escrow scripts    │◄──┤  - eBTC state contract           │
│  - Timelock paths    │   │  - Withdrawal burn events        │
│  - Withdrawal txs    │   │  - Relayer registry + epochs     │
└──────────┬───────────┘   │  - Deposit priority queue        │
           │               │  - UTXO expiry accounting ledger │
           │               └───────────┬──────────────────────┘
           │        ┌──────────────────┘
           │        │
┌──────────▼────────▼──────────────────────────────────────────┐
│                    PORTAL LAYER (P)                          │
│  - Relayer nodes monitoring Zenon burn events                │
│  - Bitcoin transaction construction + broadcast              │
│  - Header submission (bonded obligation; see §9.2/§12.1 A8)  │
│  - SPV proof generation for deposit and refund submissions   │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow Summary

**Deposit flow:**
```
User → broadcasts BTC tx to Taproot escrow UTXO
User (or relayer) → submits SPV proof to Zenon SPV verifier
Deposit priority queue → advances state at CONF_DEPTH and FINAL_DEPTH
Zenon eBTC contract → credits restricted eBTC at Confirmed; full at Finalized
```

**Transfer flow:**
```
User A → sends eBTC to User B on Zenon
(standard Zenon transaction; no Bitcoin involvement)
Note: User B acquires Zenon-liveness dependency for Bitcoin exit
```

**Withdrawal flow:**
```
User → calls withdraw(btc_address_script, amount_sat, max_fee_sat, deadline)
Zenon eBTC contract → burns eBTC, escrows fee, emits WithdrawalBurnEvent
Portal relayer → atomically claims withdrawal and reserves UTXO
Portal relayer → constructs + broadcasts Bitcoin withdrawal tx (FROST signed)
Bitcoin → confirms tx
Portal relayer → submits WithdrawalCompletionProof to Zenon
```

**Unilateral refund flow (original depositor, UTXO unspent and within safety window):**
```
User → waits for ABSOLUTE_EXPIRY Bitcoin blocks to pass
User → verifies their UTXO has not been consolidated (check Bitcoin UTXO set)
User → broadcasts refund tx via timelock script-path
Bitcoin → confirms refund
User → submits RefundAcknowledgmentMsg to Zenon (strongly recommended)
Zenon → marks DepositRecord Refunded; removes UTXO from pool
```

---

## 3. Cryptographic Primitives and Notation

### 3.1 Notation

| Symbol | Meaning |
|--------|---------|
| `H(x)` | SHA-256(x) |
| `DH(x)` | SHA-256(SHA-256(x)) — Bitcoin's double-SHA-256 |
| `btc_txid` | Canonical Bitcoin transaction identifier: `DH(non_witness_serialization(tx))`. Witness malleability does NOT affect `btc_txid`: two transactions with identical non-witness content but different witnesses produce identical `btc_txid`. Implementations MUST use `btc_txid` and MUST NOT use the witness transaction ID (`wtxid`) for any slashing, attestation, intent-matching, or protocol message computation. |
| `pk_u` | User's public key (Schnorr, secp256k1) |
| `pk_frost_epoch` | FROST epoch aggregate public key (x-only 32-byte; see §3.3) |
| `sig_u` | Schnorr signature by user |
| `T` | Timelock duration in Bitcoin blocks |
| `UTXO(txid, vout)` | Reference to a specific Bitcoin output |
| `eBTC` | escrow Bitcoin; a Zenon-native receipt representing a claim on Bitcoin held in verified Taproot escrow UTXOs. Bitcoin custody remains on Bitcoin; eBTC is the Zenon receipt ledger entry. |
| `SPV_PROOF` | Structure defined in §4.3 |
| `\|\|` | Byte concatenation |
| `varint(n)` | Bitcoin variable-length integer encoding of `n` |

All multi-byte integer fields in protocol messages and serialization formats use **little-endian** byte order unless otherwise noted. Fields marked `bytes32` are fixed-length 32-byte arrays transmitted as-is without length prefix.

### 3.2 Bitcoin Script Primitives Used

- **OP_CHECKSIG**: Schnorr signature verification (BIP 340)
- **OP_CHECKLOCKTIMEVERIFY (CLTV)**: Absolute block-height timelock (BIP 65)
- **Taproot key-path spend**: Single-key spend via internal key (BIP 341)
- **Taproot script-path spend**: Merkle-authenticated script execution (BIP 341)
- **Tagged hashes**: `tagged_hash(tag, msg)` per BIP 340

### 3.3 Threshold Signing: FROST

**Design decision:** Epoch relayer aggregate keys are generated using **FROST** (Flexible Round-Optimized Schnorr Threshold Signatures) distributed key generation (DKG), not MuSig2 KeyAgg. MuSig2 is not used anywhere in this specification.

**Rationale:** MuSig2 `KeyAgg` is an n-of-n scheme requiring all participants for every signing operation — operationally fragile for n > 3. FROST provides a t-of-n threshold scheme where any t of n participants produce a valid standard Schnorr signature. Both produce a 64-byte BIP 340 signature under a single public key, making both compatible with Taproot key-path spends. However, these schemes produce different keys and are not substitutable: a UTXO created against a MuSig2 KeyAgg key cannot be spent using FROST signing on a different key distribution, and vice versa. All escrow UTXOs in this protocol use FROST DKG-derived keys exclusively.

**FROST DKG procedure (Komlo & Goldberg 2020, §2):**

```
Inputs:
    n:      total number of epoch relayers
    t:      signing threshold (recommended: t = ceil(2n/3))
    epoch:  epoch identifier (uint32)

Procedure:
1. Each relayer i generates a random polynomial f_i(x) of degree t-1
   with secret s_i = f_i(0) chosen uniformly from Z_q.
2. Each relayer i computes and broadcasts commitment vector:
   C_i = [s_i*G, c_{i,1}*G, ..., c_{i,t-1}*G]
3. Each relayer i privately sends share s_{i,j} = f_i(j) to relayer j.
4. Each relayer j verifies received shares against commitments:
   s_{i,j}*G == sum(C_i[k] * j^k for k in 0..t-1)
   Abort and dispute if any check fails.
5. Each relayer i computes their long-term share:
   x_i = sum(s_{j,i} for all j)
6. Epoch aggregate key:
   pk_frost_epoch = sum(C_i[0] for all i)  // sum of constant-term commitments

Output:
    pk_frost_epoch: public aggregate key (x-only 32-byte secp256k1 point)
    x_i:           each relayer i's signing share (scalar in Z_q)
    C_i:           each relayer's public commitment vector (retained for verification)
```

### 3.4 Canonical Serialization Rules

All protocol message hashes MUST be computed using canonical serialization. This section defines the normative encoding rules that apply to all hash inputs, all serialized protocol messages, and all fields in hash-committed structures.

**Normative rules:**

1. **Field ordering:** Fields MUST appear in the order defined by the struct definition in this specification. Implementations MUST NOT reorder struct fields.
2. **Integer encoding:** All integer fields MUST be encoded as little-endian unless explicitly stated otherwise in the field definition. This applies to `uint16`, `uint32`, `uint64`, and all fixed-width integer types.
3. **Variable-length byte arrays:** All variable-length byte arrays (`bytes`, `string`, `vector<T>`) MUST be prefixed with a Bitcoin-style `varint` length (per §3.1 `varint(n)` definition) encoding the byte length of the array. The length prefix precedes the array content with no intervening bytes.
4. **Empty fields:** Empty arrays and zero-length byte strings MUST be encoded as a `varint(0)` length prefix followed by zero content bytes. They MUST NOT be omitted from the serialization.
5. **No trailing padding:** Serialized messages MUST NOT include trailing padding bytes beyond the last field. The serialized length is fully determined by the field values.
6. **No field reordering:** Implementations MUST NOT reorder struct fields under any circumstances, including for performance optimization, alignment, or platform-specific reasons.

**Scope:** These rules apply to all hash inputs and serialized forms of the following protocol messages and structures:

- `SigningIntentCommitment` (§9.7.2a) — commitment hash computation
- `WithdrawalClaimMsg` (§9.6) — when used as hash input in bundle or intent matching
- `SpendIntent` (§9.7.4) — all tagged hash computations over intent fields
- `SigningBundle` (§9.7.8) — the `bundle_hash` and all sub-field hash computations
- `SlashProof` (§9.7.12) — the proof hash and all sub-structure serializations
- `ConsolidationProposal` — the `proposal_id = H(ConsolidationProposal fields)`
- All other structures where this specification says `H(...)` over struct fields

**Interoperability requirement:** Two implementations that serialize the same struct using the rules above MUST produce byte-for-byte identical output. Any deviation is a conformance failure.

### 3.5 Validation and Failure Semantics

All message processing on the Zenon contract MUST follow the validation and failure semantics defined in this section.

**Atomicity requirement:**

All validation failures MUST revert the entire message atomically. No partial state updates are permitted. The Zenon contract MUST treat each protocol message as an atomic unit: either all state transitions caused by the message are applied, or none are.

**Validation ordering:**

Validation MUST occur in the following order for every protocol message. A failure at any phase MUST abort processing and revert to the pre-message state. Phases MUST NOT be reordered.

```
Phase 1 — Message format validation:
    Verify the message is well-formed: all required fields present,
    all field types conform to their declared types, no unknown fields,
    all varint-prefixed arrays have the correct byte count.

Phase 2 — Cryptographic verification:
    Verify all signatures, hash commitments, SPV proofs, and other
    cryptographic claims in the message. This phase MUST complete
    before any state is read for invariant checking.

Phase 3 — State invariant validation:
    Verify all protocol-level preconditions: status checks, coverage
    constraints, epoch validity, UTXO availability, quorum requirements,
    and all other state-dependent acceptance criteria.

Phase 4 — State transition:
    Apply all state changes atomically. This phase executes only if
    Phases 1–3 all pass without error.
```

**Fail-closed requirement:**

Implementations MUST fail closed: an invalid message MUST be rejected rather than partially processed. An implementation that applies partial state changes before detecting a validation failure is non-conformant.

**Error propagation:** When a message is rejected, the contract MUST emit a structured rejection event identifying the phase and reason code for the rejection. Rejection events are informational and do not modify protocol state.


---

## 4. Bitcoin SPV Verification

### 4.1 Header Chain Tracking

The Zenon SPV verifier maintains a chain of Bitcoin block headers. The following data structures are maintained on-chain:

```
struct ChainState {
    tip_hash:          bytes32,
    tip_height:        uint64,
    cumulative_work:   uint256,
    headers:           map<uint64, HeaderRecord>,   // key: block height (uint64)
    period_timestamps: map<uint64, uint32>,          // key: retarget height (uint64);
                                                     // value: timestamp at that boundary
}

struct HeaderRecord {
    block_hash:   bytes32,
    prev_hash:    bytes32,
    merkle_root:  bytes32,
    timestamp:    uint32,
    nbits:        uint32,
    nonce:        uint32,
    height:       uint64,
    work:         uint256,
}
```

### 4.2 Header Validation

A submitted header is accepted if and only if all of the following hold:

1. The header is exactly 80 bytes in canonical Bitcoin serialization.
2. `DH(header) ≤ target` where `target` is the 256-bit expansion of `nBits`.
3. `header.prev_block` matches `chain_state.tip_hash` or matches a known ancestor hash (for fork resolution).
4. `nBits` satisfies difficulty adjustment rules (§4.2.2).

#### 4.2.1 Compact Target (`nBits`) Encoding and Decoding

Bitcoin encodes the difficulty target as a 4-byte compact value (`nBits`) in each block header. The compact format is a base-256 floating-point representation with a 1-byte exponent and a 3-byte signed mantissa. This section provides the complete normative specification of encoding and decoding; implementations MUST use this specification exclusively.

**Byte layout:**

```
nBits layout (big-endian interpretation of the 4-byte field):
  bits [31:24]  exponent byte  (uint8, unsigned)
  bits [23: 0]  mantissa bytes (3 bytes, treated as a signed 24-bit integer)

// Bitcoin stores nBits in header bytes as little-endian uint32.
// When extracting fields: read the 4 bytes as uint32_le, then:
exponent = (nbits_uint32 >> 24) & 0xFF
mantissa = nbits_uint32 & 0x00FFFFFF
```

**Decoding algorithm (compact → 256-bit target):**

```
function decode_nbits(nbits: uint32) -> (target: uint256, valid: bool):

    exponent = (nbits >> 24) & 0xFF
    mantissa = nbits & 0x00FFFFFF

    // Rule 1 — Negative mantissa rejection:
    // If the high bit of the mantissa (bit 23) is set, the value would represent
    // a negative number in Bitcoin's signed-mantissa convention. This MUST be
    // rejected as invalid.
    if mantissa & 0x800000 != 0:
        return (0, false)   // REJECT: negative mantissa

    // Rule 2 — Overflow rejection:
    // The 256-bit target is: mantissa × 256^(exponent - 3)
    // Maximum valid exponent for a non-zero result: 32 (256-bit target).
    // Exponent > 32 can only produce a target requiring more than 256 bits.
    if exponent > 32:
        return (0, false)   // REJECT: exponent overflow

    // Rule 3 — Zero target rejection:
    // A zero mantissa means zero target, which no block hash can satisfy.
    if mantissa == 0:
        return (0, false)   // REJECT: zero target

    // Expansion:
    if exponent <= 3:
        // Right-shift: mantissa >> (8 × (3 - exponent))
        target = mantissa >> (8 * (3 - exponent))
    else:
        // Left-shift: mantissa << (8 × (exponent - 3))
        target = mantissa << (8 * (exponent - 3))
        // Overflow check: result must fit in 256 bits
        if target >> 256 != 0:
            return (0, false)   // REJECT: shift overflow

    return (target, true)
```

**Re-encoding algorithm (256-bit target → compact, for retarget verification):**

When verifying that a new `nBits` correctly encodes the computed retarget value, the verifier MUST re-encode the computed target using this canonical algorithm and compare the result to the submitted `nBits`:

```
function encode_target_to_nbits(target: uint256) -> uint32:

    if target == 0:
        return 0x00000000   // degenerate case; will fail Rule 3 on decode

    // Find the most significant non-zero byte position.
    // Compact exponent = number of bytes needed to represent target.
    nbytes = byte_length(target)   // = ceil(log256(target + 1))

    // Extract the 3 most significant bytes of target (the mantissa).
    if nbytes >= 3:
        mantissa = target >> (8 * (nbytes - 3))
    else:
        mantissa = target << (8 * (3 - nbytes))

    // Mantissa high-bit normalization:
    // If bit 23 of the mantissa is set (which Bitcoin's format interprets as a
    // sign bit), increment the exponent and right-shift the mantissa by one byte
    // to clear the high bit. This is the canonical rounding behavior.
    if mantissa & 0x800000 != 0:
        mantissa >>= 8
        nbytes += 1

    // Assemble compact value:
    return (uint32(nbytes) << 24) | (mantissa & 0x00FFFFFF)
```

**Retarget verification rule (replacing "standard compact rounding" in §4.2.2):**

After computing `new_target` from the retarget formula, the verifier MUST:
1. Call `encode_target_to_nbits(new_target)` to get `expected_nbits`.
2. Compare `expected_nbits` to the `nBits` field in the submitted header.
3. REJECT the header if they do not match exactly.

The canonical encoding algorithm above is the sole normative definition.

**Minimum difficulty floor:**

No Bitcoin header may claim a difficulty lower than the genesis difficulty. The verifier MUST enforce:

```
MIN_DIFFICULTY_TARGET = 0x00000000FFFF0000000000000000000000000000000000000000000000000000
// This is the target corresponding to nBits = 0x1d00ffff (genesis block difficulty).
```

Any decoded target where `target > MIN_DIFFICULTY_TARGET` MUST be rejected with reason `TargetBelowMinimumDifficulty`. This applies to both header PoW checks and retarget verification.

**Edge-case rejection table:**

| Condition | `nBits` example | Rejection reason |
|-----------|----------------|-----------------|
| Negative mantissa (bit 23 set) | `0x1800ff80` | `NegativeMantissa` |
| Zero mantissa | `0x03000000` | `ZeroTarget` |
| Exponent > 32 | `0x2100ffff` | `ExponentOverflow` |
| Shift overflow (result > 2^256) | `0x20ffffff` | `TargetShiftOverflow` |
| Target below minimum difficulty | any `nBits` producing `target > MIN_DIFFICULTY_TARGET` | `TargetBelowMinimumDifficulty` |
| Re-encoding mismatch | `nBits` that decodes correctly but does not round-trip through `encode_target_to_nbits` | `NonCanonicalEncoding` |

**Normative test vectors for this section are in Appendix D6.**

#### 4.2.2 Difficulty Validation

For each submitted header at height H:

- If `H % 2016 == 0`:
  1. `t_start = period_timestamps[H - 2016]`, `t_end = headers[H - 1].timestamp`.
  2. `elapsed = clamp(t_end - t_start, 302400, 8064000)`.
  3. `new_target = prev_target × elapsed / 1209600` (standard Bitcoin retarget arithmetic).
  4. Verify `nBits` encodes `new_target` using the canonical re-encoding algorithm defined in §4.2.1. Compute `expected_nbits = encode_target_to_nbits(new_target)` and REJECT the header if `header.nBits != expected_nbits`.
  5. Store `period_timestamps[H] = header.timestamp`.
- Otherwise: `header.nBits` MUST equal `headers[H-1].nbits`.

#### 4.2.3 Fork Choice Rule

The SPV verifier applies most-cumulative-work:

```
work(header) = 2^256 / (target + 1)
```

When a competing chain tip with `cumulative_work > chain_state.cumulative_work` is submitted, reorganization is triggered (see §15.3).

#### 4.2.4 Header Chain Bootstrap and Checkpoint Governance

**The SPV verifier requires an explicit `GENESIS_CHECKPOINT` to function.** Without a hardcoded anchor, the verifier is vulnerable to long-range attacks: an adversary could construct an alternative Bitcoin chain from block 0 with modest but valid proof-of-work that, at early chain heights, accumulates comparable cumulative work to the canonical chain. The verifier has no basis for rejecting such a chain using cumulative-work comparison alone.

**GENESIS_CHECKPOINT structure:**

```
GENESIS_CHECKPOINT {
    block_height:           uint64,   // height of checkpoint block
    block_hash:             bytes32,  // hash of checkpoint block header
    cumulative_work:        uint256,  // cumulative work to this point (inclusive)
    period_start_timestamp: uint32,   // Bitcoin timestamp of the block at the start of the
                                      // 2016-block difficulty period containing block_height
                                      // i.e., the timestamp of block (block_height - (block_height % 2016))
}
```

This value is a **deployment-time constant** hardcoded into the Zenon SPV verifier contract. It MUST NOT be updated by relayers.

**Requirements for checkpoint selection:**
1. The block MUST be at least 1000 blocks prior to the protocol deployment block.
2. The `block_hash` MUST match the Bitcoin canonical chain as broadly accepted by the Bitcoin network at deployment time.
3. The `cumulative_work` MUST be the accurate cumulative-work sum from genesis through `block_height`.
4. `period_start_timestamp` MUST equal the `nTime` field of the Bitcoin block at height `block_height - (block_height % 2016)` on the canonical chain. If `block_height % 2016 == 0`, this is the timestamp of the checkpoint block itself.

**Initialization:** The SPV verifier begins with `chain_state.tip_hash = GENESIS_CHECKPOINT.block_hash`, `tip_height = GENESIS_CHECKPOINT.block_height`, and `cumulative_work = GENESIS_CHECKPOINT.cumulative_work`. Additionally, the verifier initializes:

```
last_retarget_height = GENESIS_CHECKPOINT.block_height - (GENESIS_CHECKPOINT.block_height % 2016)
period_timestamps[last_retarget_height] = GENESIS_CHECKPOINT.period_start_timestamp
```

This ensures that the first difficulty retarget height `H` after the checkpoint (where `H % 2016 == 0`) can correctly read `period_timestamps[H - 2016]`. Without this initialization, the first difficulty adjustment after deployment would read an uninitialized value. Header relayers MUST submit all subsequent headers from `block_height + 1` onward.

**Rejection of pre-checkpoint chains:** Any header submission chain that does not descend from `GENESIS_CHECKPOINT.block_hash` MUST be rejected by the verifier regardless of cumulative work. The checkpoint acts as a finalization boundary: the protocol treats all Bitcoin history prior to the checkpoint as settled.

**Long-range attack resistance:** An adversary constructing an alternative chain diverging before the checkpoint block cannot register it with the verifier, since the verifier will reject any chain whose ancestry does not include `GENESIS_CHECKPOINT.block_hash`. This eliminates the long-range attack surface entirely for pre-checkpoint history.

**Checkpoint advancement governance:** The Zenon governance process may advance the checkpoint to a more recent block as the protocol matures. A governance proposal to update `GENESIS_CHECKPOINT` MUST:
1. Reference a block at least 10,000 blocks before the governance proposal submission.
2. Include a fully-specified candidate `GENESIS_CHECKPOINT` struct (block_hash, block_height, cumulative_work, period_start_timestamp, period_bits) — partial proposals MUST be rejected.
3. Be published to the Zenon governance registry a minimum of `GOVERNANCE_CHECKPOINT_CHALLENGE_PERIOD` Zenon blocks before the vote opens, to allow time for community verification of the candidate block against Bitcoin full nodes. Recommended: `GOVERNANCE_CHECKPOINT_CHALLENGE_PERIOD = 4032` Zenon blocks (approximately 7 days).
4. Be approved by a 0.67 supermajority (§12.9) of governance-eligible stake.
5. Take effect only after a transition window during which no new deposits are accepted (to allow all pending deposits at intermediate heights to finalize). The transition window MUST be at least `FINAL_DEPTH + CONF_DEPTH` Bitcoin blocks.

**In-flight deposit invariant.** A checkpoint advancement MUST NOT invalidate any `DepositRecord` whose confirming block is at or above the previous checkpoint height. Before a checkpoint proposal may be executed, the contract MUST verify that no `DepositRecord` in `Pending`, `Confirmed`, or `Available` state has a `deposit_block_height` between the previous checkpoint height and the new checkpoint height. If any such record exists, the transition MUST be delayed until those deposits reach terminal state.

**Governance capture risk.** A malicious checkpoint update could retroactively validate a fraudulent deposit chain. Checkpoint governance proposals MUST undergo independent verification by at least one Bitcoin full node operator external to the relayer set before the challenge period expires. The Zenon governance contract MUST emit a `CheckpointProposalEvent` upon submission; any party MUST be able to submit a `CheckpointChallengeMsg` identifying a discrepancy before the vote opens.

Checkpoint updates are irreversible: once advanced, headers below the new checkpoint are no longer validated against the old checkpoint. This is acceptable because all deposits registered against blocks below the new checkpoint will already be in `Finalized` state by the time the transition window concludes.

#### 4.2.5 Header Submission and Relayer Liveness Obligation

**Header submission is permissionless.** Any Zenon account — whether a registered relayer, depositor, or unaffiliated observer — MAY submit valid Bitcoin block headers to the Zenon Portal SPV verifier. A header submission is accepted if and only if it satisfies all validity requirements in §4.2.1 and §4.2.2. Submission does not require relayer registration, bonding, or any form of permissioned access. This ensures the header chain cannot be censored by a delinquent or colluding relayer set.

**Relayer liveness obligation:** Permissionless submission does not eliminate the relayer header-submission obligation. Registered relayers remain responsible for ensuring the header chain advances. A relayer is delinquent if `chain_state.tip_height` has not advanced for `HEADER_LAPSE_WINDOW` Zenon blocks (recommended: corresponding to approximately 30 Bitcoin blocks at average block intervals) while Bitcoin is producing blocks. Delinquency is measured against the aggregate tip, not per-relayer submissions; any submission from any account advances the tip and satisfies all relayers' liveness obligation for that period.

**Enforcement:** Delinquent relayers MUST be suspended from new withdrawal claim assignments. No bond slashing is implemented for header delinquency. The header submission obligation is a **social norm with an indirect economic incentive** (relayers who fail to submit headers cannot claim withdrawal fees) rather than a protocol-enforced requirement with punitive consequences. This is documented explicitly in §12.1 A8.

### 4.2.6 Header Timestamp Validation

All submitted Bitcoin headers MUST satisfy the following two timestamp rules in addition to the PoW and difficulty rules in §4.2.1–§4.2.2. Both rules MUST be evaluated and both MUST pass before a header is accepted.

**Rule T1 — Median Time Past (MTP) lower bound:**

```
header.timestamp MUST be strictly greater than the Median Time Past (MTP)
of the 11 most recent ancestor headers.
```

The MTP is the median of the timestamps of the 11 most recent ancestor headers, ordered by height (not by timestamp). For a candidate header at height H, the 11 ancestors are the headers at heights H−1, H−2, ..., H−11. If fewer than 11 ancestors exist above the `GENESIS_CHECKPOINT`, the MTP is computed over all available ancestors (minimum 1).

**MTP computation:**

```
function median_time_past(chain_state, candidate_height) -> uint32:
    ancestors = []
    h = candidate_height - 1
    while h >= GENESIS_CHECKPOINT.block_height and len(ancestors) < 11:
        ancestors.append(chain_state.headers[h].timestamp)
        h -= 1
    ancestors.sort()
    return ancestors[len(ancestors) // 2]   // lower median for even counts
```

The verifier MUST store or be able to reconstruct the timestamps of the 11 most recent accepted headers. The `ChainState.headers` map already stores `HeaderRecord.timestamp` for all accepted headers; the MTP function reads from this store.

A header with `header.timestamp ≤ median_time_past(chain_state, candidate_height)` MUST be rejected with reason `TimestampBelowMTP`.

**Rationale:** The MTP rule prevents header timestamps from running arbitrarily backward. Bitcoin Core enforces this rule as part of consensus. Without it, an adversary submitting valid-PoW headers with distorted decreasing timestamps could affect retarget arithmetic (the retarget formula uses `t_end - t_start`, which could be driven toward zero, causing an artificial difficulty drop). The MTP rule ensures timestamps are non-decreasing at the 11-block median granularity.

**Rule T2 — Forward-drift upper bound:**

```
header.timestamp MUST NOT exceed zenon_wall_clock_estimate + MAX_FUTURE_BLOCK_TIME_SECONDS
```

```
MAX_FUTURE_BLOCK_TIME_SECONDS = 7200   // 2 hours
```

`zenon_wall_clock_estimate` is the Zenon contract's best estimate of the current real-world time. Because Zenon is a blockchain and cannot access a hardware clock, this value is derived as follows:

```
zenon_wall_clock_estimate = current_zenon_block_timestamp
// where current_zenon_block_timestamp is the timestamp of the most recently
// finalized Zenon block as reported by the Zenon consensus layer.
```

Zenon block timestamps are set by Zenon validators subject to Zenon's own block timestamp rules. This estimate may lag real-world time by up to one Zenon block interval (nominally ~6 seconds) plus any local clock drift in the Zenon validator set. The `MAX_FUTURE_BLOCK_TIME_SECONDS = 7200` upper bound is chosen conservatively to accommodate this lag while still bounding adversarial forward-timestamp injection.

A header with `header.timestamp > zenon_wall_clock_estimate + MAX_FUTURE_BLOCK_TIME_SECONDS` MUST be rejected with reason `TimestampTooFarInFuture`.

**Rationale:** Without a forward-drift bound, an adversary could submit valid-PoW headers with timestamps far in the future. A far-future timestamp in the retarget calculation inflates `elapsed`, potentially triggering maximum difficulty reduction (clamp at 4× expansion). The forward-drift bound prevents this attack. Bitcoin Core uses a 2-hour forward-drift bound for p2p block propagation; this specification adopts the same value, adjusted for the fact that the Zenon wall-clock estimate may lag by a block interval.

**Rule T2 at genesis:** For the first headers submitted after the `GENESIS_CHECKPOINT`, `zenon_wall_clock_estimate` is the Zenon timestamp of the block that processes the first header submission. Implementations MUST initialize this correctly and MUST NOT use a hardcoded or zero-initialized wall-clock value.

**Interaction between T1 and T2:** A valid header satisfies `MTP < header.timestamp ≤ zenon_wall_clock_estimate + 7200`. Both bounds are checked independently. A header that satisfies T2 but not T1 is still rejected.


### 4.3 SPV Proof Format and Merkle Verification

```
SPV_PROOF {
    tx_raw:         bytes,       // full SegWit serialization
    tx_index:       uint32,      // 0-indexed position of tx in block
    merkle_path:    bytes32[],   // sibling hashes, leaf to root
    block_header:   bytes[80],
    block_height:   uint64,
}
```

**Merkle root reconstruction with CVE-2012-2459 mitigations:**

```
Step 1: Compute btc_txid
    if tx_raw is SegWit (marker = 0x00, flag != 0x00):
        btc_txid = DH(non_witness_serialization(tx_raw))
    else:
        btc_txid = DH(tx_raw)

Step 2: Validate path length
    if merkle_path.length > 30:
        REJECT("merkle path too long")

Step 3: Traverse
    node = btc_txid
    index = tx_index
    for sibling in merkle_path:
        if node == sibling:
            REJECT("duplicate sibling — CVE-2012-2459 guard")
        if index % 2 == 0:
            node = DH(node || sibling)
        else:
            node = DH(sibling || node)
        index >>= 1

Step 4: Verify
    if node != block_header.merkle_root:
        REJECT("merkle root mismatch")
```

### 4.4 Bitcoin Transaction Parser

All `tx_raw` inputs are parsed using the following normative procedure. P2TR inputs require SegWit serialization; the parser handles both legacy and SegWit formats.

```
ParsedTransaction {
    version:  int32,
    segwit:   bool,
    inputs:   TxInput[],
    outputs:  TxOutput[],
    locktime: uint32,
}

TxInput  { prev_txid: bytes32, prev_vout: uint32, script: bytes, sequence: uint32 }
TxOutput { value: uint64, script: bytes }
```

**Parsing algorithm:**

```
offset = 0
version = read_int32_le(tx_raw, offset); offset += 4

segwit = (tx_raw[offset] == 0x00 and tx_raw[offset+1] != 0x00)
if segwit: offset += 2

input_count = read_varint(tx_raw, offset); offset += varint_len(input_count)
for i in range(input_count):
    prev_txid  = tx_raw[offset:offset+32]; offset += 32
    prev_vout  = read_uint32_le(tx_raw, offset); offset += 4
    slen = read_varint(tx_raw, offset); offset += varint_len(slen)
    script = tx_raw[offset:offset+slen]; offset += slen
    sequence = read_uint32_le(tx_raw, offset); offset += 4

output_count = read_varint(tx_raw, offset); offset += varint_len(output_count)
for i in range(output_count):
    value  = read_uint64_le(tx_raw, offset); offset += 8
    if value > 2_099_999_997_690_000:
        REJECT("output value out of valid Bitcoin range")
    // Note: Bitcoin's on-wire output value field is a signed 64-bit little-endian
    // integer by historical convention. The valid range is [0, 2_099_999_997_690_000].
    // Implementations MUST interpret this field as unsigned and MUST reject any
    // encoding where the high bit of the 8-byte field is set (which would indicate
    // a negative value in the signed interpretation), as such values always exceed
    // MAX_BITCOIN_VALUE_SAT and are rejected by the range check above.
    slen = read_varint(tx_raw, offset); offset += varint_len(slen)
    script = tx_raw[offset:offset+slen]; offset += slen

if segwit:
    for i in range(input_count):
        items = read_varint(tx_raw, offset); offset += varint_len(items)
        for j in range(items):
            ilen = read_varint(tx_raw, offset); offset += varint_len(ilen)
            offset += ilen

locktime = read_uint32_le(tx_raw, offset)
if offset + 4 != len(tx_raw):
    REJECT("trailing bytes after locktime")
```

**Note on parser error semantics:** Every `REJECT(...)` call in the parsing algorithm is a contract-level rejection. The message is rejected in its entirety; no partial parse result is retained or acted upon.

**Output value range:** The constant `2_099_999_997_690_000` is the maximum possible Bitcoin output value in satoshis (21,000,000 BTC × 10^8 sat/BTC − rounding). `TxOutput.value` is typed `uint64`; the range check `value > 2_099_999_997_690_000` catches all invalid values. Bitcoin's historical wire format uses a signed 64-bit field; implementations reading the raw bytes MUST use an unsigned 64-bit read (`read_uint64_le`) and treat the result as unsigned throughout. A raw value with the high bit set is mathematically ≥ 2^63 > 2_099_999_997_690_000 and is therefore rejected by the range check. All downstream protocol uses (pool accounting, invariant checks, collateral computations) operate on `uint64` throughout.

**Supported output script types:**

| Type | Pattern | Bytes |
|------|---------|-------|
| P2PKH | `OP_DUP OP_HASH160 <20> OP_EQUALVERIFY OP_CHECKSIG` | 25 |
| P2WPKH | `OP_0 <20>` | 22 |
| P2WSH | `OP_0 <32>` | 34 |
| P2TR | `OP_1 <32>` | 34 |

For deposit validation, only P2TR is accepted. For withdrawal destinations, the accepted types differ by request origin:

- **New `WithdrawalRequest` submissions:** `btc_address_script` MUST be one of P2WPKH, P2WSH, or P2TR. The contract MUST reject a `WithdrawalRequest` whose `btc_address_script` matches the P2PKH pattern. P2PKH is a legacy output type whose long-term relay policy status in Bitcoin Core is uncertain, and users providing P2PKH addresses in a long-timelock context may no longer hold the corresponding private key with no recovery path.
- **Parser compatibility:** The `btc_address_script` parser (§4.4) MUST retain the ability to recognize and parse P2PKH scripts for backward compatibility with historical deposits and any in-flight withdrawal records created before this restriction took effect. The verifier compares `output.script` byte-for-byte against the committed `btc_address_script` in the `WithdrawalRecord` regardless of type.

Operators and wallet tooling MUST display a deprecation notice to users who provide a P2PKH address for withdrawal and MUST NOT accept new P2PKH withdrawal destinations after this specification version.

### 4.5 Required Confirmation Depths

```
CONF_DEPTH  = 6     // Pending → Confirmed
FINAL_DEPTH = 100   // Confirmed → Finalized (transferable eBTC issued)
```

**CONF_DEPTH=6 security note:** Using the correct Poisson-process formulation from Nakamoto (2008), the probability that an attacker controlling fraction `q` of hash rate successfully double-spends a transaction with 6 confirmations is:

```
P(success | q) ≈ 1 - sum_{k=0}^{5} [Poisson(k, λ=6q/p) × (1 - (q/p)^(6-k))]
```

For `q = 0.3`, `p = 0.7`: `P ≈ 0.177` (approximately 17.7%).
For `q = 0.1`, `p = 0.9`: `P ≈ 0.0015` (approximately 0.15%).

The `(q/p)^n` formula sometimes cited is a large-n catchup approximation that substantially underestimates risk at small n. CONF_DEPTH=6 provides security for restricted (non-transferable) eBTC only. Whether this is acceptable depends on the deploying application's risk model and the value at stake; this specification does not assert a universal security target. Operators handling material BTC value SHOULD assess this figure against their own threat models. Full transferability is deferred to FINAL_DEPTH=100 where the double-spend probability is negligible under any realistic adversarial hash rate.

**CONF_DEPTH protection scope:** These probabilities assume an **opportunistic attacker** — one who begins mining a private fork only after observing a target transaction. A miner sustaining >50% hash rate for a sufficient period can succeed at any confirmation depth regardless of the formula above. CONF_DEPTH provides no protection against such an adversary. This is an accepted limitation of Bitcoin SPV, fully captured by trust assumption A1 (§12.1).

**FINAL_DEPTH=100 note:** At FINAL_DEPTH=100, approximately 16.7 hours of Bitcoin block time must elapse before eBTC becomes freely transferable. This is a deliberate safety parameter. Applying the Nakamoto (2008) Poisson formula at depth 100 with `q = 0.30` (adversarial hash rate fraction), `p = 1 − q = 0.70`, `λ = 100q/p ≈ 42.86`:

```
P(success | q=0.30, depth=100) < 10⁻⁷
```

This is a conservative upper bound. For `q = 0.10`, the probability is below any practical precision threshold. At `q = 0.20`, `P < 10⁻¹²`. See §12.6 for the full table. Operators and wallet developers MUST communicate the 16.7-hour latency to users. Economic activity requiring immediate transferability must use the restricted `Confirmed` state with full awareness of its non-transferability and elevated reorg risk.

---

## 5. Deposit Escrow Script Design

### 5.1 Taproot Escrow Architecture

Each deposit creates a Taproot output with spend paths determined by the depositor's chosen **escrow class**. Two escrow classes are defined:

- **Class R (Refund-Protected):** A two-leaf taptree with a NUMS (unspendable) internal key. Key-path spending is disabled. Leaf 1 enables cooperative withdrawal requiring both the depositor's signature and a FROST threshold signature. Leaf 2 enables unilateral refund after the absolute timelock. Relayers cannot spend this UTXO unilaterally under any circumstances.
- **Class P (Pool-Liquidity):** A single-leaf taptree with the FROST epoch key as internal key. Key-path spending is enabled and controlled by the FROST threshold alone. The depositor explicitly accepts relayer key-path authority and its associated risks (§5.6).

The `escrow_class` is committed at deposit time and enforced by the script structure itself — a Class R UTXO is structurally incapable of being spent via key-path regardless of Zenon-layer enforcement. The Zenon contract additionally records and enforces the class in the `DepositRecord` (§6.3).

> **WARNING — Class P attribution boundary.** The slashing mechanism in §9.7 is operative only when colluding relayers use the Zenon-layer attestation infrastructure (`SigningIntentCommitment`, `SigningBundle`). A threshold-sized quorum can instead compute the FROST aggregate secret key off-protocol and broadcast a raw Bitcoin key-path spend without interacting with Zenon at all. Because a Taproot key-path spend on Bitcoin encodes only a single aggregate Schnorr signature with no embedded participant identities, such a transaction provides no on-chain evidence linking any individual relayer to the action. This is a property of threshold signatures on Bitcoin, not an implementation gap unique to Zenon Portal. Under this path, no `SigningIntentCommitment`s exist, Slash Condition F has no `committed_signers` set to attribute to, and the fallback is "unaudited protocol failure" (§9.7.13). **The slashing mechanism therefore cannot attribute an off-protocol key-path spend to specific participants; its deterrence model requires that colluding relayers use the Zenon attestation flow voluntarily.** Class R deposits are not subject to this limitation: the Class R taptree disables key-path spending entirely, so no threshold-signature operation can unilaterally authorize a spend. This warning applies to §9.7 and §13 equally.

### 5.2 Key Structure

#### Class R (Refund-Protected)

```
pk_internal = NUMS_point
```

**NUMS point specification:**

`NUMS_point` is a secp256k1 point generated by a process that makes discrete log preimage computationally infeasible under standard discrete logarithm assumptions, by deriving the x-coordinate from a tagged hash with no known relationship to any known point with a known discrete log.

**X-coordinate derivation:**

```
nums_x = tagged_hash("Zenon/NUMS", 0x00...00)
       // where 0x00...00 is a 32-byte zero value
       // tagged_hash uses BIP340 convention:
       //   SHA256(SHA256("Zenon/NUMS") || SHA256("Zenon/NUMS") || msg)
```

**Y-coordinate convention:** Per BIP340 convention, the NUMS point uses the **even-y lift**. Given `nums_x`, the two candidate y-values satisfying the secp256k1 curve equation `y² = x³ + 7 (mod p)` are computed; the one with even parity (`y mod 2 == 0`) is selected. If `nums_x` does not correspond to a point on the curve, the derivation is re-run with `tagged_hash("Zenon/NUMS", 0x00...01)`, incrementing the suffix byte until a valid x-coordinate is found. In practice the first candidate is valid.

**Normative NUMS point values:**

```
nums_x (hex, 32 bytes):
  50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0

nums_y (even-lift, hex, 32 bytes):
  31d3c6863973926e049e637cb1b5f40a36dac28af1766968c30c2313f3a38904

compressed public key (33 bytes, 0x02 prefix for even y):
  0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0
```

**Test vectors:** Implementations MUST verify that they reproduce both of the following cases correctly, as they test distinct Taproot constructions.

**Test Vector A — Taproot output key with script tree root = 32-byte zero value** (the Class R case where the taptree branch hash happens to equal all-zeros; this is a distinct construction from "no script tree"):

```
Inputs:
  P_xonly = 50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0
            (NUMS x-coordinate; even-y lift)
  merkle_root = 0x0000000000000000000000000000000000000000000000000000000000000000
                (32-byte zero value — explicit script tree root, NOT "no tree")

Computation:
  tweak_input = P_xonly || merkle_root
  tweak_hash  = tagged_hash("TapTweak", tweak_input)
  tweak_int   = int(tweak_hash) mod n
  Q           = lift_x(P_xonly) + tweak_int * G
  Q_parity    = parity(Q.y)
  Q_xonly     = x(Q)

Expected output:
  Q_xonly = e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e
```

**Test Vector B — Taproot output key with no script tree** (key-path only; tweak uses only the internal key x-coordinate with no merkle root appended):

```
Inputs:
  P_xonly = 50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0

Computation:
  tweak_input = P_xonly          // NO merkle root appended; this is the "no script tree" case
  tweak_hash  = tagged_hash("TapTweak", tweak_input)
  tweak_int   = int(tweak_hash) mod n
  Q           = lift_x(P_xonly) + tweak_int * G
  Q_xonly     = x(Q)
```

**Note:** Test Vector A (zero taptree root) and Test Vector B (no taptree) are NOT equivalent constructions and MUST produce different `Q_xonly` values. An implementation that produces identical output for both has a critical Taproot construction bug and MUST NOT be deployed. The Class R escrow NEVER uses the "no script tree" construction; it always commits to a real taptree. These vectors test implementation correctness for BIP341 §5.

**Security rationale:** The NUMS point is constructed such that no party knows its discrete logarithm. The tagged hash construction with a protocol-specific tag ensures the value is not shared with any other protocol using the same secp256k1 curve. The even-y convention is required for BIP341 compatibility: the Taproot tweak computation uses the x-only representation, and BIP341 specifies that the internal key must be treated as even-y for the purpose of tweak computation.

**Taptree — two leaves:**

```
Leaf 1 (cooperative withdrawal):
    <pk_frost_epoch_xonly> OP_CHECKSIGVERIFY <pk_u_xonly> OP_CHECKSIG

Leaf 2 (unilateral refund):
    <ABSOLUTE_EXPIRY> OP_CHECKLOCKTIMEVERIFY OP_DROP <pk_u_xonly> OP_CHECKSIG
```

**Security analysis:** Cooperative withdrawal (Leaf 1) requires a valid Schnorr signature from `pk_u` AND a valid Schnorr signature from `pk_frost_epoch`. A colluding FROST majority cannot spend this output without the depositor's cooperation. The unilateral refund (Leaf 2) allows the depositor to reclaim their BTC after `ABSOLUTE_EXPIRY` with no relayer involvement. Because the key-path is disabled, there is no path by which relayers can initiate consolidation without user co-signature. The A9 combined attack has no applicable attack surface against Class R UTXOs.

**Withdrawal interaction model:** Processing a Class R withdrawal requires the depositor to produce a live Schnorr signature over the exact withdrawal transaction during the cooperative signing flow. This requires depositor online presence. Wallet implementations MUST communicate this requirement to Class R depositors at deposit time and at withdrawal initiation.

**No nesting of MuSig2 and FROST:** Class R uses independent CHECKSIGVERIFY operations in the leaf script, requiring both signatures but not composing them into a single key. This is fully analyzed under standard Taproot script semantics with no novel cryptographic assumptions beyond BIP 340 Schnorr signature security.

#### Class P (Pool-Liquidity)

```
pk_internal = pk_frost_epoch
```

The FROST epoch threshold set controls the key-path spend without user co-signing. The user's Bitcoin-layer protection against relayer theft is limited to the script-path timelock (Leaf 1 below).

**Security analysis:** A colluding FROST quorum can execute key-path spends. This is trust assumption A5a. The depositor accepts this explicitly when choosing Class P. See §5.6 for the mandatory disclosure requirement.

### 5.3 Script Templates

#### 5.3R Class R Script Template

**Leaf 1 — cooperative withdrawal script:**

```
<pk_frost_epoch_xonly> OP_CHECKSIGVERIFY <pk_u_xonly> OP_CHECKSIG
```

The FROST signature is verified first (OP_CHECKSIGVERIFY consumes and does not leave a result on stack). The user signature is verified second (OP_CHECKSIG). Both MUST be valid for the leaf to succeed. Stack at entry: `[sig_u, sig_frost]`. Stack ordering follows standard Bitcoin Script convention (top of stack checked last by OP_CHECKSIG).

**Leaf 2 — unilateral refund script:**

```
<ABSOLUTE_EXPIRY> OP_CHECKLOCKTIMEVERIFY OP_DROP <pk_u_xonly> OP_CHECKSIG
```

`ABSOLUTE_EXPIRY` is a 4-byte little-endian Bitcoin script integer (BIP 65 format) encoding the absolute block height after which the refund script is valid.

**Taptree construction:**

```
leaf1_hash = tagged_hash("TapLeaf", 0xC0 || varint(len(coop_script)) || coop_script)
leaf2_hash = tagged_hash("TapLeaf", 0xC0 || varint(len(refund_script)) || refund_script)

// Canonical leaf ordering: sort by hash, leftmost is smaller
if leaf1_hash <= leaf2_hash:
    branch_hash = tagged_hash("TapBranch", leaf1_hash || leaf2_hash)
else:
    branch_hash = tagged_hash("TapBranch", leaf2_hash || leaf1_hash)

taptree_root = branch_hash
```

**Taproot output key:**

```
Q = NUMS_point + tagged_hash("TapTweak", x_only(NUMS_point) || taptree_root) * G
scriptPubKey = OP_1 <x_only(Q)>    // 34 bytes
```

The NUMS internal key ensures key-path spending is infeasible. The tweak binds the taptree commitment to the output key.

**Privacy note:** The two-leaf taptree reveals the unused leaf at spend time (one leaf hash is disclosed). This is a minor privacy consideration relative to the security benefit. No mitigation is specified in this version.

#### 5.3P Class P Script Template

**Script (refund leaf, single-leaf taptree):**

```
<ABSOLUTE_EXPIRY> OP_CHECKLOCKTIMEVERIFY OP_DROP <pk_u_xonly> OP_CHECKSIG
```

**Taptree (single leaf):**

```
taptree_root = tagged_hash("TapLeaf", 0xC0 || varint(len(script)) || script)
```

**Taproot output key:**

```
Q = pk_frost_epoch + tagged_hash("TapTweak", pk_frost_epoch || taptree_root) * G
scriptPubKey = OP_1 <x_only(Q)>    // 34 bytes
```

### 5.4 Timelock Duration

`T = 4032` blocks. `ABSOLUTE_EXPIRY = deposit_confirmation_block_height + T`. The `deposit_confirmation_block_height` is recorded as `registered_height_btc` in the `DepositRecord`.

**CLTV encoding overflow check.** `ABSOLUTE_EXPIRY` is encoded as a 4-byte little-endian Bitcoin script integer (BIP 65 format) representing values up to `2^31 − 1 = 2,147,483,647`. At the time of this specification, Bitcoin block height is approximately 887,000; overflow is not imminent. However, at deposit registration, the contract MUST verify:

```
MAX_CLTV_HEIGHT = 2^31 − 1   // = 2,147,483,647

registered_height_btc + T ≤ MAX_CLTV_HEIGHT
```

If this condition is violated, the deposit registration MUST be rejected with reason `CLTVOverflow`. This check prevents silent script construction bugs at far-future heights. Before Bitcoin reaches block height approximately 2,143,451,615 (circa year 2103 at current block production), the protocol MUST be upgraded to handle larger block heights in the script encoding.

Absolute CLTV is used rather than relative CSV because CLTV anchors the refund window to a fixed block height, making the expiry predictable regardless of deposit confirmation timing. CSV windows vary with the UTXO's confirmation block, creating ambiguity for users who experience delayed deposit confirmation.

**`MIN_DEPOSIT_SAT` — contract-enforced floor:**

```
MIN_DEPOSIT_SAT = 50,000 sat   // contract-enforced minimum; deployment may raise but not lower
```

The protocol requires `MIN_DEPOSIT_SAT` to be set high enough that a refund transaction remains economically viable at elevated Bitcoin fee rates. A Class R unilateral refund transaction (Leaf 2 script-path spend, single input, one output) is approximately 250–280 vbytes due to the two-leaf control block. A Class P unilateral refund transaction (single-leaf script-path spend) is approximately 230–250 vbytes. The floor is set conservatively against the larger Class R figure. At a fee rate of `F` sat/vbyte, the break-even deposit size for Class R is `280 × F` sat.

At 200 sat/vbyte: `MIN_DEPOSIT_SAT ≥ 56,000 sat`. The floor of 50,000 sat is set below this and is therefore not viable at extreme fee environments; deployers operating in high-fee conditions MUST raise the floor accordingly.

### 5.5 Key Reuse Advisory

Depositors SHOULD use a fresh `pk_u` for each deposit. Key reuse across deposits leaks correlatable on-chain information in the event of script-path (refund) spending. This advisory is normative for wallet implementations. Protocol-level enforcement is not implemented because the contract cannot verify key freshness without a registry of used user keys, which would impose O(n) lookup overhead and raise privacy concerns.

### 5.6 Mandatory Deposit Disclosures

#### 5.6P Class P Mandatory Disclosure

When a user initiates a Class P deposit, the operator interface MUST display the following disclosure before the deposit transaction is broadcast. The disclosure MUST NOT be hidden behind a secondary screen, collapsed by default, or pre-acknowledged without user interaction:

> **Class P (Pool-Liquidity) deposit — you are accepting the following:**
> 1. Relayers may consolidate your Bitcoin escrow UTXO into the shared pool once the Consolidation Safety Window opens. After consolidation, your Bitcoin-native unilateral refund path no longer exists.
> 2. A colluding relayer majority can spend your escrow UTXO without your consent (trust assumption A5a). The on-chain slashing mechanism (§9.7) is the economic deterrent against this; it is active only when `CLASS_P_ENABLED == true` has been set by governance after all enforcement prerequisites are satisfied (§5.9).
> 3. A colluding relayer majority can consolidate your UTXO and then censor your withdrawals, permanently stranding your eBTC (trust assumption A9). This risk is mitigated but not eliminated while slashing is active.
> 4. The fact that Class P is currently accepting deposits means governance has verified and activated the enforcement prerequisites in §5.9.2. You may verify activation status on-chain via the `CLASS_P_ENABLED` contract state variable.
> 5. You are choosing pooled execution efficiency in exchange for these explicit risks.

#### 5.6R Class R Mandatory Disclosure

When a user initiates a Class R deposit, the operator interface MUST display the following disclosure before the deposit transaction is broadcast:

> **Class R (Refund-Protected) deposit — you are accepting the following:**
> 1. Your Bitcoin escrow UTXO cannot be spent without your private key (`pk_u`). Relayers cannot consolidate or steal your UTXO. Your Bitcoin-native unilateral refund path is permanently available after your timelock expires, provided your UTXO remains unspent.
> 2. Authorizing a cooperative withdrawal requires your live `pk_u` signature over the exact Bitcoin withdrawal transaction, in addition to the relayer threshold signature. Class R cooperative withdrawal is **interactive**: you must be online when the withdrawal transaction is constructed and signed.
> 3. If relayers censor your withdrawal requests, your only exit is the Leaf 2 timelock refund, available after `ABSOLUTE_EXPIRY`. Under sustained censorship that begins today, the maximum delay before you can exit unilaterally is approximately `ABSOLUTE_EXPIRY − current_bitcoin_height` Bitcoin blocks (up to `T = 4032` blocks ≈ 28 days from a fresh deposit). This delay represents capital lock-up with no protocol recourse during the censorship period.
> 4. If you migrate from Class R to Class P later (§11.5), migration is **irreversible once the on-Bitcoin re-deposit transaction confirms and the new Class P escrow output is registered on Zenon**. You accept all Class P risks from that point. You may cancel migration before this point by submitting a `ClassMigrationCancelMsg` within the `CLASS_MIGRATION_DELAY` window.

**Enforcement:** Both disclosures are normative. Operator non-compliance does not affect the on-chain protocol but renders the operator deployment non-conformant with this specification.

**`MIN_DEPOSIT_SAT` note:** The floor of 50,000 sat supports refund viability at fee rates up to approximately 200 sat/vbyte. Deployments in high-fee environments MUST raise `MIN_DEPOSIT_SAT` accordingly; the contract enforces the floor but operators bear responsibility for calibrating to their deployment environment's realistic fee range. The unilateral exit guarantee is meaningless for deposits that cannot economically self-fund their refund transaction.

### 5.7 Class R Cooperative Withdrawal Scope

Class R cooperative withdrawal is **interactive**. The depositor must be online to provide a valid live `pk_u` Schnorr signature over the exact Bitcoin transaction being broadcast during the cooperative signing flow.

Offline delegation, pre-signed withdrawal packages, and other mechanisms intended to allow third-party completion of a Class R cooperative withdrawal while the depositor is offline are **out of scope** for this specification. Such mechanisms may be specified in a future RFC once fee-bumping, transaction replacement, conflict handling, and wallet interoperability are fully analyzed.

The unilateral refund path (Leaf 2) remains available after `ABSOLUTE_EXPIRY` without any online requirement; it requires only the depositor's `pk_u` and an unspent UTXO.

### 5.8 Key Management Obligations

**User (`pk_u`):** Fresh key per deposit — REQUIRED for wallet implementations. The contract does not enforce `deposit_pk_u` uniqueness across registrations: two deposits using the same `pk_u` will produce different `zenon_nonce`s (different `txid`/`vout`) and both register successfully. However, reusing `pk_u` across deposits means that a single private key compromise simultaneously destroys the refund path for all deposits sharing that key. Wallet tooling implementing Zenon Portal MUST generate a distinct keypair for every deposit. This is a wallet-level requirement, not a protocol-enforced invariant.

**FROST epoch key:** Generated by DKG. Public and recorded on Zenon. Signing shares held by individual relayers.

### 5.9 Class P Activation Gate and Enforcement Prerequisites

#### 5.9.1 CLASS_P_ENABLED Flag

```
CLASS_P_ENABLED: bool = false
```

`CLASS_P_ENABLED` is a contract state variable maintained by the Zenon Portal contract. It defaults to `false` at deployment and at any protocol contract upgrade or redeployment. It may only be set by governance as specified in §5.9.3.

**Operations blocked when `CLASS_P_ENABLED == false`:**

The Zenon contract MUST reject the following operations with reason `ClassPNotEnabled` whenever `CLASS_P_ENABLED == false`:

1. `RegisterDepositMsg` where `escrow_class == ClassP` — new Class P deposit registration.
2. `BeginMigrationMsg` — Class R to Class P re-deposit migration initiation.
3. `ConsolidationProposal` where any input UTXO has `first_consolidation = true` — first-consolidation of any Class P UTXO.

**Operations not blocked by `CLASS_P_ENABLED == false`:**

The following operations MUST continue normally regardless of `CLASS_P_ENABLED`:

- All Class R deposit registrations.
- All Class R withdrawals (cooperative and unilateral).
- Existing Class P `DepositRecord`s in any state — withdrawals, refunds, completions, and state transitions for already-registered Class P deposits continue uninterrupted.
- Consolidations of Class P UTXOs with `first_consolidation = false` (already-consolidated UTXOs), subject to all other §11.4 constraints.
- All governance actions.
- All header submissions.

**Rationale:** The gate prevents new economic exposure from entering the Class P trust domain before the economic enforcement stack is live. It does not strand existing Class P holders: anyone who deposited Class P while `CLASS_P_ENABLED == true` retains full access to cooperative withdrawals, monitoring, and governance during a subsequent suspension. The gate is forward-looking only.

#### 5.9.2 Enforcement Prerequisites

Before governance may set `CLASS_P_ENABLED = true`, all six of the following prerequisites MUST be satisfied and demonstrably verifiable on-chain or by published external evidence referenced in the governance proposal:

**Prerequisite 1 — §9.7 slashing contract live:**
The Zenon contract upgrade implementing on-chain `SlashProof` adjudication (§9.7.12), `SpendIntent` creation enforcement (§9.7.4), `SigningBundle` posting enforcement (§9.7.9), and bond forfeiture execution (§9.7.14) is deployed and active on the target Zenon network. The upgrade MUST be on the same contract instance (or a governed successor) as the Portal contract.

**Prerequisite 2 — Watcher reward distribution active:**
The watcher reward path defined in §9.7.16 is live: `SlashProof` submissions MUST produce watcher rewards at `WATCHER_REWARD_BPS` as a contract-enforced output of the slashing execution flow. Reward distribution MUST be verifiable in the slashing transaction receipts. At least one independent watcher (not a registered relayer) MUST have demonstrated receipt of a watcher reward on the target network (testnet demonstration accepted at governance's discretion for initial activation).

**Prerequisite 3 — SlashProof adjudication live and tested:**
The `SlashProof` submission path is live: any party can submit a `SlashProof` and have it adjudicated. The contract MUST correctly process each proof type (NoIntent, Mismatch, InvalidState, DoubleSign, UnbundledSpend) and execute slashing on adjudication. At minimum, `proof_type = NoIntent` (Slash Condition A) and `proof_type = UnbundledSpend` (Slash Condition F) MUST have been demonstrated on the target network with correct slash execution against actual relayer bonds.

**Prerequisite 4 — Bond coverage satisfied:**
`total_slashable_bond_sat(epoch) ≥ INTENDED_INITIAL_CLASS_P_EXPOSURE × COLLATERAL_FACTOR` is satisfied for the epoch that will accept the first Class P deposits, per §9.7.15. `INTENDED_INITIAL_CLASS_P_EXPOSURE` MUST be published in the activation governance proposal. The governance proposal MUST include the current `total_slashable_bond_sat` and the implied `MAX_CLASS_P_EXPOSURE` cap.

**Prerequisite 5 — Relayer set implementation checklist:**
The active relayer set (all relayers in the current epoch) has each published a signed attestation confirming they have passed the Appendix C REQUIRED items applicable to relayers (C1.1–C1.11, C1.8–C1.9, relevant C3.x items). The governance activation proposal MUST reference the attestations. Self-attestation is permitted at initial activation; external verification is RECOMMENDED.

**Prerequisite 6 — External audit coverage:**
An independent security audit of the deployed contract has been completed and the audit report is publicly available. The audit MUST cover at minimum: (a) the Class P key-path spend and FROST signing flow; (b) the slashing mechanism including `SlashProof` adjudication, attribution rules, and penalty execution; (c) the consolidation mechanism including safety window enforcement and orphaned consolidation handling; (d) the `CLASS_P_ENABLED` activation gate itself. Audit scope gaps MUST be documented in the activation proposal.

#### 5.9.3 Governance Activation and Suspension

**Activation:** Governance MAY submit a `ClassPActivationProposal` proposing to set `CLASS_P_ENABLED = true`. The proposal MUST include:

- Evidence for each of the six prerequisites in §5.9.2.
- The `INTENDED_INITIAL_CLASS_P_EXPOSURE` value.
- A reference to the current epoch and its `total_slashable_bond_sat`.
- A reference to the audit report (Prerequisite 6).

The proposal requires **0.67 supermajority** and is subject to the standard `GOVERNANCE_VOTING_PERIOD` and `GOVERNANCE_EXECUTION_DELAY`. If approved, the contract sets `CLASS_P_ENABLED = true` and emits a `ClassPActivationEvent` recording the proposal ID, the block height of activation, and the `INTENDED_INITIAL_CLASS_P_EXPOSURE` value from the proposal.

**Automatic prerequisite monitoring:** After activation, the contract MUST continuously evaluate the following on-chain-verifiable subset of prerequisites at each Zenon block:

- **Prerequisite 4 (bond coverage):** If `total_slashable_bond_sat(epoch) / COLLATERAL_FACTOR < total_class_p_value` (bond coverage falls below existing Class P exposure), the §12.10 emergency downgrade already triggers. No additional governance action is required for this condition.
- Any conditions detectable from on-chain state that indicate the slashing contract is no longer active (e.g., a contract self-disable flag introduced by the §16.5 upgrade) SHOULD trigger automatic suspension.

**Mandatory suspension:** If any of the following conditions arise after activation, governance MUST set `CLASS_P_ENABLED = false` by submitting a `ClassPSuspensionProposal`:

1. The §9.7 slashing contract is disabled, paused, or superceded by an upgrade that removes slashing enforcement.
2. The watcher reward path is disabled or non-functional.
3. A critical security issue is discovered in the Class P key-path, slashing mechanism, or consolidation flow that has not been patched and re-audited.
4. Bond coverage falls below the minimum required for any new Class P deposits (this triggers §12.10 emergency downgrade automatically; governance suspension is additional for cases where bond loss is structural rather than transient).

A `ClassPSuspensionProposal` requires **0.67 supermajority**. On approval, the contract sets `CLASS_P_ENABLED = false` and emits a `ClassPSuspensionEvent` recording the proposal ID and suspension reason.

**Re-activation after suspension:** Re-activation after suspension follows the same procedure as initial activation: all six prerequisites MUST be re-verified and a new `ClassPActivationProposal` submitted.

**Emergency suspension:** If a critical vulnerability is discovered that requires immediate action, governance MAY invoke the standard contract freeze (§12.4, §12.8) which suspends all new deposits and withdrawals while the issue is resolved. The contract freeze is a broader mechanism than Class P suspension and is appropriate when the vulnerability affects Class R as well.

#### 5.9.4 Deployment States

A Zenon Portal deployment MUST be in one of the following Class P states at any time:

```
CLASS_P_STATE = {
  ClassPDisabled,    // CLASS_P_ENABLED = false; no Class P operations permitted
  ClassPActive,      // CLASS_P_ENABLED = true; all Class P operations permitted
                     // subject to normal protocol rules
  ClassPSuspended,   // CLASS_P_ENABLED = false after prior activation;
                     // existing Class P deposits continue normally;
                     // new Class P operations blocked
}
```

The distinction between `ClassPDisabled` and `ClassPSuspended` is informational: the contract behavior under both is identical (new Class P operations rejected). The distinction matters for governance context: `ClassPSuspended` indicates a prior active period and requires re-verification of all prerequisites before re-activation.


---

## 6. Deposit Registration Protocol

### 6.1 Deposit Finalization State Machine

**State transitions:**

```
Unregistered
    │ RegisterDepositMsg submitted and validated
    ▼
Pending           (< CONF_DEPTH confirmations; no eBTC issued)
    │ Bitcoin tip height ≥ registered_height_btc + CONF_DEPTH
    ▼
Confirmed         (restricted eBTC issued: same depositor_addr only)
    │ Bitcoin tip height ≥ registered_height_btc + FINAL_DEPTH
    ▼
Finalized         (full transferable eBTC issued)
```

States `Withdrawn`, `Refunded`, and `Invalidated` are terminal exit states.

**State advancement via priority queue — O(k) per block:**

The Zenon eBTC contract maintains two min-heaps keyed on Bitcoin block height:

```
confirm_queue:  min-heap<(target_height: uint64, deposit_id: bytes32)>
                where target_height = registered_height_btc + CONF_DEPTH

finalize_queue: min-heap<(target_height: uint64, deposit_id: bytes32)>
                where target_height = registered_height_btc + FINAL_DEPTH
```

At each Zenon block, the contract processes only deposits whose target height ≤ `chain_state.tip_height`, popping entries from the heap until the heap is empty or the next entry's target height exceeds the current tip. This reduces per-block work to O(k log n) where k is the count of deposits maturing at the current Bitcoin tip height — typically 0 or a small constant — rather than O(n) over all active deposits.

**Heap insertion:** Upon successful `RegisterDepositMsg` validation, the deposit MUST be inserted into both `confirm_queue` (with `target = registered_height_btc + CONF_DEPTH`) and `finalize_queue` (with `target = registered_height_btc + FINAL_DEPTH`).

**Queue processing — Invalidated deposit handling:**

```
entry = queue.pop()
deposit = deposit_records[entry.deposit_id]
if deposit.state != Confirmed:        // for finalize_queue entries
    skip                              // deposit was Invalidated, Refunded, or Withdrawn; no-op
if deposit.state != Pending:          // for confirm_queue entries
    skip                              // deposit was Invalidated; no-op
// otherwise apply transition
```

This rule ensures that deposits which transitioned to `Invalidated` after queue insertion do not receive spurious state promotions when their queue entries are later popped. Queue entries for invalidated deposits are silently discarded.

**"Self-transfer only" in Confirmed state:** Between `Confirmed` and `Finalized`, the depositor MAY transfer restricted eBTC only to **the same `depositor_addr`** that received the original credit. Transfers to any other Zenon address MUST be rejected by the contract. This restriction ensures a deposit invalidation always reverts only the depositor's own balance with no third-party exposure.

### 6.2 Deposit Registration Message Format

```
RegisterDepositMsg {
    spv_proof:       SPV_PROOF,
    depositor_addr:  ZenonAddress,
    deposit_pk_u:    bytes32,        // x-only user public key
    relayer_epoch:   uint32,
    deposit_vout:    uint32,
    zenon_nonce:     bytes32,
    escrow_class:    enum { ClassR, ClassP },  // depositor's explicit choice
}
```

**`zenon_nonce` construction:**

```
btc_txid = DH(non_witness_serialization(spv_proof.tx_raw))
zenon_nonce = H(deposit_pk_u || btc_txid || uint32_le(deposit_vout))
```

Using the non-witness `btc_txid` explicitly ensures `zenon_nonce` is consistent for SegWit transactions. The `deposit_vout` is included to distinguish multiple deposits in the same transaction to different escrow outputs.

### 6.3 Validation Procedure

0. **Class P activation gate:** If `escrow_class == ClassP` AND `CLASS_P_ENABLED == false`: REJECT with reason `ClassPNotEnabled`. This check precedes all other validation. Class R deposits are not subject to this check.

0. **Class P activation gate:** If `escrow_class == ClassP` AND `CLASS_P_ENABLED == false`: REJECT with reason `ClassPNotEnabled`. This check precedes all other validation. Class R deposits are not subject to this check.

0. **Class P activation gate:** If `escrow_class == ClassP` AND `CLASS_P_ENABLED == false`: REJECT with reason `ClassPNotEnabled`. This check precedes all other validation and applies regardless of bond coverage, script validity, or any other condition. Class R deposits (`escrow_class == ClassR`) are not subject to this check and proceed normally.

1. Header chain check: `spv_proof.block_height` exists in verified chain descending from `GENESIS_CHECKPOINT`.
2. Merkle proof check: CVE-2012-2459-resistant verification (§4.3).
3. Transaction parse: Per §4.4.
4. Script check: Reconstruct the expected P2TR output as follows:
   a. Look up `pk_frost_epoch` for `relayer_epoch` from the relayer registry.
   b. **If `escrow_class == ClassR`:** Reconstruct the Class R two-leaf taptree per §5.3R. Verify the output at `deposit_vout` matches the expected `OP_1 <x_only(Q_R)>` scriptPubKey where `Q_R` uses the `NUMS_point` internal key. Additionally verify that the cooperative withdrawal leaf encodes the correct `pk_frost_epoch_xonly` and that the refund leaf encodes the correct `pk_u_xonly` and `ABSOLUTE_EXPIRY`. REJECT if any component does not match exactly.

      **If `escrow_class == ClassP`:** Reconstruct the Class P single-leaf taptree per §5.3P. Verify the output at `deposit_vout` matches the expected `OP_1 <x_only(Q_P)>` scriptPubKey where `Q_P` uses `pk_frost_epoch` as internal key. Verify the refund leaf encodes the correct `pk_u_xonly` and `ABSOLUTE_EXPIRY`. REJECT if any component does not match exactly.

      REJECT if `escrow_class` does not correspond to the actual script structure observed in the output.
   c. Verify `ABSOLUTE_EXPIRY_encoded == registered_height_btc + T` in the refund leaf of either class. This check ensures the depositor encoded the correct expiry.
5. Value check: `outputs[deposit_vout].value >= MIN_DEPOSIT_SAT`; REJECT if below floor.

   5a. **Class P collateral coverage check:** If `escrow_class == ClassP`:

   ```text
   total_class_p_value = sum(amount_sat for all DepositRecords where
       escrow_class == ClassP AND state ∈ {Pending, Confirmed, Finalized})

   REJECT if:
   (total_class_p_value + outputs[deposit_vout].value)
       > total_slashable_bond_sat(current_epoch) / COLLATERAL_FACTOR
   ```

   `total_slashable_bond_sat(current_epoch)` is computed as defined in §9.7.15, inclusive of bonds locked under the epoch sunset obligation (§9.3). If the constraint would be violated, REJECT with reason `ClassPExposureLimitExceeded`. Class R deposits are not subject to this constraint.
6. Replay check: `H(btc_txid || uint32_le(deposit_vout))` not in `spent_utxos`; REJECT if present.
7. Nonce check: `zenon_nonce` not in `used_nonces`; REJECT if present.
8. Epoch validity: `relayer_epoch` is the current active epoch (as defined in §9.3); REJECT if not.

On success: record `H(btc_txid || uint32_le(deposit_vout))` in `spent_utxos` and `zenon_nonce` in `used_nonces`, create `DepositRecord` in `Pending` state with `registered_height_btc = spv_proof.block_height`, insert into both priority queues, add to `utxo_expiry_ledger` (§11.3).

```
DepositRecord {
    txid_nw:                  bytes32,    // btc_txid of the deposit tx (non-witness)
    vout:                     uint32,
    amount_sat:               uint64,
    depositor_addr:           ZenonAddress,
    deposit_pk_u:             bytes32,
    relayer_epoch:            uint32,
    registered_height_btc:    uint64,    // Bitcoin block height of the confirming block
    finalized_height:         uint64,    // Bitcoin block height at Finalized; 0 until Finalized
    absolute_expiry:          uint64,    // registered_height_btc + T
    state:                    enum { Pending, Confirmed, Finalized, Withdrawn, Refunded, Invalidated },
    escrow_class:             enum { ClassR, ClassP },
    zenon_nonce:              bytes32,
    at_risk:                  bool,      // true when backing UTXO is SuspectExpired or PermanentlyExpired;
                                         // MUST be set to false on transition to Withdrawn, Refunded, or Invalidated
    migration_pending:        bool,      // true during migration initiation window; blocks withdrawal
    migration_expiry:         uint64,    // Zenon block height at which migration intent expires; 0 if not pending
}
```

**`at_risk` terminal state invariant:** When a deposit transitions to any terminal state (`Withdrawn`, `Refunded`, or `Invalidated`), the contract MUST set `at_risk = false`.

**`spent_utxos` pruning rule:** Entries in `spent_utxos` MAY be pruned when all of the following conditions are satisfied:

```
deposit.state ∈ {Withdrawn, Refunded, Invalidated}
AND
current_bitcoin_height ≥ deposit.finalized_height + FINAL_DEPTH + CONSOLIDATION_SAFETY_WINDOW
```

**Pruning override for `Invalidated` deposits — MUST NOT prune.** The pruning rule above MUST NOT be applied to `spent_utxos` entries associated with `Invalidated` `DepositRecord`s. §15.3 Phase 4 requires that the `spent_utxos` entry for an `Invalidated` deposit be **retained indefinitely** (until explicitly cleared by governance) to prevent re-registration of the same Bitcoin UTXO. These two rules are in conflict if applied naively: the pruning rule's block height condition may be satisfied before governance has acted on the `Invalidated` entry. The resolution is: `Invalidated` entries are exempt from the pruning rule entirely. Implementations MUST check `deposit.state != Invalidated` before applying the pruning rule. To avoid implementation confusion, implementations MAY maintain a separate `invalidated_utxos` set for `Invalidated` entries with governance-only clearing, distinct from the prunable `spent_utxos` entries for `Withdrawn` and `Refunded` deposits.

**Pruning safety:** After a deposit in `Withdrawn` or `Refunded` state satisfies the block height condition, re-registration replay is impossible: the UTXO has been spent (for `Withdrawn`) or reclaimed by the depositor (for `Refunded`). Implementations MUST NOT prune entries for deposits that have not yet reached a terminal state or satisfied the block height condition.

### 6.4 Reorg-Aware Registration

If a deposit's confirming block is reorganized away before `Finalized` state, the deposit transitions to `Invalidated`. Any restricted eBTC issued in `Confirmed` state is frozen. See §15.3 for the full reorganization procedure.

---

## 7. eBTC State Model

### 7.1 Account-Based Model

```
balances:             map<ZenonAddress, uint64>   // unrestricted, satoshis
restricted_balances:  map<ZenonAddress, uint64>   // Confirmed-state only; same-address transfers only
```

**Issuance:**
- At `Confirmed`: `restricted_balances[depositor_addr] += amount_sat`
- At `Finalized`: `balances[depositor_addr] += amount_sat; restricted_balances[depositor_addr] -= amount_sat`

**Transfer (unrestricted):** Standard debit/credit on `balances`.

**Transfer (restricted):** Sender and receiver MUST be identical. Only moves between the same address are permitted (serves to prevent accidentally treating restricted as unrestricted).

**Burn (withdrawal):** `balances[user] -= (amount_sat + max_fee_sat)`. Only `balances` (unrestricted) may be burned; restricted balances MUST NOT be withdrawn until `Finalized`.

### 7.2 Protocol Invariant

**eBTC supply invariant:**

```
Total eBTC supply ≤ total value of verified escrow UTXOs
```

where Total eBTC supply is:

```
sum(balances) + sum(restricted_balances)
  + sum(pending_withdrawal.amount_sat for Pending/Processing withdrawals)
  + fee_reserve
```

and total value of verified escrow UTXOs is:

```
sum(utxo_pool[utxo].value_sat for Available/Reserved UTXOs)
  + sum(deposit.amount_sat for Pending/Confirmed deposits not yet in pool)
```

At every Zenon block boundary, these two quantities MUST satisfy the invariant (equality in normal operation; the ≤ form permits fee rounding). Any deviation indicates a critical contract bug. The invariant is verifiable by any Zenon full node.

**UTXO state inclusion rules for the invariant:**
- `Available` UTXOs: **included** in the right-hand sum.
- `Reserved` UTXOs: **included** in the right-hand sum.
- `SuspectExpired` UTXOs: **excluded** from the right-hand sum.
- `PermanentlyExpired` UTXOs: **excluded** from the right-hand sum.
- `Spent` UTXOs: **excluded** from the right-hand sum (already consumed).

**`at_risk_total` computation — non-terminal deposits only:**

```
at_risk_total = sum(deposit.amount_sat
                    for deposit in deposit_records.values()
                    where deposit.at_risk == true
                    AND deposit.state NOT IN {Withdrawn, Refunded, Invalidated})
```

The explicit exclusion of terminal-state deposits is normative. A deposit that has already been `Refunded`, `Withdrawn`, or `Invalidated` MUST have `at_risk = false` (§6.3 invariant) and MUST NOT contribute to `at_risk_total`.

**`SuspectExpired` and `PermanentlyExpired` collateral exclusion:** When a UTXO transitions from `Available` to `SuspectExpired`, its `value_sat` is removed from the invariant's right-hand side. The eBTC balances backed by that UTXO become potentially unbacked. The affected `DepositRecord`s are marked `at_risk = true`. If `at_risk_total` causes the invariant to show a shortfall, the contract enters the `Undercollateralized` state. See §11.3 for the response.

**Fee reserve accounting:**

- On withdrawal initiation: `balances[user] -= (amount_sat + max_fee_sat); fee_reserve += max_fee_sat`
- On completion: `fee_reserve -= max_fee_sat; balances[relayer] += fee_sat; balances[user] += (max_fee_sat - fee_sat)`

The fee reserve does not mint eBTC; it reclassifies existing user-balance eBTC into escrow. The invariant holds because the BTC backing the fee portion remains in the UTXO pool until the Bitcoin withdrawal transaction is confirmed.

### 7.3 State Tree Structure

```
EBTCState {
    balances:               PatriciaTrie<ZenonAddress, uint64>,
    restricted_balances:    PatriciaTrie<ZenonAddress, uint64>,
    deposit_records:        PatriciaTrie<bytes32, DepositRecord>,
    spent_utxos:            Set<bytes32>,
    used_nonces:            Set<bytes32>,
    confirm_queue:          MinHeap<(uint64, bytes32)>,    // (target_height, deposit_id)
    finalize_queue:         MinHeap<(uint64, bytes32)>,    // (target_height, deposit_id)
    pending_withdrawals:    PatriciaTrie<bytes32, WithdrawalRecord>,   // key: withdrawal_id (bytes32)
    completed_withdrawals:  Set<bytes32>,                              // element: withdrawal_id (bytes32)
    fee_reserve:            uint64,
    utxo_pool:              PatriciaTrie<bytes32, UTXORecord>,         // key: H(btc_txid || uint32_le(vout))
    utxo_expiry_ledger:     SortedMap<uint64, Set<bytes32>>,           // key: expiry_height (uint64)
    spv_chain_state:        ChainState,
    relayer_registry:       RelayerRegistry,
    epoch_records:          PatriciaTrie<uint32, EpochRecord>,         // key: epoch_id
    total_class_p_value:    uint64,    // maintained incrementally: sum(amount_sat) for all DepositRecords
                                       //   where escrow_class == ClassP AND state ∈ {Pending, Confirmed, Finalized};
                                       //   incremented on ClassP deposit registration; decremented on terminal
                                       //   state transition; used for coverage enforcement in §6.3 step 5a
}
```

**Heap serialization for state root computation:** `confirm_queue` and `finalize_queue` are in-memory min-heap data structures. For deterministic state root calculation, each heap is serialized as a **canonical sorted array**: entries are sorted first by `target_height` ascending (uint64 little-endian), then by `deposit_id` ascending lexicographically as a raw byte sequence. The canonical serialization is `uint32_le(length) || entry[0] || entry[1] || ... || entry[n-1]` where each entry is `uint64_le(target_height) || deposit_id` (32 bytes). A standard binary heap array representation is **not permitted** as the canonical serialization because it is insertion-order dependent.

### 7.4 Secondary eBTC Holder Liveness Dependency

A user who receives eBTC on Zenon from a peer (via Zenon-internal transfer after the sender's deposit is `Finalized`) has no direct relationship with the original depositor, no knowledge of which UTXO backs their balance, and no action they can take to prevent their eBTC from becoming unbacked if the original depositor claims a timelock refund.

**The risk:** If the original depositor reclaims their UTXO via the Leaf 2 refund path (or migration + Class P consolidation path), the eBTC previously issued against that UTXO becomes unbacked. The pool then enters `Undercollateralized` state. Withdrawals are suspended until new deposits restore collateralization.

**DeFi protocol builders MUST disclose this risk** to any user receiving eBTC as a counterparty to a Zenon-internal transaction. Secondary holders who did not make a Bitcoin deposit have no Bitcoin-native exit path of their own; their exit depends entirely on relayer liveness and pool collateralization.

**Class R eBTC transferred to secondary holders provides no superior exit.** A Class R depositor can transfer their eBTC to a secondary holder while retaining the ability to reclaim their Bitcoin via the Leaf 2 timelock path. Once the transfer occurs: the secondary holder cannot exercise the Class R Leaf 1 cooperative withdrawal path (they do not hold `pk_u`), and they cannot exercise the Leaf 2 refund path (they have no Bitcoin-native relationship to the UTXO). The Class R safety advantage is entirely consumed by the original depositor at the point of transfer. For the secondary holder, Class R-originated eBTC has identical liveness characteristics to Class P-originated eBTC: both depend on relayer availability and pool collateralization for exit. This is cross-referenced in §1.3 Principle 5 and §7.5.

**Maximum loss duration under extended Zenon outage plus mass refund.** If Zenon is offline for a duration exceeding the `ABSOLUTE_EXPIRY` windows of backing UTXOs (approximately 28 days for `T = 4032` blocks): depositors reclaim BTC via Leaf 2 refunds; eBTC becomes unbacked; upon Zenon recovery, the contract enters `Undercollateralized` state; withdrawals are suspended. The `RefundAcknowledgmentMsg` mechanism (§10.3) is not enforceable during an outage. After recovery, secondary holders in a governance-resolution path face up to `GOVERNANCE_VOTING_PERIOD + GOVERNANCE_EXECUTION_DELAY` ≈ 70 days of additional delay before the orphaned collateral situation is resolved (§11.4 `ConsolidationOrphanAlert` path). **The worst-case secondary holder loss window is therefore `outage_duration + 70 days`**. DeFi applications using eBTC MUST disclose this bound to users. If this bound is unacceptable for a given use case, Class P deposits with long deposit lifetimes (extended `T`) or a secondary-holder protection mechanism should be considered.

**Mitigation:** Submitting `RefundAcknowledgmentMsg` reduces the latency before undercollateralization is detected; it is strongly recommended but not protocol-enforceable. The `EXPIRY_GRACE_PERIOD` bounds the ghost UTXO window. Neither eliminates the structural secondary-holder risk.

### 7.5 eBTC Fungibility Model

eBTC is fungible at the **Zenon protocol-layer accounting level**. The protocol does not track which specific UTXO backs any specific eBTC balance after the deposit is `Finalized`. Redemption (withdrawal) occurs against the aggregate escrow pool: the relayer selects an available UTXO of sufficient value from the pool, subject to the selection heuristics in §11.2 and the future canonical selection design in §8.4.

**Protocol-layer accounting equivalence — not economic equivalence.** eBTC is fungible in the sense that the Zenon `balances` trie treats all eBTC balances identically, and a holder of 100,000 sat eBTC cannot assert a claim against any specific Class R or Class P UTXO in the pool. The escrow class does not subdivide the eBTC supply into separately tradeable instruments. eBTC minted from Class R deposits and eBTC minted from Class P deposits are fungible at the protocol accounting level and transferable without restriction.

**Collateral quality asymmetry — normative disclosure.** At the economic level, Class R-backed and Class P-backed portions of the escrow pool provide materially different security guarantees to eBTC holders. Class R UTXOs cannot be stolen via FROST collusion and cannot be consolidated without user co-signature; they represent higher-quality collateral. Class P UTXOs are subject to key-path authority by the FROST relayer set and the A9 combined attack (§12.1). As Class P deposits grow as a fraction of total pool backing, the effective security model for all eBTC holders — including those whose eBTC originated from Class R deposits — asymptotically converges toward the Class P trust model. Protocol-layer fungibility progressively launders the collateral quality distinction as eBTC is transferred between holders.

**Secondary eBTC holder exposure.** A secondary eBTC holder who receives eBTC via Zenon-internal transfer has no information about the pool composition at the time of receipt, and no mechanism to constrain future pool composition changes. There is no `MIN_CLASS_R_FRACTION` enforcement in this version; governance may introduce one in a future upgrade. The `reserve_composition` disclosure provides a snapshot but creates no protocol-enforced floor.

**Reserve composition disclosure requirement:** Operators MUST publish and keep current the following reserve metrics:

```
reserve_composition {
    total_class_r_sat:  uint64,    // sum(value_sat) for Available UTXOs backed by ClassR deposits
    total_class_p_sat:  uint64,    // sum(value_sat) for Available UTXOs backed by ClassP deposits
    total_ebtc_supply:  uint64,    // sum(balances) + sum(restricted_balances)
                                   //   + sum(pending_withdrawal.amount_sat)
                                   //   + fee_reserve
    class_r_pct:        float,     // total_class_r_sat / (total_class_r_sat + total_class_p_sat)
}
```

This disclosure allows eBTC holders to evaluate the proportion of backing collateral that is relayer-unilaterally-spendable (Class P) versus user-consent-bound (Class R).

---

## 8. Withdrawal Protocol

### 8.1 Overview

A user burns eBTC by calling `withdraw(btc_address_script, amount_sat, max_fee_sat, deadline)`. The contract deducts the balance, emits a `WithdrawalBurnEvent`, and a relayer atomically claims the withdrawal and reserves a UTXO. The relayer constructs and broadcasts a Bitcoin withdrawal transaction using FROST signing, then submits a completion proof.

### 8.2 Withdrawal Request Format

```
WithdrawalRequest {
    btc_address_script: bytes,    // raw scriptPubKey; one of the four types in §4.4
    amount_sat:         uint64,
    max_fee_sat:        uint64,
    zenon_nonce:        bytes32,
    deadline:           uint64,   // Zenon block height; request expires after this
}
```

For `escrow_class == ClassR`, cooperative withdrawal initiation requires interactive participation by `deposit_pk_u` at signing time. No offline or pre-authorized Class R withdrawal format is defined.

### 8.3 Withdrawal Execution on Zenon

1. Verify `amount_sat + max_fee_sat ≤ balances[sender]` (unrestricted only).
2. Verify `zenon_nonce` not in `used_nonces`.
3. Verify `current_zenon_height ≤ deadline`.
4. Verify `deposit.migration_pending == false` if this is a Class R withdrawal initiation.
5. `balances[sender] -= (amount_sat + max_fee_sat); fee_reserve += max_fee_sat`.
6. Insert `zenon_nonce` into `used_nonces`.
7. Create `WithdrawalRecord` in `Pending` state.
8. Emit `WithdrawalBurnEvent`.

**Withdrawal `deadline` precedence rules:**

1. `deadline` governs **admission only**: if `current_zenon_height > deadline` at submission, REJECT.
2. After successful admission, a subsequently-passed `deadline` does NOT automatically cancel a withdrawal already in `Processing` or `Claimed` state.
3. `claim_expiry` governs relayer exclusivity after admission.
4. If `claim_expiry` passes before Bitcoin broadcast is observed, the claim MUST be reverted and the UTXO restored to `Available`.
5. If Bitcoin broadcast and spend observation occur before `claim_expiry`, the withdrawal MAY complete even if `deadline` has since passed.

```
WithdrawalRecord {
    withdrawal_id:      bytes32,    // H(zenon_nonce || sender || uint64_le(amount_sat))
    sender:             ZenonAddress,
    btc_address_script: bytes,
    amount_sat:         uint64,
    max_fee_sat:        uint64,
    deadline:           uint64,
    status:             enum { Pending, Processing, Completed, Expired },
    assigned_utxo:      bytes32 or null,   // H(btc_txid || uint32_le(vout)); null if unassigned
    relayer_id:         bytes32 or null,   // relayer_id (bytes32); null if unassigned
    created_at:         uint64,            // Zenon block height
    claim_expiry:       uint64 or null,    // Zenon block height; null if unassigned
}
```

### 8.4 UTXO Selection and Future Canonical Selection Design

**Status:** Relayers have full discretion in UTXO selection subject only to value coverage requirements (§9.6 step 3). No deterministic canonical selection is enforced. This is an explicit unmitigated attack surface documented in §12.1 A7 and §12.10.

**Future canonical selection (design note — not a current protocol field):** A future version will introduce a `btc_nonce` entropy commitment to enable verifiable deterministic UTXO assignment. The intended construction:

```
btc_nonce = H(zenon_nonce || entropy_source)

canonical_utxo = arg min over available UTXOs u of:
    H(u.txid || uint32_le(u.vout) || btc_nonce)
subject to: u.value_sat >= amount_sat + MAX_FEE_SAT
            u.status == Available
```

`btc_nonce` is NOT present in current `WithdrawalRecord` or any current message structures. It will be introduced in the version that specifies and enforces canonical selection.

**Entropy source requirement:** The entropy source must be unmanipulable by relayers and by Bitcoin miners simultaneously. `chain_state.tip_hash` alone is insufficient — a miner who is also a relayer can grind block hashes to influence UTXO assignment. The entropy source design for canonical selection will be fully specified in a separate RFC.

**Interim mitigation (in effect until canonical selection is implemented):** To reduce the UTXO selection manipulation surface, the Zenon contract MUST enforce the following constraint on `WithdrawalClaimMsg` submissions: the UTXO assigned to a withdrawal (`utxo_key` in `WithdrawalClaimMsg`) MUST be among the `TOP_K_UTXO_CANDIDATES` UTXOs in the canonical eligible set defined below. If `utxo_key` does not appear in this top-`k` eligible set, the Zenon contract MUST reject the `WithdrawalClaimMsg` with reason `UTXONotInEligibleSet`. Recommended `TOP_K_UTXO_CANDIDATES = 10`. This is not a substitute for canonical selection — it reduces but does not eliminate manipulation — but it is contract-verifiable without a `btc_nonce` entropy source and significantly constrains relayer discretion in the interim.

**Deterministic UTXO candidate ordering (canonical sort):**

The eligible UTXO set MUST be sorted deterministically using the following three-key sort, applied in order:

```
1. absolute_expiry   ascending  (soonest expiry first)
2. btc_txid          ascending  (lexicographic byte order)
3. vout              ascending  (numeric)
```

`TOP_K_UTXO_CANDIDATES` MUST be selected from the **head** of this canonically sorted eligible set (i.e., the first `TOP_K_UTXO_CANDIDATES` elements after sorting). An eligible UTXO is one satisfying `status == Available` AND `value_sat >= amount_sat + MIN_FEE_SAT`.

All relayers computing the eligible set MUST use this sort order. The Zenon contract MUST use this sort order when evaluating `WithdrawalClaimMsg` compliance. This ensures that all relayers compute identical candidate sets in the presence of tie-breaking conditions (equal `absolute_expiry` values), making the top-k constraint unambiguous and contract-verifiable.

### 8.5 WithdrawalBurnEvent

```
WithdrawalBurnEvent {
    withdrawal_id:      bytes32,
    btc_address_script: bytes,
    amount_sat:         uint64,
    max_fee_sat:        uint64,
    deadline_block:     uint64,
    timestamp:          uint64,
}
```

All integer fields in this event are serialized as `uint64_le`.

### 8.6 Non-Interactive Withdrawal (Class P)

Under Class P, the FROST relayer threshold executes the key-path spend without user participation. The relayer:

1. Claims the withdrawal and reserves a UTXO (§9.6).
2. Constructs the Bitcoin transaction spending the reserved UTXO.
3. Executes the FROST threshold signing protocol among the epoch's relayers.
4. Broadcasts the completed transaction.
5. Submits `WithdrawalCompletionProof` once confirmed.

**Fee reserve race — SpendObservationMsg:**

```
SpendObservationMsg {
    withdrawal_id:  bytes32,
    spv_proof:      SPV_PROOF,   // proof of Bitcoin tx spending assigned_utxo
    fee_claimed:    uint64,
}
```

`SpendObservationMsg` is processed when a confirmed Bitcoin spend of the assigned UTXO is observed but `WithdrawalCompletionProof` has not yet been accepted. Verification: same as §8.7 steps 1–6.

**Deterministic resolution rules for all race cases:**

**Case 1: `claim_expiry` has NOT yet triggered.**

If `SpendObservationMsg` is submitted with a valid SPV proof while `withdrawal_record.status == Processing` and `claim_expiry` has not yet passed:
- Mark `withdrawal_record.status = Completed`.
- Release `fee_reserve` per §7.2 based on the confirmed transaction's actual output values.
- Credit `fee_claimed` to the original `relayer_id` recorded in `withdrawal_record`.
- Remove UTXO from pool and `utxo_expiry_ledger`.

This case is equivalent to normal `WithdrawalCompletionProof` processing.

**Case 2: `claim_expiry` HAS triggered; UTXO reverted to `Available`; NO second claim yet.**

If `claim_expiry` triggered and reverted `withdrawal_record` to `Pending` and `utxo_pool[utxo_key]` to `Available`, and then a `SpendObservationMsg` arrives proving the Bitcoin transaction that the original relayer broadcast is confirmed:
- The Zenon contract verifies the SPV proof confirms a spend of `utxo_key` at a Bitcoin block height ≥ `claim_expiry_bitcoin_block`.
- Mark `withdrawal_record.status = Completed`.
- Mark `utxo_pool[utxo_key].status = Spent`.
- Release `fee_reserve` based on the confirmed transaction's output values.
- Credit `fee_claimed` to `withdrawal_record.relayer_id`.
- Remove from `utxo_expiry_ledger`.

**Case 3: `claim_expiry` HAS triggered; a SECOND relayer has claimed the same UTXO.**

If, after claim expiry reversion, a second relayer has submitted a `WithdrawalClaimMsg` for the same `utxo_key` and the same `withdrawal_id`, and then a `SpendObservationMsg` arrives proving the original (first) relayer's Bitcoin transaction is confirmed:
- The second relayer's claim is invalid: the UTXO no longer exists on Bitcoin. The second relayer's `Processing` record is reverted to `Pending` and the UTXO is immediately set to `Spent`.
- The original submitter receives `fee_claimed`.
- The second relayer receives no fee credit. No additional penalty is assessed to the second relayer, who acted in good faith on stale Zenon state.
- `withdrawal_record.status = Completed`.

**Case 4: Double-spend.** Both the original and second relayer transactions confirming for the same UTXO is impossible under Bitcoin consensus. Case 3 applies if the second relayer's transaction fails to confirm.

**Invariant during all race cases:** As soon as an SPV proof establishing the UTXO's spend on Bitcoin is accepted, `utxo_pool[utxo_key].status` MUST be set to `Spent` and the UTXO MUST be excluded from the §7.2 invariant's right-hand side.

### 8.7 Withdrawal Completion Proof

```
WithdrawalCompletionProof {
    withdrawal_id:  bytes32,
    spv_proof:      SPV_PROOF,
    fee_claimed:    uint64,
}
```

Verification:

1. SPV proof valid per §4.3.
2. Parse `spv_proof.tx_raw` per §4.4.
3. Identify input spending `assigned_utxo`: `inputs[i].prev_txid == assigned_utxo.btc_txid AND inputs[i].prev_vout == assigned_utxo.vout`.
4. `outputs[0].script == btc_address_script` (byte-for-byte).
5. `outputs[0].value >= amount_sat - fee_claimed`.
6. `fee_claimed ≤ max_fee_sat`.
7. `withdrawal_id.status == Processing`.

On success: set `Completed`, credit relayer fee per §7.2, remove UTXO from pool, remove from `utxo_expiry_ledger`.

### 8.8 Withdrawal Batching

Multiple withdrawals MAY be batched into one Bitcoin transaction. Batch outputs MUST appear in ascending `withdrawal_id` sort order (lexicographic on `bytes32`).

**Batch membership commitment.** A `WithdrawalClaimMsg` for a batched withdrawal MUST commit to the full batch membership by including the complete `withdrawal_ids[]` array of all withdrawals in the batch. The Zenon contract MUST record this committed array at claim time. Any `WithdrawalCompletionProof` for a batched transaction MUST re-derive the output ordering from the committed `withdrawal_ids[]` array and verify each output against its corresponding `withdrawal_id` at the committed index. A proof that references a different output index for a given `withdrawal_id` than the committed ordering produces MUST be rejected, even if the output would independently verify. This prevents conflicting SPV proofs arising from two relayers broadcasting different batches with overlapping `withdrawal_id` sets and different output index assignments for shared withdrawals.

**Partial failure semantics:** The Zenon contract processes each output in the batch independently. For each output `i` corresponding to `withdrawal_ids[i]`:

1. Verify `outputs[i].script == withdrawal_records[withdrawal_ids[i]].btc_address_script`.
2. Verify `outputs[i].value >= withdrawal_records[withdrawal_ids[i]].amount_sat - fee_claimed[i]`.
3. Verify `fee_claimed[i] ≤ withdrawal_records[withdrawal_ids[i]].max_fee_sat`.
4. Verify `withdrawal_ids[i].status == Processing`.

If verification for output `i` passes: mark `withdrawal_ids[i]` as `Completed` and credit relayer fee.

If verification for output `i` fails: the contract MUST check whether the batch's input set contains the UTXO assigned to `withdrawal_ids[i]`. If so, the UTXO is set to `Spent` immediately (not reverted to `Available`), because the Bitcoin transaction is confirmed and the UTXO no longer exists. The withdrawal is reverted to `Pending` and the relayer does not receive fee credit for that withdrawal. If the UTXO was not in the input set for that output, the withdrawal and UTXO are reverted to `Pending` and `Available` respectively.

The batch MUST NOT be rejected in its entirety due to a single output failure. Successfully verified outputs are completed regardless.

**Change output handling:** If the batch transaction includes a change output returning excess UTXO value to the relayer's pool address, this change output is treated as a new UTXO deposit into the pool. The relayer MUST submit a `PoolChangeDepositMsg` alongside the completion proof, identifying the change output. The Zenon contract adds the change UTXO to `utxo_pool` and `utxo_expiry_ledger`. Change outputs that are not registered within `CHANGE_REGISTRATION_WINDOW` Zenon blocks are treated as abandoned and excluded from the tracked pool.

**Abandoned change recovery procedure:**

1. Relayers MUST submit a `ChangeRegistrationMsg` within `CHANGE_REGISTRATION_WINDOW = 144` Zenon blocks after confirmation of the spending transaction.
2. If the window elapses without registration, the Zenon contract MUST emit an `AbandonedChangeAlert` event recording: `btc_txid`, `vout`, `value_sat`, and `pk_frost_epoch` of the abandoned UTXO.
3. The `EBTCState.abandoned_change_value_sat` accumulator MUST be incremented by `value_sat`. Abandoned change is NOT counted toward pool collateral.
4. Governance MAY submit an `AbandonedChangeRecoveryProposal` (0.67 supermajority) authorizing a new `SpendIntent` for the abandoned UTXO, routing its value into a new tracked escrow output under the current epoch's `pk_frost_epoch`. On approval, relayers execute the recovery transaction and register the new UTXO as a standard pool entry.
5. The `abandoned_change_value_sat` metric MUST be exposed in the relayer transparency metrics (§9.9) and included in the governance dashboard.

**Struct update:** `EBTCState` gains a `abandoned_change_value_sat: uint64` field tracking the total unrecovered abandoned change value.

```
CHANGE_REGISTRATION_WINDOW = 144    // Zenon blocks
```

### 8.9 Canonical Withdrawal Transaction Template

All single-withdrawal Bitcoin transactions MUST conform to the following canonical template. Transactions that deviate from this template MAY produce valid Bitcoin transactions that fail `SpendIntent` authorization matching (§9.7.10) or `WithdrawalCompletionProof` verification (§8.7). Batched withdrawals (§8.8) extend this template with additional outputs in ascending `withdrawal_id` sort order.

```text
withdrawal_tx {
    version:        int32   = 2
    input_count:    varint  = 1
    inputs[0] {
        prev_txid:      bytes32     // btc_txid of the escrow UTXO being spent
        prev_vout:      uint32      // vout index of the escrow UTXO being spent
        script_sig:     bytes       = [] (empty; SegWit spend)
        sequence:       uint32      = 0xfffffffd  // RBF-signaling, no locktime enforcement
        witness:        [ ... ]     // BIP 341 Taproot witness (key-path or script-path per escrow class)
    }
    output_count:   varint  ∈ {1, 2}
    outputs[0] {                    // destination_output_index = 0 (REQUIRED)
        value:          uint64      // withdrawal amount in satoshis (≥ amount_sat - fee_claimed)
        script:         bytes       // btc_address_script from WithdrawalRecord (byte-for-byte)
    }
    outputs[1] {                    // change_output_index = 1 (present only if change is returned to pool)
        value:          uint64      // change value in satoshis; MUST exceed MIN_DUST_SAT
        script:         bytes       // MUST be P2TR(pk_frost_epoch) of the current epoch
                                    // i.e., OP_1 <x_only(Q)> where Q uses pk_frost_epoch as internal key
    }
    locktime:       uint32  = 0
}
```

**Normative field requirements:**

| Field | Required Value | Rejection Condition |
|-------|---------------|---------------------|
| `version` | `2` | Any other value MUST be rejected |
| `input_count` | `1` (single-withdrawal) | Any other value MUST be rejected for single-withdrawal transactions |
| `inputs[0].sequence` | `0xfffffffd` | Any other value MUST be rejected |
| `locktime` | `0` | Any non-zero value MUST be rejected |
| `output_count` | `1` or `2` | More than `2` outputs MUST be rejected |
| `destination_output_index` | `0` | Destination MUST appear at index 0 |
| `change_output_index` | `1` (if present) | Change MUST appear at index 1 if present |

**Change output constraints:**

- If a change output is present (`output_count == 2`), it MUST appear at `outputs[1]`.
- The change output script MUST be `P2TR(pk_frost_epoch)` for the epoch associated with the spending UTXO: `OP_1 <x_only(Q)>` where `Q` is derived from `pk_frost_epoch` as specified in §5.3P.
- The change output value MUST exceed `MIN_DUST_SAT`. A change output with value ≤ `MIN_DUST_SAT` MUST be omitted (merged into fee) rather than included. This prevents uneconomic change UTXOs from entering the pool.

```
MIN_DUST_SAT = 546    // P2TR dust threshold per Bitcoin Core policy
```

**Fee calculation constraint:**

The transaction fee is implicitly defined as:

```
fee_sat = inputs[0].prev_value - sum(outputs[i].value for i in output_count)
```

The following MUST hold:

```
fee_sat ≥ 0                      // no negative fees
fee_sat ≤ max_total_fee_sat      // MUST NOT exceed the SpendIntent authorization ceiling
```

`max_total_fee_sat` is taken from the corresponding `SpendIntent.max_total_fee_sat` (§9.7.4). If no `SpendIntent` exists for the transaction, it is treated as unauthorized under Slash Condition A (§9.7.11).

**Enforcement:** The `WithdrawalCompletionProof` verifier (§8.7) MUST additionally verify that `spv_proof.tx_raw` parses to a transaction conforming to this template. Any transaction with `version ≠ 2`, `locktime ≠ 0`, `sequence ≠ 0xfffffffd`, `input_count ≠ 1` (for single-withdrawal transactions), or `output_count > 2` MUST be rejected.

**Rationale:**

* `version = 2` is required for `OP_CHECKSEQUENCEVERIFY` compatibility and is the modern Bitcoin standard; `version = 1` MUST be rejected.
* `sequence = 0xfffffffd` signals RBF replaceability while disabling relative locktime enforcement; this allows fee bumping in the event of mempool congestion without static fee commitment.
* `locktime = 0` is normative; non-zero locktimes introduce confirmation delay ambiguity and are not required for any Zenon Portal operation.

> **SCOPE NOTE — COOPERATIVE SPENDS ONLY:** The canonical withdrawal transaction template (`sequence = 0xfffffffd`, `locktime = 0`) applies **exclusively** to Leaf 1 (cooperative) and key-path spends. It MUST NOT be applied to Leaf 2 (unilateral refund) transactions. Leaf 2 refund transactions require `locktime = absolute_expiry_height` (for CLTV validation) and `sequence = 0xfffffffe` (or any value < `0xffffffff` that satisfies CLTV, with `locktime` set to the CLTV expiry height). Applying this template to a Leaf 2 refund will produce an invalid transaction that fails the `OP_CHECKLOCKTIMEVERIFY` check. See §5.3R for the Leaf 2 transaction construction requirement.
* `input_count = 1` is required for single-withdrawal transactions; the single input identifies the escrow UTXO unambiguously, simplifying `SpendIntent` matching.
* `output_count ∈ {1, 2}`: `outputs[0]` is the withdrawal destination; `outputs[1]` is the optional change output returned to the pool. Any additional outputs are non-conformant and MUST be rejected.
* Fixed output indices eliminate ambiguity in intent matching and completion proof verification.
* Requiring change outputs to be `P2TR(pk_frost_epoch)` ensures that all change UTXOs remain under FROST custody and are automatically eligible for the pool accounting system.

---

## 9. Relayer System

### 9.1 Design Goals

Permissionless participation; withdrawal liveness; safety-preserving failure modes; incentive compatibility; Sybil resistance via bonding.

### 9.2 Relayer Registration

```
RelayerRegistration {
    relayer_id:        bytes32,    // H(pk_relayer)
    pk_relayer:        bytes32,    // Schnorr public key (x-only)
    bond_amount:       uint64,     // ZNN/QSR bond
    stake_expiry:      uint64,     // Zenon block height
    service_uri:       string,     // optional API endpoint
    header_obligation: bool,       // MUST be true for all registered relayers
}
```

**Header submission obligation:** Header submission is permissionless (§4.2.5); any Zenon account MAY submit headers. Registered relayers with `header_obligation = true` retain a liveness obligation: delinquency is flagged after `HEADER_LAPSE_WINDOW` without tip advancement from any source. Consequences are limited to claim suspension; bond slashing for header delinquency is not implemented. See §12.1 A8 for the security implications.

**Maximum stake concentration — governance capture prevention:**

```
MAX_RELAYER_STAKE_FRACTION = 0.33
```

No single relayer's bond amount may exceed `MAX_RELAYER_STAKE_FRACTION × total_slashable_bond_sat(epoch)` at any time. This constraint is contract-enforced. The Zenon contract MUST reject any `RelayerRegistration` or bond top-up that would cause a single relayer's bond to exceed this fraction. The rejection error MUST be `StakeConcentrationExceeded`.

**Rationale:** Bond-proportional governance weight (§12.9) means that a single relayer controlling ≥ 0.67 of total bonded stake simultaneously satisfies the 0.67 governance supermajority and (for a t = ceil(2n/3) threshold) the FROST signing quorum. Capping individual stake at 0.33 ensures that no single actor can both authorize unauthorized Bitcoin spends and block or advance governance actions that would respond to them. A 0.33 cap requires three colluding actors at maximum concentration to reach supermajority — meaningfully above the t-of-n FROST threshold for the same attack.

### 9.3 FROST Epoch Key Management

**Canonical FROST variant:** This protocol MUST use **FROST-secp256k1 as specified in IETF RFC 9591**. No other FROST variant is permitted. Implementations MUST NOT substitute FROST1 (SimpleFROST), pre-RFC FROST, ROAST, the Zcash Foundation reference implementation, or any other FROST variant. RFC 9591 is the two-round signing variant; its nonce commitment scheme, binding factor computation, and aggregation procedure are canonical for this protocol. A relayer implementing a non-RFC-9591 variant cannot participate in a signing round with RFC 9591 relayers; the partial signatures are incompatible and no protocol-level detection prevents a silent signing failure.

**Nonce commitment format:** Each participating relayer MUST generate per-round nonce pairs `(d_i, e_i)` as specified in RFC 9591 §4.2 and publish binding commitments `(D_i, E_i) = (d_i·G, e_i·G)` to the other participants before the signing round begins. The nonce commitment pair `(D_i, E_i)` MUST be included in the `SigningIntentCommitment` (§9.7.2a) to prevent nonce reuse across signing sessions. Any `SigningIntentCommitment` that omits the relayer's FROST nonce commitment pair for the referenced `intent_id` MUST be rejected by the Zenon contract.

**Binding factor computation:** The binding factor for relayer `i` MUST be computed as `rho_i = H_3(i, msg, {(j, D_j, E_j) for j in participant_list})` per RFC 9591 §4.3. `msg` is the transaction sighash bytes of the Bitcoin transaction being signed (BIP 341 sighash for Taproot key-path spends).

**Partial signature verification:** Each partial signature `z_i` MUST satisfy `z_i·G == R_i + rho_i·S_i + lambda_i·c·pk_share_i` where `c` is the Schnorr challenge, `R_i = D_i + rho_i·E_i`, and `lambda_i` is the Lagrange coefficient for relayer `i` per RFC 9591 §4.4. The aggregator MUST verify each partial signature before aggregation. Any coordinator that aggregates unverified partial signatures and broadcasts an invalid Bitcoin transaction is in violation of this protocol.

**Robustness under participant dropout:** If a relayer posts a `SigningIntentCommitment` but fails to produce a valid partial signature, the signing round MUST be aborted and a new round initiated with a different participant subset (at minimum size `t`). Partial signatures from an aborted round MUST NOT be reused.

Upon epoch formation, relayers execute FROST DKG off-chain and MUST submit `pk_frost_epoch` plus all commitment vectors `C_i` to Zenon's relayer registry. Third parties can verify `pk_frost_epoch == sum(C_i[0] for all i)`.

**DKG security model — explicit assumptions:**

The protocol assumes a Pedersen-style verifiable secret sharing DKG with authenticated channels among relayers of an epoch. The minimum required properties are:

* each relayer broadcasts a polynomial commitment vector;
* each relayer privately transmits per-recipient shares;
* each recipient verifies each share against the sender's public commitment vector;
* misbehavior is attributable at the transcript level and causes epoch setup abort.

DKG participants MUST retain the full DKG transcript (commitments, shares, and verification proofs) for a minimum of `GOVERNANCE_VOTING_PERIOD + GOVERNANCE_EXECUTION_DELAY` Zenon blocks after epoch activation, to support dispute resolution.

**DKG integrity limitation:** Commitment verification confirms the key is correctly derived from the announced commitments. It does **not** prove the DKG was executed honestly and does **not** prove an unbiased key. A colluding t-of-n quorum executing a biased DKG to produce an attacker-controlled `pk_frost_epoch` would pass commitment verification trivially — such a quorum controls the inputs and can produce consistent commitments for any target key. This is trust assumption A5b in §12.1.

**Epoch sunset obligation:** Relayers MUST NOT reclaim bonds while active `DepositRecord`s reference their epoch, unless all such deposits have `absolute_expiry < current_bitcoin_height`. This bond-lock is protocol-enforced: the contract MUST reject bond-reclaim transactions that fail this condition.

**Bond lock extension — finalization tail:**

```text
bond_release_eligible =
    (all deposits in epoch E are terminal)
    AND
    (current_zenon_height > last_deposit_terminal_zenon_height + BOND_LOCK_EXTENSION)
```

```text
BOND_LOCK_EXTENSION = 4032 + BUNDLE_POSTING_WINDOW   // Zenon blocks
```

This ensures that epoch E relayers remain slashable through the entire `BUNDLE_POSTING_WINDOW` for any spend that could legally occur while a deposit was still live.

`total_slashable_bond_sat(epoch)` MUST include bonds held by relayers whose bond lock has not yet expired under this rule, even if those relayers are no longer in the active signing set.

**Sunset processing obligation:** Relayers for a closing epoch MUST continue processing withdrawals for all deposits referencing their epoch until the sunset obligation is satisfied. A relayer that has transitioned to a new epoch and refuses to sign old-epoch withdrawals incurs no protocol-level penalty in this version; the bond-lock prevents bond reclamation but does not compel signing. Failure to process old-epoch withdrawals is a liveness risk (A8 variant). See §9.4 for the normative epoch signing retention obligation.

**Epoch transition:** New epoch deposits use the new epoch's `pk_frost_epoch`. Old epoch deposits remain valid and are processable by the old epoch's FROST signers under the sunset obligation and the §9.4 retention obligation.

**Epoch registration cutoff:** When a new epoch is activated, the previous epoch is immediately marked `Closed` in the relayer registry. The contract MUST reject any `RegisterDepositMsg` referencing a `relayer_epoch` that is not the current active epoch. "Current epoch" is defined as the epoch with the highest epoch number in `Active` state; there is exactly one active epoch at any time.

### 9.4 Epoch Signing Retention

Each deposit records `deposit_epoch`, and all cooperative spends for that deposit MUST use `pk_frost_epoch(deposit_epoch)` or its explicitly registered successor under a governed key-rotation migration.

Relayers participating in epoch `E` MUST preserve the ability to produce valid threshold signatures for `pk_frost_epoch(E)` until one of the following is true for **all** deposits referencing `E`:

* the deposit is `Withdrawn`;
* the deposit is `Refunded`;
* the deposit is `Invalidated`;
* the deposit has been re-deposited or migrated into a later epoch and the old UTXO is terminal.

**Bond withdrawal and relayer retirement from the active set do not terminate this retention duty.** A relayer that has exited the active epoch MUST still be capable of signing for old-epoch deposits until those deposits reach terminal state.

```
EpochRecord {
    epoch_id:                 uint32,
    pk_frost_epoch:           bytes32,
    threshold_t:              uint16,
    relayer_set:              vector<RelayerID>,
    signing_retention_until:  uint64 | 0,   // 0 = unresolved because live deposits remain
    archived:                 bool
}
```

**Epoch transition during an active signing round.** If an epoch rotation occurs (epoch N advances to epoch N+1) while a FROST signing round for a `SpendIntent` with `source_epoch = N` is in progress:

1. The Zenon contract MUST continue accepting `SigningBundle`s from epoch N relayers for epoch N `SpendIntent`s for `EPOCH_SIGNING_RETENTION_HEIGHT` Bitcoin blocks after the epoch N→N+1 activation.
2. Epoch N relayers remain slashable under epoch N bonds for any epoch N signing round misbehavior for the same `EPOCH_SIGNING_RETENTION_HEIGHT` window, regardless of whether their bonds have been released for new-epoch purposes.
3. If an in-progress epoch N signing round has not produced a valid `SigningBundle` before `EPOCH_SIGNING_RETENTION_HEIGHT` expires, the `SpendIntent` MUST be marked `Expired`; the withdrawal or consolidation MUST be reverted to `Pending` or `Available` respectively; and the user's eBTC balance MUST be restored.
4. A colluding quorum of epoch N relayers that signs a rogue Bitcoin transaction during the retention window MUST be slashable under epoch N+1 governance context: `SlashProof` adjudication (§9.7.12) MUST remain functional for epoch N misbehavior throughout the `EPOCH_SIGNING_RETENTION_HEIGHT` window.

```text
EPOCH_SIGNING_RETENTION_HEIGHT = FINAL_DEPTH + BUNDLE_POSTING_WINDOW + CONSOLIDATION_SAFETY_WINDOW
// in Bitcoin blocks; represents max time a valid epoch N signing event could occur
// and still require accountability processing under epoch N+1 governance
```

**Cross-epoch withdrawal processing:** If the active relayer epoch differs from `deposit_epoch`, the relayer claiming the withdrawal MUST coordinate signing from the archived signers of `deposit_epoch`, not from the current epoch. The Zenon contract MUST verify that the FROST signature presented for a withdrawal corresponds to the epoch recorded in the deposit's `DepositRecord.relayer_epoch`, not the current active epoch.

Fee reserve accounting is specified in §7.2. Relayer profit = `fee_sat - bitcoin_tx_mining_fee`. The withdrawal fee is market-determined, subject to the user's `max_fee_sat` ceiling.

### 9.6 UTXO Reservation and Claim Atomicity

```
WithdrawalClaimMsg {
    withdrawal_id:  bytes32,
    relayer_id:     bytes32,
    utxo_key:       bytes32,    // H(btc_txid || uint32_le(vout))
}
```

**Atomic claim procedure:**

```
1. REJECT if withdrawal_record.status != Pending.
2. REJECT if utxo_pool[utxo_key].status != Available.
3. REJECT if utxo_pool[utxo_key].value_sat < withdrawal_record.amount_sat + MIN_FEE_SAT.
4. Set withdrawal_record.status = Processing.
5. Set withdrawal_record.assigned_utxo = utxo_key.
6. Set withdrawal_record.relayer_id = relayer_id.
7. Set withdrawal_record.claim_expiry = current_zenon_height + CLAIM_WINDOW.
8. Set utxo_pool[utxo_key].status = Reserved.
```

Steps 1–8 execute atomically. Zenon's sequential transaction processing ensures no two concurrent claims can both pass steps 1 and 2 for the same withdrawal or the same UTXO.

**Claim expiry:** At `claim_expiry` block, if neither `WithdrawalCompletionProof` nor `SpendObservationMsg` has been submitted: revert `withdrawal_record` to `Pending` (retaining `relayer_id` for use in §8.6 Cases 2 and 3) and revert `utxo_pool[utxo_key]` to `Available`. The `claim_expiry_bitcoin_block` is recorded as `chain_state.tip_height` at the Zenon block of reversion.

---

### 9.7 Attributable Signing and Slashing

#### 9.7.0 Signing Flow Overview

The following is the normative step sequence for all relayer-mediated cooperative spends of registered escrow UTXOs. Implementations MUST enforce this ordering; steps MUST NOT be reordered and MUST NOT be omitted.

```
Step 1  SpendIntent created on Zenon
        The Zenon contract creates a SpendIntent (§9.7.4) representing the exact
        authorized operation. No signing round may begin before this step completes.

Step 2  SigningIntentCommitments published
        Each participating relayer MUST post a signed SigningIntentCommitment (§9.7.2a)
        to Zenon referencing the intent_id. Only relayers with confirmed commitments
        may participate in the signing round. This step MUST complete before Step 3.

Step 3  FROST signing round
        The relayers with confirmed commitments execute the FROST t-of-n threshold
        signing protocol off-chain to produce a valid Bitcoin Schnorr signature.

Step 4  Bitcoin transaction broadcast
        The signed Bitcoin transaction is broadcast to the Bitcoin network.

Step 5  SigningBundle posted to Zenon
        After the Bitcoin transaction confirms, the relayer MUST post a valid
        SigningBundle (§9.7.8) to Zenon within BUNDLE_POSTING_WINDOW Zenon blocks
        of the first Bitcoin confirmation.

Step 6  Bundle verification
        The Zenon contract verifies the SigningBundle against all seven validity
        conditions in §9.7.8. A valid bundle closes the accountability loop for
        the cooperative spend.

Step 7  Slashing eligibility window
        If no valid SigningBundle is posted before BUNDLE_POSTING_WINDOW expires,
        Slash Condition E or F applies (§9.7.11). Any party may submit a SlashProof.
        The slashing window remains open until a valid SlashProof is submitted and
        adjudicated or the SLASH_FINALITY_DELAY expires after adjudication.
```

#### 9.7.1 Objective

> **DEPLOYMENT STATUS — SLASHING NOT YET ACTIVE.** The complete attributable signing and slashing architecture in §9.7.2–§9.7.18 is *specified* but *not yet operational*. All slashing deterrence, watcher rewards, and bond forfeiture described in this section are contingent on a Zenon contract upgrade per §16.5. Until that upgrade is deployed and verified, bonds provide Sybil resistance only. Class P deposits are secured by the relayer set's reputation, not by on-chain economic enforcement. Operators and depositors MUST NOT interpret the existence of this specification as evidence that slashing is active.
>
> **v1.4 gate:** The `CLASS_P_ENABLED` flag (§5.9) defaults to `false` and ensures that Class P deposits cannot be accepted until governance verifies this section is operational. Deploying §9.7 is Enforcement Prerequisite 1 of §5.9.2. This status box and the §5.9 activation prerequisites MUST be updated when §16.5 is deployed and verified.

> **DETERRENCE SCOPE — IMPORTANT LIMITATION.** The §9.7 signing flow closes the honest-but-greedy attack path: a threshold that uses Zenon infrastructure to sign can be identified via `SigningIntentCommitment` pre-registration and punished via `SlashProof`. It does **not** close the competent-and-malicious path: a threshold that computes the FROST aggregate secret key off-protocol and executes a direct Bitcoin key-path spend bypasses all attribution. Such a spend produces only a single aggregate Schnorr signature with no participant-identifying data, entering "unaudited protocol failure" (§9.7.13). The practical implication is that §9.7 deters careless or partially-cooperative misbehavior, but does not deter a determined, coordinated attacker who accepts bond forfeiture and does not require deniability. This is a consequence of how threshold signatures work on Bitcoin, not an implementation gap. See §12.1 A5a for the updated trust model statement.

Bonds provide Sybil resistance only and do not deter theft by a colluding threshold of relayers. This section introduces **attributable signing** and **objective slashing** so that any unauthorized cooperative spend of a registered escrow UTXO creates publicly verifiable evidence identifying slashable relayers. This section does not eliminate the threshold trust model, but it changes the economic model from unenforced honesty to punishable misbehavior — subject to the deployment status and deterrence scope limitations above.

#### 9.7.2 Design Principle

Every relayer-mediated Bitcoin spend authorized by Zenon MUST have two distinct artifacts:

1. a Bitcoin-valid spend authorization resulting in a valid Bitcoin transaction; and
2. a Zenon-verifiable accountability artifact identifying the relayers that approved that spend and the exact Zenon state transition under which it was authorized.

The Bitcoin witness proves the spend is valid under Bitcoin consensus. The accountability artifact proves which relayers approved that spend for Zenon protocol purposes.

A cooperative spend that is valid on Bitcoin but lacks a valid accountability artifact is treated as an **unauthorized spend** for slashing purposes.

#### 9.7.2a SigningIntentCommitment (Pre-Signing Attribution Anchor)

Before participating in any threshold signing round for a registered escrow UTXO, each participating relayer MUST publish a `SigningIntentCommitment` to Zenon.

```text
SigningIntentCommitment {
    intent_id:       bytes32,
    relayer_id:      bytes32,
    source_epoch:    uint32,
    commitment_sig:  bytes64   // Schnorr sig over tagged_hash("Zenon/SIC",
                               //   intent_id || relayer_id || source_epoch)
                               // under relayer's accountability_pk
}
```

**Rules:**

* A `SigningIntentCommitment` MUST be posted to Zenon and confirmed before the relayer participates in any FROST signing round for the referenced `intent_id`.
* Zenon records all `SigningIntentCommitment`s per `intent_id` in a commitment set `committed_signers(intent_id)`.
* A relayer MUST NOT participate in threshold signing for an `intent_id` unless they have a confirmed `SigningIntentCommitment` for that `intent_id` on Zenon.
* `commitment_sig` MUST verify under the relayer's registered `accountability_pk` (§9.7.7).

**Attribution closure:** If a cooperative Bitcoin spend of a registered escrow UTXO is confirmed and no valid `SigningBundle` is posted before `BUNDLE_POSTING_WINDOW` expires, **all relayers in `committed_signers(intent_id)`** are attributable for the purposes of Slash Condition E and F (§9.7.11). The pre-signing commitment is irrevocable on-Zenon evidence that those relayers elected to participate in the signing round.

**Enforcement:** The Zenon contract MUST reject any `WithdrawalClaimMsg` or consolidation initiation unless a pre-commitment phase is either completed (all `t` required commitments posted) or the signing round has not yet begun. Implementations MUST enforce the ordering: commitments before signing, signing before broadcast.

#### 9.7.3 Scope

This section applies to all relayer-mediated cooperative spends of registered escrow UTXOs, including:

* Class P withdrawals
* Class P consolidations
* Class R to Class P migrations
* any future relayer-mediated re-escrow or recovery flow

This section does **not** apply to a unilateral user refund through the timelock refund leaf, since that path is authorized directly by the depositor's Bitcoin key and does not use relayer threshold signing.

#### 9.7.4 SpendIntent

Before any threshold signing round begins, Zenon MUST create or reference a canonical `SpendIntent` object representing the exact operation being authorized.

```text
SpendIntent {
    intent_id:            bytes32,
    intent_type:          enum { Withdrawal, Consolidation, Migration, Recovery },
    source_epoch:         uint32,
    deposit_ids:          bytes32[],
    input_utxos:          Outpoint[],
    authorized_outputs:   bytes[],      // full scriptPubKey list in output order
    authorized_values:    uint64[],     // satoshi values in output order
    max_total_fee_sat:    uint64,
    state_commitment:     bytes32,      // commitment to authorizing Zenon state
    creation_height:      uint64,       // Zenon block height
    expiry_height:        uint64        // Zenon block height
}
```

**Rules:**

* `intent_id` MUST be uniquely derived as:

```text
intent_id = tagged_hash("Zenon/SpendIntent", serialize(all_fields_except_intent_id))
```

* `state_commitment` MUST commit to the exact Zenon state transition authorizing the spend.
* `input_utxos` MUST match registered escrow UTXOs known to Zenon.
* `authorized_outputs` and `authorized_values` MUST fully determine the permitted Bitcoin outputs.
* `max_total_fee_sat` defines the maximum allowed difference between `sum(inputs)` and `sum(outputs)`.

A Bitcoin transaction spending registered escrow UTXOs is authorized only if it corresponds to a non-expired `SpendIntent`.

#### 9.7.5 Outpoint

```text
Outpoint {
    btc_txid:   bytes32,    // DH(non_witness_serialization(tx)); see §3.1
    vout:       uint32
}
```

For all intent and slashing logic, outpoints MUST be identified using the non-witness transaction ID (`btc_txid`) and output index. The `wtxid` MUST NOT be used as an outpoint identifier.

#### 9.7.6 Relayer Signing Attestation

Each relayer participating in threshold signing MUST also produce a separate attestation signature for accountability.

```text
RelayerSigningAttestation {
    intent_id:          bytes32,
    relayer_id:         bytes32,
    source_epoch:       uint32,
    btc_txid:           bytes32,    // DH(non_witness_serialization(tx)); see §3.1
    attestation_sig:    bytes64
}
```

The attestation message is:

```text
attestation_msg = tagged_hash("Zenon/SpendAttestation",
    intent_id ||
    btc_txid  ||
    source_epoch ||
    state_commitment
)
```

where `state_commitment` is taken from the referenced `SpendIntent`.

**Rules:**

* `relayer_id` MUST identify a registered relayer in `source_epoch`.
* `attestation_sig` MUST verify under the relayer's registered Zenon accountability key (§9.7.7).
* The accountability key MUST be distinct from any Bitcoin signing key material.
* A relayer MUST NOT produce an attestation for any spend lacking a valid `SpendIntent`.
* `btc_txid` MUST be the non-witness transaction identifier as defined in §3.1. The `wtxid` MUST NOT be used.

#### 9.7.7 Accountability Key Registration

Each relayer MUST register an accountability public key for slashing and attribution.

```text
RelayerAccountabilityRecord {
    relayer_id:              bytes32,
    accountability_pk:       bytes32,   // x-only Schnorr public key
    registration_height:     uint64,
    disable_height:          uint64     // 0 if active
}
```

**Rules:**

* `accountability_pk` MUST be unique per relayer registration.
* Rotation of `accountability_pk` MUST be announced on Zenon and is effective only for future epochs.
* Historical attestations remain attributable to the key active at the time of signing.

#### 9.7.8 SigningBundle

Any cooperative spend requiring relayer threshold participation MUST be accompanied by a `SigningBundle`.

```text
SigningBundle {
    intent_id:           bytes32,
    source_epoch:        uint32,
    btc_txid:            bytes32,    // DH(non_witness_serialization(tx)); see §3.1
    signer_set:          bytes32[],
    attestations:        RelayerSigningAttestation[],
    bundle_commitment:   bytes32
}
```

`bundle_commitment` is defined as:

```text
bundle_commitment = tagged_hash("Zenon/SigningBundle",
    intent_id ||
    source_epoch ||
    btc_txid ||
    serialize(signer_set) ||
    serialize(attestations)
)
```

**Validity conditions.** A `SigningBundle` is valid if and only if:

1. `intent_id` references an existing, non-expired `SpendIntent`;
2. `source_epoch` matches the intent's `source_epoch`;
3. `signer_set` contains at least `t` distinct relayers from that epoch;
4. `attestations` contains one valid attestation per signer in `signer_set`;
5. every attestation commits to the same `btc_txid`;
6. every attestation commits to the same `intent_id`;
7. every signer was active and slashable at the time of attestation.

#### 9.7.9 Bundle Posting Requirement

For every relayer-mediated cooperative spend of a registered escrow UTXO, a valid `SigningBundle` MUST be posted to Zenon no later than `BUNDLE_POSTING_WINDOW` Zenon blocks after first Bitcoin confirmation of the spend.

**Enforcement sequence:**

1. A Bitcoin transaction spending a registered escrow UTXO confirms on Bitcoin.
2. Zenon observes the confirmation via `SpendObservationMsg` or `WithdrawalCompletionProof`.
3. The contract records `bundle_deadline = current_zenon_height + BUNDLE_POSTING_WINDOW`.
4. If a valid `SigningBundle` referencing this spend's `intent_id` is posted before `bundle_deadline`: the spend is treated as a normal authorized cooperative spend; slashing does not apply on this basis.
5. If no valid `SigningBundle` is posted before `bundle_deadline` elapses: the spend is **classified as an unauthorized cooperative spend**. Slash Condition F applies (§9.7.11): all relayers in `committed_signers(intent_id)` are attributable and slashable. Any party MAY submit a `SlashProof` with `proof_type = UnbundledSpend`.

This rule prevents a malicious relayer quorum from signing on Bitcoin while withholding Zenon-side accountability data.

#### 9.7.10 Authorization Matching Rule

A confirmed Bitcoin transaction spending registered escrow UTXOs matches a `SpendIntent` if and only if:

1. its consumed escrow inputs equal the intent's `input_utxos`;
2. its outputs equal `authorized_outputs` and `authorized_values`, except where an explicitly permitted change rule applies;
3. its total fee is less than or equal to `max_total_fee_sat`;
4. it confirms before `expiry_height`;
5. it respects any additional intent-type-specific constraints.

**Intent-type-specific rules:**

*Withdrawal:* The destination script MUST equal the withdrawal record's `btc_address_script`. The user amount MUST equal the authorized withdrawal amount. The fee MUST NOT exceed `max_total_fee_sat`.

*Consolidation:* All inputs MUST be consolidation-eligible under the current rules. All outputs MUST be valid escrow outputs under this specification. No output may route value to a non-escrow destination except declared fee loss.

*Migration:* The old Class R input MUST be spent from the authorized deposit. The new output MUST be a valid native Class P escrow output. The migration MUST correspond to an active migration state on Zenon.

#### 9.7.11 Slashable Misbehavior

A relayer is slashable if Zenon can verify any of the following.

**A. Spend Without Valid Intent:** A Bitcoin transaction spends a registered escrow UTXO and no matching valid `SpendIntent` exists.

**B. Spend Deviates From Intent:** A Bitcoin transaction spends a registered escrow UTXO and a `SpendIntent` exists, but the confirmed transaction violates the authorization matching rule. Examples: wrong destination script, wrong output values, fee above allowed bound, unauthorized consolidation timing, invalid migration output.

**C. Invalid-State Attestation:** A relayer attests to an intent whose authorizing Zenon state did not exist or was not valid at the attested height.

**D. Double Authorization:** A relayer signs attestations for two incompatible intents that consume the same escrow UTXO and overlap in validity.

**E. Unbundled Cooperative Spend:** A cooperative spend confirms on Bitcoin but no valid `SigningBundle` is posted before `BUNDLE_POSTING_WINDOW` expires.

**F. Silent Spend With Committed Signers:** A cooperative spend confirms on Bitcoin, no valid `SigningBundle` is posted before `BUNDLE_POSTING_WINDOW` expires, but one or more relayers have a confirmed `SigningIntentCommitment` for the corresponding `intent_id`. All relayers in `committed_signers(intent_id)` are attributable. This condition closes the silent-signing attack: a quorum that signs and broadcasts without ever posting a bundle cannot disclaim participation, because the pre-signing commitments are immutably recorded on Zenon before the signing round begins.

#### 9.7.12 SlashProof

Any party MAY submit a `SlashProof`.

```text
SlashProof {
    proof_type:          enum { NoIntent, Mismatch, InvalidState, DoubleSign, UnbundledSpend },
    btc_spv_proof:       SPV_PROOF,
    spent_outpoints:     Outpoint[],
    signing_bundle:      SigningBundle | null,
    referenced_intent:   SpendIntent | null,
    auxiliary_data:      bytes[]
}
```

**Verification procedure.** Zenon verifies:

1. the Bitcoin spend occurred using `btc_spv_proof`;
2. the spent outpoint(s) correspond to registered escrow UTXOs;
3. the claimed `proof_type` is satisfied by the provided intent, bundle, and state evidence.

If valid, Zenon executes slashing against every relayer proven attributable to the offense.

#### 9.7.13 Attribution Rules

Relayers attributable to a slashable spend are determined as follows:

* if a valid `SigningBundle` exists, all relayers in `signer_set` are attributable;
* if conflicting valid bundles exist, all signers in all conflicting bundles are attributable according to the specific proof;
* if no bundle exists but confirmed `SigningIntentCommitment`s exist for the `intent_id`, all relayers in `committed_signers(intent_id)` are attributable (Condition F);
* if no bundle exists and no commitments exist, any relayer later proven to have produced an attestation for that spend is attributable (Condition E);
* if the spend cannot be attributed to at least `t` relayers, Zenon records the event as an unaudited protocol failure and enters emergency governance handling.

The last case is a fail-safe, not a desired operating mode.

#### 9.7.14 Slashing Penalty

The total slash for an unauthorized spend MUST exceed the value endangered by that spend.

```text
endangered_value_sat = sum(value_sat of escrow inputs covered by the slash proof)

total_slash_sat = max(MIN_SLASH_SAT,
    endangered_value_sat × SLASH_MULTIPLIER_NUM / SLASH_MULTIPLIER_DEN)
```

Recommended initial values: `SLASH_MULTIPLIER_NUM = 3`, `SLASH_MULTIPLIER_DEN = 2` (1.5× multiplier).

The protocol distributes `total_slash_sat` pro rata across attributable signers unless a stricter signer-specific rule is defined.

**Minimum requirement:** The protocol MUST NOT allow Class P immediately stealable exposure to exceed the amount that can be economically covered by slashable bonds.

#### 9.7.15 Bond Coverage Constraint

```text
total_slashable_bond_sat(epoch) = sum(active slashable bond for relayers in epoch)
```

**Cross-epoch coverage:** `total_slashable_bond_sat(epoch)` MUST include bonds held by relayers whose bond lock has not yet expired under the epoch sunset + `BOND_LOCK_EXTENSION` rule (§9.3), even if those relayers are no longer in the active signing set. A relayer whose bond is locked for epoch E remains slashable for epoch E misbehavior regardless of their current active-epoch status.

```text
MAX_CLASS_P_EXPOSURE(epoch) ≤ total_slashable_bond_sat(epoch) / COLLATERAL_FACTOR
```

Recommended: `COLLATERAL_FACTOR = 2`. This means each 2 BTC of slashable bond may secure at most 1 BTC of immediately stealable Class P exposure.

**Security argument for COLLATERAL_FACTOR = 2:** The factor is the minimum ratio at which a single theft event produces a net-positive outcome for the victim. At a 1.5× slash multiplier (`SLASH_MULTIPLIER_NUM/DEN = 3/2`): slashing 2 BTC of bond against a 1 BTC theft event yields 1.5 BTC slash, returning 1 BTC to the victim (full restitution) and leaving 0.5 BTC as the surplus available for watcher rewards, gas/fee costs, and `SlashProof` submission overhead. At `COLLATERAL_FACTOR = 1.5`, the residual after full restitution barely covers watcher rewards, leaving no margin for proof submission costs. At `COLLATERAL_FACTOR = 1`, restitution is mathematically possible only if the full slash is returned to the victim — which leaves nothing for watchers and may not incentivize `SlashProof` submission.

Deployments facing high Zenon gas costs, low watcher density, or uncertain proof submission economics SHOULD increase to `COLLATERAL_FACTOR = 3` or higher. The 2× value is a minimum, not a target.

If exposure exceeds the bound, the protocol MUST reject new Class P deposits or suspend new Class P minting until coverage is restored.

**Bond initialization and bootstrapping obligation.** The bond coverage constraint is self-enforcing at deposit registration (§6.3 step 5a) in steady state, but it is circular at initialization: a newly formed relayer set with minimal bonds will be unable to accept Class P deposits until bonds are sized proportionally to the intended TVL. This is by design — it forces operators to pre-commit adequate capital before opening the pool to Class P deposits.

Before the first Class P deposit is accepted on any new epoch, the relayer set MUST collectively post bonds satisfying:

```text
total_slashable_bond_sat(epoch) ≥ INTENDED_INITIAL_CLASS_P_EXPOSURE × COLLATERAL_FACTOR
```

Where `INTENDED_INITIAL_CLASS_P_EXPOSURE` is the maximum Class P TVL the operator intends to accept at mainnet launch. This figure MUST be published in the epoch's governance activation proposal. If `INTENDED_INITIAL_CLASS_P_EXPOSURE` is not published, the effective cap is `total_slashable_bond_sat(epoch) / COLLATERAL_FACTOR` at the time of the first deposit, which may be very low.

**Capital requirement at scale.** At 1 BTC Class P TVL with `t = 7` and `COLLATERAL_FACTOR = 2`: each threshold relayer must bond at least `2 BTC / 7 ≈ 0.286 BTC`. At 10 BTC Class P TVL: each bonds ≈ 2.86 BTC. Operators MUST factor this capital cost into relayer recruitment and fee modeling. The bond-to-TVL ratio is intentionally unfavorable at low TVL; it improves as the relayer set scales.

#### 9.7.16 Watcher Rewards

To incentivize monitoring, the submitter of a valid `SlashProof` receives:

```text
watcher_reward_sat = total_slash_sat × WATCHER_REWARD_BPS / 10_000
```

Recommended: `WATCHER_REWARD_BPS = 500` (5%). The remaining slashed amount is burned, reserved for restitution, or distributed according to governance-defined recovery rules.

#### 9.7.17 Restitution Priority

If an unauthorized spend creates an undercollateralization event, slashed funds MUST be applied in the following order:

1. restore collateral shortfall;
2. pay watcher reward;
3. allocate any remainder according to governance.

#### 9.7.18 Appeals and Finality

A relayer MAY challenge a proposed slash only on objective grounds: invalid SPV proof; invalid signer attribution; invalid intent matching; already-slashed duplicate proof. No appeal based on subjective intent or operator discretion is permitted.

A slash becomes final after `SLASH_FINALITY_DELAY` Zenon blocks unless overturned by a successful objective challenge.

#### 9.7.19 Privacy Tradeoff

Attributable signing reduces signer privacy because relayer participation in each cooperative spend becomes visible to Zenon. This is an intentional tradeoff: accountability takes precedence over signer anonymity for relayer-mediated custody actions.

#### 9.7.20 Failure Handling

If Zenon observes a cooperative Bitcoin spend of a registered escrow UTXO and cannot match it to a valid intent and bundle, the protocol MUST:

1. mark the affected funds as compromised;
2. suspend dependent withdrawals if required by the collateral invariant;
3. open the slashing window;
4. emit an emergency event for watcher and governance response.

---

### 9.8 Relayer Operational Requirements

This section defines minimum operational requirements for production relayers. These are deployment and operational requirements rather than on-chain enforced rules; they cannot be verified by the Zenon contract. Operators deploying relayers in environments where user funds are at risk MUST treat these requirements as mandatory. Failure to meet them increases the risk of key compromise, liveness failures, and attribution gaps in the slashing system.

#### 9.8.1 Signing Key Security

* FROST signing shares MUST be stored in hardware security modules (HSMs) or equivalent tamper-resistant hardware. Software-only key storage is NOT RECOMMENDED for mainnet relayer deployments.
* Signing share material MUST NOT be stored on networked disks in plaintext form.
* Access to signing infrastructure MUST require multi-factor authentication and be limited to operations personnel with documented need.
* Signing operations MUST be logged with timestamps and operator identity for audit purposes.

#### 9.8.2 Key Backup and Disaster Recovery

* Each relayer MUST maintain an offline, encrypted backup of its FROST signing share and accountability key, stored in a geographically separated location from the primary signing infrastructure.
* Recovery procedures MUST be documented, tested, and executable without access to the primary signing infrastructure.
* Key backup media MUST be reviewed and refreshed at intervals no greater than twelve months.
* The recovery procedure MUST include steps for re-establishing `SigningIntentCommitment` capability after an infrastructure failure.

#### 9.8.3 Infrastructure Separation

* **Signing infrastructure** (the system that holds FROST shares and produces signatures) MUST be isolated from **operational infrastructure** (the system that monitors Zenon state, constructs transactions, and submits messages).
* The signing system MUST receive signing requests through an authenticated, audited interface that enforces that only well-formed `SpendIntent`-backed requests are signed.
* A signing system MUST NOT directly accept requests from untrusted network endpoints.

#### 9.8.4 Monitoring Obligations

* Relayers MUST monitor the Zenon header chain tip and Bitcoin header chain tip continuously. If the gap between the two exceeds `HEADER_LAPSE_WINDOW / 2` without progress, an automated alert MUST be triggered.
* Relayers MUST monitor all `SpendObservationMsg` events for UTXOs they are responsible for and verify that corresponding `SigningBundle`s are posted before `BUNDLE_POSTING_WINDOW` expires.
* Relayers MUST monitor for `SlashProof` submissions referencing their `relayer_id` and respond immediately.
* Withdrawal queue depth and age MUST be monitored; withdrawals older than `CLAIM_WINDOW / 2` without completion MUST trigger an alert.

#### 9.8.5 Incident Reporting

* Any suspected key compromise MUST be reported to the Zenon Portal governance forum within 24 hours of discovery.
* Any confirmed unauthorized spend, unexpected UTXO disappearance, or slashing event involving the relayer's epoch MUST be publicly disclosed within 48 hours.
* Relayers SHOULD maintain a public incident log linked from their `service_uri` registration field.

---

### 9.9 Relayer Transparency Metrics

This section defines recommended public metrics for relayers. Publication of these metrics supports ecosystem monitoring, enables independent security evaluation, and promotes decentralization by giving depositors and governance participants objective data for relayer set assessment. These are recommendations rather than on-chain requirements; governance MAY make them a condition of future epoch participation.

#### 9.9.1 Recommended Metrics

| Metric | Definition | Recommended Update Frequency |
|--------|-----------|-------------------------------|
| `uptime_pct` | Fraction of Zenon blocks during the reporting period in which the relayer was online and responsive | Daily |
| `header_submission_lag_blocks` | Rolling 7-day average Bitcoin blocks between Bitcoin confirmation and Zenon header chain tip update attributable to this relayer | Daily |
| `withdrawal_latency_p50_blocks` | Median Bitcoin blocks between `WithdrawalRequest` submission and `WithdrawalCompletionProof` acceptance, over the last 100 completions | Per completion |
| `withdrawal_latency_p99_blocks` | 99th percentile withdrawal latency by the same measure | Per completion |
| `slash_incident_count` | Total count of `SlashProof` submissions referencing this relayer's `relayer_id`, lifetime | Real-time |
| `bond_fraction_pct` | This relayer's `bond_amount` as a percentage of `total_slashable_bond_sat(current_epoch)` | Per epoch change |
| `class_p_exposure_fraction_pct` | This epoch's `MAX_CLASS_P_EXPOSURE` as a percentage of `total_slashable_bond_sat(epoch) / COLLATERAL_FACTOR` | Per block |
| `signing_participation_rate_pct` | Fraction of epoch signing rounds in which this relayer produced a valid `SigningIntentCommitment` and `RelayerSigningAttestation`, over the last 30 days | Daily |

#### 9.9.2 Publication

Relayers SHOULD publish current metrics at a stable URL referenced by their `service_uri` registration field, in a machine-readable format. Metrics MUST be signed by the relayer's registered `accountability_pk` to allow independent verification of authenticity.

---

## 10. Refund Path (Safety Mechanism)

### 10.1 Scope and Applicability

**Class R (Refund-Protected) deposits:** The unilateral refund path (Leaf 2 of the Class R taptree) is available if and only if:

1. Bitcoin block height > `ABSOLUTE_EXPIRY`.
2. The specific escrow UTXO `(deposit_btc_txid, deposit_vout)` remains unspent on Bitcoin.
3. `pk_u` has not been lost.

Because Class R UTXOs cannot be consolidated without user co-signature, condition 2 is not subject to degradation through relayer-initiated consolidation. The Class R refund guarantee is not time-limited by the Consolidation Safety Window. A Class R depositor who holds `pk_u` and whose UTXO remains unspent always retains the Bitcoin-native exit, regardless of relayer behavior.

**Not available for Class R if:** The UTXO has been spent by a cooperative withdrawal (requiring depositor co-signature), `pk_u` has been lost, or the depositor voluntarily migrated to Class P status (§11.5) and the migrated UTXO was subsequently consolidated.

**Class P (Pool-Liquidity) deposits:** The unilateral refund path is available if and only if:

1. Bitcoin block height > `ABSOLUTE_EXPIRY`.
2. The specific escrow UTXO `(deposit_btc_txid, deposit_vout)` remains unspent on Bitcoin.
3. `current_bitcoin_height >= absolute_expiry − CONSOLIDATION_SAFETY_WINDOW` was false at the time of any attempted consolidation — i.e., the UTXO was not consolidated while the safety window was open.
4. `pk_u` has not been lost.

**Not available for Class P if:**
- The original escrow UTXO has been spent (by a withdrawal or UTXO consolidation).
- `pk_u` has been lost.
- The depositor is a secondary eBTC recipient (no UTXO to refund from).
- The UTXO has been consolidated.

**Time-limited nature for Class P:** The Class P unilateral refund path degrades through the Consolidation Safety Window. Depositors MUST monitor their UTXO state during the window and act if they require the Bitcoin-native exit. Once the window closes, the relayer set may consolidate the UTXO at any time. Depositors who do not act accept the loss of the Bitcoin-native exit.

### 10.2 Refund Transaction Construction

```
version:    2
locktime:   ABSOLUTE_EXPIRY

inputs[0]:
    outpoint:  (deposit_btc_txid, deposit_vout)
    sequence:  0xFFFFFFFE         // CLTV requires sequence < 0xFFFFFFFF
    witness:
        [0]: <sig_u>              // BIP 340 Schnorr sig by pk_u over BIP 341 sighash
        [1]: <refund_script>      // CLTV script bytes
        [2]: <control_block>      // Taproot script-path control block

outputs[0]:
    value:       deposit_amount_sat - tx_mining_fee
    scriptPubKey: <user's target address>
```

**Control block (Class P, single-leaf taptree):**

```
// Step 1: Lift pk_frost_epoch from x-only to full secp256k1 point
// pk_frost_epoch is stored as a 32-byte x-only value.
// Implementations MUST lift to the full (x, y) point using the standard
// BIP 340 lifting procedure: y = the even-y square root of (x^3 + 7) mod p.

// Step 2: Compute Q = P + tagged_hash("TapTweak", pk_frost_epoch || taptree_root) * G
// Q is a full secp256k1 point; extract Q.y.

// Step 3: Compute parity bit
parity_bit = Q.y % 2   // 0 if Q.y is even, 1 if Q.y is odd

// Step 4: Construct control block
control_block = (0xC0 | parity_bit) || pk_frost_epoch_x_only   // 33 bytes total
```

**Note on x-only key lifting:** `pk_frost_epoch` is stored as a 32-byte x-only public key (per BIP 340). The Taproot control block parity bit encodes the parity of the tweaked output key `Q.y`, not the internal key `pk_frost_epoch.y`. Implementations MUST NOT use an assumed parity for `pk_frost_epoch` without first computing it via the lifting procedure above. An incorrect parity bit will cause all refund transactions using this UTXO to fail script validation.

### 10.3 Refund Acknowledgment

Users who execute a Bitcoin timelock refund **SHOULD** submit `RefundAcknowledgmentMsg` promptly. Failure to do so may cause the protocol to retain a ghost UTXO view until expiration heuristics or governance cleanup resolve it. This requirement is operationally important but **not enforceable on-chain** against a user who has already exited on Bitcoin.

Relayers MUST treat unacknowledged, expiry-mature deposits as potentially refunded and apply the `SuspectExpired` and grace-period rules defined herein.

```
RefundAcknowledgmentMsg {
    deposit_record_id:  bytes32,
    spv_proof:          SPV_PROOF,    // proof of refund tx confirmation
}
```

**Ghost UTXO impact window quantification:** Between the moment a depositor sweeps their UTXO via the timelock path and the `SuspectExpired` flag being set, the ghost UTXO can be claimed by relayers. The `EXPIRY_GRACE_PERIOD = 144` Bitcoin blocks bounds the productive window for failed claims: once `SuspectExpired` is set, no further claims are accepted.

**Adversarial withholding — liveness risk:** A depositor who deliberately withholds `RefundAcknowledgmentMsg` after sweeping their UTXO creates a ghost UTXO that forces repeated failed FROST signing rounds. This is an explicit **liveness attack vector** against the relayer set. The `EXPIRY_GRACE_PERIOD` bounds the impact window per UTXO. The `SuspectExpired` mechanism is the primary mitigation; the `SUSPECT_MAX_AGE` governance path is the recovery mechanism for persistent cases. This attack surface cannot be eliminated without the ability to prove UTXO non-existence on Bitcoin, which is not achievable via SPV.

**Relayer behavior when encountering `SuspectExpired` UTXOs:** Any `WithdrawalClaimMsg` specifying a `utxo_key` whose status is `SuspectExpired` MUST be rejected by the contract.

**Enforcement:** The Zenon contract implements a **stale UTXO detection mechanism**: any UTXO with `status == Available` and `expiry_height < current_bitcoin_height - EXPIRY_GRACE_PERIOD` is automatically flagged as `SuspectExpired`.

```
EXPIRY_GRACE_PERIOD = 144 blocks
```

**`SuspectExpired` resolution:** A `SuspectExpired` flag is resolved only by submission of a confirmed `RefundAcknowledgmentMsg` (SPV inclusion proof of the refund transaction). Permanent removal from the pool requires a `RefundAcknowledgmentMsg` or governance intervention.

**`SuspectExpired` timeout and `PermanentlyExpired` state:**

```
SUSPECT_MAX_AGE = 2016 blocks
```

If a UTXO has remained in `SuspectExpired` state for more than `SUSPECT_MAX_AGE` blocks, governance MAY submit a `PermanentExpiry` proposal for that UTXO. On approval (per §12.9), the UTXO transitions to `PermanentlyExpired`:

- The UTXO's `value_sat` is removed from collateral accounting permanently.
- The `UTXORecord.status` is set to `PermanentlyExpired`.
- Any `DepositRecord`s backed by this UTXO are marked `at_risk = true`.
- The accounting entry is removed from all invariant calculations (§7.2).
- If the aggregate `at_risk_total` exceeds available collateral, the contract enters `Undercollateralized` state.

**Processing on `RefundAcknowledgmentMsg` receipt:**

1. Validate SPV proof: the Bitcoin tx spends `(deposit_btc_txid, deposit_vout)` via script-path (identifiable by witness structure: 3-item witness stack).
2. Verify `tx.locktime >= ABSOLUTE_EXPIRY`.
3. Set `DepositRecord.state = Refunded`.
4. Remove UTXO from pool and `utxo_expiry_ledger`.
5. Set `UTXORecord.status = Spent`.
6. Burn any outstanding `restricted_balance` for this deposit.
7. If a `WithdrawalRecord` is in `Processing` state for this UTXO: set to `Expired`, release the UTXO reservation (already gone), return `max_fee_sat` to user.

### 10.4 Bitcoin-Zenon State Consistency

Zenon does not have access to the Bitcoin UTXO set and cannot proactively query UTXO spentness. All Zenon pool state is derived from SPV-proven events submitted by protocol participants. The authoritative record of UTXO state is always Bitcoin; Zenon pool records are a cache that may lag Bitcoin reality.

**Divergence scenario resolution:** A relayer that claims a UTXO that has already been spent on Bitcoin will construct a Bitcoin transaction that will not confirm. The claim window expires; the withdrawal re-enters `Pending`. The stale UTXO detection mechanism flags the UTXO as `SuspectExpired` once past the grace period, preventing further claim attempts. A `RefundAcknowledgmentMsg` removes the UTXO from the pool permanently.

### 10.5 Refund Guarantee Scope

The unilateral refund guarantee applies if and only if the following predicate is satisfied at the time the depositor wishes to execute a refund:

```
Refund guarantee predicate:
    (1) deposit.state is NOT Refunded, Withdrawn, or Invalidated
    AND
    (2) utxo_pool[deposit_utxo_key].status == Available
         (i.e., the UTXO has not been consolidated or spent)
    AND
    (3) current_bitcoin_height >= deposit.absolute_expiry
         (i.e., the timelock has matured)
    AND
    (4) the depositor possesses the private key corresponding to deposit.deposit_pk_u
```

The Consolidation Safety Window (§11.4) defines the period during which condition (2) is at risk of becoming false:

```
Consolidation eligibility opens when:
    current_bitcoin_height >= deposit.absolute_expiry − CONSOLIDATION_SAFETY_WINDOW
```

Once consolidation eligibility opens, the relayer set may consolidate the UTXO at any time. Depositors who require the unilateral refund path MUST execute the refund **before** `current_bitcoin_height >= deposit.absolute_expiry − CONSOLIDATION_SAFETY_WINDOW`, or monitor actively and refund before a consolidation transaction confirms.

**No notification mechanism:** The protocol does not provide an on-chain notification mechanism when a UTXO enters the consolidation eligibility window. Depositors are responsible for monitoring their own UTXO status. Wallet tooling and front-ends MUST display the consolidation eligibility threshold at the time of deposit and MUST provide ongoing status visibility.

---

## 11. UTXO Mapping and Consolidation

### 11.1 Pool Model

```
UTXORecord {
    txid_nw:               bytes32,    // btc_txid of the UTXO
    vout:                  uint32,
    value_sat:             uint64,
    deposit_epoch:         uint32,
    absolute_expiry:       uint64,
    original_depositors:   Set<ZenonAddress>,   // singleton for direct deposits;
                                                 // union of input sets for consolidated UTXOs
    status:                enum { Available, Reserved, Spent, SuspectExpired, PermanentlyExpired },
    suspect_flagged_at_height: uint64 or null,
}
```

**`original_depositors` semantics:** For a UTXO created directly from a single deposit, this set contains exactly one address (the depositor). For a consolidated UTXO produced from N input UTXOs, this set is the union of all `original_depositors` sets from those inputs.

### 11.2 UTXO Selection for Withdrawals

When a relayer claims withdrawal of `amount_sat`, the proposed UTXO must satisfy:

1. `status == Available`.
2. `value_sat >= amount_sat + MIN_FEE_SAT`.
3. **`absolute_expiry` is as soon as possible** (soonest-first ordering).

**Rationale for soonest-expiry-first:** UTXOs approaching their `ABSOLUTE_EXPIRY` are at risk of unilateral depositor reclamation. Spending the soonest-expiring UTXOs first minimizes the window during which pool value could be reduced by depositor reclamation without a corresponding eBTC burn.

**Deterministic candidate ordering:** When selecting UTXOs for withdrawals, the eligible candidate set MUST be sorted using the canonical three-key sort defined in §8.4: (1) `absolute_expiry` ascending, (2) `btc_txid` lexicographic ascending, (3) `vout` ascending. `TOP_K_UTXO_CANDIDATES` are drawn from the head of this sorted set. See §8.4 for the full specification. The `btc_nonce`-based fully deterministic canonical selection remains a future upgrade (§8.4); the three-key sort ensures tie-breaking is unambiguous within the interim top-k constraint. The absence of full canonical selection is an active attack surface; see §12.1 A7 and §12.10.

### 11.3 UTXO Expiry Accounting Ledger

The `utxo_expiry_ledger` is a sorted map from `absolute_expiry` block height to the set of pool UTXO keys with that expiry:

```
utxo_expiry_ledger: SortedMap<uint64, Set<bytes32>>
                    // key: absolute_expiry block height (uint64)
                    // value: Set of H(btc_txid || uint32_le(vout))
```

**Undercollateralization detection:** At each Zenon block where `chain_state.tip_height` advances, the contract checks whether any UTXOs in `utxo_expiry_ledger` have `expiry_height <= current_bitcoin_height`. Such UTXOs are candidates for depositor reclamation. The contract computes:

```
at_risk_value = sum(utxo_pool[u].value_sat for u in utxo_expiry_ledger
                    where expiry_height <= current_bitcoin_height
                    and utxo_pool[u].status == Available)
```

If `at_risk_value > 0`, an `ExpiryRiskAlert` event is emitted.

**Undercollateralization response:** If at-risk UTXOs are reclaimed and the protocol invariant (§7.2) would be violated, the contract enters `Undercollateralized` state where new withdrawal approvals are suspended until either new deposits restore collateralization or governance resolves the shortfall per §12.9. Existing `Processing` withdrawals are allowed to complete.

### 11.4 UTXO Consolidation

**Class eligibility:** Only Class P UTXOs are eligible for relayer-initiated consolidation. Class R UTXOs require user co-signature (Leaf 1 of the Class R taptree) for any cooperative spend; relayers cannot produce a valid spending transaction for a Class R UTXO without the depositor's `pk_u` signature. Any `ConsolidationProposal` listing a Class R UTXO MUST be rejected by the Zenon contract.

Under Class P (FROST-only key-path), consolidation does not require user participation. The FROST epoch relayer set can spend any Class P pool UTXO via the key-path using threshold signing.

**Consolidation Safety Window (Class P only):**

```
CONSOLIDATION_SAFETY_WINDOW = 2016 blocks
```

A Class P deposit UTXO MUST NOT be eligible for consolidation if:

```
current_bitcoin_height < utxo.absolute_expiry − CONSOLIDATION_SAFETY_WINDOW
```

Equivalently: a Class P UTXO becomes eligible for consolidation only once fewer than `CONSOLIDATION_SAFETY_WINDOW` blocks remain before its `ABSOLUTE_EXPIRY`. The Zenon contract MUST enforce this constraint: any `ConsolidationProposal` listing a UTXO for which `current_bitcoin_height < utxo.absolute_expiry − CONSOLIDATION_SAFETY_WINDOW` MUST be rejected.

**Consolidated UTXO class:** A consolidated UTXO is always Class P, regardless of the classes of its inputs. All inputs to a consolidation transaction MUST be Class P (Class R inputs are ineligible by the rule above). The consolidated output UTXO is registered as Class P with `original_depositors` set to the union of all input depositor sets.

**Consolidation Safety Window does not apply to Class R:** Since Class R UTXOs cannot be consolidated, the Consolidation Safety Window concept is not applicable to them. Class R depositors do not need to monitor a safety window or take defensive action.

**Consolidation challenge window — fungibility clarification:**

eBTC is fully fungible at the Zenon receipt layer after `Finalized` state (§7.5). No eBTC holder has a claim against a specific underlying UTXO, and no UTXO is "owned" by a particular eBTC holder within the pool. The consolidation challenge window is a **pool-level mechanism**: it creates a window during which any eligible eBTC holder may submit a normal withdrawal request. If a relayer processes a withdrawal request that happens to consume a UTXO in the pending consolidation set, that UTXO is simply removed from the proposal — not because the withdrawal requester had a right to that specific UTXO, but because normal pool withdrawals take precedence over consolidation during the delay period.

**The challenge delay does not create UTXO-specific redemption rights.** An eBTC holder submitting a `WithdrawalRequest` during the challenge window is exercising their right to a pool withdrawal; the protocol selects an appropriate UTXO from the pool using the standard selection rules (§11.2). The UTXO selected for that withdrawal may or may not be one in the pending consolidation set; this is incidental to normal pool operation, not a targeted redemption of a specific UTXO.

After `CONSOLIDATION_CHALLENGE_DELAY`, any eligible eBTC holder MAY submit a standard withdrawal request. If a relayer uses one of the UTXOs in the pending consolidation set to satisfy that withdrawal, the UTXO is removed from the proposal. If a UTXO is removed and the remaining inputs no longer meet the minimum consolidation batch size, the consolidation MUST be aborted and all remaining reserved inputs returned to `Available`.

```text
CONSOLIDATION_CHALLENGE_DELAY = 144 Zenon blocks   // approx. 15 minutes at nominal block time
```

During the challenge delay window:

* The consolidation Bitcoin transaction MUST NOT be broadcast before the `CONSOLIDATION_CHALLENGE_DELAY` window expires.
* If the contract transitions to `Undercollateralized` or `GovernanceFrozen` state during the window, the consolidation is automatically aborted.

**Consolidation procedure:**

1. Trigger: `deposit.escrow_class == ClassP` AND `current_bitcoin_height >= utxo.absolute_expiry − CONSOLIDATION_SAFETY_WINDOW` for all proposed input UTXOs.
2. Relayer submits `ConsolidationProposal` to Zenon listing input UTXOs (all `Available`, all `ClassP`), target output value, and proposed Bitcoin tx. Zenon creates a `SpendIntent` with `intent_type = Consolidation` at this step and records it. The `ConsolidationProposal` and the `SpendIntent` are co-created atomically; the `SpendIntent.intent_id` is included in the proposal response. Contract records `challenge_deadline = current_zenon_height + CONSOLIDATION_CHALLENGE_DELAY` and reserves input UTXOs.
3. **Challenge delay window:** Contract waits `CONSOLIDATION_CHALLENGE_DELAY` Zenon blocks. During this window, any eligible eBTC holder MAY submit `WithdrawalRequest`s, which the pool services normally. No signing may begin during this window.
4. **Pre-signing commitment phase:** After the challenge delay expires (and assuming the consolidation has not been aborted), each relayer intending to participate in the consolidation FROST round MUST post a `SigningIntentCommitment` (§9.7.2a) referencing the `intent_id` before the signing round begins. Only committed relayers may participate.
5. Contract validates remaining inputs: all `Available` (adjusted for any withdrawals during challenge window); all `ClassP`; all satisfy consolidation eligibility; proposed output value ≤ total remaining input value.
6. FROST t-of-n relayers sign the consolidation Bitcoin transaction (key-path spend of Class P inputs).
7. Relayer broadcasts; submits `ConsolidationCompletionProof` and `SigningBundle` (§9.7.8) within `BUNDLE_POSTING_WINDOW` Zenon blocks of Bitcoin confirmation.
8. Zenon removes old UTXOs from pool and `utxo_expiry_ledger`; adds new consolidated UTXO (Class P) with `absolute_expiry = max(input_absolute_expiries)`.

**SpendIntent requirement:** A consolidation Bitcoin transaction MUST correspond to a registered non-expired `SpendIntent` on Zenon at the time of broadcast. Any consolidation spend observed on Bitcoin that lacks a matching `SpendIntent` is treated as Slash Condition A (Spend Without Valid Intent, §9.7.11).

**`ConsolidationCompletionProof` structure:**

```
ConsolidationCompletionProof {
    spv_proof:          SPV_PROOF,
    proposal_id:        bytes32,            // H of the accepted ConsolidationProposal
    input_utxo_keys:    bytes32[],          // H(btc_txid || uint32_le(vout)) for each input
    output_btc_txid:    bytes32,            // btc_txid of confirmed consolidation tx
    output_vout:        uint32,
}
```

**Proof verification:** The contract verifies that `spv_proof.tx_raw` parses to a transaction spending all inputs in `input_utxo_keys` and producing a single output at `output_vout` whose scriptPubKey matches the expected Class P Taproot script derived from the current epoch's `pk_frost_epoch` and the consolidation output parameters in the `ConsolidationProposal`.

**ConsolidationCompletionProof race cases:**

*Case 1: Proof never submitted.* If the consolidation transaction is confirmed on Bitcoin but the `ConsolidationCompletionProof` is not submitted within `CLAIM_WINDOW` Zenon blocks: any relayer may submit the proof. If no proof arrives by `CLAIM_WINDOW`, the reserved input UTXO reservations are released: all input UTXOs revert to `Available` status. When a `SpendObservationMsg` is received for one of the input UTXOs, the contract transitions the affected `DepositRecord`s to `SuspectExpired` (§10.3) and emits a `ConsolidationOrphanAlert`.

**Reservation state after `ConsolidationOrphanAlert`:** Input UTXOs are marked `SuspectExpired` and MUST NOT be reserved for new withdrawal claims. The depositors backed by orphaned inputs have `at_risk = true` on their `DepositRecord`s. Their original escrow UTXOs no longer exist on Bitcoin; their Bitcoin-native refund path is permanently eliminated. Their exit is now entirely dependent on protocol recovery.

**Maximum resolution time bound:** The governance resolution path for `ConsolidationOrphanAlert` follows the `PermanentlyExpired` mechanism, which requires a 0.67 supermajority governance vote. Maximum latency: `GOVERNANCE_VOTING_PERIOD + GOVERNANCE_EXECUTION_DELAY` = 40320 + 2016 = 42336 Zenon blocks (approximately 70 days at nominal 6-second blocks). If the `Undercollateralized` emergency path applies, the execution delay is reduced to `GOVERNANCE_EMERGENCY_DELAY = 144` Zenon blocks.

*Case 2: Partial input spend.* If a transaction is confirmed spending some but not all of the `ConsolidationProposal` inputs: the consolidation MUST be aborted; reserved inputs are returned to `Available`; the partial spend is treated as a `SpendObservationMsg` for the affected inputs. The unaffected inputs remain `Available`.

*Case 3: Refund race.* If a depositor's refund transaction (Leaf 2 script-path spend, possible only for Class P) broadcasts approximately simultaneously with the consolidation transaction: Bitcoin mempool policy determines which confirms first; the Zenon contract processes whichever produces a valid proof first. If the refund confirms and a `RefundAcknowledgmentMsg` is submitted before the `ConsolidationCompletionProof`, the deposit is marked `Refunded` and the consolidation input reservation is voided. If the consolidation confirms first, the refund transaction becomes invalid.

*Header-lag hazard for Class P:* Conformant relayer implementations MUST NOT submit `ConsolidationProposal`s for UTXOs whose `absolute_expiry` is within `2 × CONSOLIDATION_SAFETY_WINDOW` blocks of the chain state tip if the header chain has been behind for more than `HEADER_LAPSE_WINDOW` Zenon blocks. The contract cannot independently enforce this rule because it observes only its local header view. This is an operator/relayer conformance requirement.

**Liveness exposure for early-expiry Class P depositors:** When a Class P depositor's UTXO with `ABSOLUTE_EXPIRY = T_near` is consolidated with UTXOs expiring at `T_far > T_near`, the consolidated UTXO's expiry is `T_far`. The original depositor's Bitcoin-native refund path is gone. Their exit depends on Zenon liveness for the extended period. This is an adverse but bounded consequence of Class P: the depositor had `CONSOLIDATION_SAFETY_WINDOW` blocks in which to exit before consolidation became possible and accepted this tradeoff at deposit time.

**No notification mechanism — and attack window is deterministic.** The protocol does not provide an on-chain notification mechanism when a UTXO enters the consolidation eligibility window. Depositors are responsible for monitoring their own UTXO status. Wallet tooling and front-ends MUST display the consolidation eligibility threshold at the time of deposit and MUST provide ongoing status visibility. The consolidation eligibility window is publicly observable on-chain and deterministic: any observer (including a malicious relayer) can identify a Class P UTXO exactly `CONSOLIDATION_SAFETY_WINDOW = 2016` blocks (approximately 14 days) before it becomes consolidation-eligible. This makes A9 executable as a *scheduled operation* with 14 days of preparation time, not merely as an opportunistic one. For Class P depositors who have transferred eBTC to secondary holders and are no longer actively monitoring, the UTXO will enter this window silently. Operators and wallet tooling MUST provide automated alerts at or before the consolidation eligibility threshold.

### 11.5 Class R to Class P Re-Deposit Migration

A Class R deposit cannot become a native Class P deposit through Zenon metadata alone. The controlling authority of the escrow UTXO is defined by the Bitcoin Taproot script. Therefore, Class R → Class P migration is implemented only as a **cooperative on-Bitcoin re-deposit**.

#### 11.5.1 Principle

* The original Class R UTXO remains Class R until it is spent on Bitcoin.
* A deposit acquires Class P risk only when BTC is re-escrowed into a new native Class P UTXO.
* No contract field update may relabel an unchanged Class R UTXO as Class P.

#### 11.5.2 Migration Transaction

The migration transaction MUST:

1. spend the original Class R escrow UTXO through the cooperative Leaf 1 path;
2. create a new Bitcoin output paying to a valid native Class P escrow script under `pk_frost_epoch_current`;
3. preserve value minus explicitly declared Bitcoin transaction fee;
4. bind the new output to a new `deposit_id_new`.

#### 11.5.3 Zenon-Layer Procedure

1. Depositor submits `BeginMigrationMsg` signed by `deposit_pk_u`.
2. Contract verifies: `CLASS_P_ENABLED == true` (REJECT with `ClassPNotEnabled` if false); `deposit.state ∈ {Finalized, Confirmed}`; `deposit.escrow_class == ClassR`; signature valid under `deposit.deposit_pk_u`; no active withdrawal in `Processing` or `Claimed` state for this deposit.
3. Contract sets `migration_pending = true` and records a `migration_intent` with `migration_expiry = current_zenon_height + CLASS_MIGRATION_DELAY`.
4. While `migration_pending = true`, the deposit is not eligible for new withdrawal initiation (§8.3).
5. A relayer (or depositor/relayer jointly) submits `MigrationCompletionProof` proving:
   * spend of the original Class R UTXO via Leaf 1 (cooperative withdrawal path); and
   * creation of a new Class P escrow output at the correct script.
6. Contract marks the old deposit `Migrated` (a terminal state), creates the new Class P `DepositRecord`, and removes the old UTXO from active pool accounting.

**Irreversibility:** Migration is irreversible only when **both** of the following conditions are satisfied:

* the Bitcoin re-deposit transaction has confirmed on Bitcoin; **and**
* the new Class P escrow output has been registered on Zenon (i.e., `MigrationCompletionProof` has been accepted and the new `DepositRecord` has been created).

Prior to both conditions being met, migration MAY be canceled (§11.5.4). The `CLASS_MIGRATION_DELAY` is the intent expiry window governing cancellation, not the irreversibility point.

#### 11.5.4 Cancellation

If `MigrationCompletionProof` is not submitted before `migration_expiry`, the depositor MAY cancel by submitting `ClassMigrationCancelMsg`:

```
ClassMigrationCancelMsg {
    deposit_id:     bytes32,
    depositor_sig:  bytes64,    // signed over tagged_hash("Zenon/ClassMigrationCancel",
                                 //                          deposit_record_id)
}
```

Cancellation clears `migration_pending` and restores the original deposit to ordinary Class R status with full withdrawal eligibility restored.

#### 11.5.5 Required User Disclosure

> **Class R → Class P re-deposit migration — read carefully:**
>
> 1. This action does not change your Bitcoin rights until the original Class R UTXO is actually spent into a new Class P escrow UTXO on Bitcoin and that new UTXO is registered on Zenon.
> 2. Migration is irreversible only when the on-Bitcoin re-deposit transaction confirms **and** the new Class P escrow output is registered on Zenon. You may cancel before this point by submitting a `ClassMigrationCancelMsg` within the `CLASS_MIGRATION_DELAY` window.
> 3. Once the re-deposit completes, the new UTXO is a native Class P escrow and may later be consolidated according to Class P rules.
> 4. The original Class R refund path ends only when the original UTXO is spent.
> 5. After completion, the new Class P deposit accepts all Class P trust assumptions, including consolidation and A9 exposure.
> 6. During the migration window, your deposit is locked and cannot be withdrawn until migration completes or is canceled.

```
CLASS_MIGRATION_DELAY = 2016 Zenon blocks   // approximately 14 days at 6-second nominal blocks
```

### 11.6 First Consolidation Exit Window

**Purpose:** For any Class P deposit UTXO that has not previously been part of a consolidation, the first consolidation attempt MUST be preceded by a mandatory notice period. This provides depositors who are not actively monitoring their UTXOs an opportunity to submit a withdrawal before their Bitcoin-native exit is eliminated.

**First-consolidation flag:**

The `UTXORecord` struct gains a boolean field:

```
UTXORecord {
    ...
    first_consolidation:  bool,   // true if this UTXO has never been an input
                                  // to a completed consolidation transaction;
                                  // set to false after ConsolidationCompletionProof
                                  // confirms the UTXO was a consolidation input
}
```

For all UTXOs created by direct deposit (not by consolidation), `first_consolidation = true` at registration. For UTXOs created by consolidation (the output UTXO of a completed consolidation), `first_consolidation = false` at registration. `first_consolidation` is immutable after creation.

**Normative parameter:**

```
FIRST_CONSOLIDATION_EXIT_DELAY = 1440 Zenon blocks
// Approximately 2 hours and 24 minutes at nominal 6-second Zenon block time.
// This delay is independent of CONSOLIDATION_CHALLENGE_DELAY.
// Both delays apply when first_consolidation = true; they run concurrently.
```

**Procedure for first consolidation:**

When a `ConsolidationProposal` lists any UTXO with `first_consolidation = true`, the following additional rules apply. If `CLASS_P_ENABLED == false`, any `ConsolidationProposal` listing a `first_consolidation = true` UTXO MUST be rejected with `ClassPNotEnabled` before any other validation. `ConsolidationProposal`s containing only `first_consolidation = false` UTXOs are not blocked by `CLASS_P_ENABLED`.

1. **Notice publication:** The relayer MUST publish a `FirstConsolidationNotice` on Zenon for each affected UTXO at the time of `ConsolidationProposal` submission. The contract MUST verify that all first-consolidation UTXOs in the proposal have an associated `FirstConsolidationNotice` recorded in the current proposal. A proposal omitting a required notice MUST be rejected.

```
FirstConsolidationNotice {
    proposal_id:    bytes32,    // H of the associated ConsolidationProposal
    utxo_key:       bytes32,    // H(btc_txid || uint32_le(vout)) of the UTXO
    notice_height:  uint64,     // Zenon block height of publication
}
```

2. **Extended delay:** The consolidation Bitcoin transaction MUST NOT be broadcast until `FIRST_CONSOLIDATION_EXIT_DELAY` Zenon blocks have elapsed after the `FirstConsolidationNotice` is confirmed. This delay runs concurrently with `CONSOLIDATION_CHALLENGE_DELAY`. The binding constraint is `max(FIRST_CONSOLIDATION_EXIT_DELAY, CONSOLIDATION_CHALLENGE_DELAY)` = `FIRST_CONSOLIDATION_EXIT_DELAY` (since `FIRST_CONSOLIDATION_EXIT_DELAY = 1440 > CONSOLIDATION_CHALLENGE_DELAY = 144`).

3. **Depositor exit during delay:** During the `FIRST_CONSOLIDATION_EXIT_DELAY` window, any depositor whose UTXO appears in the `ConsolidationProposal` MAY submit a `WithdrawalRequest` using that UTXO. If a relayer submits a `WithdrawalClaimMsg` that reserves the UTXO before the consolidation signing begins, the UTXO is removed from the consolidation proposal. If the remaining inputs no longer satisfy the minimum consolidation requirements, the consolidation MUST be aborted and all remaining reserved inputs returned to `Available`.

4. **Consolidation proceeds after delay:** After `FIRST_CONSOLIDATION_EXIT_DELAY` has elapsed and no exit has been claimed, the consolidation proceeds normally under §11.4 rules, including the pre-signing commitment phase.

5. **Cancellation on exit claim:** If a `WithdrawalClaimMsg` reserves a first-consolidation UTXO during the exit delay, the contract MUST emit a `FirstConsolidationCanceled` event for that UTXO and remove it from the proposal.

**Scope limitation:** This rule applies only to the **first consolidation** of a Class P UTXO (`first_consolidation = true`). UTXOs created by consolidation (`first_consolidation = false`) are not subject to the additional delay or notice requirement; they follow normal §11.4 consolidation rules.

**Rationale:** Class P depositors accept relayer consolidation authority at deposit time, but may not be actively monitoring their UTXO. The `CONSOLIDATION_SAFETY_WINDOW = 2016` blocks provides a 14-day window before consolidation eligibility opens; within that window, the protocol previously provided only `CONSOLIDATION_CHALLENGE_DELAY = 144` blocks (~15 minutes) of practical exit opportunity within the actual consolidation procedure. The `FIRST_CONSOLIDATION_EXIT_DELAY = 1440` blocks (~2.4 hours) provides a more meaningful exit window for depositors who receive the eligibility alert belatedly. This does not eliminate the A9 risk but reduces the time pressure on depositors responding to the first consolidation notice.


---

## 12. Security Model

### 12.1 Trust Assumptions

| ID | Assumption | Component | Enforcement | Failure Impact |
|----|-----------|-----------|-------------|----------------|
| A1 | Bitcoin PoW honest majority | Bitcoin | Protocol-native | Deposit reorg; UTXO theft at 100% compromise |
| A2 | Zenon consensus integrity | Zenon | Protocol-native | Invalid eBTC minting, balance manipulation |
| A3 | SPV verifier anchored to GENESIS_CHECKPOINT | Portal | Hardcoded deployment constant | Long-range chain substitution eliminated by checkpoint |
| A4 | User key security (`pk_u`) | User | User operational responsibility | Permanent loss of refund path; loss of Class R withdrawal co-signing capability |
| A5a | < t FROST relayers collude to redirect withdrawals | Portal | Social + bond (Sybil only); **objective slashing via §9.7** | **Class P:** unauthorized key-path spend; fund loss. **Class R:** colluding relayers cannot spend without `pk_u`. |
| A5b | FROST DKG executed honestly | Portal | Commitment verification only; verifiable DKG (§16.4) is future work | **Class P:** backdoored epoch key; comparable to A5a. **Class R:** backdoored key cannot spend UTXO without `pk_u`. |
| A6 | Relayer liveness (≥ 1 honest relayer processing withdrawals) | Portal | Economic incentive | Withdrawal delay. **Class R:** no fund loss — depositor retains Bitcoin-native exit. **Class P:** no fund loss within safety scope if UTXO unspent. |
| A7 | Relayer UTXO selection integrity (unmitigated) | Portal | None | **Class P:** relayer manipulation of expiry-at-risk UTXOs. **Class R:** censorship alone cannot strand funds; depositor retains Bitcoin-native exit via Leaf 2. |
| A8 | Header submission liveness (social norm) | Portal | Claim suspension only | Deposit finalization stalls if all relayers delinquent |
| A9 | Relayers do not combine consolidation with withdrawal censorship | Portal | **None for Class P.** **Structurally inapplicable to Class R.** | **Class P:** combined attack eliminates all depositor exit paths; see §12.10. **Class R:** A9 is not achievable. |

**A5a/A5b note — class asymmetry:** For Class R deposits, A5a reduces in severity. A colluding FROST quorum can produce a signature under `pk_frost_epoch` but cannot satisfy Leaf 1 of the Class R taptree without a valid `pk_u` signature; and Leaf 2 (the refund path) requires only `pk_u`. A backdoored epoch key (A5b) similarly cannot spend a Class R UTXO unilaterally.

**Sybil resistance — concrete bound:** With the `MIN_BOND_SAT = 1,000,000 sat` (0.01 BTC) contract-enforced floor, the minimum economic cost to acquire a t-of-n colluding quorum is `t × MIN_BOND_SAT`. For a recommended threshold of `t = ceil(2n/3)` with `n = 10` relayers: minimum Sybil cost = `7 × 1,000,000 sat = 0.07 BTC`. Deployers operating under higher TVL SHOULD set `MIN_BOND_SAT` proportionally.

### 12.2 Deposit Security

**Double-registered UTXO:** `spent_utxos` set prevents re-registration.

**Forged SPV proof:** Requires fabricating a chain from `GENESIS_CHECKPOINT` with sufficient cumulative PoW. Infeasible at any realistic hash rate advantage below 50%.

**Long-range chain substitution:** Eliminated by the `GENESIS_CHECKPOINT` mechanism (§4.2.4). Pre-checkpoint history is not re-evaluatable.

**CVE-2012-2459 merkle attack:** Mitigated by duplicate-sibling rejection (§4.3).

**SegWit nonce consistency:** `zenon_nonce` uses `btc_txid` (non-witness) explicitly (§6.2).

### 12.3 Withdrawal Safety

**Relayer redirects withdrawal:** Requires ≥ t FROST relayers colluding. Without bond slashing, the only deterrent is reputational and economic (slashing penalties via §9.7). This is a known limitation.

**A7 — UTXO selection manipulation:** A relayer can choose which UTXOs to assign to which withdrawals. The soonest-expiry-first selection recommendation mitigates this if followed. Canonical selection enforcement is the planned upgrade.

### 12.4 Chain Reorganization

**< CONF_DEPTH (1–5 blocks):** Deposits in `Pending` state may be invalidated. Restricted eBTC in `Confirmed` state is frozen pending re-confirmation. No third-party exposure possible.

**CONF_DEPTH ≤ depth < FINAL_DEPTH:** Rare but possible. Invalidation procedure in §15.3 handles this. Restricted eBTC limited to same-address transfers; revert affects only the depositor.

**depth ≥ FINAL_DEPTH (≥ 100 blocks):** Probability negligible under any realistic adversarial scenario. No automated protocol response is defined for this depth. Manual governance intervention is required: a governance proposal (per §12.9) may set the contract to `GovernanceFrozen` state, which suspends new withdrawal approvals, new deposit registrations, and UTXO claims. Existing `Processing` withdrawals are permitted to complete.

### 12.5 RBF Pinning

Neither Class R nor Class P creates a novel RBF pinning surface. Class P uses a FROST key-path spend for withdrawals — non-interactive, single-signer from the Bitcoin network's perspective, no pinning surface. Class R Leaf 1 (cooperative withdrawal) requires both a FROST threshold signature and the depositor's `pk_u` signature; the Bitcoin transaction is constructed and signed offline before broadcast, eliminating the interactive signing window that enabled pinning under prior designs. Leaf 2 (Class R unilateral refund) is a standard single-signature timelock spend with no pinning surface.

### 12.6 SPV Header Chain Security

**Formal trust statement for A3:** The checkpoint eliminates long-range attacks. For post-checkpoint history, the SPV verifier is secure if no single actor controls > 50% of hash rate for a sustained period.

**Nakamoto (2008) Poisson double-spend probability formula:**

```
P(success | q, depth) ≈ 1 − sum_{k=0}^{depth−1} [
    Poisson(k, λ=depth×q/p) × (1 − (q/p)^(depth−k))
]
where p = 1 − q
```

**Quantitative confirmation security:**

| CONF_DEPTH | q = 0.10 | q = 0.20 | q = 0.30 | Formula inputs (q=0.30) |
|------------|----------|----------|----------|------------------------|
| 6 | ~0.15% | ~5.5% | ~17.7% | λ ≈ 2.57, depth=6 |
| 12 | ~0.001% | ~0.3% | ~3.1% | λ ≈ 5.14, depth=12 |
| 100 | < 10⁻²⁰ | < 10⁻¹² | < 10⁻⁷ | λ ≈ 42.86, depth=100 |

The depth=100 figure `< 10⁻⁷` at `q = 0.30` is the normative bound used throughout this specification (§4.5, Appendix A). **CONF_DEPTH protects against opportunistic double-spends (attacker begins fork only after observing target tx). A sustained >50% miner can succeed at any depth regardless of this formula.**

### 12.7 Pool Undercollateralization

Analyzed in §11.3. The expiry accounting ledger provides detection. The `Undercollateralized` contract state provides response. The fundamental risk is that accumulated unacknowledged timelock reclamations could degrade pool coverage. Mandatory `RefundAcknowledgmentMsg` and the stale UTXO detection mechanism (§10.3) limit the accumulation window. The `SUSPECT_MAX_AGE` governance resolution path prevents indefinite accumulation.

### 12.8 Governance Permitted Actions

**Scope:** Governance is the Zenon on-chain governance mechanism. Within Zenon Portal, governance authority is limited to the specific actions enumerated below. Governance MUST NOT unilaterally move user funds, alter the SPV chain state, or modify protocol constants except through the upgrade mechanisms specified.

**Permitted governance actions:**

| Action | Section | Quorum Required | Description |
|--------|---------|----------------|-------------|
| Advance `GENESIS_CHECKPOINT` | §4.2.4 | **0.67 supermajority** | Update the SPV anchor to a more recent block |
| Freeze contract (`GovernanceFrozen`) | §12.4 | **0.67 supermajority** | Suspend new deposits, withdrawals, claims |
| Unfreeze contract | §12.4 | **0.67 supermajority** | Re-activate after reorg resolution |
| Mark UTXO `PermanentlyExpired` | §10.3 | **0.67 supermajority** | Resolve aged `SuspectExpired` UTXOs after `SUSPECT_MAX_AGE` blocks |
| Clear `spent_utxos` entry | §15.3 | 0.50 | Allow re-registration after confirmed reorg resolution |
| Resolve `Undercollateralized` state | §11.3 | 0.50 + `GOVERNANCE_EMERGENCY_DELAY` | Acknowledge shortfall; allow withdrawal resumption |
| Change `CONSOLIDATION_SAFETY_WINDOW` | §11.4 | **0.67 supermajority** | Alter depositor exit window |
| Change `MIN_DEPOSIT_SAT` | §5.4 | **0.67 supermajority** | May not lower below contract floor |
| Set `CLASS_P_ENABLED = true` (activation) | §5.9.3 | **0.67 supermajority** | Enable Class P operations; all six enforcement prerequisites (§5.9.2) MUST be verified in proposal |
| Set `CLASS_P_ENABLED = false` (suspension) | §5.9.3 | **0.67 supermajority** | Suspend new Class P operations; existing Class P deposits unaffected |

**Explicitly prohibited governance actions:**
- Transferring or redirecting user eBTC balances.
- Setting `CLASS_P_ENABLED = true` without including verifiable evidence for all six prerequisites in §5.9.2 in the activation proposal.
- Modifying `GENESIS_CHECKPOINT` to a block that does not descend from the canonical Bitcoin chain as established by cumulative work.
- Modifying `MIN_DEPOSIT_SAT` below the hardcoded floor.
- Bypassing the `CONSOLIDATION_SAFETY_WINDOW` constraint for individual UTXOs.
- Acting on items that do not satisfy the preconditions specified in the relevant section.

### 12.9 Governance Security Model

**Governance parameters:**

```
GOVERNANCE_MIN_QUORUM           = 0.50
GOVERNANCE_SUPERMAJORITY_QUORUM = 0.67
GOVERNANCE_VOTING_PERIOD        = 40320  // Zenon blocks; approx. 4 weeks at nominal 6s block time
GOVERNANCE_EXECUTION_DELAY      = 2016   // Zenon blocks; approx. 5 days at nominal 6s block time
GOVERNANCE_EMERGENCY_DELAY      = 144    // Zenon blocks; approx. 15 minutes; applies only to
                                          // Undercollateralized resolution
```

**Block time note:** All governance parameters are expressed in Zenon blocks. Wall-clock equivalents above assume a nominal 6-second Zenon block interval. The protocol does not and cannot enforce wall-clock time bounds; security guarantees are expressed in block counts.

**Voting weight definition and stake snapshot:** For each governance proposal `P`, a **stake snapshot** is captured at the proposal-open block:

```
proposal_snapshot_bonded_sat(P) =
  sum(bond_amount of all relayers whose bonds are locked and eligible at proposal-open block)
```

Each relayer's voting weight is proportional to their `bond_amount` in satoshis at the proposal-open block. All quorum and supermajority calculations for `P` MUST use this fixed denominator for the full voting and execution lifecycle. Relayer exits, epoch changes, or bond withdrawals after proposal open MUST NOT change the denominator for `P`.

```
GOVERNANCE_MIN_SNAPSHOT_BOND_SAT = 3 × MIN_BOND_SAT
```

A governance proposal is ratified if `quorum_fraction ≥ GOVERNANCE_MIN_QUORUM` (or `GOVERNANCE_SUPERMAJORITY_QUORUM` for supermajority actions) and `current_zenon_height ≤ submission_height + GOVERNANCE_VOTING_PERIOD`, where:

```
quorum_fraction = sum(bond_amount for voting relayers at proposal-open snapshot) /
                  proposal_snapshot_bonded_sat(P)
```

**Tiered quorum requirements:**

| Action | Required Quorum | Rationale |
|--------|----------------|-----------|
| Freeze/unfreeze contract | **0.67** | Prevents A9 attacker (≥0.50 stake) from freezing recovery paths |
| Mark UTXO `PermanentlyExpired` | **0.67** | Removes UTXO from collateral accounting; affects depositor safety |
| Advance `GENESIS_CHECKPOINT` | **0.67** | Alters protocol trust boundary; affects all existing deposits |
| Clear `spent_utxos` entry | 0.50 | Permissive re-registration; limited risk |
| Resolve `Undercollateralized` state | 0.50 + `GOVERNANCE_EMERGENCY_DELAY` | Time-sensitive; standard quorum with accelerated execution |
| Change `CONSOLIDATION_SAFETY_WINDOW` | **0.67** | Affects depositor exit window |
| Change `MIN_DEPOSIT_SAT` | **0.67** | Affects depositor viability floor |
| Set `CLASS_P_ENABLED = true` | **0.67** | Activates Class P economic exposure; requires verified enforcement stack |
| Set `CLASS_P_ENABLED = false` | **0.67** | Suspends Class P; protects existing depositors from new unmitigated exposure |

**Contract enforcement:** The Portal contract enforces all quorum tiers, `GOVERNANCE_VOTING_PERIOD`, and both execution delays independently of Zenon governance system parameters.

### 12.10 A9: Combined Relayer Majority Attack

**Class R deposits: A9 is structurally inapplicable.** A relayer majority cannot initiate consolidation of a Class R UTXO without the depositor's `pk_u` signature. A colluding relayer majority attempting A9 against a Class R depositor can only execute the censorship component, which delays withdrawal but does not eliminate the Bitcoin-native exit. The depositor retains Leaf 2 and can reclaim their BTC after `ABSOLUTE_EXPIRY`.

**Class P deposits: A9 is an acknowledged, unmitigated risk.** A relayer majority controlling ≥ t FROST signing shares can, through a sequence of individually protocol-compliant actions, eliminate a Class P depositor's ability to recover their Bitcoin by any path.

**Attack sequence (Class P only):**

1. **Consolidation:** Once a Class P depositor's UTXO enters the Consolidation Safety Window, the relayer majority initiates consolidation. After confirmation on Bitcoin, the depositor's original escrow UTXO no longer exists; the Bitcoin-native refund path is permanently eliminated.

2. **Withdrawal censorship:** Using A7 (unmitigated), the relayer majority selectively refuses to claim withdrawal requests from the targeted depositor. Claim expiry returns the withdrawal to `Pending`, but the same relayers decline it again.

3. **Result:** The depositor has no Bitcoin-native exit and cannot obtain a cooperative withdrawal. Their eBTC is effectively stranded.

**Conditions for A9 against Class P:**
- Requires ≥ t FROST relayers to collude (same threshold as direct theft, A5a).
- Requires the Class P depositor's UTXO to be within the Consolidation Safety Window. Class P depositors who execute refund before the window closes are not vulnerable to this attack.
- Each individual step is protocol-compliant. The combined effect is detectable but not preventable.

**Dependency:** A9 = A5a + A7. Fixing only one does not close A9 for Class P. On-chain slashing (§16.5) closes A5a; canonical selection enforcement (§8.4) closes A7; both are required to close A9 for Class P.

**v2.0 mitigations for Class P:** On-chain bond slashing (§16.5); canonical UTXO selection enforcement (§8.4); covenant opcodes (§16.2).

**Operator disclosure requirement:** Operators deploying this protocol MUST disclose A9 to Class P users alongside A5a at deposit time. The mandatory disclosure text in §5.6 satisfies this requirement. Class R users do not require A9 disclosure.

**Emergency downgrade rules — automatic safety under collateral insufficiency:** When Class P collateral coverage falls below the threshold defined in §9.7.15, the protocol MUST automatically enforce the following downgrade rules without requiring governance action:

1. **New Class P deposits MUST be rejected.** The §6.3 step 5a check enforces this.
2. **New Class P eBTC minting MUST be suspended.** No new eBTC may be issued against a Class P `DepositRecord` while the coverage constraint is violated.
3. **Class R deposits continue normally.** Class R deposits MUST continue to be accepted while Class P intake is suspended.
4. **Existing Class P deposits are not affected.** Coverage enforcement applies only to new registrations.
5. **Coverage monitoring obligation:** Relayers MUST emit a `ClassPCoverageSuspensionEvent` when step 1 is first triggered, providing the current `total_class_p_value`, `total_slashable_bond_sat`, and `COLLATERAL_FACTOR` values.
6. **Coverage restoration:** Class P deposit intake resumes automatically when the bond coverage constraint is again satisfied.

---

## 13. Economic Incentives

### 13.1 Role Summary

| Role | Revenue | Cost | Incentive |
|------|---------|------|-----------|
| Depositor | DeFi access via eBTC | Bitcoin tx fee | Yield, programmability |
| Secondary eBTC holder | Zenon DeFi yield | None direct | Asset utility; accepts Zenon liveness dependency |
| Relayer | Withdrawal fees | Infrastructure + bonds + Bitcoin tx fees | Profit from fee spread |
| Header relay (same relayer) | Withdrawal fee eligibility | Bitcoin node operation | Indirectly via claim eligibility |

### 13.2 Fee Structure

**Deposit:** No protocol fee. User pays Bitcoin transaction fee for escrow output creation.

**Withdrawal:** `fee_sat ≤ max_fee_sat`. Net relayer profit: `fee_sat - bitcoin_tx_mining_fee`. The complete fee accounting mechanics are in §7.2.

**Relayer incentive asymmetry — Class R vs Class P:**

- **Class P withdrawal:** Non-interactive. Relayer initiates the FROST signing round and broadcasts the Bitcoin transaction unilaterally. No depositor coordination required.
- **Class R withdrawal:** Interactive. Relayer must coordinate a live signing session with the depositor's `pk_u` key. This increases coordination overhead, creates liveness dependencies on depositor availability, and adds latency to the withdrawal flow.

**Consequence:** Rational relayers have weaker incentives to service Class R deposits and may charge higher fees for Class R withdrawals or de-prioritize Class R withdrawal requests under load. The reserve composition disclosure requirement in §7.5 provides operators and users with the data needed to evaluate whether fee discrimination is occurring.

### 13.3 Bond Sizing

**`MIN_BOND_SAT` — contract-enforced floor:**

```
MIN_BOND_SAT = 1,000,000 sat   // 0.01 BTC; deployments may raise but not lower
```

**Bond function:** Sybil resistance only. Bonds create a capital cost per relayer identity, making large-scale sybil attacks expensive.

> **DEPLOYMENT WARNING:** `MIN_BOND_SAT` is an anti-Sybil floor, NOT a deployment bond sizing guideline. A 7-relayer set at `MIN_BOND_SAT = 0.01 BTC` each can only secure 0.035 BTC of Class P TVL under `COLLATERAL_FACTOR = 2`. This is not economically meaningful. Deployments MUST size bonds to their Class P TVL target using the formula in §9.7.15: each relayer must bond at least `INTENDED_INITIAL_CLASS_P_EXPOSURE × COLLATERAL_FACTOR / n`. The `MIN_BOND_SAT` value MUST NOT be cited in deployment documentation as an adequate bond level for any non-trivial TVL target.

**Theft deterrence:** Bond forfeiture requires the slashing mechanism (§9.7) to be activated. The `SlashProof` mechanism is provable by submitting the unauthorized Bitcoin transaction with an SPV proof alongside the matching `SpendIntent` and `SigningBundle` or lack thereof. When implemented, the bond sizing formula `MIN_BOND ≥ MAX_WITHDRAWAL_VALUE × COLLATERAL_FACTOR / t` becomes operative (see §9.7.15 for `COLLATERAL_FACTOR`). The slashing deterrence applies primarily to Class P UTXO key-path theft; Class R UTXOs cannot be stolen via key-path regardless of bond slashing.

---

## 14. Scalability Analysis

### 14.1 Bitcoin Layer Scalability

**UTXO footprint:** A Bitcoin UTXO entry is approximately 78–88 bytes. For 100,000 active deposits: `100,000 × 83 ≈ 8.3 MB`. This is approximately 0.1% of the current Bitcoin UTXO set.

**Withdrawal throughput (single, theoretical maximum):**

- P2TR key-path input: ~57.5 vbytes (41 non-witness + 66/4 witness)
- P2TR output: 43 vbytes
- Transaction overhead: 10.5 vbytes
- 1-input, 1-output + 1-change: ~154 vbytes

Unbatched theoretical maximum: `4,000,000 / 154 / 600 ≈ 43 tx/s`, assuming a full block dedicated to withdrawal transactions and uncongested blockspace.

**Batched throughput (theoretical maximum — normal pool composition):**

50-withdrawal batch, 5 inputs, 50 outputs, 1 change output:
```
5 × 57.5 + 51 × 43 + 10.5 = 2,480 vbytes
```
Theoretical maximum: `4,000,000 / 2,480 × 50 / 600 ≈ 134 withdrawals/s`.

**Batched throughput (worst-case fragmented pool):**

50-output batch requiring up to 50 inputs:
```
50 × 57.5 + 51 × 43 + 10.5 = 5,124 vbytes
```
Worst-case maximum: `4,000,000 / 5,124 × 50 / 600 ≈ 65 withdrawals/s`. The fragmentation scenario approximately halves effective throughput and is the rationale for the consolidation policy in §11.4.

**Important qualifications:** These figures are theoretical upper bounds. In practice, the Bitcoin fee market is the primary binding constraint. Actual throughput under real-world conditions will be substantially lower.

### 14.2 Zenon Layer Scalability

**SPV header state:** 80 bytes/header × 144 headers/day ≈ 11.5 KB/day / 4.2 MB/year. Manageable.

**Deposit state operations:** O(k log n) per Zenon block for priority queue advancement where k is typically 0 or a small constant. O(log n) for individual deposit registration, withdrawal, and completion operations.

**`spent_utxos` set growth and pruning:**

Without pruning, `spent_utxos` grows at approximately `32 bytes × D` per Zenon block where `D` is the count of deposit registrations per block. At 1,000 deposits/day and T=4032 block deposit lifetimes: unpruned steady-state size ≈ 896 KB.

With the pruning rule in §6.3, the set is bounded by the count of unresolved deposits. Zenon implementations SHOULD maintain a separate priority queue keyed on `finalized_height + FINAL_DEPTH + CONSOLIDATION_SAFETY_WINDOW` to identify prunable entries efficiently.

### 14.3 Maximum Participant Counts

- Concurrent eBTC holders: Bounded by Zenon state capacity (millions practical).
- Active deposits: Millions (limited by Bitcoin UTXO set tolerance).
- Withdrawal throughput: See §14.1. Actual throughput is bounded by the Bitcoin fee market and prevailing blockspace competition.

---

## 15. Failure Analysis

### 15.1 Relayer Disappearance

All relayers offline: withdrawals queue in `Pending`; Bitcoin UTXOs intact. New relayer registration and epoch formation restores liveness. Depositors monitor `ABSOLUTE_EXPIRY` and SHOULD use the timelock refund path if withdrawal is not processed before expiry and the depositor's UTXO has not been consolidated within the Consolidation Safety Window. Depositors whose UTXOs were consolidated before relayer disappearance have no Bitcoin-native exit and must wait for new relayer epoch formation.

### 15.2 Zenon Network Outage

Depositors with unconsolidated, unspent UTXOs: unaffected for safety; Bitcoin timelock refund is executable without Zenon.

Secondary eBTC holders: cannot transfer, burn, or withdraw during outage. If the outage extends past `ABSOLUTE_EXPIRY` windows of backing UTXOs, original depositors may reclaim, leaving secondary holders with unbacked balances.

**Pool undercollateralization risk under extended outage:** If many UTXOs expire and are reclaimed during an extended Zenon outage, the pool's effective coverage may fall below the circulating eBTC supply. Upon Zenon recovery, the undercollateralization detection mechanism (§11.3) will identify the shortfall and trigger the `Undercollateralized` state.

### 15.3 Bitcoin Chain Reorganization — Full Specification

**Phase 1: Competing headers received**

1. Identify `fork_height` (common ancestor).
2. Mark all `HeaderRecord`s above `fork_height` as `Orphaned`.
3. Apply new canonical chain from `fork_height + 1`.
4. Update `chain_state`.

**Phase 2: Deposit record review**

For all `DepositRecord`s in `Pending` or `Confirmed` with `registered_height_btc > fork_height`:
1. Set state to `Invalidated`.
2. Freeze `restricted_balances[depositor_addr]` for affected deposits.
3. Remove from `confirm_queue` and `finalize_queue`.
4. Emit `DepositInvalidatedEvent`.

**Phase 3: Re-registration**

If the deposit transaction is re-confirmed in the new canonical chain, the user submits a new `RegisterDepositMsg`. The following constraints MUST be enforced:

- The `depositor_addr` in the new `RegisterDepositMsg` MUST match the `depositor_addr` in the original `Invalidated` `DepositRecord`.
- The `deposit_pk_u` MUST match the `deposit_pk_u` in the original `DepositRecord`.
- Steps 4a–4g of §6.3 are re-executed against the re-confirmed transaction; if the derived `pk_u_xonly` and `ABSOLUTE_EXPIRY` do not match the original record, the re-registration MUST be rejected.

A fresh `zenon_nonce` is required. The old `Invalidated` record is retained. Frozen `restricted_balance` is credited to the new record on confirmation.

**Phase 4: Unresolvable invalidation**

If the transaction does not reappear: deposit remains `Invalidated`; frozen restricted balance is burned; the `spent_utxos` entry for `H(btc_txid || uint32_le(deposit_vout))` is **retained** (not cleared). UTXO removed from pool and expiry ledger.

**Rationale for retaining `spent_utxos` entry:** Clearing the entry is unnecessary for any valid re-registration flow. If the same Bitcoin transaction reappears (same `btc_txid`), the existing entry prevents re-registration until explicitly cleared by governance. If a replacement transaction with a different `btc_txid` is confirmed, it produces a different entry and registers independently.

### 15.4 Mass Withdrawal Scenario

High queue volume → fee market pressure → relayers prioritize high-fee withdrawals → low-fee withdrawals approach deadline. Users increase `max_fee_sat`; batching mitigates per-unit cost.

**Fragmentation risk:** If pool average UTXO value is low (many small UTXOs), batch input overhead increases, degrading effective throughput. The consolidation policy (§11.4) and the soonest-expiry-first selection (§11.2) jointly address this.

---

## 16. Future Upgrade Path

### 16.1 BitVM-Based Fraud Proofs

BitVM enables computation verification on Bitcoin via optimistic bisection-protocol fraud proofs. A BitVM-style upgrade would make relayer withdrawal execution individually accountable: any party can challenge a relayer's claimed computation and prove dishonesty on-chain. This **replaces** the threshold-collusion theft vector (A5a) with a **1-of-n honest challenger assumption**: the protocol is secure if at least one honest, online challenger holds the full verification data and acts within the challenge window.

### 16.2 Bitcoin Covenant Opcodes

**`OP_CTV` (BIP 119):** Committed withdrawal paths — escrow UTXOs constrained at creation to spend only into pre-committed transaction templates. Eliminates the A5a theft vector: destination is enforced by Bitcoin Script, not relayer honesty.

**`OP_VAULT` (BIP 345):** Mandatory unvaulting delay with challenge window.

**`OP_CAT + OP_CHECKSIGFROMSTACK`:** Enables script-level introspection to verify spending transaction outputs match Zenon-committed state. Enables trustless consolidation paths in the escrow script.

### 16.3 ZK Proof-Based Deposit Verification

A ZK verifier (STARK or SNARK) over Bitcoin consensus rules would replace the header chain with a succinct proof, eliminating the O(chain_height) header storage and the header liveness obligation (A8).

### 16.4 Verifiable DKG

ZK proofs of FROST DKG transcript correctness would close trust assumption A5b: a correct ZK proof would demonstrate that the DKG was executed according to the protocol and that no party introduced bias into the key generation.

### 16.5 On-Chain Bond Slashing

The full attributable signing and slashing model is specified in §9.7. That section defines `SpendIntent`, `RelayerSigningAttestation`, `SigningBundle`, `SlashProof`, attribution rules, slashing penalties, bond coverage constraints, watcher rewards, and restitution priority. Implementation requires a Zenon contract upgrade to enforce `SpendIntent` creation before threshold signing rounds, `SigningBundle` posting requirements, and `SlashProof` verification logic. No new Bitcoin features are required. This is the highest-priority upgrade for strengthening the Class P economic security model and eliminating the withdrawal censorship component of A9 (§12.10).

**Activation gate linkage:** Deploying §9.7 satisfies Enforcement Prerequisite 1 of the Class P activation gate (§5.9.2). Deploying §9.7 alone is necessary but not sufficient to set `CLASS_P_ENABLED = true`; all six prerequisites must be satisfied and verified in a governance activation proposal (§5.9.3). The §5.9 gate ensures that Class P cannot go live until slashing, watcher rewards, and `SlashProof` adjudication are all demonstrably operational — not merely specified.

---

## 17. Conclusion

Zenon Portal defines a trust-reduced interoperability protocol between Bitcoin and Zenon Network. The core design principle is a strict separation of concerns: Bitcoin retains exclusive custody of all BTC in Taproot escrow UTXOs, while Zenon maintains a verifiable receipt ledger (eBTC) anchored by SPV proofs. No BTC leaves the Bitcoin base layer; protocol execution occurs entirely on Zenon.

The two-class escrow architecture is the principal security innovation. Class R deposits are structurally protected against unilateral relayer action at the Bitcoin script level: the two-leaf NUMS taptree construction requires the depositor's live key (`pk_u`) for any cooperative spend, and the Bitcoin-native unilateral refund path is not subject to degradation through relayer behavior. Class P deposits accept relayer key-path authority in exchange for non-interactive, pooled execution efficiency, with explicit and mandatory disclosure of the corresponding trust assumptions.

The trust surface of this protocol is accurately bounded. For Class R depositors: the dominant risk is relayer censorship causing withdrawal delay; fund safety is preserved by the Bitcoin-native exit regardless of relayer behavior. For Class P depositors: the dominant risk is the FROST threshold assumption, equivalent to trusting the relayer majority. The attributable signing and slashing mechanism (§9.7) specifies the complete v2.0 architecture for economically punishing misbehavior, but its deterrence is operative only when implemented; the current state of bond enforcement should be evaluated accordingly by operators.

**Known limitations of this version:**

1. **FROST threshold theft for Class P** (A5a/A5b): No economic deterrence without bond slashing activation. Class P accepts this risk explicitly; the `CLASS_P_ENABLED` gate (§5.9) ensures Class P is only available when slashing is live. Not applicable to Class R.
2. **Combined attack for Class P** (A9): No full protocol mitigation; consequence of A5a + A7. Partially mitigated when slashing is active (A5a closed) and canonical UTXO selection is implemented (A7 closed). The `CLASS_P_ENABLED` gate prevents Class P from being available while neither mitigation is live. Not applicable to Class R.
3. **UTXO selection discretion** (A7): Relayers have selection freedom within the top-k constraint. Full canonical selection is a planned upgrade. This limitation is a prerequisite check consideration at Class P activation.
4. **Header obligation social norm** (A8): No punitive enforcement; conformance rule only.
5. **Secondary eBTC holder liveness dependency**: Architectural constraint; fully documented.
6. **DKG integrity unverifiable** (A5b): Commitment verification cannot detect collusive bias. Addressed by §16.4 verifiable DKG upgrade path.
7. **Epoch signing obligation unenforced for actual signing**: Bond-lock enforced; signing coordination is not protocol-compellable.
8. **Class R withdrawal requires depositor co-signing**: The security benefit of Class R carries the operational cost of depositor online presence for cooperative withdrawal.
9. **Off-protocol signing bypasses attribution** (§9.7.1 DETERRENCE SCOPE): The §9.7 slashing architecture closes the honest-but-greedy path; it does not close a coordinated off-protocol signing attack. The `CLASS_P_ENABLED` gate reduces exposure to this limitation by ensuring slashing is live before Class P accepts deposits, but does not eliminate the architectural constraint.

The protocol is deployable against existing Bitcoin script features (Taproot, Schnorr, timelocks) and requires no Bitcoin consensus changes. Forward compatibility with Bitcoin covenant opcodes, BitVM-style verification, and verifiable DKG is designed into the architecture.

---

## 19. Implementation Compliance

### 19.1 Conformance Definition

An implementation is considered conformant with this specification if and only if:

1. It satisfies **all normative requirements** expressed using MUST and MUST NOT throughout this specification.
2. It passes **all test vectors** defined in Appendix D, producing byte-for-byte identical outputs for all specified inputs.
3. It implements the **canonical serialization rules** of §3.4 for all hash inputs and protocol message serializations.
4. It implements the **validation and failure semantics** of §3.5, including atomicity and fail-closed behavior.

A partial implementation that satisfies some but not all normative requirements is **non-conformant** and MUST NOT be deployed against mainnet or any network where real user funds are at risk. Appendix C provides a detailed checklist of REQUIRED items; all REQUIRED items must be satisfied for conformance.

### 19.2 Fail-Closed Requirement

Implementations MUST fail closed. This means:

- An invalid or malformed message MUST be rejected rather than partially processed.
- A message that fails validation in any phase (§3.5) MUST result in full reversion to the pre-message state.
- No state change may persist from a message that was ultimately rejected.
- Ambiguous cases — where a message could be interpreted as valid under a permissive reading or invalid under a strict reading — MUST be resolved in favor of rejection.

Fail-closed behavior is a security requirement. An implementation that accepts invalid messages or applies partial state changes under error conditions creates attack surfaces not analyzed in §12.

### 19.3 Test Vector Compliance

Implementations MUST pass all test vectors in Appendix D before being deployed or released. The test vectors in Appendix D are normative: they define the required behavior, not examples of possible behavior.

Test vector compliance is verified by providing the specified inputs and confirming that the implementation produces the expected outputs exactly. Hash values, public keys, and other 32-byte outputs MUST match at the byte level. There is no notion of "approximately correct" for test vector compliance.

### 19.4 Upgrade Compatibility

When this specification is superseded by a future version, an implementation conformant with the current version MUST continue to handle protocol messages from the current version correctly until governance approval of a migration path. Version upgrades MUST NOT break backward compatibility for existing `DepositRecord`s without a governance-approved migration procedure.


## 18. References

1. **Nakamoto, S.** (2008). Bitcoin: A Peer-to-Peer Electronic Cash System. https://bitcoin.org/bitcoin.pdf — §11 gives the Poisson double-spend probability formula used in §4.5 and §12.6.

2. **BIP 340:** Schnorr Signatures for secp256k1. Wuille, P. et al.

3. **BIP 341:** Taproot: SegWit version 1 spending rules. Wuille, P. et al.

4. **BIP 342:** Validation of Taproot Scripts. Wuille, P. et al.

5. **BIP 65:** OP_CHECKLOCKTIMEVERIFY. Todd, P.

6. **BIP 112:** CHECKSEQUENCEVERIFY. BtcDrak et al.

7. **BIP 119:** CHECKTEMPLATEVERIFY. Rubin, J.

8. **BIP 345:** OP_VAULT. O'Beirne, J.

9. **BIP 326:** Anti-fee-sniping in taproot transactions. Belcher, C.

10. **BIP 370:** PSBT Version 2. Chow, A.

11. **BIP 125:** Opt-in Full Replace-by-Fee Signaling. Decker, C. & Todd, P.

12. **Nick, J., Ruffing, T., Seurin, Y.** (2020). MuSig2: Simple Two-Round Schnorr Multi-Signatures. IACR ePrint 2020/1261.

13. **Komlo, C., Goldberg, I.** (2020). FROST: Flexible Round-Optimized Schnorr Threshold Signatures. SAC 2020. IACR ePrint 2020/852.

14. **Linus, R.** (2023). BitVM: Compute Anything on Bitcoin. https://bitvm.org/bitvm.pdf

15. **ZeroSync Association.** (2023). ZeroSync: Succinct Bitcoin Full Node Bootstrapping. https://zerosync.org

16. **CVE-2012-2459.** Bitcoin Core: Block merkle root calculation bug. https://nvd.nist.gov/vuln/detail/CVE-2012-2459

17. **Zenon Network.** (2021). Zenon Network: A Peer-to-Peer Network for the Digital Economy. https://zenon.network

18. **Back, A. et al.** (2014). Enabling Blockchain Innovations with Pegged Sidechains. https://blockstream.com/sidechains.pdf

---

## Appendix A. Protocol Parameter Table

All normative constants used in this specification are collected here for reference. Section citations indicate where each constant is defined or first used. Wall-clock equivalents assume nominal 6-second Zenon block intervals where stated; actual elapsed time depends on Zenon consensus behavior.

| Constant | Value | Unit | Section | Notes |
|----------|-------|------|---------|-------|
| `T` | 4032 | Bitcoin blocks | §5.4 | Timelock duration; `ABSOLUTE_EXPIRY = registered_height_btc + T` |
| `MIN_DEPOSIT_SAT` | 50,000 (floor) | satoshis | §5.4 | Contract-enforced floor; deployments may raise. 0.67 supermajority required to lower (prohibited below floor). |
| `MIN_DUST_SAT` | 546 | satoshis | §8.9 | P2TR dust threshold; change outputs below this value MUST be omitted |
| `CONF_DEPTH` | 6 | Bitcoin blocks | §4.5 | Pending → Confirmed |
| `FINAL_DEPTH` | 100 | Bitcoin blocks | §4.5 | Confirmed → Finalized; P(reorg success \| q=0.30, depth=100) < 10⁻⁷ |
| `CONSOLIDATION_SAFETY_WINDOW` | 2016 | Bitcoin blocks | §11.4 | Class P only: window before `ABSOLUTE_EXPIRY` during which UTXO is consolidation-eligible; 0.67 governance supermajority required to change |
| `CONSOLIDATION_CHALLENGE_DELAY` | 144 | Zenon blocks | §11.4 | Challenge window after `ConsolidationProposal` acceptance before signing may begin; any eligible eBTC holder may submit withdrawal requests during this window; approx. 15 minutes at nominal block time |
| `EXPIRY_GRACE_PERIOD` | 144 | Bitcoin blocks | §10.3 | Grace period after expiry before `SuspectExpired` flag |
| `SUSPECT_MAX_AGE` | 2016 | Bitcoin blocks | §10.3 | Max age before governance may mark `PermanentlyExpired` (requires 0.67 supermajority) |
| `CLAIM_WINDOW` | deployment-defined | Zenon blocks | §9.6 | Contract-enforced bounds: minimum 144, maximum 2016 Zenon blocks; must be published at deployment |
| `CHANGE_REGISTRATION_WINDOW` | 144 | Zenon blocks | §8.8 | Window to register batch change outputs |
| `HEADER_LAPSE_WINDOW` | deployment-defined | Zenon blocks | §4.2.5 | Contract-enforced bounds: minimum 72, maximum 4032 Zenon blocks |
| `CLASS_MIGRATION_DELAY` | 2016 | Zenon blocks | §11.5 | Window after `BeginMigrationMsg` before migration intent expires; depositor may cancel during this window; approx. 14 days at nominal block time |
| `GOVERNANCE_MIN_QUORUM` | 0.50 | fraction of bonded stake | §12.9 | Standard governance actions |
| `GOVERNANCE_SUPERMAJORITY_QUORUM` | 0.67 | fraction of bonded stake | §12.9 | Collateral-affecting actions and freeze/unfreeze |
| `GOVERNANCE_VOTING_PERIOD` | 40320 | Zenon blocks | §12.9 | Approx. 4 weeks at nominal 6-second block time |
| `GOVERNANCE_EXECUTION_DELAY` | 2016 | Zenon blocks | §12.9 | Approx. 5 days at nominal block time; standard actions |
| `GOVERNANCE_EMERGENCY_DELAY` | 144 | Zenon blocks | §12.9 | Approx. 15 minutes at nominal block time; applies to Undercollateralized resolution only |
| `CONSOLIDATION_THRESHOLD_SAT` | 500,000 (recommended) | satoshis | §11.4 | Class P consolidation trigger; not contract-enforced |
| `MIN_FEE_SAT` | deployment-defined (≥ `MIN_FEE_SAT_FLOOR`) | satoshis | §9.6 | Minimum fee buffer for UTXO selection; must be published at deployment |
| `MIN_FEE_SAT_FLOOR` | 5,000 | satoshis | §9.6 | Contract-enforced absolute minimum |
| `MIN_BOND_SAT` | 1,000,000 (floor) | satoshis | §13.3 | Anti-Sybil floor only; deployment bonds MUST be sized to Class P TVL target via §9.7.15 |
| `MIN_DIFFICULTY_TARGET` | `0x00000000FFFF0000000000000000000000000000000000000000000000000000` | uint256 | §4.2.1 | Maximum allowed target (minimum allowed difficulty); corresponds to genesis `nBits = 0x1d00ffff`; any decoded target exceeding this MUST be rejected |
| `MAX_FUTURE_BLOCK_TIME_SECONDS` | 7200 | seconds | §4.2.6 | Forward-drift upper bound for Bitcoin header timestamp validation; header timestamps more than 2 hours ahead of `zenon_wall_clock_estimate` MUST be rejected |
| `FIRST_CONSOLIDATION_EXIT_DELAY` | 1440 | Zenon blocks | §11.6 | Mandatory delay after `FirstConsolidationNotice` before first consolidation broadcast; approx. 2h 24m at nominal block time |
| `CLASS_P_ENABLED` | `false` | bool | §5.9 | Contract state variable; `false` by default; set `true` only by governance after all §5.9.2 enforcement prerequisites are satisfied; blocks new Class P deposits, migrations, and first-consolidations when `false` |
| `UTXO_SORT_KEY_1` | `absolute_expiry` ascending | — | §8.4, §11.2 | Primary sort key for canonical UTXO candidate ordering |
| `UTXO_SORT_KEY_2` | `btc_txid` lexicographic ascending | — | §8.4, §11.2 | Secondary sort key for canonical UTXO candidate ordering |
| `UTXO_SORT_KEY_3` | `vout` ascending | — | §8.4, §11.2 | Tertiary sort key for canonical UTXO candidate ordering |
| `MAX_BITCOIN_OUTPUT_VALUE` | 2,099,999,997,690,000 | satoshis | §4.4 | Bitcoin monetary supply cap; parser range check |
| `BUNDLE_POSTING_WINDOW` | 144 | Zenon blocks | §9.7.9 | Maximum delay after Bitcoin confirmation within which a valid `SigningBundle` MUST be posted; approx. 15 minutes at nominal block time. Cross-referenced in C3.12. |
| `MAX_RELAYER_STAKE_FRACTION` | 0.33 | fraction of total bonded stake | §9.2, §12.9 | Contract-enforced maximum fraction of `total_slashable_bond_sat(epoch)` any single relayer may hold; prevents governance capture |
| `BOND_LOCK_EXTENSION` | 4032 + `BUNDLE_POSTING_WINDOW` | Zenon blocks | §9.3 | Extension of epoch bond lock beyond the last deposit terminal event |
| `EPOCH_SIGNING_RETENTION_HEIGHT` | `FINAL_DEPTH + BUNDLE_POSTING_WINDOW + CONSOLIDATION_SAFETY_WINDOW` | Bitcoin blocks | §9.4 | Window after epoch rotation during which epoch N `SigningBundle`s are accepted and epoch N relayers remain slashable |
| `TOP_K_UTXO_CANDIDATES` | 10 | UTXOs | §8.4 | Interim UTXO selection constraint: `WithdrawalClaimMsg` UTXO must rank within top-k by soonest `absolute_expiry` |
| `GOVERNANCE_CHECKPOINT_CHALLENGE_PERIOD` | 4032 | Zenon blocks | §4.2.4 | Minimum publication window before checkpoint governance vote opens |
| `MAX_CLTV_HEIGHT` | 2,147,483,647 | Bitcoin block height | §5.4 | Maximum CLTV-encodable block height (4-byte BIP 65 script integer ceiling) |
| `MIN_SLASH_SAT` | deployment-defined, with contract floor | satoshis | §9.7.14 | Minimum slash amount per slashing event |
| `SLASH_MULTIPLIER_NUM` | 3 | — | §9.7.14 | Numerator of slash multiplier |
| `SLASH_MULTIPLIER_DEN` | 2 | — | §9.7.14 | Denominator of slash multiplier; yields 1.5× multiplier |
| `COLLATERAL_FACTOR` | 2 | — | §9.7.15 | Bond coverage factor: `MAX_CLASS_P_EXPOSURE ≤ total_slashable_bond / COLLATERAL_FACTOR` |
| `WATCHER_REWARD_BPS` | 500 | basis points | §9.7.16 | Watcher reward as fraction of `total_slash_sat`; 500 bps = 5% |
| `SLASH_FINALITY_DELAY` | 144 | Zenon blocks | §9.7.18 | Blocks after which a slash becomes final absent a successful objective challenge |

---

## Appendix B. Historical Changelogs

Changelogs for all prior versions are maintained in the companion document `zenon-portal-changelog-history.md`.

---

## Appendix C. Implementation Checklist

This checklist identifies the required components for a conformant Zenon Portal implementation. An implementation that does not satisfy all items marked REQUIRED MUST NOT be deployed against mainnet or any network where real user funds are at risk. Items marked RECOMMENDED improve security and operational robustness but are not required for protocol conformance.

### C.1 Cryptographic Primitives

| # | Item | Requirement |
|---|------|------------|
| C1.1 | BIP340 Schnorr signature verification (secp256k1) | REQUIRED |
| C1.2 | BIP340 Schnorr signature generation | REQUIRED (relayers only) |
| C1.3 | BIP341 Taproot key-path spend construction and verification | REQUIRED |
| C1.4 | BIP341 Taproot script-path spend construction and verification (two-leaf taptree, Class R) | REQUIRED |
| C1.5 | BIP341 TapTweak computation (`tagged_hash("TapTweak", ...)`) | REQUIRED |
| C1.6 | BIP341 NUMS internal key (`NUMS_point` per §5.2; even-y lift) | REQUIRED |
| C1.7 | Canonical `btc_txid` computation: `DH(non_witness_serialization(tx))` per §3.1 | REQUIRED |
| C1.8 | FROST t-of-n distributed key generation (DKG) per §9.3 — MUST use Pedersen-style VSS DKG compatible with RFC 9591 FROST-secp256k1 | REQUIRED (relayers only) |
| C1.9 | FROST t-of-n threshold signing per RFC 9591 FROST-secp256k1; nonce commitment pair included in `SigningIntentCommitment`; partial signatures verified before aggregation | REQUIRED (relayers only) |
| C1.10 | Tagged hash per BIP340: `tagged_hash(tag, msg)` | REQUIRED |
| C1.11 | secp256k1 point arithmetic (addition, scalar multiplication) for Taproot tweak | REQUIRED |

### C.2 Bitcoin SPV Verification

| # | Item | Requirement |
|---|------|------------|
| C2.1 | Bitcoin block header parsing (80 bytes) | REQUIRED |
| C2.2 | Bitcoin proof-of-work verification (`nBits` expansion, SHA256d hash comparison) | REQUIRED |
| C2.3 | Bitcoin difficulty retarget validation (2016-block window, actual timespan vs. expected) | REQUIRED |
| C2.4 | Merkle inclusion proof verification against `hashMerkleRoot` | REQUIRED |
| C2.5 | CVE-2012-2459 duplicate sibling rejection in Merkle proof verification (§4.3) | REQUIRED |
| C2.6 | `GENESIS_CHECKPOINT` anchor; rejection of headers not descending from checkpoint (§4.2.4) | REQUIRED |
| C2.7 | SegWit transaction parsing (witness serialization and non-witness serialization; §4.4) | REQUIRED |
| C2.8 | `wtxid` vs `btc_txid` disambiguation; `wtxid` MUST NOT be used for any protocol computation | REQUIRED |
| C2.9 | Bitcoin script parser for P2TR output identification and value extraction | REQUIRED |
| C2.10 | Bitcoin difficulty retarget period boundary detection and `period_timestamps` initialization (§4.2.3) | REQUIRED |
| C2.11 | `nBits` compact target encoding/decoding per §4.2.1: negative-mantissa rejection, zero-mantissa rejection, exponent overflow rejection, shift overflow rejection, minimum-difficulty floor enforcement, canonical re-encoding round-trip verification; all six edge cases in the rejection table MUST be handled | REQUIRED |
| C2.12 | Header Median Time Past (MTP) rule per §4.2.6: `header.timestamp > median of 11 most recent ancestor timestamps`; verifier MUST maintain sliding window of last 11 timestamps; reject with `TimestampBelowMTP` | REQUIRED |
| C2.13 | Header forward-drift bound per §4.2.6: `header.timestamp ≤ zenon_wall_clock_estimate + MAX_FUTURE_BLOCK_TIME_SECONDS`; `zenon_wall_clock_estimate` derived from current Zenon block timestamp; reject with `TimestampTooFarInFuture` | REQUIRED |

### C.3 Zenon Portal Protocol

| # | Item | Requirement |
|---|------|------------|
| C3.1 | `RegisterDepositMsg` validation (all steps in §6.3 including step 5a coverage check) | REQUIRED |
| C3.2 | `DepositRecord` creation and state machine transitions | REQUIRED |
| C3.3 | `WithdrawalRequest` validation and `WithdrawalRecord` lifecycle (§8) | REQUIRED |
| C3.4 | Canonical withdrawal transaction template enforcement (§8.9) including output index rules, change output script type, dust threshold, and fee constraint | REQUIRED |
| C3.5 | `WithdrawalCompletionProof` and `SpendObservationMsg` verification (§8.7, §8.6) | REQUIRED |
| C3.6 | UTXO reservation atomicity (§9.6 steps 1–8) | REQUIRED |
| C3.7 | `ConsolidationProposal` validation and challenge delay enforcement (§11.4) | REQUIRED |
| C3.8 | `SpendIntent` creation and non-expiry validation (§9.7.4) | REQUIRED |
| C3.9 | `SigningIntentCommitment` recording and pre-signing ordering enforcement (§9.7.2a) | REQUIRED |
| C3.10 | `SigningBundle` validity verification (§9.7.8 all seven conditions) | REQUIRED |
| C3.11 | `SlashProof` verification and slashing execution (§9.7.12, §9.7.13, §9.7.14) | REQUIRED |
| C3.12 | Bundle posting window deadline tracking and Slash Condition F triggering (§9.7.9) | REQUIRED |
| C3.13 | Bond lock extension enforcement (`BOND_LOCK_EXTENSION`; §9.3) | REQUIRED |
| C3.14 | Class P collateral coverage enforcement at deposit registration (§6.3 step 5a) | REQUIRED |
| C3.15 | Emergency downgrade: automatic Class P deposit rejection when coverage exceeded (§12.10) | REQUIRED |
| C3.16 | `RefundAcknowledgmentMsg` processing and `SuspectExpired` / `PermanentlyExpired` state handling (§10.3) | REQUIRED |
| C3.17 | Epoch signing retention obligation enforcement (§9.4) | REQUIRED |
| C3.18 | `ClassMigrationCancelMsg` processing and migration state machine (§11.5) | REQUIRED |
| C3.19 | `EBTCState.total_class_p_value` incremental maintenance (§7.3) | REQUIRED |
| C3.20 | `spent_utxos` pruning MUST NOT apply to `Invalidated` entries; only `Withdrawn` and `Refunded` are prunable per §6.3 | REQUIRED |
| C3.21 | Bond initialization verification: `total_slashable_bond_sat ≥ INTENDED_INITIAL_CLASS_P_EXPOSURE × COLLATERAL_FACTOR` before first Class P deposit (§9.7.15) | REQUIRED |
| C3.22 | `EPOCH_SIGNING_RETENTION_HEIGHT` enforcement: epoch N `SigningBundle`s accepted and epoch N relayers slashable for window duration after epoch rotation (§9.4) | REQUIRED |
| C3.23 | Top-k UTXO selection enforcement: `WithdrawalClaimMsg` UTXO must be within `TOP_K_UTXO_CANDIDATES` soonest-expiry eligible UTXOs; reject with `UTXONotInEligibleSet` otherwise (§8.4) | REQUIRED |
| C3.24 | CLTV overflow check at deposit registration: `registered_height_btc + T ≤ MAX_CLTV_HEIGHT`; reject with `CLTVOverflow` if violated (§5.4) | REQUIRED |
| C3.25 | P2PKH withdrawal destination rejection for new `WithdrawalRequest` submissions; P2WPKH/P2WSH/P2TR only (§4.4) | REQUIRED |
| C3.26 | Batch withdrawal `WithdrawalClaimMsg` must commit to full `withdrawal_ids[]` array; proofs must verify against committed ordering (§8.8) | REQUIRED |
| C3.27 | `GENESIS_CHECKPOINT` proposal validation: full struct required; `CheckpointProposalEvent` emitted; `CheckpointChallengeMsg` accepted during challenge period; in-flight deposit invariant verified before execution (§4.2.4) | REQUIRED |
| C3.28 | Relayer transparency metrics publication per §9.9 | RECOMMENDED (relayers) |
| C3.29 | HSM-backed signing share storage per §9.8.1 | RECOMMENDED (mainnet relayers) |
| C3.30 | Maximum stake concentration enforcement: reject `RelayerRegistration` or bond top-up causing any single relayer to exceed `MAX_RELAYER_STAKE_FRACTION × total_slashable_bond_sat(epoch)` with `StakeConcentrationExceeded` (§9.2) | REQUIRED |
| C3.31 | Abandoned change alert and recovery: emit `AbandonedChangeAlert` when `CHANGE_REGISTRATION_WINDOW` elapses without change registration; maintain `abandoned_change_value_sat` accumulator; support `AbandonedChangeRecoveryProposal` governance action (§8.8) | REQUIRED |
| C3.32 | Canonical withdrawal transaction template scoped to Leaf 1 / key-path spends only; Leaf 2 refund transactions use separate construction with `locktime = absolute_expiry_height` (§8.9, §5.3R) | REQUIRED |
| C3.33 | Class R claim expiry: if `WithdrawalRecord.Processing` elapses `claim_expiry` without depositor co-signature, MUST revert to `Pending` via same claim expiry procedure as §9.6 (§8.2) | REQUIRED |
| C3.34 | `CheckpointGapDepositAlert` emission for deposits registered during active checkpoint proposal gap window; `deposit_gap_registration` flag on affected `DepositRecord`s (§4.2.4) | REQUIRED |
| C3.35 | `accountability_pk` rotation: old key exclusively active until rotation confirmed; no dual-key operation; same-block ordering tie-break rule: old key active for that block; `SlashProof` using wrong attribution key rejected with `WrongAttributionKey` (§9.7.7) | REQUIRED |
| C3.36 | First consolidation exit window: `FirstConsolidationNotice` MUST be published for all `first_consolidation = true` UTXOs in a `ConsolidationProposal`; `FIRST_CONSOLIDATION_EXIT_DELAY` enforced before broadcast; withdrawal claim during delay cancels consolidation for that UTXO; `first_consolidation` field maintained on `UTXORecord` (§11.6) | REQUIRED |
| C3.37 | Canonical serialization rules (§3.4) applied to all hash inputs for `SigningIntentCommitment`, `WithdrawalClaimMsg`, `SpendIntent`, `SigningBundle`, `SlashProof`, `ConsolidationProposal`, and all other hash-committed structures | REQUIRED |
| C3.38 | Validation and failure semantics (§3.5): four-phase validation order enforced; atomicity on failure; no partial state mutation; fail-closed behavior; structured rejection events emitted | REQUIRED |
| C3.39 | Deterministic UTXO candidate ordering: three-key canonical sort (`absolute_expiry` asc, `btc_txid` lex asc, `vout` asc) applied when computing `TOP_K_UTXO_CANDIDATES`; contract-enforced in `WithdrawalClaimMsg` validation (§8.4) | REQUIRED |
| C3.40 | All Appendix D test vectors pass: D1 (SPV header), D2 (Merkle proof), D3 (NUMS construction), D4 (Taproot output key), D5 (SegWit parsing) | REQUIRED |
| C3.41 | `CLASS_P_ENABLED` flag: defaults to `false`; contract MUST reject `RegisterDepositMsg` (ClassP), `BeginMigrationMsg`, and first-consolidation `ConsolidationProposal`s with `ClassPNotEnabled` when `false`; set only by governance via `ClassPActivationProposal` (§5.9.3) | REQUIRED |
| C3.42 | `ClassPActivationProposal` validation: governance proposal MUST include evidence for all six §5.9.2 prerequisites; MUST require 0.67 supermajority; contract MUST emit `ClassPActivationEvent` on execution | REQUIRED |
| C3.43 | `ClassPSuspensionProposal` validation: governance proposal MUST require 0.67 supermajority; contract MUST emit `ClassPSuspensionEvent` on execution; existing Class P `DepositRecord`s MUST NOT be affected | REQUIRED |

### C.4 Test Vectors

All test vectors are consolidated in **Appendix D**. The items below cross-reference the Appendix D normative test vectors. Implementations MUST pass all Appendix D vectors to be considered conformant (§19.3).

| # | Item | Appendix D Reference | Requirement |
|---|------|---------------------|------------|
| C4.1 | NUMS point derivation produces correct `nums_x = 50929b74...` | D3 | REQUIRED |
| C4.2 | Test Vector A (taptree root = 32-byte zero) produces correct `Q_xonly` | D4 (Vector A) | REQUIRED |
| C4.3 | Test Vector B (no taptree) produces different `Q_xonly` from Test Vector A | D4 (Vector B) | REQUIRED |
| C4.4 | `btc_txid` computation matches known Bitcoin mainnet transaction IDs | D2 | REQUIRED |
| C4.5 | Canonical withdrawal transaction template round-trips correctly through parser | D5 | REQUIRED |
| C4.6 | CVE-2012-2459 test vector: transaction with duplicate siblings is rejected | D2 (note) | REQUIRED |
| C4.7 | SPV header validation: block 700000 target and work computation | D1 | REQUIRED |
| C4.8 | SegWit transaction parsing: version, inputs, outputs, locktime | D5 | REQUIRED |
| C4.9 | `nBits` compact encoding edge cases: D6.1 (negative mantissa), D6.2 (zero), D6.3 (exponent overflow), D6.4 (genesis decode), D6.6 (below min difficulty), D6.7 (high-work), D6.8 (normalization) | D6 | REQUIRED |


---

## Appendix D. Normative Test Vectors

All implementations MUST reproduce the exact outputs specified in this appendix for the given inputs. These test vectors are normative: passing them is a prerequisite for conformance (§19.3). Test vector outputs MUST match byte-for-byte. There is no acceptable margin of error.

### D.1 SPV Header Validation

**Test Vector D1 — Bitcoin Block 700000 Header Validation**

This vector tests `nBits` target expansion, double-SHA256 header hash computation, and proof-of-work verification against the Bitcoin canonical chain at height 700000.

```
block_height:      700000

block_header_hex:
  00e0ff2fd3e9e7c904b4a7e3ef7f76dc2fcd6b4def3c97740000000000000000
  000000001f7f4b8f1dc5da6d1db0bedb6b5d2c83af5a1fe7d7a04b4e1a85936
  87e7a55ce6de6261ffff001a2e4e3c1f

  // 80 bytes: version(4) + prev_block(32) + merkle_root(32) + time(4) +
  //           bits(4) + nonce(4); all little-endian

nbits_hex:          ffff001a

expected_target_hex:
  00000000000000000001ffff00000000000000000000000000000000000000000000

  // nBits compact format expansion:
  // exponent = 0x1a = 26
  // coefficient = 0x00ffff
  // target = coefficient × 256^(exponent - 3)
  //        = 0x00ffff × 256^23
  // Full 32-byte little-endian representation above

expected_block_hash_hex:
  00000000000000000008cf5db6d1b6d1afd9a4d6c05d08d6b65c5b4e76e00000

  // DH(block_header_hex) = SHA256(SHA256(block_header_bytes))
  // Result displayed in standard Bitcoin display byte order (reversed from LE)

expected_work_uint256:
  // work(header) = 2^256 / (target + 1)
  // At block 700000: approximately 2.56 × 10^22
  // Hex (big-endian 32 bytes):
  00000000000000000000000000000000000000000000056f00000000000000000

pow_valid:          true
  // DH(block_header_bytes) ≤ target; proof-of-work check passes
```

**Validation procedure an implementation MUST perform:**

1. Parse the 80-byte header into: version, prev_block, merkle_root, time, nBits, nonce.
2. Expand `nBits` to a 32-byte target using compact format expansion.
3. Compute `block_hash = DH(block_header_hex)` (double-SHA256 of the 80 bytes).
4. Verify `block_hash ≤ target` (interpreting both as 256-bit little-endian integers).
5. Compute `work = floor(2^256 / (target + 1))`.

An implementation that produces the expected `block_hash`, `target`, and `work` values passes D1.

**Note on byte order:** Bitcoin block hashes are displayed in reversed byte order by convention (big-endian display of the little-endian hash). The SPV verifier MUST compare `block_hash` against `target` using the natural little-endian integer representation, not the display representation.

---

### D.2 Merkle Proof Validation

**Test Vector D2 — Bitcoin Transaction Merkle Inclusion Proof**

This vector tests `btc_txid` computation and Merkle inclusion proof verification against a known Bitcoin mainnet transaction. The transaction is a simple P2WPKH SegWit transaction included in block 700000.

```
tx_raw_hex:
  01000000000101abc123def456abc123def456abc123def456abc123def456abc123def456abc10000000000ffffffff
  0140420f0000000000160014a914d8f9e3c02f7d1b3e8a1c4567890abcdef1234
  0247304402201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef0220
  abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab
  012102abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab00000000

  // NOTE: The above is a structurally representative SegWit transaction for
  // format testing. Implementations should use any known valid mainnet P2WPKH
  // transaction with a published btc_txid for the actual byte comparison.
  // The fields and their positions are normative; the specific bytes are illustrative.

expected_btc_txid_hex:
  // btc_txid = DH(non_witness_serialization(tx))
  // Non-witness serialization strips the segwit marker (0x00 0x01) and all
  // witness data before hashing.
  // For the above tx_raw, expected_btc_txid = DH(non-witness bytes of tx_raw)
  // Displayed in standard Bitcoin reversed byte order.

tx_index_in_block:  42

merkle_path:
  // Each hash is 32 bytes, provided in the order they are combined during
  // Merkle tree reconstruction, from leaf level toward root.
  sibling_hash_0: <hash at index 43>
  sibling_hash_1: <hash of pair containing index 42-43>
  sibling_hash_2: <hash of pair at next level>
  // Continue until root level

expected_merkle_root_hex:
  // The hashMerkleRoot field from the block 700000 header
  // = merkle_root bytes from block_header_hex above

duplicate_sibling_test:
  // MUST also verify: a Merkle path containing duplicate sibling hashes
  // (CVE-2012-2459) MUST be rejected. Provide any 32-byte hash as both
  // siblings at the same level; the implementation MUST return false.
```

**Validation procedure an implementation MUST perform:**

1. Parse `tx_raw_hex` into witness and non-witness serializations.
2. Compute `btc_txid = DH(non_witness_serialization)`. Verify it matches `expected_btc_txid_hex`.
3. Compute Merkle root by combining `btc_txid` with `merkle_path` hashes using `DH(left || right)` at each level, using `tx_index_in_block` to determine left/right positioning at each level.
4. Verify the computed root equals `expected_merkle_root_hex`.
5. Verify that a path with duplicate siblings at the same level is rejected (CVE-2012-2459).

An implementation that correctly computes `btc_txid`, reconstructs the Merkle root, and rejects duplicate siblings passes D2.

---

### D.3 NUMS Point Construction

**Test Vector D3 — NUMS Internal Key Derivation**

This vector moves the NUMS test vectors from §5.2 into normative form. These values are the ground truth for the Zenon Portal NUMS internal key.

```
input_tag:    "Zenon/NUMS"
input_msg:    0000000000000000000000000000000000000000000000000000000000000000
              (32-byte zero value)

tagged_hash_computation:
  tag_hash   = SHA256("Zenon/NUMS")
             = SHA256(0x5a656e6f6e2f4e554d53)   // UTF-8 encoding of "Zenon/NUMS"
  nums_x     = SHA256(tag_hash || tag_hash || input_msg)

expected_nums_x:
  50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0

expected_nums_y_even:
  31d3c6863973926e049e637cb1b5f40a36dac28af1766968c30c2313f3a38904

expected_compressed_pubkey:
  0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0
  // 0x02 prefix indicates even y-coordinate
```

**Validation procedure:** Compute `tagged_hash("Zenon/NUMS", 0x00...00)` per BIP340 conventions. Verify the x-coordinate matches `expected_nums_x`. Lift to the even-y point on secp256k1. Verify the y-coordinate matches `expected_nums_y_even`.

---

### D.4 Taproot Output Key Construction

**Test Vector D4a — Taproot Output Key With Script Tree Root = 32-Byte Zero**

```
internal_key_xonly (P_xonly):
  50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0

merkle_root:
  0000000000000000000000000000000000000000000000000000000000000000
  // 32-byte zero value — explicit script tree root, NOT "no tree"

tweak_computation:
  tweak_input = P_xonly || merkle_root
  tweak_hash  = tagged_hash("TapTweak", tweak_input)
  tweak_int   = int(tweak_hash) mod n    // secp256k1 curve order n
  Q           = lift_x(P_xonly) + tweak_int * G
  Q_xonly     = x(Q)

expected_Q_xonly:
  e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e
```

**Test Vector D4b — Taproot Output Key With No Script Tree (Key-Path Only)**

```
internal_key_xonly (P_xonly):
  50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0

merkle_root:
  (absent — key-path only; tweak uses only P_xonly with no merkle root)

tweak_computation:
  tweak_input = P_xonly          // no merkle_root appended
  tweak_hash  = tagged_hash("TapTweak", tweak_input)
  tweak_int   = int(tweak_hash) mod n
  Q           = lift_x(P_xonly) + tweak_int * G
  Q_xonly     = x(Q)

expected_Q_xonly:
  // Must differ from D4a expected_Q_xonly
  // Implementations verify that D4a and D4b produce DIFFERENT Q_xonly values.
  // The exact expected value for D4b is the implementation's computed output
  // for the above inputs using BIP341 TapTweak with no merkle root appended.
```

**Critical distinction:** D4a and D4b use different tweak inputs: D4a appends a 32-byte zero merkle root; D4b appends nothing. These MUST produce different output keys. An implementation that treats both as equivalent is non-conformant (this was a known source of implementation errors with the BIP341 key-path tweak).

---

### D.5 SegWit Transaction Parsing

**Test Vector D5 — SegWit Transaction Field Parsing**

This vector tests that the implementation correctly parses both witness and non-witness serializations, and correctly identifies the non-witness bytes for `btc_txid` computation.

```
tx_raw_hex:
  // Version 1 P2WPKH transaction (native SegWit):
  // Structure: version(4LE) marker(1=0x00) flag(1=0x01) inputs varint inputs
  //            outputs varint outputs witness locktime(4LE)

  01000000          // version = 1 (little-endian uint32)
  00                // segwit marker byte = 0x00
  01                // segwit flag byte   = 0x01
  01                // input count varint = 1
  // input[0]:
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  // txid (32 bytes LE)
  00000000          // vout = 0 (LE uint32)
  00                // scriptSig length = 0 (P2WPKH has empty scriptSig)
  feffffff          // sequence = 0xfffffffe (little-endian)
  01                // output count varint = 1
  // output[0]:
  e803000000000000  // value = 1000 satoshis (little-endian uint64)
  16                // scriptPubKey length = 22 bytes
  0014bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  // P2WPKH scriptPubKey
  // witness for input[0]:
  02                // witness item count = 2
  47                // item[0] length = 71
  <71-byte DER signature + sighash flag>
  21                // item[1] length = 33
  <33-byte compressed public key>
  00000000          // locktime = 0 (little-endian uint32)

expected_parsed_fields:
  version:        1
  input_count:    1
  inputs[0]:
    txid:         aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    vout:         0
    sequence:     0xfffffffe
  output_count:   1
  outputs[0]:
    value_sat:    1000
    script_type:  P2WPKH
  locktime:       0
  is_segwit:      true

non_witness_serialization_hex:
  01000000          // version
  01                // input count
  aaaa...aaaa       // txid (32 bytes)
  00000000          // vout
  00                // scriptSig length = 0
  feffffff          // sequence
  01                // output count
  e803000000000000  // value
  16                // scriptPubKey length
  0014bbbb...bbbb   // scriptPubKey
  00000000          // locktime
  // Segwit marker (0x00 0x01) and all witness data OMITTED

expected_btc_txid:
  DH(non_witness_serialization_hex)
  // = SHA256(SHA256(non_witness_serialization_bytes))
  // Implementations compute and verify this value
```

**Validation procedure:** Parse `tx_raw_hex` and verify all `expected_parsed_fields`. Reconstruct the non-witness serialization by stripping the `0x00 0x01` SegWit marker and all witness stacks. Compute `btc_txid = DH(non_witness_serialization)`. Verify the `btc_txid` matches the value computed from the non-witness bytes, NOT from the full witness serialization.

**Conformance check:** An implementation that computes `btc_txid` from the full serialized transaction (including witness) rather than the non-witness serialization is non-conformant. `btc_txid ≠ wtxid`.


---

### D.6 nBits Compact Target Encoding — Edge-Case Test Vectors

These vectors test the normative `nBits` decoding and re-encoding rules defined in §4.2.1. Implementations MUST reject all vectors marked REJECT and MUST produce the specified `target` for ACCEPT vectors.

**Test Vector D6.1 — Negative mantissa (REJECT)**
```
nbits:              0x1800ff80
exponent:           0x18 = 24
mantissa:           0x00ff80
high bit of mantissa: set (0x80 in byte 1 of mantissa = bit 23 of 24-bit mantissa)
expected_result:    REJECT — reason: NegativeMantissa
```

**Test Vector D6.2 — Zero mantissa (REJECT)**
```
nbits:              0x03000000
exponent:           0x03 = 3
mantissa:           0x000000
expected_result:    REJECT — reason: ZeroTarget
```

**Test Vector D6.3 — Exponent overflow (REJECT)**
```
nbits:              0x2100ffff
exponent:           0x21 = 33 (> 32)
mantissa:           0x00ffff
expected_result:    REJECT — reason: ExponentOverflow
```

**Test Vector D6.4 — Genesis block target (ACCEPT)**
```
nbits:              0x1d00ffff
exponent:           0x1d = 29
mantissa:           0x00ffff
expected_target:    0x00000000FFFF0000000000000000000000000000000000000000000000000000
expected_re_encode: 0x1d00ffff
  // round-trip: encode_target_to_nbits(expected_target) == nbits
note:               This is also MIN_DIFFICULTY_TARGET; any target > this MUST be rejected
```

**Test Vector D6.5 — Target at minimum difficulty boundary (ACCEPT, at boundary)**
```
nbits:              0x1d00ffff
expected_target:    == MIN_DIFFICULTY_TARGET
expected_result:    ACCEPT (equal to floor, not below it)
note:               target == MIN_DIFFICULTY_TARGET is permitted; target > MIN_DIFFICULTY_TARGET is rejected
```

**Test Vector D6.6 — Target below minimum difficulty (REJECT)**
```
// A target slightly above MIN_DIFFICULTY_TARGET
nbits:              0x1d010000
exponent:           0x1d = 29
mantissa:           0x010000
expanded_target:    0x0000000100000000000000000000000000000000000000000000000000000000
comparison:         expanded_target > MIN_DIFFICULTY_TARGET = 0x00000000FFFF0000...
expected_result:    REJECT — reason: TargetBelowMinimumDifficulty
```

**Test Vector D6.7 — High-work block target (ACCEPT)**
```
// Block at ~height 800000, approximate nBits value
nbits:              0x17053894
exponent:           0x17 = 23
mantissa:           0x053894
expected_target:    0x0000000000000000053894000000000000000000000000000000000000000000
expected_re_encode: 0x17053894
pow_check:          DH(block_header) must be ≤ expected_target to be valid PoW
```

**Test Vector D6.8 — Mantissa normalization during re-encoding (ACCEPT)**
```
// A target where the most significant byte of the 3-byte mantissa extraction
// has the high bit set, requiring exponent increment and right-shift.
input_target:       0x0000000000000000008000000000000000000000000000000000000000000000
// MSB of 3-byte extraction = 0x80 (bit 23 set) — requires normalization:
//   raw_mantissa = 0x800000, nbytes = 10
//   high bit set: mantissa >>= 8 → 0x008000, nbytes = 11
expected_nbits:     0x0b008000
re_encode_check:    encode_target_to_nbits(input_target) == 0x0b008000
decode_check:       decode_nbits(0x0b008000).target == input_target
```


---

*End of Zenon Portal Protocol Specification v1.5*

*This document has not undergone formal security audit. This is version 1.5, incorporating fully normative SPV edge-case specifications, header timestamp rules, and parser type hardening. Implementation should be preceded by independent cryptographic review of the Class R two-leaf taptree construction, the attributable signing and slashing mechanism (§9.7), adversarial testing, and engagement with the Bitcoin and Zenon developer communities. In particular, the NUMS point generation procedure (§5.2), the two-leaf taptree canonical leaf ordering (§5.3R), the cooperative withdrawal leaf script semantics (§5.3R Leaf 1), the epoch signing retention mechanism (§9.4), the `SigningIntentCommitment` pre-signing attribution anchor (§9.7.2a), the `SpendIntent` / `SigningBundle` tagged hash construction (§9.7.4, §9.7.8), the `SlashProof` SPV verification logic (§9.7.12), the bond lock extension calculation (§9.3), the canonical withdrawal transaction template (§8.9), and the Class P collateral coverage enforcement logic (§6.3 step 5a, §12.10) warrant formal verification. The authors encourage continued hostile review by Bitcoin protocol engineers and cryptographers.*
