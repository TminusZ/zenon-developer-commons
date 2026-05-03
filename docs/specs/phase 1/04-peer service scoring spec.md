# Zenon Peer Service Scoring Specification

**Status:** Implementation Ready
**Scope:** Local-only scoring of libp2p service peers
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification, Peer Reachability Verification Specification
**Consensus Impact:** None
**Sync Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines a local-only scoring layer for peers discovered through Zenon’s additive libp2p network.

Peer Service Discovery answers:

> What does this peer claim to provide?

Peer Reachability Verification answers:

> Can this node locally reach that peer and receive a fresh authenticated response?

Peer Service Scoring answers:

> How useful has this peer been over time from this node’s local point of view?

Scores are:

* local observations
* bounded
* time-sensitive
* diagnostic
* usable for future local peer selection

Scores are not:

* consensus truth
* global reputation
* reward eligibility
* slashing evidence
* proof-of-service

---

## Design Goals

### G1 — Local Opinion Only

Scores are produced by one node from that node’s observations.

They must not be treated as network-wide truth.

### G2 — No Consensus Meaning

Scores must never affect:

* consensus
* chain state
* transaction validity
* account-block validation
* momentum validation
* Plasma

### G3 — No Economic Meaning

Scores must never create:

* rewards
* slashing
* eligibility
* economic privilege

### G4 — Measurable Inputs Only

Scores should only use measurable local observations:

* reachability
* success count
* failure count
* timeout count
* freshness
* latency
* version compatibility

### G5 — Conservative Failure Handling

Repeated failures reduce score.

One failure must not permanently punish a peer.

### G6 — Future Compatibility

Scores should be reusable for future:

* peer ranking
* sync candidate ranking
* public relay ranking
* diagnostics

This specification does not wire scores into live routing.

---

## Activation Model

Controlled by configuration.

Default:

* **mainnet:** disabled
* **testnet:** disabled, operator configurable

Requires:

* libp2p host enabled

Automatic scoring additionally requires:

* Peer Service Discovery enabled
* Peer Reachability Verification enabled

Manual diagnostic scoring is allowed separately.

---

## Configuration

```go id="89fz6u"
type LibP2PServiceScoringConfig struct {
    Enable bool

    ScoreTTL            time.Duration
    ObservationWindow   time.Duration
    ObservationRetention time.Duration
    DecayInterval       time.Duration

    MinObservations int

    MaxScoredPeers        int
    MaxServicesPerPeer    int

    PersistScores       bool
    PersistObservations bool

    LatencyGoodMs       int
    LatencyAcceptableMs int
    LatencyPoorMs       int
    LatencyMaxSampleMs  int

    SuccessWeight       int
    FailureWeight       int
    TimeoutWeight       int
    ReachabilityWeight  int
    FreshnessWeight     int
    CompatibilityWeight int

    PreferredThreshold  int
    GoodThreshold       int
    AcceptableThreshold int

    CompatibleVersions map[string][]string
}
```

Suggested defaults:

```text id="y7n5vk"
enable = false

score_ttl = 6h
observation_window = 24h
observation_retention = 48h
decay_interval = 30m

min_observations = 3

max_scored_peers = 2048
max_services_per_peer = 16

persist_scores = true
persist_observations = true

latency_good_ms = 250
latency_acceptable_ms = 1000
latency_poor_ms = 3000
latency_max_sample_ms = 60000

success_weight = 50
failure_weight = 25
timeout_weight = 20
reachability_weight = 20
freshness_weight = 20
compatibility_weight = 5

preferred_threshold = 85
good_threshold = 70
acceptable_threshold = 50
```

---

## Score Scope

Scores are keyed by:

> authenticated peer ID + service name

Example:

```text id="q5gks7"
peer A / PUBLIC_RELAY = 91
peer A / SYNC_CANDIDATE = 52
peer A / ARCHIVE_CANDIDATE = UNSCORABLE
```

A peer’s score for one service must not automatically apply to another service.

---

## Score Labels

Allowed labels:

* UNKNOWN
* UNSCORABLE
* POOR
* ACCEPTABLE
* GOOD
* PREFERRED

Meaning:

### UNKNOWN

No active service claim exists.

### UNSCORABLE

Claim exists, but:

* not enough observations
* score expired
* required inputs unavailable

### POOR

Below acceptable threshold.

### ACCEPTABLE

Usable, but not preferred.

### GOOD

Reliable local performance.

### PREFERRED

High local reliability and freshness.

---

## Inputs

Scores may consume:

* service claim presence
* reachability state
* reachability freshness
* success observations
* failure observations
* timeout observations
* latency samples
* service version compatibility

Inputs are local-only.

Nothing is gossiped.

Nothing is written on-chain.

---

## Observation Window

Only observations inside the rolling observation window count.

Default:

```text id="6tzg0q"
24 hours
```

Older observations may remain for diagnostics but must not contribute to score.

This prevents old success history from masking recent failures.

---

## Minimum Observations

A peer-service pair is not scoreable until:

```text id="1hcb9u"
observation_count >= 3
```

Before that:

> label = UNSCORABLE

This prevents one lucky success from creating a preferred peer.

---

## Reachability Rules

A peer must not be labeled **PREFERRED** unless:

* service claim present
* reachability state = LOCALLY_VERIFIED_REACHABLE
* current time < reachability expiry
* score not expired
* minimum observations met

If reachability is:

* LOCALLY_UNREACHABLE
* STALE
* UNKNOWN
* expired

label must not exceed:

> ACCEPTABLE

Reachability is a hard cap.

---

## Freshness

Recent successful observations receive freshness credit.

Default windows:

```text id="7cgdv4"
full freshness = 1h
partial freshness = 4h
```

Recent success:

* full freshness credit

Moderately recent:

* partial freshness credit

Stale success:

* zero freshness credit

Freshness rewards current usefulness.

---

## Latency

Latency is measured using rolling local observations.

Adjustment:

* excellent latency → bonus
* acceptable latency → neutral
* poor latency → penalty
* very poor latency → stronger penalty

Unknown latency:

> neutral

Unknown latency must never be treated as zero latency.

---

## Compatibility

Optional version compatibility bonus.

Computed from:

* service name
* advertised version
* local CompatibleVersions config

Compatible:

> bonus applied

Incompatible:

> no bonus

Compatibility is informational weighting only.

Never hard trust.

---

## Score Formula

Score is derived from:

* success component
* failure component
* reachability component
* freshness component
* compatibility component
* latency adjustment

Final score:

```text id="hf1g2k"
0 <= score <= 100
```

Score must always be clamped.

---

## Score Expiry

Scores expire.

Default:

```text id="l5c4d9"
6 hours
```

Expired score:

> UNSCORABLE

Expired scores must not be used for preferred selection.

---

## Score Decay

Scores decay when fresh observations stop arriving.

Default:

```text id="a0kn76"
1 point / 30 minutes
```

Decay is:

* linear
* local-only
* bounded
* reset by fresh score-affecting observations

Decay prevents stale reputation.

---

## Selection Eligibility

A peer-service pair is eligible for preferred local selection only if:

* active service claim
* score active
* minimum observations met
* locally verified reachable
* reachability not expired
* effective label = GOOD or PREFERRED

If no peers qualify:

> return empty result

Selection must not silently relax rules.

---

## Selection Order

Within eligible peers:

1. higher label
2. higher numeric score
3. lower latency
4. more recent success
5. lower failure count
6. deterministic peer ID ordering

Selection is deterministic and local-only.

---

## Persistence

Scores may be persisted locally.

Persisted scores are cache only.

On startup:

* validate records
* recompute expiry
* refresh service claim state
* refresh reachability state
* recompute compatibility
* rebuild rolling counters if persisted
* mark insufficient data as UNSCORABLE
* enforce registry bounds

Current upstream discovery / reachability state always wins.

---

## Registry Bounds

Default:

```text id="4g2kwx"
2048 peers
16 services per peer
```

Eviction priority:

1. expired scores
2. removed service claims
3. UNKNOWN / UNSCORABLE
4. oldest update
5. lowest score
6. deterministic final tie-break

Registry remains bounded.

---

## Security Rules

Must enforce:

* local-only score records
* bounded registry
* score expiry
* score decay
* rolling observation window
* minimum observations
* reachability cap
* deterministic selection
* startup recomputation
* persisted cache validation

Must not:

* gossip scores
* write chain state
* call ChainBridge
* modify current P2P
* modify sync behavior
* modify gossip behavior
* create rewards
* create slashing
* create global reputation

---

## Abuse Cases

Mitigations exist for:

* one-shot score inflation
* stale reputation
* historical masking
* flaky peers
* timeout-heavy peers
* false accusation surfaces
* version mismatch
* persistence corruption
* registry flooding

Scores remain:

> local opinion only

Never network truth.

---

## Final Rule

Peer Service Scoring provides a bounded local ranking signal for discovered peers.

It answers:

> From this node’s perspective, which peers have been locally useful over time?

It does not prove honesty.

It does not prove global quality.

It does not create rewards.

It does not change consensus.

It creates local operational intelligence only.
