# Off-Chain Execution — Demo Plan

**Document status:** Planning overview — *informative, non-normative*. General plan only, not a specification. Normative detail lives in `SPEC.md`, `EXECUTOR.md`, and the bridge companion `research/bridges/BRIDGE-FRAMEWORK-SPEC.md`.
**Purpose:** Outline three staged demos — one per domain class — that build on each other, so each demo's work is load-bearing for the next rather than throwaway.

---

## Why these three, in this order

The off-chain execution layer defines three domain classes (`SPEC.md` §6.5):

- **`EXECUTION`** — general computation (the WASM runtime).
- **`MESSAGING`** — moves verified cross-chain *data*, no custody.
- **`BRIDGE`** — moves *value* across a foreign-chain boundary, with custody.

The demos map one-to-one onto them, and are ordered so each is a strict superset of the last:

```
Demo 1  WASM Executor   (EXECUTION)   — the base off-chain execution loop
Demo 2  BTC Oracle      (MESSAGING)   — adds the Bitcoin verification pipeline, no custody
Demo 3  BTC Bridge      (BRIDGE)      — adds custody + minting on top of the oracle
```

The key idea: **a bridge is its oracle plus custody.** Demo 2 builds the entire btcd → relay → SPV-verify → commit pipeline with zero custody risk; Demo 3 reuses that pipeline verbatim and adds the value layer. Nothing in Demo 2 is discarded.

---

## Demo 1 — WASM Executor (`EXECUTION`)

**Goal.** Prove the core off-chain execution loop end to end: a user deploys and calls a WASM contract, the bonded executor runs it off-chain, and Settlement anchors the result on L1.

**Domain profile.** The Phase-1 active point: `EXECUTION` / `L1_NATIVE` / `ATTESTATION` / `ESCROW` / `SINGLE`. No profiles or foreign chains involved.

**What it demonstrates.**
- Deploy (chunked), `CallL2`, and a payable deposit/withdraw round-trip.
- The batch lifecycle: `SubmitBatch` → withdrawal delay → `FINALIZED` → `Update` release.
- Deterministic replay: an independent watcher reproduces the executor's roots from L1-anchored data alone.
- Aggregate conservation enforced on-chain (`ESCROW`).

**What the audience sees.** A real smart contract running off Zenon consensus, its state committed to L1, and a withdrawal settling back to an L1 account — with a second node independently confirming the executor didn't cheat.

**Reused later.** Everything: the runtime, the SMT/witnessing, the batch/commitment/DA pipeline, the relay/executor/watcher roles. Demos 2 and 3 are new *plugins* on this same machinery.

---

## Demo 2 — BTC Oracle (`MESSAGING`)

**Goal.** Bring verified Bitcoin facts onto Zenon trustlessly, with no custody. A `MESSAGING` domain relays Bitcoin headers and proves a specific fact — "transaction T is confirmed at depth K in block N" — delivering it as a message to a Zenon contract's inbox.

**Domain profile.** `MESSAGING` / `L1_RELAYED` / `ATTESTATION` / `LIGHT_CLIENT` (foreign-fact) / no custody. Emits `kind=0` messages only. This is the cheapest class to stand up — no custody surface, no `MINTED` path, no OD-1 dependency.

**What it demonstrates.**
- The **`ChainVerifier`** (Bitcoin SPV): PoW, header linkage, difficulty, Merkle inclusion, and a confirmation-depth finality predicate — all inside the deterministic STF.
- The **relay role** (`SourceAdapter`) reading a **btcd** node and posting headers + inclusion proofs to Settlement as permissionless `L1_RELAYED` account-blocks.
- Trustless verification: the STF re-validates every relayed datum, so a dishonest relayer can only withhold, never forge; anyone can relay.
- Deterministic replay of foreign facts from L1-anchored data (no live Bitcoin access needed to reproduce state).

**What the audience sees.** Zenon confirming a real Bitcoin transaction with no trusted oracle or federation — just relayed headers and a proof that anyone could have submitted.

**Tooling note.** Because the executor and **btcd** are both Go, the `ChainVerifier` can reuse btcd's own header-parsing, PoW/difficulty, and Merkle primitives rather than re-implementing Bitcoin crypto. Run against **regtest** first (mine blocks on demand for fast, deterministic iteration), then testnet.

**Reused later.** This *is* the BTC bridge's verification core. Demo 3 keeps the entire pipeline and only adds custody + minting.

---

## Demo 3 — BTC Bridge (`BRIDGE`)

**Goal.** Move BTC in and out: lock BTC on Bitcoin to mint `zBTC` on Zenon, and burn `zBTC` to release BTC back.

**Domain profile.** `BRIDGE` / `L1_RELAYED` / `LIGHT_CLIENT` (foreign-fact) / `MINTED` custody. For the demo, run the execution profile at the **bonded tier** (single bonded executor, `ATTESTATION` + economic floor), with `OPTIMISTIC` fraud proofs as the stated mainnet-hardening path.

**Flow (high level).**
```
PEG-IN:  user sends BTC (tagging the Zenon recipient) → btcd relay posts headers + inclusion proof
         → ChainVerifier validates (reused from Demo 2) → BridgeLedger mints zBTC
PEG-OUT: user burns zBTC → Settlement commits a kind=1 peg-out authorization
         → a ReleaseAdapter on the Bitcoin side releases the real BTC, once per authorization
```

**What it demonstrates.**
- The shared **`BridgeLedger`** (mint / burn / pool / conservation / peg-out) delegated to from the same four-method plugin interface.
- `MINTED` custody and its conservation predicates (`mintedSupply ≤ provenForeignLocks`, etc.).
- The `kind=1` peg-out authorization — the *same* withdrawal object as a native ZTS withdrawal, consumed on the foreign side by a **`ReleaseAdapter`** instead of by `Update`.
- The full round-trip: real BTC → `zBTC` → real BTC.

**What the audience sees.** BTC bridged onto Zenon as a spendable `zBTC` token and redeemed back to Bitcoin, with the mint gated on a proven on-chain Bitcoin lock.

**Honest trust framing (must be disclosed in the demo).**
- The demo runs at the **bonded/economic tier**, not the trustless tier. Trust-minimized minting requires `OPTIMISTIC` fraud proofs (so an unbacked mint is provably slashable) and the resolution of **OD-1** (the on-chain `MINTED` reconciliation mechanism, `SPEC.md` §18.3, §30). Those are mainnet prerequisites, not demo blockers.
- The **peg-out custody side** (how the `ReleaseAdapter` actually signs a Bitcoin transaction) is the genuinely hard, chain-specific problem. For the demo, use a controlled regtest key or a threshold/adaptor-signature signer as a stretch goal; the trustless BitVM/covenant path is out of demo scope.

**Reused from Demo 2.** The btcd relay, the SPV `ChainVerifier`, and the entire header/inclusion pipeline — unchanged. The only new code is the `BridgeLedger` delegation, `zBTC` issuance, and the foreign-side `ReleaseAdapter`.

---

## What carries forward (build-once map)

| Component | Demo 1 | Demo 2 | Demo 3 |
|---|---|---|---|
| Runtime, SMT, batch/commitment/DA, roles | build | reuse | reuse |
| btcd relay + SPV `ChainVerifier` | — | build | reuse |
| `BridgeLedger`, `MINTED` custody, `ReleaseAdapter` | — | — | build |

Each demo adds exactly one new layer. The progression also matches the recommended activation order in the merge note: schema + `MESSAGING` first (no custody, no OD-1), then the `MINTED` bridge once the execution profile and OD-1 are ready.

---

## Sequencing and prerequisites (general)

1. **Demo 1** depends only on the Phase-1 build (the WASM runtime, Settlement contract, executor binary) — the current roadmap.
2. **Demo 2** additionally needs `L1_RELAYED` activation, the relay/watcher roles engaged, and the Bitcoin SPV `ChainVerifier` plugin. No custody, no minting.
3. **Demo 3** additionally needs `MINTED` issuance, the `BridgeLedger`, a `ReleaseAdapter`, and — for anything beyond the bonded demo tier — `OPTIMISTIC` fraud proofs and the OD-1 resolution.

All three run comfortably on testnet/regtest. Demo 1 is a mainnet candidate as-is; Demos 2 and 3 are testnet demonstrations whose trust tier is explicitly staged toward the mainnet-grade profiles.
