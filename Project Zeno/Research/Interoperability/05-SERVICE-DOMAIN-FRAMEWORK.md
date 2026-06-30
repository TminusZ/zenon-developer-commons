# Project Zeno: Service Domain Framework

**Document status:** Frontier research. Non-normative.
**Version:** 0.1.0
**Governing documents (in priority order):**

1. `SPEC.md` v1.3.0 (the controlling authority for all on-chain rules)
2. `BRIDGE-FRAMEWORK-SPEC.md` v0.2.0 (the Bridge Framework normative specification)
3. `EXECUTION-PROVIDER-FRAMEWORK.md` v0.1.0 (the Execution Provider architecture)
4. `INTENT-ORDERFLOW-FRAMEWORK.md` v0.1.0 (the Intent and Orderflow architecture)
5. `ECONOMIC-SECURITY-FRAMEWORK.md` v0.1.0 (the Economic Security architecture)

This document is Frontier research. It does not make implementation claims, introduce new protocol features, or bind any deployment. Every speculative mechanism is explicitly marked. Where this document references a mechanism defined in a governing document, the governing document controls.

**Purpose:** The previous Frontier documents explain how value moves across chains, how users express outcomes, how Execution Providers compete, and how economic incentives align participants. This document answers the next architectural question: what kinds of long-lived network services should exist as independent domains built on top of the Domain Settlement Layer? It defines the architectural pattern for turning infrastructure itself into modular, settlement-backed services.

**Boundary discipline:** This document does not extend Settlement, modify the domain model, or introduce new consensus rules. It describes an architectural pattern (the Service Domain) that is already expressible within the existing domain model (`SPEC.md` §6; `BRIDGE-FRAMEWORK-SPEC.md` §6.1) and explains why that pattern, applied broadly, transforms the network from cross-chain infrastructure into a general settlement architecture.

**Commit discipline:** Settlement should remain minimal. Services should become domains. If a capability described here would require Settlement to absorb new logic (identity verification, oracle aggregation, storage management, AI execution), the design is wrong. The capability must be expressed as a domain, not a protocol modification.

---

## 1. Why this document exists

### 1.1 The observation

The Domain Settlement Layer, as specified in `SPEC.md`, anchors domains. A domain is an isolated execution environment with its own state, its own STF, its own input source, its own executor set, and its own lineage, all committed through Settlement without Settlement understanding what the domain computes. Settlement does not know whether a domain runs a WASM smart-contract runtime, verifies Bitcoin SPV headers, or computes exchange rates. It knows the domain's roots, its contiguity, its conservation bounds, and its finality status. That is all it needs to know.

The Bridge Framework applied this pattern to cross-chain asset movement: each bridged chain is a domain. The Execution Provider Framework applied it to fulfillment: Execution Providers consume finalized authorizations from domains. The Intent Framework applied it to user outcomes: users express desires that Execution Providers fill.

But the pattern is not limited to bridges. Every sufficiently important infrastructure function, oracles, identity, storage, data availability, AI compute, messaging, payments, indexing, key management, and rollup coordination, can be expressed as a domain with its own STF, its own execution model, and its own economic profile. The infrastructure becomes modular: adding a capability means registering a new domain, not changing the protocol.

This document names that pattern (the Service Domain), defines its properties, and explains why it is the right architecture for scaling network capabilities without scaling consensus.

### 1.2 The central thesis

> **Settlement should not become larger. The network around Settlement should become richer. Every new capability should become a domain, not a protocol modification.**

Monolithic blockchains add features by adding opcodes, precompiles, system contracts, or consensus-level protocols. Each addition makes consensus more complex, harder to audit, slower to upgrade, and more brittle. A bug in an oracle precompile can halt the chain. A storage-pricing miscalculation can congest the network. An identity module can become a censorship vector.

The Service Domain architecture inverts this: Settlement remains a fixed, minimal, auditable truth machine. New capabilities are deployed as domains alongside it, each isolated, each independently upgradeable, each with its own failure boundary. A buggy oracle domain cannot halt Settlement. A storage domain's pricing error cannot congest the momentum chain. An identity domain's compromise cannot censor bridge operations. Failures remain domain-local because responsibilities remain domain-local.

### 1.3 What this document is not

This is not a smart-contract specification (arbitrary user programs are already covered by the WASM runtime domain). This is not a bridge specification (that is `BRIDGE-FRAMEWORK-SPEC.md`). This is not an execution or intent specification (those are their respective Frontier documents). This document defines the architectural pattern for infrastructure services that are neither user contracts nor bridges, but the connective tissue of a programmable network.

---

## 2. What is a Service Domain

### 2.1 Definition

A **Service Domain** is an independent execution environment whose purpose is to provide an infrastructure capability rather than a general application runtime.

Unlike a WASM domain that executes arbitrary user programs (the Phase 1 base case), a Service Domain exposes a specialized capability: price feeds, identity attestations, data storage, message routing, payment processing, compute orchestration, or any other infrastructure function. It inherits all Settlement guarantees (deterministic replay, conservation, replay protection, finality, domain isolation) without requiring any change to Settlement.

### 2.2 How it differs from a smart-contract runtime

A smart-contract runtime (the WASM domain) is a **general-purpose substrate**: users deploy arbitrary code, and the runtime executes whatever the code says. The runtime's value is generality. Its STF is a VM.

A Service Domain is a **special-purpose substrate**: it exposes a specific capability through a constrained interface, and its STF is optimized for that capability. The domain's value is not generality but specialization: an oracle domain computes aggregated price feeds more efficiently, more securely, and with a better-defined trust model than an oracle implemented as a WASM smart contract on a general-purpose runtime.

| Property | Smart-contract runtime (WASM domain) | Service Domain |
|---|---|---|
| **Purpose** | Execute arbitrary user programs | Provide a specific infrastructure capability |
| **STF** | A VM that runs user-deployed bytecode | A purpose-built state machine for the capability |
| **Input vocabulary** | Generic (`CallL2`, `Deploy`, `Upgrade`) | Capability-specific (e.g. `SubmitPriceFeed`, `StoreBlob`, `RoutePayment`) |
| **User interaction** | Deploy code, call contracts | Consume the capability (query a price, store data, send a message) |
| **Upgrade model** | Users deploy new contracts; the VM upgrades via `stfSpecHash` bump | The service's STF upgrades via `stfSpecHash` bump; no user-deployed code |
| **Economic model** | Gas-metered execution of arbitrary computation | Capability-specific pricing (per-query, per-byte, per-message, subscription) |
| **Failure surface** | Any user contract can have bugs | Only the service's own STF can have bugs; no user-deployed code to audit |

### 2.3 The relationship to `SPEC.md` §6

A Service Domain is not a new kind of domain. It is an ordinary domain (`SPEC.md` §6) whose `DomainPlugin` implements a service rather than a VM. The `Genesis` / `DecodeInput` / `Apply` interface (`EXECUTOR.md` §7) is the same. The commitment format is the same. The contiguity, conservation, and replay rules are the same. The only difference is what the `Apply` function does: instead of interpreting bytecode, it processes service-specific inputs (price submissions, storage requests, identity attestations) and produces service-specific effects (price state updates, stored blobs, issued credentials).

This is the key architectural point: **no Settlement change is needed.** A Service Domain is registered like any other domain (`RegisterDomain`), bonded like any other domain, committed like any other domain, and finalized like any other domain. Settlement treats it identically. The specialization is entirely inside the plugin.

---

## 3. Service Domain Properties

Every Service Domain should exhibit the following architectural properties. These are inherited from the domain model (`SPEC.md` §6; `BRIDGE-FRAMEWORK-SPEC.md` §6.1) and restated here for the service context.

### 3.1 Inherited from the domain model

**Isolated state.** Each Service Domain's state is a separate SMT, keyed by `domainId`. No domain can read or write another domain's state. A buggy oracle domain cannot corrupt a payment domain's balances. (`SPEC.md` §6; `BRIDGE-FRAMEWORK-SPEC.md` §13.13.)

**Independent STF.** Each Service Domain has its own `Apply` function, pinned by `stfSpecHash`. The oracle domain's STF aggregates price feeds; the storage domain's STF manages blob commitments; the identity domain's STF issues credentials. Each STF is pure, deterministic, and independently auditable. (`SPEC.md` §7.3; `EXECUTOR.md` §7.)

**Settlement-anchored outputs.** Service Domain effects (price updates, stored data, issued credentials) are committed through the batch commitment (`inputRoot`, `receiptRoot`, `eventRoot`, `outboxRoot`) and finalized through Settlement's standard finality mechanism. They are as trustworthy as any other Settlement-anchored fact. (`SPEC.md` §19.)

**Deterministic replay.** Any party can reconstruct a Service Domain's state from L1-anchored data (canonical inputs + committed bundles). No live network access to the service is required for replay. This means the service's history is auditable and verifiable by anyone, forever. (`EXECUTOR.md` §10.)

**Replay protection.** Service Domain inputs are replay-protected by the same mechanism as any other domain: `globalInputIndex` contiguity for L1 inputs, and per-domain input-sequence contiguity for all sources. (`SPEC.md` §4.6.)

**Version independence.** Each Service Domain carries its own version fields (`protocol_version`, `metering_version`, etc.) and its own `stfSpecHash`. Upgrading one service does not affect any other service or Settlement. (`SPEC.md` §24.)

**Independent upgrade cadence.** A Service Domain upgrades via a `stfSpecHash` bump under `MinRuntimeUpgradeDelay`, independently of any other domain. The oracle domain can upgrade its aggregation algorithm without touching the storage domain, the bridge domains, or Settlement. (`SPEC.md` §6.2, §23.)

### 3.2 Service-specific properties

**Capability-specific input vocabulary.** A Service Domain defines its own input types through `DecodeInput`. An oracle domain accepts `SubmitPriceFeed`, `RequestAggregation`, and `QueryPrice`. A storage domain accepts `StoreBlob`, `RetrieveBlob`, and `Extend`. A messaging domain accepts `Send`, `Receive`, and `Route`. The vocabulary is part of the STF specification and is pinned by `stfSpecHash`.

**Optional bridge support.** Some Service Domains bridge data, proofs, or identity across chains (an oracle domain might relay foreign price feeds; an identity domain might bridge attestations). Others never bridge anything (a pure storage domain stores blobs and retrieves them). Bridge support is optional and, when present, uses the Bridge Framework's `ChainVerifier` and `ReleaseAdapter` seams. (`BRIDGE-FRAMEWORK-SPEC.md` §7.3, §7.5.)

**Optional messaging support.** Some Service Domains consume or produce outbox messages (`kind=0`) to communicate with other domains. Others are self-contained. Messaging support is optional and uses the existing outbox mechanism. (`SPEC.md` §17.)

**Optional liquidity requirements.** Some Service Domains involve asset custody (a payment domain holds escrowed funds). Others involve no assets at all (an identity domain issues credentials, not tokens). Liquidity requirements are service-specific and, when present, are bounded by the conservation invariant. (`SPEC.md` §18.)

**Optional economic model.** Each Service Domain may define its own pricing for consumption: per-query fees for oracles, per-byte fees for storage, per-message fees for messaging, subscription models, or free tiers. The economic model is inside the STF (metered by L2 gas or by service-specific logic), not in Settlement. (`SPEC.md` §10.)

### 3.3 The non-requirement

**No service should require changes to Settlement itself.** If a new service needs a new Settlement opcode, a new conservation rule, a new commitment field, or a new finality model, then the service is not a Service Domain; it is a protocol modification. The architectural test for a Service Domain is: can it be deployed as a `RegisterDomain` without touching the node binary? If yes, it is a Service Domain. If no, it belongs in a future version of `SPEC.md`, not in this framework.

---

## 4. Domain Taxonomy

The domain model accommodates several categories of domain. The categories are informative (Settlement treats all domains identically), but they clarify the design space.

### 4.1 Categories

**Runtime Domains.** General-purpose execution environments that run user-deployed code. The WASM domain (Phase 1) is the base case. Future runtime domains might include EVM, SVM, MoveVM, or a ZK-friendly VM. Runtime domains are substrates; their value is generality.

**Bridge Domains.** Cross-chain asset movement domains, each binding a foreign chain via a `ChainBinding`, a `ChainVerifier`, and a `ReleaseAdapter`. Specified in `BRIDGE-FRAMEWORK-SPEC.md`. Bridge domains are connectors; their value is interoperability.

**Service Domains.** Infrastructure capability domains (this document). Each provides a specialized function (oracles, storage, identity, messaging, payments, compute). Service domains are utilities; their value is specialization.

**Infrastructure Domains.** [SPECULATIVE] Meta-level domains that provide services to other domains rather than to users directly. Examples: a DA domain that stores bundles for other domains' executors; an indexing domain that indexes other domains' events; a coordination domain that batches cross-domain operations. Infrastructure domains serve the network, not the user.

**Experimental Domains.** [SPECULATIVE] Domains deployed for research, testing, or prototyping. They carry no production SLA and may be registered with restricted caps and short lifetimes. Useful for testing new STF designs, new input vocabularies, or new economic models without risking production domains.

### 4.2 Why the taxonomy matters

The taxonomy clarifies which Frontier documents apply:

| Category | Bridge Framework | Execution Provider Framework | Intent Framework | Economic Security Framework | This document |
|---|---|---|---|---|---|
| Runtime | N/A | Optional | Optional | Yes | N/A |
| Bridge | Yes | Yes | Yes | Yes | N/A |
| Service | Optional | Optional | Optional | Yes | **Yes** |
| Infrastructure | Optional | Optional | Rarely | Yes | **Yes** |
| Experimental | Optional | Optional | Rarely | Minimal | **Yes** |

Every domain uses the Economic Security Framework. Bridge domains use the Bridge Framework. Service domains are the subject of this document. The other frameworks apply optionally, depending on the specific service.

---

## 5. Service Domain Lifecycle

### 5.1 Stages

A Service Domain passes through a lifecycle that is a superset of the domain lifecycle in `SPEC.md` §6. Settlement is unchanged during every stage.

**Design.** The service's capability is specified: input vocabulary, STF logic, state schema, economic model, and trust profile. This is an off-chain design effort. Settlement is not involved.

**Build.** The `DomainPlugin` is implemented: `Genesis`, `DecodeInput`, `Apply`, and (if the service has external inputs) `Source`. The plugin is compiled and tested. Settlement is not involved.

**Register.** `RegisterDomain` is called with the service's `stfSpecHash`, `inputSource`, `execProfile`, `foreignProfile` (if applicable), `executors`, and `valueCaps`. Settlement records the new `DomainRecord`. The service exists on-chain as a registered domain. (`SPEC.md` §6.)

**Deploy.** If the service includes user-addressable logic (a contract within the service), it is deployed via chunked deployment (`SPEC.md` §11). If the service is a pure STF with no user-deployed code, this stage may be skipped.

**Operate.** The executor runs the service's STF, processing inputs, producing batches, and publishing bundles. Users consume the service (querying prices, storing data, sending messages) by submitting inputs to the domain. Settlement anchors the commitments.

**Upgrade.** The service's STF is upgraded via a `stfSpecHash` bump under `MinRuntimeUpgradeDelay`. The upgrade may change the input vocabulary, the aggregation algorithm, the economic model, or any other aspect of the service, without affecting any other domain or Settlement. (`SPEC.md` §6.2, §23.)

**Retire.** [SPECULATIVE] A service that is no longer needed may be retired: inputs stop being accepted, the final batch is committed, and the domain enters a read-only state where its history remains verifiable but no new computation occurs. Custody-holding services must drain all escrowed assets before retirement (conservation invariant compliance).

**Migration.** A service may be migrated to a new domain (new `stfSpecHash`, new executor set, or new execution profile) with state continuity. The replacement's first `preStateRoot` equals the last accepted `postStateRoot` of the original. (`SPEC.md` §6.2.)

**Fork.** [SPECULATIVE] A service may be forked: a new domain is registered with a copy of the original's state at a specific finalized root, running a modified STF. The original continues unchanged. Both are independent domains with independent lineages.

**Deprecation.** [SPECULATIVE] A service that has been superseded may be deprecated: a notice period begins, after which the service enters retirement. Users and consumers migrate to the replacement during the notice period.

### 5.2 Settlement's role

Settlement's role in the lifecycle is the same for Service Domains as for any other domain: record the `DomainRecord`, accept batch commitments, enforce contiguity and conservation, and manage finality. Settlement does not know whether the domain is a WASM runtime, a BTC bridge, an oracle service, or a storage service. It treats all domains identically. This is the property that makes the lifecycle composable: adding a service, upgrading a service, retiring a service, and forking a service are all domain operations, not protocol operations.

---

## 6. Service Communication

### 6.1 The rule

> **Service Domains communicate through Settlement. Never directly.**

No Service Domain may read another Service Domain's state. No Service Domain may write to another Service Domain's state. No Service Domain may call another Service Domain's STF. Cross-domain interaction is asynchronous, mediated by Settlement, and subject to all of Settlement's guarantees (finality, replay protection, conservation).

### 6.2 Communication mechanisms

**Outbox messages (`kind=0`).** A Service Domain emits a message to another domain's inbox. The message is committed in `outboxRoot`, finalized, relayed via `RelayMessage`, and delivered to the destination domain's STF as an input. The message is replay-protected by `outboxId`. This is the primary inter-service communication mechanism. (`SPEC.md` §17.)

**Finalized authorizations (`kind=1`).** A Service Domain emits an asset-release authorization, consumed by a `ReleaseAdapter` or an Execution Provider. Used when the service involves asset custody (a payment domain authorizing a payout). (`SPEC.md` §17; `BRIDGE-FRAMEWORK-SPEC.md` §7.5.)

**Authenticated inputs.** A Service Domain's output (a finalized price feed, an issued credential, a stored blob commitment) is a Settlement-anchored fact. Another domain's STF can consume it as an input (via a relayer that presents the inclusion proof), verifying the proof against the source domain's finalized `outboxRoot` or `eventRoot`. The consuming domain trusts the proof, not the producing domain's executor.

**Bridge Framework.** For cross-chain service communication (an oracle domain relaying a foreign price feed, an identity domain bridging an attestation), the Bridge Framework's `ChainVerifier` and `ReleaseAdapter` seams apply. The service is a bridge domain for that specific interaction.

**Intent Framework.** [SPECULATIVE] A user may express an Intent that spans multiple services ("store this data and pay the storage fee from my bridge balance"). The Intent layer decomposes this into per-service operations; the services never see each other directly.

### 6.3 Why direct communication is forbidden

Direct cross-domain state access would:
- **Violate isolation.** A bug in one domain could corrupt another domain's state.
- **Destroy deterministic replay.** If domain A reads domain B's state at a specific point, replaying domain A requires knowing domain B's state at that point, creating a causal dependency that complicates replay, snapshotting, and independent upgrade.
- **Create finality dependencies.** If domain A's computation depends on domain B's not-yet-finalized state, domain A's own finalization becomes conditional on domain B's, creating circular dependencies.
- **Enable cross-domain conservation violations.** If domain A could debit domain B's custody directly, per-domain conservation would break.

The asynchronous, message-based model avoids all of these. Each domain's state is a pure function of its own inputs. Cross-domain dependencies are explicit (messages), mediated (by Settlement), and finalized (the message is final before the consumer acts on it).

---

## 7. Isolation

### 7.1 The failure-containment guarantee

The domain model's isolation guarantee (`SPEC.md` §6; `BRIDGE-FRAMEWORK-SPEC.md` §13.13) is the foundation of the Service Domain architecture. It states: a fault in one domain can never reach another domain's custody, state, or lineage. This is enforced by:

- Per-domain state (separate SMT per `domainId`).
- Per-domain custody accounting (conservation per `(domainId, asset)`).
- Per-domain commitment lineage (independent `InputCursor`, independent `preStateRoot`/`postStateRoot` chain).
- Per-domain executor set (an executor is bonded per `domainId`).
- Asynchronous, replay-protected communication (outbox messages are finalized before delivery).

### 7.2 Concrete isolation examples

**A buggy oracle domain cannot corrupt a payment domain.** The oracle domain's state is in its own SMT. Its custody (if any) is in its own conservation counters. Its executor is bonded independently. If the oracle's STF has a bug that produces incorrect prices, the payment domain is not directly affected, because the payment domain reads oracle data only through relayed, finalized outbox messages. The payment domain's STF must validate the oracle data it consumes (checking freshness, checking bounds, using multiple sources). A bad price from a faulty oracle is a service-quality problem for the consumers, not a state-corruption problem for Settlement.

**An AI compute domain cannot corrupt a storage domain.** The AI domain runs arbitrary compute (model inference, training steps) inside its own isolated state. Its outputs are committed through its own `outboxRoot`. The storage domain's state (blob commitments, retrieval indexes) is in a separate SMT. The AI domain cannot write to the storage domain's state, cannot debit its custody, and cannot alter its lineage. A bug in the AI domain's STF (incorrect inference, infinite loop caught by gas metering) is domain-local.

**A messaging domain cannot corrupt a bridge domain.** The messaging domain routes messages between domains. Its STF processes `Send`, `Receive`, and `Route` inputs. The bridge domain verifies foreign headers and authorizes releases. They share no state. A bug in the messaging domain's routing logic cannot alter the bridge domain's `ChainVerifier` state, cannot forge a release authorization, and cannot violate the bridge domain's conservation invariant.

### 7.3 The generalization

For any two Service Domains A and B: A's failure cannot alter B's state, B's custody, B's lineage, or B's finality. The worst A can do to B is produce incorrect outbox messages that B then consumes; B's defense is to validate the messages inside its own STF (checking proofs, checking bounds, using redundancy). This is the same security model that the Bridge Framework uses for foreign-chain data: trust the proof, not the source.

---

## 8. Economics

### 8.1 Reference

The Economic Security Framework (`ECONOMIC-SECURITY-FRAMEWORK.md`) defines the five categories of assurance (cryptographic, economic, competitive, legal, reputational), the trust models, the bond models, and the participant security models. This section does not redefine them. It applies them to Service Domains.

### 8.2 Economic profiles for services

Each Service Domain may choose its economic profile independently, from the profiles defined in the Economic Security Framework §13:

| Service | Likely economic profile | Why |
|---|---|---|
| Oracle domain | Bonded + competitive | Data providers post bonds; multiple providers compete on accuracy and latency |
| Identity domain | Legal + reputational | Identity attestation requires regulatory compliance; reputation is the primary trust signal |
| Storage domain | Bonded + market-driven | Storage providers post bonds covering data-loss guarantees; pricing is market-driven |
| DA domain | Competitive + cryptographic | DA sampling/encoding may be cryptographically verified; providers compete on pricing |
| AI compute domain | Bonded + competitive | Compute providers post bonds; results are reproducible (deterministic STF) |
| Messaging domain | Competitive + reputational | Multiple relay paths; reputation for reliability and censorship resistance |
| Payment domain | Legal + institutional | Regulated payment processing; institutional compliance |

### 8.3 Service-specific pricing

Each Service Domain defines its own pricing model inside its STF:

- **Per-query** (oracle domain): each price-feed query costs a fixed fee, deducted from the requester's domain balance.
- **Per-byte** (storage domain): storing and retrieving data costs proportional to size and duration.
- **Per-message** (messaging domain): each routed message costs a fixed fee.
- **Per-compute-unit** (AI domain): inference or compute tasks cost proportional to complexity, metered by the STF.
- **Subscription** [SPECULATIVE] (any service): a user pays a periodic fee for unlimited or capped access.
- **Free tier** [SPECULATIVE] (any service): basic access is free; premium features are paid.

The pricing model is part of the STF, enforced by gas metering (`SPEC.md` §10) or by service-specific balance logic inside the domain's contract state. Settlement does not know what the pricing model is; it only enforces that the domain's aggregate custody remains conservation-bounded.

---

## 9. Execution

### 9.1 Reference

The Execution Provider Framework (`EXECUTION-PROVIDER-FRAMEWORK.md`) defines how finalized authorizations become real-world outcomes. Service Domains interact with Execution Providers in three modes:

### 9.2 Services that never require Execution Providers

Some Service Domains produce information, not asset movements. An oracle domain publishes price feeds; a storage domain stores blobs; an identity domain issues credentials. Their outputs are Settlement-anchored facts (committed in `outboxRoot` or `eventRoot`), not asset-release authorizations. No Execution Provider is needed because there is nothing to "execute" on a foreign chain. The service's output is consumed by reading the finalized commitment, not by performing an external action.

### 9.3 Services that always require Execution Providers

Some Service Domains produce asset-release authorizations that must be fulfilled externally. A payment domain that authorizes a fiat payout needs a payment processor (an Execution Provider) to perform the actual bank transfer. A peg-out from a bridge-integrated service domain needs a `ReleaseAdapter` or a solver to release the real asset. In these cases, the Execution Provider Framework applies fully: providers observe the finalized authorization, quote, compete, and fill.

### 9.4 Services that optionally require Execution Providers

Some Service Domains produce outputs that may or may not require external action. A messaging domain may deliver messages to other Zenon domains (no Execution Provider needed; the relayer handles it) or to foreign chains (an Execution Provider is needed to deliver the message on the foreign chain). The service's STF is the same in both cases; only the delivery mechanism differs.

---

## 10. Intents

### 10.1 Reference

The Intent and Orderflow Framework (`INTENT-ORDERFLOW-FRAMEWORK.md`) defines how users express desired outcomes. Service Domains interact with the Intent layer in two modes:

### 10.2 Services that consume Intents

Some Service Domains are natural Intent consumers. A payment domain is a prime example: a user expresses "pay Alice $100 on Ethereum," and the payment domain decomposes this into a settlement authorization, a conversion (if needed), and a delivery. The Intent is the user-facing input; the domain consumes it and produces the settlement operations.

Other Intent-consuming services: a storage domain ("store this file for 30 days"), an AI compute domain ("run this inference model on this dataset"), a messaging domain ("deliver this message to Bob on Solana").

### 10.3 Services that never need Intents

Some Service Domains are infrastructure-level and do not interact with end users. A DA domain stores bundles for other domains' executors. An indexing domain indexes events for query services. A coordination domain batches cross-domain operations. These services have no user-facing Intent surface; they are consumed by other system components, not by users.

---

## 11. Bridge Interaction

### 11.1 Not all Service Domains bridge assets

The Bridge Framework is designed for cross-chain asset and message movement. Many Service Domains have no cross-chain component at all: a pure oracle domain aggregating on-chain Zenon data, a storage domain storing blobs on Zenon, an identity domain issuing Zenon-native credentials. These services do not need the Bridge Framework.

### 11.2 Services that bridge data

Some Service Domains bridge data rather than assets. An oracle domain that relays foreign price feeds (Chainlink on Ethereum, Pyth on Solana) is a bridge domain in the Bridge Framework's sense: it uses a `ChainVerifier` to verify foreign data and an `inputSource` of `L1_RELAYED` to bring that data into the domain's STF. The "asset" being bridged is information, not tokens.

### 11.3 Services that bridge identity

[SPECULATIVE] An identity domain that accepts attestations from foreign identity systems (ENS on Ethereum, .sol domains on Solana, government-issued digital IDs) is bridging identity. The `ChainVerifier` verifies the foreign attestation; the domain's STF issues a corresponding credential in its own state. No asset is moved, but a trust assertion crosses chain boundaries.

### 11.4 Services that bridge proofs

[SPECULATIVE] A domain that verifies proofs from foreign computation systems (a zk-proof of off-chain computation, a TEE attestation, a verifiable-random-function output) is bridging proofs. The `ChainVerifier` verifies the proof's validity; the domain's STF records the verified result as a Settlement-anchored fact.

### 11.5 Services that bridge execution rights

[SPECULATIVE] A rollup coordination domain that registers foreign rollup state roots and issues execution tickets is bridging execution rights. The foreign rollup's sequencer (or validator) submits state roots; the domain's `ChainVerifier` verifies them; the domain's STF issues execution rights that other domains or Execution Providers can consume.

### 11.6 Bridge support is optional

The architectural point: bridge support is a capability, not a requirement. A Service Domain that needs to verify foreign data uses the Bridge Framework. A Service Domain that does not need foreign data does not. The Bridge Framework is a library that services may use, not a tax they must pay.

---

## 12. Service Composition

### 12.1 Why composition matters

The power of the Service Domain architecture is not any single service; it is the composition of services. A payment domain that can query an oracle domain for exchange rates, verify a user's identity through an identity domain, and route the payout through a bridge domain is more valuable than any of those services in isolation. Composition turns infrastructure into a programmable network.

### 12.2 How composition works

Service Domains compose through the communication mechanisms of §6: outbox messages, finalized authorizations, and authenticated inputs. Each service remains independent; no service owns another; Settlement coordinates all of them.

Example composition:

```
Identity Domain          (authenticates the user)
    ↓ outbox message: "user X is KYC-verified"
Payment Domain           (processes the payment)
    ↓ outbox message: "convert 100 USDC to ETH at oracle rate"
Oracle Domain            (provides the exchange rate)
    ↓ outbox message: "ETH/USDC = 3,500.00 at block H"
Payment Domain           (finalizes the conversion amount)
    ↓ kind=1 authorization: "release 0.02857 ETH to recipient on Ethereum"
Bridge Domain            (handles the cross-chain release)
    ↓ finalized authorization
Execution Provider       (delivers the ETH on Ethereum)
    ↓ delivered
User                     (receives the payment)
```

Every arrow is an asynchronous, finalized, replay-protected message. Every domain has its own state, its own STF, its own executor, and its own failure boundary. The composition is loose: if the oracle domain is down, the payment domain cannot get a price and the payment stalls, but the payment domain's state is not corrupted. If the identity domain has a bug, it may issue incorrect attestations, but the payment domain's STF can check the attestation against its own validation rules before accepting it.

### 12.3 Composition principles

**No service has privilege over another.** The oracle domain is not a "system" domain; it is an ordinary domain whose outputs happen to be price feeds. The identity domain is not a "root of trust"; it is an ordinary domain whose outputs happen to be credentials. Settlement treats them all the same.

**Composition is opt-in.** A payment domain that wants oracle data subscribes to the oracle domain's outbox. A payment domain that does not need identity verification does not consume the identity domain's outputs. No service is forced to consume another.

**Composition is verifiable.** Because every inter-service message is a Settlement-anchored fact (committed, finalized, replay-protected), the composition is auditable. A dispute about whether the oracle domain provided a specific price at a specific time can be resolved by checking the finalized commitment. Disputes reduce to data, not to trust.

**Composition scales.** Adding a new service (a risk-scoring domain, a compliance domain, a reputation domain) means registering a new domain and connecting it via outbox messages. No existing service needs to change. No protocol upgrade is required. The composition graph grows by adding nodes, not by rewriting edges.

---

## 13. Why This Architecture Scales

### 13.1 The problem with monolithic chains

Monolithic blockchains add features by changing consensus. Each feature goes through governance, is deployed as part of the node binary, runs in every validator's execution path, and is constrained by the chain's throughput, latency, and state-growth limits. Adding an oracle feature requires every validator to run oracle logic. Adding a storage feature requires every validator to manage storage. Adding an identity feature requires every validator to process identity operations.

This approach has three scaling limits:
- **Consensus complexity.** Every feature adds code to the consensus path. More code means more bugs, more audit surface, more upgrade risk.
- **Throughput competition.** Every feature competes for the same block space. Oracle updates compete with DEX trades compete with storage operations.
- **Upgrade coupling.** Upgrading any feature requires a network-wide upgrade (hard fork or coordinated software release). Features cannot upgrade independently.

### 13.2 The Service Domain alternative

The Service Domain architecture separates consensus from computation. Settlement (consensus) remains fixed: it orders inputs, commits roots, enforces conservation, and manages finality. Services (computation) run in isolated domains: each with its own executor, its own STF, its own throughput, and its own upgrade cadence.

Adding a feature means registering a domain, not changing consensus. The oracle domain runs on its own executor(s); it does not compete with storage or messaging for Settlement block space (it submits one batch commitment per batch, regardless of how many price feeds it processed). The storage domain runs on its own executor(s); it does not slow down the oracle domain or the bridge domains. Each service scales independently.

### 13.3 The resulting properties

**Linear feature growth without consensus growth.** Each new service adds a domain. Settlement's complexity is constant (one `DomainRecord`, one batch commitment, one conservation check per domain per batch). The network's capability grows linearly with registered domains; consensus complexity does not.

**Independent throughput.** Each domain has its own batch cadence. A high-throughput messaging domain can produce batches every few seconds; a low-throughput identity domain can produce batches every few hours. They do not contend for the same execution pipeline.

**Independent failure.** A bug in one domain halts that domain. All other domains continue. Settlement continues. This is the property that makes the architecture antifragile: adding a service can never break an existing service.

**Independent upgrades.** Each domain upgrades its STF via `stfSpecHash` bump, on its own schedule, with its own user-exit window. Upgrading the oracle domain's aggregation algorithm does not require the storage domain, the bridge domains, or Settlement to do anything.

**Permissionless extension.** Anyone can design, build, and register a Service Domain (subject to the administrator's `RegisterDomain` decision under the current governance model, or permissionlessly once governance evolves). The protocol does not need to anticipate which services the network will need. The market decides.

---

## 14. Worked Examples

### 14.1 Oracle Domain

[SPECULATIVE] An oracle domain aggregates price feeds from multiple sources (on-chain DEX prices, relayed foreign oracle data, direct data-provider submissions). Its STF processes `SubmitPriceFeed` inputs, applies an aggregation function (median, TWAP, outlier-filtered mean), and publishes the aggregated price as an outbox message consumable by other domains.

- **Input source:** `L1_NATIVE` (on-chain submissions) or `L1_RELAYED` (foreign oracle data via `ChainVerifier`).
- **Execution profile:** `ATTESTATION` (bonded data providers) or `OPTIMISTIC` (fraud-provable if an aggregation is incorrect).
- **Economic model:** Per-query fees paid by consumers; data-provider bonds sized to cover the maximum damage from a false feed.
- **Execution Provider needed?** No. The oracle's output is information, not an asset release.
- **Intent support?** Indirectly: a user's Intent may trigger a payment domain to query the oracle for a conversion rate.

### 14.2 Identity Domain

[SPECULATIVE] An identity domain issues, stores, and verifies identity credentials (KYC attestations, reputation scores, membership proofs, age verifications). Its STF processes `IssueCredential`, `RevokeCredential`, and `VerifyCredential` inputs.

- **Input source:** `L1_NATIVE` (on-chain attestation submissions from authorized issuers).
- **Execution profile:** `ATTESTATION` (trusted issuers) or, for bridged foreign attestations, `LIGHT_CLIENT`.
- **Economic model:** Per-issuance fees; issuer bonds sized to cover potential damage from false attestations.
- **Execution Provider needed?** No. The identity domain's output is a credential, not an asset release.
- **Intent support?** Indirectly: a payment Intent may require identity verification before processing.

### 14.3 Storage Domain

[SPECULATIVE] A storage domain accepts, stores, and serves data blobs. Its STF processes `StoreBlob` (commit a blob hash and metadata), `ExtendStorage` (renew a blob's retention period), and `DeleteBlob` (release storage). The actual blob data is stored off-chain (DA layer, IPFS, or dedicated storage nodes); the domain commits the blob hash and metadata on-chain.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `ATTESTATION` or `OPTIMISTIC` (storage proofs: a watcher can challenge a storage provider that does not serve a committed blob).
- **Economic model:** Per-byte-per-epoch fees; storage-provider bonds covering the cost of data loss.
- **Execution Provider needed?** No (storage is on-chain commitment + off-chain serving, not asset release).
- **Intent support?** Directly: "store this file for 30 days" is a natural Intent.

### 14.4 Payment Domain

[SPECULATIVE] A payment domain processes payments: user A pays user B a specific amount of a specific asset, with optional conversion, identity verification, and compliance checks. Its STF processes `InitiatePayment`, `ConfirmPayment`, and `RefundPayment` inputs.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `ATTESTATION` or `OPTIMISTIC`.
- **Economic model:** Per-payment fees; provider bonds covering settlement risk.
- **Execution Provider needed?** Yes, if the payment involves a foreign-chain delivery (fiat payout, foreign-chain transfer). The payment domain produces a `kind=1` authorization; an Execution Provider fulfills it.
- **Intent support?** Directly: "pay Alice $100" is the canonical Intent.
- **Composition:** Consumes oracle domain (exchange rates), identity domain (KYC), bridge domain (cross-chain delivery).

### 14.5 AI Compute Domain

[SPECULATIVE] An AI compute domain runs deterministic inference tasks. Its STF processes `SubmitTask` (a model ID + input data), executes the inference (the model is part of the domain's state, deployed via chunked deployment), and publishes the result as an outbox message.

- **Input source:** `L1_NATIVE`.
- **Execution profile:** `ATTESTATION` (bonded compute providers) or `ZK_VALIDITY` (the inference is proven correct).
- **Economic model:** Per-compute-unit fees; provider bonds covering incorrect-inference risk.
- **Execution Provider needed?** No (the result is information). Yes if the result triggers an asset release (e.g., an AI-driven trading strategy that produces peg-out authorizations).
- **Intent support?** Directly: "run inference on this model with this input" is a natural Intent.
- **Key constraint:** The STF must be deterministic. Non-deterministic models (those whose output varies with floating-point precision or random seeds) must be pinned to a specific precision and seed inside the STF specification, or the watcher cannot reproduce the result.

### 14.6 Messaging Domain

[SPECULATIVE] A messaging domain routes messages between domains and, optionally, across chains. Its STF processes `Send` (emit a message to a destination domain or foreign chain), `Receive` (accept a relayed message from another domain), and `Route` (determine the optimal path for a multi-hop message).

- **Input source:** `L1_NATIVE` (intra-Zenon messages) or `L1_RELAYED` (cross-chain messages via `ChainVerifier`).
- **Execution profile:** `ATTESTATION` (bonded message routers).
- **Economic model:** Per-message fees; router bonds covering message-loss or misrouting risk.
- **Execution Provider needed?** Yes, for cross-chain delivery legs. No, for intra-Zenon routing.
- **Intent support?** Directly: "deliver this message to Bob on Solana" is a natural Intent.

---

## 15. Future Research

The following topics are identified as potential future work. They are explicitly speculative and do not commit any implementation or roadmap.

**AI service domains.** [SPECULATIVE] Domains that host deterministic AI models (inference, classification, generation with pinned seeds) as settlement-anchored services. Users submit inputs; the domain produces verified outputs.

**Confidential compute.** [SPECULATIVE] Domains whose STF runs inside a TEE (Trusted Execution Environment), providing confidentiality for the computation while still producing a Settlement-anchored commitment. The TEE attestation replaces or supplements the execution profile.

**TEE domains.** [SPECULATIVE] A generalization of confidential compute: any domain whose executor runs in a TEE, with TEE attestations as a trust model alongside or instead of bonded security.

**Unikernel service domains.** [SPECULATIVE] Domains whose STF runs in a minimal, single-purpose OS image (a unikernel), reducing the attack surface and improving performance for high-throughput services.

**Identity attestations.** [SPECULATIVE] Cross-chain identity bridging: a domain that accepts identity attestations from multiple chains and issues unified credentials consumable by any Zenon domain.

**Hardware-backed execution.** [SPECULATIVE] Domains whose execution is backed by hardware security modules (HSMs), providing tamper-resistant key management and computation.

**Storage markets.** [SPECULATIVE] A storage domain that operates as a market: storage providers compete on price and availability; the domain's STF manages the marketplace logic (listing, bidding, commitment, retrieval, penalty).

**Bandwidth markets.** [SPECULATIVE] A domain that allocates and prices network bandwidth for data relay, DA serving, or inter-domain communication.

**Decentralized APIs.** [SPECULATIVE] A domain that exposes a standardized API surface (REST, GraphQL, gRPC) backed by Settlement-anchored data, providing decentralized API services with provable data integrity.

**Service marketplaces.** [SPECULATIVE] A meta-domain that indexes available Service Domains, their capabilities, their pricing, and their reputation, serving as a discovery layer for service consumers.

**Autonomous agents.** [SPECULATIVE] AI agents that consume Service Domain outputs (prices, identities, storage, compute) and produce Settlement-anchored actions (payments, trades, messages) without human intervention.

**Autonomous infrastructure.** [SPECULATIVE] Service Domains that manage their own scaling, rebalancing, and pricing through autonomous, on-chain logic, reducing the need for human operators.

**Machine-to-machine settlement.** [SPECULATIVE] Service Domains designed for IoT and machine-to-machine payments: high-frequency, low-value settlements for data, compute, bandwidth, and access.

**IoT service domains.** [SPECULATIVE] Lightweight domains designed for resource-constrained devices: compressed input formats, minimal STF logic, and efficient commitment schemes.

**Cross-domain service composition.** Formal models for composing multiple Service Domains into complex workflows, with well-defined liveness, safety, and economic properties for the composed system.

**Programmable infrastructure.** [SPECULATIVE] A meta-framework where Service Domains themselves can programmatically instantiate, configure, and retire other Service Domains, creating a self-assembling infrastructure layer.

---

## 16. Relationship to Previous Documents

### 16.1 The complete architecture

The five Frontier documents and the governing specification now form a complete architecture:

```
SPEC.md                          ← The controlling authority: consensus, ordering, finality, conservation
    ↓
BRIDGE-FRAMEWORK-SPEC.md         ← How value moves across chains (verification, settlement, authorization)
    ↓
EXECUTION-PROVIDER-FRAMEWORK.md  ← How truth gets fulfilled (execution, liquidity, pricing)
    ↓
INTENT-ORDERFLOW-FRAMEWORK.md    ← How users express outcomes (intents, quotes, selection)
    ↓
ECONOMIC-SECURITY-FRAMEWORK.md   ← Why every participant behaves honestly (trust, bonds, competition)
    ↓
SERVICE-DOMAIN-FRAMEWORK.md      ← How infrastructure becomes modular services (this document)
```

### 16.2 Not a pipeline

The diagram above is not a pipeline. It is a layered architecture. Each document addresses a different concern:

- `SPEC.md` answers: what is the on-chain truth machine?
- The Bridge Framework answers: how does truth extend across chains?
- The Execution Provider Framework answers: how does truth become action?
- The Intent Framework answers: how do users express what they want?
- The Economic Security Framework answers: why does everyone behave?
- The Service Domain Framework answers: how does the network grow?

Each document can be read independently. Each references the others where boundaries meet. No document subsumes another.

### 16.3 What this document adds

This document adds the architectural argument for why Project Zeno is not just cross-chain infrastructure. It is a general settlement architecture. The Domain Settlement Layer is a truth machine. Bridge domains use it to move value. Service Domains use it to provide infrastructure. Runtime domains use it to run applications. The settlement layer is the same in all cases; only the domains differ.

---

## 17. Closing

This document has defined the Service Domain: an independent, isolated, Settlement-anchored execution environment that provides a specific infrastructure capability. It has shown that Service Domains inherit all Settlement guarantees without requiring any Settlement change, that they communicate through Settlement (never directly), that their failures are domain-local, that their economics are domain-specific, and that they compose through asynchronous, finalized messages.

The closing principle:

> **Settlement should not become larger. The network around Settlement should become richer. Every new capability should become a domain, not a protocol modification.**

This is the architectural principle that turns a cross-chain settlement layer into a general infrastructure platform. The protocol provides deterministic truth. Domains provide specialized services. Markets provide execution and capital. Users express outcomes. Each layer remains independent. Each layer scales independently. The settlement layer is the fixed point around which everything else moves.

---

**Document end.**

This document is Frontier research. It does not commit to any implementation, any specific Service Domain deployment, or any protocol modification. It defines an architectural pattern that is already expressible within the existing domain model. The controlling authority for all on-chain rules remains `SPEC.md` v1.3.0. Where this document speculates, it says so.
