**Status:** Frontier boundary document
**Phase status:** Mixed; `L1_RELAYED` is reserved under the Phase 1 profile
**Purpose:** Define what a relayer is, what it is not, and where the trust boundary sits
**Governing document:** `SPEC.md` governs on any conflict
**Commit discipline:** This file is not a roadmap, product claim, or implementation guarantee.

# Relayer Boundary

## 1. Why this document exists

Several Frontier use cases involve external data entering a domain through a relay path: Bitcoin SPV verification, Ethereum event relay, Sentinel-as-relayer, and any future domain declared with `inputSource = L1_RELAYED`. Each of those use cases depends on a clean account of what a relayer is, where its responsibility ends, and which other roles (executor, watcher, DA server, proof server, custodian) pick up from there.

Without that boundary, two errors become easy to make. The first is treating relayer submission as equivalent to creating validity: claiming "trustless Bitcoin interoperability" from relayer submission alone. The second is conflating the relayer with a bridge or custodian: claiming that posting a Bitcoin transaction proof is equivalent to releasing or controlling native BTC.

This document defines the boundary so those errors cannot enter subsequent Frontier documents.

The inventory rows that feed this document are: #8 (Bitcoin SPV verification domain), #20 (watcher role), #24 (Sentinel as relayer), and #44 (reorg and `confirmationDepth` boundary). The detailed Bitcoin SPV STF design belongs in `04_BTC_SPV_DOMAIN_PROTOTYPE.md`. Trust model analysis across relay configurations belongs in `03_RELAYER_TRUST_MODELS.md`. Sentinel service fit belongs in `10_SENTINEL_SERVICE_BOUNDARY.md`. This document covers the boundary itself. It describes the role boundary, not an activation plan.

## 2. Definition of a relayer

A relayer is an off-chain actor that observes an external L1 or proof source and submits proof-shaped data to Settlement as Zenon L1 account-blocks so a domain can consume that data deterministically.

The relayer's job ends at the L1 input stream. It does not execute the domain state transition. It does not hold the executor bond. It does not decide whether the submitted data is valid. Those responsibilities belong to the domain STF, which runs inside the executor and verifies the relayed input as part of its deterministic state transition.

The critical point is that proof-shaped relayed data becomes verifiable inside the STF. A Bitcoin header chain with embedded PoW and an SPV inclusion proof is not merely an observation: it is machine-checkable. The domain STF is the machine that checks it. The relayer delivers the material; the STF delivers the verdict.

## 3. What a relayer is not

| Role | Not a relayer because |
|---|---|
| Executor | Computes domain state transitions and submits batch commitments; holds the executor bond |
| Watcher | Replays executor output and raises alarms on divergence; does not submit external-chain proofs |
| DA server | Serves execution data bundles addressed by `DAHash`; downstream of domain execution |
| Proof server | Serves SMT inclusion and non-inclusion proofs to clients against committed roots |
| Custodian | Holds or signs external assets on another chain |
| Bridge | Coordinates asset movement across chains; implies custody and release |

The custody point deserves explicit statement. A relayer can submit evidence that a Bitcoin transaction occurred: the block headers, the transaction, and the Merkle path proving inclusion. A relayer cannot release native BTC. That release requires a key or a signing committee that controls funds on the Bitcoin network. BTC withdrawal is a custody and key-management problem that sits entirely outside the relayer boundary, regardless of how well the relay path works.

## 4. The `L1_RELAYED` inputSource

`L1_RELAYED` is a reserved architecture path for domains whose inputs originate as account-blocks posted to Zenon L1 by relayers and then verified by the domain STF. It is not activatable under the Phase 1 profile.

Under the Phase 1 profile, only `L1_NATIVE` may be used. `L1_RELAYED` and `EXTERNAL_OBSERVED` are reserved, and Core must reject domains selecting those input sources while the Phase 1 profile is in force (SPEC §6.1).

The `inputSource` field reserves the `L1_RELAYED` path, and the executor draft gives an informative Bitcoin example. Activation, exact domain format, and domain-specific STF rules remain future work.

For a future `L1_RELAYED` domain, the intended model is:

Relayed inputs enter the Zenon L1 input stream through account-blocks. Directly posted relay data inherits Zenon L1 data availability. Relayed inputs receive a `globalInputIndex`, enter the canonical momentum order fixed by L1, and are subject to the same contiguity enforcement as any other input (SPEC §4.4, §4.6). For proof objects that fit in account-block input limits, no separate DA path is needed for the relayed input itself. Larger proof sets may require compression, chunking, or DA references. The domain STF, not a separate trusted oracle, establishes whether each relayed datum extends the canonical external view.

Replay after the fact does not require access to the external chain. Because the relayed data has been posted as L1 account-blocks, a verifier can reconstruct domain state from those blocks alone, without querying Bitcoin or Ethereum. This is the property that makes `L1_RELAYED` significantly different from a live data feed and closer to a light-client input model.

## 5. Proof-shaped data vs observed data

These two data classes have fundamentally different trust positions, and blurring them is one of the most common ways relay analysis goes wrong.

**Proof-shaped data** includes enough machine-verifiable evidence for the domain STF to check validity independently. A Bitcoin block header chain carries proof-of-work that any implementation of the Bitcoin consensus rules can verify. An SPV Merkle branch proves a transaction was included in a block with a verifiable Merkle root. A finalized outbox inclusion proof proves a message was committed in a Settlement batch. In each case, the domain STF can reject invalid data without trusting the relayer.

**Observed data** is selected or reported by an actor such as an executor reading a price feed or an oracle querying an external API. It can be replayed for internal consistency: given the same committed observation sequence, the same outputs will be produced. But consistency is not proof. The domain cannot verify that the observed value was correct at the moment of observation unless the observation itself includes a machine-verifiable proof.

`L1_RELAYED` is architecturally designed for the proof-shaped side. SPEC §6.1 frames `L1_RELAYED` as a light-client-shaped path using headers and inclusion proofs rather than whole external chains. `EXTERNAL_OBSERVED` belongs to the observed-data side, where the trust model is executor-attested input selection rather than STF-verified proof. These two paths must not be conflated in documentation or architecture.

## 6. Relayer trust model

When a domain uses `L1_RELAYED` and the STF verifies the relayed proof, the trust model for the relay path is:

The relayer carries liveness risk but not validity trust. A malicious relayer can submit invalid data, but the STF rejects it under the domain's validity rules. A malicious relayer can also withhold data: if no relayer submits a Bitcoin block, the domain does not see it. This is a censorship risk, not a validity risk.

Permissionless relay changes the liveness model. It does not remove the requirement that someone submit the data. Because relaying is permissionless and carries no bond requirement, anyone can run a relay for a `L1_RELAYED` domain. If at least one honest relayer submits the correct data, the domain sees it and the STF processes it. The liveness assumption shifts from "the designated relayer is honest" to "at least one participant in an open relay market submits the correct data." That is a meaningful improvement, but it is an assumption about market participation, not a protocol guarantee.

Do not describe permissionless relay as defeating withholding. Permissionless relay mitigates liveness censorship if at least one honest relayer submits the data. A domain with no active relayers receives no external input, regardless of how open the relay protocol is.

The force-inclusion property of Zenon L1 applies to relay-submitted account-blocks just as it applies to user-originated inputs: once a relayed account-block is included in a confirmed momentum, the executor cannot skip it (SPEC §4.2, §4.6). This provides censorship resistance at the Settlement input level, but it presupposes that the relay-submitted block was included in the first place.

## 7. Relayer vs watcher

These two roles are easy to conflate because both are off-chain actors that monitor external state. They are logically distinct.

The watcher runs the same execution pipeline as the executor: it consumes the canonical input stream, applies the domain STF, produces `postStateRoot` computations, and compares them against the committed batch roots. In Phase 1 the watcher is alarm-only: it raises a flag when its computed root diverges from the executor's committed root, but there is no on-chain channel to act on that alarm. The Phase 2 fraud proof harness adds that channel. The watcher does not submit external-chain proofs. It re-executes what the executor executed.

The relayer submits external proof-shaped data into the Settlement input stream. It does not recompute the executor's state transition. It does not use committed batch roots as part of the relay role and does not alarm on executor divergence. It is not running the STF.

A single physical node could run both a relay path (for an `L1_RELAYED` domain) and a watcher path (for any domain). Running both on one machine is an operational choice. Conflating the roles is a design error. The relay path produces L1 account-blocks carrying external data; the watcher path produces alarm signals derived from re-executing the executor's own input sequence.

EXECUTOR_DRAFT.md §12 frames the relay as a thin source-to-L1 data path, not as an STF runner or state holder.

## 8. Relayer vs executor

The executor and the relayer are defined by what they compute and what they commit.

The executor consumes the domain's canonical input stream, applies the STF to each input in order, produces `preStateRoot`, `postStateRoot`, receipt root, event root, outbox root, and `AssetFlowSummary` for each batch, constructs the DA bundle, and submits the batch commitment to Settlement. It holds an executor bond sized to cover `MaxBatchWithdrawal`. In Phase 1, correctness of per-account balances relies on executor honesty.

The relayer only posts external input data to Zenon L1 as account-blocks. It does not compute domain state. It does not post a batch commitment. It does not hold the executor bond by virtue of relaying. If the domain STF verifies the relayed proof, the relayer carries no validity trust in the state output; that trust (or its absence) sits with the executor's attestation and, in Phase 2, with the fraud-proof enforcement chain.

A single operator could run both the relay role and the executor role for the same domain. That operational choice does not collapse the roles: the relay path produces input data, and the executor path processes that same data along with all other domain inputs.

## 9. Relayer vs DA server and proof server

Three distinct infrastructure roles become relevant once a domain processes external data. All three are downstream of execution in different ways. None of them is a relayer.

The DA server serves execution data bundles addressed by `DAHash`. The executor publishes the bundle after computing a batch; the DA server (Sentinel nodes or libp2p peers in Phase 1) makes it retrievable so watchers and browsers can replay execution. DA serving is best-effort in Phase 1 and not on-chain enforced. The DA server does not create the committed roots; it makes the evidence for verifying those roots available.

The proof server serves SMT inclusion and non-inclusion proofs to clients querying specific L2 state keys against the committed `postStateRoot`. The witnesses for those proofs are in the DA bundle. A proof server materializes them for clients that do not wish to replay the full execution. It does not create the committed root; it serves proofs against it.

The relayer puts proof-shaped external input data into the L1 input stream before the executor processes it. It is upstream of execution, not downstream. The DA server and proof server operate on artifacts produced after execution. Mixing these up produces architecture diagrams where the relayer is responsible for state availability, which it is not.

## 10. Bitcoin SPV as the clean example

Bitcoin SPV is the natural boundary case for this document because it is the clearest informative example of `L1_RELAYED` in the EXECUTOR_DRAFT.md design notes (§12), and because it cleanly separates verification from custody.

The relay path posts Bitcoin block headers and transaction Merkle proofs to Settlement as Zenon L1 account-blocks. The domain STF, running inside the executor, verifies header linkage, proof-of-work, confirmation depth, and Merkle inclusion for each relayed input. After relay, state reconstruction requires only the data already on Zenon L1: no Bitcoin node access is needed at replay time. The relayer does not custody BTC. It does not hold keys. It does not release funds.

The phrase that belongs on this boundary is: **Verify Bitcoin; do not custody it.**

The boundary between verification and custody is not a gap to be filled later by improving the relay protocol. Custody of native BTC requires holding a private key or participating in a threshold signing scheme on the Bitcoin network. That is a separate problem from SPV verification, documented in `09_CUSTODY_BOUNDARY.md` and listed in the inventory as a negative boundary with no current spec support.

## 11. Reorg and `confirmationDepth` boundary

For an `L1_RELAYED` domain, the relayer submits data from an external chain. The domain STF must define finality and confirmation predicates that govern which external data is treated as canonical. For a Bitcoin SPV domain, this means pinning a minimum confirmation depth in the `stfSpecHash` so that the STF rejects Bitcoin inclusion claims that do not satisfy the required confirmation depth against the relayed header chain. That predicate is part of the domain design, not the relay protocol.

There is a parallel confirmation boundary on the Zenon L1 side. SPEC §4.3 requires that the executor consume inputs only from momenta at or below the confirmed momentum frontier. The executor must not include in a batch any input whose containing momentum is not yet confirmed. EXECUTOR_DRAFT.md §14 specifies that a reorg deeper than `confirmationDepth` is an L1 fault that transitions the executor to `HALTED`, requiring rollback of the cursor and state to the surviving height before re-deriving.

This reorg boundary is an executor and watcher safety constraint, not a relayer trust grant. The relayer submits data; the executor controls when that data enters a batch. A relayed Zenon account-block must satisfy the Zenon confirmation frontier before the executor consumes it. Separately, the domain STF must reject external-chain data that fails the domain's external finality or canonical-view predicate.

The `confirmationDepth` value for Zenon L1 consumption has no SPEC-fixed default. SPEC §4.3 specifies the requirement ("confirmed momentums") without fixing the depth. This remains an open implementation question (see Section 13).

## 12. Unsafe claims

| Unsafe claim | Correct framing |
|---|---|
| `L1_RELAYED` is active | `L1_RELAYED` is reserved under the Phase 1 profile; Core rejects activation while the Phase 1 profile is in force |
| Relayers make external data true | Relayers transport data; the STF verifies proof-shaped data when the required verifier exists |
| Relayers solve Bitcoin custody | Relayers can submit Bitcoin proofs; custody and withdrawal of native BTC remain a separate problem outside the relay boundary |
| Permissionless relay defeats withholding | Permissionless relay mitigates liveness censorship if at least one honest relayer submits the data; it does not guarantee someone will |
| Sentinel relayers are protocol-assigned | Sentinel nodes are architecturally positioned for the relay role under a future profile where `L1_RELAYED` is activated; no spec assigns them this role |
| Relayer equals watcher | A relayer submits external proof-shaped data into the input stream; a watcher replays executor output and compares roots |
| Relayer equals bridge | A relayer does not custody or release external assets; a bridge implies asset movement across chains |
| The relay trust model is the same regardless of data class | Proof-shaped data under `L1_RELAYED` allows the STF to reject invalid inputs; observed data under `EXTERNAL_OBSERVED` does not provide the same rejection mechanism |

## 13. Open questions for Domain Settlement implementers

1. What governance gate activates `L1_RELAYED` after the Phase 1 profile? Is it an administrator action, a spork, a governance contract, or a multisig decision? The answer determines the timeline for all `L1_RELAYED` Frontier work.

2. What `confirmationDepth` policy should be pinned in `stfSpecHash` for a Bitcoin SPV domain? This is an open implementation question (inventory Q-1). The answer affects the SPV domain's liveness and its reorganization safety profile.

3. Are relayer-submitted external headers stored directly in the Settlement input stream as account-block data, or are large payloads referenced through DA bundles with only hashes committed to L1? The EXECUTOR_DRAFT.md §12 BTC example implies direct account-block submission, but the interaction with `MaxDataLength` (16 KiB per account-block) needs explicit resolution for larger proof sets.

4. Is there a canonical relay account-block format for `L1_RELAYED` domains beyond the informative BTC example in EXECUTOR_DRAFT.md §12? Or is format definition left entirely to the domain STF?

5. Should Sentinel nodes have any protocol-recognized relay role, or is relay purely permissionless infrastructure with no special Sentinel designation? The current spec names Sentinels only as best-effort DA servers (SPEC §3, §20). Any relay role would be speculative.

6. For Ethereum event relay: is a machine-verifiable proof scheme (a light-client header chain with merkle proofs, or a ZK-based attestation) intended, or does the Ethereum path degrade to `EXTERNAL_OBSERVED`? The answer determines whether Ethereum relay is proof-shaped (STF-verifiable) or observed (executor-attested), which changes the trust model substantially.

## 14. Summary

The relayer boundary is simple, but it must be enforced at every documentation step:

A relayer moves proof-shaped data from an external source into the Zenon L1 input stream. The domain STF verifies it. The executor computes the state transition. The watcher checks execution by replaying the same inputs. The DA server makes the execution artifacts retrievable. The custodian, if one exists, controls external assets on a separate chain.

Do not collapse these roles. A relay path and an executor can share a physical machine; they cannot share a definition. A relay path and a watcher path can coexist in the same binary; they perform entirely different functions.

A relayer can make external facts available to a domain. It cannot make unverifiable observations true. It cannot make custody operations trustless. It cannot make a reserved `inputSource` active under the current profile. It cannot guarantee that anyone will submit data when needed.

What a domain gains from a correctly designed relay path, if `L1_RELAYED` is activated under a future profile, is this: proof-shaped external data can enter the canonical input stream with L1-inherited ordering; directly posted relay data inherits Zenon L1 data availability; the STF has a deterministic basis for acceptance or rejection; and replay can rely on the data committed through the relay path. That is a meaningful property. It is not more than that.
