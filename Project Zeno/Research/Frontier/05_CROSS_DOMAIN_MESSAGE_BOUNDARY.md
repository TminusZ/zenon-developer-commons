**Status:** Frontier boundary document
**Phase status:** Mixed; cross-domain message structures are architecturally specified, while enforcement strength depends on the active phase
**Purpose:** Define what cross-domain messages prove, what Settlement guarantees, and what remains dependent on source-domain execution correctness
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Cross-Domain Message Boundary

## 1. Why this document exists

Cross-domain messaging is one of the most powerful primitives in the Project Zeno settlement architecture, and one of the most likely to be overclaimed. The previous Frontier documents define the relayer boundary (`01`) and verification limits (`02`). Later Frontier documents define relayer trust models and proof-shaped data. This document defines the boundary for messages that move between domains through Settlement-committed roots.

The core problem is that an outbox inclusion proof proves inclusion, not source-domain correctness. A message appearing in a committed `outboxRoot` proves it was part of the source domain's committed output for that batch. It does not prove that the source domain's executor honestly applied the STF, that the emitting contract's logic was correct, or that the message content is semantically valid for the destination domain. In Phase 1, source-domain execution correctness relies on bonded executor attestation. The inclusion proof rides on top of that attestation, not beside it.

This matters because "cross-domain messaging" sounds like it should carry the full correctness of both domains. It does not. It carries the correctness of the source domain's committed output (phase-dependent), the verifiability of the inclusion proof (deterministic), and the correctness of the destination domain's consumption logic (also phase-dependent). These are separate claims, and collapsing them hides the trust model.

The inventory rows that feed this document are: #12 (cross-domain asynchronous messaging), #40/#41 (outbox replay protection and at-most-once delivery), and portions of #13 (L2-to-L1 withdrawal via outbox).

## 2. Definition of a cross-domain message

A cross-domain message is an emitted domain output intended for another domain or for L1, committed into the source domain's outbox structure and made consumable by a destination through a Settlement-recognized inclusion path.

SPEC §17 defines the outbox message format. Each message contains a source `contractId`, `inputIndex`, monotonic `outboxIndex`, a `kind` (L2 delivery or L1 withdrawal), kind-specific target information (a destination `ContractID` for L2 delivery, or a recipient L1 address with asset and amount for withdrawal), and a payload. The per-input `outboxRoot` and the batch `outboxRoot` are Merkle roots over all messages ordered by `(inputIndex, outboxIndex)`, included in the batch commitment (SPEC §19).

Two message kinds exist in the current specification. L2 delivery routes a message to a contract on another domain. L1 withdrawal initiates the release of custodied assets back to an L1 address, subject to the withdrawal delay and conservation invariant (SPEC §18, §21).

Cross-domain messaging is asynchronous. SPEC §17.1 states that Phase 1 must not provide synchronous cross-contract calls. Cross-contract interaction must be expressed as asynchronous outbox messages processed in a later batch. There is no host function that executes another contract during the caller's execution (SPEC §8).

## 3. What Settlement guarantees

Settlement provides the canonical commitment infrastructure for cross-domain messages. Specifically:

Settlement records the batch commitment, which includes the `outboxRoot` (the Merkle root over all outbox messages in the batch). This root is on-chain and readable by any verifier. Settlement tracks batch status: `SUBMITTED`, then `FINALIZED` after the withdrawal delay elapses. Settlement enforces that `RelayMessage` operates only against `FINALIZED` batches (SPEC §17.3, §21). Settlement verifies the outbox inclusion proof: when `RelayMessage` is called, it checks that the supplied message and inclusion path are valid against the committed `outboxRoot`, and that the `domainId` and `batchId` match the batch whose root is used (SPEC §17.3). Settlement maintains the `processedOutbox` set and rejects any `RelayMessage` whose `outboxId` is already present, enforcing at-most-once delivery. For L1 withdrawals, Settlement additionally enforces the withdrawal delay, conservation invariant, and `MaxBatchWithdrawal` caps before releasing custodied assets.

Settlement does not know the semantic meaning of a message payload. It verifies inclusion and replay-protection structure, not application logic. Settlement does not replay the source domain's STF to confirm that the message should have been emitted. Settlement does not verify that the destination domain's consumption of the message is correct. In Phase 1, Settlement does not verify domain execution correctness on-chain for either the source or the destination.

## 4. What an outbox inclusion proof proves

An outbox inclusion proof demonstrates the following:

The message leaf is included in a specific committed `outboxRoot`. The inclusion path (a set of Merkle sibling hashes) is valid: recomputing the root from the leaf and the path yields the committed `outboxRoot`. The message was part of the source domain's committed output set for that batch. The batch has reached `FINALIZED` status according to Settlement's batch-status rules. The `domainId` and `batchId` in the relay match the batch whose committed root is used.

These are deterministic, verifiable claims. Any party with the message, the inclusion path, and the committed root can independently verify inclusion. The proof is reproducible and does not depend on trusting the party who submits the `RelayMessage`. `RelayMessage` is permissionless: anyone can submit a valid relay (SPEC §17.3).

The proof is structurally similar to the proof-shaped data defined in `04_PROOF_SHAPED_DATA_BOUNDARY.md`: it binds a specific claim (this message is in this outbox) to a committed root through a deterministic Merkle path.

## 5. What an outbox inclusion proof does not prove

The inclusion proof is bounded. It does not extend to claims that require source-domain execution correctness or destination-domain semantics.

It does not prove the source contract was bug-free. The emitting contract may have contained application-level errors, logic flaws, or unintended behavior that caused it to emit a message that should not have been emitted. The inclusion proof proves the message was committed, not that the contract logic was correct.

It does not prove the source executor honestly ran the STF in Phase 1. The `outboxRoot` is part of the batch commitment, which in Phase 1 rests on bonded executor attestation. A dishonest executor could commit a fabricated `outboxRoot` containing messages that the STF never produced. Phase 2 fraud proofs address this by allowing a challenger to dispute the batch. Phase 3 validity proofs may address it by requiring a cryptographic proof of correct execution.

It does not prove the destination domain must accept the message. The destination domain's STF defines its own consumption rules: authorization checks, payload validation, nonce ordering, and application-level logic. Inclusion in the source outbox is evidence of emission, not automatic permission to mutate destination state.

It does not prove the message has not already been consumed unless the consuming system checks replay protection. Settlement's `processedOutbox` set handles this for `RelayMessage`, but destination-domain application logic must also prevent duplicate processing of L2-delivered messages if the domain processes them internally.

It does not prove external asset custody or external-chain release. An L1 withdrawal outbox message triggers asset release from Settlement custody under the conservation invariant. But if the message represents a claim on assets outside the Settlement system (BTC, ETH, or other external-chain assets), the inclusion proof does not authorize or execute the external release. That is a custody boundary defined in `09_CUSTODY_BOUNDARY.md`.

It does not prove synchronous composability or shared memory between domains. The message was committed asynchronously. The destination domain processes it in a separate execution context, potentially many batches later.

## 6. Source-domain responsibilities

The source domain is responsible for the integrity of its outbox output. This means:

The domain STF must define valid message emission rules. A contract emitting an outbox message must satisfy the domain's emission constraints: correct `kind`, valid target, payload within `MaxOutboxPayloadSize`, proper nonce management, and gas coverage for the emission cost (SPEC §14.2).

Emitted messages must be committed into a deterministic outbox structure. The per-input `outboxRoot` and batch `outboxRoot` are Merkle roots with a canonical encoding and ordering (SPEC §27.4). The source executor commits these roots in the batch commitment.

The source domain must expose enough data for inclusion proof generation. The DA bundle must contain the outbox messages with sufficient structure for a third party to reconstruct the Merkle tree and produce inclusion proofs (SPEC §20).

Under Phase 1, the source domain provides bonded attestation for execution results. The `outboxRoot` is only as trustworthy as the executor's attestation that the STF was applied correctly. This is the fundamental Phase 1 limit on cross-domain message integrity.

## 7. Destination-domain responsibilities

The destination domain consumes messages from other domains. Consumption is not automatic: the destination STF must verify and enforce its own rules.

The destination must consume only messages admitted through the specified relay path. If Settlement performs `RelayMessage` verification, the destination receives a Settlement-admitted input and applies its own domain rules. If a future design delegates proof verification to the destination STF, the STF must verify the inclusion proof against the committed source-domain `outboxRoot`.

The destination must check message metadata: source `domainId`, `batchId`, message `kind`, destination target, nonce, payload hash, and any required replay-protection fields. A message targeting a different domain, carrying an unexpected `kind`, or presenting a stale nonce must be rejected.

The destination must enforce its own authorization and application logic. Inclusion in the source outbox is evidence of emission. It is not blanket authorization to mutate destination state. A validly emitted message may still be unauthorized, malformed, or semantically invalid from the destination's perspective.

The destination must track consumed messages to prevent duplicate execution. Settlement's `processedOutbox` set handles replay protection for `RelayMessage`. For L2-to-L2 delivery processed inside a domain, the destination must maintain its own consumption tracking.

Inclusion should be treated as evidence of emission, not as automatic permission. The destination's response to a validly included message is a destination-side application decision.

## 8. Ordering, replay, and duplicate consumption

Cross-domain messages inherit several ordering properties from the Settlement commitment structure, but they do not provide arbitrary synchronous ordering.

L1 momentum ordering and batch ordering create a canonical sequence after inclusion. Within a single source batch, outbox messages are ordered by `(inputIndex, outboxIndex)`. Across batches, the batch ordering is canonical. But inter-batch outbox ordering (a total order across batches for L2-to-L2 delivery) is deferred to Phase 2 (SPEC §17.3 informative note). In Phase 1, replay protection and at-most-once processing are the specified ordering guarantees.

Multiple messages from one source domain may require nonce-based ordering at the application layer. Messages from multiple source domains have only Settlement-level ordering (batch sequence), not source-level semantic ordering. The destination domain must define how it handles messages arriving from different sources with potentially different timing.

Replay protection operates at two levels. Settlement maintains `processedOutbox` with globally unique `outboxId = SHA3-256(domainId || batchId || inputIndex || outboxIndex)` and rejects duplicates (SPEC §17.3). Destination-domain application logic must additionally prevent duplicate processing for messages consumed through internal routing rather than through Settlement's `RelayMessage`.

If a destination rejects a validly emitted and validly included message (because it fails destination-side authorization, nonce checks, or application rules), that is a destination-side outcome. The message was emitted, was included, and was presented correctly, but the destination chose not to accept it. This is not a Settlement failure or a source-domain failure: it is the destination's own rule enforcement working as designed.

## 9. Cross-domain messaging versus bridges

Cross-domain messaging between Zeno domains and external asset bridges are different things with different trust models.

Cross-domain messaging within Settlement routes messages through committed outbox roots, verified by inclusion proofs, with replay protection and canonical ordering. No external-chain custody is required to move a message from one Zeno domain to another. The message is data, committed and routed through Settlement infrastructure. The assets involved are ZTS tokens held in Settlement custody and subject to the conservation invariant. Moving a message between domains does not require signing on an external chain, holding external private keys, or operating a multi-signature wallet.

An external bridge moves assets across chain boundaries. It involves custody: someone holds keys on the external chain and signs transactions to release assets. The bridge trust model includes relayer trust, custody trust, external-chain finality assumptions, and signing-committee honesty, depending on the bridge architecture. These are analyzed in `01_RELAYER_BOUNDARY.md`, `03_RELAYER_TRUST_MODELS.md`, and `09_CUSTODY_BOUNDARY.md`.

The overlap occurs when a cross-domain message represents a claim on external assets. An L1 withdrawal outbox message triggers release from Settlement custody, which is an internal operation. But if a domain's contract tracks wrapped external assets (wrapped BTC, for example), and a cross-domain message requests withdrawal of those wrapped assets, the external release still requires a separate custody mechanism on the external chain. The inclusion proof in Settlement does not authorize the Bitcoin transaction.

Cross-domain messaging should not be described as "bridging" without specifying the asset, custody model, source-domain correctness, destination-domain verification, and phase assumptions.

## 10. Cross-domain messaging versus shared state

Domains remain isolated execution environments. Cross-domain messaging is asynchronous message passing, not shared-state access.

A destination domain consumes committed outputs from a source domain. It does not read arbitrary state from the source domain's SMT. It does not synchronously call a function on the source domain. It does not share a state tree, a memory space, or a transaction context with the source domain. SPEC §17.1 is explicit: Phase 1 must not provide synchronous cross-contract calls; cross-contract interaction must be expressed as asynchronous outbox messages.

This is closer to an actor model or a message-queue architecture than to synchronous EVM-style composability, where contracts in different accounts can call each other within a single transaction. The Zeno model commits results first, then routes committed evidence to the destination in a later batch. The latency, finalization delay, and asynchronous nature are architectural features, not temporary limitations.

If synchronous cross-domain interaction is ever introduced, it would require preserving the single-input transition invariant (SPEC §17.1) and would be a substantial architectural change, not a configuration update.

## 11. Phase-specific enforcement boundaries

The strength of cross-domain message integrity changes across phases.

**Phase 1.** Settlement accepts batch commitments from bonded executors. The `outboxRoot` is part of the batch commitment and is only as reliable as the executor's honest application of the STF. The inclusion proof against that root is deterministic and verifiable. But the root itself is attested, not independently verified on-chain. A dishonest source-domain executor could commit a fabricated root containing messages the STF never produced. The destination domain's consumption of those messages would be based on a false root. The withdrawal delay provides time for detection, the per-batch withdrawal cap bounds immediate release risk, and the executor bond provides economic accountability.

**Phase 2.** Fraud proofs may allow disputed source-domain or destination-domain execution to be challenged. If a challenger demonstrates that the committed `outboxRoot` is incorrect (because the executor did not honestly apply the STF), the Phase 2 dispute path can trigger the enforcement action defined by the finalized fraud-proof design. This strengthens the trust model for cross-domain messages: the root is no longer solely attested but is challengeable under DA and honest-challenger assumptions. The exact scope of Phase 2 dispute coverage for cross-domain message correctness depends on implementation decisions not yet specified.

**Phase 3.** Validity proofs may provide cryptographic guarantees that the batch commitment, including the `outboxRoot`, is the correct result of applying the STF to the batch inputs. If implemented, this would provide the strongest correctness guarantee: the root is proven, not merely attested or challenged.

Phase 1 cross-domain messaging should not be described as fully verified or independent of executor honesty. The inclusion proof is verified; the root it proves against is attested.

## 12. Availability and message replay

Message replay requires more than a root.

Full replay of a cross-domain message flow requires: the message payload, the leaf encoding used to hash the message into the outbox tree, the inclusion path (Merkle sibling hashes), the source batch commitment containing the `outboxRoot`, and the destination domain's consumption record.

Roots alone are not enough. A verifier replaying the cross-domain flow needs the actual message content and proof path. If the payload is available on L1 (because the `RelayMessage` account-block contains it), it inherits Zenon L1 data availability. If the payload is served through DA bundles, availability depends on the DA path, which in Phase 1 is best-effort (Sentinel/libp2p, `DAMode=0`) and not on-chain enforced.

If the message payload becomes unavailable, the destination domain may be unable to verify and consume the message even though the committed root exists on-chain. The root proves that something was committed. The payload proves what was committed. Both are needed for verification.

This connects to `07_DA_AND_PROOF_SERVING_BOUNDARY.md`. The availability boundary for cross-domain messages is the same as for any DA-dependent data: commitment is not availability, and availability is not enforcement.

## 13. Browser verification boundary

A browser or light client can verify different layers of cross-domain messaging with different resource requirements.

The settlement floor is browser-verifiable from on-chain state. A browser can read the committed `outboxRoot` from the source domain's batch commitment, verify the batch status (`FINALIZED`), check conservation counters, and confirm the `processedOutbox` set for a given `outboxId`. This verifies the structural integrity of the message routing without replaying either domain.

Outbox inclusion proof verification is possible if the browser has the message payload and the Merkle inclusion path. The browser can recompute the Merkle root from the leaf and path, and compare it against the committed `outboxRoot`. This is a deterministic computation that does not require replaying either domain's STF.

Full verification of the cross-domain message flow, including confirming that the source domain's STF correctly produced the message and that the destination domain correctly consumed it, requires replaying both domains' execution. That requires the DA bundles for both domains, both domain runtimes, witnesses, the correct `stfSpecHash` for each domain, and sufficient compute resources.

Each level of verification answers a different question: "Is the root committed?" (settlement floor), "Is the message in the root?" (inclusion proof), "Did the source domain correctly produce the message?" (source execution replay), "Did the destination domain correctly consume it?" (destination execution replay). Do not claim "browser-verifiable cross-domain messaging" without specifying which of these questions the browser is answering.

## 14. Comparison table

| Claim | What can be verified | What remains assumed | Boundary |
|---|---|---|---|
| Message is included in source outbox | Deterministic Merkle inclusion proof against committed `outboxRoot` | Correctness of the `outboxRoot` (Phase 1: bonded attestation) | Inclusion proof is verifiable; root correctness is phase-dependent |
| Source domain honestly emitted message | Phase 2: challengeable via fraud proof; Phase 3: provable via validity proof | Phase 1: bonded executor attestation | Execution correctness is separate from inclusion |
| Destination consumed message exactly once | `processedOutbox` set prevents duplicate `RelayMessage`; destination tracks internal consumption | Destination application logic must enforce its own rules | Replay protection is Settlement-level for `RelayMessage`; app-level otherwise |
| Destination accepted message semantics | Destination STF applies its own authorization and validation rules | Destination execution correctness is phase-dependent | Inclusion is evidence, not automatic permission |
| Message payload is available | If posted to L1: Zenon L1 DA; if DA-served: depends on DA path | DA availability for payloads not directly posted to L1 | Commitment is not availability |
| External asset released | L1 withdrawal: Settlement releases under conservation invariant | External-chain assets: requires separate custody mechanism | Cross-domain messaging is not external-chain custody |
| Browser verified settlement floor | On-chain roots, batch status, conservation, `processedOutbox` | Settlement floor does not cover execution correctness | Floor verification is available to all browsers |
| Browser replayed full cross-domain flow | Possible with DA bundles, runtimes, witnesses, compute | DA availability, runtime access, and client resources | Full replay is conditional, not guaranteed |

## 15. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| Cross-domain messaging means shared state | It is asynchronous message passing through committed roots; domains do not share state trees or execution contexts |
| Outbox proof proves source execution was honest | It proves inclusion in a committed root; source execution correctness is phase-dependent |
| Destination must accept any included message | Destination STF verifies inclusion and applies its own authorization and consumption rules |
| Cross-domain messaging is the same as bridging | Internal message passing through Settlement does not require external-chain custody; external asset release is a separate problem |
| Phase 1 cross-domain messaging is fully verified | Phase 1 relies on bonded executor attestation for domain execution correctness; the inclusion proof is verified, the root it proves against is attested |
| A root is enough for replay | Replay requires the message payload, leaf encoding, inclusion path, and DA availability |
| Browser can verify the full cross-domain flow | Browser verification depends on whether it verifies the settlement floor, the inclusion proof, or full domain execution; each requires different data and resources |
| Synchronous cross-domain composability is available | SPEC §17.1 prohibits synchronous cross-contract calls in Phase 1; all cross-domain interaction is asynchronous |

## 16. Open questions for Domain Settlement implementers

1. What is the exact encoding and canonical structure for the outbox Merkle tree? The batch `outboxRoot` construction over `(inputIndex, outboxIndex)` ordered messages is specified in SPEC §27.4, but the exact proof generation and verification interface for third-party consumers (including destination domains and browsers) needs explicit tooling documentation.

2. For L2-to-L2 cross-domain delivery, does the destination domain consume the message through Settlement's `RelayMessage` path, or does it have a separate internal consumption mechanism? If separate, what replay-protection structure must it maintain?

3. What inter-batch outbox ordering semantics are intended for Phase 2? SPEC §17.3 defers inter-batch total ordering to Phase 2. The design of that ordering affects how destination domains handle messages from the same source across multiple batches.

4. What is the maximum message payload size (`MaxOutboxPayloadSize`), and how does it interact with the destination domain's input processing limits? Large payloads may affect gas costs and DA requirements.

5. If a cross-domain message targets a contract that does not exist on the destination domain, what is the intended behavior? Is the message consumed (recorded in `processedOutbox`) and silently dropped, or is it rejected with a specific failure mode?

6. For Phase 2 fraud proofs, is the scope of disputable execution limited to single-domain batches, or can a challenger dispute cross-domain message flows end-to-end (source emission plus destination consumption)?

7. How should destination domains handle messages from a source domain whose batch was later invalidated (in Phase 2 fraud-proof scenarios)? If a source batch is rolled back after the destination has already consumed a message from it, what is the intended recovery path?

## 17. Summary

Cross-domain messaging is an architectural primitive of the Settlement layer. Messages are committed in source-domain outbox roots, verified by deterministic inclusion proofs, protected against replay by Settlement's `processedOutbox` set, and consumable by destination domains according to their own rules. This is a genuine capability with real value.

But its honest claim is bounded.

The inclusion proof is verifiable: any party with the message and the Merkle path can confirm that the message is in the committed `outboxRoot`. Settlement's replay protection is on-chain and permissionless. These properties hold regardless of phase.

The correctness of the source-domain execution that produced the `outboxRoot` is phase-dependent. In Phase 1, it relies on bonded executor attestation. In Phase 2, it becomes challengeable under fraud-proof assumptions. In Phase 3, it may be provable via validity proofs.

Payload availability is a precondition for verification and replay. A committed root without an available payload is a commitment, not a verifiable proof. DA availability for message payloads depends on whether the data is posted directly to L1 or served through the DA path.

Destination-domain consumption is governed by the destination's own rules. Inclusion in the source outbox is evidence that the message was emitted. It is not automatic authorization to mutate destination state.

External asset release remains a separate custody boundary. Cross-domain messaging within Settlement does not require external-chain custody to route messages. But if a message represents a claim on assets outside Settlement, the external release requires a separate mechanism.

Synchronous composability is not available. Cross-domain messaging is asynchronous message passing through committed roots, not shared state or synchronous function calls.

Do not collapse these separate claims into a single statement that "cross-domain messaging is verified." The accurate framing specifies what is verified (inclusion), what is attested (source-domain correctness in Phase 1), what is conditional (availability), what is destination-governed (consumption logic), and what is entirely separate (external custody). Each claim has its own evidence requirements.
