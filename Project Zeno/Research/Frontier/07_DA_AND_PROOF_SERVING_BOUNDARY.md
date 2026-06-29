**Status:** Frontier boundary document
**Phase status:** Mixed; Phase 1 commits DA hashes and uses best-effort serving, while DA enforcement is deferred
**Purpose:** Define what `DAHash`, DA bundles, proof serving, and replay availability guarantee, and what they do not guarantee
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# DA and Proof-Serving Boundary

## 1. Why this document exists

Every previous Frontier document depends on availability somewhere. `01_RELAYER_BOUNDARY.md` requires that relayed proof data be available so the STF can verify it. `02_DOMAIN_VERIFICATION_LIMITS.md` notes that watcher replay requires the DA bundle, witnesses, runtime, and `stfSpecHash`. `03_RELAYER_TRUST_MODELS.md` distinguishes directly posted L1 data (which inherits L1 DA) from referenced payloads (which depend on a separate DA path). `04_PROOF_SHAPED_DATA_BOUNDARY.md` makes availability one of the three required properties of proof-shaped data. `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md` requires payload plus Merkle path, not just root, to replay or verify a cross-domain message. `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md` requires the committed observation payloads for replay.

Availability is a shared assumption across all of these. This document defines the boundary.

Commitment is not availability. A hash binds the verifier to a specific payload, but it does not give the verifier that payload. Availability is not validity. A retrievable payload can still be wrong. Serving is not enforcement. Best-effort infrastructure can fail without on-chain consequence in Phase 1. Sentinel/libp2p DA serving is architecturally named in the spec as a best-effort support role, not a paid or protocol-enforced Sentinel market. Proof serving and DA serving are related but distinct: serving full execution bundles is different from serving inclusion proofs against committed roots.

The inventory rows that feed this document include: #18 (DA bundle serving), #19 (DA enforcement, deferred to Phase 2), #20 (watcher role), #21 (browser-native verification floor), #25 (Sentinel as watcher, speculative), #33 (shared SMT core dependency), #38 (proof server, speculative service role), and #40/#41 (outbox replay protection, where payload availability is implicit).

## 2. Definitions

**`DAHash`.** A SHA3-256 hash of the canonical execution data bundle for a batch (SPEC §20). Included in the batch commitment. Binds the batch to a specific bundle encoding.

**DA bundle.** The off-chain artifact for a batch, containing per input: the canonical input data, the SMT witnesses for every key read or written (including absent observations), and the per-input `ExecutionResult` (SPEC §20). Has exactly one valid encoding; any reorder, omission, or duplicate yields a different `DAHash` and is non-conformant.

**Payload.** The actual data content of an input, observation, message, or proof, as distinct from its hash or commitment.

**Witness.** The SMT inclusion or non-inclusion proof material for a key observed during execution, including absent observations (SPEC §13, §20).

**Proof path.** The Merkle or SMT sibling-hash sequence from a leaf to a committed root.

**SMT proof.** An inclusion or non-inclusion proof over the path-native sparse Merkle tree, verifiable against a committed `postStateRoot` (SPEC §13).

**Outbox inclusion proof.** A Merkle proof that a specific outbox message is included in the `outboxRoot` of a finalized batch, verified by Settlement on `RelayMessage` (SPEC §17.3).

**Proof server.** A service that produces and serves SMT proofs, outbox inclusion proofs, receipt proofs, or other inclusion artifacts against committed roots. Speculative service role; not assigned by the spec.

**DA server.** A service that stores and serves DA bundles or bundle chunks addressed by `DAHash`. In Phase 1 this role is filled best-effort by Sentinel and libp2p nodes (SPEC §3, §20).

**Watcher.** A node that runs the executor's identical execution pipeline, recomputes roots, and detects divergence (SPEC §3, EXECUTOR_DRAFT.md §4, §11). Requires the DA bundle, runtime, witnesses, and `stfSpecHash` to replay.

**Browser/client verifier.** Any client (typically a browser) that verifies whichever layer of Settlement state it has data and resources for: settlement floor, inclusion proofs, or full execution replay.

**Commitment.** A hash or root that binds the producer to a specific value. Verifiable against the value if the value is available.

**Availability.** The retrievability of the underlying payload by third parties at the time it is needed for verification or replay.

**Enforcement.** A protocol-level mechanism that rejects, delays, penalizes, or otherwise responds to absent or invalid data.

A DA server serves bundles. A proof server serves inclusion and non-inclusion proofs against committed roots. A watcher replays execution. A browser or client verifies whichever layer it has data for. These roles do not collapse.

## 3. Commitment vs availability

A hash or root commits to data. It does not make that data retrievable.

`DAHash` commits to an execution data bundle. `inputRoot` commits to input leaves. `outboxRoot` commits to outbox messages. `postStateRoot` commits to state. A payload hash commits to a payload.

None of these alone provide the payload, the witness, the Merkle path, the full bundle, proof-serving liveness, or third-party retrievability. They allow a verifier with the data to check the data. They do not deliver the data.

Commitment lets a verifier check data if it has the data; it does not give the verifier the data.

## 4. What `DAHash` guarantees

`DAHash` binds a batch to a specific DA bundle. SPEC §20 makes this exact: `DAHash` must be `SHA3-256` of the canonical execution data bundle, encoded exactly as the spec defines. The bundle has one valid encoding. Any reorder, omission, or duplicate yields a different `DAHash`.

If the bundle is available, a verifier can check that the bundle matches the committed `DAHash` by recomputing the hash. This verification supports replay, watcher re-execution, browser or client replay, and the future Phase 2 fraud-proof construction described in EXECUTOR_DRAFT.md.

`DAHash` does not prove that the bundle was published to any specific location. It does not prove that the bundle is still retrievable now. It does not prove that Sentinels are serving it. It does not prove that a browser can fetch it. It does not prove that a watcher currently has it. It does not give Phase 1 any mechanism to penalize non-publication. SPEC §20 is explicit: Phase 1 DA is commitment-only; Settlement must not verify on-chain that the bundle is available.

`DAHash` is a commitment handle, not an availability proof.

## 5. Phase 1 DA serving

Phase 1 DA serving operates under SPEC §20 with `DAMode = 0`: best-effort publication via Sentinel and libp2p, content-addressed by `DAHash`, retrievable in chunks bounded by `MaxDAChunkSize`. Settlement records `DAMode` and verifies it falls within the Periphery-approved set. Phase 1 approves only `DAMode = 0`.

The executor publishes the DA bundle off-chain. SPEC §3 names Sentinel and libp2p as best-effort serving infrastructure, not consensus-critical in Phase 1. The bundle is not submitted on-chain. Settlement commits to its hash and to the `DAMode` field; the data itself lives off-chain.

If the bundle is unavailable, watchers cannot replay execution. If watchers cannot replay, they cannot detect divergence between committed roots and recomputed roots. The Phase 1 alarm-only watcher role becomes ineffective without bundle access. This increases reliance on executor honesty in practice, regardless of the bonded attestation model. SPEC §20 acknowledges this directly: with no on-chain availability enforcement and no active fraud proofs, an unavailable bundle reduces the affected batch to reliance on executor honesty. The limitation must be disclosed.

Phase 1 DA serving supports replay; it does not enforce replayability.

## 6. DA enforcement boundary

DA enforcement is different from DA serving. DA serving means data is made retrievable by some infrastructure. DA enforcement means the protocol can reject, delay, slash, challenge, or otherwise penalize unavailable data.

Phase 1 does not enforce DA availability on-chain. SPEC §20 makes this normative: Settlement must record `DAHash` and `DAMode` per batch and must not verify on-chain that the bundle is available. The enforcement layer is absent by design in Phase 1.

Future phases connect DA to enforcement. SPEC §20 notes that Phase 2 adds DA enforcement. A Phase 2 fraud-proof referee can verify a challenged execution step only if the bundle exists and the witnesses can be retrieved. EXECUTOR_DRAFT.md describes the Phase 2 watcher as the actor that reconstructs the exact bundle byte layout to verify availability and to bind witnesses to committed roots. Without DA, this verification cannot happen.

Validity proofs (Phase 3, reserved) may reduce the replay requirement for clients in some scenarios by producing on-chain-verifiable proofs of correct execution. They do not eliminate the need for public data: state access, auditability, and app-specific verification still depend on some level of data publication.

If DA is referenced through an external DA layer in some future `DAMode`, its security assumptions must be disclosed. The current Periphery-approved set contains only `DAMode = 0`.

A fraud-proof system without DA becomes an alarm system without evidence.

## 7. Proof serving vs DA serving

These are different roles with different inputs, outputs, and properties.

| Role | Serves | Used for | Does not guarantee |
|---|---|---|---|
| DA server | Full DA bundles and execution payloads addressed by `DAHash` | Replay, watcher verification, fraud-proof inputs, browser replay | Correctness of bundle contents, availability enforcement, proof validity |
| Proof server | SMT inclusion and non-inclusion proofs, outbox inclusion proofs, receipt proofs | Light-client verification, browser inclusion checks, wallet state proofs | Full execution replay, payload availability, root correctness |
| Watcher | Recomputed batch roots and divergence alarms | Phase 1 alarm-only detection, Phase 2 fraud-proof emission | Data availability, truth of observations, on-chain enforcement in Phase 1 |
| Relayer | Proof-shaped external input as L1 account-blocks | External event ingestion for future `L1_RELAYED` domains | DA serving for the resulting execution bundle, custody, execution correctness |
| Browser or client | Verifies whichever layer of state it can access | Settlement floor, inclusion proofs, optional execution replay | Full execution correctness without DA bundle, runtime, and witnesses |

A proof server can help clients verify specific claims against committed roots. It is not the same as providing the whole execution bundle. A client with an outbox inclusion proof can verify that a message is in a committed `outboxRoot`. It cannot, from the proof alone, verify that the source domain correctly produced that message. That verification requires the DA bundle, the runtime, and the witnesses.

## 8. Browser and client verification levels

Browser-verifiable is not a single capability. It is a set of levels, each requiring different data and resources.

**Level 0: Settlement floor.** A browser can verify on-chain Settlement state: committed roots, batch status, conservation counters, the `processedOutbox` set, domain registry. This requires only L1 access. No DA bundle, runtime, or witnesses are needed. The settlement floor is verifiable by any browser able to read Zenon L1 state.

**Level 1: Inclusion proof verification.** A browser can verify an inclusion proof against a committed root if it has the relevant leaf payload and proof path. An outbox inclusion proof against a finalized `outboxRoot` is verifiable in this category. An SMT state proof against a `postStateRoot` is verifiable here if the path-native API is available. This requires a proof server, the on-chain root, or local proof material. It does not require the full DA bundle.

**Level 2: Full execution replay.** A browser can replay a batch if it has the DA bundle, the domain runtime, the witnesses, the correct `stfSpecHash`, a deterministic execution environment, and sufficient compute resources. SPEC §20 notes the WASM runtime is designed to be browser-suitable. But full replay still requires all of these inputs; without them, full replay is not possible.

**Level 3: Future proof-assisted verification.** A browser may verify validity-proof or fraud-proof outputs if future proof systems exist. `proofData` is reserved and must be empty in Phase 1. Phase 2 fraud-proof verification and Phase 3 validity-proof verification are reserved.

Browser-verifiable must always specify the verification level. A Level 0 verification claim is appropriate and supportable for any browser. A Level 2 claim requires DA and runtime access. Conflating them is the most common form of browser-verification overclaim.

## 9. Watcher replay dependency

A watcher replays a domain's execution to detect divergence between committed roots and recomputed roots. Replay requires: the canonical input data, the DA bundle, the SMT witnesses for every key read or written, the domain runtime (with the correct `stfSpecHash`), the prior state root, and a deterministic execution environment.

If any of these are unavailable, watcher replay fails. The watcher cannot recompute the `postStateRoot` without the witnesses. It cannot recompute the `outboxRoot` without the outbox messages. It cannot verify execution at all if the bundle is missing.

In Phase 1, a watcher can raise an alarm only if it can replay. The alarm-only model assumes the watcher has the data. SPEC §3 says watchers SHOULD download execution data bundles and reproduce results; "SHOULD" is normative aspiration, not a guarantee of availability.

A watcher's inability to replay is not proof that the executor was honest. It is proof that the watcher lacks the data. The two cases are operationally indistinguishable from the watcher's perspective and from external observers' perspectives.

No DA, no replay; no replay, no independent execution check.

## 10. Cross-domain message availability

This section connects to `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md`.

An `outboxRoot` alone is not enough to verify or process a cross-domain message. Settlement records the `outboxRoot` as part of the batch commitment, and the root proves that some set of messages was committed. But identifying which specific message is in the set, and processing it through `RelayMessage`, requires the message payload and the inclusion path.

If the message payload is included in the `RelayMessage` account-block submitted to Settlement, it inherits Zenon L1 data availability. A verifier with L1 access can retrieve the payload and the inclusion path from the account-block. This is the strongest availability case for cross-domain messages.

If the message payload lives only in DA bundles, retrieval depends on the DA serving path. A destination domain or browser attempting to verify the message inclusion proof needs the payload, not just the root. Phase 1 DA serving is best-effort; if the bundle is unavailable, the inclusion proof cannot be reconstructed or verified.

Settlement's `processedOutbox` set prevents replay of `RelayMessage` operations by tracking unique `outboxId` values. It does not serve missing payloads or recover lost inclusion paths.

An outbox root proves there is a committed set; the payload and path prove which message is in it.

## 11. Proof-shaped external data availability

This section connects to `04_PROOF_SHAPED_DATA_BOUNDARY.md`.

A Bitcoin SPV proof is verifiable only if the headers, the transaction, the Merkle branch, and the confirmation data are available. A Bitcoin SPV STF that receives just a hash commitment to these objects, with the actual payload unavailable, cannot run the verification logic. The proof-shaped property exists only when the proof is present.

Ethereum proofs may be larger than Bitcoin proofs. Sync committee signatures, finalized checkpoint roots, and Merkle-Patricia trie proofs together may exceed account-block data limits, requiring compression, chunking, or DA references. If the relay protocol references payloads stored elsewhere rather than posting them directly to L1, the STF's verification depends on retrieving the referenced data.

If relayed proof data is directly posted to Zenon L1 account-blocks (within `MaxDataLength`), it inherits Zenon L1 data availability. If only a commitment or reference is posted and the payload lives in a DA bundle or external storage, STF verification depends on retrieving that payload. The availability boundary is at the line between "posted to L1" and "referenced from L1."

Relayer submission is transport; DA availability is retrieval.

A proof that cannot be read cannot be verified.

## 12. `EXTERNAL_OBSERVED` availability

This section connects to `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`.

`EXTERNAL_OBSERVED` data typically lives in DA bundles, not directly in L1 account-blocks. The executor commits the observations to `inputRoot` and publishes them in the DA bundle. The on-chain commitment is the `inputRoot` and the `DAHash`; the actual observed values are off-chain.

Replay of an `EXTERNAL_OBSERVED` domain requires the observed payloads. A watcher attempting to verify that the executor processed the committed observations correctly needs the actual observation data, not just the hash. The same is true for browser replay.

SPEC §6.1 requires that L2 state be reconstructible from the committed inputs and bundle alone, without access to the external system. This places a strong dependency on bundle availability. If the bundle is unavailable, the external system cannot be queried as a fallback (and even if it could, the executor's observations may no longer match the current state of the external system). The weaker, non-L1 DA guarantee must be disclosed per SPEC §6.1 and §20.

Availability still does not prove external truth. A retrievable observation is replayable, but the observation itself may have been false, stale, or incomplete (see `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md` for the full external-truth boundary).

Unavailable observations are neither replayable nor truth-bearing; they are only committed by hash.

## 13. Sentinel relevance

Sentinel nodes are architecturally natural candidates for DA serving, proof serving, relaying, and watcher infrastructure. They run with connectivity and uptime expectations, and their existing role as best-effort DA servers in SPEC §3 and §20 makes adjacent roles operationally plausible.

But the spec is precise about what it assigns. SPEC §3 says Sentinels "SHOULD serve bundles and chunks addressed by `DAHash` best-effort." This is a best-effort support role, not a paid or protocol-enforced Sentinel market. No paid Sentinel DA market is specified. No Sentinel proof-serving market is specified. No Sentinel slashing or service bond is specified. No QSR role is assigned by the spec.

Sentinel service economics belong in `10_SENTINEL_SERVICE_BOUNDARY.md`, which will analyze the spec assignment vs architectural fit distinction in detail. For this document, the relevant point is that Sentinel/libp2p DA serving supports availability, but it is not an enforced DA guarantee.

Sentinel/libp2p serving can support DA availability, but Phase 1 does not make it an enforced DA guarantee.

## 14. Failure modes

| Failure | Type | Effect | Phase 1 handling |
|---|---|---|---|
| DA bundle never published | Availability failure | Watchers cannot replay; alarm-only watchers cannot alarm | No on-chain DA enforcement; reduces affected batch to reliance on executor honesty |
| DA bundle disappears before replay | Availability failure | Late verifiers cannot reconstruct execution | Best-effort serving only; no retention guarantee in Phase 1 spec |
| Proof server unavailable | Service liveness failure | Light clients cannot fetch proof paths | Client may use another server or fetch full bundle if available |
| Proof server serves invalid proof | Validity failure | Verification fails when client checks against the committed root | Client rejects the proof; protocol is not involved |
| Relay payload referenced but unavailable | Availability failure | STF cannot verify referenced proof; domain stalls or rejects depending on STF rules | Domain-specific handling; not a Settlement concern |
| Outbox payload unavailable | Availability failure | `RelayMessage` cannot be constructed; message cannot be relayed | Root remains committed, but the specific message cannot be processed |
| Observed payload unavailable | Availability failure | `EXTERNAL_OBSERVED` domain cannot be replayed | Hash commitment alone is insufficient; weaker DA must be disclosed |
| Watcher lacks runtime or witnesses | Replay failure | Cannot independently check executor | Alarm unavailable; not necessarily indicative of executor dishonesty |
| Browser lacks compute or runtime | Client limitation | Can verify Level 0 floor but not Level 2 replay | Must not claim full browser verification |
| Sentinel stops serving | Service liveness failure | Reduced availability | No Phase 1 slashing; no protocol penalty |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| `DAHash` proves data is available | `DAHash` commits to data; availability requires actual serving infrastructure |
| A root is enough for replay | Replay requires payloads, witnesses, proofs, runtime, `stfSpecHash`, and compute |
| Sentinels guarantee DA | Sentinel/libp2p DA serving is best-effort in Phase 1; no protocol enforcement and no paid market |
| Proof servers prove execution correctness | Proof servers serve inclusion paths against committed roots; execution correctness requires replay or future proof systems |
| Browser-verifiable means full replay | Browser verification has levels; the settlement floor is Level 0, full replay is Level 2 and conditional on data and runtime access |
| Watchers can always detect bad execution | Watchers need DA bundle, witnesses, runtime, and `stfSpecHash` to replay; without them, alarms are not possible |
| Relayed data always has L1 DA | Only directly posted relay data has L1 DA; referenced payloads depend on the DA path |
| Observed data is replayable from a hash | Observed payloads must be retrievable; a hash commitment alone is not replay-ready |
| DA serving is DA enforcement | Serving makes data retrievable; enforcement requires protocol penalties or rejection rules; Phase 1 has neither |
| Phase 1 DA is guaranteed | Phase 1 DA serving is best-effort and must be disclosed per SPEC §20 |
| `proofData` covers DA enforcement | `proofData` is reserved for Phase 3 validity proofs and must be empty in Phase 1 |
| Full browser replay is the default | Full browser replay requires substantial client resources and full bundle access; the default browser-verifiable layer is the settlement floor |

## 16. Open questions for Domain Settlement implementers

1. What is the exact DA bundle schema beyond the SPEC §20 framework? The spec defines the canonical bundle structure (per-input canonical input data, SMT witnesses, per-input `ExecutionResult`). Are there additional fields or extensions intended for future input sources?

2. What is the canonical `DAHash` preimage for non-Phase-1 input sources? Phase 1 covers `L1_NATIVE`; the bundle structure for future `L1_RELAYED` and `EXTERNAL_OBSERVED` domains may require additional or different fields.

3. What minimum DA retention period is required for Phase 1? EXECUTOR_DRAFT.md §14 requires the executor to retain pre-finalization bundles, but the post-finalization retention floor is unspecified. How long must a bundle remain retrievable?

4. What must an executor publish, where, and when? The spec specifies the canonical bundle encoding but does not pin a publication interface beyond "Sentinel/libp2p, best-effort."

5. What is the expected Sentinel and libp2p serving interface? Content-addressed retrieval by `DAHash` is named; specific protocol details (chunk format, request semantics, fallback paths) are not in the current spec.

6. What proof-server APIs are required for SMT proofs, outbox inclusion proofs, receipt proofs, and absence proofs? `02_DOMAIN_VERIFICATION_LIMITS.md` Q-3 raises the canonical Settlement storage key layout question; this extends to the proof-server interface.

7. What path-native SMT APIs (`RootOfLeaves`, `ProveByPath`, `VerifyProofByPath`, `VerifyAbsenceByPath`) are required before browser proof verification is practical? This is prerequisite P-8 in EXECUTOR_DRAFT.md §18 and is not yet exported in the `merkle-state-root` branch.

8. How should clients discover DA servers and proof servers? Is there an intended directory, registry, or discovery protocol?

9. What happens if a batch finalizes but its DA bundle was never publicly retrievable? Phase 1 has no on-chain enforcement, but is there an intended off-chain or social mechanism for surfacing this failure?

10. What DA assumptions are required for Phase 2 fraud proofs? The Phase 2 watcher must reconstruct the bundle byte layout; what retention, redundancy, and serving guarantees support this?

11. Would future `DAMode` values reference external DA layers (Celestia, Avail, EigenDA, others)? If so, what are the trust assumptions and how are they disclosed?

12. Are DA and proof-serving roles expected to be protocol-recognized, app-level, Sentinel-provided, or purely off-chain infrastructure? The boundary between "best-effort support role" and "protocol-assigned service" is currently absent in the spec.

13. Is any service bond intended for DA or proof serving? If so, what asset (no QSR assignment is specified in the spec) and what enforcement mechanism?

14. What public metadata should disclose DA mode, retention assumptions, serving infrastructure, and replay requirements to users and integrators? SPEC §6.1 requires disclosure for `EXTERNAL_OBSERVED`; the broader disclosure model for all domains is less specified.

## 17. Summary

Project Zeno commits to execution data through roots and hashes. `DAHash` binds a batch to a specific bundle encoding. `inputRoot`, `outboxRoot`, and `postStateRoot` bind claims to committed structures. `proofData` is reserved for future validity proofs and must be empty in Phase 1. These commitments are necessary for replay, verification, and future enforcement.

They are not the same as availability.

`DAHash` is a commitment handle, not an availability proof. It tells a verifier what to look for; it does not guarantee that the verifier will find it. A bundle that is committed but never published yields a `DAHash` that no one can match against actual data. A bundle that is published and then disappears yields a `DAHash` that no one can replay against. In both cases, the commitment is intact and the verification surface is broken.

Phase 1 DA and proof serving are best-effort support infrastructure. The executor publishes the bundle. Sentinel and libp2p nodes serve it on a best-effort basis. There is no on-chain DA enforcement, no service bond, no slashing, and no protocol penalty for unavailability. The limitation must be disclosed per SPEC §20.

Watchers, browsers, and clients can verify more when more data is available. The settlement floor is universally verifiable. Inclusion proofs against committed roots require the leaf payload and the proof path. Full execution replay requires the DA bundle, runtime, witnesses, `stfSpecHash`, and compute. Each level has different prerequisites; the highest level is conditional, not default.

Therefore:

Commitment is not availability.
Availability is not validity.
Serving is not enforcement.
Proof serving is not execution verification.
Browser verification has levels, and each level must be specified.
Watcher replay depends on DA, runtime, witnesses, and `stfSpecHash`.
Sentinel service fit is not Sentinel protocol assignment.

Do not collapse them.
