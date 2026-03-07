# Zenon Commit Channels Protocol
## Specification v1.5

---

**Status:** Published  
**Category:** Protocol Specification  
**Network:** Zenon Network  
**Supersedes:** v1.4  

**Changes from v1.4 — four targeted corrections, zero additions:**

1. **Edit chain depth and frequency limits added.** The v1.4 edit pointer model had no bounds on depth or publication rate, creating a history traversal DoS vector. v1.5 adds `max_edit_depth` and `max_edits_per_claim` as rules object fields with chain-enforced defaults.

2. **Tombstone authority constraints tightened.** The v1.4 tombstone model allowed tombstone authority to be granted arbitrarily, making it a potential global erasure primitive. v1.5 restricts `tombstone_authority` grants in the rules object and requires tombstone scope declaration at claim creation for non-originator tombstone authority.

3. **Inline payload policy for coordination-critical claims formalized.** The v1.4 payload availability model left coordination-critical claims (those whose `resolution_authority` logic depends on payload content) silently at risk of unavailability. v1.5 introduces `payload_criticality` as a [S] field and defines the runtime policy for handling critical claims with unavailable payloads.

4. **Protocol vs. library justification added as Section 0.** The hostile review's sharpest practical question — "why a protocol and not a library?" — was unanswered in v1.4. Section 0 answers it directly.

**What did not change:** All Part I sections 1–19 carry forward except Sections 11.5 (edit/tombstone authority, amended), 12 (payload schemes, amended), and the rules object schema (Section 14, amended). Part II carries forward with one new conformance test (CT-11) in Part III. The protocol's four guarantees, temporal model, lifecycle model, resolution authority model, conflict resolution templates, and deterministic invariants are unchanged.

---

## Document Structure

**Part I — Base Protocol** (Sections 0–19): Normative. Chain-enforced. Every implementation must conform.

**Part II — Deterministic Runtime Standard** (Sections 20–24): Normative for conformant runtimes. Not chain-enforced.

**Part III — Reference Materials** (Sections 25–29): Informational.

---

# PART I — BASE PROTOCOL

---

## 0. Why a Protocol and Not a Library

This question deserves a direct answer before everything else.

A library solves a local problem. A protocol solves a coordination problem that libraries cannot address because the participants do not share a codebase, do not trust each other, and may not know each other exists.

The specific problem Commit Channels solves is this: **two autonomous agents that have never communicated, running different software stacks, operated by different parties, need to coordinate against a shared verifiable record without a trusted intermediary.**

A library does not help here. A library runs inside one process, on one machine, under the control of one operator. It can provide excellent local functionality. It cannot provide the property these agents need: a record that is verifiable by any third party who was not present when the record was created, using only the chain state and the agents' public keys.

The specific properties that require a protocol rather than a library:

**1. Censorship attribution.** If a claim fails to appear in the record, the failure is attributable to the chain, not to the application. A library cannot provide this: the application controls the library.

**2. Cross-operator verification.** The record is verifiable by participants who did not publish it and do not share any infrastructure with those who did. This requires a shared public ordering mechanism. A shared library is not a shared public ordering mechanism; it is a shared codebase, which is a much weaker property.

**3. Append-only history with no operator delete.** No operator — including the channel creator — can delete an accepted claim. This is a chain-level invariant. A library running on operator infrastructure cannot provide it; the operator controls the storage.

**4. Deterministic sequencing across independent participants.** All participants observe identical `channel_seq` assignments and identical `timestamp_height` values, independently verifiable from chain state. A library provides ordering only within a single deployment context.

**5. Cryptographic authorship without a trusted authority.** Ed25519 signature verification is cheap and trustless. But the binding of a signature to a global sequence number requires a neutral sequencer. The chain is that sequencer. There is no library-level substitute.

The correct framing is not "protocol vs. library" but "what is the minimal chain surface needed to make these properties available?" The answer to that question is the base protocol in Sections 1–19. Everything else — lifecycle semantics, coordination patterns, runtime behavior — could in principle live in a library. The reason it lives in the spec is to ensure that independent library implementations behave identically. That is the conformance problem, and it is not solvable by publishing a single library (which any operator could fork or misimplement). It is solvable by a published spec with a public conformance test suite.

---

## 0.1 Position in the Interstellar Architecture

Commit Channels occupies a specific and bounded position in the Interstellar protocol stack. Understanding this position is necessary to avoid scope confusion between what the chain provides and what runtimes derive from it.

```
Zenon Network
    ↓  (ordering · consensus · data availability)
Commit Channels
    ↓  (ordered claim log · authorship verification · append-only history · epoch records)
Interstellar OS  (verification kernel)
    ↓  (deterministic claim replay · reducer-based state derivation · state root commitment)
Protocol Modules
    ↓  (claim validation · coordination object lifecycle · domain protocol rules)
Applications / Agents
```

**What Commit Channels provides to this stack:**

Commit Channels provides the ordered, append-only claim history that Interstellar OS replays to derive coordination state. Every claim published to a channel is a coordination event with a globally agreed sequence position, a cryptographically verified author, and an immutable record. This record is the shared input on which all runtimes — including Interstellar OS — operate.

Commit Channels does not interpret what claims mean. It does not determine whether a coordination object has reached a valid lifecycle state. It does not execute protocol logic. It provides the claim stream; Interstellar OS provides the interpretation.

**What Interstellar OS provides:**

Interstellar OS is the verification kernel that consumes the Commit Channels claim stream. It verifies claims against protocol rules implemented in deterministic reducer modules, and produces a cryptographically committed state root that any conformant implementation will independently reproduce from the same inputs. The Interstellar OS state root is derived entirely from Commit Channels claim history — this is the protocol's core invariant.

**The division of responsibility in one sentence:** Commit Channels orders and records. Interstellar OS verifies and reduces. Protocol Modules interpret. Applications consume derived state.

This division is load-bearing. Any change that causes Commit Channels to interpret claim semantics, or causes Interstellar OS to depend on information not present in the claim stream, collapses the architectural separation that gives both systems their correctness properties.

---

## 1. Abstract

Zenon Commit Channels is a verifiable coordination claim ordering layer. The chain produces a globally ordered, append-only stream of cryptographically signed claims. Any participant can independently verify this stream from chain state alone.

Commit Channels provides exactly four guarantees:

1. Deterministic global ordering
2. Cryptographic authorship verification
3. Append-only claim history
4. Immutable epoch records

Everything else — payload availability, semantic validity, lifecycle correctness, coordination state derivation — is the responsibility of runtimes operating against the shared record. In the Interstellar architecture, this responsibility belongs to Interstellar OS and the protocol modules it hosts.

The protocol is designed for autonomous agents as the primary consumer. Human-facing applications are a special case of the agent model.

The core model in three sentences:

> Commit Channels is a globally ordered log of signed coordination claims. Any runtime can replay the log and derive coordination state deterministically. Autonomous agents publish claims and resolve coordination objects according to verifiable authority rules, without a central coordinator.

---

## 2. Property Taxonomy

Every property in this specification carries an explicit label.

**[G] Guarantee** — enforced unconditionally by conformant chain implementations. A violation is a consensus failure.

**[S] Signal** — recorded by the chain; not enforced by the chain. Observable and falsifiable. A false signal is detectable but not prevented.

**[C] Convention** — a recommendation for runtimes and applications. Not enforced at any layer.

No property is left unlabeled in normative sections.

---

## 3. Scope

**Commit Channels is:** a cryptographic claim ordering layer; an append-only coordination claim log; a substrate for deterministic runtime replay; a foundation for autonomous agent coordination.

**Commit Channels is not:** an application framework; a messaging platform; a smart contract runtime; a governance system; a privacy layer; an availability layer; an execution environment; a protocol semantics interpreter.

**Explicit exclusion:** If an application requires strict within-block ordering priority as an economic or coordination property, it must not be built on Commit Channels. Same-block claims are simultaneous by protocol design. This is a deliberate scope boundary, not a limitation to be worked around.

**Relationship to Interstellar OS:** Commit Channels is agnostic to the protocol semantics of the claims it records. It does not know whether a claim advances a market coordination object, a governance proposal, a Portal deposit claim, or any other protocol construct. Those interpretations are performed by Interstellar OS and its module reducers. Commit Channels must remain an ordering and record layer only, so that any conformant runtime can independently derive identical coordination state from the same claim history.

---

## 4. Terminology

| Term | Definition |
|---|---|
| **Channel** | An ordered, append-only stream of coordination claims identified by `channel_id`. In the Interstellar architecture, each channel is an independent replay pipeline consumed by the verification kernel. |
| **Claim** | A signed coordination event published to a channel. The terms *claim* and *commitment* are interchangeable; *claim* is preferred. Claims are the atoms of the coordination model. |
| **Coordination object** | A claim that opens a coordination lifecycle (assertion, intent, proposal). Resolved by a resolution claim. Runtimes derive coordination object state by replaying the claim history. |
| **Agent** | An autonomous runtime acting on claims without per-action human oversight. Primary consumer. In the Interstellar architecture, agents operate at the application layer above Interstellar OS. |
| **Runtime** | Any process that verifies and interprets claims locally by replaying claim history. Runtimes are deterministic claim replay engines: they derive coordination objects and protocol state from the ordered claim record. Interstellar OS is the canonical conformant runtime in the Interstellar architecture. Agents are a subclass of runtime. |
| **Validator** | A network node that orders claims and enforces structural validity. Does not interpret claim semantics. Does not derive coordination state. |
| **Author Clock** | Per-author, per-channel Lamport clock. Replay protection and causal ordering within a channel. |
| **Channel Sequence** | Monotonically increasing history index. Not a timing or fairness primitive. |
| **Block Height** | The canonical temporal primitive. The only reliable time boundary in the protocol. |
| **Channel Epoch** | A monotonically increasing version counter for a channel's rules. |
| **Rules Object** | A canonical, typed, versioned document governing a channel epoch. |
| **Resolution Authority** | The entity or mechanism authorized to publish a `resolution` claim for a coordination object. |
| **Claim Lifecycle** | The sequence assert → respond → resolve. The chain records lifecycle-bearing claims; runtimes derive lifecycle state by replay. |
| **Edit Depth** | The length of the edit pointer chain rooted at a coordination object. A single edit pointer on an original claim has depth 1. |
| **Payload Criticality** | A [S] field declaring whether a coordination object's resolution logic depends on payload content being available to the runtime. |

---

## 5. Temporal Model

Block height is the canonical temporal primitive.

**T1 [G]:** Every accepted claim carries a `timestamp_height` — the block height at inclusion.

**T2 [G]:** `channel_seq` is a history index establishing permanent record order within the channel. It is not a timing signal, a fairness primitive, or a submission order record.

**T3 [C]:** All claims with the same `timestamp_height` are simultaneous for coordination logic. No within-block ordering is reliable for economic or causal reasoning.

**T4 [C]:** All time-bounded operations must be expressed in block height ranges, not sequence number ranges.

**T5 [C]:** Agents and runtimes must not make coordination decisions based on intra-block sequence order.

**On validator discretion [Known limitation]:** Validators control within-block claim ordering. This cannot be eliminated by protocol rules. Applications designed against T3 are not differentially harmed by within-block reordering. Validator diversity and public block monitoring are ecosystem-level mitigations, not protocol properties.

---

## 6. Channel Object

```
Channel {
    channel_id:           bytes32     [G]
    creator:              PublicKey
    epoch:                uint64      [G]
    rules_hash:           bytes32     [G]
    authorization_root:   bytes32 | null
    created_height:       uint64      [G]
    status:               ChannelStatus   // active | frozen | archived
}
```

- `channel_id`: [G] Deterministic derivation from creation parameters. See Section 15.
- `creator`: Key that submitted `CreateChannel`. No ongoing authority beyond rules object grants.
- `epoch`: [G] Current rules version. Starts at 0. Append-only increment.
- `rules_hash`: [G] SHA-256 of the canonical rules object for the current epoch.
- `authorization_root`: [G] Non-null iff `rules_object.authorization_required = true`.
- `created_height`: [G] Block height at creation. Immutable.
- `status`: `active | frozen | archived`.

In the Interstellar architecture, each active channel corresponds to an independent deterministic replay pipeline in the Interstellar OS kernel. The `channel_id` is the key by which Interstellar OS partitions its replay workers, storage, and channel state roots.

---

## 7. Channel State and Freeze Authority

**Active**: Accepts new claims. The Interstellar OS kernel's replay pipeline for this channel is live.

**Frozen**: Does not accept new claims. History preserved. The kernel may continue replaying existing history. May be unfrozen by authorized action.

**Archived**: Permanently closed. Irreversible. The claim history remains available for replay; no new claims are added.

**Freeze authority [G]:** The rules object must declare `freeze_authority` as one of:

```
multisig(threshold: uint8, keys: []PublicKey)
governance_commitment(channel_id: bytes32, proposal_type: string)
creator_with_delay(min_blocks: uint64)
```

A `CreateChannel` or `UpdateChannelRules` transaction whose rules object declares any other freeze authority configuration is rejected by conformant validators.

A `FreezeChannel` transaction using `creator_with_delay` authority takes effect only after `min_blocks` have elapsed from the freeze transaction's `timestamp_height`.

---

## 8. Channel Epochs

**8.1 Epoch Records [G]**

Every channel has an `epoch` counter starting at 0. Rules updates increment the epoch. All epoch records are permanently stored on-chain.

```
EpochRecord {
    channel_id:    bytes32
    epoch:         uint64
    rules_hash:    bytes32
    auth_root:     bytes32 | null
    start_height:  uint64
    authority_key: PublicKey
    signature:     Signature
}
```

Epoch records are part of the immutable claim history consumed by runtimes. In the Interstellar architecture, the Interstellar OS kernel uses epoch records to determine the correct module version and rules configuration for deterministic historical replay at any sequence position.

**8.2 Claim Epoch Binding [G]**

Every claim carries a `rules_epoch`. A claim is accepted only if its `rules_epoch` matches the current channel epoch, or falls within `epoch_grace_period_blocks` declared in the rules object (default: 0).

**8.3 Epoch Update Authority [G for financial channels]**

Declared in `rules_object.epoch_update_authority`. Valid configurations are identical to freeze authority (Section 7). For `channel_class = financial`: `epoch_update_authority` must be `multisig` or `governance_commitment`. Validators enforce this at creation and at rules update.

---

## 9. Claim Object

```
ChannelClaim {
    claim_id:             bytes32
    channel_id:           bytes32
    author:               PublicKey
    author_clock:         uint64
    rules_epoch:          uint64
    channel_seq:          uint64
    claim_type:           ClaimType
    resolution_authority: ResolutionAuthority | null
    payload_criticality:  PayloadCriticality      // new in v1.5
    parent_claim:         bytes32 | null
    payload_hash:         bytes32
    payload_scheme:       PayloadScheme
    payload_pointer:      bytes | null
    expiry_height:        uint64 | null
    timestamp_height:     uint64
    signature:            Signature
}
```

**New field in v1.5:** `payload_criticality`. See Section 12.2.

**Field definitions (unchanged from v1.4 except as noted):**

- `claim_id`: [G] Deterministic. See Section 18.
- `author_clock`: [G] Strictly greater than prior accepted value for `(author, channel_id)`.
- `rules_epoch`: [G] Must match current epoch at acceptance, subject to grace period.
- `channel_seq`: [G] Contiguous, monotonically increasing history index within the channel.
- `claim_type`: See Section 10.
- `resolution_authority`: [G] Required and non-null for lifecycle-bearing claim types.
- `payload_criticality`: [S] Declares whether payload content is required for coordination resolution by the runtime. See Section 12.2.
- `parent_claim`: [G] If non-null, must reference an existing claim in the same channel.
- `payload_hash`: [G] SHA-256 of payload bytes.
- `expiry_height`: [S] Runtime-enforced.
- `timestamp_height`: [G] Block height at inclusion.

The claim object is the atom of the coordination model. In the Interstellar architecture, each claim in the channel stream is processed by the Interstellar OS kernel: verified for structural and cryptographic correctness, then passed to the appropriate module reducer for semantic interpretation and state derivation.

---

## 10. Claim Types

| Type | Description | Lifecycle-bearing |
|---|---|---|
| `assertion` | Initial claim. Opens a coordination lifecycle. | Yes |
| `intent` | Signed willingness to transact or coordinate. | Yes |
| `proposal` | Structured response to an `assertion` or `intent`. | Yes |
| `acceptance` | Accepts a prior `proposal` or `intent`. | Yes |
| `rejection` | Rejects a prior `proposal` or `intent`. | Yes |
| `resolution` | Terminal lifecycle marker. Closes a coordination object. | Terminal |
| `challenge` | Disputes a prior claim. | Yes |
| `support` | Confirms a prior claim. | Yes |
| `vote` | References a `proposal`; carries vote payload. | Yes |
| `notice` | Protocol event notification. | No |
| `attestation` | Signed claim about a key, identity, or endpoint. | No |
| `state_update` | Structured coordination state transition. | Situational |
| `edit_pointer` | Replacement payload hash for a prior claim. | No |
| `tombstone` | Marks a prior claim as withdrawn. | No |
| `availability_attestation` | Storage provider payload retention assertion. [S] | No |
| `epoch_update` | Records a channel epoch transition. | No |
| `message` | Unstructured human-readable content. | No |

**Validator enforcement [G]:** If `claim_type` is lifecycle-bearing, `resolution_authority` must be non-null.

**Claim types and Interstellar OS:** The Interstellar OS claim vocabulary (Section 7 of the Interstellar OS specification) maps onto these claim types. Commit Channels `assertion`, `proposal`, `support`, `rejection`, `challenge`, `state_update`, and `resolution` types correspond directly to the Interstellar OS base claim type vocabulary. The `claim_type` field in a `ChannelClaim` is the base type; the protocol-specific meaning is carried in the payload and interpreted by the module reducer, not by the chain.

---

## 11. Claim Lifecycle

### 11.1 The Lifecycle Model

Coordination objects follow a lifecycle from assertion to resolution. **The chain records lifecycle-bearing claims as coordination events; runtimes derive lifecycle state by replaying the claim history.** The chain enforces structural validity (non-null `resolution_authority` for lifecycle-bearing types) but does not determine semantic validity, lifecycle correctness, or whether a coordination object has reached a valid resolved state. Those determinations belong to the runtime.

Coordination objects advance through their lifecycles as claims are published that reference them. Each such claim is an event that the runtime interprets when replaying the channel's ordered claim history. The runtime derives the current lifecycle state of every coordination object from the complete sequence of events observed in that channel's history.

```
assert
  → respond (proposal / support / challenge / vote)
    → respond to response (optional depth)
      → resolve
```

### 11.2 Lifecycle State Derivation

`lifecycle_state` is not a claim field in v1.5. **Lifecycle state is always derived by runtimes from claim history.** See Section 21.5 for the canonical derivation procedure.

The chain records the events. The runtime derives the state. This separation is fundamental: it means any conformant runtime, given the same claim history, will independently produce identical lifecycle state for every coordination object. This is the deterministic replay property that makes the Commit Channels / Interstellar OS architecture work.

Derived lifecycle state set:

```
DerivedLifecycleState {
    proposed    — no terminal event observed
    active      — one or more non-terminal responses observed
    accepted    — valid acceptance observed
    rejected    — valid rejection observed
    superseded  — edit_pointer observed; original not canonical
    tombstoned  — tombstone observed; lineage terminal
    resolved    — valid resolution from authorized party observed
    expired     — expiry_height < current_block_height; no resolution
}
```

### 11.3 Lifecycle Transition Rules

```
proposed  → active       (any non-terminal response observed)
proposed  → accepted     (valid acceptance from authorized acceptor)
proposed  → rejected     (valid rejection from authorized rejector)
proposed  → superseded   (edit_pointer from original author)
proposed  → tombstoned   (tombstone from authorized tombstone party)
proposed  → resolved     (valid resolution from resolution_authority)
proposed  → expired      (expiry_height passed; no terminal event)
active    → accepted / rejected / resolved / tombstoned / expired
accepted  → resolved
rejected  → resolved
```

`superseded`, `tombstoned`, `resolved`, and `expired` are terminal.

These transition rules define what the runtime derives from claim history. The chain does not enforce that claims cause valid transitions; a `resolution` claim from an unauthorized party is a valid chain record and an invalid coordination event. The distinction between a valid record and a valid coordination event is the runtime's responsibility.

### 11.4 Resolution Authority Model

`resolution_authority` is declared in the claim's signable body. It is cryptographically bound at creation and cannot be altered without invalidating the signature.

```
ResolutionAuthority {
    authority_type: AuthorityType
    authority_data: bytes
}

AuthorityType {
    originator           — only the original claim author
    designated_key       — a specific named public key
    multisig             — N-of-M over a declared key set
    governance_channel   — a resolution commitment in a named channel
    open_competition     — any key; first valid resolution wins
    consensus            — a quorum of declared keys
}
```

**Enforcement split:** The chain enforces non-null `resolution_authority` on lifecycle-bearing claims [G]. Runtimes enforce that `resolution` claims are authored by an entity matching the declared authority [Part II, Section 21.6]. An unauthorized `resolution` is a valid chain record and an invalid coordination event. The chain records it; the runtime ignores its lifecycle effect.

### 11.5 Edit Authority, Edit Limits, and Tombstone Authority

**Edit pointers — authority:** Only the original claim author, unless rules object grants `edit_authority` to additional keys.

**Edit pointers — depth limit [G if declared; C otherwise]:** The rules object may declare `max_edit_depth` (uint16). If declared, validators reject an `edit_pointer` whose acceptance would cause the edit chain depth rooted at the original claim to exceed `max_edit_depth`.

**Edit chain depth** is defined as the length of the longest path from the original claim through `edit_pointer` claims. An `edit_pointer` at depth N has `N-1` ancestors that are also `edit_pointer` claims.

Default behavior when `max_edit_depth` is not declared: no chain-enforced depth limit. Runtimes must still be able to walk arbitrarily deep edit chains without crashing; they must not have algorithmic complexity above O(depth) for edit chain traversal.

**Edit pointers — frequency limit [G if declared; C otherwise]:** The rules object may declare `max_edits_per_claim` (uint16). If declared, validators reject an `edit_pointer` that would cause the total count of `edit_pointer` claims with `parent_claim` pointing to the same original claim to exceed `max_edits_per_claim`.

Recommended defaults for high-throughput or machine channels: `max_edit_depth = 10`, `max_edits_per_claim = 20`.

Rationale: Without these limits, a malicious author can publish an arbitrarily deep edit chain to force O(depth) work on all runtimes at negligible cost to the attacker. The limits are optional to preserve flexibility for applications with legitimate need for deep edit histories (e.g., document collaboration channels), while allowing security-conscious deployments to bound traversal cost.

**Tombstones — authority:** Only the original claim author by default. The rules object may grant `tombstone_authority` to additional keys.

**Tombstone authority constraints [new in v1.5]:** The following restrictions apply to `tombstone_authority` grants in the rules object:

1. `tombstone_authority` may not be set to `anyone` or any configuration equivalent to unrestricted tombstone publishing. Validators reject rules objects with such configurations. [G]
2. If the rules object grants `tombstone_authority` to any key other than the claim originator, the grant must declare a `tombstone_scope`: either `own_claims` (may only tombstone claims authored by the tombstone authority itself) or `designated_claims` (may only tombstone claims whose `parent_claim` or `claim_id` is explicitly listed in a tombstone target declaration). Unbounded tombstone authority over all channel claims is not a valid grant. [G for structural validity; runtime enforcement for scope compliance]
3. For `channel_class = financial` or `channel_class = governance`, `tombstone_authority` grants other than to the original claim author must additionally require multisig confirmation declared in the rules object. [G]

**Tombstone precedence [unchanged]:** A tombstone takes precedence over any edit pointer chain, regardless of sequence order. The lineage is terminal.

**Edit chain canonicalization [unchanged]:** The canonical version of a claim lineage is the `edit_pointer` with the highest `channel_seq`. All conformant runtimes produce identical canonical tips from identical history.

---

## 12. Payload Schemes and Payload Criticality

### 12.1 Payload Schemes

```
inline                       — bytes in transaction; payload_pointer null
content_addressed            — off-chain at payload_pointer (e.g. IPFS CID)
encrypted_inline             — ciphertext inline; payload_hash commits to ciphertext
encrypted_content_addressed  — ciphertext off-chain at payload_pointer
cbor                         — structured canonical CBOR
canonical_json               — structured canonical JSON
protobuf                     — structured protobuf with stable field ordering
```

[G] on integrity: retrieved content must hash to `payload_hash`. [S] on availability for off-chain schemes.

The chain records payload metadata (hash, scheme, pointer) and enforces hash integrity. The chain does not enforce payload availability. Runtimes are responsible for payload retrieval and verification before acting on payload-dependent coordination logic. In the Interstellar OS architecture, payload retrieval is a Client Layer responsibility: the Storage Client delivers payload bytes to the kernel, which verifies the hash before passing the payload to a module reducer.

### 12.2 Payload Criticality [S]

`payload_criticality` is a [S] field in v1.5. It declares whether the resolution of this coordination object depends on payload content being available to the runtime.

```
PayloadCriticality {
    non_critical    — resolution logic does not depend on payload content
    critical        — resolution logic requires payload content to be available
    conditional     — payload content may be required depending on resolution path
}
```

This field is [S]: the chain records it; the chain does not enforce availability based on it. Its purpose is to make an implicit runtime dependency explicit, observable, and enforceable by conformant runtimes. In the Interstellar OS architecture, this field corresponds to the `Incomplete` claim state: a claim with `payload_criticality = critical` whose payload has not been retrieved is held in the kernel's pending queue and is not passed to the module reducer until the payload is available and hash-verified.

**Runtime policy for critical claims [Part II, Section 21.9]:** A runtime that cannot retrieve payload content for a claim with `payload_criticality = critical` must not derive a `resolved` state for that coordination object based on payload-dependent resolution logic. The object remains in its current state. The runtime logs the missing payload and does not act further until the payload is available. This prevents coordination failures from being silently misclassified as successful resolutions.

**Design note on availability [honest account]:** The protocol does not solve payload availability. This is a known limitation (L4 from v1.4) and it is not resolved in v1.5. What v1.5 does is require that applications which have a structural dependency on payload availability declare that dependency explicitly, so that both the application designer and the runtime understand the risk surface. The correct mitigation for coordination-critical payloads remains: use `inline` or `cbor` payload schemes with the payload embedded in the transaction. An application that uses `content_addressed` payload scheme with `payload_criticality = critical` is declaring a dependency it cannot guarantee. This is permitted; it is documented; it is the application designer's responsibility.

---

## 13. Availability Attestations

[S] throughout.

Published as `claim_type = availability_attestation`. The claim's `author` is the provider key asserting retention until a specific block height.

```
AvailabilityAttestationPayload {
    payload_hash:           bytes32
    channel_id:             bytes32
    retention_end_height:   uint64
    retrieval_endpoint:     bytes
}
```

A false attestation is demonstrably incorrect on-chain. The chain does not penalize false attestations. In the Interstellar OS architecture, availability attestations are consumed by the Client Layer's Storage Client when determining retrieval sources for off-chain payload content. They are not consumed by the kernel directly.

---

## 14. Rules Object Schema

The rules object is stored off-chain. Its SHA-256 (canonical CBOR encoding) is the `rules_hash`. The `CreateChannel` and `UpdateChannelRules` transactions must include the rules object inline for validator schema validation.

**Required fields:**

```
RulesObject {
    schema_version:             uint16          // must be 3 for v1.5
    channel_class:              ChannelClass
    freeze_authority:           AuthoritySpec   // chain-validated
    epoch_update_authority:     AuthoritySpec   // chain-validated
    allowed_claim_types:        []ClaimType     // non-empty
    default_resolution_policy:  ResolutionPolicy
}

ChannelClass { financial | governance | coordination | broadcast }
```

**Optional fields [unchanged from v1.4 except additions marked]:**

```
    authorization_required:         bool
    edit_authority:                 AuthoritySpec | null
    tombstone_authority:            TombstoneAuthoritySpec | null   // amended in v1.5
    epoch_grace_period_blocks:      uint64
    payload_schema:                 SchemaRef | null
    schema_registry:                []SchemaDescriptor | null
    min_availability_attestations:  uint8
    required_attestation_keys:      []PublicKey | null
    encryption_requirement:         bool
    posting_deposit:                uint64 | null
    rate_limit:                     RateLimit | null
    max_author_clock_jump:          uint64 | null
    max_edit_depth:                 uint16 | null   // new in v1.5
    max_edits_per_claim:            uint16 | null   // new in v1.5
    conflict_resolution_overrides:  ConflictOverrides | null
```

**TombstoneAuthoritySpec [amended in v1.5]:**

```
TombstoneAuthoritySpec {
    authority:       AuthoritySpec
    tombstone_scope: TombstoneScope
    // For financial/governance channels: confirmation_required: MultiSigSpec
}

TombstoneScope {
    own_claims          // may only tombstone claims authored by this key
    designated_claims   // may only tombstone claims listed in an associated declaration
}
```

**Chain-enforced constraints [G] — additions in v1.5 marked:**

1. `schema_version = 3` for v1.5 protocol.
2. `freeze_authority` must be a valid configuration.
3. `epoch_update_authority` must be a valid configuration.
4. If `channel_class = financial`: `epoch_update_authority` must be `multisig` or `governance_commitment`.
5. `allowed_claim_types` must be a non-empty list.
6. `default_resolution_policy` must be present and valid.
7. **[new]** `tombstone_authority` grants must declare a valid `tombstone_scope`. Unrestricted tombstone authority is rejected.
8. **[new]** For `channel_class = financial` or `governance`: additional `tombstone_authority` grants (beyond originator) must include `confirmation_required` multisig spec.

---

## 15. Channel Creation

```
CreateChannel {
    creator:              PublicKey
    rules_hash:           bytes32
    rules_object:         bytes           // inline canonical CBOR
    authorization_root:   bytes32 | null
    metadata_hash:        bytes32 | null
    signature:            Signature
}
```

**channel_id derivation [G]:**

```
channel_id = H(
    "Zenon/CommitChannel/v1.5/Create" ||
    creator                            ||
    rules_hash                         ||
    authorization_root                 ||
    metadata_hash
)
```

**Validator acceptance rules:**

1. Signature valid under `creator`.
2. `H(rules_object) = rules_hash`.
3. `rules_object` parses as valid canonical CBOR.
4. `rules_object.schema_version = 3`.
5. `rules_object.freeze_authority` is a valid configuration.
6. `rules_object.epoch_update_authority` is a valid configuration.
7. If `channel_class = financial`: `epoch_update_authority` is `multisig` or `governance_commitment`.
8. `allowed_claim_types` is non-empty.
9. `default_resolution_policy` is present and valid.
10. `tombstone_authority` grant, if present, declares a valid `tombstone_scope` and satisfies financial/governance multisig requirement if applicable.
11. If `authorization_required = true`: `authorization_root` is non-null.
12. Derived `channel_id` not already in chain state.
13. Transaction fee satisfies network requirements.

---

## 16. Authorization Model

**Open channels** (`authorization_required: false`): Any key may publish, subject to fees and `allowed_claim_types`.

**Permissioned channels** (`authorization_required: true`): Author must provide a valid Merkle membership proof against the current epoch's `authorization_root`.

```
AuthorizationProof {
    leaf:   H(author_public_key)
    path:   []bytes32
    index:  uint64
    epoch:  uint64
}
```

---

## 17. Sequence Rules

**17.1 Author Clock [G]**

Each `(author, channel_id)` pair maintains an independent clock. A claim is accepted iff its `author_clock` is strictly greater than the highest accepted value for that pair. Gaps allowed; regression rejected.

The author clock in Commit Channels corresponds directly to the author clock used by Interstellar OS for replay protection and causal ordering within a channel. Both systems require strictly increasing clock values per author per channel.

**17.2 Clock Jump Bound [G if declared; C otherwise]**

If `rules_object.max_author_clock_jump` is declared, validators reject claims whose advance exceeds it.

**17.3 Clock Overflow**

`author_clock` is `uint64`. A key with `author_clock = 2^64 - 1` has permanently exhausted its clock in that channel. The next valid clock value does not exist. Runtimes must treat this key as unable to publish further claims in that channel.

**17.4 Multi-Device Coordination [C]**

Clock coordination across devices sharing a key is the application's responsibility. Recommended: non-overlapping clock ranges per device.

**17.5 Channel Sequence [G]**

Each accepted claim receives the next `channel_seq`, assigned by validators. Starts at 0. Contiguous. No gaps.

The `channel_seq` assigned by Commit Channels is the sequence position used by Interstellar OS to order claims within a channel's deterministic replay pipeline. A claim's `channel_seq` is its immutable position in the replay history.

---

## 18. Signature Rules

**18.1 Signable Body**

`payload_criticality` is included in the signable body — it is author-declared and binding.

```
SignableBody = H(
    "Zenon/CommitChannel/v1.5/Claim"  ||
    channel_id                         ||
    author                             ||
    author_clock                       ||
    rules_epoch                        ||
    claim_type                         ||
    resolution_authority               ||
    payload_criticality                ||
    parent_claim                       ||
    payload_hash                       ||
    payload_scheme                     ||
    payload_pointer                    ||
    expiry_height
)
```

Domain separator updated from v1.4.

**18.2 claim_id Derivation [G]**

```
claim_id = H(
    "Zenon/CommitChannel/v1.5/ID" ||
    channel_id                     ||
    author                         ||
    author_clock                   ||
    rules_epoch                    ||
    payload_hash
)
```

---

## 19. Validator Acceptance Rules

A validator accepts a `PublishClaim` transaction iff all of the following hold:

1. Signature is valid Ed25519 over `SignableBody` under `author`.
2. `channel_id` references an existing, active channel.
3. `rules_epoch` matches the current epoch or is within grace period.
4. `author_clock` strictly greater than prior accepted value for `(author, channel_id)`.
5. If `max_author_clock_jump` declared: advance does not exceed it.
6. `channel_seq` will be the next contiguous index (validator-assigned).
7. If `authorization_required = true`: authorization proof valid.
8. `claim_type` in `allowed_claim_types`.
9. If lifecycle-bearing: `resolution_authority` non-null.
10. If `parent_claim` non-null: referenced claim exists in same channel.
11. If `claim_type = edit_pointer` and `max_edit_depth` declared: accepting this claim would not exceed depth limit.
12. If `claim_type = edit_pointer` and `max_edits_per_claim` declared: accepting this claim would not exceed frequency limit.
13. Transaction fee satisfies network requirements.

These rules are exhaustive. **Validators must not apply additional claim-level logic.** In particular, validators must not interpret claim semantics, determine lifecycle validity, or evaluate coordination object state. Those responsibilities belong to runtimes. The chain records; runtimes interpret.

---

## 20. Deterministic Invariants

**I1–I14 carry forward unchanged from v1.4. Two invariants added:**

**I15:** If `tombstone_authority` grants non-originator tombstone authority, the grant must declare a valid `tombstone_scope`. Unrestricted tombstone authority grants are rejected. [G]

**I16:** If `max_edit_depth` is declared, `edit_pointer` claims that would exceed the depth are rejected. If `max_edits_per_claim` is declared, `edit_pointer` claims that would exceed the frequency are rejected. [G for each, when declared]

**Invariants and deterministic replay:** These invariants, together with I1–I14, guarantee that two conformant runtimes processing the same channel history will produce identical results. This deterministic reproducibility is the foundation of the Interstellar OS correctness model: the `state_root` produced by any conformant Interstellar OS instance is derivable independently by any other conformant instance from the same Commit Channels history.

---

# PART II — DETERMINISTIC RUNTIME STANDARD

## 21. Runtime Verification and History Walking

**The Deterministic Runtime Standard defines the canonical procedures by which runtimes derive coordination state from Commit Channels claim history.** A runtime is a deterministic claim replay engine. Given an ordered claim history, a conformant runtime produces identical lifecycle state for every coordination object, regardless of where or by whom the runtime is operated. In the Interstellar architecture, Interstellar OS is the canonical conformant runtime.

Sections 21.1–21.8 carry forward unchanged from v1.4, with one addition: Section 21.9.

### 21.1 Verification Procedure

*(Unchanged from v1.4)*

### 21.2 Edit Chain Walking

*(Unchanged from v1.4)*

**Note on traversal complexity:** Edit chain walking must be O(depth) or better. Implementations must not use recursive algorithms that risk stack overflow on deep chains. Iterative traversal is required for conformance.

### 21.3 Tombstone Checking

*(Unchanged from v1.4)*

**Additional tombstone scope check:** When processing a tombstone from a non-originator key, verify that the tombstone falls within the declared `tombstone_scope` for that key's grant. If the tombstone claims authority over a claim outside its declared scope, apply CR-5: record the tombstone in history; treat it as a `notice` with no lifecycle effect.

### 21.4 Conflict Resolution Templates

*(Unchanged from v1.4 — CR-1 through CR-5)*

### 21.5 Lifecycle State Derivation

*(Unchanged from v1.4)*

The lifecycle state derivation procedure produces coordination object state from claim history. This is a pure function of the ordered claim sequence: given identical inputs, all conformant runtimes produce identical derived states. This property is required by the Interstellar OS conformance criterion: the `state_root` must be identical across all conformant implementations given the same claim history.

### 21.6 Resolution Authority Validation

*(Unchanged from v1.4)*

### 21.7 Idempotent Replay

*(Unchanged from v1.4)*

### 21.8 Partial History Bootstrap

*(Unchanged from v1.4)*

In the Interstellar OS architecture, partial history bootstrap corresponds to the verifiable snapshot model (Interstellar OS Section 5.4): a node bootstraps from a verified snapshot and replays only the claim tail from the snapshot position forward, rather than replaying from genesis.

### 21.9 Payload Criticality Handling [new in v1.5]

When processing a coordination object with `payload_criticality = critical` or `payload_criticality = conditional`:

1. Attempt payload retrieval before acting on any resolution-related lifecycle transition.
2. If retrieval fails and `payload_criticality = critical`: do not derive `resolved` state. Log the missing payload. Retain the coordination object in its current state. Retry retrieval on a configurable schedule.
3. If retrieval fails and `payload_criticality = conditional`: attempt to determine from on-chain metadata whether the specific resolution path taken requires payload content. If yes, treat as `critical`. If no, proceed.
4. If retrieval fails and `payload_criticality = non_critical`: proceed normally. The payload is not required for resolution logic.

A runtime that derives `resolved` state for a coordination object with `payload_criticality = critical` and an unresolved payload hash is not conformant.

**Alignment with Interstellar OS:** In the Interstellar OS architecture, this section's requirements are enforced by the kernel's pending queue model. A claim with `payload_criticality = critical` whose payload has not yet been retrieved is held as an `Incomplete` claim in the kernel's pending queue. The kernel does not invoke the module reducer for an `Incomplete` claim. The claim is re-inserted into the verification pipeline at its original sequence position when the payload becomes available and is hash-verified. This is the Interstellar OS implementation of the payload criticality guarantee described here.

---

## 22–24. Agent Requirements, Machine Channel Requirements, Payload Retrieval

*(Carry forward unchanged from v1.4, with Section 22 gaining one additional requirement:)*

**AD-10 [new in v1.5]:** Before acting on any resolution-related lifecycle transition for a coordination object, check `payload_criticality` and apply Section 21.9. Do not resolve critical claims with unavailable payloads.

---

# PART III — REFERENCE MATERIALS

## 25–28. Coordination Profiles, Patterns, Reference Runtime

*(Carry forward unchanged from v1.4.)*

---

## 27. Conformance Test Suite

Tests CT-1 through CT-10 carry forward unchanged from v1.4. One test added:

### CT-11: Payload criticality — critical with unavailable payload

**Input:**
```
T=100: assertion A, payload_scheme=content_addressed,
       payload_hash=H1, payload_criticality=critical,
       resolution_authority=originator
T=101: resolution R, parent=A, author=originator
[payload at H1 is not retrievable]
```
**Expected behavior:** Runtime does not derive state `resolved` for A. A remains in its prior state. Payload retrieval is retried. Only after payload is successfully retrieved and verified against H1 may runtime derive `resolved`.

### CT-12: Edit depth limit enforcement

**Input:**
```
Channel with max_edit_depth=3
T=100: assertion A
T=101: edit_pointer E1, parent=A           [depth 1]
T=102: edit_pointer E2, parent=A (via E1)  [depth 2]
T=103: edit_pointer E3, parent=A (via E2)  [depth 3]
T=104: edit_pointer E4, parent=A (via E3)  [depth 4 — exceeds max]
```
**Expected:** E4 rejected by validator.

### CT-13: Tombstone scope enforcement

**Input:**
```
Channel grants tombstone_authority to KeyZ with tombstone_scope=own_claims
T=100: assertion A, author=KeyX
T=101: tombstone T1, parent=A, author=KeyZ  [KeyZ tombstoning KeyX's claim — out of scope]
```
**Expected behavior:** T1 is recorded in history. Conformant runtimes treat T1 as a `notice` with no lifecycle effect (CR-5). A's state is unchanged.

---

## 29. Security Model

### 29.1 Guarantees [G]

*(Carry forward I1–I14 from v1.4, plus:)*

15. Tombstone authority grants must declare valid `tombstone_scope`. Unrestricted tombstone authority is rejected at channel creation.
16. Edit depth and frequency limits are chain-enforced when declared.
17. `payload_criticality` is cryptographically bound in the signable body.

### 29.2 Explicit Non-Guarantees

*(Unchanged from v1.4)*

### 29.3 Threat Analysis — Additions

**Edit chain DoS.** A malicious author publishes an arbitrarily deep edit chain to force O(depth) traversal cost on all runtimes. Mitigated by optional `max_edit_depth` and `max_edits_per_claim` fields with chain-enforced bounds when declared. Channels without declared limits accept the O(depth) traversal cost as an operational trade-off for edit flexibility. Iterative (non-recursive) traversal required by conformance (Section 21.2 note).

**Tombstone erasure attack.** A party with misconfigured or compromised tombstone authority tombstones claims they do not own, disrupting coordination state for other participants. Mitigated by `tombstone_scope` requirement, restricting non-originator tombstone authority to `own_claims` or explicitly designated claims. Unrestricted tombstone authority is chain-rejected.

**Critical payload disappearance.** A coordination object with `payload_criticality = critical` has its payload become unavailable after the claim is accepted. Runtimes with the critical payload policy (Section 21.9) will not falsely derive `resolved` state. In the Interstellar OS architecture, the kernel's pending queue model provides this guarantee at the kernel level: `Incomplete` claims are never resolved by the reducer until their payload is available and hash-verified. Runtimes without conformant payload criticality handling remain a risk surface. CT-11 detects this class of failure.

### 29.4 Known Limitations

**L1–L6 carry forward unchanged from v1.4.**

**L7 [amended]:** Edit chains without declared depth limits may become expensive to traverse for runtimes. The `max_edit_depth` and `max_edits_per_claim` fields mitigate this for channels that declare them. Channels that do not declare these limits accept the traversal cost.

**L8 [new]:** Payload availability remains a fundamental limitation of the protocol. `payload_criticality = critical` makes the dependency explicit and protects against silent misclassification of unavailable-payload resolutions as successful. It does not solve availability. Applications with strict availability requirements must use inline payload schemes.

---

## Summary

v1.5 is four targeted corrections to v1.4. It does not add coordination patterns, new lifecycle semantics, new claim types, or new protocol mechanisms.

**Why this is a protocol and not a library (Section 0):** The chain provides cross-operator verifiability, censorship attribution, append-only history without operator delete, deterministic sequencing across independent participants, and trustless authorship binding. These properties require a shared public ordering mechanism. A library cannot provide them.

**Position in the Interstellar architecture (Section 0.1):** Commit Channels is the ordered claim log that Interstellar OS consumes. The chain orders and records; Interstellar OS verifies and reduces; protocol modules interpret; applications consume derived state. This division is load-bearing. Commit Channels must remain agnostic to claim semantics; Interstellar OS must derive all protocol state from the claim stream and nothing else.

**Edit chain DoS mitigation (Section 11.5, rules object):** `max_edit_depth` and `max_edits_per_claim` are now optional rules object fields with chain-enforced bounds when declared. Traversal must be iterative, not recursive.

**Tombstone scope restriction (Sections 11.5, 14, 19, 20):** Non-originator tombstone authority must declare `tombstone_scope`. Unrestricted tombstone authority is chain-rejected. Financial and governance channels require multisig confirmation for additional tombstone authority. Out-of-scope tombstones are treated as notices with no lifecycle effect.

**Payload criticality formalization (Sections 9, 12.2, 21.9, 22):** `payload_criticality` is a [S] field in the claim object, included in the signable body. It declares whether resolution logic depends on payload content. Runtimes with the Section 21.9 policy do not derive `resolved` state for critical claims with unavailable payloads. In the Interstellar OS architecture, this corresponds to the `Incomplete` claim state in the kernel's pending queue.

The core model is unchanged. The four guarantees are unchanged. The temporal model is unchanged. The lifecycle model is unchanged. The resolution authority model is unchanged. The conflict resolution templates are unchanged. The deterministic invariants are unchanged.

The design freeze policy from v1.4 carries forward: changes require a documented justification citing a specific conformance test failure or implementation defect.

---

*Zenon Commit Channels Protocol Specification v1.5*  
*Supersedes v1.4*
