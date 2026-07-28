# Executor Binary — Architecture Specification

**Document status:** Architecture specification — normative for the executor binary, grounded against go-zenon source.
**Version:** 0.3.0
**Upstream:** `SPEC.md` v1.6.0 (the on-chain protocol; governs on any conflict).

> This document specifies the **off-chain executor binary**: one generic runtime that serves any number of execution domains as plugins, runnable in **relay**, **executor**, or **watcher** roles. It does not redefine any on-chain rule; where it touches the on-chain surface it cites `SPEC.md`. It is written so a developer can build from it, so every external dependency is graded **[EXISTS]** (located in source), or **[PREREQUISITE]** (must be built first).

The governing invariants are inherited from `SPEC.md`:

> **Consensus orders. Executors compute. Settlement anchors.**
> **The runtime is generic. The domain is a plugin. State is always replayable from L1-anchored data.**

---

## Conventions

RFC 2119 / RFC 8174 keywords as in `SPEC.md`. Tag convention:

- **[CORE]** — a requirement imposed by `SPEC.md`; the binary **MUST** satisfy it regardless of this document.
- **[BINARY]** — a requirement this document adds for the executor component; local to the binary, touches no consensus byte.
- **[EXISTS]** — grounded in current go-zenon source (path cited).
- **[PREREQUISITE]** — an upstream dependency that does **not** yet exist in source and **MUST** be built before the dependent capability functions. The binary **MUST NOT** assume it exists.

`>`-blockquotes are *Informative*.

---

## 1. Scope

### 1.1 What the binary IS

A deterministic, off-chain execution engine for Project Zenon off-chain execution domains. One binary:

- consumes the canonical L1 input stream from a `znnd` source and reconstructs each domain's input sequence (`SPEC.md` §4);
- executes a domain's deterministic state-transition function (STF) through a **domain plugin**, maintaining an SMT via the path-native trie API (`SPEC.md` §13);
- produces `ExecutionResult`s, DA bundles, `DAHash`, and batch commitments (`SPEC.md` §14, §19, §20);
- runs in one of three **roles** — relay, executor, watcher (§5) — selected by configuration;
- recovers deterministically after a crash, reconciling against finalized on-chain roots (§14).

### 1.2 What the binary is NOT

- It is **not** the Settlement embedded contract (that is L1, `SPEC.md` §5).
- It does **not** define protocol behaviour. Ordering, conservation, finality, and wire formats are `SPEC.md`'s.
- It is **not** a fraud-proof referee adjudicator (Phase 2), though the watcher role produces the inputs one needs.
- Unikernel packaging is **optional**; a plain Linux build is fully conformant. Hardened packaging is a deployment concern, not architecture.

### 1.3 Relationship to upstream

| Upstream | Relationship |
|---|---|
| `SPEC.md` v1.5.0 | Defines every consensus-visible byte. This binary implements §4 (ordering / input sequence), §6.1 (input source), §6.2 (executor set / proposer), §7–§8 (runtime), §13 (SMT), §14/§27 (serialization), §19 (commitment), §20 (DA), §22 (executor model). **Core spec governs on any conflict.** |
| `common/trie` | The shared SMT core. The binary uses the **path-native API** (`RootOfLeaves`, `ProveByPath`, `VerifyProofByPath`, `VerifyAbsenceByPath`) and **MUST NOT** call the key-hashing L1 verifiers. **[EXISTS]** — see §18. |

### 1.4 Packaging, code sharing, and plugin linking

**[BINARY] The executor is a separate repository and Go module** (e.g. `github.com/zenon-network/zenon-executor`), built and operated on its own node, on its own release cadence. It is **not** a `cmd/` entry point inside go-zenon. It pulls go-zenon in as a **pinned module dependency** (`require github.com/zenon-network/go-zenon vX.Y.Z`) and imports only the consensus-frozen code it must not reimplement:

- `common/trie` — the shared SMT core, via the path-native API (§5.3);
- `common/types` — `Address`, `Hash`, `AccountHeader`, and related primitives (with `chain/nom` for `AccountBlock`/`Momentum`);
- `vm/embedded/definition` (Settlement) — the ABI to decode inputs and encode `SubmitBatch`/`RelayMessage`.

It reads momenta and Settlement storage from a `znnd` node over JSON-RPC (§5.1, §5.5); it does not embed or run L1 consensus.

"Import directly" means *use the same compiled package*, not co-locate. This is the mechanism behind the SPEC's "one verifier, no second implementation" (`SPEC.md` §13.1): L1 momentum roots and L2 executor roots are byte-identical because both sides run identical `common/trie` code, and in Phase 2 the on-chain dispute referee verifies L2 proofs with that same `VerifyProofByPath`. `common/trie` therefore rightly lives in go-zenon — L1 needs it for the momentum state root and the referee — and the executor is a *consumer* of it. The shared seam is the path-native API (§5.3); the executor **MUST NOT** import the L1 maintenance adapter (`tree.go`/`momentum_fold.go`), whose momentum-specific empty→delete fold and key pre-hashing differ from L2 (`SPEC.md` §13.6). The `common/trie` conformance vectors (`smt-v1-test-vectors.json`, gated by `conformance_test.go`) are the contract that keeps the two layers identical; the executor runs them in its own CI (§19).

**[BINARY] The dependency direction is one-way and load-bearing: `executor → go-zenon`, never the reverse.** go-zenon **MUST NOT** import the executor or any domain plugin. Keeping `common/trie` and the Settlement contract in go-zenon creates no back-dependency — they are L1 components — whereas a back-dependency *is* the real separation violation, and Core review **MUST** reject one.

**[BINARY] Domains are static, compile-time plugins.** A plugin is a Go package implementing the `Domain` (and, for external sources, `Source`) interface of §7. The domain-specific code lives outside L1 entirely — in particular the **WASM runtime** (interpreter, instrumentation, host ABI) lives inside the WASM plugin, never in go-zenon. The executor's `main` imports and registers the plugins a given build serves:

```go
exec := runtime.New(cfg)
exec.Register(wasm.New())        // the WASM L1_NATIVE domain
// exec.Register(bitcoin.New())  // a future L1_RELAYED domain
exec.Run()
```

**An operator builds the executor for the domains they intend to run** — adding or removing a domain is a rebuild against that plugin module, not a runtime load. This keeps the binary type-safe, deterministic, and conformance-testable, with no dynamic-loading fragility. Each plugin **MAY** be its own module/repo; Phase 1 may start with the WASM plugin as a package in the executor repo and extract it when a second domain appears — the boundary that matters is the `Domain` interface, not the repo line.

> *Informative.* Pinning go-zenon as a dependency pulls in its module graph and couples the executor to go-zenon's package layout; this is acceptable (Go compiles only what is imported). If the coupling later becomes a burden, extract a lean shared module (`zenon-trie`/`zenon-types`) imported by both — a refactor to reach for only if needed, never pre-emptively. Dynamic plugin loading (`.so`, subprocess/gRPC, or wasm-sandboxed) is out of scope until third parties must ship domains without rebuilding the executor (Phase 2+), and trades determinism guarantees for that flexibility.

---

## 2. Principles

1. **[BINARY] Generic runtime, plugin domain.** Everything except the STF is written once. A domain contributes a pure STF, input decoding, a genesis state, and (for external sources) a relay source adapter — nothing else (§7).
2. **[CORE] L1-anchored replay.** L2 state is a pure function of L1-anchored data (canonical inputs + commitments + DA bundles). The binary **MUST NOT** read a live external source to *reconstruct* state; external reads exist only to *propose* and to *watch* (§8, §10).
3. **[CORE] Purity of the STF.** `Apply(state, input)` is deterministic and side-effect-free: no clock, no RNG, no network, no environment. Every external fact arrives as a decoded input (`SPEC.md` §7.3, §9).
4. **[CORE] Uniform commitment envelope.** The committed batch format (`SPEC.md` §19) is identical across domains; the STF differs, the wire format does not. This keeps Settlement runtime-agnostic.
5. **[BINARY] Fail-closed.** Any internal consistency fault (root mismatch, `DAHash` mismatch, corruption) halts the binary rather than submitting (§15).

---

## 3. System context

```
   L1 (Zenon, via znnd)                Executor binary (this doc)             Off-chain
   ┌──────────────────────┐  inputs   ┌──────────────────────────┐  bundle  ┌──────────────┐
   │ Settlement contract  │◀────────▶ │  generic runtime         │────────▶ │ Sentinel /   │
   │ (SPEC.md §5)         │  Submit   │   + domain plugin(s)     │  DAHash  │ libp2p DA    │
   │  registry · custody  │  Batch    │   role: relay|exec|watch │          └──────────────┘
   │  commitments         │◀────────  │                          │
   └──────────────────────┘  reads    └──────────────────────────┘
        ▲   getDetailedMomentumsByHeight / getStateRoot / getProof   (rpc/api/ledger.go)
        └── relay role posts external data as Settlement account-blocks (L1_RELAYED domains)
```

---

## 4. Roles

There are three roles, but **executor and watcher are the same runtime in two modes**; the relay is a separate, lighter path that only external domains need. The role is a configuration flag plus an output stage on the shared pipeline (§9).

| Role | Does | Bonded? | Runs the STF? | Needed for |
|---|---|---|---|---|
| **Relay** | Watches an external source and posts its data to L1 as Settlement account-blocks | No (permissionless) | No — validation happens later, inside the STF | `L1_RELAYED` / `EXTERNAL_OBSERVED` domains only |
| **Executor** | Consumes the input sequence, runs the STF, builds and submits batch commitments | Yes (entitled proposer, `SPEC.md` §6.2, §22) | Yes | Every domain |
| **Watcher** | Runs the *identical* pipeline, reproduces the proposer's roots, compares, and surfaces divergence (Phase 2: emits a fraud proof) | Optional bond (Phase 2) | Yes | Every domain |

**[BINARY]** A single process **MAY** host multiple domains and **MAY** run different roles per domain; each `(domainId, role)` pairing is independent. State and key material **MUST** be isolated per domain in-process. (Protocol-level domain isolation is guaranteed on-chain by per-`(domain, asset)` keying, `SPEC.md` §6 — the in-process isolation is hygiene, not a consensus guarantee.)

> An `L1_NATIVE` WASM domain (Phase 1) has no relay: users post inputs to Settlement directly. The relay role exists only once `L1_RELAYED`/`EXTERNAL_OBSERVED` domains are activated (`SPEC.md` §6.1, reserved in Phase 1).

---

## 5. Layered runtime

The runtime is a stack of domain-agnostic layers; the domain plugin attaches only at the STF driver and (optionally) the relay path.

### 5.1 Input pipeline
**[CORE]** Follows the `znnd` confirmation frontier, reads confirmed momenta, filters content to the configured `domainId`, reconstructs the domain's input sequence in the order fixed by L1 (`SPEC.md` §4.4), and maintains the per-domain input-sequence cursor (`SPEC.md` §4.5).

- **[EXISTS]** `LedgerApi.GetDetailedMomentumsByHeight(height, count)` (`rpc/api/ledger.go:446`) returns momentum content `{Momentum, []*AccountBlock}`; `GetMomentumsByHeight` returns headers (with the v3 `StateRoot`).
- **[EXISTS]** Canonical order is L1-verifiable with no new derivation: `AccountHeader.Bytes() = Address‖Height‖Hash` (`common/types/account_header.go:41`) and momentum content is sorted by `bytes.Compare(a.Bytes(), b.Bytes()) <= 0` (`chain/nom/momentum_content.go:53`) — note the comparator is `<= 0`; account headers are distinct, so the ordering is total — matching `SPEC.md` §4.4.
- **[PREREQUISITE]** Settlement contract **address** (`common/types/address.go`, via `parseEmbedded`, alongside `HtlcContract:32`) and **ABI** (`vm/embedded/definition/settlement.go`) are needed to identify and decode Settlement-destined account-blocks. Neither exists; the input parser is plugin-decoded behind a stub until they land (§18).

For `L1_NATIVE`/`L1_RELAYED` domains the input sequence number equals the `globalInputIndex` (`SPEC.md` §4.5); the pipeline hands the plugin an opaque `{domainId, payload}` to decode.

**[CORE]** `globalInputIndex` is assigned over the **global** L1 stream *before* domain filtering; filtering does not renumber. A domain's batch is a contiguous slice of **that domain's subsequence**, so consecutive consumed indices may jump (e.g. domain A sees `{5, 7, 9}`, `SPEC.md` §4.6). The pipeline **MUST** track each domain's last-consumed `globalInputIndex` independently and **MUST NOT** require `nextGlobal == previousGlobal + 1`.

### 5.2 STF driver
**[CORE]** The execution loop. Feeds decoded inputs to the plugin's `Apply` one at a time, supplies a **witnessing** state accessor, collects the returned effects, computes `preStateRoot`/`postStateRoot`, charges effect gas where the domain defines it, and slices **each domain's subsequence** into batches that are contiguous **within that subsequence** up to `MaxBatchInputs` — a batch begins at the successor of the domain's own cursor, never at `globalIndex + 1` (`SPEC.md` §4.6, §10, §14).

- **Witnesses are captured here automatically** — every state read/write (including absent observations, `SPEC.md` §13.6) passes through this layer, so the plugin never builds a witness.
- **[PREREQUISITE]** The deterministic WASM runtime (instrumentation pipeline, gas metering, host ABI `storage_len`/`storage_read`/`abort`) does not exist as a component; it must be built per `SPEC.md` §7, §8, §11, §27.1. Early stages may stub execution.

### 5.3 State store
**[CORE]** A Sparse Merkle Tree over the path-native trie API (`SPEC.md` §13.1), plus persistence and checkpointing.

- **[EXISTS]** `RootOfLeaves` (`common/trie/pathapi.go:24`), `ProveByPath` (`pathapi.go:30`), `VerifyProofByPath` (`common/trie/proof.go:236`), `VerifyAbsenceByPath` (`proof.go:255`), `LeafHash`/`InternalHash` (`hash.go:46`/`53`). The path-native functions are the primitives; the key-hashing `VerifyProof`/`VerifyAbsence` are thin wrappers over them.
- **[CORE]** The binary **MUST** use only the path-native functions and **MUST NOT** call any key-hashing or L1-maintenance entry point: the key-hashing `VerifyProof`/`VerifyAbsence` (`proof.go:271`/`277`, thin wrappers that pre-hash the key via `types.NewHash`), `Tree.Update`, the `stagedApplier`/`stagedApplierMap` write-set appliers (`common/trie/momentum_fold.go:74`/`100`, which fold empty→delete), or `CompactTree` (an L1 maintenance structure). These are L1-momentum-specific and would either double-hash an already-derived path or collapse a present-empty leaf to a deletion — L1-only, `SPEC.md` §13.1, §13.5.1, §13.6.
- **[BINARY]** The store is a **cache** of deterministically derivable state; checkpoints are an optimisation, never the source of truth.

### 5.4 Commitment & bundle builder
**[CORE]** Assembles the canonical `ExecutionResult` per input, the per-batch `inputRoot`/`receiptRoot`/`eventRoot`/`outboxRoot`, the `AssetFlowSummary`, and the DA bundle hashed to `DAHash` (`SPEC.md` §14–§20). Format is uniform across domains; the plugin supplies only semantic content (which deposits/withdrawals/events occurred). **[BINARY]** The builder **MUST** verify the `DAHash` round-trip (reconstruct from the persisted bundle, confirm equality) before committing; mismatch → halt.

### 5.5 Settlement client
**[CORE]** Builds and sends `SubmitBatch` / `RelayMessage` / `Update` (the withdrawal-release crank, `SPEC.md` §18.2), reads Settlement state, and (for `RANDOM_BACKUP`) computes the proposer schedule (`SPEC.md` §6.2, §19).

- **[EXISTS]** Read paths: `LedgerApi.GetProof(height, key)` (`rpc/api/ledger.go:361`) returns `{value, proof, root}` for reading Settlement storage via L1 state proofs; `GetStateRoot(height)` (`:349`) for the recovery anchor (§14).
- **[EXISTS] (pattern)** Account-block construction/signing exists in `wallet/` (keys) and the embedded send pattern; bonded registration mirrors `RegisterSentinelMethod` (`vm/embedded/definition/sentinel.go:31`).
- **[PREREQUISITE]** The Settlement `SubmitBatch`/`RelayMessage`/`Update`/`RegisterExecutor` methods and the bond methods (`DepositQsr`/`PostBond`/`RevokeBond`, SPEC §22), the `OffchainExecutionSpork`, and a Settlement-specific send helper (and a storage-read RPC or documented key layout for the domain cursor / batch status / `postStateRoot`) do not exist (§18).

### 5.6 DA layer
**[BINARY]** Publishes and fetches bundles by `DAHash` over Sentinel/libp2p (`SPEC.md` §20, `DAMode = 0`). Best-effort; not consensus-critical in Phase 1.

### 5.7 Role controller
**[BINARY]** Selects relay/executor/watcher behaviour per domain and, for an executor under `RANDOM_BACKUP`, whether this node is the entitled proposer for the current slot (§13). Drives the same pipeline regardless.

### 5.8 Fraud-proof harness (Phase 2, reserved)
**[BINARY]** Re-runs a single challenged input through the plugin's `Apply` and compares the recomputed `postStateRoot`. Domain-agnostic except that it loads the relevant plugin. Reserved in Phase 1.

---

## 6. Settlement-contract activation (registration pattern)

> *Informative — grounding for the on-chain side the binary talks to.* The Settlement contract is added exactly as HTLC was: `GetEmbeddedMethod` (`vm/embedded/embedded.go:220`) builds the active contract map and applies spork-gated diff layers — `applyHtlcDiffs` (`embedded.go:45`) gated by `context.IsHtlcSporkEnforced()` (`embedded.go:240`; `vm/vm_context/spork.go:14`). A new `applySettlementDiffs` gated by a new `IsOffchainExecutionSporkEnforced()` mirrors it. The spork id follows `HtlcSpork`/`StateRootSpork` (`common/types/spork.go:5`/`84`); the address follows `HtlcContract` (`common/types/address.go:32`). Administration reuses the bridge `TimeChallenge`/`SecurityInfo` machinery (`vm/embedded/implementation/common.go:439`, `bridge.go`). All of this is **[PREREQUISITE]** for the Settlement side — the binary only depends on the resulting methods and storage (§5.5, §18).

---

## 7. Domain plugin interface

The plugin is the only code written to add a domain: a pure function plus decoding. It never sees Settlement, never computes a root, never builds a witness, never opens a socket inside `Apply`.

```go
// The execution contract every domain implements.
type Domain interface {
    Genesis() StateInit                                  // initial state (empty for WASM; SPV genesis for BTC)
    DecodeInput(payload []byte) (Input, error)           // opaque L1 payload → typed, structurally-valid input
    Apply(state StateAccess, in Input) (Effects, error)  // pure STF; runtime supplies the witnessing accessor
}

// Optional: only L1_RELAYED / EXTERNAL_OBSERVED domains implement this (the relay role).
type Source interface {
    Watch(ctx Context) (<-chan RelayPayload, error)      // what to relay to L1 (e.g. BTC headers + inclusion proofs)
}
```

Runtime-supplied types the plugin consumes but does not implement: `StateAccess` (`Read`/`Len`, backed by the SMT, witnessing every access including absences); `Effects` (`StateDiff`, `Events`, `OutboxMessages`, `ReturnData`, and domain value flows the runtime folds into `AssetFlowSummary`; mirrors `ContractEffects`, `SPEC.md` §14.2).

| Concern | Owner |
|---|---|
| STF (`Apply`), input decode, input-canonicity predicate, genesis, SMT key layout, `ChainVerifier` choice (bridge domains) | **Plugin** |
| External source watching (`Source` / `SourceAdapter`) — external domains only | **Plugin** |
| Ordering, input-sequence cursor, witness capture, roots, batching, commitment/bundle, Settlement comms, proposer scheduling, fraud-proof harness, profile verification | **Runtime / Settlement** |

**[BINARY]** The WASM specifics (`ExecutionInputFrame` write, `ContractEffects` validation, deposit refund `SPEC.md` §18.5) **MUST** live behind `Domain.Apply`/`DecodeInput`, even while WASM is the only implementation, so the generic runtime emerges from day one rather than being refactored out later.

**[BINARY] Bridge and messaging domains reuse this exact four-method interface.** A `BRIDGE`/`MESSAGING` domain (`SPEC.md` §6.5) is a `Domain` plugin whose `Apply` delegates to a shared **`BridgeLedger`** state machine (mint/burn/pool/conservation/peg-out/replay/fraud) with a per-chain **`ChainVerifier`** injected — the foreign-fact verifier implementing the domain's `foreignProfile` (`SPEC.md` §6.4, §6.6). `Genesis` returns the light-client anchor (`chainBinding.genesisAnchor`); `DecodeInput` decodes relayed `Header`/`Deposit`/`Redeem`/`Settle`/`Fraud` payloads; `Source.Watch` is the per-chain **`SourceAdapter`** (relay role). The foreign-side **`ReleaseAdapter`** that consumes a finalized `kind=1` peg-out authorization lives **on the foreign chain**, not in this binary (`SPEC.md` §6.6). Adding a chain is therefore a new `ChainVerifier` + `SourceAdapter` + `ReleaseAdapter` + asset wiring; the runtime, the `BridgeLedger`, and Settlement are untouched. The `ChainVerifier` **MUST** be pure (no live foreign reads inside `Apply`, §10) so replay reproduces state from L1-anchored data alone. Full interface types and the shared `BridgeLedger` pseudocode are in the companion `research/bridges/BRIDGE-FRAMEWORK-SPEC.md` §7, §12; reserved until the profiles activate (`SPEC.md` §6).

**[BINARY]** A plugin's SMT key layout **MUST** be expressed as a pure derivation to a 32-byte SMT path (`SPEC.md` §13.3 — `sha3(contract_id‖local_key)` for WASM); the runtime consumes **already-derived paths** and **MUST NOT** key-hash. This keeps the double-hash hazard (§5.3) out of the runtime as new domains are added.

---

## 8. Input-source handling

A domain declares its `inputSource` on-chain (`SPEC.md` §6.1). The binary handles each kind:

- **`L1_NATIVE`** — inputs are Settlement account-blocks; the input pipeline (§5.1) is the whole story. No relay. **Phase 1.**
- **`L1_RELAYED`** — external data is posted to Settlement as account-blocks by the relay role (§12); to the input pipeline these are ordinary L1 inputs with a `globalInputIndex`, so DA and ordering are L1-inherited and the STF validates canonicity. Reserved.
- **`EXTERNAL_OBSERVED`** — the executor reads the external chain directly; consumed inputs are committed (`inputRoot`) and published (`DAHash`), with a domain-defined input sequence. Weaker, non-L1 DA. Reserved.

**[CORE]** For all kinds the executor **MUST NOT** reorder, skip, or privately insert inputs (`SPEC.md` §4.7); for external sources this is a completeness requirement enforced by the same per-domain input-sequence contiguity that gives force-inclusion (`SPEC.md` §4.6, §6.1).

---

## 9. Execution loop

The per-domain crank, driven by the L1 confirmation frontier. Every step is a pure function of its inputs except I/O (znnd reads, store writes, L1 submission). The architecture is:

```
advance to confirmation frontier (frontier − confirmationDepth)
  → read confirmed momenta in ascending height; on a momentum-hash change at a
    previously-consumed height → reorg handling (§14)
  → derive the global stream, assign input-sequence numbers, filter to domainId
  → for each input in order: plugin.DecodeInput → plugin.Apply (witnessed) → stage effects → receipt
  → close a batch contiguous over THIS domain's subsequence at MaxBatchInputs (never over raw global indices)
  → build ExecutionResult set, roots, DA bundle (DAHash); verify DAHash round-trip
  → ── role:executor & entitled proposer ──▶ pre-check on-chain cursor; SubmitBatch
     ── role:watcher ─────────────────────▶ fetch committed batch; compare roots; on mismatch alarm/(Phase 2) fraud proof
     ── role:relay ───────────────────────▶ (separate path, §12) post source data to L1
  → on finalization: relay outbox messages / withdrawals; send Update to release due withdrawals
  → persist cursors atomically; repeat
```

**[BINARY]** Every branch detecting an internal inconsistency terminates in `HALTED(reason)`, never silent continuation (§15).

---

## 10. Determinism and replay

**[CORE]** `Apply` may consume only its `state` accessor and its decoded `input`. The binary **MUST** be able to reconstruct any domain's state from genesis (or a checkpoint) by replaying canonical inputs alone. For external domains, the executor reads the external chain only in the relay/`Source` path to decide what to propose; the consumed data is then committed and published, so a genesis syncer replays it through `Apply` to byte-identical state **without** external-network access (`SPEC.md` §13.5.1, §20). This is the property that makes the watcher and the Phase 2 referee able to reproduce the executor exactly.

---

## 11. Watcher role

**[BINARY]** The watcher runs §5.1–§5.4 identically to the executor, then instead of submitting:

1. reads the committed batch for its domain from Settlement storage (via `GetProof`, §5.5);
2. compares the committed `preStateRoot`/`postStateRoot`/`inputRoot`/`receiptRoot`/`outboxRoot`/`DAHash` to its own recomputed values for the same input-sequence range;
3. on agreement, advances; on divergence, raises a public alarm. **(Phase 2, reserved)** emit a fraud proof via the harness (§5.8) — a Phase-1 watcher is **alarm-only** and **MUST NOT** build the emitter.

The watcher is therefore an executor minus the submit stage plus a compare stage — no separate execution code. Its recovery/reconciliation logic (§14) is the same as the executor's; a non-proposing member of an executor set (`SPEC.md` §6.2) **SHOULD** run as a watcher.

---

## 12. Relay role

**[BINARY]** For `L1_RELAYED`/`EXTERNAL_OBSERVED` domains, the relay watches the external source via the plugin's `Source` adapter and posts the data the STF will need (e.g. BTC headers + transaction inclusion proofs) to Settlement as L1 account-blocks.

- Relaying is **permissionless** and carries **no trust**: the STF validates every relayed datum and rejects anything non-canonical, so a dishonest relayer can only *withhold*, which is defeated by relaying being open to anyone (force-inclusion / completeness, `SPEC.md` §4.2, §6.1).
- The relay does **not** run the STF or hold state; it is a thin source-to-L1 pump. It **MAY** be co-hosted with an executor/watcher for liveness or run standalone.
- **[PREREQUISITE]** Settlement input methods + ABI to carry relayed payloads (§18).

> Worked example (BTC `L1_RELAYED`): user sends BTC to the bridge address tagging the L2 recipient → relay posts the header(s) and the deposit's Merkle proof → the executor's `Apply` validates PoW/linkage/confirmations, verifies the branch, credits wrapped-BTC in the plugin's SMT state → standard batch commit. Replay reads the relayed headers/proofs from L1 and re-runs `Apply`; no Bitcoin access. BTC *withdrawal* (threshold-signing a Bitcoin transaction) is a key-custody problem outside this binary's scope.

---

## 13. Multiple executors and proposer selection

**[CORE] Phase 1:** `executors` size 1, `proposerPolicy = SINGLE`; **no proposer schedule is computed**. Everything below on `RANDOM_BACKUP` selection is **Phase 2, reserved**.

**[CORE]** Phase 1 has one executor per domain (`SPEC.md` §6.2). Phase 2 introduces a permissioned set under `RANDOM_BACKUP`:

- the entitled proposer for a slot is selected by the objective, on-chain-derivable seed **defined in `SPEC.md` §6.2/§22** (this document does not re-define it); after the SPEC-defined fallback timeout a backup becomes eligible. The binary computes this from L1 state + the registered set (§5.5);
- state lineage stays linear — at most one batch per cursor position; a non-entitled submission is rejected on-chain (`SPEC.md` §19);
- non-proposing members run as watchers (§11).

**[BINARY] Single-instance lease (distinct concern).** Independently of the set, the binary **MUST** prevent two copies of the *same* executor identity running concurrently (equivocation), via a single-active-instance lease acquired at boot (file lock or external lease); a non-holder **MUST** exit without entering the execution loop. This is orthogonal to proposer selection: the lease guards one identity; the proposer policy picks among identities.

---

## 14. Recovery and state machine

**[BINARY]** On startup the binary reconciles local state against the most recent *finalized* on-chain root before resuming.

```
BOOT ─ load+validate config, acquire single-instance lease ─▶ LOAD_SNAPSHOT
LOAD_SNAPSHOT ─ load local state/snapshot (or genesis) ─▶ FIND_RECOVERY_ANCHOR
FIND_RECOVERY_ANCHOR ─ read latest FINALIZED batch for the domain ─▶ RECONCILE_FINALIZED_ROOT
RECONCILE_FINALIZED_ROOT ─ recompute local root at anchor.lastInputSeq; compare ─▶ match: REPLAY_POST_ANCHOR | mismatch: HALTED
REPLAY_POST_ANCHOR ─ re-derive post-anchor state from the canonical stream ─▶ READY
REPLAY_POST_ANCHOR ─ required DA bundle missing/unfetchable ─▶ AWAIT_DA ─ retry exhausted ─▶ HALTED
READY ⇄ SUBMITTING (executor)  |  READY ⇄ COMPARING (watcher)
any state ─ consistency fault ─▶ HALTED (terminal until operator action)
```

- **Recovery anchor:** the most recent `FINALIZED` batch's `postStateRoot` + `lastInputSeq`, read from Settlement storage via `GetProof` against the L1 state root (`GetStateRoot`, §5.5). Fallback (no finalized batch): genesis (empty SMT, sequence `-1`). **[PREREQUISITE]** the Settlement storage read path (§18).
- **[BINARY]** Transient faults (disk, OOM, network) **MAY** auto-restart with bounded backoff; consistency faults (root mismatch, `DAHash` mismatch, corruption) **MUST** stay `HALTED`.
- **[CORE]** Forward replay from the anchor advances by walking the domain's subsequence (the next `globalInputIndex` *belonging to this domain*), never by incrementing the global index by 1 (§5.1).
- **`AWAIT_DA` (new state).** If post-anchor replay needs a DA bundle that is not present (own pre-finalization bundle) or not fetchable (a peer's, Phase 2), enter `AWAIT_DA` with bounded retry → `HALTED` on exhaustion. A missing local bundle for an un-finalized batch is a **defined fault**, never silent. (Phase 1 this is a local-disk read.)
- **Anchor ahead of local frontier (new edge).** If Settlement shows a `FINALIZED` batch at a height this node never produced (a restored old disk, or another set member submitted while down in Phase 2), `RECONCILE_FINALIZED_ROOT` **MUST** distinguish *local-absent* (→ re-derive forward from the anchor, `REPLAY_POST_ANCHOR`) from *root mismatch at a height local did produce* (→ `HALTED`).
- **Intermediate-finalized mismatch (new fail-closed edge).** If forward replay disagrees with **any** intermediate finalized batch root between the anchor and the local frontier → `HALTED`.
- **Reorg deeper than `confirmationDepth`** → `HALTED` (L1 fault). The executor **MUST NOT** have submitted a batch whose inputs lie below an unconfirmed reorg point; `confirmationDepth` (the open question of §17) is precisely what guarantees this.

---

## 15. Failure handling

| Failure | Detection | Behaviour | Transition |
|---|---|---|---|
| Malformed `ContractEffects` | Blob validation (`SPEC.md` §14.3, §27.1a) | `RUNTIME_FAULT`, full rollback, failure receipt | stays `READY` |
| Trie root mismatch (incremental ≠ recompute) | post-apply check (`SPEC.md` §13.5) | internal corruption | → `HALTED` |
| `DAHash` round-trip mismatch | §5.4 | bundle serialization/persistence wrong | → `HALTED` |
| Recovery-anchor root mismatch | §14 | local state corrupt/substituted | → `HALTED` |
| Reorg (consumed momentum retracted) | momentum-hash change at known height | roll back cursor+state to surviving height, re-derive; depth > `confirmationDepth` → L1 fault | → `READY` / `HALTED` |
| Crash mid-batch | restart | full recovery state machine | → `BOOT` |
| Disk full / OOM | write failure / OS signal | fail-closed; no partial submit | → `HALTED` (may auto-restart) |
| znnd unavailable | RPC timeout | retry with backoff; do not advance cursor | stays; → `HALTED` after max retries |
| Submission rejected (contiguity) | account-block rejected | another member advanced the cursor → treat as superseded | → `READY` |
| Duplicate instance | lease acquisition fails | exit immediately | never leaves `BOOT` |

---

## 16. Storage layout

**[BINARY]** Property-based; no specific KV engine prescribed. Per domain:

```
<storagePath>/<domainId>/
├── state/             # SMT cache; crash-recoverable (WAL or equiv.); pure-language engine preferred
├── snapshots/         # content-addressed, tagged with inputSeq + stfSpecHash; mismatched stfSpecHash → no load w/o replay
├── bundles/           # DA bundles keyed by DAHash; retain until FINALIZED + a Phase-2 challenge margin
├── cursor             # atomic writes: global cursor, domain input-seq cursor, last momentum height
├── momentum_hashes/   # height → hash, for reorg detection
├── batches/           # submitted batch metadata { batchId, txHash, firstInputSeq, lastInputSeq, preRoot, postRoot, daHash }
└── meta.json          # { domainId, executorId, stfSpecHash, role, createdAt, lastBootAt }
```

`cursor` writes **MUST** be atomic (rename-over); a crash must recover to the last atomically persisted cursor.

---

## 17. Configuration

**[BINARY]** All fields validated at boot; the binary **MUST** halt on any missing/malformed field. Per domain served:

```
domainId, executorId, stfSpecHash, chainId          # identity (SPEC §6, §9.1, §22)
role                  : RELAY | EXECUTOR | WATCHER
inputSource           : L1_NATIVE | L1_RELAYED | EXTERNAL_OBSERVED   (SPEC §6.1)
znndEndpoint, settlementAddress                      # L1 connection ([PREREQUISITE] address)
confirmationDepth                                    # momenta behind frontier treated as confirmed
storagePath
daServingEndpoint     : string | null
submissionKeySource   : FILE | ENV | KMS            # executor/relay only; injected at boot, never embedded
maxBatchInputs        : ≤ MaxBatchInputs (64)
```

> `confirmationDepth` has no spec-fixed value (`SPEC.md` §4.3 says "confirmed momentums" without a depth); it is an operational parameter requiring a Phase-1 default — an open question for DS.

---

## 18. Codebase grounding and prerequisites

**[EXISTS] — can build against now:**

| Capability | Source |
|---|---|
| Momentum content / headers / state root / proof | `rpc/api/ledger.go` `GetDetailedMomentumsByHeight:446`, `GetMomentumsByHeight`, `GetStateRoot:349`, `GetProof:361` |
| Canonical ordering primitives | `common/types/account_header.go:41` (`Bytes()`), `chain/nom/momentum_content.go:53` (sort) |
| Path-native SMT API | `common/trie/pathapi.go:24,30`, `proof.go:236,255`, `hash.go:46,53` |
| Embedded-contract + spork registration pattern | `vm/embedded/embedded.go:45,220,240`, `vm/vm_context/spork.go:14`, `common/types/spork.go:5,84`, `common/types/address.go:32,102` |
| Bonded registration + time-locked admin pattern | `vm/embedded/definition/sentinel.go:31`, `vm/embedded/implementation/common.go:439` (`TimeChallenge`), `bridge.go` (`SecurityInfo`) |

**[PREREQUISITE] — must be built before the dependent capability:**

| # | What | Where it would live | Blocks |
|---|---|---|---|
| P-1 | Settlement embedded contract (all methods) | `vm/embedded/implementation/settlement.go` | §5.5, §14, all submission |
| P-2 | `OffchainExecutionSpork` | `common/types/spork.go` | Settlement activation |
| P-3 | Settlement contract address | `common/types/address.go` | §5.1 input filtering |
| P-4 | Settlement ABI definitions | `vm/embedded/definition/settlement.go` | §5.1 input decode |
| P-5 | Deterministic WASM runtime (instrumentation, gas, host ABI) | new component | §5.2 execution |
| P-6 | Settlement storage read path (domain cursor, batch status, `postStateRoot`) | RPC or documented `getProof` key layout | §11, §14 recovery anchor |
| P-7 | Execution-conformance vectors (regenerated); CV-PATH / CV-APPLY vectors | `testdata/`, `common/trie/testdata/` | §19 conformance |

---

## 19. Conformance

**[CORE] (preconditions):** SMT vectors green (14/14); trie adversarial tests green incl. the double-hash trap; path-native API vectors (CV-PATH-1/2) and applier vectors (CV-APPLY-1/2) green ([PREREQUISITE] P-7); the binary uses **only** the path-native API — a grep for `VerifyProof(`/`VerifyAbsence(`/`Tree.Update`/`stagedApplier`/`CompactTree` outside the L1 adapter returns zero; the L2 `StateDiff` applier preserves present-empty and never folds empty→delete (`SPEC.md` §13.5.1, §13.6).

**[BINARY] (component):** input-sequence derivation is identical across two independent implementations for identical momentum content; replay determinism (same inputs → identical roots, `ExecutionResult`s, `DAHash`); `DAHash` reproducibility; batch-commitment round-trip (present-but-empty `proofData`; unknown `protocol_version` rejected); malformed-input rejection → `RUNTIME_FAULT`.

**[BINARY] (operational):** crash recovery reconciles against the finalized anchor with no reorder/skip/duplicate; reorg rollback; equivocation (lease) — non-holder exits; snapshot substitution → halt; watcher divergence detection on a deliberately corrupted commitment.

---

## 20. Phase mapping

| Phase | Roles active | Domains | This binary |
|---|---|---|---|
| Phase 1 | Executor (+ optional watcher) | One WASM `L1_NATIVE`, `SINGLE` proposer | Executor mode, single-instance lease, recovery state machine |
| Phase 2 | Executor + watcher + relay | Permissioned set (`RANDOM_BACKUP`), `L1_RELAYED` domains viable | Proposer scheduling, fraud-proof harness, relay role engaged |
| Phase 3 | Permissionless | `STAKE_WEIGHTED`; validity proofs (`proofData`) | Proposer policy → stake-weighted; one-time SMT-hash migration (`SPEC.md` §13.2) |

The generic-runtime / pure-STF-plugin / uniform-commitment seam does not change across phases; new domains, new executors, and the relay and watcher roles are additive.
