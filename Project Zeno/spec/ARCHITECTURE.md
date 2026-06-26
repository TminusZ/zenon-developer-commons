# Phase 1 — Architecture and Design Companion

**Status:** Design companion to `SPEC.md`. *Informative.*
**Relationship:** `SPEC.md` is the normative contract (the "what" and "MUST"). This document carries the design rationale, component architecture, end-to-end flows, and the go-zenon integration map (the "why" and "how it fits"). Where the two differ, `SPEC.md` governs.

---

## 1. The two-layer model

Programmability has historically failed on this architecture by landing on the wrong layer: execution on account chains destroys atomicity; execution on the commitment chain forces every node to re-run everything. Phase 1's prescription is off-chain execution with results returned to a settlement layer through commitments.

- **L1 — the Zenon network:** account chains (feeless async payments) + the momentum chain (state anchoring, commitment registration). A *verification surface*, not an execution environment.
- **L2 — off-chain execution:** a bonded executor runs WASM contracts off consensus and registers commitments on L1 via the Settlement embedded contract.

The invariant — **Consensus orders. Executors compute. Settlement anchors.** — assigns each concern to exactly one layer: L1 owns ordering and finality of *inputs*; the executor owns *computation*; Settlement owns *escrow and commitment recording*. No layer does another's job, which is what makes the proof ladder (attestation → fraud proofs → validity proofs) additive rather than a rewrite.

---

## 2. Component architecture

### 2.1 Settlement embedded contract (on-chain, in `znnd`)

Two responsibilities, deliberately separated so a runtime can be added without touching value logic:

- **Domain-agnostic core** — one implementation serving every domain: the domain registry, per-(domain, asset) escrow/custody and the conservation invariant, executor registration + bond, batch-commitment chaining/contiguity keyed by `domainId`, the withdrawal delay/finality state machine, outbox replay protection, and pause. This is the only code that moves value.
- **WASM domain handler** — the WASM STF's on-chain footprint: the input vocabulary (`CallL2`, deploy trio, `UpgradeContract`) and the chunked-deployment state machine. A second runtime would ship its own handler beside this one.

The split mirrors SPEC §5.2's Core/Periphery distinction: Core is node-binary (changeable only by a release + spork); Periphery is administrator-tunable storage controlled by a single Settlement admin (bridge-style, time-locked, with guardian recovery — SPEC §23), clamped by Core to hard bounds. That admin is intended to migrate to a governance contract or multisig once one exists.

### 2.2 The off-chain executor (largest component)

A standalone binary, off consensus. It hosts the generic runtime plus per-domain plugins and runs in one of three roles — **relay**, **executor**, **watcher** (SPEC §6.2; full design in `EXECUTOR.md`). In **executor** role it is structured as a pipeline:

1. **Ledger follower** — subscribes to the confirmed momentum stream, filters to its `domainId`, and assigns the input-sequence number (`globalInputIndex` for L1-sourced domains) in canonical order (SPEC §4.4–§4.5). Consumes the confirmed frontier and below so reorgs cannot reorder inputs.
2. **STF / runtime** — the deterministic WASM Core 1.0 interpreter with the three-import host ABI, gas metering, and the returned-`ContractEffects` model (SPEC §7, §8, §10). Pure function from witnessed reads + input → effects blob.
3. **State (SMT)** — the executor's own leaf set over the shared path-based core (SPEC §13; `MERKLE_STATE_L2_ALIGNMENT.md`). Produces `preStateRoot`/`postStateRoot` per input and witnesses every read.
4. **Batch builder** — slices the canonical stream into contiguous batches (`≤ MaxBatchInputs`), assembles the commitment roots (`inputRoot`, `receiptRoot`, `eventRoot`, `outboxRoot`, `AssetFlowSummary`), and submits via `SubmitBatch`.
5. **DA publisher** — publishes the execution data bundle (input data, witnesses, per-input `ExecutionResult`) content-addressed by `DAHash` over Sentinel/libp2p, best-effort (SPEC §20).

The **watcher** role runs stages 1–3 identically and compares its recomputed roots against the committed batch instead of submitting (Phase 2: emitting a fraud proof); the **relay** role, used only by external-input domains (§6 below, SPEC §6.1), posts source data to L1 as account-blocks and runs no STF. See `EXECUTOR.md`.

### 2.3 DA serving (off-chain, best-effort)

Sentinel/libp2p nodes serve bundles and chunks by `DAHash`; a browser gateway lets clients and (future) watchers reproduce execution. Not consensus-critical in Phase 1; the limitation is disclosed (SPEC §20.4-equivalent).

---

## 3. go-zenon integration map

Everything Phase 1 needs already exists as a shipped pattern; the integration touches a bounded surface.

**Adding the contract.** A new embedded contract is registered by the established spork-layering pattern, not redeployment. `GetEmbeddedMethod` (`vm/embedded/embedded.go`) builds the active method map from `getOrigin()` plus `applyXDiffs` layers, each gated by an `IsXSporkEnforced()` check. The Settlement contract adds:

- an address (`z1qxemdeddedx…`) via `parseEmbedded`, listed in `EmbeddedContracts` (`common/types/address.go`);
- an ABI definition (new file under `vm/embedded/definition/`);
- method implementations of the `Method` interface — `GetPlasma` / `ValidateSendBlock` / `ReceiveBlock` (new files under `vm/embedded/implementation/`);
- an `applySettlementDiffs(...)` layer gated by a new `IsOffchainExecutionSporkEnforced()` (`vm/vm_context/spork.go`);
- a spork id following the placeholder-hash release flow (`common/types/spork.go`).

The HTLC contract is the exact precedent (`applyHtlcDiffs` gated by `IsHtlcSporkEnforced`).

**Anchoring is free.** Every value an embedded contract writes via `context.Storage()` is canonicalized into the write-set, hashed into `ChangesHash` (`block.ChangesHash = db.PatchHash(changes)`, `vm/supervisor.go`), committed into the momentum hash (`chain/nom/momentum.go`), signed by the producing pillar, and re-verified by every node. Registering an L2 commitment is therefore *just a state write* — anchored automatically, **with no momentum or account-block format change and no hard fork beyond the spork**. This is why the Settlement spork is a contract-activation spork (like `HtlcSpork`), not a momentum-version bump (like `StateRootSpork`, which advances momentums to v3 to carry a header `StateRoot`).

**Inputs and ordering.** L2 inputs are ordinary account-blocks sent to Settlement (data + plasma only). The sequencer queues sends per-contract and the VM consumes them in canonical order; the canonical order is exactly the committed `MomentumContent` order — ascending `AccountHeader.Bytes() = Address‖Height‖Hash` (`common/types/account_header.go`, `chain/nom/momentum_content.go`). The executor reproduces this with no new derivation, so it has zero sequencing authority and force-inclusion is native (SPEC §4).

**Value movement.** Embedded receives auto-process (pillars auto-receive, `pillar/worker_contract_generator.go`) and can emit descendant `ContractSend` blocks (`vm/vm.go`) — the mechanism by which `RelayMessage` releases escrow. Embedded addresses have unlimited L1 plasma; users pay for inputs via fused plasma or PoW. DA is inherited because inputs are on-chain account-blocks, capped at 16 KiB (`vm/constants/plasma.go`).

**Bond and time windows.** The executor bond mirrors `RegisterSentinelMethod`'s escrow/lock/revoke cycle (`vm/embedded/implementation/sentinel.go`); the withdrawal delay mirrors the `TimeChallenge`/`SecurityInfo` momentum-height windows used across the bridge and liquidity contracts (`common.go`). Slashing is *not* built (Phase 2).

---

## 4. End-to-end flows

### 4.1 Deposit-and-call (payable `CallL2`)

```
User ──CallL2{domainId, target, plasma_limit, payload} + ZTS value──▶ Settlement (L1 account-block)
  Settlement.ReceiveBlock: record deposit (totalDeposited += value, aggregate only), enqueue canonical input
  Executor: at globalInputIndex N, run target(payload) with deposit in frame; contract credits caller in its own state
            and returns claimed_deposit; runtime auto-refunds (deposit_amount - claimed_deposit) to depositor (§18.5)
  Executor: fold StateDiff → postStateRoot; build batch [..N..]; SubmitBatch(commitment)
  Settlement.SubmitBatch: verify contiguity + preStateRoot==prev postStateRoot + AssetFlowSummary; store SUBMITTED
  … withdrawal delay elapses → FINALIZED
```

One L1 account-block funds and invokes (SPEC §18.5). The deposit credit is unconditional; a call revert rolls back only the contract's effects.

### 4.2 Withdrawal (L2 → L1)

```
Contract: debit the account in its own state, emit L1_WITHDRAWAL outbox message (recipient, asset, amount)
Executor: commit batch with outboxRoot over the message
… batch FINALIZED after the delay …
Anyone ──RelayMessage{message, inclusion proof vs outboxRoot}──▶ Settlement
  Settlement: verify proof + FINALIZED + outboxId not in processedOutbox; register pendingWithdrawalReserve
  … withdrawal delay from finalization … release: transfer via descendant ContractSend, re-check conservation
```

`RelayMessage` is permissionless and releases at most one withdrawal per call (bounded descendant fan-out, SPEC §27.9). Replay is impossible via the unique `outboxId` + `processedOutbox` set.

### 4.3 Contract deployment

```
DeployContractStart(code_hash, total_size, chunk_count) → pending record keyed by (domainId, code_hash)
DeployContractChunk × chunk_count (≤16 KiB each, hash-committed)
DeployContractFinalize → assemble, verify SHA3==code_hash, validate (no WASI/float/SIMD/threads, 3 imports),
                         instrument (gas/stack/memory), CodeHash = sha3(instrumented), derive ContractID
```

Content-addressing by the pre-instrumentation `code_hash` removes all executor discretion over the assembled bytecode (SPEC §11). Two hashes: `code_hash` (developer identity) vs `CodeHash` (executable identity).

---

## 5. The shared SMT, architecturally

One SMT *algorithm* serves both layers; the maintenance differs. This is the most divergence-prone area, so the boundary is explicit:

```
                 ┌─────────────────────────────────────────────┐
                 │  SHARED PATH-BASED CORE (frozen, conformance) │
                 │  LeafHash, InternalHash, RootOfLeaves,        │
                 │  ProveByPath, Verify{Proof,Absence}ByPath     │
                 └───────────────▲─────────────────▲────────────┘
                                 │                 │
              ┌──────────────────┴───┐     ┌───────┴───────────────────┐
              │ L1 momentum adapter  │     │ L2 executor adapter        │
              │ (common/trie/Tree)   │     │ (in the executor)          │
              │ path = sha3(dbkey)   │     │ path = sha3(cid‖local_key) │
              │ empty value = delete │     │ EMPTY sentinel = delete;   │
              │ versioned persistence│     │ zero-len value = present-  │
              │                      │     │ empty; witness collection  │
              └──────────────────────┘     └────────────────────────────┘
```

The core hashes, routes, and proves identically for both — the same vector set (`smt-v1-test-vectors.json`) gates it. The adapters differ only in how they map keys to paths and how they treat empties. The L2 adapter **must not** reuse the L1 adapter, for the two reasons in `MERKLE_STATE_L2_ALIGNMENT.md`. The payoff: in Phase 2, the on-chain dispute referee verifies L2 proofs with the *same* `VerifyProofByPath` the executor uses — one verifier, no second implementation.

---

## 6. Domain model and isolation

Settlement anchors **domains**; a domain is `{runtime, STF spec, input source, bonded executor set, state-root lineage}`. Per-domain keying on every counter is what gives **domain isolation**: a faulty or dishonest domain's executor can never reach another domain's custody, because conservation is enforced per (domain, asset) and the executor is bound per `domainId`.

Phase 1 registers **exactly one** domain (WASM) with one bonded executor. The schema is domain-shaped from day one because retrofitting a `domainId` into storage keys later would be a migration, whereas carrying it now is nearly free. Opening `RegisterDomain` beyond the single WASM domain is a later governance decision, not an engineering one. A future runtime is a new handler compiled into `znnd` and activated by governance/spork, with its own executor(s) bonding in; cross-domain interaction, when it exists, is asynchronous (outbox → finalize → relay into the other domain's inbox) — there are no synchronous cross-domain calls.

**Input source (SPEC §6.1).** Each domain declares where its inputs originate: `L1_NATIVE` (Settlement account-blocks — Phase 1's WASM domain), `L1_RELAYED` (external data posted to L1, e.g. a Bitcoin bridge relaying headers + inclusion proofs), or `EXTERNAL_OBSERVED` (read directly off an external chain). The kind is a security-typed property — it fixes where canonical order and data availability come from — and is the field a user reads to judge a domain's trust profile. Phase 1 activates only `L1_NATIVE`; the other two are reserved in the schema, so a relayed domain later is a new handler, not a protocol change.

**Executor set (SPEC §6.2).** The single `executor` is generalised to an `executors` set with a `proposerPolicy`. Phase 1 uses a size-1 set under `SINGLE` — behaviour identical to one bonded executor — while Phase 2's permissioned set (random proposer + backup) needs no schema or commitment-format change.

---

## 7. Trust and safety model

Phase 1 is **bonded attestation, not trustless execution** (SPEC §1). The on-chain, executor-independent guarantee is aggregate solvency per (domain, asset): `totalReleased + pendingWithdrawalReserve ≤ totalDeposited`. The safety mechanisms are the executor bond, the withdrawal delay, the per-batch withdrawal cap, the conservation invariant, and public visibility of every commitment during the delay. Per-account correctness relies on executor honesty until Phase 2 fraud proofs. This framing must be communicated to users without obfuscation.

---

## 8. Forward compatibility

The Phase 1 surface is chosen so Phases 2 and 3 are additive:

- **Phase 2 (fraud proofs).** Adds the momentum state root (the L1 half of the shared SMT, already in progress via `StateRootSpork`), a per-call replay referee that verifies L2 proofs with `VerifyProofByPath`, a dispute-game contract with slashing, DA availability enforcement, inter-batch outbox ordering, and activation of the permissioned executor set. As of SPEC v1.3.0 the `DomainRecord` already carries the `executors` set, `proposerPolicy`, and `inputSource`, and the commitment the `executorId`; the per-domain input-sequence contiguity already pins the challenge target. Phase 2 *populates* these fields rather than adding them — nothing in the on-chain footprint changes except added Periphery verifier registries.
- **Phase 3 (validity proofs).** Swaps the dispute game for a verifier; the reserved `proofData` field (SPEC §19) is the forward hook, and the withdrawal delay can shrink to proof-generation latency. The single anticipated breaking change — a ZK-friendly SMT hash — is isolated behind one interface (SPEC §13.2) and executed as a one-time versioned migration.

The decision that makes all of this possible is taken in Phase 1: **inputs stay as on-chain account-blocks**, so DA is inherited from L1 and every input is replayable by anyone.

---

*See `SPEC.md` for all normative requirements, `EXECUTOR.md` for the executor binary architecture (relay/executor/watcher roles, codebase grounding), `MERKLE_STATE_L2_ALIGNMENT.md` for the `common/trie` upgrade plan, and `../phase-2/SPEC.md` / `../phase-3/SPEC.md` for later phases.*
