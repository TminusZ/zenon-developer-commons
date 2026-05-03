# Zenon Sync Candidate Selection Specification

**Status:** Implementation Ready
**Scope:** Local deterministic selection of peers eligible for libp2p sync requests
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification, Peer Reachability Verification Specification, Peer Service Scoring Specification, libp2p Sync Protocol Specification
**Consensus Impact:** None
**Current P2P Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines how a local node selects which peers are eligible candidates for:

```text id="4j7xmn"
/zenon/sync/1.0.0
```

Candidate selection answers:

* who may be asked
* who should be asked first
* who should be temporarily avoided
* how stale local signals are treated
* how manual peers interact with discovered peers
* how single-peer dependency is reduced when alternatives exist

Candidate selection does not decide:

* what data is accepted
* which ranges are requested
* how sync scheduling works
* fork choice
* validation
* consensus truth

It only ranks local candidate suitability.

---

## Core Rule

Candidate selection decides:

> who to ask

Existing validation decides:

> what to believe

A selected peer is never trusted merely because it is selected.

Higher rank does not create:

* authority
* truth
* consensus weight
* reward eligibility

All received sync data remains untrusted until accepted by existing validation paths.

---

## Design Goals

The selector should:

1. Prefer peers that support `/zenon/sync/1.0.0`
2. Prefer authenticated compatible network identity
3. Prefer `SYNC_CANDIDATE` or `FULL_NODE`
4. Prefer locally reachable peers
5. Prefer recently successful peers
6. Apply temporary cooldown after bad behavior
7. Reduce single-peer dependency when alternatives exist
8. Keep deterministic output for identical local state
9. Perform no network I/O
10. Produce explainable exclusion reasons

---

## Inputs

The selector consumes local state only.

It must not:

* dial peers
* refresh peer-info
* open streams
* perform reachability checks
* perform sync requests

Selection is read-only local evaluation.

Inputs may include:

* Service Discovery records
* Reachability records
* Service Scoring records
* authenticated peer-info
* manual peer config
* local cooldown state

---

## Authenticated Identity Rule

Candidate records are merged only by:

> authenticated libp2p peer ID

Authenticated identity may come from:

* authenticated connection identity
* authenticated peer-info
* authenticated reachability result
* authenticated scoring history
* explicit operator-pinned manual peer ID

Never from:

* payload-declared peer ID
* metadata-declared peer ID
* unsigned record identity
* multiaddr text

If:

```text id="xbyz2q"
payload_peer_id != authenticated_peer_id
```

then:

> reject record

A multiaddr is never identity proof.

---

## Base Eligibility

A peer is base eligible if one is true:

* fresh `SYNC_CANDIDATE` claim
* fresh `FULL_NODE` claim
* enabled manual sync peer

These do not qualify alone:

* `PUBLIC_RELAY`
* unrelated service claims

Base eligibility is only candidacy.

Not trust.

---

## Protocol Eligibility

Required protocol:

```text id="0mk6hw"
/zenon/sync/1.0.0
```

Rules:

* confirmed supported → eligible
* confirmed unsupported → excluded
* unknown support → excluded by default
* malformed peer-info → excluded

Manual peers may allow unknown support only through explicit config.

Manual peers may never override:

> confirmed unsupported

---

## Network / Genesis Eligibility

Known authenticated mismatch:

* wrong network → exclude
* wrong genesis → exclude

Authenticated compatibility evidence is required by default.

Self-reported discovery claims do not prove authenticated compatibility.

Manual peers may tolerate missing authenticated evidence only through explicit local override.

Manual override never bypasses:

* known wrong network
* known wrong genesis
* malformed identity
* conflicting authenticated identity

Manual peers are configurable.

Not trusted.

---

## Address Eligibility

Candidate must have:

* usable multiaddr

or:

* active authenticated connection

Otherwise:

> exclude

Reason:

```text id="j91m3q"
NO_USABLE_ADDRESS
```

---

## Reachability Policy

Default:

only:

> `LOCALLY_VERIFIED_REACHABLE`

is eligible.

By policy, implementations may optionally allow:

* `UNKNOWN`
* `STALE`

with warning:

> `REACHABILITY_NOT_VERIFIED`

`LOCALLY_UNREACHABLE` is excluded by default.

Manual override may permit temporary return under strict cap.

Reachability remains local evidence only.

---

## Scoring Policy

Selection uses:

> effective score label

Allowed labels:

* `PREFERRED`
* `ACCEPTABLE`
* `DEGRADED`
* `UNSCORABLE`

Rules:

* `PREFERRED` → eligible
* `ACCEPTABLE` → eligible
* `DEGRADED` → eligible only if better peers are insufficient
* `UNSCORABLE` → excluded by default

Manual peers may explicitly allow:

> `UNSCORABLE`

Expired score remains:

> `UNSCORABLE`

Fresh service claim does not revive expired score.

---

## Staleness Rules

Expired:

* service record → invalid candidacy
* reachability → becomes `STALE`
* score → becomes `UNSCORABLE`
* peer-info protocol → support becomes unknown
* peer-info identity → compatibility evidence becomes unavailable

Freshness in one layer does not revive stale state in another layer.

Every layer expires independently.

---

## Cooldown / Backoff

Cooldown is:

* local
* temporary
* diagnostic
* bounded

Never:

* consensus
* slashing
* global reputation

Suggested minimums:

```text id="e2cv6v"
connection failure = 30s
timeout = 60s
rate limited = 120s
malformed response = 10m
protocol violation = 30m
max cooldown = 1h
```

Repeated failures may apply exponential backoff.

Cooldown expiry restores eligibility only if other rules pass.

Manual peers obey cooldown by default.

Manual override must be explicit.

---

## Manual Peer Policy

Manual peers are:

> operator-configured candidates

They are not trusted.

They do not bypass validation.

They may relax missing-data requirements only through explicit config:

* missing service record
* missing reachability
* missing score
* unknown protocol support
* missing authenticated compatibility evidence

Manual peers must never override:

* wrong network
* wrong genesis
* malformed identity
* confirmed unsupported protocol
* invalid authenticated identity

Manual override is narrow and explicit.

Never generic trust.

---

## Diversity Policy

When multiple eligible peers exist:

selection should prefer diversity across:

* source type (manual / discovered)
* service type (`SYNC_CANDIDATE` / `FULL_NODE`)

Diversity:

* must remain deterministic
* may promote lower-ranked eligible peers
* must never promote ineligible peers
* must never override hard exclusions

Source diversity has priority over service diversity.

Unsatisfied diversity is diagnostic only.

Return results anyway.

---

## Ordering

Eligible peers are ordered deterministically by:

1. manual priority (if configured)
2. reachability quality
3. effective score label
4. higher numeric score
5. fewer failures
6. fewer timeouts
7. newer successful interaction
8. lower latency
9. fresher peer-info
10. fresher service record
11. canonical peer ID ordering

No randomness is permitted in selector ordering.

Scheduling randomness belongs in future scheduling specs.

---

## Selection API

```go id="d51bq9"
type Selector interface {
    SelectSyncCandidates(n uint32) ([]SyncCandidate, SelectionSummary)
}
```

Rules:

* `n = 0` → empty result
* `n > max_sync_candidates` → cap locally
* `returned <= effective_n`

Suggested default:

```text id="wtjlwm"
max_sync_candidates = 16
```

Selection pipeline:

1. collect local records
2. reject invalid identity records
3. merge by authenticated peer ID
4. apply eligibility gates
5. apply staleness rules
6. apply reachability policy
7. apply cooldown policy
8. apply scoring policy
9. order deterministically
10. apply diversity
11. return top N + summary

No network activity occurs in selection.

---

## Empty Result

If no peers qualify:

> return empty list

Reason:

```text id="28sqxj"
NO_ELIGIBLE_SYNC_CANDIDATES
```

This is valid output.

Selector must not automatically fall back to current P2P.

Fallback behavior requires separate integration specification.

---

## Security Rules

Must enforce:

* authenticated identity merge
* explicit protocol support checks
* authenticated network/genesis checks
* hard exclusions
* cooldown bounds
* deterministic ordering
* local-only state
* no network I/O
* no trust promotion
* manual override boundaries

Must not:

* dial peers
* fetch live state
* write chain state
* change consensus
* create rewards
* create slashing
* create global reputation

---

## Abuse Cases

Mitigations exist for:

* fake sync service claims
* wrong-network peers
* stale high scores
* single-peer dependency
* malformed peer-info
* address churn
* reachability drift
* over-querying one good peer
* conflicting local signals
* operator manual misconfiguration

Selection remains:

> local operational ranking only

Never protocol truth.

---

## Final Rule

Sync Candidate Selection chooses:

> which peers are worth asking first

It does not choose:

> what is true

Validation remains authoritative.

Selection is local operational judgment only.
