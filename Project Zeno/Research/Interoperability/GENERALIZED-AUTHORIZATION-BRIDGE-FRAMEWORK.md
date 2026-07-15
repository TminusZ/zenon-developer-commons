# Generalized Authorization and Bridge Framework: Normative Specification

**Document status:** Normative specification for a generalized, multi-chain Bridge Framework. RFC 2119 / RFC 8174 language throughout.
**Version:** 0.3.2 (semantic-review residual revision)
**Changelog:**
- **0.3.2** Security review follow-up: made the off-chain semantic review of a pinned Interop Enforcement Specification an explicit per-chain trust assumption. Added the residual that a hash proves artifact identity, not adequacy, and that negligent or colluding activation governance can approve a non-conformant foreign deployment despite a non-zero pin.
- **0.3.1** Review pass: made the four-clause governing invariant textually canonical at both ends of the document; moved destination enforcement into an explicit non-canonical boundary addendum. Required every foreign deployment to supply a chain-specific Interop Enforcement Specification before A7 may be considered satisfied. Stress-tested and corrected the worked examples as composed claim/accounting/enforcement flows.
- **0.3.0** Architectural rewrite: introduced Authorization Domains as a first-class responsibility distinct from consensus, execution, and settlement. Added the canonical `AuthorizedClaim`, `ClaimPolicy`, claim-capability registration, claim lifecycle, and Settlement claim dispatcher. Moved chain-neutral bridge accounting from the domain STF into Settlement-owned `BridgeLedger` handlers. Restricted Authorization Domain output to claims and verifier-state updates; an Authorization Domain cannot mint, burn, debit, credit, reserve, or release value directly. Recast `BRIDGE` and `MESSAGING` as registered claim-policy purposes rather than domain classes. Added A15 (claim wire/schema extension) and A16 (Settlement claim-dispatch upgrade). Preserved the two proof ladders, domain isolation, replay, conservation, release adapters, and all active Phase-1 rules.
- **0.2.0** Audit pass: resolved 5 contradictions with `SPEC.md`, 6 overclaims, and Phase-boundary gaps. Added A12 (DomainRecord schema extension), A13 (ATTESTATION-quorum proofData), A14 (outbox encoding extension). Resolved `MINTED` `AssetID` encoding (representation tokens are ZTS on L1; A6 adds issuance-authority gate, not a new encoding). Narrowed wire-compatibility claim to batch commitments only; outbox/DomainRecord/AssetFlowSummary require versioned extensions. Introduced OPEN DESIGN (OD-1 through OD-4) as a category distinct from OPEN PARAMETER for items requiring mechanism design, not just value choices. Scoped `MINTED` as a significant Settlement upgrade. Marked `VerifierRegistry` dispatch interface, `EXTERNAL_OBSERVED` completeness predicate, and timeout proof-of-non-delivery as OPEN DESIGN. Defined `ForeignClaim` and related types as OPEN TYPE per chain. Clarified `VerifyConsensusProof` replaces the three-method sequence for `ZK_CONSENSUS`.
- **0.1.0** Initial draft.
**Relationship to the Project Zenon off-chain-execution corpus (controlling authority, in priority order):**

- `SPEC.md` v1.3.0: Phase 1 off-chain WASM execution, bonded attestation, on-chain conservation. The normative contract for every consensus-visible byte; **governs on any conflict**.
- `ARCHITECTURE.md`: Phase 1 design companion (informative).
- `EXECUTOR.md` v0.2.0: executor binary architecture (relay / executor / watcher roles, plugin seam).
- `BRIDGE-FRAMEWORK-RESEARCH.md`: the shared `BridgeLedger` / `ChainVerifier` / `ForeignReleaser` model (research, non-normative).
- `GENERALIZING-TO-OTHER-CHAINS.md`: the smart-contract-chain integration playbook (research, non-normative).

External bridge systems (IBC, Hyperlane, LayerZero V2, Wormhole, Chainlink CCIP, Axelar, Polkadot XCM, zkBridge and related academic work) are cited **as secondary design references only** and are never controlling. Where the primary corpus and an external system differ, the primary corpus governs the generalized core; the external system is treated as a design reference and labelled as such (Appendix C).

[`The Fourth Room`](https://zenonaliencommons.substack.com/p/the-fourth-room) is the informative architectural rationale for separating foreign observation, verification, authorization, settlement, and enforcement. It is non-controlling; this specification supplies the concrete capability, wire, state-machine, and failure boundaries that the essay deliberately leaves open.

This document is **forward-looking**. It generalizes the Bridge Framework beyond the Phase 1 single-runtime, single-executor, `L1_NATIVE`-only shape. It introduces capabilities (multiple domains, relayed and observed input sources, multi-executor sets, the optimistic and validity execution profiles, foreign light-client and zk-consensus verification, cross-chain messaging with timeouts and acknowledgements, and minted bridge assets) that are **reserved, deferred, or out of scope in Phase 1**. Each such capability is tagged with the assumption it depends on (Assumptions Register, below) and the phase that activates it. **No statement in this document relaxes any Phase 1 on-chain rule that is currently active under `SPEC.md`.**

---

## 0. Conventions, tags, and the Assumptions Register

### 0.1 Requirement keywords

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL are to be interpreted as described in RFC 2119 and RFC 8174 when, and only when, they appear in all capitals.

### 0.2 Content-class tags

Every requirement, parameter, and forward hook is classified into exactly one of four content classes, sharply distinguished per the brief:

- **Normative.** A binding invariant expressed with RFC 2119 keywords. An implementation is non-conformant if it violates a Normative statement.
- **Implementation guidance.** Non-binding engineering advice. An implementation MAY diverge if it preserves all Normative invariants.
- **Deployment parameter.** A value fixed per deployment, bounded by Normative hard bounds. Recorded but not fixed here.
- **Deferred.** A capability or decision explicitly assigned to a later phase or to a future versioned upgrade.

In addition:

- **OPEN PARAMETER.** A value or decision this document deliberately does not fix. An integrator MUST choose it before deployment; choosing it is a precondition of conformance for the affected component. Open parameters are collected in §22. Where an open parameter is owned by the party standing up a domain, it is assigned to **Domain Settlement implementers**.
- **OPEN DESIGN.** A required mechanism whose design is not yet fixed. Unlike an OPEN PARAMETER, it cannot be resolved by selecting a value; the affected capability MUST remain inactive until a versioned specification resolves it.
- **OPEN TYPE.** A chain- or proving-system-specific inner type. Its owner MUST publish canonical encoding, bounds, and a schema hash before deployment; the framework never treats an unspecified runtime object as consensus-visible bytes.

`>`-blockquotes are *Informative* unless they contain an explicit Normative statement.

### 0.3 Source-grounding tags

- **[CORE]**: a requirement imposed by `SPEC.md`; reproduced here for the generalized framing. The on-chain protocol governs.
- **[FRAMEWORK]**: a requirement this document adds for the generalized Bridge Framework. It MUST NOT contradict any `SPEC.md` rule; where it would, the `SPEC.md` rule wins and the [FRAMEWORK] rule is void for that case.

### 0.4 The governing invariants

The active Phase-1 corpus supplies three separated responsibilities:

> **Consensus orders. Execution computes. Settlement anchors.**

This revision introduces the missing fourth protocol responsibility for external facts:

> **Authorization admits external claims.**

The canonical generalized governing invariant is:

> **Consensus orders. Execution computes. Authorization admits. Settlement accounts.**

L1 owns canonical ordering and input finality. The generic executor owns deterministic computation. An Authorization Domain owns the chain-specific decision that a foreign claim has standing under a registered `ClaimPolicy`. Settlement owns custody, accounting, replay protection, conservation, and commitment recording. **No responsibility may silently acquire another responsibility's authority.**

The foreign-fact path is correspondingly explicit: `SourceAdapter` observes; `ChainVerifier` evaluates evidence; domain registration and `ClaimPolicy` grant standing; Settlement accounts.

> **Boundary addendum:** when a settled authorization must cause a change on another chain, that destination chain enforces through its `ReleaseAdapter`. Destination enforcement is deliberately outside the four-clause Zenon-side governing invariant and outside Zenon's direct control.

Physical co-location does not collapse logical ownership. The same executor binary MAY host both Execution Domains and Authorization Domains, but an Authorization Domain's normative output is an `AuthorizedClaim`, never a balance mutation or release. Settlement MAY act on that claim only through a registered, Core-bounded claim handler. This boundary, rather than process topology, defines conformance.

A second inherited invariant, from `EXECUTOR.md`:

> **The runtime is generic. The domain is a plugin. State is always replayable from L1-anchored data.**

### 0.5 Assumptions Register

This document assumes the following. Each assumption is **false or reserved in Phase 1** unless marked active. A capability that depends on an assumption is non-deployable until that assumption holds.

| # | Assumption | Status in Phase 1 | Depends-on note |
|---|---|---|---|
| **A1** | `RegisterDomain` is open to more than the single WASM domain. | Administrator decision; closed by default (`SPEC.md` §3, §6). | Multiple Execution or Authorization Domains. |
| **A2** | `L1_RELAYED` and `EXTERNAL_OBSERVED` input sources are activatable. | Reserved; Core MUST reject them under the Phase-1 profile (`SPEC.md` §6.1). | Every external bridge. |
| **A3** | A multi-member executor set under `RANDOM_BACKUP` (or stronger) is active. | Reserved; Phase 1 is `SINGLE`, size 1 (`SPEC.md` §6.2, §22). | Liveness beyond one executor. |
| **A4** | A fraud-proof referee that re-runs `Apply` and a dispute/slash game exist on-chain. | Deferred to Phase 2 (`SPEC.md` §1, §30). | `OPTIMISTIC` execution profile. |
| **A5** | A validity-proof verifier registry exists on-chain, and `proofData` is honoured. | Deferred to Phase 3; `proofData` MUST be empty in Phase 1 (`SPEC.md` §19, §24). | `ZK_VALIDITY` execution profile. |
| **A6** | Bridge-token issuance authority exists: Settlement MAY mint and burn a representation ZTS backed by finalized foreign-lock claims rather than L1 deposits. | Not in Phase 1 (`SPEC.md` §18.1: L1-backed assets only; `GENERALIZING-TO-OTHER-CHAINS.md` §3 step 7). | `MINTED` custody mode (remote-backed assets). |
| **A7** | A per-chain `ReleaseAdapter` is deployable and audited, and a chain-specific **Interop Enforcement Specification** canonically defines its verification, custody, replay, atomicity, timeout, and upgrade rules. The specification hash is pinned in `ChainBinding`. A7 is false for a deployment until both the adapter and its pinned specification exist. | Out of scope of Zenon Core, but a mandatory bridge-deployment artifact (`BRIDGE-FRAMEWORK-RESEARCH.md` §3.2; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q5). | Peg-out on every chain. |
| **A8** | A ZK-friendly SMT hash migration MAY be required to make the state tree efficiently provable. | Deferred to Phase 3 as a one-time versioned migration (`SPEC.md` §13.2). | `ZK_VALIDITY`, `ZK_CONSENSUS`. |
| **A9** | The Zenon L1 momentum chain provides canonical input ordering and input finality as given. | Active (`SPEC.md` §3, §4). | Everything. |
| **A10** | Zenon L1 has no on-chain `k`-of-`n` multisig primitive; Settlement Periphery is governed by a single administrator with guardian recovery and Core hard bounds. | Active (`SPEC.md` §23). | Governance model. |
| **A11** | The canonical SMT path-native API (`RootOfLeaves` / `ProveByPath` / `VerifyProofByPath` / `VerifyAbsenceByPath`) is available to the executor (landed in `common/trie` or shipped as a local driver). | PREREQUISITE, not yet in the branch (`EXECUTOR.md` §18 P-8). | Executor state store, watcher, referee. |
| **A12** | The Settlement `DomainRecord` schema includes the generalized fields (`domainClass`, `execProfile`, `foreignProfile`, `profileConfig`, `chainBinding`, `claimPolicy`, `finalityModel`), activated via a spork-gated node release. These are Settlement Core additions (semantics-defining, folded into `stfSpecHash`); they are constrained to their Phase 1 default values until the spork activates. | Not in Phase 1; requires a spork-gated `znnd` release. | Every Authorization Domain; A1 depends on this. |
| **A13** | A `protocol_version` bump enables non-empty `proofData` for quorum-attestation payloads under the `ATTESTATION` execution profile. | Not in Phase 1; `proofData` MUST be empty in Phase 1 (`SPEC.md` §19, §24). Phase 3 reserves `proofData` for validity proofs; this assumption gates an intermediate use before Phase 3. | `ATTESTATION`-quorum sub-variant. |
| **A14** | An `outbox_version` bump introduces the extended outbox encoding with `Destination` (tagged union), `Timeout`, and `ackPolicy` fields. | Not in Phase 1; Phase 1 outbox encoding is `SPEC.md` §27.4 exactly. | Cross-chain messaging (§7.1, §7.6), foreign-chain peg-out destinations. |
| **A15** | A `protocol_version` bump introduces canonical `AuthorizedClaim`, `ClaimPolicy`, `ClaimEffectSummary`, `ClaimDispatchData`, and claim-receipt encodings, plus `claimRoot` in the versioned batch extension. | Not in Phase 1. Unknown versions MUST be rejected. | The Authorization Domain → Settlement interface. |
| **A16** | Settlement Core exposes a versioned claim dispatcher and chain-neutral `BridgeLedger` claim handlers. The dispatcher verifies claim provenance, policy capability, replay, finality, value caps, and conservation before applying any accounting effect. | Not in Phase 1; requires a spork-gated `znnd` release. | Asset and message effects caused by Authorized Claims; depends on A6, A12, and A15 as applicable. |

---

## 1. Abstract and scope

### 1.1 Abstract

This document specifies a generalized Authorization and Bridge Framework: a chain-neutral set of abstractions, data structures, state machines, and invariants for admitting verified foreign claims into Zenon Settlement and, as a consequence of those claims, moving **messages** and **assets** between Zenon and arbitrary external chains, EVM and non-EVM, under multiple independently selectable security profiles.

The framework reuses the Zenon-side ledger logic once and exposes a small number of per-chain seams. The foreign-chain client, verification method, claim schema, foreign-side release mechanism, representation-asset identity, and real liquidity are per-chain. The mint and burn accounting, collateral/pool bookkeeping, conservation invariant, peg-out authorization, replay protection, and claim-effect state machines are shared and owned by Settlement. Authorization Domains may establish facts; they cannot perform those accounting operations themselves.

The framework preserves every active Phase-1 rule while extending its separation of concerns to the fourth responsibility: "Consensus orders. Execution computes. Authorization admits. Settlement accounts." It preserves domain isolation, deterministic replay, separation of runtime semantics from custody semantics, and pluggable proof profiles.

### 1.2 In scope

1. A generalized **domain model** with distinct `EXECUTION` and `AUTHORIZATION` domain classes. Each foreign system is understood by an Authorization Domain whose claim capabilities and accounting scope are registered and isolated.
2. **Two orthogonal verification ladders**: an *execution* ladder (`ATTESTATION` → `OPTIMISTIC` → `ZK_VALIDITY`) that secures the correctness of a batch's state transition, and a *foreign-fact* ladder (`COMMITTEE` → `LIGHT_CLIENT` → `ZK_CONSENSUS`) that secures the truth of an external-chain event. Each ladder is per-domain, pluggable, and additive (§6).
3. A canonical **`AuthorizedClaim` boundary**, a Settlement-owned shared `BridgeLedger` state machine for mint/burn/pool/conservation/peg-out, and the two per-chain seams `ChainVerifier` (foreign fact → authorized claim) and `ReleaseAdapter` (Zenon authorization → foreign enforcement) (§7).
4. Canonical **identifiers, wire formats, data model, and state machines** for domains, batches, messages, proofs, assets, and release operations (§8, §9, §10).
5. **Cross-chain messaging** with replay protection, timeouts, acknowledgements, and refunds, generalizing the Phase 1 asynchronous outbox (§7.1, §10.4).
6. **Asset movement** under both custodial-escrow (Phase 1 native ZTS) and remote-backed-mint (representation-asset) custody modes, with the conservation invariants for each (§7.2, §13).
7. A **fee and payment model** spanning source-chain inclusion, off-chain execution, and destination-chain delivery (§7.8).
8. **Failure handling, recovery, testing, verification, deployment, and migration** strategies (§15 through §20).

### 1.3 Out of scope

- The internal consensus mechanics of Zenon L1 or of any foreign chain. Both are consumed as given (`SPEC.md` §2.1).
- The cryptographic construction of any specific zero-knowledge proving system. The framework fixes the *extension points* a proof system plugs into, never the curve, field, or circuit (§6.4, OPEN PARAMETER).
- Synchronous cross-domain or cross-chain calls. All cross-domain interaction is asynchronous (outbox → finalize → relay → inbox), per `SPEC.md` §17.1.
- The implementation of the foreign-side `ReleaseAdapter` contracts. The framework defines the *authorization object* they consume and the invariants they MUST satisfy, never their code (`BRIDGE-FRAMEWORK-RESEARCH.md` §3.2; A7).
- Foreign-chain custody key management (for example BTC threshold signing). This is a key-custody problem outside the executor binary's scope (`EXECUTOR.md` §12).
- Liquidity provisioning, market-making, and fast-exit LP economics. These are a UX layer, not a trust dependency (`GENERALIZING-TO-OTHER-CHAINS.md` §3 step 9).

### 1.4 Relationship between the framework, an Authorization Domain, and a bridge

Class versus instance (`BRIDGE-FRAMEWORK-RESEARCH.md` §1):

```
AuthorizationBridgeFramework              ← the shared template (this document)
  ├─ EXECUTION domain                     ← Phase 1 WASM contracts, the base case
  ├─ Bitcoin AUTHORIZATION domain         ← emits registered Bitcoin claims only
  ├─ Ethereum AUTHORIZATION domain        ← emits registered Ethereum claims only
  └─ Solana AUTHORIZATION domain          ← emits registered Solana claims only

Settlement Claim Dispatcher               ← checks standing, replay, finality, caps
  ├─ BridgeLedger handler                 ← asset accounting and peg authorization
  └─ Message handler                      ← foreign-message admission and delivery

Foreign ReleaseAdapter                    ← destination-side enforcement, per chain
```

An Authorization Domain is not itself a bridge. A complete bridge is the composition of an Authorization Domain, a registered claim policy, Settlement's claim handler, and a foreign `ReleaseAdapter`. Same shared Settlement code, separate verifier state, accounting scope, liquidity, and foreign contracts.

---

## 2. Trust model and threat model

### 2.1 The load-bearing honesty statement

> **An Authorized Claim is exactly as trustworthy as the weaker of its authorization-execution profile and its foreign-fact profile, and no more. Settlement containment limits the scope of a false claim; it does not make the claim true. This MUST be communicated without qualification or obfuscation.** [CORE/FRAMEWORK].

There is no single global trust assumption. Each Authorization Domain carries its own profile pair and policy scope. Four permanent safety rails keep execution correctness, foreign truth, availability, and authorization/accounting authority distinct:

- **Rail 1: STF-verifiable does not mean Settlement-verified.** Under execution profile `ATTESTATION`, Settlement records `preStateRoot`/`postStateRoot` but **MUST NOT** verify them; their correctness rests on the bonded executor set, not on the chain. Settlement verifies execution only under `ZK_VALIDITY` (a validity proof) or, conditionally and only when challenged, under `OPTIMISTIC` (a fraud proof). [CORE] (`SPEC.md` §1, §5, §26.)
- **Rail 2: EXTERNAL_OBSERVED commits what was observed, not what was true or authorized.** A commitment binds the inputs consumed. The foreign-fact profile determines whether the event is true; `ClaimPolicy` determines whether that class of event has standing; Settlement determines what bounded accounting effect follows. [FRAMEWORK]
- **Rail 3: Commitment is not availability.** `DAHash` commits a bundle; it does **not** guarantee the bundle is retrievable. Data-availability enforcement is a separate, later mechanism. An unavailable bundle reduces the affected batch to reliance on executor honesty regardless of any proof profile. [CORE] (`SPEC.md` §20.)
- **Rail 4: Verification is not authorization, and authorization is not accounting.** A proof may verify while proving a claim Settlement is not registered to hear. Authorization Domains MUST NOT perform Settlement effects; Settlement MUST NOT interpret chain-specific evidence. [FRAMEWORK]

### 2.2 What is guaranteed on-chain, independently of executor honesty

Generalizing `SPEC.md` §1, the following hold for every domain in every profile, enforced by Settlement Core:

1. **Aggregate custody solvency per authorization scope and asset.** Settlement MUST NOT authorize outflow exceeding accounted inflow for the `ClaimPolicy` capability and asset.
2. **Capability and accounting isolation.** Every claim, custody record, commitment, deposit, withdrawal, and replay key MUST be scoped by `domainId`; asset accounting MUST additionally be scoped by the registered policy/asset binding.
3. **Canonical input order fixed by L1.** For `L1_NATIVE` and `L1_RELAYED` domains, the executor cannot reorder, skip, or privately insert inputs; omission produces a non-contiguous batch rejected on-chain.
4. **Batch chaining, contiguity, withdrawal delay, per-batch caps, and public commitment visibility** during the finality window.
5. **At-most-once claim and message processing** via `ProcessedClaim` and `ProcessedOutbox`.

### 2.3 What is NOT guaranteed, by profile

| Property | `ATTESTATION` exec | `OPTIMISTIC` exec | `ZK_VALIDITY` exec |
|---|---|---|---|
| Per-account / per-message correctness verified on-chain | No (executor honesty) | Only if a watcher challenges in time (1-of-N honest + DA) | Yes (proof) |
| On-chain verification of `postStateRoot` | No | On challenge | Yes |
| Slashing for incorrect execution | No | Yes, on successful fraud proof | N/A (invalid proof cannot finalize) |

| Property | `COMMITTEE` foreign | `LIGHT_CLIENT` foreign | `ZK_CONSENSUS` foreign |
|---|---|---|---|
| Foreign event truth established by | Attester quorum honesty | Foreign consensus + verifier correctness | Succinct proof + verifier correctness |
| Tolerable adversary | < quorum threshold colluding | < foreign-chain safety threshold | < foreign-chain safety threshold |

### 2.4 Adversary model

The framework defends against an adversary that MAY: (a) control the executor (propose arbitrary roots) up to the limit of the active execution profile; (b) control any relayer (relaying is permissionless and trustless: a relayer can only withhold, never forge, since the STF re-validates every datum, `EXECUTOR.md` §12); (c) reorganize a foreign chain up to its stated finality bound; (d) withhold a DA bundle; (e) submit malformed or replayed inputs, proofs, and messages; (f) attempt to manipulate fee quotes; (g) compromise a single foreign-side verifier contract; and (h) attempt cross-domain custody reachability. The adversary MAY NOT: break the hash function (SHA3-256), forge L1 momentum finality, exceed a foreign chain's stated safety threshold, or compromise the Settlement Core node-binary logic (changeable only by a sanctioned release, `SPEC.md` §5.2). The administrator is **partially trusted**: bounded by time-locks, guardian recovery, and Core hard bounds (§18; `SPEC.md` §23), and explicitly enumerated as a defended-against compromise target (§13.10).

### 2.5 Trust-minimization direction

The two ladders are strict strengthenings. Migrating a domain along either ladder removes trust without changing the Zenon-side ledger, the commitment format, or the custody accounting (§6.6, §20.4). The economic case for the shared framework is precisely that the strengthening is written once and inherited by every instance.

---

## 3. Goals, non-goals, and open parameters

### 3.1 Goals

- **G1.** Reuse the Settlement-owned bridge ledger across all chains; adding a chain costs an Authorization Domain, a `ReleaseAdapter`, and policy/asset registration, never a new accounting engine.
- **G2.** Support EVM and non-EVM targets without collapsing either into the other. The framework MUST NOT assume EVM semantics, EVM account models, or a single proof system.
- **G3.** Make the security profile a per-domain, pluggable choice with explicit, enumerated extension points, and a clean additive migration path.
- **G4.** Preserve deterministic replay: any party MUST be able to reconstruct a domain's state from L1-anchored data alone, with no live foreign-chain access (`EXECUTOR.md` §10).
- **G5.** Keep L1 cost bounded and constant per batch: L1 stores roots and bounded metadata only (`SPEC.md` §3).
- **G6.** Make every failure mode explicit, fail-closed, and recoverable from a finalized anchor (`EXECUTOR.md` §14, §15).
- **G7.** Make foreign knowledge reusable without granting its verifier custody or accounting authority.

### 3.2 Non-goals

- **NG1.** Trustless execution in the attestation profile. That profile is bonded attestation, full stop (Rail 1).
- **NG2.** Synchronous cross-domain or cross-chain calls (`SPEC.md` §17.1).
- **NG3.** A protocol-level per-account balance ledger. Per-account balances are contract/STF state; Settlement bounds only the aggregate (`SPEC.md` §18.1a).
- **NG4.** A universal proof object that every foreign verifier consumes unchanged. The framework permits per-releaser proof encodings (§6.4, OPEN PARAMETER; `BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q2).
- **NG5.** Fixing latency or security budgets. These are deployment choices.
- **NG6.** Liquidity, fronting, and LP economics as a trust dependency.
- **NG7.** Treating an Authorization Domain as a custodian, balance ledger, minting authority, or destination enforcer.

### 3.3 Open parameters (collected in full in §22)

The framework deliberately does not fix, among others: the foreign-chain confirmation/finality predicate per chain; the attester set size and threshold per `COMMITTEE` domain; the challenge-window duration per `OPTIMISTIC` domain; the proving system, curve, and verifying-key management per zk domain; the representation-asset decimals-normalization policy; the timeout and acknowledgement windows per messaging channel; the fee-quote denomination and refresh policy; and the foreign verifier-contract upgrade governance. Each is marked OPEN PARAMETER at its point of use and assigned an owner.

---

## 4. Definitions and terminology

A consolidated glossary is Appendix A. The terms that carry Normative weight are defined here.

- **Domain.** The unit Settlement anchors. An `EXECUTION` Domain computes application state. An `AUTHORIZATION` Domain maintains a verified view of one foreign system and emits claims permitted by its policy.
- **Authorization Domain.** A domain whose sole protocol authority is to evaluate foreign evidence and emit canonical `AuthorizedClaim`s. It cannot mutate custody, balances, issuance, reserves, or release state.
- **`AuthorizedClaim`.** The canonical statement crossing from an Authorization Domain into Settlement: issuer, policy version, claim type, unique foreign event, subject/value, and finality reference.
- **`ClaimPolicy`.** The Core-bounded capability registration enumerating allowed claim types, schemas, assets, handlers, caps, and finality requirements.
- **Settlement.** The runtime-agnostic Zenon embedded contract that holds escrow, maintains the domain registry, and records batch commitments. Split into **SettlementCore** (node-binary, spork-gated) and **SettlementPeriphery** (administrator-tunable storage, Core-clamped). (`SPEC.md` §5.)
- **Executor.** The bonded off-chain binary that consumes the canonical input stream for its domain, runs the STF, and submits batch commitments. (`SPEC.md` §22; `EXECUTOR.md` §4.)
- **Watcher.** The same binary in compare mode: reproduces the proposer's roots and surfaces divergence; under `OPTIMISTIC`, emits a fraud proof. (`EXECUTOR.md` §11.)
- **Relayer (relay role).** A permissionless, trustless pump that posts external-source data to L1 as Settlement account-blocks (`L1_RELAYED` / `EXTERNAL_OBSERVED`), and that carries finalized outbox messages to their destination. A relayer can only withhold; it can never forge, because the STF and Settlement re-validate everything (`EXECUTOR.md` §12).
- **STF (state-transition function).** The pure, deterministic function `Apply(state, input) → effects` a domain plugin implements. No clock, RNG, network, or environment (`SPEC.md` §7.3; `EXECUTOR.md` §7).
- **`BridgeLedger`.** The shared, chain-neutral Settlement claim handler for mint/burn/pool/conservation/peg-out/replay. An Authorization Domain cannot invoke it directly.
- **`ChainVerifier`.** The per-chain read seam internal to an Authorization Domain.
- **`SourceAdapter`.** The per-chain relay seam: watches a foreign chain and decides what to post to L1 (`EXECUTOR.md` §7 `Source`).
- **`ReleaseAdapter` (a.k.a. `ForeignReleaser`).** The per-chain write seam, living **on the foreign chain**: consumes a finalized Zenon peg-out authorization and releases real assets (`BRIDGE-FRAMEWORK-RESEARCH.md` §3.2).
- **Execution profile.** How a batch's STF correctness is secured: `ATTESTATION` | `OPTIMISTIC` | `ZK_VALIDITY`. The Phase 1→2→3 ladder, lifted to a per-domain dimension (§6.3).
- **Foreign-fact profile.** How a foreign-chain event's truth is established: `NONE` | `COMMITTEE` | `LIGHT_CLIENT` | `ZK_CONSENSUS` (§6.4).
- **Input source.** Where a domain's inputs originate and from where canonical order, DA, and censorship-resistance derive: `L1_NATIVE` | `L1_RELAYED` | `EXTERNAL_OBSERVED` (`SPEC.md` §6.1).
- **Custody mode.** How an asset is represented on Zenon: `ESCROW` (real ZTS in Settlement custody) | `MINTED` (a representation asset backed by attested foreign collateral) (§7.2).
- **Peg-in.** An Authorization Domain proves a foreign lock and emits a lock claim; Settlement accepts and credits or mints under policy.
- **Peg-out.** Asset movement Zenon → foreign: burn or debit on Zenon, then authorize a foreign release via a `kind=1` outbox object.
- **Outbox message.** The asynchronous effect object a contract or the runtime emits, committed in `outboxRoot`, relayed after finality. `kind=0` is L2/cross-domain delivery; `kind=1` is an L1/foreign withdrawal authorization (`SPEC.md` §17.2, §27.4).
- **Batch.** A contiguous slice of a domain's canonical input subsequence, `≤ MaxBatchInputs`, summarized by one batch commitment (`SPEC.md` §4.6, §19).
- **Finality (of a batch).** The point at which withdrawals/releases MAY be authorized: elapsed withdrawal delay (`ATTESTATION`), elapsed challenge window with no successful challenge (`OPTIMISTIC`), or verified validity proof (`ZK_VALIDITY`) (§10.2).
- **Conservation invariant.** The per-(authorization scope, asset) predicate Settlement enforces after every mutating operation.

---

## 5. System model

### 5.1 Layers and actors

The framework spans four Zenon-side responsibilities, a foreign enforcement boundary, and an off-chain delivery substrate.

1. **L1: Zenon momentum chain (consensus orders).** Provides total canonical ordering of all inputs and input finality; anchors Settlement storage (including all batch-commitment roots) through `ChangesHash` with no momentum-format change. The sole source of truth for canonical input order and input finality. MUST NOT execute any STF. (`SPEC.md` §3, §4; `ARCHITECTURE.md` §3.)
2. **Execution runtime (execution computes).** One generic executor hosts pure deterministic domain STFs. It grants no claim standing.
3. **Authorization Domains (authorization admits).** An `AUTHORIZATION` plugin maintains a verified foreign view and emits only claims allowed by its `ClaimPolicy`.
4. **Settlement embedded contract (settlement accounts).** Maintains domain/policy registries, dispatches finalized claims, and enforces replay, custody, conservation, caps, finality, and pause.
5. **Foreign chains and enforcement adapters.** Each bridged chain runs a `ReleaseAdapter`; this is destination-side enforcement, not Zenon authorization.
6. **DA substrate (best-effort).** Sentinel/libp2p nodes serve bundles by `DAHash`.

### 5.2 Generalized architecture (Mermaid flowchart)

```mermaid
flowchart TB
    subgraph FOREIGN["Foreign chains (per-chain, A7)"]
        FCsrc["Source events<br/>(locks, finality, spends)"]
        REL["ReleaseAdapter / ForeignReleaser<br/>(BitVM graph | EVM verifier contract | SVM program)"]
    end

    subgraph EXEC["Generic execution runtime (execution computes), EXECUTOR.md"]
        SRC["SourceAdapter.Watch<br/>(relay role)"]
        PIPE["Generic runtime pipeline<br/>follower → STF → SMT → batch → DA"]
        WATCH["Watcher / fraud-proof harness<br/>(OPTIMISTIC)"]
    end

    subgraph AUTH["Authorization Domain (authorization admits)"]
        CV["ChainVerifier<br/>(foreign-fact profile)"]
        POLICY["ClaimPolicy<br/>(registered capability cage)"]
        CLAIM["AuthorizedClaim<br/>(canonical statement)"]
    end

    subgraph L1["L1, Zenon momentum chain (consensus orders), SPEC.md §4"]
        ORDER["Canonical ordering<br/>globalInputIndex, confirmed momenta"]
    end

    subgraph SETTLE["Settlement embedded contract (settlement accounts), SPEC.md §5"]
        CORE["SettlementCore<br/>registry · standing · custody · conservation · finality · replay"]
        HAND["Claim dispatcher + BridgeLedger<br/>registered, Core-bounded effects"]
        PERI["SettlementPeriphery (admin, Core-clamped)<br/>caps · delays · verifier registries · admin/guardians"]
    end

    USER["User / dApp"]

    USER -->|"Deposit / CallL2 / Redeem (account-block)"| ORDER
    FCsrc -->|"observed"| SRC
    SRC -->|"L1_RELAYED: post headers + inclusion proofs (account-block)"| ORDER
    ORDER -->|"confirmed, ordered {domainId, payload}"| PIPE
    PIPE --> AUTH
    CV --> CLAIM
    POLICY --> CLAIM
    CLAIM -->|"claimRoot"| PIPE
    PIPE -->|"SubmitBatch(commitment, proofData, claimRoot)"| CORE
    CORE --- HAND
    CORE --- PERI
    PIPE -->|"publish bundle"| DA["Sentinel / libp2p (DAHash, best-effort)"]
    WATCH -->|"read committed batch"| CORE
    WATCH -->|"OPTIMISTIC: Challenge(fraud proof)"| CORE
    CORE -->|"finalized claim inclusion"| HAND
    HAND -->|"mint/credit/message or kind=1 authorization"| CORE
    CORE -->|"FINALIZED kind=1 authorization"| REL
    REL -->|"release real asset"| USER
    CORE -->|"kind=1 peg-out / withdrawal (RelayMessage)"| USER
```

### 5.3 The two structural corrections

> **The withdrawal/peg-out trigger on Zenon is shared, not per-chain.** Getting an asset out is always "burn or debit on Zenon → Settlement commits a `kind=1` outbox authorization → after finality, a relayer carries it to the destination." There is **no** per-chain withdrawal contract *on Zenon*. The per-chain contract is the **consumer** of that authorization and lives **on the foreign chain** (`BRIDGE-FRAMEWORK-RESEARCH.md` §2). This is what lets a single set of Settlement rules serve BTC, ETH, SOL, and Zenon-native withdrawals identically.

> **The foreign verifier reports facts; it does not move the books.** Foreign observations become `AuthorizedClaim`s. Settlement alone maps a finalized claim to an accounting effect. Putting verification and pool mutation in one `Apply` is non-conformant.

### 5.4 Determinism and replay boundary

[CORE] L2 state MUST be a pure function of L1-anchored data (canonical inputs + commitments + DA bundles). The executor MUST NOT read a live foreign source to *reconstruct* state; foreign reads exist only to *propose* (relay role) and to *watch*. A genesis syncer replays consumed, committed inputs through `Apply` to byte-identical state with no foreign-network access (`EXECUTOR.md` §10). For `L1_RELAYED` domains this is automatic: the relayed headers and proofs are ordinary L1 inputs. For `EXTERNAL_OBSERVED` domains the consumed observations MUST be committed (`inputRoot`) and published (`DAHash`), and state MUST be reconstructible from them alone (`SPEC.md` §6.1, §20).

### 5.5 Compatibility-profile space

A domain occupies a point in a six-dimensional configuration space:

```
(domainClass, inputSource, execProfile, foreignProfile, claimPolicy*, proposerPolicy)
   EXECUTION     L1_NATIVE          ATTESTATION   NONE          null           SINGLE
   AUTHORIZATION L1_RELAYED         OPTIMISTIC    COMMITTEE     ASSET|MESSAGE  RANDOM_BACKUP
                 EXTERNAL_OBSERVED  ZK_VALIDITY   LIGHT_CLIENT                 STAKE_WEIGHTED
                                                  ZK_CONSENSUS
```

Phase 1 occupies `(EXECUTION, L1_NATIVE, ATTESTATION, NONE, null, SINGLE)`. `AUTHORIZATION` requires a non-null policy and foreign profile.

---

## 6. Domain model and compatibility profiles

### 6.1 The generalized `DomainRecord`

[FRAMEWORK] Settlement storage MUST hold one `DomainRecord` per `domainId`, generalizing `SPEC.md` §6. Fields added beyond the Phase 1 record are marked **(new)**; all Phase 1 fields retain their Phase 1 meaning and constraints.

> **Settlement Core change (A12/A15/A16).** Activating `AUTHORIZATION` requires the extended domain schema, claim encodings, and claim dispatcher. Until those assumptions land, only Phase-1 defaults are legal.

```
DomainRecord {
    domainId        : u32                  // assigned at RegisterDomain
    domainClass     : EXECUTION | AUTHORIZATION             // normative authority boundary
    runtimeKind     : RuntimeKind          // WASM | ... ; the STF host. Phase 1 = WASM
    stfSpecHash     : bytes32              // pins runtimeKind, VM version, genesis, input-envelope +
                                          //   commitment format, AND the profile bindings below
    inputSource     : L1_NATIVE | L1_RELAYED | EXTERNAL_OBSERVED            // SPEC.md §6.1
    execProfile     : ATTESTATION | OPTIMISTIC | ZK_VALIDITY                // (new) secures the batch STF
    foreignProfile  : NONE | COMMITTEE | LIGHT_CLIENT | ZK_CONSENSUS        // (new) secures foreign facts
    profileConfig   : ProfileConfig        // (new) tagged union, §6.3/§6.4
    chainBinding    : ChainBinding | null  // non-null iff AUTHORIZATION
    claimPolicy     : ClaimPolicy | null   // non-null iff AUTHORIZATION
    executors       : ExecutorSet          // bonded set; size 1 in Phase 1
    minExecutors    : u16                  // 1 in Phase 1; below this the domain cannot finalize
    proposerPolicy  : SINGLE | RANDOM_BACKUP | STAKE_WEIGHTED               // SPEC.md §6.2
    valueCaps       : ValueCaps            // per-window per-asset outbox caps; sizes the bond
    finalityModel   : DELAY | CHALLENGE_WINDOW | PROOF_VERIFIED             // (new) derived from execProfile
    status          : ACTIVE | PAUSED
}
```

```
ClaimPolicy {
    policyVersion    : u32
    purpose          : ASSET | MESSAGE
    capabilities     : List<ClaimCapability>
    activationHeight : u64
    exitDelay        : u64
}

ClaimCapability {
    claimType        : FOREIGN_LOCK | FOREIGN_RELEASE | FOREIGN_MESSAGE |
                       FOREIGN_NON_DELIVERY | FOREIGN_MISCONDUCT
    claimSchemaHash  : bytes32
    handlerId        : bytes32
    assetBindings    : List<AssetID>
    valueCaps        : ValueCaps
    finalityRuleHash : bytes32
}
```

```
ChainBinding {
    foreignChainId    : ChainId            // canonical foreign-chain identifier (§8.2)
    chainVerifierId   : bytes32            // pins the ChainVerifier implementation (foreign-fact verification)
    genesisAnchor     : Bytes              // light-client checkpoint: header / sync-committee root / bank hash
    releaseAdapterRef : Bytes              // foreign-side ReleaseAdapter identifier (addr / script / graph id)
    enforcementSpecHash : bytes32          // hash of the controlling per-chain Interop Enforcement Specification
    finalityParams    : Bytes              // OPEN PARAMETER per chain: confirmation depth / finality predicate
}
```

`chainBindingHash = SHA3-256(canonical ChainBinding encoding)`. `enforcementSpecHash = SHA3-256(exact published Interop Enforcement Specification artifact bytes)`; the artifact's byte sequence, not a rendered document, is controlling.

**Normative:**
- `domainClass`, profiles, `claimPolicy`, and every `ChainBinding` field are semantics-defining and MUST be folded into `stfSpecHash`. [CORE/FRAMEWORK]
- An `AUTHORIZATION` domain MUST remain inactive while `enforcementSpecHash` is zero, unavailable to validators, or inconsistent with `releaseAdapterRef`. Changing the adapter or its controlling specification requires a versioned domain migration (§20.3). [FRAMEWORK, A7]
- `chainBinding` and `claimPolicy` MUST both be null for `EXECUTION` and non-null for `AUTHORIZATION`. Core MUST reject class-mismatched outputs. [FRAMEWORK]
- Each capability MUST identify one registered Core-bounded handler. Guardians MAY pause immediately; narrowing follows `SoftDelay`; broadening requires a policy-version bump and full exit window.
- `purpose=ASSET` and `purpose=MESSAGE` MUST remain separate domains even when they reuse verifier code.
- A claim outside the active capability has no standing even if its proof verifies.
- `finalityModel` MUST equal the value mandated by `execProfile` (§10.2): `ATTESTATION → DELAY`, `OPTIMISTIC → CHALLENGE_WINDOW`, `ZK_VALIDITY → PROOF_VERIFIED`. Core MUST reject a `RegisterDomain` whose `finalityModel` disagrees with `execProfile`. [FRAMEWORK]
- **Phase 1 profile:** Core MUST accept only `EXECUTION`, `L1_NATIVE`, `ATTESTATION`, `NONE`, null chain/policy, one executor, and `SINGLE`. [CORE]

### 6.2 Input-source classes

[CORE] Every domain MUST declare `inputSource`. The value is binding on how the canonical input stream is established and on the DA and censorship guarantees offered; it MUST be surfaced as part of the domain's trust profile (`SPEC.md` §6.1).

| `inputSource` | Inputs originate as | Canonical order | Data availability | Censorship-resistance |
|---|---|---|---|---|
| `L1_NATIVE` | Settlement account-blocks | L1 momentum order | Inherited from L1 | Native force-inclusion |
| `L1_RELAYED` | External data posted to Settlement as account-blocks | L1 momentum order of the relaying blocks | Inherited from L1 | Permissionless relay + force-inclusion |
| `EXTERNAL_OBSERVED` | Observations read directly by the executor | External order under a domain-pinned finality predicate, committed by the executor | The external system + the published bundle (not L1-guaranteed) | Domain completeness predicate, fraud-enforced |

**Normative:**
- The input-source taxonomy is a three-property classification: **(order source, DA source, censorship mechanism)**. Each class fixes all three. Any future input-source class MUST specify all three properties explicitly; adding one is a `stfSpecHash`-level change. [FRAMEWORK] This document does not define a fourth class; doing so is OPEN PARAMETER.
- For `L1_RELAYED`, an Authorization Domain MUST establish input validity and canonicity inside `Apply`, update only verifier/claim state, and reject data that does not extend its foreign view. [CORE/FRAMEWORK]
- For `EXTERNAL_OBSERVED`, the domain MUST pin a deterministic finality/confirmation predicate in `stfSpecHash`; consumed observations MUST be committed (`inputRoot`) and published (`DAHash`); and L2 state MUST be reconstructible from the committed inputs and bundle alone. The weaker, non-L1 DA guarantee MUST be disclosed (Rail 3). The "fraud-enforced" completeness in the table above depends on A4 (the fraud-proof referee); without it, completeness is enforced only by watcher comparison without on-chain recourse. The completeness predicate itself (how to define "all canonical external items" for a given source) is an **OPEN DESIGN** question, not just an OPEN PARAMETER; it is source-specific and MUST be defined per domain. [CORE]
- For all classes the executor MUST NOT reorder, skip, or privately insert inputs; for external sources this is a **completeness** requirement enforced by per-domain input-sequence contiguity (`SPEC.md` §4.6, §4.7). [CORE]

> *Informative.* Foreign evidence is an ordered domain input. The Authorization Domain verifies it and emits a claim; Settlement never interprets chain-specific evidence.

### 6.3 The execution profile ladder (secures the batch STF)

[FRAMEWORK] `execProfile` determines how Settlement treats `preStateRoot`/`postStateRoot`, what `SubmitBatch` verifies, the finality model, and the content of the reserved `proofData` field (`SPEC.md` §19). This is the Phase 1→2→3 ladder of `SPEC.md` §2.2 lifted to a per-domain dimension.

```
ProfileConfig (execProfile arm) :=
  ATTESTATION  { attesterThreshold : AttesterPolicy }     // single-bonded (Phase 1) or quorum (A13)
  OPTIMISTIC   { challengeWindow : u64 (heights),         // ≥ WithdrawalDelay floor
                 fraudVerifierRef : bytes32 }             // referee registry entry (A4)
  ZK_VALIDITY  { validityVerifierRef : bytes32,           // verifier registry entry (A5)
                 verifyingKeyId : bytes32,
                 publicInputSchema : bytes32 }
```

| `execProfile` | `SubmitBatch` verifies | `proofData` carries | Finality | On-chain correctness | Penalty |
|---|---|---|---|---|---|
| `ATTESTATION` | Proposer entitlement, contiguity, size, `assetFlowSummary`, chaining; **NOT execution** | Empty (single-bonded, Phase 1) or the quorum attestation under `AttesterPolicy` (requires A13: `protocol_version` bump) | `DELAY` (withdrawal delay) | None (Rail 1) | Process-fault only in Phase 1; bond at risk via fraud proof once `OPTIMISTIC` is enabled |
| `OPTIMISTIC` | As above, plus opens a challenge window | Empty at submit; fraud proof supplied later via `Challenge` | `CHALLENGE_WINDOW` | On challenge: referee re-runs `Apply` for the single disputed input (`SPEC.md` §4.6, §13.5.1) | Bond slashed on successful fraud proof (A4) |
| `ZK_VALIDITY` | As `ATTESTATION`, plus verifies the validity proof against `verifyingKeyId` before acceptance | The SNARK over the batch transition (and optionally foreign consensus) | `PROOF_VERIFIED` (MAY be immediate) | Full (the proof) | An invalid proof cannot finalize |

**Normative:**
- Under `ATTESTATION`, Settlement MUST NOT verify execution correctness (Rail 1). Under `ZK_VALIDITY`, Settlement MUST verify the validity proof before a batch enters its finalized state and MUST reject a batch whose proof does not verify against the registered `verifyingKeyId`. Under `OPTIMISTIC`, Settlement MUST verify a submitted fraud proof by the referee procedure and, on success, MUST reject the challenged batch and slash the proposer's bond. [FRAMEWORK / CORE]
- A single batch transition MUST satisfy `postStateRoot = F(preStateRoot, input_data, code_hash)` in every profile; the profile changes only *who checks it and when*, never the function (`SPEC.md` §17.1 invariant). [CORE]
- The fraud-proof referee MUST re-run the identical canonical applier (`SPEC.md` §13.5.1), including the deposit-settlement step (`SPEC.md` §18.5 forward hook), so that "the executor ran the wrong code/version" is ordinary state divergence, not a special Settlement failure mode (`SPEC.md` §5.4). [CORE]
- `proofData` MUST be the zero-length encoding under `ATTESTATION`-single-bonded and under `OPTIMISTIC` at submit time; Core MUST reject a non-empty `proofData` outside the profiles and phases that define its contents (`SPEC.md` §19, §24). The `ATTESTATION`-quorum sub-variant, which places a quorum attestation in `proofData`, requires a `protocol_version` bump (A13) and MUST NOT be activated while Phase 1 `proofData` rules are in force. [CORE]

### 6.4 The foreign-fact profile ladder (secures external-chain truth)

[FRAMEWORK] For `AUTHORIZATION` domains, `foreignProfile` secures truth; `execProfile` secures computation; `ClaimPolicy` grants standing. All three are independent.

```
ProfileConfig (foreignProfile arm) :=
  NONE         { }                                        // EXECUTION domains
  COMMITTEE    { attesterSet : Set<ForeignAttesterId>,    // relayer/oracle quorum
                 threshold : u16 }
  LIGHT_CLIENT { clientKind : LightClientKind,            // PoW | sync-committee | tower-bft | ...
                 finalityRule : bytes32 }                 // OPEN PARAMETER per chain
  ZK_CONSENSUS { consensusVerifierRef : bytes32,          // succinct proof-of-consensus verifier
                 verifyingKeyId : bytes32 }
```

| `foreignProfile` | Foreign truth established by | Implemented in `ChainVerifier` as | Tolerable adversary |
|---|---|---|---|
| `COMMITTEE` | A quorum of foreign attesters signs the foreign event | Threshold-signature check over a relayed attestation | `< threshold` colluding attesters |
| `LIGHT_CLIENT` | Foreign consensus + inclusion verified from relayed headers/proofs | `VerifyHeaderChain` + `VerifyInclusion` + `VerifyFinality` | `< foreign safety threshold` |
| `ZK_CONSENSUS` | A succinct proof of foreign consensus + inclusion | `VerifyConsensusProof` (the fourth primitive, §7.3) | `< foreign safety threshold` + proof soundness |

**Normative:**
- `foreignProfile = NONE` iff `domainClass = EXECUTION`. [FRAMEWORK]
- Under `LIGHT_CLIENT` and `ZK_CONSENSUS`, the `ChainVerifier` MUST reject any relayed datum that does not extend the verified light-client view; a dishonest relayer MUST be unable to advance the foreign view to a state the foreign chain did not reach (Rail 2). [FRAMEWORK]
- The `finalityRule` (`LIGHT_CLIENT`) and the confirmation/finality predicate in `chainBinding.finalityParams` are OPEN PARAMETER per chain and MUST be chosen so that no Zenon-side release ever finalizes over a re-organizable foreign event (§13.5, §14). [FRAMEWORK]

> The two ladders compose inside an Authorization Domain. Neither pairing grants accounting authority; policy separately determines which facts cross into Settlement.

### 6.5 Legal combinations and constraints

[FRAMEWORK] Core MUST reject a `RegisterDomain` violating any of:

1. `chainBinding = null` and `claimPolicy = null` iff `domainClass = EXECUTION` iff `foreignProfile = NONE`.
2. An `AUTHORIZATION` domain MUST emit only Authorized Claims plus verifier-state changes. A `MESSAGE` policy MUST have no asset binding.
3. `inputSource = EXTERNAL_OBSERVED` MUST be paired with `foreignProfile ∈ {LIGHT_CLIENT, ZK_CONSENSUS}` **or** an explicitly disclosed `COMMITTEE` predicate; an `EXTERNAL_OBSERVED` domain whose observation predicate reduces to "the executor says so" with no foreign-fact profile MUST NOT be activated, because it would violate Rail 2 with no compensating verification.
4. `execProfile = ZK_VALIDITY` requires A5 (validity-verifier registry) and MAY require A8 (ZK-friendly SMT hash); Core MUST reject it until both prerequisites are registered.
5. `execProfile = OPTIMISTIC` requires A4 (fraud-proof referee + dispute game); Core MUST reject it until the referee registry entry exists.

### 6.6 Migration path along both ladders (additive)

[FRAMEWORK] Migration along either ladder is a `stfSpecHash` bump under `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`, changing **no** commitment format and **no** custody accounting:

```
exec:    ATTESTATION ─▶ OPTIMISTIC ─▶ ZK_VALIDITY        (SPEC.md Phase 1 ─▶ 2 ─▶ 3)
foreign: COMMITTEE   ─▶ LIGHT_CLIENT ─▶ ZK_CONSENSUS      (relayer quorum ─▶ verified ─▶ proven)
```

- Each step is a **strict strengthening**: the post-migration domain accepts a superset of the security guarantees and a subset of the trust assumptions of the pre-migration domain. [FRAMEWORK]
- The commitment carries `proofData` (empty → fraud-proof references → validity proof) and `executorId` (single → set member) so that no on-chain footprint changes except added Periphery verifier registries (`SPEC.md` §6.2, §19; `ARCHITECTURE.md` §8). [CORE]
- The withdrawal delay MAY shrink along the execution ladder: it is a full delay under `ATTESTATION`, a challenge window under `OPTIMISTIC`, and proof-generation latency (optionally zero) under `ZK_VALIDITY` (`SPEC.md` §21). [CORE]
- A migration MUST NOT alter any finalized root, receipt, or conservation counter, and the replacement's first batch `preStateRoot` MUST equal the last accepted `postStateRoot` for the domain (`SPEC.md` §6.2, §22). [CORE]
- Ladder migration MUST NOT implicitly widen `ClaimPolicy`; proof strength and authority scope are independent. [FRAMEWORK]

---

## 7. Required abstractions

This section defines the framework's abstractions and their typed interfaces. The interfaces are written in Go-flavoured pseudocode for precision; an implementation MAY use any language that preserves the type contracts and the Normative behaviour. Each interface is also referenced from §12.

The physical plugin seam remains the four-method executor interface, but output depends on `domainClass`: `EXECUTION` emits ordinary effects; `AUTHORIZATION` emits verifier-state changes and claims only.

### 7.0 The Authorization Domain → Settlement boundary

```go
type AuthorizedClaim struct {
    DomainID        uint32
    PolicyVersion   uint32
    ClaimType       ClaimType
    ClaimSchemaHash [32]byte
    ForeignEventID  [32]byte
    Subject         []byte
    Asset           AssetID
    Amount          uint256
    PayloadHash     [32]byte
    FinalityRef     []byte
    ObservedAt      uint64
}

type AuthorizationEffects struct {
    StateDiff StateDiff
    Claims    []AuthorizedClaim
    Events    []Event
}

type ClaimDispatchData struct {
    Payload []byte // preimage of PayloadHash; schema-bound and policy-size-bounded
}
```

`claimId = SHA3-256(canonical AuthorizedClaim encoding)`. `ForeignEventID` MUST be stable for the same foreign occurrence.

The `claimSchemaHash` pins the canonical interpretation of `Subject` and the zero/non-zero rules for all other fields. The framework's built-in schemas are:

| Claim type | Canonical `Subject` | Value fields | Registered handler effect |
|---|---|---|---|
| `FOREIGN_LOCK` | Zenon recipient encoding | `Asset` and `Amount > 0` | atomically record verified collateral and mint/credit under `AssetRegistry` |
| `FOREIGN_RELEASE` | `outboxId:bytes32` | asset/amount MUST equal the `PENDING` authorization | set `PegOutRecord=RELEASED` and reconcile finalized release; never create release authority |
| `FOREIGN_MESSAGE` | registered target identifier | `Asset=0`, `Amount=0`, `PayloadHash` required | deliver the hash-matched dispatch payload to the policy-permitted target |
| `FOREIGN_NON_DELIVERY` | `outboxId:bytes32` | asset/amount MUST equal the `PENDING` authorization | set `PegOutRecord=REFUNDED` and execute the recorded refund after the deadline |
| `FOREIGN_MISCONDUCT` | canonical actor/evidence reference | no transferable value | open only the registered pause/slash adjudication path |

For non-delivery, `ForeignEventID = SHA3-256("NON_DELIVERY" ‖ chainBindingHash ‖ outboxId ‖ finalizedCheckpoint)`; for positive foreign events it MUST be the chain-canonical transaction/log/output identifier normalized by the schema. A handler MUST obtain the refund recipient and original burn from the pending authorization record, never from relayer-supplied replacement fields.

**Normative:**
- An Authorization Domain MUST derive each claim from evidence accepted by its pinned `ChainVerifier` and emit only policy-permitted claims.
- Its `StateDiff` namespace MUST be disjoint from balances, custody, issuance, reserves, and `ProcessedClaim`; a violation MUST halt the domain.
- A claim has no Settlement effect until its batch is finalized and `RelayClaim` supplies a valid inclusion proof under `claimRoot`.
- `RelayClaim` MUST verify canonical encoding, provenance, batch finality, inclusion, policy/capability, both replay keys, remaining `ClaimEffectSummary` budget, hard caps, and conservation. Failure MUST leave state unchanged.
- `ClaimDispatchData.Payload` MUST be at most `MaxDataLength`, MUST satisfy `SHA3-256(Payload) = PayloadHash` when the schema requires a payload, and MUST be empty when the schema forbids one. Policy MAY impose a smaller bound. [FRAMEWORK]
- `PolicyVersion` MUST equal the immutable policy version pinned by the claim's batch. That policy record MUST remain available for the entire claim-dispatch/expiry window; a later policy version MUST NOT retroactively widen, reinterpret, or silently strand an already-finalized claim.
- Successful dispatch MUST atomically consume claim budget and replay keys, invoke exactly one registered handler, record `ClaimReceipt`, and re-check conservation. Settlement MUST NOT decode foreign evidence or call `ChainVerifier`.

### 7.1 Messaging

[FRAMEWORK] The framework generalizes the Phase 1 asynchronous outbox (`SPEC.md` §17) into a cross-domain/cross-chain messaging primitive. All messaging is asynchronous; there are no synchronous cross-domain calls (`SPEC.md` §17.1).

```
Message := {
    srcDomainId   : u32
    srcContractId : bytes32        // bytes32(0) for runtime-emitted messages
    batchId       : u64
    inputIndex    : u64
    outboxIndex   : u32
    kind          : u8             // 0 = cross-domain/cross-chain delivery, 1 = asset withdrawal/peg-out
    dest          : Destination    // §7.1.1
    timeout       : Timeout|null   // §7.5; null = fire-and-forget (Phase 1 semantics)
    ackPolicy     : NONE|ON_DELIVERY|ON_EXECUTION   // §7.6
    payload       : Bytes          // ≤ MaxOutboxPayloadSize; empty for kind=1 (SPEC.md §27.4)
}
```

```
Destination :=
  LOCAL_DOMAIN { domainId : u32 }                          // another Zenon domain's inbox
  FOREIGN_CHAIN { chainId : ChainId ; releaseAdapterRef : Bytes ; recipient : Bytes ; asset : AssetID|null ; amount : u256|0 }
```

**Normative:**
- Every message MUST carry the globally unique `messageId = outboxId = SHA3-256(srcDomainId || batchId || inputIndex || outboxIndex)` (`SPEC.md` §17.3, §27.4). `messageId` is the replay key and the idempotency key for delivery. [CORE]
- A `kind = 1` message MUST have empty `payload` and MUST carry an asset withdrawal/peg-out `Destination` (`SPEC.md` §27.4). A `kind = 0` message MAY carry an arbitrary `payload` to a `LOCAL_DOMAIN` or `FOREIGN_CHAIN` destination. [CORE/FRAMEWORK]
- A `purpose=MESSAGE` policy MAY admit `FOREIGN_MESSAGE` claims only through the message handler and MUST NOT touch custody. [FRAMEWORK]
- Inter-batch total ordering of messages is **Deferred** to Phase 2; in the base profile, replay protection and at-most-once delivery are the only ordering guarantees (`SPEC.md` §17.3). [CORE]

#### 7.1.1 Message lifecycle (summary; state machine in §10.4)

`EMITTED` (in `ContractEffects`) → `COMMITTED` (in `outboxRoot`) → `FINALIZED` (batch finalized) → `RELAYED` (relayer presents proof at destination) → `DELIVERED` / `EXECUTED` (destination consumes) → optionally `ACKED`; or `TIMED_OUT` → `REFUNDED` if undelivered by `timeout`.

### 7.2 Asset representation

[FRAMEWORK] Custody mode is recorded per `(authorizationDomainId, asset)`. The registry binds claims to Settlement handlers; it grants the Authorization Domain no asset access.

| Custody mode | Real asset lives | Zenon-side representation | Peg-in | Peg-out | Requires |
|---|---|---|---|---|---|
| `ESCROW` | Zenon L1 (ZTS) in Settlement custody | the ZTS asset itself | `Deposit` / payable `CallL2` increases `totalDeposited` | `kind=1` outbox releases from custody | Phase 1 native (`SPEC.md` §18) |
| `MINTED` | a foreign chain (locked) | a ZTS representation controlled by Settlement | finalized `FOREIGN_LOCK` claim dispatches mint | finalized local burn authorizes release | A6+A15+A16 |

**Normative:**
- Every `AssetID` in both custody modes MUST satisfy the `SPEC.md` §18.1 encoding: the canonical 32-byte encoding of a 10-byte ZTS identifier, bytes `[0:22]` zero, bytes `[22:32]` the ZTS identifier. Settlement MUST reject any `AssetID` with a non-zero byte in `[0:22]`, regardless of custody mode. [CORE]
- A `MINTED` token MUST be a ZTS whose issuance authority is held by Settlement. Minting is gated on a finalized, replay-checked `FOREIGN_LOCK` claim. [FRAMEWORK]
- The asset registry MUST bind each `MINTED` `AssetID` to a `(domainId, foreignChainId, foreignAssetRef, decimalsPolicy)` tuple; the binding MUST be injective so there is exactly one representation `AssetID` per real foreign asset per domain. The decimals-normalization policy is OPEN PARAMETER (`GENERALIZING-TO-OTHER-CHAINS.md` §7 Q3). [FRAMEWORK]
- Phase-1 contract balances remain STF state. Representation issuance, bridge-pool accounting, claim credits, and reserves are Settlement effects. Authorization Domains write neither. [CORE/FRAMEWORK]
- `MINTED` issuance MUST be performed only by Settlement's registered claim handler after the enclosing Authorization batch is finalized. A local peg-out burn MUST be final before Settlement emits a release authorization. Neither transition may be supplied by an Authorization Domain's `StateDiff` (§13.7). [FRAMEWORK, A6]
- The "lock-and-release versus burn-and-mint" distinction of bridge literature is **directional**: a single domain MAY use lock-and-release in one direction and burn-and-mint in the other. Worked examples B.2 and B.3 show both against the same invariants.

> **Required companion design.** `MINTED` is not activated by a feature flag. Before A6 may be treated as satisfied, a **MINTED Settlement Extension Specification** MUST define the ZTS issuance authority, asset registration and decimal normalization, the exact atomic transitions for lock/mint/burn/authorize/release/refund, counter storage and migration, caps, governance, failure recovery, and conformance vectors. This framework fixes their abstract boundary and conservation predicate; OD-1 records the remaining Core mechanism. Authorization batches carry no mint `AssetFlowSummary`; Settlement reconciles each finalized claim atomically.

### 7.3 Consensus, finality, and the `ChainVerifier`

[FRAMEWORK] The per-chain read seam internal to an Authorization Domain. It is pure and deterministic, with no network access inside `Apply`.

```go
// Per-chain foreign-fact verification (read seam, foreign → Zenon).
type ChainVerifier interface {
    // Advance/reorg the light-client header or finality state from relayed data.
    // MUST reject any datum that does not extend the canonical verified view.
    VerifyHeaderChain(headers []byte, state HeaderState) (HeaderState, error)

    // Prove a specific foreign event (lock / spend / log) is included under a verified header.
    VerifyInclusion(evidence []byte, at HeaderState) (ForeignEvent, error)

    // Decide whether a verified event is final enough to act on (chain-specific predicate).
    VerifyFinality(ref ForeignRef, at HeaderState) (bool, error)

    // Foreign-fact profile ZK_CONSENSUS only: verify a succinct proof of foreign
    // consensus + inclusion in one step, replacing the three-method sequence above.
    // For ZK_CONSENSUS domains, VerifyHeaderChain/VerifyInclusion/VerifyFinality
    // SHOULD return ErrUnsupported; for COMMITTEE and LIGHT_CLIENT domains,
    // VerifyConsensusProof MUST return ErrUnsupported.
    VerifyConsensusProof(proof []byte, claim ForeignClaim) (ForeignEvent, error)
}

// Types consumed by ChainVerifier (per-chain; framework-level contracts only).
// HeaderState: the verified light-client state (chain-specific: sync-committee root,
//   PoW tip + difficulty, Tower-BFT bank hash, etc.). OPEN TYPE per chain.
// ForeignEvent: a proven foreign occurrence (lock, spend, log). Contains at minimum:
//   Outpoint (the replay key), ZenonRecipient, Amount, and a Ref for finality checks.
// ForeignRef: a reference to a ForeignEvent's position in the foreign chain (block hash +
//   tx index, slot + log index, etc.), sufficient for VerifyFinality. OPEN TYPE per chain.
// ForeignClaim: the statement a ZK_CONSENSUS proof proves (chain id + block range +
//   event claim). OPEN TYPE per chain and per proving system.
```

**Normative:**
- The four primitives are the complete extension surface for foreign-fact verification. `VerifyConsensusProof` is the fourth primitive added to the research's three (`BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q1) to make `ChainVerifier` expressive for ZK-light-client chains; a `COMMITTEE` or `LIGHT_CLIENT` domain MUST leave it unsupported. [FRAMEWORK]
- A `ChainVerifier` MUST be a pure function of its arguments and the witnessed `StateAccess`; it MUST NOT read a clock, RNG, network, or environment. The relayed `headers`/`evidence` are decoded inputs, never live reads. [CORE]
- Its output MUST be normalized into `AuthorizedClaim`; Settlement MUST NOT receive chain-specific proof objects. [FRAMEWORK]
- Per-chain instantiations (`BRIDGE-FRAMEWORK-RESEARCH.md` §3.1; `GENERALIZING-TO-OTHER-CHAINS.md` §3 step 1):
  - **BTC:** PoW header chain + difficulty + Merkle inclusion + `K` confirmations.
  - **ETH:** sync-committee (or ZK-of-consensus) tracking + Casper FFG finality + Merkle-Patricia receipt/state proof.
  - **SOL:** leader schedule / Tower-BFT vote tracking (or ZK-of-bank) + slot/bank-hash inclusion.

### 7.4 Relayers, validators, executors, watchers

[CORE] Roles are unchanged from `EXECUTOR.md` §4; the framework only generalizes which domains need which role.

| Role | Does | Bonded? | Runs the STF? | Needed for |
|---|---|---|---|---|
| **Relay** | Watches a foreign source (`SourceAdapter`) and posts its data to L1; also carries finalized outbox messages to destinations | No (permissionless) | No | `L1_RELAYED` / `EXTERNAL_OBSERVED` domains; all peg-out delivery |
| **Executor** | Consumes the input sequence, runs the STF, builds and submits batches | Yes (entitled proposer) | Yes | Every domain |
| **Watcher** | Reproduces the proposer's roots, compares, surfaces divergence; under `OPTIMISTIC` emits a fraud proof | Optional bond | Yes | Every domain; required for `OPTIMISTIC` security |

```go
// Per-chain relay seam (external domains only). EXECUTOR.md §7 Source.
type SourceAdapter interface {
    // What to relay to L1 (e.g. BTC headers + inclusion proofs). Permissionless, trustless:
    // the STF re-validates everything, so a dishonest relayer can only withhold.
    Watch(ctx Context) (<-chan RelayPayload, error)
}
```

**Normative:**
- Relaying MUST be permissionless and trustless: the STF (`Apply`/`ChainVerifier`) MUST re-validate every relayed datum and reject anything non-canonical, so withholding is the only available misbehaviour and is defeated by open relay (force-inclusion/completeness, `SPEC.md` §4.2, §6.1; `EXECUTOR.md` §12). [CORE]
- A non-proposing executor-set member SHOULD operate as a watcher; under `OPTIMISTIC`, at least one honest watcher with bundle access is the security assumption (§13.3; `SPEC.md` §6.2). [CORE]
- A single process MAY host multiple domains and MAY run different roles per domain; state and key material MUST be isolated per domain in-process (`EXECUTOR.md` §4). [FRAMEWORK]

### 7.5 Proofs and the `ReleaseAdapter`

[FRAMEWORK] The per-chain write seam, living **on the foreign chain** (A7). The framework defines the authorization object it consumes and the invariants it MUST satisfy; it does **not** implement the adapter.

```go
// Foreign-side consumer of a finalized Zenon peg-out authorization (off-Zenon, per chain).
// Specified as the contract the foreign deployment MUST satisfy, not as executable Zenon code.
type ReleaseAdapter interface {
    // Verify finalized Zenon Settlement state containing the matching PENDING PegOutRecord
    // and release the real foreign asset exactly once before its deadline.
    Release(authorization PegOutAuthorization, proof ZenonProof) (ReleaseReceipt, error)
}

PegOutAuthorization := {
    domainId           : u32
    outboxId           : bytes32          // = messageId; the foreign-side replay key
    chainBindingHash   : bytes32          // binds adapter + controlling enforcement specification
    asset              : AssetID
    amount             : u256
    recipient          : Bytes            // foreign-chain address/script
    burnRef            : bytes32          // binds to the finalized burn (receipt/outbox commitment)
    timeout            : Timeout          // destination-enforced release deadline
}
```

**Normative (obligations on any conformant `ReleaseAdapter` deployment, A7):**
- It MUST implement the version identified by `chainBindingHash` and MUST reject an authorization whose binding does not name that adapter and its pinned `enforcementSpecHash`. [FRAMEWORK]
- It MUST release at most once per `outboxId` (foreign-side replay protection mirroring `processedOutbox`); a second `Release` with the same `outboxId` MUST be rejected (`SPEC.md` §17.3; §13.6). [FRAMEWORK]
- It MUST verify Zenon L1 finality and inclusion of a matching Settlement `PegOutRecord{state=PENDING}`. Core creates that record only after the source outbox batch is finalized and the local debit/burn, binding, caps, replay, and conservation checks succeed (§10.3). A chain-specific adapter MAY additionally verify the source batch/profile proof, but MUST NOT substitute an unprocessed outbox leaf for the `PENDING` Settlement record. The exact `ZenonProof` object is defined by the pinned Interop Enforcement Specification and remains a per-chain OPEN PARAMETER (`BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q2; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q1). [FRAMEWORK]
- It MUST release exactly `amount` of `asset` to `recipient` and MUST NOT release on a mismatched or unfinalized authorization. [FRAMEWORK]
- It MUST evaluate `timeout` under finalized destination-chain state and reject a release after the deadline. A timeout refund MUST require a finalized `FOREIGN_NON_DELIVERY` claim proving that `outboxId` was absent from the adapter's processed set at or after that deadline (§7.6). [FRAMEWORK]
- The Zenon side MUST NOT depend on the `ReleaseAdapter`'s liveness for **Zenon-side conservation**: withholding delays release but cannot create another authorization. A compromised or non-conformant adapter can still lose foreign custody; that residual is outside Zenon's enforcement reach and is governed by §18.3. [FRAMEWORK]

> Per-chain releaser instantiations (`BRIDGE-FRAMEWORK-RESEARCH.md` §3.2, §6): BTC Tier 1 = BitVM transaction graph + bonded operators (optimistic, 1-of-N); BTC Tier 2 = covenant script verifying the proof in-script (needs a soft fork); ETH/SOL = a verifier contract/program that checks a Zenon burn proof and releases locked collateral directly (lock-and-release, no operator fronting).

### 7.6 Timeouts and acknowledgements

[FRAMEWORK] A generalization beyond Phase 1, which has fire-and-forget outbox with replay protection only. Timeouts and acks are modelled on IBC's `recvPacket` / `acknowledgePacket` / `timeoutPacket` (Appendix C.1, secondary) but expressed against the framework's commitment/finality machinery.

```
Timeout :=
  DEST_HEIGHT { chainId : ChainId ; height : u64 }     // foreign block height deadline
  DEST_TIME   { chainId : ChainId ; unixSecs : u64 }   // foreign timestamp deadline
  SRC_HEIGHT  { height : u64 }                          // Zenon momentum-height deadline (for LOCAL_DOMAIN)
```

**Normative:**
- A message MAY carry a `timeout`. If present, the destination MUST refuse delivery once the timeout has elapsed at the destination, and the source domain MUST become eligible for a **refund/rollback** path on proof that the message was not delivered by the deadline (§10.4, §15.5). A message with `timeout = null` is fire-and-forget (Phase 1 semantics). [FRAMEWORK]
- A foreign timeout requires a finalized `FOREIGN_NON_DELIVERY` claim from the destination Authorization Domain. A local timeout uses finalized local non-inclusion. Delivery and timeout MUST be mutually exclusive. [FRAMEWORK]
- An `ackPolicy` MAY request an acknowledgement: `ON_DELIVERY` (the destination emits an ack outbox message back to the source on accept) or `ON_EXECUTION` (the ack carries the execution result/status). The ack is itself a `kind=0` message from the destination domain/chain, replay-protected by its own `outboxId`, and delivered by the same relay path. `NONE` requests no ack. Acks are OPTIONAL; a domain that does not implement acks MUST set `ackPolicy = NONE`. [FRAMEWORK]
- Timeout windows and ack windows are OPEN PARAMETER per messaging channel and MUST be chosen so that a timeout cannot fire on a message still deliverable under the destination's finality (the three windows of source finality, destination finality, and timeout MUST be ordered so no refund races a valid delivery; §13.5, §14; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q4). [FRAMEWORK]

### 7.7 Validators / executors / watchers (set and proposer policy)

[CORE] Unchanged from `SPEC.md` §6.2 and §22; restated for the generalized set.

```
ExecutorSet := List<ExecutorMember>             // size 1 in Phase 1
ExecutorMember := { executorId : Address ; bond : Amount ; bondAsset : AssetID }
```

**Normative:**
- Each member MUST post a bond sized to at least the **Core-ceiling** value of `MaxBatchWithdrawal` for the domain, not the current Periphery value (`SPEC.md` §22). The bond MUST be slashable on a successful fraud proof (`OPTIMISTIC`, A4). [CORE]
- `proposerPolicy` selects the entitled proposer (`SINGLE` / `RANDOM_BACKUP` / `STAKE_WEIGHTED`); selection inputs MUST be reconstructible by any party from L1 state and `executors` with no executor discretion. State lineage MUST stay linear: at most one batch per cursor position (`SPEC.md` §6.2, §19). [CORE]
- The bond denomination across instances is OPEN PARAMETER: each operator-backed instance needs a bond in an asset uncorrelated with the bridged asset; whether a shared bond pool may serve multiple instances or they must be isolated for clean slashing is unresolved (`BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q4). [OPEN PARAMETER]

### 7.8 Fees, gas, and payment

[FRAMEWORK] Cross-chain payment spans three cost centres, generalizing the Phase 1 two-ledger model (L1 plasma + L2 gas, `SPEC.md` §10).

```go
FeeQuote := {
    domainId       : u32
    srcFee         : Amount      // L1 inclusion cost: plasma (fused) or PoW (SPEC.md §10, ARCHITECTURE.md §3)
    execFee        : Amount      // off-chain execution: L2 gas at metering_version (SPEC.md §10.2)
    destFee        : Amount      // destination delivery: foreign gas the relayer fronts
    feeAsset       : AssetID     // OPEN PARAMETER: denomination
    quotedAtHeight : u64
    expiryHeight   : u64         // quote validity window
}
```

**Normative:**
- A `FeeQuote` is **advisory**. The protocol MUST enforce only that (a) the L1 input is plasma/PoW-funded for inclusion (else it never enters the canonical stream, `SPEC.md` §4.1), (b) execution that exhausts `execFee`/gas fails with `OUT_OF_GAS` and full rollback (`SPEC.md` §10.5), and (c) a relayer that fronts `destFee` is reimbursable from prepaid fees held in domain state. A wrong or stale quote MUST NOT be able to over-release value or corrupt state; it can only cause a delivery to be unprofitable, retried, or refunded (§15.5). [FRAMEWORK]
- Fee-quote manipulation MUST be defended structurally (§13.14): because the quote is advisory and never gates correctness, a manipulated quote degrades only liveness/UX, never custody safety. Prepaid destination fees MUST be conservation-accounted like any other asset. [FRAMEWORK]
- The relayer reimbursement mechanism, the prepaid-fee escrow contract, and a fast-exit LP layer (for latency) are OPEN PARAMETER and are a UX layer, not a trust dependency (`GENERALIZING-TO-OTHER-CHAINS.md` §3 step 9). [OPEN PARAMETER]

### 7.9 Governance and upgrades

[CORE] Generalized from `SPEC.md` §23. Two governance surfaces exist, and the framework keeps them separate.

- **Zenon-side governance (Settlement Periphery).** A single Settlement administrator, time-locked (`AdministratorDelay` ≥ `2 × MomentumsPerEpoch`; `SoftDelay` ≥ `MomentumsPerEpoch`), with guardian recovery and Core hard bounds the administrator cannot exceed. Runtime/profile upgrades are `stfSpecHash` bumps under `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`. Migrates to a governance/multisig address once one exists (A10). [CORE]
- **Authorization-policy governance.** Policy registration decides what foreign claims Settlement hears. Broadening requires a visible exit delay; emergency authority is pause-only. [FRAMEWORK]
- **Foreign-side governance (the `ReleaseAdapter` trust root).** The foreign verifier contract is the trust root on the foreign side. Its upgrade/audit governance is OPEN PARAMETER and MUST be specified per chain so that upgrading it does not reintroduce a custodian (`GENERALIZING-TO-OTHER-CHAINS.md` §7 Q5; A7). [OPEN PARAMETER]

The full governance invariants and the governance-key-compromise defense are in §18 and §13.10.

### 7.10 The Settlement-owned `BridgeLedger`

[FRAMEWORK] `BridgeLedger` is a set of Core-bounded, chain-neutral Settlement claim handlers.

```go
type ClaimDispatcher interface {
    RelayClaim(claim AuthorizedClaim, data ClaimDispatchData, inclusion ClaimProof) (ClaimReceipt, error)
}

func DispatchBridgeClaim(s SettlementState, c AuthorizedClaim, data ClaimDispatchData, p ClaimProof, cap ClaimCapability) error {
    id := ClaimID(c)
    require(c.matches(cap))
    require(verifyClaimInclusion(c, p))
    require(batchFinalized(c.DomainID, p.BatchID))
    require(!s.ProcessedClaim[id])
    require(!s.ProcessedForeignEvent[c.DomainID][c.ForeignEventID])
    require(fitsRemainingClaimBudget(s, p.BatchID, c))
    require(dataMatchesSchemaAndHash(data, c, cap))

    handler := s.CoreClaimHandlers[cap.HandlerID]
    require(handler != nil)
    require(handler.ClaimType == c.ClaimType)
    require(handler.SchemaHash == c.ClaimSchemaHash)
    handler.Apply(s, c, data) // closed, Core-bounded implementation; never domain-selected code

    require(conservationHolds(s, c.DomainID, c.Asset))
    consumeClaimBudgetAndReplayKeys(s, p.BatchID, id, c)
}
```

- Dispatch MUST be atomic and selected solely by the capability's registered `handlerId`. `CoreClaimHandlers` is a closed node-binary registry; policy can select an existing bounded handler but cannot install or invoke arbitrary code.
- Peg-out begins with a local finalized debit/burn, never a foreign claim.
- Peg-in replay keys are both `claimId` and `(domainId, ForeignEventID)`; foreign release keys on `outboxId`.
- Handlers MUST NOT modify verifier state, domain code, policy registration, or another scope.

#### 7.11 How the abstractions map onto the executor plugin

Each Authorization Domain uses the four-method executor plugin with a narrower output contract:

| Plugin method (`EXECUTOR.md` §7) | Delegates to |
|---|---|
| `Genesis()` | chain light-client anchor + empty verifier state + policy version |
| `DecodeInput()` | decode relayed headers, evidence, and claim requests |
| `Apply()` | update verifier state, verify evidence, emit policy-permitted claims |
| `Source.Watch()` | the relay role: watch the foreign chain (`SourceAdapter`), emit headers/proofs/spends |

New chain = new Authorization Domain, policy registration, optional asset wiring, and foreign `ReleaseAdapter`. Settlement handlers remain chain-neutral.

---

## 8. Canonical data model

### 8.1 Entities and the asset registry

Settlement storage MUST hold the following entities, all keyed by `domainId` where domain-scoped, generalizing `SPEC.md` §5.4. New entities beyond Phase 1 are marked **(new)**.

- **`DomainRecord`** per `domainId` (§6.1).
- **`BatchCommitment`** per `(domainId, batchId)`: Phase-1 roots plus, for `AUTHORIZATION`, `claimRoot` and `claimEffectSummary` under A15.
- **`InputCursor`** per `domainId`: last input-sequence number consumed by an accepted batch (`SPEC.md` §4.5).
- **`CustodyRecord`** per `(domainId, asset)`: the conservation counters, specialized by custody mode (§13.7).
- **`AssetRegistry`** **(new)** per `(domainId, asset)`: `custodyMode`, and for `MINTED` the `(foreignChainId, foreignAssetRef, decimalsPolicy)` binding (§7.2).
- **`ClaimPolicyRecord`** **(new)** per `(domainId, policyVersion)`.
- **`ClaimRecord`** **(new)** per `claimId`: `COMMITTED | FINALIZED | DISPATCHED | REJECTED`.
- **`ClaimDispatchBudget`** **(new)** per `(domainId, batchId, claimType, asset)`.
- **`ProcessedClaim`** and **`ProcessedForeignEvent`** replay sets.
- **`ClaimReceipt`** per `claimId`: handler, effect hash, dispatch height, custody digest.
- **`ProcessedOutbox`** set: `outboxId`s already relayed, for replay protection (`SPEC.md` §17.3).
- **`PegOutRecord`** **(new)** per `outboxId`: immutable authorization fields (`domainId`, asset, amount, recipient, refund recipient, `burnRef`, `chainBindingHash`, timeout) and state `PENDING | RELEASED | REFUNDED`. `FOREIGN_RELEASE` and `FOREIGN_NON_DELIVERY` handlers compete to leave `PENDING`; exactly one may succeed.
- **`PendingDeployment`** per `(domainId, code_hash)`: chunked-deployment records (`SPEC.md` §11).
- **`ExecutorRegistration`** per `(domainId, executorId)`: bond and status (`SPEC.md` §22).
- **`VerifierRegistry`** **(new)** Periphery: `OPTIMISTIC` fraud-referee entries (A4) and `ZK_VALIDITY`/`ZK_CONSENSUS` verifying-key entries (A5); reserved in Phase 1 (`SPEC.md` §5.2). **OPEN DESIGN:** the registry entry format, the on-chain verification dispatch interface (how Core invokes a registered verifier against `proofData`), and the verifying-key update governance are not yet specified; A4 and A5 name their existence, not their interface. This is separate from the proving system choice (OPEN PARAMETER O-5).
- **`MessageState`** **(new)** per `outboxId` (for messages carrying `timeout`/`ackPolicy`): lifecycle state (§10.4). Fire-and-forget messages need only the `ProcessedOutbox` membership.
- **`Periphery`** config: caps, delays, admin/guardians, pause authority (`SPEC.md` §23).

### 8.2 Canonical identifiers

[FRAMEWORK] All identifiers are SHA3-256 derived or fixed-width unsigned, big-endian, with exactly one valid encoding (`SPEC.md` §14.1, §27).

| Entity | Canonical identifier | Definition |
|---|---|---|
| **Domain** | `domainId : u32` | Assigned at `RegisterDomain` (`SPEC.md` §6). |
| **Foreign chain** | `chainId : ChainId` | `ChainId := chainNamespace : u16 ‖ chainReference : bytes30`. Namespace enumerates EVM / SVM / BTC / Cosmos / ...; reference is the chain's native id (EIP-155 id, genesis hash, etc.). OPEN PARAMETER: the namespace registry. |
| **Batch** | `(domainId, batchId)`, `batchId : u64` | Per-domain monotonic; identifies a `BatchCommitment` (`SPEC.md` §19). |
| **Input** | `globalInputIndex : u64` (L1-sourced) / domain ordinal (`EXTERNAL_OBSERVED`) | Canonical input order (`SPEC.md` §4.5). `inputHash = SHA3-256(canonical input encoding)` (`SPEC.md` §27.5). |
| **Authorized claim** | `claimId : bytes32` | `SHA3-256(canonical AuthorizedClaim encoding)`. |
| **Foreign event** | `(domainId, ForeignEventID)` | Stable normalized foreign occurrence and second claim-effect replay key. |
| **Message** | `messageId = outboxId = SHA3-256(domainId ‖ batchId ‖ inputIndex ‖ outboxIndex)` | The replay and delivery idempotency key (`SPEC.md` §17.3, §27.4). |
| **Proof** | `proofId = SHA3-256(execProfile ‖ verifyingKeyId ‖ publicInputsHash)` (zk) / `SHA3-256(challengeTarget ‖ preRoot ‖ postRoot)` (fraud) | **(new)** Identifies a verification artifact; the statement schema is OPEN PARAMETER per proving system. |
| **Asset** | `AssetID : bytes32` | Canonical ZTS encoding per `SPEC.md` §18.1 for both `ESCROW` and `MINTED` (§7.2). |
| **Release op** | `releaseId = outboxId` (one release per `outboxId`) | **(new)** The peg-out/withdrawal release is identified by its `outboxId`; foreign-side replay keys on it (§7.5, §13.6). |

### 8.3 ER diagram (Mermaid)

```mermaid
erDiagram
    DOMAIN_RECORD ||--o{ BATCH_COMMITMENT : "anchors"
    DOMAIN_RECORD ||--|| INPUT_CURSOR : "tracks"
    DOMAIN_RECORD ||--o{ CUSTODY_RECORD : "per-asset custody"
    DOMAIN_RECORD ||--o{ ASSET_REGISTRY : "per-asset binding"
    DOMAIN_RECORD ||--o{ EXECUTOR_REGISTRATION : "bonded set"
    DOMAIN_RECORD ||--o| CHAIN_BINDING : "foreign binding (authorization)"
    DOMAIN_RECORD ||--o{ CLAIM_POLICY : "grants capabilities"
    DOMAIN_RECORD ||--o{ PENDING_DEPLOYMENT : "chunked deploys"
    BATCH_COMMITMENT ||--o{ OUTBOX_MESSAGE : "commits (outboxRoot)"
    BATCH_COMMITMENT ||--o{ RECEIPT : "commits (receiptRoot)"
    BATCH_COMMITMENT ||--o{ EVENT : "commits (eventRoot)"
    BATCH_COMMITMENT ||--|| ASSET_FLOW_SUMMARY : "carries"
    BATCH_COMMITMENT ||--o{ AUTHORIZED_CLAIM : "commits (claimRoot)"
    AUTHORIZED_CLAIM ||--o| CLAIM_RECEIPT : "dispatches once"
    OUTBOX_MESSAGE ||--o| PROCESSED_OUTBOX : "consumed once (outboxId)"
    OUTBOX_MESSAGE ||--o| MESSAGE_STATE : "if timeout/ack"
    OUTBOX_MESSAGE ||--o| PEGOUT_RECORD : "kind=1 authorization state"
    OUTBOX_MESSAGE }o--|| ASSET_REGISTRY : "kind=1 references asset"
    CUSTODY_RECORD }o--|| ASSET_REGISTRY : "mode"
    VERIFIER_REGISTRY ||--o{ DOMAIN_RECORD : "profile verifier (optimistic/zk)"

    DOMAIN_RECORD {
        u32 domainId PK
        enum domainClass
        enum runtimeKind
        bytes32 stfSpecHash
        enum inputSource
        enum execProfile
        enum foreignProfile
        enum proposerPolicy
        enum finalityModel
        enum status
    }
    CHAIN_BINDING {
        u32 domainId FK
        ChainId foreignChainId
        bytes32 chainVerifierId
        bytes genesisAnchor
        bytes releaseAdapterRef
        bytes32 enforcementSpecHash
        bytes finalityParams
    }
    BATCH_COMMITMENT {
        u32 domainId FK
        u64 batchId PK
        u64 firstInputSeq
        u64 lastInputSeq
        bytes32 preStateRoot
        bytes32 postStateRoot
        bytes32 inputRoot
        bytes32 receiptRoot
        bytes32 eventRoot
        bytes32 outboxRoot
        bytes32 claimRoot
        bytes32 DAHash
        u8 DAMode
        Address executorId
        u64 submittedAtHeight
        bytes proofData
        enum state
    }
    CLAIM_POLICY {
        u32 domainId FK
        u32 policyVersion PK
        enum purpose
        bytes32 capabilitiesRoot
    }
    AUTHORIZED_CLAIM {
        bytes32 claimId PK
        u32 domainId FK
        u32 policyVersion
        enum claimType
        bytes32 foreignEventId
        AssetID asset
        u256 amount
    }
    CLAIM_RECEIPT {
        bytes32 claimId PK
        bytes32 handlerId
        bytes32 effectHash
        u64 dispatchHeight
    }
    CUSTODY_RECORD {
        u32 domainId FK
        AssetID asset PK
        u256 totalDeposited
        u256 pendingWithdrawalReserve
        u256 totalReleased
        u256 representationOutstanding
        u256 pendingForeignRelease
        u256 verifiedLockedCollateral
    }
    ASSET_REGISTRY {
        u32 domainId FK
        AssetID asset PK
        enum custodyMode
        ChainId foreignChainId
        bytes foreignAssetRef
        bytes decimalsPolicy
    }
    OUTBOX_MESSAGE {
        bytes32 outboxId PK
        u32 srcDomainId
        u64 batchId
        u64 inputIndex
        u32 outboxIndex
        u8 kind
        bytes dest
        bytes timeout
        enum ackPolicy
        bytes payload
    }
    PROCESSED_OUTBOX {
        bytes32 outboxId PK
    }
    MESSAGE_STATE {
        bytes32 outboxId PK
        enum lifecycle
        u64 deadline
    }
    PEGOUT_RECORD {
        bytes32 outboxId PK
        u32 domainId FK
        AssetID asset
        u256 amount
        bytes recipient
        Address refundRecipient
        bytes32 burnRef
        bytes32 chainBindingHash
        bytes timeout
        enum state
    }
    VERIFIER_REGISTRY {
        bytes32 verifierRef PK
        enum kind
        bytes32 verifyingKeyId
    }
```

---

## 9. Canonical wire formats

[CORE] All wire formats are the custom canonical binary format of `SPEC.md` §14.1 and §27: integers fixed-width big-endian unsigned; hashes/IDs/asset-ids fixed 32-byte; L1 `Address` 20 bytes; fields in exact order; `Bytes = u32 length prefix + raw`; lists = `u32 count + elements` (sorted where required); exactly one valid encoding. JSON, protobuf, and SSZ MUST NOT be used. The framework reuses every Phase 1 encoding unchanged and adds bridge/profile fields as canonical extensions.

### 9.1 Reused Phase 1 encodings (normative, unchanged)

- **`OutboxMessage`** (`SPEC.md` §27.4): `source_contract:bytes32 ; input_index:u64 ; outbox_index:u32 ; kind:u8 ; (kind==0: target_contract:bytes32) | (kind==1: recipient_l1:Address(20) ; asset_id:AssetID ; amount:u256) ; payload:Bytes`. For `kind==1`, `payload` MUST be empty. `outboxId = SHA3-256(domainId ‖ batchId(u64) ‖ input_index(u64) ‖ outbox_index(u32))`.
- **Canonical input encoding / `inputRoot` leaf** (`SPEC.md` §27.5): `input_kind:u8 ‖ source_account_block_hash:bytes32 ‖ <kind-specific tail>`, defined for all six input kinds.
- **`AssetFlowSummary`** (`SPEC.md` §27.6): `List<AssetFlowEntry>`, `AssetFlowEntry := asset_id:AssetID ; deposit_credit:u256 ; withdrawal_debit:u256`, sorted by `asset_id` ascending, no duplicates.
- **`Receipt`** (`SPEC.md` §27.7), **`ExecutionResult`/`ContractEffects`** (`SPEC.md` §27.1a), **`StateDiff`** with the `EMPTY` sentinel `0xFFFFFFFF` distinct from present-empty `0x00000000` (`SPEC.md` §27.2), **batch commitment** (`SPEC.md` §19).

### 9.2 Batch commitment, generalized (normative)

The Phase-1 commitment remains byte-for-byte unchanged under its existing version. An Authorization Domain uses the A15 extension; decoding MUST branch on `protocol_version` first.

```
BatchCommitmentV3 := protocol_version:u16 ; <other version fields §20> ;
    domainId:u32 ; batchId:u64 ; firstInputSeq:u64 ; lastInputSeq:u64 ;
    preStateRoot:bytes32 ; postStateRoot:bytes32 ;
    inputRoot:bytes32 ; receiptRoot:bytes32 ; eventRoot:bytes32 ; outboxRoot:bytes32 ; claimRoot:bytes32 ;
    DAHash:bytes32 ; DAMode:u8 ; executorId:Address(20) ; submittedAtHeight:u64 ;
    assetFlowSummary:AssetFlowSummary ; claimEffectSummary:ClaimEffectSummary ; proofData:Bytes
```

For `EXECUTION`, claim fields MUST be empty. For `AUTHORIZATION`, `outboxRoot` and `assetFlowSummary` MUST be empty. At submit, Core MUST reject summary entries without a matching policy capability or exceeding its caps.

**Normative `proofData` semantics by `execProfile`:**
- `ATTESTATION`-single-bonded and `OPTIMISTIC` at submit: `proofData` MUST be the zero-length encoding (`u32` length `0x00000000`); Core MUST reject a non-empty `proofData` and MUST reject trailing bytes (`SPEC.md` §19, §24). [CORE]
- `ATTESTATION`-quorum: `proofData` MUST be the canonical encoding of the quorum attestation defined by `AttesterPolicy` (an aggregated/threshold signature over the rest of the commitment), verified by Core before acceptance. Requires A13 (`protocol_version` bump enabling non-empty `proofData` for attestation payloads); MUST NOT coexist with Phase 1 `proofData` rules. **(new)** [FRAMEWORK, A13]
- `ZK_VALIDITY`: `proofData` MUST be the canonical encoding of the validity proof and its public-input binding, verified by Core against the registered `verifyingKeyId` before the batch finalizes. The on-chain verification dispatch interface (how Core invokes the registered verifier) is **OPEN DESIGN** (see §8.1 `VerifierRegistry`). The `publicInputSchema : bytes32` is a hash of the statement schema, not the schema itself; the schema MUST be registered alongside the verifying key. **(new)** [FRAMEWORK, A5, OPEN DESIGN for dispatch interface]
- The commitment MUST fit `MaxOnChainCommitmentSize = MaxDataLength` (16 KiB) in all profiles; a proof too large to fit MUST be carried by reference (a `proofId` plus an off-chain proof in the bundle) with Core verifying against the reference. OPEN PARAMETER: the reference-vs-inline threshold per proving system. [FRAMEWORK]

### 9.3 New wire formats (normative)

- **`AuthorizedClaim`**: `domainId:u32 ‖ policyVersion:u32 ‖ claimType:u8 ‖ claimSchemaHash:bytes32 ‖ foreignEventId:bytes32 ‖ subject:Bytes ‖ asset:AssetID ‖ amount:u256 ‖ payloadHash:bytes32 ‖ finalityRef:Bytes ‖ observedAt:u64`.
- **`ClaimEffectSummary`**: sorted list of `claimType:u8 ‖ asset:AssetID ‖ count:u32 ‖ totalAmount:u256`; bounds cumulative dispatchable effects but grants none.
- **`ClaimProof`**: `domainId:u32 ‖ batchId:u64 ‖ claimIndex:u32 ‖ merkleProof:Bytes`.
- **`ClaimDispatchData`**: `payload:Bytes`; the payload is capped by policy and `MaxDataLength` and MUST hash to `AuthorizedClaim.PayloadHash` when required (§7.0).
- **`ChainBinding`**: `foreignChainId:ChainId ‖ chainVerifierId:bytes32 ‖ genesisAnchor:Bytes ‖ releaseAdapterRef:Bytes ‖ enforcementSpecHash:bytes32 ‖ finalityParams:Bytes`; `chainBindingHash` is SHA3-256 of this exact encoding (§6.1).
- **`ClaimReceipt`**: `claimId:bytes32 ‖ handlerId:bytes32 ‖ effectHash:bytes32 ‖ dispatchHeight:u64 ‖ custodyDigest:bytes32`.
- **`PegOutRecord`**: `outboxId:bytes32 ‖ domainId:u32 ‖ asset:AssetID ‖ amount:u256 ‖ recipient:Bytes ‖ refundRecipient:Address(20) ‖ burnRef:bytes32 ‖ chainBindingHash:bytes32 ‖ timeout:Timeout ‖ state:u8`. The record is immutable except for the one-way `PENDING → RELEASED | REFUNDED` state transition.
- **`PegOutAuthorization`** (§7.5) is the foreign-facing projection of the `PENDING` `PegOutRecord` derived from a finalized `kind=1` outbox object; its canonical encoding is `domainId:u32 ‖ outboxId:bytes32 ‖ chainBindingHash:bytes32 ‖ asset:AssetID ‖ amount:u256 ‖ recipient:Bytes ‖ burnRef:bytes32 ‖ timeout:Timeout`. The `recipient` and accompanying `ZenonProof` encodings are per-chain and MUST be defined by the pinned Interop Enforcement Specification (§7.5, §18.3).
- **`Timeout`** and **`ackPolicy`** (§7.6) extend `kind=0` message metadata; their canonical encodings are `Timeout := tag:u8 ‖ (DEST_HEIGHT: chainId:ChainId ‖ height:u64 | DEST_TIME: chainId:ChainId ‖ unixSecs:u64 | SRC_HEIGHT: height:u64)` and `ackPolicy:u8`. These fields, together with the `Destination` tagged union replacing Phase 1's fixed `target_contract:bytes32`, constitute a new outbox encoding that requires an `outbox_version` bump (A14); they MUST NOT appear under the Phase 1 `outbox_version`. **(new)** [FRAMEWORK, A14]
- **`ProfileConfig` and `ClaimPolicy`** are stored outside batches but folded into `stfSpecHash`. [A12/A15]

> **Wire compatibility.** Phase-1 encodings remain unchanged at existing versions. Claim roots, claim structures, DomainRecord, and generalized outbox require explicit version bumps. [FRAMEWORK]

---

## 10. State machine definitions

### 10.1 Batching and contiguity (normative, unchanged from `SPEC.md` §4.6)

- A batch MUST be a contiguous slice of its domain's canonical input subsequence, beginning at the successor of the domain's stored `InputCursor`, with `≥ 1` and `≤ MaxBatchInputs` inputs. [CORE]
- Contiguity is **per-domain over the domain's subsequence, not over the raw `globalInputIndex`**. Settlement MUST verify, per domain at acceptance, that `firstInputSeq` is the successor of the stored cursor with no gap, overlap, replay, non-canonical order, or count exceeding `MaxBatchInputs`. [CORE]
- Momentum splitting across batches is permitted; there is no atomic-per-momentum requirement (`SPEC.md` §4.6). [CORE]

### 10.2 Batch lifecycle (all execution profiles)

[FRAMEWORK] The batch lifecycle generalizes `SPEC.md` §21 across the three execution profiles. The states and transitions:

```mermaid
stateDiagram-v2
    [*] --> SUBMITTED : SubmitBatch accepted<br/>(entitlement, contiguity, size,<br/>class-appropriate roots/summaries,<br/>chaining; + ZK proof)

    SUBMITTED --> FINALIZED_DELAY : execProfile=ATTESTATION<br/>withdrawal delay elapsed
    SUBMITTED --> CHALLENGE_OPEN : execProfile=OPTIMISTIC<br/>challenge window opens
    SUBMITTED --> FINALIZED_PROOF : execProfile=ZK_VALIDITY<br/>(proof verified at submit;<br/>finality MAY be immediate)

    CHALLENGE_OPEN --> CHALLENGED : Challenge(fraud proof) submitted
    CHALLENGE_OPEN --> FINALIZED_DELAY : window elapsed, no challenge
    CHALLENGED --> REJECTED : referee re-runs Apply,<br/>divergence proven → slash bond
    CHALLENGED --> CHALLENGE_OPEN : challenge fails (proof invalid)

    REJECTED --> [*] : batch and its successors rolled back<br/>to last good cursor
    FINALIZED_DELAY --> [*] : committed outputs actionable
    FINALIZED_PROOF --> [*] : committed outputs actionable

    SUBMITTED --> HALT_CORRUPT : Core invariant violated<br/>(MUST NOT occur; halt)
```

**Normative:**
- No withdrawal, message delivery, or claim dispatch MAY occur from a non-finalized batch. [CORE/FRAMEWORK]
- `ATTESTATION`: `SUBMITTED → FINALIZED` after the withdrawal delay in momentum heights from `submittedAtHeight` (not wall-clock). [CORE]
- `OPTIMISTIC`: `SUBMITTED → CHALLENGE_OPEN`; a watcher MAY `Challenge` within the window; on a successful fraud proof the batch and every later batch on that cursor lineage MUST be `REJECTED` and the proposer slashed; absent a successful challenge by window close, the batch finalizes. The challenge window MUST be ≥ the `WithdrawalDelay` floor. [FRAMEWORK, A4]
- `ZK_VALIDITY`: the validity proof is verified at `SubmitBatch`; finality MAY be immediate or after a short proof-availability margin (Deployment parameter). An unverifiable proof MUST cause rejection at submit (the batch never enters `SUBMITTED`). [FRAMEWORK, A5]
- A challenge or rejection MUST NOT alter any *already-finalized* batch; rejection rolls back only `SUBMITTED`/`CHALLENGE_OPEN` batches at or after the proven-divergent cursor. [FRAMEWORK]

### 10.2.1 Authorized claim lifecycle

```mermaid
stateDiagram-v2
    [*] --> EMITTED : Authorization Apply verifies evidence
    EMITTED --> COMMITTED : included in claimRoot
    COMMITTED --> FINALIZED : batch finalizes
    FINALIZED --> DISPATCHED : RelayClaim checks standing,<br/>replay, caps, conservation
    FINALIZED --> REJECTED : any check fails
    DISPATCHED --> [*] : ClaimReceipt recorded atomically
    REJECTED --> [*] : no Settlement mutation
```

- Batch finality proves only that the domain emitted the claim under its execution profile. Dispatch still checks standing and Settlement predicates.
- `DISPATCHED` is irreversible except through an explicitly specified compensating handler.

### 10.3 Peg-out / withdrawal lifecycle

[FRAMEWORK] Generalizes `SPEC.md` §18.2 and §17.3 to cover both `ESCROW` withdrawal and `MINTED` peg-out, and both `LOCAL_DOMAIN` and `FOREIGN_CHAIN` destinations.

```mermaid
stateDiagram-v2
    [*] --> DEBITED : local finalized debit/burn<br/>(Execution Domain or Settlement issuance handler)
    DEBITED --> AUTHORIZED : kind=1 OutboxMessage committed<br/>in outboxRoot (PegOutAuthorization)
    AUTHORIZED --> FINALIZED : enclosing batch FINALIZED (§10.2)
    FINALIZED --> RELAYED : RelayMessage(proof) accepted<br/>outboxId ∉ processedOutbox;<br/>domainId/batchId match proof
    RELAYED --> RESERVED : pendingWithdrawalReserve↑<br/>release-eligible at finalizationHeight+WithdrawalDelay
    RESERVED --> RELEASED : ESCROW → descendant send after delay;<br/>MINTED → adapter releases, then finalized<br/>FOREIGN_RELEASE reconciles PegOutRecord

    FINALIZED --> TIMED_OUT : timeout elapsed at destination<br/>+ non-delivery proof (§7.6)
    TIMED_OUT --> REFUNDED : source re-credits/re-mints;<br/>outboxId consumed by timeout path
    RELEASED --> [*]
    REFUNDED --> [*]
```

**Normative:**
- `RelayMessage` MUST be permissionless, MUST supply an inclusion proof against a `FINALIZED` batch's committed `outboxRoot`, MUST verify `FINALIZED` status, and MUST verify that the supplied `domainId`/`batchId` match the batch whose `outboxRoot` verifies the proof (`SPEC.md` §17.3). [CORE]
- The `outboxId` MUST be recorded in `ProcessedOutbox` on processing; a second relay of the same `outboxId` MUST be rejected. A release is **one-per-`RelayMessage`** (`SPEC.md` §27.9). [CORE]
- Release MUST re-check the conservation invariant (§13.7) and MUST be bounded by `MaxBatchWithdrawal` per (domain, asset) at the batch level (`SPEC.md` §18.3, §27.9). [CORE]
- Processing a `MINTED` peg-out authorization MUST atomically validate the finalized debit/burn, create `PegOutRecord{state=PENDING}`, decrease `representationOutstanding`, and increase `pendingForeignRelease`. A duplicate `outboxId`, missing burn, or mismatched binding/asset/amount MUST revert the entire operation. The exact ZTS plumbing remains OD-1. [FRAMEWORK]
- `FOREIGN_RELEASE` and `FOREIGN_NON_DELIVERY` handlers MUST require the same `PegOutRecord` to be `PENDING` and atomically move it to `RELEASED` or `REFUNDED`, respectively. A claim against either terminal state MUST be rejected, even if it uses a new checkpoint-derived `ForeignEventID`. [FRAMEWORK]
- For `FOREIGN_CHAIN` destinations (`MINTED`), the actual asset transfer is performed by the `ReleaseAdapter`. Zenon-side conservation does not depend on adapter liveness, but foreign custody safety does depend on adapter conformance (§7.5, §18.3). [FRAMEWORK]
- Foreign delivery/refund exclusion MUST NOT assume Zenon's `ProcessedOutbox` is visible to the destination. The authorization carries a destination-enforced deadline: a release finalized before the deadline makes a later non-delivery proof impossible, while a release attempted at or after the deadline is rejected by the adapter. Settlement refunds only after a finalized `FOREIGN_NON_DELIVERY` claim at or after that deadline (§7.5, §7.6). [FRAMEWORK]
- An Authorization Domain MUST NOT create `DEBITED` or emit peg-out merely by asserting a foreign fact.

### 10.4 Message lifecycle (kind=0, with timeout/ack)

[FRAMEWORK] For `kind = 0` cross-domain/cross-chain messages carrying `timeout`/`ackPolicy`:

```mermaid
stateDiagram-v2
    [*] --> EMITTED : STF returns message in ContractEffects
    EMITTED --> COMMITTED : in outboxRoot
    COMMITTED --> FINALIZED : batch FINALIZED
    FINALIZED --> RELAYED : relayer presents inclusion proof at destination
    RELAYED --> DELIVERED : destination accepts (outboxId ∉ its processed set,<br/>not past timeout)
    DELIVERED --> EXECUTED : destination STF/contract consumes payload
    EXECUTED --> ACKED : ackPolicy≠NONE → ack message back to source
    FINALIZED --> TIMED_OUT : deadline elapsed at destination + non-delivery proof
    TIMED_OUT --> REFUNDED : source rollback path
    ACKED --> [*]
    EXECUTED --> [*] : ackPolicy=NONE
    REFUNDED --> [*]
```

**Normative:**
- Delivery MUST be idempotent on `outboxId` at the destination (the destination maintains its own processed set). A duplicate delivery MUST be a rejected no-op, never a double-execution (§13.7). [FRAMEWORK]
- An ack is itself a `kind=0` message from the destination, replay-protected by its own `outboxId`, finalized and relayed by the same machinery. Ack delivery failure MUST NOT roll back an already-`EXECUTED` message; acks are best-effort confirmations, and a missing ack is handled by source-side retry or timeout policy, not by reverting the destination (§13.12). [FRAMEWORK]
- The `EXECUTED`-without-ack terminal state is legal (`ackPolicy = NONE`), reproducing Phase 1 fire-and-forget semantics. [FRAMEWORK]

### 10.5 Replay protection semantics (normative, consolidated)

| Replay surface | Idempotency key | Enforced by | Source |
|---|---|---|---|
| L1 input replay | `source_account_block_hash` + `chain_id` binding (`inputHash`) | L1 account-block uniqueness | `SPEC.md` §27.5, §26 |
| Outbox/message relay | `outboxId = SHA3-256(domainId ‖ batchId ‖ inputIndex ‖ outboxIndex)` | `ProcessedOutbox` set (at-most-once) | `SPEC.md` §17.3 |
| Foreign release (peg-out) | `releaseId = outboxId` | `ReleaseAdapter` processed set (foreign side) | §7.5 |
| Zenon peg-out resolution | `outboxId` | Settlement `PegOutRecord` terminal state | §10.3 |
| Authorized claim dispatch | `claimId` | Settlement `ProcessedClaim` | §7.0 |
| Foreign-event effect | `(domainId, ForeignEventID)` | Settlement `ProcessedForeignEvent` | §7.0 |
| Peg-in credit/mint | both keys above | Settlement claim dispatcher | §7.10 |
| Cross-domain delivery | `outboxId` | destination domain's processed set | §10.4 |
| Batch replay | per-domain `InputCursor` (no gap/overlap/replay) | Settlement contiguity check | `SPEC.md` §4.6 |

**Normative:** Each surface MUST be protected by its key independently; a single key MUST NOT be assumed to cover two surfaces (for example, on-Zenon `ProcessedOutbox` does not protect the foreign side, which MUST keep its own per-`outboxId` set). [FRAMEWORK]

### 10.6 Timeout and acknowledgement semantics (normative, consolidated)

- A timeout is evaluated under destination finality. Foreign refund requires finalized `FOREIGN_NON_DELIVERY`; local refund uses finalized non-inclusion. [FRAMEWORK]
- The three windows (source-batch finality, destination finality, and the timeout deadline) MUST satisfy `sourceFinality + destinationFinality ≤ timeoutDeadline` (in a common time/height reference, OPEN PARAMETER per channel) so a refund can never race a still-valid delivery (§13.5, §14). [FRAMEWORK]
- Acknowledgements MUST NOT be a precondition of delivery correctness; they are confirmations layered on top, and their absence MUST degrade only liveness/UX (§13.12). [FRAMEWORK]

---

## 11. Executor architecture

[CORE/FRAMEWORK] The executor remains one generic runtime. `AUTHORIZATION` adds class-specific output validation and a `claimRoot` builder, not accounting logic.

### 11.1 Pipeline (per domain)

The executor-role pipeline is the five stages of `ARCHITECTURE.md` §2.2 / `EXECUTOR.md` §5:

1. **Ledger follower**: follows the `znnd` confirmation frontier, reads confirmed momenta at or below `frontier − confirmationDepth`, filters content to `domainId`, reconstructs the domain's input subsequence in canonical order, maintains the per-domain cursor. MUST track each domain's last-consumed `globalInputIndex` independently and MUST NOT require raw global-index contiguity (`SPEC.md` §4.6; `EXECUTOR.md` §5.1). [CORE]
2. **STF / runtime**: for `AUTHORIZATION`, runs the pinned verifier, validates claims against policy, and rejects forbidden namespaces or financial effects. [CORE/FRAMEWORK]
3. **State (SMT)**: the executor's leaf set over the shared path-native trie API (`RootOfLeaves` / `ProveByPath` / `VerifyProofByPath` / `VerifyAbsenceByPath`); MUST NOT call any key-hashing entry point or fold empty→delete (`SPEC.md` §13.1, §13.5.1; A11). [CORE]
4. **Batch builder**: `EXECUTION` builds ordinary roots and empty claim fields; `AUTHORIZATION` builds `claimRoot`/`ClaimEffectSummary` and empty financial roots. [CORE/FRAMEWORK]
5. **DA publisher**: publishes the canonical bundle content-addressed by `DAHash` over Sentinel/libp2p, best-effort (`SPEC.md` §20; `EXECUTOR.md` §5.6). [CORE]

The watcher role runs stages 1–4 identically and compares against the committed batch instead of submitting; under `OPTIMISTIC` it emits a fraud proof (`EXECUTOR.md` §11). The relay role runs no STF: it is the `SourceAdapter` pump posting foreign data to L1, and it carries finalized outbox messages to destinations (`EXECUTOR.md` §12). [CORE]

### 11.2 Executor idempotency requirements (normative)

[CORE] Replay determinism is the executor's core idempotency contract (`EXECUTOR.md` §10, §19):
- Identical canonical inputs MUST produce identical `postStateRoot`s, `ExecutionResult`s, and `DAHash`es across independent compliant implementations. [CORE]
- Re-running the pipeline from a checkpoint or from genesis MUST yield byte-identical state; the local store is a **cache** of deterministically derivable state, never the source of truth (`EXECUTOR.md` §5.3, §14). [CORE]
- `SubmitBatch` MUST be idempotent against the on-chain cursor: re-submitting an already-accepted batch (same cursor position) MUST be rejected by Settlement contiguity, not double-applied (§10.5; `SPEC.md` §4.6). [CORE]
- For `EXTERNAL_OBSERVED` domains, idempotency additionally requires that the committed `inputRoot` + bundle fully determine the consumed observations, so a replayer reaches identical state with no foreign access (`SPEC.md` §6.1). [CORE]

### 11.3 Recovery anchor rules (normative)

[CORE] On startup the executor reconciles local state against the most recent *finalized* on-chain root before resuming (`EXECUTOR.md` §14):
- **Recovery anchor** = the most recent `FINALIZED` batch's `postStateRoot` + `lastInputSeq`, read from Settlement storage via an L1 state proof; genesis (empty SMT, sequence `−1`) if none. [CORE]
- **Forward replay** from the anchor advances by walking the domain's own subsequence (the next `globalInputIndex` belonging to this domain), never by incrementing the global index by 1. [CORE]
- **Anchor-ahead-of-local** MUST distinguish *local absent* (re-derive forward) from *root mismatch at a height local produced* (HALT). These MUST NOT be collapsed. [CORE]
- **Intermediate-finalized mismatch** anywhere between anchor and frontier MUST HALT. [CORE]
- **Reorg deeper than `confirmationDepth`** MUST HALT as an L1 fault; the executor MUST NOT have submitted any batch whose inputs lie below an unconfirmed reorg point. `confirmationDepth` is OPEN PARAMETER (`EXECUTOR.md` §14, §19 Q-1). [CORE / OPEN PARAMETER]
- **Missing pre-finalization bundle** at recovery → `AWAIT_DA` with bounded retry, then HALT; a lost local bundle for an un-finalized batch is a consistency fault (`EXECUTOR.md` §14). [CORE]

### 11.4 Halt-on-corruption conditions (normative)

[CORE] Fail-closed: any internal consistency fault MUST halt the binary rather than submit (`EXECUTOR.md` §2, §15). The MUST-halt set:

| Condition | Source |
|---|---|
| Trie root mismatch (incremental ≠ full recompute) | `SPEC.md` §13.5; `EXECUTOR.md` §15 |
| `DAHash` round-trip mismatch | `EXECUTOR.md` §5.4, §15 |
| Recovery-anchor root mismatch | `EXECUTOR.md` §14, §15 |
| Intermediate-finalized root mismatch | `EXECUTOR.md` §14, §15 |
| DA bundle missing at recovery (after `AWAIT_DA`) | `EXECUTOR.md` §14, §15 |
| Reorg deeper than `confirmationDepth` | `EXECUTOR.md` §14, §15 |
| Snapshot substitution detected | `EXECUTOR.md` §19 |
| Duplicate executor instance (lease lost) | `EXECUTOR.md` §13, §15 |
| Output violates `domainClass` or ClaimPolicy | §6.1, §7.0 |
| Authorization `StateDiff` reaches financial namespace | §7.0 |

Transient faults (disk, OOM, network) MAY auto-restart with bounded backoff; consistency faults MUST stay HALTED until operator action (`EXECUTOR.md` §14). [CORE]

---

## 12. Executor API surface

The complete set of typed interfaces a developer implements or consumes. The plugin-implemented interfaces are `DomainPlugin` (§12.1), `ChainVerifier` (§7.3), `SourceAdapter` (§7.4), and the foreign-side `ReleaseAdapter` (§7.5). The runtime-provided interfaces the plugin consumes are `SettlementClient` (§12.2), `StateAccess`, and `Effects`. The fee model is `FeeQuote` (§7.8).

### 12.1 `DomainPlugin` (the only code written to add a domain)

[CORE/FRAMEWORK] The plugin shape follows `EXECUTOR.md`; result type is tagged by `domainClass`.

```go
// The execution contract every domain implements (EXECUTOR.md §7).
type DomainPlugin interface {
    Genesis() StateInit                                  // empty for WASM; verifier anchor for authorization
    DecodeInput(payload []byte) (Input, error)           // opaque L1 payload → typed, structurally-valid input
    Apply(state StateAccess, in Input) (DomainEffects, error)
}

type DomainEffects interface { isDomainEffects() }
// EXECUTION -> Effects; AUTHORIZATION -> AuthorizationEffects

// Optional: only L1_RELAYED / EXTERNAL_OBSERVED domains implement this (the relay role).
type Source interface {
    Watch(ctx Context) (<-chan RelayPayload, error)
}
```

Ownership boundary (`EXECUTOR.md` §7), normative:

| Concern | Owner |
|---|---|
| STF (`Apply`), input decode, input-canonicity predicate, genesis, SMT key layout, `ChainVerifier` choice | **Plugin** |
| Foreign source watching (`Source`/`SourceAdapter`), external domains only | **Plugin** |
| Claim normalization | **Authorization plugin** |
| Output-class validation, roots, batching, proof harness | **Runtime** |
| Claim standing, replay, custody, conservation, issuance, release authorization | **Settlement** |

[CORE] The plugin's key layout MUST be a pure derivation to a 32-byte SMT path (`SHA3-256(contract_id ‖ local_key)` for WASM); the runtime consumes already-derived paths and MUST NOT key-hash (`SPEC.md` §13.3; `EXECUTOR.md` §7). [CORE]

### 12.2 `SettlementClient` (runtime → Settlement)

[FRAMEWORK] The runtime's view of Settlement. Builds and sends `SubmitBatch` / `RelayMessage` / `Challenge`, reads Settlement state via L1 state proofs, and (for `RANDOM_BACKUP`) computes the proposer schedule (`EXECUTOR.md` §5.5). It is the only component that talks to L1; the plugin never does.

```go
type SettlementClient interface {
    // Read paths (L1 state proofs; EXECUTOR.md §5.5).
    GetDomainRecord(domainId uint32, atHeight uint64) (DomainRecord, Proof, error)
    GetBatch(domainId uint32, batchId uint64, atHeight uint64) (BatchCommitment, Proof, error)
    GetInputCursor(domainId uint32, atHeight uint64) (uint64, Proof, error)
    GetCustody(domainId uint32, asset AssetID, atHeight uint64) (CustodyRecord, Proof, error)
    GetClaimPolicy(domainId uint32, policyVersion uint32, atHeight uint64) (ClaimPolicy, Proof, error)
    GetStateRoot(atHeight uint64) (Hash, error)             // recovery anchor

    // Write paths (account-blocks to Settlement).
    SubmitBatch(commitment BatchCommitment) (TxHash, error) // entitled proposer only
    RelayMessage(msg OutboxMessage, inclusion Proof) (TxHash, error) // permissionless
    RelayClaim(claim AuthorizedClaim, data ClaimDispatchData, inclusion ClaimProof) (TxHash, error) // permissionless
    Challenge(domainId uint32, target ChallengeTarget, fraudProof []byte) (TxHash, error) // OPTIMISTIC, A4

    // Proposer schedule (RANDOM_BACKUP / STAKE_WEIGHTED; SINGLE returns the sole member).
    EntitledProposer(domainId uint32, cursorPos uint64) (Address, error)
}
```

**Normative:**
- `SubmitBatch` MUST be callable only by the entitled proposer for the batch's `firstInputSeq` cursor position; Settlement re-checks entitlement on-chain (`SPEC.md` §6.2, §19). [CORE]
- `RelayMessage` MUST be permissionless and idempotent on `outboxId` (§10.3). [CORE]
- `RelayClaim` MUST be permissionless and idempotent on both claim replay keys. [FRAMEWORK]
- `Challenge` MUST exist only for `OPTIMISTIC` domains and MUST carry a fraud proof the on-chain referee can verify by re-running `Apply` for the single disputed input (§6.3; A4). [FRAMEWORK]
- All read paths MUST be backed by L1 state proofs so the executor trusts L1 state, not an RPC's word (`EXECUTOR.md` §5.5). [CORE]

### 12.3 Runtime-provided types (consumed, not implemented)

[CORE/FRAMEWORK] `EXECUTION` returns Phase-1 `Effects`; `AUTHORIZATION` returns `AuthorizationEffects`. The runtime MUST NOT coerce one output type into the other.

---

## 13. Security properties

Each subsection states a threat, the Normative defense, and the residual risk or OPEN PARAMETER. The defenses compose with the profile-dependent trust model of §2; none of them upgrades a profile's trust assumption (a defense bounds *additional* failure modes, it does not make `ATTESTATION` trustless).

### 13.1 Replay

**Threat.** An input, message, peg-in, peg-out, or batch is processed more than once.
**Defense (normative).** Every replay surface has its own idempotency key, enforced independently (§10.5): `inputHash` + `chain_id` for L1 inputs; `claimId` and `(domainId, ForeignEventID)` for claim effects; `outboxId` + `ProcessedOutbox` for message relay; `releaseId = outboxId` for foreign release; and the per-domain `InputCursor` for batches. Dispatch consumes both claim keys atomically. A second presentation of any consumed key MUST be rejected as a no-op. [CORE/FRAMEWORK]
**Residual.** None on Zenon for the keyed surfaces. The foreign side MUST maintain its own per-`outboxId` set (the on-Zenon `ProcessedOutbox` does not extend to the foreign chain); a `ReleaseAdapter` that omits this is non-conformant (§7.5; A7).

### 13.2 Equivocation

**Threat.** An executor identity submits two conflicting batches at the same cursor position, or two copies of the same identity run concurrently.
**Defense (normative).** State lineage is linear: Settlement accepts at most one batch per cursor position; a non-entitled or non-canonical submission MUST be rejected (`SPEC.md` §6.2, §19). The binary MUST hold a single-active-instance lease; a non-holder MUST exit before the execution loop (`EXECUTOR.md` §13). Double-submission and equivocation are process faults provable from Settlement storage alone, and are the only Phase-1-honest faults (`SPEC.md` §22). [CORE]
**Residual.** Equivocation across *distinct* set members under `RANDOM_BACKUP` is prevented by the objective proposer-entitlement rule; under `ATTESTATION`-quorum, a quorum that signs two conflicting commitments is a quorum-trust failure (Rail 1), bounded by slashing once `OPTIMISTIC` is enabled (A4).

### 13.3 Withheld data / DA failure (and watcher liveness)

**Threat.** The executor commits `DAHash` but withholds the bundle, so watchers cannot reproduce execution or build fraud proofs.
**Defense (normative).** For `L1_NATIVE`/`L1_RELAYED`, input data is on-chain (account-blocks), so input DA is inherited from L1 and cannot be withheld; only the *witness/result* bundle is off-chain (Rail 3). `DAMode` is recorded and Core MUST verify it is in the Periphery-approved set (`SPEC.md` §20). Under `OPTIMISTIC`, security additionally assumes **at least one honest watcher with bundle access** within the challenge window; the challenge window MUST be long enough for bundle retrieval and proof construction (Deployment parameter). [CORE]
**Residual.** An unavailable bundle reduces the affected batch to executor-honesty regardless of profile (Rail 3). On-chain DA enforcement is **Deferred** to Phase 2 (`SPEC.md` §20). `EXTERNAL_OBSERVED` has weaker, non-L1 DA that MUST be disclosed. DA-bundle retention floor relative to the challenge window is OPEN PARAMETER (`EXECUTOR.md` §19 Q-4).

### 13.4 Invalid or mismatched proofs

**Threat.** A submitted validity proof, fraud proof, attestation, foreign-inclusion proof, or `RelayMessage` inclusion proof is invalid or bound to the wrong statement.
**Defense (normative).** Each proof MUST be verified against its registered context before it has effect: `RelayMessage` against a `FINALIZED` batch's `outboxRoot`; `RelayClaim` against a `FINALIZED` Authorization batch's `claimRoot`, active policy version, and claim-effect budget; a `ZK_VALIDITY` proof against the registered `verifyingKeyId` and `publicInputSchema`; a fraud proof by re-running the canonical applier; and foreign evidence by the `ChainVerifier` against verified foreign consensus (§7.0, §7.3). A proof bound to a wrong domain, class, batch, policy, key, schema, root, or public input MUST be rejected. [CORE/FRAMEWORK]
**Residual.** Proof-system soundness is assumed (adversary model §2.4). Proof-object portability across heterogeneous foreign verifiers (one SNARK statement consumed by an EVM contract and an SVM program) is **not** assumed; per-releaser encodings are permitted and OPEN PARAMETER (`BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q2; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q1).

### 13.5 Finality misclassification and source-chain reorgs

**Threat.** A foreign event treated as final is reorganized; or a batch is built on un-confirmed L1 momenta; or a release finalizes over a re-organizable foreign event.
**Defense (normative).** On the L1 side, the executor MUST consume inputs only from momenta at or below `frontier − confirmationDepth`, and MUST HALT on a reorg deeper than `confirmationDepth` (`SPEC.md` §4.3; `EXECUTOR.md` §14). On the foreign side, the `ChainVerifier.VerifyFinality` predicate and `chainBinding.finalityParams` MUST be chosen so that no Zenon-side release authorization is emitted against a foreign event that can still reorganize under the foreign chain's stated finality; the three windows (source finality, destination finality, timeout) MUST be ordered so a refund cannot race a valid delivery (§10.6). [CORE/FRAMEWORK]
**Residual.** `confirmationDepth` (L1) and the per-chain foreign finality predicate are OPEN PARAMETER; choosing them too shallow reintroduces reorg risk, too deep harms latency (`EXECUTOR.md` §19 Q-1; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q4). Finality on probabilistic chains (BTC) is a confirmation-count choice; on accountable chains (ETH FFG) it is a slot/epoch rule; on Solana it is a vote/bank rule. The framework fixes the *predicate slot*, never the value.

### 13.6 Duplicate delivery

**Threat.** The same finalized message or peg-out is delivered/released twice (for example by two relayers racing).
**Defense (normative).** Delivery is idempotent on `outboxId`: the on-Zenon `ProcessedOutbox` (for local destinations and the Zenon-side release accounting) and the foreign-side per-`outboxId` set (for foreign releases) each admit a given `outboxId` once; a release is one-per-`RelayMessage` (`SPEC.md` §27.9). Relayers racing the same `outboxId` produce one success and rejected duplicates, never a double-release (§10.3, §10.4). [CORE/FRAMEWORK]
**Residual.** None on a conformant deployment. A `ReleaseAdapter` lacking foreign-side replay protection is non-conformant (§7.5).

### 13.7 Settlement conservation invariants (the formal core)

[FRAMEWORK] For every `(domainId, asset)`, after every state-modifying Settlement operation, the custody-mode-specific predicate MUST hold, and Core MUST revert any operation that would violate it. This generalizes `SPEC.md` §18.3.

**Custody mode `ESCROW` (Phase 1 native, `SPEC.md` §18.3):**
```
totalReleased[d][a] + pendingWithdrawalReserve[d][a]  ≤  totalDeposited[d][a]
```
- `totalDeposited` increases unconditionally and finally on the embedded receive of a `Deposit` / payable `CallL2` (the L1 transfer has settled). `pendingWithdrawalReserve` increases on `RelayMessage` of a finalized withdrawal; `totalReleased` increases on release after the delay, decreasing `pendingWithdrawalReserve` (`SPEC.md` §18.2). [CORE]

**Custody mode `MINTED` (representation asset, A6):** one compositional solvency predicate.
```
representationOutstanding[d][a] + pendingForeignRelease[d][a]
    <= verifiedLockedCollateral[d][a]
```

The three terms denote current amounts, not cumulative historical totals. Settlement MUST apply these atomic transitions:

| Event | `representationOutstanding` | `pendingForeignRelease` | `verifiedLockedCollateral` |
|---|---:|---:|---:|
| finalized, replay-checked `FOREIGN_LOCK` claim | `+ amount` | unchanged | `+ amount` |
| finalized local burn creating a peg-out authorization | `- amount` | `+ amount` | unchanged |
| finalized, replay-checked `FOREIGN_RELEASE` claim | unchanged | `- amount` | `- amount` |
| finalized, replay-checked `FOREIGN_NON_DELIVERY` refund | `+ amount` | `- amount` | unchanged |

- Each transition MUST reject underflow, overflow, asset/domain mismatch, or a post-state violating the predicate. A lock claim mints and records backing atomically; a burn and its authorization are atomic; release reconciliation and timeout refund are mutually exclusive on `outboxId`. [FRAMEWORK, A6]
- A `FOREIGN_RELEASE` claim records what the foreign adapter finalized; it does not authorize that release retroactively. The only release authority is the earlier finalized burn-bound `PegOutAuthorization`. [FRAMEWORK]
- Minting against an unfinalized claim, authorizing against an unfinalized burn, or refunding without a finalized non-delivery claim MUST be rejected. [FRAMEWORK]

> **Predicate vs mechanism (`MINTED`).** The predicate and transition table are normative and sufficient to test conservation, but the exact Settlement/Core and ZTS issuance mechanism remains OD-1. The Phase-1 `AssetFlowSummary` reconciliation path does not apply: Authorization batches commit bounded claims, and Settlement performs issuance and reconciliation only during atomic claim dispatch. `MINTED` MUST remain disabled until the MINTED Settlement Extension Specification resolves OD-1 (§7.2).

**Common to both modes (normative):**
- The per-batch cap `MaxBatchWithdrawal` MUST be enforced per `(domain, asset)` so the maximum loss from a single fraudulent batch is bond-coverable (`SPEC.md` §18.3, §22). [CORE]
- Runtime-emitted deposit refunds (`SPEC.md` §18.5) are excluded from the `MaxBatchWithdrawal` aggregate but remain conservation-bounded (`SPEC.md` §27.9). [CORE]
- `AssetFlowSummary` deposit credits MUST reconcile against recorded L1 deposit events on `SubmitBatch` for `ESCROW` (`SPEC.md` §18.4). `MINTED` uses finalized claim dispatch and the transition table above, not an Authorization Domain `AssetFlowSummary`. [CORE/FRAMEWORK]
- Aggregate over-withdrawal/over-mint MUST be impossible and MUST NOT depend on executor honesty; per-account/per-message correctness relies on executor honesty until the execution profile removes it (Rail 1). [CORE]

### 13.8 Gas underfunding

**Threat.** An input or destination delivery runs out of gas mid-execution, leaving partial state.
**Defense (normative).** L2 execution that exhausts gas MUST fail `OUT_OF_GAS` with **full rollback**; no `StateDiff`/`Events`/`OutboxMessages` are applied (`SPEC.md` §10.5, §14.3). The L1 input must be plasma/PoW-funded merely to *enter* the stream; under-funding there means the input never becomes canonical, not a partial apply (`SPEC.md` §4.1). Destination-side gas is fronted by the relayer against a prepaid fee; an under-funded delivery fails atomically at the destination and is retried or refunded, never half-applied (§7.8, §15.5). [CORE/FRAMEWORK]
**Residual.** A persistently under-priced destination causes liveness delay (retries), never a custody fault (the fee is advisory, §7.8).

### 13.9 Partial execution failure

**Threat.** A multi-effect input partially succeeds (some state written, some messages emitted) then fails.
**Defense (normative).** Execution is all-or-nothing per input: on any failure (`REVERT`, `OUT_OF_GAS`, `RUNTIME_FAULT`, `VALIDATION_FAILED`, `RESULT_TOO_LARGE`) state is left unchanged and contract-emitted effects are discarded (`SPEC.md` §13.5, §14.3). The **only** exception is the runtime-emitted deposit refund, which is appended independently so a failed deposit still returns funds (`SPEC.md` §18.5, §27.4). A failed input still produces exactly one receipt with `status ≠ SUCCESS` (`SPEC.md` §15). [CORE]
**Residual.** A contract that *explicitly* claims a deposit then mishandles it is a bridge-specific contract bug (§13.15), not a partial-execution failure of the runtime.

### 13.10 Governance key compromise

**Threat.** The single Settlement administrator key (or the foreign verifier-contract upgrade key) is compromised.
**Defense (normative, Zenon side).** The administrator controls Periphery only; Core is node-binary and unreachable (`SPEC.md` §5.2). Every administrator action is time-locked (`AdministratorDelay ≥ 2 × MomentumsPerEpoch`; `SoftDelay ≥ MomentumsPerEpoch`), giving users an exit window before any change takes effect; guardians can install a new administrator under the delay; and Core hard bounds (challenge-window/withdrawal-delay min/max, `MaxBatchWithdrawal` floor/ceiling, `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`) cannot be exceeded **even by a compromised administrator** (`SPEC.md` §23). The administrator MUST NOT alter finalized roots, canonical order, the withdrawal delay below bounds, bonded funds absent a fraud proof, or any Core constant. The one custody-touching administrator action (the domain escape hatch) is itself time-locked, guardian-co-signed, and event-emitting (`SPEC.md` §23). [CORE]
**Defense (normative, foreign side).** The pinned Interop Enforcement Specification MUST identify every adapter upgrade key, threshold, delay, pause path, and custody power. Immutable or proof-gated adapters are preferred; any mutable deployment MUST provide an exit window and versioned migration procedure (§18.3; A7). [FRAMEWORK]
**Residual.** A compromised Zenon administrator can still degrade liveness within Core bounds. A compromised foreign adapter or upgrade authority may drain or freeze the custody it controls; Zenon can stop issuing new authorizations and isolate the domain, but cannot reverse a foreign-chain release or force an adapter upgrade. That risk MUST be stated per chain rather than described as eliminated. [FRAMEWORK]

### 13.11 Verifier / adapter version skew

**Threat.** The executor, the watcher, the on-chain referee/verifier, and the foreign `ReleaseAdapter` disagree on the STF, the proof format, or the SMT semantics.
**Defense (normative).** `stfSpecHash` pins runtime, wire formats, profiles, policy, and the full `ChainBinding`; `PegOutAuthorization.chainBindingHash` separately binds the foreign consumer to the named adapter and `enforcementSpecHash`. Snapshots and proofs with mismatched pins MUST be rejected. A runtime, verifier, adapter, or enforcement-spec change is a delayed, versioned migration (§18.2, §20). [CORE/FRAMEWORK]
**Residual.** Zenon cannot force foreign software to upgrade. The old adapter version MUST remain able to settle or expire every authorization issued under its binding before custody migrates; otherwise the upgrade is a liveness or custody event governed by the per-chain Interop Enforcement Specification. [FRAMEWORK, A7]

### 13.12 Message ordering bugs (and ack degradation)

**Threat.** Cross-domain/cross-chain messages are delivered out of intended order, or an ack is lost.
**Defense (normative).** In the base profile, messaging guarantees **at-most-once** delivery via `outboxId`, not total order; inter-batch total ordering is **Deferred** to Phase 2 (`SPEC.md` §17.3). A channel needing ordering MUST encode sequence numbers in its `payload` and enforce ordering in the destination STF; the framework MUST NOT silently assume ordering it does not provide. Acks are confirmations only: a lost ack MUST NOT revert an already-`EXECUTED` message; source-side retry/timeout policy handles it (§10.4). [CORE/FRAMEWORK]
**Residual.** Application-level ordering is the application's responsibility until Phase 2 inter-batch ordering lands. Choosing the ack/timeout windows is OPEN PARAMETER (§10.6).

### 13.13 Cross-domain isolation failure

**Threat.** A fault in one domain reaches another domain's custody.
**Defense (normative).** All custody, conservation, commitment, deposit, withdrawal, and replay accounting MUST be keyed by `domainId` (and `(domainId, asset)`); an executor is bonded per `domainId` and supports exactly one domain; cross-domain interaction is asynchronous (outbox → finalize → relay into the other domain's inbox), with no synchronous cross-domain calls (`SPEC.md` §6, §17.1, §18). In-process multi-domain hosting MUST isolate state and key material per domain (`EXECUTOR.md` §4). [CORE]
**Residual.** None at the protocol level: a faulty ETH bridge cannot drain the BTC pool because conservation is per `(domain, asset)` and the authorization for one domain cannot verify against another's `outboxRoot` (`BRIDGE-FRAMEWORK-RESEARCH.md` §1, §7). Cross-instance accounting for a unified dashboard needs care but is read-only (`BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q3).

### 13.14 Fee quote manipulation

**Threat.** An adversary manipulates a `FeeQuote` to overcharge, undercharge, or stall.
**Defense (normative).** A `FeeQuote` is advisory and never gates correctness (§7.8): inclusion is gated by L1 plasma/PoW, execution by gas with full-rollback on exhaustion, and release by conservation and replay protection. A manipulated quote can only make a delivery unprofitable (retried) or cause a refund; it MUST NOT over-release value or corrupt state. Prepaid destination fees MUST be conservation-accounted like any other asset. [FRAMEWORK]
**Residual.** Liveness/UX degradation only. The reimbursement mechanism and quote-refresh policy are OPEN PARAMETER.

### 13.15 Bridge-specific contract bugs

**Threat.** A bug in an Authorization STF, a Settlement claim handler, a foreign `ReleaseAdapter`, or a user contract that accepted funds.
**Defense (normative).** Class-output checking and namespace disjointness prevent an Authorization STF from writing accounting state. Settlement handlers are closed, registered, cap-bounded, replay-checked, atomic, and conservation-checked (§7.0, §7.10, §13.7). A conformant adapter verifies only finalized, burn-bound, binding-matched authorizations and releases each `outboxId` once (§7.5). [CORE/FRAMEWORK]
**Residual.** A Settlement Core bug is a protocol bug. A contract can mishandle funds it accepted. A foreign adapter bug or compromised governance authority can drain or freeze that adapter's foreign custody despite perfect Zenon-side claims; the framework limits cross-domain blast radius and provides a precise audit contract, but it cannot enforce code on another chain (§18.3). [FRAMEWORK]

### 13.16 Pinned-spec semantic non-conformance

**Threat.** `enforcementSpecHash` is non-zero and resolves to exact bytes, but the artifact omits or misstates one of §18.3's required rules, does not describe the deployed adapter faithfully, or is approved without substantive review.

**Defense (normative).** Core MUST reject a zero hash and bind the accepted bytes into `ChainBinding` and `stfSpecHash`. The activation/governance process and conforming validators MUST retrieve those bytes, check all seven §18.3 obligations against the deployed adapter, and reject activation on any omission or mismatch. Chain-specific audits and conformance vectors SHOULD be independently reproducible before activation. [FRAMEWORK, A7]

**Residual.** A content hash proves artifact identity, not semantic adequacy or reviewer diligence. Negligent or colluding activation governance and validators can approve a non-conformant specification or adapter. Zenon can still enforce its own claim standing, replay, caps, and conservation boundaries, but it cannot prevent that foreign deployment from freezing, mis-releasing, or losing the custody it controls. The activation reviewers and supporting validators are therefore part of the disclosed per-chain trust model until the relevant obligations become mechanically verifiable. [FRAMEWORK]

### 13.17 Consolidated MUST-fail conditions

[CORE/FRAMEWORK] An implementation MUST fail (reject the operation, or HALT where indicated) on each of:
- Non-contiguous, overlapping, replayed, mis-ordered, or oversized batch (reject; `SPEC.md` §4.6).
- `preStateRoot ≠ previous accepted postStateRoot` for the domain (reject; `SPEC.md` §19).
- Unrecognized `protocol_version` or any version field (reject; `SPEC.md` §24).
- Non-empty `proofData` outside the profile/phase that defines it (Phase 1: empty always; post-A13: quorum attestation under `ATTESTATION`-quorum only; post-A5: validity proof under `ZK_VALIDITY` only); an invalid `ZK_VALIDITY` proof; a failed quorum attestation (reject; §9.2).
- A batch whose output type, roots, state namespace, or effect summary disagrees with `domainClass` (reject and HALT the domain on forbidden Authorization state writes; §6.1, §7.0, §11.4).
- `RelayClaim` against a non-Authorization or unfinalized batch; invalid claim inclusion; inactive/wrong policy version; schema, type, asset, handler, finality, cap, or budget mismatch; consumed `claimId` or `(domainId, ForeignEventID)`; or a post-effect conservation failure (reject atomically; §7.0, §7.10).
- `RelayMessage` with a mismatched `domainId`/`batchId`, an unfinalized batch, or an `outboxId ∈ ProcessedOutbox` (reject; `SPEC.md` §17.3).
- Authorization-domain activation with a zero, unavailable, or mismatched `enforcementSpecHash` (reject; §6.1, §18.3).
- `ReleaseAdapter.Release` with a wrong `chainBindingHash`, adapter/spec version, proof, asset, amount, recipient, or burn reference; an unfinalized authorization; a consumed `outboxId`; or an expired deadline (reject atomically; §7.5, §18.3).
- Any operation violating the §13.7 conservation predicate (revert; `SPEC.md` §18.3).
- `AssetID` with a non-zero byte in `[0:22]` or non-canonical alignment (reject; `SPEC.md` §18.1).
- A `RegisterDomain` selecting a reserved `inputSource`/profile under the active phase profile, or an illegal profile combination (reject; §6.5).
- A runtime-upgrade delay below `WithdrawalDelay`, or any Periphery value outside Core hard bounds (reject; `SPEC.md` §23).
- Any internal consistency fault in the executor (HALT; §11.4).

---

## 14. Liveness properties

[FRAMEWORK] Safety (no over-release, no double-spend) never depends on liveness; this section states what the framework guarantees about *progress*, separately and weaker.

### 14.1 Liveness guarantees and their conditions

| Property | Holds when | Source |
|---|---|---|
| **Input inclusion** | At least one honest relayer exists (relaying is permissionless), and the input is plasma/PoW-funded | `SPEC.md` §4.2; `EXECUTOR.md` §12 |
| **Batch progress** | The entitled proposer is live, or `proposerPolicy ≠ SINGLE` provides a backup that becomes entitled | `SPEC.md` §6.2; A3 |
| **Withdrawal/peg-out delivery** | At least one honest relayer carries the finalized `kind=1` authorization; the `ReleaseAdapter` is live | §10.3; A7 |
| **Challenge liveness** (`OPTIMISTIC`) | At least one honest watcher with bundle access acts within the window | §13.3; A4 |
| **Foreign-view advance** | At least one honest relayer posts foreign headers/proofs | §7.4; §13.5 |

**Normative:**
- Under `proposerPolicy = SINGLE` (Phase 1), batch progress depends on the single executor; its outage stalls the domain but **cannot** cause loss, and recovery resumes from the last finalized anchor (§11.3). Liveness beyond one executor requires A3 (`SPEC.md` §22, §30). [CORE]
- No liveness mechanism MAY shorten a finality window, bypass a conservation check, or release against an unfinalized batch to "make progress". Progress that would violate §2.2 or §13.7 MUST NOT be taken. [FRAMEWORK]
- Censorship-resistance is a liveness property delivered by permissionless relay plus force-inclusion; it MUST NOT be weakened by a profile choice (`SPEC.md` §4.2). [CORE]

### 14.2 The finality-window ordering constraint (liveness vs safety)

[FRAMEWORK] The single most delicate liveness/safety interaction is the timeout/refund race (§10.6). The constraint `sourceFinality + destinationFinality ≤ timeoutDeadline` MUST hold so that the refund path (a liveness affordance) can never fire on a message that is still validly deliverable (a safety violation). Choosing these windows is OPEN PARAMETER per channel; the constraint on their *ordering* is Normative. [FRAMEWORK]

---

## 15. Failure handling and recovery

[CORE] Fail-closed is the governing principle: when the system cannot prove it is correct, it MUST stop, not guess (`EXECUTOR.md` §2, §15).

### 15.1 Failure taxonomy

| Class | Examples | Disposition |
|---|---|---|
| **Per-input execution failure** | `REVERT`, `OUT_OF_GAS`, `RUNTIME_FAULT`, `VALIDATION_FAILED`, `RESULT_TOO_LARGE` | Roll back the input; emit a non-success receipt; continue the batch (§13.9; `SPEC.md` §14.3) |
| **Transient operational fault** | disk, OOM, RPC/network blip | Auto-restart with bounded backoff (`EXECUTOR.md` §14) |
| **Consistency fault** | root mismatch, DA round-trip mismatch, anchor mismatch, deep reorg, snapshot substitution, lease loss | HALT until operator action (§11.4) |
| **Foreign-side failure** | `ReleaseAdapter` down/buggy, foreign reorg | Zenon side safe (one-per-`outboxId`, conservation-bounded); delivery delayed/retried/refunded (§13.5, §13.6) |
| **Governance fault** | administrator key compromise | Time-lock + guardians + Core bounds; user exit window (§13.10) |

### 15.2 Retry semantics (normative)

- **Input inclusion retry:** permissionless; any relayer MAY repost; L1 account-block uniqueness dedups (§13.1). [CORE]
- **Batch submission retry:** an accepted batch re-submitted at the same cursor MUST be rejected by contiguity, not double-applied; a rejected submission MAY be corrected and resubmitted while the cursor is unchanged (§11.2). [CORE]
- **Message/peg-out delivery retry:** permissionless and idempotent on `outboxId`; racing relayers yield one success and rejected duplicates (§13.6). [CORE/FRAMEWORK]
- **Foreign-view retry:** a withheld header is defeated by open relay; any relayer MAY post it (§7.4). [CORE]
- **DA retry:** at recovery, a missing pre-finalization bundle enters `AWAIT_DA` with bounded retry, then HALT (§11.3). [CORE]

Retries MUST be safe by construction (idempotent on the relevant key), never "try again and hope"; a retry that is not idempotent on a key MUST NOT exist (§10.5). [FRAMEWORK]

### 15.3 Recovery from anchors (normative)

Recovery is the §11.3 procedure: reconcile against the most recent finalized root, forward-replay the domain subsequence, distinguish local-absent from root-mismatch (HALT on mismatch), and never resume past an unresolved consistency fault. State is always a deterministic function of L1-anchored data, so recovery is replay, not reconstruction from a backup (`EXECUTOR.md` §10, §14). [CORE]

### 15.4 Halt and resume (normative)

A HALTED binary MUST surface the specific invariant violated and MUST require operator action; it MUST NOT auto-resume a consistency fault (§11.4). Operator runbooks (snapshot vs replay-from-genesis, divergence triage) are implementation guidance (`EXECUTOR.md` §17), but the halt itself is Normative.

### 15.5 Refund and rollback (normative)

[FRAMEWORK] Two refund paths exist, both conservation-preserving:
- **Deposit refund (peg-in side, intra-domain).** A deposit a contract does not explicitly claim is auto-refunded by the runtime as an independent outbox effect, even if the triggering input failed (`SPEC.md` §18.5, §27.4). [CORE]
- **Timeout refund (messaging/peg-out side, cross-chain).** On a destination-side non-delivery proof past the timeout, the source re-credits (`ESCROW`) or re-mints (`MINTED`) the value, consuming the `outboxId` via the timeout path so delivery and refund are mutually exclusive (§10.3, §10.4, §7.6). The re-credit/re-mint MUST re-satisfy §13.7. [FRAMEWORK]

A rollback MUST NOT alter a finalized root or another `(domain, asset)`'s counters; it only returns the specific debited/burned value to its origin under the same invariant that authorized the attempt. [FRAMEWORK]

---

## 16. Testing and simulation

[FRAMEWORK] The framework inherits the Phase 1 conformance philosophy: behaviour is pinned by vectors and differential replay, not by prose alone (`SPEC.md` §13.7, §28; `EXECUTOR.md` §16).

### 16.1 Required conformance vectors

A conformant implementation MUST pass:
- **SMT conformance suite** over the path-native API: `RootOfLeaves`/`ProveByPath`/`VerifyProofByPath`/`VerifyAbsenceByPath`, the empty-vs-absent distinction (`EMPTY` sentinel `0xFFFFFFFF` vs present-empty `0x00000000`), and the canonical applier ordering (`SPEC.md` §13.5.1, §13.6; A11). [CORE]
- **Execution conformance vectors:** `(preStateRoot, input, code_hash) → (postStateRoot, ExecutionResult, receipt)` triples, including every failure mode and the deposit-refund hook (`SPEC.md` §28; §13.9). [CORE]
- **Gas/metering vectors** at the pinned `metering_version` (`SPEC.md` §10.2). [CORE]
- **Wire-format vectors** for every canonical encoding, including the generalized `proofData` arms and the new `PegOutAuthorization`/`Timeout` encodings (§9). [FRAMEWORK]
- **Conservation vectors** for both custody modes (§13.7), including over-withdraw/over-mint rejection and `MaxBatchWithdrawal` enforcement. [FRAMEWORK]
- **Profile vectors:** `ATTESTATION`/`OPTIMISTIC`/`ZK_VALIDITY` finality transitions (§10.2) and `COMMITTEE`/`LIGHT_CLIENT`/`ZK_CONSENSUS` foreign-fact acceptance/rejection (§6.4). [FRAMEWORK]

### 16.2 Differential and replay testing

- **Differential execution:** independent implementations MUST agree byte-for-byte on roots and results for shared vectors (`SPEC.md` §13.7). [CORE]
- **Replay determinism:** replay from genesis and from snapshots MUST reach byte-identical state; a snapshot tagged with a mismatched `stfSpecHash` MUST trigger replay, not load (`EXECUTOR.md` §16). [CORE]
- **Watcher divergence:** a watcher fed the same inputs MUST reproduce the proposer's roots or surface divergence; under `OPTIMISTIC` it MUST be able to construct a verifying fraud proof for an injected divergence (§13.3; A4). [FRAMEWORK]

### 16.3 Adversarial simulation (recommended)

[Implementation guidance] Simulate, per domain: foreign reorgs up to and beyond `confirmationDepth`; DA withholding across the challenge window; relayer censorship and racing duplicates; fee-quote manipulation; timeout/refund races at the window boundary (§14.2); and governance-key-compromise drills against the time-lock. These are recommended harnesses, not Normative vectors, but the **window-ordering** and **conservation** properties they probe are Normative.

### 16.4 Bridge-specific test matrix

[Implementation guidance] For each bridged chain, derive tests from the pinned Interop Enforcement Specification. Test the `ChainVerifier` against real headers and reorg/finality edges; test the `ReleaseAdapter` against duplicate `outboxId`, wrong `chainBindingHash`, wrong adapter/spec version, unfinalized or mismatched authorization, deadline-boundary delivery, atomic failure, and upgrade migration. Trace peg-in → claim → mint → burn → authorization → release claim, plus timeout → non-delivery claim → refund, against §13.7 after every transition.

---

## 17. Formal verification strategy

[FRAMEWORK] Targets for machine-checked or proof-carrying assurance, in priority order. This is a strategy, not a delivered artifact; items are Deferred unless a Phase activates them.

### 17.1 Highest-value invariants to formalize

1. **Conservation (§13.7), both modes.** The aggregate-solvency predicates are the load-bearing safety property and the natural first target for a machine-checked proof that no Settlement operation sequence violates them. [FRAMEWORK]
2. **Replay/idempotency (§10.5).** Each surface's key uniquely gates its effect; formalize that no two distinct effects share a key and no key admits two effects. [FRAMEWORK]
3. **Finality-window ordering (§14.2).** The `sourceFinality + destinationFinality ≤ timeoutDeadline` constraint and the delivery/refund mutual exclusion (§7.6) are a small, high-value temporal property. [FRAMEWORK]
4. **Linearity of state lineage (§13.2).** At most one accepted batch per cursor; no equivocation finalizes. [CORE]
5. **Profile soundness hooks.** Under `ZK_VALIDITY`, the verified statement MUST entail `postStateRoot = F(preStateRoot, inputs, code_hash)`; under `OPTIMISTIC`, the referee procedure MUST be sound and complete for single-input divergence (`SPEC.md` §13.5.1). [FRAMEWORK]

### 17.2 Approach

[Implementation guidance]
- **Executable spec + differential testing** is the Phase 1 baseline and MUST remain the conformance backstop regardless of later proofs (`SPEC.md` §28). [CORE]
- **State-machine model checking** (TLA+-style) of the batch, peg-out, and message lifecycles (§10) for the safety and window-ordering properties, with the conservation predicate as an invariant. [Guidance]
- **Proof-carrying execution** under `ZK_VALIDITY`: the validity proof *is* the per-batch formal artifact; the framework's job is to pin the statement schema (`publicInputSchema`) so the proof means what Settlement assumes (§9.2; A5). [FRAMEWORK]
- **Foreign-fact verification** (`ChainVerifier`) is verified against the foreign chain's own finality spec; `LIGHT_CLIENT` correctness reduces to the foreign consensus rule, `ZK_CONSENSUS` to the proof system's soundness (§6.4). [Guidance]

### 17.3 Scope limits

[FRAMEWORK] Formal verification here covers the **Zenon-side** framework and its invariants. `ReleaseAdapter` correctness is a separate per-chain proof or audit obligation against the pinned Interop Enforcement Specification (A7). Zenon bounds what it authorizes and isolates accounting by domain; it does not bound arbitrary behavior by a compromised foreign custody contract. The proving system's internal soundness is assumed, not proved here (§2.4).

---

## 18. Deployment and upgrade strategy

[CORE] Generalized from `SPEC.md` §23 and §11. Two trust surfaces (Zenon Periphery, foreign adapter) are governed separately and never merged.

### 18.1 Governance invariants (Zenon side, normative)

- **Core is unreachable by governance.** SettlementCore is node-binary logic, changeable only by a sanctioned node release; the administrator cannot alter it (`SPEC.md` §5.2). [CORE]
- **Everything administrator-tuned is Periphery and Core-clamped.** Caps, delays, verifier registries, and admin/guardian sets live in Periphery; each has a Core hard bound the administrator cannot exceed: `challengeWindow`/`WithdrawalDelay` within `[min,max]`, `MaxBatchWithdrawal` within `[floor,ceiling]`, `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`, `AdministratorDelay ≥ 2 × MomentumsPerEpoch`, `SoftDelay ≥ MomentumsPerEpoch` (`SPEC.md` §23, §25). [CORE]
- **Time-locks on every change.** Hard-parameter changes wait `AdministratorDelay`; soft changes wait `SoftDelay`; runtime/profile changes wait `MinRuntimeUpgradeDelay ≥ WithdrawalDelay`, guaranteeing a user-exit window before any semantics change (§13.10). [CORE]
- **Guardian recovery.** Guardians can replace a compromised administrator under the delay, but cannot themselves exceed Core bounds (`SPEC.md` §23). [CORE]
- **Migration to multisig.** The single-administrator model is an explicit consequence of Zenon L1 lacking an on-chain `k`-of-`n` multisig (A10); the administrator SHOULD be a governance/multisig address once one exists (`SPEC.md` §23). [CORE]

### 18.2 Upgrade procedures (normative)

- **Runtime/profile upgrade** (including ladder migrations, §6.6) is a `stfSpecHash` bump under `MinRuntimeUpgradeDelay`; the replacement's first batch `preStateRoot` MUST equal the last accepted `postStateRoot`; no finalized root/receipt/counter changes (`SPEC.md` §6.2, §22; §6.6). [CORE]
- **Contract code deployment/upgrade** within a domain uses chunked deployment with a pre-registered `code_hash` and atomic activation; a partially uploaded code MUST NOT execute (`SPEC.md` §11). [CORE]
- **Verifier registry updates** (Periphery): adding an `OPTIMISTIC` referee (A4) or a `ZK_VALIDITY`/`ZK_CONSENSUS` verifying key (A5) is a Periphery change under the delay; it MUST NOT retroactively invalidate a finalized batch. [FRAMEWORK]
- **Profile activation** (`RegisterDomain` or migration enabling a reserved profile) MUST satisfy §6.5 prerequisites. An Authorization Domain additionally requires A7, A12, A15, and A16; `MINTED` additionally requires A6 and resolution of OD-1. [FRAMEWORK]

### 18.3 Foreign-side deployment (normative obligations, A7)

Every foreign-chain deployment MUST publish a chain-specific **Interop Enforcement Specification** before its Authorization Domain can activate. That document is the controlling specification for the named `ReleaseAdapter`, and its canonical hash MUST equal `ChainBinding.enforcementSpecHash`. `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q5 is the framework-level forward pointer; the corresponding BTC, EVM, SVM, or other Interop document supplies the load-bearing chain-specific rules.

The Interop Enforcement Specification MUST define:

1. the custody location, asset mapping, and every principal or key able to move or freeze custody;
2. canonical encodings and validation rules for `chainBindingHash`, `PegOutAuthorization`, `ZenonProof`, `ReleaseReceipt`, and foreign non-delivery evidence;
3. how Zenon L1 finality and inclusion of the exact `PENDING` `PegOutRecord`, including `burnRef`, binding, destination recipient/amount/asset, and deadline, are verified;
4. persistent `outboxId` replay storage and atomic ordering of verify, release, and replay-key write;
5. the exact destination-finality and timeout/refund rules, including rejection after deadline and the proof that delivery and refund are mutually exclusive;
6. deployment addresses/scripts/graph identifiers, initialization anchors, audit artifacts, conformance vectors, monitoring, pause, and recovery procedures; and
7. upgrade keys, thresholds, time-locks, exit window, old-version settlement period, and custody-migration procedure.

Core MUST mechanically reject a zero `enforcementSpecHash`; it need not parse the document. The activation/governance process and conforming validators MUST retrieve and review the exact bytes named by the hash and MUST keep the domain inactive if the artifact is unavailable, omits a required rule, or names an adapter inconsistent with `releaseAdapterRef`. Changing the adapter or document requires a delayed domain migration and a new `chainBindingHash`; the old adapter MUST remain able to settle or expire all authorizations issued under its binding before custody migrates. [FRAMEWORK, A7]

The `genesisAnchor` MUST be the agreed light-client checkpoint and, with every other `ChainBinding` field, MUST be folded into `stfSpecHash` (§6.1). These obligations do not make foreign code controllable by Zenon; they make its trust and failure surface explicit, versioned, auditable, and deployment-blocking rather than merely out of scope. The residual trust in the off-chain semantic review is stated explicitly in §13.16.

### 18.4 Phased rollout (informative)

A new bridge domain follows the corpus's phase ladders independently of other domains: stand up as `(ATTESTATION, COMMITTEE or LIGHT_CLIENT)` with conservative caps and a long withdrawal delay; widen caps and shorten delay as the `ChainVerifier`/`ReleaseAdapter` earn confidence; migrate along the execution ladder to `OPTIMISTIC` (A4) then `ZK_VALIDITY` (A5), and along the foreign-fact ladder to `ZK_CONSENSUS`, each as a `stfSpecHash` bump (§6.6). Per-domain phasing means a mature BTC bridge and a new SOL bridge coexist at different rungs.

---

## 19. Performance and cost tradeoffs

[FRAMEWORK] The framework fixes *where* costs land, never their magnitudes (those are per-chain and per-deployment, OPEN PARAMETER).

### 19.1 Cost centres

| Cost | Where | Scaling | Lever |
|---|---|---|---|
| L1 anchoring | Settlement storage per batch | **Constant** per batch (roots + bounded metadata ≤ 16 KiB) | `MaxBatchInputs` amortizes more inputs per anchor (`SPEC.md` §3, §25) |
| Off-chain execution | Executor | Linear in input count/complexity at `metering_version` | Batch size; runtime efficiency (`SPEC.md` §10.2) |
| DA bundle | Sentinel/libp2p | Linear in witness/result size | `DAMode`; bundle retention window (`SPEC.md` §20) |
| Foreign verification (peg-in) | STF (`ChainVerifier`) | Per foreign-fact profile: `LIGHT_CLIENT` linear in headers; `ZK_CONSENSUS` constant-ish verify | Profile choice; checkpoint cadence (§6.4) |
| Foreign release (peg-out) | `ReleaseAdapter` on foreign chain | Foreign gas to verify a Zenon proof | Proof system; Tier-1 optimistic vs Tier-2 in-script (§7.5) |
| Proof generation | Prover (`ZK_VALIDITY`/`ZK_CONSENSUS`) | Heavy off-chain; light on-chain verify | Proving system; SMT hash (A8) |

### 19.2 The central tradeoff: trust vs latency vs cost

[FRAMEWORK] Moving up either ladder trades proving/verification cost and latency for reduced trust (§2.5):
- `ATTESTATION → OPTIMISTIC` adds a challenge-window **latency** (withdrawal waits the window) for fraud-provable safety; cheap on-chain, needs watcher liveness + DA. [FRAMEWORK]
- `OPTIMISTIC → ZK_VALIDITY` removes the challenge window (finality MAY be immediate) at the cost of **prover** expense and possibly an SMT hash migration (A8). [FRAMEWORK]
- `COMMITTEE → LIGHT_CLIENT` adds **header-tracking** cost for cryptographic foreign truth; `LIGHT_CLIENT → ZK_CONSENSUS` trades **prover** cost for cheap on-chain consensus verification. [FRAMEWORK]
- The light-client data cost on data-heavy chains (Solana vote data) is precisely why `EXTERNAL_OBSERVED` exists as a DA-tradeoff escape hatch (§6.2; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q2). [FRAMEWORK]

### 19.3 OPEN PARAMETERS (performance)

`MaxBatchInputs` tuning, `confirmationDepth` per chain, DA retention window vs challenge window, checkpoint cadence per light client, proof-batching granularity, and the inline-vs-reference `proofData` threshold are all OPEN PARAMETER, owned by Domain Settlement implementers (§22).

---

## 20. Versioning and migration rules

[CORE] Generalized from `SPEC.md` §24 and §6.2.

### 20.1 Explicit versioning (normative)

Every consensus-visible structure carries an explicit version and is **unknown-version-rejects**: `protocol_version`, `metering_version`, `serialization_version`, `statediff_version`, `executionresult_version`, `receipt_version`, `outbox_version`, `damode_version`. An unrecognized value MUST cause rejection before any other field is interpreted (`SPEC.md` §24). The generalized `proofData` arms and the new `PegOutAuthorization`/`Timeout` encodings are governed by `protocol_version`/`outbox_version`. [CORE]

### 20.2 `stfSpecHash` as the semantic pin (normative)

`stfSpecHash` pins runtimeKind, VM version, genesis, the input envelope, commitment format, claim policy, profiles, and every field of `ChainBinding`, including `releaseAdapterRef` and `enforcementSpecHash`. Any change to these is a `stfSpecHash` bump; a snapshot tagged with a mismatched hash MUST NOT load without replay (§6.1, §13.11; `EXECUTOR.md` §16). [CORE/FRAMEWORK]

### 20.3 Domain runtime migration (normative)

Replacing a domain's runtime/profile preserves the ledger: same custody counters, same commitment lineage; the replacement's first `preStateRoot` MUST equal the last accepted `postStateRoot`; no finalized artifact changes (`SPEC.md` §6.2, §22). [CORE]

### 20.4 Ladder migration rules (normative)

Both ladders migrate additively (§6.6): each step is a strict strengthening, changes no commitment format and no custody accounting, MAY shrink the withdrawal delay along the execution ladder, and MUST keep the first post-migration `preStateRoot` equal to the last pre-migration `postStateRoot`. Adding Periphery verifier registries is the only new on-chain footprint. [FRAMEWORK]

### 20.5 Wire-compatibility rule (normative)

The **batch commitment** encoding is wire-forward-compatible: every Phase 1 commitment is a legal generalized commitment (empty `proofData`, `EXECUTION` class), and a Phase 1 verifier rejects only the new constructs it does not recognize, exactly as the unknown-version rule already mandates (`SPEC.md` §24). The **outbox encoding** (`Destination`/`Timeout`/`ackPolicy`; A14), the **`DomainRecord` schema** (A12), and any `MINTED`-mode `AssetFlowSummary` extension require versioned upgrades and are **not** backward-compatible at the wire level; a domain using them MUST operate under the bumped version fields. [FRAMEWORK]

---

## 21. Acceptance criteria

[FRAMEWORK] This specification is **complete enough to implement** when an engineer can build each component below from this document plus the cited primary corpus, **without inventing protocol behaviour**. Each criterion names the component and the sections that fully determine it.

A conformant realization MUST allow independent implementation of:

1. **Proposer / executor**: from §11 (pipeline, idempotency, recovery, halt), §12.1 (`DomainPlugin`), §12.2 (`SettlementClient`), §10.1 (batching/contiguity), §9 (wire formats). An engineer MUST be able to build the follower, STF host, SMT stage, batch builder, and DA publisher with no undefined behaviour. ✔ if every pipeline stage and every submit/relay/challenge call is specified; OPEN PARAMETERS (`confirmationDepth`, batch tuning) are explicitly listed, not missing.
2. **Watcher / fraud-proof harness**: from §11.1 (watcher role), §13.3 (watcher liveness), §6.3 (`OPTIMISTIC` referee), §16.2 (divergence testing). ✔ if the watcher can reproduce roots and, under `OPTIMISTIC`, construct a verifying single-input fraud proof.
3. **Relayer**: from §7.4 (`SourceAdapter`), §10.3/§10.4 (relay of finalized messages), §13.6 (idempotent on `outboxId`). ✔ if "what to post to L1" and "how to deliver a finalized message" are fully specified and permissionless.
4. **Settlement contract (Core + handlers)**: from §6 (`DomainRecord`, profiles, claim policy), §7.0/§7.10 (claim dispatcher and handlers), §8/§9 (data and wire model), §10 (lifecycles), §13.7 (conservation), §13.17 (MUST-fail set), and §18 (governance). ✔ if every accept/reject/revert/halt condition is enumerated and every claim effect is selected by a registered Core-bounded handler.
5. **Chain adapter (read) (`ChainVerifier`)**: from §7.3 (interface + four primitives), §6.4 (foreign-fact profiles), §13.5 (finality/reorg). ✔ if the four primitives and the per-profile obligations are specified; the per-chain finality predicate is a named OPEN PARAMETER, not a gap.
6. **Release adapter (write) (`ReleaseAdapter`)**: from §7.5, §10.3, §13.6, and the mandatory per-chain Interop Enforcement Specification (§18.3). ✔ only if the deployed adapter, proof/non-delivery encodings, timeout boundary, replay/atomicity, custody powers, and upgrade procedure are defined by bytes matching `enforcementSpecHash`. The framework alone is intentionally insufficient to implement a chain adapter.
7. **Asset/messaging layer**: from §7.1, §7.2, §7.6, §10.4, and §13.7. ✔ if peg-in/peg-out/message/timeout/ack are defined with replay keys and class-correct effects. **Qualification:** `MINTED` remains non-deployable until OD-1 is resolved by the MINTED Settlement Extension Specification; foreign timeout remains non-deployable for a chain until its Interop Enforcement Specification defines the proof-of-non-delivery path.
8. **Fee layer**: from §7.8 (`FeeQuote`), §13.8/§13.14 (underfunding, manipulation). ✔ if the three cost centres and the advisory-quote rule are specified and no fee path gates correctness.

**Negative acceptance (normative):** the document is **not** acceptable if any of the following is left to implementer guess: a conservation predicate; replay key; class-output rule; claim-standing check; handler dispatch rule; MUST-fail condition; finality transition; profile proof semantics; legal combination; governance hard bound; or the identity of the controlling foreign enforcement specification. An integrator-chosen value is acceptable only where explicitly tagged OPEN PARAMETER with an owner (§22).

---

## 22. Open issues and deferred items

[FRAMEWORK] Every deliberately unfixed decision, collected. **OPEN PARAMETER** items MUST be chosen before deploying the affected component; **Deferred** items are assigned to a later phase. OPEN PARAMETERS owned by the party standing up a domain are assigned to **Domain Settlement implementers**.

### 22.1 Open parameters (must be chosen per deployment)

| # | Parameter | Owner | Reference |
|---|---|---|---|
| O-1 | `confirmationDepth` (L1 reorg safety) | Domain Settlement implementers | §11.3, §13.5; `EXECUTOR.md` §19 Q-1 |
| O-2 | Per-chain foreign finality predicate (`finalityParams`, `finalityRule`) | Domain Settlement implementers | §6.1, §13.5 |
| O-3 | `MaxBatchInputs`, caps, withdrawal/challenge-window values (within Core bounds) | Administrator (Periphery) | §18.1, §19.3 |
| O-4 | `COMMITTEE` attester set + threshold | Domain Settlement implementers | §6.4 |
| O-5 | `ZK_VALIDITY`/`ZK_CONSENSUS` proving system, curve, `verifyingKeyId`, `publicInputSchema` | Domain Settlement implementers | §6.3, §6.4, §9.2 |
| O-6 | `ZenonProof` object encoding per `ReleaseAdapter` (proof portability) | Domain Settlement implementers | §7.5, §13.4; `BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q2 |
| O-7 | Representation-asset decimals-normalization policy | Domain Settlement implementers | §7.2; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q3 |
| O-8 | Timeout/ack windows per channel (subject to the §14.2 ordering constraint) | Domain Settlement implementers | §7.6, §10.6 |
| O-9 | Fee denomination, reimbursement mechanism, prepaid-fee escrow, fast-exit LP layer | Domain Settlement implementers | §7.8 |
| O-10 | Bond denomination; shared-vs-isolated bond pool across instances | Domain Settlement implementers | §7.7; `BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q4 |
| O-11 | Foreign `ReleaseAdapter`/verifier-contract upgrade governance | Domain Settlement implementers | §13.10, §13.11; `GENERALIZING-TO-OTHER-CHAINS.md` §7 Q5 |
| O-12 | DA retention window relative to challenge window; `DAMode` set | Administrator (Periphery) | §13.3; `EXECUTOR.md` §19 Q-4 |
| O-13 | `ChainId` namespace registry | Framework governance | §8.2 |
| O-14 | Inline-vs-reference `proofData` size threshold per proving system | Domain Settlement implementers | §9.2 |
| O-15 | Cross-instance (read-only) accounting/dashboard model | Framework integrators | §13.13; `BRIDGE-FRAMEWORK-RESEARCH.md` §8 Q3 |

**OPEN DESIGN items** (not just parameter choices; require design work before a value can be chosen):

| # | Design question | Depends on | Reference |
|---|---|---|---|
| OD-1 | MINTED Settlement Extension: exact Core/ZTS issuance authority, registry, atomic claim/burn/release/refund transitions, counter storage/migration, caps, and recovery mechanisms implementing §13.7 | A6, A15, A16, D-7 | §7.2 required companion design, §13.7 |
| OD-2 | `EXTERNAL_OBSERVED` completeness predicate (how to define "all canonical external items" for a given source and how to fraud-prove an omission) | A2, A4 | §6.2 |
| OD-3 | On-chain verifier dispatch interface (`VerifierRegistry` entry format, Core verification call, verifying-key update governance) | A4 or A5 | §8.1 |
| OD-4 | Timeout proof-of-non-delivery path (how a source verifies that a foreign destination did not process a message by the deadline) | A2, A14 | §7.6, §10.4, §21 criterion 7 |

**Deployment dependency note.** Some OPEN PARAMETERs cannot be chosen until prerequisites are resolved. O-8 requires A2 + A14 + OD-4. O-5 requires A5 + OD-3. O-7 requires A6 + OD-1. O-6 and O-11 are controlling fields in the per-chain Interop Enforcement Specification required by A7. An unresolved prerequisite makes its dependent parameter non-actionable.

### 22.2 Deferred items (assigned to a later phase)

| # | Item | Phase | Reference |
|---|---|---|---|
| D-1 | `OPTIMISTIC` execution profile: on-chain fraud referee + dispute/slash game | Phase 2 (A4) | §6.3; `SPEC.md` §30 |
| D-2 | `ZK_VALIDITY` execution profile: validity-verifier registry + honoured `proofData` | Phase 3 (A5) | §6.3; `SPEC.md` §19, §30 |
| D-3 | ZK-friendly SMT hash migration (one-time, versioned) | Phase 3 (A8) | §9.2; `SPEC.md` §13.2 |
| D-4 | On-chain data-availability enforcement | Phase 2 | §13.3; `SPEC.md` §20 |
| D-5 | Inter-batch total message ordering | Phase 2 | §13.12; `SPEC.md` §17.3 |
| D-6 | Multi-member executor sets / `RANDOM_BACKUP` / `STAKE_WEIGHTED` liveness | Post-Phase-1 (A3) | §7.7; `SPEC.md` §22, §30 |
| D-7 | MINTED Settlement Extension Specification and bridge-token issuance authority | Next Settlement-extension design; before A6 activation | §7.2, §13.7, OD-1 |
| D-8 | `L1_RELAYED` / `EXTERNAL_OBSERVED` input-source activation | When A2 lands | §6.2; `SPEC.md` §6.1 |
| D-9 | Migration of the Settlement administrator to a governance/multisig address | When A10 resolves | §18.1; `SPEC.md` §23 |
| D-10 | A fourth input-source class (if ever needed) | Future versioned change | §6.2 |
| D-11 | Settlement `DomainRecord` schema extension (new fields, Core change, spork-gated) | When A12 lands | §6.1 |
| D-12 | `ATTESTATION`-quorum sub-variant (`proofData` quorum attestation via `protocol_version` bump) | When A13 lands | §6.3, §9.2 |
| D-13 | Extended outbox encoding (`Destination`/`Timeout`/`ackPolicy` via `outbox_version` bump) | When A14 lands | §7.1, §7.6, §9.3 |
| D-14 | Authorized-claim wire/schema extension (`claimRoot`, claim proofs, receipts, effect summaries) | When A15 lands | §7.0, §9 |
| D-15 | Settlement claim dispatcher and registered bridge/message handlers | When A16 lands | §7.10, §12.2 |
| D-16 | Per-chain Interop Enforcement Specification and conformant `ReleaseAdapter` | Before activating that chain | §7.5, §18.3, A7 |

### 22.3 Research questions and open designs carried forward (non-normative)

From the research corpus, not yet design-resolved and explicitly surfaced: proof portability across heterogeneous foreign verifiers (O-6); cross-instance accounting (O-15); bond denomination and pooling (O-10); light-client data cost on data-heavy chains (the `EXTERNAL_OBSERVED` tradeoff, §19.2); and verifier-contract upgrade governance without reintroducing a custodian (O-11). These are the open questions of `BRIDGE-FRAMEWORK-RESEARCH.md` §8 and `GENERALIZING-TO-OTHER-CHAINS.md` §7, carried into this specification as named, owned items rather than left implicit.

Additionally, the audit of this document surfaced four **OPEN DESIGN** items (OD-1 through OD-4) that require mechanism design rather than a chosen value. The highest-priority next normative artifact is the **MINTED Settlement Extension Specification** resolving OD-1; until it exists, `MINTED` is a specified capability boundary and invariant, not an activatable feature.

---

## Appendix A: Glossary

| Term | Meaning |
|---|---|
| **`ackPolicy`** | Whether/when a message requests an acknowledgement back to its source: `NONE` / `ON_DELIVERY` / `ON_EXECUTION` (§7.6). |
| **`AssetID`** | 32-byte canonical ZTS encoding per `SPEC.md` §18.1, bytes `[0:22]` zero, bytes `[22:32]` the ZTS identifier. Applies to both `ESCROW` and `MINTED` assets; a `MINTED` representation token is a ZTS issued on L1 (§7.2). |
| **`AssetFlowSummary`** | Per-batch, per-asset deposit-credit/withdrawal-debit summary reconciled on submit (`SPEC.md` §27.6). |
| **`AuthorizedClaim`** | Canonical, policy-scoped assertion emitted by a finalized Authorization Domain and admitted into Settlement only through `RelayClaim` (§7.0). |
| **Batch** | A contiguous slice of a domain's canonical input subsequence (`≤ MaxBatchInputs`) summarized by one commitment (§10.1). |
| **`BridgeLedger`** | Settlement-owned, chain-neutral handlers for claim effects, custody, conservation, and peg authorization; never run inside an Authorization plugin (§7.10). |
| **`ChainBinding`** | The foreign-chain binding in a `DomainRecord`, including verifier, anchor, adapter, finality rules, and `enforcementSpecHash` (§6.1). |
| **`ChainId`** | Canonical foreign-chain identifier: `namespace:u16 ‖ reference:bytes30` (§8.2). |
| **`ChainVerifier`** | Per-chain read seam verifying foreign headers/finality/inclusion inside the STF; implements the foreign-fact profile (§7.3). |
| **Challenge window** | The `OPTIMISTIC` interval during which a watcher may submit a fraud proof (§10.2). |
| **Conservation invariant** | The per-`(domain, asset)` custody-solvency predicate Settlement enforces after every mutation (§13.7). |
| **`confirmationDepth`** | How far below the L1 frontier the executor consumes inputs; reorg-safety parameter (OPEN PARAMETER, §11.3). |
| **Custody mode** | `ESCROW` (real ZTS in custody) or `MINTED` (ZTS representation token backed by attested foreign collateral; significant Settlement upgrade, A6) (§7.2). |
| **`DAHash` / `DAMode`** | The content-address of a batch's data bundle and its availability mode (best-effort in the base profile) (`SPEC.md` §20). |
| **`ClaimPolicy`** | Versioned registry of the claim schemas, handlers, assets, caps, and finality rules an Authorization Domain is permitted to present (§6.1). |
| **Domain** | The unit Settlement anchors: class + runtime + STF + input source + profiles + executor set + lineage, plus policy/foreign binding for Authorization Domains (§4). |
| **`DomainPlugin`** | The four-method plugin (`Genesis`/`DecodeInput`/`Apply`, optional `Source`) that is the only code written to add a domain (§12.1). |
| **`domainClass`** | `EXECUTION` or `AUTHORIZATION`; asset/message are claim-policy purposes, not domain classes (§6.1). |
| **Execution profile** | How a batch's STF correctness is secured: `ATTESTATION` / `OPTIMISTIC` / `ZK_VALIDITY` (§6.3). |
| **`EXTERNAL_OBSERVED`** | Input source where the executor reads observations directly, committing them; weaker, non-L1 DA (§6.2). |
| **Foreign-fact profile** | How a foreign event's truth is established: `NONE` / `COMMITTEE` / `LIGHT_CLIENT` / `ZK_CONSENSUS` (§6.4). |
| **`FeeQuote`** | Advisory quote spanning source inclusion, off-chain execution, and destination delivery (§7.8). |
| **Finality (batch)** | The point releases may be authorized: delay elapsed / challenge window clear / validity proof verified (§10.2). |
| **Input source** | `L1_NATIVE` / `L1_RELAYED` / `EXTERNAL_OBSERVED`: where inputs originate and from where order/DA/censorship derive (§6.2). |
| **Interop Enforcement Specification** | Mandatory chain-specific document whose hash is pinned in `ChainBinding` and which controls adapter verification, custody, replay, timeout, atomicity, and upgrades (§18.3). |
| **`kind` (outbox)** | `0` = cross-domain/cross-chain delivery; `1` = asset withdrawal/peg-out authorization (`SPEC.md` §17.2). |
| **`L1_NATIVE` / `L1_RELAYED`** | Inputs as Settlement account-blocks (native) or external data posted as account-blocks (relayed), both L1-ordered (§6.2). |
| **`messageId` / `outboxId`** | `SHA3-256(domainId ‖ batchId ‖ inputIndex ‖ outboxIndex)`; the replay and delivery idempotency key (§8.2). |
| **`MaxBatchInputs` / `MaxBatchWithdrawal`** | Per-batch input-count cap (64) and per-`(domain,asset)` withdrawal cap sizing the bond (`SPEC.md` §25, §22). |
| **Peg-in / peg-out** | Asset movement foreign→Zenon (lock then credit/mint) / Zenon→foreign (burn/debit then authorize release) (§4). |
| **`PegOutAuthorization`** | Burn-bound, binding-pinned, deadline-bearing object a foreign `ReleaseAdapter` consumes (§7.5). |
| **`proofData`** | The (Phase 1-empty) commitment field that, generalized, carries the quorum attestation (A13) or validity proof (A5) per profile (§9.2). |
| **`proposerPolicy`** | `SINGLE` / `RANDOM_BACKUP` / `STAKE_WEIGHTED`: objective entitled-proposer selection (§7.7). |
| **Recovery anchor** | The most recent finalized `postStateRoot` + `lastInputSeq` an executor reconciles against at startup (§11.3). |
| **Relayer** | Permissionless, trustless role posting foreign data to L1 and carrying finalized messages; can only withhold, never forge (§7.4). |
| **`ReleaseAdapter`** | Per-chain write seam on the foreign chain consuming a finalized Zenon peg-out authorization (§7.5). |
| **Settlement (Core / Periphery)** | The node-binary, spork-gated core vs the administrator-tunable, Core-clamped periphery (§4; `SPEC.md` §5). |
| **`SettlementClient`** | The runtime's interface to Settlement (submit/relay/challenge + L1-state-proof reads) (§12.2). |
| **`SourceAdapter`** | Per-chain relay seam deciding what foreign data to post to L1 (§7.4). |
| **STF** | The pure, deterministic state-transition function `Apply` a plugin implements (§4). |
| **`stfSpecHash`** | The semantic pin for runtime, VM, genesis, wire formats, profiles, claim policy, and the full `ChainBinding` (§20.2). |
| **Four safety rails** | Execution correctness, foreign-fact correctness, data availability, and claim standing/accounting are independent checks (§2.1). |
| **`Timeout`** | A message's destination-evaluated deadline enabling a refund path on non-delivery (§7.6). |
| **Watcher** | The executor binary in compare mode; reproduces roots, surfaces divergence, emits fraud proofs under `OPTIMISTIC` (§7.4). |

---

## Appendix B: Worked examples

Each example is an end-to-end trace against the mechanisms above. Notation: `d` = domainId, `a` = asset. State counters are those of §13.7.

### B.1 Foreign message admission and acknowledgement

`d_c_msg` is an `AUTHORIZATION` domain with `claimPolicy.purpose=MESSAGE`, `inputSource=L1_RELAYED`, `execProfile=ATTESTATION`, and `foreignProfile=LIGHT_CLIENT`.

1. Chain C finalizes application event `E`. A relayer posts its header and inclusion proof; `ChainVerifier` verifies C's consensus, inclusion, and finality.
2. `Apply` updates only verifier state and emits `FOREIGN_MESSAGE{ForeignEventID=E.id, subject=registeredTarget, payloadHash=H(P)}`. It does not call the target or write its state.
3. The batch commits the claim in `claimRoot` and finalizes. `RelayClaim` then checks inclusion, policy standing, both replay keys, and the message handler cap before dispatching to the registered Zenon target.
4. If the target emits an acknowledgement, that acknowledgement enters an Execution Domain outbox and is delivered to C by C's pinned message endpoint. Losing the acknowledgement does not undo the already-dispatched message.

No custody counter changes. Stronger evidence for `E` would not widen the targets or schemas authorized by the active claim policy.

### B.2 ETH lock, zETH mint, burn, and release

`d_eth_asset` is an `AUTHORIZATION` domain with `claimPolicy.purpose=ASSET`, `execProfile=OPTIMISTIC`, and `foreignProfile=LIGHT_CLIENT`. `zETH` is `MINTED` and bound to the ETH custody contract named by the pinned Interop Enforcement Specification.

1. The user locks `1 ETH`. A relayer posts the finalized receipt proof. `ChainVerifier` verifies FFG finality and inclusion; `Apply` emits a `FOREIGN_LOCK` claim and changes no balance.
2. After the Authorization batch finalizes, `RelayClaim` checks standing, `claimId`, `(d_eth_asset, ForeignEventID)`, cap, and conservation. The registered Settlement handler atomically sets `verifiedLockedCollateral += 1 ETH`, `representationOutstanding += 1 ETH`, and credits `1 zETH`.
3. The user redeems `1 zETH` through the registered Settlement path. Settlement atomically burns it, changes `representationOutstanding -= 1 ETH` and `pendingForeignRelease += 1 ETH`, and records a burn-bound `PegOutAuthorization` containing `chainBindingHash` and deadline `H`.
4. Before `H`, the Ethereum `ReleaseAdapter` verifies the finalized Zenon proof and binding, checks replay, releases exactly `1 ETH`, and records `outboxId` atomically.
5. A finalized release receipt returns through `d_eth_asset` as a `FOREIGN_RELEASE` claim. Dispatch changes `pendingForeignRelease -= 1 ETH` and `verifiedLockedCollateral -= 1 ETH`. All three counters return to zero.

### B.3 BTC peg round trip with a BitVM release path

`d_btc_asset` has the same responsibility split as B.2, but its `ChainVerifier` checks proof of work, difficulty transitions, Merkle inclusion, and `K` confirmations.

1. A finalized `0.5 BTC` custody output produces a `FOREIGN_LOCK` claim. Only finalized `RelayClaim` dispatch mints `0.5 zBTC`; the Authorization Domain never mints.
2. A local finalized redeem burns `0.5 zBTC`, moves that amount from `representationOutstanding` to `pendingForeignRelease`, and creates the binding-pinned authorization.
3. The BitVM release graph enforces the authorization according to the BTC Interop Enforcement Specification. A later finalized spend proof becomes `FOREIGN_RELEASE` and reconciles the two current-value counters.
4. An unauthorized custody spend may become `FOREIGN_MISCONDUCT`; dispatch opens only the registered pause/slash path. The claim itself cannot select arbitrary slashing or Settlement code.

### B.4 Failed release, retry, and duplicate

Use the ETH authorization from B.2. The first destination transaction runs out of gas.

1. The adapter call reverts atomically: no ETH moves and `outboxId` is not recorded. Zenon remains at `pendingForeignRelease=1 ETH`.
2. Any relayer retries the same proof before deadline `H`. The second call releases and records the key atomically.
3. A third call with the same `outboxId` is rejected. The release receipt is admitted once by the Authorization Domain and dispatched once by Settlement, so foreign replay and Zenon claim replay are independently tested.

### B.5 Timeout and refund

Use B.2, but no release succeeds before destination height `H`.

1. The adapter rejects every release at or after `H`; the deadline is part of the signed/proved authorization, not relayer metadata.
2. At a finalized destination state at or after `H`, a proof shows `outboxId` absent from the adapter's processed set. `d_eth_asset` verifies it and emits `FOREIGN_NON_DELIVERY`.
3. After that claim's batch finalizes, dispatch consumes the timeout path and atomically changes `pendingForeignRelease -= 1 ETH`, `representationOutstanding += 1 ETH`, reminting `1 zETH` to the recorded refund recipient. Collateral remains locked.
4. A late destination release is rejected by the adapter's deadline check. A duplicate refund is rejected by claim and foreign-event replay. Delivery and refund therefore exclude each other without assuming that a Zenon replay set is visible on Ethereum.

### B.6 Committee foreign-fact profile

`d_cmte` is `AUTHORIZATION/ASSET` with `execProfile=ATTESTATION` and `foreignProfile=COMMITTEE{set, threshold=t}`.

1. At least `t` members attest to a foreign lock; `ChainVerifier` verifies the threshold statement and `Apply` emits `FOREIGN_LOCK`.
2. Batch finality establishes only that the attested claim was emitted. Settlement still checks policy, replay, cap, handler, and conservation at dispatch.
3. Trust is the weaker of the execution attestation and foreign committee assumptions. Migrating to `LIGHT_CLIENT` changes `stfSpecHash` but neither claim capability nor Settlement accounting.

### B.7 Light-client foreign-fact profile

`d_lc` is `AUTHORIZATION/ASSET` with `execProfile=OPTIMISTIC` and `foreignProfile=LIGHT_CLIENT`.

1. Relayed headers advance only through the pinned consensus transition; no live RPC read is consensus input.
2. A dishonest relayer can withhold data but cannot make an invalid header or event pass the verifier. A dishonest executor can still emit a claim inconsistent with verified state until the optimistic challenge assumption catches it.
3. Once the batch finalizes, the same Settlement checks and handlers as B.6 apply. Cryptographic foreign verification does not grant broader claim standing.

### B.8 ZK-validity execution profile

`d_zk` is `AUTHORIZATION/ASSET` with `execProfile=ZK_VALIDITY` and `foreignProfile=LIGHT_CLIENT`.

1. The proposer proves the Authorization STF transition, including verifier-state update and exact `claimRoot`, under the registered public-input schema.
2. An invalid proof is rejected at submit; a valid batch may finalize without an optimistic challenge window.
3. `RelayClaim` still enforces active policy, replay, budget, caps, handler identity, and conservation. Stronger execution verification changes confidence in the claim computation, not what Settlement is willing to hear.

### B.9 EVM source to SVM destination message

Two directional components compose without sharing verifier code.

1. `d_eth_msg` verifies a finalized Ethereum event and emits `FOREIGN_MESSAGE`. Settlement dispatches it to a registered Zenon routing contract.
2. The routing contract executes in an `EXECUTION` domain and emits an outbound message committed in `outboxRoot` for Solana.
3. The Solana message program verifies the finalized Zenon proof in its SVM-native encoding, checks deadline and replay, and executes once.

Ethereum FFG verification remains inside `d_eth_msg`; Solana enforcement remains inside the SVM program. Settlement is the only junction, and no EVM assumption leaks into the SVM side.

### B.10 BTC source to EVM destination asset through an explicit swap

Cross-chain asset routing composes two independent bridge ledgers; it does not pretend one custody pool backs another.

1. A BTC lock is admitted through `d_btc_asset`, and dispatch mints `zBTC` as in B.3. The BTC ledger now has matching outstanding representation and locked collateral.
2. The user swaps `zBTC` for `zWBTC-ETH` through an ordinary Zenon liquidity venue. The LP now owns the `zBTC`; no bridge counter changes merely because ownership changed.
3. `zWBTC-ETH` is separately backed by WBTC locked under `d_eth_wbtc`. Burning it creates an Ethereum-bound authorization and moves only the ETH-domain counters from outstanding representation to pending release.
4. The Ethereum adapter releases WBTC and the later `FOREIGN_RELEASE` claim reconciles only `d_eth_wbtc`. The BTC collateral remains backing the `zBTC` now held by the LP.

The route succeeds through an explicit market exchange between two conserved representations. There is no cross-domain netting and no claim from one domain can spend the other's custody.

---

## Appendix C: Comparative mappings (SECONDARY design references)

> **Status: SECONDARY and non-controlling.** The systems below are mature designs cited to locate this framework in the design space and to borrow vocabulary where it clarifies. **None of them governs any requirement in this document; the Project Zenon primary corpus governs (§0.3).** Where a system's choice differs from the framework's, the difference is noted, not resolved in the external system's favour. Mappings are into the framework's two-ladder model: the **execution ladder** (`ATTESTATION`/`OPTIMISTIC`/`ZK_VALIDITY`, securing batch computation) and the **foreign-fact ladder** (`COMMITTEE`/`LIGHT_CLIENT`/`ZK_CONSENSUS`, securing external truth).

### C.1 IBC (Inter-Blockchain Communication)

IBC verifies the counterparty chain with an on-chain **light client** and moves packets by proving commitment inclusion under a verified header, with explicit `recvPacket` / `acknowledgePacket` / `timeoutPacket` semantics and ordered/unordered channels. Mapping: IBC sits at **foreign-fact `LIGHT_CLIENT`** with no separate execution ladder (each chain executes its own STF natively). The framework's timeout/ack model (§7.6, §10.4) is most directly modelled on IBC's packet lifecycle, re-expressed against batch finality and `outboxId` replay rather than IBC's channel/sequence model. **Difference:** IBC assumes both endpoints run light clients of each other; the framework keeps execution off-chain under its own execution ladder and verifies the foreign side inside the STF, so only the foreign→Zenon direction needs a `ChainVerifier` and the Zenon→foreign direction needs a `ReleaseAdapter` (asymmetric seams, §5.3).

### C.2 Hyperlane

Hyperlane is permissionless interchain messaging with a modular **Interchain Security Module (ISM)** the application chooses (multisig, optimistic, or others), plus relayers and watchers. Mapping: the ISM is a per-application security-profile selector, closely analogous to the framework's per-domain profile pair; a Hyperlane multisig ISM ≈ **foreign-fact `COMMITTEE`**, an optimistic ISM ≈ an **`OPTIMISTIC`-style** challenge layer. The framework's relayer/watcher roles (§7.4) match Hyperlane's. **Difference:** the framework separates the *execution* ladder (computation correctness) from the *foreign-fact* ladder (external truth) as two orthogonal dimensions (§6.3/§6.4), whereas the ISM bundles "is this message valid" into one configurable module; and the framework adds a conservation-bounded custody layer (§13.7) that pure-messaging Hyperlane does not center.

### C.3 LayerZero V2

LayerZero V2 decomposes verification into configurable **DVNs (Decentralized Verifier Networks)** plus an executor, with the application choosing its DVN set and thresholds (X-of-Y-of-N). Mapping: a multi-DVN configuration is a **foreign-fact `COMMITTEE`** with an explicit threshold (worked example B.6); the LayerZero executor maps to the framework's relayer-delivery role (§7.4). **Difference:** the framework's foreign-fact ladder treats a committee as the *weakest* rung and provides a documented additive migration to `LIGHT_CLIENT`/`ZK_CONSENSUS` (§6.6); and again the orthogonal execution ladder secures the *computation*, a concern outside LayerZero's messaging-verification scope. The framework's "trust = weaker of the two ladders" honesty rule (§2.1) is intentionally sharper than a configurable-trust framing.

### C.4 Wormhole

Wormhole's baseline security is a **guardian set** that observes and signs cross-chain messages (VAAs), i.e. an attestation/committee model, with later additions exploring on-chain light-client and zk verification paths. Mapping: classic Wormhole guardians ≈ **foreign-fact `COMMITTEE`**; its zk-light-client direction ≈ movement toward **`LIGHT_CLIENT`/`ZK_CONSENSUS`**. **Difference:** the framework never treats a committee as the terminal security model; the committee is rung 1 of a ladder whose top is cryptographic foreign verification, and the framework's custody safety is conservation-bounded on the Zenon side independent of the foreign-fact rung (§13.7), so a foreign-fact compromise cannot over-release beyond accounted inflow.

### C.5 Chainlink CCIP

CCIP layers a separate **Risk Management Network** atop its committee-based message verification, adding an independent anomaly-detection/secondary-attestation layer. Mapping: CCIP's primary committee ≈ **foreign-fact `COMMITTEE`**; the Risk Management Network is an independent watcher/circuit-breaker layer analogous in spirit to the framework's watcher role (§7.4) plus the Settlement pause authority and Core hard bounds (§18.1). **Difference:** the framework's "circuit breaker" is structural and on-chain (conservation invariants, `MaxBatchWithdrawal` caps, time-locked governance, halt-on-corruption) rather than a separate attesting network; safety does not depend on a second committee being honest.

### C.6 Axelar

Axelar is a proof-of-stake **validator-set** network that runs light-client-style verification of connected chains and routes general message passing, with validators staking and subject to slashing. Mapping: Axelar's validator set ≈ a **`COMMITTEE`** that performs **`LIGHT_CLIENT`-style** verification, with bonding/slashing analogous to the framework's executor bond and fraud-slash (§7.7, §6.3 `OPTIMISTIC`). **Difference:** Axelar is itself a consensus zone in the path; the framework keeps Zenon L1 as the single ordering/finality source and runs verification *inside the STF* of an off-chain executor bonded to Settlement, rather than introducing an intermediary chain (§5.1). The framework's execution-correctness guarantee comes from its own execution ladder, not from the verifier network's consensus.

### C.7 Polkadot XCM / XCMP

XCM is a **message format** and XCMP the transport; security derives from **shared validator security** within a relay chain (parachains trust the shared validator set and the relay chain's finality), not from per-pair bridges. Mapping: XCM's format/transport split maps to the framework's `Message`/`Destination` (§7.1) plus relay delivery (§7.4); shared-security trust ≈ a strong, homogeneous **`LIGHT_CLIENT`-equivalent** guaranteed by the shared relay chain. **Difference:** the framework is explicitly *heterogeneous* and trust-minimizing across chains it does not control (BTC, ETH, SOL), so it cannot assume shared security and instead pins a per-chain `ChainVerifier` and a per-chain finality predicate (O-2); it borrows XCM's clean format/transport separation but not its shared-security assumption.

### C.8 zkBridge

zkBridge verifies the source chain's consensus with a **succinct (zk) proof** consumed by an on-chain verifier on the destination, achieving cryptographic cross-chain verification without a trusted committee. Mapping: zkBridge is the canonical **foreign-fact `ZK_CONSENSUS`** instantiation (the `VerifyConsensusProof` primitive, §7.3) and, where it also proves state transitions, informs the **`ZK_VALIDITY`** execution rung (§6.3). **Difference:** the framework treats zk verification as the *top* of each ladder reached by additive migration from cheaper rungs (§6.6), not as the only mode; it keeps the proving system, curve, and statement schema as OPEN PARAMETERs (O-5) and pins only the *extension points* a proof plugs into, so a specific zkBridge construction is one valid realization of the `ZK_CONSENSUS` slot rather than a baked-in dependency.

### C.9 Summary mapping

| System | Foreign-fact rung (mapped) | Execution ladder analogue | What the framework borrows | Where it differs |
|---|---|---|---|---|
| IBC | `LIGHT_CLIENT` | native per-chain | timeout/ack packet lifecycle | asymmetric off-chain execution + seams |
| Hyperlane | `COMMITTEE` (modular ISM) | optional optimistic ISM | relayer/watcher roles, modular profiles | two orthogonal ladders + custody conservation |
| LayerZero V2 | `COMMITTEE` (DVNs) | out of scope | threshold committee, executor delivery | additive migration to cryptographic rungs |
| Wormhole | `COMMITTEE` (guardians) | out of scope | attestation model as rung 1 | conservation-bounded custody, ladder top = zk |
| CCIP | `COMMITTEE` + risk net | out of scope | independent watcher/circuit-breaker idea | structural on-chain breakers, no second committee |
| Axelar | `COMMITTEE`+`LIGHT_CLIENT` | bonded/slashed | bond + slashing, light-client verification | no intermediary chain; single L1 ordering source |
| Polkadot XCM | shared-security `LIGHT_CLIENT` | shared validators | format/transport separation | heterogeneous, per-chain verifier, no shared security |
| zkBridge | `ZK_CONSENSUS` | informs `ZK_VALIDITY` | the succinct-proof rung itself | proof system kept as an extension point, not baked in |

> The throughline: every external system occupies one or two points the framework expresses as **rungs on two orthogonal ladders**, and the framework's contribution is not a new verification primitive but the **separation** of execution-correctness from foreign-truth, the **shared conservation-bounded custody** beneath both, and a **documented additive migration** from the cheapest rungs (bonded attestation + committee) to the strongest (validity proof + zk-consensus), written once and inherited by every bridged chain (§2.5, §6.6, G1).

---

## Document end

This specification generalizes the Project Zenon Phase-1 off-chain-execution corpus into an Authorization and Bridge Framework while preserving every active Phase-1 rule. It is normative where tagged with RFC 2119 keywords, informative in its rationale, and explicit about undeployable assumptions, open designs, deployment artifacts, and parameters (§22). The controlling authority remains `SPEC.md` v1.3.0; on conflict, the on-chain protocol governs and the corresponding [FRAMEWORK] statement is void for that case (§0.3).

**Governing invariant, restated verbatim:** Consensus orders. Execution computes. Authorization admits. Settlement accounts.

**External enforcement boundary:** Destination chains enforce through the `ReleaseAdapter` defined by their pinned Interop Enforcement Specification. This is not a fifth Zenon-side responsibility and is not part of the canonical invariant.
