**Status:** Frontier boundary document
**Phase status:** Mixed; outbox relay proof structures are architecturally specified, while source-root correctness remains phase-dependent
**Purpose:** Define the proof path for cross-domain relay, including inclusion verification, replay protection, DA requirements, and remaining trust boundaries
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Cross-Domain Relay Proofs

## 1. Why this document exists

`05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md` defines the semantic boundary of cross-domain messages: what they are, what they mean, what Settlement guarantees, and what remains dependent on source-domain execution correctness, destination-domain rules, and DA availability. This document narrows the focus to the proof mechanics: the artifact that makes a cross-domain message processable through Settlement.

The message boundary and the proof boundary are related but distinct. A message is the object being routed (an `OutboxMessage` with kind, target, payload, and metadata). A relay proof is the evidence that the message is included in a committed `outboxRoot`. The proof is deterministic and machine-verifiable. The proof is meaningful only as far as the root it proves against is meaningful.

In Phase 1, source-root correctness rests on bonded executor attestation (see `02_DOMAIN_VERIFICATION_LIMITS.md` and `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md`). DA availability is required to construct and verify the proof (see `07_DA_AND_PROOF_SERVING_BOUNDARY.md`). The proof does not erase either dependency.

The relay proof proves membership in a committed root; it does not prove that the root was honestly produced.

The inventory rows that feed this document include: #12 (cross-domain asynchronous messaging), #13 (L2-to-L1 withdrawal via outbox), #40/#41 (outbox replay protection and at-most-once delivery), and rows discussing browser verification, DA bundles, or proof-serving roles.

## 2. Definitions

**Source domain.** The domain whose contract emits an outbox message and whose executor commits the message to the batch `outboxRoot`.

**Destination domain.** The domain that consumes the relayed message. For L2 delivery, this is another Project Zeno domain. For L1 withdrawal, the destination is Zenon L1 itself, processed by Settlement.

**Outbox message.** An emitted domain output encoded per SPEC §17.2: source `contractId`, `inputIndex`, monotonic `outboxIndex`, `kind` (L2 delivery or L1 withdrawal), kind-specific target, and payload bounded by `MaxOutboxPayloadSize`.

**Outbox leaf.** The canonical encoded outbox message used as a leaf in the per-input outbox Merkle tree.

**Per-input `outboxRoot`.** The Merkle root over all outbox messages produced by a single input, ordered by `outboxIndex`.

**Batch `outboxRoot`.** The Merkle root over all outbox messages in a batch, ordered by `(inputIndex, outboxIndex)`. Included in the batch commitment per SPEC §19.

**Finalized batch.** A batch whose status has transitioned from `SUBMITTED` to `FINALIZED` according to Settlement's batch-status rules (SPEC §21). `RelayMessage` operates only on finalized batches.

**Relay proof.** The artifact that allows Settlement (or, in future profiles, a destination STF) to verify that a specific outbox message is included in a committed `outboxRoot`. Logically combines the message, the Merkle inclusion path, the source `domainId` and `batchId`, and any batch metadata required to bind the path to the correct root.

**Inclusion path.** The sequence of sibling hashes from a leaf to a committed root.

**`RelayMessage`.** The permissionless Settlement method that consumes a relay proof and either delivers the message to a destination domain (for L2 delivery) or executes the L1 withdrawal release (for L1 withdrawal), per SPEC §17.3.

**`outboxId`.** A globally unique identifier for each outbox message: `SHA3-256(domainId || batchId || inputIndex || outboxIndex)` (SPEC §17.3).

**`processedOutbox`.** The Settlement-maintained set of processed `outboxId` values. Prevents duplicate `RelayMessage` processing.

**L2 delivery.** An outbox message with `kind = 0` (L2 delivery) targeting a contract on another domain.

**L1 withdrawal.** An outbox message with `kind = 1` (L1 withdrawal) targeting a recipient L1 address with `AssetID` and amount, subject to withdrawal delay and conservation invariant.

**Payload.** The application-defined data carried by an outbox message.

**Proof server.** A speculative service role that constructs and serves outbox inclusion proofs (and other inclusion artifacts) against committed roots. Not protocol-assigned.

**DA bundle.** The off-chain artifact for a batch containing canonical input data, witnesses, and per-input `ExecutionResult` (SPEC §20). Required for reconstructing relay proofs when the inclusion path is not directly available.

## 3. Relay proof object

A relay proof is logically composed of the following:

The source `domainId`. The source `batchId`. The `inputIndex` within that batch and the `outboxIndex` within that input. The message payload, encoded canonically per SPEC §27.4. The message `kind` (L2 delivery or L1 withdrawal). The kind-specific target: a destination `ContractID` for L2 delivery, or recipient L1 address with `AssetID` and amount for L1 withdrawal. The committed `outboxRoot` against which the proof is verified (read from the source batch commitment on-chain). The Merkle inclusion path (sibling hashes from leaf to root). The finalized batch reference (the batch commitment itself, anchored on Zenon L1). Any additional domain or batch metadata required to bind the proof to the correct root.

The exact wire format for serializing a relay proof may be implementation-defined or require additional tooling documentation. SPEC §17.3 and §27.4 specify the encoding of outbox messages and the `outboxId` construction. The on-the-wire format for the inclusion path and accompanying metadata depends on the proof-server interface or `RelayMessage` calldata layout, which is implementation territory.

A relay proof is not just a Merkle path; it is a Merkle path plus the metadata that binds the path to the intended batch, domain, and message.

## 4. What Settlement verifies on `RelayMessage`

Settlement verifies the following on every `RelayMessage` call, grounded in SPEC §17.3:

The source batch exists in the Settlement batch commitment chain for the named `domainId`. The source batch is `FINALIZED`. The supplied `domainId` and `batchId` bind to the same batch whose committed `outboxRoot` is used to verify the inclusion proof. SPEC §17.3 makes this binding normative: a relay presenting a valid proof against a mismatched domain or batch cursor must be rejected. The message leaf recomputes to the committed `outboxRoot` through the supplied Merkle path. The message kind is valid for the relay path being invoked. The `outboxId`, computed from `domainId`, `batchId`, `inputIndex`, and `outboxIndex`, is not present in `processedOutbox`. For L1 withdrawal messages, the withdrawal delay has elapsed (per SPEC §21), the conservation invariant remains satisfied after the release (SPEC §18.3), and `MaxBatchWithdrawal` is respected.

Settlement records the `outboxId` in `processedOutbox` upon processing, preventing replay. For L1 withdrawals, Settlement updates `pendingWithdrawalReserve` and `totalReleased` accounting per (domain, asset).

Settlement does not verify the following: source STF correctness (the executor's honest application of the STF is bonded-attested in Phase 1, not on-chain replayed); source contract business logic (the contract may have emitted a message in error without violating any domain rule that Settlement can check); destination contract correctness (Settlement does not execute destination domains during `RelayMessage`); external-chain custody (Settlement releases assets it custodies; assets on other chains are out of scope); full DA availability beyond the proof material supplied to `RelayMessage` (the inclusion path and the message are submitted with the call; broader DA is a separate concern); Phase 1 execution correctness in any form.

Settlement verifies inclusion against the committed root, not the correctness of the computation that produced the root.

## 5. What the relay proof proves

A valid relay proof proves the following:

This exact encoded message is included in this committed `outboxRoot`. The inclusion path is valid: recomputing the root from the leaf and the path yields the committed `outboxRoot`. The proof is bound to a specific source `domainId` and `batchId`. The batch has reached the finalized status required for `RelayMessage`. The message has not already been relayed through Settlement, if `processedOutbox` is checked at this call. For L1 withdrawals, the release path passed Settlement's custody and conservation checks.

A valid relay proof does not prove the following:

Source-domain execution was honest. Source contract logic was correct: the contract may have emitted the message under buggy or malicious application logic. Destination acceptance is required: a destination domain may receive a Settlement-admitted input and still reject it under destination-side rules. Payload was available before this relay: the payload arrives with the relay; broader availability for replay or audit is a separate concern. External asset release is possible outside Settlement: the relay can trigger Settlement custody release, not external-chain release. Synchronous composability exists: cross-domain interaction is asynchronous (SPEC §17.1).

Inclusion is a structural fact; correctness of emission is an execution fact.

## 6. Source-root correctness

The relay proof is checked against the committed `outboxRoot`. The root itself is produced by the source-domain executor. The proof's structural validity is independent of the root's correctness, which creates the most important nuance in this document.

**Phase 1.** Root correctness is bonded-attested. The source executor computed the STF, produced the `outboxRoot`, and committed it in the batch commitment. Settlement does not replay the source STF. Watchers may replay if the DA bundle is available and they have the runtime, witnesses, and `stfSpecHash` (see `07_DA_AND_PROOF_SERVING_BOUNDARY.md`). In Phase 1, watchers are alarm-only with no on-chain enforcement channel (see `02_DOMAIN_VERIFICATION_LIMITS.md`). A dishonest executor could commit an `outboxRoot` containing messages the STF never legitimately produced, and a relay proof against that root would be structurally valid.

**Phase 2.** Fraud proofs may make incorrect roots challengeable under DA availability and honest-challenger assumptions (see `02_DOMAIN_VERIFICATION_LIMITS.md`). The Phase 2 dispute path can trigger the enforcement action defined by the finalized fraud-proof design. The relay proof verification logic itself does not change; what changes is the strength of the underlying root.

**Phase 3.** Validity proofs may prove root correctness cryptographically if implemented. `proofData` is reserved for this purpose and must be empty in Phase 1 (SPEC §19). The relay proof would then sit on top of a validity-proven root rather than an attested one.

The relay proof can be perfectly valid against a dishonest root.

This is the core caution of this document. Structural validity of the proof and correctness of the underlying root are two different verification questions. The first is deterministic and machine-checkable. The second is phase-dependent. Anyone reading "the relay proof verified" must understand that this means the message is in the committed root, not that the root is correct.

## 7. Destination-domain acceptance

A valid relay proof is evidence of source emission, not automatic destination permission.

The destination domain must enforce its own rules independently of the relay proof's validity. Target matching: the relayed message must address a contract or recipient that the destination domain recognizes. Source-domain authorization rules: the destination may require that messages from certain source domains are allowed, or that specific source contracts have permission to act on destination state. Message kind: the destination should reject messages whose `kind` does not match its consumption path. Nonce and ordering rules: if the destination expects messages in a specific order from a source, out-of-order or skipped messages must be handled. Payload schema: the payload must conform to the format the destination contract expects. Application-level validation: any business-logic checks (authorization signatures, value bounds, time validity) apply at consumption. Duplicate-consumption prevention beyond what Settlement provides via `processedOutbox`, if the destination has additional internal routing paths.

If Settlement performs `RelayMessage` verification before delivery, the destination receives a Settlement-admitted input and applies its own domain rules. If a future profile delegates proof verification to a destination STF, that STF must verify the inclusion proof against the committed source `outboxRoot` directly. Either way, destination-side rule enforcement is separate from inclusion verification.

Relay proof validity is not destination-state authorization.

## 8. Replay protection and `processedOutbox`

Settlement maintains the `processedOutbox` set to prevent the same outbox message from being relayed more than once through `RelayMessage`.

The `outboxId` is defined in SPEC §17.3:

```
outboxId = SHA3-256(domainId || batchId || inputIndex || outboxIndex)
```

This binds the relay to the source domain, the batch, the input, and the outbox slot within that input. The four fields together identify a unique outbox message across all domains and all batches. Settlement rejects a `RelayMessage` whose `outboxId` is already in `processedOutbox`.

This mechanism gives at-most-once delivery through `RelayMessage`. A message can be relayed once; subsequent attempts are rejected before any state mutation. For L1 withdrawals, this prevents double-release of custodied assets. For L2 delivery, it prevents repeated processing through the Settlement `RelayMessage` path, while destination-side duplicate-effect prevention remains the destination domain's responsibility.

`processedOutbox` does not prevent application-level duplicate effects if the destination domain has additional internal routing paths. A destination contract that records consumption in its own state still needs to enforce its own idempotency: the same logical operation should not be applied twice even if Settlement processed the relay once.

The replay-protection scope is therefore narrower than total duplicate-effect prevention. Settlement guarantees: each `outboxId` is processed at most once through `RelayMessage`. Destination domains must guarantee: each logical effect on destination state happens at most once according to the destination's own application rules.

`processedOutbox` prevents duplicate relay; it does not replace destination application logic.

## 9. DA requirements for relay proofs

This section connects to `07_DA_AND_PROOF_SERVING_BOUNDARY.md`.

Constructing or verifying a relay proof requires the message payload, the leaf encoding, the inclusion path, the committed `outboxRoot`, the batch metadata, and the finalized batch status from on-chain Settlement state. Of these, the on-chain artifacts (root, metadata, status) are read directly from Settlement. The off-chain artifacts (payload, leaf encoding, inclusion path) must come from somewhere.

If the message and its inclusion path are posted directly in the `RelayMessage` account-block calldata, they inherit Zenon L1 data availability after submission. Any subsequent verifier with L1 access can retrieve the full relay material from the account-block. This is the strongest availability case.

If the message or proof path must be reconstructed from a DA bundle (because they were not included in the `RelayMessage` call, or for client-side verification before relay), reconstruction depends on DA availability. Phase 1 DA serving is best-effort (Sentinel/libp2p, `DAMode = 0`) and is not on-chain enforced (SPEC §20).

A committed `outboxRoot` without payload or path is insufficient for relay or verification. The root tells a verifier what to recompute against; it does not provide the leaf or the path.

An outbox root says a set exists; the relay proof says this message is in that set.

## 10. Proof serving

A proof server is a speculative service role that constructs and serves inclusion artifacts: outbox inclusion proofs, SMT state proofs, receipt proofs, absence proofs, and proof paths for browser or client verification.

A proof server is not protocol-assigned. The current spec does not name a proof-server role with specific obligations, fees, or service guarantees. A proof server is not the source of truth: the committed roots on Settlement are. A proof server constructs and serves the path material that allows clients to verify claims against those roots.

Invalid proofs are rejected by deterministic verification. A proof server that serves a malformed or incorrect inclusion path produces verification failures at the consuming verifier; the protocol does not need to enforce proof-server honesty because the verifier independently checks the proof against the committed root.

Proof-server liveness affects client convenience and relay construction: if a proof server is unavailable, a client must either find another server, fetch the data from the DA bundle directly, or wait. Proof-server liveness is not the same as Settlement safety. Settlement safety is unaffected by whether a particular proof server is online.

A proof server serves evidence; it does not create the truth of the committed root.

## 11. L1 withdrawal relay proofs

L1 withdrawal is the special relay path that releases custodied assets back to L1 addresses.

Settlement verifies the following on a `RelayMessage` for an L1 withdrawal:

Inclusion of the withdrawal message in the finalized `outboxRoot` per the standard relay verification. Replay protection via `processedOutbox`. The withdrawal delay has elapsed since the batch was finalized (SPEC §21). The conservation invariant remains satisfied: `totalReleased + pendingWithdrawalReserve <= totalDeposited` per (domain, asset) (SPEC §18.3). The per-batch withdrawal cap `MaxBatchWithdrawal` is respected. The asset and amount fields in the message are well-formed. The recipient L1 address is valid.

The release boundary is precise. Settlement can release assets it custodies under the conservation invariant. Aggregate over-release is prevented on-chain: a domain cannot withdraw more than it has been deposited, regardless of executor behavior. Per-account correctness still depends on source-domain execution correctness in Phase 1: the source domain's contract is responsible for debiting the correct account when emitting the withdrawal, and Settlement does not verify that per-account accounting. External-chain asset release remains a separate custody problem: L1 withdrawal in this context means Zenon L1, not Bitcoin, Ethereum, or other external chains.

L1 withdrawal relay proves a withdrawal message exists in a finalized outbox; aggregate Settlement accounting bounds release, but per-account correctness remains phase-dependent.

## 12. L2-to-L2 relay proofs

For L2 delivery, the relay proof establishes that a source-domain message exists and has been included in a finalized source `outboxRoot`. Destination consumption semantics are not fully equivalent to L1 withdrawal, and several caveats apply.

Phase 1 specifies one WASM domain. True cross-domain L2-to-L2 delivery requires a second active domain, which is reserved under the Phase 1 profile (see `05_CROSS_DOMAIN_MESSAGE_BOUNDARY.md`). The outbox format, `RelayMessage` mechanics, and `processedOutbox` are specified in Phase 1, but the cross-domain destination is not present.

Inter-batch outbox ordering for L2-to-L2 delivery (a total order across batches) is deferred to Phase 2 (SPEC §17.3 informative note). Phase 1 specifies replay protection and at-most-once processing; ordering across batches is not pinned.

The destination-domain consumption path may require additional implementation detail beyond what is currently specified. Whether destination domains consume Settlement-admitted relay inputs, run their own inclusion verification, or use a hybrid mechanism is an open question (see Section 16).

Do not claim live L2-to-L2 messaging. Do not claim synchronous composability: cross-domain interaction is asynchronous in Phase 1 (SPEC §17.1) and any synchronous semantics would require explicit specification beyond what currently exists.

L2-to-L2 relay proof establishes source emission; destination processing is a separate execution step.

## 13. Browser and light-client verification

A browser or light client can verify a relay proof if it has the committed `outboxRoot` (read from on-chain Settlement state), the message payload, the inclusion path, the batch metadata (`domainId`, `batchId`), and the finalized batch status from on-chain state.

This is Level 1 inclusion proof verification per the `07_DA_AND_PROOF_SERVING_BOUNDARY.md` taxonomy: deterministic recomputation of a Merkle root from a leaf and a path, compared against the committed root. The browser confirms that the specific message is in the committed set.

What this verification does not confirm: source STF correctness (the source executor's honest application of the STF is not verified by the relay proof); destination execution correctness (the browser does not see how the destination processes the message); the full cross-domain flow (source emission, route through Settlement, destination consumption).

Full verification of the cross-domain flow requires replay of both source and destination domains. That means: the DA bundles for both batches, both domain runtimes, witnesses for both executions, the correct `stfSpecHash` for each domain, and sufficient compute. This is Level 2 execution replay, with substantially higher resource requirements.

Browser relay-proof verification answers "is this message in this root?" not "was the whole cross-domain flow correct?"

## 14. Failure modes

| Failure | Type | Effect | Boundary |
|---|---|---|---|
| Invalid Merkle path | Proof validity failure | Relay rejected at verification | Deterministic verification catches it |
| Message not in committed root | Proof validity failure | Relay rejected | Structural proof failure |
| Batch not finalized | Finality / status failure | Relay rejected | Settlement status gate |
| `domainId` or `batchId` mismatch | Binding failure | Relay rejected | SPEC §17.3 normative check |
| Duplicate `outboxId` | Replay failure | Relay rejected | `processedOutbox` catches it |
| Valid proof against dishonest root | Execution correctness failure | A message that should not have been emitted can be relayed if the root is finalized in Phase 1 | Phase-dependent source correctness; Phase 2 fraud proofs may address it |
| Payload unavailable | Availability failure | Proof cannot be constructed; off-chain verification fails | DA and proof-serving boundary |
| Proof server unavailable | Service liveness failure | Client or relayer must find another source or use the DA bundle | Not a Settlement failure |
| Destination rejects message | Destination semantics failure | Message is not consumed by destination | Destination-domain rules |
| External asset release expected | Custody mismatch | Relay proof cannot release native external assets | Custody boundary |
| Browser lacks DA bundle or runtime | Client limitation | Can verify inclusion but not full cross-domain flow | Verification level boundary |
| Conservation invariant would be violated | Settlement-level safety failure | L1 withdrawal release rejected | SPEC §18.3 enforced |
| `MaxBatchWithdrawal` exceeded | Withdrawal cap failure | L1 withdrawal release rejected | Per-batch cap protection |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Relay proof proves source execution correctness | Relay proof proves inclusion in a committed root; root correctness is phase-dependent |
| Relay proof makes cross-domain messaging fully verified | Inclusion is verified; source execution correctness and destination acceptance are separate concerns |
| A valid relay proof means the destination must accept | Destination domain applies its own authorization, schema, and consumption rules |
| `processedOutbox` solves all duplicate effects | It prevents duplicate `RelayMessage`; destination applications may need additional consumed-message tracking |
| An outbox root is enough to relay | Relay requires the message payload, the inclusion path, and the bound batch metadata |
| Proof-server availability is part of protocol safety | Proof servers aid construction and clients; invalid proofs are caught deterministically; Settlement safety does not depend on any specific proof server |
| L2-to-L2 messaging is available in Phase 1 | Phase 1 specifies one WASM domain; true cross-domain delivery requires a second active domain, which is reserved |
| Relay proof is a bridge | Relay proof moves messages and routes asset release within Settlement custody; external-chain asset release is a separate custody problem |
| Browser relay-proof verification equals full flow verification | Browser verification of a relay proof is inclusion verification only unless the browser also replays both domains |
| A valid proof against a committed root means the root was honest | The proof may be structurally valid against a dishonest Phase 1 root; root correctness is bonded-attested in Phase 1 |
| Synchronous cross-domain composition is possible via relay | Cross-domain interaction is asynchronous per SPEC §17.1; relay proofs are processed asynchronously |
| Settlement verifies the destination contract's response to the message | Settlement verifies inclusion and replay protection; destination contract logic is a separate execution step |

## 16. Open questions for Domain Settlement implementers

1. What is the canonical wire format for a relay proof as submitted through `RelayMessage`? SPEC §17.3 specifies the verification logic and the `outboxId` construction; the calldata layout for the proof material itself may need explicit tooling documentation.

2. What is the exact outbox leaf encoding for the per-input and batch outbox trees? SPEC §27.4 specifies the `OutboxMessage` structure; the leaf encoding (whether the message bytes are hashed directly or wrapped in a leaf prefix) should be confirmed.

3. What is the canonical Merkle tree construction for the batch `outboxRoot` and the per-input `outboxRoot`? Specifically: hash function (`SHA3-256` per SPEC §13.5), tree padding strategy for sparse trees, and any domain-separation tags between input-level and batch-level roots.

4. What proof-server API should expose outbox inclusion proofs? Should it be content-addressed by `outboxId`, by `(domainId, batchId, inputIndex, outboxIndex)`, or both?

5. Is `RelayMessage` the only path for L2-to-L2 delivery, or can destination domains consume relay proofs through internal mechanisms in some future profile? This affects whether destination domains need to implement their own inclusion verification.

6. What destination-domain replay-protection structure is required beyond `processedOutbox`, if any? If a destination consumes a message through `RelayMessage` and also updates its own state, what duplicate-prevention rules apply at the destination?

7. How are failed destination deliveries represented? If `RelayMessage` succeeds but the destination's consumption logic rejects the message, is there an on-chain signal, or is the rejection purely destination-internal?

8. If a destination rejects a message, is the source `outboxId` considered consumed in `processedOutbox`? Or can the message be re-relayed later?

9. How should inter-batch outbox ordering be specified in Phase 2? Total ordering across batches for a single source domain, total ordering across source domains, or per-pair (source, destination) ordering?

10. How does a Phase 2 fraud-proof challenge handle a destination that already consumed a message from a source batch later proven invalid? Is rollback possible, or is the consumption considered final?

11. Are relay proof payloads always posted directly in `RelayMessage` account-blocks, or can they reference DA bundles by hash? If reference is allowed, what are the availability assumptions?

12. What browser proof format is expected for client-side relay-proof verification? Should the proof be a self-contained blob, or does the client fetch components separately?

## 17. Summary

A cross-domain relay proof is a membership proof. It proves that a specific encoded message is included in a committed source-domain `outboxRoot`.

Settlement verifies that membership proof on `RelayMessage`, binds it to a finalized batch via `domainId` and `batchId`, and prevents duplicate relay through `processedOutbox`. For L1 withdrawal messages, Settlement additionally enforces the withdrawal delay, the conservation invariant, and `MaxBatchWithdrawal` before releasing custodied assets. This is a real, deterministic, on-chain verification capability.

It is also bounded.

The relay proof does not prove that the source-domain executor honestly produced the `outboxRoot`. In Phase 1, root correctness is bonded-attested by the source executor's bond, the withdrawal delay, the per-batch withdrawal cap, and any watcher alarm channel. In Phase 2, root correctness may become challengeable under DA availability and honest-challenger assumptions. In Phase 3, root correctness may become provable through validity proofs. The relay proof verification logic does not change across these phases; what changes is the strength of the root.

The relay proof does not force destination acceptance. Destination domains apply their own authorization, schema, and consumption rules. A Settlement-admitted relay input is evidence of emission, not automatic permission to mutate destination state.

The relay proof does not solve DA. Constructing and verifying the proof requires the message payload, the inclusion path, and the batch metadata. Directly posted relay material inherits L1 DA; referenced material depends on the DA path. Phase 1 DA serving is best-effort.

The relay proof does not solve custody. L1 withdrawal in this Settlement context means Zenon L1 release from Settlement custody, governed by the conservation invariant. External-chain asset release (Bitcoin, Ethereum) requires separate custody mechanisms that the relay proof cannot provide.

Therefore:

Relay proof verification is inclusion verification.
Source-root correctness is phase-dependent.
Destination consumption is destination-governed.
Replay protection is Settlement-enforced for `RelayMessage`.
DA availability is required for proof construction and verification.
Custody remains outside the proof.

Do not collapse them.
