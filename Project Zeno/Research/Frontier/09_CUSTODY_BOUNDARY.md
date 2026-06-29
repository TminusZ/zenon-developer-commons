**Status:** Frontier boundary document
**Phase status:** Mixed; internal Settlement custody is specified for ZTS-backed assets, while external-chain custody is out of scope
**Purpose:** Define the boundary between event verification, Settlement custody, wrapped claims, and external-chain asset release
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Custody Boundary

## 1. Why this document exists

Every previous Frontier document has touched the custody boundary obliquely. `01_RELAYER_BOUNDARY.md` defines relayers as transport actors, not custodians. `03_RELAYER_TRUST_MODELS.md` defines relay-plus-custody as a separate trust model in which event verification and asset control are different functions. `04_PROOF_SHAPED_DATA_BOUNDARY.md` notes that Bitcoin SPV proves events but does not solve BTC withdrawal. `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md` distinguishes internal cross-domain messaging from external-chain bridging. `08_CROSS_DOMAIN_RELAY_PROOFS.md` confirms that relay proofs cannot release assets outside Settlement custody.

This document makes the custody boundary explicit. It does not propose a custody mechanism. It does not design a bridge. It defines what Settlement custodies, what Settlement does not custody, why event verification is not asset control, and where the unspecified gap sits.

Custody means control over asset release. Verification means checking evidence. Settlement custody applies only to assets held by Settlement itself. External-chain custody requires keys, threshold signing, smart contracts, or other chain-specific control mechanisms that the current Project Zeno spec does not define. The boundary between them is the most dangerous overclaim surface in the entire Frontier series, because the failure mode of conflating them is real-world asset loss.

Proving that an event happened is not the same as holding the keys required to act on that event.

The inventory rows that feed this document include: #8 (Bitcoin SPV verification domain), #9 (Bitcoin deposit detection, if treated as a use case category), #10 (Bitcoin withdrawal, negative boundary only), #12 (cross-domain asynchronous messaging), #13 (L2-to-L1 withdrawal via outbox), #36 (domain escape hatch), #39 (external bridge), and rows discussing wrapped assets, Sentinel custody fit, or unsafe bridge claims.

## 2. Definition of custody

Custody is the practical and cryptographic ability to release, move, or prevent movement of an asset.

For internal Settlement assets, custody is exercised by the Settlement contract itself: the contract holds the assets, and asset movement happens through Settlement's own state transitions. For external-chain assets, custody is exercised by whatever party controls the keys, scripts, contracts, or committees that move the asset on the relevant external chain. These are different and non-substitutable.

Five concepts must be kept apart in this document:

**Settlement custody.** Assets held by the Project Zeno Settlement contract or module. These are ZTS assets deposited into Settlement under SPEC §5 and §18.

**External-chain custody.** Assets controlled by mechanisms on a chain other than Zenon: Bitcoin scripts, Ethereum contracts, Solana programs, threshold-signing committees, or any party holding private keys on those networks.

**Claim accounting.** L2 contract state recording who is entitled to what. This can include wrapped representations of external assets, but the accounting record is not the asset itself.

**Event verification.** Machine-verifiable confirmation that something happened: a Bitcoin transaction was included, an Ethereum event was emitted, an oracle reported a value. This produces evidence; it does not produce control.

**Message routing.** Evidence or instructions moving between domains through committed roots and relay proofs. This routes data, not asset control.

Custody is control, not knowledge.

## 3. What Settlement custodies

Settlement custodies assets that are deposited into Settlement under the specified deposit path. In Phase 1, this means ZTS assets backed 1:1 by L1 ZTS tokens.

SPEC §5 and §18 establish the model. All L2 assets must be backed 1:1 by L1 ZTS assets in Phase 1: Settlement tracks `totalDeposited`, `pendingWithdrawalReserve`, and `totalReleased` per (domain, asset), and enforces the conservation invariant `totalReleased + pendingWithdrawalReserve <= totalDeposited` on every mutating path (SPEC §18.3). Deposit credits are produced by Settlement when L1 deposit account-blocks are observed and processed.

L1 withdrawal outbox messages can trigger release from Settlement custody through `RelayMessage`, subject to the withdrawal delay, the conservation invariant, and `MaxBatchWithdrawal` caps (see `08_CROSS_DOMAIN_RELAY_PROOFS.md`). Settlement is the custodian of the assets it releases.

Per-account correctness within the aggregate Settlement custody depends on source-domain execution correctness, which in Phase 1 is bonded-attested. A dishonest executor cannot violate aggregate conservation (Settlement enforces it on-chain), but it can in principle misattribute balances among accounts during the withdrawal delay window, bounded by the executor bond and the per-batch withdrawal cap.

Settlement can release only what Settlement actually holds.

## 4. What Settlement does not custody

Settlement does not custody assets outside the Zenon L1 ZTS deposit path. This includes, without limitation:

Native BTC on the Bitcoin network. Native ETH on Ethereum. ERC-20 tokens on Ethereum. Assets on Solana, Move-based chains, Cosmos chains, or any other external blockchain. Centralized exchange balances. Bank balances. Web2 service balances or credits. Assets controlled by a separate bridge committee or signer set. Assets that a future Project Zeno threshold-signing mechanism might control, until and unless such a mechanism is specified.

If an external asset is represented inside a Zeno domain, that representation is a claim, receipt, accounting entry, or wrapped object. It is not native custody. The redeemability of the claim depends entirely on whatever external-chain mechanism (if any) backs it. The current Project Zeno spec defines no such mechanism for any external chain.

A wrapped external asset without a redemption mechanism is an accounting claim, not native custody.

## 5. Event verification vs custody

Verification produces evidence. Custody produces control. The two are different, and stacking verification capabilities does not produce custody.

A future Bitcoin SPV domain can verify that a Bitcoin transaction was included in a block at a given confirmation depth. This is event verification. It produces evidence that a deposit occurred.

A future Ethereum event verification path, if it exists, can verify that an Ethereum contract emitted a specific event with specific log topics. This is event verification. It produces evidence that a state change occurred.

An oracle observation can report that an external value was seen by an observer (see `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`). This is observation. It produces evidence committed by the observer.

A cross-domain relay proof can prove that a message exists in a committed source-domain `outboxRoot` (see `08_CROSS_DOMAIN_RELAY_PROOFS.md`). This is inclusion verification. It produces evidence that a message was emitted.

None of these by themselves controls assets on the external chain. Each can justify a state update inside a Zeno domain that records, accounts for, or credits a claim. None of them can sign a Bitcoin transaction, broadcast an Ethereum transaction, or otherwise move assets on the external network.

Verification can justify a state update; custody is what makes redemption possible.

## 6. Bitcoin SPV deposit detection

A future `L1_RELAYED` Bitcoin SPV domain, if activated under a future profile, could verify the following inside the domain STF:

The Bitcoin header chain, validating proof-of-work and difficulty rules. Header linkage from the chain tip back through ancestors. Transaction inclusion via Merkle inclusion proofs against committed block Merkle roots. Confirmation depth pinned in `stfSpecHash` (see `01_RELAYER_BOUNDARY.md` and `04_PROOF_SHAPED_DATA_BOUNDARY.md`). Whether a transaction sent to a specific watched Bitcoin script or address has been confirmed.

If the STF defines the rule, the domain could credit a wrapped-BTC claim in L2 contract state when a deposit is verified. This produces an internal accounting entry backed by the verified Bitcoin event.

The boundary that must be enforced:

This verifies deposit detection. It does not prove who controls the deposited BTC after the deposit transaction confirms. It does not create a Bitcoin withdrawal path. It does not sign Bitcoin transactions. It does not solve the key-custody problem of holding the BTC. It does not make BTC native to Project Zeno.

The deposit address or script on Bitcoin must be controlled by someone. That control is custody. Whatever party (a custodial operator, a threshold-signing committee, a smart-contract escrow, a BitVM-style protocol) holds the keys or controls the script is the custodian. The SPV domain proves that BTC reached the watched script. It does not establish who can move that BTC afterward.

Bitcoin SPV can verify deposit evidence; it cannot sign a Bitcoin withdrawal.

## 7. Bitcoin withdrawal negative boundary

This section exists because Bitcoin withdrawal is the most common confusion point and the most consequential overclaim risk in the entire Frontier series.

BTC withdrawal is explicitly outside the current Settlement and Executor scope. The inventory marks #10 (Bitcoin withdrawal) as a negative boundary only: it appears in the inventory not as a use case to build, but as a boundary to enforce. EXECUTOR_DRAFT.md §12, which describes a Bitcoin SPV domain as an informative worked example, places BTC withdrawal explicitly out of scope.

Possible custody mechanisms that could in principle support BTC withdrawal include, without claiming integration or design intent:

A threshold-signing committee using Schnorr or FROST-style multi-signature schemes. A federated multisig of named signers. A BitVM-style enforcement protocol that uses optimistic fraud proofs and pre-signed transactions to constrain custody behavior. A custodial operator with off-chain key management. A future cryptographic bridge design that has not yet been specified. An external smart-contract bridge where applicable (not applicable for BTC, which lacks general smart contracts).

None of these are specified by the current Project Zeno spec. This document does not propose any of them. The boundary is marked as a custody gap that remains an open implementation question for Domain Settlement implementers.

BTC withdrawal is a key-management problem, not a relay-proof problem.

## 8. Ethereum and other external assets

An EVM-compatible Zeno domain, if ever activated, would provide runtime and tooling compatibility with Ethereum-style smart contracts. It would not provide Ethereum custody, liquidity, security, or finality.

Ethereum event verification, if ever implemented as a proof-shaped path under `L1_RELAYED`, would verify evidence about Ethereum state: sync committee signatures, finalized checkpoint roots, Merkle-Patricia trie inclusion proofs for state, storage, or receipts. This is event verification. It produces evidence; it does not produce custody.

An EVM Zeno domain would not custody ETH or ERC-20s unless an Ethereum-side custody mechanism is separately specified: an Ethereum smart-contract lockbox that releases assets based on Project Zeno's evidence, a threshold-signing committee with Ethereum keys, a custodial operator, or a future cryptographic bridge design. None of these are in the current spec.

EVM compatibility is runtime compatibility. The Ethereum Virtual Machine is an execution environment specification. Compiling a domain to support EVM bytecode does not connect that domain to Ethereum's liquidity, asset base, security, or finality. A Zeno EVM domain would inherit Zenon L1 security, not Ethereum security.

EVM compatibility gives execution compatibility; it does not give Ethereum custody, liquidity, security, or finality.

The same logic applies to Solana, Cosmos chains, Move chains, or any other external blockchain. Compatibility with their runtimes (if ever offered) provides runtime parity, not custody.

## 9. Cross-domain messaging is not external bridging

This section connects to `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md` and `08_CROSS_DOMAIN_RELAY_PROOFS.md`.

Cross-domain messaging inside Settlement routes messages between Zeno domains through committed outbox roots and inclusion proofs. It can move instructions, evidence, claims, or accounting updates from one domain to another. All of this happens within the Settlement contract on Zenon L1. No external-chain transaction occurs.

Because no external-chain transaction occurs, no external-chain custody is required. The assets involved are ZTS assets held by Settlement, subject to the conservation invariant. Moving a message between domains does not require signing on Bitcoin, Ethereum, or any other chain.

External bridging is a different operation. It moves asset control across chain boundaries. It requires that someone (or something) hold the keys, control the scripts, or operate the contracts that move assets on the external chain. The bridge trust model includes custody trust as a primary component.

Internal message relay moves committed evidence; external bridging moves asset control.

These cannot be substituted. A cross-domain relay proof inside Project Zeno cannot release Bitcoin, no matter how cryptographically rigorous the proof is. Conversely, an external bridge that signs Bitcoin transactions is not equivalent to a verified relay proof inside Settlement, regardless of how trusted the signers may be.

## 10. L1 withdrawal via outbox

This is the positive case: the path where Settlement is the custodian and asset release works correctly within the specified model.

For Zenon L1 assets held by Settlement (ZTS deposits):

The source domain emits an L1 withdrawal outbox message specifying recipient, asset, and amount (SPEC §17). `RelayMessage` verifies inclusion in the finalized source `outboxRoot` (see `08_CROSS_DOMAIN_RELAY_PROOFS.md`). `processedOutbox` prevents duplicate release. Settlement enforces the withdrawal delay (SPEC §21), the conservation invariant (SPEC §18.3), and `MaxBatchWithdrawal`. Settlement releases the custodied ZTS asset to the recipient L1 address.

The boundary:

Aggregate over-release is prevented on-chain. A domain cannot withdraw more than was deposited, regardless of executor behavior. Per-account correctness depends on source-domain execution correctness in Phase 1: the source domain's contract is responsible for debiting the correct user account when emitting the withdrawal, and Settlement does not verify per-account accounting. External-chain release is not covered: this is Zenon L1 withdrawal, not BTC, ETH, or any other external asset.

L1 withdrawal works because Settlement is the custodian.

This is the only case in the entire Frontier series where the relay proof and asset release combine into a working flow without requiring an external custody mechanism. It works specifically because the assets in question are ZTS, the custodian is Settlement, and the release happens on Zenon L1.

## 11. Wrapped assets and claims

A wrapped asset inside a Zeno domain is an L2 contract-level representation of something that may or may not be redeemable.

Different wrapped-asset designs imply different things:

A verified deposit claim: the domain has verified (via SPV proof or another event-verification path) that a deposit occurred on an external chain, and credits an internal balance. Redemption depends on whether the external chain has a corresponding release path.

An accounting entry: the domain tracks balances for an off-chain or external system without verifying any specific event. Redemption depends on whatever off-chain process backs the accounting.

A redemption promise: the domain represents a future promise that an external party will release assets when conditions are met. Redemption depends on the external party's honesty and capability.

A claim against a custodian: the domain explicitly represents a custodial relationship in which a named party holds assets and will release them under defined conditions. Redemption depends on the custodian.

A claim against a signer set: the domain represents control by a threshold or multisig group. Redemption depends on the signer set's honesty and key security.

An application-level token backed by external custody: the domain mints internal tokens that represent claims on externally custodied assets. Redemption depends on the custody mechanism.

The safe framing: the domain accounts for claims. The custody mechanism determines whether claims are redeemable. The user-facing trust model is the custody mechanism, not the domain's accounting.

The unsafe framing: the domain has native BTC or ETH. This is not true if the assets sit on Bitcoin or Ethereum and the domain only holds an accounting entry.

The wrapped token is only as strong as the custody mechanism behind it.

## 12. Custody trust models

| Model | Who controls release? | What Zeno can verify | Main trust assumption |
|---|---|---|---|
| Settlement-custodied ZTS | Settlement contract | Deposits, conservation invariant, withdrawal relay proofs | Phase 1 per-account correctness depends on executor honesty |
| Bitcoin SPV deposit claim | Domain STF verifies BTC proofs; no Zeno control over BTC | Deposit evidence (header chain, PoW, Merkle inclusion) | Redemption requires a separately specified BTC custody mechanism |
| Threshold-signer bridge | The signer set holding external-chain keys | Signatures, attestations, possibly proof inputs | Threshold honesty and key security |
| Committee-attested bridge | The committee under its threshold rule | Committee signatures, possibly observation feeds | Committee honesty and incentive structure |
| Smart-contract lockbox on external chain | An external-chain contract releases on evidence | External-chain events or proofs if a relay path exists | External-chain contract correctness and proof-path security |
| Custodial operator | A single operator with the keys | Operator reports, possibly attestations | Operator honesty and operational integrity |
| BitVM-style enforcement | A pre-signed transaction protocol on Bitcoin | External protocol evidence and challenge interactions | External protocol assumptions and economic incentives |

These are classifications, not designs. None of these are specified by the current Project Zeno spec for any external asset. The table exists to make the trust differences visible: each model places trust in a different actor or mechanism, and none of them is equivalent to event verification alone.

## 13. Sentinel relevance

Sentinels are plausible infrastructure operators for relaying, DA serving, proof serving, and watching. They have connectivity and uptime expectations, and they already serve a best-effort DA role (SPEC §3, §20).

The discipline established across the Frontier series applies here as well. No current spec assigns Sentinels custody authority. No current spec assigns Sentinels as bridge signers. No current spec assigns Sentinels as threshold-signature participants. No current spec assigns QSR as a custody bond or service bond.

Sentinel custody participation, if ever proposed, would require explicit spec definition of: which assets Sentinels custody, what threshold or multisig scheme governs them, what slashing or bond mechanism enforces honest behavior, what asset (QSR, ZNN, or something else) bonds the role, what governance gate activates it, and what disclosure surfaces inform users.

None of this exists in the current spec. Custody service economics are out of scope for this document. Speculative Sentinel role analysis, if pursued, belongs in `10_SENTINEL_SERVICE_BOUNDARY.md`, and even there the framing must be speculative architectural fit, not protocol assignment.

Sentinel suitability is not custody assignment.

## 14. Failure modes

| Failure | Type | Effect | Boundary |
|---|---|---|---|
| Valid BTC deposit proof but no signer set | Custody gap | Wrapped claim cannot be redeemed for native BTC | SPV verifies events; custody is a separate mechanism |
| Signer set refuses withdrawal | Custody liveness failure | Redemption stalls indefinitely | External custody trust model |
| Signer set colludes | Custody safety failure | External assets can be stolen | Key-management risk |
| Relay proof valid against dishonest source root | Execution correctness failure | A withdrawal message that should not have been emitted may reach Settlement | Phase-dependent source correctness; Phase 2 fraud proofs may address it |
| Settlement conservation would be violated | Internal custody safety | Release rejected on-chain | SPEC §18.3 invariant |
| Per-account balance fabricated in Phase 1 | Execution correctness failure | The wrong user may withdraw, within the aggregate cap | Executor bond, withdrawal delay, per-batch cap, watcher alarm |
| External chain reorgs deposit | Finality failure | Wrapped claim may be credited too early if confirmation depth is insufficient | Confirmation predicate pinned in `stfSpecHash` |
| Oracle reports false reserve | Observation truth failure | Wrapped claim backing may be overstated | Oracle boundary (see `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`) |
| Wrapped token has no redemption path | Product or design failure | Token is an internal claim with no external backing | Custody disclosure obligation |
| Sentinel signer role assumed without spec | Governance or spec failure | Misleading trust model in user-facing material | Sentinel role is not assigned by spec |
| Custody mechanism unspecified in domain disclosure | Disclosure failure | Users may not understand the trust model | Domain disclosure obligation |
| External-chain contract bug | External custody safety failure | Locked external assets may be lost | External-chain contract correctness assumption |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Bitcoin SPV gives Zeno native BTC | Bitcoin SPV can verify Bitcoin events inside a domain STF; native BTC custody requires a separate Bitcoin-side mechanism that is not specified |
| Deposit detection solves withdrawal | Deposit verification and withdrawal signing are different problems with different trust requirements |
| Relayers control bridge safety | Relayers transport evidence; custodians control external asset release |
| Cross-domain messaging eliminates bridges | Internal Zeno-domain messaging is not external-chain asset custody; it does not move assets across chain boundaries |
| EVM domain gives ETH liquidity, security, or custody | EVM compatibility is runtime compatibility only; Ethereum-side custody is not provided |
| Wrapped BTC is redeemable by default | Redeemability depends entirely on the custody and signing mechanism behind the wrapper |
| Sentinels are bridge custodians | No current spec assigns Sentinels custody authority |
| QSR is the bridge bond | No current spec assigns QSR as a custody or service bond |
| Relay proof can release external assets | Relay proof can trigger Settlement actions only for assets Settlement custodies |
| Settlement verifies external reserves | Settlement can verify committed proofs or messages; it cannot verify unproven external reserve truth |
| Verifying an event is the same as holding the asset | Verification produces evidence; custody produces control |
| A domain accounting for wrapped BTC is the same as holding BTC | The accounting entry is a claim against whatever custody mechanism (if any) backs the wrapper |

## 16. Open questions for Domain Settlement implementers

1. Is any external-chain custody mechanism intended for BTC? The current spec does not include one. If one is intended, when does it enter scope?

2. If BTC custody is intended, is it threshold signing (FROST, BLS, ECDSA-based), BitVM-style enforcement, federated multisig, custodial operator, or another mechanism?

3. What party controls external-chain keys under any intended custody mechanism? A protocol-defined committee, a Sentinel subset, a separate signer network, or named custodians?

4. What asset, if any, bonds custody behavior? No QSR assignment is currently specified. What economic security model is intended?

5. What slashing or enforcement mechanism exists for external custody failure? Internal Settlement slashing only affects assets Settlement custodies; external custody failure may require different remedies.

6. How are external-chain withdrawals requested, authorized, signed, and broadcast? What is the user-facing flow and what are the latency expectations?

7. How are failed or censored external-chain withdrawals handled? Is there a recovery path, an escape hatch, or a delegated retry mechanism?

8. What confirmation depth is required before crediting wrapped claims for each external chain? This is `stfSpecHash` policy, not a one-size-fits-all parameter.

9. How are reorgs handled after a deposit is credited? If a Bitcoin deposit is credited and the Bitcoin chain reorgs past the deposit transaction's block, what happens to the wrapped claim?

10. How does Settlement distinguish internally custodied ZTS assets from externally custodied wrapped claims in its public state? Are wrapped claims represented as a distinct asset class with different release rules?

11. What metadata must disclose custody model, redemption assumptions, and trust dependencies to users and integrators? Is there a required disclosure surface analogous to the SPEC §6.1 disclosure requirement for `EXTERNAL_OBSERVED`?

12. Are Sentinels ever expected to participate in custody, or only in relaying, DA serving, proof serving, and watching infrastructure?

13. If a future bridge uses BitVM-style machinery, what part lives inside Project Zeno (verification, accounting, dispute participation) and what part lives on Bitcoin (pre-signed transactions, challenge games)?

14. Is any custody mechanism in scope before Phase 2 fraud proofs and Phase 3 validity proofs become operational? Or does external custody work require those proof systems as a precondition for safety?

## 17. Summary

Verification is not custody.

A relayer can transport evidence. A domain STF can verify proof-shaped evidence according to the rules pinned in its `stfSpecHash`. Settlement can release assets it actually custodies under the conservation invariant and the withdrawal mechanics. These are real capabilities that the Frontier series has spent eight prior documents defining.

None of that gives Project Zeno control over assets on an external chain.

Bitcoin SPV can verify Bitcoin deposit evidence. It cannot sign a Bitcoin withdrawal.

Ethereum event verification, if a machine-verifiable proof path is implemented, can verify Ethereum evidence. It cannot custody ETH or ERC-20 tokens.

Cross-domain relay proofs can move messages and evidence inside Settlement, routing through committed outbox roots with replay protection. They cannot move native external-chain assets across chain boundaries.

Wrapped external assets are claims against whatever custody mechanism (if any) backs them. Their safety, redeemability, and trust model depend on that mechanism. Without a specified mechanism, a wrapped asset is an internal accounting entry, not a controllable external asset.

Therefore:

Event verification is not custody.
Relay is not signing.
Messaging is not bridging.
Wrapped accounting is not native asset control.
Settlement custody applies only to assets Settlement holds.
External-chain release requires separate external-chain control.

Do not collapse them. The cost of collapsing them is real-world asset loss when users discover that the "trustless" representation they were promised has no redemption path.

The single most important boundary in the Frontier series is the one this document defines. Verification produces evidence. Custody produces control. The two are different, and no amount of cryptographic rigor in the verification path produces custody by itself.
