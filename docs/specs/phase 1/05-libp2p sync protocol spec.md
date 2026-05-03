# Zenon libp2p Sync Protocol Specification

**Status:** Implementation Ready
**Scope:** Bounded read-only sync data exchange over libp2p libp2p
**Target:** go-zenon Phase 1
**Depends On:** libp2p Host Specification, Peer Service Discovery Specification, Peer Reachability Verification Specification, Peer Service Scoring Specification
**Consensus Impact:** None
**Current P2P Impact:** None
**Gossip Impact:** None
**Economic Impact:** None

---

## Purpose

This specification defines a bounded request / response sync protocol over libp2p.

It allows one libp2p-enabled Zenon node to request read-only chain data from another libp2p-enabled Zenon node.

Supported operations:

* peer tip discovery
* momentum lookup by hash
* bounded momentum range fetch
* account blocks by momentum
* bounded account-chain range fetch

This specification does not define:

* current P2P replacement
* gossip
* chain insertion
* consensus validation
* rewards
* slashing
* global trust

It only defines:

> how bounded sync data is requested, served, received, validated, and rejected over libp2p

---

## Core Rule

All data received through libp2p sync is untrusted.

A receiving node MUST validate all received objects through existing go-zenon validation paths before any use.

Successful transport proves only:

> a connected peer returned bytes matching a bounded request

It does not prove:

* canonicality
* validity
* best-chain membership
* honesty
* global trustworthiness

Validation remains authoritative.

Transport is only transport.

---

## Design Goals

### G1 — Additive Only

The protocol must remain additive.

It must not:

* disable current P2P
* replace current P2P
* reroute current sync
* mutate consensus behavior

### G2 — Read-Only Serving

Serving nodes may only read local chain data.

Serving must never:

* mutate state
* create missing data
* fetch synchronously from other peers to answer
* write through ChainBridge

### G3 — Validation Before Use

Returned objects are untrusted until validated locally.

### G4 — Explicit Bounds

Every request type must be bounded.

Unbounded queries are forbidden.

### G5 — Deterministic Wire Contract

The protocol schema, framing, limits, and status codes are fixed.

### G6 — Safe Failure

Malformed, oversized, unsupported, unavailable, or invalid responses must fail closed.

### G7 — No Automatic Trust

Discovery, Reachability, and Scoring may influence peer choice.

They must never bypass validation.

---

## Protocol ID

```text id="jlwm8n"
/zenon/sync/1.0.0
```

Protocol type:

one-shot request / response

Lifecycle:

1. open stream
2. write one request
3. close write side
4. responder reads one request
5. responder validates
6. responder writes one response
7. responder closes stream
8. requester reads one response
9. requester closes stream

One request only.

One response only.

Then close.

Persistent streams are not defined in Phase 1.

---

## Activation Model

Requires:

```text id="vlm78y"
enable_libp2p = true
enable_libp2p_sync = true
```

Recommended defaults:

* **mainnet:** false
* **testnet:** operator configurable
* **devnet:** operator configurable

Even when enabled:

> current P2P remains authoritative

---

## Network Identity

Every request and response must include:

* network_id
* genesis_hash

Validation order:

1. network_id non-empty
2. network_id matches local network
3. genesis_hash length valid
4. genesis_hash matches local genesis hash

Mismatch:

* WRONG_NETWORK
  or
* WRONG_GENESIS

Responses failing identity checks must be rejected before payload use.

---

## Hash Rules

All hashes are raw bytes.

Expected length:

```text id="qovzdb"
32 bytes
```

Applies to:

* genesis_hash
* momentum_hash
* account-block hashes
* tip hashes

Wrong length:

> invalid request or invalid response

Hash strings are forbidden in wire format.

---

## Framing

Messages use:

> protobuf + varint length prefix

Wire format:

```text id="7m65s8"
varint_length || protobuf_payload
```

Receiver must:

1. read length
2. enforce max bytes before allocation
3. read exact payload bytes
4. decode protobuf

Raw protobuf without framing is invalid.

Fixed-width framing is invalid.

---

## Configuration

```go id="j4j6wn"
type LibP2PSyncConfig struct {
    Enable bool

    StreamTimeout time.Duration
    DialTimeout   time.Duration

    MaxRequestBytes  uint64
    MaxResponseBytes uint64

    MaxMomentumRangeCount       uint32
    MaxAccountBlocksPerMomentum uint32
    MaxAccountChainRangeCount   uint32

    MaxConcurrentInboundStreams  int
    MaxConcurrentOutboundStreams int

    MaxRequestsPerPeerMinute int
    MaxInvalidResponsesPerPeer int
}
```

Suggested defaults:

```text id="v6m7tr"
stream_timeout = 10s
dial_timeout = 10s

max_request_bytes = 64 KiB
max_response_bytes = 8 MiB

max_momentum_range_count = 128
max_account_blocks_per_momentum = 4096
max_account_chain_range_count = 1024

max_concurrent_inbound_streams = 32
max_concurrent_outbound_streams = 32

max_requests_per_peer_minute = 120
max_invalid_responses_per_peer = 10
```

All limits must be enforced before allocation.

---

## Request Types

Allowed request types:

* GET_PEER_TIP
* GET_MOMENTUM_BY_HASH
* GET_MOMENTUM_RANGE
* GET_ACCOUNT_BLOCKS_BY_MOMENTUM
* GET_ACCOUNT_CHAIN_RANGE

Unknown request types:

> UNSUPPORTED_REQUEST

No other request types are valid in Phase 1.

---

## Response Status Codes

Allowed status:

* OK
* BAD_REQUEST
* WRONG_NETWORK
* WRONG_GENESIS
* UNSUPPORTED_REQUEST
* NOT_FOUND
* RANGE_TOO_LARGE
* RESPONSE_TOO_LARGE
* RATE_LIMITED
* TEMPORARILY_UNAVAILABLE
* INTERNAL_ERROR

Rules:

If:

```text id="ay5e1x"
status != OK
```

then:

> success payload must be empty

If:

```text id="2r5v1c"
status == OK
```

then:

> matching success payload must exist

Partial OK responses are forbidden.

Short OK responses are invalid.

---

## Supported Operations

### GET_PEER_TIP

Returns:

* momentum_height
* momentum_hash
* timestamp_unix

Advisory only.

Not proof of best chain.

Useful for planning bounded range requests.

---

### GET_MOMENTUM_BY_HASH

Returns:

> one exact momentum by hash

Validation:

* hash matches request
* object decodes
* object passes existing validation before use

Missing:

> NOT_FOUND

---

### GET_MOMENTUM_RANGE

Returns:

> exact bounded ordered momentum range

Rules:

* count > 0
* count <= configured max
* returned count must equal requested count on OK
* ordered ascending
* heights must match requested range

Short OK responses are invalid.

Partial success is forbidden.

---

### GET_ACCOUNT_BLOCKS_BY_MOMENTUM

Returns:

> complete locally known account-block set for one momentum

Rules:

* complete set only
* partial OK forbidden
* if full set exceeds bound → RESPONSE_TOO_LARGE
* definitive empty set → OK with empty list

---

### GET_ACCOUNT_CHAIN_RANGE

Returns:

> bounded ordered account-chain block range

Rules:

* valid address required
* count > 0
* count <= configured max
* ordered ascending
* every block must belong to requested account

Valid empty range:

> OK with empty list

Empty is not an error.

---

## Validation Rules

Before serving:

must validate:

* framing
* message size
* network_id
* genesis_hash
* request_id
* exactly one request variant
* request bounds

Before using response:

must validate:

* framing
* message size
* network_id
* genesis_hash
* request_id match
* known status
* payload/status consistency
* response bounds
* object decode
* object ownership / range correctness
* existing go-zenon validation path

Anything failing validation:

> reject locally

No partial acceptance.

---

## Serving Rules

Serving node may:

> answer from local read-only data

Serving node must not:

* mutate state
* insert chain data
* call ChainBridge write paths
* bypass validation boundaries
* fetch externally to answer

Unavailable local data:

> NOT_FOUND
> or
> TEMPORARILY_UNAVAILABLE

depending on local condition.

---

## Receiving Rules

Receiving node must treat returned objects as:

> untrusted bytes

Before use:

must verify:

* decode succeeds
* hash matches request where applicable
* range matches request
* ownership matches request
* existing validation accepts object

Only validated objects may proceed further.

Transport success alone means nothing.

---

## Chain Insertion Boundary

Forbidden:

* direct state insertion from sync handler
* validation bypass
* consensus writes
* ChainBridge writes
* canonical marking by transport layer

Allowed:

* return bytes
* validate locally
* discard invalid objects
* record diagnostics

Transport is not chain insertion.

---

## Rate Limits and Bounds

Must bound:

* inbound streams
* outbound streams
* request rate
* request bytes
* response bytes
* response memory
* timeout windows

Suggested:

```text id="3zjlwm"
32 inbound streams
32 outbound streams
120 requests / peer / minute
10 second timeout
```

Bound everything.

Fail closed.

---

## Security Rules

Must enforce:

* authenticated peer identity
* network separation
* genesis separation
* exact bounds
* rate limits
* timeouts
* object validation before use
* no partial OK
* no direct insertion
* no trust bypass

Must not:

* gossip sync payloads
* mutate consensus
* write chain state
* create rewards
* create slashing
* modify current P2P

---

## Abuse Cases

Mitigations exist for:

* oversized requests
* oversized responses
* range explosion
* malformed framing
* wrong-network serving
* wrong-genesis serving
* invalid objects
* stream exhaustion
* slow streams
* short OK responses
* partial account-block responses
* mismatched responses
* rate abuse

All failures remain:

> local protocol failures only

Never consensus events.

---

## Final Rule

libp2p Sync is a bounded read-only transport.

It does not decide truth.

It does not replace current P2P.

It does not insert chain state.

It does not bypass validation.

It only allows a node to ask:

> What exact bounded chain data do you have?

The answer becomes useful only after local validation proves it acceptable.
