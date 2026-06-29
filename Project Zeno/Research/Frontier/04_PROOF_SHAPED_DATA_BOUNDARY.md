**Status:** Frontier boundary document
**Phase status:** Mixed; proof-shaped external inputs are architecturally analyzed, while `L1_RELAYED` remains reserved under the Phase 1 profile
**Purpose:** Define what qualifies as proof-shaped data, what does not, and what a domain STF must verify before accepting external evidence
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Proof-Shaped Data Boundary

## 1. Why this document exists

The previous Frontier documents establish three foundations. `01_RELAYER_BOUNDARY.md` defines the relayer as a transport role. `02_DOMAIN_VERIFICATION_LIMITS.md` defines what is verified at each layer and phase. `03_RELAYER_TRUST_MODELS.md` defines the trust models that apply under different data classes and relay configurations.

All three depend on a distinction that has not yet been given its own definition: the line between external data that a domain STF can verify and external data that is merely observed, attested, or reported. This document defines that line.

The distinction matters because it determines whether the relayer carries validity trust. If the submitted data is proof-shaped and the STF can verify it, the relayer is not trusted for validity. If the submitted data is an observation or an attestation without independent external-chain evidence, the relayer or observer carries validity trust regardless of how many parties submitted it.

Getting this wrong produces two categories of error. The first is calling observed data proof-shaped, which hides the trust placed in the observer behind a word that implies machine verification. The second is calling committee attestations equivalent to external-chain proofs, which hides the trust placed in the committee behind a word that implies consensus-level evidence.

This document defines proof-shaped data, lists what it is not, explains the boundary cases, and connects the classification to the execution-correctness and availability requirements from `02_DOMAIN_VERIFICATION_LIMITS.md`.

## 2. Definition of proof-shaped data

Proof-shaped data is external input that carries enough machine-verifiable evidence for a domain STF to check the claimed fact deterministically during execution.

Three properties make data proof-shaped:

The proof binds the claimed fact to a verifiable predicate. A Bitcoin Merkle inclusion proof binds the claim "this transaction was included in this block" to the block's Merkle root, which is deterministically computable from the block header. Internally, a finalized outbox inclusion proof plays a similar role: it binds the claim "this message was emitted in this batch" to the committed `outboxRoot` of a finalized Settlement batch. The binding is the proof. Without it, the claim is an assertion, not evidence.

The domain STF implements the verification logic for that predicate. A Bitcoin SPV domain STF implements header-chain validation (proof-of-work, linkage, difficulty), confirmation-depth enforcement, and Merkle inclusion checking. If the STF does not implement verification for a given proof type, the proof is inert: it is data that could be verified but is not, because no verifier runs.

The proof is available at execution time. The STF cannot verify a proof it cannot read. If the proof payload is referenced by hash but the payload itself is unavailable, the STF has a commitment but not evidence. Availability is a precondition for verification, not a substitute for it.

A proof-shaped object is not accepted because a relayer submitted it. It is accepted only if the STF verifies the proof according to rules pinned by the domain's `stfSpecHash`. Submission is transport. Verification is acceptance.

## 3. Required properties

For external data to qualify as proof-shaped under this document's definition, it must satisfy all of the following:

**Deterministic verifiability.** Any party running the same STF with the same input must reach the same accept/reject verdict. The verification cannot depend on external network access, timing, randomness, or operator discretion at verification time.

**Binding to a consensus root or cryptographic commitment.** The proof must connect the claimed fact to a root, hash, signature, or accumulator that is itself part of a verifiable chain of evidence. A Bitcoin header's `hashPrevBlock` binds it to its predecessor. A Merkle branch binds a leaf to a root. A threshold signature binds a message to a signer set. The binding is what makes the proof checkable rather than merely assertable.

**Self-contained replay.** After the proof data is posted to the Zenon L1 input stream or made available through the declared DA path, replay must not require access to the external system. A verifier replaying the domain's execution should be able to re-verify the proof from the committed data alone.

**Pinned verification rules.** The domain's `stfSpecHash` must pin the exact verification logic: which proof types are accepted, what confirmation predicates apply, what header validation rules are enforced, and what constitutes a valid binding. Unpinned or ambiguous verification rules make the accept/reject boundary executor-dependent, which undermines the determinism requirement.

## 4. What proof-shaped data is not

**An observation.** An executor reading a price from an API, a block height from an RPC endpoint, or a balance from an external node is observing, not proving. The observation may be accurate, but there is no machine-verifiable binding between the reported value and the external system's consensus state. The domain can replay the committed observation sequence for consistency, but consistency is not truth.

**A committee attestation by itself.** A threshold signature proves that a quorum of signers signed a message. It does not prove that the message content is true in the external world unless the attestation is accompanied by independently verifiable external-chain evidence. A committee attesting "block 800,000 has hash X" proves the committee signed that statement. Whether block 800,000 actually has hash X is a separate question, answered by the external chain's consensus, not the committee's signing ceremony.

**An API response.** A JSON payload from a web service, a price feed, a log line, or a screenshot is not proof-shaped. These are reports. They may be accurate, timestamped, and signed by the service provider, but they do not carry a binding to an external consensus root that the STF can independently verify.

**A hash commitment without the payload.** A hash proves that some payload existed if the payload is later available and hashes to the committed value. But a hash alone does not let a watcher or browser replay the proof. The hash is a commitment, not a proof. Availability of the underlying payload is a precondition for verification (see Section 10).

**A custody action.** Proving that a withdrawal was requested in L2 state is separate from releasing assets on another chain. The L2 withdrawal outbox message is proof-shaped within Settlement (it is verified via an outbox inclusion proof against a finalized `outboxRoot`). But the corresponding release of native BTC, ETH, or other external assets requires a custody mechanism (key management, threshold signing) that is outside the proof-shaped data boundary entirely.

**A claim that the executor applied the STF correctly.** In Phase 1, the executor attests to the batch roots. That attestation is not a proof in this document's sense. It is bonded attestation. The proof of correct STF application is what Phase 2 fraud proofs and Phase 3 validity proofs are designed to provide.

## 5. Bitcoin SPV as the clean example

Bitcoin SPV is the cleanest illustration of proof-shaped data because every component of the proof is machine-verifiable from the submitted data alone.

A Bitcoin block header contains the previous block hash, the Merkle root of the block's transactions, the timestamp, the difficulty target, and the nonce. A verifier can check header linkage (each header's `hashPrevBlock` matches the hash of the prior header), proof-of-work (the header hash satisfies the declared difficulty target), and difficulty adjustment rules (the target follows the expected schedule) without contacting the Bitcoin network.

A Merkle inclusion proof (a transaction and a set of sibling hashes forming a path from the transaction's leaf to the Merkle root in the block header) proves that the transaction was included in the block whose header carries that root. The verifier computes the path and checks that the result matches the committed root.

Confirmation depth can be pinned in the domain's `stfSpecHash`: the STF rejects Bitcoin inclusion claims that do not satisfy the required confirmation depth against the relayed header chain. This predicate is deterministic and reproducible.

These properties make Bitcoin SPV data proof-shaped under this document's definition. The relayer transports headers and Merkle proofs. The domain STF verifies them. Replay requires only the data already posted to Zenon L1. No Bitcoin node access is needed at replay time.

The boundary that must be enforced: Bitcoin SPV proves that an event occurred on the Bitcoin chain (a transaction was included in a block with sufficient confirmations). It does not solve BTC custody. Native BTC release requires a separate key-management or threshold-signing mechanism on the Bitcoin network. Proving a deposit is not the same as enabling a withdrawal. That custody boundary is defined in `09_CUSTODY_BOUNDARY.md`.

## 6. Ethereum proof paths and complications

Ethereum proof-shaped data is architecturally possible but substantially more complex than Bitcoin SPV.

Ethereum's consensus mechanism (proof-of-stake with a sync committee, Casper FFG finality, and the beacon chain) produces verifiable finality gadgets, but the verification logic required by an STF is more involved than Bitcoin's proof-of-work check. A domain STF verifying Ethereum state would need to verify sync committee signatures (BLS aggregate signatures over the beacon chain), confirm finalized checkpoint roots, verify state root inclusion in the beacon block, and then verify account, storage, or receipt proofs (Merkle-Patricia trie inclusion proofs) against the verified state root.

Each of these steps is machine-verifiable in principle. Sync committee signatures can be checked if the STF knows the current committee public keys. Finalized checkpoint roots provide a consensus-level anchor. State, storage, and receipt proofs rely on Ethereum's trie-based commitment structures. But the total verification surface is larger, the data requirements are heavier, and the STF complexity is significantly greater than Bitcoin SPV.

Several complications affect whether Ethereum event relay is practically proof-shaped:

The sync committee rotates periodically. The STF must either track committee transitions or receive them as part of the relay payload, adding data and verification overhead. The light-client protocol for following committee rotations is specified in Ethereum's consensus layer, but implementing it inside a domain STF is non-trivial.

State proofs (Merkle-Patricia trie proofs) can be large. Ethereum's trie structure uses variable-length paths with extension and branch nodes, making proofs larger and more complex than Bitcoin's binary Merkle proofs. Proof compression or ZK-based attestation may be needed to fit within account-block data limits.

If the system observes Ethereum data through an RPC endpoint or third-party service rather than verifying consensus proofs, the data is observed, not proof-shaped. An RPC response claiming "contract X emitted event Y at block Z" is an assertion from the RPC provider. Without the corresponding receipt proof anchored to a verified block root, the STF cannot independently verify it. That path belongs closer to `EXTERNAL_OBSERVED` and the oracle boundary defined in `06_EXTERNAL_OBSERVED_ORACLE_BOUNDARY.md`.

The exact Ethereum proof model is an open implementer question. Whether the intended path uses full light-client verification, ZK-compressed state attestations, or `EXTERNAL_OBSERVED` with executor-attested observations determines whether Ethereum event relay is proof-shaped (STF-verifiable), committee-attested (Model C from `03_RELAYER_TRUST_MODELS.md`), or observed (Model D). This question is listed in Section 13.

## 7. Committee attestations are not proofs by default

A threshold signature scheme (such as FROST, BLS multisig, or a k-of-n ECDSA scheme) produces a cryptographic object that is machine-verifiable. The STF can verify that the signature is valid under the declared public key set and threshold. In that narrow sense, a committee attestation is proof-shaped: the claim "this committee signed this message under this threshold rule" is deterministically checkable.

But the underlying external event is not proven by the signatures alone. If a committee of five signers attests that "Bitcoin block 850,000 has hash 0xabc...," the signature proves only that three (or however many meet the threshold) of those five signers signed that statement. Whether Bitcoin block 850,000 actually has that hash is a question about Bitcoin's consensus state, not about the committee's signing ceremony. A dishonest or compromised committee majority can sign a false statement that the STF will accept because the signatures are cryptographically valid.

Committee attestations become proof-shaped for the narrow claim about signer participation. They do not become proof-shaped for the broader claim about external-chain state unless accompanied by independently verifiable external-chain evidence (such as the actual Bitcoin headers and Merkle proofs that the committee's statement describes).

If a committee attests to external data and the domain STF also independently verifies the underlying proof, the committee attestation is redundant for validity (the proof is what matters) but may serve a liveness or coordination function. If the STF verifies only the committee signatures and not the underlying event, validity trust resides with the committee.

If the same committee that attests to events also controls custody keys for external assets, the architecture combines attestation trust and custody trust. That combined model belongs in `09_CUSTODY_BOUNDARY.md`, not here.

## 8. Observations are not proofs

An observation is a value reported by an actor who read it from an external source. The domain can commit the observation and replay it deterministically: given the same committed observation sequence, the same outputs are produced. But deterministic replay is a consistency property, not a truth property. The domain can verify replay consistency, not external truth, unless the observation includes a machine-verifiable proof.

This distinction separates `L1_RELAYED` from `EXTERNAL_OBSERVED` at the architectural level. SPEC §6.1 defines `EXTERNAL_OBSERVED` for sources where the executor reads the external system directly and commits the observations. The executor must pin a deterministic finality and confirmation predicate in the domain's `stfSpecHash`, commit the consumed inputs in `inputRoot`, and publish them in the DA bundle. State must be reconstructible from the committed inputs and bundle alone, without access to the external system. But none of this makes the observation externally verifiable. The predicate controls what the executor is allowed to commit, not whether what the executor committed was true.

The practical consequence: an oracle domain using `EXTERNAL_OBSERVED` can report a price, a block hash, or a contract state. Replaying the domain produces the same result from the same committed inputs. But if the executor committed a false value (reported an incorrect price, fabricated a block hash), the replay produces the same false result. Phase 2 fraud proofs can verify disputed STF application against committed inputs, but they cannot prove that the inputs themselves were true observations of the external world.

Observed data is a fundamentally different trust class from proof-shaped data. Collapsing them under the same label hides the trust that the observer carries.

## 9. Proof verification versus execution correctness

This section restates a boundary from `02_DOMAIN_VERIFICATION_LIMITS.md` in the specific context of proof-shaped data.

A domain STF may contain verification logic that checks proof-shaped inputs: validating Bitcoin headers, checking Merkle inclusion, verifying committee signatures. That verification runs during execution, inside the executor. If the verification logic is correct and the proof is valid, the STF accepts the input. If the proof is invalid, the STF rejects it. This is input-level verification.

But in Phase 1, Settlement does not verify that the executor ran the STF honestly. The batch commitment containing the execution results rests on bonded executor attestation. A dishonest executor could claim to have verified a proof when it did not, or claim to have rejected a proof when it should have accepted it, and in Phase 1 there is no on-chain mechanism to challenge that claim.

Phase 2 fraud proofs address this by allowing a challenger to trigger on-chain replay of a disputed execution step. Phase 3 validity proofs may address it by requiring a cryptographic proof that the STF was applied correctly. But these are future phases. In Phase 1, the trust model is: the proof is verifiable by the STF, the STF is deterministic, but honest application of the STF is attested, not independently verified on-chain.

Proof-shaped data reduces relayer validity trust. It does not address execution-correctness trust, which is a separate layer handled by the phase-specific enforcement mechanism.

## 10. Availability requirements

Proof verification requires that the proof is available at execution time. After execution, replay verification requires that the proof remains retrievable.

For `L1_RELAYED` domains, directly posted relay data enters the Zenon L1 input stream through account-blocks. To the extent the proof payload is posted directly in account-block data, it inherits Zenon L1 data availability. Any node with L1 access can retrieve and re-verify the proof. This is the strongest availability model for proof-shaped data.

If proof objects exceed account-block data limits, the payload may be referenced by hash with the full data stored in a DA bundle or external storage. In that case, availability depends on the DA path, not L1 directly. Phase 1 DA serving is best-effort (Sentinel/libp2p, `DAMode=0`) and is not enforced on-chain. A referenced proof payload that becomes unavailable cannot be re-verified by watchers or browsers, even though the hash commitment remains on L1.

A hash commitment is not full proof availability. The hash proves that some payload existed at the time of commitment, but it does not by itself let a verifier replay the proof. A watcher replaying domain execution needs the actual proof object, not just its hash. A browser verifying the settlement floor (on-chain roots, conservation invariant) does not need the proof data, but a browser attempting full execution replay does.

These availability boundaries feed directly into `07_DA_AND_PROOF_SERVING_BOUNDARY.md`. The summary for this document: proof-shaped data that is available can be verified. Proof-shaped data that is committed by hash but unavailable is a commitment, not a verifiable proof.

## 11. Comparison table

| Input type | Machine-verifiable? | What the STF can verify | What remains trusted | Proper classification |
|---|---|---|---|---|
| Bitcoin header chain + Merkle inclusion proof | Yes | Header linkage, PoW, difficulty, confirmation depth, transaction inclusion | Liveness (someone submits); execution correctness (Phase 1 bonded attestation) | Proof-shaped |
| Ethereum receipt or state proof with verified consensus root | Yes, if the STF implements the full verification path | Sync committee signatures, finalized checkpoint, trie inclusion | Liveness; execution correctness; STF verification completeness for Ethereum's consensus path | Proof-shaped (if full verification path implemented) |
| Threshold committee signature | Signature is verifiable; underlying event is not | That the committee signed the message under the threshold rule | The truthfulness of the attested external event, unless independently proven | Committee attestation (proof-shaped for the narrow signer-participation claim only) |
| API price report or RPC response | No | Nothing beyond format validity | The truthfulness of the reported value; observer honesty | Observed data |
| Executor observation log | No (committed observations are replayable, not verifiable against external truth) | Replay consistency of the committed sequence | Observer/executor honesty for the original observation | Observed data |
| Hash pointer to unavailable payload | The hash itself is verifiable; the payload is not accessible | That a payload with this hash was committed | Availability of the payload for actual verification or replay | Commitment only (not verifiable without the payload) |
| Custody release transaction (e.g. BTC withdrawal signing) | Not as proof-shaped input | Nothing; custody actions are outside the domain STF's verification scope | The custodian or signing committee controlling external assets | Custody (outside the proof-shaped boundary) |

## 12. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Any relayed data is proof-shaped | Only data carrying machine-verifiable evidence bound to a consensus root or cryptographic commitment is proof-shaped |
| A committee signature proves the external event | It proves the committee signed the message; the underlying event is trusted unless independently proven by external-chain evidence |
| A hash is enough for replay | A hash is only useful for replay if the full payload is available; a hash without the payload is a commitment, not a proof |
| Bitcoin SPV solves BTC withdrawals | SPV proves Bitcoin events; native BTC release requires a custody or signing mechanism outside the proof boundary |
| Phase 1 verifies proofs on-chain | Phase 1 execution correctness relies on bonded executor attestation; Settlement does not replay the domain STF |
| Oracle reports are proof-shaped | Oracle reports are observed or attested; they become proof-shaped only if paired with a machine-verifiable proof system |
| Ethereum event relay is automatically proof-shaped | It depends on whether the STF implements the full consensus and inclusion verification path; RPC observations are not proof-shaped |
| Proof-shaped data removes all trust assumptions | It reduces relayer validity trust; liveness, availability, execution-correctness, and custody assumptions remain |

## 13. Open questions for Domain Settlement implementers

1. For Ethereum event relay, is a machine-verifiable proof scheme (light-client header chain with sync committee verification, or ZK-compressed state attestation) intended? Or does the Ethereum path use `EXTERNAL_OBSERVED` with executor-attested observations? The answer determines whether the Ethereum trust model is proof-shaped or observed.

2. What is the maximum proof payload size that can fit in a single account-block? For proof objects exceeding `MaxDataLength` (16 KiB), what chunking, compression, or DA-reference scheme is intended?

3. For committee-attested relay models, is there an intended threshold scheme (FROST, BLS multisig, k-of-n ECDSA)? If so, what are the trust assumptions for committee composition and rotation?

4. Should proof-shaped verification rules be pinned exclusively in `stfSpecHash`, or is there a role for on-chain configuration parameters that can be updated through the runtime upgrade path?

5. For Bitcoin SPV, are there intended bounds on the relay payload format (raw headers vs. compressed headers, full Merkle branches vs. compact proofs)?

6. Is there an intended boundary between proof-shaped `L1_RELAYED` and observed `EXTERNAL_OBSERVED` for chains that offer partial proof paths (e.g., chains with finality gadgets but no easily verifiable light-client protocol)?

7. What verification properties must a proof-shaped domain STF satisfy for Phase 2 fraud-proof compatibility? Does the fraud-proof referee need to re-run the proof verification logic, and if so, are there constraints on the verification's gas cost or determinism requirements?

8. For proof payloads served through DA rather than posted directly to L1, what minimum availability evidence is required before an executor may accept the proof as input?

## 14. Summary

Proof-shaped data is the boundary where external input can become verifiable evidence inside a domain STF. But that boundary holds only under strict conditions.

The proof must carry machine-verifiable evidence binding the claimed fact to a consensus root, hash, or cryptographic commitment. The domain STF must implement the verification logic for that binding, pinned by `stfSpecHash`. The proof must be available at execution time and retrievable for replay. And in Phase 1, the executor must honestly apply the STF, because Settlement does not verify execution correctness on-chain.

Proof-shaped data reduces relayer validity trust: the relayer transports evidence, and the STF checks it, so a malicious relayer submitting invalid proofs is rejected by the verification logic. But proof-shaped data does not remove liveness assumptions (someone must submit), availability assumptions (the proof must be retrievable), execution-correctness assumptions (Phase 1 is bonded attestation), or custody assumptions (proving an event is not the same as controlling assets).

The classification matters because it determines the honest framing for every external-data integration. Bitcoin SPV with header and Merkle proofs is proof-shaped. An Ethereum event verified through the full consensus and inclusion path can be proof-shaped. A committee attestation is proof-shaped for the narrow claim of signer participation, not for the underlying event. An oracle report is observed, not proof-shaped. A custody action is outside this boundary entirely.

Do not call data proof-shaped unless the STF can verify it. Do not call verification complete unless the executor honestly applied the STF under the active phase. Do not call the system custody-capable because it can verify events. These are separate claims with separate evidence requirements, and collapsing them is the most common source of overclaims in external-data architectures.
