# ZENON PORTAL
## A Bitcoin–Zenon Interoperability Protocol

**Protocol Specification — Final**
**Status:** Final · **Category:** Cross-Chain Protocol Design
**Target Audience:** Bitcoin Core developers · Cryptography researchers · Bridge security auditors · Distributed systems academics

**Design philosophy:** custody first, liquidity second, honest threat modeling.

---

## Abstract

Zenon Portal is a bridge protocol using Bitcoin as the custody and settlement layer and Zenon Network as the execution layer. Bitcoin deposits are locked in Taproot escrow UTXOs. Zenon verifies deposits via SPV proofs and credits eBTC to depositors. Withdrawals are processed by a permissionless relayer market with contract-enforced bond obligations.

**Per-deposit key isolation.** Each Class R UTXO uses a deposit-specific signing key derived as `deposit_key = H_tweak(frost_epoch_key || deposit_id)`. The Taproot key path is constructed as `MuSig2(deposit_key, pk_u)` per BIP-327 + BIP-341. Key-path theft for any single deposit requires simultaneous compromise of the derived deposit key AND the depositor key. Epoch compromise does not propagate across deposits. Blast radius is O(1) per deposit, not O(N) per epoch. See §5.14 and §3.9.

**eBTC tiers.** eBTC exists in two security tiers with on-chain queryability and event-log aggregation. See §7.

**Single-hop secret delegation; multi-hop via capability delegation.** Secret delegation is limited to one hop (depositor → designated holder). Multi-hop transfer uses capability delegation chains, which propagate authorization rather than the adaptor secret. Known Limitation #45 (superseded-holder race) is eliminated by design. See §7.8 and §7.11.

**Hybrid SPV verification with implementation diversity and permissionless slashing.** Deposits require both SPV verifier acceptance AND quorum attestation. Quorum nodes must declare a distinct Bitcoin implementation from the on-chain SPV verifier. Dishonest quorum nodes can be permissionlessly slashed via on-chain challenge. See §4.8.

**FROST DKG transparency.** DKG transcripts are published to Zenon and verified to include all registered relayers above minimum bond. Cartel exclusion is on-chain detectable. See §9.19.

**Bootstrap security halt.** New deposit acceptance is suspended until `MIN_HEADER_RELAY_NODE_COUNT` independent quorum nodes are registered. No SPV-only fallback during bootstrap. See §4.8.3.

**Contract-enforced circuit-breaker (automated).** Deposit acceptance is automatically paused by the Zenon contract when the stealable fraction exceeds the bond ceiling. Contract logic, not governance norm. Manual governance circuit-breakers are removed from the safety-critical path.

**Class P. MUST NOT be enabled at deployment.** Architecture isolated in Appendix P. See §P.

---

## Table of Contents

1. Introduction
2. System Architecture
3. Cryptographic Primitives and Notation
4. Bitcoin SPV Verification
5. Deposit Escrow Script Design
6. Deposit Registration Protocol
7. eBTC State Model — Tiered Guarantee Structure
8. Withdrawal Protocol
9. Relayer System
10. Refund Path
11. UTXO Mapping and Consolidation
12. Security Model
17. Conclusion: Formal Worst-Case Guarantee
18. References
19. Implementation Compliance

Appendix A. Protocol Parameter Table
Appendix B. State Machines
Appendix C. Implementation Checklist
Appendix D. Normative Test Vectors
Appendix L. Delegation Mode Selection Guide (informational)
Appendix P. Class P Architecture — MUST NOT IMPLEMENT

---

## 1. Introduction

### 1.1 Motivation and Honest Positioning

Bitcoin has no native cross-chain execution capability. Any protocol that wraps Bitcoin value on another chain must operate within Bitcoin's scripting constraints and the fundamental limitations of cross-chain messaging. Zenon Portal's design philosophy is to reach the maximum security ceiling achievable under those constraints — not to market around them.

The remaining limitations documented in §12.20 are consequences of Bitcoin's scripting model, not protocol design choices. The honest characterization of those limits is a first-class design requirement.

### 1.2 Scope

This specification covers: per-deposit derived signing keys for UTXO blast-radius isolation; MuSig2-hardened Taproot key path for Class R UTXOs; single-hop secret delegation with multi-hop via capability delegation chains; quorum implementation diversity and permissionless slashing; FROST DKG transcript verification; deposit halt during bootstrap; Class P isolation.

### 1.3 Design Principles

1. Bitcoin custody is the security foundation. All other properties are layered atop Bitcoin's unilateral exit guarantee.
2. Honest threat modeling is non-negotiable. No property is claimed that cannot be proven under the stated assumptions.
3. Economic deterrence is bounded. The circuit-breaker enforces that stealable TVL never exceeds total slashable bonds.
4. The adaptor mechanism is the atomicity primitive. Its security derives from Schnorr adaptor properties, not trust.
5. Tier transparency is a first-class requirement. eBTC holders must be able to verify the security tier of their holdings on-chain.
6. Depositor unilateral exit is unconditional after ABSOLUTE_EXPIRY.
7. UTXO isolation is enforced at the key level. Each deposit uses a derived signing key; epoch compromise does not aggregate into multi-deposit theft.
8. Governance is not a safety mechanism. Safety responses are exclusively automated.
9. Bootstrap periods are security windows, not operational inconveniences. Deposit acceptance halts rather than falls back to a weaker verification model.
10. Single-hop secret delegation is the maximum secure depositor-absent exit delegation. The adaptor secret `t` MUST be disclosed to exactly one designated holder, never re-encrypted through a chain.
11. Verification redundancy requires implementation diversity, not just organizational diversity. Quorum implementation diversity is a normative security requirement, not an operational recommendation.
12. DKG ceremony transparency is a prerequisite for economic deterrence against cartel formation. DKG transcripts are normative on-chain artifacts.
13. Taproot key path construction determines the compromise blast radius. Per-deposit key derivation reduces the blast radius from O(N) per epoch to O(1) per deposit.

### 1.4 Relationship to Existing Work and Anticipated Criticisms

**On per-deposit key derivation:** The derivation `deposit_key = H_tweak(frost_epoch_key || deposit_id)` produces a key unique to each deposit. The FROST epoch signing group still controls the epoch key from which deposit keys are derived. However, because each deposit key is distinct, a relayer cartel cannot reuse signing material across deposits — each UTXO requires a fresh adaptor pre-signature under the deposit-specific key. The security gain over epoch-scoped signing is that even a total epoch key compromise, combined with arbitrary depositor key compromises, cannot be applied uniformly: each UTXO requires independent depositor cooperation under its unique deposit key. The MuSig2 aggregation with `pk_u` ensures the depositor remains a required party for key-path spending of any individual UTXO.

**On MuSig2 key path hardening:** The MuSig2 aggregation requires a one-time key aggregation ceremony at UTXO construction time. Implementations MUST provide tooling to support this ceremony.

### 1.5 Bridge Failure Mode Taxonomy

| Category | Failure Mode | Protocol Response |
|---|---|---|
| SPV bug | Incorrect block accepted | Quorum blocks mint; impl diversity prevents correlated failure |
| FROST threshold compromise | Epoch key reconstructed | Per-deposit key derivation limits blast radius to individual UTXOs |
| Depositor key compromise | Single UTXO key-path exposed | Requires FROST threshold compromise simultaneously |
| Relayer cartel | Off-protocol signing | Bond slashing; circuit-breaker halts deposits above TVL ceiling |
| Quorum capture | False attestation | Permissionless challenge; automatic slashing |
| Silent DKG exclusion | Parallel epoch key | DKG transcript verification; DKGExclusionComplaint slashing |
| Bootstrap failure | Insufficient quorum | Deposit HALT; no SPV-only fallback |

---

## 2. System Architecture

### 2.1 Logical Layers

```
Bitcoin Network
  └── Taproot UTXOs (per-deposit key path; Leaf 1 adaptor; Leaf 2 CLTV)
Zenon Network
  └── Portal Contract
        ├── SPV Verifier
        ├── Header Relay Quorum Registry (implementation-tag gated)
        ├── DKG Transcript Registry
        ├── SpendIntent Ledger
        ├── eBTC Token State (tiered)
        └── Delegation Registry
```

### 2.2 Trust Assumptions

| ID | Assumption | Component | Failure Impact |
|---|---|---|---|
| A1 | Depositor controls sk_u | Depositor | Key-path theft requires FROST threshold + depositor key + deposit-specific derivation |
| A2 | FROST t-of-n threshold honest majority | Relayer set | Threshold compromise + depositor compromise still limited to O(1) per deposit |
| A3 | Header relay quorum has ≥ k honest members using a codebase DISTINCT from the on-chain SPV verifier | Header relay quorum | Deposit pause if quorum disagrees with SPV; NOT unbounded mint |
| A4 | Zenon contract executes as specified | Zenon consensus | Catastrophic if violated |
| A5 | Bitcoin consensus is live and honest | Bitcoin network | Unconditional exits unavailable if violated |
| A6 | Capability delegation depositor is reachable and willing to complete adaptor signature when delegation-chain tip requests withdrawal | Depositor (capability delegation mode only) | Withdrawal blocked until depositor responds or ABSOLUTE_EXPIRY; Leaf 2 remains available |
| A7 | FROST DKG ceremony includes all registered relayers above minimum bond; transcript is published and verifiable | Relayer set / DKG ceremony | If transcript missing or incomplete: epoch key derived from non-canonical relayer set; accountability enforcement degraded |
| A8 | Depositor participates in MuSig2 key aggregation at deposit construction time | Depositor (key path setup) | If depositor refuses: UTXO cannot be constructed under hardened key path |

### 2.3 Component Descriptions

**Bitcoin Layer.** Taproot UTXOs constructed per §5.14. Three spending paths: MuSig2 key path (bilateral clean exit), Leaf 1 adaptor script (standard withdrawal), Leaf 2 CLTV (unilateral depositor exit).

**Zenon Portal Contract.** Stateful contract on Zenon Network managing: deposit registration, eBTC minting/burning, SpendIntent state, tier assignment, delegation registry, DKG transcript registry, quorum node registry, circuit-breaker logic.

**SPV Verifier.** On-chain component verifying Bitcoin SPV proofs per §4. Tagged with a declared implementation identifier. Cannot share a codebase tag with any registered quorum node.

**Header Relay Quorum.** Registered nodes publishing signed Bitcoin header attestations. Bonded; subject to permissionless challenge and slashing. Must use a Bitcoin implementation distinct from the on-chain SPV verifier.

**DKG Transcript Registry.** On-chain data store holding published FROST DKG transcripts per epoch. Contract verifies transcript completeness and signature before accepting epoch key.

**Relayer Market.** Permissionless relayer set managing FROST signing, adaptor pre-signature publication, and Bitcoin broadcast. Epoch-anchored bond obligations enforced by contract.

### 2.4 Failure Containment Model

#### 2.4.1 Contract-Enforced Circuit-Breaker

The Zenon contract automatically suspends new deposit acceptance when:

- **TVL/bond ratio trigger:** stealable fraction of all Class R UTXOs in the current epoch exceeds `STEALABLE_FRACTION_CEILING / total_slashable_bonds`. No governance action required.
- **Bootstrap trigger:** registered independent quorum nodes < `MIN_HEADER_RELAY_NODE_COUNT`. Hard gate; not configurable.
- **Quorum recovery trigger:** if registered independent quorum nodes drop below `MIN_HEADER_RELAY_NODE_COUNT` at any point during operation (e.g., after permissionless slashing), deposit acceptance is suspended until sufficient nodes re-register. No SPV-only fallback.

#### 2.4.2 Governance Role (Non-Safety-Critical Only)

Manual governance is NOT in the safety-critical path. Governance retains the ability to adjust non-safety-critical parameters: relayer registration thresholds, epoch rotation periods, fee parameters. Safety responses — deposit pause, quorum node slashing, bond burning — are exclusively automated via contract logic or permissionless on-chain challenge. This eliminates governance capture as a safety attack vector.

### 2.5 Primary Evidence Architecture

The primary on-chain evidence channel provides all data required for automated enforcement: SpendIntent state, accountability key records, epoch commitments, DKG transcripts, quorum attestation records. All normative slashing rules are enforceable exclusively from on-chain state.

A gossip residual layer is preserved as an informational liveness mechanism in Appendix E. It is not normative and is not required for any safety-critical operation.

---

## 3. Cryptographic Primitives and Notation

### 3.1 Notation

| Symbol | Definition |
|---|---|
| `sk_u` | Depositor's Schnorr private key |
| `pk_u` | Depositor's Schnorr public key (`sk_u · G`) |
| `frost_epoch_key` | FROST DKG aggregate public key for the current epoch |
| `deposit_id` | Unique identifier for a deposit (bytes32) |
| `deposit_key` | Per-deposit derived signing key (see §3.9) |
| `musig2_agg_key` | MuSig2 aggregate of `deposit_key` and `pk_u` |
| `taproot_output_key` | Final P2TR output key (Taproot-tweaked `musig2_agg_key`) |
| `t` | Adaptor secret scalar |
| `σ■` | Adaptor pre-signature |
| `σ` | Completed Schnorr signature (`σ■ + t`) |
| `H_tweak` | Tagged hash function for key derivation |
| `tagged_hash(tag, msg)` | BIP-340 tagged hash |

### 3.2 – 3.6 Standard Primitives

Schnorr signatures per BIP-340. Taproot construction per BIP-341. FROST threshold signing per RFC 9591. MuSig2 key aggregation and two-round signing per BIP-327. ECIES encryption using the depositor's key for adaptor secret delegation.

### 3.7 Ephemeral Adaptor Secret Construction

The adaptor secret `t` for deposit `deposit_id` is derived deterministically:

```
t = H_adaptor(sk_u || deposit_id || intent_id)
```

`t` is bound to a specific `intent_id`, which is bound to a specific UTXO. The adaptor mechanism operates entirely through the Leaf 1 script path. The MuSig2 key path is a separate, independent spending path.

### 3.8 Rebindable Class R Exit Rights — Constraint Analysis

The adaptor secret `t` is bound to `intent_id`, which is bound to a specific UTXO. The per-deposit key path hardening (§5.14) does not affect adaptor binding — the adaptor mechanism operates on the Leaf 1 script path, independent of the Taproot key path construction.

### 3.9 Per-Deposit Key Derivation and MuSig2 Construction

The Taproot key path uses a per-deposit signing key, not the raw epoch key. This reduces the blast radius of any epoch key compromise from O(N) deposits to O(1) per deposit.

**Step 1: FROST epoch aggregate key**
```
frost_epoch_key := FROST_DKG_aggregate(relayer_1, ..., relayer_n)
    // per RFC 9591; DKG transcript published per §9.19
```

**Step 2: Per-deposit key derivation**
```
deposit_key := H_tweak(frost_epoch_key || deposit_id)
    // tagged hash: tagged_hash('Zenon/DepositKey/v1', frost_epoch_key || deposit_id)
    // deposit_id: bytes32 unique identifier registered at deposit creation
    // deposit_key is a scalar tweak applied as: deposit_key_point = frost_epoch_key + H_tweak(...) · G
```

**Step 3: MuSig2 key aggregation with depositor key**
```
musig2_agg_key := MuSig2_KeyAgg([deposit_key_point, pk_u])
    // per BIP-327 §3.1.1
    // Canonical key ordering: [deposit_key_point, pk_u]
```

**Step 4: Taproot output key**
```
taproot_output_key := taproot_tweak(musig2_agg_key, merkle_root)
    // per BIP-341 §Script Trees
    // merkle_root commits to Leaf 1 (adaptor script) and Leaf 2 (pk_u CLTV)
```

**Security property of per-deposit derivation:** Because `deposit_key` is a deterministic function of `frost_epoch_key` and `deposit_id`, the FROST epoch signing group can still produce adaptor pre-signatures for any deposit in the epoch — this is required for the standard withdrawal flow. However, a key-path spend on any individual UTXO requires `MuSig2(deposit_key_point, pk_u)`, meaning the depositor for that specific UTXO must cooperate. An attacker who compromises the epoch key gains the ability to derive all `deposit_key` values — but cannot spend any UTXO without also compromising the corresponding `pk_u`. Each UTXO remains an independent target.

---

## 4. Bitcoin SPV Verification

### 4.1 – 4.7 SPV Verifier Rules (H1–H12)

The on-chain SPV verifier validates Bitcoin block headers and transaction inclusion proofs. Verification rules H1–H12 enforce: proof-of-work validity, chain work threshold (`MIN_CHAIN_WORK`), checkpoint anchoring, Merkle path correctness, coinbase maturity, and transaction depth requirements. The verifier is tagged with a declared implementation identifier used for quorum diversity enforcement.

### 4.8 Header Relay Quorum — Hybrid Verification Layer

#### 4.8.1 Motivation

The SPV verifier is the most dangerous single component in the protocol: any implementation divergence from Bitcoin consensus enables unbounded eBTC minting. The header relay quorum converts SPV-bug failure from "silent unbounded mint" to "requires two simultaneous failures." Implementation diversity ensures a systematic library bug cannot cause both to fail identically.

#### 4.8.2 Header Relay Node Architecture

Header relay nodes publish signed attestations of the canonical Bitcoin header chain. Each node registers with:

```
HeaderRelayNodeRegistration {
    node_id:            bytes32,   // derived from attestation_pk
    attestation_pk:     bytes33,   // long-lived Schnorr key
    implementation_tag: bytes32,   // tagged_hash of: client_software_name || version_string
                                   // e.g. tagged_hash('Zenon/ImplTag/v1', 'Bitcoin Core 27.1')
    registration_bond:  uint64,    // bonded ZNN at registration
}
```

The Zenon contract MUST reject registration when:

- Node's `attestation_pk` matches any registered relayer's accountability key (key distinctness requirement).
- Node's `implementation_tag` resolves to the same codebase name as the on-chain SPV verifier's declared `implementation_tag` (implementation diversity requirement). An `implementation_tag` matches if it resolves to the same codebase name after tag parsing, regardless of version string.
- Node's `registration_bond` < `MIN_QUORUM_NODE_BOND`.

#### 4.8.3 Deposit Acceptance Rule

A deposit SPV proof MUST satisfy ALL THREE conditions before the Zenon contract mints eBTC:

- **Condition 1 — SPV validity:** proof passes H1–H12 verifier rules, checkpoint validation, and `MIN_CHAIN_WORK` threshold.
- **Condition 2 — Quorum attestation:** at least `HEADER_RELAY_QUORUM_THRESHOLD` distinct header relay nodes have published `HeaderAttestation` entries attesting to the same tip block hash within `HEADER_ATTESTATION_WINDOW` Zenon blocks.
- **Condition 3 — Bootstrap gate:** registered independent quorum nodes MUST be ≥ `MIN_HEADER_RELAY_NODE_COUNT`. If not, deposit acceptance is SUSPENDED — NOT fallen back to SPV-only. This gate remains active until the minimum quorum count is restored.

**CRITICAL:** There is no SPV-only fallback under any condition. A deposit halt during quorum recovery is a liveness pause, not a safety degradation.

#### 4.8.4 Quorum Failure Modes

| Scenario | SPV Result | Quorum Result | Deposit Outcome |
|---|---|---|---|
| Normal operation | Accept | Attests same chain | ✓ Accepted |
| SPV bug, quorum honest, distinct impl | Accept (incorrect) | Does not attest (different bug surface) | ✗ Blocked — deposit pause |
| SPV bug, quorum shares impl | Accept (incorrect) | — | PREVENTED by registration rule |
| SPV correct, quorum slow | Accept | Not yet attested | ✗ Blocked temporarily — retryable |
| SPV correct, quorum majority captured | Accept | Attests wrong chain | ✗ Blocked — permissionless challenge available |
| SPV bug AND quorum majority captured, distinct impls | Accept (incorrect) | Attests same wrong chain | ✗ Unbounded mint — requires two independent impl-diverse failures |
| Quorum count below MIN (bootstrap or after slashing) | Accept | Insufficient nodes | ✗ Deposits SUSPENDED — no fallback |

#### 4.8.5 Permissionless Quorum Node Challenge

Any party may submit an on-chain challenge against a registered quorum node that has attested to an incorrect Bitcoin header chain:

```
QuorumNodeChallenge {
    challenged_node_id: bytes32,
    attestation_ref:    bytes32,   // hash of the challenged HeaderAttestation
    challenge_headers:  bytes[],   // Bitcoin header chain contradicting attestation
                                   // must span from a checkpoint to the claimed tip
    challenge_sig:      bytes64,   // challenger's Schnorr sig (for bond claim)
}
```

Challenge resolution:

- The contract verifies `challenge_headers` using the SPV verifier (H1–H12 rules + checkpoint + `MIN_CHAIN_WORK`).
- If `challenge_headers` is valid and contradicts the challenged node's attestation: node's `registration_bond` is automatically slashed to the contract treasury; node is marked INACTIVE; challenger receives `CHALLENGE_REWARD` from the slashed bond.
- If `challenge_headers` is invalid: challenge is rejected; challenger's submission bond is slashed (prevents griefing).
- Governance is NOT involved in challenge resolution. The contract enforces the outcome automatically. Governance retains only the ability to adjust `CHALLENGE_REWARD` and submission bond parameters, subject to the `CHALLENGE_REWARD_FLOOR` minimum.

```
CHALLENGE_REWARD           = 20% of challenged node bond   // [PROPOSED]
CHALLENGE_SUBMISSION_BOND  = 10 ZNN                        // [PROPOSED]
```

#### 4.8.6 Independence Requirements

Header relay nodes MUST satisfy all of:

- **Key distinctness:** `attestation_pk` MUST NOT match any registered relayer's accountability key.
- **Implementation diversity:** `implementation_tag` MUST resolve to a codebase name distinct from the on-chain SPV verifier's declared codebase. Enforced at registration. Re-checked at each quorum attestation: attestations from a node whose `implementation_tag` has been invalidated are rejected.
- **Bond requirement:** `registration_bond` ≥ `MIN_QUORUM_NODE_BOND`. Slashable via permissionless challenge.

```
MIN_QUORUM_NODE_BOND = 100 ZNN   // [PROPOSED; OPEN — BLOCKING]
```

#### 4.8.7 Incentive Design

Header relay nodes receive:

- Per-attestation fee paid from the deposit fee pool when the attestation contributes to a successful deposit acceptance.
- Bond at risk: incorrect attestation → permissionless slashing via §4.8.5.

---

## 5. Deposit Escrow Script Design

### 5.1 – 5.13 Standard Deposit Escrow

Class R UTXOs are constructed as P2TR outputs on Bitcoin. Script tree structure (Leaf 1, Leaf 2) and UTXO lifecycle are as specified in the base protocol. Leaf 1 implements the adaptor-based cooperative withdrawal. Leaf 2 implements the depositor unilateral exit backstop via `pk_u OP_CHECKSIGVERIFY OP_CHECKLOCKTIMEVERIFY`.

Per-deposit configurable fallback delays allow depositors to set `ABSOLUTE_EXPIRY` within the allowed protocol range at deposit construction time.

### 5.14 Taproot Key Path — Per-Deposit Derived Key with MuSig2 Construction

#### 5.14.1 Motivation

Without per-deposit key derivation, the Taproot key path is controlled by the FROST epoch aggregate key (possibly hardened with `pk_u`). Any epoch key compromise can be applied uniformly to all UTXOs in the epoch, provided the attacker can also obtain per-depositor cooperation (or compromise per-depositor keys).

Per-deposit key derivation eliminates this uniform applicability. Each deposit produces a unique `deposit_key = H_tweak(frost_epoch_key || deposit_id)`. The MuSig2 aggregation with `pk_u` further requires the depositor's cooperation for any key-path spend. The result: no two UTXOs share the same key-path spend conditions. The blast radius of any epoch-level compromise is O(1) per deposit, not O(N) per epoch.

#### 5.14.2 Normative Script Construction

```
// === Class R Taproot UTXO Construction ===

// Step 1: FROST epoch aggregate (published DKG transcript per §9.19)
frost_epoch_key := FROST_DKG_aggregate(relayer_1, ..., relayer_n)

// Step 2: Per-deposit key derivation
deposit_key_scalar := H_tweak('Zenon/DepositKey/v1', frost_epoch_key || deposit_id)
deposit_key_point  := frost_epoch_key + deposit_key_scalar · G

// Step 3: MuSig2 key aggregation with depositor key
musig2_agg_key := MuSig2_KeyAgg([deposit_key_point, pk_u])
    // per BIP-327 §3.1.1
    // Canonical ordering: [deposit_key_point, pk_u] — MUST be consistent across implementations

// Step 4: Taproot script tree
leaf_1      := <adaptor withdrawal script>          // see §5.X
leaf_2      := pk_u OP_CHECKSIGVERIFY
               <ABSOLUTE_EXPIRY> OP_CHECKLOCKTIMEVERIFY OP_DROP OP_TRUE
merkle_root := TapBranch(TapLeaf(leaf_1), TapLeaf(leaf_2))

// Step 5: Taproot output key
taproot_output_key := taproot_tweak(musig2_agg_key, merkle_root)   // per BIP-341

// Resulting output:
// P2TR: OP_1 <taproot_output_key>
```

#### 5.14.3 Spending Paths

| Path | Spending Condition | Who Controls | Use Case |
|---|---|---|---|
| Key path | Valid Schnorr sig under `taproot_output_key = MuSig2(deposit_key_point, pk_u)` | FROST threshold (for deposit_key) + depositor BOTH must cooperate | Clean bilateral exit; NOT standard withdrawal path |
| Leaf 1 (script path) | Adaptor withdrawal: relayer provides σ■; holder completes σ = σ■ + t | Relayer (adaptor) + authorized holder (t) + Zenon IsTier1 gate | Standard cooperative withdrawal for Tier 1 holders |
| Leaf 2 (script path) | `pk_u` signature + ABSOLUTE_EXPIRY elapsed | Depositor alone | Unilateral exit backstop; unconditional after timelock |

#### 5.14.4 Relayer Signing Under Per-Deposit Key Derivation

Relayers produce adaptor pre-signatures via FROST partial signatures under the `deposit_key_point` for each UTXO. Because `deposit_key_point = frost_epoch_key + H_tweak(...) · G`, relayers can compute the per-deposit key deterministically given `frost_epoch_key` and `deposit_id`. The FROST signing protocol is unchanged; the per-deposit key derivation is an additive tweak applied before signing.

Each adaptor pre-signature `σ■` is bound to the specific `deposit_key_point` of its UTXO. Adaptor pre-signatures from one deposit cannot be applied to another.

#### 5.14.5 Deposit Construction Protocol

1. **Step 1.** Depositor requests the current epoch's `frost_epoch_key` from any registered relayer or from the Zenon contract's published epoch registry.
2. **Step 2.** Depositor receives the assigned `deposit_id` from the Zenon contract (pre-registration step).
3. **Step 3.** Depositor computes `deposit_key_point` and `musig2_agg_key` locally per §5.14.2. No interaction with relayers is required for this computation.
4. **Step 4.** Depositor constructs the Taproot output key as specified in §5.14.2 and broadcasts the funding transaction.
5. **Step 5.** Depositor MUST verify the Taproot output key before broadcasting: the expected key must match the actual output key in the transaction. Mismatch indicates a key substitution attack.
6. **Step 6.** Depositor proceeds with deposit registration (§6), submitting SPV proof of the confirmed UTXO.

#### 5.14.6 Impact on Existing Withdrawal Flows

The per-deposit key construction does NOT affect:

- **Leaf 1 (adaptor-based cooperative withdrawal):** entirely unchanged. The adaptor mechanism operates on the script path.
- **Leaf 2 (depositor unilateral exit):** entirely unchanged. Script path spend using `pk_u` + CLTV.
- **Tier 1/Tier 2 distinction:** unchanged. IsTier1 checks operate on Zenon state.
- **Delegation modes (§7.8, §7.11):** unchanged. Both operate through Leaf 1.

---

## 6. Deposit Registration Protocol

Deposit registration accepts a UTXO when ALL THREE conditions are satisfied:

- **Condition 1:** SPV validity (H1–H12 rules, checkpoint, `MIN_CHAIN_WORK`).
- **Condition 2:** Quorum attestation (`HEADER_RELAY_QUORUM_THRESHOLD` nodes within `HEADER_ATTESTATION_WINDOW` blocks).
- **Condition 3:** Bootstrap gate (registered quorum nodes ≥ `MIN_HEADER_RELAY_NODE_COUNT`). If not satisfied: SUSPEND deposit acceptance. No SPV-only fallback.

The Zenon contract records the UTXO's declared Taproot key path construction — specifically, whether it uses the per-deposit derived MuSig2-hardened key path per §5.14. Deposits with legacy key path construction (epoch aggregate key alone, or MuSig2 without per-deposit derivation) are assigned a lower tier ceiling than fully-hardened deposits.

The contract also records the `deposit_id` and verifies that the UTXO's Taproot output key matches the expected per-deposit MuSig2-hardened construction for the claimed epoch, `deposit_id`, and `pk_u`.

---

## 7. eBTC State Model — Tiered Guarantee Structure

### 7.1 Two-Tier Model

eBTC exists in two security tiers reflecting the cryptographic guarantees of the underlying UTXO:

- **Tier 1:** Full protocol guarantees. UTXO constructed with per-deposit MuSig2-hardened Taproot key path, verified DKG transcript, IsTier1 = true in Zenon state. Adaptor-based withdrawal; economic deterrence enforced by bond mechanism.
- **Tier 2:** SPV-only guarantees. UTXO registered without full key path hardening, or associated with a rejected/missing DKG transcript. No IsTier1 privilege; adaptor withdrawal not guaranteed.

### 7.2 – 7.7 Tier Transparency, Queryability, and DeFi Integration

The Zenon contract exposes `IsTier1(deposit_id) → bool` for on-chain queryability. A tier event log aggregates all tier assignments and transitions. DeFi contracts integrating eBTC MUST query `IsTier1` before treating eBTC as having Tier 1 guarantees. eBTC from deposits without per-deposit key derivation hardening is not fungible with fully-hardened Tier 1 eBTC for the purposes of the security model.

### 7.8 Single-Hop Secret Delegation

#### 7.8.1 Motivation and Scope

Secret delegation is limited to a single hop. There are no multi-hop secret chains; there are no superseded holders. The depositor designates exactly one holder of `t` in a direct `AdaptorDelegation`. That holder may subsequently re-delegate using capability delegation certificates (§7.11) that route back through the depositor for final adaptor completion.

#### 7.8.2 Single-Hop AdaptorDelegation Construction

```
AdaptorDelegation {
    deposit_id:     bytes32,
    delegate_pk:    bytes33,     // exactly ONE designated holder
    encrypted_t:    bytes,       // ECIES encryption of t under delegate_pk
    delegation_sig: bytes64,     // Schnorr sig under sk_u over:
                                 //   tagged_hash('Zenon/AdaptorDeleg/v1',
                                 //   deposit_id || delegate_pk || H(encrypted_t))
    zenon_height:   uint64,
}
```

The Zenon contract MUST reject any `ChainDelegationExtension` message for deposits registered under this protocol. Single-hop is enforced at the contract level.

```
// Contract enforcement
if deposit.protocol_version >= CURRENT and msg.type == ChainDelegationExtension:
    REJECT   // multi-hop secret delegation not permitted
```

#### 7.8.3 Security Properties

- **Superseded-holder race condition (KL #45):** ELIMINATED BY DESIGN. There is exactly one holder of `t` at any time.
- **Off-protocol race:** the designated holder retains `t` after delegation. Collusion with a compromised relayer is bounded by the selection of the delegate.
- **Depositor revocation:** the depositor can submit a `RevocationMsg` to Zenon, invalidating the delegate's Tier 1 status. This does not prevent an off-protocol Bitcoin spend if the delegate has already obtained `σ■` through relayer complicity.
- **Leaf 2 depositor backstop:** always available to the depositor after `ABSOLUTE_EXPIRY`.

#### 7.8.4 Limitations

- No depositor-absent multi-hop re-delegation via secret delegation. Multi-hop requires capability delegation (§7.11) with depositor availability at withdrawal.
- Pool DeFi contracts without ECIES keys: not addressable without covenants.
- Delegate key loss: the depositor's Leaf 2 path remains available after `ABSOLUTE_EXPIRY`.

### 7.9 Threshold Aggregate Delegation

The depositor may designate a threshold MPC aggregate as the recipient of `t`, enabling institutional custody configurations where no single party holds the adaptor secret outright.

### 7.10 Reference Collateral Scoring Interface

Optional external service specification. Protocol implementations are not required to implement or expose this interface. See Appendix E for the informational specification.

### 7.11 Capability Delegation Mode

#### 7.11.1 Role

Capability delegation is the ONLY mechanism for multi-hop re-delegation. It does not propagate `t` at any point. The depositor designates a chain of authorized parties via delegation certificates; the depositor is required only when the final withdrawal is executed.

#### 7.11.2 Authorization Certificate Construction

```
DelegationCert {
    deposit_id:    bytes32,
    delegate_pk:   bytes33,       // authorized holder's public key
    cert_nonce:    bytes32,       // H(deposit_id || delegate_pk || Zenon_height)
    expiry_height: uint64,
    cert_sig:      bytes64,       // Schnorr sig under sk_u over:
                                  //   tagged_hash('Zenon/DelegationCert/v1',
                                  //   deposit_id || delegate_pk ||
                                  //   cert_nonce || expiry_height)
}
```

Multi-hop chains extend via `DerivedDelegationCert`, signed by the current chain tip, without depositor involvement at re-delegation time. Depositor involvement is required only when the withdrawal is actually executed.

#### 7.11.3 Withdrawal Flow Under Capability Delegation

1. Chain tip submits `WithdrawalRequestMsg` including full certificate chain.
2. Zenon contract verifies certificate chain from `DelegationCert` to current tip.
3. Contract publishes `DepositorCompletionRequest`.
4. Depositor computes `t = H_adaptor(sk_u || intent_id)` and submits `AdaptorCompletionMsg`.
5. Relayer retrieves `t`, obtains FROST partial signature `σ_frost` under `deposit_key_point`, publishes `AdaptorPreSigBlob`.
6. Certificate chain tip uses `σ■` and `t` to compute `σ = σ■ + t` and broadcasts.

If depositor does not respond within `DEPOSITOR_COMPLETION_TIMEOUT`, the request enters `PendingDepositorCompletion` state. Leaf 2 remains available to the depositor after `ABSOLUTE_EXPIRY`.

```
DEPOSITOR_COMPLETION_TIMEOUT = 2016 Zenon blocks   // ~5 days [PROPOSED]
```

#### 7.11.4 Operational Comparison

| Property | Single-hop secret delegation (§7.8) | Capability delegation (§7.11) |
|---|---|---|
| Depositor liveness at withdrawal | Not required | Required |
| `t` distribution | Depositor + exactly one delegate (ECIES) | Depositor only (transiently published at withdrawal) |
| Superseded-holder race risk | None (single-hop: no superseded holders) | None (`t` never distributed) |
| Multi-hop support | No (single-hop only) | Yes (certificate derivation) |
| Pool DeFi support | No | No (requires depositor) |
| Institutional custody suitability | Moderate (single designated holder) | High (depositor controls timing) |
| Depositor-absent cooperative exit | Yes (for designated holder) | No (depositor must respond) |

---

## 8. Withdrawal Protocol

### 8.1 – 8.5 Standard Withdrawal Flow

The standard cooperative withdrawal proceeds through Leaf 1 for Tier 1 holders:

1. Authorized holder submits `WithdrawalClaimMsg` to Zenon, specifying `intent_id` and destination Bitcoin address.
2. Zenon contract verifies `IsTier1`, locks the `SpendIntent`, and emits `SpendIntentLocked`.
3. Assigned relayer computes FROST partial signatures under `deposit_key_point` for the specified UTXO.
4. Relayer publishes `AdaptorPreSigBlob` containing `σ■`.
5. Authorized holder obtains `t` (from direct delegation or capability delegation flow), computes `σ = σ■ + t`, and broadcasts the Bitcoin transaction spending via Leaf 1.
6. `t` is extracted from the broadcast transaction by the relayer, completing the Zenon-side accounting.

### 8.6 Secondary Holder Withdrawal Initiation

The secondary holder position is either: (a) the single designated holder in a direct `AdaptorDelegation` (§7.8), or (b) the current tip of a capability delegation certificate chain (§7.11). The withdrawal initiation flow for both cases follows §8.1–8.5 with the appropriate holder credential.

---

## 9. Relayer System

### 9.1 – 9.12 Relayer Registration and Epoch Management

Relayers register with bonded ZNN and accountability keys. Epoch management governs FROST DKG ceremony timing, key rotation, and bond lockup periods. Fee mechanics are determined by the relayer market. Dispute resolution for adaptor signature failures operates via the `SpendIntent` lock and bond enforcement mechanism.

### 9.13 Open Fallback Execution for Class R

If the assigned relayer fails to publish an `AdaptorPreSigBlob` within the `ADAPTOR_PUBLICATION_TIMEOUT`, any registered relayer may execute the fallback path: acquire the FROST partial signatures from the epoch signing group and publish the adaptor pre-signature. The original assigned relayer's bond is subject to slashing for abandonment.

### 9.14 – 9.18 Bond Mechanics and Accountability

Epoch-anchored slashing commitments; `SpendIntent` lock and automated bond enforcement; time-locked bond release after epoch expiry; accountability key pre-registration; relayer registration stake cap — as specified in the base protocol.

```
RELAYER_REGISTRATION_STAKE_CAP = 10% of total registered relayer bonds   // [PROPOSED]
```

### 9.19 FROST DKG Transcript Publication and Verification

#### 9.19.1 Motivation

Without DKG transcript transparency, a cartel of registered relayers could conduct a private DKG ceremony excluding honest relayers, producing an epoch key they alone control. Silent cartel formation is economically undeterrable if undetectable. DKG transcripts are published on-chain and verified to include all registered relayers above the minimum bond. Exclusion is an on-chain event that triggers bond slashing.

#### 9.19.2 DKG Transcript Publication

```
DKGTranscript {
    epoch_id:          uint64,
    participant_set:   bytes33[],    // sorted list of all participant pubkeys
    round1_msgs:       bytes[],      // FROST DKG Round 1 commitment messages
    round2_msgs:       bytes[],      // FROST DKG Round 2 encrypted shares
    epoch_key_claim:   bytes33,      // claimed frost_epoch_key output
    transcript_sig:    bytes64,      // Schnorr sig under epoch_key_claim over:
                                     //   tagged_hash('Zenon/DKGTranscript/v1',
                                     //   epoch_id || H(participant_set) ||
                                     //   H(round1_msgs) || H(round2_msgs) ||
                                     //   epoch_key_claim)
}
```

The `transcript_sig` is produced under the claimed epoch key. If the claimed epoch key was produced by a cartel sub-ceremony using different round messages, the participants cannot produce a valid `transcript_sig` for the declared inputs.

#### 9.19.3 Contract Verification Rules

The Zenon contract MUST:

- Verify that `participant_set` includes every registered relayer with bond ≥ `MIN_RELAYER_BOND` for the current epoch. Missing relayers → epoch key rejected.
- Verify that `transcript_sig` is a valid Schnorr signature under `epoch_key_claim` over the tagged transcript hash. Invalid signature → epoch key rejected.
- Verify that `epoch_key_claim` matches the `frost_epoch_key` used in the per-deposit key derivation for UTXOs registered for the epoch. Mismatch → UTXO registration rejected for the epoch.

An epoch with a rejected or missing DKG transcript is not a valid epoch. UTXOs claiming to belong to a transcript-less epoch are Tier 2, not Tier 1.

#### 9.19.4 Excluded-Relayer Slashing

```
DKGExclusionComplaint {
    epoch_id:       uint64,
    relayer_pk:     bytes33,    // excluded relayer's accountability key
    transcript_ref: bytes32,    // hash of the DKGTranscript
    complaint_sig:  bytes64,    // sig under relayer_pk
}
```

- If the contract confirms the relayer is registered with sufficient bond and is absent from `participant_set`: all participants in `participant_set` are slashed `EXCLUSION_PENALTY` pro-rata.
- If the excluded relayer submitted a parallel private DKG transcript: `EXCLUSION_SELF_PENALTY` applied.

```
EXCLUSION_PENALTY      = 10% of each participant bond      // [PROPOSED]
EXCLUSION_SELF_PENALTY = 50% of excluded relayer bond      // [PROPOSED]
```

---

## 10. Refund Path

Deposits that fail SPV verification, quorum attestation, or bootstrap gate checks may be refunded via the Zenon contract's refund mechanism. Refund claims require proof that the deposit registration was rejected and that `ABSOLUTE_EXPIRY` has not elapsed. After `ABSOLUTE_EXPIRY`, the Leaf 2 script path on Bitcoin provides unconditional unilateral exit independent of the Zenon contract.

---

## 11. UTXO Mapping and Consolidation

The `deposit_id` used in per-deposit key derivation is the primary key in the Zenon contract's UTXO registry. UTXO consolidation — combining multiple small deposits into fewer UTXOs — requires constructing new UTXOs with fresh `deposit_id` values and fresh per-deposit key derivations. Consolidated UTXOs are treated as new deposits for the purposes of epoch assignment and tier determination.

---

## 12. Security Model

### 12.1 – 12.11 Core Security Analysis

FROST security analysis, adaptor security, relayer bond analysis, epoch key management, UTXO isolation, circuit-breaker analysis, tier model security, delegation security — as specified in the base protocol, extended where noted by the per-deposit key derivation improvement.

**FROST + per-deposit derivation:** The FROST epoch key is the root of all per-deposit keys. Compromise of `frost_epoch_key` by a t-of-n threshold collusion enables the attacker to derive all `deposit_key_point` values. However, spending any individual UTXO via the key path still requires the corresponding depositor's cooperation (`pk_u`). Without per-deposit derivation, a single epoch key compromise combined with access to the adaptor pre-signature system would expose all UTXOs in the epoch simultaneously. With per-deposit derivation, each UTXO is an independent target requiring independent depositor compromise. The attack complexity scales linearly with the number of UTXOs targeted.

### 12.12 Governance Capture Scenarios

Manual governance is NOT in the safety-critical path. The residual governance attack surface:

- **Parameter manipulation:** governance can adjust non-safety-critical parameters (timeouts, fee structures, epoch rotation periods). These adjustments cannot cause immediate eBTC theft.
- **Quorum node registration manipulation:** the implementation diversity enforcement is contract-level, not governance-adjustable.
- **Challenge mechanism parameter manipulation:** `CHALLENGE_REWARD` and submission bond are governance-adjustable but bounded below by `CHALLENGE_REWARD_FLOOR`, which governance cannot reduce. This bound MUST be a contract minimum.

By removing manual governance from the safety-critical path and making core safety mechanisms contract-enforced, governance capture no longer has a direct path to immediate theft.

### 12.13 Class P Mechanism-Design Risk

Class P is isolated in Appendix P with MUST NOT IMPLEMENT. No Class P analysis appears in the normative §12 sections.

### 12.14 DA Evidence Availability

The gossip evidence channel and satellite DA layer are demoted to informational appendices. All normative slashing rules are enforceable from on-chain primary evidence alone. Satellite DA unavailability does not affect safety or slashing correctness — only the speed of evidence discovery for manual investigation.

### 12.15 – 12.19

Relayer market centralization risk, satellite/relayer identity overlap, secondary holder position analysis, tier gap characterization, and fungible pricing of non-equivalent security are discussed in the extended security analysis. The per-deposit key derivation reduces (but does not eliminate) the practical impact of relayer centralization, since a centralized relayer cartel must still target depositors individually rather than sweeping an epoch.

### 12.20 Remaining Hard Limits

#### 12.20.1 Properties Achievable Under Current Scripting Model

| Property | Mechanism | Contract-Enforced? |
|---|---|---|
| Depositor unilateral exit | Leaf 2 CLTV+CHECKSIG | Yes (Bitcoin script) |
| Key-path theft requires depositor cooperation | `MuSig2(deposit_key_point, pk_u)` as Taproot key path | Yes (Bitcoin script / BIP-327) |
| Per-deposit blast radius isolation | `deposit_key = H_tweak(frost_epoch_key \|\| deposit_id)` | Yes (Bitcoin script / BIP-340 tagged hash) |
| Single-hop adaptor secret delegation — depositor absent | AdaptorDelegation + ECIES (one hop) | Partial (Zenon state; delegate-honesty bounded) |
| Multi-hop delegation without secret propagation | Capability delegation certificate chains | Partial (Zenon state; depositor liveness at withdrawal) |
| Threshold aggregate delegation | MPC aggregate key as recipient | Partial (MPC trust) |
| Automated bond burn for abandoned claims | SpendIntent lock timeout | Yes (Zenon contract) |
| Post-epoch bond lockup | Bond release lock | Yes (Zenon contract) |
| Persistent relayer identity | Accountability key | Yes (Zenon contract) |
| Stake concentration bound | Registration stake cap | Yes (Zenon contract) |
| New deposit pause on TVL/bond ratio trigger | Contract-enforced circuit-breaker | Yes (Zenon contract) |
| New deposit halt during bootstrap/quorum recovery | Bootstrap gate + quorum recovery suspension | Yes (Zenon contract) |
| Fake chain rejection | Checkpoint hashes + MIN_CHAIN_WORK | Yes (verifier initialization) |
| SPV bug → deposit pause (not mint) | Header relay quorum (impl-diverse) | Yes (quorum layer) |
| Dishonest quorum node removal | Permissionless on-chain challenge | Yes (Zenon contract) |
| Cartel DKG exclusion detection | DKG transcript publication + contract verification | Yes (Zenon contract) |
| Tier status queryability | IsTier1() | Yes (Zenon contract) |
| Tier event aggregation | Tier event log | Yes (Zenon contract emits) |

#### 12.20.2 Properties That Remain Fundamentally Impossible Without Covenants

The following are irreducible limits of the current Bitcoin scripting model:

- **Cryptographically binding exit rights to Zenon token ownership:** Bitcoin script cannot query Zenon state.
- **Preventing off-protocol signing by FROST participants:** any t-of-n FROST signer set can produce valid Schnorr signatures outside the protocol. The only deterrent is the accountability key + bond slashing mechanism.
- **Constraining the destination of funds after a Bitcoin UTXO is spent:** once the spending conditions are satisfied, the transaction can assign outputs freely.
- **Enforcing cross-chain atomic settlement in the Zenon→Bitcoin direction:** Bitcoin cannot receive or verify proofs of Zenon state changes.
- **Non-interactive trustless peg-out without any timelock:** requires either a time-constrained spending path (Leaf 2 CLTV) or a trusted co-signer.
- **Revoking FROST key shares once distributed:** cryptographic key material cannot be un-distributed. Epoch rotation limits blast radius but does not eliminate residual risk within an epoch.
- **Eliminating the epoch key as a root of per-deposit keys:** the per-deposit derivation reduces the blast radius to O(1) per deposit, but the epoch key remains the derivation root. A full epoch key compromise combined with all depositor key compromises in the epoch would still expose all UTXOs. This cannot be eliminated without per-UTXO independent key ceremonies.

#### 12.20.3 Deliberate Tradeoffs

- **Per-deposit key derivation adds relayer signing complexity:** relayers must compute `deposit_key_point` for each UTXO they serve. This is a deterministic computation with no interaction overhead.
- **Depositor liveness requirement for capability delegation withdrawals:** this is a security-liveness tradeoff. Capability delegation is the more secure mode.
- **MuSig2 KeyAgg ceremony at deposit construction:** one-time interactive ceremony per deposit. The security gain justifies the construction complexity.
- **Single-hop secret delegation:** eliminates KL #45 at the cost of multi-hop depositor-absent re-delegation. Capability delegation fills this role.

---

## 17. Conclusion: Formal Worst-Case Guarantee

### 17.1 The Formal Guarantee

**Unconditional Guarantees (Mathematical — No Behavioral Assumptions)**

- Every Tier 1 depositor retains permanent Bitcoin-native Leaf 2 exit capability after `ABSOLUTE_EXPIRY`. This requires only the depositor's private key and that `ABSOLUTE_EXPIRY` has elapsed.
- UTXO atomicity: each UTXO can be spent exactly once.
- Key-path theft per deposit: requires simultaneous compromise of `deposit_key_point` (requiring FROST threshold compromise + knowledge of `deposit_id`) AND depositor key `pk_u`. FROST epoch compromise alone is not sufficient. Each deposit is an independent target.
- Adaptor binding: a valid adaptor pre-signature `σ■` that is completed to `σ` reveals the adaptor secret `t`. Mathematical consequence of Schnorr adaptor signature properties.

**Conditional Guarantees (Hold Given Honest Majority Assumptions)**

- Tier 1 single-hop secret delegation: cooperative exit for the designated holder requires relayer providing `σ■` through proper `WithdrawalClaimMsg` flow, IsTier1 passing, and designated holder possessing `t`. No race condition with prior holders (single-hop: no prior holders exist).
- Tier 1 capability delegation: cooperative exit for certificate chain tip requires depositor availability. If depositor is permanently unavailable: Leaf 2 is the backstop for the depositor.
- SPV verification safety: if the header relay quorum maintains an honest majority using a Bitcoin implementation distinct from the SPV verifier, SPV consensus divergence is converted to an observable deposit pause rather than silent unbounded eBTC minting.
- DKG transparency: if the Zenon contract successfully verifies DKG transcripts and all registered relayers participate, silent cartel formation through parallel DKG is prevented.

**Economically Deterred — Hold Given Rational-Actor Assumptions**

- FROST threshold collusion: requires bond sacrifice, accountability key exposure, and epoch key compromise. Deterred when stealable TVL per deposit < slashable bonds (circuit-breaker enforces at epoch level).
- Relayer providing `σ■` outside protocol flow: requires accountability key forfeit and slashing. Deterred when bond value > expected gain per deposit.
- Quorum node attesting to incorrect chain: permissionless challenge results in automatic bond slashing.

### 17.2 Known Limitations

| KL # | Status | Description |
|---|---|---|
| KL #45 | ELIMINATED | Superseded-holder race condition — single-hop secret delegation has no superseded holders |
| KL #46 | Preserved | Quorum liveness dependency — bootstrap gate converts bootstrap failure to explicit halt |
| KL #47 | MITIGATED | Quorum majority capture → deposit freeze — permissionless on-chain challenge removes governance from node removal path |
| KL #48 | Preserved (irreducible without covenants) | Capability delegation depositor availability |
| KL #49 | New | MuSig2 KeyAgg ceremony adds deposit construction latency. One-time cost per deposit; does not affect withdrawal flows. |
| KL #50 | New | Single-hop secret delegation cannot support depositor-absent multi-hop re-delegation. Capability delegation fills this role but requires depositor availability at withdrawal. |
| KL #51 | New | DKG transcript publication introduces epoch key finalization latency. Contract cannot accept UTXOs for an epoch until DKG transcript is published and verified. |
| KL #52 | New | Per-deposit key derivation requires relayers to compute `deposit_key_point` per UTXO. Deterministic and non-interactive; operational overhead only. |
| KL #53 | New | Epoch key remains the derivation root for all per-deposit keys. Full epoch compromise + all depositor key compromises would still expose all epoch UTXOs. Irreducible without per-UTXO independent key ceremonies (requires covenant support or out-of-band ceremonies). |

---

## 18. References

1. Nakamoto, S. (2008). Bitcoin: A Peer-to-Peer Electronic Cash System.
2. Decker, C., Russell, R., Osuntokun, O. (2018). eltoo: A Simple Layer2 Protocol for Bitcoin.
3. Bitcoin Improvement Proposal 340 (BIP-340). Schnorr Signatures for secp256k1.
4. Bitcoin Improvement Proposal 341 (BIP-341). Taproot: SegWit version 1 spending rules.
5. Bitcoin Improvement Proposal 342 (BIP-342). Validation of Taproot Scripts.
6. Bitcoin Improvement Proposal 327 (BIP-327). MuSig2 for BIP340-compatible Multi-Signatures.
7. Komlo, C., Goldberg, I. (2020). FROST: Flexible Round-Optimized Schnorr Threshold Signatures. RFC 9591.
8. Nick, J., Ruffing, T., Seurin, Y. (2021). MuSig2: Simple Two-Round Schnorr Multi-Signatures.
9. Aumasson, J.-P., Neves, S., Wilcox-O'Hearn, Z., Winnerlein, C. (2013). BLAKE2: Simpler, Smaller, Fast as MD5.
10. Boneh, D., et al. (2018). Compact Multi-Signatures for Smaller Blockchains. ASIACRYPT 2018.

---

## 19. Implementation Compliance

### 19.1 – 19.23 Base Protocol Compliance

Standard compliance requirements for SPV verification, deposit registration, withdrawal protocol, relayer bond enforcement, epoch management, and delegation registry — as specified.

### 19.24 Header Relay Quorum Compliance

| # | Item | Requirement |
|---|---|---|
| C_HQ.1 | `RegisterDepositMsg` processing checks: (1) SPV validity, (2) quorum attestation, (3) bootstrap gate — ALL THREE before minting eBTC | REQUIRED |
| C_HQ.2 | Quorum condition: ≥ `HEADER_RELAY_QUORUM_THRESHOLD` distinct `HeaderAttestation` entries matching claimed tip hash within `HEADER_ATTESTATION_WINDOW` blocks | REQUIRED |
| C_HQ.3 | If registered independent quorum node count < `MIN_HEADER_RELAY_NODE_COUNT`: deposit acceptance SUSPENDED — NOT fallen back to SPV-only. No SPV-only fallback under any condition. | REQUIRED |
| C_HQ.4 | Header relay node registration rejected if node's attestation key matches any registered relayer's accountability key | REQUIRED |
| C_HQ.5 | `HeaderAttestation` signature validated under registered `attestation_pk` before counting toward quorum threshold | REQUIRED |
| C_HQ.6 | Header relay node registration rejected if node's `implementation_tag` resolves to same codebase as on-chain SPV verifier's declared `implementation_tag` | REQUIRED |
| C_HQ.7 | Header relay node registration requires `registration_bond` ≥ `MIN_QUORUM_NODE_BOND` | REQUIRED |
| C_HQ.8 | `QuorumNodeChallenge` with valid contradicting Bitcoin header chain → automatic bond slash + node INACTIVE, no governance vote | REQUIRED |
| C_HQ.9 | `CHALLENGE_REWARD` bounded below by contract minimum; governance cannot reduce below floor | REQUIRED |
| C_HQ.T1 | Test vector D26: Deposit with valid SPV proof, quorum attests same chain → accepted | REQUIRED |
| C_HQ.T2 | Test vector D27: Deposit with valid SPV proof, quorum attests different chain → blocked | REQUIRED |
| C_HQ.T3 | Test vector D28: Deposit with fewer than MIN nodes registered → SUSPENDED (NOT SPV-only fallback) | REQUIRED |
| C_HQ.T4 | Test vector D31: Quorum node with same `implementation_tag` as SPV verifier → registration rejected | REQUIRED |
| C_HQ.T5 | Test vector D32: `QuorumNodeChallenge` with valid contradicting chain → node slashed, INACTIVE, challenger rewarded | REQUIRED |
| C_HQ.T6 | Test vector D33: `QuorumNodeChallenge` with invalid challenge chain → challenger bond slashed | REQUIRED |

### 19.25 Capability Delegation Compliance

| # | Item | Requirement |
|---|---|---|
| C_CAP.1 | `DelegationCert` validated: `cert_sig` under `pk_u`; `cert_nonce` unused; `expiry_height` not elapsed | REQUIRED |
| C_CAP.2 | `DerivedDelegationCert` chain validated: each link signed by prior link; rooted in valid `DelegationCert` | REQUIRED |
| C_CAP.3 | IsTier1 returns true for current capability delegation certificate chain tip | REQUIRED |
| C_CAP.4 | `DepositorCompletionRequest` emitted when capability delegation chain tip submits `WithdrawalRequestMsg` | REQUIRED |
| C_CAP.5 | Depositor `AdaptorCompletionMsg` validated: `t = H_adaptor(sk_u \|\| intent_id)`; signed under `pk_u` | REQUIRED |
| C_CAP.6 | `t` removed from Zenon contract state after withdrawal completes or `DEPOSITOR_COMPLETION_TIMEOUT` expires | REQUIRED |
| C_CAP.7 | Capability delegation certificates stored in delegation registry with mode tag; IsTier1 query is mode-agnostic | REQUIRED |
| C_CAP.T1 | Test vector D29: Capability delegation 2-hop chain; withdrawal with depositor response; IsTier1 at each level | REQUIRED |
| C_CAP.T2 | Test vector D30: Capability delegation; depositor unresponsive; `PendingDepositorCompletion` state; timeout | REQUIRED |

### 19.26 Taproot Key Path Compliance

| # | Item | Requirement |
|---|---|---|
| C_KP.1 | Per-deposit key: `deposit_key_scalar = H_tweak('Zenon/DepositKey/v1', frost_epoch_key \|\| deposit_id)`; `deposit_key_point = frost_epoch_key + deposit_key_scalar · G` | REQUIRED |
| C_KP.2 | Class R UTXO Taproot key path = `taproot_tweak(MuSig2_KeyAgg([deposit_key_point, pk_u]), merkle_root)` per §5.14.2 | REQUIRED |
| C_KP.3 | `deposit_key_point` used in MuSig2_KeyAgg MUST be derived from the `frost_epoch_key` in the corresponding verified `DKGTranscript` | REQUIRED |
| C_KP.4 | Deposit registration verifies: UTXO Taproot output key matches expected per-deposit-derived MuSig2-hardened key for claimed epoch, `deposit_id`, and `pk_u` | REQUIRED |
| C_KP.5 | MuSig2 KeyAgg computation uses canonical key ordering: `[deposit_key_point, pk_u]` | REQUIRED |
| C_KP.6 | Deposits with legacy key path (FROST aggregate alone, or MuSig2 without per-deposit derivation) are rejected for fully-hardened deposit registration | REQUIRED |
| C_KP.7 | Relayer adaptor pre-signatures computed under `deposit_key_point`, not `frost_epoch_key` directly | REQUIRED |
| C_KP.T1 | Test vector D34: Valid per-deposit-derived MuSig2-hardened UTXO + correct epoch key + matching `pk_u` → deposit accepted | REQUIRED [BLOCKING] |
| C_KP.T2 | Test vector D35: UTXO with `frost_epoch_key` alone as Taproot key (legacy) → deposit rejected | REQUIRED [BLOCKING] |
| C_KP.T3 | Test vector D36: MuSig2 KeyAgg mismatch (wrong epoch key or wrong `deposit_id`) → deposit rejected | REQUIRED [BLOCKING] |
| C_KP.T4 | Test vector D43: Two deposits in same epoch: UTXO key paths are distinct (per-deposit derivation produces distinct keys) | REQUIRED [BLOCKING] |
| C_KP.T5 | Test vector D44: Adaptor pre-signature under `deposit_key_point` from one deposit rejected when applied to a different deposit's UTXO | REQUIRED [BLOCKING] |

### 19.27 DKG Transcript Compliance

| # | Item | Requirement |
|---|---|---|
| C_DKG.1 | `DKGTranscript` submission: `participant_set` MUST include all registered relayers with bond ≥ `MIN_RELAYER_BOND` for the epoch | REQUIRED |
| C_DKG.2 | `DKGTranscript` `transcript_sig` verified under `epoch_key_claim` over tagged transcript hash before epoch key is accepted | REQUIRED |
| C_DKG.3 | Epoch key derived from unverified or missing `DKGTranscript` → all UTXOs for epoch assigned Tier 2 (not Tier 1) | REQUIRED |
| C_DKG.4 | `DKGExclusionComplaint`: if relayer present in registry with sufficient bond but absent from `participant_set` → all participants slashed `EXCLUSION_PENALTY` | REQUIRED |
| C_DKG.5 | DKG transcript published within `DKG_TRANSCRIPT_DEADLINE` blocks of epoch start; otherwise epoch key rejected | REQUIRED |
| C_DKG.T1 | Test vector D37: Valid `DKGTranscript` with all registered relayers → epoch key accepted | REQUIRED [BLOCKING] |
| C_DKG.T2 | Test vector D38: `DKGTranscript` missing one registered relayer → epoch key rejected; `DKGExclusionComplaint` succeeds; participants slashed | REQUIRED [BLOCKING] |
| C_DKG.T3 | Test vector D39: `DKGTranscript` with invalid `transcript_sig` → epoch key rejected | REQUIRED [BLOCKING] |

### 19.28 Bootstrap Security Compliance

| # | Item | Requirement |
|---|---|---|
| C_BS.1 | Deposit acceptance SUSPENDED when registered independent quorum nodes < `MIN_HEADER_RELAY_NODE_COUNT` | REQUIRED |
| C_BS.2 | No SPV-only fallback under any condition. SPV-only acceptance is NOT PERMITTED. | REQUIRED |
| C_BS.3 | Deposit suspension also applies when quorum node count drops below minimum during operation (e.g., after permissionless slashing) | REQUIRED |
| C_BS.4 | Bootstrap completion gate: deposit acceptance opens when `MIN_HEADER_RELAY_NODE_COUNT` nodes with distinct `implementation_tags` and sufficient bonds are registered | REQUIRED |
| C_BS.T1 | Test vector D40: Protocol startup with 0 quorum nodes → deposits suspended | REQUIRED [BLOCKING] |
| C_BS.T2 | Test vector D41: MIN nodes reached → deposits resume (after SPV and quorum conditions met) | REQUIRED [BLOCKING] |
| C_BS.T3 | Test vector D42: Quorum node slashed → drops below MIN → deposits suspended mid-operation | REQUIRED [BLOCKING] |

---

## Appendix A. Protocol Parameter Table

| Constant | Value | Unit | Section | Notes |
|---|---|---|---|---|
| `HEADER_RELAY_QUORUM_THRESHOLD` | 3 | nodes | §4.8 | [PROPOSED] |
| `HEADER_ATTESTATION_WINDOW` | 576 | Zenon blocks | §4.8 | ~2 hours [PROPOSED] |
| `MIN_HEADER_RELAY_NODE_COUNT` | 5 | nodes | §4.8.3 | Below this: deposit HALT (not SPV fallback) [PROPOSED] |
| `MIN_QUORUM_NODE_BOND` | 100 | ZNN | §4.8.6 | [PROPOSED; OPEN — BLOCKING] |
| `CHALLENGE_REWARD` | 20% of challenged bond | — | §4.8.5 | [PROPOSED] |
| `CHALLENGE_SUBMISSION_BOND` | 10 | ZNN | §4.8.5 | Anti-griefing [PROPOSED] |
| `CHALLENGE_REWARD_FLOOR` | TBD | ZNN | §12.12 | Governance cannot reduce below floor [OPEN — BLOCKING] |
| `DKG_TRANSCRIPT_DEADLINE` | 288 | Zenon blocks | §9.19 | ~1 hour after epoch start [PROPOSED] |
| `EXCLUSION_PENALTY` | 10% of each participant bond | — | §9.19.4 | [PROPOSED] |
| `EXCLUSION_SELF_PENALTY` | 50% of excluded relayer bond | — | §9.19.4 | [PROPOSED] |
| `DEPOSITOR_COMPLETION_TIMEOUT` | 2016 | Zenon blocks | §7.11 | ~5 days [PROPOSED] |
| `MAX_DELEGATION_DEPTH` | 1 | hops | §7.8 | Single-hop secret delegation enforced |
| `MAX_CAPABILITY_CHAIN_DEPTH` | 8 | hops | §7.11 | Capability delegation chains |
| `DEPOSIT_KEY_TAG` | `'Zenon/DepositKey/v1'` | — | §5.14.2 | BIP-340 tagged hash prefix for per-deposit key derivation |

**Blocking items for deployment:**

- Normative test vectors D34–D44 (§19.26–§19.28).
- `MIN_QUORUM_NODE_BOND` calibration (§4.8.6).
- `CHALLENGE_REWARD_FLOOR` value (§12.12 governance capture resistance).
- DKG transcript format standardization and reference implementation.
- MuSig2 KeyAgg ceremony tooling for depositors (§5.14.4).
- `DKG_TRANSCRIPT_DEADLINE` calibration for practical epoch setup time.
- Per-deposit key derivation reference implementation and test vectors (§3.9, §5.14).
- Relayer signing library update for `deposit_key_point` computation per UTXO.

---

## Appendix B. State Machines

- **AdaptorDelegation (single-hop):** `Issued → Active → (Revoked | Expired | Spent)`. No `Superseded` state.
- **DKGTranscript:** `Submitted → (Verified | Rejected)`. Verified: epoch key accepted; UTXOs can register for epoch. Rejected: epoch operates as Tier 2 only.
- **HeaderRelayNode:** `Registered → Active → (Slashed_and_Inactive | Voluntarily_Deregistered)`. Slashed via permissionless `QuorumNodeChallenge`.
- **BootstrapGate:** `Suspended → (Active when MIN nodes registered)`. `Active → Suspended` when node count drops below MIN.
- **QuorumNodeChallenge:** `Submitted → (Upheld: node slashed | Rejected: challenger slashed)`.
- **DKGExclusionComplaint:** `Submitted → (Upheld: participants slashed | Rejected: no action)`.
- **SpendIntent:** `Created → Locked → (Completed | Abandoned_and_Slashed)`.
- **DepositKey (per-deposit):** No state machine — deterministic derivation from `frost_epoch_key` and `deposit_id`; no lifecycle beyond the UTXO lifecycle.
- **DelegationCert, DerivedDelegationCert, HeaderAttestation, DepositorCompletionRequest:** as specified in the base protocol.

---

## Appendix D. Normative Test Vectors

| Vector | Description | Status |
|---|---|---|
| D1–D25 | Base protocol vectors | Per base spec |
| D26 | Deposit: valid SPV + quorum attests same chain → accepted | [BLOCKING] |
| D27 | Deposit: valid SPV + quorum attests different chain → blocked | [BLOCKING] |
| D28 | Deposit: registered quorum nodes < MIN → SUSPENDED (not SPV-only) | [BLOCKING] |
| D29 | Capability delegation: 2-hop chain; depositor responds; withdrawal completes | [BLOCKING] |
| D30 | Capability delegation: depositor unresponsive; timeout; `PendingDepositorCompletion` | [BLOCKING] |
| D31 | Quorum node registration: `implementation_tag` matches SPV verifier → rejected | [BLOCKING] |
| D32 | `QuorumNodeChallenge`: valid contradicting chain → node slashed, INACTIVE, challenger rewarded | [BLOCKING] |
| D33 | `QuorumNodeChallenge`: invalid challenge chain → challenge rejected, challenger bond slashed | [BLOCKING] |
| D34 | Per-deposit-derived MuSig2-hardened UTXO: correct epoch key + matching `deposit_id` + matching `pk_u` → deposit accepted | [BLOCKING] |
| D35 | Legacy UTXO (`frost_epoch_key` alone or MuSig2 without per-deposit derivation): deposit rejected | [BLOCKING] |
| D36 | Per-deposit key derivation mismatch (wrong epoch key or wrong `deposit_id`) → deposit rejected | [BLOCKING] |
| D37 | `DKGTranscript` with all registered relayers, valid sig → epoch key accepted | [BLOCKING] |
| D38 | `DKGTranscript` missing registered relayer → epoch key rejected; `DKGExclusionComplaint` succeeds | [BLOCKING] |
| D39 | `DKGTranscript` with invalid `transcript_sig` → epoch key rejected | [BLOCKING] |
| D40 | Bootstrap: 0 quorum nodes → deposits suspended | [BLOCKING] |
| D41 | Bootstrap: MIN nodes registered → deposits resume | [BLOCKING] |
| D42 | Quorum node slashed mid-operation → drops below MIN → deposits suspended | [BLOCKING] |
| D43 | Two deposits in same epoch: Taproot output keys are distinct (per-deposit derivation produces distinct keys) | [BLOCKING] |
| D44 | Adaptor pre-signature under `deposit_key_point` of deposit A rejected when applied to deposit B's UTXO | [BLOCKING] |

---

## Appendix L. Delegation Mode Selection Guide (Informational)

### L.1 Overview

Multi-hop secret delegation is not available. The choice is between:

- **Single-hop secret delegation (§7.8):** depositor designates exactly one holder of `t`. Depositor-absent cooperative exit. No race condition.
- **Capability delegation chains (§7.11):** multi-hop authorization chains. Depositor required only at withdrawal time. No secret propagation at all.

### L.2 Decision Criteria

| Criterion | Single-hop secret deleg (§7.8) | Capability delegation (§7.11) |
|---|---|---|
| Depositor reachable at withdrawal? | Not required | Required |
| Need to re-delegate to a third party? | No (single-hop; use capability for this) | Yes |
| Priority: depositor-absent exit | Yes | No |
| Priority: eliminating secret from counterparty | No (counterparty holds `t`) | Yes (depositor holds `t` until withdrawal) |
| Institutional custody | Moderate | Preferred |
| Long-term cold storage | Acceptable (one designated holder) | Recommended |
| DeFi pool integration | Neither (without ECIES per deposit) | Neither (requires depositor) |

### L.3 Hybrid Approach

A depositor may issue both: a single-hop `AdaptorDelegation` to one institutional holder (for immediate depositor-absent exit), and a `DelegationCert`-rooted capability chain for a secondary authorized party. The Zenon contract enforces that only one withdrawal can complete per UTXO.

### L.4 Default Recommendation

For institutions where depositor liveness is available at withdrawal: capability delegation. No secret is distributed; the superseded-holder concern is fully eliminated; multi-hop transfer is available.

For depositors who cannot guarantee availability: single-hop secret delegation. One trusted counterparty holds `t`. This is the depositor's primary fallback before the Leaf 2 path.

---

## Appendix P. Class P Architecture

**MUST NOT IMPLEMENT.** Class P is NOT part of the deployed protocol. This appendix is preserved for architectural completeness and future protocol versioning research only. Any implementation that enables Class P functionality is non-compliant.

Class P will not be considered for enablement until:

- All normative test vectors (D1–D44) pass with verified implementations.
- A separate Class P adversarial review cycle is completed for the Class P specific mechanism-design risks.
- A separate protocol version specifically designed for Class P enablement is published and approved.

---

*The remaining known limitations (§12.20.2, KL #46–#53) are irreducible consequences of the Bitcoin scripting model. No further structural improvement is available without Bitcoin consensus changes.*
