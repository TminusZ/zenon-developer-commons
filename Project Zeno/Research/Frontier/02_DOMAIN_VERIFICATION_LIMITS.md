**Status:** Frontier boundary document
**Phase status:** Mixed; Phase 1 is bonded attestation, Phase 2 fraud proofs are deferred, Phase 3 validity proofs are deferred
**Purpose:** Define what can be verified by Settlement, by a domain STF, by watchers, and by future proof systems
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Domain Verification Limits

## 1. Why this document exists

Many Frontier claims depend on the word "verify." But "verify" means different things depending on which layer is doing the checking. Settlement verifying input ordering is not the same as a domain STF verifying a Bitcoin Merkle proof during execution, which is not the same as a watcher detecting divergence, which is not the same as Phase 2 fraud-proof enforcement, which is not the same as Phase 3 validity-proof verification. Collapsing these into a single claim produces overclaims that damage credibility and mislead integrators.

This document defines the scope of verification at each layer and each phase so that subsequent Frontier work cannot blur the boundaries. Specifically, it exists to:

Prevent Phase 1 from being described as on-chain execution verification. Phase 1 is bonded attestation with on-chain custody and conservation constraints (SPEC §1). The Settlement contract does not execute WASM, does not replay the domain STF, and does not verify per-account L2 balances.

Separate STF verification from Settlement verification. A domain STF can deterministically verify input data during execution, including proof-shaped inputs such as Bitcoin headers or Merkle proofs. But in Phase 1, Settlement does not independently replay that STF. The executor attests to the result.

Separate watcher replay from fraud-proof enforcement. A watcher can recompute the executor's roots and detect divergence, but in Phase 1 it has no on-chain enforcement channel. Watcher replay is detection, not enforcement.

Explain why Phase 2 and Phase 3 matter. Phase 2 adds fraud-proof enforcement under explicit assumptions. Phase 3 reserves validity-proof verification. Neither is present in Phase 1. Both change the verification model in ways that must not be projected backward.

Prevent browser verification from being overstated. A browser can verify the settlement floor (on-chain roots, conservation invariant, finalized batch status). Full execution replay requires the DA bundle, the domain runtime, witnesses, the correct `stfSpecHash`, a deterministic execution environment, and sufficient compute resources. The floor and the full replay are different things.

The inventory rows that feed this document are: #14 (Phase 2 fraud proofs), #15 (Phase 3 validity proofs), #16 (RANDOM_BACKUP executor set), #17 (STAKE_WEIGHTED executor set), #21 (browser-native verification floor), #25 (Sentinel as watcher), #34 (declarative returned-blob ABI), and #45 (single-instance lease and equivocation boundary).

## 2. The verification stack

| Layer | What it verifies | What it does not verify in Phase 1 |
|---|---|---|
| Zenon L1 ordering | Account-block inclusion, momentum order, confirmed frontier | Domain execution correctness |
| Settlement Core | Batch contiguity, conservation counters, withdrawal delays, caps, outbox replay protection, pause scope, runtime upgrade delay bounds | Per-account balance correctness; WASM execution; STF application honesty |
| Domain STF | Domain-specific validity rules during execution (input format, contract effects, storage access, proof-shaped input verification for future external domains) | That the executor applied the STF honestly (this is attested, not independently verified, in Phase 1) |
| Watcher | Recomputes `postStateRoot` and detects divergence by replaying the full execution pipeline | Cannot slash, revert, or trigger on-chain action in Phase 1 |
| Browser / client | Settlement floor: on-chain roots, conservation invariant, finalized batch status, outbox inclusion proofs | Full execution correctness, unless the client also has the DA bundle, domain runtime, witnesses, and sufficient compute |
| Phase 2 fraud-proof referee | Challenged execution step correctness via on-chain replay | Not present in Phase 1 |
| Phase 3 validity verifier | Validity proof for batch correctness | Not present in Phase 1 |

The central distinction: Settlement verification and domain STF verification are not the same thing. Settlement verifies the floor (ordering, conservation, custody constraints, relay proofs). The domain STF verifies domain-specific rules during execution. In Phase 1, Settlement trusts the executor's attestation that the STF was applied correctly. In Phase 2, that attestation becomes challengeable. In Phase 3, the attestation may be replaced by a validity proof.

## 3. Phase 1: bonded attestation, not on-chain execution verification

SPEC §1 states that Phase 1 is bonded attestation and is not on-chain execution verification. This is normative context for the entire specification and must be communicated to users and integrators without qualification.

Phase 1 operates as follows. The executor computes off-chain: it consumes the canonical input stream, applies the domain STF, and produces execution results. It submits batch commitments to Settlement containing roots, indices, `DAHash`, `AssetFlowSummary`, and other commitment metadata. Settlement enforces input ordering and per-domain contiguity, so the executor cannot skip or reorder inputs. Settlement enforces aggregate conservation per (domain, asset), so aggregate withdrawals plus pending reserves cannot exceed total deposits. Settlement enforces withdrawal delays and `MaxBatchWithdrawal` caps, bounding the value at risk per batch. Settlement verifies finalized outbox inclusion proofs when `RelayMessage` is called, and maintains the `processedOutbox` set for replay protection.

Settlement does not execute WASM. Settlement does not replay the domain STF. Settlement does not verify that `postStateRoot` is the correct result of applying the STF to the inputs. Settlement does not verify per-account L2 balances. Per-account correctness relies on the bonded executor's honesty until Phase 2 fraud proofs.

Phase 1 verifies the settlement floor, not the full execution trace.

The on-chain guarantee is specific and bounded: no domain can pay out more in aggregate than was deposited, regardless of executor behavior. Within that aggregate bound, an dishonest executor can misattribute balances among accounts during the withdrawal delay window, bounded by the executor bond and the per-batch withdrawal cap. That residual trust is what Phase 2 reduces by adding fraud-proof enforcement under DA availability and honest-challenger assumptions.

## 4. What Settlement verifies in Phase 1

Settlement verifies the following in Phase 1, all on-chain and independent of executor honesty:

The domain exists in the registry and is permitted under the current profile. Input ordering follows the canonical L1 order (SPEC §4.4). Batch contiguity holds: each batch begins at the successor of the domain's previous batch cursor, with no gap, overlap, or replay (SPEC §4.6). `preStateRoot` of the incoming batch equals the `postStateRoot` of the previous accepted batch. Batch status transitions from `SUBMITTED` to `FINALIZED` after the withdrawal delay elapses. The conservation invariant holds: `totalReleased + pendingWithdrawalReserve <= totalDeposited` per (domain, asset), enforced on every mutating path (SPEC §18.3). `MaxBatchWithdrawal` caps per-batch withdrawal value. Batch-declared asset-flow summaries are checked against Settlement accounting rules and recorded deposit and release state. The `processedOutbox` set prevents replay of relayed messages. Outbox inclusion proofs against the committed `outboxRoot` of a `FINALIZED` batch are verified for `RelayMessage`, including `domainId` and `batchId` binding (SPEC §17.3). Pause scope constraints (`PAUSE_SUBMIT` / `PAUSE_RELAY`) are enforced per SPEC §23 and §27.10. Runtime upgrade delay is at least `WithdrawalDelay` (SPEC §6). The domain escape hatch is subject to `AdministratorDelay` and guardian co-signature (SPEC §23).

Settlement does not verify the following in Phase 1:

WASM execution correctness (SPEC §1, §2.1). Contract-level business logic or returned effects. Per-account L2 balances (these are contract state, not Settlement state, per SPEC §18.1a). External truth of observed data from `EXTERNAL_OBSERVED` domains. Bitcoin proof validity, unless a future domain with an appropriate STF and relay path is activated. Ethereum proof validity, unless a future domain with an appropriate STF and proof scheme is activated. DA availability beyond recording `DAHash` in the batch commitment (SPEC §20).

The `RelayMessage` point deserves care. When Settlement verifies an outbox inclusion proof for `RelayMessage`, it is verifying that a message exists in the committed `outboxRoot` of a finalized batch. It is not re-executing the domain to confirm that the message should have been emitted. The correctness of the `outboxRoot` itself depends on the executor's honest application of the STF, which is what Phase 2 makes challengeable.

## 5. What the domain STF verifies

The domain STF verifies whatever the domain's rules define, during execution, inside the executor. For the Phase 1 WASM domain, this includes: input format validity, contract returned-effects blob structure, storage read/write consistency against witnesses, outbox message formation, deposit claim bounds, and the full WASM execution semantics defined by the runtime profile (SPEC §7, §8, §14).

For a future Bitcoin SPV domain under `L1_RELAYED`, the STF would verify header chain linkage, proof-of-work, confirmation depth predicates, and Merkle inclusion for transaction proofs. For a future Ethereum-related domain, verification would depend on whether a machine-verifiable proof scheme exists: an Ethereum light-client proof path would be STF-verifiable, while an observation path without proofs would fall under `EXTERNAL_OBSERVED` and verify only replay consistency.

The critical boundary is this: in Phase 1, the domain STF can be deterministic, well-specified, and capable of rejecting invalid inputs. But Settlement does not independently replay the STF. The executor runs the STF and attests to the result. Settlement records the attestation. The distinction between "the STF can verify this" and "Settlement has verified this" is the gap that Phase 2 fills.

STF-verifiable does not mean Settlement-verified in Phase 1.

## 6. Watcher replay

A watcher runs the same execution pipeline as the executor. It consumes the canonical input stream for a domain, applies the STF to each input, computes `preStateRoot` and `postStateRoot`, and compares its results against the committed batch roots. If its computed root diverges from the executor's committed root, it has detected dishonest or faulty execution. This requires access to the relevant DA bundle, witnesses, runtime, and exact `stfSpecHash`.

In Phase 1, the watcher's only option is to raise an alarm. There is no on-chain channel through which the watcher can challenge a batch, trigger a replay, or slash the executor's bond. SPEC §3 says browser clients and watchers "SHOULD" download execution data bundles and reproduce results independently, and adds that in Phase 1 this is advisory. EXECUTOR_DRAFT.md §5.8 specifies that a Phase 1 watcher must not build the fraud-proof emitter.

The alarm-only limitation is not a design flaw: it is the Phase 1 boundary. The watcher is a detection mechanism. Phase 2 adds the enforcement mechanism (the fraud-proof channel). Detection without enforcement still has value: a detected divergence is a public signal that the executor is misbehaving, which informs users and governance even without automated slashing. But it must not be described as enforcement.

A Sentinel node may run a watcher binary. This is a plausible architectural fit, not a protocol assignment. The spec does not assign Sentinels an official watcher role and does not define a paid watcher service market.

## 7. Browser and client verification

The settlement floor is browser-verifiable. A browser or light client with access to Zenon L1 state can independently verify:

On-chain Settlement storage: the domain registry, conservation counters (`totalDeposited`, `pendingWithdrawalReserve`, `totalReleased`), batch commitment chain, batch status (`SUBMITTED` / `FINALIZED`), and the `processedOutbox` set. Committed roots (`preStateRoot`, `postStateRoot`, `outboxRoot`, `receiptRoot`, `eventRoot`, `inputRoot`) are readable from Settlement state. Outbox inclusion proofs can be verified against the committed `outboxRoot` of a finalized batch. The conservation invariant can be checked directly from on-chain counters.

Full execution replay is a different and more demanding operation. It requires the DA bundle for the batch (containing per-input canonical input data, SMT witnesses, and execution results). It requires the domain runtime (the WASM module, instrumentation pipeline, and host ABI implementation). It requires the correct `stfSpecHash` to know which STF version to run. It requires a deterministic execution environment capable of reproducing byte-identical results. And it requires sufficient compute resources.

The WASM runtime is designed to be browser-suitable (SPEC §20 mentions a browser gateway), and the settlement floor is available from on-chain state without any DA bundle. But the gap between "can verify the floor" and "can fully replay execution" is substantial. Not every browser will have the DA bundle. Not every client will run the full WASM execution environment. The settlement floor is available to all; full replay is conditional.

The settlement floor is browser-verifiable; full execution replay is conditional on DA bundle availability, the domain runtime, witnesses, and sufficient client resources.

## 8. Proof-shaped input verification vs execution verification

This distinction is easy to miss and important to enforce.

A domain STF may verify proof-shaped input data during execution. A Bitcoin SPV domain, for example, would verify Bitcoin block headers (checking proof-of-work and chain linkage) and Merkle inclusion proofs (checking that a transaction appears in a block). A cross-domain relay message is verified by Settlement checking its inclusion proof against the committed `outboxRoot` of a finalized batch. These are input-level verifications: the data entering the domain is checked against a proof before the domain processes it.

But input proof verification is not execution correctness verification. Even if a domain STF can reject invalid Bitcoin proofs during execution, Phase 1 Settlement does not independently execute that STF. The batch commitment containing the execution results still rests on the bonded executor's attestation. A dishonest executor could claim to have rejected an invalid proof and produce a fraudulent `postStateRoot`, and in Phase 1 there is no on-chain mechanism to challenge that claim. Phase 2 fraud proofs provide that mechanism.

Input proof verification is inside the STF. Execution correctness verification is a separate layer. Collapsing them leads to claims like "the domain verifies Bitcoin proofs therefore Phase 1 is verified," which skips the executor attestation step entirely.

## 9. Phase 2 fraud proofs

Phase 2 adds an on-chain replay and referee path for challenged execution. It is deferred and is not present in Phase 1.

When Phase 2 is activated, a challenger (typically a watcher) can submit a fraud proof targeting a specific input within a batch. The on-chain referee replays that single execution step using the committed `preStateRoot`, the canonical input data, and the DA bundle witnesses, and compares the result against the committed `postStateRoot`. If the results diverge, the Phase 2 dispute path provides the enforcement mechanism defined by the fraud-proof design.

This changes the trust model. Phase 1 relies on bonded attestation: the executor attests honestly because its bond is at stake, and the withdrawal delay gives watchers time to detect problems before funds are released. Phase 2 adds a mechanism by which detection can become enforcement. But it does not remove all trust assumptions. It assumes DA availability: the DA bundle must be accessible so the referee can replay the challenged step. It assumes at least one honest challenger submits the fraud proof within the challenge window. It introduces dispute and slashing logic that did not exist in Phase 1.

Phase 2 reduces executor trust by adding fraud-proof enforcement, assuming DA availability and at least one honest challenger within the challenge window.

The `RANDOM_BACKUP` proposer policy (SPEC §6.2) is the Phase 2 executor-set path. It introduces a permissioned set of bonded executors with an objectively-derived proposer schedule, where non-proposing members operate as watchers and can submit fraud proofs on divergence. The schema for this (`executors`, `minExecutors`, `proposerPolicy`) is already present in the `DomainRecord`; Phase 2 populates it rather than adding it.

The Phase 1 watcher must not build the fraud-proof emitter (EXECUTOR_DRAFT.md §5.8). A Phase 1 implementation that includes fraud-proof emission logic is non-conformant, because the on-chain referee and slashing infrastructure do not exist.

## 10. Phase 3 validity proofs

Phase 3 reserves a validity-proof verification path. The verification system itself is not present in Phase 1, even though the batch commitment reserves the `proofData` field for that future path.

The batch commitment structure includes a `proofData` field (SPEC §19). In Phase 1, this field must be the zero-length encoding, and Core must reject any commitment with non-empty `proofData`. In Phase 3, this field would carry a validity proof (such as a ZK proof) demonstrating that the batch's `postStateRoot` is the correct result of applying the STF to the batch's inputs. If the proof verifies, finality can be immediate rather than waiting for a challenge window.

Phase 3 introduces additional changes. The `STAKE_WEIGHTED` proposer policy (SPEC §6.2) is reserved for Phase 3 and must not be activated before its enabling phase. Without validity proofs, permissionless executor sets cannot be made safe. A one-time migration to a ZK-friendly SMT hash function is deferred and isolated behind a single interface (SPEC §13.2), so the migration touches one component when it occurs. No ZK-friendly hash, field, or width parameter is locked in Phase 1.

Phase 3 is a reserved proof path, not a present capability.

## 11. Declarative returned-blob ABI and verification tractability

The returned-blob ABI (SPEC §8.2) is relevant to this document because it affects the tractability of future verification systems.

In Project Zeno's WASM domain, contracts do not call host functions for state writes, event emission, outbox messages, or balance transfers. Instead, each contract returns a canonical `ContractEffects` blob from its entry point. The runtime reads that blob, validates its structure, charges post-execution effect gas, and then applies the declared effects. The runtime computes `postStateRoot` from the declared state changes; the contract never sees or produces roots.

This design separates computation from state application. Execution becomes a pure function from witnessed reads and input data to an effects blob. The runtime's application of that blob to the SMT is a separate, deterministic step. SPEC §8.2 describes this as the single most important ABI decision for keeping Phase 2 and Phase 3 tractable: a Phase 2 fraud-proof referee needs to prove that a given module and inputs produce a given blob, and a Phase 3 validity proof circuit needs to prove the same thing, with SMT application handled as a separate stage.

The ABI is proof-friendly; it is not itself a proof system. The returned-blob model does not make Phase 1 execution Settlement-verified. It makes Phase 2 fraud proofs and Phase 3 validity proofs architecturally feasible without requiring a redesign of the execution model.

## 12. Single-instance lease and equivocation boundary

EXECUTOR_DRAFT.md §13 requires the executor binary to acquire a single-active-instance lease (a file lock or external lease) at boot. A second instance of the same executor identity that cannot acquire the lease must exit without entering the execution loop. This prevents one executor identity from running two copies that could submit conflicting batches.

This is an operator-level safety requirement, not a protocol-level Phase 1 enforcement mechanism. Settlement does not know whether the executor acquired a lease. What Settlement does know is whether a submission satisfies contiguity and proposer-entitlement rules: a duplicate or non-contiguous submission is rejected by the batch acceptance logic (SPEC §19). So the on-chain surface detects certain equivocation symptoms (double submission at the same cursor position), but the lease is the operator-side prevention that keeps those symptoms from occurring in the first place.

The single-instance lease is orthogonal to the `RANDOM_BACKUP` and `STAKE_WEIGHTED` proposer policies. Those policies govern which member of a multi-executor set is entitled to propose at a given cursor position. The lease guards a single identity against running twice. One is a set-level scheduling concern (Phase 2 and Phase 3); the other is an identity-level process-safety concern (applicable at every phase).

Single-instance lease is an operator safety requirement, not a Phase 1 decentralization mechanism. Phase 2 adds slashable equivocation enforcement through the fraud-proof dispute path.

## 13. Verification matrix

| Claim | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| Settlement enforces input order | Yes | Yes | Yes |
| Settlement enforces aggregate conservation | Yes | Yes | Yes |
| Settlement verifies WASM execution correctness | No | Challenge-based | Validity-proof path |
| Watcher can detect divergence | Alarm-only | Can feed fraud proof | May still monitor |
| Fraud-proof enforcement | No | Yes (under DA and challenger assumptions) | Possibly replaced or reduced by validity proofs |
| Validity-proof verification | No | No | Reserved path |
| Browser can verify settlement floor | Yes | Yes | Yes |
| Browser can fully replay execution | Conditional on DA bundle, runtime, witnesses, and compute | Conditional | Conditional, possibly proof-assisted |
| `L1_RELAYED` proof data can be STF-verified | Reserved path (not Phase 1) | If activated and STF defined | If activated and proof path defined |
| `EXTERNAL_OBSERVED` truth can be verified | No; only replay consistency | No, unless machine-verifiable proof exists | No, unless machine-verifiable proof exists |

## 14. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Phase 1 execution is on-chain verified | Phase 1 is bonded attestation with on-chain custody and conservation constraints; Settlement does not replay the STF |
| Settlement verifies WASM execution | Settlement verifies the settlement floor (ordering, conservation, custody constraints), not the execution trace |
| Watchers enforce correctness in Phase 1 | Watchers detect divergence in Phase 1; enforcement is deferred to Phase 2 |
| Browser verification means full execution verification | The browser verifies the settlement floor; full replay depends on DA bundle, witnesses, runtime, and compute |
| STF-verifiable means Settlement-verified | STF verification occurs during execution inside the executor; Settlement does not replay the STF in Phase 1 |
| Fraud proofs remove trust | Fraud proofs reduce executor trust under DA availability and honest-challenger assumptions |
| ZK proofs are present | `proofData` is reserved and must be empty in Phase 1; Core rejects non-empty `proofData` |
| Bitcoin SPV proof verification means BTC custody is solved | SPV verifies events inside the STF; custody of native BTC remains a separate problem |
| `EXTERNAL_OBSERVED` verifies external truth | It verifies replay consistency, not external truth, unless the observation includes a machine-verifiable proof |
| Sentinel watchers are protocol-assigned | Sentinel watcher is a plausible architectural fit, not a spec assignment |
| The executor set prevents equivocation in Phase 1 | The single-instance lease prevents local duplicate submission; Phase 2 handles slashable equivocation |

## 15. Open questions for Domain Settlement implementers

1. What is the exact Phase 1 watcher interface and expected alarm format? Is the alarm a log entry, a public broadcast, or a structured message?

2. What path-native SMT APIs (`RootOfLeaves`, `ProveByPath`, `VerifyProofByPath`, `VerifyAbsenceByPath`) are required before browser or client proof verification against committed roots is usable? These are prerequisite P-8 in EXECUTOR_DRAFT.md §18, not yet exported in the `merkle-state-root` branch.

3. What is the canonical Settlement storage key layout for `getProof` over the domain cursor, batch status, and `postStateRoot`? This is prerequisite P-6 in EXECUTOR_DRAFT.md §18. Without it, watchers and clients cannot anchor verification against L1 state proofs.

4. What DA bundle retention floor is required for meaningful watcher and browser replay? The executor must retain pre-finalization bundles (EXECUTOR_DRAFT.md §14), but the minimum retention period relative to the challenge window is unspecified.

5. What is the Phase 2 fraud-proof challenge window duration, and what is the bond and slashing flow? The withdrawal delay is a pre-mainnet parameter (SPEC §25.2), and its relationship to any Phase 2 challenge window should be explicitly specified.

6. What is the exact scope of `RANDOM_BACKUP` in Phase 2? The `RANDOM_BACKUP` path is named in SPEC §6.2, but the operational details of proposer selection, fallback behavior, and non-proposing watcher operation need implementation specification.

7. What `proofData` envelope format is intended for Phase 3? The field is reserved as a `Bytes` type with zero-length encoding in Phase 1, but the proof system, circuit structure, and verification interface are entirely open.

8. What constraints on the SMT hash function, key derivation, and tree structure must remain stable now to avoid blocking a future ZK-friendly migration? SPEC §13.2 isolates the hash behind a single interface, but the migration path depends on which parts of the current structure are circuit-compatible.

## 16. Summary

Project Zeno verification is layered. Each layer verifies something different, and the layers must not be collapsed.

Settlement verifies the floor: input ordering, custody constraints, aggregate conservation, replay protection, withdrawal timing, and finalized outbox inclusion proofs. This floor is on-chain, independent of executor honesty, and browser-verifiable.

The domain STF verifies domain-specific rules during execution, inside the executor. For the WASM domain this means input validity, contract effects structure, and storage consistency. For future external domains it could include proof-shaped input verification such as Bitcoin SPV checks. But STF-verifiable does not mean Settlement-verified. In Phase 1, Settlement trusts the executor's attestation that the STF was applied correctly.

The executor attests to the resulting state. Its bond, the withdrawal delay, and the per-batch withdrawal cap are the Phase 1 safety mechanisms. Per-account correctness depends on executor honesty.

The watcher can replay the full execution pipeline and detect divergence. In Phase 1, it raises an alarm. It does not slash, revert, or enforce. Detection and enforcement are separate capabilities.

Phase 2 adds fraud-proof enforcement, closing the gap between detection and correction. It operates under explicit assumptions: DA availability and at least one honest challenger within the challenge window. It reduces executor trust; it does not eliminate all trust.

Phase 3 reserves validity-proof verification, which could replace or reduce fraud proofs and allow immediate finality. It is not present in Phase 1, and no proof system, hash function, or circuit design is locked.

The accurate claim for Phase 1 is narrower than "Project Zeno verifies execution," and it is stronger for being precise: Phase 1 anchors deterministic execution under bonded attestation and verifies the settlement floor. Later phases add progressively stronger execution verification paths.
