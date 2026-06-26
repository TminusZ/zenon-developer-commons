# Phase 1 — Off-Chain WASM Execution with Bonded Attestation and On-Chain Conservation

**Document status:** Specification — normative.
**Version:** 1.3.0
**Phase scope:** Phase 1 (single bonded executor per domain; bonded attestation, not trustless execution). The domain schema is generalised for multi-domain, multi-executor, and external-input operation in later phases (§6.1, §6.2), with Phase 1 as the degenerate case.
**Classification:** Normative requirements with *Informative* commentary and explicitly marked *Deferred* items.

**Revision history:**

- **1.3.0** — Generalised the domain schema with no behavioural change to Phase 1. Added `inputSource` (§6.1) and `proposerPolicy` (§6.2) to `DomainRecord`; the single `executor` field becomes the `executors` set (§6.2). Renamed batch bounds and the domain cursor to a generic **input sequence** (`firstInputSeq`/`lastInputSeq`, §4.5–§4.6, §19), with `globalInputIndex` as the value for L1-sourced domains. Generalised `SubmitBatch` acceptance and §22 to the entitled proposer of the executor set. Phase 1 remains `L1_NATIVE` / `SINGLE` / size-1; **no migration required**.
- **1.2.0** — Prior baseline.

---

## Conventions

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **MAY**, and **OPTIONAL** are to be interpreted as in RFC 2119 and RFC 8174.

Three classes of content appear:

- **Normative** text defines binding requirements.
- **Informative** text (a leading `>` blockquote, or an explicit *Informative* label) explains rationale and carries no binding force.
- **Deferred** items are explicitly out of Phase 1 scope, recorded so Phase 1 does not foreclose them.

The architectural invariant of this protocol is:

> **Consensus orders. Executors compute. Settlement anchors.**

Every requirement derives from that invariant. This document is self-contained and normative: it is written to be handed directly to implementers. Design rationale, component architecture, end-to-end flows, and the go-zenon integration map live in the companion `ARCHITECTURE.md` (informative); the normative requirements for sharing the SMT core with L2 — including the path-native API the L2 executor MUST use and the key-hashing functions it MUST NOT call — are in §13.1. Companion machine-readable artifacts (`smt-v1-test-vectors.json`, `proof-format.md`, `wasm-gas-table-v1.json`/`.md`, `execution-conformance-v1.json`) are normative where they specify exact bytes, ordinals, or costs.

---

## 1. Trust model

> **Phase 1 is bonded attestation. It is not trustless execution.** This is normative context for the entire specification and **MUST** be communicated to users and integrators without qualification or obfuscation.

The chain cannot pay out more than was deposited in aggregate per (domain, asset) — enforced on-chain, independent of executor honesty. Per-account balance correctness relies on the bonded executor's honesty until Phase 2 fraud proofs.

| Guaranteed in Phase 1 (on-chain, executor-independent) | Not guaranteed until Phase 2 |
|---|---|
| Aggregate solvency per (domain, asset): `totalReleased + pendingWithdrawalReserve <= totalDeposited` | Per-account balance correctness (who owns what) |
| Domain isolation: a domain's executor can never reach another domain's custody | On-chain verification of `preStateRoot`/`postStateRoot` (execution correctness) |
| Canonical input order fixed by L1; the executor cannot reorder/skip/insert | Slashing for incorrect execution |
| Batch chaining (`preStateRoot == prev postStateRoot`), contiguous input ranges; withdrawal delay; per-batch cap; public commitments | DA availability enforcement |

**Normative:**

- The Settlement contract **MUST NOT** execute WASM.
- The Settlement contract **MUST NOT** verify execution correctness.
- The Settlement contract **MUST** record batch commitments and **MUST** enforce custody, withdrawal delays, batch caps, and the per-(domain, asset) conservation invariant (§18).
- The executor bond, the withdrawal delay, the per-batch withdrawal cap, the conservation invariant, and the public visibility of commitments during the delay are the safety mechanisms in Phase 1.
- Aggregate over-withdrawal **MUST** be prevented on-chain by Settlement conservation accounting (§18), independently of executor honesty.

> The honest framing: Phase 1 cannot pay out more than was deposited in aggregate (enforced on-chain), but within the withdrawal delay and bounded by the bond and the per-batch cap it can misattribute balances among accounts if the executor is dishonest. That residual trust is removed in Phase 2.

---

## 2. Goal and scope

Run smart contracts off the consensus layer and settle their results on Zenon L1, without any momentum-format change and without L1 ever executing contract code. Phase 1 is the smallest deterministic WASM execution layer that can later be hardened with fraud proofs (Phase 2) and validity proofs (Phase 3) additively — no rewrite, no state migration, with the single exception of the deferred Phase 3 ZK-friendly state-tree hash migration (§13.2).

### 2.1 Non-goals

- Phase 1 does **NOT** execute WASM on L1.
- Phase 1 does **NOT** verify execution correctness on-chain (no fraud proofs, no validity proofs).
- Phase 1 does **NOT** provide trustless execution (§1).
- Phase 1 does **NOT** define synchronous cross-contract calls (§17).
- Phase 1 does **NOT** define a multi-executor set, native L2 token issuance, or zkVM circuit design.
- Phase 1 does **NOT** define L1 consensus mechanics; the Zenon momentum chain is consumed as given.

### 2.2 Phase roadmap

| Phase | Executor model | Correctness model | Finality model |
|---|---|---|---|
| Phase 1 | Single bonded executor per domain | Bonded attestation (no on-chain correctness verification) | Withdrawal delay |
| Phase 2 | Permissioned executor set | Fraud proofs + DA availability enforcement | Fraud-proof challenge window |
| Phase 3 | Permissionless executors | Validity proofs (ZK) | Proof-verified, optionally immediate |

**Normative:** Phase 1 design decisions **MUST NOT** create structural barriers to Phase 2 or Phase 3, except the state-tree hash migration deferred in §13.2, which **MUST** be implemented as a one-time versioned migration.

---

## 3. Architecture

Settlement is a **runtime-agnostic anchor**: it holds escrow, maintains a **domain registry**, and records batch commitments — it never interprets contract code. The unit it manages is an **execution domain** (a runtime + STF spec + bonded executor + state-root lineage). Phase 1 ships the Settlement core plus **exactly one domain handler — WASM** — and registers **one bonded executor running the WASM runtime** at launch. The schema is domain-shaped so additional runtimes need no migration; opening domain creation further is an administrator decision in Phase 1 (later, a governance/multisig decision — §6, §23).

```
   L1 (Zenon)                                   Off-chain                    Off-chain (best-effort)
   ┌────────────────────────────────┐        ┌──────────────────┐         ┌────────────────────┐
   │ Settlement embedded contract   │ inputs │  WASM Executor   │ bundles │ Sentinel / libp2p  │
   │ (spork-gated)                  │◀──────▶│ (single bonded,  │────────▶│ DA serving by      │
   │  domain-agnostic CORE:         │ Submit │  per WASM domain)│ DAHash  │ DAHash, browser GW │
   │   registry · escrow/custody    │ Batch  │  runtime + SMT   │         └────────────────────┘
   │   per-domain commitments       │◀───────│  batch builder   │
   │  domain HANDLERS: [ WASM ]     │        └──────────────────┘
   └────────────────────────────────┘  commitments anchored via ChangesHash → momentum (no header change)
```

**Normative component roles:**

- **L1 consensus (Zenon momentum chain):** **MUST** provide canonical ordering of all inputs (§4) and anchor Settlement storage including batch commitment roots. **MUST NOT** execute WASM. It is the sole source of truth for canonical input order and for input finality.
- **Domain-agnostic core (one implementation, serves every domain):** the domain registry + lifecycle, per-(domain, asset) escrow/custody + conservation, per-domain executor registration + bond, batch-commitment chaining/contiguity keyed by `domainId`, withdrawal delay/finality, outbox replay protection, and pause.
- **Domain handler (one per runtime; Phase 1 = WASM only):** the runtime's input vocabulary plus any Settlement-side bookkeeping the runtime needs — for WASM, the chunked-deployment state machine and `code_hash` records. Compiled into `znnd`, gated by the spork. A future runtime adds another handler the same way (§6).
- **Executor:** **MUST** consume the canonical input stream filtered to its `domainId` in canonical order, compute deterministic WASM state transitions off-chain, produce execution artifacts, and submit batch commitments. It **MUST NOT** reorder, skip, censor, or privately insert inputs; it has no sequencing authority.
- **Browser clients / watchers:** **SHOULD** download execution data bundles (§20) and reproduce results independently. In Phase 1 this is advisory — there is no on-chain channel to act on a detected divergence; that channel is added in Phase 2.
- **Sentinels / libp2p:** **SHOULD** serve bundles and chunks addressed by `DAHash` best-effort (§20); not consensus-critical in Phase 1.

**On-chain vs off-chain (normative):** L1 **MUST** store only roots and bounded commitment metadata; it **MUST NOT** store bulk execution-layer state or bulk execution data. Bulk state (the SMT) and bulk data (input data, witnesses, per-input results) are held by the executor and published off-chain.

> This separation is the load-bearing decision. It keeps L1 cost bounded and constant per batch and is what lets the WASM layer be added with no momentum-structure change.

---

## 4. Canonical input stream

### 4.1 Origination

**Normative:**

- All inputs **MUST** originate as account-blocks sent to the Settlement embedded contract on L1, carrying a `{domainId, payload}` envelope (data + plasma only; pillars order them, never execute them). Data availability is inherited from L1.
- The valid input types are exactly: `CallL2`, `Deposit`, `DeployContractStart`, `DeployContractChunk`, `DeployContractFinalize`, `UpgradeContract`. (`Deposit` and the deploy/upgrade/call surface are domain-scoped by `domainId`; core methods are in §5.3.)
- An input becomes part of the canonical stream when, and only when, the account-block carrying it is included in a confirmed momentum (§4.3).
- The executor **MUST NOT** process inputs from any source other than the canonical stream and **MUST NOT** treat any privately observed transaction as an input until it appears in a confirmed momentum.

### 4.2 Force inclusion is native

**Normative:**

- Force inclusion requires no additional mechanism. A user who submits any valid input to Settlement and has the account-block included in a confirmed momentum has force-included it.
- The executor **MUST** process that input in canonical order. A batch omitting a canonical input fails contiguity verification at Settlement (§4.6) and **MUST** be rejected.

> The Settlement contract *is* the force-inclusion mechanism. The only residual censorship surface is L1 censorship — preventing an account-block from entering a momentum at all — an L1 consensus concern outside this scope.

### 4.3 Confirmed-momentum requirement

**Normative:**

- The executor **MUST** consume inputs only from momenta at or below the node's confirmation frontier, so ordering cannot be altered by an L1 reorganization.
- The executor **MUST NOT** include in a batch any input whose containing momentum is not yet confirmed.

### 4.4 Canonical ordering

**Normative:** the canonical order of inputs **MUST** be:

1. **Momentum height ascending.**
2. **Within a momentum, the existing `MomentumContent` order committed by go-zenon** — the ascending lexicographic order of `AccountHeader.Bytes()`, where

   ```
   AccountHeader.Bytes() = Address (20B) || Height (8B big-endian) || Hash (32B)
   ```

- The executor **MUST** reproduce this exact order and **MUST NOT** apply any alternative (by account-block hash alone, fee, plasma, input type, or originator).

> This reflects go-zenon reality and is L1-verifiable with no new derivation: `common/types/account_header.go` defines `Bytes()` as `Address ‖ Height ‖ Hash`, and `chain/nom/momentum_content.go` sorts content by `bytes.Compare(a.Bytes(), b.Bytes())`. That ordering is already committed inside the momentum hash via `MomentumContent.Hash()`.

### 4.5 Global input index

**Normative:**

- Each input **MUST** be assigned a `globalInputIndex`: a `uint64`, zero-based, strictly monotonically increasing across the entire stream, never reset, assigned in canonical order.
- Assignment **MUST** be deterministic: any party reconstructing the canonical stream **MUST** compute identical values.
- `globalInputIndex` is bounded by `2^64 − 1`. Reaching that value is outside Phase 1 operational scope; an implementation **MUST** halt input admission (it **MUST NOT** wrap to `0`) if the next index would overflow, and the condition **MUST** be treated as a protocol-version migration trigger, never a reset.
- For generality across input sources (§6.1), a domain's ordered inputs form its **input sequence**, whose ordinal is the **input sequence number**; batch bounds and the per-domain cursor are named over it (`firstInputSeq`/`lastInputSeq`, §4.6, §19). For `L1_NATIVE` and `L1_RELAYED` domains the input sequence number **MUST** equal the `globalInputIndex` defined above. For `EXTERNAL_OBSERVED` domains (reserved in Phase 1) it is the domain-defined ordinal committed by the executor (§6.1).

> `globalInputIndex` is assigned over the global stream; per-domain filtering does not renumber. A domain's batch covers a contiguous slice of the global index (§4.6); indices belonging to other domains simply do not appear in this domain's batches, and contiguity is checked per domain against that domain's own cursor.

### 4.6 Batch contiguity and momentum splitting

**Normative:**

- A batch **MUST** be a contiguous slice of its domain's canonical input subsequence: the inputs for `domainId` with `globalInputIndex` values strictly increasing, beginning at the successor of that domain's previous batch's last index, with at most `MaxBatchInputs` (§25) inputs.
- A batch **MUST** contain at least one input.
- Batch boundaries **MAY** fall between two inputs originating in the same momentum. Momentum splitting across batches is permitted; there is no atomic-per-momentum requirement.
- Settlement **MUST** verify, per domain at acceptance, that `batch.firstInputSeq` is the successor of the domain's stored input-sequence cursor over that domain's inputs, with no gap, overlap, replay, non-canonical ordering, or count exceeding `MaxBatchInputs`. (For L1-sourced domains `firstInputSeq == firstGlobalInputIndex`; §4.5.)

> **Contiguity is per-domain over the domain's subsequence, not over the raw global index.** When two domains (A and B) are both active, the global stream might carry inputs at indices: 5(A), 6(B), 7(A), 8(B), 9(A). Domain A's subsequence is `{5, 7, 9}`. A valid first batch for domain A covering indices 5 and 7 has `firstInputSeq = 5`, `lastInputSeq = 7` (equal to `firstGlobalInputIndex`/`lastGlobalInputIndex` for this L1-sourced domain) — the raw jump from 5 to 7 is correct and expected. Domain A's stored cursor advances to 7; the next batch must start at the domain A input whose `globalInputIndex` immediately follows 7 in domain A's subsequence (i.e., 9). Implementations **MUST NOT** check raw `globalInputIndex` contiguity; they **MUST** track each domain's last-consumed index independently and verify only that the incoming batch begins at the next index in that domain's own sequence.

> `globalInputIndex` contiguity (per domain) is sufficient for fraud proofs: a Phase 2 challenge targets a single index whose `preStateRoot` is the previous index's `postStateRoot`. Momentum boundaries are irrelevant. Allowing momentum splitting prevents a large momentum from forcing an oversized batch.

### 4.7 No executor sequencing authority

**Normative:** the executor **MUST NOT** reorder, skip, privately insert, or otherwise sequence inputs outside the canonical stream. There is no skip mechanism — omission produces a non-contiguous batch rejected on-chain.

---

## 5. Settlement embedded contract

### 5.1 Activation

**Normative:**

- Settlement **MUST** be a Zenon embedded contract gated behind a dedicated **`OffchainExecutionSpork`**.
- Before activation, all Settlement methods **MUST** reject inputs; after activation they become live per this spec.

> This uses the established extension pattern. A new embedded contract is registered by adding a base entry plus a spork-gated diff layer, exactly as the HTLC contract was added. In `vm/embedded/embedded.go`, `GetEmbeddedMethod` builds the active contract map by applying `applyXDiffs` layers gated by `context.IsXSporkEnforced()`. A new `applySettlementDiffs(...)` layer, gated by a new `IsOffchainExecutionSporkEnforced()` in `vm/vm_context/spork.go`, mirrors `applyHtlcDiffs` / `IsHtlcSporkEnforced`:
>
> ```go
> // vm/vm_context/spork.go — new accessor, mirroring IsHtlcSporkEnforced
> func (ctx *accountVmContext) IsOffchainExecutionSporkEnforced() bool {
>     active, err := ctx.cacheStore.IsSporkActive(types.OffchainExecutionSpork)
>     common.DealWithErr(err)
>     return active
> }
>
> // vm/embedded/embedded.go — new gate inside GetEmbeddedMethod
> if context.IsOffchainExecutionSporkEnforced() {
>     applySettlementDiffs(contractsMap)
> }
> ```
>
> The contract address is a new `z1qxemdeddedx…` value added to `EmbeddedContracts` in `common/types/address.go` (via `parseEmbedded`, alongside `HtlcContract`). The spork id follows the placeholder-hash release flow in `common/types/spork.go` (precedents: `HtlcSpork`, `DynamicPlasmaSpork`, `StateRootSpork`).

This is a **contract-activation spork** (like `HtlcSpork`), **not** a momentum-version bump (like `StateRootSpork`, which advances momentums to version 3 to carry a header `StateRoot`). Commitments anchor through the existing `ChangesHash` path, so the momentum header is unchanged: any value an embedded contract writes via `context.Storage()` is folded into `ChangesHash` (`block.ChangesHash = db.PatchHash(changes)` in `vm/supervisor.go`), committed into the momentum hash (`chain/nom/momentum.go`), signed by the producing pillar, and re-verified by every node. **No momentum or account-block format change; no hard fork beyond the spork.**

> *Informative.* The L2 root-sharing foundation is gated by its own independent spork: `chain/nom/momentum.go` defines `StateRootMomentumVersion = 3` with a `StateRoot` header field folded into `ComputeHash` from version 3; `verifier/momentum.go` enforces it (`verifyStateRoot`, `ErrMStateRootInvalid`, `ErrMStateRootMustBeZero`); `common/types/spork.go` carries `StateRootSpork` (placeholder hash, safe-by-default until governance activation); and `chain/state_tree.go` drives a `trie.NodeTree`. The Settlement spork (`OffchainExecutionSpork`) is independent of `StateRootSpork` and adds **no** momentum-version bump of its own; it anchors via `ChangesHash` as described above.

### 5.2 Core and Periphery

**Normative:**

- **SettlementCore** is node-binary embedded logic, changeable only by a coordinated node release gated behind a spork or hard fork. The administrator (and any Periphery method) **MUST NOT** be able to alter Core logic through any on-chain method or storage write. There is **no on-chain upgrade proxy** and no bytecode replacement; "immutable core" means binary logic only a sanctioned release can change.
- **SettlementPeriphery** is administrator-controlled configuration in contract storage, modified through dedicated admin methods (single Settlement administrator, §23) and **clamped** by Core to immutable hard bounds (§23).
- Periphery **MUST NOT** write Core state directly; Core reads Periphery values as inputs to its own enforcement and **MUST** clamp them.

**Core responsibilities (node-binary):** batch acceptance (canonical-ordering, contiguity, `AssetFlowSummary`, commitment-size checks); the domain registry + lifecycle; per-(domain, asset) deposit custody and conservation (§18); withdrawal registration, delay, release; the chunked-deployment state machine (§11); force-inclusion contiguity (§4.6); emergency pause (§23); hard bounds on all Periphery values.

> Maps onto existing patterns: bonded registration and time-windowed administration mirror `RegisterSentinelMethod` and the `TimeChallenge` / `SecurityInfo` machinery used across the bridge and liquidity contracts (`vm/embedded/implementation/sentinel.go`, `common.go`, `liquidity.go`).

**Periphery responsibilities (administrator-controlled storage):** approved `DAMode` set; challenge window / withdrawal-delay duration (within hard bounds); `MaxBatchWithdrawal` (within hard bounds); per-domain executor identity (§22) and per-domain `valueCaps`; the administrator and guardian set (§23); the emergency-pause authority address; reserved registries for the Phase 2 fraud-proof verifier and Phase 3 validity-proof verifier.

### 5.3 Method list

**Normative:** Settlement **MUST** expose exactly the following methods in Phase 1. Each implements the standard embedded-contract `Method` interface — `GetPlasma` / `ValidateSendBlock` / `ReceiveBlock` (`vm/embedded/embedded.go`). Every user/executor input carries `domainId`; core methods are domain-keyed, WASM rows are the WASM STF's vocabulary, and a different runtime would register its own.

| Method | Origin | Scope | Purpose |
|---|---|---|---|
| `RegisterDomain` | Admin | core | Register/configure a domain: `runtimeKind`, `stfSpecHash`, `minExecutors`, `valueCaps`, status. Phase 1 registers exactly one: WASM |
| `RegisterExecutor` | Admin | core | Bind/replace the bonded executor (+ bond) for a `domainId` (§22) |
| `Deposit` | User | core + WASM domain | Lock an L1 ZTS asset into custody (core) and deliver it to a named `target_contract` with no application payload, which credits it (§18.2, §18.5). Funds a contract / credits the depositor |
| `SubmitBatch` | Executor | core | Register a `domainId` batch commitment (§19) |
| `RelayMessage` | Permissionless | core | Relay a proven, finalized `domainId` outbox message, incl. L1 withdrawal release (§17) |
| `Pause` | Pause authority | core | Emergency pause — global or per-domain (`PAUSE_SUBMIT` / `PAUSE_RELAY`, §23) |
| `CallL2` | User | WASM domain | Submit a call into the WASM domain's input stream; **payable** — MAY carry attached ZTS value delivered to the target contract as a deposit (§18.5, §27.5) |
| `DeployContractStart` / `…Chunk` / `…Finalize` | User | WASM domain | Chunked WASM deployment (§11) |
| `UpgradeContract` | User | WASM domain | Replace code of an `OWNER_UPGRADEABLE` WASM contract (§12) |

Runtime upgrades for a domain are a governed delayed `stfSpecHash` bump (§6), not a per-call method.

### 5.4 Storage responsibilities

**Normative:** Settlement **MUST** maintain at least, all keyed by `domainId` where domain-scoped:

- The domain registry: `DomainRecord` per `domainId` (§6).
- The batch commitment chain per domain: per-batch roots, indices, `DAHash`, `DAMode`, `executorId`, `submittedAtHeight`, `AssetFlowSummary`, and batch state (`SUBMITTED` / `FINALIZED`).
- The per-domain input-sequence cursor (last input consumed by an accepted batch for that domain; for L1-sourced domains this is the `globalInputIndex`, §4.5).
- Per-(domain, asset) `totalDeposited`, `pendingWithdrawalReserve`, `totalReleased` (§18).
- Pending chunked-deployment records keyed by `(domainId, pre-instrumentation code_hash)` (§11).
- The processed-outbox set for replay protection (§17.3).
- Executor registration and bond per domain (§22).
- Periphery configuration (§23).

---

## 6. Domain model

Settlement anchors **domains**; a domain is the unit of runtime + STF + bonded executor + state-root lineage. **Phase 1 registers exactly one domain (WASM) with one bonded executor.** The schema is domain-shaped so additional runtimes need no migration.

**DomainRecord** (Settlement storage, keyed by `domainId`):

```
DomainRecord {
    domainId        // u32 identifier, assigned at RegisterDomain
    runtimeKind     // WASM — the only kind with a handler in Phase 1
    stfSpecHash     // pins runtime kind, runtime/VM version, genesis state, input-envelope + commitment format
    inputSource     // L1_NATIVE | L1_RELAYED | EXTERNAL_OBSERVED — where inputs originate (§6.1)
    executors       // the bonded executor set for this domain (§6.2); exactly one member in Phase 1
    minExecutors    // 1 in Phase 1; below this the domain cannot finalize batches
    proposerPolicy  // SINGLE | RANDOM_BACKUP | (reserved) STAKE_WEIGHTED — entitled-proposer rule (§6.2)
    valueCaps       // per-window per-asset outbox value caps — bounds at-risk value, sizes the bond
    status          // active / paused
}
```

**Normative:**

- `RegisterDomain` is **admin-only** (the Settlement administrator, §23) in Phase 1 and registers exactly one domain (`runtimeKind = WASM`, `inputSource = L1_NATIVE`, an `executors` set of size 1, `proposerPolicy = SINGLE`). `inputSource`, `executors`, and `proposerPolicy` are fixed at registration and changeable only by the governed mechanisms of §6.1/§6.2 (an `inputSource` change is a runtime-semantics change and **MUST** be treated as a `stfSpecHash` bump under `MinRuntimeUpgradeDelay`).
- All conservation, commitment, deposit, and withdrawal accounting **MUST** be keyed by `domainId` (and, for asset accounting, by `(domainId, asset)`). This per-domain keying is what gives **domain isolation**: a faulty/dishonest domain can never pay out beyond its own deposits, and one domain's executor can never reach another domain's custody.
- Routing: inputs reach a domain as a `{domainId, payload}` envelope sent to Settlement — never via an off-chain channel, so DA stays inherited. Value-bearing operations (`Deposit`, withdrawals) always route through Settlement because escrow lives there. The executor filters the confirmed momentum stream to its `domainId`.

**What Settlement governs (domain lifecycle):** `RegisterDomain`; executor bind/replace with a per-domain bond; **runtime upgrades as `stfSpecHash` bumps under a mandatory delay** (the L2-node-software upgrade path, giving users an exit window); domain pause; and the **escape hatch** for a stalled domain or one below `minExecutors` (forced withdrawals against the last finalized root — an administrator action in Phase 1, provable in Phase 2).

**Runtime upgrade delay floor (normative):** the mandatory delay on a `stfSpecHash` bump **MUST** satisfy `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`. A runtime upgrade changes the STF for all future roots and is the highest-impact change this protocol permits; users must have at least as long to observe and exit as the withdrawal delay gives them on any other finality boundary. Core **MUST** enforce this as a hard bound; the administrator **MUST NOT** configure a shorter upgrade delay regardless of Periphery settings.

**What lives inside the domain's STF (not Settlement):** the meaning of `CallL2`/deploy/upgrade, the L2 contract registry, per-contract code/version/owner, and the SMT layout — all defined by the WASM runtime. "The executor ran the wrong code/version" is therefore ordinary state divergence (attestable in Phase 1, fraud-provable in Phase 2), not a special Settlement failure mode.

> **One WASM runtime, open to others.** Phase 1 builds and runs a single runtime under one bonded executor. The domain-agnostic core does not preclude a third party proposing another runtime later: that is a new domain handler shipped into `znnd` and activated by governance/spork, with its own executor(s) bonding in. The per-runtime fraud-proof adapter (Phase 2) and synchronous/cross-domain messaging are out of Phase 1 scope; cross-domain interaction, when it exists, is asynchronous (outbox → finalize → relay into the other domain's inbox).

### 6.1 Input-source descriptor

**Normative:** every domain **MUST** declare `inputSource` ∈ `{ L1_NATIVE, L1_RELAYED, EXTERNAL_OBSERVED }`. The value is binding on how the executor and any verifier establish the canonical input stream, and on the data-availability and censorship guarantees the domain offers; it **MUST** be surfaced to users and integrators as part of the domain's trust profile.

| `inputSource` | Inputs originate as | Canonical order | Data availability | Censorship-resistance |
|---|---|---|---|---|
| `L1_NATIVE` | Settlement account-blocks (§4.1) | L1 momentum order (§4.4) | Inherited from L1 | Native force-inclusion (§4.2) |
| `L1_RELAYED` | External data submitted to Settlement as account-blocks | L1 momentum order of the relaying account-blocks | Inherited from L1 | Permissionless relay + force-inclusion |
| `EXTERNAL_OBSERVED` | Observations of an external system, read by the executor | The external system's order under a domain-pinned finality/confirmation predicate, committed by the executor | The external system + the published DA bundle (not L1-guaranteed) | Domain completeness predicate, fraud-enforced (Phase 2) |

- For `L1_NATIVE` and `L1_RELAYED`, the canonical order **MUST** be the L1 order of the originating account-blocks (§4.4); the executor **MUST NOT** apply any other order. For `L1_RELAYED`, the domain STF **MUST** establish input validity and canonicity (e.g. external-chain linkage, proof-of-work, confirmation depth) and **MUST** reject any relayed datum that does not extend the domain's canonical view; relaying **MUST** be permissionless.
- For `EXTERNAL_OBSERVED`, the domain **MUST** pin a deterministic finality/confirmation predicate in its `stfSpecHash`; the executor **MUST** commit the consumed external inputs (`inputRoot`, §19) and publish them in the DA bundle (`DAHash`, §20); and L2 state **MUST** be reconstructible from the committed inputs and bundle alone, without access to the external system. The weaker, non-L1 DA guarantee **MUST** be disclosed (§20).
- For all kinds the executor **MUST NOT** reorder, skip, or privately insert inputs (§4.7); for external sources this manifests as a **completeness** requirement (no canonical external item omitted), enforced by the same per-domain input-sequence contiguity as force-inclusion (§4.6).

**Normative (Phase 1):** only `L1_NATIVE` **MAY** be activated. `L1_RELAYED` and `EXTERNAL_OBSERVED` are reserved; Core **MUST** reject a `RegisterDomain` selecting a reserved `inputSource` while the Phase-1 profile is in force.

> *Informative.* `L1_RELAYED` makes an external domain a strict special case of an internal one: inputs are ordinary L1 account-blocks, so they receive a `globalInputIndex`, inherit L1 DA, and are fraud-proven by the §4/§19 machinery — the only new logic is inside the STF (e.g. SPV header validation). External bridges are light-client-shaped (headers + inclusion proofs, not whole chains), so the L1 data cost is small. `EXTERNAL_OBSERVED` exists for sources too data-heavy to relay, trading L1-anchored DA for executor-attested, fraud-checked input selection.

### 6.2 Executor set and proposer policy

**Normative:**

- Each domain **MUST** have an `executors` set of bonded executor identities, each a registered L1 address tied to that one domain (a registered executor supports exactly one domain). Each member **MUST** post a bond before activation, sized per §22.
- `RegisterExecutor` (admin, §23) adds or replaces a member of `executors` for a `domainId`; a replacement's first batch `preStateRoot` **MUST** equal the last accepted `postStateRoot` for that domain, and registration changes **MUST NOT** alter finalized state.
- `proposerPolicy` selects the **entitled proposer** for a given batch slot:
  - `SINGLE` — the set has exactly one member, always entitled. **Phase 1 MUST use this.**
  - `RANDOM_BACKUP` — the entitled proposer is selected by an objective, on-chain-derivable seed (e.g. derived from the momentum at the batch's first-input cursor boundary); after a fallback timeout in momentum heights, a deterministically-ordered backup member becomes additionally eligible. Selection inputs **MUST** be reconstructible by any party from L1 state and `executors`, with no executor discretion.
  - `STAKE_WEIGHTED` — reserved (permissionless / Phase 3); **MUST NOT** be activated before its enabling phase.
- State lineage remains linear: at most one batch is accepted per cursor position (§19); a non-entitled or non-canonical submission **MUST** be rejected. Non-proposing set members **SHOULD** operate as off-chain watchers that reproduce the proposer's work and (Phase 2) submit fraud proofs on divergence.

**Normative (Phase 1):** `executors` **MUST** contain exactly one member, `minExecutors` **MUST** be 1, and `proposerPolicy` **MUST** be `SINGLE` — observationally identical to the single-executor rule of §22. The §19 `executorId` field records which member submitted, so moving to a Phase-2 set requires no commitment-format change.

---

## 7. Runtime profile

### 7.1 WebAssembly Core 1.0 only

**Normative:**

- The runtime **MUST** implement WebAssembly Core Specification 1.0 (the MVP feature set) and no more, interpreter profile.
- It **MUST NOT** enable any post-MVP proposal unless a future version of this spec enumerates it.
- The deployment validation pipeline (§11) **MUST** reject any module using out-of-set features.

### 7.2 Prohibited capabilities

**Normative:** the runtime **MUST NOT** expose, and validation **MUST** reject modules using:

- **WASI:** any import from `wasi_snapshot_preview1` or any WASI namespace.
- **Floating point:** any `f32.*`/`f64.*` instruction or float type, including in imported signatures.
- **Threads / atomics:** the threads proposal, shared memory, any atomic instruction.
- **SIMD:** any `v128` instruction.
- **Nondeterminism sources:** system clocks, OS randomness, uninitialized-memory-dependent behavior, growth-dependent layout exposure.
- **Post-MVP integer ops:** the sign-extension operators (`i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, `i64.extend32_s`) and saturating conversions (`*.trunc_sat_*`), which are outside strict Core 1.0 MVP. They are never metered (`wasm-gas-table-v1`) and **MUST** be rejected at validation.

> Floating point is prohibited because NaN canonicalization is platform-dependent. Determinism is the precondition for Phase 2 fraud proofs and Phase 3 validity proofs.

### 7.3 Deterministic context

**Normative:**

- Linear memory **MUST** be zero-initialized before contract entry; table entries **MUST** be deterministically initialized.
- The only host imports are the three in §8. No other host function exists.
- Given the same execution context (§9), the same witnessed pre-state, and the same input data, every compliant runtime **MUST** produce a byte-identical `ExecutionResult` (§14).

### 7.4 Resource limits

**Normative:**

- Linear memory **MUST NOT** exceed `MaxMemory` (§25); a `memory.grow` that would exceed it **MUST** return `-1` and **MUST NOT** grow.
- Call-stack depth **MUST NOT** exceed `MaxStackDepth` (§25), enforced as a fixed constant identical across implementations.
- These limits **MUST** be enforced by deterministic instrumentation injected at deployment (§11). *This instrumentation is the highest-risk Phase 1 item and is retired first (§29).*

### 7.5 Traps and aborts

**Normative:**

- All WASM traps (unreachable, integer division by zero, trapping-op overflow, OOB memory/table, indirect-call type mismatch, uninitialized table element, stack exhaustion) **MUST** canonicalize to receipt status `RUNTIME_FAULT` (§15) with full rollback for the affected input.
- A contract `abort` (§8) **MUST** halt immediately, record `REVERT`, and roll back the affected input.
- Trap/abort handling **MUST** be deterministic.

---

## 8. Minimal host ABI

### 8.1 Allowed imports

**Normative:** the Phase 1 host ABI **MUST** expose exactly three imports; validation **MUST** reject any module importing any other symbol.

```
// Byte length of the value at key as a non-negative i64 when present; -1 when absent.
// Present-empty (0) and absent (-1) are DISTINCT (§13.6, §27.8).
storage_len(key_ptr: i32, key_len: i32) -> i64

// Reads value into out buffer. Returns bytes written; -1 if absent; -2 if buffer too small.
// Every observed key (including absent observations) is witnessed (§20).
storage_read(key_ptr: i32, key_len: i32, out_ptr: i32, out_len: i32) -> i64

// Intentional contract-level failure: halts immediately, full rollback, abort code recorded.
// Distinct from a WASM trap.
abort(code: i32) -> !   // no return
```

### 8.2 All other effects are returned, not called

**Normative:**

- All effects other than reads **MUST** be returned through the canonical result blob (§14): `StateDiff`, `Events`, `OutboxMessages`, `ReturnData`.
- The entry point **MUST** return a single packed `(pointer, length)` identifying the serialized `ContractEffects` in linear memory (exact ABI in §27.1). The runtime reads it, validates it, charges post-execution effect gas (§10), computes `preStateRoot`/`postStateRoot`, and applies it only on success.
- The following host functions **MUST NOT** exist in Phase 1: `state_write`, `transfer`, `withdraw`, `emit_event`, `send_message`, `set_return_data`, `sha3_256`.

> The declarative returned-blob model separates computation from state application (execution is a pure function from witnessed reads + input to an effects blob), removes write-ordering ambiguity (the contract declares the final value per key; the host applies in canonical key order), and minimizes the Phase 3 circuit (prove "module + inputs ⇒ blob"; SMT application is a separate, simpler stage). This is the single most important ABI decision for keeping Phase 2/3 tractable.

---

## 9. Execution context

**Normative:** each execution **MUST** be provided these deterministic context values, supplied by the runtime (none via a host call):

- `chain_id` (§9.1).
- `caller` (§9.2).
- `momentum_height`: height of the confirmed momentum establishing this input's position.
- `momentum_timestamp`: that momentum's `TimestampUnix` — a coarse, manipulable-within-tolerance reference. Contracts **MUST NOT** use it as a high-precision clock or security-critical entropy. It is non-decreasing across inputs in `globalInputIndex` order (it is the containing momentum's `TimestampUnix`, and momentum heights are consumed in ascending order, §4.4). Contracts **MAY** rely on non-decrease but **MUST NOT** rely on strict increase, since multiple inputs in the same momentum share one timestamp.
- `contract_id` (§12).
- `code_hash`: the post-instrumentation `CodeHash` (§11, §12).
- `input_index`: the `globalInputIndex`.

The runtime **MUST NOT** allow a contract to set, spoof, or override any context value, in particular `caller`. Context is presented through runtime-populated entry-point parameters / a context region (§27.1), not host functions; there is no `get_caller`/`get_code_hash`.

### 9.1 chain_id

**Normative:** `chain_id` **MUST** be `SHA3-256("ZENON_WASM_L2:" || network_name)` (`network_name` ∈ `"mainnet"`, `"testnet"`, named devnet), a fixed 32-byte constant recorded as a literal, never changing for the life of the network. It **MUST** be incorporated into `ContractID` derivation (§12) and replay protection (§26).

### 9.2 caller derivation

**Normative:**

- For L1-originated inputs, `caller` **MUST** be `SHA3-256("L1_CALLER:" || raw_l1_address)`.
- For contract-originated executions (an outbox message delivered to a contract, §17), `caller` **MUST** be the source contract's `ContractID`, with no additional hashing.
- The two caller domains **MUST** be structurally distinguishable; the domain separator guarantees an L1 caller can never collide with a `ContractID`.

---

## 10. Plasma and gas

### 10.1 Two separate ledgers

**Normative:**

- **L1 plasma** pays for account-block admission and is governed entirely by Zenon L1 rules. It **MUST NOT** be conflated with L2 gas.
- **L2 execution gas** is a separate ledger metered and enforced by the executor off-chain; it never touches L1 plasma consensus.
- `CallL2.plasma_limit` is an **L2 execution budget** authorized by the submitter and enforced by the executor — **not** L1 fused plasma.

> Submitting a `CallL2` costs L1 plasma to enter a momentum; executing the resulting input costs L2 gas, accounted off-chain. L1 cannot meter WASM without running it, which this spec forbids. Embedded addresses have unlimited L1 plasma (`vm/vm.go`); a user send costs `21000 + 68/byte` (`vm/plasma.go`), so a full 16 KiB input (≈1.14M plasma) exceeds the PoW-only ceiling and requires fused QSR — L2 inputs are feeless-but-rate-limited exactly like all L1 traffic.

### 10.2 Opcode gas table

**Normative:**

- L2 gas **MUST** be metered by a static table mapping each permitted Core 1.0 opcode to a fixed non-negative integer cost, fixed for a given `metering_version` (§24) and unchangeable without an increment (because in Phase 3 the table becomes part of the arithmetic circuit).
- Memory growth **MUST** be charged per page on `memory.grow` in addition to the base instruction cost. Declared **initial** linear memory **MUST** be charged at the same per-page rate before execution begins; if the L2 budget cannot cover it, the input fails `OUT_OF_GAS` before the contract runs. (The per-page rate and `memory.grow` base are in `wasm-gas-table-v1.json`.)
- The concrete table for Phase 1 is `metering_version = 1`, defined in `wasm-gas-table-v1.json` / `.md`. Implementations **MUST** reproduce those costs exactly, using the basic-block metering model defined there with the `br_table` and `memory.grow` surcharges.

### 10.3 Host-function gas

**Normative:** charged at invocation, before the host runs; if insufficient L2 gas remains, execution **MUST** halt with `OUT_OF_GAS` before the host executes. Values (`metering_version = 1`, reproduce exactly): `storage_len = 100`; `storage_read = 200 + 10 * ceil(value_bytes / 32)` (absent key charges base only); `abort = 1`.

### 10.4 Post-execution effect charge

**Normative:** after the contract returns its blob and before `StateDiff` is applied, the runtime **MUST** charge gas for declared effects from serialized sizes (`metering_version = 1`, reproduce exactly): `StateDiff` entry `500 + 20 * ceil(value_bytes / 32)` (deletion charges base only); event `100 + 10 * ceil(data_bytes / 32)`; outbox message `200 + 5 * ceil(payload_bytes / 32)`; `ReturnData` `10 + 2 * ceil(return_bytes / 32)`. If remaining gas is insufficient, the input **MUST** fail `OUT_OF_GAS` with full rollback; no partial effects.

### 10.5 Out-of-gas rollback

**Normative:** on `OUT_OF_GAS`, all state changes from the affected input **MUST** be discarded; gas accounting **MUST** be deterministic across implementations.

---

## 11. Contract deployment

> A non-trivial module exceeds the 16 KiB account-block data limit (`MaxDataLength`, `vm/constants/plasma.go`). Deployment is therefore chunked, committed by hash, and assembled deterministically before validation and instrumentation. Content-addressing by the pre-instrumentation `code_hash` removes all executor discretion over the assembled result. Deploy records are keyed by `(domainId, code_hash)`.

### 11.1 DeployContractStart

`DeployContractStart(domainId, code_hash, metadata_hash, total_size, chunk_count)` — **Normative:**

- `code_hash` **MUST** be `SHA3-256` of the complete pre-instrumentation bytecode (the deployer's binding commitment); `metadata_hash` **MUST** be `SHA3-256` of the canonical metadata encoding.
- `total_size` **MUST** be the exact byte length and **MUST NOT** exceed `MaxWasmSize` (§25); `chunk_count` **MUST** equal `ceil(total_size / MaxDAChunkSize)` and **MUST NOT** exceed `MaxChunkCount`.
- On acceptance, Core **MUST** create a pending record keyed by `(domainId, code_hash)` recording `metadata_hash`, `total_size`, `chunk_count`, deployer `caller`, start height, and an empty chunk set.
- If a non-expired, non-finalized record already exists for the same `(domainId, code_hash)`, fail `VALIDATION_FAILED`.

### 11.2 DeployContractChunk

`DeployContractChunk(domainId, code_hash, chunk_index, chunk_hash, chunk_data)` — **Normative:** the record **MUST** exist (non-finalized, non-expired) and the submitting `caller` **MUST** equal the recorded deployer; `chunk_index ∈ [0, chunk_count)` and not already present; `chunk_data` ≤ `MaxDAChunkSize`, all chunks except the last exactly `MaxDAChunkSize`, last exactly `total_size - (chunk_count-1)*MaxDAChunkSize`; `chunk_hash` **MUST** equal `SHA3-256(chunk_data)`. When `chunk_count == 1` the single chunk **is** the last chunk and its size **MUST** equal `total_size` (not `MaxDAChunkSize`). On success, record `(chunk_index → chunk_hash)`; chunk bytes are published in the data bundle, only the hash is committed to state.

### 11.3 DeployContractFinalize

`DeployContractFinalize(domainId, code_hash)` — **Normative:**

- The record **MUST** exist and the `caller` **MUST** be the deployer; all chunks **MUST** be present.
- Bytecode **MUST** be assembled by concatenating chunks in ascending index; `SHA3-256(assembled)` **MUST** equal `code_hash` and `len` **MUST** equal `total_size`, else `VALIDATION_FAILED` and the record is discarded.
- Validation **MUST** run on the assembled bytecode: Core 1.0 structural validation; rejection of WASI/floats/threads/atomics/SIMD and post-MVP integer ops (sign-extension, `trunc_sat`) per §7.2; host-import restriction to exactly `storage_len`/`storage_read`/`abort`; size checks; required exports (§27.1).
- Instrumentation **MUST** then run deterministically: gas-metering injection, stack-depth limiter, memory-growth limiter. The instrumented size **MUST NOT** exceed the post-instrumentation ceiling (§25).
- The executable `CodeHash` **MUST** be `SHA3-256(instrumented_bytecode)`. `ContractID` **MUST** be derived per §12 using the deployer address, this input's `globalInputIndex`, and `chain_id`. The deployment `ExecutionResult` **MUST** include both `code_hash` and `CodeHash`.

### 11.4 Two hashes

**Normative:** `code_hash` = `SHA3-256(pre-instrumentation)` (developer-visible identity, what chunked assembly verifies against); `CodeHash` = `SHA3-256(post-instrumentation)` (executable identity stored in state, provided as context, used by the STF). They **MUST NOT** be conflated; because instrumentation is deterministic, any verifier can reproduce `CodeHash` from the pre-instrumentation bytecode.

### 11.5 Expiry

**Normative:** a pending record **MUST** expire if not finalized within `DeploymentExpiryWindow` (§25) heights of `DeployContractStart`; an expired record **MUST** be treated as nonexistent and its `code_hash` freed; plasma spent on start/chunk **MUST NOT** be refunded on expiry.

---

## 12. Contract identity and upgrades

**Normative:**

- `ContractID` **MUST** be `SHA3-256(deployer_address || deployment_global_input_index(8B BE) || chain_id)` — unique (by `globalInputIndex` monotonicity) and stable across upgrades.
- `CodeHash` is the post-instrumentation hash (§11.4), stored in state and provided as context; on upgrade it changes, `ContractID` does not.
- Every contract **MUST** declare one upgrade policy at deployment, committed to the state root and immutable thereafter: `IMMUTABLE` (an `UpgradeContract` **MUST** yield `UNAUTHORIZED`); `OWNER_UPGRADEABLE` (code **MAY** be replaced by the designated owner). Reserved future policies **MUST NOT** be activated in Phase 1.
- `OWNER_UPGRADEABLE` contracts **MUST** specify an owner; `UpgradeContract` **MUST** be authorized by the owner (verified via `caller`, §9.2), **MUST** supply replacement bytecode passing the full §11.3 pipeline, and **MUST** produce a new `CodeHash`. Ownership transfer **MUST** be possible only by the current owner. Non-trivial replacement bytecode **MUST** use the chunked mechanism (§11).
- An upgrade **MUST NOT** reset or modify existing contract state; the protocol **MUST NOT** enforce ABI/state-layout compatibility (developer's responsibility). The upgrade `ExecutionResult` **MUST** include old and new `CodeHash`; the old `CodeHash` **MUST** be retained in historical state for future fraud-proof use.

---

## 13. State model

### 13.1 Off-chain SMT, shared pure layer

**Normative:**

- Execution-layer state **MUST** be a Sparse Merkle Tree maintained off-chain by the executor, with a fixed 256-bit key space and non-inclusion proofs for absent keys.
- L1 **MUST** store only SMT roots (within batch commitments); it **MUST NOT** store SMT contents or traverse the SMT.
- The SMT **MUST** be byte-for-byte deterministic across compliant implementations, verified against the conformance suite (§13.7).

**Shared library — scope (normative):** the L2 executor's SMT and the L1 momentum state root **MUST** be byte-identical for identical leaf sets and **MUST** be produced by the same consensus-frozen hashing/routing/proof core in `common/trie`: `LeafHash`, `InternalHash`, the constant-zero empty hash, and MSB-first routing (`hash.go`); the full-depth root computation (`compute.go`); and the deepest-first compressed-sparse proof codec `encodeProof`/`decodeProof` plus root reconstruction (`proof.go`). These bytes are conformance-bound by `common/trie/conformance_test.go`, which loads `smt-v1-test-vectors.json` and governs **both** layers from a single vector set.

**The L2 executor operates on 32-byte paths directly and MUST NOT route through any key-hashing entry point.** The L2 derived key (§13.3) is *already* a 32-byte `SHA3-256` output and is the SMT path directly; passing it to any function that internally applies `types.NewHash` would compute `sha3(path) ≠ path` and **double-hash**, producing a divergent tree. The following existing functions hash their `key` argument and are **L1-only** — the L2 executor **MUST NOT** call any of them: `VerifyProof(root, key, …)`, `VerifyAbsence(root, key, …)`, `Tree.Prove(id, key)`, `NodeTree.Prove(id, key)`, `Tree.Update`, and the `stagedApplier`/`stagedApplierMap` write-set appliers.

**Path-native public API (normative).** `common/trie` exports the following path-native functions, which perform **no** key hashing; the L2 executor **MUST** use only these for root computation, proof generation, and proof verification. Each reproduces the exact bytes locked by the conformance suite and adds only the path-vs-key distinction:

- `RootOfLeaves(paths []Path, values [][]byte) Hash` — the full-depth root over 32-byte paths and raw values.
- `ProveByPath(leaves, targetPath Hash) (present bool, value []byte, proof []byte)` — a proof for a target supplied as a path, never a key.
- `VerifyProofByPath(root, path, value, proof []byte) (bool, error)` — identical to `VerifyProof` except the supplied `path` is compared to the decoded proof's path directly, with no `types.NewHash` call.
- `VerifyAbsenceByPath(root, path, proof []byte) (bool, error)` — the absence analogue, likewise path-native.

The L1 maintenance adapter (`tree.go`, `nodestore.go`) remains the sole owner of key hashing and of the empty-value fold rule (§13.5.1, caveat 1).

> **What is NOT shared (normative caveat).** The L1 *maintenance* adapter (`common/trie/tree.go`: `Tree.Update`, `Commit`, `FoldFilter`, `stagedApplier`; and `nodestore.go`: `NodeTree.Update`/`Commit`/`Prove`) is L1-momentum-specific and **MUST NOT** be reused by the L2 executor, for two reasons:
>
> 1. **Empty-value-as-deletion.** The L1 adapter collapses an empty value to a deletion (`stagedApplier.Put`: `if len(value) == 0 { del }`) — correct for L1 storage, which has no present-empty values. The L2 model **requires** a *present-empty* leaf distinct from an absent key (§13.6). The L2 executor **MUST** implement its own `StateDiff` application per the canonical algorithm in §13.5.1, honoring the `EMPTY` deletion sentinel (§27.2) and never folding empty→delete. The core itself already supports a present-empty leaf: `LeafHash(path, [])` is `sha3(path)`, which is non-zero and distinct from the empty (absent) slot. (This has been executed against the source: present-empty root ≠ absent root; `LeafHash(path,[])` is non-zero.)
> 2. **Key pre-hashing.** The L1 adapter derives the leaf position by hashing the supplied db key (`types.NewHash(key)`), because L1 keys are arbitrary-length. The L2 derived key (§13.3) is *already* a 32-byte SHA3 output and is the path directly. The L2 executor **MUST** pass the derived key as the path into the path-native API (`RootOfLeaves`, `ProveByPath`, `VerifyProofByPath`, `VerifyAbsenceByPath`) and **MUST NOT** route through `Tree.Update` or any key-hashing verifier/prover, or it will double-hash.

### 13.2 Hash function

**Normative:**

- In Phase 1 and Phase 2 the SMT **MUST** use `SHA3-256` for leaves, interior nodes, and roots. Leaves are `SHA3-256(path || value)`; interior nodes `SHA3-256(left || right)`. Empty subtrees are the 32-byte zero hash at every level (the constant zero, not a per-level computed default), subject to the both-empty short-circuit (§13.4).
- A migration to a ZK-friendly hash **MAY** occur in Phase 3 and is **Deferred**; no ZK-friendly hash/field/width/parameter is locked in Phase 1. The SMT hash **MUST** be isolated behind a single interface so the migration touches one component.
- All non-SMT commitments (`eventRoot`, `outboxRoot`, `receiptRoot`, `inputRoot`, `DAHash`, `CodeHash`, `code_hash`, `ContractID`, `metadata_hash`, `stateDiffHash`, `returnHash`) **MUST** use `SHA3-256` in all phases and are not subject to the Phase 3 migration.

> This matches the shipped `common/trie`: `LeafHash(path, value) = sha3(path‖value)`, `InternalHash(left,right) = sha3(left‖right)` with `emptyHash = 32 zero bytes`, gated by `conformance_test.go` against `smt-v1-test-vectors.json`.

### 13.3 State-key derivation

**Normative:**

- State keys **MUST** be derived as `SHA3-256(contract_id || local_key)`, where `local_key` is contract-defined, at most `MaxStateKeySize` bytes (§25).
- The **runtime**, not the contract, **MUST** perform this derivation, always using the executing contract's `contract_id`. A contract therefore cannot address another contract's state. The keys a contract passes to `storage_len`/`storage_read` and emits in its `StateDiff` are `local_key`s; the runtime derives the SMT key before touching the tree.
- The derived 32-byte key is used directly as the SMT path (§13.1, caveat 2). Canonical `StateDiff` ordering (§27.2) is over derived keys.
- Protocol-reserved per-contract values (`CodeHash`, upgrade policy, owner) **MUST** be stored under a reserved key prefix contracts **MUST NOT** write; a write to a reserved key **MUST** yield `UNAUTHORIZED`.

### 13.4 Tree structure and proof shape

**Normative (these govern routing and proof bytes and match `common/trie` exactly):**

- The SMT **MUST** be an uncompressed full-depth binary tree of exactly 256 levels; every key occupies a leaf at depth 256 positioned by its 32-byte path. Implementations **MAY** use a compressed in-memory representation but the committed root and all proofs **MUST** equal the full depth-256 tree.
- Descent **MUST** be most-significant-bit-first: at depth `d`, the selecting bit is `(key[d/8] >> (7 - (d mod 8))) & 1`. Bit `0` routes left, `1` routes right. Interior nodes are `SHA3-256(left || right)` with `left` the bit-0 subtree.
- An interior node both of whose children are the 32-byte zero hash **MUST** itself be the zero hash and **MUST NOT** be `SHA3-256(zero||zero)`. With exactly one empty child, the empty side is the zero hash.
- Proofs **MUST** be full-depth over all 256 levels, deepest-first (leaf-to-root). A zero-hash sibling is a real sibling counted at its level. The canonical byte encoding — a 256-bit non-zero-sibling bitmap (deepest-first, MSB-first within each byte), `sib_count`, then only the non-zero siblings — is defined in `proof-format.md` and implemented by `encodeProof`/`decodeProof`; implementations **MUST** reproduce it byte-for-byte and **MUST NOT** truncate levels.

### 13.5 StateDiff application

**Normative:**

- A `StateDiff` is a canonical list of `(key, new_value)` sorted ascending by derived key, exactly one valid encoding (§27.2). Deletion uses the `EMPTY` sentinel, distinct from a present empty value.
- State changes **MUST** be staged and applied to the SMT only after the input succeeds and the post-execution effect charge is covered. On any failure (`REVERT`, `OUT_OF_GAS`, `RUNTIME_FAULT`, `RESULT_TOO_LARGE`, validation failure) no entries are applied.
- After applying a `StateDiff`, the resulting root **MUST** equal a fresh full recomputation over accumulated state (incremental == full recompute).

### 13.5.1 Canonical L2 StateDiff applier

**Normative:** the L2 executor **MUST** compute the post-state leaf set exactly as defined here. Given a prior leaf set `S` (a map of 32-byte derived keys → raw values) and a canonical `StateDiff` whose entries are sorted ascending by derived key with no duplicates (§27.2), the post-state leaf set `S'` is computed as:

1. `S' := S`.
2. For each entry `(key, new_value)` in `StateDiff` order:
   - If `new_value` carries the `EMPTY` sentinel length prefix `0xFFFFFFFF` (§27.2): **remove** `key` from `S'`. Deleting a `key` that is not in `S'` is a well-formed no-op that leaves the root unchanged.
   - Otherwise `new_value` has a length `L` in `[0x00000000, MaxStateValueSize]`: **set** `S'[key] = new_value`. This **includes** the present-empty case `L = 0x00000000`, which stores a zero-length value whose leaf hash is `LeafHash(key, [])` = `SHA3-256(key)` — distinct from absence (§13.6). The applier **MUST NOT** fold a zero-length present value into a deletion.
3. `postStateRoot := RootOfLeaves(S')` using the path-native API (§13.1).

The empty→delete fold of the L1 adapter (`tree.go`/`nodestore.go` `stagedApplier`) is L1-only and **MUST NOT** be used here; the only deletion trigger at L2 is the explicit `EMPTY` sentinel. The post-state root produced by this incremental applier **MUST** equal a fresh `RootOfLeaves` recomputation over `S'` (the incremental == full-recompute invariant, §13.5, §13.7 SMT-014). On any input failure (`REVERT`, `OUT_OF_GAS`, `RUNTIME_FAULT`, `RESULT_TOO_LARGE`, validation failure) the applier **MUST** leave state unchanged (`S' := S`, no entries applied).

> *Informative.* This algorithm is the consensus-critical bridge between §27.2's wire-level sentinel discrimination and §13's tree. The two distinctions it locks — `0xFFFFFFFF` ⇒ delete vs. `0x00000000` ⇒ present-empty, and "delete-absent is a no-op" — are exactly the points two independent implementers would otherwise resolve differently, silently changing the post-state root. A Phase 2 fraud-proof referee **MUST** run this identical applier to adjudicate a challenged `postStateRoot`.

### 13.6 Absent versus present-empty

**Normative:** the runtime **MUST** distinguish three observable conditions (see §27.8 for exact return semantics):

- **Absent** (non-inclusion): `storage_len → -1`; `storage_read → -1`, writes nothing.
- **Present-empty** (inclusion, zero-length value): `storage_len → 0`; `storage_read → 0`, writes zero bytes.
- **Present non-empty** (length `L>0`): `storage_len → L`; `storage_read → L` if buffer ≥ L (writes L), else `-2`.

A key deleted via the `EMPTY` sentinel is **absent** (`-1`), not present-empty. Every key observed (including absent observations) **MUST** be recorded in the input's witness set (§20).

> Conflating absent and present-empty would make a non-inclusion proof indistinguishable from an empty-value inclusion proof, letting a dishonest executor swap one for the other undetectably in Phase 2. This is a correctness requirement. (It is also exactly why the L2 executor cannot reuse the L1 `tree.go` empty==delete fold rule — §13.1.)

### 13.7 Conformance suite

**Normative:** the canonical SMT vector suite (`smt-v1-test-vectors.json` + `proof-format.md`) is a normative companion and **MUST** exist before Phase 1 implementation is considered complete. It **MUST** cover at minimum: empty-tree root; single-key insertion across the key space; long-shared-prefix keys; deletion of an existing key; deletion of a non-existent key (no-op); update to a new value; update to the current value (root unchanged); inclusion proofs; non-inclusion proofs through populated subtrees; present-empty inclusion (root distinct from absence); and batch `StateDiff` application equal to full recompute. Each vector specifies expected roots and proof bytes; an implementation **MUST** reproduce every value byte-for-byte. (The L1 pure layer is gated on this suite via `conformance_test.go`.)

The suite **MUST** additionally lock the L2-specific behaviors that the L1 layer does not exercise:

- **Path-native API equivalence (CV-PATH-1/2):** `VerifyProofByPath`/`VerifyAbsenceByPath`/`RootOfLeaves`/`ProveByPath` reproduce the exact roots and proof bytes of the SMT vectors when the SMT key is supplied as a **path** (no key hashing); the key-hashing `VerifyProof(root, path-as-key, …)` rejects the same path.
- **L2 applier (CV-APPLY-1/2):** a `StateDiff` mixing a present-empty write (`L=0x00000000`) and an `EMPTY` delete (`L=0xFFFFFFFF`) with expected post-root; and the incremental==full-recompute invariant of §13.5.1 applied step-by-step.

---

## 14. ExecutionResult and ContractEffects

### 14.1 Canonical binary serialization

**Normative:** `ExecutionResult` and all sub-structures **MUST** use a custom canonical binary format: integers fixed-width big-endian unsigned (`u8`/`u16`/`u32`/`u64`/`u256`); hashes/IDs/addresses/asset-ids fixed 32-byte (L1 `Address` is 20 bytes, used only in `caller` preimages and withdrawal recipients); fields in the exact order specified; `Bytes` = `u32` length prefix + raw bytes; lists = `u32` count + elements (sorted where required); exactly one valid encoding. JSON, protobuf, and SSZ **MUST NOT** be used. Full wire formats in §27.

### 14.2 Two objects

**Normative:** execution produces two related objects sharing the same field encodings:

- The contract returns a **`ContractEffects`** blob from `run` (§27.1; byte grammar §27.1a) — it cannot compute state roots. In order: `executionresult_version`, `globalInputIndex`, `StateDiff`, `Events`, `OutboxMessages`, `ReturnData`, `claimed_deposit`.
- The runtime assembles the canonical **`ExecutionResult`** (byte grammar §27.1a) by inserting `preStateRoot`, `postStateRoot` immediately after `globalInputIndex`: `executionresult_version`, `globalInputIndex`, `preStateRoot`, `postStateRoot`, `StateDiff`, `Events`, `OutboxMessages`, `ReturnData`, `claimed_deposit`.

`claimed_deposit` is a `u256` (§18.5): the amount of the input's `deposit_amount` the contract accepts into its own accounting. It **MUST** be `0` when the input carries no deposit, and **MUST NOT** exceed `deposit_amount` (else `RUNTIME_FAULT`). It is the only contract-returned field that is not a state/event/message effect; it is an instruction to the runtime's deposit-settlement step (§18.5).

The contract **MUST NOT** emit `preStateRoot`/`postStateRoot`; a `ContractEffects` blob that includes them **MUST** cause `RUNTIME_FAULT`. The runtime **MUST** compute `postStateRoot` itself and **MUST NOT** trust any root from the contract.

### 14.3 Failure semantics and size limits

**Normative:** on failure, `StateDiff`/`Events`/`OutboxMessages` **MUST** be discarded (empty) and `claimed_deposit` treated as `0`; `ReturnData` **MAY** be empty. (The runtime-emitted deposit-refund outbox of §18.5 is appended independently of contract effects and is **not** subject to this discard rule.) A malformed returned blob (length-prefix inconsistency, trailing bytes, out-of-order fields, non-canonical list order) **MUST** cause `RUNTIME_FAULT` with full rollback; the runtime **MUST NOT** repair it. `ReturnData` **MUST NOT** exceed `MaxReturnData`; the total serialized `ExecutionResult` **MUST NOT** exceed `MaxExecutionResult`, else `RESULT_TOO_LARGE` with full rollback (§25).

---

## 15. Receipts

**Normative:** each input **MUST** produce exactly one receipt (canonical encoding §27.7) containing, in order: `inputIndex`; `inputHash` (SHA3-256 of the canonical input encoding, §27.5); `batchId`; `contractId` (or zero if no contract target); `codeHash` (or zero if none executed); `status`; `gasUsed`; `stateDiffHash` (or zero if empty); `returnHash` (or zero); `eventRoot` (or zero); `eventCount`; `outboxRoot` (or zero); `outboxCount`.

**Status codes (exhaustive; ordinals fixed, §27.7):** `SUCCESS=0`, `REVERT=1`, `OUT_OF_GAS=2`, `RUNTIME_FAULT=3`, `VALIDATION_FAILED=4`, `RESULT_TOO_LARGE=5`, `UNAUTHORIZED=6`, `UNSUPPORTED_OPERATION=7`. Additional codes **MUST NOT** be introduced without a `receipt_version` increment.

**Failed-input outbox invariant:** a non-`SUCCESS` receipt has `outboxCount = 0` and `outboxRoot = bytes32(0)` **except** for a single runtime-emitted deposit refund (§18.5, §27.4). When a deposit refund is emitted on a failed input, the receipt **MUST** carry `outboxCount = 1` and `outboxRoot` computed over that one message. This is the only outbox content permitted on a non-`SUCCESS` receipt; all contract-emitted outbox messages are discarded on failure (§14.3). The refund message **MUST** appear in the input's bundle entry and witness set on a par with any success-path outbox message.

The batch `receiptRoot` **MUST** be a binary Merkle root (§27.3 construction) over all receipts ordered by `globalInputIndex`, and **MUST** be in the batch commitment (§19).

---

## 16. Events

**Normative:**

- Events are execution metadata, **not** state: they **MUST NOT** influence the state root and **MUST NOT** be readable by contracts.
- Each event contains `contractId`, up to `MaxTopicsPerEvent` 32-byte topics, a `data` field ≤ `MaxEventDataSize`, the enclosing `inputIndex`, and a monotonic `eventIndex` (§27.3).
- Events from one input **MUST** appear in emission order; per-input count ≤ `MaxEventsPerExecution`. The per-input `eventRoot` is a Merkle root over the input's events; the batch `eventRoot` is the Merkle root over all batch events ordered by `(inputIndex, eventIndex)`, included in the batch commitment. Events are included on success, discarded on failure.
- Wallets/indexers **MUST** be able to build event inclusion proofs against the committed `eventRoot` from the data bundle.

---

## 17. Outbox and messaging

### 17.1 Asynchronous only

**Normative:** Phase 1 **MUST NOT** provide synchronous cross-contract calls; a contract **MUST NOT** invoke another contract within its own execution. Cross-contract interaction **MUST** be expressed as asynchronous outbox messages processed in a later batch. There is no host function that executes another contract (§8).

> Deferred, not banned. A future versioned upgrade **MAY** introduce synchronous calls only if they preserve the single-input transition invariant `postStateRoot = F(preStateRoot, input_data, code_hash)`, introduce no nondeterminism, and do not disturb canonical ordering.

### 17.2 Format and commitment

**Normative:** an outbox message (encoding §27.4) contains source `contractId`, `inputIndex`, monotonic `outboxIndex`, `kind` (0 = L2 delivery, 1 = L1 withdrawal), the kind-specific target (target `ContractID`, or recipient L1 address + `AssetID` + amount), and a `payload` ≤ `MaxOutboxPayloadSize`. The per-input `outboxRoot` and the batch `outboxRoot` (over all messages ordered by `(inputIndex, outboxIndex)`) are Merkle roots included in the batch commitment.

### 17.3 Replay protection and RelayMessage

**Normative:**

- Each outbox message **MUST** have a globally unique `outboxId = SHA3-256(domainId || batchId || inputIndex || outboxIndex)`. Settlement **MUST** maintain a `processedOutbox` set; a `RelayMessage` whose `outboxId` is already present **MUST** be rejected. Messages **MUST** be processed at most once.
- `RelayMessage` is permissionless. It **MUST** supply the message and an inclusion proof against the committed `outboxRoot` of a `FINALIZED` batch (§21); Settlement **MUST** verify the proof and `FINALIZED` status before acting and **MUST** record the `outboxId` on processing. **Settlement MUST additionally verify that the `domainId` and `batchId` supplied with the relay message match the domain and batch whose committed `outboxRoot` is used to verify the inclusion proof**; a relay presenting a valid proof against a mismatched domain or batch cursor **MUST** be rejected.
- For L1 withdrawals, release **MUST** additionally satisfy the withdrawal delay and conservation rules (§18, §21) and is one-per-`RelayMessage` (§27.9).

> Inter-batch outbox ordering (a total order across batches for L2-to-L2 delivery) is **Deferred** to Phase 2; replay protection and at-most-once processing are sufficient for Phase 1.

---

## 18. Asset model and conservation

### 18.1 L1-backed assets only

**Normative:** Phase 1 **MUST NOT** issue L2-native tokens; all execution-layer assets **MUST** be backed 1:1 by L1 assets in Settlement custody. An `AssetID` **MUST** be the canonical 32-byte encoding of a 10-byte ZTS identifier: bytes `[0:22]` (the leading 22 bytes) are zero, and bytes `[22:32]` are the ZTS identifier in its native byte order. This map is bijective and is the **only** valid `AssetID` encoding; it **MUST NOT** be a hash of the ZTS and **MUST NOT** use any alternative alignment (e.g. the ZTS bytes at `[0:10]`). Settlement **MUST** reject any `AssetID` with a non-zero byte in `[0:22]` (`UNSUPPORTED_OPERATION` on user/executor inputs, `VALIDATION_FAILED` on `SubmitBatch`) and **MUST** reject any non-canonical alignment. All conservation counters (§18.3) and `AssetFlowSummary` entries (§18.4, §27.6) are keyed by this canonical `AssetID`, so the single encoding guarantees one custody pot per real asset.

### 18.1a Balances are contract-managed (no protocol ledger)

**Normative:**

- Settlement custody is a single aggregate pot per (domain, asset). Settlement/Core **MUST** track only the aggregate counters `totalDeposited`, `pendingWithdrawalReserve`, `totalReleased` (§18.3); it **MUST NOT** maintain a per-account balance ledger.
- **Per-account balances are contract state.** Each contract records who owns what in its own SMT state (§13). There is **no protocol-level spendable balance** and **no balance or transfer host function** (the host ABI is exactly the three imports of §8). Value is moved between accounts only by contract logic writing its own `StateDiff`.
- Value enters L2 only by being **delivered to a contract** that credits it: a `Deposit` (value, no application call — §18.2) or a payable `CallL2` (value + call — §18.5). A withdrawal leaves L2 only by a contract emitting an L1-withdrawal outbox message (§17); the outbox carries the L1 recipient/asset/amount and has **no protocol source-account field**, because the emitting contract is the source of truth for whose balance it debited.

> This is the only model consistent with both the three-import host ABI and the outbox withdrawal format: per-account accounting lives in contracts, Settlement bounds only the aggregate. It is also what the trust model already states — aggregate solvency is enforced on-chain; per-account correctness relies on executor honesty until Phase 2 (§1, §18.6). For the "park value in L2 and withdraw later, no dapp" case, a canonical first-party **system vault contract** provides bare custody through the same mechanism (a payable deposit credits `caller`; a withdraw call debits and emits the outbox).

### 18.2 Deposits and withdrawals

**Normative:**

- A `Deposit` is a user send of a ZTS asset to Settlement carrying `{domainId, target_contract}` (§27.5) — value with no application call. On the embedded receive, Core **MUST** increase `totalDeposited[domainId][asset]` (final on L1, so safe). The deposit is a canonical input that the runtime delivers to `target_contract` by running it with an empty application payload and the deposit in the input frame (`deposit_asset`/`deposit_amount`, §27.1); the contract accepts it via `claimed_deposit` and credits the depositor (`caller`) — or its own treasury — in its own state, and any unclaimed amount is refunded automatically (§18.5). Token burn/mint and descendant `ContractSend` mechanics already exist (`vm/vm.go`). If `target_contract` resolves to no deployed contract (no code at that `ContractID`), the input **MUST** fail `VALIDATION_FAILED`, and the full `deposit_amount` **MUST** be auto-refunded to the depositor per the §18.5 failure path; a deposit therefore can never strand against a non-existent or undeployed target. The same rule applies to a payable `CallL2` whose `target_contract` is undeployed.
- A withdrawal is initiated by a contract emitting an L1-withdrawal outbox message (§17); the contract **MUST** debit the withdrawing account in its own state at emission (double-spend prohibited at the execution layer — the contract owns the per-account ledger, §18.1a).
- On `RelayMessage` of a withdrawal from a `FINALIZED` batch, Core **MUST** increase `pendingWithdrawalReserve[domainId][asset]` and record a release-eligible height of `finalizationHeight + WithdrawalDelay`. On release (after the delay), Core **MUST** move the amount into `totalReleased[domainId][asset]`, decrease `pendingWithdrawalReserve`, transfer the asset via a descendant send, and re-check the conservation invariant. Release is one-per-`RelayMessage` (§27.9).

### 18.3 Conservation invariant

**Normative:** for every (domain, asset), after every state-modifying Settlement operation the following **MUST** hold, and Core **MUST** revert any operation that would violate it:

```
totalReleased[domainId][asset] + pendingWithdrawalReserve[domainId][asset] <= totalDeposited[domainId][asset]
```

> Implementation sketch (Core, every mutating path):
>
> ```go
> // pseudocode — runs after applying any deposit/withdrawal/release effect
> rel := store.TotalReleased(domainId, asset)
> pend := store.PendingWithdrawalReserve(domainId, asset)
> dep := store.TotalDeposited(domainId, asset)
> if new(big.Int).Add(rel, pend).Cmp(dep) > 0 {
>     return constants.ErrSettlementConservationViolated // revert; refund attached value via embedded rollback
> }
> ```

- The per-batch withdrawal cap `MaxBatchWithdrawal` (§25, pre-mainnet) **MUST** be enforced per (domain, asset) so the maximum loss from a single fraudulent batch is bounded and coverable by the executor bond.
- Aggregate over-withdrawal **MUST NOT** be possible and does not depend on executor honesty. Per-account correctness relies on executor honesty in Phase 1 and is removed by Phase 2 fraud proofs.

### 18.4 AssetFlowSummary

**Normative:** each batch commitment **MUST** include a bounded `AssetFlowSummary` of ≤ `MaxAssetsPerBatch` entries `(AssetID, depositCredit, withdrawalDebit)` (encoding §27.6). On `SubmitBatch`, Core **MUST** verify that deposit credits in the summary correspond to recorded L1 deposit events for that domain — including deposits carried by payable `CallL2` inputs (§18.5).

**`depositCredit` is the on-chain deposited amount** — the value locked into Settlement custody by the corresponding L1 `Deposit` or payable `CallL2` account-block, independent of whether the receiving contract claimed any or all of it. This definition reconciles against L1 deposit events (which is what Core verifies) and does not depend on contract behaviour or execution outcome. `withdrawalDebit` includes all outbox withdrawals from the batch, including runtime-emitted deposit refunds (§18.5). The per-asset conservation identity is:

```
depositCredit − withdrawalDebit(incl. refunds) = net amount that stayed in L2
```

This identity holds by construction across all deposit scenarios (success-partial, fail-full, partial-claim with refund) and **MUST** be stated explicitly in implementation documentation. The summary is recorded for Phase 2 fraud-proof use; per-account flows are not otherwise verified on-chain in Phase 1.

### 18.5 Deposit delivery, claim, and refund

> Both value-entry methods deliver an attached ZTS value to a target contract. `Deposit` is the no-application-payload form (fund a contract / credit me, e.g. a contract owner funding their contract); payable `CallL2` is the with-payload form (invoke a method, optionally with value). Both are mechanically supported by the existing VM — an embedded `ReceiveBlock` already observes `sendBlock.TokenStandard` and `sendBlock.Amount` alongside the ABI call data (e.g. `LiquidityStakeMethod`), so one send can carry both value and a call.

**Normative:**

- A `Deposit` or `CallL2` account-block **MAY** carry an attached ZTS value (`sendBlock.TokenStandard`, `sendBlock.Amount`); a non-zero amount is a deposit for the input's `domainId` and `target_contract`. `ValidateSendBlock` **MUST** reject an attached asset that is not custodyable for that domain.
- On the embedded receive, Core **MUST** increase `totalDeposited[domainId][asset]` by the attached amount. This custody increase is **unconditional and final** (the L1 transfer has already settled) and is independent of the outcome of the off-chain call.
- The runtime **MUST** populate the input frame's `deposit_asset`/`deposit_amount` (§27.1) from the on-chain send (`zero32`/`0` when none) and route execution to `target_contract`.
- **Explicit claim.** The contract declares, in its returned `ContractEffects`, a `claimed_deposit : u256` (§14.2) — how much of `deposit_amount` it accepts into its own accounting and **MUST** credit in its own `StateDiff`. The runtime **MUST** cause `RUNTIME_FAULT` if `claimed_deposit > deposit_amount`, or if `claimed_deposit > 0` when `deposit_amount == 0`. A contract that omits the field (default `0`), ignores the deposit, or fails claims nothing.
- **Automatic refund of the unclaimed remainder.** After execution the runtime **MUST** refund `deposit_amount − claimed_deposit` (on `SUCCESS`) or the full `deposit_amount` (on any failure — the contract's effects, including any claim, are discarded per §14.3) to the depositor. The refund is a runtime-emitted `L1_WITHDRAWAL` outbox message (§27.4) with `recipient_l1 = the source account-block's L1 sender`, `asset_id = deposit_asset`, `amount = the unclaimed remainder`; it is appended to the input's outbox set and committed in `outboxRoot`, then relayed after the withdrawal delay, conservation-bounded (§18.3), and replay-protected like any withdrawal (§17.3). No refund outbox is emitted when the remainder is `0`.
- A contract therefore **cannot silently strand the unclaimed portion of a deposit**: anything it does not explicitly claim — because it failed, has no deposit logic, or claimed only part — is returned to the depositor automatically. The claimed portion is subject to the same per-account trust boundary as all Phase-1 balances (§1); the safe default (`claimed_deposit = 0`) is the do-nothing default.

> *Informative.* The L1 tokens never move during execution — they sit in Settlement custody throughout. "Claim" is bookkeeping: `claimed_deposit` is the amount the contract takes responsibility for (and must credit in its own state); the remainder has no owner in the contract-managed model (§18.1a) and is therefore refunded out of the custody it already occupies, once the refund outbox finalizes. The only residual trust is a contract that *explicitly* claims and then mishandles the funds — equivalent to any contract bug over money it has accepted, which no settlement-layer rule can prevent. A heavier alternative (a persistent per-account *landing-zone balance* that accrues unclaimed deposits for the depositor to reclaim at will, rather than auto-refunding per input) is recorded in §30 should it ever be wanted; the per-input auto-refund here is the lighter form and needs no protocol balance ledger.

> **Phase 2 fraud-proof scope note (normative forward hook).** The deposit-settlement step — custody increase → frame population → claim evaluation → refund outbox emission — is part of the runtime's STF, not the contract's effects blob. A Phase 2 fraud-proof referee **MUST** include this step in the STF it verifies: it is not sufficient to prove only "module + inputs ⇒ effects blob." The referee **MUST** additionally verify that `claimed_deposit` is within bounds, that the runtime correctly computed `deposit_amount − claimed_deposit`, and that the resulting refund outbox message (if any) is present at the correct `outbox_index` in the committed `outboxRoot`. All inputs to this check are available without new commitment structure: `deposit_asset`/`deposit_amount` are in the input frame (part of `input_data`); `claimed_deposit` is in the committed `ContractEffects`; and the refund outbox message is in the DA bundle.

---

## 19. Batch commitments

**Normative:** a batch commitment (canonical order) contains: `protocol_version` and other version fields (§24); `domainId`; `batchId` (`u64`); `firstInputSeq`, `lastInputSeq` (the batch's input-sequence bounds, §4.5; equal to `firstGlobalInputIndex`/`lastGlobalInputIndex` for L1-sourced domains); `preStateRoot`, `postStateRoot`; `inputRoot` (Merkle root over the batch's canonical input encodings ordered by `globalInputIndex`); `receiptRoot`; `eventRoot`; `outboxRoot`; `DAHash`; `DAMode` (`u8`); `executorId`; `submittedAtHeight`; `assetFlowSummary`; `proofData` (reserved, **MUST** be empty in Phase 1 and Core **MUST** ignore it).

**Size/bounds:** a commitment **MUST** fit `MaxOnChainCommitmentSize` = `MaxDataLength` (16 KiB) — roots and bounded metadata only. A batch **MUST NOT** exceed `MaxBatchInputs` and **MUST** be contiguous per domain (§4.6).

**Batch commitment wire format (normative).** The commitment is encoded in the field order listed above using §27.0 primitives, with `assetFlowSummary` per §27.6 and `proofData : Bytes`. The version fields (§24) are encoded **first** in the structure; an unrecognized `protocol_version` **MUST** be rejected before any other field is interpreted. In Phase 1, `proofData` **MUST** be the zero-length `Bytes` encoding (`u32` length `0x00000000`, no payload): it is a present-but-empty field, **never** omitted. Core **MUST** reject a Phase-1 commitment whose `proofData` length is non-zero, and **MUST** reject any commitment with trailing bytes after `proofData`. The commitment has exactly one valid encoding.

**SubmitBatch (normative):** only a member of the domain's `executors` set that is the **entitled proposer** for the batch's `firstInputSeq` cursor position under the domain's `proposerPolicy` (§6.2) **MAY** submit. Core **MUST** verify: caller is a set member and the entitled proposer for `domainId` at that cursor position; `protocol_version` recognized; per-domain contiguity against the stored input-sequence cursor; commitment size; `assetFlowSummary` deposit correspondence; `proofData` is the zero-length encoding; and `preStateRoot == previous accepted postStateRoot` for that domain. On acceptance the batch enters `SUBMITTED` and the domain's cursor advances to `lastInputSeq`. Core **MUST NOT** verify execution correctness in Phase 1. (Under the Phase-1 profile — `SINGLE`, a size-1 set — this reduces to "caller is the domain's single registered executor.")

---

## 20. Data availability

**Normative:**

- Phase 1 DA is commitment-only: Settlement **MUST** record `DAHash` and `DAMode` per batch and **MUST NOT** verify on-chain that the bundle is available. `DAHash` **MUST** be `SHA3-256` of the canonical execution data bundle, encoded exactly as defined below.
- The bundle for a batch **MUST** contain, per input: the canonical input data, the SMT witnesses for all keys read or written (including absent observations), and the per-input `ExecutionResult`. It **MUST NOT** be submitted on-chain; it is published off-chain and committed via `DAHash`.
- **Canonical bundle layout (normative).** The bundle is the concatenation, in **ascending `globalInputIndex` order**, of one `BundleInputRecord` per input in the batch, with no separators and no framing other than that defined here:

  ```
  BundleInputRecord :=
      globalInputIndex : u64
      inputData        : Bytes                          // canonical input encoding (§27.5)
      witnessCount     : u32
      witnesses        : witnessCount × WitnessEntry     // ascending by derivedKey, no duplicates
      executionResult  : Bytes                           // canonical ExecutionResult (§27.1a), u32-length-prefixed

  WitnessEntry :=
      derivedKey : bytes32                               // the §13.3 derived SMT key
      proof      : Bytes                                 // §13.4 proof bytes: inclusion for a read/write of a
                                                         // present key; non-inclusion for an absent observation
  ```

  Witnesses **MUST** cover every key observed during the input — every key read or written, and every absent observation (§27.8) — sorted ascending by `derivedKey` with no duplicates. `DAHash = SHA3-256(concat(BundleInputRecord for each input, in ascending globalInputIndex order))`. The bundle has exactly one valid encoding; any reorder of records, omission of a witnessed key, or duplicate witness yields a different `DAHash` and is non-conformant. A Phase 2 watcher reconstructs this exact byte layout to verify availability and to bind witnesses to the committed roots.
- `DAMode` **MUST** be an explicit `u8`. The only approved Phase 1 value is `DAMode = 0`: best-effort publication via Sentinel/libp2p, content-addressed by `DAHash`, retrievable in chunks ≤ `MaxDAChunkSize`. Settlement **MUST** verify `DAMode` is in the Periphery-approved set.

> Limitation (**MUST** be disclosed): with no on-chain availability enforcement and no active fraud proofs, an unavailable bundle reduces the affected batch to reliance on executor honesty. Phase 2 adds DA enforcement.

---

## 21. Finality and withdrawal delay

**Normative:**

- A batch enters `SUBMITTED` on acceptance; no withdrawal **MAY** be released from a `SUBMITTED` batch. It transitions to `FINALIZED` when the withdrawal delay (measured in L1 momentum heights from `submittedAtHeight`, not wall-clock) has elapsed. Withdrawals **MAY** be released only from `FINALIZED` batches.
- The withdrawal delay **MUST** be at least the challenge-window duration and enforced by Core within hard bounds (§23). The exact duration is a pre-mainnet parameter (§25.2).

> Across phases: Phase 1, the delay protects via bond + bounded per-batch cap + public commitment visibility; Phase 2, it becomes the fraud-proof challenge window; Phase 3, validity proofs **MAY** permit immediate finality (the reserved `proofData` field is the forward hook).

---

## 22. Executor model

**Normative:**

- A domain has a bonded **executor set** with an entitled-proposer rule (§6.2). **Phase 1 MUST operate with exactly one active executor per domain** (`executors` size 1, `proposerPolicy = SINGLE`); its identity and bond **MUST** be in Settlement storage, and only it **MAY** call `SubmitBatch` for that domain. Phase 2 relaxes this to a permissioned set under `RANDOM_BACKUP` with no schema or commitment-format change.
- The executor **MUST** post a bond before activation. The bond **MUST** be slashable on a successful fraud proof (Phase 2) and **MUST** be sized to at least cover the **Core-ceiling value of `MaxBatchWithdrawal`** for the domain — not the current Periphery-configured value. An administrator raising `MaxBatchWithdrawal` toward the Core ceiling must not silently under-collateralize the executor; the bond is sized against the worst-case the administrator can configure within bounds, so that the constraint holds independently of any future Periphery change. Denomination/amount are pre-mainnet parameters (§25.2).
- Executor registration/replacement **MUST** be performed by the Settlement administrator (`RegisterExecutor`, §23), **MUST NOT** alter finalized state, and **MUST** require the replacement's first batch `preStateRoot` to equal the last accepted `postStateRoot` for that domain.

> The `executorId` field and the registration model accommodate a permissioned executor set in Phase 2 without changing the commitment format. Bonded registration mirrors `RegisterSentinelMethod` (`vm/embedded/implementation/sentinel.go`); revoke-locked-until-finalized mirrors the sentinel/stake revoke windows. No slashing logic exists in Phase 1 (all Phase 2); the only Phase-1-honest faults are process faults provable from Settlement storage alone (equivocation, double-submission). **Downtime enforcement in Phase 1 is an administrator action: the administrator may replace an unresponsive executor via `RegisterExecutor` after the applicable `AdministratorDelay`; withholding epoch emissions is a separate L1-governance lever and is outside Settlement's scope.** Both mechanisms are explicitly enumerated as Phase-1 downtime levers; a more automated mechanism is deferred to Phase 2.

---

## 23. Administration and emergency controls

> Zenon L1 has no on-chain multisig primitive in Phase 1, so a `k`-of-`n` authority cannot be expressed on-chain. Settlement therefore uses a **single administrator address**, exactly as the bridge contract (`bridgeInfo.Administrator`) and the spork-address-gated controls (dynamic plasma, liquidity) do today. **The stated goal is to move this control to the network's governance/spork contract or a multisig once one exists** — the administrator field is the migration hook (a future `ChangeAdministrator` repoints it with no Settlement change).

**Normative:**

- Settlement Periphery **MUST** be controlled by a **single Settlement administrator address** stored in contract state. Admin-gated methods **MUST** verify that the sending address equals the stored administrator (the bridge `sendBlock.Address == Administrator` pattern). The administrator controls Periphery only; Core is node-binary and unreachable by the administrator (§5.2).
- Administrator and Periphery-parameter changes **MUST** be time-challenged, reusing the bridge `SecurityInfo` / `TimeChallenge` machinery (`vm/embedded/implementation/common.go`, `bridge.go`): a `ChangeAdministrator` takes effect only after `AdministratorDelay` (≥ `MinAdministratorDelay = 2 × MomentumsPerEpoch`), and soft parameter changes after `SoftDelay` (≥ `MinSoftDelay = MomentumsPerEpoch`), so users can observe a pending change and exit before it activates.
- A set of nominated **guardians** (`SecurityInfo.Guardians`) **MUST** provide administrator recovery: if the administrator key is lost or compromised, guardians vote to install a new administrator under `AdministratorDelay`, exactly as in the bridge. This is the single-key analogue of multi-party control until the governance/multisig migration.
- Core **MUST** enforce immutable hard bounds on Periphery values, independent of the administrator: a minimum and maximum challenge window / withdrawal delay; a non-zero floor and a ceiling on `MaxBatchWithdrawal`; and a floor on the runtime-upgrade (`stfSpecHash`-bump) delay of `MinRuntimeUpgradeDelay ≥ WithdrawalDelay` (§6). Concrete bound values are pre-mainnet (§25.2); the existence and enforcement of bounds are normative — **even a compromised administrator cannot exceed them**, and in particular cannot configure a runtime-upgrade delay shorter than the active withdrawal delay.
- The administrator **MUST NOT**: alter finalized roots/receipts/balances; alter canonical input order or `globalInputIndex`; bypass the withdrawal delay; release bonded funds absent a successful fraud proof; or change SMT structure, key derivation, serialization formats, status-code semantics, or `ContractID` derivation (Core/protocol constants, changeable only by migration).

**Domain escape hatch (the one sanctioned exception to the above, normative):** when a domain is stalled or falls below `minExecutors`, the administrator **MAY** initiate forced withdrawals against the last finalized root (§6). This is the single custody-touching administrator action permitted in Phase 1. It **MUST** be subject to the same `AdministratorDelay` time-lock and guardian co-signature as any other administrator action of equivalent risk, **MUST** emit a public L1 event identifying the domain and the triggering condition, and **MUST NOT** alter any finalized root, receipt, or conservation counter. It is the migration hook for the Phase 2 on-chain escape-hatch mechanism; until then it is a last-resort governance action, not a routine operation.

**Emergency pause (normative):** an emergency pause **MUST** exist in Core, activatable by a **single emergency-pause authority address** — the Settlement administrator, or a separately configured single key for faster response — mirroring the bridge `Halt`/`Unhalt` pattern. It has two independently settable scopes, applicable globally or per domain: `PAUSE_SUBMIT` (halts `SubmitBatch`) and `PAUSE_RELAY` (halts `RelayMessage` incl. release). Activation **MUST** by default set `PAUSE_SUBMIT` only; withdrawals from already-`FINALIZED`, past-delay batches **MUST** remain releasable unless `PAUSE_RELAY` is separately and explicitly authorized for an active asset-safety exploit (emitting a distinct public L1 event, §27.10). Pause **MUST NOT** rewrite history or alter roots/receipts/balances/conservation counters/canonical order; activation and deactivation **MUST** emit a public L1 event.

> *Informative — bounding a single key in the interim.* Until an on-chain multisig or governance contract exists, the administrator's power is bounded by three things that do not depend on key custody: the **time-locks** (`AdministratorDelay`/`SoftDelay`) that give users an exit window before any change, **guardian recovery** for a lost/compromised key, and the **Core hard bounds** that no administrator value can exceed. Migration is a one-line repoint of the administrator (and pause authority) at the governance/multisig address via the same time-challenged flow, with no change to Settlement Core.

---

## 24. Versioning

**Normative:** the following components **MUST** carry explicit `u16` version fields, each first in its canonical encoding: `protocol_version` (batch commitments), `runtime_profile_version`, `metering_version` (Phase 1 = `1`, bound to `wasm-gas-table-v1.json`), `serialization_version`, `statediff_version`, `executionresult_version`, `receipt_version`, `outbox_version`, `damode_version`. `proofData` (§19) is reserved/version-gated for Phase 3 and **MUST** be empty in Phase 1.

Settlement **MUST** reject batch commitments whose `protocol_version` it does not recognize; clients and the executor **MUST NOT** silently interpret an unknown-version structure (unknown == reject). A version increment that changes any on-chain-committed format or circuit-relevant constant (the opcode gas table, the SMT hash function) **MUST** be accompanied by a migration specification; the Phase 3 SMT hash migration (§13.2) is the principal anticipated migration and **MUST** be a one-time versioned state migration.

---

## 25. Constants

### 25.1 Fixed protocol constants

These are fixed for Phase 1 (changing any requires a major protocol version increment and is a breaking change to the Phase 3 circuit). They live in `vm/constants/` and are enforced by Core as hard bounds where applicable.

| Constant | Value |
|---|---|
| `MaxDataLength` (L1 account-block data) | 16 KiB (`1024 * 16`) — already `vm/constants/plasma.go` |
| `MaxOnChainCommitmentSize` | 16 KiB |
| `MaxCallPayload` | 8 KiB |
| `MaxReturnData` | 4 KiB |
| `MaxExecutionResult` | 32 KiB |
| `MaxBatchInputs` | 64 |
| `MaxDAChunkSize` | 16 KiB |
| `MaxWasmSize` (pre-instrumentation) | 256 KiB |
| `MaxChunkCount` | 16 |
| `DeploymentExpiryWindow` | 2,880 momentum heights |
| `MaxMemory` | 4 MiB (64 WASM pages) |
| `MaxStackDepth` | 512 frames |
| Post-instrumentation size ceiling | 1 MiB |
| `MaxStateKeySize` | 32 bytes |
| `MaxStateValueSize` | 16 KiB |
| `MaxEventsPerExecution` | 64 |
| `MaxEventDataSize` | 1 KiB |
| `MaxTopicsPerEvent` | 4 |
| `MaxOutboxPerExecution` | 32 |
| `MaxOutboxPayloadSize` | 8 KiB |
| `MaxAssetsPerBatch` | 16 |
| `MaxWithdrawalsPerRelay` | 16 |
| `MinRuntimeUpgradeDelay` (Core hard floor on the `stfSpecHash`-bump delay, §6, §23) | `≥ WithdrawalDelay` — relative to the active withdrawal delay, not a fixed integer; Core **MUST** reject any configured runtime-upgrade delay below the active `WithdrawalDelay` |

### 25.2 Pre-mainnet parameters

Not fixed by this spec; **MUST** be set before mainnet, bounded by Core hard bounds (§23) where noted.

| Parameter | Notes |
|---|---|
| Challenge window / withdrawal-delay duration | In momentum heights; within hard bounds. Natural floor reference: `MomentumsPerEpoch` (`vm/constants/embedded.go`, `MinSoftDelay`). |
| Executor bond amount + denomination | At least `MaxBatchWithdrawal`, per domain. |
| `MaxBatchWithdrawal` | Within Core floor/ceiling, per (domain, asset). |
| Per-domain `valueCaps` | Per-window outbox caps; bond-sizing input. **Window length and reset semantics MUST be specified before mainnet:** the window is a rolling count of momentum heights; the cap resets at the start of each window; partial windows at domain activation count from the first accepted batch. Core MUST enforce a minimum window floor ≥ `WithdrawalDelay` so the cap cannot be trivially bypassed by spreading withdrawals across micro-windows. |
| Settlement administrator address (+ guardian set) | Single key, bridge-style; `AdministratorDelay`/`SoftDelay` ≥ Core minimums (§23). Migrates to a governance/multisig address later. |
| Emergency-pause authority address | The administrator, or a separate single key for faster response (§23). |
| Runtime-upgrade (`stfSpecHash`) delay length | Mandatory user-exit window. |

---

## 26. Security properties

**Normative:**

- **Sequencing integrity.** The executor **MUST NOT** reorder, skip, or privately insert inputs; canonical order is fixed by L1 (§4.4); omission yields a non-contiguous batch rejected on-chain (§4.6); a `CallL2` in a confirmed momentum is force-included (§4.2).
- **MEV.** Executor-level sandwiching/reordering is structurally prevented (no ordering discretion; non-canonical batches rejected). *Informative:* L1 inclusion-timing, application-level, oracle-timing, and cross-domain arbitrage MEV are out of scope (L1- or application-layer concerns).
- **Replay.** L1-originated inputs are non-replayable (tied to a unique confirmed account-block and `chain_id`, §27.5); outbox messages are non-replayable via unique `outboxId` + `processedOutbox` (§17.3).
- **Determinism.** Execution **MUST** be deterministic per §7 and §13; any implementation producing a different `postStateRoot` for the same input and witnessed pre-state is non-conformant.
- **DA / trust limits.** Phase 1 is commitment-only DA and bonded-attestation safety; aggregate over-withdrawal is prevented on-chain (§18.3), per-account correctness relies on executor honesty until Phase 2. These limits **MUST** be disclosed and **MUST NOT** be overstated.

---

## 27. Wire formats and tightened semantics

This section is fully normative. Where it and an earlier section overlap, this section governs the exact encoding; the earlier section governs intent.

### 27.0 Common primitives

`u8`/`u16`/`u32`/`u64`/`u256`: fixed-width big-endian unsigned, of exactly 1/2/4/8/32 bytes respectively. A `u256` is always exactly 32 bytes; it is **not** range-checked at the codec layer (a value larger than, e.g., total supply is a well-formed `u256` — domain range checks such as conservation are the responsibility of §18.3, not the decoder, which **MUST NOT** add codec-level range rejections beyond fixed width). `bytes32`/`Hash`/`ContractID`/`AssetID`/`CodeHash`: fixed 32-byte. `Address`: fixed 20-byte (only in `caller` preimages and withdrawal recipients; never substituted for a 32-byte field). `Bytes`: `u32` length `L` + `L` raw bytes. `List<T>`: `u32` count `N` + `N` encodings, no separators. Every structure has exactly one valid encoding; a decoder **MUST** reject trailing bytes, inconsistent length/count prefixes, or out-of-order fields.

### 27.1 Entry-point ABI

**Normative:**

- A module **MUST** export linear memory as `memory` and exactly one entry `run` with signature `(i32, i32) -> i64`.
- Before invoking `run`, the runtime **MUST** write a contiguous **input frame** at offset 0 and call `run(0, frame_len)`; all memory above `frame_len` is zero. The frame is the canonical encoding of:

  ```
  ExecutionInputFrame :=
      context_version : u16          // = runtime_profile_version
      chain_id        : bytes32
      caller          : bytes32
      contract_id     : bytes32
      code_hash       : bytes32      // post-instrumentation CodeHash
      momentum_height : u64
      momentum_time   : u64          // TimestampUnix
      input_index     : u64          // globalInputIndex
      deposit_asset   : AssetID      // attached deposit asset (payable CallL2 / Deposit); zero32 when none
      deposit_amount  : u256         // attached deposit amount; 0 when none
      payload         : Bytes        // input-type-specific (§27.5)
  ```

- `run` **MUST** return `i64 r`: if `r ≥ 0`, `result_ptr = (r >> 32) & 0xFFFFFFFF`, `result_len = r & 0xFFFFFFFF`; the runtime reads exactly `result_len` bytes at `result_ptr` as the `ContractEffects` blob (§14.2, grammar §27.1a), then assembles the `ExecutionResult`. `result_ptr + result_len` **MUST** be in-bounds, else `RUNTIME_FAULT`. If `r < 0`, treat as `abort` with code `(-r)` truncated to `i32`, status `REVERT`, full rollback. A trap during `run` **MUST** canonicalize to `RUNTIME_FAULT` regardless of any partial result region. The runtime **MUST NOT** call any function other than `run`; a module without `memory` and a conforming `run` **MUST** be rejected at deployment validation.

### 27.1a ContractEffects and ExecutionResult wire formats

**Normative.** The blob returned by `run` is exactly the following, in this field order, using §27.0 primitives:

```
ContractEffects :=
    executionresult_version : u16
    globalInputIndex        : u64
    StateDiff               : List<StateDiffEntry-local>   // §27.2 local-key form
    Events                  : List<Event>                  // §27.3
    OutboxMessages          : List<OutboxMessage>          // §27.4
    ReturnData              : Bytes
    claimed_deposit         : u256                         // ALWAYS present; 0 when deposit_amount == 0
```

- `claimed_deposit` is a fixed 32-byte field and **MUST** always be encoded, including the value `0`. A blob that omits it (i.e. ends after `ReturnData`) **MUST** cause `RUNTIME_FAULT`.
- The runtime **MUST** cause `RUNTIME_FAULT` if `claimed_deposit > deposit_amount`, or if `claimed_deposit > 0` when `deposit_amount == 0` (§18.5).
- The blob **MUST NOT** contain `preStateRoot` or `postStateRoot`; presence of either field (i.e. any decoding that yields a 9-field structure with roots after `globalInputIndex`) **MUST** cause `RUNTIME_FAULT` (§14.2).
- A decoder **MUST** reject trailing bytes after `claimed_deposit`, any length/count-prefix inconsistency, out-of-order fields, or a non-canonical `StateDiff`/`Events`/`OutboxMessages` list order.

The runtime assembles the canonical **`ExecutionResult`** from a successful `ContractEffects` blob by (a) inserting `preStateRoot`,`postStateRoot` immediately after `globalInputIndex`, and (b) re-encoding `StateDiff` from local-key form into the derived-key `StateDiffEntry` form (§27.2), sorted ascending by derived key:

```
ExecutionResult :=
    executionresult_version : u16
    globalInputIndex        : u64
    preStateRoot            : bytes32
    postStateRoot           : bytes32
    StateDiff               : List<StateDiffEntry>         // §27.2 derived-key form, sorted
    Events                  : List<Event>                  // §27.3
    OutboxMessages          : List<OutboxMessage>          // §27.4, incl. runtime-emitted refund (§18.5)
    ReturnData              : Bytes
    claimed_deposit         : u256
```

`ExecutionResult` has exactly one valid encoding; a decoder **MUST** reject trailing bytes or any deviation from this field order. The total serialized `ExecutionResult` **MUST NOT** exceed `MaxExecutionResult` (§14.3, §25).

### 27.2 StateDiff and the EMPTY deletion sentinel

**Normative (key encoding differs between the two blobs):**

- In a **`ContractEffects`** blob, each `StateDiff` key is a length-prefixed `local_key` (`u32 L ≤ MaxStateKeySize` + `L` bytes); entries need not be sorted (canonical order is over derived keys). The runtime derives `SHA3-256(contract_id || local_key)` and **MUST** reject a blob that, after derivation, has duplicate derived keys.
- In the canonical **`ExecutionResult`**, each `StateDiff` entry is:

  ```
  StateDiffEntry := key : bytes32 (derived SMT key) ; new_value : Bytes
  ```

  Entries **MUST** be sorted ascending by derived key with no duplicates; a decoder **MUST** reject duplicates or non-ascending order.
- **Deletion sentinel:** deletion is `new_value` with length prefix `L = 0xFFFFFFFF` followed by zero bytes (`EMPTY`); it removes `key` (a subsequent non-inclusion proof). A present empty value is `L = 0x00000000` (inclusion of the empty value). A present value **MUST NOT** have length `0xFFFFFFFF`; lengths in `[MaxStateValueSize+1, 0xFFFFFFFE]` **MUST** be rejected. Deleting a non-existent key is a well-formed no-op leaving the root unchanged.

### 27.3 Event encoding and Merkle construction

```
Event := contract_id : bytes32 ; input_index : u64 ; event_index : u32 ;
         topics : List<bytes32> (≤ MaxTopicsPerEvent) ; data : Bytes (≤ MaxEventDataSize)
```

Within an input, events appear in ascending `event_index` from 0 with no gaps, ≤ `MaxEventsPerExecution`. **Merkle construction (all roots in §27):** leaf hash `SHA3-256(0x00 || encoded_element)`, node hash `SHA3-256(0x01 || left || right)`; for an odd node count at a level, the last node is promoted unchanged (no duplication); the empty set has root `bytes32(0)`. (Distinct from the SMT, §13.) The batch `eventRoot` is over all batch events ordered by `(input_index, event_index)`.

### 27.4 OutboxMessage encoding

```
OutboxMessage := source_contract : bytes32 ; input_index : u64 ; outbox_index : u32 ;
    kind : u8 (0=L2_DELIVERY, 1=L1_WITHDRAWAL) ;
    // kind==0: target_contract : bytes32
    // kind==1: recipient_l1 : Address(20) ; asset_id : AssetID ; amount : u256
    payload : Bytes (≤ MaxOutboxPayloadSize)
```

`kind` **MUST** be 0 or 1 (else `RUNTIME_FAULT`); branch fields **MUST** match `kind` exactly. For `kind == 1` (L1 withdrawal), `payload` **MUST** be the zero-length `Bytes` encoding; a non-empty payload on a withdrawal **MUST** cause `RUNTIME_FAULT` (the withdrawal's effect is fully determined by `recipient_l1`/`asset_id`/`amount`, and `outboxId` does not commit to `payload`, so a non-empty withdrawal payload is unverifiable surface). Within an input, ascending `outbox_index` from 0, no gaps, ≤ `MaxOutboxPerExecution`. `outboxId = SHA3-256(domainId || batchId(u64) || input_index(u64) || outbox_index(u32))`; `domainId` and `batchId` are bound at batch construction by the runtime. Roots use the §27.3 construction, batch root ordered by `(input_index, outbox_index)`.

A **runtime-emitted deposit refund** (§18.5) is an `L1_WITHDRAWAL` message with `source_contract = bytes32(0)` (no contract source; the runtime is the emitter) and an empty `payload`. Its `outbox_index` **MUST** equal the number of retained contract outbox messages for the input — which is `0` on any non-`SUCCESS` (where contract messages are discarded), and equal to the count of contract-emitted messages on `SUCCESS`. It occupies the next `outbox_index` after any contract-emitted messages on success, or `outbox_index = 0` on a failed input. It is otherwise an ordinary outbox message for `outboxRoot`, relay, and replay purposes.

### 27.5 CallL2 / Deposit payload and input identity

```
CallL2Args  := target_contract : bytes32 ; plasma_limit : u64 ; payload : Bytes (≤ MaxCallPayload)
DepositArgs := target_contract : bytes32 ; plasma_limit : u64    // no application payload
```

(The `domainId` envelope is carried by the Settlement method call, §4.1.) Neither input carries an application-level nonce; replay protection is L1 account-block uniqueness + `chain_id` binding. The runtime routes execution to `target_contract`; `plasma_limit` is consumed by L2 gas accounting and is **NOT** placed in the contract-visible frame. For `CallL2` the frame `payload` is `CallL2Args.payload`; for `Deposit` the frame `payload` is empty. Any attached ZTS value on the account-block is a deposit delivered to `target_contract` (§18.5): the runtime sets the frame `deposit_asset`/`deposit_amount` from the on-chain send (`zero32`/`0` when none); the `Args` carry no value field. `caller` is derived per §9.2. `inputHash` (receipt) **MUST** be `SHA3-256(input_kind:u8 || source_account_block_hash:bytes32 || …kind-specific…)`, binding the receipt to the exact L1 account-block; the kind-specific tail is `target_contract:bytes32 || plasma_limit:u64 || deposit_asset:AssetID || deposit_amount:u256 || payload:Bytes` for `CallL2`, and `target_contract:bytes32 || plasma_limit:u64 || deposit_asset:AssetID || deposit_amount:u256` for `Deposit`.

**Canonical input encoding and `inputRoot` (normative).** The `inputRoot` (§19) leaf for an input is its **canonical input encoding**: `input_kind:u8 || source_account_block_hash:bytes32 || <kind-specific tail>`, byte-identical to the `inputHash` preimage above, defined for **all six** input types (not only `CallL2`/`Deposit`):

- `CallL2` (`input_kind = 0`): tail `target_contract:bytes32 || plasma_limit:u64 || deposit_asset:AssetID || deposit_amount:u256 || payload:Bytes`.
- `Deposit` (`input_kind = 1`): tail `target_contract:bytes32 || plasma_limit:u64 || deposit_asset:AssetID || deposit_amount:u256`.
- `DeployContractStart` (`input_kind = 2`): tail `code_hash:bytes32 || metadata_hash:bytes32 || total_size:u64 || chunk_count:u32` (§11.1 args in declared order).
- `DeployContractChunk` (`input_kind = 3`): tail `code_hash:bytes32 || chunk_index:u32 || chunk_hash:bytes32` (the `chunk_data` is committed by `chunk_hash`, not inlined).
- `DeployContractFinalize` (`input_kind = 4`): tail `code_hash:bytes32`.
- `UpgradeContract` (`input_kind = 5`): tail `contract_id:bytes32 || new_code_hash:bytes32` (§12), where `new_code_hash` is the pre-instrumentation `code_hash` of the replacement bytecode.

The `input_kind` ordinals are fixed and **MUST NOT** be reused. `inputRoot` is the §27.3 Merkle root over these canonical input encodings ordered by `globalInputIndex`. The same encoding is the `inputData` field of the DA bundle record (§20).

### 27.6 AssetFlowSummary encoding

```
AssetFlowSummary := List<AssetFlowEntry> (≤ MaxAssetsPerBatch)
AssetFlowEntry := asset_id : AssetID ; deposit_credit : u256 ; withdrawal_debit : u256
```

Sorted by `asset_id` ascending, no duplicates; **MUST** include every asset touched by a deposit or withdrawal and **MUST NOT** include an asset with both fields zero. Exceeding `MaxAssetsPerBatch` means the executor **MUST** split activity across batches.

### 27.7 Receipt encoding

```
Receipt := receipt_version : u16 ; input_index : u64 ; input_hash : bytes32 ; batch_id : u64 ;
    contract_id : bytes32 (or 0) ; code_hash : bytes32 (or 0) ; status : u8 ; gas_used : u64 ;
    state_diff_hash : bytes32 (or 0) ; return_hash : bytes32 (or 0) ;
    event_root : bytes32 (or 0) ; event_count : u32 ; outbox_root : bytes32 (or 0) ; outbox_count : u32
```

Status ordinals fixed (§15); the batch `receiptRoot` uses the §27.3 construction over receipts ordered by `input_index`.

### 27.8 storage_len: absent vs empty

**Normative:** over derived SMT keys (§13.3), the runtime **MUST** expose: absent → `storage_len = -1`, `storage_read = -1` (writes nothing); present-empty → `0` / `0` (writes zero bytes); present length `L>0` → `L` / `L` if buffer ≥ L else `-2`. A key deleted via `EMPTY` is absent (`-1`). Every observed key (incl. absent) **MUST** be witnessed (§20).

### 27.9 Withdrawal fan-out per batch

**Normative:** a single `RelayMessage` **MUST** release at most one withdrawal (one descendant send); `MaxWithdrawalsPerRelay = 16` bounds any batched-relay convenience method, which **MUST** reject requests exceeding it. Independently, a single batch **MUST NOT** register withdrawals whose aggregate per (domain, asset) exceeds `MaxBatchWithdrawal`. Both bounds **MUST** hold: the first bounds descendant-block fan-out per L1 action; the second bounds value at risk per batch.

**Runtime-emitted deposit refunds (§18.5) are excluded from the `MaxBatchWithdrawal` aggregate.** The cap exists to bound fraud loss from contract-emitted withdrawals; a deposit refund returns value that entered custody in the same batch and therefore cannot increase at-risk value. Conservation (§18.3) still bounds all refund withdrawals. Without this exemption, an attacker can spray cheap failing deposits to push a domain's per-batch refund total over the cap and stall batch production indefinitely — blocking return of already-custodied funds.

### 27.10 RelayMessage under pause

**Normative:** `PAUSE_SUBMIT` halts `SubmitBatch`; `PAUSE_RELAY` halts `RelayMessage` incl. release. Activation **MUST** by default set `PAUSE_SUBMIT` only. A `RelayMessage` for a withdrawal from an already-`FINALIZED` batch **MUST** remain processable while only `PAUSE_SUBMIT` is active — halting submission **MUST NOT** freeze withdrawals already past the delay. `PAUSE_RELAY` **MUST** be a separately authorized escalation for an active asset-safety exploit, emitting a distinct public L1 event. Neither scope **MUST** ever rewrite history or alter roots/receipts/balances/conservation counters/canonical order. On `PAUSE_RELAY` deactivation, previously eligible withdrawals **MUST** again be releasable with unchanged release-eligible heights.

---

## 28. Codebase foundations

Phase 1 reuses shipped, consensus-tested go-zenon patterns. Symbols (not line numbers) are cited so the references survive refactors.

- **Embedded-contract extension by spork layering** — `getOrigin()` + `applyXDiffs` gated by `context.IsXSporkEnforced()` in `vm/embedded/embedded.go` (`GetEmbeddedMethod`); the `Method` interface `GetPlasma`/`ValidateSendBlock`/`ReceiveBlock`. Precedent: `applyHtlcDiffs` / `IsHtlcSporkEnforced`.
- **Spork release flow** — placeholder hash → `CreateSpork` → real id → `ActivateSpork` → enforcement, with test/devnet override of `ImplementedSporksMap` (`common/types/spork.go`; precedents `HtlcSpork`, `DynamicPlasmaSpork`, `StateRootSpork`). `OffchainExecutionSpork` is added here as a contract-activation spork (no momentum-version bump).
- **Embedded addresses** — a new `z1qxemdeddedx…` value via `parseEmbedded`, listed in `EmbeddedContracts` (`common/types/address.go`).
- **Automatic anchoring** — embedded state writes fold into `ChangesHash` (`block.ChangesHash = db.PatchHash(changes)`, `vm/supervisor.go`) → momentum hash (`chain/nom/momentum.go`) → pillar signature → re-verified by every node, no format change.
- **Deterministic input ordering, auto-receive, descendant sends, unlimited embedded plasma** — `vm/vm.go`, `chain/momentum/ledger_store.go`, `pillar/worker_contract_generator.go`.
- **Canonical ordering source** — `AccountHeader.Bytes() = Address ‖ Height ‖ Hash` (`common/types/account_header.go`); `MomentumContent` sorts by `bytes.Compare(a.Bytes(), b.Bytes())` (`chain/nom/momentum_content.go`).
- **Bonded registration + time-windows** — `RegisterSentinelMethod` and the `TimeChallenge` / `SecurityInfo` family (`vm/embedded/implementation/sentinel.go`, `common.go`) as templates for the executor bond and withdrawal delay.
- **Shared SMT core (consensus-frozen hashing/routing/proof bytes)** — `common/trie/hash.go` (`LeafHash`, `InternalHash`, constant-zero `emptyHash`, MSB-first `pathBit`), `compute.go` (full-depth root computation), and `proof.go` (`encodeProof`/`decodeProof`/`reconstructRoot`). The L2 executor uses the path-native API — `RootOfLeaves`, `ProveByPath`, `VerifyProofByPath`, `VerifyAbsenceByPath` (§13.1) — for all root computation, proof generation, and verification. The key-hashing verifiers `VerifyProof(root, key, …)`/`VerifyAbsence(root, key, …)` and the maintenance adapters `tree.go` (`Tree.Update`/`Commit`/`Prove`) and `nodestore.go` (`NodeTree`) are **L1-only** and **MUST NOT** be reused by L2 (§13.1). Conformance-gated by `conformance_test.go` against `smt-v1-test-vectors.json`.
- **Constants** — `vm/constants/plasma.go` (`MaxDataLength`), `vm/constants/embedded.go` (`MomentumsPerEpoch`, `MinSoftDelay`, `MinAdministratorDelay`, emission split). New Settlement constants are added in `vm/constants/`.

---

## 29. Build sequencing

- **1A — Off-chain executor + conformance (no chain changes).** Runtime + deterministic profile (§7), validation + instrumentation pipelines (§11), three-import host ABI (§8), the shared SMT core (§13) consumed **only** through the path-native API (§13.1) with the L2-specific application semantics (§13.5–§13.6) and the canonical applier (§13.5.1), canonical ordering off `MomentumContent` (§4.4), the canonical serializer (§14, §27, §27.1a); gated by the SMT (§13.7, incl. the path-native and applier vectors) and execution (`execution-conformance-v1.json`) vector suites. *Retires the deterministic-instrumentation risk first.*
- **1B — Spork-gated Settlement contract.** All §5.3 methods (domain-agnostic core + WASM handler), domain registry + lifecycle (§6), chunked deployment (§11), per-(domain, asset) custody + conservation (§18), delay + bounded descendant sends (§21, §27.9), Core/Periphery (§5.2), pause (§23). Ship dark; testnet.
- **1C — Executor wiring + best-effort DA, testnet → mainnet activation.** `RegisterDomain` (WASM), register the bonded executor, wire `SubmitBatch`, stand up Sentinel/libp2p bundle + chunk serving by `DAHash` and a browser gateway (§20), activate the spork.

---

## 30. Open / deferred items

**Pre-mainnet parameters** (§25.2): withdrawal-delay duration, executor bond amount/denomination, `MaxBatchWithdrawal`, per-domain `valueCaps`, Settlement administrator address + guardian set, emergency-pause authority address, runtime-upgrade delay length.

**To finalize in implementation docs:** the `{domainId, payload}` envelope encoding; the Settlement storage key layout (domain registry + per-(domain, asset) counters); per-domain deploy policy / code caps; domain-failure escape-hatch mechanics; the canonical first-party **system vault contract** (bare custody / park-and-withdraw, §18.1a).

**Optional future extension (not Phase 1):** deposit stranding is prevented by explicit `claimed_deposit` + automatic refund of the unclaimed remainder (§18.5). A heavier alternative — a persistent per-(account, asset) *landing-zone balance* that accrues unclaimed deposits for the depositor to reclaim at will (rather than auto-refunding each input) — would additionally let users batch and time their reclaims, at the cost of a protocol balance sub-ledger and a `WithdrawDeposit` method. Recorded only so the choice is explicit; not needed for Phase 1 safety.

**Explicitly Phase 2+ (not in Phase 1):** on-chain root verification, fraud proofs, slashing, DA enforcement, the multi-executor set, watcher economics, inter-batch outbox ordering, and per-runtime fraud-proof adapters. **Phase 3:** validity proofs, proving-system selection, and the ZK-friendly SMT hash migration. See `../phase-2/SPEC.md`, `../phase-3/SPEC.md`.

---

## 31. Conformance vectors

An implementation is conformant when it reproduces the companion vector suites byte-for-byte. These are normative companion artifacts (§13.7 and the Conventions intro).

**SMT / trie (`smt-v1-test-vectors.json`, `proof-format.md`):**

- SMT-001…SMT-014 reproduce roots and proof bytes byte-for-byte.
- **CV-PATH-1** — `VerifyProofByPath`/`VerifyAbsenceByPath` accept the vector key supplied as a path (no key hashing); the key-hashing `VerifyProof(root, path-as-key, …)` rejects it.
- **CV-PATH-2** — `RootOfLeaves(paths, values)` reproduces every SMT `expected_root`.
- **CV-APPLY-1** — applier vector with one present-empty write (`0x00000000`) and one `EMPTY` delete (`0xFFFFFFFF`), with expected post-root and present-empty ≠ absent.
- **CV-APPLY-2** — incremental == full recompute across N diffs (§13.5.1, applier-layer mirror of SMT-014).

**Execution / deposit (`execution-conformance-v1.json`):**

- **EXEC-DEP-1** — payable `CallL2`, partial claim (deposit 100, claim 40): 60 refund at the correct `outbox_index`; `depositCredit = 100`, `withdrawalDebit ≥ 60` (§18.4 identity).
- **EXEC-DEP-2** — `claimed_deposit` omitted from the blob ⇒ `RUNTIME_FAULT` (§27.1a).
- **EXEC-DEP-3** — `Deposit` to an undeployed `ContractID` ⇒ `VALIDATION_FAILED`, full refund, receipt `outboxCount = 1` (§18.2).
- **EXEC-FAIL-OUTBOX-1** — failed input with a deposit: receipt `outboxCount = 1`, `outboxRoot` over the single refund, `outbox_index = 0` (§15, §27.4).

**Serialization / commitment / bundle:**

- **CV-BUNDLE-1** — two-input bundle, one absent read, fixed `DAHash` (§20).
- **CV-ASSET-1/2** — ZTS↔`AssetID` round-trip; reject a non-zero high byte / non-canonical alignment (§18.1).
- **CV-COMMIT-1/2** — batch commitment round-trip with empty `proofData`; reject non-empty `proofData` (§19).
- **CV-INPUTROOT-1** — mixed-kind batch (`CallL2` + `Deposit` + `Deploy*` + `Upgrade`) `inputRoot` (§27.5).
- **CV-OUTBOX-1** — withdrawal with a non-empty payload ⇒ `RUNTIME_FAULT` (§27.4).
- **CV-DEPLOY-1** — single-chunk deploy (`chunk_count == 1`) sizing (§11.2).

---

## 32. Implementation and deployment tasks

Forward-looking work that is code, parameters, or companion artifacts rather than normative spec text:

- **Pre-mainnet parameters (§25.2):** withdrawal-delay duration, executor bond amount/denomination, `MaxBatchWithdrawal` (and its Core ceiling), per-domain `valueCaps` (window length + reset), administrator + guardian set, emergency-pause authority, runtime-upgrade delay length — all set before mainnet within the Core hard bounds of §23.
- **Companion artifacts:** `proof-format.md`, `wasm-gas-table-v1.json`/`.md` (`metering_version = 1`), and `execution-conformance-v1.json` (the §31 vectors).
- **Settlement storage key layout (§5.4):** domain registry, per-(domain, asset) counters, processed-outbox set, deploy records.
- **`{domainId, payload}` envelope encoding** for the on-chain method-call surface (§4.1).
- **System vault contract (§18.1a):** the canonical first-party bare-custody / park-and-withdraw contract.
- **Domain-failure escape-hatch mechanics (§6, §23):** the forced-withdrawal-against-last-finalized-root administrator action within the §23 carve-out.
- **Best-effort DA serving (§20, §29-1C):** Sentinel/libp2p bundle + chunk serving by `DAHash` and the browser gateway.
