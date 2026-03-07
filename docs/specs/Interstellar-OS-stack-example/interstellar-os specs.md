# Interstellar OS
## Sovereign Verification Kernel Specification

**Status:** Published  
**Domain:** Zenon Ecosystem / Interstellar Protocol Suite

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Model](#2-system-model)
3. [Architecture Overview](#3-architecture-overview)
4. [Verification Kernel](#4-verification-kernel)
5. [State Model and Verifiable Snapshots](#5-state-model-and-verifiable-snapshots)
6. [Determinism Rules](#6-determinism-rules)
7. [Universal Claim Vocabulary](#7-universal-claim-vocabulary)
8. [Module Architecture](#8-module-architecture)
9. [Standard Modules](#9-standard-modules)
10. [Verification Pipeline](#10-verification-pipeline)
11. [Security Model](#11-security-model)
12. [Client Layer](#12-client-layer)
13. [Relationship to Protocol Specifications](#13-relationship-to-protocol-specifications)
14. [Conformance and Test Vectors](#14-conformance-and-test-vectors)

**Appendices**

- Appendix A: Glossary
- Appendix B: Design Non-Goals

---

## 1. Introduction

### 1.1 Purpose

**Interstellar OS is a deterministic coordination engine. It does not execute arbitrary programs or transactions. Instead, it interprets ordered coordination claims and derives protocol state through deterministic reducers.**

It derives shared protocol state by replaying claim-driven lifecycles of coordination objects. It is not a general-purpose operating system, a smart contract virtual machine, or a client application. The name reflects its role as the base execution environment for a participant's protocol activity, not kernel-level process management.

More precisely: Interstellar OS is the **sovereign verification kernel** for the Interstellar protocol suite. It ingests an ordered log of signed coordination claims produced by Commit Channels, verifies them against protocol rules implemented in deterministic reducer modules, and derives a cryptographically committed state root that any conformant implementation will independently reproduce from the same inputs.

The design inherits its philosophy from Bitcoin Core. The system's security comes from what it refuses to do. The kernel does not execute arbitrary code. It does not make protocol decisions. It does not run interfaces. It reduces a claim history to a state root and defends a signing boundary.

**The claim flow in brief:**

```
coordination claims → reducers → coordination objects → state root
```

Claims arrive ordered. Reducers interpret them deterministically. Coordination objects are the derived protocol state. The state root is the cryptographic commitment to that state. This is the entire system.

### 1.2 Architectural Position

```
┌─────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                     │
│   Wallets · Agents · Trading UIs · Analytics            │
└─────────────────────────────▲───────────────────────────┘
                              │
┌─────────────────────────────┴───────────────────────────┐
│                    PROTOCOL MODULES                     │
│   Interstellar Markets · Portal · Governance · Identity │
│   Each module = Claim Validator + Pure State Reducer    │
└─────────────────────────────▲───────────────────────────┘
                              │
┌─────────────────────────────┴───────────────────────────┐
│               INTERSTELLAR OS (this document)           │
│   Claim Verifier · Replay Engine · Reducer Host         │
│   State Store · State Root · Signing Boundary           │
└─────────────────────────────▲───────────────────────────┘
                              │
┌─────────────────────────────┴───────────────────────────┐
│                    COMMIT CHANNELS                      │
│   Ordered log of signed coordination claims             │
└─────────────────────────────▲───────────────────────────┘
                              │
┌─────────────────────────────┴───────────────────────────┐
│                     ZENON NETWORK                       │
│   Ordering · Consensus · Data Availability              │
└─────────────────────────────┴───────────────────────────┘
```

Each layer has a strictly bounded responsibility. Zenon orders. Commit Channels structures. Interstellar OS verifies and reduces. Protocol Modules interpret. The Application Layer consumes derived state.

The kernel has no knowledge of markets, bridges, or governance. It only knows claims, module interfaces, and the reduction loop.

### 1.3 The Core Invariant

The entire architecture is built on one invariant:

> **All shared protocol state must be derivable solely from Commit Channel claim history.**

State that cannot be derived from claims is local state (private keys, personal configuration). Local state is the participant's private concern and does not affect the `state_root`. Shared state that is not derivable from claims does not exist in this system.

### 1.4 Why a Verification Kernel Is Necessary

Zenon's ordering guarantee ensures all participants observe claims in the same sequence. Ordering alone does not determine:

- Whether claim signatures are valid.
- Whether payloads conform to protocol rules.
- Whether a proposed state transition is internally consistent.
- Whether a participant should authorize a response.

These checks require local, deterministic computation. The kernel performs that computation. Because the computation is deterministic and operates on shared ordered input, two conformant participants will always derive the same `state_root` for the same claim history under the same module versions.

### 1.5 Kernel vs. Client

The kernel is the deterministic verification engine. It is trusted, minimal, and auditable. It consists of the Claim Verifier, Replay Engine, Reducer Host, State Store, and Key Manager. The kernel boundary is the trusted computing base.

The client layer is everything built on top: wallets, agents, automation policies, storage services. The client layer is untrusted and communicates with the kernel only through the defined State API and Signing Boundary.

This is the same architectural distinction Bitcoin makes between its validation engine and wallet frontend.

### 1.6 The Core Architectural Principle: Separation of Ordering and Coordination

Most distributed ledger systems entangle two responsibilities in a single layer: ordering claims and interpreting what those claims mean. This entanglement forces protocol evolution to proceed at the speed of consensus — which is slow, socially costly, and prone to hard forks.

Interstellar OS separates these responsibilities deliberately and completely.

**Zenon handles ordering.** Zenon's consensus produces an agreed sequence of claims. Zenon has no knowledge of markets, governance, identity, or bridges. It decides: claim A comes before claim B. Nothing more.

**Interstellar OS handles interpretation.** The kernel receives the ordered claim stream and decides what those claims mean: which coordination objects they advance, which state transitions they produce, whether they are valid under the current protocol rules.

The consequence of this separation is that **protocol rules can evolve without changing the ordering layer.** A markets module upgrade, a governance rule change, a new Portal verification algorithm — all are expressed as new module versions, activated at a specific sequence position via the Governance Module. Zenon does not change. The kernel does not change. Only the reducer changes.

This makes Interstellar OS architecturally closer to an event-sourcing runtime than to a traditional blockchain. The ordered claim log is the event stream. Module reducers are the interpreters. Derived state is the materialized view. The `state_root` is the commitment over that view.

This design principle should be treated as a load-bearing constraint. Any change that causes Zenon to interpret claim meaning, or causes the kernel to encode protocol-specific logic directly, collapses the architecture back into the entangled model and forfeits this property.

### 1.7 Channels as the Unit of Execution and Scale

The channel-scoped replay model is not merely a correctness mechanism. It is the primary scaling primitive of this architecture.

Most distributed ledger systems treat the entire system as a single global state machine with a single global execution space. Scaling is applied as an afterthought — sharding, rollups, subnets — each of which introduces cross-partition complexity, asynchronous consensus, and execution receipts. The initial abstraction was wrong, and scaling retrofits are expensive.

Interstellar OS is built on a different foundation. The protocol is already partitioned by coordination log. Each channel is a first-class, independent, semantically meaningful execution partition. This is not a future optimization; it is the current architecture.

**The implementation principle that follows from this:** treat each channel as an independent unit of execution, storage, replay, archival, and bootstrap.

```
Correct implementation model:

channel A → replay worker A → per-channel storage A → per-channel snapshot A
channel B → replay worker B → per-channel storage B → per-channel snapshot B
channel C → replay worker C → per-channel storage C → per-channel snapshot C

global state root = commitment over {channel roots}
```

**What this enables:**

*Parallel execution without compromising determinism.* Claims within a channel remain serial. Claims across channels execute in parallel. The `state_root` is the same regardless of channel execution order, because channels are independent by construction (D-15, D-17).

*Selective synchronization.* A participant using markets and governance but not Portal does not need to sync Portal channels. The `ChannelModuleRegistry` (Section 5.7) defines which channels exist; participants subscribe to the subset they require and derive only those channel roots.

**Selective sync trust semantics:** A node synchronizing only a subset of channels can verify the state of those channels locally and independently. However, it cannot independently verify the full global `state_root` — the global root is a commitment over all channel roots, including channels the node does not track. For channels it omits, the node must rely on peer-confirmed roots. Such nodes provide **partial verification** rather than full independent state verification. This is an intentional capability tradeoff: participants who require full sovereignty must sync all channels. Participants who accept peer-confirmed roots for some channels gain operational efficiency at the cost of partial trust delegation for those channels.

*Per-channel archival policies.* Governance channels have low write frequency and require permanent archival. High-frequency market channels may archive only recent windows. Settled Portal channels may be compressed. These policies are operationally distinct and should be managed per-channel, not globally.

*Faster bootstrap.* A new node bootstrapping from a per-channel snapshot loads only the channels it needs. Hot channels can be bootstrapped first; cold channels loaded lazily. Full-node bootstrap is parallelizable across channels.

*Load isolation.* A spammed or slow channel does not degrade the replay pipeline of other channels. The worst-case impact of a misbehaving channel is local to that channel's replay worker and pending queue.

**The one constraint to preserve:** channels must remain independent for replay. Any hidden coupling across channels — undeclared cross-channel state dependencies, implicit shared mutable state, out-of-band coordination between channel workers — destroys the scaling property. Rules D-15 (cross-channel parent prohibition), D-17 (checkpoint-scoped foreign reads), and D-18 (bounded cross-module visibility) exist precisely to keep this coupling explicit, bounded, and deterministic.

The global `state_root` should be understood as a compact commitment over many independently replayable channel states, not as "the system." The system is the set of channels. The root is their digest.

### 1.8 Module Composition Doctrine: Claims for Actions, Foreign Reads for Configuration

As the module ecosystem grows, a critical architectural discipline must be maintained: **the choice of how modules interact determines whether the system remains composable without becoming entangled.**

Two composition models are available, and they are not equivalent.

**Explicit claim composition** — modules interact by publishing claims onto each other's channels. A governance resolution mirrors a `state_update` onto the Markets channel. A Portal `deposit_settlement` mirrors an assertion onto the Markets channel. Every cross-module interaction is explicit in channel history. This model is auditable, deterministic, easy to replay, and preserves channel independence. It is heavier: more claims, more protocol ceremony, slower cross-module propagation.

**Foreign-read composition** — modules interact by reading checkpoint-scoped foreign namespaces. Markets reads Governance parameters. Portal reads the Governance bootstrap checkpoint. A future derivatives module reads Markets state. This model is lighter and more expressive, but bounded staleness becomes fundamental, and hidden dependencies proliferate.

Both models are valid. Used without discipline, foreign reads will accumulate into a web of implicit checkpoint-lagged dependencies that are individually reasonable but collectively impossible to reason about.

**The architectural rule for Interstellar is:**

> **Use explicit claims for action-like state. Use foreign reads for configuration-like state.**

Concretely:

*Safe foreign reads* — governance parameter sets, portal checkpoint hashes, module registry versions, bootstrap constants. These are naturally checkpoint-tolerant. A module reading a governance parameter via `read_foreign` can tolerate lag of up to `C` claims without correctness impact.

*Unsafe foreign reads* — current bundle sets, live open intents, unsettled deposit race conditions, auction selection inputs. These are timing-sensitive. Correct behavior cannot be guaranteed when visibility is lagged by up to `C` claims. These interactions must be expressed as explicit claims.

The practical test: if a protocol rule fails or produces incorrect results when the foreign namespace value is `C` claims stale, the interaction must be an explicit claim, not a foreign read.

This doctrine is the boundary condition that allows Interstellar to function as a general coordination layer — composable enough for meaningful module interoperability, disciplined enough to preserve architectural clarity. Implementations that drift toward unrestricted foreign reads will still execute correctly, but protocol reasoning will degrade as implicit dependencies accumulate. Protocol specifications MUST document which cross-module interactions use foreign reads and justify that those reads are safe under the `0 ≤ lag ≤ C` bound.

**Where coupling lives:** In this architecture, coupling between modules that flows through claims is explicit and auditable. Coupling that flows through foreign reads is implicit. Explicit coupling is harder to write; implicit coupling is harder to reason about. The doctrine above is the right dividing line: keep it implicit only where staleness is harmless.

---

## 2. System Model

### 2.1 Coordination Objects as the Primary Concept

The fundamental conceptual entity in the Interstellar architecture is the **coordination object**: a shared interaction between participants that has a lifecycle, evolves through discrete steps, and reaches a terminal state.

Coordination objects are not stored as mutable records. They are derived by the module reducer from claim history. The object exists as a computed view over the sequence of claims that describe its lifecycle.

Examples of coordination objects:

| Protocol   | Object              | Opens with                        | Closes with                        |
|------------|---------------------|-----------------------------------|------------------------------------|
| Markets    | Trade Intent        | `assertion(trade_intent)`         | `resolution(bundle_finalize)` or `rejection(intent_cancel)` |
| Markets    | Settlement Round    | `assertion(lane_open)`            | `resolution(lane_close)`           |
| Portal     | Deposit Claim       | `assertion(btc_deposit_claim)`    | `resolution(deposit_settlement)` or `resolution(claim_expiry)` |
| Governance | Parameter Proposal  | `assertion(parameter_proposal)`   | `resolution(parameter_activation)` or `rejection(governance_rejection)` |
| Identity   | Key Binding         | `assertion(identity_claim)`       | `resolution(key_revocation)`       |

Every protocol module defines a set of coordination objects it manages and the lifecycle rules that govern how claims transition those objects between states.

### 2.2 Claims as Lifecycle Events

A **claim** is a signed, structured event that advances a coordination object through its lifecycle. Claims are the atoms of the system. The kernel processes claims. Modules interpret them. Applications observe the derived object state.

A claim has:

- A **base claim type** drawn from the universal vocabulary (Section 7). The type describes the coordination role: is this an opening assertion, a competing proposal, a dispute, a terminal resolution?
- A **payload kind** identifying the protocol-specific object type. Defined by the module, not the kernel.
- A **payload** containing the domain object data.
- An **author signature** binding the claim to its publisher.
- An ordered list of **parent claim references** establishing causal dependencies.
- An **author clock** value — a per-author monotonic counter within the channel.

The kernel processes claims by base type. Modules process claims by payload kind.

### 2.3 The Coordination Lifecycle

Every coordination object follows a universal lifecycle expressible through base claim types:

```
assertion                               (open)
    ↓
proposal / support / challenge          (contested)
/ state_update
    ↓
rejection                               (explicitly declined)
    ↓
resolution                              (terminal)
```

Modules define which lifecycle paths are valid for each object type, which claims each participant role may author, and what state the reducer derives at each step.

### 2.4 The Three Computation Phases

All kernel computation is one of three phases:

**Verification.** The kernel checks that a claim is structurally valid, signatures are correct, and causal dependencies are satisfied. Deterministic.

**Reduction.** A verified claim is applied to the module's current namespace state via the pure reducer function `state' = reduce(state, claim)`. Deterministic.

**Authorization.** The participant's key signs a response claim. This is a deliberate participant action, not a kernel computation. It occurs only after successful verification and reduction. Authorization does not affect `state_root`.

These phases are strictly ordered. No authorization occurs before verification and reduction are complete. No reduction occurs before verification passes.

### 2.5 Conceptual Distinctions

**Ordered claim.** A claim present in Zenon with a globally agreed sequence position. May be structurally invalid.

**Verified claim.** A claim that has passed all kernel and module verification steps. Consistent with known state.

**Incomplete claim.** A verified claim whose external payload reference cannot be resolved. Held in the pending queue. Not rejected.

**Reduced state.** The namespace state produced by applying a verified claim through the module's pure reducer.

**Authorized response.** A new claim signed by the participant following a verified and reduced prior claim.

---

## 3. Architecture Overview

Interstellar OS is divided into two sharply separated components: the **Verification Kernel** (trusted) and the **Client Layer** (untrusted).

```
┌─────────────────────────────────────────────────────────────┐
│                   CLIENT LAYER (untrusted)                  │
│                                                             │
│   Wallet UI          external process; queries State API    │
│   Agents             external process; queries State API    │
│   Automation Policy  client-side config; never in kernel    │
│   Storage Client     payload retrieval; delivers to kernel  │
│                                                             │
└──────────────────────────▲──────────────────────────────────┘
                           │  State API / Signing Boundary
┌──────────────────────────┴──────────────────────────────────┐
│              VERIFICATION KERNEL (trusted)                  │
│                                                             │
│   Key Manager      signing boundary; no key export          │
│   State Store      append-log + snapshots + state_root      │
│   Claim Verifier   structure, signatures, causal ordering   │
│   Replay Engine    deterministic reduction loop             │
│   Reducer Host     module loading, isolation, mediation     │
│                                                             │
│   ─────────────────────────────────────────────────────     │
│                                                             │
│   PROTOCOL MODULES (trusted interpreters)                   │
│   Interstellar Markets    Claim Validator + Pure Reducer    │
│   Portal Subsystem        (separately audited)              │
│   Governance              Claim Validator + Pure Reducer    │
│   Identity                Claim Validator + Pure Reducer    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │  Claim Stream
┌──────────────────────────┴──────────────────────────────────┐
│                   COMMIT CHANNELS                           │
└─────────────────────────────────────────────────────────────┘
```

The kernel boundary is the trusted computing base. Everything outside the kernel is untrusted input. The kernel never initiates outbound connections to client-layer components. The client layer communicates with the kernel only through the State API.

The kernel loop is:

```
for channel in active_channels:
    for claim in channel.claim_log:
        if !claim_verifier.verify(claim):       reject
        if !module.validate(state, claim):      reject | defer
        delta = module.reduce(state, claim)
        state.apply(delta)
        channel_state_root[channel.id] = authenticated_root(channel_state[channel.id])

state_root = BLAKE3("interstellar-os-state-root-v6", sorted(channel_state_root values))
```

Each channel is an independent deterministic replay pipeline. Channels may be replayed in parallel; claims within a single channel are replayed serially in sequence position order. The global `state_root` is a commitment over the sorted set of per-channel state roots.

The per-channel replay loop, plus the Key Manager's signing boundary, is the entire kernel.

---

## 4. Verification Kernel

### 4.1 Key Manager

The Key Manager is the root of trust. It is the only component with access to private key material.

**Responsibilities:**

- Key generation using cryptographically secure entropy.
- At-rest encryption using participant-supplied passphrase or hardware-backed key derivation.
- Hardware wallet delegation. When a hardware wallet backend is configured, the Key Manager holds no private key material; all signing operations are delegated to the hardware device.
- Hierarchical deterministic key derivation (BIP-32 compatible) for multi-account structures.
- Key rotation with atomic re-encryption of dependent state.

**Signing interface:**

```
sign(request: SigningRequest) → SigningResult

SigningRequest {
    message:            Bytes
    key_id:             KeyId
    origin_module:      ModuleId
    human_readable:     String      // shown during interactive confirmation
}

SigningResult {
    signature:          Signature
    key_id:             KeyId
    timestamp:          Timestamp
}
```

No component other than the Key Manager calls signing primitives directly. All signing requests are routed through the Reducer Host. The Key Manager never returns private key material to any caller. The Key Manager may refuse any signing request; refusal is not a protocol error.

**Key resolution:** The Key Manager does not maintain an identity graph. Key-to-identity resolution is performed by querying the Identity Module namespace via the Reducer Host. This keeps identity as protocol state, not kernel state.

### 4.2 State Store

The State Store is the kernel's persistent data layer. All state mutations flow through the Replay Engine via the Reducer Host. No external process writes to the State Store directly.

**Structure:** An append-only log of state deltas plus periodic snapshots. Each log entry records:

- The `claim_id` that produced this delta.
- The `sequence_position` at which the claim appeared.
- The state delta as a set of namespace key-value mutations.
- The `state_root` after this delta is applied.
- A hash chain link to the prior log entry.

Snapshots capture full namespace state at configurable intervals. On startup, the kernel loads the most recent valid snapshot and replays the log from that point. Hash chain corruption triggers rollback to the prior snapshot and re-sync from the Commit Channel.

**State namespaces:**

```
kernel.*                    Kernel-managed state (sync head, checkpoint records)
module.<module_id>.*        Module-owned namespace
```

A module may only read and write its own namespace. Cross-namespace access is not permitted. Namespace isolation is enforced by the Reducer Host before applying any `StateProposal`.

### 4.3 Claim Verifier

The Claim Verifier performs structural and cryptographic verification. It does not evaluate protocol semantics.

**Verification steps, in order:**

1. **Deserialization.** Deserialize the claim envelope from canonical encoding. Reject on any failure.
2. **Schema validation.** Verify all required fields are present and within declared bounds. Verify `claim_type` is a recognized base type from the universal vocabulary.
3. **Signature verification.** Verify the author signature against the author's public key. Key resolution is performed by reading the Identity Module namespace from the State Store. Reject if the key is unknown or has a recorded revocation.

   **Identity bootstrap exception:** If the claim type is `assertion` and the payload kind is `identity_claim`, and the Identity namespace contains no record for the claimed author key, the Claim Verifier uses the public key declared in the `identity_claim` payload itself for signature verification. This is the self-authenticating exception that resolves the identity bootstrap paradox: the first identity claim for a key is verified using the key it declares, not a pre-existing namespace entry. The Identity Module reducer subsequently writes this key into the namespace. All subsequent claims by this author require a pre-existing namespace entry and do not qualify for the self-authenticating exception. See Section 9.4 for the full bootstrap specification.

4. **Parent reference validation.** Verify that each entry in `parent_claim_ids` references a claim already in the verified set at a lower sequence position within the same channel. Reject if any parent is unknown. Reject with `CrossChannelParentReference` if any parent is in a different channel (Rule D-15).
5. **Author clock validation.** Verify that the author clock value is strictly greater than the prior claim by the same author in this channel. Reject on equal or lower values.

   **Author clock stall and recovery:** An author who publishes a claim at clock value `N` and then attempts to publish at any value `≤ N` will have all subsequent claims rejected until they publish at `clock > N`. There is no mechanism to reset an author clock; author clocks are monotonically increasing by design. Authors who lose track of their highest clock value (e.g., after catastrophic state loss) must rotate their key: publish a `state_update(key_binding)` claim from a still-functional key, or publish a new `assertion(identity_claim)` for a fresh key. The old key's clock state is abandoned. Implementations should persist the highest observed author clock per key across restarts to prevent self-inflicted clock collisions after a crash.

6. **Payload hash verification.** If the claim carries an external payload reference, verify the retrieved payload's content hash matches the hash recorded in the claim. If the payload has not yet been retrieved, mark the claim `Incomplete` and place it in the pending queue. Do not reject.

Steps 1–5 reject the claim immediately on failure (`KernelRejection`). Step 6 never produces a rejection on the basis of payload unavailability.

### 4.4 Replay Engine

The Replay Engine drives the deterministic reduction loop. It is responsible for:

- Maintaining `sync_heads`: a per-channel map of the kernel's current position in each active Commit Channel stream.
- Driving the verify → validate → reduce loop for each claim within each channel.
- Managing the pending queue for `Incomplete` claims (Section 6.2).
- Managing the dependency queue for `Deferred` claims (Section 8.4).
- Generating checkpoints at configurable intervals.
- Computing and recording `channel_state_root` after each delta within a channel.
- Computing and recording the global `state_root` from the sorted set of `channel_state_root` values after each delta.

**Per-channel replay model:** Each Commit Channel is an independent deterministic replay pipeline. Claims within a single channel are processed serially in `sequence_position` order. Channels may be processed in parallel on independent threads or processes. The Replay Engine maintains a separate `sync_head` per channel. A channel's replay state is not affected by the replay progress of other channels.

**Channel state root:** After each claim reduction within a channel, the Replay Engine updates `channel_state_root[channel_id]` to reflect the new state produced by that channel's claim history. The global `state_root` is recomputed from the full sorted set of `channel_state_root` values after each per-channel update.

**Replay guarantee:** Given a checkpoint at position `P` within a channel and all claims from `P` to `P+N` in that channel, the Replay Engine produces the same `channel_state_root` at `P+N` on every conformant implementation. The global `state_root` follows deterministically from the set of all channel state roots. This is the conformance criterion (Section 14.1).

**Divergence detection:** The Replay Engine records its `state_root` at each checkpoint. Participants may cross-check these values with peers. A mismatch indicates a module version difference, a data integrity failure, or an implementation bug.

### 4.5 Reducer Host

The Reducer Host is the interface between the kernel and the Protocol Modules.

**Responsibilities:**

- Loading module binaries. Before loading, the Reducer Host verifies the binary's BLAKE3 content hash against the participant's module registry. A binary not in the registry is not loaded.
- Providing modules with a read-only view of their own namespace.
- Receiving `StateProposal` objects from module reducers, validating namespace boundaries, and applying them atomically to the State Store.
- Routing signing requests from modules to the Key Manager.
- Enforcing the reducer contract (Section 6.5): modules may not call network, clock, or randomness primitives during `validate` or `reduce` execution.

**Module trust model:** Modules are **trusted protocol interpreters**. They are not untrusted plugins. A module loaded by the Reducer Host is trusted to implement its protocol specification correctly. The namespace boundary exists to contain accidental bugs and prevent cross-module interference, not to defend against adversarial module code. Because modules are trusted, they must be audited before production deployment and their content hashes must appear in the participant's module registry.

---

## 5. State Model and Verifiable Snapshots

### 5.1 Runtime State Object

```
RuntimeState {

    kernel: {
        runtime_id:                     Bytes[32]
        schema_version:                 UInt32
        channel_module_registry_hash:   Bytes[32]   // BLAKE3 of active ChannelModuleRegistry
        sync_heads: Map<ChannelId, SyncHead {
            channel_id:             ChannelId
            sequence_position:      UInt64
            claim_id:               Bytes[32]
            channel_state_root:     Bytes[32]
        }>
    }

    keys: {
        records: Map<KeyId, KeyRecord {
            key_id:     KeyId
            public_key: PublicKey
            key_type:   Enum { Ed25519, Secp256k1, BLS12-381 }
            derivation: DerivationPath?
        }>
    }

    module_state: Map<ModuleId, ModuleNamespace {
        namespace:          AuthenticatedMap<Bytes, Bytes>  // incremental root update structure
        namespace_root:     Bytes[32]                       // current authenticated root
        state_version:      UInt64                          // monotonic version counter
    }>

    channels: Map<ChannelId, ChannelState {
        channel_id:             ChannelId
        replay_position:        UInt64          // last processed sequence_position in this channel
        channel_state_root:     Bytes[32]       // authenticated root over module namespace roots
                                                // for modules written by this channel
    }>

    state_root:         Bytes[32]
    state_version:      UInt64

}
```

**Authenticated map requirement:** `ModuleNamespace.namespace` is not a plain key-value store. It must be implemented as an authenticated map data structure that supports incremental root updates (e.g., a sparse Merkle tree or similar authenticated dictionary). This is required by Rule D-16. See Section 5.2 for the incremental update requirement.

**Channel-module association:** The mapping between channels and modules is defined by the `ChannelModuleRegistry` (Section 5.7). This registry is the canonical, deterministic source of truth for claim routing. Claims arriving on a channel are routed to the modules listed in the registry entry for that channel. A module's namespace is written only by claims arriving on its registered channel(s). Cross-channel namespace writes are not permitted. Two nodes with different active registries will produce different `channel_state_root` and `state_root` values; the `channel_module_registry_hash` in checkpoints makes this divergence detectable.

### 5.2 State Root Computation

State root computation is two-level: per-channel state roots are computed first, then committed into a global state root.

**Per-channel state root:**

```
channel_state_root[channel_id] = BLAKE3(
    "interstellar-os-channel-root-v6",
    channel_id,
    sorted_concatenation(
        namespace_root[module_id]
        for each module_id associated with channel_id
    )
)
```

Each channel's root commits to the current namespace roots of all modules written by that channel. If a channel is associated with a single module (the common case), the channel root is a commitment to that module's namespace root.

**Global state root:**

```
state_root = BLAKE3(
    "interstellar-os-state-root-v6",
    sorted_concatenation(channel_state_root[channel_id] values)
)
```

The domain separator prevents collision with state roots from prior spec versions or other systems. BLAKE3 is used throughout.

**Namespace root computation:**

```
namespace_root[module_id] = authenticated_root(module_state[module_id].namespace)
```

**Incremental update requirement (Rule D-16):** Namespace roots must be maintained incrementally under each `StateProposal`. When a `StateProposal` mutates `k` keys in a namespace of `N` total entries, the implementation must update `namespace_root` in `O(k log N)` time or better, not `O(N)` time. Full recomputation from all namespace entries is permitted only in verification mode, recovery mode, or test mode.

This requirement follows directly from the `StateProposal` model: proposals carry small mutation sets. Implementations must use a data structure that supports small authenticated updates efficiently — such as a sparse Merkle tree or authenticated skip list. Implementations that serialize and rehash the full namespace on each delta are non-conformant under this rule and will not scale to production-grade namespace sizes.

**State root update sequence:** After each verified claim reduces to a `StateProposal` and is applied:

1. Incrementally update `namespace_root[module_id]` for all mutated module namespaces.
2. Recompute `channel_state_root[channel_id]` for the channel that produced the claim.
3. Recompute the global `state_root` from the updated set of channel roots.

Steps 1–3 are atomic from the State Store's perspective.

**Canonical namespace entry serialization:** Namespace keys and values appearing in snapshot data and SMT leaf encoding must use the following canonical serialization:

```
SerializedKey   = uint32_be(len(key))   || key_bytes
SerializedValue = uint32_be(len(value)) || value_bytes
```

Where `uint32_be` is a 4-byte big-endian length prefix. When namespace entries are enumerated for snapshot serialization or full-namespace recomputation, they must be sorted lexicographically by `SerializedKey` before processing. This lexicographic ordering is defined over raw byte sequences using unsigned byte comparison. Two implementations that store identical namespace contents must produce identical serialized representations and therefore identical `namespace_root` values.

### 5.3 Checkpoints

A checkpoint is produced at a configurable interval of sequence positions. The checkpoint record is:

```
Checkpoint {
    sequence_positions:             Map<ChannelId, UInt64>      // per-channel last applied position
    claim_ids:                      Map<ChannelId, Bytes[32]>   // per-channel last applied claim
    channel_state_roots:            Map<ChannelId, Bytes[32]>   // per-channel state roots
    state_root:                     Bytes[32]
    module_content_hashes:          Map<ModuleId, Bytes[32]>    // BLAKE3 of each loaded binary
    channel_module_registry_hash:   Bytes[32]                   // BLAKE3 of active ChannelModuleRegistry
    snapshot_hash:                  Bytes[32]                   // BLAKE3 of the snapshot file
    checkpoint_interval:            UInt64                      // number of claims between checkpoints
    timestamp:                      Timestamp
}
```

The `module_content_hashes` field records the exact binary used to produce this `state_root`, not just a version string. Two implementations using different binaries for the same module version may produce different `state_root` values; the content hash makes this detectable.

The `channel_module_registry_hash` records the active registry at this checkpoint. Two implementations with different registry configurations will produce different `state_root` values at the same sequence position; this field makes the divergence immediately diagnosable.

The `checkpoint_interval` field records the number of claims between global checkpoints at the time this checkpoint was produced. This value bounds the cross-module visibility lag per Rule D-18.

### 5.4 Verifiable Snapshots

A snapshot enables a new node to bootstrap from a known-good state without replaying the full claim history. The snapshot is verifiable without trusting the provider.

**Snapshot format:**

```
Snapshot {
    sequence_positions:             Map<ChannelId, UInt64>
    state_root:                     Bytes[32]
    channel_state_roots:            Map<ChannelId, Bytes[32]>
    module_content_hashes:          Map<ModuleId, Bytes[32]>
    channel_module_registry_hash:   Bytes[32]                   // BLAKE3 of active ChannelModuleRegistry
    snapshot_data:                  Bytes               // canonical serialization of RuntimeState
    snapshot_hash:                  Bytes[32]           // BLAKE3(snapshot_data)
}
```

**Verification procedure for new nodes:**

1. Obtain a `Snapshot` from any source (archive node, peer, local file).
2. Compute `BLAKE3(snapshot.snapshot_data)` and verify it equals `snapshot.snapshot_hash`. If not, discard the snapshot.
3. Compute `state_root` from the deserialized `snapshot_data` using the procedure in Section 5.2. Verify it equals `snapshot.state_root`. If not, discard the snapshot.
3a. Verify that every entry in `snapshot.module_content_hashes` matches the corresponding entry in the local module registry. If any module hash in the snapshot does not match the locally registered hash for that module, discard the snapshot and raise an `UnregisteredModuleHash` error. A snapshot that passes steps 2 and 3 but fails step 3a is internally consistent but derived from modules the local node has not audited and registered. Loading such a snapshot is a security violation. An operator may explicitly override this check only after manually auditing and registering the foreign module binaries.
3b. Verify that `snapshot.channel_module_registry_hash` matches the BLAKE3 of the locally active `ChannelModuleRegistry`. If it does not match, discard the snapshot. A snapshot produced under a different registry configuration will produce a different `state_root` under the local registry, even if the snapshot data is otherwise internally consistent.
4. Cross-check `snapshot.state_root` against the value published by at least one trusted peer at the corresponding sequence positions. If no peer can confirm, the node may still proceed but must treat its state as unconfirmed until it catches up to the live stream and finds agreement with peers.
5. Load the `snapshot_data` into the State Store as the starting point. Begin replaying claims from the recorded per-channel sequence positions.

**Key property:** The snapshot is verified against the content of `snapshot_data` using only hash computation. No replay is required to trust a snapshot. The snapshot provider is not trusted; only the mathematical properties of the snapshot are checked and, critically, only snapshots derived from locally registered module binaries and the locally active channel-module registry are accepted.

**Snapshot canonicality bounds:** A snapshot that passes all five verification steps has the following properties:
- **Internal consistency**: `snapshot_data` hashes to the claimed `snapshot_hash`.
- **State root consistency**: The deserialized state produces the claimed `state_root`.
- **Module alignment**: The modules used to derive the state are audited and locally registered.
- **Registry alignment**: The channel-module binding used to derive the state matches the local registry.
- **Canonicality**: NOT proven by the above. Canonical confirmation — that this `state_root` is the agreed-upon correct state at these sequence positions — requires either (a) peer state root agreement at step 4, or (b) independent replay from genesis. Snapshot verification is verifiable local-state import; it is not a trustless proof of canonical history.

This distinction is not a limitation to be hidden. It is the correct characterization of what snapshot verification provides.

### 5.5 Module Version Log

The Module Version Log records the content hash and activation sequence position of every module version ever loaded by this runtime:

```
ModuleVersionLog {
    entries: [
        ModuleVersionEntry {
            module_id:          ModuleId
            content_hash:       Bytes[32]
            activation_seq:     UInt64          // first sequence position using this binary
            deactivation_seq:   UInt64?         // null if currently active
        }
    ]
}
```

**Historical replay requirement:** When replaying claims at position `P` within a channel, the Reducer Host must load the module version whose `activation_seq ≤ P < deactivation_seq`. This requires that historical module binaries be available.

### 5.6 Module Archive

The Module Archive is the store of historical module binaries required for deterministic historical replay. It is not part of the kernel; it is a Client Layer infrastructure component. However, its availability is a prerequisite for full history replay.

For each entry in the Module Version Log, the corresponding binary identified by `content_hash` must be available in the Module Archive. The Reducer Host retrieves historical binaries from the Module Archive and verifies their content hash before use.

Participants who do not require full history replay (e.g., those bootstrapping from a verified snapshot and replaying only the recent tail) need only the currently active module versions, not the full Module Archive.

**Archive distribution:** Module binaries are content-addressed and may be distributed by any node in the network. The content hash provides integrity verification independent of the distribution source.

### 5.7 ChannelModuleRegistry

The `ChannelModuleRegistry` is the canonical, governance-controlled source of truth for channel-to-module routing. It is part of the deterministic input set of the kernel. All conformant implementations processing the same claim history with the same active registry must produce identical `state_root` values.

**Registry structure:**

```
ChannelModuleRegistry {
    version:    UInt64          // monotonically increasing version counter
    entries: [
        ChannelModuleBinding {
            channel_id:     ChannelId
            module_ids:     [ModuleId]   // ordered list; claims on this channel are routed
                                         // to these modules in listed order
        }
    ]
}

channel_module_registry_hash = BLAKE3(
    "interstellar-os-channel-module-registry-v6",
    canonical_serialization(ChannelModuleRegistry)
)
```

**Genesis registry:** The initial `ChannelModuleRegistry` is defined in the genesis configuration. It is embedded in the genesis state and its hash is committed in the first checkpoint. No claim processing may occur before the genesis registry is loaded and its hash verified.

**Registry updates:** The `ChannelModuleRegistry` may only be updated via a `resolution(parameter_activation)` claim from the Governance Module that includes a `channel_module_registry` field specifying the new registry. The new registry takes effect at the `activation_sequence_position` recorded in the activation claim, not at the position of the claim itself. This preserves deterministic replay for all participants.

When the registry is updated, the new `channel_module_registry_hash` is committed in the next checkpoint. Historical replay at positions prior to the update must use the registry version active at that position, resolved from the governance claim history.

**Routing uniqueness requirement:** For each channel, the set of accepted `(claim_type, payload_kind)` pairs across all modules registered to that channel must be disjoint. No two modules on the same channel may declare the same `(claim_type, payload_kind)` pair in their `accepted_claims` set. A `ChannelModuleRegistry` entry that would produce a routing ambiguity for any claim type is invalid and must be rejected at governance activation time. This rule makes routing declarative rather than positional: the correct module for any claim is determined by its type pair alone, not by module list order.

**Rationale:** Without this rule, a registry update that reorders the `module_ids` list could silently change which module processes a given claim type, altering protocol behavior without any visible semantic change to the claim stream. The uniqueness requirement eliminates this foot-gun: the registry may be reordered without behavioral consequence.

**Routing semantics:** When a claim arrives on a channel:
1. The Reducer Host looks up the channel's entry in the active `ChannelModuleRegistry`.
2. If no entry exists for the channel, the claim is `KernelRejected` with `UnregisteredChannel`.
3. If the claim's `(claim_type, payload_kind)` pair does not match any module's `accepted_claims` set among the channel's registered modules, the claim is `KernelRejected` with `UnroutableClaim`.
4. If the claim's `(claim_type, payload_kind)` pair matches more than one module's `accepted_claims` set (a routing ambiguity), the claim is `KernelRejected` with `AmbiguousRouting`. This condition indicates a non-conformant registry that should have been rejected at activation.
5. Otherwise, the claim is routed to the unique matching module.

**Conformance implication:** Two implementations that configure channel-module associations outside of the `ChannelModuleRegistry` — through local configuration, environment variables, or any other mechanism not governed by the registry — are non-conformant. The registry is the entire binding model. There is no other conformant binding source.

---

## 6. Determinism Rules

The kernel's correctness depends on deterministic execution across all conformant implementations. This section defines the complete set of normative determinism requirements. A kernel implementation that violates any rule is non-conformant.

### 6.1 Claim Processing Determinism

**D-1:** The Claim Verifier's output for a given claim envelope and a given prior state must be identical across all conformant implementations. This includes the identity bootstrap exception: when processing an `assertion(identity_claim)` for an author key not yet present in the Identity namespace, all conformant implementations must use the public key declared in the payload for signature verification. The self-authenticating exception is a defined, deterministic behavior, not an implementation choice.

**D-2:** A module's `validate` function for a given `(claim, namespace_state)` must return the same result across all conformant implementations running the same module binary.

**D-3:** A module's `reduce` function for a given `(claim, namespace_state)` must return the same `StateProposal` across all conformant implementations running the same module binary.

### 6.2 Payload Availability

**D-4:** A claim whose external payload cannot be retrieved is marked `Incomplete` and placed in the pending queue. It is not rejected. Module validation is not invoked for `Incomplete` claims.

**D-5:** When an `Incomplete` claim's payload becomes available (verified against the recorded hash), the Replay Engine re-inserts it into the verification pipeline at its original `sequence_position`.

**D-6:** Claims are always processed in `sequence_position` order. A claim that becomes available late is processed in its original position, not in the position it became available.

**D-7:** `Incomplete` claims are never rejected on the basis of local payload availability conditions. An `Incomplete` claim remains pending indefinitely until its payload arrives or the claim is superseded by a `resolution` claim for the same coordination object.

**Pending queue design tradeoff:** The kernel prioritizes deterministic replay over resource boundedness. Incomplete claims may accumulate indefinitely if their payloads never appear. This is an intentional design choice: payload withholding cannot break safety — the `state_root` is unaffected — but may impose unbounded operational costs on nodes that are targeted by a sustained withholding campaign. Operators should understand this tradeoff explicitly: the kernel will never evict an incomplete claim to relieve memory pressure, because eviction would cause state divergence. The cost of safety is that resource consumption from incomplete claims is not bounded by the kernel itself. Operator alerting and capacity planning are the mitigations.

**D-7a — Pending queue eviction prohibition:** Implementations MUST NOT evict incomplete claims from the pending queue unless the corresponding coordination object has already been resolved by a `resolution` claim recorded in the verified claim history. Eviction of incomplete claims whose objects remain unresolved would cause state divergence between nodes with different eviction policies, violating the conformance criterion (Section 14.1). This is a safety rule, not a liveness recommendation.

**D-8:** Because `Incomplete` claims are never rejected, two nodes with different payload availability will have divergent per-channel `sync_head` positions but will reach the same `state_root` once both have resolved all pending claims. Payload availability is a liveness concern, not a safety concern. However, "liveness concern only" should not be read as "operationally benign." A sustained payload withholding campaign — where a participant repeatedly publishes claims with large unretrievable payloads — creates long-lived pending queue pressure, memory consumption, and synchronization lag, even though safety is not compromised. Operators must plan for this as a realistic operational adversarial pattern.

**D-9:** Payload retrieval is Client Layer behavior. The kernel issues payload requests to the Storage Client via a defined interface and receives payload bytes in response. The kernel verifies the hash before use. The kernel is not aware of retrieval mechanisms, timeouts, or retry policies.

**Pending queue operational guidance:** Implementations SHOULD alert operators when per-channel pending queue depth exceeds a configurable threshold (recommended default: 10,000 incomplete claims per channel) or when total pending payload byte budget exceeds a configurable threshold (recommended default: 512 MB across all channels). When these thresholds are exceeded, new incomplete claims MUST still be accepted and tracked — they MUST NOT be rejected or silently dropped. The purpose of the alerts is to surface the operational cost of payload withholding to the operator, not to trigger eviction.

### 6.3 Local Policy Isolation

**D-10:** Local authorization policy (automation rules, amount limits, counterparty restrictions) is evaluated in the Client Layer. It does not affect kernel computation.

**D-11:** Two participants with different automation policies replaying the same claim history produce the same `state_root`. Their authorization decisions may differ; differences only affect state if the resulting response claims differ, in which case those claims appear in the claim history and are subject to the same deterministic processing.

### 6.4 Module Versioning and Replay

**D-12:** When replaying a claim at sequence position `P` within a channel, the Reducer Host uses the module version whose `activation_seq ≤ P < deactivation_seq` in the Module Version Log.

**D-13:** A module version upgrade takes effect at the `sequence_position` recorded in the `resolution(parameter_activation)` claim activating it. The upgrade does not take effect when the binary is loaded.

**D-14:** Checkpoints record `module_content_hashes`, not version strings. Two checkpoints at the same sequence position with different `module_content_hashes` will not generally produce the same `state_root`, even if the version strings are identical.

### 6.5 Reducer Determinism Contract

This section specifies the normative constraints on module reducer implementations. A module that violates the Reducer Determinism Contract is non-conformant and must not be distributed as a trusted protocol interpreter.

**The reducer model:**

Reducers must be implemented as pure state transition functions:

```
validate(namespace_state, claim) → ValidationResult
reduce(namespace_state, claim)   → StateProposal
```

Where `namespace_state` is a read-only projection of the module's namespace, and `claim` is the verified claim envelope.

**Normative constraints on `validate` and `reduce`:**

**RDC-1:** Reducers must not access wall-clock time in any form.

**RDC-2:** Reducers must not generate or consume randomness. All randomness used by a protocol must be derived from values present in the claim payload or the namespace state.

**RDC-3:** Reducers must not perform network I/O.

**RDC-4:** Reducers must not access filesystem paths outside the read-only namespace view provided by the Reducer Host.

**RDC-5:** Reducers must not use floating-point arithmetic. All numeric operations must use integer arithmetic or fixed-point representations with defined overflow and rounding behavior.

**RDC-6:** Reducers must not rely on undefined iteration order for any collection type. All collections must be iterated in a defined, implementation-independent order (e.g., lexicographic key order for maps).

**RDC-7:** Reducers must not use platform-specific or compiler-specific behavior. All arithmetic must be deterministic across processor architectures and compiler versions.

**RDC-8:** Reducers must not retain state between invocations outside the namespace view. Each call to `validate` or `reduce` must be fully determined by its inputs.

The Reducer Host enforces RDC-3 and RDC-4 via OS-level sandbox restrictions on module execution. RDC-1, RDC-2, RDC-5, RDC-6, RDC-7, and RDC-8 are implementation-level requirements that module auditors must verify.

**Enforcement note:** The Reducer Host cannot mechanically enforce RDC-5 through RDC-8. These constraints are part of the module audit requirements. Module specifications must document their numeric representations and collection ordering guarantees. Conformance test vectors (Section 14) are the primary mechanism for detecting violations.

### 6.6 Channel Replay Model

This section formally specifies channel-scoped replay, cross-channel reference rules, and the requirements for coordinating across channels.

**Channel replay rule:** Each Commit Channel is an independent deterministic replay pipeline. The Replay Engine maintains a separate `sync_head` and `channel_state_root` for each active channel. Replay within a channel is strictly sequential by `sequence_position`. The replay state of channel A is not affected by the replay progress or state of channel B.

**D-15 — Cross-channel parent reference prohibition:** `parent_claim_ids` entries must reference claims within the same channel as the referencing claim. Cross-channel `parent_claim_ids` references are rejected at Stage 2 (Kernel Verification) with `CrossChannelParentReference`. This is a `KernelRejection`.

**Rationale for D-15:** Allowing cross-channel parent references would require a global ordering of claims across channels to evaluate causal dependencies, reintroducing the global replay ordering problem this architecture is designed to eliminate. Cross-channel coordination must instead be expressed through the claim content itself.

**Cross-channel coordination pattern:** When a protocol action requires coordinating claims across two channels, the coordination is expressed by publishing independent claims to each channel — not by creating a cross-channel parent reference. For example: if a governance activation on Channel A must also take effect in a markets module on Channel B, the governance module emits its `resolution(parameter_activation)` on Channel A; the markets module observes the activated parameter by reading governance namespace state (a read-only cross-namespace dependency permitted under Section 4.5), and then processes a subsequent `state_update` claim on Channel B at the appropriate position.

**Read-only cross-module namespace access:** Modules may read from other modules' namespaces via the Reducer Host's `ReadOnlyNamespaceView` interface. However, cross-module reads are subject to Rule D-17 below, which restricts them to checkpoint-scoped state to preserve channel independence. The composition doctrine (Section 1.8) further governs which cross-module interactions are safe as foreign reads and which must be expressed as explicit claims.

> **Foreign reads are intentionally stale.** A module calling `read_foreign` does not receive the current live state of the target namespace. It receives the state of that namespace as committed at the most recent completed global checkpoint. Protocols must be designed to tolerate this bounded lag. A developer who assumes `read_foreign` returns live state will write subtly incorrect protocol logic. This is not a limitation to be worked around — it is the mechanism that makes parallel channel replay deterministic.

**D-17 — Cross-module namespace reads are checkpoint-scoped:** When a module reads from a namespace owned by a different module, the `ReadOnlyNamespaceView` provided by the Reducer Host exposes that foreign namespace's state as committed at the most recent global checkpoint, not its live post-checkpoint state. A module may only access live state from its own namespace.

**Rationale for D-17:** Without this rule, cross-module reads create an ordering dependency between parallel channel replays. If Module A (on Channel A) reads Module B's live namespace, and Module B (on Channel B) is being replayed in parallel, the result of Module A's read depends on how far along Channel B's replay has progressed — violating the channel parallelism invariant. By restricting cross-module reads to checkpointed state, both channels see the same foreign namespace state regardless of replay order. The checkpointed state is immutable and agreed upon by all participants.

**`ReadOnlyNamespaceView` access model:**

```
ReadOnlyNamespaceView {
    // Own namespace: live (post-checkpoint) state. Reflects all mutations
    // applied since the last checkpoint within this channel.
    read_own(key: Bytes) → Bytes?

    // Foreign namespace: checkpoint-scoped state only. Reflects the state
    // committed at the most recent global checkpoint. Does not reflect
    // post-checkpoint mutations in other channels.
    read_foreign(module_id: ModuleId, key: Bytes) → Bytes?
}
```

**Identity namespace exception:** The Claim Verifier's key resolution reads the Identity Module namespace. Because the Claim Verifier runs before any state reduction, it reads Identity namespace state from the State Store's current committed state. For channels that have Identity as an associated module, this is live state. For channels that do not, this is checkpoint-scoped state via D-17. The identity bootstrap exception (Section 4.3) handles the case where no identity record yet exists.

**Channel parallelism invariant:** Two conformant implementations, one processing channels sequentially and one processing them in parallel, must produce identical `state_root` values given the same claim histories in all channels. This invariant is preserved by D-15 (no cross-channel parent references) and D-17 (cross-module reads are checkpoint-scoped).

### 6.7 Namespace Root Maintenance

**D-16 — Incremental namespace root updates:** Namespace roots must be maintained incrementally under each `StateProposal`. When a `StateProposal` contains mutations to `k` keys in a namespace of `N` total entries, the implementation must update `namespace_root[module_id]` in `O(k log N)` time or better. Full recomputation from all namespace entries — serializing and rehashing the complete namespace — is permitted only in verification mode, recovery mode, or test mode. An implementation that performs full recomputation during normal steady-state operation is non-conformant under this rule.

**Rationale:** Module namespaces for active protocols will grow large over time. The Markets namespace accumulates intents, fills, and round history. The Portal namespace accumulates header records, deposit claims, and settlement history. The Governance namespace accumulates proposal and vote records. The Identity namespace accumulates key bindings and revocations. At production scale, these namespaces may contain millions of entries. Because the `state_root` must be recomputed after every claim reduction, namespace root maintenance cost is incurred on every state mutation — including during live operation, not just during replay. Implementations that use full recomputation will exhibit `O(N)` cost per claim, causing performance collapse as namespace sizes grow. Incremental updates keep per-claim cost at `O(k log N)` regardless of namespace size, where `k` is small by construction (a typical `StateProposal` mutates a handful of keys).

**Canonical authenticated map format:** To ensure snapshot interoperability across implementations, all conformant implementations must use the following canonical authenticated map format for `ModuleNamespace.namespace`:

```
Canonical Authenticated Map:
    Structure:      Sparse Merkle Tree
    Hash function:  BLAKE3
    Leaf key:       BLAKE3("smt-leaf-key", namespace_key)
    Leaf value:     BLAKE3("smt-leaf-value", namespace_value)
    Empty subtree:  BLAKE3("smt-empty", depth_as_u8)
    Internal node:  BLAKE3("smt-internal", left_child, right_child)
    Root:           BLAKE3("smt-root", tree_root_hash)
```

The domain-separated hash inputs prevent second-preimage attacks across tree levels. This canonical format ensures that two implementations storing the same namespace contents produce identical `namespace_root` values, which is required for snapshot interoperability.

**Required data structure:** To satisfy D-16, namespace storage must use the canonical sparse Merkle tree format defined above. Implementations may use alternative internal representations for performance (e.g., caching subtree hashes), provided the resulting `namespace_root` is identical to what the canonical format would produce.

**Verification and recovery exception:** For verifiable snapshot verification (Section 5.4), conformance test vector execution (Section 14), and post-corruption recovery, full namespace recomputation is permitted and may be preferable for simplicity. Implementations should clearly separate the verification/recovery code path from the steady-state code path to prevent the full-recomputation path from being used inadvertently in production.

### 6.8 Checkpoint Visibility Semantics

Rule D-17 introduces checkpoint-scoped foreign reads. This section formally specifies the visibility lag that follows from that rule, and defines which cross-module coordination patterns are safe to use.

**D-18 — Cross-module visibility lag is bounded by the checkpoint interval:** Let `C` be the global checkpoint interval, measured in total claims processed across all channels between consecutive global checkpoint commits. For any state mutation written to Module B's namespace at position `P`, Module A's `read_foreign` call will reflect that mutation at the earliest at the checkpoint that follows `P`. The cross-module visibility lag is therefore bounded as:

```
0 ≤ cross-module visibility lag ≤ C claims
```

A state mutation committed at position `P` is guaranteed to be visible to all `read_foreign` callers by the checkpoint at position `P + C` or earlier.

**Protocol specifications MUST NOT assume instantaneous cross-module visibility.** A protocol rule that reads a foreign module's namespace and expects to observe state written in the same checkpoint interval is incorrect under this architecture. Such a rule will exhibit bounded staleness of up to `C` claims in duration.

**Cross-module coordination pattern table:**

| Protocol need | Safe pattern | Unsafe pattern |
|---|---|---|
| Markets reads governance parameter after activation | Read via `read_foreign` — acceptable; lag ≤ C claims | Assume immediate visibility on same claim |
| Portal reads governance bootstrap checkpoint | Read via `read_foreign` at startup — acceptable | Assume parameter visible before first checkpoint |
| Module A confirms Module B reached a terminal state | Same-channel `resolution` claim mirrored to Module A's channel | Polling Module B's namespace live during replay |
| Two modules must agree on a shared value at the same logical time | Publish value via `assertion` on a shared channel; both modules read it from own namespace | Cross-module read in same checkpoint window |

**Composition doctrine alignment:** The pattern table above is the operational expression of the composition doctrine from Section 1.8. The "Safe pattern" column represents foreign-read composition (acceptable for configuration-like state). The "Unsafe pattern" column represents cases that must be expressed as explicit claims. Protocol authors must consult both Section 1.8 and this table when designing cross-module interactions.

**Determining safe lag tolerance:** A protocol rule is safe under D-17 and D-18 if its correctness holds for any observed value of the foreign namespace within the most recent checkpoint's committed state. If a protocol requires tighter synchronization — where a module must see another module's state at a specific claim position, not just as of the prior checkpoint — the coordination must be expressed by publishing an explicit claim to the dependent channel, not by reading foreign namespace state.

**Checkpoint interval configuration:** The checkpoint interval `C` is a runtime configuration parameter recorded in each checkpoint (Section 5.3). Protocol specifications that depend on cross-module foreign reads SHOULD document the maximum checkpoint interval they can tolerate. A participant configured with a checkpoint interval larger than that tolerance is misconfigured for that protocol combination.

---

## 7. Universal Claim Vocabulary

### 7.1 Design Principle

Every claim has two levels of typing:

- **Base claim type:** Describes the coordination role. Defined in this section. Stable across all protocol versions. Processed by the kernel.
- **Payload kind:** Describes the protocol-specific meaning. Defined by the module specification. Processed by the relevant module. The kernel is agnostic to payload kind values.

The base vocabulary must remain stable. Adding a new base type requires a kernel-level change. Protocol-specific concepts must be expressed as `payload_kind` values under an existing base type.

### 7.2 Base Claim Types

**`assertion`**

A participant opens a new coordination object or states that a condition exists.

Examples: lane open, deposit claim, oracle value post, governance proposal introduction, identity record creation.

---

**`proposal`**

A participant offers a candidate action or outcome in response to one or more open coordination objects.

Examples: solver bundle submission, governance amendment, settlement proposal.

---

**`support`**

A participant affirms, endorses, or provides evidence for a prior claim or open object.

Examples: watcher deposit confirmation, governance endorsement, oracle peer confirmation.

---

**`rejection`**

A participant explicitly declines a prior proposal or closes an open object without selecting a proposal.

Examples: intent cancel, governance proposal rejection, counterparty decline.

Silence is not rejection. Explicit `rejection` claims are required wherever the protocol must distinguish an explicit decline from a non-response.

---

**`challenge`**

A participant disputes the correctness, validity, or authority of a prior claim.

Examples: bundle dispute, bridge deposit dispute, governance activation dispute, oracle value challenge.

`challenge` is the entry point for all dispute flows. An open `challenge` without a `resolution` leaves the challenged object in a contested state.

---

**`state_update`**

A non-terminal state transition for a long-lived coordination object.

Examples: lane partial fill, escrow state advance, governance phase change.

Use sparingly. Prefer `resolution` wherever the lifecycle reaches a terminal state.

---

**`resolution`**

A terminal claim that closes a coordination object.

Examples: bundle finalized, claim settled, challenge resolved, proposal activated, lane closed, intent expired, round closed.

A `resolution` claim makes the referenced coordination object immutable. All subsequent claims referencing a resolved object are invalid.

`resolution` absorbs the role of `acceptance` from earlier versions. When a resolution selects a specific proposal as the winning outcome, it includes an `accepted_proposal_id` field referencing the selected proposal claim.

```
ResolutionPayload {
    object_id:              Bytes[32]       // coordination object being resolved
    accepted_proposal_id:   Bytes[32]?      // if resolution selects a proposal
    outcome:                PayloadKind-specific data
}
```

---

### 7.3 Multi-Parent References

Claims may depend on multiple prior claims. The `parent_claim_ids` field is an ordered list:

```
parent_claim_ids: [Bytes[32]]
```

The first entry is the primary causal parent (the coordination object being advanced). Subsequent entries are additional causal dependencies (e.g., the set of `proposal` claims that a `resolution(bundle_finalize)` resolves against).

The Claim Verifier verifies that all entries in `parent_claim_ids` reference verified claims at lower sequence positions. A claim with an unresolved parent reference is rejected at Stage 2 of the verification pipeline.

### 7.4 Universal Coordination Lifecycle

```
assertion                       (object opened)
    ↓
proposal /                      (zero or more, any order)
support /
challenge /
state_update
    ↓
rejection                       (optional terminal: explicit decline)
    ↓
resolution                      (terminal: object closed)
```

Every module's claim flow must map to this lifecycle. A flow that cannot be expressed in this model indicates a design problem in the protocol.

### 7.5 Protocol Module Payload Kinds (Reference Mapping)

The following mappings are illustrative. Authoritative payload kind definitions are in each module's specification.

| Protocol Object            | Base Claim Type | Example Payload Kind        |
|----------------------------|-----------------|-----------------------------|
| Trade intent               | `assertion`     | `trade_intent`              |
| Intent cancel              | `rejection`     | `intent_cancel`             |
| Lane open                  | `assertion`     | `lane_open`                 |
| Lane close                 | `resolution`    | `lane_close`                |
| Bundle submission          | `proposal`      | `settlement_bundle`         |
| Bundle finalization        | `resolution`    | `bundle_finalize`           |
| Bundle dispute             | `challenge`     | `bundle_dispute`            |
| BTC deposit claim          | `assertion`     | `btc_deposit_claim`         |
| Watcher confirmation       | `support`       | `deposit_confirmation`      |
| Deposit dispute            | `challenge`     | `deposit_dispute`           |
| Deposit settled            | `resolution`    | `deposit_settlement`        |
| Governance proposal        | `assertion`     | `parameter_proposal`        |
| Governance endorsement     | `support`       | `governance_endorsement`    |
| Governance vote (oppose)   | `rejection`     | `governance_vote`           |
| Parameter activation       | `resolution`    | `parameter_activation`      |
| Identity claim             | `assertion`     | `identity_claim`            |
| Key binding                | `state_update`  | `key_binding`               |
| Key revocation             | `resolution`    | `key_revocation`            |

### 7.6 What Is Not a Base Claim Type

The following must not be added to the base vocabulary:

- `vote` — expressed as `support` or `rejection` with `payload_kind: governance_vote`.
- `intent` — expressed as `assertion` with `payload_kind: trade_intent`.
- `acceptance` — absorbed by `resolution` with `accepted_proposal_id`.
- Any domain-specific object name.

The base vocabulary is sealed. Changes require a kernel-level version increment.

---

## 8. Module Architecture

### 8.1 Module Classification

Modules are trusted protocol interpreters. They are not sandboxed plugins of unknown provenance. A module loaded by the Reducer Host is treated as part of the trusted protocol implementation. The namespace boundary enforces state isolation, not security against adversarial code.

Module requirements:
- Published with a BLAKE3 content hash.
- Versioned with a SemVer string.
- Independently audited against the Reducer Determinism Contract before production deployment.
- Verified against the participant's module registry before loading.

### 8.2 Module Interface

```
Module {
    module_id:              ModuleId
    protocol_version:       SemVer
    accepted_claims:        Set<(ClaimType, PayloadKind)>

    initialize(
        config:         ModuleConfig,
        state_view:     ReadOnlyNamespaceView
    ) → Result<(), ModuleError>

    validate(
        namespace_state:    ReadOnlyNamespaceView,
        claim:              ClaimEnvelope
    ) → ValidationResult

    reduce(
        namespace_state:    ReadOnlyNamespaceView,
        claim:              ClaimEnvelope
    ) → StateProposal

    signing_request(
        namespace_state:    ReadOnlyNamespaceView,
        claim:              ClaimEnvelope
    ) → SigningRequest?

    shutdown() → Result<(), ModuleError>
}
```

`validate` and `reduce` take `namespace_state` and `claim` as their only inputs. No other runtime context is accessible. This signature enforces the pure function model.

### 8.3 Validate and Reduce Are Separate

`validate` checks semantic validity. It is a read-only pure function. It does not produce state mutations.

`reduce` computes the state delta. It is only called after `validate` returns `Valid`. It is also a read-only pure function; it returns a `StateProposal` but does not apply it directly.

Separation prevents a class of bugs where partial state mutations occur from claims that are subsequently determined invalid.

### 8.4 Deferred Claims

`validate` may return `Deferred(dependency_claim_id)`. The claim is structurally valid but its semantic validity cannot be assessed until a prior claim resolves. The Replay Engine places deferred claims in a dependency queue keyed by `dependency_claim_id`. When the dependency resolves, dependent claims are re-queued in their original sequence order.

Circular dependencies (A defers on B, B defers on A) are detected and both claims are rejected with `CircularDependency`.

### 8.5 State Proposals

```
StateProposal {
    module_id:  ModuleId
    mutations: [
        Mutation {
            namespace_key:  Bytes
            operation:      Enum { Set(value: Bytes), Delete }
        }
    ]
}
```

The Reducer Host verifies that all `namespace_key` values are within the module's registered namespace prefix before applying. Out-of-namespace proposals are discarded and the incident is recorded for audit.

### 8.6 Signing Requests from Modules

When `signing_request` returns a non-null value, the Reducer Host forwards it through the signing pipeline:

```
Module.signing_request(namespace_state, claim)
    → Reducer Host (validates module identity and request format)
    → Key Manager (routes to participant confirmation or client-side policy)
    → Signature returned to Reducer Host
    → Reducer Host constructs signed response claim
    → Response claim submitted to Commit Channel
```

The module receives only the signed response claim. It never receives the private key or the raw signature bytes directly.

### 8.7 Deterministic Module SDK

The Reducer Determinism Contract (Section 6.5) defines what modules must not do. The Deterministic Module SDK defines the canonical implementation of how to do it correctly. The SDK is the **reference implementation** of determinism primitives for the Interstellar module ecosystem. It is not a kernel component and is not normatively required to be used verbatim, but it establishes the canonical behavior that all conformant implementations must reproduce.

Module authors who implement modules using the SDK types satisfy RDC-5, RDC-6, and RDC-7 by construction. Module authors who implement without the SDK must demonstrate equivalent behavior through manual audit and conformance test vector compliance. In practice, the SDK is the expected implementation path; departure from it requires explicit audit justification.

**SDK canonical components:**

```
CanonicalMap<K, V>
    // Ordered map with defined lexicographic key iteration.
    // Canonical reference implementation of RDC-6 for map types.
    // Iteration order: lexicographic by serialized key (big-endian length-prefixed bytes).

FixedPoint<precision: u8>
    // Fixed-point integer arithmetic with defined overflow behavior.
    // Canonical reference implementation of RDC-5.
    // Overflow behavior: saturate or panic (module must declare which at compile time).

CanonicalBytes
    // Canonical serialization helpers for namespace key/value encoding.
    // All integer types: big-endian. All compound types: length-prefixed fields
    // in declared field order. Canonical reference for SMT leaf encoding and
    // snapshot_data serialization.

BLAKE3Hasher
    // Thin wrapper over BLAKE3 with domain-separated helpers.
    // Prevents hash confusion with kernel-internal BLAKE3 uses.
    // Domain separator format: BLAKE3("interstellar-module-<purpose>", ...)
```

**What the SDK does not provide:** The SDK does not provide network access, clock access, randomness sources, or filesystem access. These are prohibited by RDC-1 through RDC-4 and the Reducer Host enforces them at the OS level. Protocol randomness must be derived from values present in the claim payload or namespace state.

**SDK and the audit process:** Module audit reports must document whether the module uses the SDK. Audits of SDK-based modules may treat RDC-5, RDC-6, and RDC-7 compliance as established for SDK-typed operations and focus their determinism review on the module's logic. Audits of non-SDK modules must verify all numeric representations, iteration orders, and serialization formats explicitly against the canonical behaviors defined above. The audit burden for non-SDK modules is materially higher.

---

## 9. Standard Modules

### 9.1 Interstellar Markets Module

**Module ID:** `interstellar.markets.v1`  
**Trust classification:** Trusted protocol interpreter. Must be independently audited.

**Purpose:** Derives market state (lane state, intent pool, bundle history, settlement fills) by replaying ZIM protocol claims. Implements ZIM validation rules as a pure reducer.

**Coordination objects managed:**

- **Intent Lane:** opened by `assertion(lane_open)`, closed by `resolution(lane_close)`.
- **Trade Intent:** opened by `assertion(trade_intent)`, closed by `resolution(bundle_finalize)` referencing the intent, or by `rejection(intent_cancel)`.
- **Settlement Round:** opened implicitly by `assertion(lane_open)`, advanced by `proposal(settlement_bundle)` submissions, closed by `resolution(bundle_finalize)`.

**Accepted claims:**

| Base Type    | Payload Kind          | Description                                   |
|--------------|-----------------------|-----------------------------------------------|
| `assertion`  | `lane_open`           | Opens an intent lane                          |
| `assertion`  | `trade_intent`        | Publishes a trade intent                      |
| `rejection`  | `intent_cancel`       | Cancels an open intent                        |
| `proposal`   | `settlement_bundle`   | Solver submits a candidate bundle             |
| `challenge`  | `bundle_dispute`      | Disputes a submitted bundle                   |
| `resolution` | `bundle_finalize`     | Closes the round; selects the winning bundle  |
| `resolution` | `lane_close`          | Closes the lane                               |

**Claim-driven auction model:**

Bundle selection is fully expressed as claims. Validators order claims; they do not compute auctions.

Round timeline:

```
assertion(lane_open)
assertion(trade_intent) [one or more]
proposal(settlement_bundle) [one or more, from solvers]
resolution(bundle_finalize) [one per round]
```

The `resolution(bundle_finalize)` payload:

```
BundleFinalizePayload {
    lane_id:                LaneId
    auction_round:          UInt64
    parent_claim_ids:       [bundle_submit_claim_id, ...]   // all candidate bundles
    accepted_proposal_id:   Bytes[32]                       // selected bundle claim_id
    eligible_set_hash:      Bytes[32]                       // hash of computed eligible set
    selection_seed:         Bytes[32]                       // verifiable random seed
}
```

The reducer verifies the `bundle_finalize` claim by:

1. Confirming `accepted_proposal_id` references a submitted `proposal(settlement_bundle)` in `parent_claim_ids`.
2. Recomputing the eligible set from all referenced bundle proposals under ZIM validity rules.
3. Verifying `eligible_set_hash` matches the recomputed eligible set.
4. Verifying that applying `selection_seed` over the eligible set selects `accepted_proposal_id`.

If any check fails, the `resolution(bundle_finalize)` claim is rejected as `ModuleRejection`. The round remains open.

**Auction round scheduling:**

```
auction_round = zenon_block_height / ROUND_BLOCK_LENGTH
```

`ROUND_BLOCK_LENGTH` is a governance-controlled parameter. Derived deterministically from block height; no validator schedule tracking required.

**State derived:**

Active lanes, open intent pool per lane, submitted bundle sets, finalized settlement history, per-account fill records.

**Cross-module dependencies:** The Markets Module reads Governance namespace state via `read_foreign` to obtain the active `ROUND_BLOCK_LENGTH` parameter and other governance-controlled market parameters. This is a safe foreign read under the composition doctrine (Section 1.8): governance parameters are configuration-like, checkpoint-tolerant, and slowly changing. The Markets Module MUST NOT use `read_foreign` to read live market state from other channels; any inter-market coordination must be expressed as explicit claims.

### 9.2 Portal Subsystem

**Module ID:** `interstellar.portal.v1`  
**Trust classification:** Trusted protocol interpreter. **High-risk. Separately audited. Treat as a bridge verification engine.**

**Purpose:** Verifies Bitcoin SPV proofs and issues BTC-backed claim objects within the Interstellar system.

**Risk classification:** The Portal Subsystem has a categorically different risk profile from other modules. An incorrect SPV verification produces unbacked claims. This module must be audited independently of other modules, with specific review of the SPV verification implementation, the header chain bootstrap procedure, and reorg handling.

**Deployment recommendation:** Participants who do not require independent Bitcoin verification may configure their runtime to accept Portal state derived by a trusted archive node rather than running Portal SPV locally. Independent Portal verification is available for participants who require it and have completed the associated security review.

**Accepted claims:**

| Base Type    | Payload Kind              | Description                                      |
|--------------|---------------------------|--------------------------------------------------|
| `assertion`  | `btc_deposit_claim`       | Claims a Bitcoin deposit with SPV proof          |
| `support`    | `deposit_confirmation`    | Watcher confirms the deposit                     |
| `challenge`  | `deposit_dispute`         | Disputes a deposit claim                         |
| `resolution` | `deposit_settlement`      | Settles a confirmed deposit as a backed claim    |
| `resolution` | `claim_expiry`            | Records expiry of an unconfirmed claim           |

**SPV verification requirements:**

- **Bootstrap checkpoint governance requirement:** The Portal SPV bootstrap checkpoint hash and height must be published as a governance-controlled parameter and activated via `resolution(parameter_activation)` before the Portal module processes any `assertion(btc_deposit_claim)`. The active governance parameter key is `portal.bootstrap_checkpoint` and encodes `{block_hash: Bytes[32], block_height: UInt32}`. A Portal module instance configured with a bootstrap checkpoint that does not match the currently active `portal.bootstrap_checkpoint` governance parameter is in a misconfigured state and must not settle deposits until the discrepancy is resolved. The Portal module reads this parameter via `read_foreign` from the Governance namespace. This is a safe foreign read: the bootstrap checkpoint is configuration-like state that changes rarely and is checkpoint-tolerant.
- Minimum confirmation depth: configurable, default 6. Deposits confirmed at lower depth are not eligible for `resolution(deposit_settlement)`.
- Reorg handling: reorgs invalidating settled claims must be published as `challenge(deposit_dispute)` claims. The Portal Subsystem is responsible for detecting reorgs in its header cache and publishing challenge claims. The protocol specification for Portal must define who is authorized to publish these challenges and how disputes are adjudicated.
- Header chain verification must check cumulative proof-of-work, not only header format.

### 9.3 Governance Module

**Module ID:** `interstellar.governance.v1`

**Purpose:** Tracks protocol parameter proposals, records endorsements and opposition, and activates new parameter sets at specified sequence positions.

**Accepted claims:**

| Base Type    | Payload Kind                | Description                               |
|--------------|-----------------------------|-------------------------------------------|
| `assertion`  | `parameter_proposal`        | Introduces a protocol parameter proposal  |
| `support`    | `governance_endorsement`    | Endorses a proposal                       |
| `rejection`  | `governance_vote`           | Opposes a proposal                        |
| `resolution` | `parameter_activation`      | Activates the approved parameter set      |

**Parameter activation:** A `resolution(parameter_activation)` claim is only valid if its referenced `assertion(parameter_proposal)` has accumulated endorsement weight meeting the threshold defined in the currently active governance parameters. The reducer verifies this before accepting the resolution. The new parameter set takes effect at the `activation_sequence_position` recorded in the claim, not at the sequence position of the resolution claim itself.

**Cross-module read exposure:** Governance namespace state is the primary source of foreign reads for other modules. The Governance Module's namespace is read-only to other modules; no module may write to the Governance namespace except via Governance's own reducer. This is by design: governance parameters are configuration-like state that other modules consume safely via `read_foreign`.

### 9.4 Identity Module

**Module ID:** `interstellar.identity.v1`

**Scope declaration:** The Identity Module is a **key-binding registry**. It is not a trust system. It proves key ownership only. It does not assign authority, roles, reputation, or membership. It does not define trust domains. These richer semantics are not provided by this module and must not be assumed based on the presence of an identity record. Authorization, role assignment, reputation scoring, and membership rules must be defined explicitly by the protocol modules and governance parameters that require them.

This scope restriction is load-bearing. Downstream protocols that overread the Identity Module — assuming it implies permission or authority — will build on a guarantee the module does not provide. Such protocols will be semantically incorrect even if they compile and execute deterministically.

**Purpose:** Maintains the participant's local identity graph: associations between public keys and participant identifiers, key binding history, and revocation records. Other modules query identity state via the Reducer Host's read-only namespace view. The Claim Verifier also reads from the Identity namespace to resolve author keys during signature verification.

**Accepted claims:**

| Base Type      | Payload Kind         | Description                                |
|----------------|----------------------|--------------------------------------------|
| `assertion`    | `identity_claim`     | Associates a public key with an identity   |
| `state_update` | `key_binding`        | Adds a key to an existing identity         |
| `resolution`   | `key_revocation`     | Revokes a key                              |

**Identity bootstrap specification:** The identity bootstrap problem is: the Claim Verifier must verify the signature on an `assertion(identity_claim)` before the key mapping that claim creates exists in the namespace. This is resolved by the self-authenticating exception defined in Section 4.3 and Rule D-1. Formally:

```
IdentityClaimPayload {
    public_key:     PublicKey       // the key being registered
    identity_id:    Bytes[32]       // the identity this key belongs to
    key_type:       Enum { Ed25519, Secp256k1, BLS12-381 }
    metadata:       Bytes?          // optional human-readable label
}
```

When the Claim Verifier processes an `assertion(identity_claim)` and finds no namespace entry for the claim's declared author key:
1. It uses the `public_key` field from the `IdentityClaimPayload` for signature verification.
2. If verification passes, the claim proceeds to module validation and reduction as normal.
3. The Identity Module reducer writes `public_key → identity_id` into the namespace.
4. All subsequent claims by this author use the standard namespace lookup path.

**What an identity record does and does not establish:**

```
Does establish:
  - The author possesses the private key corresponding to public_key
  - The author chose to associate this key with identity_id
  - The key has not been revoked at this sequence position

Does NOT establish:
  - That the author has any particular permission or role
  - That identity_id is unique or globally meaningful
  - That the author is authorized to take any specific protocol action
  - Reputation, trustworthiness, or membership in any group
```

**Author clock and key hygiene:** Key management is part of protocol hygiene. An author who loses track of their highest clock value must rotate their key. A key rotation does not inherit the previous key's history or any protocol-level authority that may have been assigned to it by other modules. Modules that assign authority to specific keys must handle key rotation explicitly in their own protocol logic.

**Kernel integration note:** The Identity Module is a standard protocol module. It is not special-cased in the kernel beyond the bootstrap exception defined in Section 4.3. The Claim Verifier reads the Identity Module's namespace via the State Store to resolve public keys during signature verification. This is a read-only dependency. The kernel does not write to the Identity namespace.

---

## 10. Verification Pipeline

Every claim from the Commit Channel stream passes through the following pipeline before state is modified.

### 10.1 Pipeline Stages

**Stage 1 — Ingestion**

The kernel receives a claim from the Commit Channel stream. If the claim references an external payload, a retrieval request is issued to the Storage Client. If the payload is not yet available, the claim is marked `Incomplete` and placed in the pending queue (Rule D-4). Processing does not continue until the payload is available and its hash verified.

**Stage 2 — Kernel Verification (Claim Verifier)**

The Claim Verifier runs steps 1–6 from Section 4.3. Failure at steps 1–5 produces a `KernelRejection`. Step 6 never produces a rejection; it produces `Incomplete` status only. Kernel-rejected claims do not proceed to module validation.

**Stage 3 — Module Validation (Reducer Host → Module.validate)**

The Reducer Host routes the claim to the module registered for its `(claim_type, payload_kind)`. Results:

- `Valid` → proceed to Stage 4.
- `Invalid(reason)` → `ModuleRejection`. Recorded. Processing stops.
- `Deferred(dep_id)` → placed in dependency queue. Processing suspended.

**Stage 4 — State Reduction (Reducer Host → Module.reduce)**

`reduce(namespace_state, claim)` is called. Returns a `StateProposal`. The Reducer Host validates namespace boundaries and applies the proposal atomically. The State Store computes the new `state_root`.

**Stage 5 — Signing Request (Optional)**

`signing_request(namespace_state, claim)` is called. If non-null, the request is forwarded through the Key Manager signing pipeline. Approval or rejection is a participant decision (or client-layer policy decision). If approved, the signed response claim is submitted to the Commit Channel.

Stages 4 and 5 are independent. A claim may produce a state reduction without requiring a signing request.

### 10.2 Pipeline Invariants

- State mutation does not occur before Stage 2 passes.
- Module code does not execute before Stage 2 passes.
- Signing does not occur before Stages 2, 3, and 4 complete.
- Claims are processed in `sequence_position` order within their channel.
- Claims from different channels may be processed in parallel; claims from the same channel are processed serially in `sequence_position` order (Rule D-15).
- `parent_claim_ids` entries must reference claims within the same channel as the referencing claim; cross-channel parent references are rejected at Stage 2 (Rule D-15).
- Namespace roots are updated incrementally after each `StateProposal` application; full recomputation is not performed during normal operation (Rule D-16).
- Cross-module namespace reads during Stage 3 and Stage 4 are restricted to the most recent global checkpoint state of the read namespace; live post-checkpoint state of foreign modules is not accessible (Rule D-17).
- Cross-module visibility lag is bounded by the checkpoint interval `C`; no claim may assume zero-lag foreign namespace visibility (Rule D-18).
- Claim routing is determined solely by the active `ChannelModuleRegistry`; no other binding source is consulted (Section 5.7). Claims arriving on an unregistered channel are `KernelRejected` with `UnregisteredChannel`. Claims matching more than one module's accepted types are `KernelRejected` with `AmbiguousRouting`.
- The identity bootstrap exception is applied deterministically: an `assertion(identity_claim)` for an unknown author key uses the payload's `public_key` for signature verification (Rule D-1 amendment).

### 10.3 Rejection Recording

All rejections (`KernelRejection`, `ModuleRejection`) are recorded in the State Store with `claim_id`, `sequence_position`, rejection stage, reason code, and timestamp. Rejection records are surfaced to the Client Layer via the State API.

---

## 11. Security Model

### 11.1 Trust Hierarchy

```
Fully trusted:
    Verification Kernel
    (Key Manager, State Store, Claim Verifier, Replay Engine, Reducer Host)

Trusted protocol interpreters (audited, registry-verified):
    Protocol Modules
    (Interstellar Markets, Portal Subsystem, Governance, Identity)

Untrusted:
    Everything else
    (Client Layer, agents, Storage Client, claim stream contents, all payloads)
```

The kernel boundary is the security boundary. Everything outside the kernel is untrusted input.

### 11.2 Threat Model

**Malicious claim payloads.** An attacker publishes a structurally valid claim with a crafted payload. Defense: kernel verification runs before module code; payload hash verification prevents payload substitution after publication.

**Compromised module binary.** A module binary is replaced with a malicious version. Defense: content-hash verification against the module registry before loading. A compromised module can corrupt its own namespace but cannot access keys, other namespaces, or the network.

**Invalid solver proposals.** A malicious solver submits a bundle that appears valid but contains incorrect fills. Defense: the Markets Module reducer independently re-derives the eligible set and verifies the selection result in the `bundle_finalize` reduction. An invalid finalize claim is rejected at Stage 3.

**Key compromise.** The participant's key storage is accessed by an attacker. Defense: hardware wallet delegation; at-rest encryption; key rotation procedures. The kernel does not expose a key export interface.

**Replay attacks.** A prior valid claim is resubmitted. Defense: author clock validation (Stage 2) requires strictly increasing clock values per author per channel.

**State divergence.** Two participants derive different `state_root` values for the same history. Defense: state root cross-checking at checkpoints detects divergence; `module_content_hashes` in checkpoint records enables root cause identification; `channel_state_roots` in checkpoints enables per-channel divergence isolation; `channel_module_registry_hash` in checkpoints enables detection of registry mismatches; test vector conformance reduces implementation divergence probability.

**Registry configuration divergence.** Two nodes use different `ChannelModuleRegistry` configurations and silently produce divergent `state_root` values while each believing itself correct. Defense: `channel_module_registry_hash` is committed in every checkpoint and snapshot. A registry mismatch between nodes is detectable at the first checkpoint comparison. The registry is governance-controlled; any registry change requires a `resolution(parameter_activation)` claim visible to all participants.

**Payload withholding.** An attacker withholds payload data to stall a participant's kernel. Defense: `Incomplete` claims remain pending indefinitely per D-7. This does not affect safety — the `state_root` is not affected and the attacker cannot cause incorrect state. However, payload withholding is not operationally cheap for the victim. A sustained campaign creates long-lived pending queue pressure, memory consumption, and synchronization lag. The system is safe but the operator cost of sustained withholding is real and should be planned for. Operator alerting thresholds (Section 6.2) are the primary mitigation.

**Snapshot poisoning.** A snapshot provider distributes a snapshot with incorrect state. Defense: the verifiable snapshot model (Section 5.4) requires four layers of verification — internal hash consistency (step 2), state root recomputation (step 3), module registry verification (step 3a), and registry configuration verification (step 3b). A snapshot derived from malicious module binaries is rejected at step 3a. A snapshot produced under a different registry configuration is rejected at step 3b.

**Checkpoint-visibility lag exploitation.** A protocol actor attempts to exploit the bounded staleness of foreign namespace reads (D-17, D-18) by timing claims to race the checkpoint boundary and observe inconsistent module state. Defense: D-18 specifies that cross-module visibility lag is bounded by `C` claims. No conformant protocol specification may assume zero-lag foreign reads. The composition doctrine (Section 1.8) further restricts foreign reads to configuration-like state that is inherently checkpoint-tolerant. Any protocol vulnerable to this class of attack was incorrectly specified.

**Cross-module read ordering attack.** An attacker attempts to cause state divergence by crafting claims that exploit differences in channel replay ordering when modules read each other's namespaces. Defense: Rule D-17 restricts all cross-module namespace reads to checkpoint-scoped state, making them independent of live replay ordering. No ordering attack on cross-module reads is possible when D-17 is enforced.

**Composition drift.** The module ecosystem gradually accumulates unsafe foreign reads — timing-sensitive interactions expressed as `read_foreign` instead of explicit claims — until protocol reasoning degrades and subtle race conditions emerge. Defense: the composition doctrine (Section 1.8) establishes the architectural rule and the criteria for safe vs. unsafe foreign reads. Protocol specifications must document their cross-module interactions and justify foreign reads against the `0 ≤ lag ≤ C` bound. The cross-module coordination pattern table (Section 6.8) is the operational reference.

**Identity authority overread.** A downstream protocol assumes that a registered identity record implies authority or permission beyond key possession. Defense: Section 9.4 explicitly declares that the Identity Module is a key-binding registry only. It does not assign authority, roles, or membership. Protocols that assign permissions to keys must do so through their own governance-controlled mechanisms, not by reading identity records and assuming semantics the module does not provide.

**Identity bootstrap impersonation.** An attacker attempts to register a key with a false identity by exploiting the self-authenticating exception. Defense: the bootstrap exception only proves key possession. It does not grant any protocol permissions beyond what the Identity Module's rules and higher-level governance assign to the registered identity. An attacker who registers a key can only act under that key; they cannot impersonate keys they do not possess.

**Zenon equivocation.** Zenon presents different orderings to different participants. Defense: `state_root` cross-checking at checkpoints will detect ordering divergence.

**Bitcoin header bootstrap divergence (Portal-specific).** Two Portal nodes use different bootstrap checkpoints and disagree on deposit validity. Defense: the Portal bootstrap checkpoint is a governance-controlled parameter (`portal.bootstrap_checkpoint`). All conformant Portal instances must match the active governance value. Divergence is detectable and constitutes a misconfiguration.

### 11.3 Security Invariants

1. Private keys never leave the Key Manager in plaintext.
2. Module code never executes on kernel-rejected claims.
3. Signing never occurs before Stages 2, 3, and 4 complete.
4. All state mutations are atomic and append-log-recorded.
5. All external payload data is hash-verified before use.
6. Author clocks prevent claim replay within a channel.
7. Namespace boundaries prevent cross-module state corruption.
8. Local policy never affects `state_root`.
9. `Incomplete` claims are never rejected or evicted on the basis of local network conditions (payload unavailability is a liveness concern, not a safety concern; eviction is prohibited by D-7a).
10. Snapshots are verifiable by hash computation without trusting the provider; snapshots derived from unregistered module binaries are rejected at verification step 3a; snapshots produced under a different registry configuration are rejected at step 3b.
11. `parent_claim_ids` entries never reference claims from a different channel; cross-channel parent references are rejected at Stage 2.
12. Namespace roots are maintained incrementally; per-claim state root computation cost is `O(k log N)` independent of total namespace size.
13. Cross-module namespace reads are restricted to checkpoint-scoped state; no ordering dependency between parallel channel replays arises from cross-module reads (D-17); cross-module visibility lag is bounded by the checkpoint interval (D-18).
14. The identity bootstrap exception is deterministic; all conformant implementations apply the self-authenticating path for `assertion(identity_claim)` claims with no pre-existing namespace entry for the author key.
15. The Portal bootstrap checkpoint is a governance-controlled parameter; Portal instances not matching the active governance value must not settle deposits.
16. Channel-to-module binding is determined solely by the active `ChannelModuleRegistry`; the registry hash is committed in every checkpoint and snapshot; configuration divergence is detectable at checkpoint time.
17. The Identity Module establishes key possession only; it does not assign authority, roles, or membership; protocols depending on identity-derived authority are relying on semantics the module does not provide.
18. Foreign reads are used only for configuration-like state; action-like cross-module coordination is expressed as explicit claims; this invariant is the boundary condition for ecosystem composability without semantic entanglement.

---

## 12. Client Layer

The Client Layer contains all components outside the Verification Kernel. These components are untrusted from the kernel's perspective and communicate with the kernel only through the State API.

### 12.1 State API

```
get_state_root(sequence_position?) → StateRoot
get_module_namespace(module_id, key_pattern) → Map<Bytes, Bytes>
get_claim_status(claim_id) → ClaimStatus      // Pending | Incomplete | Verified | Rejected
get_pending_signing_requests(filter?) → List<PendingSigningRequest>
approve_signing_request(request_id) → Result
reject_signing_request(request_id) → Result
submit_claim(claim_envelope) → SubmitResult
deliver_payload(claim_id, payload_bytes) → DeliveryResult
```

### 12.2 Wallet UI

An external process querying the State API to display participant state and submit unsigned claims. Has no special trust relationship with the kernel.

### 12.3 Agents

External processes automating protocol participation. Agents query the State API to observe coordination object state, construct unsigned claims, and submit them through `submit_claim`. Agents never possess signing keys and are treated as adversarial inputs by the kernel.

### 12.4 Automation Policy

Client-side configuration governing automated approval of signing requests. Implemented as a Client Layer component that monitors pending signing requests via the State API and calls `approve_signing_request` programmatically when requests match defined criteria. The kernel has no awareness of automation policy. It is never in the kernel. It does not affect `state_root`.

### 12.5 Storage Client

Client Layer component responsible for payload retrieval. Delivers payloads to the kernel via `deliver_payload`. The kernel verifies all delivered payloads against the recorded hash before use.

Sources may include local filesystem cache, archive node, community storage peers, or any content-addressed store. The kernel's security is unaffected by storage source because all payloads are hash-verified.

### 12.6 Module Archive

The historical store of module binaries required for full history replay (Section 5.6). Maintained as a Client Layer component. Binaries are content-addressed and publicly distributable. The Reducer Host retrieves historical binaries from the Module Archive via the Client Layer interface.

---

## 13. Relationship to Protocol Specifications

### 13.1 Separation of Concerns

**Protocol specifications define claim formats, payload kinds, coordination object lifecycles, and semantic rules.**  
**Interstellar OS implements deterministic ingestion, verification, and reduction.**

The kernel changes only when the base claim vocabulary, the module interface contract, or the state root computation changes. Protocol-level rule changes are expressed as new module versions, activated at a specific sequence position via the Governance Module.

### 13.2 Commit Channels

Commit Channels defines the canonical claim envelope format, the channel lifecycle model, and the causal ordering rules. The Claim Verifier implements Commit Channels structural verification. The kernel is a Commit Channels client.

### 13.3 Interstellar Markets (ZIM)

ZIM protocol objects (intents, lanes, bundles) are expressed as claim payloads. ZIM defines `payload_kind` values, validation rules, and reducer behavior. The kernel has no knowledge of market semantics.

ZIM's auction is fully claim-driven. `resolution(bundle_finalize)` claims carry the selected bundle reference and the verifiable selection proof. Validators order claims; the Markets Module verifies the selection result.

All market state is reproducible by replaying the ZIM claim history through the Markets Module reducer.

### 13.4 Portal

Portal defines the Bitcoin SPV proof format, escrow script construction, and BTC-backed claim rules. The Portal Subsystem implements client-side Portal verification. The kernel treats Portal as a high-risk, separately audited module.

The Portal bootstrap checkpoint is a governance parameter (`portal.bootstrap_checkpoint`). It must be activated via `resolution(parameter_activation)` before any deposit settlement claims are accepted. This ensures all participants share a common Bitcoin header chain ancestry commitment. See Section 9.2 for the full requirement.

### 13.5 Governance

The Governance Module tracks parameter proposals and activates changes at specified sequence positions. Protocol upgrades — including module version upgrades — require a `resolution(parameter_activation)` claim. The upgrade takes effect at the `activation_sequence_position` in the claim, preserving deterministic replay for all participants.

---

## 14. Conformance and Test Vectors

### 14.1 The Conformance Criterion

An Interstellar OS implementation is conformant if and only if:

> **Given the same claim history, the same genesis state, and the same module binaries (verified by content hash), the implementation produces the same `state_root` at every checkpoint position.**

This criterion subsumes all other correctness properties. An implementation satisfying it correctly implements the kernel specification.

### 14.2 Test Vector Categories

The test vector suite is required for interoperability. Without it, divergence between implementations is undetectable until participants observe mismatched state roots in production.

**Category 1: Structural verification vectors.**  
Claims with known-valid and known-invalid structural properties. Expected output: `KernelRejection` or `Incomplete` or `Valid` for each, with rejection reason codes. Includes `CrossChannelParentReference` and `UnregisteredChannel` rejection cases.

**Category 2: Module validation vectors.**  
Claim payloads with known-valid, known-invalid, and known-deferred semantic properties for each module. Expected output: `Valid`, `Invalid(reason)`, or `Deferred(dep_id)`.

**Category 3: Reducer output vectors.**  
`(namespace_state, claim)` pairs with expected `StateProposal` outputs. These vectors test the pure reducer function in isolation, without the kernel. Any implementation of the reducer that passes these vectors is conformant for that module.

**Category 4: State root vectors.**  
Sequences of verified claims with expected per-channel `channel_state_root` and global `state_root` after each application. These are the primary integration test. Includes parallel-vs-sequential channel replay vectors that must produce identical `state_root` values.

**Category 5: Replay vectors.**  
Full claim histories from genesis to checkpoint N with expected `state_root` at checkpoint N and at each intermediate checkpoint. These test the Replay Engine's checkpoint management across multiple channels. Includes vectors verifying `channel_module_registry_hash` values at each checkpoint.

**Category 6: Pending queue vectors.**  
Claim sequences with delayed payload delivery. Expected output: correct `Incomplete` status, correct re-insertion order when payload arrives, correct `state_root` after resolution. Includes vectors verifying that incomplete claims are NOT evicted when their coordination objects remain unresolved (D-7a).

**Category 7: Verifiable snapshot vectors.**  
Snapshot records with expected verification pass/fail results, including: tampered `snapshot_data` (fail step 2), mismatched `snapshot_hash` (fail step 2), `state_root` recomputation mismatch (fail step 3), `module_content_hashes` not in local registry (fail step 3a), `channel_module_registry_hash` mismatch (fail step 3b), correct snapshots passing all steps.

**Category 8: Identity bootstrap vectors.**  
Claim sequences exercising the identity bootstrap path: (a) `assertion(identity_claim)` as the first claim by a key — expected: self-authenticating verification passes, key written to namespace; (b) a second claim by the same key after bootstrap — expected: standard namespace lookup path; (c) an `assertion(identity_claim)` with a signature that does not match the payload's `public_key` — expected: `KernelRejection`.

**Category 9: Cross-module read determinism vectors.**  
Multi-channel claim sequences where Module A reads Module B's namespace. Expected: identical `state_root` regardless of which channel's claims are processed first. Includes vectors verifying the checkpoint-scoped read boundary: Module A reads a value written to Module B after the last checkpoint and must NOT see it until the next checkpoint (D-17, D-18).

**Category 10: Channel replay ordering vectors.**  
Multi-channel claim sequences processed in all valid interleavings (channels processed in different orders). Expected: identical `state_root` across all interleavings. These vectors directly validate the channel-parallel replay invariant from Section 1.7 and the combined effect of D-15 and D-17. Reference implementations must pass all interleavings, not just the canonical sequential order. This is the primary test for the scaling property of the architecture.

**Category 11: Composition doctrine vectors.**  
Cross-module claim sequences that exercise the boundary between safe and unsafe foreign reads. These vectors verify that (a) configuration-like foreign reads (governance parameters, bootstrap constants) behave correctly under varying checkpoint lag, (b) action-like coordination expressed as explicit claims produces correct and deterministic state, and (c) a module that attempts to use `read_foreign` for timing-sensitive state would produce incorrect results at the maximum lag bound, demonstrating why explicit claims are required.

### 14.3 State Root Publication

Conformant implementations should publish their `state_root` at each checkpoint to a designated discovery channel. Cross-checking with peers detects divergence. Systematic divergence indicates an implementation bug, module version mismatch, or data integrity failure.

### 14.4 Module Registry

The participant's module registry records, for each module:

```
RegistryEntry {
    module_id:      ModuleId
    content_hash:   Bytes[32]       // BLAKE3 of the module binary
    version:        SemVer
    audit_record:   URI             // reference to public audit report
}
```

The Reducer Host refuses to load any module not present in the registry. Loading a module whose content hash does not match the registry entry is a security violation, not a configuration error.

---

## Appendix A: Glossary

| Term | Definition |
|---|---|
| Claim | A signed, structured coordination event published to a Commit Channel. The primary protocol primitive. |
| Coordination Object | A shared multi-party interaction managed by a protocol module, derived from claim history, with a defined lifecycle from `assertion` to `resolution`. |
| Base Claim Type | One of the seven base types (`assertion`, `proposal`, `support`, `rejection`, `challenge`, `state_update`, `resolution`). Stable. Processed by the kernel. |
| Payload Kind | A module-defined string identifying the protocol-specific meaning of the claim payload. Processed by the relevant module. |
| Channel State Root | A BLAKE3 commitment over the namespace roots of all modules associated with a given Commit Channel, at a given sequence position within that channel. |
| State Root | A BLAKE3 commitment over the sorted set of all channel state roots at a given global position. The primary correctness proof for the kernel. |
| Channel Replay Pipeline | The independent deterministic replay pipeline associated with a single Commit Channel. Claims within the pipeline are processed serially in sequence position order. Pipelines for different channels may run in parallel. |
| ChannelState | The kernel's per-channel runtime record: `channel_id`, `replay_position`, and `channel_state_root`. |
| ChannelModuleRegistry | The governance-controlled canonical source of truth for channel-to-module binding. Defines which modules are associated with each channel. Its hash is committed in every checkpoint and snapshot. Defined in Section 5.7. |
| Cross-Module Visibility Lag | The bounded staleness introduced by D-17 and D-18: a state mutation written to Module B's namespace is visible to Module A's `read_foreign` calls at the earliest at the next global checkpoint after the mutation. The lag is bounded by `0 ≤ lag ≤ C` claims where `C` is the checkpoint interval. |
| Key-Binding Registry | The correct characterization of the Identity Module's scope: it records associations between public keys and identity identifiers, proving key possession only. It does not assign authority, roles, reputation, or membership semantics. |
| Canonical Authenticated Map | The canonical data structure for `ModuleNamespace.namespace`: a sparse Merkle tree using BLAKE3 with domain-separated leaf keys, leaf values, empty subtrees, internal nodes, and root hash. Specified in Section 6.7. Required for snapshot interoperability. |
| Authenticated Map | More broadly: any key-value data structure that maintains a cryptographic root commitment and supports incremental root updates in `O(k log N)` time. The canonical form required by this spec is the sparse Merkle tree defined in Section 6.7. |
| Checkpoint | A record of `state_root`, per-channel `sequence_positions`, per-channel `channel_state_roots`, `module_content_hashes`, `channel_module_registry_hash`, `checkpoint_interval`, and `snapshot_hash` at a defined position. |
| Verifiable Snapshot | A full state capture plus `snapshot_hash`, `state_root`, and `channel_module_registry_hash`, verifiable by hash computation without trusting the provider. Passes internal consistency, state root, module hash, and registry hash checks. Does not prove canonical history without peer confirmation. |
| Module Archive | The Client Layer store of historical module binaries, identified by content hash, required for deterministic historical replay. |
| Reduction | Applying a verified claim through the pure reducer function `reduce(namespace_state, claim) → StateProposal`. Deterministic. |
| Reducer Determinism Contract | The normative constraints (RDC-1 through RDC-8) on module reducer implementations. A module violating these constraints is non-conformant. |
| Deterministic Module SDK | The canonical reference implementation of determinism primitives for the Interstellar module ecosystem: `CanonicalMap`, `FixedPoint`, `CanonicalBytes`, and `BLAKE3Hasher`. Modules using the SDK satisfy RDC-5, RDC-6, and RDC-7 by construction. |
| Self-Authenticating Claim | An `assertion(identity_claim)` processed by the bootstrap exception: when no Identity namespace entry exists for the author key, signature verification uses the `public_key` declared in the payload. Defined in Section 4.3 and Section 9.4. |
| Checkpoint-Scoped Read | A cross-module namespace read (via `read_foreign`) that returns the target namespace's state as committed at the most recent global checkpoint, not live post-checkpoint state. Required by Rule D-17 to preserve channel parallelism determinism. |
| Incomplete Claim | A structurally valid claim whose external payload has not yet been retrieved. Held in the pending queue. Never rejected or evicted while its coordination object remains unresolved (D-7a). |
| Deferred Claim | A structurally valid claim whose semantic validation depends on a prior unresolved claim. Held in the dependency queue. |
| Verified Claim | A claim that has passed all kernel and module verification steps. |
| Authorized Response | A new claim signed by the participant's key following a verified and reduced prior claim. Does not affect `state_root`. |
| Author Clock | A per-author monotonic counter enforcing claim ordering within a channel and preventing replay. Cannot be reset; key rotation is the recovery path for lost clock state. |
| Trusted Protocol Interpreter | A module audited against the Reducer Determinism Contract, versioned by content hash, and loaded from the participant's module registry. |
| Client Layer | All components outside the Verification Kernel. Untrusted. Communicates with the kernel only via the State API. |
| Signing Boundary | The interface between the Key Manager and all other components. Private keys do not cross this boundary. |
| Cross-Channel Coordination | Protocol coordination expressed through independent claims published to multiple channels, not through cross-channel `parent_claim_ids` references (which are prohibited by D-15). |
| Composition Doctrine | The architectural rule (Section 1.8) governing module interoperability: explicit claims for action-like cross-module state; `read_foreign` for configuration-like state. The boundary condition that allows composability without semantic entanglement. |
| Safe Foreign Read | A `read_foreign` call on configuration-like, slowly changing state (governance parameters, bootstrap constants, registry versions) whose correctness is unaffected by lag of up to `C` claims. Permitted under the composition doctrine. |
| Unsafe Foreign Read | A `read_foreign` call on timing-sensitive, action-like state (live market state, open intents, auction inputs, unsettled race conditions) whose correctness requires tighter synchronization than `C`-claim lag permits. Must be expressed as an explicit claim instead. |
| Partial Verification Node | A node that synchronizes only a subset of channels. Such a node verifies local channel state independently but must rely on peer-confirmed roots for channels it does not track. Provides partial rather than full independent state verification. |
| AmbiguousRouting | A `KernelRejection` error produced when a claim's `(claim_type, payload_kind)` pair matches the `accepted_claims` sets of more than one module on the same channel. Indicates a non-conformant `ChannelModuleRegistry` that should have been rejected at governance activation. |

---

## Appendix B: Design Non-Goals

1. **Smart contract execution.** The kernel does not execute arbitrary code. Modules are deterministic protocol interpreters.
2. **Consensus participation.** The kernel does not participate in Zenon or Commit Channels consensus. It consumes their outputs.
3. **Global state agreement by coordination.** Agreement is an emergent property of shared rules applied to shared ordered input. There is no coordination protocol between runtime instances.
4. **Validator-side protocol logic.** Validators order claims. They do not compute auctions, evaluate bridge proofs, or execute governance.
5. **Cross-chain bridging beyond Portal.** Bitcoin integration via Portal is the only bridge mechanism in scope for this version.
6. **Payload storage.** The kernel verifies payload hashes. Payload retrieval and storage are Client Layer concerns.
7. **Full namespace recomputation during steady-state operation.** The verifiable snapshot model addresses replay cost at scale. Incremental namespace root maintenance (Rule D-16) is a normative requirement: full recomputation is permitted only for verification, recovery, and test mode. Parallel channel replay is a direct consequence of the channel-scoped replay model, not an optimization.
8. **Identity authority semantics.** The Identity Module establishes key possession. Role assignment, authorization, reputation, and trust domain membership are not kernel concerns. Protocol modules and governance parameters that require these semantics must define them explicitly.
9. **Unrestricted cross-module composition.** The kernel provides `read_foreign` as a mechanism for safe configuration reads, not as a general integration bus. Cross-module action coordination must be expressed as explicit claims. Protocols that require tight cross-module synchronization must publish claims, not poll foreign namespaces. The composition doctrine (Section 1.8) is load-bearing; relaxing it degrades architectural clarity and reasoning tractability.

*Interstellar OS — End of Specification*
