# Generalizing to Other Chains — Integration Playbook (Smart-Contract Chains)

**Document status:** Research / exploration — *non-normative*. Forward-looking; ignores Phase-1 activation limits.
**Relationship to specs:** Builds on `SPEC.md` v1.3.0, `EXECUTOR.md` v0.2.0 (§7 plugin interface), `BRIDGE-FRAMEWORK-RESEARCH.md` (the shared `BridgeLedger` / `ChainVerifier` model), and `BTC-BRIDGE-RESEARCH.md` (the non-programmable baseline).
**Scope:** Integrating chains that **have smart contracts** (EVM: Ethereum, L2s, sidechains; SVM: Solana). These are the *easier* case than Bitcoin, because the foreign chain can verify a Zenon proof itself.

---

## 1. Why programmable chains are easier

Recall the asymmetry from `BTC-BRIDGE-RESEARCH.md` §1: a bridge has two verification directions.

| Direction | BTC | Programmable chain (ETH/SOL) |
|---|---|---|
| **Zenon verifies foreign** (secures mint) | SPV in the executor STF | light client in the executor STF |
| **Foreign verifies Zenon** (secures peg-out) | impossible in-script → BitVM/covenant workaround | **native** — a contract/program verifies the Zenon proof and releases |

The hard half of the Bitcoin bridge — "Bitcoin can't check that Zenon authorized a withdrawal" — simply does not exist on a programmable chain. You deploy a verifier contract that checks the Zenon burn proof and releases locked collateral directly. **No operators, no fronting liquidity, no challenge window, no 1-of-N.** Trust collapses to "the verifier contract is correct + the light-client assumption holds in each direction."

So the playbook below targets a **lock-and-release** design, not the optimistic operator design BTC needs.

---

## 2. What you reuse vs. what you build

Reused unchanged from the framework (`BRIDGE-FRAMEWORK-RESEARCH.md`):

- The `BridgeLedger` (mint/burn/pool/conservation/replay/peg-out authorization).
- The executor plugin shape (four methods; §7).
- The `kind=1` outbox authorization + finality + `proofData` hook (`SPEC.md` §17, §19).
- zToken mint/burn via Settlement.

Built new, per chain:

1. A `ChainVerifier` (the foreign light client, in `Apply`).
2. A `Source.Watch` relay (push foreign data to Settlement).
3. A `Genesis` light-client anchor.
4. `Input`/`Effects` variants for that chain.
5. **On the foreign chain:** a lock contract + a Zenon-verifier contract (the `ForeignReleaser`).
6. zToken identity (zETH, zUSDC, zSOL, …) wired to Settlement mint/burn.

---

## 3. Integration steps

### Step 1 — Choose the light-client model (Zenon-verifies-foreign)

This is the main per-chain design decision and drives everything in `ChainVerifier`.

- **Ethereum (PoS):** track the **sync committee** (512 validators, ~27h periods) and **Casper FFG finality** (2 justified/finalized epochs). Inclusion proofs are **Merkle-Patricia proofs** against `receiptsRoot`/`stateRoot` in a verified block header. Heavier but well-trodden (Helios-style). A ZK-of-consensus proof can shrink the on-L1 data if sync-committee data is too large for `L1_RELAYED` (see §6).
- **Solana:** there is no lightweight sync committee; you track the **leader schedule + Tower BFT vote aggregation** (or, more practically, a **ZK proof of the bank/slot**). Inclusion is via the relayed account/slot data bound to a verified bank hash. The light client is the hard part here; budget for it.

Output: an implementation of `VerifyHeaderChain` / `VerifyInclusion` / `VerifyFinality` for the chain.

### Step 2 — Implement the `ChainVerifier` (plugin `Apply` core)

Pure, deterministic, witnessed via `StateAccess`. It must establish input canonicity (`SPEC.md` §6.1): reject any relayed datum that doesn't extend the canonical light-client view. No network access inside `Apply` (`EXECUTOR.md` §10).

### Step 3 — Implement `Source.Watch` (the relay role)

Watch the foreign chain and emit to Settlement: new headers/finality updates, deposit (lock) inclusion proofs, and peg-out fulfillment confirmations. Permissionless and trustless — `Apply` re-validates everything, so a dishonest relayer can only withhold, which open relay defeats (`SPEC.md` §4.2; `EXECUTOR.md` §12).

### Step 4 — Define the `Genesis` anchor

A checkpointed foreign header / sync-committee root / bank hash so the light client doesn't sync from genesis, plus empty `BridgeLedger` state.

### Step 5 — Define `Input` / `Effects` variants

`Header`, `Deposit`, `Redeem`, `Settle` (lock-release confirmation), and — if you keep a watchtower — `Fraud`. `Effects` carry `StateDiff`, `Events`, and the `kind=1` outbox authorization.

### Step 6 — Deploy the foreign-side contracts (the `ForeignReleaser`)

Two contracts on the foreign chain:

- **Lock vault:** receives the user's ETH/ERC-20/SOL/SPL on peg-in; tags the Zenon recipient (calldata / instruction data — the programmable-chain analogue of `OP_RETURN`); holds the collateral.
- **Zenon verifier + releaser:** verifies a finalized Zenon **burn proof** (the `proofData` SNARK over Settlement state, `SPEC.md` §19) and releases locked collateral to the user's foreign address. Enforces one-release-per-burn (replay protection on the foreign side).

This is where the trust-minimization lives for programmable chains: the release is gated by an on-chain proof check, not by an operator.

### Step 7 — Wire zToken issuance on Zenon

zETH/zUSDC/zSOL are ZTS tokens minted/burned **only** by Settlement, gated on the executor's verified deposit (mint) and the user's redeem (burn). (Requires bridge-token issuance authority — beyond Phase 1, an assumption of this line of work.)

### Step 8 — Connect the peg-out authorization channel

Burn on Zenon → Settlement emits the `kind=1` outbox authorization → a relayer carries it (with the `proofData` proof) to the foreign verifier contract → contract verifies and releases. This is the same outbox/`RelayMessage` pattern as native ZTS withdrawals (`SPEC.md` §17), with the foreign contract as the consumer instead of Settlement itself.

### Step 9 — Liquidity model

Lock-and-release: the collateral locked at peg-in **is** the peg-out liquidity, unlocked by proof. No operator fronting, no bonds needed for correctness. (You may still want optional fast-exit LPs for latency, but they are a UX layer, not a trust dependency.)

### Step 10 — Conformance & replay

Replay determinism (same inputs → identical roots), light-client reorg handling, inclusion-proof vectors, and a foreign-side test that a burn proof releases exactly once. Mirrors `EXECUTOR.md` §19.

---

## 4. Worked example — Ethereum (zETH / zUSDC)

### Peg-in (ETH → zETH)

```
1. User calls lockVault.deposit{value}(zenonRecipient) on Ethereum
2. Relayer posts to Settlement: beacon header/finality update + the deposit's
   Merkle-Patricia inclusion proof against the block's receiptsRoot
3. Executor STF (EthVerifier):
       • advance sync-committee / finality state
       • verify the deposit log is included and finalized
       • replay-check the (txHash, logIndex)
4. Settlement mints zETH to zenonRecipient; collateral accounted in the ETH pool
```

### Peg-out (zETH → ETH)

```
1. User calls Settlement.Redeem(amount, ethDest)
       → zETH burned; Settlement emits kind=1 authorization {burnId, amount, ethDest}
         + proofData proof of the finalized burn
2. Relayer submits {authorization, proof} to the Ethereum verifier contract
3. Verifier contract checks the Zenon burn proof (light client of Zenon, in the EVM),
   confirms burnId unspent, releases `amount` from the lock vault to ethDest,
   and marks burnId released
```

No operators, no fronting, no challenge window. The only assumptions are the correctness of the two verifiers and the two light-client security models.

---

## 5. Solana specifics

Same shape, two differences:

- **Light client (Zenon-verifies-Solana) is harder.** No sync committee; expect a ZK-of-bank proof or vote-aggregation tracking. This may push the Solana instance toward `EXTERNAL_OBSERVED` (executor-attested DA) rather than `L1_RELAYED` if the consensus data is too heavy to relay on Zenon L1 (`SPEC.md` §6.1).
- **Foreign verification (Solana-verifies-Zenon) is easy.** A Solana program can verify a SNARK within the compute budget and release locked SPL/SOL — the same lock-and-release as Ethereum.

So Solana is "hard in, easy out," the mirror of Bitcoin's "easy in, hard out."

---

## 6. Where the per-chain weight actually lands

| Chain | Zenon-verifies-foreign (mint) | Foreign-verifies-Zenon (peg-out) | Liquidity / operators |
|---|---|---|---|
| BTC | easy (SPV) | hard (BitVM/covenant) | operators + bonds required |
| ETH | medium (sync committee / ZK) | easy (EVM verifier contract) | lock-and-release, none required |
| SOL | hard (ZK-of-bank) | easy (program verifier) | lock-and-release, none required |

The takeaway for whoever scopes this: programmable chains move the difficulty from the *peg-out / custody* side (Bitcoin's problem) to the *light-client / mint* side, and remove the operator/liquidity trust dependency entirely. The shared framework absorbs all of this — each new chain is a `ChainVerifier` + a `Source` + two foreign contracts, not a new bridge.

---

## 7. Open questions

1. **Proof portability.** Can one `proofData` SNARK statement of a finalized burn be verified efficiently by both an EVM contract and a Solana program (curve/precompile choice — BN254 vs BLS12-381 vs ed25519-friendly)?
2. **Light-client data cost.** Are ETH sync-committee and SOL vote data small enough for `L1_RELAYED`, or do they force `EXTERNAL_OBSERVED` for those instances?
3. **ERC-20 / SPL scope.** Per-token registration, decimals normalization, and conservation accounting per `(domain, asset)` — straightforward but must be enumerated.
4. **Finality mismatch.** Ethereum finality (~13 min) vs. Solana optimistic confirmation vs. Zenon withdrawal delay — the three windows must be chosen so no release finalizes over a re-orgable foreign event (`EXECUTOR.md` §14).
5. **Verifier-contract upgrade governance.** The foreign verifier is the trust root on the foreign side; how is it upgraded/audited without reintroducing a custodian?

---

## 8. One-paragraph summary

Bridging to smart-contract chains is the easy case: the foreign chain can verify a Zenon burn proof itself, so peg-out becomes a trustless lock-and-release with no operators, no fronting liquidity, and no challenge window — the difficulty moves to building a good light client of the foreign chain inside the executor's `Apply` (medium for Ethereum, hard for Solana). Integration is a fixed playbook: pick a light-client model, implement the `ChainVerifier` and `Source`, set a genesis anchor, deploy a lock vault + Zenon-verifier contract on the foreign chain, and wire zToken mint/burn through Settlement's existing `kind=1` outbox channel. Everything else — the bridge ledger, conservation, replay protection, the authorization object — is inherited unchanged from the shared framework, so each new chain costs a verifier and two contracts, not a whole bridge.
