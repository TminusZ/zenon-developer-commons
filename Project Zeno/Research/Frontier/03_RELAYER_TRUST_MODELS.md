**Status:** Frontier boundary document
**Phase status:** Mixed; `L1_RELAYED` is architecturally defined but reserved under the Phase 1 profile
**Purpose:** Analyze what trust, if any, a relayer carries under different data and relay models
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Relayer Trust Models

## 1. Why this document exists

`01_RELAYER_BOUNDARY.md` defines what a relayer is: an off-chain actor that submits proof-shaped external data into the Zenon L1 input stream. `02_DOMAIN_VERIFICATION_LIMITS.md` defines what is actually verified at each layer and phase. This document fills the gap between those two: given a defined relayer boundary and a known verification stack, what trust does a relayer carry, and how does that trust change with different data classes and relay configurations?

Relayer trust is not one thing. It depends on several independent dimensions that must not be collapsed.

Whether the relayer is trusted for validity depends on the data class. If the domain STF can verify the submitted data against a machine-verifiable proof, the relayer is not trusted for validity. If the submitted data is an observation without a machine-verifiable proof, the relayer (or the underlying observer) carries validity trust. These are different architectures with different risk profiles.

Whether someone will submit data is a liveness question, not a validity question. Permissionless relay changes the liveness model by opening submission to any participant, but it does not guarantee that anyone will participate.

Whether the data is retrievable after submission is an availability question. Directly posted relay data inherits Zenon L1 data availability. Referenced payloads that live in DA bundles or external storage depend on a separate availability path.

Whether external assets can be moved is a custody question, entirely separate from whether an event was verified. Relay can prove that an event occurred. It cannot release assets on another chain.

This document defines five relay trust models, identifies their failure modes, and prevents the dangerous conflation of verification, liveness, availability, and custody.

## 2. Trust dimensions

| Dimension | Question | Relayer relevance |
|---|---|---|
| Validity | Is the submitted data correct? | Only matters if the domain STF cannot independently verify it |
| Liveness | Will someone submit the data? | Always relevant; permissionless relay improves the model without guaranteeing participation |
| Availability | Can verifiers retrieve the data later? | Depends on whether data is posted directly to L1 account-blocks or referenced through a separate DA path |
| Ordering | Is the data ordered canonically? | L1 momentum ordering applies after submission; the relayer does not control order |
| Finality | Is the external event final enough? | Determined by the domain STF's confirmation predicate pinned in `stfSpecHash`, not by relayer discretion |
| Execution correctness | Did the executor apply the STF honestly? | Not a relayer question; Phase 1 is bonded attestation; Phase 2 adds fraud-proof enforcement under assumptions |
| Custody | Who controls external assets? | Not the relayer unless the same actor is separately assigned a custodian role |

The validity/liveness distinction is the most important axis. Many overclaims result from treating "the data was submitted" as equivalent to "the data is valid" or treating "valid submissions are possible" as equivalent to "submissions will happen."

## 3. Model A: permissionless proof relay

This is the cleanest `L1_RELAYED` trust model. Anyone can submit proof-shaped data to Settlement as Zenon L1 account-blocks. The domain STF verifies the proof during execution, and submissions that fail verification are rejected.

Under this model, the relayer is not trusted for validity, provided the proof is machine-verifiable and the STF implements the corresponding verification logic. A malicious relayer submitting an invalid Bitcoin header chain, for example, produces data that the Bitcoin SPV domain STF rejects: the proof-of-work does not satisfy the difficulty target, the headers do not link correctly, or the Merkle inclusion proof does not match. The STF's rejection is deterministic and reproducible by any party replaying from L1 data.

Liveness, however, remains an assumption. Permissionless relay means any participant can submit, so the system does not depend on a single designated operator. But "anyone can" is not the same as "someone will." If no relayer submits Bitcoin headers for a period, the Bitcoin SPV domain sees no new external input during that period. Permissionless relay mitigates liveness censorship if at least one honest relayer submits the data. It does not guarantee that anyone will.

Once a relayed account-block is included in a confirmed Zenon momentum, force-inclusion and contiguity rules apply: the executor cannot skip it (SPEC §4.2, §4.6). This eliminates executor-level censorship of submitted relay data, but it presupposes that the data was submitted and included in the first place.

Directly posted relay data inherits Zenon L1 data availability. If proof objects exceed account-block data limits, they may require compression, chunking, or DA references, and the availability properties of referenced payloads depend on the DA path rather than L1 directly. This boundary is analyzed in `07_DA_AND_PROOF_SERVING_BOUNDARY.md`.

In Phase 1, Settlement does not verify execution correctness on-chain. Even under permissionless proof relay, the batch containing the executor's processing of the relayed data rests on bonded attestation. STF-verifiable does not mean Settlement-verified in Phase 1 (see `02_DOMAIN_VERIFICATION_LIMITS.md`).

Permissionless proof relay removes designated-relayer validity trust when the STF verifies the proof, but it does not remove the liveness assumption that someone must submit the data.

## 4. Model B: designated proof relay

A deployment may designate a specific operator as the expected relayer for a domain, even though the relay protocol itself is permissionless. The designated operator runs the relay binary, monitors the external chain, and submits proof-shaped data to Settlement.

The validity properties are the same as Model A: if the proof is machine-verifiable and the STF checks it, the designated relayer is not trusted for validity. An invalid submission is rejected by the STF. Any other party can also submit valid data, since relaying is permissionless.

The difference is liveness. If the deployment's infrastructure, monitoring, and tooling are built around one operator, and that operator goes offline or withholds data, the domain misses external events until another relayer steps in. The protocol allows anyone to submit, but the operational reality may be that only the designated operator has the integration, data feeds, and incentive to do so. In that case, the liveness model is effectively centralized around a single operator, even though the protocol surface is permissionless.

Designated proof relay centralizes liveness, not validity, assuming the STF verifies the proof.

This is not necessarily a failure: a designated operator with monitoring, redundancy, and clear SLAs may provide better liveness than hoping for altruistic permissionless participation. But it must be described honestly. If the domain's external-data liveness depends on one operator, that is a meaningful trust assumption that should be communicated.

## 5. Model C: committee relay and threshold attestation

A committee of signers may attest to external data and submit the attestation to Settlement. The domain STF verifies the committee's aggregate signature or threshold attestation.

The trust boundary here is fundamentally different from proof relay. In Models A and B, the relayer submits data that the STF can verify against external-chain consensus rules: proof-of-work, header linkage, Merkle inclusion. The relayer is not trusted for validity because the proof itself is the evidence.

In committee relay, the STF verifies committee signatures, not external-chain proofs. The validity of the attested data depends on the honesty of the committee members who signed. If a threshold of committee members collude to attest to false data, the STF will accept it because the signatures are valid even though the underlying claim is not. The trust has moved from the external chain's consensus mechanism to the committee's economic or social incentive structure.

This is a legitimate trust model, and it may be appropriate for external chains where machine-verifiable proof relay is impractical. But it must not be described as proof-shaped verification. Committee signatures attest; external-chain proofs verify. The distinction matters because the failure modes are different: a proof-relay failure is a bug in the STF's verification logic, while a committee-relay failure is a breakdown in the committee's incentive structure.

If the same committee that attests to external events also controls the keys for releasing external assets, the relay role and the custody role have been merged. That architecture has different and higher risk than attestation alone, and belongs in `09_CUSTODY_BOUNDARY.md`.

Committee relay can create an explicit social or economic trust model, but it should not be described as proof-shaped verification unless the underlying external event is also machine-verifiable.

## 6. Model D: observed relay and oracle-like reporting

An observer reads external data (price feeds, API responses, state snapshots) and submits it to Settlement. The submitted data does not include a machine-verifiable proof of external-chain state. The domain STF can replay the committed observation sequence deterministically, but it cannot independently verify that the observed values were correct at the moment of observation.

This model overlaps with `EXTERNAL_OBSERVED` rather than clean `L1_RELAYED`. SPEC §6.1 defines `EXTERNAL_OBSERVED` for sources where the executor reads the external system directly and commits the observations, with weaker DA guarantees that must be disclosed. The relay framing is secondary: what matters is that the data class is observed rather than proof-shaped.

Under this model, validity trust sits with the observer, attester, or executor that selected the observation. Consistency is possible (replaying the same committed sequence produces the same outputs), but correctness is not independently verifiable. The domain can verify replay consistency, not external truth, unless the observation includes a machine-verifiable proof.

DA may be weaker under `EXTERNAL_OBSERVED`: the observation data may not be posted to L1, so availability depends on the executor's DA bundle publication and the serving infrastructure. This weaker DA guarantee must be disclosed (SPEC §6.1, §20).

The detailed boundary for observed data and oracle-like domains belongs in `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`. This section establishes only that observed relay is a different trust model from proof relay and must not be conflated with it.

## 7. Model E: relay plus custody

This is the case where a relay function and a custody function are performed by the same actor or within the same system. It is the most dangerous model to describe imprecisely because the word "relay" makes it sound like a transport function, while custody implies control over external assets.

The Bitcoin SPV path illustrates the boundary. A relay submitting Bitcoin block headers and Merkle inclusion proofs allows a domain STF to verify that a Bitcoin transaction occurred. That verification can credit wrapped-BTC in L2 contract state. But releasing native BTC on the Bitcoin network requires a separate key or signing committee that controls the funds. The relay proved the event; only a custodian can act on the external chain.

When the same operator both relays events and holds custody keys, the trust model is no longer just relay trust. It includes custody trust: the operator can observe a withdrawal request in L2 state and refuse to sign the external release, or can sign unauthorized releases. These are custodian failures, not relayer failures, even if the same entity performs both roles.

The required decomposition for any relay-plus-custody architecture is:

Event verification: did the external event occur? (Relay and STF.)
State update: is the domain state updated to reflect the event? (Executor and STF.)
Withdrawal claim: has the L2 contract emitted a withdrawal outbox message? (Domain execution.)
External asset release: does someone sign and broadcast the external transaction? (Custody.)

BTC withdrawal is not a relayer problem. It is a custody and key-management problem. The relay boundary document (`01_RELAYER_BOUNDARY.md`) and the custody boundary document (`09_CUSTODY_BOUNDARY.md`) must be read together for any architecture that combines both functions.

## 8. Liveness failure modes

| Failure mode | Type | Consequence |
|---|---|---|
| No relayer submits data | Liveness | Domain sees no external input for the affected period; external events are missed, not fabricated |
| Relayers submit data too late | Liveness | Domain's view of the external chain lags; time-sensitive applications may be affected |
| Relayers submit only part of an external chain view | Liveness / partial availability | Domain has an incomplete view; the STF's canonical-view predicate may reject the partial data or produce a delayed state |
| Relayers submit data that is valid but economically stale | Liveness | Not a validity failure (the proof is correct), but applications that depend on timely data may behave suboptimally |
| Relayers submit data before the external confirmation predicate is satisfied | Validity (if STF rejects) / liveness (if retry needed) | The STF should reject insufficiently confirmed data; the relayer must resubmit after the predicate is met |
| Relayed account-blocks are not included on Zenon L1 | L1-level censorship / congestion | The relay submission exists but has not entered a confirmed momentum; this is a Zenon L1 liveness concern outside Settlement scope |
| Large proof data exceeds account-block limits | Availability / format | Requires unresolved chunking, compression, or DA references; an open design question |

None of these are validity failures if the STF correctly verifies or rejects the proof-shaped data. Liveness failure means the domain does not see external events. It does not mean the domain sees false events. The distinction matters because liveness failures are recoverable (submit the data later), while undetected validity failures corrupt state.

Permissionless relay mitigates several of these modes by allowing any participant to fill liveness gaps. But mitigation depends on someone actually participating. A permissionless relay protocol with zero active participants provides zero liveness.

## 9. Validity failure modes

| Failure mode | STF response (if correctly implemented) |
|---|---|
| Invalid proof submitted (bad PoW, broken linkage) | STF rejects the input |
| Malformed payload (wrong encoding, truncated data) | STF rejects or causes `RUNTIME_FAULT` |
| Header chain does not satisfy domain confirmation rules | STF rejects the input |
| Inclusion proof does not match committed root | STF rejects the input |
| External event fails the domain's `confirmationDepth` predicate | STF rejects the input |
| Wrong domain format or `stfSpecHash` mismatch | Input rejected at the domain routing layer |

Under proof-shaped relay, these failures should be caught and rejected by the domain STF during execution. They are not relayer-trust failures in the validity sense: the relayer submitted bad data, and the STF rejected it. The system worked as designed.

But there is a critical caveat from `02_DOMAIN_VERIFICATION_LIMITS.md`: in Phase 1, correct STF application relies on bonded executor attestation. Settlement does not replay the STF on-chain. If the executor is dishonest and claims to have applied the STF when it did not, a submitted proof that should have been rejected could be incorrectly accepted, or a valid proof could be incorrectly rejected. Phase 2 fraud proofs address this by allowing a challenger to trigger on-chain replay of the disputed step.

Proof rejection is an STF property; honest application of the STF is an execution-correctness property. These are different layers, and confusing them leads to claims that proof relay alone makes the system safe, which omits the executor-attestation step.

Therefore, proof relay improves the validity model only to the extent that the STF verification logic is correct, deterministic, and honestly applied under the active phase.

## 10. Availability and replay

After a relay submission enters a confirmed Zenon momentum, the question shifts from "will someone submit?" to "can verifiers retrieve and replay?"

If the proof data is posted directly in Zenon L1 account-block data, it inherits Zenon L1 data availability. Any node with access to Zenon L1 state can retrieve the relayed data and replay the domain's processing of it without accessing the external chain. This is the property that makes `L1_RELAYED` closer to a light-client input model than a live data feed: the evidence is archived on L1.

If only hashes or references are posted to L1 and the full payload lives in a DA bundle or external storage, replay depends on the availability of that separate data path. Phase 1 DA serving is best-effort (Sentinel/libp2p, `DAMode=0`) and is not enforced on-chain. A referenced payload that becomes unavailable degrades the replay guarantee even though the hash commitment remains on L1.

The distinction matters for watcher replay and browser verification. A watcher that replays execution needs the actual proof data, not just the hash. A browser verifying the settlement floor does not need the proof data (the floor is on-chain state), but a browser attempting full execution replay does.

This boundary feeds directly into `07_DA_AND_PROOF_SERVING_BOUNDARY.md`. The summary for this document: do not claim all relayed data automatically has full L1 DA. Directly posted relay data does. Referenced payloads depend on their DA path.

## 11. Comparison table

| Model | Validity trust | Liveness trust | DA assumption | Custody involved? | Safe claim |
|---|---|---|---|---|---|
| A: Permissionless proof relay | STF verifies proof; relayer not trusted for validity if STF is honestly applied | At least one relayer submits | L1 DA if directly posted; DA-path-dependent otherwise | No | Cleanest `L1_RELAYED` trust model |
| B: Designated proof relay | STF verifies proof; same validity model as A | Designated relayer or fallback submitter | Same as A | No | Centralizes liveness, not validity |
| C: Committee relay | Committee, if STF verifies signatures only; external-chain proof if STF also verifies underlying event | Committee liveness | Depends on data publication model | Possibly, if committee also holds custody keys | Explicit committee trust model; distinct from proof relay |
| D: Observed relay | Observer, attester, or executor selecting the observation | Observer or executor | Often weaker; must be disclosed per SPEC §6.1, §20 | Application-dependent | Replay consistency, not external truth |
| E: Relay plus custody | Depends on proof path for event validity | Relayer and custodian operational availability | Depends on architecture | Yes | Must be treated as custody-bearing |

The table makes one pattern visible: as you move from A to E, the trust surface expands. Model A places validity trust in the STF and liveness trust in the relay market. Model E places trust in the STF (for event verification), the relay operator (for liveness), and the custodian (for external asset control). Collapsing these models hides the expanding trust surface.

## 12. Sentinel relevance

Sentinel nodes are architecturally positioned as natural candidates for relay infrastructure. They already run as Zenon network participants with connectivity and uptime expectations, and their existing role as best-effort DA servers (SPEC §3, §20) involves serving data addressed by hash, which is operationally adjacent to monitoring and submitting external-chain data.

But no spec assigns Sentinels as relayers. No paid Sentinel relay market is specified. No QSR service bond for relay operation is specified. Sentinel relay is a speculative architectural fit, not a protocol assignment.

Detailed analysis of Sentinel service roles, including relay, watcher, DA serving, and proof serving, belongs in `10_SENTINEL_SERVICE_BOUNDARY.md`. For this document, the relevant point is that Sentinel relay participation would operate under Model A (permissionless proof relay) or Model B (designated proof relay), with the same trust properties described in those sections. Sentinel identity does not change the trust model; the data class and verification path determine trust.

## 13. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Relayers make external data verified | Relayers transport data; proof-shaped data is verified by the domain STF during execution, not by the relay act |
| Permissionless relay guarantees liveness | Permissionless relay improves liveness if at least one honest or incentivized relayer submits; it does not guarantee participation |
| Designated relayer controls validity | Not if the STF verifies proof-shaped data and the executor applies the STF honestly |
| Committee relay is the same as proof relay | Committee signatures are a trust model; proof relay uses the external chain's own consensus evidence |
| Bitcoin SPV solves BTC custody | Bitcoin SPV verifies events inside the STF; BTC withdrawal requires a separate custody mechanism |
| All relayed data has L1 DA | Directly posted relay data has L1 DA; referenced payloads depend on their DA path |
| Sentinel relayers are protocol-assigned | Sentinel relay is a plausible architectural fit, not a spec assignment |
| Phase 1 verifies relay proofs on-chain | Phase 1 Settlement does not verify domain execution correctness on-chain; STF verification occurs inside the executor under bonded attestation |

## 14. Open questions for Domain Settlement implementers

1. What governance gate activates `L1_RELAYED` after the Phase 1 profile? Is it an administrator action, a spork, a governance contract, or a multisig decision?

2. Is relayer-submitted data always direct account-block payload, or can account-blocks carry references to DA bundles containing the full proof objects? The answer determines whether all relay data inherits L1 DA or only the commitment hash does.

3. Is there a canonical relay payload envelope for `L1_RELAYED` domains, or is format definition left entirely to each domain's STF?

4. How should relay payloads that exceed the 16 KiB `MaxDataLength` account-block limit be chunked, compressed, or referenced? Bitcoin headers are small, but Ethereum state proofs or committee attestations with auxiliary data may be larger.

5. For Bitcoin SPV, what `confirmationDepth` policy should be pinned in the `stfSpecHash`? This is an STF design question with relay-liveness implications: deeper confirmation requirements mean longer submission latency.

6. For Ethereum event relay, is a machine-verifiable proof scheme (light-client header chain with Merkle proofs, or a ZK-based attestation) intended? Or does the Ethereum path use `EXTERNAL_OBSERVED` with observed data? The answer determines whether the trust model is A/B (proof relay) or D (observed relay).

7. Should any relay role be protocol-recognized for Sentinel nodes, or should relay remain purely permissionless infrastructure with no special designation?

8. Are relayers intended to be economically incentivized by protocol mechanisms, application-level fees, off-chain agreements, or is the incentive model not specified? The answer affects which liveness model (A vs B) is realistic for a given deployment.

## 15. Summary

The relayer trust model depends on the data class and the verification path.

For proof-shaped data under a permissionless relay model, the relayer transports evidence and the domain STF verifies it. The relayer is not trusted for validity, but someone must still submit the data. Liveness is an assumption about market participation, not a protocol guarantee. In Phase 1, correct STF application still relies on bonded executor attestation; Settlement does not verify execution correctness on-chain.

For observed data, replay consistency is possible but external truth is not independently verified unless the observation includes a machine-verifiable proof. The trust sits with the observer or attester, not with the relay protocol.

For committee attestations, the trust sits with the committee's honesty and incentive structure. This is a legitimate trust model, but it is not the same as proof-shaped verification and must not be described as such.

For custody-bearing flows, relay is not enough. External asset release requires a separate custodian or signing mechanism. The relay proved the event; only a custodian can act on the external chain.

These are four different trust models:

Proof relay is a validity-verification model: the STF checks the proof.
Observed relay is an attestation and replay model: consistency is verifiable, truth is not.
Committee relay is an explicit social and economic trust model: committee honesty determines correctness.
Relay plus custody is a custody model: event verification and asset control are separate functions with separate trust.

Do not collapse them. Each has its own failure modes, its own assumptions, and its own honest framing. The strongest claim available for proof relay is precise and bounded: proof-shaped data submitted by an untrusted relayer can be verified by the domain STF, so validity trust shifts from the relayer to the proof and the STF. That is a meaningful architectural property. It is not a claim that the system is free of trust assumptions.
