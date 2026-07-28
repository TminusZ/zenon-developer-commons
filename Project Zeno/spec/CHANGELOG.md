# Phase 1 — Changelog

Revision history for the Phase 1 document set (`SPEC.md`, `ARCHITECTURE.md`, `EXECUTOR.md`, companion artifacts). The documents themselves are forward-reading; all history lives here.

---

## SPEC v1.6.0 / EXECUTOR v0.3.0 / ARCHITECTURE — 2026-07-26

Absorbs the generalized **Bridge Framework** into the normative documents as first-class schema, with Phase 1 reframed as the single **active** point of a general model and every other configuration reserved/gated. No Phase-1 behaviour changes — the WASM `EXECUTION` domain at `(ATTESTATION, NONE, ESCROW, SINGLE)` is byte-for-byte unaffected. The framework's reference material (worked examples, comparative mappings, testing/formal-verification/deployment strategy) remains the companion `research/bridges/BRIDGE-FRAMEWORK-SPEC.md`, whose core-model sections are now normative here.

### 1. Trust model generalized (§1)

Two **independent** per-domain trust dimensions: an **execution profile** (`ATTESTATION → OPTIMISTIC → ZK_VALIDITY`) and a **foreign-fact profile** (`NONE → COMMITTEE → LIGHT_CLIENT → ZK_CONSENSUS`). A domain is exactly as trustless as the weaker of the two. Three permanent Rails restated (STF-verifiable ≠ Settlement-verified; a foreign fact commits what was observed, not what is true; commitment ≠ availability). Guarantee table generalized to `ESCROW` (honesty-independent) vs `MINTED` (profile-dependent). Phase-1 active point pinned normative.

### 2. Domain model generalized (§6, §6.3–§6.6)

`DomainRecord` gains `domainClass` (`EXECUTION | BRIDGE | MESSAGING`), `execProfile`, `foreignProfile`, `profileConfig`, `chainBinding`, `finalityModel` — all folded into `stfSpecHash`, all constrained to Phase-1 defaults until a spork-gated Core release. New normative subsections: the two profile ladders (§6.3, §6.4), legal-combination + custody-mode constraints (§6.5), and the bridge abstractions `ChainVerifier` / `SourceAdapter` / `BridgeLedger` / `ReleaseAdapter` + the `kind=1` peg-out authorization (§6.6). The executor's four-method plugin interface is unchanged (`EXECUTOR.md` §7).

### 3. Messaging and asset model generalized (§17, §18)

- §17.2: `kind=1` is the single authorization object for *every* withdrawal — Zenon-native (consumed by `Update`) and bridge peg-out (consumed by a foreign `ReleaseAdapter`) are the same object with different consumers. `MESSAGING` emits `kind=0` only. §17.4: reserved timeout/ack/refund messaging. §27.4: reserved foreign-recipient `kind=1` sub-variant (version-gated).
- §18.1: custody modes `ESCROW` (Phase 1) / `MINTED` (reserved). §18.3: `MINTED` conservation predicates added alongside `ESCROW`, with the **OD-1** reconciliation resolution — economic floor (`MaxBatchMint`, §25.2) + `OPTIMISTIC` execution floor, optionally Core-direct enforcement under `COMMITTEE`/`ZK_CONSENSUS`. `MINTED` aggregate solvency is only as strong as the layer that makes the foreign backing fact checkable to Core.

### 4. Storage, versioning, bonds, open items

- §5.4: reserved `AssetRegistry` (+ `MINTED` counters), `MessageState`, and Periphery verifier registries. §5.3: `RegisterDomain` row lists the new fields.
- §22: bond sizing covers `MaxBatchMint` for `MINTED` domains. §24: `proofData` contents are profile-dependent; semantics-defining domain fields folded into `stfSpecHash`; `ATTESTATION`-quorum `proofData` needs a `protocol_version` bump.
- §30: bridge framework recorded as schema-present/activation-reserved; **OD-1 (`MINTED` reconciliation)** flagged as the single gating open-design blocker before any asset bridge deploys.

### 5. ARCHITECTURE + EXECUTOR companions

`ARCHITECTURE.md` §6–§8 generalized (domain classes, two-ladder trust, bridge forward-compat) + new §4.4 peg-in/peg-out flow. `EXECUTOR.md` §7 adds the `BridgeLedger`/`ChainVerifier`/`SourceAdapter`/`ReleaseAdapter` delegation with the plugin interface unchanged; upstream pin → SPEC v1.6.0.

### Activation gating (unchanged safety posture)

Every generalized capability ships reserved: Core **MUST** reject any non-Phase-1 value until the enabling spork-gated release lands. Activation prerequisites: fraud-proof referee registry (`OPTIMISTIC`), validity/consensus verifier registries (`ZK_VALIDITY`/`ZK_CONSENSUS`), `MINTED` issuance + OD-1 resolution, and the per-chain `ChainVerifier`/`SourceAdapter`/`ReleaseAdapter` (last off-Zenon). Recommended sequencing: schema + `MESSAGING` first (no custody, no OD-1), then `OPTIMISTIC` fraud proofs, then trust-minimized `MINTED` bridges.

---

## SPEC v1.5.0 / EXECUTOR v0.2.2 — 2026-07-06

Closes the two spec-rooted plan gaps surfaced by the epic review.

### 1. Deployment verification assignment (§11.2, §11.3, §12)

§11.3 defined the Finalize checks without assigning them on-chain vs off-chain — infeasible as an on-chain obligation, since Settlement commits only chunk hashes to state and cannot recompute `sha3(assembled)`. Now explicit:

- **Settlement (on-chain):** per-chunk `chunk_hash == sha3(chunk_data)` at each chunk receive (bytes in hand — its only byte-level code verification); at `Finalize`/`UpgradeContract`, record-existence, deployer, all-chunks-present, and record consumption. No assembly, validation, instrumentation, or bytecode storage.
- **Runtime/STF (off-chain, deterministic):** assembly, `sha3(assembled) == code_hash`, `len == total_size`, Core 1.0 validation + prohibited-feature rejection, instrumentation, `CodeHash`/`ContractID` derivation. A mismatch is a `VALIDATION_FAILED` receipt (no contract / no code change) — reproducible by any watcher from L1-anchored data, fraud-provable in Phase 2.
- §12 upgrade finalizer updated to the same split (Core: bookkeeping + consumption; STF: pipeline).

### 2. Executor bond mechanics (§5.3, §5.4, §19, §22, §25.2, §28)

The bond flow was unspecified (no posting vehicle, no return path, no methods). Now defined as the **sentinel two-leg flow**: `DepositQsr` accumulates the QSR leg (reclaimable via `WithdrawQsr` while unconsumed); `PostBond(domainId)` carries exactly the ZNN leg and consumes the required QSR deposit; accepted only from the registered executor address after admin `RegisterExecutor`. The executor is **ACTIVE** (eligible to `SubmitBatch`, enforced in §19) only while registered + fully bonded. `RevokeBond` returns both legs once the address is no longer the registered executor and all its batches are `FINALIZED`. New §5.3 methods: `DepositQsr`/`WithdrawQsr`/`PostBond`/`RevokeBond`; new §5.4 storage: per-address QSR bond-deposit balances. Precedent: `DepositQsrMethod`/`WithdrawQsrMethod`/`checkAndConsumeQsr` (`vm/embedded/implementation/common.go`), exact-amount ZNN leg per `RegisterSentinelMethod` (`sentinel.go`); amounts are pre-mainnet parameters (§25.2).

### Companion sync

`EXECUTOR.md` → v0.2.2 (upstream pin, §5.5 prerequisite adds the bond methods). Epic tickets synced in the same pass (see below).

### Epic plan changes (applied with this revision)

- Tickets **10 ↔ 11 swapped** (admin layer now builds before the domain registry that consumes its gate); cross-references updated in 12–17.
- Ticket **12** rewritten to the two-leg bond flow; ticket **14** Finalize reduced to the on-chain half (assembly/validation moved to ticket 04's STF scope); ticket **15** requires the ACTIVE (bonded) executor; ticket **04** gains the assembly-hash check.
- **Vector authoring ownership**: tickets 02/03/04 now explicitly author their layer's §31 vectors (CV-PATH/CV-APPLY, CV-COMMIT/INPUTROOT/BUNDLE/ASSET/OUTBOX/DEPLOY, EXEC-DEP/EXEC-FAIL-OUTBOX) and retire the stale-artifact banners.
- New ticket **20 — system vault contract** (§18.1a/§32; E2E fixture); the E2E/activation ticket renumbered **20 → 21**.

---

## SPEC v1.4.0 / EXECUTOR v0.2.1 — 2026-07-06

Resolves the gaps found in the source-verification review of the spec suite against `feature/merkle-state-root`.

### 1. Withdrawal release model (§5.3, §17.3, §18.2, §21, §27.9, §27.10)

The release trigger was previously unspecified: `RelayMessage` both registered a reserve and was implied to release it after a second `WithdrawalDelay` from finalization, which conflicted with `outboxId` replay protection (a second relay of the same message is rejected) and silently doubled the advertised withdrawal delay.

- `RelayMessage` is now **registration-only**: proof + `FINALIZED` + replay check → record `outboxId`, increase `pendingWithdrawalReserve`, enqueue on the domain's release queue.
- A new permissionless, rate-limited **`Update`** method (added to the §5.3 method list) drains the queue in registration order, ≤ `MaxWithdrawalsPerUpdate` (16) per call, one descendant send per release, conservation re-checked per release. Precedent: `UpdateEmbeddedAcceleratorMethod` / `checkAndPerformUpdate` (`vm/embedded/implementation/accelerator.go`, `common.go`) — note this pattern is permissionless + rate-limited, not producer-gated.
- **`FINALIZED` is the only time gate**: the post-finalization `WithdrawalDelay` (`finalizationHeight + WithdrawalDelay` release-eligible height) is removed.
- `MaxWithdrawalsPerRelay` renamed **`MaxWithdrawalsPerUpdate`** (§25). `PAUSE_RELAY` now halts `RelayMessage` registration and `Update` release (§23, §27.10).
- New §5.4 storage: the per-domain release queue.

### 2. On-chain input-sequence accounting (§4.6, §5.4, §19)

Contiguity verification and `AssetFlowSummary` deposit correspondence implicitly required Settlement to know each domain's input indices and per-range deposits, but no text assigned that obligation.

- New §4.6 normative bullet: **Settlement assigns the global input index at receive time** (every decodable input envelope for a registered domain increments the counter; undecodable sends consume no index — same predicate as the executor's §4.5 derivation), records the domain's assigned indices and per-(domain, asset) cumulative deposit totals, and verifies batch bounds against its own assignment (`firstInputSeq` = earliest unconsumed, `lastInputSeq` assigned and ≤ highest assigned, range count ≤ `MaxBatchInputs`).
- Grounding: embedded receives replay committed send order (per-contract FIFO sequencer, `chain/account/sequencer.go`). Side effect: closes the receive-lag race — a batch covering not-yet-received inputs is rejected and resubmitted.
- §19 `SubmitBatch` verification list and §5.4 storage list updated to match.

### 3. Deploy chunk sizing (§11.1, §11.2, §25)

Non-last chunks were required to be exactly `MaxDAChunkSize` (16 KiB) = `MaxDataLength`, leaving no room for the method's ABI envelope in the account-block data field — such a chunk was unpostable on L1.

- New constant **`MaxDeployChunkData` = 15 KiB** governs on-chain deploy chunk payloads; `chunk_count = ceil(total_size / MaxDeployChunkData)`; **`MaxChunkCount` = 18** (ceil(256 KiB / 15 KiB)).
- `MaxDAChunkSize` (16 KiB) now governs **only** off-chain DA bundle chunk serving (§20).
- **`MaxWasmSize` renamed `MaxCodeSize`** — the pre-instrumentation code-size cap is runtime-neutral, not WASM-specific.

### 4. Upgrade finalization (§12)

There was no path from a chunked replacement upload to an executed upgrade: `DeployContractFinalize` (the only consumer of a pending record) always derives a new `ContractID`.

- `UpgradeContract(contract_id, new_code_hash)` is now the **finalizer of upgrade-destined records**: requires a complete, non-expired pending record for `(domainId, new_code_hash)` whose deployer == caller; runs the full §11.3 pipeline; replaces code (`CodeHash` changes, `ContractID` unchanged); consumes the record. `Finalize` and `Upgrade` are mutually exclusive consumers; §11.5 expiry applies identically.

### 5. Conformance-artifact status notes (§31, `WASM Spec/execution-conformance-v1-README.md`)

`execution-conformance-v1.json` (EXEC-001…012) encodes a frame/blob layout without `deposit_asset`/`deposit_amount`/`claimed_deposit` and does not match §27.1/§27.1a; the §31 vector IDs (EXEC-DEP-*, EXEC-FAIL-OUTBOX-1, CV-*) and the CV-PATH/CV-APPLY trie vectors are not yet generated. Stale-status banners added to both documents; regeneration is gated on build stage 1A (§29, EXECUTOR P-7). Until then only SMT-001…014 (`smt-v1-test-vectors.json`) are authoritative.

### Companion-document sync

- `ARCHITECTURE.md`: §2.1 core responsibilities (input-index assignment, release queue/`Update`), §3 integration map (Settlement-side numbering, `Update` precedent), §4.2 withdrawal flow, §4.3 chunk sizing + upgrade finalization.
- `EXECUTOR.md` → v0.2.1: upstream pinned to SPEC v1.4.0; §5.5 Settlement client and P-1 method list include `Update`; §9 loop sends `Update` on finalization.

### Epic sync (applied with this revision)

The `epics/` tickets were synced to v1.4.0: README version pins; ticket 09 (renamed/added constants incl. `MaxOnChainCommitmentSize` 15 KiB, new storage entities: assigned-index records, cumulative deposit totals, release queue, `lastUpdate`); ticket 11 (pause scopes); ticket 13 (shared input-admission helper, cumulative-totals deposit correspondence); ticket 14 (`MaxDeployChunkData`/`MaxChunkCount=18`/`MaxCodeSize`, Finalize/Upgrade mutual exclusion); ticket 15 (assigned-index verification, 15 KiB size); ticket 16 (rewritten: registration-only `RelayMessage` + `Update` release crank); ticket 17 (on-chain upgrade-record checks + admission helper); tickets 18/20 (client sends `Update`; E2E flow). Also fixed misattributed code citations (`AccountBlock` is `chain/nom`, not `common/types` — tickets 01, EXECUTOR §1.4; `RegisterSentinelMethod` implementation line — tickets 12/18) and the ARCHITECTURE §2.2 watcher stage range (1–4, not 1–3). `MaxOnChainCommitmentSize` was reduced to 15 KiB in §19/§25 (same chunk-envelope bug class as `MaxDeployChunkData`).

### Known follow-ups

All open items from this revision (assembly-verification assignment, bond flow, vector-authoring ownership, system vault ticket, 10↔11 build order) were resolved in v1.5.0. The conformance artifacts themselves still regenerate at build stage 1A (tickets 02/03/04).

---

## SPEC v1.3.0

Generalised the domain schema with no behavioural change to Phase 1. Added `inputSource` (§6.1) and `proposerPolicy` (§6.2) to `DomainRecord`; the single `executor` field became the `executors` set (§6.2). Renamed batch bounds and the domain cursor to a generic **input sequence** (`firstInputSeq`/`lastInputSeq`, §4.5–§4.6, §19), with `globalInputIndex` as the value for L1-sourced domains. Generalised `SubmitBatch` acceptance and §22 to the entitled proposer of the executor set. Phase 1 remained `L1_NATIVE` / `SINGLE` / size-1; no migration required.

## SPEC v1.2.0

Prior baseline.
