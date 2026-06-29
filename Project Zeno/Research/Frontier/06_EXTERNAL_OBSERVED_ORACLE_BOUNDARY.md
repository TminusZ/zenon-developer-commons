**Status:** Frontier boundary document
**Phase status:** Mixed; `EXTERNAL_OBSERVED` is architecturally defined but reserved under the Phase 1 profile
**Purpose:** Define what observed external data proves, what it does not prove, and how oracle-like inputs differ from proof-shaped relay data
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# External Observed / Oracle Boundary

## 1. Why this document exists

The previous Frontier documents created a layered vocabulary. `01_RELAYER_BOUNDARY.md` defines the relayer as a transport role that does not create validity. `02_DOMAIN_VERIFICATION_LIMITS.md` establishes that STF-verifiable does not mean Settlement-verified in Phase 1. `03_RELAYER_TRUST_MODELS.md` separates proof relay, observed relay, committee relay, and custody-bearing relay as distinct trust models. `04_PROOF_SHAPED_DATA_BOUNDARY.md` defines proof-shaped data as external input carrying enough machine-verifiable evidence for a domain STF to check a claimed fact deterministically. `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md` defines inclusion proofs as proving inclusion in a committed root, not source-domain execution correctness.

This document defines the other side of the proof-shaped boundary: externally observed data. Where proof-shaped data lets the STF verify a predicate, observed data gives the STF a value to replay.

Observed data is not proof-shaped by default. Replay consistency is not external truth. Oracle-like data can be operationally useful, but its trust model must be disclosed honestly. `EXTERNAL_OBSERVED` is reserved in Phase 1: Core must reject domains selecting it under the Phase 1 profile. The weaker, non-L1 DA guarantee for `EXTERNAL_OBSERVED` domains must be disclosed (SPEC §6.1, §20). Proof-carrying observations, where observed data includes machine-verifiable evidence, may narrow the trust question but do not erase it.

The inventory rows that feed this document include: #11 (oracle / external data feed domain), #6 (Ethereum event / state relay and verification limits, where the path may degrade to `EXTERNAL_OBSERVED` if no machine-verifiable proof scheme exists), and any DA-related rows involving weaker non-L1 DA.

## 2. Definition of `EXTERNAL_OBSERVED`

`EXTERNAL_OBSERVED` is a reserved `inputSource` for domains whose executor observes an external system and commits those observations into the domain's execution pipeline.

SPEC §6.1 defines the semantics. The domain must pin a deterministic finality and confirmation predicate in its `stfSpecHash`. The executor must commit the consumed external inputs via `inputRoot` (SPEC §19) and publish them in the DA bundle via `DAHash` (SPEC §20). L2 state must be reconstructible from the committed inputs and bundle alone, without access to the external system. The weaker, non-L1 DA guarantee must be disclosed.

The executor may read an external API, RPC endpoint, price feed, database, web service, or off-chain system. The observed value becomes part of the domain's committed input sequence. Replay can reproduce the same state transition if the same committed observations and DA bundle are available. But the domain does not independently verify whether the observation was true at the moment it was made.

`EXTERNAL_OBSERVED` commits what was observed, not what was true.

The distinction from `L1_RELAYED` is structural. `L1_RELAYED` data enters the Zenon L1 input stream as account-blocks, inheriting L1 data availability and L1 ordering. `EXTERNAL_OBSERVED` data is committed by the executor in the DA bundle, with a domain-defined ordinal rather than a `globalInputIndex` (SPEC §4.5). The data availability guarantee is weaker: the observations live in the DA bundle, not on L1.

## 3. `EXTERNAL_OBSERVED` is reserved in Phase 1

Phase 1 specifies `L1_NATIVE` only. `L1_RELAYED` and `EXTERNAL_OBSERVED` are reserved under the Phase 1 profile (SPEC §6.1). Core must reject a `RegisterDomain` selecting `EXTERNAL_OBSERVED` while the Phase 1 profile is in force.

This document analyzes the boundary properties of `EXTERNAL_OBSERVED` for future profile decisions. It is not an activation plan, a design proposal, or a commitment to implement oracle domains. Reserved architecture path does not mean active capability.

## 4. Observed data vs proof-shaped data

| Data type | Example | What the STF can verify | What remains trusted |
|---|---|---|---|
| Proof-shaped data | Bitcoin headers + Merkle proof | Header linkage, PoW, confirmation predicate, inclusion | Honest STF application in Phase 1 |
| Cross-domain outbox proof | Message + Merkle path | Inclusion in committed `outboxRoot` | Source-domain root correctness in Phase 1 |
| Observed RPC response | Ethereum RPC says event occurred | Replay of the committed observation | RPC truth, observer selection, completeness |
| Price feed observation | API reports price X | Replay of price X as input | Whether price X was accurate |
| Committee-attested observation | Threshold signs value X | Signature threshold | Whether X was externally true |
| Proof-carrying observation | zkTLS-style proof of HTTPS response | Whatever the carried proof binds and the STF verifies | Broader real-world truth beyond the proof predicate |

Proof-shaped data lets the STF verify a predicate. Observed data gives the STF a value to replay.

The difference is not about complexity or cost. A simple observation (price at time T) is fundamentally different from a simple proof (Merkle inclusion of a transaction in a block header with verified PoW). The observation can be committed and replayed deterministically. The proof can be verified against an external-chain consensus property. The boundary is the presence or absence of machine-verifiable binding to an external consensus root or cryptographic commitment.

## 5. Replay consistency

An `EXTERNAL_OBSERVED` domain can provide deterministic replay under specific conditions. The observations must be committed into the input stream via `inputRoot`. Input ordering must follow the domain-defined ordinal, committed in batch bounds (`firstInputSeq`/`lastInputSeq`). The DA bundle must contain the observed values. The domain STF must be deterministic. The `stfSpecHash` must pin the interpretation rules.

Replay consistency means a watcher can recompute the same `postStateRoot` from the same committed observations. A browser or verifier may replay if it has the DA bundle, runtime, witnesses, `stfSpecHash`, and sufficient compute. Disputes in Phase 2 could challenge whether the executor applied the committed observations correctly through the fraud-proof path.

Replay consistency does not mean the observation was true. It does not mean the observation was complete. It does not mean the observer did not omit other relevant data. It does not mean the API or RPC source was honest. It does not mean the observed value had reached external finality at the time it was committed.

Replay consistency is an execution property, not an external-truth property.

## 6. External truth boundary

A domain cannot verify external truth from a bare observation.

An executor observes a Bitcoin price as $X. Replay proves only that $X was used as input. An executor observes an Ethereum event via RPC. Replay proves only that the observation was committed and processed. An executor observes a weather result, game score, bank balance, or API response. Replay proves only that the domain processed that response.

External truth requires one of the following: a machine-verifiable proof that the STF can verify (the domain becomes proof-shaped for that predicate), a trusted observer or committee whose honesty is disclosed and accepted, social or economic oracle assumptions with explicit trust models, a later dispute process over observations if such a mechanism is specified, or explicit acceptance by the application's users that the domain uses an observed and trusted feed.

The point is not that observed data is useless. Many applications can operate responsibly on observed data if the trust model is disclosed. A price oracle with a reputable provider, economic bonding, and median filtering may be a reasonable trust arrangement. But the claim must be "this domain uses observed data from source S under trust model T," not "this domain verifies external truth."

Observed truth is a trust model, not a verification result.

## 7. Completeness and withholding

Even if every committed observation is individually replayable, the observer may have omitted relevant observations. The completeness problem is distinct from the accuracy problem.

An observer submitting price updates might report only favorable samples. An observer monitoring an external chain might omit adverse events. An observer might delay updates until a window of economic advantage passes. An observer might select one RPC provider over another based on the responses received. An observer might report a stale value when a more recent one was available.

These are selection, completeness, and liveness failures. They are not proof failures in the Merkle-proof or header-chain-linkage sense. They operate at a different layer of trust.

SPEC §6.1 addresses this as a normative requirement: for all input sources, the executor must not reorder, skip, or privately insert inputs; for external sources this manifests as a completeness requirement. The enforcement strength depends on whether the external sequence and completeness predicate are objectively checkable from committed data. Settlement can enforce contiguity over the domain's committed input sequence, but it cannot independently know that an uncommitted external observation should have been included unless the domain's STF has a machine-verifiable rule that exposes the omission.

An observed domain can replay what was committed; it cannot replay what was omitted.

## 8. Finality and freshness

External observations may depend on time, freshness, or the external system's finality model.

A price feed timestamp establishes when the price was observed. An Ethereum block's confirmation depth affects whether the observed event might be reverted by a reorg. An exchange API response may reflect a value that changes milliseconds later. An oracle heartbeat determines how often updates are expected.

The domain's `stfSpecHash` should pin deterministic acceptance rules for these properties: maximum observation age, timestamp interpretation, external confirmation depth (if relevant), source identity, fallback behavior for missing or late observations, stale-data rejection thresholds, and reorg policy for external chains.

If a freshness or staleness rule is not pinned in the `stfSpecHash`, the executor has discretion over which observations are "fresh enough," which makes execution non-deterministic. If freshness depends on wall-clock time at execution time, determinism may break unless the timestamp is part of the committed input rather than read from the local clock.

Freshness must be committed and interpreted deterministically; it cannot be left to executor discretion.

## 9. DA and availability

`EXTERNAL_OBSERVED` carries weaker DA concerns than `L1_RELAYED` data posted directly to L1 account-blocks.

Observed data lives in the DA bundle rather than directly on Zenon L1. The committed `inputRoot` and `DAHash` are on-chain, but the observation payloads are off-chain. The `inputRoot` binds the committed observations to a root that can be verified, but verifying that root requires the actual payloads, not just the hash.

Phase 1 DA serving is best-effort (Sentinel/libp2p, `DAMode=0`) and is not enforced on-chain (SPEC §20). An unavailable DA bundle reduces the affected batch to reliance on executor honesty, because watchers cannot replay execution if they cannot retrieve the inputs. SPEC §20 states this limitation must be disclosed.

For `EXTERNAL_OBSERVED`, the DA concern is compounded: the observations are committed by the executor and published in the DA bundle, but there is no L1 fallback. If the DA bundle is unavailable, the observations cannot be replayed at all. The weaker, non-L1 DA guarantee must be disclosed to users and integrators as part of the domain's trust profile (SPEC §6.1, §20).

This connects to a later DA and proof-serving boundary document. The summary for this section: commitment is not availability, and availability is not truth.

## 10. Proof-carrying observations

A proof-carrying observation is observed external data accompanied by machine-verifiable evidence that lets the domain STF verify some predicate about the observation.

The concept emerges from developments in the broader ecosystem. zkTLS-style protocols aim to produce machine-verifiable evidence about HTTPS responses, TLS sessions, server identity, or related transcript properties. Signed API responses with verifiable public keys allow the STF to confirm that a known signer produced the response. Certificate-chain or transcript proofs bind a response to a TLS session. Attested TEE transcripts bind execution to a hardware-attested enclave.

The boundary for proof-carrying observations within Project Zeno:

No zkTLS integration is specified in the current spec. No oracle system is specified. Proof-carrying observations are not automatically proof-shaped for every claim. They become proof-shaped only with respect to the predicate that the carried proof actually binds and that the STF actually verifies.

A proof that "server S returned response R over a valid TLS session" does not prove "R is the true market price." It does not prove "R represents a complete view of the data." It does not prove "S is an honest service." It proves that the response was delivered by the server with the specified certificate over a valid TLS connection. That is a meaningful reduction in trust: the observer can no longer fabricate responses from that server. But the trust in the server itself, and in the completeness and accuracy of its responses, remains.

Proof-carrying observations narrow the trust question; they do not erase it.

## 11. Committee observations and attestation

A committee can observe external data and sign an attestation. The domain STF can verify the committee's aggregate or threshold signature.

This verification is machine-verifiable for the narrow claim that the committee signed the statement under the specified threshold rule. It is not machine-verifiable for the broader claim that the external fact is true. A committee of five signers attesting "the BTC/USD price is X" proves that three of five signers agreed on X. It does not prove the price was X. A dishonest or compromised committee majority can sign a false value that passes signature verification.

Committee observation may be a legitimate trust arrangement. Many existing oracle systems use committee attestation with economic incentives, slashing conditions, and reputation. But the trust model is social and economic, not cryptographic. It must be labeled as committee trust, not proof-shaped verification.

If the same committee that attests to observations also controls custody keys for external assets, the architecture combines observation trust and custody trust. That combined model belongs in `09_CUSTODY_BOUNDARY.md`.

Committee signatures prove agreement, not external truth.

## 12. Settlement's role

Settlement can verify the following for an `EXTERNAL_OBSERVED` domain, if `EXTERNAL_OBSERVED` is activated in a future profile:

Domain registration rules and `inputSource` validation. Input ordering and batch contiguity (the domain-defined ordinal committed in batch bounds). Batch commitments, roots (`preStateRoot`, `postStateRoot`, `inputRoot`, `outboxRoot`, etc.), and batch status transitions. Aggregate conservation per (domain, asset) for assets in Settlement custody. Withdrawal delay and `MaxBatchWithdrawal` caps. Outbox inclusion proofs and `processedOutbox` replay protection. Pause scope constraints and runtime upgrade delay bounds.

Settlement cannot verify the following for `EXTERNAL_OBSERVED` domains:

Whether an observation was true. Whether the observer omitted data. Whether an API was honest. Whether an RPC endpoint was accurate. Whether a price was fair. Whether external finality was achieved, unless the finality predicate is encoded in the STF and the STF is honestly applied (Phase 1 limitation). Execution correctness in Phase 1 (bonded attestation, as for any domain).

Settlement can anchor observed data; it cannot make the observation true.

## 13. Watchers and observed data

Watchers can replay an `EXTERNAL_OBSERVED` domain if they have the DA bundle, runtime, witnesses, and `stfSpecHash`. In Phase 1, watchers can detect divergence between committed batch roots and replayed execution, raising an alarm. In Phase 2, watchers could feed fraud proofs to challenge incorrect STF application against committed observations.

But watchers cannot necessarily detect whether an omitted observation should have been included. They cannot detect whether a price feed reported an incorrect value. They cannot detect whether an RPC provider returned stale or false data. They cannot detect whether a committee colluded. They cannot detect whether a web API response reflected real-world truth. These failures are external-truth failures, not execution failures. A watcher replays execution against the committed input; if the committed input was false, the replayed execution is also false and the watcher produces the same result.

The exception: if the completeness or truth predicate is itself committed and machine-verifiable (for example, if the STF requires a sequence of consecutive external block heights and the watcher can verify that a gap exists in the committed sequence), then the watcher can detect that specific class of omission. But this requires the omission to be detectable from the committed data, not from external knowledge.

Watchers can check execution against committed observations; they cannot check uncommitted reality.

## 14. Browser and client verification

A browser or light client can verify the settlement floor from on-chain Settlement state: committed roots, batch status, conservation counters, `processedOutbox`. This does not require access to the DA bundle.

A browser may replay an `EXTERNAL_OBSERVED` domain's execution if it has the observed payloads, DA bundle, runtime, witnesses, `stfSpecHash`, and sufficient compute resources. But browser replay of an observed domain still verifies execution against committed observations, not the truth of the observations. The browser confirms that the domain processed the committed inputs correctly (deterministic replay). It does not confirm that the inputs were true, complete, or fresh.

Browser replay of an observed domain confirms deterministic processing of observations, not the truth of the observations.

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| `EXTERNAL_OBSERVED` is active in Phase 1 | It is reserved; Phase 1 specifies `L1_NATIVE` only |
| Oracle data becomes true once committed | Commitment makes data replayable, not true |
| Observed data is proof-shaped | Observed data is proof-shaped only if it carries machine-verifiable evidence the STF verifies |
| Replay proves external truth | Replay proves deterministic processing of committed observations |
| Watchers verify oracle truth | Watchers verify execution against committed observations, not uncommitted reality |
| Committee signatures prove the external fact | They prove committee agreement unless accompanied by machine-verifiable evidence |
| zkTLS solves oracle trust | zkTLS-style proofs narrow the trust question; they do not prove every claim about real-world truth |
| Hash commitments are enough for replay | Payload availability is required; hash alone is a commitment, not a replay-ready artifact |
| `EXTERNAL_OBSERVED` has L1-grade DA | DA may be weaker (non-L1) and must be disclosed per SPEC §6.1 and §20 |
| Settlement verifies observed truth | Settlement anchors commitments; it does not verify external truth |

## 16. Open questions for Domain Settlement implementers

1. What governance gate activates `EXTERNAL_OBSERVED` after the Phase 1 profile?

2. What canonical input envelope should observed data use? What fields must be committed for deterministic replay: source identifier, timestamp, observed value, signature, proof, payload hash, DA reference?

3. How should the weaker DA guarantee be disclosed to users and integrators? Should it be a required field in the domain's public metadata?

4. Can an `EXTERNAL_OBSERVED` domain require multiple observers or committee attestations as part of its `stfSpecHash` rules, or is multi-observer design outside the `EXTERNAL_OBSERVED` model?

5. Are proof-carrying observations classified as `L1_RELAYED` (if the proof is posted to L1 as an account-block), `EXTERNAL_OBSERVED` (if the proof is in the DA bundle), or a separate future `inputSource` profile?

6. What deterministic freshness, heartbeat, and stale-data rules should be recommended for `stfSpecHash` pinning? Should there be a minimum set of required freshness fields?

7. What, if anything, can Phase 2 fraud proofs enforce about observation completeness? If the completeness predicate is pinned (e.g., "all sequential blocks from height N to M must be present"), fraud proofs can detect gaps. If completeness is defined vaguely, fraud proofs cannot help.

8. Should observed-data domains carry stricter withdrawal caps, longer withdrawal delays, or additional bond requirements due to the weaker external-truth guarantees?

9. Are Sentinels expected to serve any observer, attester, or data-source role for `EXTERNAL_OBSERVED` domains, or is Sentinel involvement purely speculative infrastructure fit with no spec assignment?

10. If a proof-carrying observation system (such as a zkTLS-style prover) is integrated in a future profile, does it change the `inputSource` classification, or does the domain remain `EXTERNAL_OBSERVED` with a richer proof payload?

## 17. Summary

`EXTERNAL_OBSERVED` is the reserved path for domains that commit external observations rather than machine-verifiable proofs.

Its useful property is replay consistency. Given the same committed observations, DA bundle, runtime, witnesses, and `stfSpecHash`, the domain execution can be replayed deterministically and a watcher can detect execution divergence.

Its limitation is external truth. The domain can verify what it processed. It cannot verify that the observation was true, complete, fresh, or fairly selected unless those properties are themselves machine-verifiable and enforced by the STF.

Proof-carrying observations may improve the model by attaching verifiable evidence to observed data. A zkTLS proof, for example, can bind a response to a specific server's TLS session. But the proof only proves the predicate it actually binds. A proof that "server S returned value R" does not prove "R is the true price." The trust question narrows but does not disappear.

Committee observations introduce social and economic trust. A threshold signature proves that the committee agreed. Whether the committee's statement is true depends on the committee's honesty and incentive structure, not on cryptographic verification.

Therefore:

Proof-shaped relay is a verification model: the STF checks the proof.
Observed relay is a replay and attestation model: consistency is verifiable, truth is not.
Proof-carrying observation is a partial-verification model: the carried proof narrows the trust surface.
Committee observation is a social and economic trust model: signatures prove agreement, not facts.
Custody remains separate from all four.

Do not collapse them.
