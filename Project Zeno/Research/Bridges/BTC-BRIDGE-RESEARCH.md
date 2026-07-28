# Trustless BTC ⇄ Zenon Bridging via the Settlement Layer

**Document status:** Research / exploration — *non-normative*. Forward-looking; deliberately ignores Phase-1 activation limits.
**Relationship to specs:** Builds on `SPEC.md` v1.3.0 (Settlement) and `EXECUTOR.md` v0.2.0 (Executor). Where it cites on-chain behaviour it points at those documents and at current go-zenon source.
**Question being explored:** Can the Settlement layer *move* BTC between Bitcoin L1 and Zenon L1 without trusting any custodian in the process — and if so, what does the complete in/out flow look like?

---

## 1. The crux: two directions of light-client verification

Every BTC bridge reduces to two verification problems, and only one of them is hard.

| Direction | Question | Difficulty | Who solves it here |
|---|---|---|---|
| **Zenon verifies Bitcoin** | "Did this BTC payment / spend actually happen, buried under K confirmations?" | Easy | The **executor**, as an SPV light client inside the STF (`EXECUTOR.md` §12, the BTC `L1_RELAYED` worked example) |
| **Bitcoin verifies Zenon** | "Did Zenon *authorize* this BTC to move?" | Hard | The **Settlement layer** must export a succinct, finalized, verifiable authorization; the Bitcoin side consumes it (BitVM today, covenant tomorrow) |

Bitcoin script cannot run a Zenon light client, so it cannot natively release BTC "only when Zenon says so." That single fact is the whole peg-out problem, and it dictates the architecture below.

**Therefore the Settlement layer's real product is not custody — it is **provable Zenon authorization**.** Custody lives in Bitcoin script. The executor secures the observation side (mint and fraud detection); Settlement is the canonical, finalized, succinctly-provable authority on mint/burn.

This separation is what keeps the design honest: at no point does the protocol hold a pooled key whose holder could abscond.

---

## 2. Two trust tiers, one Settlement design

The Settlement/executor design is identical across both tiers. Only the Bitcoin-side enforcement of authorization changes.

- **Tier 1 — Optimistic / BitVM-style.** Buildable on Bitcoin *today*, no soft fork. Security is **1-of-N honest + economic bonds**. Fraud is caught by any single honest watcher within a challenge window.
- **Tier 2 — Covenant-verified.** Requires a Bitcoin upgrade (e.g. `OP_CAT`/`OP_CHECKTEMPLATEVERIFY`/`OP_CHECKSIGFROMSTACK` enabling proof or signature verification in script). Security is **zero trust**: BTC moves iff Zenon authorized it, enforced by Bitcoin consensus. Deletes the operators entirely.

Tier 1 is the realistic build target; Tier 2 is the endgame the design must not foreclose.

---

## 3. Roles

- **zBTC** — a ZTS token on Zenon, minted and burned **only** by the Settlement contract. (Note: this requires L2-native/bridge token issuance, which is out of Phase-1 scope per `SPEC.md` §2.1/§18.1 — a forward-looking assumption of this document.)
- **Settlement contract** — the authorization ledger and fraud court. Records mints, burns, peg-out orders, and operator bonds; verifies SPV proofs relayed to it; adjudicates disputes; slashes. Reuses the existing bonded-registration and `TimeChallenge`/`SecurityInfo` machinery (`vm/embedded/implementation/{common,bridge}.go`).
- **Executor** — SPV light client of Bitcoin inside the STF (Zenon-verifies-Bitcoin). Deterministic and replayable from L1-anchored data; itself bonded and fraud-provable per the offchain-execution spec.
- **Operators (Tier 1 only)** — a set of N who collectively hold the locked-BTC pool and front liquidity for peg-out. Security is **1-of-N**: a single honest participant suffices.
- **Watchers / relayers** — permissionless. Anyone can relay Bitcoin headers + proofs, or submit a fraud proof. Permissionless relay means censorship can only *delay*, never steal (`SPEC.md` §4.2, §6.1).

---

## 4. PEG-IN — BTC → zBTC

**Goal:** lock BTC so it can only ever leave via a Zenon-authorized peg-out (or a user refund), then mint zBTC against the proven lock.

### Tier 1 flow

```
1. User signals peg-in intent on Zenon
       → Settlement issues a deposit descriptor (binds the deposit to a Zenon recipient)

2. User sends BTC to a Taproot peg-in address with:
       • key path:    N-of-N of the operator set
       • script path: a pre-signed BitVM transaction graph (the only spendable futures)
       • script path: a user refund after timeout (if the mint never happens)

3. Relayer (permissionless) posts the funding tx header(s) + Merkle proof to Settlement

4. Executor STF SPV-verifies:
       • payment to the correct peg-in descriptor
       • correct amount
       • >= K confirmations on the canonical header chain

5. Settlement mints zBTC to the user; the UTXO is accounted into the peg pool
```

### Why no custodian is trusted

- **Mint requires proof.** zBTC cannot be minted without a real, SPV-proven BTC lock. Replay protection (already-credited outpoints) prevents double-mint — mirrors `SPEC.md` §17.3's `processedOutbox` pattern.
- **The BTC cannot be stolen.** Operators only ever *pre-sign a fixed graph of transactions* and then discard their keys. The only reachable spends are (a) an authorized, challengeable peg-out, or (b) the user's timeout refund. No signature exists for any spend outside the graph, so collusion cannot move the coins arbitrarily.
- **Trust assumption:** at least 1-of-N operators actually discarded their key. The user refund path makes a stalled mint safe for the depositor.

---

## 5. PEG-OUT — zBTC → BTC

**Goal:** burn zBTC on Zenon and release the matching BTC from the pool, with fraud catchable by any single honest watcher.

### Tier 1 flow

```
1. User calls Settlement.Redeem(amount, btc_dest)
       → zBTC is burned
       → Settlement writes a FINALIZED peg-out authorization {burnId, amount, btc_dest}
         (this record is the "Zenon truth" object the Bitcoin side must consume)

2. An operator FRONTS the BTC immediately:
       → sends `amount` to btc_dest from its own liquidity
       → the user is made whole right away (fast withdrawal)

3. The operator reclaims from the pool by asserting on Bitcoin:
       "burnId X authorized this reimbursement" (spends a BitVM connector output)

4. A challenge window opens:
       • unchallenged → operator sweeps the pool UTXO (reimbursed)
       • challenged   → the BitVM challenge-response executes the verification
                        on-chain in tiny steps; a lying operator loses its bonded
                        stake and the reimbursement is blocked

5. Settlement marks burnId reimbursed (replay protection);
   the connector output is consumed exactly once on Bitcoin
```

### Why no custodian is trusted

- The user is paid in step 2 **regardless of operator honesty downstream**.
- The trust-minimization lives in operator reimbursement: an operator who fronts a fake peg-out, or claims reimbursement without a real finalized burn, is *provably wrong* and is slashed by **any one honest watcher**.
- An operator who simply refuses to serve forfeits the fee; another operator (or a fallback servicer) takes it. Liveness degrades to "at least one operator participates," not "a specific party must act."
- **No party can both move pool BTC and avoid a matching burn.** That is the core invariant.

---

## 6. The connective tissue — this is already the spec's outbox pattern

Peg-out is **literally the Settlement outbox pattern pointed at a different chain.**

`SPEC.md` §17 already defines an outbox message with `kind = 1` (L1 withdrawal) and a permissionless `RelayMessage` that releases it **only** from a `FINALIZED` batch, with inclusion-proof verification and replay protection. The BTC peg-out *is* that message. The only thing that changes is the **consumer**:

| | Native ZTS withdrawal (in spec today) | BTC peg-out (this document) |
|---|---|---|
| Authorization object | `kind = 1` outbox message | `kind = 1` outbox message (same) |
| Released from | `FINALIZED` batch after withdrawal delay | `FINALIZED` batch after withdrawal delay (same) |
| Consumer / releaser | `RelayMessage` releases ZTS from Settlement custody on Zenon | BitVM verifier (Tier 1) or covenant (Tier 2) releases BTC on Bitcoin |
| Replay protection | `processedOutbox` set (§17.3) | `processedOutbox` set + single-use Bitcoin connector output |

What the Settlement layer must **export** to the Bitcoin side is a succinct, canonical proof that *"burn X is in finalized Zenon state."* The reserved `proofData` field in the batch commitment (`SPEC.md` §19, §24) — the Phase-3 validity-proof hook — is exactly the vehicle: a SNARK over the STF proving the burn is committed under a finalized `postStateRoot`/`outboxRoot`. BitVM can verify a SNARK-verifier execution; a covenant could check it directly.

**One state machine, two verification directions:** the executor secures BTC→Zenon observation (mint, fraud detection); the outbox + finality + validity-proof machinery — already specced — is the Zenon→BTC authorization channel. It simply gains a Bitcoin-side reader.

---

## 7. The two fraud loops (Tier 1)

Both are adjudicated by the STF / on-chain verification, never by a vote. Every decision is a deterministic function of relayed Bitcoin data plus Settlement state.

### A. Redemption enforcement (per peg-out)

```
INITIATED  → user redeems; zBTC burned; authorization finalized; operator must reimburse legitimately
PROVING    → operator claims reimbursement against burnId; anyone may relay supporting/contradicting BTC proofs
SETTLED    → claim verified (matches a finalized burn, correct amount, not already reimbursed) → operator sweeps pool UTXO
DEFAULTED  → challenge window elapses with a disproven/absent claim → operator bond slashed; pool protected
DISPUTED   → a watcher contests a bogus claim → BitVM challenge-response resolves it deterministically
```

### B. Custody policing (continuous watchtower)

```
1. Each pool UTXO is tracked in Settlement state (recorded at mint / via SPV)
2. A spend is AUTHORIZED iff it matches a SETTLED peg-out or a pre-declared, SPV-confirmed rebalance
3. Executor + any watcher monitor Bitcoin for spends of tracked UTXOs
4. An unauthorized spend → anyone submits SPV proof of the spend + absence of matching authorization
       → slash the operator bond, halt the operator, distribute pro-rata to that pool's zBTC backers
```

The executor here is a **pure SPV oracle with no discretion**; because its verdicts are deterministic over L1-anchored data, the executor itself need not be trusted once the offchain layer has its own fraud proofs.

---

## 8. Tier 2 — covenant endgame (deletes the operators)

If Bitcoin gains the ability to verify a proof in-script:

```
PEG-IN:  BTC is locked under a covenant:
         "spendable only by a transaction carrying a valid proof of a finalized
          Zenon peg-out authorization for this amount + destination,
          OR a user refund after timeout."

PEG-OUT: user burns zBTC
         → Settlement emits a validity proof of the burn (the proofData hook)
         → anyone submits the Bitcoin spend carrying that proof
         → the covenant verifies it in Bitcoin consensus
         → BTC is released to btc_dest
```

No operators, no bonds, no fronting, no challenge window, no 1-of-N. The BTC moves **if and only if** Zenon authorized it. The Settlement layer's role is unchanged — be the finalized, succinctly-provable authority on burns. Only Bitcoin's ability to check the proof changes.

---

## 9. Trust analysis summary

| Property | Tier 1 (BitVM, today) | Tier 2 (covenant, endgame) |
|---|---|---|
| Mint correctness (no mint without locked BTC) | SPV-enforced ✓ | SPV-enforced ✓ |
| Custody (BTC cannot be stolen) | Pre-signed graph + 1-of-N honest + bonds | Covenant-enforced, 0 trust |
| Peg-out correctness (BTC out ⇒ matching burn) | Optimistic fraud proof, 1-of-N watcher | Covenant-verified, 0 trust |
| Censorship | Permissionless relay/challenge → delay only | Permissionless → delay only |
| User-facing withdrawal speed | Instant (operator fronts) | Proof-time + 1 Bitcoin confirmation |
| Bitcoin changes required | None | Soft fork (covenants) |

The residual Tier-1 assumption collapses to: **each pool's bond value ≥ the BTC it secures, and at least one honest watcher relays fraud within the challenge window.** That is the optimistic-rollup / BitVM trust model — no privileged custodian, which is the decisive improvement over the existing TSS bridge (`vm/embedded/implementation/bridge.go`).

---

## 10. Reused vs. new machinery

**Reused (exists or already specced):**

- Executor SPV light client over `L1_RELAYED` inputs — `EXECUTOR.md` §12.
- Permissionless relay + force-inclusion + per-domain contiguity — `SPEC.md` §4.2, §4.6, §6.1.
- Outbox `kind = 1` withdrawals + `RelayMessage` + `processedOutbox` replay protection — `SPEC.md` §17.
- Finality / withdrawal delay as the challenge window — `SPEC.md` §21.
- `proofData` validity-proof hook for the succinct Zenon→BTC attestation — `SPEC.md` §19, §24.
- Bonded registration + `TimeChallenge`/`SecurityInfo` admin/slashing patterns — `vm/embedded/implementation/{common,bridge,sentinel}.go`.
- SHA256 hashlock support (for any HTLC-flavored sub-step) — `vm/embedded/{definition,implementation}/htlc.go` (`HashTypeSHA256`, `crypto.HashSHA256`).

**New (must be built):**

- zBTC ZTS issuance gated on Settlement mint/burn (token-issuance authority — beyond Phase 1).
- The BitVM transaction-graph construction and the pre-signed peg-in address template (Tier 1).
- The Bitcoin-side verifier: BitVM challenge-response circuit (Tier 1) or covenant script (Tier 2) that consumes the Settlement validity proof.
- Operator set membership, bonding sizing, and rebalance pre-declaration logic (Tier 1).
- The SPV STF for the BTC domain (PoW/linkage/difficulty/reorg + Merkle inclusion) — reserved `L1_RELAYED` work.

---

## 11. Open questions

1. **Validity-proof scope.** Exactly what must the `proofData` SNARK attest for the Bitcoin side — full STF correctness, or just "burnId committed under finalized root"? The narrower the statement, the smaller the BitVM circuit.
2. **Bond denomination.** Operator/pool bonds must be in an asset uncorrelated with BTC (not zBTC — circular). ZNN/QSR or a basket? How is over-collateralization sized against BTC price moves within the challenge window?
3. **Peg-in liveness vs. key deletion.** The N-of-N pre-signed-graph + key-deletion ceremony is the trust root for Tier 1 peg-in. How is key deletion attested, and how does the set rotate without re-locking every UTXO?
4. **Reorg depth coupling.** The Bitcoin K-confirmation depth, the Zenon withdrawal delay, and the BitVM challenge window must be jointly chosen so no peg-out finalizes over a reorg-able burn (`EXECUTOR.md` §14, the `confirmationDepth` open question).
5. **Rebalancing.** Consolidating many small pool UTXOs is itself a pool spend; it must be pre-declared and SPV-confirmed so the watchtower (loop B) does not read it as theft.
6. **Fee handling.** Bitcoin fees for fronting and reclaim are operator costs; how are they priced into the peg-out fee without a trusted price oracle?

---

## 12. One-paragraph summary

The Settlement layer can be the mover of BTC across chains, but its product is **provable authorization, not custody.** The executor already solves Zenon-verifying-Bitcoin (securing mint and powering fraud proofs); the hard half is Bitcoin-verifying-Zenon, which the Settlement layer answers by exporting a finalized, succinct proof of each burn through the very same outbox/finality/`proofData` machinery the spec already defines for ZTS withdrawals. Custody stays in Bitcoin script: a pre-signed BitVM graph with bonded operators and 1-of-N honest watchers today, a covenant that checks the proof directly tomorrow. In both tiers there is no privileged custodian — the decisive improvement over a TSS federation — and the path from the optimistic build to the zero-trust endgame requires no change to the Settlement design, only a Bitcoin-side reader upgrade.
