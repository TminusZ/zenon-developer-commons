**Status:** Frontier boundary document
**Phase status:** Mixed; best-effort Sentinel/libp2p DA serving is named, while Sentinel service markets, bonds, slashing, and custody roles are not specified
**Purpose:** Define the boundary between Sentinel architectural fit, best-effort support, protocol assignment, and future service-market speculation
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Sentinel Service Boundary

## 1. Why this document exists

Every previous Frontier document has touched the Sentinel question and consistently deferred resolution to this document.

`01_RELAYER_BOUNDARY.md` describes Sentinels as plausible relayer operators under a future `L1_RELAYED` profile, with the explicit caveat that no spec assigns the role. `02_DOMAIN_VERIFICATION_LIMITS.md` notes that a Sentinel may run a watcher binary but no protocol watcher market is defined. `03_RELAYER_TRUST_MODELS.md` classifies Sentinel relay participation as architectural fit under Models A or B (permissionless or designated proof relay), not as a special protocol role. `07_DA_AND_PROOF_SERVING_BOUNDARY.md` describes Sentinel/libp2p DA serving as best-effort support infrastructure, not as protocol-enforced availability. `09_CUSTODY_BOUNDARY.md` is explicit that no current spec assigns Sentinels custody authority and no current spec assigns QSR as a custody or service bond.

This document consolidates the boundary. It does not propose new Sentinel roles. It does not design a service market. It does not assume the Sentinel ecosystem will or will not evolve in any particular direction. It defines what is grounded in the spec, what is plausible as architectural fit, and what would need to be specified before any service-market claim can be made.

Sentinels are infrastructure-shaped. They have connectivity, uptime expectations, and existing service responsibilities in the broader Zenon ecosystem. That shape makes several future service roles operationally plausible. But operational plausibility is not protocol assignment. Historical Sentinel design hints in the broader Zenon ecosystem are not current Project Zeno spec obligations. QSR's role in other Zenon contexts is not, by itself, a service collateral assignment for Project Zeno. Plausible business models for Sentinel operators are not protocol facts.

Sentinel suitability is not Sentinel assignment.

The inventory rows that feed this document include: #18 (DA bundle serving), #20 (watcher role), #21 (browser-native verification floor), #24 (Sentinel as relayer, speculative), #25 (Sentinel as watcher, speculative), #38 (proof server, speculative service role), and the negative custody boundary established in `09_CUSTODY_BOUNDARY.md`.

## 2. What the spec actually assigns

The grounded Phase 1 Sentinel role is best-effort DA support. This is the only role with current spec grounding, and the framing matters.

SPEC §3 names Sentinels as part of the off-chain layer alongside libp2p and the WASM executor: "Sentinels / libp2p: SHOULD serve bundles and chunks addressed by `DAHash` best-effort (§20); not consensus-critical in Phase 1." SPEC §20 confirms this in the DA section: Phase 1 DA is commitment-only; Settlement records `DAHash` and `DAMode` per batch and must not verify on-chain that the bundle is available. `DAMode = 0` is best-effort publication via Sentinel/libp2p, content-addressed by `DAHash`.

What this grounded assignment does and does not include:

It supports DA retrieval by clients, watchers, and verifiers who need to access bundles. It is not consensus-critical: the Zenon L1 consensus operates without depending on Sentinel availability. It is not on-chain enforced: Settlement does not check whether any specific Sentinel served any specific bundle. It is not a paid market: no protocol-level payment flows to Sentinels for DA serving in Phase 1. It has no specified slashing: a Sentinel that stops serving incurs no protocol penalty. It has no specified QSR bond: no Sentinel asset is staked, locked, or otherwise bonded against DA serving obligations in the current spec. It has no specified custody role: Sentinels do not hold any Project Zeno assets in any specified capacity.

The grounded Phase 1 Sentinel role is best-effort DA support, not enforced service provision.

## 3. Best-effort support vs protocol enforcement

These two concepts must be kept apart because the difference is the difference between a service hint and a service market.

**Best-effort support.** Nodes may serve data. Clients may retrieve data. Availability improves if nodes participate. Service failure may reduce replayability or convenience but produces no on-chain consequence. The role is operational, not normative. No protocol mechanism checks success or punishes failure. Participation is voluntary, ungoverned, and unpaid by the protocol.

**Protocol enforcement.** The protocol checks whether the service was delivered. Failure can trigger rejection, delay, slashing, or other protocol-level consequences. The role has explicit registration and obligations defined in the spec. Service has measurable success and failure conditions. Economic security is defined: bonds, slashing rules, reward sources, dispute mechanisms.

Phase 1 Sentinel DA serving is best-effort support. The spec uses "SHOULD," not "MUST." There is no enforcement mechanism, no measurable success condition tracked by Settlement, and no economic consequence for non-participation.

Best-effort serving helps availability; it does not guarantee availability.

This is not a defect. Phase 1 is designed around this property: SPEC §20 explicitly states that Phase 1 DA is commitment-only, with enforcement deferred. The Sentinel role matches the phase. Mismatching them (treating best-effort serving as enforcement, or treating enforcement as merely best-effort) is the overclaim risk this document addresses.

## 4. Plausible Sentinel service roles

| Role | Why Sentinels fit | Spec status | Boundary |
|---|---|---|---|
| DA server | Connectivity, storage, chunk-serving infrastructure | Best-effort support named (SPEC §3, §20) | No Phase 1 enforcement, no slashing, no paid market |
| Proof server | Could serve SMT inclusion proofs, outbox proofs, receipt proofs | Speculative; no spec assignment | No assigned proof-server market; proof validity is deterministic |
| Relayer | Could submit proof-shaped external data for future `L1_RELAYED` domains | Speculative; permissionless model is role-agnostic | No official relayer role; STF verification is what matters |
| Watcher | Could replay execution and alarm on divergence | Speculative or optional | Phase 1 watchers are alarm-only; no on-chain enforcement |
| Browser verification backend | Could serve proofs and bundles to lightweight clients | Speculative | Client convenience, not protocol safety |
| Oracle observer | Could observe external data under future `EXTERNAL_OBSERVED` domains | Speculative; `EXTERNAL_OBSERVED` is reserved | External truth assumptions remain regardless of observer identity |
| Custody signer | Could theoretically participate in a threshold-signing set | Not specified | Custody authority is not assigned by spec |

This is a classification, not a roadmap. The "Why Sentinels fit" column describes architectural plausibility. The "Spec status" column describes what the current spec actually says. The "Boundary" column states the limit on any claim about the role.

Plausible role fit is a research classification, not an implementation claim.

## 5. Sentinel as DA server

This is the one role with Phase 1 grounding.

Sentinel and libp2p infrastructure can help distribute DA bundles and chunks addressed by `DAHash`. Clients, watchers, and verifiers retrieve bundles from this serving layer to perform replay, fraud-proof construction (in future phases), or browser verification.

The boundary is precise:

`DAHash` is a commitment, not an availability proof (see `07_DA_AND_PROOF_SERVING_BOUNDARY.md`). Phase 1 DA is best-effort. If Sentinels stop serving, watchers may be unable to replay, and the alarm-only Phase 1 watcher role becomes ineffective. No Phase 1 slashing or penalty exists for non-participation in DA serving. No paid DA market is specified. The retention period for served bundles is not fully specified in SPEC; EXECUTOR_DRAFT.md §14 requires the executor to retain pre-finalization bundles, but the post-finalization Sentinel retention floor is unspecified.

Sentinel DA serving supports replayability only when the data is actually served.

The asymmetry to keep visible: serving improves availability, non-serving reduces it, and Phase 1 has no mechanism to make either a protocol-level event. The system depends on voluntary participation for the data layer that watchers, fraud proofs (Phase 2), and browser replay all rely on.

## 6. Sentinel as proof server

Sentinels could plausibly serve inclusion proofs against committed Settlement roots: SMT inclusion proofs for state queries, SMT non-inclusion proofs for absence verification, outbox inclusion proofs for cross-domain relay (see `08_CROSS_DOMAIN_RELAY_PROOFS.md`), receipt proofs for execution outcome verification, and proof material for browser clients implementing inclusion-proof verification (Level 1 of the `07_DA_AND_PROOF_SERVING_BOUNDARY.md` taxonomy).

The boundary:

Proof-server role is not assigned to Sentinels by the spec. The proof-server API is not specified at the protocol level. Invalid proofs are rejected by deterministic verification at the consuming verifier; protocol-level honesty enforcement is not required for proof-server safety. Proof-server liveness affects client convenience and relay construction, but Settlement safety does not depend on any specific proof server. Proof serving is not execution verification: a proof server serves inclusion paths against existing committed roots; it does not verify that the committed roots are correct (which is a Phase 1 bonded-attestation question, addressed by Phase 2 fraud proofs or Phase 3 validity proofs).

A Sentinel proof server would serve evidence against roots; it would not create the roots' correctness.

## 7. Sentinel as relayer

Sentinels are plausible relayer operators for future `L1_RELAYED` domains because they are existing online infrastructure nodes with connectivity, uptime, and content-serving experience.

If `L1_RELAYED` is activated under a future profile, Sentinels could submit Bitcoin block headers and SPV inclusion proofs for a Bitcoin SPV domain (EXECUTOR_DRAFT.md §12 worked example), Ethereum proof payloads if a machine-verifiable Ethereum proof path is specified, or other proof-shaped external inputs that the relevant STF can verify.

The boundary:

`L1_RELAYED` is reserved under the Phase 1 profile (SPEC §6.1). No domain currently uses it. Relayer role is not assigned to Sentinels; relay is permissionless and role-agnostic. Relayer validity trust depends on STF verification of the submitted proof, not on the identity of the submitting party (see `03_RELAYER_TRUST_MODELS.md` Model A). Relayer liveness depends on someone submitting the data, which permissionless relay improves (any participant can submit) but does not guarantee. No Sentinel relay market is specified: no protocol-level fees, bonds, or service obligations exist.

Sentinel identity does not make relayed data valid; STF verification does.

A Sentinel submitting an invalid Bitcoin SPV proof produces data that the Bitcoin SPV domain STF rejects, the same way any other party's invalid proof would be rejected. The Sentinel's identity carries no special weight in the validity calculation. This is by design: in a permissionless relay model, validity sits with the proof and the STF, not with the relayer.

## 8. Sentinel as watcher

Sentinels are plausible watchers because they can run replay infrastructure: download DA bundles, execute the WASM runtime against committed inputs, recompute roots, and raise alarms on divergence.

The boundary:

Phase 1 watchers are alarm-only with no on-chain enforcement channel (see `02_DOMAIN_VERIFICATION_LIMITS.md`). Watching requires the DA bundle, runtime, witnesses, and `stfSpecHash`; a watcher without these inputs cannot replay. Watching cannot slash or revert in Phase 1. The watcher role is not assigned exclusively to Sentinels; any party with the data and runtime can watch. Phase 2 fraud-proof emission is deferred and is explicitly out of scope for Phase 1 watchers (EXECUTOR_DRAFT.md §5.8 forbids a Phase 1 watcher from building the fraud-proof emitter).

Watching is replay, not authority.

A Sentinel that runs a watcher binary detects divergence the same way any other watcher does. The detection has the same alarm-only consequence in Phase 1. The Sentinel does not gain enforcement authority by virtue of running watcher software. This matters because user-facing material sometimes implies "Sentinels watch the network," which can be heard as "Sentinels enforce correctness," which is not true in Phase 1.

## 9. Sentinel as oracle observer

Sentinels could theoretically observe external feeds (price oracles, RPC endpoints, web services) under a future `EXTERNAL_OBSERVED` domain.

The boundary:

`EXTERNAL_OBSERVED` is reserved under the Phase 1 profile (SPEC §6.1). Observed data is not proof-shaped by default (see `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`). Sentinel observation does not make external truth verified: a Sentinel reading a price feed produces an observation that the domain can replay deterministically, but the domain cannot independently verify that the observed value was correct. Committee observation by Sentinels would introduce social and economic trust (see `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md` Section 11), not cryptographic verification. No Sentinel oracle role is specified by the current spec. No oracle market is specified.

Sentinel observation is still observation unless it carries a proof the STF verifies.

If a Sentinel-style committee attested to an external value via threshold signature, the STF could verify the signature's validity (committee signed the statement). It still could not verify that the underlying external claim was true. The trust model would be committee trust, not proof-shaped verification.

## 10. Sentinel as custodian or signer

This section is the most consequential boundary in this document because the failure mode is real-world asset loss.

No current spec assigns Sentinels custody authority. No current spec makes Sentinels Bitcoin signers, Ethereum signers, bridge custodians, or threshold-signature participants. This is true regardless of whether Sentinel operators have historically participated in any custodial or signing role in adjacent ecosystems.

If a future design proposes Sentinels as signers or custodians, the spec would need to define, at minimum:

Signer selection rules: how Sentinels become eligible, how the active set is chosen, how rotation works. Threshold scheme: which cryptographic scheme governs signing (FROST, BLS, ECDSA-based, Schnorr aggregation, or other), what the threshold is, how it scales with participants. Key-generation protocol: how distributed key generation is performed, how trust is established during setup, how new signers join. Slashing or accountability: what behavior is slashable, how it is detected, what the dispute mechanism is. Bond asset: what economic stake backs custodial behavior; no QSR assignment is currently specified. Signing policy: under what conditions Sentinels are obligated to sign, and what defines refusal. Withdrawal authorization rules: how a withdrawal request becomes an authorized signing operation. Recovery path: what happens when a threshold cannot be reached, when a Sentinel disappears, or when the signing infrastructure fails. Governance gate: which authority activates the custody role and under what process. Disclosure requirements: what users and integrators must be told about the custody model.

None of this is specified. Until it is specified, Sentinel custody must not be claimed.

Custody requires explicit key authority; Sentinel status alone grants none.

The discipline applied in `09_CUSTODY_BOUNDARY.md` Section 7 (Bitcoin withdrawal as a negative boundary) applies here as well: naming possible custody mechanisms is not the same as integrating one, and no part of the Frontier series implies that any specific custody design is intended.

## 11. QSR boundary

QSR is a candidate service collateral thesis in some adjacent Zenon contexts. It is not a Project Zeno service collateral assignment.

The current spec does not assign QSR as: DA bond for Sentinel DA serving, relayer bond for `L1_RELAYED` relay submissions, watcher bond for Phase 1 alarm-only watching, proof-server bond for inclusion proof serving, oracle bond for `EXTERNAL_OBSERVED` observation, custody bond for external-chain asset control, or Sentinel service collateral for any service-market mechanism.

If QSR is proposed later as a service bond, the spec would need to define: the bonded role with specific obligations, the amount or formula for the bond (fixed, proportional to value at risk, or dynamic), the lock duration during which the bond is at risk, the slashing conditions that are objectively measurable, the reward source that compensates honest service providers, the service-level objective that defines successful service delivery, the dispute process for contested slashing or rewards, and the governance activation gate.

None of this exists in the current spec. The asset's name appearing in adjacent ecosystem context is not a specification, and treating it as one is the kind of overclaim this Frontier series exists to prevent.

QSR relevance is a thesis unless the spec assigns it.

## 12. Service market requirements

Before any Sentinel service market can be claimed, the following must exist in the spec:

**Role registration.** A mechanism for nodes to declare themselves as offering a specific service, with verifiable identity and service-specific metadata.

**Service obligations.** Explicit obligations the registered role must fulfill: what data is served, what response time is expected, what availability is required.

**Service discovery.** How clients find available service providers: a registry, a gossip protocol, a discovery layer, or another mechanism.

**Measurement of performance.** How service delivery is observed and recorded. Without measurement, neither rewards nor slashing can be objective.

**Payment or reward flow.** Where the funds come from (user fees, protocol issuance, application-level fees, off-chain agreements) and how they reach service providers.

**Bond or accountability mechanism.** If the service claims economic security, what asset is bonded and how the bond is held.

**Slashing or penalty rules.** What conditions trigger slashing and how the slashing is executed, if enforcement is claimed.

**Client routing or selection rules.** How clients choose among multiple service providers, and what guarantees the selection mechanism provides.

**Failure handling.** What happens when service is not delivered: refunds, fallback paths, dispute mechanisms.

**Governance activation.** Which authority enables the service market and under what process.

**Metadata disclosure.** What information users and integrators see about which services are available, paid, bonded, and slashable.

None of these exist for any Sentinel service in the current Project Zeno spec. The DA serving role is the closest to having any of them, and it has none: the role is named but unregistered, unobligated, unmeasured, unpaid, unbonded, unslashable, and ungoverned.

A service market is a protocol and economic design, not a vibes-based role label.

## 13. Sentinel roles by phase

| Role | Phase 1 status | Phase 2/3 possibility | Claim discipline |
|---|---|---|---|
| DA serving | Best-effort named support (SPEC §3, §20) | Could become enforced with DA enforcement and fraud-proof design | Say "support," not "guarantee" |
| Proof serving | Speculative; not assigned | Could become a service market if proof-server role is specified | Say "plausible," not "assigned" |
| Relaying | Speculative; permissionless model applies | Could support `L1_RELAYED` domains if activated | Say "possible operator," not "official role" |
| Watching | Optional and alarm-only; not assigned exclusively | Could feed Phase 2 fraud proofs if watcher infrastructure matures | Say "watcher fit," not "watcher authority" |
| Oracle observing | Reserved (`EXTERNAL_OBSERVED` is reserved); speculative | Could support observed domains under future profiles | Say "observed trust model remains" |
| Custody signing | Not assigned; not in spec | Possible only with explicit custody design beyond Phase 1 scope | Do not claim |
| QSR bonding | Not assigned for any Sentinel service role | Possible only if specified with full bond mechanics | Do not claim |

## 14. Failure modes

| Failure | Type | Effect | Boundary |
|---|---|---|---|
| Sentinel stops serving DA | Service liveness failure | Watchers may lose replay ability; alarm-only watchers cannot alarm | No Phase 1 slashing or protocol penalty |
| Sentinel serves incomplete or corrupt bundle | Availability or integrity failure | Hash mismatch produces verification failure if data is present; missing chunks cause partial unavailability | `DAHash` detects mismatch deterministically |
| Sentinel proof server offline | Service liveness failure | Client must find another proof source or fetch the DA bundle | Not protocol safety; client convenience |
| Sentinel serves invalid proof | Proof validity failure | Client rejects the proof at deterministic verification | Protocol safety unaffected |
| Sentinel relayer withholds data | Relay liveness failure | Domain misses external input during the withholding window | Permissionless relay mitigates only if another relayer submits |
| Sentinel relayer submits invalid proof | Validity failure | STF rejects the submission if proof-shaped and the STF is honestly executed | STF verification boundary; phase-dependent execution correctness |
| Sentinel watcher cannot fetch DA bundle | Replay failure | No alarm can be raised | DA availability boundary; not indicative of executor honesty |
| Sentinel watcher detects divergence | Detection event | Alarm raised; no on-chain enforcement in Phase 1 | Phase 2 fraud-proof channel is deferred |
| Sentinel observer reports false value | External-truth failure | Domain processes a false observation as if it were correct | Oracle boundary; no Sentinel observation guarantee |
| Sentinel signer colludes (hypothetical, not specified) | Custody safety failure | External assets controlled by the signer set may be stolen | Custody role is not assigned; this scenario presupposes an unspecified mechanism |
| QSR bond assumed but not specified | Disclosure failure | Users overestimate economic security | QSR is not assigned as a service bond |
| Sentinel role inferred from adjacent ecosystem hints | Disclosure failure | Misleading trust model in user-facing material | Only spec-grounded roles should be claimed |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Sentinels guarantee DA | Sentinel/libp2p DA serving is best-effort in Phase 1; no protocol enforcement, no slashing, no paid market |
| Sentinels are official relayers | Sentinels are plausible relayer operators under a future `L1_RELAYED` profile; no official role is assigned |
| Sentinels are official watchers | Any party with DA, runtime, and witnesses can watch; Sentinel watcher fit is speculative or optional |
| Sentinels provide a proof-serving market | Proof serving by Sentinels is plausible but not specified; no API, registration, or compensation flow exists |
| Sentinels are bridge custodians | No current spec assigns custody authority to Sentinels |
| Sentinels make oracle data true | Observation remains observation unless paired with a machine-verifiable proof that the STF verifies |
| QSR is service collateral | QSR service collateral for Project Zeno service roles is a thesis unless the spec assigns it |
| Sentinel services are paid by protocol | No paid Sentinel service market is specified in Phase 1 |
| Sentinel failure is slashable | No Phase 1 Sentinel service slashing is specified |
| Sentinel role fit means roadmap | Role fit is research classification; roadmap is governance and implementation work |
| Sentinels enforce DA availability | Sentinels serve data when they choose to; enforcement is a Phase 2 concept that the current spec does not implement |
| Sentinels are the official Zenon service layer | The spec names Sentinels in a specific best-effort DA support role; broader service-layer claims require explicit spec definition |

## 16. Open questions for Domain Settlement implementers

1. Is Sentinel/libp2p DA serving intended to remain best-effort in Phase 1, or is there a planned transition to an enforced model in a later phase?

2. What exact DA serving API should Sentinels expose? The current spec names content-addressing by `DAHash` and chunk size bounded by `MaxDAChunkSize`, but the request semantics, fallback paths, and chunk-discovery protocol need explicit specification.

3. What retention period is expected for DA bundles and chunks served by Sentinels? Indefinite, time-bounded, or proof-window-bounded?

4. Should proof serving be protocol-recognized, with registered Sentinel proof servers, or left entirely to off-chain infrastructure with no spec involvement?

5. Should Sentinels be eligible relayers for future `L1_RELAYED` domains, or should relaying remain fully permissionless and role-agnostic, with Sentinel participation no different from any other participant?

6. Should Sentinels have any privileged watcher or fraud-proof emission role in Phase 2, or should fraud-proof emission be permissionless under the same role-agnostic discipline?

7. Should `EXTERNAL_OBSERVED` domains, when activated, support Sentinel observers or Sentinel observer committees? Or should observation be domain-specific and Sentinel-independent?

8. Are Sentinels ever intended to participate in external-chain custody or threshold signing? If so, under what governance gate and with what specification work as prerequisite?

9. Is QSR intended as a service bond for any Sentinel role in Project Zeno? If so, with what amount, lock mechanics, and slashing conditions?

10. What service-level objectives would define a DA, proof, relay, or watcher market? What latency, availability, completeness, and accuracy metrics are objectively measurable?

11. What payment source would fund any such service market? User fees, protocol issuance, application-level fees, off-chain agreements, or a combination?

12. What slashing conditions are objectively measurable at the protocol level? Subjective conditions cannot be slashed deterministically.

13. What governance gate activates any Sentinel service role? The same gate as `L1_RELAYED` activation, a separate governance process, or per-role activation?

14. What public metadata should disclose which services are best-effort, paid, bonded, slashable, or merely off-chain? Is there a required disclosure surface analogous to the SPEC §6.1 disclosure requirement for `EXTERNAL_OBSERVED`?

## 17. Summary

Sentinels are infrastructure-shaped. They are natural candidates for DA serving, proof serving, relaying, watching, browser-support infrastructure, oracle observation, and possibly future custody participation if such a mechanism is ever specified.

Natural fit is not protocol assignment.

The grounded Phase 1 Sentinel role is best-effort DA support. SPEC §3 and §20 name Sentinel/libp2p DA serving as a best-effort support role: Sentinels SHOULD serve bundles and chunks addressed by `DAHash`, not consensus-critical, not on-chain enforced. This helps make DA bundles retrievable when nodes serve them. It does not guarantee availability. It does not create DA enforcement. It does not create a paid market. It does not assign QSR as a bond.

Everything beyond that grounded support role remains speculative unless explicitly specified.

Therefore:

Sentinel DA serving is support, not guarantee.
Sentinel relaying is plausible, not assigned.
Sentinel watching is plausible, not authority.
Sentinel proof serving is plausible, not specified.
Sentinel oracle observation is still observation.
Sentinel custody requires explicit key authority, which is not granted by spec.
QSR service collateral for Project Zeno service roles is a thesis, not a spec fact.
Service markets require protocol and economic design beyond what currently exists.

Do not collapse them.

The discipline this document enforces is the same discipline the rest of the Frontier series enforces: name what the spec says, label what is plausible as plausible, mark what is unspecified as unspecified, and do not let architectural fit upgrade itself into protocol assignment through repeated mention. Sentinels matter to the Project Zeno operational picture. That importance is preserved most honestly by describing the role accurately rather than inflating it.
