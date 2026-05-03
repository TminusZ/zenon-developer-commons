# Zenon libp2p Host Specification

**Status:** Implementation Ready
**Scope:** Additive libp2p host only
**Target:** go-zenon
**Consensus Impact:** None
**Sync Impact:** None
**Gossip Impact:** None
**Replacement Impact:** None

---

## Purpose

This specification defines the first additive libp2p host layer for go-zenon.

The purpose is to introduce a modern peer-to-peer substrate without replacing or modifying the current P2P stack.

This specification enables:

* stable libp2p peer identity
* encrypted libp2p connections
* static bootstrap peers
* peer-info request / response
* network ID rejection
* wrong-network backoff
* basic peer table
* basic observability

This specification does **not** enable:

* libp2p sync
* libp2p gossip
* libp2p transaction relay
* libp2p momentum relay
* libp2p account-block relay
* peer scoring
* service records
* AutoNAT
* relay nodes
* DEX coordination
* atomic swap coordination
* replacement of current P2P

The first implementation must remain strictly additive.

---

## Design Goals

### G1 — No Consensus Impact

The libp2p host must not affect:

* consensus
* chain state
* account-block validation
* momentum validation
* Plasma accounting

### G2 — No Current P2P Replacement

The existing P2P layer remains authoritative for current network behavior.

The libp2p host runs beside it.

### G3 — Stable Peer Identity

Each node receives a persistent libp2p identity key separate from all existing Zenon keys.

### G4 — Minimal Useful Peer Metadata

Nodes can exchange basic peer information through a small request / response protocol.

### G5 — Network Separation

Peers from the wrong network must be rejected and placed in temporary backoff.

### G6 — Future Compatibility

The host establishes the foundation for future:

* sync
* gossip
* service discovery
* reachability verification
* peer scoring
* peer-native coordination

---

## Non-Goals

This specification does not define:

* sync protocol
* gossip protocol
* peer scoring
* service records
* AutoNAT
* relay
* DHT routing
* pubsub
* wallet light-client behavior
* P2P DEX behavior
* atomic swap negotiation
* current P2P replacement

Any future protocol must be specified separately.

---

## Activation Model

libp2p is controlled by configuration.

Default:

* **testnet:** enabled or operator-configurable
* **mainnet:** disabled in first release

Mainnet default enablement requires a separate migration-roadmap decision.

---

## Replacement Blocking Rule

The libp2p host may be implemented before current P2P source verification is complete because it is additive.

Replacement work is blocked.

Replacement means any PR that:

* modifies existing P2P message behavior
* disables existing P2P
* removes existing P2P
* reroutes current sync through libp2p
* reroutes current gossip through libp2p
* changes ProtocolManager behavior
* changes `p2p.Server`
* changes current seeders
* counts libp2p peers as current sync peers

No replacement PR may begin until the Current P2P Map source-verification checklist is complete and reviewed.

---

## Package Layout

```text
p2p/libp2p/
  host.go
  config.go
  identity.go
  peer_table.go
  peer_info.go
  backoff.go
  metrics.go
  proto/
    peer_info.proto
```

The package must remain independent from existing `p2p.Server`.

It may be started and stopped from node startup / shutdown hooks.

---

## Configuration

```go
type LibP2PConfig struct {
    Enable bool

    KeyPath string

    ListenAddresses []string
    BootstrapPeers  []string

    MaxPeers    int
    MaxInbound  int
    MaxOutbound int

    DialTimeout   time.Duration
    StreamTimeout time.Duration

    WrongNetworkBackoff time.Duration
}
```

Suggested defaults:

```text
enable_libp2p = false
libp2p_key_path = <node_data_dir>/libp2p/peer.key

libp2p_listen_addresses = [
  "/ip4/0.0.0.0/tcp/<libp2p_port>"
]

libp2p_bootstrap_peers = []

libp2p_max_peers = 60
libp2p_max_inbound = 40
libp2p_max_outbound = 20

libp2p_dial_timeout = 10s
libp2p_stream_timeout = 10s
wrong_network_backoff = 10m
```

---

## Port Assignment

Known ports:

* `35995` — current P2P
* `35997` — HTTP RPC
* `35998` — WS RPC

libp2p must not conflict.

Suggested:

* `35999`
* `36000`

Final port selection must be recorded consistently across documentation and config defaults.

---

## Identity

The libp2p host uses a persistent **Ed25519** identity key.

It must not reuse:

* existing P2P ECDSA key
* wallet key
* producer key
* consensus key
* Pillar key
* Sentinel key

Startup:

```text
if key exists:
  load

else:
  generate Ed25519 key
  persist key
```

Peer ID is derived from the Ed25519 public key.

Identity has networking meaning only.

No consensus meaning.

---

## Final Rule

This PR adds the libp2p host.

It does not:

* migrate the network
* replace current P2P
* add sync
* add gossip
* touch consensus

The first goal is simple:

> prove Zenon nodes can maintain stable libp2p identity, open encrypted connections, exchange bounded peer metadata, reject wrong networks, and shut down cleanly without changing anything else.
