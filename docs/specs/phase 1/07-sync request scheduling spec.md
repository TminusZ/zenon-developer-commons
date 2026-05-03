# Zenon Sync Request Scheduling Specification

**Status:** Implementation Ready
**Scope:** Local deterministic scheduling of bounded sync requests over libp2p libp2p
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification, Peer Reachability Verification Specification, Peer Service Scoring Specification, libp2p Sync Protocol Specification, Sync Candidate Selection Specification
**Consensus Impact:** None
**Current P2P Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines how a local node schedules bounded sync requests using:

```text id="5r1jlb"
/zenon/sync/1.0.0
```

It answers:

* which candidate to query first
* how many peers may be queried
* when to rotate peers
* how retries work
* how per-peer pressure is bounded
* how global sync pressure is bounded
* how advisory disagreement is handled
* how local observations feed scoring and cooldown

It does not define:

* fork choice
* canonical chain selection
* object acceptance
* IBD strategy
* gossip
* current P2P replacement
* rewards
* slashing

Scheduling decides:

> how to ask

Validation decides:

> what to accept

---

## Core Rule

A scheduled request creates:

> transport opportunity

It does not create:

* trust
* consensus weight
* authority
* proof of correctness
* proof of dishonesty

A frequently queried peer is not authoritative.

A divergent response is not proof of malicious behavior.

All returned data remains:

> untrusted until existing validation accepts it

---

## Design Goals

The scheduler should:

1. Consume ordered Sync Candidates deterministically
2. Avoid hammering one peer
3. Bound per-peer request load
4. Bound global request load
5. Rotate peers after failures
6. Prefer sequential scheduling for identical requests
7. Keep advisory disagreement unresolved when uncertain
8. Emit local observations for scoring
9. Emit local cooldown signals when warranted
10. Never write chain state
11. Never perform discovery directly
12. Never fall back automatically to current P2P

---

## Inputs

The scheduler consumes:

* SyncCandidate list
* local scheduler config
* local budget state
* local per-peer state
* local cooldown state
* local clock
* local validation result sink
* local observation sink

The scheduler may:

> open sync streams

The scheduler must not:

* perform peer discovery
* refresh peer-info
* run reachability verification
* perform candidate selection logic internally
* write chain state
* write ChainBridge state

Candidate refresh must come from:

> Sync Candidate Selection

---

## Request Classes

Allowed classes:

* ADVISORY
* OBJECT_LOOKUP
* RANGE_LOOKUP
* ACCOUNT_LOOKUP

Mapping:

```text id="jlwm2s"
GET_PEER_TIP → ADVISORY
GET_MOMENTUM_BY_HASH → OBJECT_LOOKUP
GET_MOMENTUM_RANGE → RANGE_LOOKUP
GET_ACCOUNT_BLOCKS_BY_MOMENTUM → ACCOUNT_LOOKUP
GET_ACCOUNT_CHAIN_RANGE → ACCOUNT_LOOKUP
```

Class controls:

* timeout
* retry budget
* limited parallelism
* observation type
* cooldown impact

Class does not control:

> acceptance

Validation still decides acceptance.

---

## Deterministic Request Fingerprint

Every logical request must produce:

> deterministic request fingerprint

Fingerprint includes:

* request type
* request parameters
* local network ID
* local genesis hash
* protocol ID
* advisory session ID when applicable

Fingerprint must not include:

* peer score
* candidate rank
* peer response data
* peer randomness
* peer-influenced nonce
* local timestamp

Identical logical request:

> same fingerprint

Different logical request:

> different fingerprint

This prevents duplicate logical request confusion.

---

## Candidate Consumption

Scheduler consumes ordered candidates.

Rules:

1. preserve initial ordering
2. do not query all simultaneously
3. skip peers under cooldown
4. skip peers over caps
5. rotate on failure
6. same-peer retry disabled by default
7. candidate rank never affects validation

Selection order is:

> scheduling preference only

Never trust weighting.

---

## Per-Peer Caps

Suggested defaults:

```text id="9h1zla"
max_in_flight_per_peer = 2
max_in_flight_per_peer_per_class = 1
max_requests_per_peer_per_minute = 30
same_peer_retry_default = disabled
```

Applies equally to:

* manual peers
* preferred peers
* acceptable peers

No peer bypasses caps.

---

## Global Budget

Suggested defaults:

```text id="y4qk2m"
max_total_in_flight_sync_requests = 16
max_total_sync_requests_per_minute = 240
max_identical_request_parallelism = 1
```

Budget exhaustion:

> reject local scheduling request

Result:

```text id="jlwm5k"
SCHEDULED_BUDGET_EXHAUSTED
```

This is:

> local only

It does not penalize peers.

Queueing is out of scope.

---

## Timeout Policy

Suggested defaults:

```text id="b8wr1g"
ADVISORY = 3s
OBJECT_LOOKUP = 5s
RANGE_LOOKUP = 10s
ACCOUNT_LOOKUP = 10s
max_timeout = 30s
```

Timeout covers full lifecycle:

* connection acquisition
* stream open
* negotiation
* request write
* response framing
* response read

Timeout result:

* close stream
* record timeout observation
* rotate candidate
* apply local cooldown policy

Timeout does not prove dishonesty.

Timeout does not create global reputation.

---

## Retry Policy

Suggested defaults:

```text id="m2o9rk"
ADVISORY attempts = 3
OBJECT_LOOKUP attempts = 3
RANGE_LOOKUP attempts = 4
ACCOUNT_LOOKUP attempts = 4
```

Retry means:

> try next eligible peer

Retry does not mean:

> immediately retry same peer

Same-peer retry:

> disabled by default

If enabled later:

* explicit config required
* retry cap required
* alternatives must be exhausted
* peer must not be cooling down
* caps must allow retry

---

## Candidate Rotation

Rotate after:

* connection failure
* timeout
* RATE_LIMITED
* TEMPORARILY_UNAVAILABLE
* malformed response
* protocol violation
* validation rejection
* RESPONSE_TOO_LARGE
* advisory disagreement requiring more observations

Do not rotate after:

* local cancellation
* construction failure
* local budget exhaustion
* valid response when request is satisfied

Rotation remains deterministic.

---

## Parallelism

Default:

```text id="jlwm8v"
max_identical_request_parallelism = 1
```

Meaning:

> sequential identical-request scheduling

Limited advisory parallelism may be configured later.

Even then:

* never query all peers at once
* obey per-peer caps
* obey global caps

Parallelism does not create fork choice.

---

## Advisory Tip Handling

`GET_PEER_TIP` is:

> advisory only

It is:

* planning metadata
* uncertainty reduction signal

It is not:

* fork choice
* canonical proof
* proof of dishonesty

Divergence:

> same height, different hash

Response:

* mark advisory divergence
* do not advance planning from divergent tips
* query additional candidates within advisory budget
* if unresolved:

```text id="jlwm0p"
SCHEDULED_ADVISORY_DIVERGENCE_UNRESOLVED
```

That is normal scheduler output.

Not consensus failure.

Not fork proof.

---

## Response Handling

Scheduler handles:

* OK
* RATE_LIMITED
* TEMPORARILY_UNAVAILABLE
* NOT_FOUND
* RESPONSE_TOO_LARGE
* malformed response
* validation rejected response

Rules:

### RATE_LIMITED

* rotate peer
* apply local cooldown
* no global reputation

### TEMPORARILY_UNAVAILABLE

* rotate peer
* temporary signal only
* not dishonesty

### NOT_FOUND

* local view only
* not global absence proof
* may query other peers

### RESPONSE_TOO_LARGE

* reject partial payload
* scheduler does not split ranges
* future IBD strategy may split

### Malformed

* rotate peer
* record malformed observation
* local cooldown

### Validation Rejected

* reject object
* rotate peer
* local observation only
* not proof of dishonesty

---

## Observations

Scheduler emits local-only observations:

* success
* timeout
* connection failure
* RATE_LIMITED
* TEMPORARILY_UNAVAILABLE
* NOT_FOUND
* RESPONSE_TOO_LARGE
* malformed response
* validation rejected
* advisory divergence

Observations feed:

* local scoring
* local cooldown

Observations do not create:

* global reputation
* slashing
* rewards

Construction failures emit:

> no peer observation

because no peer was contacted.

---

## Cooldown Feedback

Cooldown may be applied for:

* repeated timeout
* repeated connection failure
* repeated RATE_LIMITED
* malformed responses
* protocol violations
* repeated validation rejection

Cooldown must not be triggered by:

* one NOT_FOUND
* one TEMPORARILY_UNAVAILABLE
* advisory disagreement alone
* local construction failure

Cooldown is:

* local
* temporary
* bounded
* diagnostic

Never consensus.

Never punishment.

---

## Empty Candidate Behavior

No candidates:

```text id="jlwm4u"
SCHEDULED_NO_CANDIDATES
```

Candidates exist but unusable:

```text id="jlwm7x"
SCHEDULED_NO_USABLE_CANDIDATES
```

All tried and failed:

```text id="jlwm1n"
SCHEDULED_ALL_CANDIDATES_FAILED
```

These are:

> local scheduler outcomes only

They do not imply:

* object absence
* network failure
* malicious behavior

---

## Security Rules

Must enforce:

* deterministic request fingerprint
* per-peer caps
* global caps
* timeout bounds
* deterministic rotation
* no chain writes
* no ChainBridge writes
* no trust promotion
* local-only cooldown
* local-only observations

Must not:

* define fork choice
* define canonicality
* create rewards
* create slashing
* create global reputation
* replace current P2P
* perform peer discovery directly

---

## Abuse Cases

Mitigations exist for:

* rank-1 peer overuse
* rate-limit traps
* advisory disagreement
* malformed payload peers
* repeated NOT_FOUND responses
* oversized responses
* manual peer overuse
* repeated timeout peers
* retry loops

Scheduler remains:

> bounded local orchestration only

Never protocol truth.

---

## Final Rule

Sync Request Scheduling decides:

> when, where, and how to ask for bounded sync data

It does not decide:

> what is true

Validation remains authoritative.

Scheduling is local orchestration only.
