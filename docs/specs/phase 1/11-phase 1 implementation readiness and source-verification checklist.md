# Zenon Phase 1 Implementation Readiness and Source-Verification Checklist

**Status:** Implementation Ready
**Scope:** Implementation gating, source verification, CI safety boundaries, and readiness classification for Zenon Phase 1 libp2p integration
**Type:** Implementation Gatekeeper
**Protocol Impact:** None
**Consensus Impact:** None
**Current P2P Replacement:** None
**ChainBridge Authority:** None
**Migration Authority:** None

---

## Purpose

The previous Phase 1 specifications define mechanisms.

This checklist defines:

> what may be built
> what may be connected
> what must remain disabled
> what must be source-verified first
> what blocks implementation
> what CI must enforce

This document exists to prevent:

> a correct mechanism being connected through an unsafe boundary

Build mechanism first.

Connect only through verified boundaries.

---

## Core Rule

When in doubt:

> disable
> shadow
> observe
> do not mutate

Do not connect libp2p into:

* accepted chain state mutation
* current P2P broadcaster paths
* current P2P sync/fetch paths
* gossip publish paths
* ChainBridge write paths
* bridge-adjacent embedded contract writes

unless the relevant source-verification gates are satisfied.

Unknown path:

> unsafe

Unsafe path:

> disabled

---

## Readiness Bands

Phase 1 readiness bands:

```text id="g1n5xv"
Band 0  SAFE_LOCAL_CODE
Band 1  LIBP2P_RUNTIME
Band 2  SHADOW_OBSERVATION
Band 3  READ_ONLY_NETWORK_REQUESTS
Band 4A IBD_PLANNING_SHADOW
Band 4B IBD_SHADOW_VALIDATION_DIAGNOSTICS
Band 5  AUXILIARY_FETCH
Band 6  GOSSIP_ACTIVE
Band 7  MIGRATION_EXPERIMENTAL
```

Rules:

* higher bands require lower bands stable first
* production connection must progress sequentially
* mock parallel development is allowed
* production skipping is forbidden
* each band remains independently gated

Band progression is:

> readiness staging

Not migration authorization.

---

## FeatureReadiness Model

Each feature must expose explicit readiness state.

```go id="h6k2pw"
type FeatureReadinessStatus string

const (
    FeatureBlocked    FeatureReadinessStatus = "BLOCKED"
    FeatureShadowOnly FeatureReadinessStatus = "SHADOW_ONLY"
    FeatureReadOnly   FeatureReadinessStatus = "READ_ONLY"
    FeatureActive     FeatureReadinessStatus = "ACTIVE"
)

type FeatureReadiness struct {
    Feature      FeatureID
    Status       FeatureReadinessStatus
    MissingGates []GateID
}
```

Rules:

`BLOCKED`

> feature must not start

`SHADOW_ONLY`

> observe only
> no fetch
> no publish
> no acceptance submission
> no mutation

`READ_ONLY`

> bounded read-only behavior only

`ACTIVE`

> only within authority granted by its band

FeatureReadiness is mandatory for:

> Band 3 and above

---

## Partial Feature Enablement

Bands may be partially enabled.

Example:

* `GET_PEER_TIP` gates satisfied
* `GET_ACCOUNT_CHAIN_RANGE` gates missing

Result:

* `GET_PEER_TIP` = enabled
* `GET_ACCOUNT_CHAIN_RANGE` = blocked

Band:

> partially enabled

Never present partially enabled band as fully enabled.

Feature-level readiness always wins.

---

## GateID Namespace

Gate identifiers must be:

* stable
* namespaced
* implementation-safe
* CI-safe

Format:

```text id="2q8n4r"
<spec-prefix>:<section>:<gate-id>
```

Prefixes:

```text id="5v1m7t"
host
disc
reach
score
sync
select
sched
ibd
gossip
coex
ready
```

Examples:

```text id="0k3w9m"
coex:30:12
gossip:gate:accepted-momentum-event
ready:17:momentum-validation-entrypoint
```

Forbidden:

* free-form strings
* unstable names
* unnamed blockers
* raw numeric gate labels

Every missing gate must be explicit.

---

## FeatureID Namespace

Feature identifiers must be stable.

Format:

```text id="3r7v1p"
phase1:<feature-name>
```

Examples:

```text id="6n2k8q"
phase1:libp2p-host
phase1:service-discovery-shadow
phase1:reachability-verification
phase1:service-scoring
phase1:sync-peer-tip
phase1:sync-momentum-range
phase1:sync-request-scheduling
phase1:ibd-planning-shadow
phase1:auxiliary-fetch-momentum
phase1:gossip-active-momentum
phase1:coexistence-rollback
```

No free-form FeatureIDs.

Stable identifiers only.

---

## Build Bands Summary

### Band 0 — Safe Local Code

Build now:

* config structs
* enums
* local stores
* dedup stores
* rate limiters
* observation structs
* mocks
* test harnesses
* serialization helpers
* mode state machine skeleton

No network.

No chain mutation.

No ChainBridge.

---

### Band 1 — libp2p Runtime

Unlocks:

> host only

Allowed:

* host startup
* peer identity
* bootstrap
* peer-info exchange

Forbidden:

* sync
* IBD
* gossip publish
* chain writes

---

### Band 2 — Shadow Observation

Unlocks:

* discovery shadow
* reachability verification
* service scoring
* gossip shadow

Observation only.

No fetch.

No publish.

No mutation.

---

### Band 3 — Read-Only Requests

Unlocks:

* bounded sync requests
* bounded sync serving
* scheduler
* candidate selection
* local request observations

Still:

> no direct acceptance
> no chain mutation

---

### Band 4A / 4B — IBD Shadow

Unlocks:

* planning shadow
* optional non-mutating validation diagnostics if verified

Still:

> no acceptance
> no mutation

---

### Band 5 — Auxiliary Fetch

Unlocks:

> submit candidate data through existing verified validation / acceptance boundaries only

Still:

* additive only
* no replacement
* no hidden fallback

---

### Band 6 — Gossip Active

Unlocks:

* momentum announcements
* tip announcements
* bounded fetch-after-announce

Only from:

> accepted local state

Account-block gossip:

> disabled until separately verified

---

### Band 7 — Migration Experimental

Local / dev only.

Never production without future explicit migration specification.

Unlocks:

> nothing authoritative

---

## Global Hard Blockers

Implementation stops if:

* validation / acceptance boundary unknown
* non-mutating validation path unknown for shadow validation
* ChainBridge write path reachable
* bridge-adjacent embedded contract write reachable
* current P2P broadcaster reachable from libp2p path
* current P2P sync/fetch reachable from libp2p path
* scheduler bypassed
* candidate selection bypassed
* ObjectIngressSource absent at publish boundary
* gossip source is not `LOCAL_ACCEPTANCE`
* silent current P2P fallback exists
* mode transition not atomic
* rollback generation safety missing

Result:

> disable affected feature
> record local diagnostic
> current P2P unchanged

---

## Validation / Acceptance Boundary Matrix

Must source-verify for:

`MOMENTUM`
`ACCOUNT_BLOCK`

Required fields:

* validation entry point
* acceptance entry point
* validation / acceptance separation
* validation mutability
* acceptance mutability
* non-mutating validation-only path
* shadow safety
* auxiliary-fetch safety
* read-only accepted-state accessor
* store write paths
* error / rejection semantics
* accepted-object event source

Rules:

Unknown mutability:

> mutating

Unknown boundary:

> unsafe

Unknown accessor:

> unavailable

Blank field:

> gate unsatisfied

Unfilled matrix:

> not readiness evidence

Partial matrix:

> unlocks partial features only

---

## Current P2P Isolation Checklist

Must inspect:

* startup path
* peer discovery
* sync logic
* fetch paths
* message handlers
* broadcaster paths
* momentum broadcast path
* validation / acceptance calls
* ChainBridge adjacency

Must prove libp2p cannot indirectly invoke:

* current P2P broadcast
* current P2P sync/fetch
* rebroadcast loops

Until proven:

> no bridge
> no replacement
> no rebroadcast

---

## ChainBridge Isolation Checklist

Must inspect:

* ChainBridge writers
* swap / claim writers
* orchestrator signer paths
* bridge state mutators
* embedded bridge contract calls
* embedded contract write adjacency

Rule:

Any reachable write path from libp2p:

> hard blocker

Read-only diagnostics may be allowed if independently verified.

Mutation authority remains forbidden.

---

## ObjectIngressSource Checklist

Every ingress object must classify:

```go id="7m4t2k"
LOCAL_ACCEPTANCE
CURRENT_P2P
LIBP2P_SYNC
LIBP2P_GOSSIP
```

Rules:

Only:

> `LOCAL_ACCEPTANCE`

may trigger gossip publish.

Unknown source:

* cannot publish
* cannot bridge
* cannot assume local acceptance

This prevents:

> double broadcast loops
> source confusion
> rebroadcast amplification

---

## Required CI Guards

CI must fail if:

* current P2P broadcaster is called from Phase 1 path
* current P2P sync/fetch path is called from Phase 1 path
* ChainBridge writer is called from Phase 1 path
* shadow mode publishes gossip
* feature bypasses readiness gate
* transition partially applies without rollback
* late async result mutates state after rollback
* unstable GateIDs appear
* free-form FeatureIDs appear

These are:

> hard CI boundaries

Not warnings.

---

## Recommended Implementation Order

Build in order:

1. Band 0 foundations
2. coexistence manager skeleton
3. host runtime
4. discovery shadow
5. reachability
6. scoring
7. sync protocol
8. candidate selection
9. request scheduling
10. read-only store access verification
11. IBD planning shadow
12. validation / acceptance boundary verification
13. IBD shadow validation diagnostics
14. auxiliary fetch
15. gossip shadow
16. accepted-object event verification
17. gossip active
18. account-block gossip only if fully verified
19. migration experimental only under future spec

Parallel development:

> allowed with mocks

Production connection:

> gated sequentially

---

## Buildable Now

Immediately buildable:

* config
* enums
* stores
* mocks
* dedup
* rate limiters
* observation models
* libp2p host skeleton
* service discovery registry
* nonce cache
* scoring engine
* scheduler state
* gossip envelopes
* coexistence manager skeleton

Mock-buildable:

* scheduler
* selector
* IBD planner
* gossip service
* rollback manager

Real state connection:

> source gates required first

---

## Must Remain Disabled Until Verified

Disabled by default:

* account-block gossip
* shadow validation without verified non-mutating path
* auxiliary acceptance submission without verified acceptance boundary
* current P2P bridge
* production migration experimental
* ChainBridge interaction
* current P2P replacement
* gossip active publish without verified accepted-object source

Unknown safety:

> disabled

Always.

---

## Final Rule

This document is the implementation gatekeeper.

Final invariant:

> build local mechanisms first
> connect only through source-verified boundaries
> if a path can mutate state and is not verified, do not call it

Current P2P remains authoritative.

Phase 1 remains:

> additive
> gated
> observable
> reversible
