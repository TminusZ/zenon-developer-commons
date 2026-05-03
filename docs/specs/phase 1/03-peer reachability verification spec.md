# Zenon Peer Reachability Verification Specification

**Status:** Implementation Ready
**Scope:** Local reachability verification for libp2p peers
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification
**Consensus Impact:** None
**Sync Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines a local reachability verification layer for Zenon’s additive libp2p network.

Peer Service Discovery allows a peer to claim:

* I provide FULL_NODE
* I provide PUBLIC_RELAY
* I may be a SYNC_CANDIDATE
* I may be useful network infrastructure

This specification adds verification:

* can the local node freshly reach the peer
* can the peer accept a fresh inbound connection
* can the peer answer a minimal authenticated challenge
* can the result be stored locally without becoming consensus state

This specification creates:

> local, bounded, non-consensus reachability observations

It does not create:

* rewards
* slashing
* global truth
* proof-of-service
* automatic trust
* consensus meaning

---

## Design Goals

### G1 — Local Evidence Only

Reachability results are local observations only.

A successful result means:

> reachable from this node, at this time

Nothing more.

### G2 — No Consensus Meaning

Results must never affect:

* consensus
* chain state
* Plasma
* transaction validity
* momentum validity
* account-block validity

### G3 — No Economic Meaning

Reachability results must never create:

* rewards
* slashing
* entitlement
* service reputation

### G4 — Discovery Driven

Checks should primarily target peers advertising:

* PUBLIC_RELAY

Secondary targets:

* FULL_NODE
* SYNC_CANDIDATE
* BOOTSTRAP_CANDIDATE
* ARCHIVE_CANDIDATE

### G5 — Bounded Resource Use

Verification must be:

* timeout bounded
* nonce bounded
* concurrency bounded
* rate limited
* registry bounded

---

## Protocol ID

```text id="lfp96r"
/zenon/reachability/1.0.0
```

Protocol type:

one-shot request / response

Peers must not be rejected solely for not supporting reachability verification.

---

## Activation Model

Controlled by configuration.

Default:

* **mainnet:** disabled
* **testnet:** disabled, operator configurable

Requires:

* libp2p host enabled

Automatic checks additionally require:

* peer service discovery enabled

Manual mode may use operator-configured static targets.

---

## Configuration

```go id="zjlwmq"
type LibP2PReachabilityConfig struct {
    Enable bool

    CheckInterval  time.Duration
    ResultTTL      time.Duration
    RequestTimeout time.Duration
    DialTimeout    time.Duration
    MaxClockSkew   time.Duration

    MaxConcurrentChecks           int
    MaxChecksPerPeerHour          int
    MaxInboundRequestsPerPeerHour int
    MaxTargetsPerRound            int
    MaxReachabilityResults        int

    ChallengeBytes    int
    RequireFreshNonce bool
    MaxActiveNonces   int

    VerifyPublicRelayOnly bool

    OperatorStaticReachabilityTargets []string
}
```

Suggested defaults:

```text id="gpk0gr"
enable = false

check_interval = 30m
result_ttl = 2h

request_timeout = 10s
dial_timeout = 10s

max_clock_skew = 10m

max_concurrent_checks = 16
max_checks_per_peer_hour = 4
max_inbound_requests_per_peer_hour = 4
max_targets_per_round = 128
max_reachability_results = 2048

challenge_bytes = 32
require_fresh_nonce = true
max_active_nonces = 4096

verify_public_relay_only = true
```

---

## Reachability States

Allowed states:

* UNKNOWN
* CLAIMED_REACHABLE
* LOCALLY_VERIFIED_REACHABLE
* LOCALLY_UNREACHABLE
* STALE

Meaning:

### UNKNOWN

No claim and no check.

### CLAIMED_REACHABLE

Peer advertises service claim, but no successful verification exists.

### LOCALLY_VERIFIED_REACHABLE

Fresh local verification succeeded within TTL.

### LOCALLY_UNREACHABLE

Fresh local verification failed.

### STALE

Previous result expired.

Expired positive and expired negative results both become:

> STALE

---

## Verification Model

A peer is locally verified reachable only if both steps succeed:

1. Fresh Dial Test
2. Challenge Response Test

---

## Step 1 — Fresh Dial Test

The checker must:

* snapshot current connection handles for peer
* dial candidate multiaddr
* authenticate expected peer ID
* observe a new post-check connection handle

Requirements:

* connection handle must be new
* authenticated peer ID must match target peer
* reused pre-check connections do not count
* dial deduplication into old connection does not count

Failure:

```text id="g51qvh"
FRESH_DIAL_NOT_SATISFIED
```

This prevents false positives from stale connections.

---

## Step 2 — Challenge Response

After fresh dial:

open:

```text id="r0lnrq"
/zenon/reachability/1.0.0
```

Send:

* random nonce
* timestamp
* network ID

Peer must:

* echo nonce exactly
* pass timestamp validation
* match network ID

Success:

> LOCALLY_VERIFIED_REACHABLE

Failure:

> LOCALLY_UNREACHABLE

---

## Nonce Rules

Nonce must be:

* cryptographically random
* default 32 bytes
* non-empty
* never reused within result TTL
* never reused across peers within result TTL

Cache stores:

* nonce
* created_unix
* expiry_unix
* target_peer_id

If nonce cache fills:

```text id="o5tn7p"
NONCE_CACHE_FULL
```

This is local resource exhaustion.

It must not mark peer unreachable.

---

## Result Model

Registry key:

> authenticated peer ID

Registry stores:

* state
* last_checked_unix
* last_success_unix
* last_failure_unix
* success_count
* failure_count
* verified_multiaddr
* observed_multiaddrs
* last_error
* expiry_unix
* source_service_claim
* service_claim_present

Registry is:

* local only
* bounded
* optionally persisted
* never consensus state
* never reward state

---

## Public Relay Verification Rules

A peer may be treated as locally verified public relay only if:

* state = LOCALLY_VERIFIED_REACHABLE
* now < expiry_unix
* service_claim_present = true
* source_service_claim = PUBLIC_RELAY

All four required.

Missing any one:

> not eligible

---

## Timestamp Validation

Validation:

```text id="h95hz5"
abs(local_time - timestamp_unix) <= max_clock_skew
```

Failure:

* reject message
* close stream
* record failure

Must not:

* disconnect peer
* apply wrong-network backoff

---

## Rate Limiting

Outbound:

```text id="7a0z8l"
4 checks / peer / hour
```

Inbound:

```text id="a4twll"
4 requests / peer / hour
```

Concurrency:

```text id="8nvvzk"
16 concurrent checks
```

Round target cap:

```text id="fxw5ea"
128 peers / round
```

Bounded probing only.

No continuous probing.

---

## Security Rules

Must enforce:

* authenticated peer identity
* peer ID match
* fresh dial requirement
* new connection requirement
* random nonce
* nonce non-reuse
* timestamp validation
* network ID validation
* rate limits
* concurrency limits
* result TTL

Must not:

* gossip negative results
* write on-chain
* reward peers
* slash peers
* modify current P2P
* call ChainBridge
* change sync behavior
* change gossip behavior

---

## Abuse Cases

Mitigations exist for:

* probe flooding
* fake PUBLIC_RELAY claims
* existing connection false positives
* dial deduplication false positives
* nonce replay
* nonce cache starvation
* address poisoning
* false accusation surfaces
* stale claim abuse

Results remain:

> local observations only

Never global truth.

---

## Final Rule

Peer Service Discovery lets a peer claim usefulness.

Peer Reachability Verification lets a local node test one narrow part of that claim.

It does not prove honesty.

It does not prove quality.

It does not create rewards.

It does not change consensus.

It only answers:

> Can I freshly reach this peer right now through libp2p, and can it answer a fresh authenticated challenge?
