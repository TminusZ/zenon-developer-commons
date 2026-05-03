# Zenon Current P2P Coexistence and Migration Roadmap Specification

**Status:** Implementation Ready
**Scope:** Additive coexistence, gating, observability, and rollback between existing go-zenon current P2P and the libp2p Phase 1 libp2p stack
**Target:** go-zenon Phase 1
**Depends On:** All prior Phase 1 libp2p specifications, existing go-zenon validation / acceptance logic, existing go-zenon current P2P behavior
**Consensus Impact:** None
**Current P2P Replacement:** None
**ChainBridge Impact:** None
**Economic Impact:** None
**Global Reputation Impact:** None

---

## Purpose

The Phase 1 libp2p stack now defines:

* host identity
* service discovery
* reachability verification
* service scoring
* bounded sync requests
* sync candidate selection
* sync request scheduling
* initial sync planning
* live gossip announcements

This specification defines:

> how that stack coexists beside current P2P without replacing it

It answers:

* what remains authoritative
* which libp2p capabilities may run
* which capabilities remain read-only
* which capabilities may fetch data
* which capabilities may publish gossip
* how rollback works
* how double-broadcast loops are prevented
* how readiness is observed
* what requires a future migration specification

This is:

> coexistence architecture

Not migration authorization.

---

## Core Rule

Current P2P remains authoritative until an explicit migration specification says otherwise.

libp2p may:

* observe
* request
* announce
* validate through existing validated paths

libp2p must not:

* replace current P2P by implication
* silently fall back into current P2P on failure
* disable current P2P automatically
* bridge into current P2P without bridge specification
* write ChainBridge state
* define consensus

Existence does not create authority.

---

## Design Goals

The coexistence layer should:

1. Keep current P2P authoritative by default
2. Gate every libp2p capability explicitly
3. Support shadow observation before active use
4. Support additive auxiliary fetch before replacement
5. Support gossip observation before active publishing
6. Prevent double-broadcast loops
7. Prevent silent fallback paths
8. Preserve validation / acceptance boundaries
9. Preserve ChainBridge isolation
10. Preserve consensus isolation
11. Provide readiness metrics
12. Provide rollback for every mode
13. Require explicit migration specification before replacement

---

## Existing Authority Boundary

Current P2P remains authoritative for:

* peer connectivity
* current network sync behavior
* current broadcast behavior
* transaction relay
* momentum relay
* existing chain behavior

Existing validation / acceptance remains authoritative for:

* momentum acceptance
* account-block acceptance
* accepted state mutation

libp2p must not modify those boundaries.

Replacement requires:

* explicit migration specification
* staged rollout plan
* rollback plan
* readiness gates
* hostile review

---

## Integration Modes

Allowed modes:

```text id="3t9k6q"
LIBP2P_DISABLED
LIBP2P_HOST_ONLY
LIBP2P_DISCOVERY_SHADOW
LIBP2P_SYNC_READ_ONLY
LIBP2P_IBD_SHADOW
LIBP2P_AUXILIARY_FETCH
LIBP2P_GOSSIP_SHADOW
LIBP2P_GOSSIP_ACTIVE
LIBP2P_MIGRATION_EXPERIMENTAL
```

Default:

```text id="7h2m5p"
LIBP2P_DISABLED
```

No mode in this specification replaces current P2P.

`LIBP2P_MIGRATION_EXPERIMENTAL` is:

> local test / development only

Never production by default.

---

## Mode Progression

Normal progression:

```text id="6q1r8v"
DISABLED
→ HOST_ONLY
→ DISCOVERY_SHADOW
→ SYNC_READ_ONLY
→ IBD_SHADOW
→ AUXILIARY_FETCH
→ GOSSIP_SHADOW
→ GOSSIP_ACTIVE
→ MIGRATION_EXPERIMENTAL
```

Progression is:

* explicit
* local
* gated
* observable
* reversible

No automatic migration.

No hidden mode promotion.

---

## Mode Semantics

### LIBP2P_DISABLED

Allowed:

> nothing

Behavior:

* no host
* no discovery
* no sync
* no gossip

Current P2P unchanged.

Safe default.

---

### LIBP2P_HOST_ONLY

Allowed:

* host startup
* peer identity
* listener binding
* bootstrap connectivity
* peer-info exchange

Forbidden:

* sync
* IBD
* gossip publish
* chain writes

Current P2P unchanged.

---

### LIBP2P_DISCOVERY_SHADOW

Allowed:

* service discovery
* reachability verification
* service scoring
* diagnostics

Forbidden:

* fetch
* IBD
* gossip publish
* chain writes

Diagnostic only.

---

### LIBP2P_SYNC_READ_ONLY

Allowed:

* bounded sync requests
* bounded sync serving
* advisory tips
* local observations

Forbidden:

* direct acceptance
* direct chain insertion
* current P2P replacement

Returned data remains untrusted.

Validation remains authoritative.

---

### LIBP2P_IBD_SHADOW

Allowed:

* advisory sampling
* range planning
* scheduler requests
* diagnostics
* non-mutating comparison paths only

Forbidden:

* accepted state mutation
* current P2P replacement

Shadow only.

---

### LIBP2P_AUXILIARY_FETCH

Allowed:

* additive bounded fetch
* scheduler-routed requests
* candidate-selected requests
* validation through existing acceptance paths only

Forbidden:

* direct canonicality
* direct chain insertion
* current P2P replacement

Current P2P remains authoritative.

---

### LIBP2P_GOSSIP_SHADOW

Allowed:

* subscribe
* decode
* authenticate
* deduplicate
* rate-limit
* diagnostics

Forbidden:

* publish
* bridge
* chain writes

Observation only.

---

### LIBP2P_GOSSIP_ACTIVE

Allowed:

* publish accepted-object announcements
* bounded fetch-after-announce
* scheduler-routed gossip fetches

Forbidden:

* publish unaccepted objects
* bridge into current P2P
* replace current P2P

Additive only.

---

### LIBP2P_MIGRATION_EXPERIMENTAL

Reserved for:

> controlled local testing only

Forbidden in production without future migration specification.

No implied authority.

---

## Validation Boundary

libp2p may submit fetched candidate objects only through:

> existing validation / acceptance paths

libp2p must never:

* accept directly
* mutate accepted state directly
* bypass validation
* invent acceptance logic

If safe validation / acceptance boundaries are unknown:

> feature remains gated off

Unknown is never permissive.

---

## No Silent Fallback

If libp2p fails:

> libp2p reports failure

It must not:

* secretly invoke current P2P fetch
* secretly invoke current P2P broadcast
* silently bridge messages
* silently downgrade authority boundaries

Current P2P may continue independently because it already exists.

That is not fallback.

That is coexistence.

---

## Current P2P Bridge Policy

Default:

```text id="9w3k1m"
AllowCurrentP2PBridge = false
```

Meaning:

> no bridge exists in Phase 1

Forbidden:

* libp2p gossip → current P2P broadcast
* current P2P broadcast → libp2p gossip
* libp2p sync failure → current P2P fetch
* peer score sharing between systems

Any bridge requires:

> future explicit bridge specification

Not config-only activation.

---

## ChainBridge Isolation

Forbidden:

* ChainBridge writer
* bridge signer
* bridge executor
* swap state writer
* bridge state mutator

Allowed:

> read-only diagnostics if independently source-verified

Phase 1 libp2p must not write ChainBridge state.

---

## Consensus Isolation

Forbidden:

* new fork choice
* new canonicality rule
* validator rule changes
* momentum acceptance rule changes
* account-block acceptance rule changes

Allowed:

> submitting candidate data to existing validation / acceptance paths

Consensus remains unchanged.

---

## ObjectIngressSource

Every object entering coexistence receives local ingress classification:

```go id="4m8q2v"
type ObjectIngressSource string

const (
    IngressSourceLocalAcceptance ObjectIngressSource = "LOCAL_ACCEPTANCE"
    IngressSourceCurrentP2P      ObjectIngressSource = "CURRENT_P2P"
    IngressSourceLibp2pSync      ObjectIngressSource = "LIBP2P_SYNC"
    IngressSourceLibp2pGossip    ObjectIngressSource = "LIBP2P_GOSSIP"
)
```

Rules:

Only:

```text id="1x5r7n"
LOCAL_ACCEPTANCE
```

may trigger libp2p publish.

Never:

* current P2P ingress
* libp2p sync ingress
* libp2p gossip ingress

Unknown ingress:

> suppress publish

Never assume `LOCAL_ACCEPTANCE`.

This prevents:

> double-broadcast loops

by mechanism, not policy.

---

## Readiness Metrics

Implementations should expose:

* current mode
* host running state
* discovery totals
* reachability totals
* sync request totals
* sync success / failure
* IBD shadow planning totals
* gossip receive totals
* gossip drop totals
* gossip fetch totals
* bridge blocked totals

Metrics are:

> diagnostic only

Metrics must never trigger automatic migration.

---

## Migration Gates

Before any replacement specification exists:

Required:

* current P2P source verified
* validation / acceptance boundaries source verified
* ChainBridge isolation verified
* sync stack verified
* gossip stack verified
* rollback verified
* double-broadcast prevention verified
* bridge remains disabled
* shadow metrics collected
* additive fetch tested
* gossip shadow tested

Satisfied gates do not authorize migration.

They only establish:

> coexistence readiness

Migration still requires:

> future explicit migration specification

---

## Rollback Rule

Every mode must roll back safely.

Rollback must:

* stop new libp2p work
* preserve accepted chain state
* preserve current P2P operation
* stop gossip publish first
* stop fetch triggers
* stop shadow planning
* ignore late async results from rolled-back generations

Rollback must never:

* invoke current P2P fallback
* write ChainBridge state
* corrupt accepted state

Rollback is mandatory architecture.

Not optional behavior.

---

## Crash Downgrade Rule

Unexpected libp2p crash:

* record failure
* stop new work
* downgrade only to lower-capability mode
* never auto-upgrade
* never trigger migration
* never invoke hidden fallback
* preserve current P2P

Late async results from old generation:

> ignored

Failed generation becomes non-current.

Generation ownership is strict.

---

## Implementation Boundary

Suggested module:

```text id="2k6n9p"
integration/libp2pcoexistence
```

Suggested interface:

```go id="8p4t1q"
type Libp2pIntegrationManager interface {
    CurrentMode() Libp2pIntegrationMode
    StartMode(ctx context.Context, mode Libp2pIntegrationMode) error
    TransitionMode(ctx context.Context, mode Libp2pIntegrationMode) error
    Rollback(ctx context.Context, target Libp2pIntegrationMode) error
}
```

Allowed dependencies:

* current P2P read-only diagnostics
* libp2p host manager
* discovery manager
* sync scheduler
* initial sync engine
* gossip service
* metrics
* config
* clock

Forbidden dependencies:

* ChainBridge writer
* consensus mutator
* reward writer
* slashing writer
* global reputation publisher
* current P2P broadcaster

---

## Final Rule

Current P2P remains authoritative.

libp2p remains:

> additive
> gated
> observable
> reversible

Until a future migration specification explicitly changes authority:

> coexistence is not replacement
> observation is not migration
> additive capability is not authority
