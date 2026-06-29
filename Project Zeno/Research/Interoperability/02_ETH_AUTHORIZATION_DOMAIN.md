**Status:** Interoperability research
**Phase status:** Forward-looking; depends on reserved or out-of-scope machinery including `L1_RELAYED`, wrapped-claim issuance authority, Ethereum proof verification, and Ethereum-side lockbox contracts
**Purpose:** Define a poolless ETH/ERC-20 Authorization Domain design using Ethereum-side lockbox custody, Zeno-side verification and accounting, and optional solver acceleration
**Governing document:** `SPEC.md` governs on conflict
**Boundary discipline:** `../Frontier/` and `00_INTEROP_DESIGN_PRINCIPLES.md` govern interoperability safety claims
**Commit discipline:** This file is not a roadmap, bridge announcement, product claim, or implementation guarantee.

# ETH Authorization Domain: Poolless Lockbox Design

## 1. Status and purpose

This is a forward-looking interoperability design study. It depends on reserved or out-of-scope machinery and cannot be activated under the current Phase 1 profile.

The dependencies are explicit:

`inputSource = L1_RELAYED` is reserved in Phase 1 (SPEC §6.1). Core must reject domains selecting `L1_RELAYED` while the Phase 1 profile is in force. Any Ethereum verification domain requires `L1_RELAYED` activation. Ethereum proof verification inside a Zeno domain STF is not implemented; the verification path (sync committee proofs, finalized checkpoint validation, Merkle-Patricia trie proofs for receipts or storage) is feasibility-stage research, not built code. Wrapped-claim issuance authority for zETH and zERC-20 accounting assets is out of Phase 1 scope. The Phase 1 WASM domain registry contains one domain (`L1_NATIVE`); additional domain registration is reserved. Ethereum-side lockbox contracts are external work that must be specified, audited, and deployed independently of Project Zeno. Relayer and watcher tooling for an Ethereum domain does not exist in-tree. Solver liquidity, if used, is optional and external. Phase 2 fraud proofs and Phase 3 validity proofs are deferred and do not affect Phase 1 claims.

This document does not claim Phase 1 activation. It does not claim live ETH bridging. It does not claim that Project Zeno custodies ETH. It does not propose deployment timelines. The Frontier discipline established across `../Frontier/01` through `../Frontier/10` and the principles in `00_INTEROP_DESIGN_PRINCIPLES.md` apply throughout.

## 2. One-sentence thesis

The simplest viable ETH design is a poolless ETH Authorization Domain where an Ethereum lockbox contract custodies ETH and ERC-20 assets, a Zeno domain verifies Ethereum deposit evidence and accounts for wrapped claims, Settlement finalizes burn authorizations through the outbox, and the Ethereum lockbox releases assets only under a specified proof or authorization path.

## 3. Core idea in plain language

The design has three role groups:

**Ethereum side.** The lockbox contract holds ETH and ERC-20 deposits and releases them under specified release rules. Ethereum is the custody chain.

**Zeno side.** The ETH Verifier Domain verifies Ethereum deposit evidence. The zETH and zERC-20 accounting module mints wrapped claims on verified deposits, burns them on withdrawal, and emits authorization messages. Settlement finalizes the authorization and provides outbox inclusion proofs. Zeno is the verification, accounting, and authorization layer.

**Off-chain operators.** Relayers transport proofs and authorizations between Ethereum and Zeno. Watchers monitor both sides for inconsistencies. Optional solvers may front liquidity to users for faster withdrawals. These are transport, monitoring, and acceleration roles.

The design avoids Project Zeno-operated liquidity pools. There is no Zeno-owned ETH pool, no AMM bootstrapping requirement, no LP token, and no market-maker dependency for basic redemption. Users do not need to wait for a Zeno-owned pool to contain ETH. Instead, ETH and ERC-20 assets are locked in Ethereum contracts. Zeno mints wrapped claims only after verifying lockbox deposit evidence. Withdrawals burn wrapped claims on Zeno and produce finalized authorization. The Ethereum lockbox releases the underlying ETH or ERC-20 when the required authorization path is satisfied.

Optional solvers can front ETH or ERC-20 to users before the final lockbox release completes, then claim reimbursement from the lockbox. This is a UX acceleration, not a custody substitute.

The base design is contract-custodied, not pool-custodied.

The intuition "bridgeless bridge" sometimes appears in adjacent discussions. The formal design here is not bridgeless. It has custody (the Ethereum lockbox), it has proof or authorization verification, it has relayer infrastructure, and it has all the trust assumptions documented below. The honest decomposition is: no Zeno-operated liquidity pool, Ethereum-side contract custody, Zeno-side verification and accounting and authorization, optional solver acceleration, still a custody mechanism, still requires proof or authorization verification.

Poolless does not mean custodyless.

## 4. Architecture overview

```
Ethereum L1
  |
  | deposit / release
  v
Ethereum Lockbox Contract
  |
  | deposit events / release claims
  v
Relayer / Proof Service
  |
  | Ethereum proof payloads
  v
ETH Verifier Domain on Zeno
  |
  | verified Ethereum facts
  v
zETH / zERC20 Accounting Module
  |
  | burn / withdrawal authorization
  v
Settlement Outbox
  |
  | finalized authorization proof
  v
Relayer / Solver / Watcher
  |
  | proof or claim to Ethereum
  v
Ethereum Lockbox Contract
  |
  | release ETH / ERC-20
  v
User on Ethereum
```

The components named in the diagram are defined in the next section.

## 5. Components

### 5.1 Ethereum Lockbox Contract

**Responsibilities.** Custody ETH and ERC-20 deposits sent to the contract. Emit canonical deposit events containing asset, amount, depositor address, Zeno recipient binding, deposit nonce or unique identifier, and destination domain. Bind each deposit to a specific Zeno recipient or account address so that minted claims credit the correct party. Prevent replay on the release side by tracking processed withdrawal authorizations. Release funds only when the configured authorization path is satisfied. Optionally reimburse solvers who front liquidity, subject to the lockbox's claim-acceptance logic. Expose events suitable for proof relay into the Zeno ETH Verifier Domain. Enforce token-specific rules where ETH and ERC-20 differ (the calldata, the transfer mechanism, the allowance model).

**Boundary.** The lockbox is Ethereum-side custody. Project Zeno does not custody ETH or ERC-20 tokens. The lockbox contract must be specified, audited, and deployed separately before any production claim. The lockbox contract's correctness is an Ethereum-side responsibility outside the Zeno spec.

### 5.2 ETH Verifier Domain

**Responsibilities.** Accept Ethereum proof payloads as inputs via future `L1_RELAYED`. Verify Ethereum finality and checkpoint evidence, if a full proof path is implemented. Verify execution-layer receipt or storage proof against the finalized state root. Verify the deposit event from the Ethereum lockbox contract (correct contract address, correct event topic, correct field encoding). Verify event fields: asset, amount, depositor, Zeno recipient binding, deposit nonce. Reject replayed deposits through a `processedDeposits` set within the domain. Emit verified Ethereum facts into domain state for downstream consumption by the accounting module.

**Boundary.** This is substantially heavier than Bitcoin SPV. Ethereum proof verification may require sync committee BLS signature aggregation, finalized checkpoint tracking, execution payload root binding to the beacon block, receipts root verification, and Merkle-Patricia trie proof verification for the specific event. The trie format uses variable-length encoded paths and branch nodes, which is more complex than binary Merkle trees.

If full Ethereum light-client verification is not implemented in the MVP, the design must say what trust replaces it. Possible substitutes include trusted checkpoints (a hard-coded recent finalized block hash), committee-attested Ethereum proofs (a signer set vouches for proof inputs), centralized proof services (a single provider produces proofs), optimistic proofs with a challenge window, external oracles, or mock proofs for demonstration. Each substitute imports its own trust model that must be disclosed.

### 5.3 zETH / zERC-20 Accounting Module

**Responsibilities.** Mint a wrapped claim balance only after a verified lockbox deposit event has been processed by the ETH Verifier Domain. Track processed deposits to prevent double-mint. Burn the wrapped claim balance on withdrawal request, debiting the user's account on Zeno. Emit a withdrawal authorization message to the Settlement outbox containing the Ethereum recipient, asset, amount, and any nonce or claim identifier. Track processed withdrawals to prevent double-burn or double-emission. Enforce internal accounting consistency: total minted claims equal total verified deposits minus total burned claims. This accounting invariant is internal to the domain; it does not by itself prove the Ethereum lockbox remains solvent unless lockbox reserves are separately verified or disclosed. Distinguish between ETH and supported ERC-20 assets by `AssetID` or equivalent identifier.

**Boundary.** Wrapped accounting is not native ETH custody. A zETH balance is a claim against the Ethereum lockbox. A zERC-20 balance is a claim against the same lockbox, with the asset's identity specified in the accounting metadata. If the lockbox is underfunded, the accounting balance does not by itself guarantee redemption. Reserve assumptions must be disclosed.

### 5.4 Settlement Outbox

**Responsibilities.** Finalize withdrawal authorization messages emitted by the accounting module. Provide outbox inclusion proofs against the committed `outboxRoot` for verifiers (whether the Ethereum lockbox or an off-chain authorization-mode handler). Prevent duplicate relay through the `processedOutbox` set where the authorization is processed through `RelayMessage` (though for cross-chain authorization, the lockbox itself performs the destination-side replay check). Bind each authorization to its source `domainId`, source `batchId`, `inputIndex`, `outboxIndex`, recipient, asset, and amount per the standard outbox structure (SPEC §17, §27.4).

**Boundary.** The outbox inclusion proof verifies inclusion against the committed root. It does not prove source-domain execution correctness beyond Phase 1 bonded-attestation assumptions (see `../Frontier/08_CROSS_DOMAIN_RELAY_PROOFS.md`). In Phase 2, the source-root correctness becomes challengeable; in Phase 3 it may become provable.

### 5.5 Relayer / Proof Service

**Responsibilities.** Watch Ethereum lockbox deposit events on Ethereum L1. Build Ethereum proof payloads suitable for the ETH Verifier Domain's `stfSpecHash`-pinned verification rules. Submit proof payloads into the Zeno ETH Verifier Domain via the `L1_RELAYED` input path (when activated). Watch Zeno finalized outbox authorizations after batches finalize. Submit authorization proofs or attestations to the Ethereum lockbox in the format the lockbox accepts, based on the chosen authorization mode (see Section 11). Optionally help users or solvers monitor flow status.

**Boundary.** Relayers transport evidence. They are not trusted for validity if proofs are properly verified by the receiving STF or lockbox contract. They are not custodians: they never hold ETH or ERC-20 on behalf of users, and they never hold zETH or zERC-20 claims on behalf of users. Relayer liveness affects whether deposits and withdrawals progress in a timely manner.

### 5.6 Optional Solver

**Responsibilities.** Front ETH or ERC-20 to the user on Ethereum immediately after observing a finalized Zeno burn authorization, before the lockbox release completes. Take a claim against the lockbox's authorization (the same authorization the user could otherwise process directly). Receive reimbursement from the lockbox if the claim is valid, unprocessed, and matches the authorization. Price latency, gas, and counterparty risk into the spread offered to users.

**Boundary.** Solvers are optional liquidity accelerators. They are not the core custody mechanism. Solver liquidity is not required for the base lockbox design; a user who is willing to wait for the lockbox release does not need a solver. If solvers exit the market, base redemption through the lockbox remains available (subject to whichever authorization mode is configured).

Solver liquidity improves UX; it does not define custody.

### 5.7 Watcher

**Responsibilities.** Monitor Ethereum lockbox events (deposits, releases, solver claims). Monitor Zeno authorization state (finalized outbox authorizations, batch status, accounting balances). Detect mismatched releases (lockbox released to wrong recipient or wrong amount), duplicate claims, invalid solver claims, stale proofs, or any other observable inconsistency. Alarm in Phase 1: raise public signals when inconsistencies are detected. Possibly feed future fraud-proof or challenge mechanisms if those are specified in the chosen authorization mode (especially Mode B, optimistic challenge).

**Boundary.** Watching is replay and monitoring, not authority. A Phase 1 watcher has no on-chain enforcement channel within Zeno Settlement (see `../Frontier/02_DOMAIN_VERIFICATION_LIMITS.md`). On the Ethereum side, watcher participation in optimistic-challenge logic depends entirely on whether the lockbox contract implements such a mechanism.

## 6. Deposit flow: ETH or ERC-20 into Zeno

Step-by-step:

1. The user deposits ETH or an ERC-20 token into the Ethereum Lockbox Contract on Ethereum L1, specifying a Zeno recipient address in the deposit calldata.

2. The lockbox emits a canonical deposit event containing the asset (ETH or ERC-20 contract address), the amount, the Ethereum depositor's address, the Zeno recipient, a unique deposit identifier or nonce, and the destination Zeno domain.

3. A relayer observes the event, waits for the required Ethereum finality (per the domain's `stfSpecHash`-pinned predicate), and constructs a proof payload that the ETH Verifier Domain can verify.

4. The relayer submits the proof payload into the ETH Verifier Domain via `L1_RELAYED` (when activated). The proof payload includes the Ethereum proof material (header chain or checkpoint evidence, receipt or storage proof, event encoding) appropriate to the chosen verification path.

5. The ETH Verifier Domain verifies finality and receipt or log inclusion if the full proof path is implemented. Event field decoding produces the deposit's asset, amount, depositor, recipient, and nonce.

6. The domain checks event fields against expected formats and confirms the deposit has not been processed before by checking `processedDeposits`.

7. The accounting module mints or credits a zETH or zERC-20 claim to the Zeno recipient based on the verified amount.

8. `processedDeposits` records the deposit identifier or canonical event identity so the same deposit cannot be processed again.

**Core invariant.** No verified lockbox deposit event, no wrapped claim mint.

**Boundary.** If Ethereum proof verification is not fully implemented, the substitute trust model must be named in the deployment documentation. The substitute does not change the structural flow, but it changes the trust model.

## 7. Withdrawal flow: Zeno to ETH or ERC-20

Base lockbox flow:

1. The user submits a burn transaction to the ETH Authorization Domain on Zeno, specifying the Ethereum recipient address, the asset (ETH or ERC-20), and the amount.

2. The accounting module debits the user's zETH or zERC-20 balance, records a unique `withdrawalId` (or `burnId`) for the burn, and emits a withdrawal authorization message to the Settlement outbox. The authorization contains the recipient, asset, amount, source domain, source batch, and any nonce or claim identifier required by the lockbox.

3. The Zeno batch containing the burn transaction proceeds through Settlement: submission, withdrawal delay, finalization (per SPEC §21).

4. After finalization, a relayer constructs the authorization proof or attestation appropriate to the chosen authorization mode (see Section 11) and submits it to the Ethereum Lockbox Contract.

5. The Ethereum Lockbox verifies the authorization path according to its configured mode: a committee signature, an optimistic challenge window, a direct Zeno proof, or a third-party protocol's attestation.

6. If verification succeeds and the authorization has not been processed before, the lockbox releases ETH or the ERC-20 token to the Ethereum recipient.

7. The lockbox records the authorization as processed to prevent replay (lockbox-side `processedWithdrawals`).

**Core invariant.** No finalized Zeno burn authorization, no valid lockbox release.

**Boundary.** The hard part of this design is the lockbox's verification of the Zeno authorization. Section 11 enumerates the possible modes and their trust models. The design does not pick a final mode; it classifies the options.

## 8. Optional solver-accelerated withdrawal

A solver can compress the withdrawal latency for users willing to pay a spread.

Flow:

1. The user burns zETH or zERC-20 on Zeno as in the base flow.

2. After the Zeno batch finalizes and the withdrawal authorization is available, a solver observes the authorization and decides to participate.

3. The solver pays the user on Ethereum from the solver's own ETH or ERC-20 balance, taking on the latency and risk of the subsequent lockbox claim.

4. The solver submits its claim to the lockbox along with the authorization (and any solver-claim metadata the lockbox requires).

5. If the authorization is valid and unprocessed, the lockbox reimburses the solver with the underlying ETH or ERC-20.

6. Invalid or duplicate claims are rejected by the lockbox according to its replay-protection rules. Disputed claims may require a challenge process if the lockbox supports one.

The benefit of this flow is UX: the user receives ETH on Ethereum without waiting for the slowest part of the authorization-verification path. The user pays a spread that compensates the solver for capital cost, risk, and gas.

**Boundary.** This avoids the user waiting for the slowest proof path. It does not remove custody from the design: the lockbox still custodies the assets, and the solver only fronts capital. It does not require Zeno-operated pools: the solver provides its own capital. It does require solver incentives sufficient to attract participation, claim priority rules in the lockbox, replay protection (one authorization, one reimbursement), and failure handling if a solver claim is disputed.

Solver-fronted liquidity is a UX layer over the lockbox, not a replacement for the lockbox.

## 9. Why this is poolless

The base design does not need a Zeno-owned ETH pool, a Zeno-operated LP pool, AMM liquidity, pooled user liquidity on Zeno, or market makers for basic redemption.

What the design does need: Ethereum lockbox custody, a proof or authorization verification path that the lockbox accepts, a relayer or proof service, replay protection on both deposits and withdrawals, accounting correctness in the Zeno domain, and clear user disclosure of the chosen authorization mode and its trust model.

The "poolless" property reduces the bootstrapping burden. Many bridge designs require initial liquidity, which creates chicken-and-egg problems and exposes early users to LP risks. A lockbox-based design starts with no Zeno-side liquidity at all: the first deposit creates the first wrapped claim, and the first withdrawal triggers the first lockbox release.

The "poolless" property does not reduce the trust burden. The lockbox is still a custody mechanism. The proof or authorization path still has trust assumptions. Relayers still need to participate. Watchers still need to monitor.

Poolless means no dedicated liquidity pool; it does not mean no custody mechanism.

### 9.1 What poolless does not remove

Poolless removes the need for a Zeno-operated liquidity pool. It does not remove the need for:

- lockbox solvency;
- proof or authorization verification;
- replay protection;
- relayer liveness;
- token allowlisting;
- custody disclosure;
- failure handling when the lockbox rejects or cannot release.

## 10. Ethereum proof verification boundary

Ethereum deposit verification inside a Zeno domain is not as simple as Bitcoin SPV. The verification surface is substantially larger.

A full proof path may require:

Beacon chain finality proof to establish that a specific beacon block is finalized under Casper FFG consensus. Sync committee signature verification: BLS aggregate signature over the relevant beacon block, verified against the committee's public keys. Sync committee rotation tracking: the committee changes periodically, so the STF must either track committee transitions through light-client updates or receive committee data with each proof. Finalized execution payload root: the execution-layer state root binds to the beacon block via the execution payload header. Receipts root or state root, depending on whether the proof targets event logs or account or storage state. Receipt or state Merkle-Patricia trie proof: the proof material descends from the root through extension and branch nodes to the leaf carrying the receipt or value. Log or event decoding: the receipt contains a list of logs; the specific event of interest is identified by log address (the lockbox contract address) and topic hashes. Contract address and topic matching: the verification ensures the event came from the expected lockbox address and matched the expected event signature. Chain ID and fork domain binding: the proof must be tied to the correct Ethereum mainnet, not a testnet or fork, to prevent cross-chain replay. Replay protection: the deposit identifier or canonical event identity must be tracked.

Each of these components is implementable in principle. The combined surface is large. Implementing the full verification path inside a domain STF requires significant work in proof handling, BLS verification, Merkle-Patricia trie traversal, and rigorous determinism.

If the MVP does not implement full Ethereum light-client verification, it must say so and classify the replacement: trusted checkpoint (a recent finalized block hash hard-coded into the domain configuration), committee-attested Ethereum proof (a signer set vouches for the proof's correctness), centralized proof service (a single provider produces and submits proofs), optimistic proof with a challenge window (proofs are accepted optimistically and can be challenged), external oracle (a third-party oracle network attests to the deposit), mock proof for demonstration (testnet or signet only, never production).

Ethereum custody is easier than Bitcoin custody because Ethereum supports general smart contracts (the lockbox can implement programmable release logic). Ethereum proof verification into Zeno is not automatically easier than Bitcoin SPV; the consensus and state structures are more complex, and the proof formats are correspondingly larger.

## 11. Ethereum lockbox verification of Zeno authorization

This is the mirror problem to Section 10. For withdrawal, the Ethereum lockbox must decide whether a Zeno burn authorization is valid.

The design does not pick a final mode. It classifies the modes available, each with a different trust model.

### Mode A: Committee-signed authorization

A signer set observes finalized Zeno outbox authorizations and signs them in a format the Ethereum lockbox can verify (typically an ECDSA aggregate or a BLS multisignature).

**Pros.** Easiest MVP path. Simple Ethereum contract verification logic (signature checks). Cheaper gas cost on Ethereum because no large proof needs to be verified.

**Cons.** Introduces signer trust as an explicit assumption. Requires signer selection rules, bond, slashing, and governance to provide any economic security. The lockbox is only as honest as the signer set's threshold.

### Mode B: Optimistic challenge

A relayer submits the authorization to the lockbox, which accepts it optimistically. A challenge window allows watchers to dispute invalid authorizations within a defined period; after the window, the authorization is considered final.

**Pros.** Less trust in any single submitter. Aligns with established optimistic-bridge patterns. Allows the lockbox to operate without a full proof verifier.

**Cons.** Latency cost: users wait for the challenge window. Challenge logic complexity: dispute resolution must be specified, implemented, and audited. Requires watchers willing to participate and bonds to make challenges credible.

### Mode C: Direct Zeno proof verification

The Ethereum lockbox contract verifies a cryptographic proof that a specific Zeno authorization was finalized in a specific Settlement batch.

**Pros.** Strongest eventual path among the listed modes: it can reduce committee and challenge-window assumptions, assuming a sound and efficiently verifiable Zeno proof format exists.

**Cons.** Requires a Zeno proof format suitable for Ethereum-side verification. Likely Phase 3 or later (validity proofs of Zeno state would need to be implemented and verifiable on Ethereum). May be prohibitively expensive without a succinct proof system (zk-SNARK or similar). The hash-function mismatch between Zenon's SMT and Ethereum's verification requirements may compound the difficulty.

### Mode D: Solver or protocol integration

A third-party protocol or solver network handles authorization and settlement on its own terms, integrating with the lockbox through whatever interface that protocol provides.

**Pros.** Faster integration: existing protocols may have built-out infrastructure. May reuse existing liquidity, signer sets, or proof systems.

**Cons.** Imports the third-party protocol's trust model. May not be Zeno-native: the lockbox's behavior is partly outside Project Zeno's control. The third-party protocol's safety and liveness become part of the design's safety and liveness.

A real deployment might combine these modes (committee for fast path, optimistic for fallback, direct proof for future migration). The combination has its own trust model and is not analyzed here.

## 12. Custody model

The Ethereum lockbox contract is the custodian. It controls ETH and ERC-20 release according to its contract rules.

What this means in detail:

Project Zeno does not custody ETH or ERC-20. The Zeno chain does not hold these assets, the Settlement contract does not hold these assets, and no Project Zeno address controls these assets on Ethereum.

Relayers do not custody ETH or ERC-20. They transport proofs and authorizations. They never have access to lockbox funds.

Solvers custody their own working capital only until reimbursed. A solver that fronts 10 ETH to a user is holding (briefly) a 10 ETH claim against the lockbox. The solver's own funds are at risk; the user's withdrawal authorization is independently valid against the lockbox regardless of solver behavior.

Wrapped zETH and zERC-20 claims are claims against the lockbox. A user holding zETH has a Zeno-side claim that, when burned, produces a withdrawal authorization that the lockbox honors under its configured rules. The user does not have direct cryptographic control over the underlying ETH; they have a claim against the contract that controls it.

The lockbox is the vault; Zeno is the authorization layer.

## 13. Security assumptions

Splitting by layer:

**Zeno-side assumptions.** The ETH Verifier Domain correctly verifies Ethereum deposit evidence, or the MVP explicitly names its weaker substitute (trusted checkpoint, committee attestation, etc.). The accounting module correctly enforces mint, burn, and replay rules. Settlement finalizes withdrawal authorizations under standard batch finalization. Phase 1 bonded executor trust applies (see `../Frontier/02_DOMAIN_VERIFICATION_LIMITS.md`): per-account correctness depends on executor honesty in Phase 1; the executor bond provides accountability, while the withdrawal delay and per-batch cap bound immediate release risk.

**Ethereum-side assumptions.** The lockbox contract is correctly implemented and audited. The lockbox holds enough ETH and ERC-20 to cover outstanding claims; reserve disclosure is required to verify this externally. The lockbox release logic correctly verifies the selected authorization mode (committee signature, optimistic challenge, direct proof, or third-party protocol). Ethereum finality assumptions hold: blocks finalized under Casper FFG are not reverted in practice. ERC-20 token behavior is standard or explicitly handled (see Section 16, Q8).

**Relayer assumptions.** Relayers can censor or delay proof submission, but cannot forge verified proofs (the Verifier Domain rejects invalid proofs). Liveness requires at least one relayer or proof submitter willing to participate.

**Solver assumptions.** Solvers may refuse to provide liquidity. Solvers price risk and latency into their spreads. Solver failure affects UX, not base redemption, as long as the lockbox release path remains available.

## 14. Failure modes

| Failure | Layer | Effect | Boundary |
|---|---|---|---|
| Invalid Ethereum receipt proof submitted | Verification | Deposit rejected by the Verifier Domain | STF verification catches it deterministically |
| Ethereum proof payload unavailable for replay | DA / proof availability | Deposit cannot be re-verified by watchers | Proof availability boundary (`../Frontier/07`) |
| Deposit event replayed | Accounting | Double-mint attempt | `processedDeposits` rejects |
| Lockbox contract bug | Custody | Funds may be lost, stuck, or stolen | Ethereum-side custody risk; requires audit |
| ERC-20 nonstandard behavior (fee-on-transfer, rebasing, pausable) | Custody / token | Accounting mismatch between deposit amount and credited claim | Token allowlist required |
| Zeno burn authorization forged (Phase 1) | Withdrawal | Lockbox may release incorrectly if its verification of the authorization is weak | Depends on the selected authorization mode |
| Zeno source root dishonest | Execution correctness | Invalid burn may be finalized in Phase 1 | Phase-dependent root correctness (`../Frontier/02`, `../Frontier/08`) |
| Relayer censors proof | Liveness | Deposit or withdrawal delayed | Permissionless relay mitigates if others submit |
| Solver refuses to front | UX / liquidity | User must wait for base lockbox release | Solver is optional |
| Solver pays wrong recipient | Solver failure | Solver loss or user dispute | Solver-layer risk, not protocol safety |
| Duplicate withdrawal claim submitted to lockbox | Replay | Double-release attempt | Lockbox `processedWithdrawals` rejects |
| Ethereum reorg or finality failure | Finality | Deposit credited too early or release reverted | Finality predicate must be pinned |
| Lockbox underfunded relative to outstanding claims | Custody / accounting | Some claims may not be redeemable on demand | Reserve disclosure required |
| Committee signer colludes (Mode A) | Authorization mode | Invalid release possible if committee threshold is broken | Mode A trust model |
| Watchers offline in optimistic mode (Mode B) | Enforcement | Invalid authorization may pass the challenge window | Mode B trust model |
| Direct proof verification too expensive (Mode C) | Cost / feasibility | Mode C impractical until succinct proofs mature | Cost analysis required |
| Third-party protocol failure (Mode D) | Imported trust | Third-party protocol's safety becomes the lockbox's safety | Mode D trust model |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| This is a bridgeless bridge | It is a poolless lockbox authorization design; custody still exists in the Ethereum lockbox |
| Project Zeno custodies ETH | The Ethereum lockbox contract custodies ETH and ERC-20; Project Zeno verifies, accounts, and authorizes |
| No pool means no trust model | Poolless removes the LP-pool dependency, not custody or proof assumptions |
| ETH is native to Zeno | zETH is a wrapped claim against Ethereum lockbox custody; ETH itself remains on Ethereum |
| EVM compatibility gives ETH liquidity | Runtime compatibility is unrelated to asset custody or liquidity |
| Solvers remove the need for custody | Solvers accelerate withdrawals; lockbox custody still backs redemption |
| Relayers secure the bridge | Relayers transport evidence; verification and custody define safety |
| Ethereum proof verification is easy | Ethereum custody is easier than BTC custody, but Ethereum proof verification into Zeno is complex |
| Committee signatures (Mode A) are trustless | Mode A imports signer trust and needs bonding and slashing if economic security is claimed |
| Direct proof verification is available in Phase 1 | Direct Zeno proof verification on Ethereum is future work (Phase 3 or later), not Phase 1 capability |
| Optimistic mode (Mode B) is automatically safe | Optimistic safety requires watchers, bonds, and a credible challenge mechanism |
| zETH and zERC-20 are equivalent to ETH and ERC-20 | They are claims against the lockbox; redeemability depends on lockbox state and the authorization mode |
| The MVP is a production bridge | The MVP demonstrates the authorization flow; production deployment requires custody specification, audit, and governance |

## 16. Open questions for Domain Settlement implementers

1. Which Ethereum authorization mode should the lockbox use first: committee, optimistic, direct proof, or third-party protocol? The choice determines the MVP's trust profile.

2. What exact Ethereum proof path should the ETH Verifier Domain verify for deposits: receipt proof against receipts root, storage proof against state root, or a combination? Receipts cover events; storage covers explicit state.

3. Is full Ethereum light-client verification (sync committee plus finality plus trie proofs) feasible inside a Zeno WASM domain STF? What is the proof-size and gas profile?

4. What proof sizes exceed `MaxDataLength` (16 KiB per account-block) and therefore require DA references rather than direct posting? Receipt proofs and state proofs may exceed this limit.

5. What chain ID, fork, finality, and replay-protection fields must be pinned in `stfSpecHash`? Each must be deterministic and immutable for a given domain version.

6. Should the MVP use a trusted checkpoint (hard-coded recent finalized block hash) or committee-attested Ethereum proofs as the substitute for full light-client verification? Both have weaknesses; which weakness is more acceptable for a demonstration?

7. What ETH and ERC-20 assets are allowed? Is there an allowlist? An allowlist is recommended given the heterogeneity of ERC-20 behavior.

8. How are fee-on-transfer, rebasing, pausable, blacklistable, or upgradeable ERC-20s handled? Each has accounting implications that the lockbox contract must address explicitly.

9. How does the lockbox prove its reserves to Zeno or to users? Is there a proof-of-reserves mechanism in the lockbox contract, an off-chain attestation, or an independent watcher tracking the lockbox balance?

10. What withdrawal authorization fields must the lockbox consume? Recipient, asset, amount, source domain, source batch, outbox index, and what else?

11. How does the lockbox prevent duplicate releases for the same authorization? Lockbox-side `processedWithdrawals` keyed by authorization identifier.

12. What happens if the lockbox rejects a valid Zeno authorization (due to a bug or a configuration mismatch)? Is there an upgrade path, a rescue function, or a dispute mechanism?

13. What happens if a solver pays a user but cannot get reimbursed (because the lockbox rejects the solver's claim)? Solver-side risk only, or does it create a user-side claim against the lockbox directly?

14. What is the minimum honest MVP boundary that demonstrates the design without overclaiming?

15. When, if ever, can this design honestly be called a bridge? The Interop principles state that "bridge" requires a specified custody and release path; what completeness threshold satisfies that?

## 17. Minimal implementation boundary

The first implementation should be a demonstration, not production deployment.

The MVP should include: an Ethereum lockbox mock or testnet contract that emits canonical deposit events and exposes a release function under the chosen authorization mode; a defined deposit event format with all required fields; proof or mocked proof submission into the ETH Verifier Domain (mocked proofs are acceptable for demonstration); `processedDeposits` replay protection within the Verifier Domain; test zETH and zERC-20 minting on the Zeno side; a burn function in the accounting module that debits the user's claim and emits an authorization; a withdrawal authorization object with the required fields; a finalized outbox entry containing the authorization; a lockbox release path (mock or testnet) that consumes the authorization under the chosen mode (committee, optimistic, or mocked direct proof); duplicate withdrawal rejection by the lockbox.

The MVP must not include: mainnet ETH custody, production ERC-20 token support, a production solver market with real funds, unstated committee trust (any committee-attested mode must explicitly document the committee and its trust model), claims of trustless bridging in any documentation, or claims of native ETH on Zeno.

The MVP proves poolless authorization flow, not production ETH bridging.

## 18. Acceptance tests

**Deposit side.**

1. A valid lockbox deposit event with all fields present and verified produces a correctly credited zETH or zERC-20 claim balance on Zeno.

2. A replayed deposit event (same deposit identifier) is rejected by `processedDeposits`.

3. A proof claiming the lockbox at a wrong contract address fails verification.

4. A proof carrying the wrong event topic fails verification.

5. A deposit binding to an unauthorized or malformed Zeno recipient is rejected.

6. A proof against an insufficiently confirmed Ethereum block, or against an unfinalized checkpoint, is rejected.

7. A deposit involving an unsupported token (outside the allowlist) is rejected.

**Withdrawal side.**

1. A valid burn transaction emits exactly one withdrawal authorization to the Settlement outbox.

2. A withdrawal authorization cannot be used by the lockbox before its source batch finalizes.

3. A valid authorization, after finalization, releases the corresponding asset from the test lockbox under the chosen authorization mode.

4. A duplicate authorization (same source domain, batch, input index, outbox index) is rejected by the lockbox.

5. A withdrawal claim presenting the wrong recipient is rejected.

6. A withdrawal claim presenting the wrong amount is rejected.

7. A withdrawal involving an unsupported asset is rejected.

8. Solver reimbursement, if the solver flow is included in the MVP, requires a matching authorization and is rejected if the authorization does not match.

## 19. Deliverable naming

The first deliverable should be named:

**ETH Authorization Domain MVP**

It should not be named: ETH Bridge, Zeno ETH Bridge, Bridgeless Bridge, Trustless ETH Bridge, Native ETH on Zeno, or Poolless Trustless Bridge.

Acceptable external descriptions for documentation, presentations, and code commits include: ETH Authorization Domain MVP, poolless ETH/ERC-20 lockbox demonstrator, Zeno-side authorization layer for an Ethereum lockbox, or ETH deposit-verification and withdrawal-authorization demo.

The naming discipline matters because "bridge" carries strong implications about custody completeness and production readiness that this design does not yet satisfy.

## 20. Summary

The ETH Authorization Domain is easier than the BTC Authorization Domain on the custody side because Ethereum can host a lockbox contract with programmable release logic. Bitcoin lacks general smart contracts, so any BTC custody mechanism (BitVM-style, threshold signing, federated multisig) must be assembled from primitives that Bitcoin does support.

It is not automatically easier on the proof-verification side. Bitcoin SPV verification is a well-understood path: header chain, proof-of-work, Merkle inclusion, confirmation depth. Ethereum verification involves beacon chain finality, sync committee aggregation, finalized checkpoint tracking, and Merkle-Patricia trie proofs for receipts or state. The verification surface is larger and the proof material is heavier.

The honest design is poolless, not custodyless. Ethereum holds the assets in a lockbox contract. Zeno verifies deposit evidence, accounts for wrapped claims, burns claims on withdrawal, and emits finalized withdrawal authorizations. Relayers move proofs and authorizations between the two chains. Solvers may accelerate withdrawals by fronting liquidity, but they do not define custody.

Therefore:

Poolless does not mean custodyless.
Lockbox custody is still custody.
Zeno authorization is not Ethereum asset control.
zETH and zERC-20 are claims against the lockbox.
Solvers improve UX, not base safety.
Ethereum proof verification remains a feasibility boundary, not a solved problem inside a Zeno domain STF.
Direct Zeno proof verification on Ethereum is future work unless explicitly implemented.

Do not collapse them. The decomposition discipline that runs through the Frontier series and the Interop principles applies here: separate verification from custody, accounting from redemption, messaging from bridging, runtime compatibility from liquidity, relay from signing. The chains differ. The decomposition does not.
