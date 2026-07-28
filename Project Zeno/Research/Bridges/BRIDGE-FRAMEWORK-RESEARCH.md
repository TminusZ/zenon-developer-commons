# Shared Bridge Framework

**Document status:** Research / exploration — *non-normative*. Forward-looking; ignores Phase-1 activation limits.
**Relationship to specs:** Builds on `SPEC.md` v1.3.0 (Settlement), `EXECUTOR.md` v0.2.0 (Executor §7 domain plugin interface), and `BTC-BRIDGE-RESEARCH.md` (the BTC instance that motivates the abstraction).
**Question being explored:** If we want BTC, ETH, SOL (and future) bridges, what can be written **once** and reused, and what is irreducibly per-chain?

---

## 1. The core idea: share the code, not the money

A "shared bridge framework" is an abstraction over the **Zenon-side ledger logic**, not over liquidity or foreign-chain custody. The distinction is the whole point and the most common source of confusion.

- The **mint/burn accounting, the collateral pool bookkeeping, the conservation invariant, the peg-out authorization, replay protection, and the fraud/slash state machines** are *identical* whether the asset is BTC, ETH, or SOL. Write them once.
- The **liquidity (real BTC/ETH/SOL), the foreign-side release mechanism, and the light-client verifier** are necessarily per-chain. They cannot be shared.

The mental model is class vs. instance:

```
BridgeLedger              ← the shared framework (mint/burn/pool/conservation/peg-out/fraud)
  ├─ BtcBridge            ← instance: own BTC pool, own zBTC, BitVM releaser, SPV verifier
  ├─ EthBridge            ← instance: own ETH pool, own zETH, contract releaser, PoS verifier
  └─ SolBridge            ← instance: own SOL pool, own zSOL, program releaser, PoH/vote verifier
```

Same code, separate state, separate liquidity, separate foreign contracts. The framework is the template; each chain is a self-contained instance stamped from it. Domain isolation (`SPEC.md` §6) guarantees one instance can never reach another's custody — a faulty ETH bridge cannot drain the BTC pool.

---

## 2. What is shared vs. per-chain

| Concern | Shared (framework) | Per-chain (instance) |
|---|---|---|
| Mint accounting (credit on proven lock) | ✅ | — |
| Burn accounting (debit on redeem) | ✅ | — |
| Collateral pool / conservation invariant | ✅ | — |
| Peg-out authorization object (`kind=1` outbox) | ✅ | — |
| Replay protection (`processedOutbox`) | ✅ | — |
| Fraud / slash state machines | ✅ | — |
| Withdrawal **trigger** on Zenon (burn → outbox) | ✅ | — |
| Light-client header/finality verification | — | ✅ |
| Inclusion-proof verification | — | ✅ |
| zToken identity (zBTC / zETH / zSOL) | — | ✅ |
| Real collateral / liquidity | — | ✅ |
| Foreign-side **releaser** (consumes the authorization) | — | ✅ |
| Operator set & bonds (only where needed) | — | ✅ |

The single most important correction to most people's mental model: **the withdrawal trigger on Zenon is shared, not per-chain.** Getting an asset out is always "burn the zToken → Settlement emits an outbox authorization" (`SPEC.md` §17, `kind = 1`). There is no per-chain withdrawal contract *on Zenon*. The per-chain contract is the **consumer** of that authorization, and it lives on the **foreign** chain.

```
Zenon side (shared):     burn zToken ──▶ Settlement emits kind=1 outbox authorization
Foreign side (per-chain): BitVM graph (BTC) | verifier contract (ETH) | program (SOL) consumes it
```

---

## 3. The two seams

The framework exposes exactly two pluggable interfaces. Everything else is shared code.

### 3.1 `ChainVerifier` — the read seam (foreign → Zenon)

Each chain supplies how to verify its own facts. This is the only chain-specific *verification* code.

```go
type ChainVerifier interface {
    // Advance/reorg the light-client header (or finality) state from relayed data.
    VerifyHeaderChain(headers []byte, state HeaderState) (HeaderState, error)
    // Prove a specific event (lock / spend / log) is included under a verified header.
    VerifyInclusion(evidence []byte, at HeaderState) (ForeignEvent, error)
    // Decide whether a verified event is final enough to act on.
    VerifyFinality(ref ForeignRef, at HeaderState) (bool, error)
}
```

- BTC: PoW header chain + difficulty + Merkle inclusion + K confirmations.
- ETH: sync-committee (or ZK-of-consensus) tracking + Casper FFG finality + Merkle-Patricia receipt/state proof.
- SOL: leader schedule / vote tracking (or ZK-of-bank) + slot/bank-hash inclusion.

### 3.2 `ForeignReleaser` — the write seam (Zenon → foreign)

Each chain supplies how the foreign side consumes a finalized Zenon peg-out authorization and releases real assets. This lives **on the foreign chain**, not in the executor:

- BTC (Tier 1): BitVM transaction graph + bonded operators (optimistic, 1-of-N).
- BTC (Tier 2): covenant script verifying the proof in-script (needs soft fork).
- ETH/SOL: a verifier contract/program that checks a Zenon burn proof and releases locked collateral directly.

The framework does not implement the releaser; it only emits the **authorization object** the releaser consumes. That clean boundary is why the design survives different trust/liquidity models per chain without changing the Zenon side.

---

## 4. The shared `BridgeLedger`

The reusable state machine that every bridge instance runs inside its plugin's `Apply`. Pseudocode shape:

```go
type BridgeLedger struct {
    verifier ChainVerifier   // injected per chain
    asset    AssetID         // the zToken minted/burned (per chain)
}

func (b *BridgeLedger) Apply(state StateAccess, in Input) (Effects, error) {
    switch in.Kind {

    case HeaderInput:                       // advance the light client
        hs, err := b.verifier.VerifyHeaderChain(in.Headers, readHeaderState(state))
        return writeHeaderState(hs), err

    case DepositInput:                      // PEG-IN: prove a foreign lock, then mint
        ev, err := b.verifier.VerifyInclusion(in.Evidence, readHeaderState(state))
        require(b.verifier.VerifyFinality(ev.Ref, ...))
        require(!alreadyCredited(state, ev.Outpoint))   // replay protection
        creditPool(state, ev.Amount)
        return mintEffect(b.asset, ev.ZenonRecipient, ev.Amount)

    case RedeemInput:                       // PEG-OUT: burn, then authorize release
        require(burnable(state, in.From, in.Amount))
        debit(state, in.From, in.Amount)
        return outboxAuthorization(kind=1, b.asset, in.Amount, in.ForeignDest)

    case SettleInput:                       // operator reimbursement / lock-release confirmation
        ev, err := b.verifier.VerifyInclusion(in.Evidence, readHeaderState(state))
        require(matchesFinalizedBurn(state, ev))
        markReimbursed(state, ev.BurnId)
        return releasePoolSlice(state, ev)

    case FraudInput:                        // unauthorized foreign spend
        ev, err := b.verifier.VerifyInclusion(in.Evidence, readHeaderState(state))
        require(spendsPoolUtxo(state, ev) && !authorized(state, ev))
        return slashEffect(state, ev.Operator)
    }
}
```

The only thing that changes between BTC, ETH, and SOL is the injected `ChainVerifier` and the `asset`. Everything else — pool accounting, conservation, the `kind=1` authorization, replay protection, slashing — is shared.

---

## 5. How it maps onto the executor plugin (EXECUTOR.md §7)

Each bridge instance is still just a `Domain` plugin (four methods). The framework is what those methods delegate to:

| Plugin method | Delegates to |
|---|---|
| `Genesis()` | the chain's light-client anchor (checkpoint header) + empty `BridgeLedger` state |
| `DecodeInput()` | structural decode of relayed payloads into `Input` variants (Header/Deposit/Redeem/Settle/Fraud) |
| `Apply()` | `BridgeLedger.Apply` with the chain's `ChainVerifier` injected |
| `Watch()` (`Source`) | the relay role: watch the foreign chain, emit headers/proofs/spends to Settlement |

So the framework does not change the executor's plugin surface at all — it is a **library the plugins share**, exactly as `common/trie` is a library both L1 and the executor share (`EXECUTOR.md` §1.4). New chain = new `ChainVerifier` + `Source` + zToken wiring; the `BridgeLedger` is untouched.

---

## 6. Liquidity models (and why they differ per chain)

A subtlety that the framework deliberately leaves to the instance: whether the bridge needs **fronting liquidity** at all.

- **Non-programmable foreign chain (BTC).** Bitcoin can't verify a Zenon proof in-script, so peg-out needs bonded operators to *front* the BTC and reclaim from the pool via BitVM (`BTC-BRIDGE-RESEARCH.md` §5). Operator-fronting liquidity + bonds are required.
- **Programmable foreign chain (ETH, SOL).** The foreign contract/program can verify the Zenon burn proof and release locked collateral *directly*. The locked collateral **is** the liquidity; no operator has to front anything. Trust drops to "the verifier contract is correct + the light-client assumption holds."

The framework accommodates both because the Zenon-side ledger doesn't care which release model the foreign chain uses — it only emits the authorization. Liquidity and the releaser are instance concerns.

---

## 7. Trust, per instance

Because each instance carries its own verifier and releaser, the trust model is per-chain — there is no single global trust assumption:

| Instance | Peg-in trust | Peg-out trust |
|---|---|---|
| BTC (Tier 1) | SPV mint + pre-signed graph (1-of-N key deletion) | optimistic / BitVM, 1-of-N honest watcher + bonds |
| BTC (Tier 2) | SPV mint + covenant lock | covenant-verified, 0 trust |
| ETH | sync-committee/ZK light client | verifier contract, ~0 trust (light-client assumption only) |
| SOL | leader/vote or ZK light client | verifier program, ~0 trust (light-client assumption only) |

Domain isolation means a weakness in one instance is contained to that instance's pool (`SPEC.md` §1, §6).

---

## 8. Open questions

1. **Verifier abstraction boundary.** Is `ChainVerifier` (header/inclusion/finality) expressive enough for ZK-light-client chains, or does it need a fourth `VerifyConsensusProof` primitive?
2. **Proof object portability.** The peg-out authorization must be consumable by a BitVM circuit *and* an EVM contract *and* a Solana program. Is a single `proofData` (`SPEC.md` §19) SNARK statement sufficient for all three verifiers, or per-releaser encodings?
3. **Shared vs. duplicated replay sets.** One global `processedOutbox` keyed by `(domain, outboxId)` vs. per-instance sets — the spec already keys by domain (§17.3), so this is mostly settled, but cross-instance accounting (e.g. a unified dashboard) needs care.
4. **Bond denomination across instances.** Each operator-backed instance needs bonds in an asset uncorrelated with the bridged asset; can a shared bond pool serve multiple instances, or must they be isolated for clean slashing?
5. **Light-client cost on L1.** ETH sync-committee / SOL vote data are heavier than BTC headers; does that push some instances toward `EXTERNAL_OBSERVED` (executor-attested DA) rather than `L1_RELAYED` (`SPEC.md` §6.1)?

---

## 9. One-paragraph summary

The shared bridge framework reuses the **Zenon-side ledger** — mint/burn, pool, conservation, the `kind=1` peg-out authorization, replay protection, and the fraud/slash machines — across every chain, exposing exactly two seams: a `ChainVerifier` for reading foreign facts and a `ForeignReleaser` (off-chain, per chain) for consuming Zenon authorizations. Each bridge is still a four-method executor plugin that delegates into this shared `BridgeLedger`; only the verifier, the zToken, the liquidity, and the foreign releaser are per-chain. Liquidity and custody never get shared (and shouldn't — domain isolation depends on it), but the bookkeeping does, which is the entire economic case for the framework: add a chain by writing a verifier and a releaser, not a whole bridge.
