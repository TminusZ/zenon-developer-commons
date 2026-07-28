# Executor Architecture — Generic Runtime with Domain Plugins

**Document status:** Design / working draft (non-normative).
**Builds on:** `SPEC.md` (Phase 1 normative spec) and `research/EXECUTOR-IDEAS.md`.
**Companion:** `research/SPEC-DOMAINRECORD-UPDATE.md` (proposed normative amendment giving the on-chain schema this architecture assumes).

> This document describes the *off-chain* executor software: how it is structured so that one runtime serves every execution domain and a new domain is added as a plugin rather than a protocol change. It does not redefine any on-chain rule in `SPEC.md`; where it touches the on-chain surface (the domain registry, the batch-commitment sequence cursor, the executor set) it defers to the companion amendment.

The architectural invariant of the protocol is unchanged:

> **Consensus orders. Executors compute. Settlement anchors.**

This document adds one off-chain corollary:

> **The runtime is generic. The domain is a plugin. State is always replayable from L1-anchored data.**

---

## 1. Purpose and scope

`EXECUTOR-IDEAS.md` proposed a generic multi-domain executor with a `Domain` interface and a `Domain`/`Adapter` split. This document refines that into an implementable component architecture that:

- maximises the reusable, domain-agnostic runtime so adding a domain (WASM, Bitcoin, Ethereum, …) is a plugin of a few hundred lines, not a fork of the executor;
- keeps every domain's execution a pure, deterministic function of L1-anchored inputs, so any party can replay state from genesis and any watcher can detect divergence;
- is forward-compatible with Phase 2 (permissioned executor set + fraud proofs) and Phase 3 (validity proofs) without an off-chain rewrite or an on-chain migration.

Phase 1 ships exactly one domain (WASM) and one bonded executor (`SPEC.md` §3, §6, §22). This document is written for the multi-domain, multi-executor target so that the Phase 1 binary is the degenerate case of the general design, not a throwaway.

---

## 2. Principles

1. **Generic runtime, plugin domain.** Everything except the state-transition logic is written once and shared. A domain contributes a pure STF, input decoding, a genesis state, and (for external sources) a relay source adapter — nothing else.
2. **L1-anchored replay.** L2 state is a pure function of data anchored on Zenon L1 (canonical inputs + batch commitments + DA bundles). The runtime **never** reads a live external source to *reconstruct* state. External reads exist only to *propose* and to *challenge*.
3. **Purity of the STF.** `Apply(state, input)` is deterministic and side-effect-free: no clocks, no randomness, no network, no direct external reads. Every external fact it needs arrives as a decoded input.
4. **Uniform commitment envelope.** The on-chain commitment format (state/input/receipt/event/outbox roots, `DAHash`, `AssetFlowSummary`, `executorId`) is identical across domains. The STF differs; the wire format does not. This is what keeps Settlement runtime-agnostic.
5. **Isolation is on-chain, hygiene is in-process.** Domain isolation (one domain can never reach another's custody) is guaranteed by per-`(domain, asset)` keying in Settlement, independent of the executor process. In-process state isolation between co-hosted domains is a separate engineering concern, not a protocol guarantee.

---

## 3. Roles

There are three roles, but they are not three independent programs. **Executor and watcher are the same runtime in two modes**; the relay is a separate, lighter path that only external domains need.

| Role | What it does | Bonded? | Runs the STF? | Needed for |
|---|---|---|---|---|
| **Relay** | Watches an external source and posts its data to L1 as Settlement inputs | No (permissionless) | No (validation happens later, inside the STF) | Relayed/observed external domains only |
| **Executor** | Consumes canonical inputs, runs the STF, builds and submits batch commitments | Yes (one entitled proposer per slot) | Yes | Every domain |
| **Watcher** | Runs the *identical* pipeline, compares the executor's committed roots to its own, and (Phase 2) submits fraud proofs on divergence | Optional bond (Phase 2) | Yes | Every domain |

Consequences:

- **Executor = pipeline + "submit the batch I built." Watcher = pipeline + "fetch the committed batch, compare, alarm/challenge."** The execution code is shared; the role is a mode flag plus an output stage. A watcher is an executor that verifies instead of proposing.
- **Relay carries no trust.** Because the STF validates every relayed datum and rejects anything non-canonical, a dishonest relayer cannot corrupt state — only withhold. Withholding is defeated by relaying being permissionless (§8, force-inclusion / completeness).
- **WASM (an `L1_NATIVE` domain) has no relay at all** — users post inputs to Settlement directly.

---

## 4. Layered architecture (the generic runtime)

The runtime is a stack of domain-agnostic layers. The domain plugin attaches at the STF driver and (optionally) at the relay path; it touches nothing else.

### 4.1 Input pipeline
Connects to a `znnd` node, follows the confirmation frontier, reads confirmed momenta, filters content to the configured `domainId`, maintains the per-domain sequence cursor, and reconstructs the canonical input stream in the order fixed by L1 (`SPEC.md` §4.4). For `L1_NATIVE` and `L1_RELAYED` domains the inputs are L1 account-blocks and the pipeline hands the plugin an opaque `{domainId, payload}` to decode. Identical for every L1-sourced domain.

### 4.2 STF driver
The execution loop. Feeds decoded inputs to the plugin's `Apply` one at a time, supplies a witnessing state accessor, collects the returned effects, computes `preStateRoot`/`postStateRoot`, charges effect gas where the domain defines it, and slices the stream into contiguous batches up to `MaxBatchInputs`. **Witnesses are captured here, automatically**, because every state read/write the plugin performs passes through this layer — the plugin never builds a witness itself.

### 4.3 State store
The Sparse Merkle Tree over the shared `common/trie` path-native API (`SPEC.md` §13.1), plus persistence and checkpointing. Every domain uses the same SMT core; checkpoints are a performance optimisation only — the source of truth is always replay from L1.

### 4.4 Commitment & bundle builder
Assembles the canonical `ExecutionResult` per input, the per-batch `inputRoot`/`receiptRoot`/`eventRoot`/`outboxRoot`, the `AssetFlowSummary`, and the off-chain DA bundle hashed to `DAHash` (`SPEC.md` §14–§20). Format is uniform across domains; the plugin supplies only the semantic content (which deposits/withdrawals/events occurred).

### 4.5 Settlement client + DA
Builds and sends `SubmitBatch` / `RelayMessage`, reads Settlement state, computes the proposer schedule for the domain's executor set, and publishes/fetches bundles by `DAHash` over Sentinel/libp2p. Generic.

### 4.6 Role controller
Selects executor vs watcher behaviour, and — for an executor — whether this node is the entitled proposer for the current slot (§9). Drives the same pipeline either way.

### 4.7 Fraud-proof harness (Phase 2, reserved)
Generic referee plumbing that re-runs a single challenged input through the domain plugin's `Apply` and compares the recomputed `postStateRoot` to the committed one. Because the plugin is a pure function, the referee is domain-agnostic except that it loads the relevant plugin. Reserved in Phase 1.

### 4.8 Infrastructure
Storage, networking, metrics, logging, configuration. Generic.

---

## 5. The domain plugin

The plugin is the only code written to add a domain. It is a **pure function plus decoding**: it never sees Settlement, never computes a root, never builds a witness, never opens a socket inside `Apply`.

```go
// The execution contract every domain implements.
type Domain interface {
    // Genesis state for this domain (empty for WASM; SPV genesis header for BTC).
    Genesis() StateInit

    // Decode an opaque L1 payload (or observed datum) into a typed, validated input.
    // Structural/well-formedness rejection happens here; semantic validity happens in Apply.
    DecodeInput(payload []byte) (Input, error)

    // The pure STF. `state` is a runtime-supplied accessor that records every key
    // touched as a witness. Returns the declarative effects; the runtime computes roots,
    // builds receipts/bundle/commitment, and applies state only on success.
    Apply(state StateAccess, in Input) (Effects, error)
}

// Optional: only relayed/observed external domains implement this.
type Source interface {
    // Watch the external chain and emit the payloads that should be relayed to L1
    // (e.g. BTC headers + inclusion proofs). Used by the Relay role only.
    Watch(ctx Context) (<-chan RelayPayload, error)
}
```

Runtime-supplied types the plugin consumes but does not implement:

- `StateAccess` — `Read(key) ([]byte, bool)` / `Len(key) int64`, backed by the SMT, **witnessing every access** (including absent observations, `SPEC.md` §13.6).
- `Effects` — `StateDiff`, `Events`, `OutboxMessages`, `ReturnData`, and any domain-defined value flows (deposits/withdrawals) the runtime folds into `AssetFlowSummary`. Mirrors `ContractEffects` (`SPEC.md` §14.2).

### 5.1 What the plugin owns vs what the runtime owns

| Concern | Owner |
|---|---|
| State-transition logic (`Apply`) | Plugin |
| Input decoding & structural validation (`DecodeInput`) | Plugin |
| Input *canonicity* predicate (e.g. BTC PoW/confirmation rules) | Plugin (inside `Apply`/`DecodeInput`) |
| Genesis state, SMT key layout | Plugin |
| External source watching (`Source`) | Plugin (external domains only) |
| Canonical ordering, sequence cursor, confirmation frontier | Runtime |
| Witness capture | Runtime |
| Root computation, batching, commitment/bundle format | Runtime |
| Settlement communication, proposer scheduling, DA publish/fetch | Runtime |
| Fraud-proof refereeing harness | Runtime |

The plugin difference between an internal and an external domain is concentrated in one place: **input admission**. An `L1_NATIVE` domain gets canonicity for free from L1 (an input is valid because it is in a confirmed momentum addressed to the domain). An external domain must establish canonicity itself (valid header chain, sufficient confirmations) — and that logic lives in the plugin, which is exactly what a Phase 2 fraud proof re-runs.

---

## 6. Execution lifecycle

The `Ingest → Execute → Commit` lifecycle from `EXECUTOR-IDEAS.md` holds, with two refinements from the design discussion:

1. **`Prove` is not a separate phase.** In the SMT model, witnesses fall out of execution — every key read or written is recorded by the runtime's `StateAccess` as a byproduct. There is no proving pass; there is a witness *capture* that the runtime does for free.
2. **Execution is split into pure STF and state application.** The plugin's `Apply` is the pure part (`witnessed reads + input → effects`); the runtime validates the effects, charges effect gas, computes roots, and applies state only on success. This is `SPEC.md` §8/§14 generalised across domains and is the single most important property for keeping Phase 2/3 tractable.

The runtime loop, per domain, is a crank driven by the L1 confirmation frontier:

```
advance to confirmation frontier
  → filter momenta to domainId, extend canonical stream, assign sequence numbers
  → for each input in order: plugin.DecodeInput → plugin.Apply (witnessed) → stage effects
  → close a contiguous batch at MaxBatchInputs (or a flush policy)
  → build ExecutionResult set, roots, DA bundle (DAHash)
  → [executor + entitled proposer] SubmitBatch     | [watcher] fetch committed batch, compare roots
  → on finalization: relay outbox messages / withdrawals
  → repeat
```

Because every step is deterministic, a crashed node rebuilds state by replaying canonical inputs from the last checkpoint (or genesis); a watcher reproduces the executor bit-for-bit; a Phase 2 referee re-runs a single input.

---

## 7. Determinism and replay

The hard rule that makes external domains safe to replay:

> **`Apply` may consume only its `state` accessor and its decoded `input`. It may not read anything else** — no wall clock, no RNG, no environment, no live external chain.

For external domains the consequence is precise: the executor *reads* the external chain (in the `Source` adapter, on the relay path) only to decide what to propose; the consumed external data is then committed (`inputRoot`) and published (`DAHash`). A node syncing from genesis replays that committed data through `Apply` and reaches byte-identical state **without ever touching the external network**. See `SPEC.md` §13.5.1 and §20 for the byte-level applier and bundle layout the runtime reuses unchanged.

---

## 8. Input-source kinds

A domain declares, at registration, where its inputs come from. This is a security-typed property, not an incidental one — it determines ordering, DA, canonicity, and censorship-resistance. (Normative schema in the companion amendment.)

| Kind | Inputs originate as | Canonical order | DA guarantee | Censorship-resistance | Phase 1 |
|---|---|---|---|---|---|
| `L1_NATIVE` | Settlement account-blocks (user calls/deposits/deploys) | L1 momentum order | L1-inherited | Native force-inclusion (`SPEC.md` §4.2) | **Shipped (WASM)** |
| `L1_RELAYED` | External data posted to Settlement as account-blocks | L1 momentum order of the relays | L1-inherited (strong) | Permissionless relay + force-inclusion | Reserved |
| `EXTERNAL_OBSERVED` | Executor reads the external chain directly | External chain order + confirmation rule, committed by the executor | External chain (weaker) + bundle | Completeness predicate + fraud proof | Reserved |

Two unifications worth noting:

- **Force-inclusion and external completeness are the same property over different sequences.** Internal: contiguity over the input sequence means no L1 input is skipped. External: contiguity over the same sequence means no canonical block is skipped. One cursor mechanism covers both.
- **For `L1_NATIVE` and `L1_RELAYED`, the input sequence number *is* the L1 `globalInputIndex`** — relayed external data are L1 account-blocks, so they get a `globalInputIndex` exactly like native inputs, and the existing contiguity machinery applies unchanged. Only `EXTERNAL_OBSERVED` needs a domain-defined sequence; the generalised cursor (companion amendment) covers all three.

**Recommendation:** design and spec around `L1_RELAYED` for the first external domain (BTC). It makes an external domain a strict special case of an internal one — same anchoring, same DA, same replay, same fraud-proof shape — and external bridges are light-client-shaped (headers + inclusion proofs, not whole chains), so the L1 data cost is small. Keep `EXTERNAL_OBSERVED` reserved for sources too data-heavy to relay.

---

## 9. Multiple executors and proposer selection (Phase 2)

Phase 1 has one executor per domain; Phase 2 introduces a permissioned set. State lineage is linear (`preStateRoot == prev postStateRoot`), so two executors cannot both advance the same cursor — only one batch is accepted per slot. The clean model:

- The domain has a **set** of bonded executors (each a registered address tied to that one domain).
- For each batch slot, one member is the **entitled proposer**, chosen by an **objective, on-chain-derivable seed** (e.g. derived from the momentum at the cursor boundary) — mirroring momentum-producer selection. After a **fallback timeout** in momentum heights, a designated backup becomes eligible, preserving liveness.
- Every other member runs as a **watcher**: it reproduces the proposer's work and submits a fraud proof on divergence.

Because the seed and timeout derive deterministically from L1 state plus the registered set, `SubmitBatch` can compute "is this caller the entitled proposer at this height" without extra stored schedule. **Phase 1 is the degenerate case**: a set of size 1 with the trivial proposer policy, so the entitled proposer is always the single executor — no schema or method change between phases. Selection is kept as a *policy* so Phase 3 can move to stake-weighting if executors become permissionless.

---

## 10. Worked example — a relayed BTC domain

Mapping the BTC deposit flow onto the components (domain = `runtimeKind=BITCOIN`, `inputSource=L1_RELAYED`):

| Step | Component | What happens |
|---|---|---|
| User deposits BTC | (external) | Sends BTC to the bridge address, tagging the L2 recipient (e.g. `OP_RETURN`). |
| Relay headers | Relay role → `Source` adapter | Anyone posts the BTC block header(s) to Settlement as `{domainId, payload}`. 80-byte headers fit an account-block. |
| Relay inclusion proof | Relay role | Posts the deposit tx + Merkle branch + block height (same or later input). |
| Validate & credit | STF driver → plugin `Apply` | Validates PoW/linkage, extends the SPV header chain, checks ≥ N confirmations, verifies the Merkle branch, reads the recipient, checks the outpoint isn't already credited, credits wrapped-BTC in the plugin's own SMT state. |
| Commit | Commitment builder → Settlement client | Standard batch: roots + `DAHash` (headers, proofs, witnesses, results) + `SubmitBatch`. Settlement records it without knowing it is Bitcoin. |
| Finalize & use | Settlement client | After the withdrawal delay the batch is `FINALIZED`; wrapped-BTC is usable, or delivered via `RelayMessage` to another contract. |

The SPV header validation and inclusion-proof checking are the *entire* BTC-specific surface; they live in `Apply`/`DecodeInput`. Replay from genesis reads the relayed headers/proofs from L1 and re-runs `Apply` — no Bitcoin access. If the executor refuses to relay a user's deposit, the user relays it themselves and the executor's STF must process it in canonical order or fail contiguity — force-inclusion, carried over from the internal model.

> Withdrawal (BTC *out*) is a key-custody / threshold-signing problem (the bridge must sign a Bitcoin transaction), orthogonal to this input/replay architecture and out of scope here.

---

## 11. Adding a domain — the checklist

To add a new domain, implement only:

1. `Genesis()` — the domain's initial state.
2. `DecodeInput(payload)` — parse and structurally validate the domain's inputs.
3. `Apply(state, input)` — the pure, deterministic STF, including the input-canonicity predicate for external sources.
4. The SMT key layout the domain uses.
5. *(External only)* a `Source` adapter for the relay role.
6. Register the domain on-chain (`RegisterDomain`, admin) with its `runtimeKind`, `stfSpecHash`, `inputSource`, and caps; bond an executor (`RegisterExecutor`).

Everything else — input pipeline, witnessing, SMT, batching, commitment/bundle format, Settlement client, DA, proposer scheduling, fraud-proof harness — is the unchanged generic runtime. No protocol change; no new momentum format; no migration.

---

## 12. Phase mapping

| Phase | Executor model | This architecture | On-chain change |
|---|---|---|---|
| Phase 1 | Single bonded executor, one WASM `L1_NATIVE` domain | Runtime in executor mode, set of size 1, trivial proposer policy | Settlement spork (`SPEC.md` §5.1) |
| Phase 2 | Permissioned set + fraud proofs + DA enforcement | Watchers active; fraud-proof harness engaged; relayed external domains viable | None to the runtime/plugin seam; verifier registry already reserved |
| Phase 3 | Permissionless + validity proofs | Proposer policy → stake-weighted; `proofData` carries the validity proof | One-time SMT-hash migration (`SPEC.md` §13.2), already isolated |

The off-chain seam (generic runtime + pure-STF plugin + uniform commitment) does not change across phases. New domains and new executors are additive.
