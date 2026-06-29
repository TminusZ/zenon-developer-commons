**Status:** Interoperability research principles
**Phase status:** Mixed; chain-specific studies may depend on reserved or out-of-scope machinery
**Purpose:** Define the common decomposition, terminology, safety rails, and claim discipline for Project Zeno interoperability design studies
**Governing document:** `SPEC.md` governs on any conflict
**Boundary discipline:** `../Frontier/` governs interoperability safety claims
**Commit discipline:** This file is not a roadmap, bridge announcement, product claim, or implementation guarantee.

# Interoperability Design Principles

## 1. Why this document exists

The Frontier folder defined the safety rails. Across ten documents, it established that relayers transport evidence rather than create validity, that verification at different layers means different things, that proof-shaped data and observed data are different trust classes, that cross-domain messaging is not external bridging, that DA commitment is not availability, and that custody is control rather than knowledge.

The Interop folder applies those rails to concrete chain-specific studies. Bitcoin, Ethereum, Solana, and any other external chain raise the same set of design questions, but each chain answers them differently. The purpose of this document is to prevent every chain study from reinventing terminology, repeating Frontier work, or overclaiming what the design accomplishes.

The core points carry across every chain:

External event verification is not custody. A domain STF can verify that an event occurred on Bitcoin, Ethereum, or another chain; that verification produces evidence, not control over the asset.

Runtime compatibility is not external-chain liquidity. Compiling a Zeno domain to support EVM, SVM, Move, or Cairo bytecode gives execution compatibility, not access to Ethereum's, Solana's, Sui's, or StarkNet's asset base.

Messaging is not bridging. Cross-domain messages route within Settlement through committed outbox roots. External bridges move asset control across chain boundaries, which requires external-chain custody.

Wrapped accounting is not native asset control. An internal balance representing an external asset is a claim against whatever custody mechanism (if any) backs it.

Relay is not signing. Submitting evidence to Settlement is a transport operation. Signing a transaction on an external chain requires keys on that chain.

Proof availability is not automatic. A proof that cannot be retrieved cannot be verified or replayed.

Phase 1 is bonded attestation. Source-domain execution correctness is attested by the executor's bond, the withdrawal delay, and the per-batch cap, not by on-chain replay.

Future proof systems and custody systems must be labeled as future. Phase 2 fraud proofs and Phase 3 validity proofs are reserved. External custody mechanisms (threshold signing, BitVM-style enforcement, lockbox contracts, federated multisig) are not currently specified.

Interop research starts by separating what can be verified from what can be controlled.

## 2. Folder scope

The Interop folder contains chain-specific applications of the principles defined here and the boundaries enforced in `../Frontier/`. Documents in scope:

Chain-specific authorization-domain studies. External event verification studies. Inbound proof relay feasibility studies. Wrapped-claim accounting designs. Outbox authorization designs. Custody-model comparisons across chains. External bridge feasibility studies (under "feasibility study," not "bridge announcement"). Proof-format feasibility studies (proof size, complexity, STF cost). Chain-specific failure-mode analysis.

Documents not in scope:

Product announcements. Bridge marketing. Production deployment claims. Tokenomics claims. Sentinel service-market claims. QSR utility claims unless specified by the protocol spec. External-chain custody claims without a specified mechanism. Phase 1 activation claims for reserved machinery (`L1_RELAYED`, `EXTERNAL_OBSERVED`, Phase 2 fraud proofs, Phase 3 validity proofs).

The boundary discipline is straightforward:

`Frontier/` defines the boundaries.
`Interop/` applies them to specific chains.

If an Interop study conflicts with a Frontier boundary, the Frontier boundary controls. If a Frontier boundary needs revision, the revision happens in `Frontier/` and then Interop documents update.

## 3. Required decomposition

Every Interop design must be decomposed into the following layers. Each layer has a different trust model, a different failure surface, and a different specification requirement.

**Verification.** What external facts can a domain STF verify? Examples include Bitcoin transaction inclusion (header chain plus Merkle proof against confirmed block), Ethereum receipt or storage proof against a finalized checkpoint root, validator signature aggregation, Solana account-state proof if feasible, or an oracle observation if no machine-verifiable proof path exists. The boundary: verification produces evidence, not control.

**Accounting.** What internal state can Project Zeno update based on verified or observed evidence? Examples include wrapped claim balances (zBTC, zETH, zSOL, or any other wrapper), processed deposit sets to prevent replay, burn records when wrapped claims are destroyed, withdrawal authorization objects emitted to Settlement outboxes, vault UTXO tracking for chains where external custody is UTXO-shaped, receipt registries for cross-chain claim provenance. The boundary: accounting records claims; it is not the external asset itself.

**Messaging.** What messages, proofs, or authorizations can move through Settlement? Examples include outbox messages emitted by domain contracts, `RelayMessage` calls verified by Settlement against committed outbox roots, withdrawal authorization payloads bound to specific external recipients, proof-shaped inputs entering through future `L1_RELAYED` domains, observation payloads under future `EXTERNAL_OBSERVED` domains. The boundary: messaging routes evidence or instructions; it does not move native external-chain assets.

**Custody.** Who controls the external asset? Examples include Settlement custody for ZTS assets, Bitcoin script custody for BTC, Ethereum lockbox contract custody for ETH or ERC-20s, a threshold signer set for any external chain, BitVM-style enforcement protocols for Bitcoin, custodial operator arrangements, federated bridge committees, or unspecified mechanisms that future design work must define. The boundary: custody is control, not knowledge.

**Enforcement.** What happens when a participant lies, withholds, censors, refuses, signs incorrectly, or submits invalid data? Examples include STF rejection of invalid proof, Settlement rejection of duplicate `outboxId`, the conservation invariant rejecting over-release on-chain, Phase 1 watcher alarms, Phase 2 fraud-proof dispute paths, Phase 3 validity-proof verification, external-chain challenge games where they apply, signer slashing in threshold schemes that specify it, bond loss where a bond is specified. The boundary: enforcement must be specified before economic security can be claimed.

**DA and proof availability.** What data must be available to verify or replay? Examples include external chain headers, Merkle inclusion paths, raw transaction payloads, receipt or storage proofs, DA bundles produced by the executor, outbox inclusion proofs, SMT witnesses for state observed during execution, the domain runtime itself, and the `stfSpecHash` that pins verification rules. The boundary: commitment is not availability (see `../Frontier/07_DA_AND_PROOF_SERVING_BOUNDARY.md`).

**Phase status.** Which parts of the design are Phase 1 specified, reserved architecture paths (`L1_RELAYED`, `EXTERNAL_OBSERVED`, future `inputSource` extensions), deferred to Phase 2 or Phase 3 (fraud proofs, validity proofs, certain enforcement mechanisms), speculative infrastructure roles (Sentinel relay, proof serving, watcher participation), external work (Bitcoin-side or Ethereum-side mechanisms outside Project Zeno), or unsafe and do-not-claim (production-quality custody without specified mechanism)? Every chain-specific design must label each component's phase status.

## 4. Preferred terminology

Safe terms that should be used freely when the design supports them:

**Authorization Domain.** A domain that verifies external evidence, accounts for internal claims, and emits outbox authorizations for downstream consumption (by another domain, by an external custody mechanism, or by a user). Does not itself control the external asset.

**Verification Domain.** A domain whose primary function is verifying external chain evidence through a proof-shaped STF. May or may not produce internal accounting state.

**External Event Verification.** The act of verifying, inside a domain STF, that a specific event occurred on an external chain, based on proof-shaped evidence (headers, Merkle proofs, signatures, validator attestations, or other machine-verifiable artifacts).

**Wrapped Claim.** An internal Project Zeno accounting object representing an asset that exists on another chain or under another custody mechanism. The redeemability of the wrapped claim depends on the backing custody mechanism, which may or may not be specified.

**Withdrawal Authorization.** An outbox message emitted by a domain that authorizes a downstream custody mechanism to release an external asset. The authorization is evidence of authorization; the release requires the custody mechanism.

**Relay Proof.** An inclusion proof verifying that an outbox message exists in a committed source-domain `outboxRoot`. Defined in `../Frontier/08_CROSS_DOMAIN_RELAY_PROOFS.md`.

**Custody Mechanism.** The party, key set, script, contract, committee, or protocol that controls release of an external asset on its native chain.

**External Enforcement Layer.** Any mechanism outside Project Zeno (BitVM-style protocols, Ethereum smart contracts with dispute games, threshold-signer slashing on the external chain) that enforces correctness of a custody operation.

**Feasibility Study.** A research document analyzing whether a chain-specific design is implementable, what its proof-size and STF-cost profile looks like, and what specification work would be required. Does not commit to implementation.

**Demonstrator.** A non-production implementation used to validate format, accounting, and replay-protection mechanics. Typically mocks custody.

**Mock-first implementation.** An implementation that intentionally mocks the external custody mechanism while building out the verification, accounting, authorization, and replay-protection layers. The verification and accounting are real; the custody is simulated.

Terms to avoid unless fully justified:

**Bridge.** Reserved for designs with a specified custody and release path. An Authorization Domain study that does not yet define custody must not be called a bridge.

**Trustless bridge.** Avoid entirely. The trust model of any external-chain interoperability design includes multiple trust assumptions; a single label cannot honestly summarize them.

**Non-custodial bridge.** Avoid unless the design genuinely has no custody role. Most bridge designs have custody somewhere (a smart contract, a signer set, a protocol). "Non-custodial" is often misleading.

**Native BTC, native ETH, native SOL.** Project Zeno does not natively support assets on other chains. Wrapped claims are not native assets.

**Ethereum liquidity, Solana liquidity.** Runtime compatibility does not grant access to another chain's liquidity. Avoid claims that imply otherwise.

**Live interoperability.** No interoperability is live. Avoid.

**Production bridge.** Avoid until the design is specified, implemented, audited, and deployed.

**Sentinel service market.** Avoid. Sentinel service economics are not specified (see `../Frontier/10_SENTINEL_SERVICE_BOUNDARY.md`).

**QSR-backed service.** Avoid unless the spec assigns QSR to that service role.

**Decentralized custody.** Avoid as a blanket term. Custody decentralization is a design property that must be specified, not asserted.

Authorization Domain is the honest name for a design that verifies and authorizes but does not itself custody the external asset.

## 5. Authorization Domain pattern

The Authorization Domain pattern is the recommended starting point for most Interop studies, because it cleanly separates what Project Zeno can do (verify, account, authorize) from what it cannot do (control external assets without a specified custody mechanism).

An Authorization Domain:

Verifies external evidence, if proof-shaped evidence exists for the relevant chain and the STF implements the corresponding verification logic. Records internal accounting state: wrapped claim balances, processed input sets, burn records, authorization-emission state. Prevents replay through both Settlement's `processedOutbox` set (for outbox-emitted authorizations) and the domain's own processed-deposit tracking. Emits finalized outbox authorizations that downstream parties (other domains, external custody mechanisms, users) can consume. May support wrapped claims as L2 accounting objects. May track external custody state as observed inputs if such tracking is useful for the design. May feed an external enforcement layer with the authorization payload.

An Authorization Domain does not automatically:

Custody external assets on their native chain. Sign external-chain transactions. Guarantee redemption of wrapped claims into native external assets. Prove external reserve truth (only events are verified, not balances). Make wrapped assets equivalent to native assets. Remove external-chain trust assumptions that lie outside the domain's verification scope.

Bitcoin as the worked example: a BTC Authorization Domain may verify Bitcoin deposit transactions through SPV (header chain, proof-of-work, Merkle inclusion, confirmation depth), credit zBTC claims to L2 accounts based on verified deposits, allow zBTC to circulate within Project Zeno, accept burn operations that destroy zBTC and emit withdrawal authorization outbox messages, and bind each authorization to a specific Bitcoin recipient and amount. None of this signs a Bitcoin transaction. The actual BTC release requires a Bitcoin-side custody and enforcement mechanism, which may be a BitVM-style protocol, a threshold-signing committee, a federated multisig, or another design that is specified separately.

The same pattern applies to other chains with their own verification paths and their own custody mechanisms. The decomposition does not change. The chain-specific details change.

## 6. Chain classes

External chains can be grouped by the shape of their verification and custody questions. The classes below are illustrative, not exhaustive.

**SPV-style proof chains.** Example: Bitcoin. Typical verification path: header chain validation (proof-of-work, difficulty rules, linkage), Merkle transaction inclusion against block Merkle roots, confirmation depth pinned in `stfSpecHash`, deposit descriptor matching against watched scripts or addresses. Custody issue: SPV verifies deposits; it does not solve withdrawal signing. Bitcoin lacks general smart contracts that could serve as a lockbox, so custody requires either a key-holding party (custodial, threshold, federated) or a protocol like BitVM that uses pre-signed transactions and challenge games to constrain custody behavior.

**Finality-proof and receipt-proof chains.** Example: Ethereum. Typical verification path: finalized checkpoint validation through beacon chain consensus evidence, sync committee BLS signature aggregation, state root inclusion in beacon blocks, then Merkle-Patricia trie proofs for account state, storage, or receipts against the verified state root. Custody issue: event verification does not custody ETH or ERC-20 tokens. Ethereum has general smart contracts, so custody can take the form of an Ethereum-side lockbox contract that releases assets when it sees a verified proof of a Project Zeno authorization. The lockbox contract is itself a custody mechanism, with its own correctness assumptions.

**High-throughput account-state chains.** Example: Solana. Verification is feasibility-first: Solana's high block production rate, validator-set size, and account-state proof format may interact poorly with proof-size constraints inside a Zeno domain STF. Studies should analyze finality and fork-choice (how to define a confirmation predicate), account proof format (how Solana account state is committed and proven), proof-size and STF-cost analysis (whether the verification fits within domain execution bounds). Custody issue: account proof verification is not SOL custody. An external Solana program, signer set, or custody mechanism is required for actual SOL release.

**Runtime-compatible chains.** Examples: EVM, SVM, Move, CosmWasm, Cairo. These are not interoperability targets in the asset-movement sense. A Zeno domain offering EVM-compatible execution provides runtime parity with Ethereum smart contracts, allowing Solidity-compatible code to deploy. This is a developer-experience property, not a liquidity property. Runtime compatibility is not asset custody, liquidity, security, or finality inheritance. Each runtime-compatible domain still operates entirely on Zenon L1, with Zenon L1 security, ZTS-backed assets, and Project Zeno's settlement model.

Runtime compatibility gives execution compatibility; it does not import the external chain's assets.

## 7. Custody model requirement

Every chain-specific study must include a custody section. The section must answer:

Who controls the external asset? What keys, scripts, contracts, or committees can move it? What prevents unauthorized release? What forces or incentivizes valid release? What happens if the custodian refuses to act on a legitimate withdrawal authorization? What happens if the custodian colludes against users? What happens during reorgs or external-chain finality failure (a deposit confirmed at depth N gets reverted)? What bond, if any, backs custody behavior? What enforcement mechanism exists to detect and respond to dishonest custody? What is explicitly out of scope for this study?

If these questions are unanswered, the document must say so explicitly. The honest framing is:

This design verifies and authorizes. It does not yet define external custody.

This is not a weakness of the study; it is the correct boundary for early-stage interoperability work. The Authorization Domain pattern is most useful when the verification, accounting, and authorization layers stabilize before the custody mechanism is designed.

No custody section, no bridge claim.

A document that defines verification and accounting without defining custody is an Authorization Domain study or a Verification Domain study, not a bridge. Calling it a bridge before custody is specified misrepresents the design.

## 8. Minimal implementation boundary

Every chain-specific design must define its first honest deliverable. The first deliverable should be the smallest piece that can be built, tested, and described accurately without overclaiming.

**Bitcoin first deliverable.** Examples of an honest first deliverable: Bitcoin header relay (a domain that ingests block headers and validates the chain), SPV Merkle proof verification (the domain STF accepts and verifies inclusion proofs), deposit descriptor matching (the domain identifies deposits to watched addresses or scripts), processed deposit replay protection (each detected deposit is recorded once), test zBTC minting (wrapped claims are credited based on verified deposits, on a testnet or signet), burn authorization (zBTC can be destroyed and a withdrawal authorization can be emitted), finalized outbox authorization (the authorization message reaches Settlement's finalized outbox). What is explicitly excluded from the first deliverable: production BTC custody, mainnet BTC release, signer set governance, BitVM machinery construction.

**Ethereum first deliverable.** Examples: finalized Ethereum proof feasibility analysis (can a domain STF verify sync committee proofs and trie inclusion within size and gas bounds?), event or receipt proof verification (the STF accepts and verifies Ethereum proofs), lockbox-event accounting (verified events update internal claim balances), processed event replay protection, burn authorization for wrapped claims. What is explicitly excluded: production ETH or ERC-20 custody unless an Ethereum-side lockbox contract is specified, deployed, and integrated.

**Solana first deliverable.** Examples: proof feasibility study (what would Solana verification look like?), account-state proof analysis (can the proof format fit in a domain?), finality and fork-choice analysis (what confirmation predicate works for Solana?). What is explicitly excluded: any SOL custody claim.

The principle: the first deliverable should prove the smallest honest claim.

## 9. Mock-first rule

If the external custody and enforcement layer is the hardest and least specified part of an interoperability design, the implementation work should mock it first.

The purpose of a mock is to stabilize the parts of the design that Project Zeno fully controls: the proof format used by the domain STF, the accounting state in domain contracts, the replay-protection structure, the authorization object emitted by the outbox, the relayer submission path, the watcher assumptions, the failure-mode handling.

Once these are stable, the custody design can be slotted in. Building production custody before the verification and authorization layer is stable couples two hard problems and makes both harder.

External custody should remain mocked until verification, accounting, authorization, and replay protection are stable.

This is not a deferral of the custody problem. It is a sequencing recommendation: build what can be built honestly, validate it, then attach the custody layer. The mock makes the connection point explicit. When the custody mechanism is specified, it slots into the mocked interface, and the surrounding code does not need to change.

## 10. Required unsafe claims table

Every chain-specific Interop document must include a table of unsafe claims and their correct framings. At minimum, the table must include the rows below. Chain-specific rows should be added as needed.

| Unsafe claim | Correct framing |
|---|---|
| This is a bridge | This is an authorization-domain or verification-domain study unless custody and release are specified |
| External event verification gives native asset custody | Verification produces evidence; custody requires external-chain control |
| Deposit detection solves withdrawal | Deposit verification and withdrawal release are separate problems with separate trust requirements |
| Wrapped assets are redeemable by default | Redeemability depends entirely on the custody mechanism backing the wrapper |
| Relayers secure the bridge | Relayers transport evidence; validity comes from STF verification and custody comes from the custody mechanism |
| Runtime compatibility gives asset liquidity | Runtime compatibility is execution compatibility only |
| Cross-domain messaging replaces bridges | Internal messaging is not external-chain asset custody |
| Sentinels provide the service by default | Sentinel role assignment requires explicit spec definition |
| QSR bonds the service | QSR bonding for Interop service roles is speculative unless specified |
| Phase 1 is fully verified | Phase 1 is bonded attestation with on-chain custody and conservation constraints; execution correctness is not on-chain verified |

## 11. Required failure modes table

Every chain-specific Interop document must include a failure-modes table. Minimum columns: Failure, Layer, Effect, Boundary.

The minimum failures to consider in every chain study:

Invalid proof submitted to the domain STF. Unavailable proof payload (proof referenced but not retrievable). DA bundle missing for source-domain replay. Replayed deposit (same deposit credited twice). Replayed withdrawal (same authorization processed twice). External chain reorg deeper than the confirmation predicate. Dishonest source root (Phase 1 bonded-attestation failure). Custodian refuses a legitimate withdrawal (liveness failure). Custodian colludes against users (safety failure). Signer key compromise (in threshold or multisig designs). Oracle false report (in observation-based designs). Relayer censorship (no one submits a needed payload). Watcher offline (no alarm during executor divergence). No operator liquidity (the design assumes liquidity that is not present). Insufficient bond (bond does not cover value at risk). Proof too large for the domain STF (verification cannot fit in account-block limits). Runtime incompatibility (the verification logic cannot be implemented in the domain's runtime). User believes a wrapped claim is the native asset (disclosure failure).

Each chain-specific document should add chain-specific failures: Bitcoin reorgs at various confirmation depths, Ethereum sync committee changes, Solana validator-set drift, and so on.

## 12. Disclosure requirements

Every Interop design must disclose, near the top of the document:

The phase status of each component (Phase 1 specified, reserved, deferred, speculative, external work). Whether the external input source is reserved (`L1_RELAYED` is reserved under the Phase 1 profile, as is `EXTERNAL_OBSERVED`). Whether proof verification is implemented, prototyped, or speculative. Whether custody is specified, mocked, or unspecified. Whether redemption is specified or out of scope. Whether DA is L1-posted (inheriting Zenon L1 DA) or DA-referenced (depending on best-effort serving). Whether relayers are permissionless or assigned. Whether Sentinels have any assigned role in the design. Whether QSR is assigned any role in the design. Whether watchers are Phase 1 alarm-only or expected to feed Phase 2 fraud proofs. Whether Phase 2 or Phase 3 proof systems are required for the design's safety claims. Whether the design is a research demo, a testnet implementation, a signet implementation (for Bitcoin), or a production proposal.

Interop claims must disclose their weakest layer. If proof verification is solid but custody is unspecified, the document must lead with the custody gap. If accounting is stable but DA is best-effort, the document must lead with the DA assumption.

## 13. Comparison matrix template

The following matrix is a reusable shape for cross-chain comparisons. Specific entries are placeholders for documents to fill in; the shape is what matters.

| Chain | Verification path | Accounting object | Custody mechanism | Enforcement mechanism | Phase status | Honest name |
|---|---|---|---|---|---|---|
| BTC | SPV: header chain + Merkle transaction inclusion + confirmation depth | zBTC wrapped claim, processed deposits, burn record, withdrawal authorization | External Bitcoin-side mechanism required (not specified by Project Zeno spec) | BitVM-style enforcement, threshold signing, or other if and when specified | Forward-looking; depends on `L1_RELAYED` activation and Bitcoin-side custody design | BTC Authorization Domain |
| ETH | Sync committee + finalized checkpoint + receipt or storage proof, if feasibility confirms | Wrapped ETH or ERC-20 claim, processed events, burn record | Ethereum lockbox contract or external signer set required | External Ethereum contract enforcement or signer slashing | Feasibility / forward-looking | ETH Authorization Domain |
| SOL | Feasibility to be analyzed (account-state proof format, finality predicate, proof size) | Wrapped SOL claim (placeholder pending feasibility) | External custody required (Solana program, signer set, or other) | To be determined based on feasibility | Feasibility-first | SOL Feasibility Study |

The matrix is illustrative. Each chain-specific study should populate its own row with care, and should not over-specify the rows for other chains.

## 14. Relationship to the BTC Authorization Domain

The BTC Authorization Domain is the first concrete Interop case study in this folder.

It should be treated as:

Forward-looking. The BTC Authorization Domain depends on `L1_RELAYED` activation, which is reserved under the Phase 1 profile (SPEC §6.1).

Non-normative. The BTC study is research material, not protocol specification. SPEC.md remains authoritative.

Not Phase 1 active. No domain currently uses `L1_RELAYED`. The BTC study describes what would be possible under a future profile.

Not a production bridge. The study does not specify BTC custody. The Bitcoin-side enforcement layer (whether BitVM-style, threshold signing, or other) is external work that the BTC study refers to but does not design in full.

Not BTC custody by Zenon. Project Zeno does not custody BTC. The BTC Authorization Domain verifies Bitcoin events and authorizes downstream actions; the actual BTC sits on Bitcoin under whatever mechanism the Bitcoin-side layer specifies.

An authorization-domain design combining Bitcoin SPV verification, zBTC accounting, burn authorization for withdrawal, and an external Bitcoin-side enforcement layer that must be specified separately.

The BTC study is useful precisely because it shows the decomposition explicitly:

Bitcoin verifies custody state externally. The Bitcoin-side machinery, whatever it is, manages BTC on Bitcoin.

Zeno verifies Bitcoin evidence. The domain STF accepts SPV proofs, checks header validity and confirmation depth, and confirms transaction inclusion.

Settlement accounts for zBTC. The wrapped claim balance is L2 state, governed by domain contract logic and protected by the conservation invariant.

Outbox emits withdrawal authorization. When zBTC is burned, the domain emits an authorization message that downstream parties can consume.

Bitcoin-side machinery enforces release. The actual BTC release happens on Bitcoin, governed by the Bitcoin-side mechanism, not by Project Zeno.

Relayers and watchers move and police evidence. Relayers submit headers and proofs (under future `L1_RELAYED`); watchers replay execution and alarm on divergence (with the limits defined in `../Frontier/02_DOMAIN_VERIFICATION_LIMITS.md`).

The BTC design is a model for decomposition, not a shortcut around custody.

## 15. Open questions for Domain Settlement implementers

1. What is the canonical naming standard for Interop documents: Authorization Domain, Verification Domain, Feasibility Study, or a finer-grained taxonomy?

2. What chain-specific proof formats are acceptable inside a domain STF? Are there constraints on proof complexity, verification cost, or determinism that apply uniformly across chains?

3. What proof sizes fit within Zenon L1 account-block limits versus DA-referenced payloads? The `MaxDataLength` (16 KiB) per account-block is a hard constraint; larger proofs require chunking, compression, or DA references.

4. What external input sources require `L1_RELAYED` activation? Is each chain a separate `inputSource` registration, or does one `L1_RELAYED` activation enable multiple chain-specific domains?

5. What chain-specific finality or confirmation predicates must be pinned in `stfSpecHash`? Each chain has its own finality model (PoW depth, finalized checkpoints, validator-set confirmations, etc.), and the predicate must be deterministic.

6. What custody models are acceptable for wrapped claims? Should the spec define a minimum set (threshold signing, lockbox contract, BitVM-style) or allow arbitrary mechanisms?

7. How should Settlement distinguish internally custodied ZTS assets from externally backed wrapped claims in its public state? Are these distinct asset classes with different release rules?

8. What disclosure metadata must every Interop domain publish? Is there a required disclosure surface analogous to the SPEC §6.1 disclosure requirement for `EXTERNAL_OBSERVED`?

9. What role, if any, should Sentinels play in relaying, proof serving, watching, or custody for Interop domains? The Frontier discipline (no role assignment without explicit spec) should be maintained.

10. What role, if any, should QSR play in service bonding for Interop infrastructure? Same discipline: speculative unless specified.

11. What is the minimal acceptance-test standard before a design can leave research and demo status? What constitutes a credible signet implementation, a credible testnet, or a credible production deployment?

12. What is the naming threshold for calling something a bridge? At what point of specification completeness can a design honestly use that word?

## 16. Summary

Interoperability is not one thing. It is a stack of separable claims:

What can be verified.
What can be accounted for.
What can be messaged.
What can be custodied.
What can be enforced.
What data must be available.
What phase the mechanism belongs to.

Project Zeno can study powerful interoperability designs by keeping those claims separate. The Frontier folder defined the boundaries. The Interop folder applies them to specific chains. Each chain-specific study decomposes the design into the seven layers above, labels each layer's phase status, and discloses its weakest assumption.

The honest default name is Authorization Domain, not bridge. A bridge claim requires a specified custody and release path. Most early-stage studies will not have that. They will have verification, accounting, and authorization layers stable, with custody mocked or referred out. That is the correct state for early Interop research.

Therefore:

Verification is not custody.
Accounting is not redemption.
Messaging is not bridging.
Runtime compatibility is not liquidity.
Relay is not signing.
DA commitment is not availability.
Sentinel fit is not role assignment.
QSR relevance is not bond assignment.
Phase 1 is bonded attestation.
External-chain release requires external-chain control.

Do not collapse the layers.

The same decomposition discipline that runs through the Frontier series runs through this folder. The chains differ. The decomposition does not. A BTC Authorization Domain, an ETH Authorization Domain, and a SOL Feasibility Study are different documents, but they all answer the same seven questions, label the same phase boundaries, disclose the same weakest assumptions, and resist the same overclaims. That is what makes interoperability research honest. That is what this folder is for.
