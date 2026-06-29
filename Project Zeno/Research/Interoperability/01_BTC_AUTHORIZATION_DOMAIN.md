# Zeno BTC Authorization Domain — Minimal Frontier Design

## 1. Status and purpose

**Status.** Frontier research. Non-normative.

**Phase status.** Forward-looking. The design depends on machinery that is reserved or out of scope today:

- `inputSource = L1_RELAYED` (SPEC.md §6.1) is a reserved input class, not active in Phase 1, which is `L1_NATIVE` only.
- Bridge-token issuance authority for a zBTC ZTS (SPEC.md §2.1, §18.1) is out of Phase 1 scope.
- Permissionless relayer and watchtower software for a BTC verifier domain does not yet exist in-tree.
- The Bitcoin-side BitVM machinery (transaction graph, connector outputs, challenge protocol) is external work.

This document does **not** claim Phase 1 activation. It is a forward-looking implementation sketch describing the simplest design that combines Project Zeno Domain Settlement with a Bitcoin-side BitVM bridge.

**Purpose.** Define the simplest Zeno-native BTC Authorization Domain capable of verifying Bitcoin deposits, minting and burning zBTC through Settlement, and exporting finalized withdrawal authorizations to a Bitcoin-side enforcement layer.

**Governing document.** SPEC.md governs on conflict. Where this document and SPEC.md disagree, SPEC.md wins. Where this document references concepts not yet in SPEC.md, those references are speculative and labeled as such.

**Commit discipline.** This document is not a roadmap commitment, not a product claim, not a production bridge claim, and not a representation that any Citrea or Clementine code is being integrated into Zenon. The references to BitVM-style and Clementine-style design are external pattern references only.

---

## 2. One-sentence thesis

The simplest viable design is a **Zeno BTC Authorization Domain** that verifies Bitcoin deposits via SPV, mints and burns zBTC through Settlement, emits finalized withdrawal authorizations from the outbox, and lets a BitVM-style Bitcoin bridge layer, using Clementine as an external reference pattern, enforce the matching BTC release or operator reimbursement.

---

## 3. Core idea in plain language

The system splits cleanly across three roles. Each role does one thing and does it within the trust model of the chain it lives on.

- **Zenon side = the brain, the court, the authorization layer.**
  Zenon decides whether a BTC deposit is real (by SPV-verifying Bitcoin proofs inside a domain), whether a zBTC mint is allowed, whether a zBTC burn finalized, and what the finalized burn authorizes on the Bitcoin side. Zenon does not move BTC. It produces canonical, finalized truth about authorization.

- **Bitcoin side = the vault, the custody and enforcement layer.**
  BTC stays in Bitcoin script. The vault is a Taproot output constrained by a pre-signed BitVM transaction graph (and, in the endgame, by a covenant). The vault constrains BTC movement to pre-defined paths, where invalid release or reimbursement claims are challengeable during a dispute window.

- **Relayers and watchers = the couriers and the security cameras.**
  Relayers move Bitcoin proofs into Zenon and move finalized Zenon authorization data out to the Bitcoin-side operator and watcher tooling. Watchers monitor both sides for inconsistency: an operator claiming reimbursement without a matching finalized burn, or a vault UTXO spend that does not match any settled peg-out. Relay is permissionless. Censorship can delay, but cannot steal, if at least one honest relayer eventually submits.

Two things are explicitly **not** true under this design:

1. Zenon does not custody BTC. There is no pooled Zenon-held private key that signs BTC spends. Custody lives in Bitcoin script.
2. Bitcoin does not natively verify Zenon today. Bitcoin script cannot run a Zenon light client. The enforcement gap is closed by the BitVM transaction graph plus economic bonds plus the 1-of-N honest watcher assumption. Replacing that with a covenant that directly verifies a Zenon validity proof is the Tier 2 endgame, not the MVP.

---

## 4. Architecture overview

```
                            Bitcoin L1
                                |
                                | deposits / vault spends / payouts
                                v
                    +---------------------------+
                    |  Relayer / Watcher Service |
                    +---------------------------+
                                |
                                | headers + Merkle proofs + fraud evidence
                                v
                    +---------------------------+
                    |   BTC Verifier Domain      |   Zenon side
                    |   (SPV light client,       |
                    |    deterministic STF)      |
                    +---------------------------+
                                |
                                | verified Bitcoin facts
                                v
                    +---------------------------+
                    |   zBTC Settlement Module   |
                    |   (mint, burn, accounting, |
                    |    outbox authorization)   |
                    +---------------------------+
                                |
                                | finalized withdrawal authorization
                                v
                    +---------------------------+
                    |  Relayer / Watcher Service |
                    +---------------------------+
                                |
                                | authorization data, claim challenges
                                v
                    +---------------------------+
                    |   Bitcoin BitVM Vault      |   Bitcoin side
                    |   (Taproot + pre-signed    |
                    |    graph, operators,       |
                    |    challenge window)       |
                    +---------------------------+
                                |
                                | enforced release / operator reimbursement
                                v
                            Bitcoin L1
```

- **BTC Verifier Domain.** A deterministic domain whose STF consumes Bitcoin headers and Merkle proofs as `L1_RELAYED` inputs and produces verified Bitcoin facts. Per "Bring Your Own Runtime," a domain is a runtime plus state-mapping plus operator registration, not a separate L1.
- **zBTC Settlement Module.** The authorization ledger. Mints zBTC against proven deposits, burns zBTC on user redemption, enforces conservation, and emits outbox-formatted withdrawal authorizations.
- **Relayer / Watcher Service.** A permissionless off-chain service shuttling proofs and authorizations between Bitcoin and Zenon, plus monitoring both sides for fraud.
- **Bitcoin BitVM Vault.** External Bitcoin-side machinery. A Taproot output constrained by a pre-signed BitVM transaction graph, operator bonds, connector outputs, and a challenge window.

---

## 5. Components

### 5.1 BTC Verifier Domain

A specialized Zenon domain. Not a new L1 and not a base-chain consensus component. Per "Bring Your Own Runtime," any deterministic execution environment can be wrapped as a domain that settles to Zenon L1. The BTC Verifier Domain is one such environment, specialized for Bitcoin light-client verification.

**Responsibilities (MVP).**

- Accept Bitcoin block headers via `L1_RELAYED` input.
- Verify header linkage (each header references the previous block hash).
- Verify proof-of-work and difficulty rules. The MVP **MAY** simplify difficulty enforcement (e.g. trust difficulty as posted, validate retarget arithmetic later); a production implementation **MUST** enforce the full PoW and retarget rules. Any MVP that does not fully validate Bitcoin difficulty **MUST** be treated as a local or testnet demonstration only and **MUST NOT** be described as validating Bitcoin consensus.
- Verify transaction Merkle inclusion against the committed header chain.
- Verify that a deposit output matches a registered peg-in descriptor (script template + amount + binding to a Zenon recipient).
- Verify confirmation depth meets a configured threshold `K`.
- Reject deposits whose outpoints have already been processed (replay protection).
- Later: verify spend proofs for tracked vault UTXOs to detect unauthorized custody movement.

**Status.** The domain executor is a deterministic SPV light client. Its verdicts are functions of L1-anchored relayed data plus domain state. In Phase 1 terms, this is bonded attestation: the executor is trusted to compute correctly within the SPEC.md §1 trust model until fraud-proof machinery is available.

**Bound.** This is a domain/executor role. It does not extend Zenon base-chain consensus. The momentum chain does not run SPV. SPV runs inside the domain STF.

### 5.2 zBTC Settlement Module

The authorization ledger. zBTC is a ZTS token whose mint and burn authority is reserved to this module. The exact token issuance mechanism is not specified here; bridge-token issuance is out of Phase 1 scope per SPEC.md §2.1, §18.1, and is treated as a forward-looking dependency.

**Responsibilities.**

- Mint zBTC only against a BTC deposit proven by the BTC Verifier Domain.
- Burn zBTC on a user redemption request that supplies a Bitcoin destination.
- Enforce no double mint (per-outpoint replay set).
- Enforce no double withdrawal (per-burnId replay set; the existing outbox `processedOutbox` pattern in SPEC.md §17.3 is the template).
- Track total BTC locked versus total zBTC outstanding, enforcing the per-(domain, asset) conservation invariant (SPEC.md §18).
- Emit finalized withdrawal authorization objects via the outbox channel (SPEC.md §17, `kind = 1`).

**Suggested state fields (illustrative, non-normative).**

```
processedDeposits      : set<bitcoinOutpoint>
processedWithdrawals   : set<burnId>
totalBtcLocked         : sats
totalZbtcMinted        : sats
totalZbtcBurned        : sats
pendingWithdrawals     : map<burnId, WithdrawalAuthorization>
vaultUtxos             : set<bitcoinOutpoint>    // tracked custody set
operatorBonds          : map<operatorId, BondRecord>
```

Field names are sketches. The authoritative naming and serialization belong in a future normative spec.

### 5.3 Withdrawal Authorization Object

The structured, finalized record that the Bitcoin-side system consumes. This is the "Zenon truth" object.

```
WithdrawalAuthorization {
    burnId             : opaque unique id
    amountSats         : uint64
    btcDestination     : bitcoin address or script
    zenonAccount       : account that burned zBTC
    domainId           : the BTC Authorization Domain id
    batchId            : the batch in which the burn was committed
    outboxIndex        : position in the outbox for inclusion proofs
    finalizedAt        : momentum height (or equivalent finality marker)
    authorizationRoot  : outbox root committed in the finalized batch
    proofData          : OPTIONAL / FUTURE  // SNARK over STF, Phase 3 hook
}
```

The object is emitted into the outbox under the existing `kind = 1` withdrawal message slot. The Bitcoin-side reader consumes:

- in the MVP: the finalized outbox entry plus the inclusion proof against `authorizationRoot`;
- in the endgame: a SNARK in `proofData` proving the burn is committed under a finalized `postStateRoot` / `outboxRoot`, suitable for direct on-chain Bitcoin verification (Tier 2 covenant).

`proofData` is reserved. It is not required for the MVP.

### 5.4 BTC Relayer / Watcher Service

Permissionless off-chain software. The DS relayer/watcher role applied to Bitcoin. This is not a browser extension; it is a service that may run anywhere, by anyone.

**Responsibilities.**

- Watch Bitcoin for deposits to registered peg-in descriptors and for spends of tracked vault UTXOs.
- Build SPV proofs (block header chain + Merkle inclusion path).
- Submit Bitcoin proofs into the BTC Verifier Domain via the L1 input channel.
- Watch Zenon for finalized withdrawal authorizations on the BTC Authorization Domain outbox.
- Pass authorization data to Bitcoin-side operators and watchers in a form they can consume.
- Monitor operator reimbursement claims on Bitcoin.
- Submit fraud evidence or challenge data when an operator claim does not match a finalized Zenon authorization, or when a vault UTXO is spent without a matching settled peg-out.
- Relay Bitcoin payout and reimbursement proofs back into Zenon so Settlement can mark withdrawals completed.

**Trust note.** Relayers are not trusted for correctness. Proofs they submit are verified inside the domain STF. Relayers can be censored or delayed but cannot lie. Liveness degrades to "at least one honest relayer eventually submits."

### 5.5 Bitcoin BitVM Vault

External Bitcoin-side machinery. The hardest part of the system, and the part Zenon does not control.

**Responsibilities.**

- Hold the locked BTC pool in Bitcoin script.
- Constrain spend paths using Taproot script paths and a pre-signed BitVM transaction graph. Pre-signed graph plus operator key deletion is the trust root for Tier 1 custody.
- Allow valid peg-out reimbursement: an operator who fronted BTC to a redeeming user reclaims from the pool by asserting a claim referencing a `burnId`.
- Allow challenge paths: a watcher who proves the claim does not correspond to a finalized Zenon burn triggers the configured operator slashing path and blocks the reimbursement.
- Allow timeout / refund paths so depositors are not trapped if mint never happens.
- Allow pre-declared, SPV-confirmed rebalance paths so vault UTXOs can be consolidated without watchers reading the consolidation as theft.
- Prevent arbitrary custodian spend: no key combination can move BTC outside the pre-signed graph.

**Note.** The MVP does not build this. It is the future and external work. Phases C and D below stage it.

---

## 6. Peg-in flow: BTC to zBTC

Step-by-step:

1. **User requests a deposit descriptor from Zenon.**
   The user signals peg-in intent. The BTC Authorization Domain (or a registration helper) returns a Bitcoin deposit descriptor that binds the deposit to the user's Zenon recipient account.

2. **User sends BTC to the Bitcoin vault peg-in address.**
   The address is a Taproot output whose only spendable futures are the pre-signed BitVM graph (operator-cooperative path with key deletion) plus the user's timeout refund.

3. **Relayer submits Bitcoin headers and a Merkle proof to the BTC Verifier Domain.**
   The proof contains the funding transaction and the header chain in which it is buried.

4. **The BTC Verifier Domain validates:**
   - the transaction is included in a header on the domain-accepted Bitcoin header chain (Merkle path);
   - the output script matches the registered peg-in descriptor;
   - the amount matches the descriptor's expected value;
   - the confirmation depth meets the threshold `K`;
   - the outpoint has not been processed before.

5. **Settlement mints zBTC** to the user's Zenon account.

6. **The deposit outpoint is marked processed** in `processedDeposits`.

**Core invariant.** **No valid BTC proof, no zBTC mint.** The mint side has no privileged custodian path. A mint without a real, SPV-proven, descriptor-matching deposit that has not already been credited is impossible by construction.

---

## 7. Peg-out flow: zBTC to BTC

Step-by-step:

1. **User burns zBTC and provides a Bitcoin destination.**
   The user calls a redeem function on the BTC Authorization Domain. zBTC supply decreases by `amountSats`. A `burnId` is generated.

2. **Settlement creates a withdrawal authorization.**
   A `WithdrawalAuthorization` object is added to the outbox under `kind = 1`.

3. **The authorization finalizes after the required delay.**
   The outbox entry becomes releasable only once its batch is `FINALIZED` per SPEC.md §17, §21. Before finalization the authorization MUST NOT be acted upon by the Bitcoin-side machinery.

4. **A relayer carries the finalized authorization to the Bitcoin side.**
   Operators and watchers ingest the authorization plus its inclusion proof against `authorizationRoot`.

5. **An operator fronts BTC** to `btcDestination` from its own liquidity. The user is made whole immediately if an operator elects to front liquidity. The operator now holds a claim against the vault pool for `amountSats` referenced by `burnId`.

6. **A challenge window opens.** Watchers verify the operator's claim against the finalized Zenon authorization. If the claim does not match a finalized burn, references an already-reimbursed `burnId`, or asserts an incorrect amount or destination, any single honest watcher submits a challenge.

7. **If the claim survives the window unchallenged or wins a challenge**, the operator sweeps a pool UTXO via the BitVM connector output and is reimbursed. If the claim fails, the operator's bond is slashed and the reimbursement is blocked.

8. **A Bitcoin payout / reimbursement proof is relayed back to Zenon.**
   The SPV proof of the reimbursement spend is submitted to the BTC Verifier Domain.

9. **Zenon marks the withdrawal completed and reimbursed.**
   `processedWithdrawals` is updated. The pool UTXO accounting is updated.

**Core invariant.** **No finalized Zenon burn authorization, no valid BTC reimbursement.** An operator claiming pool BTC without a matching finalized burn should be provably wrong on relayed Bitcoin data plus Settlement state, assuming the BitVM challenge protocol can consume the required Zenon authorization evidence, and is slashed by any single honest watcher within the challenge window.

---

## 8. Minimal state machine

A single peg-out passes through the following states. The MVP does not need to encode every state explicitly; the diagram is the conceptual contract between Zenon and the Bitcoin-side machinery.

```
DEPOSIT_REQUESTED
        |
        v
BTC_LOCK_PROVEN
        |
        v
ZBTC_MINTED
        |
        v
ZBTC_BURNED
        |
        v
WITHDRAWAL_AUTH_FINALIZED
        |
        v
BTC_PAYOUT_CLAIMED
        |
        v
CHALLENGE_WINDOW
        |
        +--> SETTLED  ----> COMPLETED
        |
        +--> DISPUTED ----> SLASHED
```

- **DEPOSIT_REQUESTED.** User has a deposit descriptor; no BTC has moved yet.
- **BTC_LOCK_PROVEN.** A funding transaction matching the descriptor is buried under `K` confirmations and a valid SPV proof has been accepted by the BTC Verifier Domain.
- **ZBTC_MINTED.** Settlement has minted zBTC to the user.
- **ZBTC_BURNED.** The user has redeemed; zBTC supply has decreased; a `burnId` exists.
- **WITHDRAWAL_AUTH_FINALIZED.** The outbox entry has finalized. The Bitcoin-side machinery may now act on it.
- **BTC_PAYOUT_CLAIMED.** An operator has fronted BTC and posted a reimbursement claim on Bitcoin.
- **CHALLENGE_WINDOW.** The window during which any watcher may contest the operator's claim. Window duration is jointly constrained by Zenon withdrawal delay, Bitcoin reorg depth `K`, and the BitVM challenge protocol's worst-case round trip.
- **SETTLED.** Claim survived or won. Operator sweeps the pool UTXO.
- **DISPUTED.** A watcher successfully proved the claim is invalid.
- **COMPLETED.** Bitcoin payout proof has been relayed back; Settlement records the burn as fully reimbursed.
- **SLASHED.** Operator bond has been slashed; pool BTC is protected; the user remains whole (paid in step 5 of §7).

---

## 9. MVP implementation phases

Phases are scoped so that each one ends in a working, demonstrable artifact. No phase requires the next phase to be complete.

### Phase A: Deposit-only demo

**Goal.** Prove that a Bitcoin deposit, witnessed by a Bitcoin proof, mints a test zBTC token on a Zenon test network.

**Build.**

- Header relay for the BTC Verifier Domain.
- Merkle inclusion proof verification inside the domain STF.
- Peg-in descriptor registration and deposit-output match check.
- `processedDeposits` set with replay protection.
- A test zBTC mint path gated on a proven deposit.

**Out of scope for Phase A.** Burn, withdrawal, operators, Bitcoin-side vault, challenge windows.

### Phase B: Burn authorization demo

**Goal.** Prove that a zBTC burn produces a finalized, outbox-formatted withdrawal authorization that a relayer can read.

**Build.**

- A burn function on the BTC Authorization Domain.
- The `WithdrawalAuthorization` object with `burnId`, `amountSats`, `btcDestination`, `authorizationRoot`, and outbox indexing.
- Outbox-style indexing using the existing SPEC.md §17 `kind = 1` slot.
- `processedWithdrawals` set with replay protection.
- A relayer process that reads a finalized authorization and prints / publishes it.

**Out of scope for Phase B.** Any Bitcoin-side enforcement. The relayer only reads.

### Phase C: Mock Clementine payout

**Goal.** Simulate the Bitcoin-side operator reimbursement and watcher challenge logic without touching real BTC.

**Build.**

- A fake operator process that produces reimbursement claims tied to `burnId`s.
- A fake challenge window (timer).
- A fake vault state machine that processes claims and slashing.
- A watcher process that verifies the operator's claim against the finalized Zenon authorization and submits challenges when the claim is inconsistent.

The goal is the protocol shape, not Bitcoin script. This is where the Tier 1 enforcement logic is debugged in isolation.

### Phase D: Bitcoin signet/testnet BitVM path

**Goal.** Replace the mocks with real Bitcoin-side scripts on signet or testnet.

**Build.**

- A Taproot vault template (peg-in address, pre-signed graph endpoints).
- A BitVM / Clementine-style claim and challenge path: connector outputs, claim transactions, the on-chain step-verification game.
- Operator-fronting logic over real signet BTC.
- Watchtower challenge logic.
- Payout proof relay back into Zenon so Settlement can close the loop.

**Out of scope for Phase D.** Mainnet deployment, production bond sizing, key-deletion ceremony at production trust level, covenant (Tier 2) work.

---

## 10. What to fork or reuse

**Do not fork BitVM as a Zenon runtime.** BitVM is Bitcoin-side machinery. Wrapping it as a Zenon execution environment is a category error and the wrong layer.

Instead:

- **Fork or adapt the BitVM / Clementine architecture** for the Bitcoin-side vault and challenge layer. This is external work that lives on Bitcoin.
- **Build (or fork from a Bitcoin SPV library) a BTC verifier domain** for Zenon. Headers, PoW, Merkle inclusion, confirmation depth, reorg handling.
- **Fork or adapt relayer / watchtower concepts** from BitVM bridge ecosystems. Permissionless relay, fraud-proof relay, claim monitoring.
- **Keep Settlement as the authorization ledger.** Do not reinvent the outbox, the finality model, or `processedOutbox`. They already exist in SPEC.md §17 and §21. The BTC peg-out is a `kind = 1` outbox message with a Bitcoin-side reader.

The framing:

> **Fork the pattern, not the whole chain.**

The Citrea and Clementine designs are reference patterns for how to build a BitVM bridge against an external authorization source. Nothing in this design pulls Citrea or Clementine code into Zenon.

### 10.5 Simplest MVP boundary

The first implementation should not attempt to build a production bridge. The smallest useful implementation is **deposit-only verification plus mock burn authorization**. The purpose is to prove that a Bitcoin event can become a verified domain fact, and that a zBTC burn can become a finalized outbox authorization. Bitcoin-side BitVM enforcement should be mocked until the Zenon-side accounting and proof format are stable. Treat any work past that point (signet vault scripts, real challenge games, operator fronting) as a separate workstream that begins only after Phases A and B are settled.

---

## 11. Security assumptions

Assumptions split cleanly by layer. Mixing them is the most common source of incorrect security claims about BitVM-style bridges.

### Zenon-side assumptions

- The BTC Verifier Domain correctly validates Bitcoin proofs (headers, PoW where enforced, Merkle inclusion, confirmation depth, outpoint freshness).
- Settlement correctly enforces mint, burn, replay, and conservation rules.
- Withdrawal authorizations are finalized before any Bitcoin-side machinery acts on them. Acting on a non-finalized authorization is a protocol violation.
- The Phase 1 SPEC.md §1 trust model applies: bonded executor honesty is required for per-account correctness until Phase 2 fraud proofs. Aggregate solvency per (domain, asset) is on-chain enforced.

### Bitcoin-side assumptions

- The pre-signed BitVM transaction graph correctly constrains all spendable futures of every pool UTXO.
- Operator keys are actually deleted after the pre-signing ceremony so that no key combination can produce a signature outside the graph. This is the trust root for Tier 1 custody.
- At least one honest watcher challenges within the challenge window. This is the 1-of-N honest assumption that BitVM-style bridges share.
- Operator bonds are large enough relative to the BTC they secure that misbehavior is unprofitable. Bond sizing is an open problem (see §13).
- Challenge windows are long enough to absorb worst-case Bitcoin congestion and BitVM challenge-response round trips.
- Bitcoin reorg assumptions: the confirmation depth `K`, the Zenon withdrawal delay, and the BitVM challenge window are jointly chosen so a peg-out never finalizes over a reorg-able burn.

### Relayer assumptions

- Relayers can be censored or delayed, but not trusted for correctness. All relayed data is verified inside a deterministic STF (Zenon side) or by Bitcoin script (BitVM side).
- The system is live as long as at least one honest relayer eventually submits the relevant proof or challenge.
- Permissionless relay mitigates liveness censorship at the cost of latency, never at the cost of safety.

---

## 12. What this design does not solve yet

Explicit negative boundaries. These are not minor caveats; they are the open frontier of the design.

- Does **not** make Bitcoin natively verify Zenon today. Bitcoin script cannot run a Zenon light client. The Tier 1 design closes the gap with BitVM optimistic enforcement.
- Does **not** remove the need for Bitcoin-side BitVM or covenant machinery. The Bitcoin side has to exist independently.
- Does **not** define production bond sizing. Bond denomination and over-collateralization remain open (see §13.5, §13.6).
- Does **not** solve the operator key-deletion ceremony at production trust level. Attesting key deletion and rotating the operator set without re-locking every UTXO is an unresolved problem.
- Does **not** solve UTXO rebalancing. Consolidating many small pool UTXOs is itself a vault spend and must be reconciled with the watchtower loop so it is not read as theft.
- Does **not** specify the final scope of the `proofData` SNARK. The narrower the statement, the smaller the BitVM verification circuit. Whether the MVP needs `proofData` at all is open.
- Does **not** provide Phase 1 activation. `L1_RELAYED`, zBTC issuance authority, and the relayer/watchtower software stack are all out of scope for Phase 1 as specified in SPEC.md v1.3.0.
- Does **not** claim mainnet readiness. The MVP phases above terminate at signet/testnet.
- Does **not** eliminate all liveness assumptions. Liveness degrades gracefully to "at least one honest relayer / watcher / operator participates," but it is not unconditional.

---

## 13. Open questions

These are the questions a normative spec for this domain must answer before any production claim is made.

1. **Bitcoin header and difficulty rules.** What exact PoW and retarget validation is required for MVP versus production? Can the MVP simplify to header-linkage and trusted difficulty, deferring full retarget enforcement?

2. **Minimum safe confirmation depth.** What value of `K` is acceptable for the MVP, and how does it scale with the BTC value at stake per peg-in?

3. **What the withdrawal authorization must prove for BitVM consumption.** The full STF, or only "burnId committed under a finalized outbox root for this domain"? The narrower scope is implementable sooner; the broader scope is closer to Tier 2.

4. **Is `proofData` required in the first version?** Or can the MVP rely entirely on the finalized outbox authorization plus watcher verification, with `proofData` deferred to a Phase 3 hook?

5. **Operator bond denomination.** ZNN, QSR, BTC, a basket, or something else? BTC is circular (the bond would correlate with what it secures). ZNN/QSR introduces a cross-asset price risk inside the challenge window.

6. **Bond sizing relative to vault BTC.** What over-collateralization ratio protects against price moves within the challenge window? Worst-case BTC moves up while bond asset moves down.

7. **Operator rotation.** How does the operator set rotate without re-locking every pool UTXO under a new pre-signed graph? Without a clean rotation primitive, the operator set is effectively static.

8. **Vault UTXO rebalancing.** How is a consolidation transaction pre-declared and SPV-confirmed in a way the watchtower loop accepts? The naive case looks identical to theft.

9. **Challenge window duration.** What is the exact length, and how is it derived from Bitcoin congestion bounds, BitVM challenge protocol round trips, and Zenon withdrawal delay?

10. **Bitcoin fee pricing.** Bitcoin fees for fronting and reimbursement are operator costs. How are they priced into the peg-out fee without a trusted price oracle?

11. **Failure modes if no operator fronts BTC.** If no operator chooses to front a peg-out, what happens? Does the user wait? Is there a fallback servicer? Does the user have a direct claim path against the pool after a timeout?

12. **Fallback and refund path.** What is the user's refund path when peg-in mint never happens (timeout refund script), and what is the user's recourse path when peg-out has no operator participant?

---

## 14. Summary

The Zeno BTC Authorization Domain is the simplest way to combine Project Zeno Domain Settlement with a Citrea/Clementine-style BitVM bridging architecture. Zenon does not custody BTC. Zenon verifies Bitcoin deposits inside a specialized domain, accounts for zBTC through Settlement, finalizes burn authorizations through the outbox, and exports those authorizations to a Bitcoin-side BitVM enforcement layer. The Bitcoin-side machinery, built and operated outside Zenon, enforces the matching BTC release or operator reimbursement, with watchers catching invalid claims inside a challenge window. The design is modular: Zenon is the authorization layer, Bitcoin is the vault, and relayers and watchers carry and police the evidence between them. None of this is Phase 1 active. It is a forward-looking design target whose components depend on machinery (`L1_RELAYED`, bridge-token issuance, relayer/watchtower tooling, the Bitcoin-side BitVM stack) that does not yet exist in tree.

---

## 15. Minimal implementation boundary

The sections from here on are addressed to implementers. They are a build target, not theory.

The first implementation **MUST** include:

1. Bitcoin header relay (`SubmitBtcHeaders` input acceptance and storage).
2. Bitcoin Merkle proof verification inside the BTC Verifier Domain.
3. Deposit descriptor matching (registered descriptor lookup; output script and amount comparison).
4. `processedDeposits` replay protection.
5. Test zBTC mint gated on a proven deposit.
6. zBTC burn function.
7. `WithdrawalAuthorization` creation on burn.
8. Finalized outbox entry readable by a relayer.

The first implementation **MUST NOT** include:

1. Mainnet BTC.
2. A production BitVM vault.
3. Real operator fronting of BTC.
4. Production bond sizing or production slashing parameters.
5. Covenant assumptions.
6. Any external description as "trustless," "production-ready," "non-custodial bridge," or "mainnet bridge."

The boundary above is the binding scope of the first deliverable. Work that goes past it is a separate workstream and belongs in a separate spec.

---

## 16. Minimal interface shapes

Illustrative message shapes for the first implementation. Field names are sketches. Types are conceptual (sats are uint64, header bytes are raw Bitcoin serialization, etc.). The authoritative encoding belongs in a future normative spec. All shapes here are non-normative.

```
SubmitBtcHeaders {
    headers        : array<rawBitcoinHeader>   // contiguous, parent-linked
    anchorHeight   : uint32                    // height of headers[0]
}
```

```
SubmitBtcDepositProof {
    txBytes              : bytes               // raw Bitcoin transaction
    outputIndex          : uint32              // index of the deposit output
    merkleProof          : array<bytes>        // inclusion path to header
    blockHeader          : rawBitcoinHeader    // header containing the tx
    headerHeight         : uint32
    depositDescriptorId  : opaque              // registered peg-in descriptor id
}
```

```
MintFromDeposit {                              // internal Settlement transition
    depositOutpoint      : (txid, vout)
    amountSats           : uint64
    zenonRecipient       : zenonAccountId
    depositDescriptorId  : opaque
    provingBatchId       : opaque              // batch in which proof was accepted
}
```

```
BurnForBtcWithdrawal {                         // user-initiated
    amountSats           : uint64
    btcDestination       : bytes               // raw script or address bytes
    zenonAccount         : zenonAccountId
}
```

```
FinalizeWithdrawalAuthorization {              // emitted as a finalized outbox entry
    burnId               : opaque
    batchId              : opaque
    outboxIndex          : uint32
    authorizationRoot    : hash
    finalizedAt          : momentumHeight
}
```

```
MarkBtcPayoutObserved {                        // relayer-submitted, SPV-verified
    burnId               : opaque
    bitcoinTxBytes       : bytes               // raw payout transaction
    outputIndex          : uint32
    merkleProof          : array<bytes>
    blockHeader          : rawBitcoinHeader
    headerHeight         : uint32
}
```

These are the surfaces a developer touches first. They map directly to the actions in §6 and §7.

---

## 17. Acceptance tests

These tests gate the first deliverable. A change that regresses any of them violates the boundary in §15.

### 17.1 Phase A passes if:

1. A valid BTC deposit proof mints test zBTC to the Zenon recipient bound by the deposit descriptor.
2. Re-submitting the same outpoint fails (replay protection enforced).
3. A deposit to a script that does not match the registered descriptor fails.
4. A deposit with insufficient confirmations fails (depth below the configured threshold `K`).
5. A malformed Merkle proof fails (the path does not reconstruct to the header's Merkle root).
6. A header not connected to the accepted chain fails (parent hash mismatch against the verifier's known chain tip).

### 17.2 Phase B passes if:

1. A zBTC burn produces exactly one `WithdrawalAuthorization` outbox entry with correct `burnId`, `amountSats`, `btcDestination`, and `zenonAccount`.
2. The authorization is not readable as "finalized" before its batch is finalized.
3. After finalization, the authorization is fetchable along with an inclusion proof against `authorizationRoot`.
4. Two distinct burns produce two distinct `burnId`s.
5. The same `burnId` cannot be marked completed twice via `MarkBtcPayoutObserved`.
6. A burn of zero, or of more zBTC than the account holds, fails.

Phase B tests assume the Phase A tests are passing.

---

## 18. Mock-first rule for the Bitcoin BitVM Vault

The Bitcoin BitVM Vault is the hardest part of the system and the part Zenon does not own. Building it first inverts the dependency order and burns developer time on the wrong layer.

The Bitcoin BitVM Vault **MUST** be mocked until:

- deposit verification is stable;
- `WithdrawalAuthorization` encoding is stable;
- the relayer can read finalized outbox entries with inclusion proofs;
- replay protection is tested under adversarial inputs.

Phase C in the rollout (§9) is the mocking phase. Phase D, which uses real signet or testnet Bitcoin scripts, begins only after the conditions above are met. Skipping Phase C is a project-management failure mode, not a technical shortcut.

---

## 19. Deliverable naming

The first deliverable is the **BTC Authorization Domain MVP**.

The first deliverable is **not** "the BTC bridge," "the Zenon BTC bridge," or "the Zeno bridge." Those names imply trustless cross-chain custody movement, which the MVP does not provide and cannot honestly claim. Calling the MVP a bridge invites overclaiming and forces the project to defend a stronger position than the artifact actually supports.

External descriptions should refer to the MVP as one of:

- "BTC Authorization Domain MVP";
- "deposit-verification and burn-authorization demonstrator on Zenon";
- "the Zenon-side authorization layer for a future BitVM-style Bitcoin bridge."

The term "bridge" applies only to the combined Zenon-plus-Bitcoin system once the Bitcoin-side enforcement layer exists end-to-end, and only after Phase D has demonstrated a working signet or testnet path with honest framing of the trust assumptions in §11.

---

*Status: Frontier research, non-normative. SPEC.md governs on conflict.*
