# Zenon Initial Sync Strategy Specification

**Status:** Implementation Ready
**Scope:** Local deterministic initial sync / IBD planning over libp2p libp2p
**Target:** go-zenon Phase 1
**Depends On:** libp2p Sync Protocol Specification, Sync Candidate Selection Specification, Sync Request Scheduling Specification, existing Zenon validation / acceptance logic
**Consensus Impact:** None
**Current P2P Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines how a local node plans initial sync using:

```text id="xv9d7k"
/zenon/sync/1.0.0
```

It answers:

* how advisory peer tips are sampled
* how a cautious sync target is selected
* how bounded momentum ranges are planned
* how `RESPONSE_TOO_LARGE` changes local range policy
* how momentum and account-block dependencies are respected
* how accepted progress advances
* how divergence, unavailable peers, and validation rejection pause progress safely

It does not define:

* fork choice
* consensus truth
* gossip
* current P2P fallback
* rewards
* slashing
* global reputation
* ChainBridge writes

It only defines:

> what bounded sync data should be requested next, and when local progress may safely advance

---

## Core Rule

IBD decides:

> what to request next

Scheduling decides:

> how to ask

Validation decides:

> what to accept

No object becomes accepted merely because:

* it was requested
* it was returned
* multiple peers returned matching bytes
* advisory peers reported matching tips

Acceptance remains entirely controlled by existing validation / acceptance logic.

Fork choice remains out of scope.

---

## Design Goals

The initial sync engine should:

1. Progress from latest locally accepted state
2. Use advisory peer tips only for planning
3. Avoid single-peer trust by default
4. Request bounded momentum ranges
5. Treat `RESPONSE_TOO_LARGE` as local planning feedback
6. Pause safely on advisory divergence
7. Pause safely on validation rejection
8. Halt cleanly when a source-verification dependency is unknown
9. Avoid current P2P fallback
10. Never write chain state directly
11. Never write ChainBridge state
12. Preserve explicit machine-readable pause / halt reasons

---

## Inputs

The engine consumes local inputs:

* latest accepted momentum
* local momentum store
* local account-block store
* existing validation / acceptance interface
* Sync Request Scheduler
* Sync Candidate Selector
* InitialSyncConfig
* local progress state
* local clock

The engine must not:

* open sync streams directly
* perform peer discovery directly
* run reachability verification directly
* modify current P2P

All network sync requests must go through:

> Sync Request Scheduling

---

## Outputs

The engine returns:

* session ID
* start height
* final accepted height
* requested ranges
* accepted momentum count
* rejected momentum count
* account-block request count
* final status
* pause reason
* halt reason

Allowed terminal states:

* `IBD_PROGRESS_MADE`
* `IBD_ALREADY_SYNCED`
* `IBD_PAUSED_ADVISORY_DIVERGENCE`
* `IBD_PAUSED_NO_CANDIDATES`
* `IBD_PAUSED_NO_USABLE_CANDIDATES`
* `IBD_PAUSED_SCHEDULER_BUDGET`
* `IBD_PAUSED_RESPONSE_TOO_LARGE`
* `IBD_PAUSED_VALIDATION_REJECTION`
* `IBD_HALTED_SOURCE_VERIFICATION_REQUIRED`
* `IBD_CANCELLED`

Pause:

> safe stop, may retry later

Halt:

> implementation dependency or source-verification boundary unresolved

---

## Configuration

```go id="4v5s0w"
type InitialSyncConfig struct {
    MomentumAccountBlockOrdering MomentumAccountBlockOrdering

    LocalMaxRequestCount      uint32
    MinMomentumRangeCount     uint32
    DefaultMomentumRangeCount uint32

    MinTipSamples uint32
    MaxTipSamples uint32

    AllowSinglePeerTarget bool
    AllowConservativeContinuationOnTipDivergence bool

    CandidateRefreshInterval time.Duration
}
```

Suggested defaults:

```text id="z2kq4p"
MinTipSamples = 2
MaxTipSamples = 5

AllowSinglePeerTarget = false
AllowConservativeContinuationOnTipDivergence = false

CandidateRefreshInterval = 60s
```

All config is local-only.

Remote peers must never influence configuration.

---

## Advisory Tip Sampling

IBD begins with:

```text id="2m4n9b"
GET_PEER_TIP
```

Rules:

* all tip sampling goes through scheduler
* tips are advisory only
* tips do not advance accepted state
* tips do not define fork choice
* tips do not prove honesty
* tips do not prove canonicality

Default minimum:

```text id="3j8h1m"
2 usable advisory tips
```

This is:

> anti-single-peer planning hygiene

It is not a security proof.

Two matching tips do not prove truth.

---

## Advisory Divergence

If scheduler returns:

```text id="0d7l2r"
SCHEDULED_ADVISORY_DIVERGENCE_UNRESOLVED
```

Default:

> pause

Result:

* `IBD_PAUSED_ADVISORY_DIVERGENCE`
* reason = `ADVISORY_DIVERGENCE`

No peer is punished.

No peer is globally marked dishonest.

No current P2P fallback occurs.

Optional conservative continuation:

* disabled by default
* may continue only toward lowest non-divergent common height
* may never infer canonical tip
* must re-sample after conservative target is reached

---

## Sync Target Selection

Default target:

> minimum usable advisory height observed

This is:

> cautious planning target

Not:

> canonical tip

Not:

> best chain proof

Not:

> fork choice

Single usable tip:

* default → pause
* optional single-peer mode → allowed only by explicit config

If single-peer mode is used:

> validation remains unchanged

Single-peer target is planning convenience only.

Never trust promotion.

---

## Momentum Range Planning

Start:

```text id="4w7y2t"
latest_accepted_height + 1
```

Initial count:

```text id="z8p3n1"
min(default_range, remaining_to_target)
```

Rules:

* count > 0
* count <= configured max
* never skip unknown heights
* never request beyond selected target
* planning is bounded

If local height >= target:

> `IBD_ALREADY_SYNCED`

---

## Range Size Policy

Default strategy:

> gradual growth on success
> halving on `RESPONSE_TOO_LARGE`

Example:

```text id="7v1q5k"
64 → 32 → 16 → 8 → 4 → 2 → 1
```

Rules:

* smaller retry is a new logical request
* scheduler does not split ranges
* immediate identical oversized retry is forbidden
* floor division is intentional
* minimum range is 1

If:

> range = 1
> still `RESPONSE_TOO_LARGE`

then:

> `IBD_PAUSED_RESPONSE_TOO_LARGE`

This means:

> local planning cannot reduce further

It does not prove peer dishonesty.

---

## Momentum Validation Boundary

Returned momentums are:

> untrusted serialized objects

IBD must:

* decode
* submit to existing validation / acceptance path
* wait for accepted / rejected result

IBD must not:

* accept directly from scheduler output
* implement independent acceptance
* advance progress on matching peer responses alone

Progress advances only after:

> existing validation / acceptance accepts object

Validation remains authoritative.

---

## Partial Prefix Policy

Default:

```text id="1x6m9c"
partial_prefix_acceptance = disabled
```

Meaning:

if a returned range contains an invalid momentum:

> pause

Result:

* `IBD_PAUSED_VALIDATION_REJECTION`

Later momentums in that range:

> must not be assumed valid

Partial prefix advancement requires future explicit source verification.

Disabled by default.

---

## Momentum / Account-Block Ordering

Ordering is source-verified configuration.

Allowed:

* `MOMENTUM_ACCEPTS_BEFORE_ACCOUNT_BLOCKS`
* `ACCOUNT_BLOCKS_REQUIRED_BEFORE_MOMENTUM_ACCEPTANCE`

Default:

```text id="6q0k2a"
ORDERING_UNKNOWN
```

If unknown:

> halt

Result:

* `IBD_HALTED_SOURCE_VERIFICATION_REQUIRED`

IBD must not guess ordering.

Remote peers must never influence ordering.

---

## Account Block Retrieval

When required, request:

```text id="8f2r4m"
GET_ACCOUNT_BLOCKS_BY_MOMENTUM
```

Rules:

* follows configured ordering
* account blocks are untrusted serialized objects
* existing validation decides acceptance
* completeness semantics follow Sync Protocol
* partial OK remains forbidden

If dependency ordering is unknown:

> halt safely

Never guess.

---

## Account Chain Recovery

Optional recovery path:

```text id="0t5n8q"
GET_ACCOUNT_CHAIN_RANGE
```

Default:

> disabled

May only be enabled after source verification of:

* address parsing
* account-chain height model
* range semantics

It is recovery only.

Not fork choice.

Not canonicality.

---

## Progress Advancement

Local progress advances only after:

* accepted momentum
* accepted required account-block set
* validated local store update that is part of acceptance path

Progress must not advance on:

* advisory tips
* received bytes
* matching peer responses
* decode success
* validation-only success if acceptance is separate
* `NOT_FOUND`
* `TEMPORARILY_UNAVAILABLE`
* `RESPONSE_TOO_LARGE`

Accepted progress only.

Nothing else.

---

## Candidate Refresh

Refresh candidates when:

* no usable candidates
* cooldown state changed materially
* advisory sampling round completes
* repeated request failures occur
* refresh interval expires

Suggested:

```text id="5h3q7w"
60 seconds
```

Refresh must go through:

> Sync Candidate Selection

Never direct discovery.

---

## Scheduler Mapping

IBD consumes scheduler outcomes.

Examples:

* no candidates → `IBD_PAUSED_NO_CANDIDATES`
* no usable candidates → `IBD_PAUSED_NO_USABLE_CANDIDATES`
* budget exhausted → `IBD_PAUSED_SCHEDULER_BUDGET`
* advisory divergence → `IBD_PAUSED_ADVISORY_DIVERGENCE`
* repeated validation rejection → `IBD_PAUSED_VALIDATION_REJECTION`

Scheduler failures are:

> local operational outcomes

Not peer dishonesty proof.

---

## Security Rules

Must enforce:

* advisory-only tip interpretation
* bounded range requests
* validation-before-acceptance
* no direct acceptance from sync output
* no direct stream opening
* scheduler-only network requests
* explicit pause / halt states
* no fallback to current P2P
* no ChainBridge writes
* no trust promotion
* no fork choice creation

Must not:

* invent ordering
* infer canonicality
* skip validation
* create rewards
* create slashing
* create global reputation

---

## Abuse Cases

Mitigations exist for:

* single-peer target capture
* advisory divergence
* oversized range pressure
* decodable but invalid momentum payloads
* missing account-block completeness knowledge
* scheduler budget exhaustion
* unknown acceptance ordering
* validation adapter contract failure

IBD remains:

> bounded local planning only

Never protocol truth.

---

## Final Rule

Initial Sync Strategy decides:

> what bounded chain data should be requested next

Scheduling decides:

> how to ask

Validation decides:

> what becomes accepted

Still:

> requested first is not trusted first
> returned first is not accepted first

Acceptance remains authoritative.
