**Status:** Interoperability research
**Phase status:** Forward-looking and feasibility-heavy; depends on reserved or out-of-scope machinery including `L1_RELAYED`, wrapped-claim issuance authority, Solana proof verification, Solana-side custody programs, and optional external liquidity/solver infrastructure
**Purpose:** Define a SOL/SPL Authorization Domain design that avoids Project Zeno-operated liquidity pools by using Solana-side custody, existing liquidity routes, and Zeno-side verification, accounting, and authorization
**Governing document:** `SPEC.md` governs on conflict
**Boundary discipline:** `../Frontier/` and `00_INTEROP_DESIGN_PRINCIPLES.md` govern interoperability safety claims
**Commit discipline:** This file is not a roadmap, bridge announcement, product claim, or implementation guarantee.

# SOL Authorization Domain: Existing Liquidity and Program-Custody Design

## 1. Status and purpose

This is a forward-looking interoperability design study and feasibility document. It depends on reserved or out-of-scope machinery and cannot be activated under the current Phase 1 profile.

The dependencies are explicit:

`inputSource = L1_RELAYED` is reserved in Phase 1 (SPEC §6.1). Core must reject domains selecting `L1_RELAYED` while the Phase 1 profile is in force. Any Solana verification domain requires `L1_RELAYED` activation. Solana proof verification inside a Zeno domain STF is not implemented; the verification path is feasibility-stage research, not built code. The feasibility analysis itself is open: whether a Solana account-state, transaction status, or commitment proof can be verified inside a WASM domain STF within proof-size and compute bounds is one of the central open questions of this document. Wrapped-claim issuance authority for zSOL and zSPL accounting assets is out of Phase 1 scope. The Phase 1 WASM domain registry contains one domain (`L1_NATIVE`); additional domain registration is reserved. Solana-side custody programs are external work that must be specified, audited, and deployed independently of Project Zeno. Existing Solana liquidity venues or solver networks, if used, are external infrastructure not controlled by Project Zeno; their availability, pricing, and trust models are not Project Zeno properties. Relayer and watcher tooling for a Solana domain does not exist in-tree. Phase 2 fraud proofs and Phase 3 validity proofs are deferred and do not affect Phase 1 claims.

This document does not claim Phase 1 activation. It does not claim live SOL bridging. It does not claim that Project Zeno custodies SOL or SPL tokens. It does not claim Project Zeno controls Solana liquidity, routing venues, or solver networks. The Frontier discipline established across `../Frontier/01` through `../Frontier/10` and the principles in `00_INTEROP_DESIGN_PRINCIPLES.md` apply throughout.

## 2. One-sentence thesis

The simplest viable SOL design is a feasibility-first SOL Authorization Domain where Solana-side custody and liquidity remain on Solana, a Zeno domain verifies or receives evidence of Solana deposits where feasible, Zeno accounts for zSOL and zSPL wrapped claims and emits finalized withdrawal authorizations, and Solana-side programs, solvers, or existing liquidity routes handle release or settlement under a separately specified trust model.

## 3. Core idea in plain language

The design has three role groups:

**Solana side.** A custody program holds SOL or SPL deposits and releases them under specified release rules. Existing Solana liquidity venues, solver networks, or routing infrastructure may participate as acceleration or alternative settlement paths. Solana is the custody and liquidity chain.

**Zeno side.** The SOL Verifier Domain receives Solana deposit evidence (proof, attestation, or another disclosed substitute). The zSOL and zSPL accounting module mints wrapped claims on accepted deposits, burns them on withdrawal, and emits authorization messages. Settlement finalizes the authorization and provides outbox inclusion proofs. Zeno is the verification, accounting, and authorization layer.

**Off-chain operators.** Relayers transport proofs and authorizations between Solana and Zeno. Watchers monitor both sides for inconsistencies. Optional solvers, liquidity participants, or existing routing protocols may front liquidity to users for faster withdrawals. These are transport, monitoring, and acceleration roles.

The design avoids Project Zeno-operated SOL pools. Zeno should not create its own SOL liquidity pool, deploy an AMM, mint LP tokens against SOL reserves, or operate a market-maker network for basic redemption. Solana already has substantial liquidity, well-developed token programs, multiple DEX venues, established routing infrastructure, and active solver-style participants. Project Zeno does not need to replicate any of that; it needs to connect to it under explicit trust assumptions.

Instead, Solana-side programs, token accounts, liquidity venues, or solver-style participants provide custody and liquidity where possible. Zeno receives verified or attested evidence of Solana-side deposits, mints wrapped claims, burns claims on withdrawal, and emits finalized authorizations. Solana-side mechanisms release SOL or SPL assets to users, or reimburse solvers who fronted those assets.

The base design is Solana-custodied and Zeno-authorized.

This is not a "bridgeless bridge." It is a decomposition of custody, liquidity, verification, accounting, and authorization. The custody mechanism still exists (a Solana program). The verification mechanism still exists (proof or attestation into a Zeno domain). The authorization mechanism still exists (Zeno outbox). The liquidity mechanism may live partly outside Project Zeno's perimeter, but each piece has a defined trust model that the design must disclose.

Existing liquidity is a routing resource, not a custody guarantee.

## 4. Architecture overview

```
Solana L1
  |
  | deposit / release / liquidity
  v
Solana Custody Program / Existing Liquidity Route
  |
  | deposit evidence / account evidence / release claims
  v
Relayer / Proof Service
  |
  | Solana proof or attestation payloads
  v
SOL Verifier Domain on Zeno
  |
  | verified or accepted Solana facts
  v
zSOL / zSPL Accounting Module
  |
  | burn / withdrawal authorization
  v
Settlement Outbox
  |
  | finalized authorization
  v
Relayer / Solver / Watcher
  |
  | authorization or claim to Solana side
  v
Solana Program / Solver / Liquidity Route
  |
  | release SOL / SPL or reimburse solver
  v
User on Solana
```

The components named in the diagram are defined in the next section.

## 5. Components

### 5.1 Solana Custody Program

**Responsibilities.** Custody SOL and SPL token deposits sent to specific program-derived addresses (PDAs) or program-controlled token accounts. Accept deposits from users with a defined deposit instruction that binds the deposit to a Zeno recipient address and a destination domain. Emit or expose deposit evidence (a log event, an account state change, or a transaction status entry) that a relayer can use to construct a payload for the Zeno verifier. Bind each deposit to a Zeno recipient, account, and domain so that minted claims credit the correct party. Prevent duplicate release by tracking processed withdrawal authorizations. Release SOL or SPL tokens only when the configured authorization path is satisfied. Optionally reimburse solvers who fronted liquidity, subject to the program's claim-acceptance logic. Expose program state or events in a form suitable for proof construction or attestation relay.

**Boundary.** The Solana custody program is the Solana-side custody mechanism. Project Zeno does not custody SOL or SPL tokens. This program must be specified, audited, and deployed separately before any production claim. Its correctness is a Solana-side responsibility outside the Zeno spec.

### 5.2 Existing Solana Liquidity Route

**Responsibilities.** Use existing Solana liquidity participants, DEX venues, or solver networks where doing so is operationally viable. Avoid bootstrapping a new Zeno-owned SOL or SPL pool. Allow a solver, market maker, routing protocol, or liquidity provider to front SOL or SPL to the user before the base release path completes. Settle reimbursement against the Solana custody program or another specified mechanism in a way that respects replay protection and claim-acceptance rules.

**Boundary.** Existing liquidity is not magic custody. Liquidity providers on Solana are not Project Zeno's custodians, contractors, or counterparties. They exist on Solana under their own terms. Using existing liquidity improves routing and UX for users. It does not prove reserves anywhere. It does not guarantee redemption if the providers exit, if Solana fees spike, or if routing markets become illiquid. Each external venue, solver, or protocol used imports its own trust model into the design, which must be disclosed.

Existing liquidity can accelerate settlement; it cannot replace the custody mechanism.

### 5.3 SOL Verifier Domain

**Responsibilities.** Accept Solana proof or attestation payloads as inputs via future `L1_RELAYED`. Verify Solana deposit evidence if a feasible proof path exists. The path may include verifying a slot's commitment level (processed, confirmed, or finalized), verifying account state at that slot, verifying that a specific transaction executed and produced the expected state change, or verifying validator-set or checkpoint evidence depending on the chosen verification approach. Verify deposit fields: asset (SOL or SPL token mint), amount, depositor address, Zeno recipient binding, deposit identifier or nonce, destination domain. Reject replayed deposits through a `processedDeposits` set within the domain. Emit verified or accepted Solana facts into domain state for downstream consumption by the accounting module.

**Boundary.** This is feasibility-heavy. Solana proof verification surfaces include: account-state proof format (Solana account state lives in a per-account commitment under the bank hash; access to historical account state at a specific slot requires either snapshots, account-history services, or a specific proof construction that is not standard infrastructure), slot and finality commitment analysis (Solana's commitment levels and fork-choice behavior define the predicate the domain must apply), validator-set or stake-weighted checkpoint evidence (verifying that a slot is finalized typically requires evidence about validator votes weighted by stake), transaction status proof analysis (a deposit instruction's execution is recorded in transaction status, but proving execution to a remote verifier requires specific proof construction), and proof-size analysis (account proofs, transaction proofs, and signature verification material may individually or together exceed practical limits inside a WASM domain STF).

If full Solana proof verification is not feasible or is not implemented in the MVP, the design must explicitly name the substitute trust path. Possible substitutes include: a trusted checkpoint (a recent finalized slot hash hard-coded into the domain configuration), Solana-side program attestation (a custody program that itself signs or commits to deposit facts in a way the Zeno domain can consume), committee-attested proof (a signer set vouches for the deposit's correctness), centralized proof or indexer service (a single provider produces and submits attestations), oracle observation (a third-party oracle network attests to the deposit, with the trust model documented per `../Frontier/06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`), optimistic claim with a challenge window, or a mock proof for demonstration only.

Solana-side liquidity may be easy to access; Solana proof verification into Zeno is the hard boundary.

### 5.4 zSOL / zSPL Accounting Module

**Responsibilities.** Mint a wrapped claim balance only after an accepted Solana deposit (proof-verified or substitute-attested) has been processed by the SOL Verifier Domain. Track processed deposits to prevent double-mint. Burn the wrapped claim balance on withdrawal request, debiting the user's account on Zeno. Emit a withdrawal authorization message to the Settlement outbox containing the Solana recipient address, asset identifier, amount, and any nonce or claim identifier required by the Solana-side mechanism. Track withdrawal identifiers (`withdrawalId` or `burnId`) for replay protection on the Zeno side. Enforce internal accounting consistency: total minted claims equal total accepted deposits minus total burned claims. This accounting invariant is internal to the domain; it does not by itself prove that the Solana-side custody mechanism remains solvent or that existing liquidity routes can satisfy outstanding claims unless reserves and routing capacity are separately verified or disclosed. Distinguish between SOL and supported SPL token assets by mint address or equivalent identifier. Enforce a token allowlist if needed.

**Boundary.** zSOL and zSPL are claims against the specified Solana-side mechanism. They are not native SOL or native SPL tokens. A user holding zSOL has a Zeno-side balance that, when burned, produces a withdrawal authorization that the Solana-side custody program or settlement route honors under its configured rules. The user does not have direct control over SOL on Solana; they have a claim against the program (and possibly against routing or solver mechanisms) that operates on Solana.

### 5.5 Settlement Outbox

**Responsibilities.** Finalize withdrawal authorization messages emitted by the accounting module. Provide outbox inclusion proofs against the committed `outboxRoot` for verifiers, whether the Solana custody program (under direct proof verification, if feasible) or off-chain authorization-mode handlers. Bind each authorization to its source `domainId`, source `batchId`, `inputIndex`, `outboxIndex`, recipient, asset, and amount per the standard outbox structure (SPEC §17, §27.4). Prevent duplicate internal processing through the `processedOutbox` set where the authorization is processed through `RelayMessage`; for cross-chain authorization paths, the Solana-side program performs the destination-side replay check.

**Boundary.** The outbox inclusion proof verifies inclusion against the committed root. It does not prove source-domain execution correctness beyond Phase 1 bonded-attestation assumptions (see `../Frontier/08_CROSS_DOMAIN_RELAY_PROOFS.md`).

### 5.6 Relayer / Proof Service

**Responsibilities.** Watch the Solana custody program for deposit instructions and the resulting state changes. Build or collect Solana proof or attestation payloads in the format the SOL Verifier Domain accepts under the configured mode. Submit payloads into the Zeno SOL Verifier Domain via the `L1_RELAYED` input path (when activated). Watch Zeno finalized outbox authorizations after batches finalize. Submit authorization payloads to the Solana-side program, solver, or liquidity route in the format that side accepts. Assist with status monitoring for users and solvers.

**Boundary.** Relayers transport evidence. They are not trusted for validity if proofs or attestations are properly verified at the receiving side. They are not custodians: they never hold SOL, SPL, or zSOL/zSPL claims on behalf of users. They cannot make invalid proofs valid.

### 5.7 Optional Solver / Liquidity Participant

**Responsibilities.** Front SOL or SPL tokens to the user on Solana from the solver's own reserves or by routing through existing Solana liquidity venues. Take a claim against the Zeno authorization or the Solana custody program. Receive reimbursement from the custody program (or another specified settlement route) if the claim is valid and matches an unprocessed authorization. Price latency, gas, slippage, and counterparty risk into the spread offered to users.

**Boundary.** Solver liquidity is optional. It improves UX for users who do not want to wait for the base release path. It does not define custody. It does not guarantee redemption: if solvers exit the market, base redemption through the custody program remains available (subject to whichever authorization mode is configured). Solver behavior is outside Project Zeno's enforcement scope.

### 5.8 Watcher

**Responsibilities.** Monitor Solana custody program state (deposits, releases, solver claims). Monitor Zeno accounting and outbox authorizations (finalized authorizations, batch status, accounting balances). Detect mismatched releases (custody program released to wrong recipient or wrong amount), duplicate claims, false deposits (deposits credited to Zeno without matching Solana state), stale attestations, or invalid solver claims. Alarm in Phase 1: raise public signals when inconsistencies are detected. Feed challenge mechanisms if a future optimistic-mode authorization path is specified.

**Boundary.** Watching is replay and monitoring, not authority. A Phase 1 watcher has no on-chain enforcement channel within Zeno Settlement (see `../Frontier/02_DOMAIN_VERIFICATION_LIMITS.md`). On the Solana side, watcher participation in any challenge logic depends entirely on whether the custody program implements such a mechanism.

## 6. Deposit flow: SOL or SPL into Zeno

Step-by-step:

1. The user deposits SOL or an SPL token into the Solana Custody Program by invoking the program's deposit instruction. The instruction specifies a Zeno recipient address and a destination domain identifier.

2. The deposit produces program state changes: program-owned account balance increases, the deposit is bound to the Zeno recipient and a deposit identifier or nonce, and a log event (or equivalent verifiable artifact) records the deposit asset, amount, depositor, recipient, and destination domain.

3. A relayer observes the deposit, waits for the required Solana commitment level (per the domain's `stfSpecHash`-pinned predicate), and constructs a proof or attestation payload appropriate to the chosen verification path.

4. The relayer submits the payload into the SOL Verifier Domain via `L1_RELAYED` (when activated). The payload includes the Solana-side material (account-state proof, transaction status proof, commitment evidence, or attestation depending on the mode) sufficient for the configured verification.

5. The SOL Verifier Domain verifies the payload if a feasible proof path is implemented, or accepts the explicitly named substitute trust path (trusted checkpoint, program attestation, committee attestation, oracle, etc.). The substitute trust model is documented in the domain's `stfSpecHash` configuration and disclosed to users.

6. The domain checks deposit fields against expected formats and confirms the deposit has not been processed before by checking `processedDeposits`.

7. The accounting module mints or credits a zSOL or zSPL claim to the Zeno recipient based on the verified or accepted amount.

8. `processedDeposits` records the deposit identifier or canonical Solana event or account identity so the same deposit cannot be processed again.

**Core invariant.** No accepted Solana deposit evidence, no wrapped claim mint.

**Boundary.** If the deposit evidence is attestation-based rather than proof-shaped (because full proof verification is not yet implemented), the document and the deployed domain configuration must say so. The substitute does not change the structural flow, but it changes the trust model substantially.

## 7. Withdrawal flow: Zeno to SOL or SPL

Base flow:

1. The user submits a burn transaction to the SOL Authorization Domain on Zeno, specifying the Solana recipient address, the asset (SOL or SPL mint), and the amount.

2. The accounting module debits the user's zSOL or zSPL balance, records a unique `withdrawalId` (or `burnId`) for the burn, and emits a withdrawal authorization message to the Settlement outbox. The authorization contains the recipient, asset, amount, source domain, source batch, and any nonce or claim identifier required by the Solana-side mechanism.

3. The Zeno batch containing the burn transaction proceeds through Settlement: submission, withdrawal delay, finalization (per SPEC §21).

4. After finalization, a relayer carries the authorization payload to the Solana-side custody program or solver route, in the format the chosen authorization mode requires.

5. The Solana-side program verifies the authorization under the selected mode (committee signature, optimistic challenge, direct Zeno proof, or third-party protocol integration).

6. If verification succeeds and the authorization has not been processed before, the program releases SOL or SPL tokens to the Solana recipient, or reimburses the solver who already paid the user.

7. The program records the authorization as processed (Solana-side `processedWithdrawals` or equivalent) to prevent replay.

**Core invariant.** No finalized Zeno burn authorization, no valid Solana-side release.

**Boundary.** The hard part of this design is the Solana-side verification of the Zeno authorization. Section 11 enumerates the possible modes and their trust models. The design does not pick a final mode; it classifies the options.

## 8. Optional existing-liquidity and solver-accelerated withdrawal

Instead of creating a Zeno-operated SOL pool, the design can use existing Solana liquidity participants, solver networks, or routing protocols.

Flow:

1. The user burns zSOL or zSPL on Zeno as in the base flow.

2. After the Zeno batch finalizes and the withdrawal authorization is available, a solver or liquidity participant observes the authorization and decides to participate. Different participants may offer different spreads or different routing.

3. The solver pays the user on Solana using its own SOL or SPL reserves, or by routing through an existing DEX or aggregator. The user receives the asset on Solana faster than the base release path would allow.

4. The solver submits a reimbursement claim to the Solana custody program (or to a separately specified settlement route) along with the authorization payload and any solver-claim metadata the program requires.

5. If the authorization is valid and unprocessed, the program reimburses the solver. Invalid or duplicate claims are rejected by the program's replay-protection rules.

The benefit of this flow: it leverages existing Solana liquidity instead of requiring Project Zeno to bootstrap a pool, deploy a market maker, or operate routing infrastructure on Solana. Users receive faster settlement; solvers earn a spread; Project Zeno does not custody or route any external liquidity.

**Boundary.** This improves UX and avoids pool bootstrapping. It does not remove custody from the design: the Solana-side program still custodies the assets, and solvers only front capital they later reclaim. It does not remove proof or authorization assumptions: the custody program still verifies the authorization before reimbursement. It does require solver incentives sufficient to attract participation, claim priority rules, replay protection, and failure handling if a solver claim is disputed. It imports the trust model of any existing liquidity venue or routing protocol used; that trust model must be disclosed.

Liquidity routing is optional acceleration, not base security.

## 9. Why this avoids reinventing liquidity

The base design does not require Project Zeno to operate a SOL pool, an SPL pool, an AMM, an LP token system, or a market-maker network for basic redemption.

The design may use Solana-side program custody (for the assets locked against minted claims), existing Solana liquidity venues (DEX aggregators, DEX pools, lending protocols, or other liquidity sources for solver routing), solver participants (off-chain or on-chain entities that front capital in exchange for a spread), existing token routing infrastructure (Solana-native aggregators or routers that handle SPL token movements), or protocol integrations with established Solana cross-chain or liquidity protocols if separately specified.

What the design must not assume: that external liquidity equals custody (it does not; the liquidity providers' reserves are not Project Zeno's reserves), that routing equals a redemption guarantee (it does not; routing markets can become illiquid or shift pricing), that solvers replace reserves (they front capital, they do not back claims), that liquidity venues import a benign trust model (they import whatever trust their own design requires), that Project Zeno can claim control over liquidity it does not control (it cannot).

Do not rebuild liquidity; specify how existing liquidity is safely consumed.

### 9.1 What liquidity-routing does not remove

Using existing Solana liquidity removes the need for Project Zeno to operate a SOL or SPL pool. It does not remove the need for:

- custody-program solvency (the program must hold or be able to release enough SOL and SPL for outstanding claims that route through it);
- proof or authorization verification (the custody program must still validate that any release is properly authorized);
- replay protection (on both Zeno and Solana sides);
- relayer liveness (someone must submit proofs and authorizations);
- token allowlisting (SPL behavior is heterogeneous);
- custody and routing disclosure (users must know which mechanism backs their claim);
- failure handling (when liquidity is unavailable, when routes fail, when solvers refuse, when the custody program rejects).

## 10. Solana proof verification boundary

Solana proof verification into Zeno is feasibility-heavy. This is the most important technical caution in this document.

A full proof path may require:

A commitment and finality predicate for Solana slots. Solana defines commitment levels (`processed`, `confirmed`, `finalized`) and uses optimistic confirmation under Tower BFT. The domain's `stfSpecHash` must pin a predicate that is deterministic, reorg-resistant within practical bounds, and verifiable from the proof material the relayer can produce.

An account-state proof format. Solana account state lives in per-account leaves committed under the bank hash for each slot. Producing a verifiable proof that "account X had state Y at slot Z" requires access to the historical bank hash structure or to a snapshot-based attestation mechanism. Standard Solana RPC nodes do not generally serve historical state proofs in a uniform format.

A transaction status or instruction-execution proof. A deposit instruction's execution is recorded in transaction status (success/failure, logs, instruction-level outcomes). Producing a verifiable proof of execution to a remote verifier requires either transaction-status commitment verification or reproducing the instruction's state effects via account-state proof.

Validator-set or checkpoint evidence. Verifying that a slot is finalized typically requires evidence about validator votes weighted by stake. Validator set rotation, epoch boundaries, and stake updates each add to the verification surface.

Proof-size and STF-cost analysis. Account proofs, transaction proofs, and signature verification material may individually or together exceed practical limits inside a WASM domain STF. Account-block payload limits (`MaxDataLength`, 16 KiB) constrain on-chain proof submission; larger proofs require chunking or DA references.

Deterministic verification inside a Zeno domain STF. Whatever verification logic is chosen must be byte-deterministic across compliant runtimes (SPEC §7) and must not depend on local clock, network state, or other non-deterministic inputs.

Handling Solana forks and commitment levels. Solana's fork-choice rules and the timing of optimistic confirmation versus economic finalization affect when a deposit can safely be considered final from the Zeno domain's perspective.

Do not claim this verification problem is solved. The current state of practice is that Solana light clients with cryptographic verification at the level of detail required for cross-chain proof verification remain an active research area. Several projects have built attestation-based or trusted-relayer-based approaches; full proof-based verification is less common.

If full proof verification is not implemented in the MVP, the substitute trust path must be explicitly classified: trusted checkpoint (a recent finalized slot hash hard-coded), program attestation (the Solana custody program itself signs or commits to deposit facts), committee attestation (a signer set vouches for the deposit), centralized indexer or proof service (a single provider produces attestations), oracle observation (a third-party oracle network attests, with `../Frontier/06` trust model), optimistic challenge (proofs accepted with a challenge window), or mock proof for demonstration only.

Solana interoperability may be liquidity-light but proof-heavy.

## 11. Solana-side verification of Zeno authorization

This is the mirror problem to Section 10. For withdrawal, the Solana-side program (or settlement route) must decide whether a Zeno burn authorization is valid.

The design does not pick a final mode. It classifies the modes available, each with a different trust model.

### Mode A: Committee-signed authorization

A signer set observes finalized Zeno outbox authorizations and signs them in a format the Solana program can verify (typically Ed25519 signatures, with optional aggregation depending on the scheme).

**Pros.** Easiest MVP path. Simple program verification logic (signature checks). Low compute cost on Solana relative to alternatives.

**Cons.** Introduces signer trust as an explicit assumption. Requires signer selection rules, bond, slashing, and governance to provide any economic security. The program is only as honest as the signer set's threshold.

### Mode B: Optimistic challenge

A relayer submits the authorization to the program, which accepts it optimistically. A challenge window allows watchers to dispute invalid authorizations within a defined period; after the window, the authorization is considered final.

**Pros.** Less trust in any single submitter. Aligns with established optimistic patterns from EVM-side designs.

**Cons.** Latency cost: users wait for the challenge window. Challenge logic complexity: dispute resolution must be specified, implemented, and audited on Solana. Requires watchers willing to participate and bonds to make challenges credible. Solana's compute and account-rent model affects how the challenge state is stored and processed.

### Mode C: Direct Zeno proof verification

The Solana custody program verifies a cryptographic proof that a specific Zeno authorization was finalized in a specific Settlement batch.

**Pros.** Strongest eventual path among the listed modes: it can reduce committee and challenge-window assumptions, assuming a sound and efficiently verifiable Zeno proof format exists.

**Cons.** Requires a Zeno proof format suitable for Solana-side verification. Likely Phase 3 or later (validity proofs of Zeno state would need to be implemented and verifiable inside a Solana program). Solana compute-unit limits and program size limits affect feasibility. The hash-function mismatch between Zenon's SMT and Solana's native primitives may compound the difficulty.

### Mode D: Existing protocol or solver integration

A third-party protocol or solver network handles authorization and settlement on its own terms, integrating with the custody program through whatever interface that protocol provides.

**Pros.** Avoids reinventing liquidity and authorization machinery. Faster integration if a suitable protocol already exists.

**Cons.** Imports the third-party protocol's trust model. May not be Zeno-native: the program's behavior is partly outside Project Zeno's control. The third-party protocol's safety and liveness become part of the design's safety and liveness. Must disclose the weakest layer.

A real deployment might combine these modes (committee for fast path, optimistic for fallback, direct proof for future migration). The combination has its own trust model and is not analyzed here.

## 12. Custody model

The Solana-side custody program, solver route, or protocol integration is the custodian and release mechanism.

What this means in detail:

Project Zeno does not custody SOL or SPL tokens. The Zeno chain does not hold these assets, the Settlement contract does not hold these assets, and no Project Zeno address controls these assets on Solana.

Relayers do not custody SOL or SPL. They transport proofs and authorizations. They never have access to custody program funds.

Solvers custody their own working capital only until reimbursed. A solver that fronts 100 SOL to a user is holding (briefly) a 100 SOL claim against the custody program. The solver's own funds are at risk; the user's withdrawal authorization is independently valid against the custody program regardless of solver behavior.

Wrapped zSOL and zSPL claims are claims against the specified Solana-side mechanism. A user holding zSOL has a Zeno-side claim that, when burned, produces a withdrawal authorization that the Solana-side program honors under its configured rules.

Solana holds the assets; Zeno holds the authorization state.

## 13. Security assumptions

Splitting by layer:

**Zeno-side assumptions.** The SOL Verifier Domain correctly verifies Solana deposit evidence under the chosen mode, or the deployed configuration explicitly names the weaker substitute (trusted checkpoint, attestation, oracle, etc.). The accounting module correctly enforces mint, burn, and replay rules. Settlement finalizes withdrawal authorizations under standard batch finalization. Phase 1 bonded executor trust applies: per-account correctness depends on executor honesty in Phase 1; the executor bond provides accountability, while the withdrawal delay and per-batch cap bound immediate release risk.

**Solana-side assumptions.** The custody program is correctly implemented and audited. The program holds or can access enough SOL and SPL for outstanding claims. The selected authorization mode (committee, optimistic, direct proof, or third-party) is correctly verified. Solana finality and commitment assumptions hold; fork-choice behavior remains within practical bounds. SPL token behavior is standard or explicitly handled (Token-2022 extensions, frozen accounts, upgradeable programs require explicit policy).

**Liquidity and solver assumptions.** Solvers may refuse to provide liquidity. Existing liquidity routes may fail, become illiquid, or price poorly. Solver failure affects UX, not base redemption, as long as the custody release path remains available. Third-party routes import their own trust model into the design.

**Relayer assumptions.** Relayers can censor or delay proof and authorization submission, but cannot forge verified proofs if verification is implemented. Liveness requires at least one relayer or proof submitter willing to participate.

## 14. Failure modes

| Failure | Layer | Effect | Boundary |
|---|---|---|---|
| Invalid Solana proof submitted | Verification | Deposit rejected if proof verification is implemented | STF verification boundary |
| Proof path infeasible inside domain STF | Verification feasibility | Design cannot claim proof-shaped Solana verification; must use substitute | Feasibility boundary |
| Attestation false (in attestation mode) | Observation and trust | False mint possible if the attestation source is trusted | Substitute trust model must be disclosed |
| Deposit replayed | Accounting | Double-mint attempt | `processedDeposits` rejects |
| Custody program bug | Custody | SOL or SPL lost, stuck, or stolen | Solana-side custody risk; requires audit |
| SPL token nonstandard behavior (Token-2022 extensions, fee-on-transfer, frozen accounts, upgradeable mints) | Token | Accounting mismatch | Token allowlist required |
| Solana fork or commitment failure | Finality | Deposit credited too early or release reverted | Finality predicate must be pinned |
| Relayer censors proof | Liveness | Deposit or withdrawal delayed | Permissionless relay mitigates if others submit |
| Existing liquidity route unavailable | Liquidity | User must use base release path or wait | Routing is optional |
| Solver refuses to front | UX | User waits for base release | Solver is optional |
| Solver pays wrong recipient | Solver | Solver loss or user dispute | Solver-layer risk, not protocol safety |
| Duplicate withdrawal claim submitted to custody program | Replay | Double-release attempt | Solana-side replay protection rejects |
| Zeno source root dishonest | Execution correctness | Invalid burn may be finalized in Phase 1 | Phase-dependent root correctness |
| Committee signer colludes (Mode A) | Authorization mode | Invalid release possible if committee threshold is broken | Mode A trust model |
| Watchers offline in optimistic mode (Mode B) | Enforcement | Invalid authorization may pass the challenge window | Mode B trust model |
| Direct proof too expensive on Solana (Mode C) | Feasibility | Mode C impractical until succinct proofs and Solana program limits align | Compute and cost boundary |
| Third-party protocol failure (Mode D) | Imported trust | Route or release fails; design's safety degrades to the third party's | Mode D trust model |
| Custody program underfunded | Custody and accounting | Some claims may not be redeemable on demand | Reserve disclosure required |
| Liquidity venue front-runs or MEV-extracts | Liquidity | User receives worse price than expected | External venue behavior; outside Zeno control |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| This is a SOL bridge | This is a SOL/SPL Authorization Domain or feasibility study unless custody and release are specified |
| Project Zeno custodies SOL | The Solana-side custody program or route custodies and releases SOL and SPL; Project Zeno verifies, accounts, and authorizes |
| SOL is native to Zeno | zSOL is a wrapped claim against Solana-side custody; SOL itself remains on Solana |
| Existing liquidity means guaranteed redemption | Existing liquidity improves routing; redemption depends on the custody mechanism |
| Solvers remove the need for custody | Solvers accelerate settlement; custody remains external |
| Zeno does not need proof verification | If proof verification is absent, the substitute trust model must be explicitly disclosed |
| Solana proof verification is easy | Solana proof verification is feasibility-heavy; full light-client verification inside a domain STF is an open problem |
| Runtime compatibility imports Solana liquidity | Runtime compatibility is not asset custody or liquidity |
| Sentinels provide Solana service by default | Sentinel role assignment requires explicit spec definition |
| QSR bonds SOL interoperability | QSR bonding is speculative unless specified |
| Phase 1 is fully verified | Phase 1 is bonded attestation with on-chain custody and conservation constraints; execution correctness is not on-chain verified |
| The MVP is a production bridge | MVP demonstrates flow; production custody requires specification, audit, and governance |
| Solana-side commitment levels are equivalent to finality | Solana commitment levels are distinct; `finalized` is the strongest, but the domain must pin its predicate explicitly |
| zSOL is fungible with SOL across all venues | zSOL is fungible only where it is accepted as a claim; native SOL is required for Solana-native operations |

## 16. Open questions for Domain Settlement implementers

1. Is the correct name SOL Authorization Domain, SOL Feasibility Study, or SOL/SPL Authorization Domain? Naming matters because Solana's SOL and SPL token distinction is significant for accounting.

2. What exact Solana evidence can a Zeno domain STF verify deterministically? Account state, transaction status, log events, or some combination?

3. Is Solana account-state proof verification feasible inside a Zeno WASM domain STF within proof-size and compute bounds? What proof construction would be needed?

4. What finality or commitment predicate is acceptable for Solana deposits? `confirmed` (33% economic), `finalized` (66% economic), or a slot-depth heuristic?

5. What proof sizes for the chosen verification path exceed `MaxDataLength` (16 KiB per account-block) and therefore require DA references?

6. What substitute trust path is acceptable for the MVP if full proof verification is not feasible? Committee, oracle, trusted checkpoint, or program attestation?

7. What Solana-side custody program design is minimal yet sufficient? PDA-based custody, escrow accounts, or program-controlled token accounts?

8. Can existing Solana liquidity routes or solver networks be used without creating a Zeno-operated pool? What integration interfaces are required?

9. What SPL tokens are supported? Is allowlisting required? How is the allowlist governed?

10. How are Token-2022 extensions, frozen accounts, upgradeable mints, transfer hooks, or other nonstandard SPL behavior handled? Each may invalidate naive accounting.

11. How does the Solana-side program verify Zeno authorization? Direct signature check, optimistic acceptance with challenge, or third-party protocol integration?

12. What authorization mode is acceptable first for the MVP: committee (Mode A), optimistic (Mode B), direct proof (Mode C), or third-party route (Mode D)?

13. What happens if the existing liquidity route becomes unavailable mid-deployment? Is there a fallback to direct custody release?

14. What happens if a solver pays a user but cannot get reimbursed by the custody program (because the authorization is rejected)? Solver-side risk only, or does it create user-side recourse?

15. What reserve or solvency disclosure is required for the custody program? On-chain proof-of-reserves, periodic attestations, or off-chain reporting?

16. When, if ever, can this design honestly be called a bridge? What specification completeness threshold satisfies the Interop principles' bridge criterion?

## 17. Minimal implementation boundary

The first implementation should be a demonstration or feasibility artifact, not a production deployment.

The MVP should include: a Solana custody program mock or devnet deployment that emits canonical deposit evidence and exposes a release function under the chosen authorization mode; a defined deposit event or account-state format with all required fields; proof or mocked proof submission into the SOL Verifier Domain (mocked or attestation-based proofs are acceptable for demonstration); `processedDeposits` replay protection within the Verifier Domain; test zSOL and zSPL minting on the Zeno side; a burn function in the accounting module that debits the user's claim and emits an authorization; a withdrawal authorization object with the required fields; a finalized outbox entry containing the authorization; a Solana-side release mock or devnet release path that consumes the authorization under the chosen mode; an optional solver simulation using mock liquidity to demonstrate the acceleration path; duplicate withdrawal rejection on the Solana side.

The MVP must not include: mainnet SOL custody, production SPL token support, a production solver market with real funds, unstated committee trust (any committee-attested mode must explicitly document the committee and its trust model), claims of trustless bridging in any documentation, claims of native SOL on Zeno, or claims that existing Solana liquidity guarantees redemption.

The MVP proves authorization flow and liquidity-routing shape, not production SOL bridging.

## 18. Acceptance tests

**Deposit side.**

1. A valid custody-program deposit with all fields present produces a correctly credited zSOL or zSPL claim balance on Zeno.

2. A replayed deposit (same deposit identifier) is rejected by `processedDeposits`.

3. A payload claiming the custody program at a wrong address fails verification.

4. A deposit binding to an unauthorized or malformed Zeno recipient is rejected.

5. A deposit involving an unsupported SPL token (outside the allowlist) is rejected.

6. An invalid or insufficient Solana proof or attestation under the chosen mode fails verification.

7. A proof or attestation from a wrong Solana cluster or fork (e.g., devnet evidence against mainnet configuration) fails the chain-ID or fork binding check.

**Withdrawal side.**

1. A valid burn transaction emits exactly one withdrawal authorization to the Settlement outbox.

2. A withdrawal authorization cannot be used by the Solana-side program before its source batch finalizes.

3. A valid authorization, after finalization, releases the corresponding asset from the devnet or mock custody program under the chosen authorization mode.

4. A duplicate authorization (same source domain, batch, input index, outbox index, or same `withdrawalId`) is rejected by the Solana-side replay protection.

5. A withdrawal claim presenting the wrong recipient is rejected.

6. A withdrawal claim presenting the wrong amount is rejected.

7. A withdrawal involving an unsupported asset is rejected.

8. Solver reimbursement, if the solver flow is included in the MVP, requires a matching authorization and is rejected if the authorization does not match.

## 19. Deliverable naming

The first deliverable should be named:

**SOL Authorization Domain MVP**

Acceptable external descriptions for documentation, presentations, and code commits include: SOL/SPL Authorization Domain MVP, Solana-side custody and Zeno authorization demonstrator, zSOL/zSPL deposit-verification and withdrawal-authorization demo, or Solana liquidity-routing feasibility demo.

It should not be named: SOL Bridge, Zeno SOL Bridge, Native SOL on Zeno, Trustless SOL Bridge, Poolless Trustless SOL Bridge, or Bridgeless Bridge.

The naming discipline matters because "bridge" carries strong implications about custody completeness and production readiness that this design does not yet satisfy. The Solana case carries the additional caution that proof-verification feasibility itself is unresolved, so even more discipline is appropriate.

## 20. Summary

The SOL Authorization Domain should avoid reinventing liquidity.

Solana already has substantial liquidity, established token programs, mature DEX venues, well-developed routing infrastructure, and active solver-style participants. Project Zeno should not begin by creating a new Zeno-owned SOL pool, deploying a Zeno-operated AMM on Solana, or building a market-maker network for basic redemption. The honest design keeps SOL and SPL custody and liquidity on Solana, uses Zeno as the feeless and MEV-resistant authorization and accounting layer, and connects the two through explicitly specified proof, attestation, or solver paths.

This makes the design liquidity-light, not custodyless and not solved on the verification side.

Solana holds the assets. Zeno holds the authorization state. Relayers move evidence. Watchers monitor. Solvers and existing liquidity routes may improve UX. Each external venue, solver, or protocol used imports its own trust model that the design must disclose.

The hardest unresolved problem is Solana proof verification into a Zeno domain STF. Account-state proof formats, finality predicates, validator-set verification, and proof-size constraints together make this feasibility-heavy. The MVP may need to use an attestation-based substitute (program attestation, committee, oracle, or trusted checkpoint) rather than a proof-shaped verification path; the substitute must be disclosed and its trust model documented.

Therefore:

Use existing liquidity where possible.
Do not treat liquidity as custody.
Do not treat routing as a redemption guarantee.
Do not claim SOL is native to Zeno.
Do not claim Solana proof verification is solved.
Disclose any attestation or oracle substitute and its trust model.
Keep custody on Solana.
Keep authorization on Zeno.

Do not collapse them. The decomposition discipline that runs through the Frontier series and the Interop principles applies here: separate verification from custody, accounting from redemption, messaging from bridging, runtime compatibility from liquidity, relay from signing. The chains differ. The decomposition does not.

The three-document Interop pattern is now visible. BTC = authorization domain plus Bitcoin-side enforcement layer (because Bitcoin lacks general smart contracts, so custody is BitVM-style, threshold signing, federation, or another assembled mechanism). ETH = authorization domain plus Ethereum-side lockbox contract (because Ethereum has general smart contracts, so the custody mechanism is a deployed contract). SOL = authorization domain plus Solana-side program and existing liquidity (because Solana has general smart contracts and substantial native liquidity, so the custody and routing mechanisms can use what already exists). Same decomposition. Different chain-specific instantiations. Different feasibility profiles. Same boundary discipline.
