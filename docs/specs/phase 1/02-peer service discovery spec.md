# Zenon Peer Service Discovery Specification

**Status:** Implementation Ready
**Scope:** Bounded libp2p service advertisement and local discovery
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification
**Consensus Impact:** None
**Sync Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines a minimal peer service discovery layer for Zenon’s additive libp2p network.

Its purpose is to allow peers to:

* advertise what network services they claim to provide
* request and receive advertised service records from other peers
* maintain a bounded, local, non-consensus service registry

This specification turns the libp2p host from a pure connection layer into a discoverable service substrate.

It does **not** define:

* rewards
* slashing
* registration
* proof-of-service
* sync
* gossip
* routing
* economic entitlement
* on-chain service records

Service records are self-reported metadata only.

They are hints.

They are not proof.

---

## Design Goals

### G1 — No Consensus Impact

Service discovery must not affect:

* consensus
* chain state
* account-block validation
* momentum validation
* Plasma
* protocol rewards

### G2 — Self-Reported Metadata Only

Service records are peer claims only.

They do not prove:

* correctness
* honesty
* reachability
* uptime
* service quality
* reward eligibility

### G3 — Bounded and Safe

All service records must be:

* size bounded
* TTL bounded
* validation bounded
* registry bounded
* rate limited

### G4 — Future Compatibility

The layer should provide reusable service vocabulary for future specs without activating future behavior.

### G5 — Local Registry Only

Each node maintains its own service registry.

Registry state is local node state only.

Never consensus state.

---

## Protocol ID

```text id="1ktthm"
/zenon/service-discovery/1.0.0
```

Protocol type:

one-shot request / response

Unknown versions are ignored.

Peers must not be rejected solely because they do not support service discovery.

---

## Activation Model

Controlled by configuration.

Default:

* **mainnet:** disabled
* **testnet:** disabled, operator configurable

Service discovery requires libp2p host to be enabled.

If libp2p host is disabled, service discovery must remain disabled.

---

## Configuration

```go id="a8mvf0"
type LibP2PServiceDiscoveryConfig struct {
    Enable bool

    AdvertisedServices []string

    RecordTTL          time.Duration
    MaxRecordTTL       time.Duration
    RequestTimeout     time.Duration

    MaxServicesPerPeer int
    MaxRecordsPerPeer  int
    MaxRegistryPeers   int
    MaxRecordSizeBytes int

    MinRequestInterval     time.Duration
    InboundRequestInterval time.Duration
    RetryAfterFailureDelay time.Duration
    MaxClockSkew           time.Duration
}
```

Suggested defaults:

```text id="2kqj1t"
enable = false

record_ttl = 30m
max_record_ttl = 1h
request_timeout = 10s

max_services_per_peer = 16
max_records_per_peer = 16
max_registry_peers = 2048
max_record_size_bytes = 64 KiB

min_request_interval = 5m
inbound_request_interval = 1m
retry_after_failure_delay = 10s

max_clock_skew = 10m
```

---

## Service Record Model

A service record is a self-reported peer claim:

> I am the authenticated libp2p peer on this connection.
> On network Y.
> At time T.
> For TTL window Z.
> I claim to provide services S.

A service record does not prove:

* service works
* service is reachable
* service is honest
* service is high quality

Registry key:

> authenticated libp2p peer ID from the secure connection

Never from payload fields.

No peer ID field exists in payload by design.

---

## Service Names

Allowed format:

```text id="r3f7gi"
^[A-Z0-9_-]{1,64}$
```

Canonical format:

uppercase snake case

Examples:

* FULL_NODE
* PUBLIC_RELAY
* SYNC_CANDIDATE
* BOOTSTRAP_CANDIDATE
* ARCHIVE_CANDIDATE
* METRICS_OPT_IN

Unknown valid names may be stored as informational records.

Unknown names must not cause rejection.

---

## Recognized Service Types

### FULL_NODE

Claims to run a full node.

Does not prove correctness or sync availability.

### PUBLIC_RELAY

Claims to accept inbound libp2p connections.

Does not prove reachability.

### SYNC_CANDIDATE

Claims possible future sync support.

Does not permit sync under this specification.

### BOOTSTRAP_CANDIDATE

Claims usefulness as bootstrap peer.

Does not automatically become bootstrap seed.

### ARCHIVE_CANDIDATE

Claims deeper historical storage.

Does not prove archive completeness.

### METRICS_OPT_IN

Claims optional metrics participation.

No metrics serving behavior is defined here.

---

## Timestamp and Freshness

Every request / response includes:

```text id="ibv1z5"
timestamp_unix
```

Validation:

```text id="lgw9hn"
abs(local_time - timestamp_unix) <= max_clock_skew
```

Default:

```text id="txsq59"
10 minutes
```

Failure:

* reject message
* close stream
* do not update registry

Must not:

* disconnect peer
* apply wrong-network backoff

---

## TTL and Expiry

Default TTL:

```text id="7rvhku"
30 minutes
```

Maximum TTL:

```text id="ddqvul"
1 hour
```

If peer advertises longer TTL:

> clamp locally

Expired records must be removed.

Records are temporary.

Never permanent.

---

## Local Service Registry

Registry key:

> authenticated peer ID

Registry stores:

* service records
* expiry
* connected state
* last_seen_unix
* last_updated_unix
* validation result
* response state

Registry is:

* local only
* bounded
* optionally persisted
* never written to chain state
* never used for consensus

---

## Registry Eviction

Default cap:

```text id="om6frk"
2048 peers
```

Eviction order:

1. expired entries
2. zero-record entries
3. disconnected oldest last_seen_unix
4. oldest last_updated_unix

This bounds memory growth.

---

## Validation Rules

Must validate:

* protobuf decodes
* message <= 64 KiB
* network_id matches
* timestamp valid
* service count <= 16
* metadata count <= 16
* metadata key <= 64 bytes
* metadata value <= 256 bytes
* service name valid
* ttl > 0

Reserved economic metadata is silently dropped.

Examples:

* reward_address
* stake_amount
* qsr_amount
* pillar_id

No economic interpretation is allowed.

---

## Rate Limiting

Outbound:

```text id="28l9m5"
1 request / peer / 5 minutes
```

Single retry allowed after failure:

```text id="1jvy5w"
retry_after_failure_delay = 10s
```

Only once per connection event.

Inbound:

```text id="ty7db3"
1 accepted request / peer / minute
```

Violations:

* close stream
* no application response
* log event

No disconnect required for first violation.

---

## Security Rules

Must enforce:

* authenticated peer identity
* network ID validation
* message size limits
* TTL limits
* rate limits
* metadata limits
* registry bounds
* timestamp validation

Must not trust service claims for:

* consensus
* rewards
* sync
* routing
* correctness

Must not:

* call ChainBridge
* modify current P2P
* write chain state

---

## Abuse Cases

Mitigations exist for:

* registry flooding
* metadata spam
* request flooding
* retry bypass via reconnect
* stale record replay
* fake service claims
* reserved economic metadata abuse

Claims remain hints only.

Verification comes later.

---

## Final Rule

Peer service discovery tells the node what another peer claims it can do.

It does not prove the peer can do it.

It does not trust the peer.

It does not reward the peer.

It does not change consensus.

It provides a bounded, local, peer-authenticated vocabulary for network capabilities.
